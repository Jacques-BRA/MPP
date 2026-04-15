-- =============================================
-- Procedure:   Location.LocationTypeDefinition_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns LocationTypeDefinition rows with optional filtering
--   by LocationTypeId and deprecated status. Includes the parent
--   LocationType.Name for display purposes.
--   Read-only proc — empty result means no matching rows.
--
-- Parameters:
--   @LocationTypeId    BIGINT = NULL - Filter to a single tier. NULL = all tiers.
--   @IncludeDeprecated BIT    = 0   - When 1, includes deprecated definitions.
--
-- Result set:
--   LocationTypeDefinition columns plus LocationTypeName,
--   ordered by HierarchyLevel then Code.
--
-- Dependencies:
--   Tables: Location.LocationTypeDefinition, Location.LocationType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-13 - 1.1 - Added Icon column to result set
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationTypeDefinition_List
    @LocationTypeId    BIGINT = NULL,
    @IncludeDeprecated BIT    = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ltd.Id,
        ltd.LocationTypeId,
        lt.Name            AS LocationTypeName,
        ltd.Code,
        ltd.Name,
        ltd.Description,
        ltd.Icon,
        ltd.CreatedAt,
        ltd.DeprecatedAt
    FROM Location.LocationTypeDefinition ltd
    INNER JOIN Location.LocationType lt
        ON lt.Id = ltd.LocationTypeId
    WHERE (@LocationTypeId IS NULL OR ltd.LocationTypeId = @LocationTypeId)
      AND (@IncludeDeprecated = 1 OR ltd.DeprecatedAt IS NULL)
    ORDER BY lt.HierarchyLevel, ltd.Code;
END;
GO
