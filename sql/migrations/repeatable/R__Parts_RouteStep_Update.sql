-- =============================================
-- Procedure:   Parts.RouteStep_Update
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.1
--
-- Description:
--   Updates mutable fields of a RouteStep: OperationTemplateId, IsRequired,
--   Description. SequenceNumber is NOT updated here — use _MoveUp /
--   _MoveDown to reorder steps.
--
--   Rejects if the parent RouteTemplate is deprecated OR published —
--   deprecated and published routes are immutable to preserve production
--   traceability. Create a new version to modify.
--
-- Parameters (input):
--   @Id BIGINT                    - Required.
--   @OperationTemplateId BIGINT   - Required. Must be active.
--   @IsRequired BIT = 1
--   @Description NVARCHAR(500) NULL
--   @AppUserId BIGINT             - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--
-- Dependencies:
--   Tables: Parts.RouteStep, Parts.RouteTemplate, Parts.OperationTemplate
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
--   2026-04-14 - 1.1 - Reject if parent RouteTemplate is Published
-- =============================================
CREATE OR ALTER PROCEDURE Parts.RouteStep_Update
    @Id                  BIGINT,
    @OperationTemplateId BIGINT,
    @IsRequired          BIT            = 1,
    @Description         NVARCHAR(500)  = NULL,
    @AppUserId           BIGINT,
    @Status              BIT            OUTPUT,
    @Message             NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.RouteStep_Update';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id, @OperationTemplateId AS OperationTemplateId,
                @IsRequired AS IsRequired, @Description AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Id IS NULL OR @OperationTemplateId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Target must exist
        DECLARE @ParentRouteId BIGINT;
        SELECT @ParentRouteId = RouteTemplateId
        FROM Parts.RouteStep
        WHERE Id = @Id;

        IF @ParentRouteId IS NULL
        BEGIN
            SET @Message = N'RouteStep not found.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Parent RouteTemplate must be active (deprecated routes are immutable)
        IF NOT EXISTS (SELECT 1 FROM Parts.RouteTemplate
                       WHERE Id = @ParentRouteId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Parent RouteTemplate is deprecated (deprecated routes are immutable).';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Parent RouteTemplate must not be published (published routes are immutable)
        IF EXISTS (SELECT 1 FROM Parts.RouteTemplate
                   WHERE Id = @ParentRouteId AND PublishedAt IS NOT NULL)
        BEGIN
            SET @Message = N'Parent RouteTemplate is published (immutable). Create a new version to modify.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- OperationTemplateId must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.OperationTemplate
                       WHERE Id = @OperationTemplateId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated OperationTemplateId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Capture OldValue for audit BEFORE the UPDATE
        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT RouteTemplateId, OperationTemplateId, SequenceNumber,
                    IsRequired, Description
             FROM Parts.RouteStep WHERE Id = @Id
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Parts.RouteStep
        SET OperationTemplateId = @OperationTemplateId,
            IsRequired          = @IsRequired,
            Description         = @Description
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'RouteStep',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'RouteStep updated.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'RouteStep updated successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
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
