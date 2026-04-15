-- =============================================
-- Procedure:   Parts.Bom_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns a single Bom row by Id, joined to Parts.Item (PartNumber) and
--   Location.AppUser (CreatedByDisplayName).
--
--   Returns the Bom header row only. Callers needing lines should call
--   Parts.BomLine_ListByBom with the returned Id.
--
-- Parameters:
--   @Id BIGINT - PK. Required.
--
-- Result set:
--   Bom header row with joined PartNumber and CreatedByDisplayName.
--
-- Dependencies:
--   Tables: Parts.Bom, Parts.Item, Location.AppUser
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params, 2 result sets)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
--   2026-04-14 - 2.1 - Dropped 2nd result set; Ignition Named Queries
--                      only read the first. Use BomLine_ListByBom for lines.
-- =============================================
CREATE OR ALTER PROCEDURE Parts.Bom_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        b.Id,
        b.ParentItemId,
        i.PartNumber,
        b.VersionNumber,
        b.EffectiveFrom,
        b.PublishedAt,
        b.DeprecatedAt,
        b.CreatedByUserId,
        u.DisplayName AS CreatedByDisplayName,
        b.CreatedAt
    FROM Parts.Bom b
    INNER JOIN Parts.Item i       ON i.Id = b.ParentItemId
    INNER JOIN Location.AppUser u ON u.Id = b.CreatedByUserId
    WHERE b.Id = @Id;
END;
GO
