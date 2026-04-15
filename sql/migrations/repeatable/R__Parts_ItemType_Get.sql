-- =============================================
-- Procedure:   Parts.ItemType_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns a single ItemType row by Id. Empty result = not found.
--
-- Parameters:
--   @Id BIGINT - PK of the ItemType to retrieve. Required.
--
-- Result set:
--   Zero or one row from Parts.ItemType.
--
-- Dependencies:
--   Tables: Parts.ItemType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.ItemType_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, Description, CreatedAt, DeprecatedAt
    FROM Parts.ItemType
    WHERE Id = @Id;
END;
GO
