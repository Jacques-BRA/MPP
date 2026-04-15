-- =============================================
-- Procedure:   Location.LocationTypeDefinition_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns a single LocationTypeDefinition row by Id, joined to
--   LocationType.Name for display.
--   Read-only proc — empty result means not found.
--
-- Parameters:
--   @Id BIGINT  - PK of the LocationTypeDefinition to retrieve. Required.
--
-- Result set:
--   Zero or one row from Location.LocationTypeDefinition with
--   LocationTypeName from the parent LocationType.
--
-- Dependencies:
--   Tables: Location.LocationTypeDefinition, Location.LocationType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-13 - 1.1 - Added Icon column to result set
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationTypeDefinition_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ltd.Id,
        ltd.LocationTypeId,
        lt.Name            AS LocationTypeName,
        ltd.Code,
        ltd.Name,
        ltd.Description,
        ltd.Icon,
        ltd.CreatedAt,
        ltd.DeprecatedAt
    FROM Location.LocationTypeDefinition ltd
    INNER JOIN Location.LocationType lt
        ON lt.Id = ltd.LocationTypeId
    WHERE ltd.Id = @Id;
END;
GO
