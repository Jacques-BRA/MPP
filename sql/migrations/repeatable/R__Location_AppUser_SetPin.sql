-- =============================================
-- Procedure:   Location.AppUser_SetPin
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Sets (or replaces) the PinHash for an existing AppUser. Audit values
--   are redacted — PIN hashes are never written to audit logs.
--
-- Parameters:
--   @Id BIGINT              - PK of the AppUser. Required.
--   @PinHash NVARCHAR(255)  - New hashed PIN value. Required.
--   @AppUserId BIGINT       - User performing the action. Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR).
--   Status=1 on success, 0 on failure.
--
-- Dependencies:
--   Tables: Location.AppUser
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Error Handling:
--   - Validation/business-rule failures: @Status=0, @Message set, Audit_LogFailure, RETURN.
--   - CATCH handler: rollback, @Status=0, @Message captured, Audit_LogFailure, THROW.
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-15 - 2.0 - SELECT result for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.AppUser_SetPin
    @Id        BIGINT,
    @PinHash   NVARCHAR(255),
    @AppUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Result variables (returned via SELECT instead of OUTPUT)
    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    -- Capture input for failure-log snapshots (PinHash excluded — never log secrets)
    DECLARE @ProcName NVARCHAR(200) = N'Location.AppUser_SetPin';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @Id IS NULL OR @PinHash IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'AppUser',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Target must exist and not be deprecated
        IF NOT EXISTS (SELECT 1 FROM Location.AppUser WHERE Id = @Id AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'AppUser not found or is deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'AppUser',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        UPDATE Location.AppUser
        SET PinHash = @PinHash
        WHERE Id = @Id;

        -- Success audit INSIDE the transaction — values REDACTED for security
        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'AppUser',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'AppUser PIN updated.',
            @OldValue          = N'[REDACTED]',
            @NewValue          = N'[REDACTED]';

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'AppUser PIN updated successfully.';
        SELECT @Status AS Status, @Message AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);

        -- Failure log OUTSIDE the rolled-back transaction
        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'AppUser',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
            -- Swallow; don't mask the original exception
        END CATCH

        SELECT @Status AS Status, @Message AS Message;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
