-- =============================================
-- Procedure:   Tools.DieRankCompatibility_Remove
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Hard-deletes a DieRankCompatibility row for a given rank pair.
--   Canonicalises (RankA, RankB) before lookup. Idempotent:
--   no-op success if no row exists for the pair.
-- =============================================
CREATE OR ALTER PROCEDURE Tools.DieRankCompatibility_Remove
    @RankA     BIGINT,
    @RankB     BIGINT,
    @AppUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Tools.DieRankCompatibility_Remove';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @RankA AS RankA, @RankB AS RankB
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @RankA IS NULL OR @RankB IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DieRankCompatibility',
                @EntityId = NULL, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @LoId BIGINT = CASE WHEN @RankA <= @RankB THEN @RankA ELSE @RankB END;
        DECLARE @HiId BIGINT = CASE WHEN @RankA <= @RankB THEN @RankB ELSE @RankA END;

        DECLARE @ExistingId BIGINT, @OldCanMix BIT;
        SELECT @ExistingId = Id, @OldCanMix = CanMix
        FROM Tools.DieRankCompatibility
        WHERE RankAId = @LoId AND RankBId = @HiId;

        IF @ExistingId IS NULL
        BEGIN
            SET @Status  = 1;
            SET @Message = N'No compatibility row to remove (idempotent).';
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT @OldCanMix AS CanMix FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        DELETE FROM Tools.DieRankCompatibility WHERE Id = @ExistingId;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'DieRankCompatibility',
            @EntityId          = @ExistingId,
            @LogEventTypeCode  = N'Deprecated',
            @LogSeverityCode   = N'Info',
            @Description       = N'DieRankCompatibility pair removed.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'DieRankCompatibility pair removed successfully.';
        SELECT @Status AS Status, @Message AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DieRankCompatibility',
                @EntityId = NULL, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH END CATCH

        SELECT @Status AS Status, @Message AS Message;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
