-- =============================================
-- Procedure:   Parts.ItemLocation_SetConsumptionMetadata
-- Author:      Blue Ridge Automation
-- Created:     2026-04-23
-- Version:     1.0
--
-- Description:
--   Sets the consumption metadata (MinQuantity, MaxQuantity,
--   DefaultQuantity, IsConsumptionPoint) on an active ItemLocation
--   row. These columns were added in migration 0010 to mirror the
--   legacy Flexware "Compatible work cells" consumption fields
--   (OI-18, Phase E of the 2026-04-20 refactor).
--
--   This proc exists as a companion to ItemLocation_Add so metadata
--   can be edited after the eligibility pairing is established.
--   Add writes metadata only on INSERT and leaves it alone on
--   reactivation, so SetConsumptionMetadata is the single path for
--   changing values on an existing row.
--
--   Pass NULL for any quantity field to clear it. Pass 0 or 1 for
--   @IsConsumptionPoint to set it explicitly (no tri-state — the
--   column is NOT NULL DEFAULT 0).
--
-- Parameters (input):
--   @Id BIGINT                    - ItemLocation.Id. Required.
--   @MinQuantity INT NULL         - Cleared when NULL.
--   @MaxQuantity INT NULL         - Cleared when NULL.
--   @DefaultQuantity INT NULL     - Cleared when NULL.
--   @IsConsumptionPoint BIT       - Required. 0 or 1.
--   @AppUserId BIGINT             - Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR).
--   Status=1 on success, 0 on failure.
--
-- Dependencies:
--   Tables: Parts.ItemLocation
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-23 - 1.0 - Initial version (Phase G.3, OI-18)
-- =============================================
CREATE OR ALTER PROCEDURE Parts.ItemLocation_SetConsumptionMetadata
    @Id                 BIGINT,
    @MinQuantity        INT    = NULL,
    @MaxQuantity        INT    = NULL,
    @DefaultQuantity    INT    = NULL,
    @IsConsumptionPoint BIT,
    @AppUserId          BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.ItemLocation_SetConsumptionMetadata';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id, @MinQuantity AS MinQuantity,
                @MaxQuantity AS MaxQuantity, @DefaultQuantity AS DefaultQuantity,
                @IsConsumptionPoint AS IsConsumptionPoint
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @Id IS NULL OR @IsConsumptionPoint IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Business rule: target must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.ItemLocation
                       WHERE Id = @Id AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'ItemLocation not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Consumption metadata sanity: non-negative; Min <= Max when both supplied
        IF (@MinQuantity IS NOT NULL AND @MinQuantity < 0)
           OR (@MaxQuantity IS NOT NULL AND @MaxQuantity < 0)
           OR (@DefaultQuantity IS NOT NULL AND @DefaultQuantity < 0)
        BEGIN
            SET @Message = N'Consumption quantities must be non-negative.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        IF @MinQuantity IS NOT NULL AND @MaxQuantity IS NOT NULL AND @MinQuantity > @MaxQuantity
        BEGIN
            SET @Message = N'MinQuantity cannot exceed MaxQuantity.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Capture OldValue before UPDATE
        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT MinQuantity, MaxQuantity, DefaultQuantity, IsConsumptionPoint
             FROM Parts.ItemLocation WHERE Id = @Id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Parts.ItemLocation
        SET MinQuantity        = @MinQuantity,
            MaxQuantity        = @MaxQuantity,
            DefaultQuantity    = @DefaultQuantity,
            IsConsumptionPoint = @IsConsumptionPoint
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'ItemLocation',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'ItemLocation consumption metadata updated.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'ItemLocation consumption metadata updated successfully.';
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

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ItemLocation',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        SELECT @Status AS Status, @Message AS Message;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
