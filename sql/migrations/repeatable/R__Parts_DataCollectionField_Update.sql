-- =============================================
-- Procedure:   Parts.DataCollectionField_Update
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     1.0
--
-- Description:
--   Updates Name and Description of an existing DataCollectionField. Code is immutable
--   after create. Rejects if row is deprecated.
--
-- Parameters (input):
--   @Id BIGINT                 - PK. Required.
--   @Name NVARCHAR(100)        - Required.
--   @Description NVARCHAR(500) - Optional.
--   @AppUserId BIGINT          - User performing the action. Required for audit.
--
-- Parameters (output):
--   @Status BIT                - 1 on success, 0 on failure.
--   @Message NVARCHAR(500)     - Human-readable status message.
--
-- Dependencies:
--   Tables: Parts.DataCollectionField
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Error Handling:
--   Standard three-tier: validation, business rule, CATCH with RAISERROR.
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.DataCollectionField_Update
    @Id          BIGINT,
    @Name        NVARCHAR(100),
    @Description NVARCHAR(500) = NULL,
    @AppUserId   BIGINT,
    @Status      BIT           OUTPUT,
    @Message     NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.DataCollectionField_Update';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id, @Name AS Name, @Description AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @Id IS NULL OR @Name IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DataCollectionField',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: target must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.DataCollectionField WHERE Id = @Id AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'DataCollectionField not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DataCollectionField',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Capture OldValue for audit BEFORE the UPDATE
        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT Code, Name, Description FROM Parts.DataCollectionField WHERE Id = @Id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Parts.DataCollectionField
        SET Name = @Name, Description = @Description
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'DataCollectionField',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'DataCollectionField updated.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'DataCollectionField updated successfully.';
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
