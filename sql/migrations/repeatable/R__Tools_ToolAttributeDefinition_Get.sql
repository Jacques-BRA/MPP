-- =============================================
-- Procedure:   Tools.ToolAttributeDefinition_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolAttributeDefinition_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, ToolTypeId, Code, Name, DataType, IsRequired, SortOrder,
           CreatedAt, DeprecatedAt
    FROM Tools.ToolAttributeDefinition
    WHERE Id = @Id;
END;
GO
