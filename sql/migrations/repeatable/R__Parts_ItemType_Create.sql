-- =============================================
-- Procedure:   Parts.ItemType_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     1.0
--
-- Description:
--   Creates a new ItemType row. Validates required fields and Code uniqueness
--   (against active rows; deprecated Codes may be re-used).
--   Logs success to Audit.ConfigLog or failure to Audit.FailureLog.
--
-- Parameters (input):
--   @Code NVARCHAR(30)         - Unique code. Required.
--   @Name NVARCHAR(100)        - Display name. Required.
--   @Description NVARCHAR(500) - Optional description.
--   @AppUserId BIGINT          - User performing the action. Required for audit.
--
-- Parameters (output):
--   @Status BIT                - 1 on success, 0 on failure.
--   @Message NVARCHAR(500)     - Human-readable status message.
--   @NewId BIGINT              - New ItemType.Id on success, NULL on failure.
--
-- Dependencies:
--   Tables: Parts.ItemType
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Error Handling:
--   - Validation/business-rule failures: @Status=0, @Message set, Audit_LogFailure, RETURN.
--   - CATCH handler: rollback, @Status=0, @Message captured, Audit_LogFailure, RAISERROR.
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.ItemType_Create
    @Code        NVARCHAR(30),
    @Name        NVARCHAR(100),
    @Description NVARCHAR(500)  = NULL,
    @AppUserId   BIGINT,
    @Status      BIT            OUTPUT,
    @Message     NVARCHAR(500)  OUTPUT,
    @NewId       BIGINT         = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';
    SET @NewId   = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Parts.ItemType_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Code AS Code, @Name AS Name, @Description AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @Code IS NULL OR @Name IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'ItemType',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: Code unique among active rows
        IF EXISTS (SELECT 1 FROM Parts.ItemType WHERE Code = @Code AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'An ItemType with this Code already exists.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'ItemType',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        BEGIN TRANSACTION;

        INSERT INTO Parts.ItemType (Code, Name, Description, CreatedAt)
        VALUES (@Code, @Name, @Description, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'ItemType',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'ItemType created.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'ItemType created successfully.';
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
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'ItemType',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
            -- Swallow; don't mask the original exception
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
