-- =============================================
-- Procedure:   Tools.Tool_GetByCode
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Returns a single Tool row by Code with joined ToolType, StatusCode,
--   and DieRank for display. Code is globally UNIQUE. Empty result =
--   not found.
--
-- Parameters:
--   @Code NVARCHAR(50) - Tool identifier (e.g., `DC-042`). Required.
--
-- Result set:
--   Zero or one Tool row with joined display fields.
--
-- Dependencies:
--   Tables: Tools.Tool, Tools.ToolType, Tools.ToolStatusCode, Tools.DieRank
-- =============================================
CREATE OR ALTER PROCEDURE Tools.Tool_GetByCode
    @Code NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        t.Id,
        t.ToolTypeId,
        tt.Code              AS ToolTypeCode,
        tt.Name              AS ToolTypeName,
        tt.HasCavities,
        t.Code,
        t.Name,
        t.Description,
        t.DieRankId,
        dr.Code              AS DieRankCode,
        dr.Name              AS DieRankName,
        t.StatusCodeId,
        sc.Code              AS StatusCode,
        sc.Name              AS StatusName,
        t.CreatedAt,
        t.UpdatedAt,
        t.CreatedByUserId,
        t.UpdatedByUserId,
        t.DeprecatedAt
    FROM Tools.Tool t
    INNER JOIN Tools.ToolType       tt ON tt.Id = t.ToolTypeId
    INNER JOIN Tools.ToolStatusCode sc ON sc.Id = t.StatusCodeId
    LEFT  JOIN Tools.DieRank        dr ON dr.Id = t.DieRankId
    WHERE t.Code = @Code;
END;
GO
