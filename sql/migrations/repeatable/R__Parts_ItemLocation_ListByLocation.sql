-- =============================================
-- Procedure:   Parts.ItemLocation_ListByLocation
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns all active eligibility pairings for a given Location, joined
--   to Parts.Item (PartNumber, Description) and Parts.ItemType
--   (Name AS ItemTypeName). Only rows where both ItemLocation.DeprecatedAt
--   and Item.DeprecatedAt are NULL are returned. Ordered by
--   Item.PartNumber ascending.
--
-- Parameters:
--   @LocationId BIGINT - Required.
--
-- Result set:
--   Zero or more ItemLocation rows with PartNumber, Description, ItemTypeName.
--
-- Dependencies:
--   Tables: Parts.ItemLocation, Parts.Item, Parts.ItemType
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
--   2026-04-23 - 2.1 - Phase G.3: consumption metadata exposed (OI-18)
-- =============================================
CREATE OR ALTER PROCEDURE Parts.ItemLocation_ListByLocation
    @LocationId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        il.Id,
        il.ItemId,
        il.LocationId,
        i.PartNumber,
        i.Description,
        it.Name                AS ItemTypeName,
        il.MinQuantity,
        il.MaxQuantity,
        il.DefaultQuantity,
        il.IsConsumptionPoint,
        il.CreatedAt,
        il.DeprecatedAt
    FROM Parts.ItemLocation il
    INNER JOIN Parts.Item i
        ON i.Id = il.ItemId
    INNER JOIN Parts.ItemType it
        ON it.Id = i.ItemTypeId
    WHERE il.LocationId = @LocationId
      AND il.DeprecatedAt IS NULL
      AND i.DeprecatedAt  IS NULL
    ORDER BY i.PartNumber ASC;
END;
GO
