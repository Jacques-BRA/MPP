-- =============================================
-- Procedure:   Location.LocationType_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns all LocationType rows ordered by HierarchyLevel ascending.
--   Read-only proc — empty result means no rows exist.
--
-- Parameters:
--   None.
--
-- Result set:
--   All columns from Location.LocationType ordered by HierarchyLevel.
--
-- Dependencies:
--   Tables: Location.LocationType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationType_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, HierarchyLevel, Description
    FROM Location.LocationType
    ORDER BY HierarchyLevel;
END;
GO
