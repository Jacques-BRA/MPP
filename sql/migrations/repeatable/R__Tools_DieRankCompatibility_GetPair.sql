-- =============================================
-- Procedure:   Tools.DieRankCompatibility_GetPair
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
--
-- Description:
--   Returns the compatibility row for a specific rank pair, direction-
--   independent. Canonicalises input so (A, B) and (B, A) resolve to
--   the same stored row (CHECK enforces RankAId <= RankBId at the
--   storage level; this proc mirrors the convention for queries).
--   Empty result = pair not defined (merge proc treats unresolved
--   pairs as reject-with-supervisor-override).
-- =============================================
CREATE OR ALTER PROCEDURE Tools.DieRankCompatibility_GetPair
    @RankA BIGINT,
    @RankB BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LoId BIGINT = CASE WHEN @RankA <= @RankB THEN @RankA ELSE @RankB END;
    DECLARE @HiId BIGINT = CASE WHEN @RankA <= @RankB THEN @RankB ELSE @RankA END;

    SELECT
        drc.Id,
        drc.RankAId,
        drA.Code            AS RankACode,
        drc.RankBId,
        drB.Code            AS RankBCode,
        drc.CanMix,
        drc.CreatedAt,
        drc.UpdatedAt
    FROM Tools.DieRankCompatibility drc
    INNER JOIN Tools.DieRank drA ON drA.Id = drc.RankAId
    INNER JOIN Tools.DieRank drB ON drB.Id = drc.RankBId
    WHERE drc.RankAId = @LoId
      AND drc.RankBId = @HiId;
END;
GO
