-- =============================================
-- Procedure:   Oee.DowntimeReasonCode_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-15
-- Version:     1.0
--
-- Description:
--   Returns downtime reason codes with joined Area name,
--   reason-type name, and source-code name. Optional filters for
--   Area and reason type. Deprecated rows excluded by default.
--
-- Parameters (input):
--   @AreaLocationId       BIGINT NULL - Filter by Area.
--   @DowntimeReasonTypeId BIGINT NULL - Filter by reason type.
--   @IncludeDeprecated    BIT         - If 0 (default), excludes deprecated.
--
-- Returns (result set):
--   All matching downtime reason codes ordered by AreaName, Code.
--
-- Dependencies:
--   Tables: Oee.DowntimeReasonCode, Location.Location,
--           Oee.DowntimeReasonType, Oee.DowntimeSourceCode
--
-- Change Log:
--   2026-04-15 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Oee.DowntimeReasonCode_List
    @AreaLocationId       BIGINT = NULL,
    @DowntimeReasonTypeId BIGINT = NULL,
    @IncludeDeprecated    BIT    = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        drc.Id,
        drc.Code,
        drc.Description,
        drc.AreaLocationId,
        loc.Name            AS AreaName,
        drc.DowntimeReasonTypeId,
        drt.Name            AS ReasonTypeName,
        drc.DowntimeSourceCodeId,
        dsc.Name            AS SourceCodeName,
        drc.IsExcused,
        drc.CreatedAt,
        drc.DeprecatedAt
    FROM Oee.DowntimeReasonCode drc
    LEFT JOIN Location.Location      loc ON drc.AreaLocationId       = loc.Id
    LEFT JOIN Oee.DowntimeReasonType drt ON drc.DowntimeReasonTypeId = drt.Id
    LEFT JOIN Oee.DowntimeSourceCode dsc ON drc.DowntimeSourceCodeId = dsc.Id
    WHERE (@IncludeDeprecated = 1 OR drc.DeprecatedAt IS NULL)
      AND (@AreaLocationId       IS NULL OR drc.AreaLocationId       = @AreaLocationId)
      AND (@DowntimeReasonTypeId IS NULL OR drc.DowntimeReasonTypeId = @DowntimeReasonTypeId)
    ORDER BY loc.Name, drc.Code;
END
GO
