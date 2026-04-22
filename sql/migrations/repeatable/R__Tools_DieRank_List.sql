-- =============================================
-- Procedure:   Tools.DieRank_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Returns DieRank rows ordered by SortOrder then Code. Mutable code
--   table; seeded empty at migration 0010 pending MPP Quality's
--   authoritative rank list.
--
-- Parameters:
--   @IncludeDeprecated BIT = 0 - When 1, includes deprecated rows.
--
-- Result set:
--   Id, Code, Name, Description, SortOrder, CreatedAt, DeprecatedAt.
--
-- Dependencies:
--   Tables: Tools.DieRank
-- =============================================
CREATE OR ALTER PROCEDURE Tools.DieRank_List
    @IncludeDeprecated BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, Description, SortOrder, CreatedAt, DeprecatedAt
    FROM Tools.DieRank
    WHERE (@IncludeDeprecated = 1 OR DeprecatedAt IS NULL)
    ORDER BY SortOrder, Code;
END;
GO
