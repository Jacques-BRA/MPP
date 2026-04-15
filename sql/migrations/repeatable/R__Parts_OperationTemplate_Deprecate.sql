-- =============================================
-- Procedure:   Parts.OperationTemplate_Deprecate
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Soft-deletes an active OperationTemplate by setting DeprecatedAt.
--   Rejects if any active Parts.RouteStep (under an active
--   Parts.RouteTemplate) references this OperationTemplate.
--
--   The dependency check is guarded by sys.tables so the proc compiles
--   cleanly in earlier phases where RouteStep / RouteTemplate may not
--   yet exist.
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
--   Tables: Parts.OperationTemplate; optionally Parts.RouteStep,
--           Parts.RouteTemplate (existence-guarded)
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.OperationTemplate_Deprecate
    @Id        BIGINT,
    @AppUserId BIGINT,
    @Status    BIT           OUTPUT,
    @Message   NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.OperationTemplate_Deprecate';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OperationTemplate',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.OperationTemplate WHERE Id = @Id AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'OperationTemplate not found or already deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OperationTemplate',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Dependency check: active RouteStep rows under active RouteTemplates
        DECLARE @DepCount INT = 0;

        IF EXISTS (SELECT 1 FROM sys.tables t INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
                   WHERE s.name = N'Parts' AND t.name = N'RouteStep')
           AND EXISTS (SELECT 1 FROM sys.tables t INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
                       WHERE s.name = N'Parts' AND t.name = N'RouteTemplate')
        BEGIN
            EXEC sp_executesql
                N'SELECT @cnt = COUNT(*)
                  FROM Parts.RouteStep rs
                  INNER JOIN Parts.RouteTemplate rt ON rt.Id = rs.RouteTemplateId
                  WHERE rs.OperationTemplateId = @id AND rt.DeprecatedAt IS NULL;',
                N'@id BIGINT, @cnt INT OUTPUT',
                @id = @Id, @cnt = @DepCount OUTPUT;
            IF @DepCount > 0
            BEGIN
                SET @Message = N'Cannot deprecate: active RouteSteps reference this OperationTemplate.';
                EXEC Audit.Audit_LogFailure
                    @AppUserId = @AppUserId, @LogEntityTypeCode = N'OperationTemplate',
                    @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                    @FailureReason = @Message, @ProcedureName = @ProcName,
                    @AttemptedParameters = @Params;
                RETURN;
            END
        END

        BEGIN TRANSACTION;

        UPDATE Parts.OperationTemplate
        SET DeprecatedAt = SYSUTCDATETIME()
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'OperationTemplate',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Deprecated',
            @LogSeverityCode   = N'Info',
            @Description       = N'OperationTemplate deprecated.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'OperationTemplate deprecated successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OperationTemplate',
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
