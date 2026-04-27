-- =============================================
-- Procedure:   Oee.DowntimeReasonCode_Update
-- Author:      Blue Ridge Automation
-- Created:     2026-04-15
-- Version:     1.0
--
-- Description:
--   Updates an existing downtime reason code. Code is immutable
--   (deprecate + create new to change it). Updates Description,
--   AreaLocationId, DowntimeReasonTypeId, DowntimeSourceCodeId,
--   and IsExcused. Rejects if target row is deprecated.
--
-- Parameters (input):
--   @Id                   BIGINT        - Required.
--   @Description          NVARCHAR(500) - Required.
--   @AreaLocationId       BIGINT        - Required. Active Location.
--   @DowntimeReasonTypeId BIGINT NULL   - Optional.
--   @DowntimeSourceCodeId BIGINT NULL   - Optional.
--   @IsExcused            BIT           - Required.
--   @AppUserId            BIGINT        - Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR).
--
-- Dependencies:
--   Tables: Oee.DowntimeReasonCode, Location.Location,
--           Oee.DowntimeReasonType, Oee.DowntimeSourceCode
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-15 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Oee.DowntimeReasonCode_Update
    @Id                   BIGINT,
    @Description          NVARCHAR(500),
    @AreaLocationId       BIGINT,
    @DowntimeReasonTypeId BIGINT = NULL,
    @DowntimeSourceCodeId BIGINT = NULL,
    @IsExcused            BIT,
    @AppUserId            BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Oee.DowntimeReasonCode_Update';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id, @Description AS Description,
                @AreaLocationId AS AreaLocationId,
                @DowntimeReasonTypeId AS DowntimeReasonTypeId,
                @DowntimeSourceCodeId AS DowntimeSourceCodeId,
                @IsExcused AS IsExcused
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @Id IS NULL OR @Description IS NULL OR LTRIM(RTRIM(@Description)) = N''
           OR @AreaLocationId IS NULL OR @IsExcused IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DowntimeReasonCode',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Existence checks
        -- ====================
        DECLARE @OldDesc         NVARCHAR(500);
        DECLARE @OldAreaId       BIGINT;
        DECLARE @OldTypeId       BIGINT;
        DECLARE @OldSourceId     BIGINT;
        DECLARE @OldIsExcused    BIT;
        DECLARE @DeprecatedAt    DATETIME2(3);
        DECLARE @RowExists       BIT = 0;

        SELECT @OldDesc      = Description,
               @OldAreaId    = AreaLocationId,
               @OldTypeId    = DowntimeReasonTypeId,
               @OldSourceId  = DowntimeSourceCodeId,
               @OldIsExcused = IsExcused,
               @DeprecatedAt = DeprecatedAt,
               @RowExists    = 1
        FROM Oee.DowntimeReasonCode WHERE Id = @Id;

        IF @RowExists = 0
        BEGIN
            SET @Message = N'Downtime reason code not found.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DowntimeReasonCode',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        IF @DeprecatedAt IS NOT NULL
        BEGIN
            SET @Message = N'Cannot update a deprecated downtime reason code.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DowntimeReasonCode',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- FK existence checks
        -- ====================
        IF NOT EXISTS (SELECT 1 FROM Location.Location WHERE Id = @AreaLocationId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated AreaLocationId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DowntimeReasonCode',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        IF @DowntimeReasonTypeId IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM Oee.DowntimeReasonType WHERE Id = @DowntimeReasonTypeId)
        BEGIN
            SET @Message = N'Invalid DowntimeReasonTypeId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DowntimeReasonCode',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        IF @DowntimeSourceCodeId IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM Oee.DowntimeSourceCode WHERE Id = @DowntimeSourceCodeId)
        BEGIN
            SET @Message = N'Invalid DowntimeSourceCodeId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DowntimeReasonCode',
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
            (SELECT @OldDesc AS Description,
                    @OldAreaId AS AreaLocationId,
                    @OldTypeId AS DowntimeReasonTypeId,
                    @OldSourceId AS DowntimeSourceCodeId,
                    @OldIsExcused AS IsExcused
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        UPDATE Oee.DowntimeReasonCode SET
            Description          = LTRIM(RTRIM(@Description)),
            AreaLocationId       = @AreaLocationId,
            DowntimeReasonTypeId = @DowntimeReasonTypeId,
            DowntimeSourceCodeId = @DowntimeSourceCodeId,
            IsExcused            = @IsExcused,
            UpdatedAt            = SYSUTCDATETIME(),
            UpdatedByUserId      = @AppUserId
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'DowntimeReasonCode',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'Downtime reason code updated.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Downtime reason code updated successfully.';
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
                @LogEntityTypeCode   = N'DowntimeReasonCode',
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
