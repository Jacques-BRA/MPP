-- =============================================
-- Procedure:   Workorder.ScrapSource_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Returns a single ScrapSource row by Id. Empty result = not found.
--
-- Parameters:
--   @Id BIGINT - PK. Required.
--
-- Result set:
--   Zero or one ScrapSource row.
--
-- Dependencies:
--   Tables: Workorder.ScrapSource
-- =============================================
CREATE OR ALTER PROCEDURE Workorder.ScrapSource_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, Description
    FROM Workorder.ScrapSource
    WHERE Id = @Id;
END;
GO
