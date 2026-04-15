-- =============================================
-- Procedure:   Lots.ContainerStatusCode_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns a single ContainerStatusCode row by Id. Read-only proc — empty
--   result means not found.
--
-- Parameters:
--   @Id BIGINT - PK of the ContainerStatusCode to retrieve. Required.
--
-- Result set:
--   Zero or one row from Lots.ContainerStatusCode.
--
-- Dependencies:
--   Tables: Lots.ContainerStatusCode
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Lots.ContainerStatusCode_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name
    FROM Lots.ContainerStatusCode
    WHERE Id = @Id;
END;
GO
