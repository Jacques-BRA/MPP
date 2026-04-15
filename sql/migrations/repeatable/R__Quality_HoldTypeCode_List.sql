-- =============================================
-- Procedure:   Quality.HoldTypeCode_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns all HoldTypeCode rows ordered by Code. Read-only code table.
--
-- Parameters:
--   None.
--
-- Result set:
--   All rows from Quality.HoldTypeCode.
--
-- Dependencies:
--   Tables: Quality.HoldTypeCode
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Quality.HoldTypeCode_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name
    FROM Quality.HoldTypeCode
    ORDER BY Code;
END;
GO
