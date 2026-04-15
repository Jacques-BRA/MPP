-- =============================================
-- Procedure:   Parts.Bom_WhereUsedByChildItem
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns BomLine rows referencing the given child Item, joined to the
--   parent Bom and parent Item for context. Answers "where is this
--   component used?" across BOMs. When @ActiveOnly = 1, excludes
--   BomLines whose parent Bom is deprecated.
--
-- Parameters:
--   @ChildItemId BIGINT    - Required.
--   @ActiveOnly  BIT = 1   - When 1, excludes rows where the parent Bom is deprecated.
--
-- Result set:
--   Zero or more BomLine rows with parent Bom header and parent Item info.
--
-- Dependencies:
--   Tables: Parts.BomLine, Parts.Bom, Parts.Item, Parts.Uom
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.Bom_WhereUsedByChildItem
    @ChildItemId BIGINT,
    @ActiveOnly  BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        bl.Id            AS BomLineId,
        bl.BomId,
        b.ParentItemId,
        pi.PartNumber    AS ParentPartNumber,
        pi.Description   AS ParentDescription,
        b.VersionNumber,
        b.PublishedAt,
        b.DeprecatedAt,
        bl.QtyPer,
        bl.UomId,
        u.Code           AS UomCode
    FROM Parts.BomLine bl
    INNER JOIN Parts.Bom b   ON b.Id  = bl.BomId
    INNER JOIN Parts.Item pi ON pi.Id = b.ParentItemId
    INNER JOIN Parts.Uom u   ON u.Id  = bl.UomId
    WHERE bl.ChildItemId = @ChildItemId
      AND (@ActiveOnly = 0 OR b.DeprecatedAt IS NULL)
    ORDER BY pi.PartNumber, b.VersionNumber DESC;
END;
GO
