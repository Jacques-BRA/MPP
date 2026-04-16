-- =============================================
-- File:         0012_Oee_Reference/050_Shift_read.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-15
-- Description:
--   Tests for Oee.Shift_List (Phase 8 read-only from Config Tool;
--   Arc 2 plant-floor controller writes Oee.Shift rows). This test
--   inserts 2 runtime fixture rows directly (no Shift_Create proc
--   exists by design) and exercises the filter parameters and the
--   joined ScheduleName column.
--
--   Pre-conditions:
--     - Migrations 0001-0009 applied
--     - AppUser Id=1 exists
-- =============================================

EXEC test.BeginTestFile @FileName = N'0012_Oee_Reference/050_Shift_read.sql';
GO

-- =============================================
-- Pre-cleanup: remove leftover fixture rows from prior runs
-- =============================================
DELETE FROM Oee.Shift
WHERE ShiftScheduleId IN (
    SELECT Id FROM Oee.ShiftSchedule
    WHERE Name IN (N'TEST Shift Sched A', N'TEST Shift Sched B')
);

DELETE FROM Oee.ShiftSchedule
WHERE Name IN (N'TEST Shift Sched A', N'TEST Shift Sched B');
GO

-- =============================================
-- Setup: create a ShiftSchedule via the Create proc, then insert
-- 2 runtime Shift fixture rows (and a 3rd tied to a sibling
-- schedule so we can test the ShiftScheduleId filter).
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500), @SchedAId BIGINT, @SchedBId BIGINT;

CREATE TABLE #SA (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #SA EXEC Oee.ShiftSchedule_Create
    @Name              = N'TEST Shift Sched A',
    @Description       = N'Fixture for Shift_List test (A)',
    @StartTime         = '06:00:00',
    @EndTime           = '14:00:00',
    @DaysOfWeekBitmask = 31,
    @EffectiveFrom     = '2026-01-01',
    @AppUserId         = 1;
SELECT @SchedAId = NewId FROM #SA;
DROP TABLE #SA;

CREATE TABLE #SB (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #SB EXEC Oee.ShiftSchedule_Create
    @Name              = N'TEST Shift Sched B',
    @Description       = N'Fixture for Shift_List test (B)',
    @StartTime         = '14:00:00',
    @EndTime           = '22:00:00',
    @DaysOfWeekBitmask = 31,
    @EffectiveFrom     = '2026-01-01',
    @AppUserId         = 1;
SELECT @SchedBId = NewId FROM #SB;
DROP TABLE #SB;

-- Direct INSERT into Oee.Shift (runtime table, no Create proc).
-- Two rows tied to schedule A, one to schedule B.
INSERT INTO Oee.Shift (ShiftScheduleId, ActualStart, ActualEnd, Remarks)
VALUES
    (@SchedAId, '2026-04-10 06:00:00', '2026-04-10 14:00:00', N'Fixture A1'),
    (@SchedAId, '2026-04-11 06:00:00', '2026-04-11 14:00:00', N'Fixture A2'),
    (@SchedBId, '2026-04-10 14:00:00', '2026-04-10 22:00:00', N'Fixture B1');
GO

-- =============================================
-- Test: Shift_List with no filters returns >= 2 rows
-- =============================================
DECLARE @Count INT;
CREATE TABLE #L (
    Id BIGINT, ShiftScheduleId BIGINT, ScheduleName NVARCHAR(100),
    ActualStart DATETIME2(3), ActualEnd DATETIME2(3),
    Remarks NVARCHAR(500), CreatedAt DATETIME2(3)
);
INSERT INTO #L EXEC Oee.Shift_List;
SELECT @Count = COUNT(*) FROM #L;
DROP TABLE #L;

DECLARE @AtLeast2 NVARCHAR(1) = CASE WHEN @Count >= 2 THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'Shift_List[NoFilters]: at least 2 rows returned',
    @Expected = N'1',
    @Actual   = @AtLeast2;
GO

-- =============================================
-- Test: Shift_List filtered by ShiftScheduleId returns only matching rows
-- =============================================
DECLARE @SchedAId BIGINT;
SELECT @SchedAId = Id FROM Oee.ShiftSchedule WHERE Name = N'TEST Shift Sched A';

CREATE TABLE #L2 (
    Id BIGINT, ShiftScheduleId BIGINT, ScheduleName NVARCHAR(100),
    ActualStart DATETIME2(3), ActualEnd DATETIME2(3),
    Remarks NVARCHAR(500), CreatedAt DATETIME2(3)
);
INSERT INTO #L2 EXEC Oee.Shift_List @ShiftScheduleId = @SchedAId;

DECLARE @Total INT = (SELECT COUNT(*) FROM #L2);
DECLARE @Match INT = (SELECT COUNT(*) FROM #L2 WHERE ShiftScheduleId = @SchedAId);
DROP TABLE #L2;

DECLARE @TotalStr NVARCHAR(10) = CAST(@Total AS NVARCHAR(10));
EXEC test.Assert_IsEqual
    @TestName = N'Shift_List[FilterBySchedule]: 2 fixture rows for Sched A',
    @Expected = N'2',
    @Actual   = @TotalStr;

DECLARE @AllMatch NVARCHAR(1) =
    CASE WHEN @Total > 0 AND @Total = @Match THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'Shift_List[FilterBySchedule]: all rows match Sched A Id',
    @Expected = N'1',
    @Actual   = @AllMatch;
GO

-- =============================================
-- Test: Shift_List filtered by date range — only 2026-04-10 row(s)
-- For Sched A: only the A1 fixture (2026-04-10) should match.
-- =============================================
DECLARE @SchedAId BIGINT;
SELECT @SchedAId = Id FROM Oee.ShiftSchedule WHERE Name = N'TEST Shift Sched A';

CREATE TABLE #L3 (
    Id BIGINT, ShiftScheduleId BIGINT, ScheduleName NVARCHAR(100),
    ActualStart DATETIME2(3), ActualEnd DATETIME2(3),
    Remarks NVARCHAR(500), CreatedAt DATETIME2(3)
);
INSERT INTO #L3 EXEC Oee.Shift_List
    @ShiftScheduleId = @SchedAId,
    @FromDate        = '2026-04-10',
    @ToDate          = '2026-04-10';

DECLARE @Count INT = (SELECT COUNT(*) FROM #L3);
DROP TABLE #L3;

DECLARE @CountStr NVARCHAR(10) = CAST(@Count AS NVARCHAR(10));
EXEC test.Assert_IsEqual
    @TestName = N'Shift_List[DateRange]: 1 fixture row on 2026-04-10 for Sched A',
    @Expected = N'1',
    @Actual   = @CountStr;
GO

-- =============================================
-- Test: Result set includes joined ScheduleName column
-- =============================================
DECLARE @SchedAId BIGINT;
SELECT @SchedAId = Id FROM Oee.ShiftSchedule WHERE Name = N'TEST Shift Sched A';

CREATE TABLE #L4 (
    Id BIGINT, ShiftScheduleId BIGINT, ScheduleName NVARCHAR(100),
    ActualStart DATETIME2(3), ActualEnd DATETIME2(3),
    Remarks NVARCHAR(500), CreatedAt DATETIME2(3)
);
INSERT INTO #L4 EXEC Oee.Shift_List @ShiftScheduleId = @SchedAId;

DECLARE @GotName NVARCHAR(100) = (SELECT TOP 1 ScheduleName FROM #L4 ORDER BY ActualStart DESC);
DROP TABLE #L4;

EXEC test.Assert_IsEqual
    @TestName = N'Shift_List: ScheduleName join populated',
    @Expected = N'TEST Shift Sched A',
    @Actual   = @GotName;
GO

-- =============================================
-- Cleanup: remove fixture rows
-- =============================================
DELETE FROM Oee.Shift
WHERE ShiftScheduleId IN (
    SELECT Id FROM Oee.ShiftSchedule
    WHERE Name IN (N'TEST Shift Sched A', N'TEST Shift Sched B')
);

DELETE FROM Oee.ShiftSchedule
WHERE Name IN (N'TEST Shift Sched A', N'TEST Shift Sched B');
GO

EXEC test.EndTestFile;
GO
