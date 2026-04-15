-- =============================================
-- Procedure:   Oee.DowntimeSourceCode_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns all DowntimeSourceCode rows ordered by Code. Read-only code table.
--
-- Parameters:`n--   None.
--
-- Result set:
--   All rows from Oee.DowntimeSourceCode.
--
-- Dependencies:
--   Tables: Oee.DowntimeSourceCode
--
-- Change Log:
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Oee.DowntimeSourceCode_List
AS
BEGIN
    SET NOCOUNT ON;        SELECT Id, Code, Name
        FROM Oee.DowntimeSourceCode
        ORDER BY Code;
END;
GO

