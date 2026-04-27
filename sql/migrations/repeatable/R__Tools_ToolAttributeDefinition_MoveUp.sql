-- =============================================
-- Procedure:   Tools.ToolAttributeDefinition_MoveUp
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
--
-- Description:
--   Swap SortOrder with the nearest active sibling above within the
--   same ToolTypeId scope. No-op if already at the top.
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolAttributeDefinition_MoveUp
    @Id        BIGINT,
    @AppUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Tools.ToolAttributeDefinition_MoveUp';
    DECLARE @Params   NVARCHAR(MAX) = (SELECT @Id AS Id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttributeDefinition',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @CurrentSort INT, @ToolTypeId BIGINT;
        SELECT @CurrentSort = SortOrder, @ToolTypeId = ToolTypeId
        FROM Tools.ToolAttributeDefinition
        WHERE Id = @Id AND DeprecatedAt IS NULL;

        IF @CurrentSort IS NULL
        BEGIN
            SET @Message = N'ToolAttributeDefinition not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttributeDefinition',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @SwapId BIGINT, @SwapSort INT;
        SELECT TOP 1 @SwapId = Id, @SwapSort = SortOrder
        FROM Tools.ToolAttributeDefinition
        WHERE ToolTypeId = @ToolTypeId
          AND DeprecatedAt IS NULL
          AND SortOrder < @CurrentSort
        ORDER BY SortOrder DESC;

        IF @SwapId IS NULL
        BEGIN
            SET @Status  = 1;
            SET @Message = N'Already at the top position.';
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        BEGIN TRANSACTION;
        UPDATE Tools.ToolAttributeDefinition SET SortOrder = @SwapSort    WHERE Id = @Id;
        UPDATE Tools.ToolAttributeDefinition SET SortOrder = @CurrentSort WHERE Id = @SwapId;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttributeDefinition',
            @EntityId = @Id, @LogEventTypeCode = N'Updated',
            @LogSeverityCode = N'Info',
            @Description = N'ToolAttributeDefinition moved up.',
            @OldValue = NULL, @NewValue = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'ToolAttributeDefinition moved up successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttributeDefinition',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH END CATCH

        SELECT @Status AS Status, @Message AS Message;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
