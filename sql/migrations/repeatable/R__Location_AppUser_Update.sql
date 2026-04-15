-- =============================================
-- Procedure:   Location.AppUser_Update
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Updates mutable fields on an existing AppUser: DisplayName, ClockNumber,
--   IgnitionRole. Does NOT update AdAccount (immutable), PinHash (separate
--   proc: AppUser_SetPin), or DeprecatedAt (separate proc: AppUser_Deprecate).
--   Captures old/new values as JSON for audit diff.
--
-- Parameters:
--   @Id BIGINT                        - PK of the AppUser to update. Required.
--   @DisplayName NVARCHAR(200)        - New display name. Required.
--   @ClockNumber NVARCHAR(20) NULL    - New clock number (NULL to clear).
--   @IgnitionRole NVARCHAR(100) NULL  - New Ignition role (NULL to clear).
--   @AppUserId BIGINT                 - User performing the action. Required for audit.
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
CREATE OR ALTER PROCEDURE Location.AppUser_Update
    @Id           BIGINT,
    @DisplayName  NVARCHAR(200),
    @ClockNumber  NVARCHAR(20)   = NULL,
    @IgnitionRole NVARCHAR(100)  = NULL,
    @AppUserId    BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Result variables (returned via SELECT instead of OUTPUT)
    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    -- Capture input for failure-log snapshots
    DECLARE @ProcName NVARCHAR(200) = N'Location.AppUser_Update';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id           AS Id,
                @DisplayName  AS DisplayName,
                @ClockNumber  AS ClockNumber,
                @IgnitionRole AS IgnitionRole
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @Id IS NULL OR @DisplayName IS NULL OR @AppUserId IS NULL
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
        -- Capture old values for audit diff
        -- ====================
        DECLARE @OldValue NVARCHAR(MAX);
        SELECT @OldValue =
            (SELECT DisplayName,
                    ClockNumber,
                    IgnitionRole
             FROM Location.AppUser
             WHERE Id = @Id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        DECLARE @NewValue NVARCHAR(MAX) =
            (SELECT @DisplayName  AS DisplayName,
                    @ClockNumber  AS ClockNumber,
                    @IgnitionRole AS IgnitionRole
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        UPDATE Location.AppUser
        SET DisplayName  = @DisplayName,
            ClockNumber  = @ClockNumber,
            IgnitionRole = @IgnitionRole
        WHERE Id = @Id;

        -- Success audit INSIDE the transaction
        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'AppUser',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'AppUser updated.',
            @OldValue          = @OldValue,
            @NewValue          = @NewValue;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'AppUser updated successfully.';
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
