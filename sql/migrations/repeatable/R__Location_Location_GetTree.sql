-- =============================================
-- Procedure:   Location.Location_GetTree
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns the full subtree rooted at the specified Location using a
--   recursive CTE. Only active (non-deprecated) descendants are included;
--   the root node itself is always returned regardless of DeprecatedAt.
--   Builds a MaterializedPath (Name > Name > ...) for display and a
--   zero-padded SortPath for depth-first ordering — enabling single-pass
--   tree assembly in Ignition (parent always precedes its children).
--   Read-only proc — empty result means location not found.
--
-- Parameters:
--   @RootLocationId BIGINT - Starting location. Required.
--
-- Result set:
--   Id, ParentLocationId, Name, Code, LocationTypeDefinitionId,
--   DefinitionName, TypeName, HierarchyLevel, SortOrder, Description,
--   DeprecatedAt, Depth (0=root), MaterializedPath, SortPath, Icon
--
-- Dependencies:
--   Tables: Location.Location, Location.LocationTypeDefinition, Location.LocationType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-13 - 1.1 - Added zero-padded SortPath column for depth-first ordering
--   2026-04-13 - 1.2 - Added Icon column from LocationTypeDefinition
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.Location_GetTree
    @RootLocationId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Tree AS (
        -- anchor
        SELECT l.Id, l.ParentLocationId, l.Name, l.Code,
               l.LocationTypeDefinitionId, l.SortOrder,
               l.Description, l.DeprecatedAt,
               0 AS Depth,
               CAST(l.Name AS NVARCHAR(MAX)) AS MaterializedPath,
               CAST(RIGHT('0000' + CAST(l.SortOrder AS NVARCHAR(5)), 5) AS NVARCHAR(MAX)) AS SortPath
        FROM Location.Location l
        WHERE l.Id = @RootLocationId

        UNION ALL

        -- recursive: active children only
        SELECT c.Id, c.ParentLocationId, c.Name, c.Code,
               c.LocationTypeDefinitionId, c.SortOrder,
               c.Description, c.DeprecatedAt,
               t.Depth + 1,
               t.MaterializedPath + N' > ' + c.Name,
               t.SortPath + N'.' + RIGHT('0000' + CAST(c.SortOrder AS NVARCHAR(5)), 5)
        FROM Location.Location c
        INNER JOIN Tree t ON t.Id = c.ParentLocationId
        WHERE c.DeprecatedAt IS NULL
    )
    SELECT tr.Id, tr.ParentLocationId, tr.Name, tr.Code,
           tr.LocationTypeDefinitionId, d.Name AS DefinitionName,
           lt.Name AS TypeName, lt.HierarchyLevel,
           tr.SortOrder, tr.Description, tr.DeprecatedAt,
           tr.Depth, tr.MaterializedPath, tr.SortPath,
           d.Icon
    FROM Tree tr
    INNER JOIN Location.LocationTypeDefinition d ON d.Id = tr.LocationTypeDefinitionId
    INNER JOIN Location.LocationType lt ON lt.Id = d.LocationTypeId
    ORDER BY tr.SortPath;
END;
GO
