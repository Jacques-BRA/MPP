-- =============================================
-- Procedure:   Tools.ToolAssignment_History
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
--
-- Description:
--   Returns ToolAssignment rows within an AssignedAt window for a
--   Tool. Both @From and @To are optional; NULLs widen the window.
--   Most recent first.
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolAssignment_History
    @ToolId BIGINT,
    @From   DATETIME2(3) = NULL,
    @To     DATETIME2(3) = NULL
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
      AND (@From IS NULL OR ta.AssignedAt >= @From)
      AND (@To   IS NULL OR ta.AssignedAt <= @To)
    ORDER BY ta.AssignedAt DESC;
END;
GO
