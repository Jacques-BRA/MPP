-- =============================================
-- Procedure:   Tools.ToolStatusCode_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Returns all ToolStatusCode rows ordered by Id (preserves seeded
--   order: Active, UnderRepair, Scrapped, Retired). Read-only code
--   table; no CRUD procs.
--
-- Parameters:
--   None.
--
-- Result set:
--   Id, Code, Name, Description.
--
-- Dependencies:
--   Tables: Tools.ToolStatusCode
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolStatusCode_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, Description
    FROM Tools.ToolStatusCode
    ORDER BY Id;
END;
GO
