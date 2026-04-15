-- =============================================
-- Procedure:   Location.LocationAttributeDefinition_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns a single LocationAttributeDefinition row by Id.
--   Read-only proc — empty result means not found.
--
-- Parameters:
--   @Id BIGINT - PK of the LocationAttributeDefinition to retrieve. Required.
--
-- Result set:
--   Zero or one row from Location.LocationAttributeDefinition.
--
-- Dependencies:
--   Tables: Location.LocationAttributeDefinition
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationAttributeDefinition_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        lad.Id,
        lad.LocationTypeDefinitionId,
        lad.AttributeName,
        lad.DataType,
        lad.IsRequired,
        lad.DefaultValue,
        lad.Uom,
        lad.SortOrder,
        lad.Description,
        lad.CreatedAt,
        lad.DeprecatedAt
    FROM Location.LocationAttributeDefinition lad
    WHERE lad.Id = @Id;
END;
GO
