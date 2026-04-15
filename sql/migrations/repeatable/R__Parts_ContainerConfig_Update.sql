-- =============================================
-- Procedure:   Parts.ContainerConfig_Update
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Updates mutable fields of an active ContainerConfig. ItemId is
--   immutable — to associate a config with a different Item, deprecate
--   this one and create a new one. Sets UpdatedAt = SYSUTCDATETIME() on
--   every successful update.
--
--   @ClosureMethod and @TargetWeight are OI-02 columns (scale-driven
--   container closure) — accepted as optional parameters pending MPP
--   customer validation. Safe to leave NULL today.
--
-- Parameters (input):
--   @Id BIGINT                       - Required.
--   @TraysPerContainer INT           - Required.
--   @PartsPerTray INT                - Required.
--   @IsSerialized BIT = 0
--   @DunnageCode NVARCHAR(50) NULL
--   @CustomerCode NVARCHAR(50) NULL
--   @ClosureMethod NVARCHAR(20) NULL   -- OI-02 pending
--   @TargetWeight DECIMAL(10,4) NULL   -- OI-02 pending
--   @AppUserId BIGINT                - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--
-- Dependencies:
--   Tables: Parts.ContainerConfig
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.ContainerConfig_Update
    @Id                BIGINT,
    @TraysPerContainer INT,
    @PartsPerTray      INT,
    @IsSerialized      BIT            = 0,
    @DunnageCode       NVARCHAR(50)   = NULL,
    @CustomerCode      NVARCHAR(50)   = NULL,
    @ClosureMethod     NVARCHAR(20)   = NULL,
    @TargetWeight      DECIMAL(10,4)  = NULL,
    @AppUserId         BIGINT,
    @Status            BIT            OUTPUT,
    @Message           NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.ContainerConfig_Update';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id, @TraysPerContainer AS TraysPerContainer,
                @PartsPerTray AS PartsPerTray, @IsSerialized AS IsSerialized,
                @DunnageCode AS DunnageCode, @CustomerCode AS CustomerCode,
                @ClosureMethod AS ClosureMethod, @TargetWeight AS TargetWeight
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Id IS NULL OR @TraysPerContainer IS NULL OR @PartsPerTray IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ContainerConfig',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Parts.ContainerConfig WHERE Id = @Id AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'ContainerConfig not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ContainerConfig',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT TraysPerContainer, PartsPerTray, IsSerialized,
                    DunnageCode, CustomerCode, ClosureMethod, TargetWeight
             FROM Parts.ContainerConfig WHERE Id = @Id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Parts.ContainerConfig
        SET TraysPerContainer = @TraysPerContainer,
            PartsPerTray      = @PartsPerTray,
            IsSerialized      = @IsSerialized,
            DunnageCode       = @DunnageCode,
            CustomerCode      = @CustomerCode,
            ClosureMethod     = @ClosureMethod,
            TargetWeight      = @TargetWeight,
            UpdatedAt         = SYSUTCDATETIME()
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'ContainerConfig',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'ContainerConfig updated.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'ContainerConfig updated successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'ContainerConfig',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
