-- =============================================
-- Procedure:   Lots.ContainerStatusCode_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns all ContainerStatusCode rows ordered by Code. Read-only code table.
--
-- Parameters:
--   None.
--
-- Result set:
--   All rows from Lots.ContainerStatusCode.
--
-- Dependencies:
--   Tables: Lots.ContainerStatusCode
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Lots.ContainerStatusCode_List
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name
    FROM Lots.ContainerStatusCode
    ORDER BY Code;
END;
GO
