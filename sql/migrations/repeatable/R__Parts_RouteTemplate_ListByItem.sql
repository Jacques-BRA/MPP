-- =============================================
-- Procedure:   Parts.RouteTemplate_ListByItem
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns RouteTemplate rows for the given Item, joined to Location.AppUser
--   for the CreatedByUser display name. Ordered by VersionNumber DESC
--   (newest first). When @ActiveOnly = 1, excludes deprecated routes.
--
-- Parameters:
--   @ItemId     BIGINT    - Required.
--   @ActiveOnly BIT = 1   - When 1, excludes DeprecatedAt rows.
--
-- Result set:
--   Zero or more RouteTemplate rows, newest version first.
--
-- Dependencies:
--   Tables: Parts.RouteTemplate, Location.AppUser
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.RouteTemplate_ListByItem
    @ItemId     BIGINT,
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        rt.Id,
        rt.ItemId,
        rt.VersionNumber,
        rt.Name,
        rt.EffectiveFrom,
        rt.PublishedAt,
        rt.DeprecatedAt,
        rt.CreatedByUserId,
        u.DisplayName AS CreatedByDisplayName,
        rt.CreatedAt
    FROM Parts.RouteTemplate rt
    INNER JOIN Location.AppUser u ON u.Id = rt.CreatedByUserId
    WHERE rt.ItemId = @ItemId
      AND (@ActiveOnly = 0 OR rt.DeprecatedAt IS NULL)
    ORDER BY rt.VersionNumber DESC;
END;
GO
