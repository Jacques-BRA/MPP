-- =============================================
-- Procedure:   Workorder.OperationStatus_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns all OperationStatus rows ordered by Code. Read-only code table.
--
-- Parameters:`n--   None.
--
-- Result set:
--   All rows from Workorder.OperationStatus.
--
-- Dependencies:
--   Tables: Workorder.OperationStatus
--
-- Change Log:
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Workorder.OperationStatus_List
AS
BEGIN
    SET NOCOUNT ON;        SELECT Id, Code, Name
        FROM Workorder.OperationStatus
        ORDER BY Code;
END;
GO

