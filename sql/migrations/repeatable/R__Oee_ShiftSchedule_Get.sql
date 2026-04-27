-- =============================================
-- Procedure:   Oee.ShiftSchedule_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-15
-- Version:     1.0
--
-- Description:
--   Returns a single shift schedule by Id. Empty result if not found.
--
-- Parameters (input):
--   @Id BIGINT - Required.
--
-- Returns (result set):
--   Single row (or empty) with shift schedule fields.
--
-- Dependencies:
--   Tables: Oee.ShiftSchedule
--
-- Change Log:
--   2026-04-15 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Oee.ShiftSchedule_Get
    @Id BIGINT
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
    WHERE Id = @Id;
END
GO
