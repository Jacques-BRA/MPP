-- =============================================
-- Procedure:   Parts.OperationTemplateField_Add
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Adds a DataCollectionField to an OperationTemplate by inserting
--   an OperationTemplateField junction row. Validates both FKs are
--   active, rejects if the OperationTemplate is deprecated, and
--   rejects duplicate ACTIVE pairings gracefully before the filtered
--   unique index fires.
--
-- Parameters (input):
--   @OperationTemplateId   BIGINT - FK → Parts.OperationTemplate. Required.
--   @DataCollectionFieldId BIGINT - FK → Parts.DataCollectionField. Required.
--   @IsRequired            BIT    = 1
--   @AppUserId             BIGINT - Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR), NewId (BIGINT).
--   Status=1 on success, 0 on failure. NewId is NULL on failure.
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-15 - 2.0 - SELECT result for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.OperationTemplateField_Add
    @OperationTemplateId   BIGINT,
    @DataCollectionFieldId BIGINT,
    @IsRequired            BIT           = 1,
    @AppUserId             BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';
    DECLARE @NewId   BIGINT        = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Parts.OperationTemplateField_Add';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @OperationTemplateId   AS OperationTemplateId,
                @DataCollectionFieldId AS DataCollectionFieldId,
                @IsRequired            AS IsRequired
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @OperationTemplateId IS NULL OR @DataCollectionFieldId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OpTemplateField',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- Business rule: OperationTemplate must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.OperationTemplate
                       WHERE Id = @OperationTemplateId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated OperationTemplateId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OpTemplateField',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- Business rule: DataCollectionField must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.DataCollectionField
                       WHERE Id = @DataCollectionFieldId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated DataCollectionFieldId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OpTemplateField',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- Business rule: no active duplicate pairing (catch before unique index)
        IF EXISTS (SELECT 1 FROM Parts.OperationTemplateField
                   WHERE OperationTemplateId   = @OperationTemplateId
                     AND DataCollectionFieldId = @DataCollectionFieldId
                     AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'This DataCollectionField is already active on the OperationTemplate.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OpTemplateField',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        BEGIN TRANSACTION;

        INSERT INTO Parts.OperationTemplateField
            (OperationTemplateId, DataCollectionFieldId, IsRequired, CreatedAt)
        VALUES
            (@OperationTemplateId, @DataCollectionFieldId, @IsRequired, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'OpTemplateField',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'OperationTemplateField added.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'OperationTemplateField added successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OpTemplateField',
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
