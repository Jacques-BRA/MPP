-- =============================================
-- Procedure:   Parts.RouteTemplate_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Creates the first version (VersionNumber = 1) of a RouteTemplate for
--   a given Item. The route starts empty — steps are added via
--   Parts.RouteStep_Add. For subsequent versions, use _CreateNewVersion
--   which clones the prior version's steps.
--
-- Parameters (input):
--   @ItemId BIGINT          - Required. Must be active.
--   @Name NVARCHAR(200)     - Required. Display label for this route version.
--   @EffectiveFrom DATETIME2(3) NULL - When this version becomes active.
--                                       NULL → uses SYSUTCDATETIME().
--   @AppUserId BIGINT       - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--   @NewId BIGINT          - New RouteTemplate.Id on success.
--
-- Dependencies:
--   Tables: Parts.RouteTemplate, Parts.Item
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.RouteTemplate_Create
    @ItemId        BIGINT,
    @Name          NVARCHAR(200),
    @EffectiveFrom DATETIME2(3)  = NULL,
    @AppUserId     BIGINT,
    @Status        BIT           OUTPUT,
    @Message       NVARCHAR(500) OUTPUT,
    @NewId         BIGINT        = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';
    SET @NewId   = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Parts.RouteTemplate_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @ItemId AS ItemId, @Name AS Name, @EffectiveFrom AS EffectiveFrom
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @ItemId IS NULL OR @Name IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Route',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Parts.Item WHERE Id = @ItemId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated ItemId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Route',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Reject if a RouteTemplate for this Item already exists (use _CreateNewVersion instead)
        IF EXISTS (SELECT 1 FROM Parts.RouteTemplate WHERE ItemId = @ItemId)
        BEGIN
            SET @Message = N'A RouteTemplate already exists for this Item. Use _CreateNewVersion to add a new version.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Route',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        DECLARE @EffFrom DATETIME2(3) = ISNULL(@EffectiveFrom, SYSUTCDATETIME());

        BEGIN TRANSACTION;

        INSERT INTO Parts.RouteTemplate
            (ItemId, VersionNumber, Name, EffectiveFrom, CreatedByUserId, CreatedAt)
        VALUES
            (@ItemId, 1, @Name, @EffFrom, @AppUserId, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'Route',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'RouteTemplate created (v1).',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'RouteTemplate created successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Route',
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
