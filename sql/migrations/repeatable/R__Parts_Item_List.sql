-- =============================================
-- Procedure:   Parts.Item_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns Item rows joined to ItemType.Name and Uom.Code for display.
--   Supports optional filtering by ItemTypeId, a LIKE search on
--   PartNumber or Description, and inclusion of deprecated rows.
--
-- Parameters:
--   @ItemTypeId         BIGINT NULL        - Filter to one item type. NULL = any.
--   @SearchText         NVARCHAR(200) NULL - LIKE filter on PartNumber/Description.
--   @IncludeDeprecated  BIT = 0            - When 1, includes deprecated rows.
--
-- Result set:
--   Parts.Item rows joined to ItemType.Name (AS ItemTypeName) and
--   Uom.Code (AS UomCode), WeightUom.Code (AS WeightUomCode).
--
-- Dependencies:
--   Tables: Parts.Item, Parts.ItemType, Parts.Uom
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
--   2026-04-23 - 2.1 - Phase G.3: CountryOfOrigin exposed (OI-19)
--   2026-04-27 - 2.2 - OI-12 correction: MaxParts exposed (moved from ContainerConfig)
-- =============================================
CREATE OR ALTER PROCEDURE Parts.Item_List
    @ItemTypeId        BIGINT        = NULL,
    @SearchText        NVARCHAR(200) = NULL,
    @IncludeDeprecated BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SearchPattern NVARCHAR(210) = NULL;
    IF @SearchText IS NOT NULL AND LEN(@SearchText) > 0
        SET @SearchPattern = N'%' + @SearchText + N'%';

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
        i.CountryOfOrigin,
        i.MaxParts,
        i.CreatedAt,
        i.UpdatedAt,
        i.CreatedByUserId,
        i.UpdatedByUserId,
        i.DeprecatedAt
    FROM Parts.Item i
    INNER JOIN Parts.ItemType it ON it.Id = i.ItemTypeId
    INNER JOIN Parts.Uom u       ON u.Id  = i.UomId
    LEFT  JOIN Parts.Uom wu      ON wu.Id = i.WeightUomId
    WHERE (@ItemTypeId IS NULL OR i.ItemTypeId = @ItemTypeId)
      AND (@IncludeDeprecated = 1 OR i.DeprecatedAt IS NULL)
      AND (@SearchPattern IS NULL
           OR i.PartNumber  LIKE @SearchPattern
           OR i.Description LIKE @SearchPattern)
    ORDER BY i.PartNumber;
END;
GO
