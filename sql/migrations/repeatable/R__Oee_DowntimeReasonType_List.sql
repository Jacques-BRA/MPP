-- =============================================
-- Procedure:   Oee.DowntimeReasonType_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-15
-- Version:     1.0
--
-- Description:
--   Returns all downtime reason types (read-only seed table).
--   Six fixed rows at Ids 1-6.
--
-- Parameters (input):
--   (none)
--
-- Returns (result set):
--   All rows from Oee.DowntimeReasonType.
--
-- Dependencies:
--   Tables: Oee.DowntimeReasonType
--
-- Change Log:
--   2026-04-15 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Oee.DowntimeReasonType_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        Code,
        Name
    FROM Oee.DowntimeReasonType
    ORDER BY Id;
END
GO
