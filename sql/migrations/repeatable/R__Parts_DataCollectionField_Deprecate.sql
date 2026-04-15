-- =============================================
-- Procedure:   Parts.DataCollectionField_Deprecate
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     1.0
--
-- Description:
--   Soft-deletes a DataCollectionField row by setting DeprecatedAt. Rejects if the
--   DataCollectionField is referenced by any Parts.OperationTemplateField.DataCollectionFieldId
--   (active rows only).
--
-- Parameters (input):
--   @Id BIGINT         - PK. Required.
--   @AppUserId BIGINT  - User performing the action. Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--
-- Dependencies:
--   Tables: Parts.DataCollectionField, Parts.OperationTemplateField (for dependency
--           check — table may not exist yet; check is guarded by sys.tables lookup)
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Error Handling:
--   Standard three-tier: validation, business rule, CATCH with RAISERROR.
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.DataCollectionField_Deprecate
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

    DECLARE @ProcName NVARCHAR(200) = N'Parts.DataCollectionField_Deprecate';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DataCollectionField',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: target must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.DataCollectionField WHERE Id = @Id AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'DataCollectionField not found or already deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DataCollectionField',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: no active dependents (Parts.OperationTemplateField)
        -- Guarded: Parts.OperationTemplateField may not exist yet in earlier phases.
        IF EXISTS (SELECT 1 FROM sys.tables t
                   INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
                   WHERE s.name = N'Parts' AND t.name = N'OperationTemplateField')
        BEGIN
            DECLARE @DepCount INT;
            EXEC sp_executesql
                N'SELECT @cnt = COUNT(*) FROM Parts.OperationTemplateField WHERE DataCollectionFieldId = @id AND DeprecatedAt IS NULL;',
                N'@id BIGINT, @cnt INT OUTPUT',
                @id = @Id, @cnt = @DepCount OUTPUT;

            IF @DepCount > 0
            BEGIN
                SET @Message = N'Cannot deprecate: active OperationTemplateFields reference this DataCollectionField.';
                EXEC Audit.Audit_LogFailure
                    @AppUserId = @AppUserId, @LogEntityTypeCode = N'DataCollectionField',
                    @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                    @FailureReason = @Message, @ProcedureName = @ProcName,
                    @AttemptedParameters = @Params;
                RETURN;
            END
        END

        BEGIN TRANSACTION;

        UPDATE Parts.DataCollectionField
        SET DeprecatedAt = SYSUTCDATETIME()
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'DataCollectionField',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Deprecated',
            @LogSeverityCode   = N'Info',
            @Description       = N'DataCollectionField deprecated.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'DataCollectionField deprecated successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DataCollectionField',
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
