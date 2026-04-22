-- =============================================
-- Procedure:   Tools.ToolAttribute_Upsert
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Upserts an attribute value on a Tool. Inserts if no row exists
--   for (ToolId, ToolAttributeDefinitionId); otherwise updates Value.
--   Validates that the AttributeDefinition belongs to the Tool's
--   ToolType (polymorphic integrity).
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolAttribute_Upsert
    @ToolId                    BIGINT,
    @ToolAttributeDefinitionId BIGINT,
    @Value                     NVARCHAR(500),
    @AppUserId                 BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Tools.ToolAttribute_Upsert';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @ToolId AS ToolId,
                @ToolAttributeDefinitionId AS ToolAttributeDefinitionId,
                @Value AS Value
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @ToolId IS NULL OR @ToolAttributeDefinitionId IS NULL
           OR @Value IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttribute',
                @EntityId = NULL, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Validate Tool exists and get its ToolTypeId
        DECLARE @ToolTypeId BIGINT;
        SELECT @ToolTypeId = ToolTypeId
        FROM Tools.Tool
        WHERE Id = @ToolId AND DeprecatedAt IS NULL;

        IF @ToolTypeId IS NULL
        BEGIN
            SET @Message = N'Tool not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttribute',
                @EntityId = @ToolId, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Validate AttributeDefinition belongs to the Tool's ToolType
        IF NOT EXISTS (SELECT 1 FROM Tools.ToolAttributeDefinition
                       WHERE Id = @ToolAttributeDefinitionId
                         AND ToolTypeId = @ToolTypeId
                         AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Attribute definition does not belong to this Tool''s ToolType, or is deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttribute',
                @EntityId = @ToolId, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @OldValue NVARCHAR(500), @ExistingId BIGINT;
        SELECT @ExistingId = Id, @OldValue = Value
        FROM Tools.ToolAttribute
        WHERE ToolId = @ToolId AND ToolAttributeDefinitionId = @ToolAttributeDefinitionId;

        BEGIN TRANSACTION;

        IF @ExistingId IS NULL
        BEGIN
            INSERT INTO Tools.ToolAttribute
                (ToolId, ToolAttributeDefinitionId, Value, UpdatedAt, UpdatedByUserId)
            VALUES
                (@ToolId, @ToolAttributeDefinitionId, @Value, SYSUTCDATETIME(), @AppUserId);
        END
        ELSE
        BEGIN
            UPDATE Tools.ToolAttribute
            SET Value           = @Value,
                UpdatedAt       = SYSUTCDATETIME(),
                UpdatedByUserId = @AppUserId
            WHERE Id = @ExistingId;
        END

        DECLARE @OldJson NVARCHAR(MAX) =
            (SELECT @OldValue AS Value FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'ToolAttribute',
            @EntityId          = @ToolId,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'ToolAttribute upserted.',
            @OldValue          = @OldJson,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'ToolAttribute upserted successfully.';
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
