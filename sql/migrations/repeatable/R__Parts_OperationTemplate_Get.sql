-- =============================================
-- Procedure:   Parts.OperationTemplate_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns a single OperationTemplate row by Id, joined to
--   Location.Location for AreaName. Empty result = not found.
--
-- Parameters:
--   @Id BIGINT - PK. Required.
--
-- Result set:
--   Zero or one OperationTemplate row with joined AreaName.
--
-- Dependencies:
--   Tables: Parts.OperationTemplate, Location.Location
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.OperationTemplate_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ot.Id,
        ot.Code,
        ot.VersionNumber,
        ot.Name,
        ot.AreaLocationId,
        l.Name           AS AreaName,
        ot.Description,
        ot.CreatedAt,
        ot.DeprecatedAt
    FROM Parts.OperationTemplate ot
    INNER JOIN Location.Location l ON l.Id = ot.AreaLocationId
    WHERE ot.Id = @Id;
END;
GO
