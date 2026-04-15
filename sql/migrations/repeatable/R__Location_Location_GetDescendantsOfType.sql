-- =============================================
-- Procedure:   Location.Location_GetDescendantsOfType
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Walks DOWN the location hierarchy from the given node using a
--   recursive CTE, then filters results to only those whose
--   LocationTypeDefinition.LocationTypeId matches @LocationTypeId.
--   Excludes the root node itself and deprecated descendants.
--   Read-only proc — empty result means no matching descendants.
--
-- Parameters:
--   @LocationId     BIGINT - Starting location. Required.
--   @LocationTypeId BIGINT - LocationType.Id to filter by. Required.
--
-- Result set:
--   Id, ParentLocationId, Name, Code, LocationTypeDefinitionId,
--   DefinitionName, SortOrder, Description, Icon
--   Ordered by Name.
--
-- Dependencies:
--   Tables: Location.Location, Location.LocationTypeDefinition, Location.LocationType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-13 - 1.1 - Added Icon column from LocationTypeDefinition
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.Location_GetDescendantsOfType
    @LocationId     BIGINT,
    @LocationTypeId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Descendants AS (
        -- anchor: the root node (excluded from final output)
        SELECT l.Id, l.ParentLocationId, l.Name, l.Code,
               l.LocationTypeDefinitionId, l.SortOrder,
               l.Description,
               1 AS IsRoot
        FROM Location.Location l
        WHERE l.Id = @LocationId

        UNION ALL

        -- recursive: active children only
        SELECT c.Id, c.ParentLocationId, c.Name, c.Code,
               c.LocationTypeDefinitionId, c.SortOrder,
               c.Description,
               0 AS IsRoot
        FROM Location.Location c
        INNER JOIN Descendants d ON d.Id = c.ParentLocationId
        WHERE c.DeprecatedAt IS NULL
    )
    SELECT ds.Id, ds.ParentLocationId, ds.Name, ds.Code,
           ds.LocationTypeDefinitionId, def.Name AS DefinitionName,
           ds.SortOrder, ds.Description, def.Icon
    FROM Descendants ds
    INNER JOIN Location.LocationTypeDefinition def ON def.Id = ds.LocationTypeDefinitionId
    WHERE ds.IsRoot = 0
      AND def.LocationTypeId = @LocationTypeId
    ORDER BY ds.Name;
END;
GO
