-- =============================================
-- Procedure:   Tools.ToolAssignment_ListByTool
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
--
-- Description:
--   Returns assignment history for a Tool, most recent first. Joined
--   to Location for display (cell Code, cell Name).
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolAssignment_ListByTool
    @ToolId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ta.Id,
        ta.ToolId,
        ta.CellLocationId,
        l.Code              AS CellCode,
        l.Name              AS CellName,
        ta.AssignedAt,
        ta.ReleasedAt,
        ta.AssignedByUserId,
        ta.ReleasedByUserId,
        ta.Notes
    FROM Tools.ToolAssignment ta
    INNER JOIN Location.Location l ON l.Id = ta.CellLocationId
    WHERE ta.ToolId = @ToolId
    ORDER BY ta.AssignedAt DESC;
END;
GO
