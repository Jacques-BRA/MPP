-- =============================================
-- Procedure:   Tools.ToolAttribute_Remove
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Hard-deletes a specific ToolAttribute row. No soft delete —
--   attribute values are either set or absent; clearing an attribute
--   means removing the row. Idempotent: no-op success if the row
--   doesn't exist.
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolAttribute_Remove
    @ToolId                    BIGINT,
    @ToolAttributeDefinitionId BIGINT,
    @AppUserId                 BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Tools.ToolAttribute_Remove';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @ToolId AS ToolId, @ToolAttributeDefinitionId AS ToolAttributeDefinitionId
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @ToolId IS NULL OR @ToolAttributeDefinitionId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttribute',
                @EntityId = @ToolId, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @OldValue NVARCHAR(500);
        SELECT @OldValue = Value
        FROM Tools.ToolAttribute
        WHERE ToolId = @ToolId AND ToolAttributeDefinitionId = @ToolAttributeDefinitionId;

        IF @OldValue IS NULL
        BEGIN
            SET @Status  = 1;
            SET @Message = N'No attribute value to remove (idempotent).';
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @OldJson NVARCHAR(MAX) =
            (SELECT @OldValue AS Value FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        DELETE FROM Tools.ToolAttribute
        WHERE ToolId = @ToolId AND ToolAttributeDefinitionId = @ToolAttributeDefinitionId;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'ToolAttribute',
            @EntityId          = @ToolId,
            @LogEventTypeCode  = N'Deprecated',
            @LogSeverityCode   = N'Info',
            @Description       = N'ToolAttribute removed.',
            @OldValue          = @OldJson,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'ToolAttribute removed successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttribute',
                @EntityId = @ToolId, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH END CATCH

        SELECT @Status AS Status, @Message AS Message;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
