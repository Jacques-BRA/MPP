-- =============================================
-- Procedure:   Parts.RouteStep_Add
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.1
--
-- Description:
--   Appends a step to the end of a RouteTemplate. SequenceNumber is
--   auto-assigned as MAX(sibling SequenceNumber) + 1 within the route.
--   To re-order steps after Add, use _MoveUp / _MoveDown.
--
--   Rejects if the target RouteTemplate is deprecated OR published —
--   deprecated and published routes are immutable to preserve production
--   traceability. Create a new version to modify.
--
-- Parameters (input):
--   @RouteTemplateId BIGINT        - Required.
--   @OperationTemplateId BIGINT    - Required.
--   @IsRequired BIT = 1
--   @Description NVARCHAR(500) NULL
--   @AppUserId BIGINT              - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--   @NewId BIGINT          - New RouteStep.Id on success.
--
-- Dependencies:
--   Tables: Parts.RouteStep, Parts.RouteTemplate, Parts.OperationTemplate
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
--   2026-04-14 - 1.1 - Reject if parent RouteTemplate is Published
-- =============================================
CREATE OR ALTER PROCEDURE Parts.RouteStep_Add
    @RouteTemplateId     BIGINT,
    @OperationTemplateId BIGINT,
    @IsRequired          BIT            = 1,
    @Description         NVARCHAR(500)  = NULL,
    @AppUserId           BIGINT,
    @Status              BIT            OUTPUT,
    @Message             NVARCHAR(500)  OUTPUT,
    @NewId               BIGINT         = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';
    SET @NewId   = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Parts.RouteStep_Add';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @RouteTemplateId AS RouteTemplateId,
                @OperationTemplateId AS OperationTemplateId,
                @IsRequired AS IsRequired, @Description AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @RouteTemplateId IS NULL OR @OperationTemplateId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Parts.RouteTemplate WHERE Id = @RouteTemplateId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'RouteTemplate not found or deprecated (deprecated routes are immutable).';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Parent RouteTemplate must not be published (published routes are immutable)
        IF EXISTS (SELECT 1 FROM Parts.RouteTemplate
                   WHERE Id = @RouteTemplateId AND PublishedAt IS NOT NULL)
        BEGIN
            SET @Message = N'Parent RouteTemplate is published (immutable). Create a new version to modify.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Parts.OperationTemplate WHERE Id = @OperationTemplateId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated OperationTemplateId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        BEGIN TRANSACTION;

        -- Auto-assign SequenceNumber = MAX(siblings) + 1
        DECLARE @NextSeq INT;
        SELECT @NextSeq = ISNULL(MAX(SequenceNumber), 0) + 1
        FROM Parts.RouteStep
        WHERE RouteTemplateId = @RouteTemplateId;

        INSERT INTO Parts.RouteStep
            (RouteTemplateId, OperationTemplateId, SequenceNumber, IsRequired, Description)
        VALUES
            (@RouteTemplateId, @OperationTemplateId, @NextSeq, @IsRequired, @Description);

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'RouteStep',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'RouteStep added.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'RouteStep added successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
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
