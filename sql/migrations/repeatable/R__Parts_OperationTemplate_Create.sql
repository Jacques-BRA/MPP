-- =============================================
-- Procedure:   Parts.OperationTemplate_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Creates a brand-new OperationTemplate at VersionNumber = 1. The
--   (Code, VersionNumber) UNIQUE constraint ensures no conflict with
--   existing families.
--
--   NOTE: To create a subsequent version of an existing template (the
--   clone-to-modify workflow), call Parts.OperationTemplate_CreateNewVersion
--   instead — it copies the parent row and its OperationTemplateField
--   junction rows into a new version atomically.
--
-- Parameters (input):
--   @Code NVARCHAR(20)             - Code for this operation family. Required.
--   @Name NVARCHAR(100)            - Required.
--   @AreaLocationId BIGINT         - FK → Location.Location (Area-tier). Required.
--   @Description NVARCHAR(500) NULL
--   @AppUserId BIGINT              - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--   @NewId BIGINT          - New OperationTemplate.Id on success.
--
-- Dependencies:
--   Tables: Parts.OperationTemplate, Location.Location
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.OperationTemplate_Create
    @Code           NVARCHAR(20),
    @Name           NVARCHAR(100),
    @AreaLocationId BIGINT,
    @Description    NVARCHAR(500)  = NULL,
    @AppUserId      BIGINT,
    @Status         BIT            OUTPUT,
    @Message        NVARCHAR(500)  OUTPUT,
    @NewId          BIGINT         = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';
    SET @NewId   = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Parts.OperationTemplate_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Code AS Code, @Name AS Name,
                @AreaLocationId AS AreaLocationId, @Description AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @Code IS NULL OR @Name IS NULL OR @AreaLocationId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OperationTemplate',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: AreaLocationId must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Location.Location WHERE Id = @AreaLocationId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated AreaLocationId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OperationTemplate',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: no existing family with this Code
        IF EXISTS (SELECT 1 FROM Parts.OperationTemplate WHERE Code = @Code)
        BEGIN
            SET @Message = N'An OperationTemplate with this Code already exists. Use _CreateNewVersion to add a new version of the existing family.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OperationTemplate',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        BEGIN TRANSACTION;

        INSERT INTO Parts.OperationTemplate
            (Code, VersionNumber, Name, AreaLocationId, Description, CreatedAt)
        VALUES
            (@Code, 1, @Name, @AreaLocationId, @Description, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'OperationTemplate',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'OperationTemplate created (v1).',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'OperationTemplate created successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OperationTemplate',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
