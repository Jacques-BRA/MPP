-- =============================================
-- Procedure:   Parts.RouteTemplate_GetActiveForItem
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns the single active RouteTemplate row for the given Item, as of
--   @AsOfDate (default: now). "Active" means:
--     PublishedAt IS NOT NULL AND PublishedAt <= @AsOfDate
--     AND EffectiveFrom <= @AsOfDate
--     AND (DeprecatedAt IS NULL OR DeprecatedAt > @AsOfDate)
--   Of all matching rows, the highest VersionNumber wins (TOP 1).
--
--   Draft routes (PublishedAt IS NULL) are INVISIBLE to production.
--
--   Header only — callers needing steps should call Parts.RouteTemplate_Get.
--
-- Parameters:
--   @ItemId BIGINT           - Required.
--   @AsOfDate DATETIME2 NULL - Evaluation point-in-time. Defaults to SYSUTCDATETIME().
--
-- Result set:
--   Zero or one RouteTemplate row.
--
-- Dependencies:
--   Tables: Parts.RouteTemplate, Parts.Item, Location.AppUser
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 1.1 - Added PublishedAt filter (Draft routes invisible)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.RouteTemplate_GetActiveForItem
    @ItemId   BIGINT,
    @AsOfDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AsOf DATETIME2(3) = ISNULL(@AsOfDate, SYSUTCDATETIME());

    SELECT TOP 1
        rt.Id,
        rt.ItemId,
        i.PartNumber,
        rt.VersionNumber,
        rt.Name,
        rt.EffectiveFrom,
        rt.PublishedAt,
        rt.DeprecatedAt,
        rt.CreatedByUserId,
        u.DisplayName AS CreatedByDisplayName,
        rt.CreatedAt
    FROM Parts.RouteTemplate rt
    INNER JOIN Parts.Item i       ON i.Id = rt.ItemId
    INNER JOIN Location.AppUser u ON u.Id = rt.CreatedByUserId
    WHERE rt.ItemId = @ItemId
      AND rt.PublishedAt IS NOT NULL
      AND rt.PublishedAt <= @AsOf
      AND rt.EffectiveFrom <= @AsOf
      AND (rt.DeprecatedAt IS NULL OR rt.DeprecatedAt > @AsOf)
    ORDER BY rt.VersionNumber DESC;
END;
GO
