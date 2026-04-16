-- =============================================
-- Procedure:   Oee.ShiftSchedule_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-15
-- Version:     1.0
--
-- Description:
--   Returns all shift schedules. By default only active (non-
--   deprecated) rows are returned; pass @ActiveOnly = 0 to include
--   deprecated schedules.
--
-- Parameters (input):
--   @ActiveOnly BIT - Defaults to 1 (exclude deprecated).
--
-- Returns (result set):
--   All matching shift schedules ordered by Name.
--
-- Dependencies:
--   Tables: Oee.ShiftSchedule
--
-- Change Log:
--   2026-04-15 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Oee.ShiftSchedule_List
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        Name,
        Description,
        StartTime,
        EndTime,
        DaysOfWeekBitmask,
        EffectiveFrom,
        CreatedAt,
        CreatedByUserId,
        UpdatedAt,
        UpdatedByUserId,
        DeprecatedAt
    FROM Oee.ShiftSchedule
    WHERE (@ActiveOnly = 0 OR DeprecatedAt IS NULL)
    ORDER BY Name;
END
GO
