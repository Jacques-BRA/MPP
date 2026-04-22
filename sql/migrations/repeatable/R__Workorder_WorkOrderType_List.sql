-- =============================================
-- Procedure:   Workorder.WorkOrderType_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Returns all WorkOrderType rows (Demand, Maintenance, Recipe).
--   Read-only code table seeded at migration 0010.
--
-- Parameters:
--   None.
--
-- Result set:
--   Id, Code, Name, Description.
--
-- Dependencies:
--   Tables: Workorder.WorkOrderType
-- =============================================
CREATE OR ALTER PROCEDURE Workorder.WorkOrderType_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, Description
    FROM Workorder.WorkOrderType
    ORDER BY Id;
END;
GO
