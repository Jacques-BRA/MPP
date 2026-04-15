-- =============================================
-- Procedure:   Location.LocationType_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns a single LocationType row by Id, or an empty result set
--   if not found. Read-only proc — empty result means not found.
--
-- Parameters:
--   @Id BIGINT  - PK of the LocationType to retrieve. Required.
--
-- Result set:
--   Zero or one row from Location.LocationType.
--
-- Dependencies:
--   Tables: Location.LocationType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationType_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, HierarchyLevel, Description
    FROM Location.LocationType
    WHERE Id = @Id;
END;
GO
