-- ============================================================
-- STORED PROCEDURE TEMPLATE — MPP MES
-- ============================================================
--
-- Copy this file as a starting point for any new stored procedure.
-- The full template with detailed commentary is in:
--   MPP_MES_PHASED_PLAN_CONFIG_TOOL.md > "Stored Procedure Template and Conventions"
--
-- Key rules:
--   - Every proc gets @Status BIT OUTPUT and @Message NVARCHAR(500) OUTPUT
--   - Three-tier error hierarchy: parameter validation, business rule, unexpected exception
--   - Success audit (Audit_LogConfigChange) INSIDE the transaction
--   - Failure audit (Audit_LogFailure) OUTSIDE the rolled-back transaction
--   - @AppUserId required on every mutating proc
--   - Code-string pattern for audit calls (N'Location', N'Created', N'Info')
--
-- Naming: Schema.Entity_Verb  (e.g., Location.Location_Create, Parts.Item_Update)
-- File:   R__Schema_Entity_Verb.sql  (e.g., R__Location_Location_Create.sql)
--
-- ============================================================


-- =============================================
-- FULL EXAMPLE: Location.Location_Create
-- =============================================

-- =============================================
-- Procedure:   Location.Location_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     1.0
--
-- Description:
--   Creates a new Location row under the specified parent. Validates
--   LocationTypeDefinition and parent existence. Enforces Code uniqueness.
--   Logs success to Audit.ConfigLog or failure to Audit.FailureLog.
--
-- Parameters (input):
--   @LocationTypeDefinitionId INT      - FK to LocationTypeDefinition. Required.
--   @ParentLocationId INT NULL         - FK to Location. NULL only for the Enterprise root.
--   @Name NVARCHAR(200)                - Display name. Required.
--   @Code NVARCHAR(50)                 - Short identifier. Required. Must be unique among active rows.
--   @Description NVARCHAR(500) NULL    - Optional description.
--   @AppUserId INT                     - User performing the action. Required for audit attribution.
--
-- Parameters (output):
--   @Status BIT                        - 1 on success, 0 on failure.
--   @Message NVARCHAR(500)             - Human-readable status message.
--   @NewId INT                         - New Location.Id on success, NULL on failure.
--
-- Result set:
--   None. Data output is via @NewId.
--
-- Dependencies:
--   Tables: Location.Location, Location.LocationTypeDefinition
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Error Handling:
--   - Validation/business-rule failures: @Status=0, @Message set, Audit_LogFailure, RETURN.
--   - CATCH handler: rollback, @Status=0, @Message captured, Audit_LogFailure, THROW.
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Location.Location_Create
    @LocationTypeDefinitionId BIGINT,
    @ParentLocationId          BIGINT            = NULL,
    @Name                      NVARCHAR(200),
    @Code                      NVARCHAR(50),
    @Description               NVARCHAR(500)  = NULL,
    @AppUserId                 BIGINT,
    @Status                    BIT            OUTPUT,
    @Message                   NVARCHAR(500)  OUTPUT,
    @NewId                     BIGINT         = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Initialize output
    SET @Status  = 0;
    SET @Message = N'Unknown error';
    SET @NewId   = NULL;

    -- Capture input for failure-log snapshots
    DECLARE @ProcName NVARCHAR(200) = N'Location.Location_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @LocationTypeDefinitionId AS LocationTypeDefinitionId,
                @ParentLocationId         AS ParentLocationId,
                @Name                     AS Name,
                @Code                     AS Code,
                @Description              AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @LocationTypeDefinitionId IS NULL OR @Name IS NULL OR @Code IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'Location',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Location.LocationTypeDefinition
                       WHERE Id = @LocationTypeDefinitionId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated LocationTypeDefinitionId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Location', @EntityId = NULL,
                @LogEventTypeCode = N'Created', @FailureReason = @Message,
                @ProcedureName = @ProcName, @AttemptedParameters = @Params;
            RETURN;
        END

        IF @ParentLocationId IS NOT NULL AND NOT EXISTS
            (SELECT 1 FROM Location.Location WHERE Id = @ParentLocationId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated ParentLocationId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Location', @EntityId = NULL,
                @LogEventTypeCode = N'Created', @FailureReason = @Message,
                @ProcedureName = @ProcName, @AttemptedParameters = @Params;
            RETURN;
        END

        -- ====================
        -- Business rule checks
        -- ====================
        IF EXISTS (SELECT 1 FROM Location.Location WHERE Code = @Code AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'A location with this Code already exists.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Location', @EntityId = NULL,
                @LogEventTypeCode = N'Created', @FailureReason = @Message,
                @ProcedureName = @ProcName, @AttemptedParameters = @Params;
            RETURN;
        END

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        INSERT INTO Location.Location
            (LocationTypeDefinitionId, ParentLocationId, Name, Code, Description, CreatedAt)
        VALUES
            (@LocationTypeDefinitionId, @ParentLocationId, @Name, @Code, @Description, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        -- Success audit INSIDE the transaction — rolls back atomically with the data
        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'Location',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'Location created.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Location created successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Capture error details BEFORE the nested TRY/CATCH clears the error context
        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);
        SET @NewId   = NULL;

        -- Failure log OUTSIDE the rolled-back transaction
        -- Wrap in nested TRY/CATCH so a log-write failure doesn't mask the real error
        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'Location',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
            -- Swallow; we're already in a bad state and shouldn't mask the original exception
        END CATCH

        -- Re-raise so Ignition logs it as a critical exception
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO


-- =============================================
-- BLANK SKELETON: Copy and fill in
-- =============================================

/*
-- =============================================
-- Procedure:   [Schema].[Entity_Verb]
-- Author:      [Your Name]
-- Created:     YYYY-MM-DD
-- Version:     1.0
--
-- Description:
--   [What this proc does and why]
--
-- Parameters (input):
--   [List each param with type and purpose]
--   @AppUserId INT - User performing the action. Required for audit attribution.
--
-- Parameters (output):
--   @Status BIT    - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--   [Any proc-specific outputs like @NewId]
--
-- Result set:
--   [None / describe rowset for read procs]
--
-- Dependencies:
--   Tables: [list]
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Error Handling:
--   - Validation/business-rule failures: @Status=0, @Message set, Audit_LogFailure, RETURN.
--   - CATCH handler: rollback, @Status=0, @Message captured, Audit_LogFailure, THROW.
--
-- Change Log:
--   YYYY-MM-DD - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE [Schema].[Entity_Verb]
    -- Input params
    @AppUserId      BIGINT,
    -- Output params
    @Status         BIT            OUTPUT,
    @Message        NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'[Schema].[Entity_Verb]';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT -- list input params here
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        -- IF ... BEGIN SET @Message = ...; EXEC Audit.Audit_LogFailure ...; RETURN; END

        -- ====================
        -- Business rule checks
        -- ====================
        -- IF ... BEGIN SET @Message = ...; EXEC Audit.Audit_LogFailure ...; RETURN; END

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        -- Your INSERT / UPDATE / DELETE here

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'[EntityType]',
            @EntityId          = NULL,  -- or @NewId
            @LogEventTypeCode  = N'Created',  -- or Updated, Deprecated
            @LogSeverityCode   = N'Info',
            @Description       = N'[description]',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'[Success message].';
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
                @LogEntityTypeCode   = N'[EntityType]',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
            -- Swallow
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
*/
