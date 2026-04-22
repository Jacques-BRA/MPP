-- =============================================
-- Procedure:   Tools.ToolAssignment_ListActiveByCell
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
--
-- Description:
--   Returns the Tool currently mounted on the given Cell (if any).
--   Zero or one row (filtered UNIQUE on ReleasedAt IS NULL enforces
--   single active assignment per Cell). Joined to Tool for display.
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolAssignment_ListActiveByCell
    @CellLocationId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ta.Id,
        ta.ToolId,
        t.Code              AS ToolCode,
        t.Name              AS ToolName,
        tt.Code              AS ToolTypeCode,
        ta.CellLocationId,
        ta.AssignedAt,
        ta.AssignedByUserId,
        ta.Notes
    FROM Tools.ToolAssignment ta
    INNER JOIN Tools.Tool     t  ON t.Id  = ta.ToolId
    INNER JOIN Tools.ToolType tt ON tt.Id = t.ToolTypeId
    WHERE ta.CellLocationId = @CellLocationId
      AND ta.ReleasedAt IS NULL;
END;
GO
