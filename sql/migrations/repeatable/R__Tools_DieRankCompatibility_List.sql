-- =============================================
-- Procedure:   Tools.DieRankCompatibility_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
--
-- Description:
--   Returns all DieRankCompatibility rows joined to DieRank twice
--   (once per axis) for display. Ordered by RankA.SortOrder,
--   RankB.SortOrder.
-- =============================================
CREATE OR ALTER PROCEDURE Tools.DieRankCompatibility_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        drc.Id,
        drc.RankAId,
        drA.Code            AS RankACode,
        drA.Name            AS RankAName,
        drc.RankBId,
        drB.Code            AS RankBCode,
        drB.Name            AS RankBName,
        drc.CanMix,
        drc.CreatedAt,
        drc.UpdatedAt
    FROM Tools.DieRankCompatibility drc
    INNER JOIN Tools.DieRank drA ON drA.Id = drc.RankAId
    INNER JOIN Tools.DieRank drB ON drB.Id = drc.RankBId
    ORDER BY drA.SortOrder, drB.SortOrder;
END;
GO
