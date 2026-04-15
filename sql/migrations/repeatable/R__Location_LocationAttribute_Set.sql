-- =============================================
-- Procedure:   Location.LocationAttribute_Set
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Upsert for LocationAttribute values. Sets the attribute value for
--   a given Location + AttributeDefinition pair. If a row already exists,
--   updates the value; otherwise inserts a new row.
--
--   Validates:
--     - Required parameters not NULL
--     - LocationId exists and is active (not deprecated)
--     - LocationAttributeDefinitionId exists and is active
--     - Cross-definition: the attribute definition's LocationTypeDefinitionId
--       must match the location's LocationTypeDefinitionId
--
--   Logs success to Audit.ConfigLog and failure to Audit.FailureLog.
--
-- Parameters (input):
--   @LocationId                     BIGINT        - FK to Location. Required.
--   @LocationAttributeDefinitionId  BIGINT        - FK to LocationAttributeDefinition. Required.
--   @AttributeValue                 NVARCHAR(255) - Value to set. Required.
--   @AppUserId                      BIGINT        - User performing the action. Required.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR).
--   Status=1 on success, 0 on failure.
--
-- Dependencies:
--   Tables: Location.LocationAttribute, Location.LocationAttributeDefinition,
--           Location.Location
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
CREATE OR ALTER PROCEDURE Location.LocationAttribute_Set
    @LocationId                     BIGINT,
    @LocationAttributeDefinitionId  BIGINT,
    @AttributeValue                 NVARCHAR(255),
    @AppUserId                      BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Result variables (returned via SELECT instead of OUTPUT)
    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    -- Capture input for failure-log snapshots
    DECLARE @ProcName NVARCHAR(200) = N'Location.LocationAttribute_Set';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @LocationId AS LocationId,
                @LocationAttributeDefinitionId AS LocationAttributeDefinitionId,
                @AttributeValue AS AttributeValue
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @LocationId IS NULL OR @LocationAttributeDefinitionId IS NULL
           OR @AttributeValue IS NULL OR @AppUserId IS NULL
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
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Validate Location exists and is active
        DECLARE @LocDefId BIGINT;
        SELECT @LocDefId = LocationTypeDefinitionId
        FROM Location.Location
        WHERE Id = @LocationId AND DeprecatedAt IS NULL;

        IF @LocDefId IS NULL
        BEGIN
            SET @Message = N'Location not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Validate attribute definition exists and is active
        DECLARE @AttrDefParentId BIGINT;
        SELECT @AttrDefParentId = LocationTypeDefinitionId
        FROM Location.LocationAttributeDefinition
        WHERE Id = @LocationAttributeDefinitionId AND DeprecatedAt IS NULL;

        IF @AttrDefParentId IS NULL
        BEGIN
            SET @Message = N'Attribute definition not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Cross-definition validation
        -- ====================
        IF @LocDefId != @AttrDefParentId
        BEGIN
            SET @Message = N'Attribute definition does not belong to this location''s type definition.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Check for existing row (upsert logic)
        -- ====================
        DECLARE @ExistingId BIGINT, @OldVal NVARCHAR(255);
        SELECT @ExistingId = Id, @OldVal = AttributeValue
        FROM Location.LocationAttribute
        WHERE LocationId = @LocationId
          AND LocationAttributeDefinitionId = @LocationAttributeDefinitionId;

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        IF @ExistingId IS NOT NULL
        BEGIN
            -- UPDATE existing
            UPDATE Location.LocationAttribute
            SET AttributeValue  = @AttributeValue,
                UpdatedAt       = SYSUTCDATETIME(),
                UpdatedByUserId = @AppUserId
            WHERE Id = @ExistingId;

            DECLARE @OldValue NVARCHAR(MAX) = (SELECT @OldVal AS AttributeValue FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
            DECLARE @NewValue NVARCHAR(MAX) = (SELECT @AttributeValue AS AttributeValue FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

            EXEC Audit.Audit_LogConfigChange
                @AppUserId         = @AppUserId,
                @LogEntityTypeCode = N'LocationAttrDef',
                @EntityId          = @ExistingId,
                @LogEventTypeCode  = N'Updated',
                @LogSeverityCode   = N'Info',
                @Description       = N'LocationAttribute value updated.',
                @OldValue          = @OldValue,
                @NewValue          = @NewValue;

            SET @Status  = 1;
            SET @Message = N'Attribute value updated successfully.';
        END
        ELSE
        BEGIN
            -- INSERT new
            INSERT INTO Location.LocationAttribute
                (LocationId, LocationAttributeDefinitionId, AttributeValue, CreatedAt)
            VALUES
                (@LocationId, @LocationAttributeDefinitionId, @AttributeValue, SYSUTCDATETIME());

            DECLARE @NewId BIGINT = CAST(SCOPE_IDENTITY() AS BIGINT);
            DECLARE @InsertValue NVARCHAR(MAX) = @Params;

            EXEC Audit.Audit_LogConfigChange
                @AppUserId         = @AppUserId,
                @LogEntityTypeCode = N'LocationAttrDef',
                @EntityId          = @NewId,
                @LogEventTypeCode  = N'Created',
                @LogSeverityCode   = N'Info',
                @Description       = N'LocationAttribute value created.',
                @OldValue          = NULL,
                @NewValue          = @InsertValue;

            SET @Status  = 1;
            SET @Message = N'Attribute value set successfully.';
        END

        COMMIT TRANSACTION;

        SELECT @Status AS Status, @Message AS Message;
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

        SELECT @Status AS Status, @Message AS Message;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
