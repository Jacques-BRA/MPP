-- =============================================
-- Procedure:   Lots.LotStatusCode_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns all LotStatusCode rows ordered by Code. Read-only code table
--   with a BlocksProduction flag used by production interlocks.
--
-- Parameters:`n--   None.
--
-- Result set:
--   All rows from Lots.LotStatusCode including BlocksProduction flag.
--
-- Dependencies:
--   Tables: Lots.LotStatusCode
--
-- Change Log:
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Lots.LotStatusCode_List
AS
BEGIN
    SET NOCOUNT ON;        SELECT Id, Code, Name, BlocksProduction
        FROM Lots.LotStatusCode
        ORDER BY Code;
END;
GO

