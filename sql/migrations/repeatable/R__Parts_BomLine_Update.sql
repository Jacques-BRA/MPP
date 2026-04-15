-- =============================================
-- Procedure:   Parts.BomLine_Update
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Updates mutable fields of a BomLine. Only QtyPer and UomId are
--   mutable — BomId, ChildItemId, and SortOrder are immutable here
--   (SortOrder is managed via _MoveUp / _MoveDown; BomId/ChildItemId
--   changes require Remove + Add).
--
--   Rejects in any of these cases:
--     - Parent BOM is Deprecated
--     - Parent BOM is Published (publish-lock — create a new version
--       to modify)
--     - Target BomLine row does not exist
--     - @UomId is invalid or deprecated
--
-- Parameters (input):
--   @Id BIGINT            - Required.
--   @QtyPer DECIMAL(10,4) - Required.
--   @UomId BIGINT         - Required.
--   @AppUserId BIGINT     - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--
-- Dependencies:
--   Tables: Parts.BomLine, Parts.Bom, Parts.Uom
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.BomLine_Update
    @Id        BIGINT,
    @QtyPer    DECIMAL(10,4),
    @UomId     BIGINT,
    @AppUserId BIGINT,
    @Status    BIT            OUTPUT,
    @Message   NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.BomLine_Update';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id, @QtyPer AS QtyPer, @UomId AS UomId
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Id IS NULL OR @QtyPer IS NULL OR @UomId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Look up target row + its parent BomId
        DECLARE @BomId BIGINT = NULL;

        SELECT @BomId = BomId
        FROM Parts.BomLine WHERE Id = @Id;

        IF @BomId IS NULL
        BEGIN
            SET @Message = N'BomLine not found.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Parent BOM must be active AND unpublished (draft)
        DECLARE @ParentPublished  DATETIME2(3) = NULL;
        DECLARE @ParentDeprecated DATETIME2(3) = NULL;
        SELECT @ParentPublished  = PublishedAt,
               @ParentDeprecated = DeprecatedAt
        FROM Parts.Bom WHERE Id = @BomId;

        IF @ParentDeprecated IS NOT NULL
        BEGIN
            SET @Message = N'Parent BOM is deprecated (immutable).';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        IF @ParentPublished IS NOT NULL
        BEGIN
            SET @Message = N'Parent BOM is published (immutable). Create a new version to modify.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- UomId must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.Uom WHERE Id = @UomId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated UomId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Capture OldValue for audit BEFORE the UPDATE
        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT BomId, ChildItemId, QtyPer, UomId, SortOrder
             FROM Parts.BomLine WHERE Id = @Id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Parts.BomLine
        SET QtyPer = @QtyPer,
            UomId  = @UomId
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'BomLine',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'BomLine updated.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'BomLine updated successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
