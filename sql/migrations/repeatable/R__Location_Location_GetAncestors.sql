-- =============================================
-- Procedure:   Location.Location_GetAncestors
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Walks UP the location hierarchy from the given node to the root
--   using a recursive CTE via ParentLocationId. Returns the node itself
--   (Depth=0) plus every ancestor up to the root.
--   Read-only proc — empty result means location not found.
--
-- Parameters:
--   @LocationId BIGINT - Starting location. Required.
--
-- Result set:
--   Id, ParentLocationId, Name, Code, LocationTypeDefinitionId,
--   DefinitionName, TypeName, HierarchyLevel, SortOrder, Depth, Icon
--   Ordered root-first (Depth DESC).
--
-- Dependencies:
--   Tables: Location.Location, Location.LocationTypeDefinition, Location.LocationType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-13 - 1.1 - Added Icon column from LocationTypeDefinition
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.Location_GetAncestors
    @LocationId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Ancestors AS (
        -- anchor: the node itself
        SELECT l.Id, l.ParentLocationId, l.Name, l.Code,
               l.LocationTypeDefinitionId, l.SortOrder,
               0 AS Depth
        FROM Location.Location l
        WHERE l.Id = @LocationId

        UNION ALL

        -- recursive: walk to parent
        SELECT p.Id, p.ParentLocationId, p.Name, p.Code,
               p.LocationTypeDefinitionId, p.SortOrder,
               a.Depth + 1
        FROM Location.Location p
        INNER JOIN Ancestors a ON a.ParentLocationId = p.Id
    )
    SELECT an.Id, an.ParentLocationId, an.Name, an.Code,
           an.LocationTypeDefinitionId, d.Name AS DefinitionName,
           lt.Name AS TypeName, lt.HierarchyLevel,
           d.Icon, an.SortOrder, an.Depth
    FROM Ancestors an
    INNER JOIN Location.LocationTypeDefinition d ON d.Id = an.LocationTypeDefinitionId
    INNER JOIN Location.LocationType lt ON lt.Id = d.LocationTypeId
    ORDER BY an.Depth DESC;
END;
GO
