-- =============================================
-- Procedure:   Oee.Shift_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-15
-- Version:     1.0
--
-- Description:
--   Returns runtime shift instances with their schedule name,
--   optionally filtered by schedule and/or date range on ActualStart.
--   Config Tool uses this read-only; Arc 2 writes Shift rows.
--
-- Parameters (input):
--   @ShiftScheduleId BIGINT NULL - Filter by schedule.
--   @FromDate DATE NULL          - Inclusive lower bound on ActualStart.
--   @ToDate   DATE NULL          - Inclusive upper bound on ActualStart.
--
-- Returns (result set):
--   Matching shifts ordered by ActualStart DESC.
--
-- Dependencies:
--   Tables: Oee.Shift, Oee.ShiftSchedule
--
-- Change Log:
--   2026-04-15 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Oee.Shift_List
    @ShiftScheduleId BIGINT = NULL,
    @FromDate        DATE   = NULL,
    @ToDate          DATE   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.Id,
        s.ShiftScheduleId,
        ss.Name          AS ScheduleName,
        s.ActualStart,
        s.ActualEnd,
        s.Remarks,
        s.CreatedAt
    FROM Oee.Shift s
    INNER JOIN Oee.ShiftSchedule ss ON s.ShiftScheduleId = ss.Id
    WHERE (@ShiftScheduleId IS NULL OR s.ShiftScheduleId = @ShiftScheduleId)
      AND (@FromDate        IS NULL OR s.ActualStart >= CAST(@FromDate AS DATETIME2(3)))
      AND (@ToDate          IS NULL OR s.ActualStart <  DATEADD(DAY, 1, CAST(@ToDate AS DATETIME2(3))))
    ORDER BY s.ActualStart DESC;
END
GO
