-- =============================================
-- Procedure:   Parts.ItemLocation_Add
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Registers an eligibility pairing (this Item can run on this Location).
--   Idempotent and safe to call from an Eligibility Map Editor checkbox:
--     - If an ACTIVE pairing already exists: no-op, returns success.
--     - If a DEPRECATED pairing exists for this (Item, Location): re-activates
--       it by clearing DeprecatedAt.
--     - Otherwise: inserts a new row.
--
-- Parameters (input):
--   @ItemId BIGINT     - Required.
--   @LocationId BIGINT - Required.
--   @AppUserId BIGINT  - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--   @NewId BIGINT          - Row Id (new or re-activated). NULL if no-op on already-active.
--
-- Dependencies:
--   Tables: Parts.ItemLocation, Parts.Item, Location.Location
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.ItemLocation_Add
    @ItemId     BIGINT,
    @LocationId BIGINT,
    @AppUserId  BIGINT,
    @Status     BIT            OUTPUT,
    @Message    NVARCHAR(500)  OUTPUT,
    @NewId      BIGINT         = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';
    SET @NewId   = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Parts.ItemLocation_Add';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @ItemId AS ItemId, @LocationId AS LocationId
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @ItemId IS NULL OR @LocationId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Parts.Item WHERE Id = @ItemId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated ItemId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Location.Location WHERE Id = @LocationId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated LocationId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Decide whether to no-op, reactivate, or insert
        DECLARE @ExistingId BIGINT = NULL;
        DECLARE @ExistingDeprecatedAt DATETIME2(3) = NULL;

        SELECT TOP 1
            @ExistingId = Id,
            @ExistingDeprecatedAt = DeprecatedAt
        FROM Parts.ItemLocation
        WHERE ItemId = @ItemId AND LocationId = @LocationId;

        BEGIN TRANSACTION;

        IF @ExistingId IS NOT NULL AND @ExistingDeprecatedAt IS NULL
        BEGIN
            -- Already active — no-op
            SET @NewId = @ExistingId;
            COMMIT TRANSACTION;
            SET @Status  = 1;
            SET @Message = N'ItemLocation already active (no-op).';
            RETURN;
        END
        ELSE IF @ExistingId IS NOT NULL AND @ExistingDeprecatedAt IS NOT NULL
        BEGIN
            -- Reactivate
            UPDATE Parts.ItemLocation
            SET DeprecatedAt = NULL
            WHERE Id = @ExistingId;

            SET @NewId = @ExistingId;

            EXEC Audit.Audit_LogConfigChange
                @AppUserId         = @AppUserId,
                @LogEntityTypeCode = N'ItemLocation',
                @EntityId          = @ExistingId,
                @LogEventTypeCode  = N'Created',
                @LogSeverityCode   = N'Info',
                @Description       = N'ItemLocation reactivated.',
                @OldValue          = NULL,
                @NewValue          = @Params;
        END
        ELSE
        BEGIN
            -- Insert new
            INSERT INTO Parts.ItemLocation (ItemId, LocationId, CreatedAt)
            VALUES (@ItemId, @LocationId, SYSUTCDATETIME());

            SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

            EXEC Audit.Audit_LogConfigChange
                @AppUserId         = @AppUserId,
                @LogEntityTypeCode = N'ItemLocation',
                @EntityId          = @NewId,
                @LogEventTypeCode  = N'Created',
                @LogSeverityCode   = N'Info',
                @Description       = N'ItemLocation created.',
                @OldValue          = NULL,
                @NewValue          = @Params;
        END

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'ItemLocation added successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
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
