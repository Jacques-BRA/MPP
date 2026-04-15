-- =============================================
-- Procedure:   Quality.DefectCode_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Returns a single defect code by Id.
--
-- Parameters (input):
--   @Id BIGINT - Required.
--
-- Returns (result set):
--   Single row with all defect code fields.
--
-- Dependencies:
--   Tables: Quality.DefectCode, Location.Location
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Quality.DefectCode_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        dc.Id,
        dc.Code,
        dc.Description,
        dc.AreaLocationId,
        loc.Name               AS AreaName,
        dc.IsExcused,
        dc.CreatedAt,
        dc.DeprecatedAt
    FROM Quality.DefectCode dc
    LEFT JOIN Location.Location loc ON dc.AreaLocationId = loc.Id
    WHERE dc.Id = @Id;
END
GO
