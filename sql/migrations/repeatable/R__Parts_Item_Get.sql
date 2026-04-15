-- =============================================
-- Procedure:   Parts.Item_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns a single Item row by Id joined to ItemType.Name and Uom.Code
--   for display. Empty result = not found.
--
-- Parameters:
--   @Id BIGINT - PK. Required.
--
-- Result set:
--   Zero or one Item row with joined ItemTypeName, UomCode, WeightUomCode.
--
-- Dependencies:
--   Tables: Parts.Item, Parts.ItemType, Parts.Uom
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.Item_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        i.Id,
        i.ItemTypeId,
        it.Name               AS ItemTypeName,
        i.PartNumber,
        i.Description,
        i.MacolaPartNumber,
        i.DefaultSubLotQty,
        i.MaxLotSize,
        i.UomId,
        u.Code                AS UomCode,
        i.UnitWeight,
        i.WeightUomId,
        wu.Code               AS WeightUomCode,
        i.CreatedAt,
        i.UpdatedAt,
        i.CreatedByUserId,
        i.UpdatedByUserId,
        i.DeprecatedAt
    FROM Parts.Item i
    INNER JOIN Parts.ItemType it ON it.Id = i.ItemTypeId
    INNER JOIN Parts.Uom u       ON u.Id  = i.UomId
    LEFT  JOIN Parts.Uom wu      ON wu.Id = i.WeightUomId
    WHERE i.Id = @Id;
END;
GO
