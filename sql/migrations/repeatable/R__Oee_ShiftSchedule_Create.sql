-- =============================================
-- Procedure:   Oee.ShiftSchedule_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-15
-- Version:     1.0
--
-- Description:
--   Creates a new shift schedule. Name must be unique.
--   DaysOfWeekBitmask must be 1-127 (Mon=1, Tue=2, Wed=4, Thu=8,
--   Fri=16, Sat=32, Sun=64). Overnight shifts (EndTime <
--   StartTime) are valid.
--
-- Parameters (input):
--   @Name              NVARCHAR(100) - Required. Unique.
--   @Description       NVARCHAR(500) - Optional.
--   @StartTime         TIME(0)       - Required.
--   @EndTime           TIME(0)       - Required.
--   @DaysOfWeekBitmask INT           - Required. 1-127.
--   @EffectiveFrom     DATE          - Required.
--   @AppUserId         BIGINT        - Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR), NewId (BIGINT).
--
-- Dependencies:
--   Tables: Oee.ShiftSchedule
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-15 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Oee.ShiftSchedule_Create
    @Name              NVARCHAR(100),
    @Description       NVARCHAR(500) = NULL,
    @StartTime         TIME(0),
    @EndTime           TIME(0),
    @DaysOfWeekBitmask INT,
    @EffectiveFrom     DATE,
    @AppUserId         BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';
    DECLARE @NewId   BIGINT        = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Oee.ShiftSchedule_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Name AS Name, @Description AS Description,
                @StartTime AS StartTime, @EndTime AS EndTime,
                @DaysOfWeekBitmask AS DaysOfWeekBitmask,
                @EffectiveFrom AS EffectiveFrom
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @Name IS NULL OR LTRIM(RTRIM(@Name)) = N''
           OR @StartTime IS NULL OR @EndTime IS NULL
           OR @DaysOfWeekBitmask IS NULL
           OR @EffectiveFrom IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ShiftSchedule',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        IF @DaysOfWeekBitmask < 1 OR @DaysOfWeekBitmask > 127
        BEGIN
            SET @Message = N'DaysOfWeekBitmask must be between 1 and 127.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ShiftSchedule',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- ====================
        -- Business rule: unique name
        -- ====================
        IF EXISTS (SELECT 1 FROM Oee.ShiftSchedule WHERE Name = LTRIM(RTRIM(@Name)))
        BEGIN
            SET @Message = N'A shift schedule with this Name already exists.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ShiftSchedule',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        INSERT INTO Oee.ShiftSchedule
            (Name, Description, StartTime, EndTime, DaysOfWeekBitmask,
             EffectiveFrom, CreatedAt, CreatedByUserId)
        VALUES
            (LTRIM(RTRIM(@Name)),
             CASE WHEN @Description IS NULL THEN NULL ELSE LTRIM(RTRIM(@Description)) END,
             @StartTime, @EndTime, @DaysOfWeekBitmask,
             @EffectiveFrom, SYSUTCDATETIME(), @AppUserId);

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'ShiftSchedule',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'Shift schedule created.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Shift schedule created successfully.';
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
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'ShiftSchedule',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END
GO
