-- =============================================
-- Procedure:   Parts.Bom_GetActiveForItem
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns the single active Bom row for the given parent Item, as of
--   @AsOfDate (default: now). "Active" means:
--     PublishedAt IS NOT NULL AND PublishedAt <= @AsOfDate
--     AND EffectiveFrom <= @AsOfDate
--     AND (DeprecatedAt IS NULL OR DeprecatedAt > @AsOfDate)
--   Of all matching rows, the highest VersionNumber wins (TOP 1).
--
--   Draft BOMs (PublishedAt IS NULL) are INVISIBLE to production.
--
--   Header only — callers needing lines should call Parts.Bom_Get.
--
-- Parameters:
--   @ParentItemId BIGINT     - Required.
--   @AsOfDate DATETIME2 NULL - Evaluation point-in-time. Defaults to SYSUTCDATETIME().
--
-- Result set:
--   Zero or one Bom row.
--
-- Dependencies:
--   Tables: Parts.Bom, Parts.Item, Location.AppUser
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.Bom_GetActiveForItem
    @ParentItemId BIGINT,
    @AsOfDate     DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AsOf DATETIME2(3) = ISNULL(@AsOfDate, SYSUTCDATETIME());

    SELECT TOP 1
        b.Id,
        b.ParentItemId,
        i.PartNumber,
        b.VersionNumber,
        b.EffectiveFrom,
        b.PublishedAt,
        b.DeprecatedAt,
        b.CreatedByUserId,
        u.DisplayName AS CreatedByDisplayName,
        b.CreatedAt
    FROM Parts.Bom b
    INNER JOIN Parts.Item i       ON i.Id = b.ParentItemId
    INNER JOIN Location.AppUser u ON u.Id = b.CreatedByUserId
    WHERE b.ParentItemId = @ParentItemId
      AND b.PublishedAt IS NOT NULL
      AND b.PublishedAt <= @AsOf
      AND b.EffectiveFrom <= @AsOf
      AND (b.DeprecatedAt IS NULL OR b.DeprecatedAt > @AsOf)
    ORDER BY b.VersionNumber DESC;
END;
GO
