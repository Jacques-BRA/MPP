-- =============================================
-- Procedure:   Parts.ItemLocation_ListByItem
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns all active eligibility pairings for a given Item, joined to
--   Location.Location (Name, Code) and Location.LocationTypeDefinition
--   (Name AS DefinitionName). Only rows where DeprecatedAt IS NULL are
--   returned. Ordered by Location.Name ascending.
--
-- Parameters:
--   @ItemId BIGINT - Required.
--
-- Result set:
--   Zero or more ItemLocation rows with LocationName, LocationCode,
--   DefinitionName.
--
-- Dependencies:
--   Tables: Parts.ItemLocation, Location.Location,
--           Location.LocationTypeDefinition
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.ItemLocation_ListByItem
    @ItemId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        il.Id,
        il.ItemId,
        il.LocationId,
        l.Name                  AS LocationName,
        l.Code                  AS LocationCode,
        ltd.Name                AS DefinitionName,
        il.CreatedAt,
        il.DeprecatedAt
    FROM Parts.ItemLocation il
    INNER JOIN Location.Location l
        ON l.Id = il.LocationId
    INNER JOIN Location.LocationTypeDefinition ltd
        ON ltd.Id = l.LocationTypeDefinitionId
    WHERE il.ItemId = @ItemId
      AND il.DeprecatedAt IS NULL
    ORDER BY l.Name ASC;
END;
GO
