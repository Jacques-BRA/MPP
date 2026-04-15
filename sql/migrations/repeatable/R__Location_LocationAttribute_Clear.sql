-- =============================================
-- Procedure:   Location.LocationAttribute_Clear
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Deletes a LocationAttribute value row (hard DELETE). Attribute values
--   are a value store, not an auditable entity with lifecycle.
--
--   Validates:
--     - Required parameters not NULL
--     - LocationId exists and is active
--     - LocationAttributeDefinitionId exists and is active
--     - Cross-definition: definition's LocationTypeDefinitionId must match
--       the location's LocationTypeDefinitionId
--     - Rejects if the attribute definition has IsRequired = 1
--     - Rejects if no attribute value row exists to delete
--
--   Logs success to Audit.ConfigLog and failure to Audit.FailureLog.
--
-- Parameters (input):
--   @LocationId                     BIGINT - FK to Location. Required.
--   @LocationAttributeDefinitionId  BIGINT - FK to LocationAttributeDefinition. Required.
--   @AppUserId                      BIGINT - User performing the action. Required.
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
CREATE OR ALTER PROCEDURE Location.LocationAttribute_Clear
    @LocationId                     BIGINT,
    @LocationAttributeDefinitionId  BIGINT,
    @AppUserId                      BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Result variables (returned via SELECT instead of OUTPUT)
    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    -- Capture input for failure-log snapshots
    DECLARE @ProcName NVARCHAR(200) = N'Location.LocationAttribute_Clear';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @LocationId AS LocationId,
                @LocationAttributeDefinitionId AS LocationAttributeDefinitionId
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @LocationId IS NULL OR @LocationAttributeDefinitionId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Updated',
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
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Validate attribute definition exists and is active
        DECLARE @AttrDefParentId BIGINT;
        DECLARE @IsRequired BIT;
        SELECT @AttrDefParentId = LocationTypeDefinitionId,
               @IsRequired = IsRequired
        FROM Location.LocationAttributeDefinition
        WHERE Id = @LocationAttributeDefinitionId AND DeprecatedAt IS NULL;

        IF @AttrDefParentId IS NULL
        BEGIN
            SET @Message = N'Attribute definition not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Updated',
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
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Business rule: required attributes cannot be cleared
        -- ====================
        IF @IsRequired = 1
        BEGIN
            SET @Message = N'Cannot clear a required attribute.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Check row exists
        -- ====================
        DECLARE @ExistingId BIGINT, @OldVal NVARCHAR(255);
        SELECT @ExistingId = Id, @OldVal = AttributeValue
        FROM Location.LocationAttribute
        WHERE LocationId = @LocationId
          AND LocationAttributeDefinitionId = @LocationAttributeDefinitionId;

        IF @ExistingId IS NULL
        BEGIN
            SET @Message = N'No attribute value exists to clear.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Mutation (atomic)
        -- ====================
        DECLARE @OldValue NVARCHAR(MAX) = (SELECT @OldVal AS AttributeValue FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        DELETE FROM Location.LocationAttribute
        WHERE Id = @ExistingId;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'LocationAttrDef',
            @EntityId          = @ExistingId,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'LocationAttribute value cleared (deleted).',
            @OldValue          = @OldValue,
            @NewValue          = NULL;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Attribute value cleared successfully.';
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
                @LogEventTypeCode    = N'Updated',
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
