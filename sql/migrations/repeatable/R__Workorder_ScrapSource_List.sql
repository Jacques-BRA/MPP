-- =============================================
-- Procedure:   Workorder.ScrapSource_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Returns all ScrapSource rows (Inventory, Location). Read-only
--   code table seeded at migration 0010 (OI-20).
--
-- Parameters:
--   None.
--
-- Result set:
--   Id, Code, Name, Description.
--
-- Dependencies:
--   Tables: Workorder.ScrapSource
-- =============================================
CREATE OR ALTER PROCEDURE Workorder.ScrapSource_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, Description
    FROM Workorder.ScrapSource
    ORDER BY Id;
END;
GO
