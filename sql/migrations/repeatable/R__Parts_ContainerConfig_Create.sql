-- =============================================
-- Procedure:   Parts.ContainerConfig_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Creates a ContainerConfig for an Item. At most one active config is
--   allowed per Item — enforced both by explicit business-rule check
--   and by the filtered unique index UQ_ContainerConfig_ActiveItemId.
--
--   @ClosureMethod and @TargetWeight are OI-02 columns (scale-driven
--   container closure) — accepted as optional parameters pending MPP
--   customer validation. Today they default to NULL; once OI-02 is
--   resolved and callers start supplying values, no proc change is
--   required. Expected non-null values for ClosureMethod: 'ByCount' or
--   'ByWeight' (not enforced here — treated as a free-text code until
--   the OI resolves).
--
-- Parameters (input):
--   @ItemId BIGINT                  - FK → Parts.Item. Required.
--   @TraysPerContainer INT          - Required.
--   @PartsPerTray INT               - Required.
--   @IsSerialized BIT = 0
--   @DunnageCode NVARCHAR(50) NULL
--   @CustomerCode NVARCHAR(50) NULL
--   @ClosureMethod NVARCHAR(20) NULL   -- OI-02 pending
--   @TargetWeight DECIMAL(10,4) NULL   -- OI-02 pending
--   @AppUserId BIGINT               - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--   @NewId BIGINT          - New row Id on success.
--
-- Dependencies:
--   Tables: Parts.ContainerConfig, Parts.Item
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.ContainerConfig_Create
    @ItemId            BIGINT,
    @TraysPerContainer INT,
    @PartsPerTray      INT,
    @IsSerialized      BIT            = 0,
    @DunnageCode       NVARCHAR(50)   = NULL,
    @CustomerCode      NVARCHAR(50)   = NULL,
    @ClosureMethod     NVARCHAR(20)   = NULL,
    @TargetWeight      DECIMAL(10,4)  = NULL,
    @AppUserId         BIGINT,
    @Status            BIT            OUTPUT,
    @Message           NVARCHAR(500)  OUTPUT,
    @NewId             BIGINT         = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';
    SET @NewId   = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Parts.ContainerConfig_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @ItemId AS ItemId, @TraysPerContainer AS TraysPerContainer,
                @PartsPerTray AS PartsPerTray, @IsSerialized AS IsSerialized,
                @DunnageCode AS DunnageCode, @CustomerCode AS CustomerCode,
                @ClosureMethod AS ClosureMethod, @TargetWeight AS TargetWeight
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @ItemId IS NULL OR @TraysPerContainer IS NULL OR @PartsPerTray IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ContainerConfig',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: ItemId must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.Item WHERE Id = @ItemId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated ItemId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ContainerConfig',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: no active config already exists for this Item
        IF EXISTS (SELECT 1 FROM Parts.ContainerConfig WHERE ItemId = @ItemId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'An active ContainerConfig already exists for this Item.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ContainerConfig',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        BEGIN TRANSACTION;

        INSERT INTO Parts.ContainerConfig
            (ItemId, TraysPerContainer, PartsPerTray, IsSerialized,
             DunnageCode, CustomerCode, ClosureMethod, TargetWeight, CreatedAt)
        VALUES
            (@ItemId, @TraysPerContainer, @PartsPerTray, @IsSerialized,
             @DunnageCode, @CustomerCode, @ClosureMethod, @TargetWeight, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'ContainerConfig',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'ContainerConfig created.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'ContainerConfig created successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);
        SET @NewId   = NULL;

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ContainerConfig',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
