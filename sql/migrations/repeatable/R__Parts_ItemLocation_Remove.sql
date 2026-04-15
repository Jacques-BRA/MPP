-- =============================================
-- Procedure:   Parts.ItemLocation_Remove
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Soft-deletes the ACTIVE eligibility pairing for a given
--   (ItemId, LocationId) by setting DeprecatedAt = SYSUTCDATETIME().
--   If no active pairing exists (either never registered or already
--   deprecated), returns @Status = 0 with a friendly message.
--
-- Parameters (input):
--   @ItemId BIGINT     - Required.
--   @LocationId BIGINT - Required.
--   @AppUserId BIGINT  - User performing the action. Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--
-- Dependencies:
--   Tables: Parts.ItemLocation
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Error Handling:
--   Standard three-tier: validation, business rule, CATCH with RAISERROR.
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.ItemLocation_Remove
    @ItemId     BIGINT,
    @LocationId BIGINT,
    @AppUserId  BIGINT,
    @Status     BIT            OUTPUT,
    @Message    NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.ItemLocation_Remove';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @ItemId AS ItemId, @LocationId AS LocationId
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @ItemId IS NULL OR @LocationId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
                @EntityId = NULL, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Look up the active pairing (if any) by (ItemId, LocationId)
        DECLARE @ExistingId BIGINT = NULL;

        SELECT TOP 1 @ExistingId = Id
        FROM Parts.ItemLocation
        WHERE ItemId = @ItemId
          AND LocationId = @LocationId
          AND DeprecatedAt IS NULL;

        -- Business rule: active pairing must exist
        IF @ExistingId IS NULL
        BEGIN
            SET @Message = N'No active ItemLocation pairing exists for this Item and Location.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
                @EntityId = NULL, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        BEGIN TRANSACTION;

        UPDATE Parts.ItemLocation
        SET DeprecatedAt = SYSUTCDATETIME()
        WHERE Id = @ExistingId;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'ItemLocation',
            @EntityId          = @ExistingId,
            @LogEventTypeCode  = N'Deprecated',
            @LogSeverityCode   = N'Info',
            @Description       = N'ItemLocation deprecated.',
            @OldValue          = @Params,
            @NewValue          = NULL;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'ItemLocation removed successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
                @EntityId = NULL, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
