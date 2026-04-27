-- =============================================
-- Procedure:   Tools.ToolAttributeDefinition_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Creates a new attribute definition for a given ToolType. Enforces
--   DataType ∈ { String, Integer, Decimal, Boolean, Date }, Code unique
--   among active rows for the same ToolTypeId (filtered UNIQUE).
--   Auto-assigns SortOrder.
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolAttributeDefinition_Create
    @ToolTypeId  BIGINT,
    @Code        NVARCHAR(50),
    @Name        NVARCHAR(100),
    @DataType    NVARCHAR(20),
    @IsRequired  BIT           = 0,
    @AppUserId   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';
    DECLARE @NewId   BIGINT        = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Tools.ToolAttributeDefinition_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @ToolTypeId AS ToolTypeId, @Code AS Code, @Name AS Name,
                @DataType AS DataType, @IsRequired AS IsRequired
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @ToolTypeId IS NULL OR @Code IS NULL OR @Name IS NULL
           OR @DataType IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttributeDefinition',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        IF @DataType NOT IN (N'String', N'Integer', N'Decimal', N'Boolean', N'Date')
        BEGIN
            SET @Message = N'Invalid DataType. Must be String, Integer, Decimal, Boolean, or Date.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttributeDefinition',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tools.ToolType WHERE Id = @ToolTypeId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated ToolTypeId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttributeDefinition',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tools.ToolAttributeDefinition
                   WHERE ToolTypeId = @ToolTypeId AND Code = @Code AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'An active attribute definition with this Code already exists for this ToolType.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttributeDefinition',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        DECLARE @NextSort INT;
        SELECT @NextSort = ISNULL(MAX(SortOrder), 0) + 1
        FROM Tools.ToolAttributeDefinition
        WHERE ToolTypeId = @ToolTypeId AND DeprecatedAt IS NULL;

        BEGIN TRANSACTION;

        INSERT INTO Tools.ToolAttributeDefinition
            (ToolTypeId, Code, Name, DataType, IsRequired, SortOrder, CreatedAt)
        VALUES
            (@ToolTypeId, @Code, @Name, @DataType, @IsRequired, @NextSort, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'ToolAttributeDefinition',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'ToolAttributeDefinition created.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'ToolAttributeDefinition created successfully.';
        SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);
        SET @NewId   = NULL;

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ToolAttributeDefinition',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH END CATCH

        SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
