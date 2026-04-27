-- =============================================
-- Procedure:   Workorder.WorkOrderType_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.1  (2026-04-24 — comment corrected per OI-07)
--
-- Description:
--   Returns all WorkOrderType rows.
--   Read-only code table.
--
--   Authoritative seed (post-OI-07 correction, 2026-04-24):
--     - Production — the MVP-LITE bookkeeping flow.
--
--   Future rows (NOT seeded in MVP; added by future maintenance-engine project):
--     - Demand — planned preventative maintenance.
--     - Maintenance — emergency maintenance.
--
--   Note: Shipped migration 0010_phase9_tools_and_workorder.sql seeded 3 rows
--   (Demand / Maintenance / Recipe) at Ids 1/2/3. A follow-up versioned
--   correction migration renames Id=1 Demand→Production and DELETEs Ids 2 + 3.
--   See OIR OI-07 (v2.9) for the full narrative.
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
