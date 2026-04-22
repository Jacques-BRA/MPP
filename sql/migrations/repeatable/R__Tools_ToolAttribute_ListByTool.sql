-- =============================================
-- Procedure:   Tools.ToolAttribute_ListByTool
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
--
-- Description:
--   Returns attribute values for a Tool joined to the attribute
--   definition for display (Code, Name, DataType).
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolAttribute_ListByTool
    @ToolId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ta.Id,
        ta.ToolId,
        ta.ToolAttributeDefinitionId,
        tad.Code       AS AttributeCode,
        tad.Name       AS AttributeName,
        tad.DataType,
        tad.IsRequired,
        ta.Value,
        ta.UpdatedAt,
        ta.UpdatedByUserId
    FROM Tools.ToolAttribute ta
    INNER JOIN Tools.ToolAttributeDefinition tad ON tad.Id = ta.ToolAttributeDefinitionId
    WHERE ta.ToolId = @ToolId
    ORDER BY tad.SortOrder, tad.Code;
END;
GO
