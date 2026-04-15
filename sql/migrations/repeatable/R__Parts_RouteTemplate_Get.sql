-- =============================================
-- Procedure:   Parts.RouteTemplate_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns a single RouteTemplate row by Id, joined to Location.AppUser
--   for the CreatedByUser display name and to Parts.Item for PartNumber.
--
--   Returns the RouteTemplate header row only. Callers needing steps should
--   call Parts.RouteStep_ListByRoute with the returned Id.
--
-- Parameters:
--   @Id BIGINT - PK. Required.
--
-- Result set:
--   RouteTemplate header with joined PartNumber and CreatedByDisplayName.
--
-- Dependencies:
--   Tables: Parts.RouteTemplate, Parts.Item, Location.AppUser
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params, 2 result sets)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
--   2026-04-14 - 2.1 - Dropped 2nd result set; Ignition Named Queries
--                      only read the first. Use RouteStep_ListByRoute for steps.
-- =============================================
CREATE OR ALTER PROCEDURE Parts.RouteTemplate_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
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
    WHERE rt.Id = @Id;
END;
GO
