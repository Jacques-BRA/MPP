-- =============================================
-- Procedure:   Parts.RouteStep_MoveUp
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.1
--
-- Description:
--   Moves a RouteStep up in the ordered step list by swapping
--   SequenceNumber with the nearest sibling above (lower SequenceNumber)
--   within the same RouteTemplateId. No-op (Status=1) if already first.
--
--   Pattern is copied directly from Location.Location_MoveUp, with table
--   Parts.RouteStep, grouping column RouteTemplateId, and ordering column
--   SequenceNumber.
--
--   Rejects if the parent RouteTemplate is deprecated OR published —
--   deprecated and published routes are immutable to preserve production
--   traceability. Create a new version to modify.
--
-- Parameters (input):
--   @Id BIGINT        - PK of the RouteStep to move. Required.
--   @AppUserId BIGINT - User performing the action. Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success (including no-op), 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--
-- Dependencies:
--   Tables: Parts.RouteStep, Parts.RouteTemplate
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
--   2026-04-14 - 1.1 - Reject if parent RouteTemplate is Published
-- =============================================
CREATE OR ALTER PROCEDURE Parts.RouteStep_MoveUp
    @Id        BIGINT,
    @AppUserId BIGINT,
    @Status    BIT            OUTPUT,
    @Message   NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.RouteStep_MoveUp';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'RouteStep',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Get current row's SequenceNumber and parent RouteTemplateId
        DECLARE @CurrentSeq INT, @ParentRouteId BIGINT;
        SELECT @CurrentSeq    = SequenceNumber,
               @ParentRouteId = RouteTemplateId
        FROM Parts.RouteStep
        WHERE Id = @Id;

        IF @CurrentSeq IS NULL
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

        -- Find nearest sibling ABOVE (lower SequenceNumber)
        DECLARE @SwapId BIGINT, @SwapSeq INT;

        SELECT TOP 1 @SwapId = Id, @SwapSeq = SequenceNumber
        FROM Parts.RouteStep
        WHERE RouteTemplateId = @ParentRouteId
          AND SequenceNumber < @CurrentSeq
        ORDER BY SequenceNumber DESC;

        -- Already first — no-op, success
        IF @SwapId IS NULL
        BEGIN
            SET @Status  = 1;
            SET @Message = N'Already first.';
            RETURN;
        END

        -- Mutation (atomic)
        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT @Id AS Id, @CurrentSeq AS OldSequenceNumber,
                    @SwapId AS SwapId, @SwapSeq AS SwapOldSequenceNumber
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        DECLARE @NewValue NVARCHAR(MAX) =
            (SELECT @Id AS Id, @SwapSeq AS NewSequenceNumber,
                    @SwapId AS SwapId, @CurrentSeq AS SwapNewSequenceNumber
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Parts.RouteStep SET SequenceNumber = @SwapSeq    WHERE Id = @Id;
        UPDATE Parts.RouteStep SET SequenceNumber = @CurrentSeq WHERE Id = @SwapId;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'RouteStep',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'RouteStep moved up.',
            @OldValue          = @OldValue,
            @NewValue          = @NewValue;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Moved up successfully.';
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
