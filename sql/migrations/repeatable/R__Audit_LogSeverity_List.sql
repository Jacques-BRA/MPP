-- =============================================
-- Procedure:   Audit.LogSeverity_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns all LogSeverity lookup rows ordered by Id.
--   Read-only proc — empty result means no rows exist.
--
-- Parameters:
--   None.
--
-- Result set:
--   All rows from Audit.LogSeverity.
--
-- Dependencies:
--   Tables: Audit.LogSeverity
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Audit.LogSeverity_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        Code,
        Name
    FROM Audit.LogSeverity
    ORDER BY Id;
END;
GO
