-- =============================================
-- Procedure:   Tools.DieRank_MoveDown
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Moves a DieRank down in the sort order by swapping SortOrder with
--   the nearest active sibling below. No-op (Status=1) if already
--   at the bottom.
-- =============================================
CREATE OR ALTER PROCEDURE Tools.DieRank_MoveDown
    @Id        BIGINT,
    @AppUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Tools.DieRank_MoveDown';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DieRank',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @CurrentSort INT;
        SELECT @CurrentSort = SortOrder
        FROM Tools.DieRank
        WHERE Id = @Id AND DeprecatedAt IS NULL;

        IF @CurrentSort IS NULL
        BEGIN
            SET @Message = N'DieRank not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DieRank',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @SwapId BIGINT, @SwapSort INT;
        SELECT TOP 1 @SwapId = Id, @SwapSort = SortOrder
        FROM Tools.DieRank
        WHERE DeprecatedAt IS NULL AND SortOrder > @CurrentSort
        ORDER BY SortOrder ASC;

        IF @SwapId IS NULL
        BEGIN
            SET @Status  = 1;
            SET @Message = N'Already at the bottom position.';
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT @Id AS Id, @CurrentSort AS OldSortOrder,
                    @SwapId AS SwapId, @SwapSort AS SwapOldSortOrder
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        DECLARE @NewValue NVARCHAR(MAX) =
            (SELECT @Id AS Id, @SwapSort AS NewSortOrder,
                    @SwapId AS SwapId, @CurrentSort AS SwapNewSortOrder
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Tools.DieRank SET SortOrder = @SwapSort    WHERE Id = @Id;
        UPDATE Tools.DieRank SET SortOrder = @CurrentSort WHERE Id = @SwapId;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'DieRank',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'DieRank moved down.',
            @OldValue          = @OldValue,
            @NewValue          = @NewValue;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'DieRank moved down successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DieRank',
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
