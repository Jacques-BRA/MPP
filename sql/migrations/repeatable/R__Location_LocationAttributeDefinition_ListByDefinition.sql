-- =============================================
-- Procedure:   Location.LocationAttributeDefinition_ListByDefinition
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns LocationAttributeDefinition rows for a given
--   LocationTypeDefinitionId, ordered by SortOrder ASC.
--   Optionally includes deprecated rows.
--   Read-only proc — empty result means no matching rows.
--
-- Parameters:
--   @LocationTypeDefinitionId BIGINT - FK to LocationTypeDefinition. Required.
--   @IncludeDeprecated BIT = 0      - When 1, includes deprecated definitions.
--
-- Result set:
--   LocationAttributeDefinition columns ordered by SortOrder ASC.
--
-- Dependencies:
--   Tables: Location.LocationAttributeDefinition
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationAttributeDefinition_ListByDefinition
    @LocationTypeDefinitionId BIGINT,
    @IncludeDeprecated        BIT = 0
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
    WHERE lad.LocationTypeDefinitionId = @LocationTypeDefinitionId
      AND (@IncludeDeprecated = 1 OR lad.DeprecatedAt IS NULL)
    ORDER BY lad.SortOrder ASC;
END;
GO
