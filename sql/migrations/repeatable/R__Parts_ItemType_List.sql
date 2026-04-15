-- =============================================
-- Procedure:   Parts.ItemType_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns ItemType rows ordered by Code. Mutable code table; supports
--   optional inclusion of deprecated rows.
--
-- Parameters:
--   @IncludeDeprecated BIT = 0 - When 1, includes deprecated rows.
--
-- Result set:
--   Rows from Parts.ItemType filtered by @IncludeDeprecated.
--
-- Dependencies:
--   Tables: Parts.ItemType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.ItemType_List
    @IncludeDeprecated BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, Description, CreatedAt, DeprecatedAt
    FROM Parts.ItemType
    WHERE (@IncludeDeprecated = 1 OR DeprecatedAt IS NULL)
    ORDER BY Code;
END;
GO
