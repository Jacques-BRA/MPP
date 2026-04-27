-- =============================================
-- Procedure:   Tools.ToolCavity_ListByTool
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
--
-- Description:
--   Returns ToolCavity rows for a Tool ordered by CavityNumber.
--   Joined to ToolCavityStatusCode for display.
-- =============================================
CREATE OR ALTER PROCEDURE Tools.ToolCavity_ListByTool
    @ToolId            BIGINT,
    @IncludeDeprecated BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        tc.Id,
        tc.ToolId,
        tc.CavityNumber,
        tc.StatusCodeId,
        sc.Code           AS StatusCode,
        sc.Name           AS StatusName,
        tc.Description,
        tc.CreatedAt,
        tc.UpdatedAt,
        tc.CreatedByUserId,
        tc.UpdatedByUserId,
        tc.DeprecatedAt
    FROM Tools.ToolCavity tc
    INNER JOIN Tools.ToolCavityStatusCode sc ON sc.Id = tc.StatusCodeId
    WHERE tc.ToolId = @ToolId
      AND (@IncludeDeprecated = 1 OR tc.DeprecatedAt IS NULL)
    ORDER BY tc.CavityNumber;
END;
GO
