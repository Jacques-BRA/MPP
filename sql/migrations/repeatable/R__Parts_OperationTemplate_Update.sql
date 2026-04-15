-- =============================================
-- Procedure:   Parts.OperationTemplate_Update
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Updates mutable fields of an active OperationTemplate. Code and
--   VersionNumber are IMMUTABLE — to change either, use
--   OperationTemplate_CreateNewVersion (for VersionNumber) or create
--   a new family via OperationTemplate_Create (for Code).
--
--   Captures OldValue via FOR JSON PATH before the UPDATE and passes
--   both OldValue and NewValue to Audit_LogConfigChange.
--
-- Parameters (input):
--   @Id BIGINT                    - Required.
--   @Name NVARCHAR(100)           - Required.
--   @AreaLocationId BIGINT        - FK → Location.Location. Required.
--   @Description NVARCHAR(500) NULL
--   @AppUserId BIGINT             - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--
-- Dependencies:
--   Tables: Parts.OperationTemplate, Location.Location
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.OperationTemplate_Update
    @Id             BIGINT,
    @Name           NVARCHAR(100),
    @AreaLocationId BIGINT,
    @Description    NVARCHAR(500) = NULL,
    @AppUserId      BIGINT,
    @Status         BIT           OUTPUT,
    @Message        NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.OperationTemplate_Update';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id, @Name AS Name,
                @AreaLocationId AS AreaLocationId, @Description AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @Id IS NULL OR @Name IS NULL OR @AreaLocationId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OperationTemplate',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: target must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.OperationTemplate WHERE Id = @Id AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'OperationTemplate not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'OperationTemplate',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
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
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Capture OldValue for audit BEFORE the UPDATE
        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT Name, AreaLocationId, Description
             FROM Parts.OperationTemplate WHERE Id = @Id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Parts.OperationTemplate
        SET Name           = @Name,
            AreaLocationId = @AreaLocationId,
            Description    = @Description
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'OperationTemplate',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'OperationTemplate updated.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'OperationTemplate updated successfully.';
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
