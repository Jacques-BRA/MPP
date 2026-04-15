-- =============================================
-- Procedure:   Parts.OperationTemplate_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns OperationTemplate rows joined to Location.Location for the
--   AreaName. Optionally filters to a single Area and/or excludes
--   deprecated rows.
--
-- Parameters:
--   @AreaLocationId BIGINT = NULL - When supplied, filters to this Area.
--   @ActiveOnly     BIT    = 1    - When 1, excludes DeprecatedAt rows.
--
-- Result set:
--   Zero or more OperationTemplate rows with joined AreaName, ordered by
--   Code, VersionNumber.
--
-- Dependencies:
--   Tables: Parts.OperationTemplate, Location.Location
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.OperationTemplate_List
    @AreaLocationId BIGINT = NULL,
    @ActiveOnly     BIT    = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ot.Id,
        ot.Code,
        ot.VersionNumber,
        ot.Name,
        ot.AreaLocationId,
        l.Name           AS AreaName,
        ot.Description,
        ot.CreatedAt,
        ot.DeprecatedAt
    FROM Parts.OperationTemplate ot
    INNER JOIN Location.Location l ON l.Id = ot.AreaLocationId
    WHERE (@AreaLocationId IS NULL OR ot.AreaLocationId = @AreaLocationId)
      AND (@ActiveOnly = 0 OR ot.DeprecatedAt IS NULL)
    ORDER BY ot.Code, ot.VersionNumber;
END;
GO
