-- =============================================
-- Procedure:   Location.AppUser_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Creates a new AppUser row. Validates required fields and AdAccount
--   uniqueness (active or deprecated — column has a UNIQUE constraint).
--   Logs success to Audit.ConfigLog or failure to Audit.FailureLog.
--
-- Parameters:
--   @AdAccount NVARCHAR(100)          - AD identity. Required. Must be unique.
--   @DisplayName NVARCHAR(200)        - Display name. Required.
--   @ClockNumber NVARCHAR(20) NULL    - Optional clock number for shop-floor auth.
--   @PinHash NVARCHAR(255) NULL       - Optional hashed PIN.
--   @IgnitionRole NVARCHAR(100) NULL  - Optional Ignition security role.
--   @AppUserId BIGINT                 - User performing the action. Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR), NewId (BIGINT).
--   Status=1 on success, 0 on failure. NewId is NULL on failure.
--
-- Dependencies:
--   Tables: Location.AppUser
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Error Handling:
--   - Validation/business-rule failures: Status=0, Message set, Audit_LogFailure.
--   - CATCH handler: rollback, Status=0, Audit_LogFailure, then RAISERROR.
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Changed to SELECT result for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.AppUser_Create
    @AdAccount    NVARCHAR(100),
    @DisplayName  NVARCHAR(200),
    @ClockNumber  NVARCHAR(20)   = NULL,
    @PinHash      NVARCHAR(255)  = NULL,
    @IgnitionRole NVARCHAR(100)  = NULL,
    @AppUserId    BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Result variables (returned via SELECT instead of OUTPUT)
    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';
    DECLARE @NewId   BIGINT        = NULL;

    -- Capture input for failure-log snapshots
    DECLARE @ProcName NVARCHAR(200) = N'Location.AppUser_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @AdAccount    AS AdAccount,
                @DisplayName  AS DisplayName,
                @ClockNumber  AS ClockNumber,
                @IgnitionRole AS IgnitionRole
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @AdAccount IS NULL OR @DisplayName IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'AppUser',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- ====================
        -- Business rule checks
        -- ====================
        -- AdAccount has a UNIQUE constraint (active or deprecated), so check both
        IF EXISTS (SELECT 1 FROM Location.AppUser WHERE AdAccount = @AdAccount)
        BEGIN
            SET @Message = N'An AppUser with this AdAccount already exists.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'AppUser',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        INSERT INTO Location.AppUser
            (AdAccount, DisplayName, ClockNumber, PinHash, IgnitionRole, CreatedAt)
        VALUES
            (@AdAccount, @DisplayName, @ClockNumber, @PinHash, @IgnitionRole, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        -- Success audit INSIDE the transaction
        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'AppUser',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'AppUser created.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'AppUser created successfully.';
        SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Capture error details BEFORE the nested TRY/CATCH clears the error context
        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);
        SET @NewId   = NULL;

        -- Failure log OUTSIDE the rolled-back transaction
        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'AppUser',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
            -- Swallow; don't mask the original exception
        END CATCH

        -- Return result before re-raising
        SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;

        -- Re-raise so Ignition logs it as a critical exception
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
