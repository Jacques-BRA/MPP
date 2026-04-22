-- =============================================
-- Procedure:   Tools.ToolCavityStatusCode_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Returns all ToolCavityStatusCode rows ordered by Id (preserves
--   seeded order: Active, Closed, Scrapped). Read-only code table.
--
-- Parameters:
--   None.
--
-- Result set:
--   Id, Code, Name, Description.
--
-- Dependencies:
--   Tables: Tools.ToolCavityStatusCode
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolCavityStatusCode_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, Description
    FROM Tools.ToolCavityStatusCode
    ORDER BY Id;
END;
GO
