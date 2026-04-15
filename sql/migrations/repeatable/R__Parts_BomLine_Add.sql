-- =============================================
-- Procedure:   Parts.BomLine_Add
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Appends a component line to a Draft BOM. SortOrder is auto-assigned
--   as MAX(sibling SortOrder) + 1 within the BOM.
--
--   Rejects in any of these cases:
--     - Parent BOM is Published (PublishedAt IS NOT NULL) — publish-lock
--     - Parent BOM is Deprecated
--     - ChildItemId equals the BOM's ParentItemId (one-level self-reference)
--     - ChildItemId is already an active line on this BOM (prevents
--       duplicate-component lines; update the existing line's QtyPer
--       instead — caught by the proc check AND the UQ_BomLine_Bom_ChildItem
--       index)
--     - Any referenced Item/UOM is deprecated or missing
--
--   To reorder lines after Add, use _MoveUp / _MoveDown.
--
-- Parameters (input):
--   @BomId BIGINT          - Required.
--   @ChildItemId BIGINT    - Required.
--   @QtyPer DECIMAL(10,4)  - Required.
--   @UomId BIGINT          - Required.
--   @AppUserId BIGINT      - Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR), NewId (BIGINT).
--   Status=1 on success, 0 on failure. NewId is NULL on failure.
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-15 - 2.0 - SELECT result for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.BomLine_Add
    @BomId       BIGINT,
    @ChildItemId BIGINT,
    @QtyPer      DECIMAL(10,4),
    @UomId       BIGINT,
    @AppUserId   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';
    DECLARE @NewId   BIGINT        = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Parts.BomLine_Add';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @BomId AS BomId, @ChildItemId AS ChildItemId,
                @QtyPer AS QtyPer, @UomId AS UomId
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @BomId IS NULL OR @ChildItemId IS NULL OR @QtyPer IS NULL OR @UomId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- Look up parent BOM state + ParentItemId
        DECLARE @ParentItemId    BIGINT      = NULL;
        DECLARE @ParentPublished DATETIME2(3) = NULL;
        DECLARE @ParentDeprecated DATETIME2(3) = NULL;

        SELECT @ParentItemId     = ParentItemId,
               @ParentPublished  = PublishedAt,
               @ParentDeprecated = DeprecatedAt
        FROM Parts.Bom WHERE Id = @BomId;

        IF @ParentItemId IS NULL
        BEGIN
            SET @Message = N'Parent BOM not found.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        IF @ParentDeprecated IS NOT NULL
        BEGIN
            SET @Message = N'Parent BOM is deprecated (immutable).';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        IF @ParentPublished IS NOT NULL
        BEGIN
            SET @Message = N'Parent BOM is published (immutable). Create a new version to modify.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- Self-reference: ChildItemId cannot equal the BOM's ParentItemId
        IF @ChildItemId = @ParentItemId
        BEGIN
            SET @Message = N'A BOM cannot contain its parent Item as a component (self-reference).';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- ChildItemId must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.Item WHERE Id = @ChildItemId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated ChildItemId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- UomId must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.Uom WHERE Id = @UomId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated UomId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- ChildItemId must not already be a line on this BOM
        IF EXISTS (SELECT 1 FROM Parts.BomLine WHERE BomId = @BomId AND ChildItemId = @ChildItemId)
        BEGIN
            SET @Message = N'This Item is already a line on the BOM. Update the existing line to change QtyPer.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        BEGIN TRANSACTION;

        DECLARE @NextSort INT;
        SELECT @NextSort = ISNULL(MAX(SortOrder), 0) + 1
        FROM Parts.BomLine
        WHERE BomId = @BomId;

        INSERT INTO Parts.BomLine (BomId, ChildItemId, QtyPer, UomId, SortOrder)
        VALUES (@BomId, @ChildItemId, @QtyPer, @UomId, @NextSort);

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'BomLine',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'BomLine added.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'BomLine added successfully.';
    SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);
        SET @NewId   = NULL;

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
