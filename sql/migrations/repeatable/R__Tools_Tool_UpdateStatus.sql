-- =============================================
-- Procedure:   Tools.Tool_UpdateStatus
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Transitions a Tool's StatusCodeId (business state: Active,
--   UnderRepair, Scrapped, Retired). Separate from DeprecatedAt
--   (row-lifecycle soft delete) — a Retired Tool can still exist as
--   an active (non-deprecated) row for reporting. Status is resolved
--   by its Code string per FDS-11-011 audit convention.
--
-- Parameters (input):
--   @Id BIGINT                 - PK. Required.
--   @StatusCode NVARCHAR(30)   - Target status code. Required.
--   @AppUserId BIGINT          - Required.
--
-- Result set:
--   Single row: Status, Message.
--
-- Dependencies:
--   Tables: Tools.Tool, Tools.ToolStatusCode
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
-- =============================================
CREATE OR ALTER PROCEDURE Tools.Tool_UpdateStatus
    @Id         BIGINT,
    @StatusCode NVARCHAR(30),
    @AppUserId  BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Tools.Tool_UpdateStatus';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id, @StatusCode AS StatusCode
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Id IS NULL OR @StatusCode IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Tool',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @NewStatusId BIGINT, @OldStatusId BIGINT, @OldStatusCode NVARCHAR(30);

        SELECT @NewStatusId = Id
        FROM Tools.ToolStatusCode
        WHERE Code = @StatusCode;

        IF @NewStatusId IS NULL
        BEGIN
            SET @Message = N'Unknown status code.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Tool',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        SELECT @OldStatusId = t.StatusCodeId, @OldStatusCode = sc.Code
        FROM Tools.Tool t
        INNER JOIN Tools.ToolStatusCode sc ON sc.Id = t.StatusCodeId
        WHERE t.Id = @Id AND t.DeprecatedAt IS NULL;

        IF @OldStatusId IS NULL
        BEGIN
            SET @Message = N'Tool not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Tool',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        IF @OldStatusId = @NewStatusId
        BEGIN
            -- No-op success — avoids noisy audit rows for idempotent calls
            SET @Status  = 1;
            SET @Message = N'Tool already at that status.';
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT @OldStatusCode AS StatusCode
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Tools.Tool
        SET StatusCodeId    = @NewStatusId,
            UpdatedAt       = SYSUTCDATETIME(),
            UpdatedByUserId = @AppUserId
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'Tool',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'Tool status changed.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Tool status updated.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Tool',
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
