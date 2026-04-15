-- =============================================
-- Procedure:   Audit.FailureLog_GetTopProcs
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns the top 50 stored procedures by failure frequency within a
--   date range. Useful for identifying procedures that are failing most
--   often and may need attention.
--   Read-only proc — empty result means no failures in the date range.
--
-- Parameters:
--   @StartDate DATETIME2(3) - Start of date range (inclusive). Required.
--   @EndDate DATETIME2(3)   - End of date range (inclusive). Required.
--
-- Result set:
--   Top 50 rows: ProcedureName, FailureCount — ordered by FailureCount DESC.
--
-- Dependencies:
--   Tables: Audit.FailureLog
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Audit.FailureLog_GetTopProcs
    @StartDate  DATETIME2(3),
    @EndDate    DATETIME2(3)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (50)
        fl.ProcedureName,
        COUNT(*) AS FailureCount
    FROM Audit.FailureLog fl
    WHERE fl.AttemptedAt BETWEEN @StartDate AND @EndDate
    GROUP BY fl.ProcedureName
    ORDER BY FailureCount DESC;
END;
GO
