-- =============================================
-- Procedure:   Oee.DowntimeSourceCode_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns a single DowntimeSourceCode row by Id, or an empty result set if
--   not found.
--
-- Parameters:`n--   @Id BIGINT  - PK of the entity to retrieve. Required.
--
-- Result set:
--   Zero or one row from Oee.DowntimeSourceCode.
--
-- Dependencies:
--   Tables: Oee.DowntimeSourceCode
--
-- Change Log:
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Oee.DowntimeSourceCode_Get
    @Id      BIGINT
AS
BEGIN
    SET NOCOUNT ON;        SELECT Id, Code, Name
        FROM Oee.DowntimeSourceCode
        WHERE Id = @Id;
END;
GO

