-- =============================================
-- Procedure:   Tools.DieRank_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Returns a single DieRank row by Id. Empty result = not found.
--
-- Parameters:
--   @Id BIGINT - PK. Required.
--
-- Result set:
--   Zero or one DieRank row.
--
-- Dependencies:
--   Tables: Tools.DieRank
-- =============================================
CREATE OR ALTER PROCEDURE Tools.DieRank_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, Description, SortOrder, CreatedAt, DeprecatedAt
    FROM Tools.DieRank
    WHERE Id = @Id;
END;
GO
