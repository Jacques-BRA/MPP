-- =============================================
-- Procedure:   Location.LocationAttributeDefinition_Update
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Updates mutable fields on an existing LocationAttributeDefinition:
--   AttributeName, DataType, IsRequired, DefaultValue, Uom, Description.
--   Does NOT change SortOrder (use MoveUp/MoveDown) or DeprecatedAt
--   (use Deprecate). Captures old/new values as JSON for audit diff.
--
-- Parameters (input):
--   @Id BIGINT                    - PK of the row to update. Required.
--   @AttributeName NVARCHAR(100)  - New attribute name. Required.
--   @DataType NVARCHAR(50)        - New data type. Required.
--   @IsRequired BIT = 0           - Whether attribute is required.
--   @DefaultValue NVARCHAR(255)   = NULL - Default value.
--   @Uom NVARCHAR(20)             = NULL - Unit of measure.
--   @Description NVARCHAR(500)    = NULL - Optional description.
--   @AppUserId BIGINT             - User performing the action. Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR).
--   Status=1 on success, 0 on failure.
--
-- Dependencies:
--   Tables: Location.LocationAttributeDefinition
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
CREATE OR ALTER PROCEDURE Location.LocationAttributeDefinition_Update
    @Id              BIGINT,
    @AttributeName   NVARCHAR(100),
    @DataType        NVARCHAR(50),
    @IsRequired      BIT             = 0,
    @DefaultValue    NVARCHAR(255)   = NULL,
    @Uom             NVARCHAR(20)    = NULL,
    @Description     NVARCHAR(500)   = NULL,
    @AppUserId       BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Result variables (returned via SELECT instead of OUTPUT)
    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    -- Capture input for failure-log snapshots
    DECLARE @ProcName NVARCHAR(200) = N'Location.LocationAttributeDefinition_Update';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id,
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
        IF @Id IS NULL OR @AttributeName IS NULL OR @DataType IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Target must exist and not be deprecated
        IF NOT EXISTS (SELECT 1 FROM Location.LocationAttributeDefinition
                       WHERE Id = @Id AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'LocationAttributeDefinition not found or is deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Capture old values for audit diff
        -- ====================
        DECLARE @OldValue NVARCHAR(MAX);
        SELECT @OldValue =
            (SELECT AttributeName,
                    DataType,
                    IsRequired,
                    DefaultValue,
                    Uom,
                    Description
             FROM Location.LocationAttributeDefinition
             WHERE Id = @Id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        DECLARE @NewValue NVARCHAR(MAX) =
            (SELECT @AttributeName AS AttributeName,
                    @DataType AS DataType,
                    @IsRequired AS IsRequired,
                    @DefaultValue AS DefaultValue,
                    @Uom AS Uom,
                    @Description AS Description
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        UPDATE Location.LocationAttributeDefinition
        SET AttributeName = @AttributeName,
            DataType      = @DataType,
            IsRequired    = @IsRequired,
            DefaultValue  = @DefaultValue,
            Uom           = @Uom,
            Description   = @Description
        WHERE Id = @Id;

        -- Success audit INSIDE the transaction
        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'LocationAttrDef',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'LocationAttributeDefinition updated.',
            @OldValue          = @OldValue,
            @NewValue          = @NewValue;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'LocationAttributeDefinition updated successfully.';
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
