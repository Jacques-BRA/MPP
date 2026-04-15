-- =============================================
-- Procedure:   Parts.BomLine_Remove
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   HARD DELETEs a BomLine row. BomLine has no DeprecatedAt column —
--   lines are part of a BOM version; removal is a hard delete. After
--   deletion, compacts the SortOrder of remaining siblings within the
--   same BomId so there are no gaps:
--
--     UPDATE Parts.BomLine
--     SET SortOrder = SortOrder - 1
--     WHERE BomId = @ParentBomId AND SortOrder > @RemovedSort;
--
--   Rejects if the parent BOM is Deprecated OR Published — published/
--   deprecated BOMs are immutable (create a new version to modify).
--
-- Parameters (input):
--   @Id BIGINT        - Required.
--   @AppUserId BIGINT - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--
-- Dependencies:
--   Tables: Parts.BomLine, Parts.Bom
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.BomLine_Remove
    @Id        BIGINT,
    @AppUserId BIGINT,
    @Status    BIT            OUTPUT,
    @Message   NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.BomLine_Remove';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Target must exist; also capture its parent and SortOrder
        DECLARE @ParentBomId BIGINT, @RemovedSort INT;
        SELECT @ParentBomId = BomId,
               @RemovedSort = SortOrder
        FROM Parts.BomLine
        WHERE Id = @Id;

        IF @ParentBomId IS NULL
        BEGIN
            SET @Message = N'BomLine not found.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Parent BOM must be active (unpublished, non-deprecated)
        DECLARE @ParentPublished  DATETIME2(3) = NULL;
        DECLARE @ParentDeprecated DATETIME2(3) = NULL;
        SELECT @ParentPublished  = PublishedAt,
               @ParentDeprecated = DeprecatedAt
        FROM Parts.Bom WHERE Id = @ParentBomId;

        IF @ParentDeprecated IS NOT NULL
        BEGIN
            SET @Message = N'Parent BOM is deprecated (immutable).';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        IF @ParentPublished IS NOT NULL
        BEGIN
            SET @Message = N'Parent BOM is published (immutable). Create a new version to modify.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Capture OldValue for audit BEFORE the DELETE
        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT BomId, ChildItemId, QtyPer, UomId, SortOrder
             FROM Parts.BomLine WHERE Id = @Id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        -- Hard delete
        DELETE FROM Parts.BomLine WHERE Id = @Id;

        -- Compact SortOrder of remaining siblings — close the gap
        UPDATE Parts.BomLine
        SET SortOrder = SortOrder - 1
        WHERE BomId = @ParentBomId
          AND SortOrder > @RemovedSort;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'BomLine',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Deprecated',
            @LogSeverityCode   = N'Info',
            @Description       = N'BomLine removed (hard delete) and sibling SortOrder compacted.',
            @OldValue          = @OldValue,
            @NewValue          = NULL;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'BomLine removed successfully.';
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
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
