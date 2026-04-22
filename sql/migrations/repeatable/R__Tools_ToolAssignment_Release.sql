-- =============================================
-- Procedure:   Tools.ToolAssignment_Release
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Releases the currently-active assignment for a Tool. Sets
--   ReleasedAt and ReleasedByUserId on the single active row (filtered
--   UNIQUE guarantees there's at most one). Elevated action
--   (FDS-04-007). Rejects if the Tool has no active assignment.
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolAssignment_Release
    @ToolId    BIGINT,
    @AppUserId BIGINT,
    @Notes     NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Tools.ToolAssignment_Release';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @ToolId AS ToolId, @Notes AS Notes
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @ToolId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAssignment',
                @EntityId = @ToolId, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @AssignmentId BIGINT, @CellLocationId BIGINT;
        SELECT @AssignmentId = Id, @CellLocationId = CellLocationId
        FROM Tools.ToolAssignment
        WHERE ToolId = @ToolId AND ReleasedAt IS NULL;

        IF @AssignmentId IS NULL
        BEGIN
            SET @Message = N'No active assignment found for this Tool.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAssignment',
                @EntityId = @ToolId, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT @AssignmentId AS AssignmentId, @CellLocationId AS CellLocationId
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Tools.ToolAssignment
        SET ReleasedAt       = SYSUTCDATETIME(),
            ReleasedByUserId = @AppUserId,
            Notes            = ISNULL(@Notes, Notes)
        WHERE Id = @AssignmentId;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'ToolAssignment',
            @EntityId          = @AssignmentId,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'Tool assignment released.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Tool assignment released successfully.';
        SELECT @Status AS Status, @Message AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAssignment',
                @EntityId = @ToolId, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH END CATCH

        SELECT @Status AS Status, @Message AS Message;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
