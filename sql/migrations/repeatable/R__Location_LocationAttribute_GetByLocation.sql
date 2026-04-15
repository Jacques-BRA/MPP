-- =============================================
-- Procedure:   Location.LocationAttribute_GetByLocation
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns all attribute values for a given LocationId, joined to
--   their attribute definitions. Ordered by definition SortOrder ASC.
--   Read-only proc — empty result means no attributes are set.
--
-- Parameters:
--   @LocationId BIGINT - FK to Location. Required.
--
-- Result set:
--   LocationAttribute columns plus definition metadata, ordered by
--   LocationAttributeDefinition.SortOrder ASC.
--
-- Dependencies:
--   Tables: Location.LocationAttribute, Location.LocationAttributeDefinition
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationAttribute_GetByLocation
    @LocationId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        la.Id,
        la.LocationId,
        la.LocationAttributeDefinitionId,
        la.AttributeValue,
        la.CreatedAt,
        la.UpdatedAt,
        la.UpdatedByUserId,
        lad.AttributeName,
        lad.DataType,
        lad.IsRequired,
        lad.DefaultValue,
        lad.Uom,
        lad.SortOrder,
        lad.Description
    FROM Location.LocationAttribute la
    INNER JOIN Location.LocationAttributeDefinition lad
        ON lad.Id = la.LocationAttributeDefinitionId
    WHERE la.LocationId = @LocationId
    ORDER BY lad.SortOrder ASC;
END;
GO
