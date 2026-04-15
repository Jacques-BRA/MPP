-- =============================================
-- Procedure:   Location.LocationAttributeDefinition_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Creates a new LocationAttributeDefinition row under the specified
--   LocationTypeDefinition. Auto-assigns SortOrder as MAX(active siblings)+1.
--   Validates LocationTypeDefinitionId FK exists and is not deprecated.
--   Logs success to Audit.ConfigLog or failure to Audit.FailureLog.
--
-- Parameters:
--   @LocationTypeDefinitionId BIGINT      - FK to LocationTypeDefinition. Required.
--   @AttributeName            NVARCHAR(100) - Display name. Required.
--   @DataType                 NVARCHAR(50)  - Data type identifier. Required.
--   @IsRequired               BIT = 0       - Whether attribute is required.
--   @DefaultValue             NVARCHAR(255) = NULL - Default value.
--   @Uom                      NVARCHAR(20)  = NULL - Unit of measure.
--   @Description              NVARCHAR(500) = NULL - Optional description.
--   @AppUserId                BIGINT        - User performing the action. Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR), NewId (BIGINT).
--   Status=1 on success, 0 on failure. NewId is NULL on failure.
--
-- Dependencies:
--   Tables: Location.LocationAttributeDefinition, Location.LocationTypeDefinition
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Error Handling:
--   - Validation/business-rule failures: @Status=0, @Message set, Audit_LogFailure, RETURN.
--   - CATCH handler: rollback, @Status=0, @Message captured, Audit_LogFailure, RAISERROR.
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
--   2026-04-15 - 2.0 - SELECT result for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationAttributeDefinition_Create
    @LocationTypeDefinitionId  BIGINT,
    @AttributeName             NVARCHAR(100),
    @DataType                  NVARCHAR(50),
    @IsRequired                BIT             = 0,
    @DefaultValue              NVARCHAR(255)   = NULL,
    @Uom                       NVARCHAR(20)    = NULL,
    @Description               NVARCHAR(500)   = NULL,
    @AppUserId                 BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Result variables (returned via SELECT instead of OUTPUT)
    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';
    DECLARE @NewId   BIGINT        = NULL;

    -- Capture input for failure-log snapshots
    DECLARE @ProcName NVARCHAR(200) = N'Location.LocationAttributeDefinition_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @LocationTypeDefinitionId AS LocationTypeDefinitionId,
                @AttributeName AS AttributeName,
                @DataType AS DataType,
                @IsRequired AS IsRequired,
                @DefaultValue AS DefaultValue,
                @Uom AS Uom,
                @Description AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @LocationTypeDefinitionId IS NULL OR @AttributeName IS NULL OR @DataType IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Location.LocationTypeDefinition
                       WHERE Id = @LocationTypeDefinitionId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated LocationTypeDefinitionId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- ====================
        -- Mutation (atomic)
        -- ====================
        DECLARE @NextSort INT;
        SELECT @NextSort = ISNULL(MAX(SortOrder), 0) + 1
        FROM Location.LocationAttributeDefinition
        WHERE LocationTypeDefinitionId = @LocationTypeDefinitionId
          AND DeprecatedAt IS NULL;

        BEGIN TRANSACTION;

        INSERT INTO Location.LocationAttributeDefinition
            (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description, CreatedAt)
        VALUES
            (@LocationTypeDefinitionId, @AttributeName, @DataType, @IsRequired, @DefaultValue, @Uom, @NextSort, @Description, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        -- Success audit INSIDE the transaction
        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'LocationAttrDef',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'LocationAttributeDefinition created.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'LocationAttributeDefinition created successfully.';
        SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Capture error details BEFORE nested TRY/CATCH clears context
        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);
        SET @NewId   = NULL;

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
            -- Swallow; don't mask the original exception
        END CATCH

        SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
