-- =============================================
-- Procedure:   Tools.DieRankCompatibility_Upsert
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Upserts a compatibility row for a rank pair. Canonicalises
--   (RankA, RankB) to (smaller-Id, larger-Id) so (A, B) and (B, A)
--   write the same row. CanMix = 1 allows cross-die merges of lots
--   with these two ranks; CanMix = 0 blocks them. Self-pairs
--   (RankAId = RankBId) are permitted (same-rank compatibility is
--   trivially true but the row is still valid for explicit storage).
-- =============================================
CREATE OR ALTER PROCEDURE Tools.DieRankCompatibility_Upsert
    @RankA     BIGINT,
    @RankB     BIGINT,
    @CanMix    BIT,
    @AppUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Tools.DieRankCompatibility_Upsert';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @RankA AS RankA, @RankB AS RankB, @CanMix AS CanMix
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @RankA IS NULL OR @RankB IS NULL OR @CanMix IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DieRankCompatibility',
                @EntityId = NULL, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tools.DieRank WHERE Id = @RankA AND DeprecatedAt IS NULL)
           OR NOT EXISTS (SELECT 1 FROM Tools.DieRank WHERE Id = @RankB AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'One or both DieRankIds are invalid or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DieRankCompatibility',
                @EntityId = NULL, @LogEventTypeCode = N'Updated',
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

        BEGIN TRANSACTION;

        IF @ExistingId IS NULL
        BEGIN
            INSERT INTO Tools.DieRankCompatibility (RankAId, RankBId, CanMix, CreatedAt)
            VALUES (@LoId, @HiId, @CanMix, SYSUTCDATETIME());
        END
        ELSE
        BEGIN
            UPDATE Tools.DieRankCompatibility
            SET CanMix    = @CanMix,
                UpdatedAt = SYSUTCDATETIME()
            WHERE Id = @ExistingId;
        END

        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT @OldCanMix AS CanMix FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        -- Capture the Id for the audit log: existing row's Id if we updated,
        -- or the newly-inserted Id. Resolved via a lookup because IDENT
        -- scope may be stale after the IF/ELSE branch.
        DECLARE @AuditId BIGINT;
        SELECT @AuditId = Id
        FROM Tools.DieRankCompatibility
        WHERE RankAId = @LoId AND RankBId = @HiId;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'DieRankCompatibility',
            @EntityId          = @AuditId,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'DieRankCompatibility upserted.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'DieRankCompatibility upserted successfully.';
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
                @EntityId = NULL, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH END CATCH

        SELECT @Status AS Status, @Message AS Message;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
