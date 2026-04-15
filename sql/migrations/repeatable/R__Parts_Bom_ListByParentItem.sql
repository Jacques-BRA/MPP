-- =============================================
-- Procedure:   Parts.Bom_ListByParentItem
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns Bom rows for the given parent Item, joined to Location.AppUser
--   for the CreatedByUser display name. Includes PublishedAt and DeprecatedAt
--   so the UI can badge rows as Draft/Published/Deprecated. Ordered by
--   VersionNumber DESC (newest first). When @ActiveOnly = 1, excludes
--   deprecated BOMs (Drafts still included — "active" in the editing sense).
--
-- Parameters:
--   @ParentItemId BIGINT   - Required.
--   @ActiveOnly   BIT = 1  - When 1, excludes DeprecatedAt rows.
--
-- Result set:
--   Zero or more Bom rows, newest version first.
--
-- Dependencies:
--   Tables: Parts.Bom, Location.AppUser
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.Bom_ListByParentItem
    @ParentItemId BIGINT,
    @ActiveOnly   BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        b.Id,
        b.ParentItemId,
        b.VersionNumber,
        b.EffectiveFrom,
        b.PublishedAt,
        b.DeprecatedAt,
        b.CreatedByUserId,
        u.DisplayName AS CreatedByDisplayName,
        b.CreatedAt
    FROM Parts.Bom b
    INNER JOIN Location.AppUser u ON u.Id = b.CreatedByUserId
    WHERE b.ParentItemId = @ParentItemId
      AND (@ActiveOnly = 0 OR b.DeprecatedAt IS NULL)
    ORDER BY b.VersionNumber DESC;
END;
GO
