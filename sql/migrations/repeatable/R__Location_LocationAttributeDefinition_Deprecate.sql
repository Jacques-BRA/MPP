-- =============================================
-- Procedure:   Location.LocationAttributeDefinition_Deprecate
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Soft-deletes a LocationAttributeDefinition by setting DeprecatedAt.
--   Rejects if any Location.LocationAttribute rows reference this definition.
--   After deprecating, compacts sibling SortOrder gaps using ROW_NUMBER()
--   renumbering among remaining active siblings.
--
-- Parameters (input):
--   @Id BIGINT        - PK of the row to deprecate. Required.
--   @AppUserId BIGINT - User performing the action. Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR).
--   Status=1 on success, 0 on failure.
--
-- Dependencies:
--   Tables: Location.LocationAttributeDefinition, Location.LocationAttribute
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
CREATE OR ALTER PROCEDURE Location.LocationAttributeDefinition_Deprecate
    @Id        BIGINT,
    @AppUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Result variables (returned via SELECT instead of OUTPUT)
    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    -- Capture input for failure-log snapshots
    DECLARE @ProcName NVARCHAR(200) = N'Location.LocationAttributeDefinition_Deprecate';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Deprecated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Target must exist
        IF NOT EXISTS (SELECT 1 FROM Location.LocationAttributeDefinition WHERE Id = @Id)
        BEGIN
            SET @Message = N'LocationAttributeDefinition not found.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Deprecated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Target must not already be deprecated
        IF EXISTS (SELECT 1 FROM Location.LocationAttributeDefinition
                   WHERE Id = @Id AND DeprecatedAt IS NOT NULL)
        BEGIN
            SET @Message = N'LocationAttributeDefinition is already deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Deprecated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Business rule checks
        -- ====================

        -- Reject if any LocationAttribute rows reference this definition
        IF EXISTS (SELECT 1 FROM Location.LocationAttribute
                   WHERE LocationAttributeDefinitionId = @Id)
        BEGIN
            SET @Message = N'Cannot deprecate: LocationAttribute rows reference this definition.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Deprecated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Capture old values for audit
        -- ====================
        DECLARE @ParentDefId BIGINT;
        SELECT @ParentDefId = LocationTypeDefinitionId
        FROM Location.LocationAttributeDefinition
        WHERE Id = @Id;

        DECLARE @OldValue NVARCHAR(MAX);
        SELECT @OldValue =
            (SELECT AttributeName,
                    DataType,
                    IsRequired,
                    DefaultValue,
                    Uom,
                    SortOrder,
                    Description,
                    DeprecatedAt
             FROM Location.LocationAttributeDefinition
             WHERE Id = @Id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        UPDATE Location.LocationAttributeDefinition
        SET DeprecatedAt = SYSUTCDATETIME()
        WHERE Id = @Id;

        -- Compact sibling SortOrder gaps using ROW_NUMBER() renumbering
        ;WITH Renumbered AS (
            SELECT Id, ROW_NUMBER() OVER (ORDER BY SortOrder) AS NewSort
            FROM Location.LocationAttributeDefinition
            WHERE LocationTypeDefinitionId = @ParentDefId
              AND DeprecatedAt IS NULL
        )
        UPDATE lad
        SET lad.SortOrder = r.NewSort
        FROM Location.LocationAttributeDefinition lad
        INNER JOIN Renumbered r ON r.Id = lad.Id;

        -- Capture new state for audit
        DECLARE @NewValue NVARCHAR(MAX);
        SELECT @NewValue =
            (SELECT AttributeName,
                    DataType,
                    IsRequired,
                    DefaultValue,
                    Uom,
                    SortOrder,
                    Description,
                    DeprecatedAt
             FROM Location.LocationAttributeDefinition
             WHERE Id = @Id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        -- Success audit INSIDE the transaction
        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'LocationAttrDef',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Deprecated',
            @LogSeverityCode   = N'Info',
            @Description       = N'LocationAttributeDefinition deprecated.',
            @OldValue          = @OldValue,
            @NewValue          = @NewValue;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'LocationAttributeDefinition deprecated successfully.';
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
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Deprecated',
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
