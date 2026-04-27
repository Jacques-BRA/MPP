-- =============================================
-- Procedure:   Tools.ToolAttributeDefinition_ListByType
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Returns ToolAttributeDefinition rows for a given ToolType ordered
--   by SortOrder. Filterable on @IncludeDeprecated.
--
-- Parameters:
--   @ToolTypeId BIGINT         - Required.
--   @IncludeDeprecated BIT = 0
--
-- Result set:
--   Id, ToolTypeId, Code, Name, DataType, IsRequired, SortOrder,
--   CreatedAt, DeprecatedAt.
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolAttributeDefinition_ListByType
    @ToolTypeId        BIGINT,
    @IncludeDeprecated BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, ToolTypeId, Code, Name, DataType, IsRequired, SortOrder,
           CreatedAt, DeprecatedAt
    FROM Tools.ToolAttributeDefinition
    WHERE ToolTypeId = @ToolTypeId
      AND (@IncludeDeprecated = 1 OR DeprecatedAt IS NULL)
    ORDER BY SortOrder, Code;
END;
GO
