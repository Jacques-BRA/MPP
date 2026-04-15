-- =============================================
-- Procedure:   Parts.BomLine_ListByBom
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns all BomLine rows for the given BOM, joined to Parts.Item
--   (ChildPartNumber + ChildDescription) and Parts.Uom (UomCode).
--   Ordered by SortOrder ASC.
--
-- Parameters:
--   @BomId BIGINT - Required.
--
-- Result set:
--   Zero or more BomLine rows for the BOM, ordered by SortOrder.
--
-- Dependencies:
--   Tables: Parts.BomLine, Parts.Item, Parts.Uom
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.BomLine_ListByBom
    @BomId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        bl.Id,
        bl.BomId,
        bl.ChildItemId,
        i.PartNumber       AS ChildPartNumber,
        i.Description      AS ChildDescription,
        bl.QtyPer,
        bl.UomId,
        u.Code             AS UomCode,
        bl.SortOrder
    FROM Parts.BomLine bl
    INNER JOIN Parts.Item i ON i.Id = bl.ChildItemId
    INNER JOIN Parts.Uom  u ON u.Id = bl.UomId
    WHERE bl.BomId = @BomId
    ORDER BY bl.SortOrder ASC;
END;
GO
