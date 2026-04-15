-- =============================================
-- Procedure:   Parts.Bom_CreateNewVersion
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Creates a new BOM version by cloning the parent row and all its
--   BomLines. The new BOM starts as a Draft (PublishedAt = NULL) so
--   engineering can edit before publishing. The parent row is NOT
--   auto-deprecated — it stays whatever it was. A typical workflow:
--     1. _CreateNewVersion → draft clone
--     2. BomLine_Add/Update/MoveUp/MoveDown/Remove → edit the clone
--     3. _Publish on the clone
--     4. (optional) _Deprecate on the prior version if no longer needed
--
-- Parameters (input):
--   @ParentBomId BIGINT              - Source version to clone. Required.
--   @EffectiveFrom DATETIME2(3) NULL - When the new version becomes active.
--                                       NULL → uses SYSUTCDATETIME().
--   @AppUserId BIGINT                - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--   @NewId BIGINT          - New Bom.Id on success.
--
-- Dependencies:
--   Tables: Parts.Bom, Parts.BomLine
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.Bom_CreateNewVersion
    @ParentBomId   BIGINT,
    @EffectiveFrom DATETIME2(3)  = NULL,
    @AppUserId     BIGINT,
    @Status        BIT           OUTPUT,
    @Message       NVARCHAR(500) OUTPUT,
    @NewId         BIGINT        = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';
    SET @NewId   = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Parts.Bom_CreateNewVersion';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @ParentBomId AS ParentBomId, @EffectiveFrom AS EffectiveFrom
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @ParentBomId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Bom',
                @EntityId = @ParentBomId, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        DECLARE @ParentItemId BIGINT = NULL;
        SELECT @ParentItemId = ParentItemId FROM Parts.Bom WHERE Id = @ParentBomId;

        IF @ParentItemId IS NULL
        BEGIN
            SET @Message = N'Parent BOM not found.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Bom',
                @EntityId = @ParentBomId, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        DECLARE @EffFrom DATETIME2(3) = ISNULL(@EffectiveFrom, SYSUTCDATETIME());

        BEGIN TRANSACTION;

        DECLARE @NextVersion INT;
        SELECT @NextVersion = ISNULL(MAX(VersionNumber), 0) + 1
        FROM Parts.Bom
        WHERE ParentItemId = @ParentItemId;

        INSERT INTO Parts.Bom
            (ParentItemId, VersionNumber, EffectiveFrom, CreatedByUserId, CreatedAt)
        VALUES
            (@ParentItemId, @NextVersion, @EffFrom, @AppUserId, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        -- Clone BomLines from parent → new BOM
        INSERT INTO Parts.BomLine (BomId, ChildItemId, QtyPer, UomId, SortOrder)
        SELECT @NewId, ChildItemId, QtyPer, UomId, SortOrder
        FROM Parts.BomLine
        WHERE BomId = @ParentBomId;

        DECLARE @LineCount INT = @@ROWCOUNT;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'Bom',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'BOM cloned from parent as new version (Draft).',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'New BOM version created as Draft (' +
                       CAST(@LineCount AS NVARCHAR(10)) + N' line(s) copied).';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Bom',
                @EntityId = @ParentBomId, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
