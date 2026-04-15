-- =============================================
-- Procedure:   Audit.LogEventType_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns all LogEventType lookup rows ordered by Code.
--   Read-only proc — empty result means no rows exist.
--
-- Parameters:
--   None.
--
-- Result set:
--   All rows from Audit.LogEventType.
--
-- Dependencies:
--   Tables: Audit.LogEventType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Audit.LogEventType_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        Code,
        Name,
        Description
    FROM Audit.LogEventType
    ORDER BY Code;
END;
GO
