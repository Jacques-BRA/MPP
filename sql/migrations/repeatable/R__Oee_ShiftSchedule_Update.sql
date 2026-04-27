-- =============================================
-- Procedure:   Oee.ShiftSchedule_Update
-- Author:      Blue Ridge Automation
-- Created:     2026-04-15
-- Version:     1.0
--
-- Description:
--   Updates an existing shift schedule. All mutable fields
--   (Name, Description, StartTime, EndTime, DaysOfWeekBitmask,
--   EffectiveFrom) are updatable. Name uniqueness is enforced
--   excluding self. Rejects if target is deprecated.
--
-- Parameters (input):
--   @Id                BIGINT        - Required.
--   @Name              NVARCHAR(100) - Required.
--   @Description       NVARCHAR(500) - Optional.
--   @StartTime         TIME(0)       - Required.
--   @EndTime           TIME(0)       - Required.
--   @DaysOfWeekBitmask INT           - Required. 1-127.
--   @EffectiveFrom     DATE          - Required.
--   @AppUserId         BIGINT        - Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR).
--
-- Dependencies:
--   Tables: Oee.ShiftSchedule
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-15 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Oee.ShiftSchedule_Update
    @Id                BIGINT,
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

    DECLARE @ProcName NVARCHAR(200) = N'Oee.ShiftSchedule_Update';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id, @Name AS Name, @Description AS Description,
                @StartTime AS StartTime, @EndTime AS EndTime,
                @DaysOfWeekBitmask AS DaysOfWeekBitmask,
                @EffectiveFrom AS EffectiveFrom
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @Id IS NULL
           OR @Name IS NULL OR LTRIM(RTRIM(@Name)) = N''
           OR @StartTime IS NULL OR @EndTime IS NULL
           OR @DaysOfWeekBitmask IS NULL
           OR @EffectiveFrom IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ShiftSchedule',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        IF @DaysOfWeekBitmask < 1 OR @DaysOfWeekBitmask > 127
        BEGIN
            SET @Message = N'DaysOfWeekBitmask must be between 1 and 127.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ShiftSchedule',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Existence checks
        -- ====================
        DECLARE @OldName      NVARCHAR(100);
        DECLARE @OldDesc      NVARCHAR(500);
        DECLARE @OldStart     TIME(0);
        DECLARE @OldEnd       TIME(0);
        DECLARE @OldBitmask   INT;
        DECLARE @OldEffective DATE;
        DECLARE @DeprecatedAt DATETIME2(3);
        DECLARE @RowExists    BIT = 0;

        SELECT @OldName      = Name,
               @OldDesc      = Description,
               @OldStart     = StartTime,
               @OldEnd       = EndTime,
               @OldBitmask   = DaysOfWeekBitmask,
               @OldEffective = EffectiveFrom,
               @DeprecatedAt = DeprecatedAt,
               @RowExists    = 1
        FROM Oee.ShiftSchedule WHERE Id = @Id;

        IF @RowExists = 0
        BEGIN
            SET @Message = N'Shift schedule not found.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ShiftSchedule',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        IF @DeprecatedAt IS NOT NULL
        BEGIN
            SET @Message = N'Cannot update a deprecated shift schedule.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ShiftSchedule',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Business rule: unique name (excluding self)
        -- ====================
        IF EXISTS (SELECT 1 FROM Oee.ShiftSchedule
                   WHERE Name = LTRIM(RTRIM(@Name)) AND Id <> @Id)
        BEGIN
            SET @Message = N'Another shift schedule with this Name already exists.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ShiftSchedule',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Build old/new JSON
        -- ====================
        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT @OldName AS Name, @OldDesc AS Description,
                    @OldStart AS StartTime, @OldEnd AS EndTime,
                    @OldBitmask AS DaysOfWeekBitmask,
                    @OldEffective AS EffectiveFrom
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        UPDATE Oee.ShiftSchedule SET
            Name              = LTRIM(RTRIM(@Name)),
            Description       = CASE WHEN @Description IS NULL THEN NULL ELSE LTRIM(RTRIM(@Description)) END,
            StartTime         = @StartTime,
            EndTime           = @EndTime,
            DaysOfWeekBitmask = @DaysOfWeekBitmask,
            EffectiveFrom     = @EffectiveFrom,
            UpdatedAt         = SYSUTCDATETIME(),
            UpdatedByUserId   = @AppUserId
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'ShiftSchedule',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'Shift schedule updated.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Shift schedule updated successfully.';
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
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'ShiftSchedule',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        SELECT @Status AS Status, @Message AS Message;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END
GO
