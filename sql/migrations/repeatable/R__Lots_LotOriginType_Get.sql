-- =============================================
-- Procedure:   Lots.LotOriginType_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns a single LotOriginType row by Id, or an empty result set if
--   not found.
--
-- Parameters:`n--   @Id BIGINT  - PK of the entity to retrieve. Required.
--
-- Result set:
--   Zero or one row from Lots.LotOriginType.
--
-- Dependencies:
--   Tables: Lots.LotOriginType
--
-- Change Log:
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Lots.LotOriginType_Get
    @Id      BIGINT
AS
BEGIN
    SET NOCOUNT ON;        SELECT Id, Code, Name
        FROM Lots.LotOriginType
        WHERE Id = @Id;
END;
GO

