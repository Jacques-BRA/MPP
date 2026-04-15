-- =============================================
-- Procedure:   Parts.BomLine_MoveDown
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Swaps a BomLine's SortOrder with the nearest-higher sibling within
--   the same BomId. No-op (status=1, message "already last") if already
--   last. Rejects if the parent BOM is Published or Deprecated.
--
-- Parameters (input):
--   @Id BIGINT        - BomLine.Id. Required.
--   @AppUserId BIGINT - Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR).
--   Status=1 on success, 0 on failure.
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-15 - 2.0 - SELECT result for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.BomLine_MoveDown
    @Id        BIGINT,
    @AppUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.BomLine_MoveDown';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Look up the row and its parent state
        DECLARE @BomId     BIGINT = NULL;
        DECLARE @CurSeq    INT    = NULL;

        SELECT @BomId  = BomId,
               @CurSeq = SortOrder
        FROM Parts.BomLine WHERE Id = @Id;

        IF @BomId IS NULL
        BEGIN
            SET @Message = N'BomLine not found.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @ParentPublished  DATETIME2(3) = NULL;
        DECLARE @ParentDeprecated DATETIME2(3) = NULL;
        SELECT @ParentPublished  = PublishedAt,
               @ParentDeprecated = DeprecatedAt
        FROM Parts.Bom WHERE Id = @BomId;

        IF @ParentDeprecated IS NOT NULL
        BEGIN
            SET @Message = N'Parent BOM is deprecated (immutable).';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        IF @ParentPublished IS NOT NULL
        BEGIN
            SET @Message = N'Parent BOM is published (immutable). Create a new version to modify.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Find the nearest sibling below
        DECLARE @SwapId  BIGINT = NULL;
        DECLARE @SwapSeq INT    = NULL;

        SELECT TOP 1 @SwapId  = Id,
                     @SwapSeq = SortOrder
        FROM Parts.BomLine
        WHERE BomId = @BomId AND SortOrder > @CurSeq
        ORDER BY SortOrder ASC;

        IF @SwapId IS NULL
        BEGIN
            SET @Status  = 1;
            SET @Message = N'Already last.';
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        BEGIN TRANSACTION;

        UPDATE Parts.BomLine SET SortOrder = @SwapSeq WHERE Id = @Id;
        UPDATE Parts.BomLine SET SortOrder = @CurSeq  WHERE Id = @SwapId;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'BomLine',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'BomLine moved down.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'BomLine moved down successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'BomLine',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        SELECT @Status AS Status, @Message AS Message;

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
