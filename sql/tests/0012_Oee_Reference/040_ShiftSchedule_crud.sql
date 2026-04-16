-- =============================================
-- File:         0012_Oee_Reference/040_ShiftSchedule_crud.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-15
-- Description:
--   Tests for Oee.ShiftSchedule CRUD procs (Phase 8):
--     Oee.ShiftSchedule_Create
--     Oee.ShiftSchedule_Get
--     Oee.ShiftSchedule_List
--     Oee.ShiftSchedule_Update
--     Oee.ShiftSchedule_Deprecate
--
--   DaysOfWeekBitmask: Mon=1, Tue=2, Wed=4, Thu=8, Fri=16, Sat=32, Sun=64
--     => Mon-Fri = 31. Valid range 1-127 (CHECK constraint + proc validation).
--
--   Pre-conditions:
--     - Migrations 0001-0009 applied
--     - AppUser Id=1 exists
-- =============================================

EXEC test.BeginTestFile @FileName = N'0012_Oee_Reference/040_ShiftSchedule_crud.sql';
GO

-- =============================================
-- Pre-cleanup: remove leftover rows from prior failed runs
-- =============================================
DELETE FROM Oee.ShiftSchedule
WHERE Name IN (N'First Shift', N'First Shift Updated', N'First Shift Dup');
GO

-- =============================================
-- Test: Create happy path — Status=1, NewId>0
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500), @NewId BIGINT;
DECLARE @SStr NVARCHAR(1);

CREATE TABLE #R1 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #R1 EXEC Oee.ShiftSchedule_Create
    @Name              = N'First Shift',
    @Description       = N'06:00-14:00 Mon-Fri',
    @StartTime         = '06:00:00',
    @EndTime           = '14:00:00',
    @DaysOfWeekBitmask = 31,
    @EffectiveFrom     = '2026-01-01',
    @AppUserId         = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #R1;
DROP TABLE #R1;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Create[HappyPath]: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @NewIdStr NVARCHAR(20) = CAST(@NewId AS NVARCHAR(20));
EXEC test.Assert_IsNotNull
    @TestName = N'ShiftSchedule_Create[HappyPath]: NewId is not NULL',
    @Value    = @NewIdStr;

DECLARE @NewIdGtZero NVARCHAR(1) = CASE WHEN @NewId > 0 THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Create[HappyPath]: NewId > 0',
    @Expected = N'1',
    @Actual   = @NewIdGtZero;
GO

-- =============================================
-- Test: Create duplicate Name — Status=0
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500), @NewId BIGINT;
DECLARE @SStr NVARCHAR(1);

CREATE TABLE #R2 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #R2 EXEC Oee.ShiftSchedule_Create
    @Name              = N'First Shift',  -- duplicate
    @StartTime         = '14:00:00',
    @EndTime           = '22:00:00',
    @DaysOfWeekBitmask = 31,
    @EffectiveFrom     = '2026-01-01',
    @AppUserId         = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #R2;
DROP TABLE #R2;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Create[DupName]: status is 0',
    @Expected = N'0',
    @Actual   = @SStr;

EXEC test.Assert_Contains
    @TestName    = N'ShiftSchedule_Create[DupName]: message mentions already exists',
    @HaystackStr = @M,
    @NeedleStr   = N'already exists';
GO

-- =============================================
-- Test: Create with DaysOfWeekBitmask=0 — Status=0 (out-of-range; CHECK or proc)
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500), @NewId BIGINT;
DECLARE @SStr NVARCHAR(1);

BEGIN TRY
    CREATE TABLE #R3 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
    INSERT INTO #R3 EXEC Oee.ShiftSchedule_Create
        @Name              = N'Bad Bitmask Zero',
        @StartTime         = '06:00:00',
        @EndTime           = '14:00:00',
        @DaysOfWeekBitmask = 0,
        @EffectiveFrom     = '2026-01-01',
        @AppUserId         = 1;
    SELECT @S = Status, @M = Message, @NewId = NewId FROM #R3;
    DROP TABLE #R3;
END TRY
BEGIN CATCH
    -- Proc re-raises via RAISERROR after returning the result set; the
    -- INSERT-EXEC may surface the error before we capture S. Treat caught
    -- error as Status=0 (failure path correctly hit).
    SET @S = 0;
    SET @M = ERROR_MESSAGE();
    IF OBJECT_ID('tempdb..#R3') IS NOT NULL DROP TABLE #R3;
END CATCH

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Create[Bitmask0]: status is 0',
    @Expected = N'0',
    @Actual   = @SStr;
GO

-- =============================================
-- Test: Create with DaysOfWeekBitmask=200 — Status=0 (out of range)
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500), @NewId BIGINT;
DECLARE @SStr NVARCHAR(1);

BEGIN TRY
    CREATE TABLE #R4 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
    INSERT INTO #R4 EXEC Oee.ShiftSchedule_Create
        @Name              = N'Bad Bitmask 200',
        @StartTime         = '06:00:00',
        @EndTime           = '14:00:00',
        @DaysOfWeekBitmask = 200,
        @EffectiveFrom     = '2026-01-01',
        @AppUserId         = 1;
    SELECT @S = Status, @M = Message, @NewId = NewId FROM #R4;
    DROP TABLE #R4;
END TRY
BEGIN CATCH
    SET @S = 0;
    SET @M = ERROR_MESSAGE();
    IF OBJECT_ID('tempdb..#R4') IS NOT NULL DROP TABLE #R4;
END CATCH

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Create[Bitmask200]: status is 0',
    @Expected = N'0',
    @Actual   = @SStr;
GO

-- =============================================
-- Test: Get by Id returns row with Name='First Shift'
-- =============================================
DECLARE @TargetId BIGINT;
SELECT @TargetId = Id FROM Oee.ShiftSchedule WHERE Name = N'First Shift';

DECLARE @Count INT;
CREATE TABLE #G (
    Id BIGINT, Name NVARCHAR(100), Description NVARCHAR(500),
    StartTime TIME(0), EndTime TIME(0), DaysOfWeekBitmask INT,
    EffectiveFrom DATE, CreatedAt DATETIME2(3), CreatedByUserId BIGINT,
    UpdatedAt DATETIME2(3), UpdatedByUserId BIGINT, DeprecatedAt DATETIME2(3)
);
INSERT INTO #G EXEC Oee.ShiftSchedule_Get @Id = @TargetId;
SELECT @Count = COUNT(*) FROM #G;

DECLARE @GotName NVARCHAR(100) = (SELECT TOP 1 Name FROM #G);
DROP TABLE #G;

EXEC test.Assert_RowCount
    @TestName      = N'ShiftSchedule_Get[HappyPath]: 1 row returned',
    @ExpectedCount = 1,
    @ActualCount   = @Count;

EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Get[HappyPath]: Name is First Shift',
    @Expected = N'First Shift',
    @Actual   = @GotName;
GO

-- =============================================
-- Test: Get with missing Id — empty result
-- =============================================
DECLARE @Count INT;
CREATE TABLE #G (
    Id BIGINT, Name NVARCHAR(100), Description NVARCHAR(500),
    StartTime TIME(0), EndTime TIME(0), DaysOfWeekBitmask INT,
    EffectiveFrom DATE, CreatedAt DATETIME2(3), CreatedByUserId BIGINT,
    UpdatedAt DATETIME2(3), UpdatedByUserId BIGINT, DeprecatedAt DATETIME2(3)
);
INSERT INTO #G EXEC Oee.ShiftSchedule_Get @Id = 999999;
SELECT @Count = COUNT(*) FROM #G;
DROP TABLE #G;

EXEC test.Assert_RowCount
    @TestName      = N'ShiftSchedule_Get[Missing]: empty result',
    @ExpectedCount = 0,
    @ActualCount   = @Count;
GO

-- =============================================
-- Test: List @ActiveOnly=1 includes our row
-- =============================================
DECLARE @TargetId BIGINT;
SELECT @TargetId = Id FROM Oee.ShiftSchedule WHERE Name = N'First Shift';

CREATE TABLE #L (
    Id BIGINT, Name NVARCHAR(100), Description NVARCHAR(500),
    StartTime TIME(0), EndTime TIME(0), DaysOfWeekBitmask INT,
    EffectiveFrom DATE, CreatedAt DATETIME2(3), CreatedByUserId BIGINT,
    UpdatedAt DATETIME2(3), UpdatedByUserId BIGINT, DeprecatedAt DATETIME2(3)
);
INSERT INTO #L EXEC Oee.ShiftSchedule_List @ActiveOnly = 1;

DECLARE @HasRow INT = (SELECT COUNT(*) FROM #L WHERE Id = @TargetId);
DROP TABLE #L;

DECLARE @HasStr NVARCHAR(1) = CASE WHEN @HasRow = 1 THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_List[ActiveOnly]: contains First Shift',
    @Expected = N'1',
    @Actual   = @HasStr;
GO

-- =============================================
-- Test: Update happy path — Name='First Shift Updated' -> Status=1; Get confirms
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);
DECLARE @TargetId BIGINT;

SELECT @TargetId = Id FROM Oee.ShiftSchedule WHERE Name = N'First Shift';

CREATE TABLE #R5 (Status BIT, Message NVARCHAR(500));
INSERT INTO #R5 EXEC Oee.ShiftSchedule_Update
    @Id                = @TargetId,
    @Name              = N'First Shift Updated',
    @Description       = N'Renamed by test',
    @StartTime         = '06:00:00',
    @EndTime           = '14:00:00',
    @DaysOfWeekBitmask = 31,
    @EffectiveFrom     = '2026-01-01',
    @AppUserId         = 1;
SELECT @S = Status, @M = Message FROM #R5;
DROP TABLE #R5;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Update[HappyPath]: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @StoredName NVARCHAR(100);
SELECT @StoredName = Name FROM Oee.ShiftSchedule WHERE Id = @TargetId;
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Update[HappyPath]: Name changed',
    @Expected = N'First Shift Updated',
    @Actual   = @StoredName;
GO

-- =============================================
-- Test: Deprecate happy path — Status=1, DeprecatedAt set
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);
DECLARE @TargetId BIGINT;

SELECT @TargetId = Id FROM Oee.ShiftSchedule WHERE Name = N'First Shift Updated';

CREATE TABLE #R6 (Status BIT, Message NVARCHAR(500));
INSERT INTO #R6 EXEC Oee.ShiftSchedule_Deprecate
    @Id        = @TargetId,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #R6;
DROP TABLE #R6;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Deprecate[HappyPath]: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @DepAt DATETIME2(3);
SELECT @DepAt = DeprecatedAt FROM Oee.ShiftSchedule WHERE Id = @TargetId;
DECLARE @DepStr NVARCHAR(1) = CASE WHEN @DepAt IS NOT NULL THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Deprecate[HappyPath]: DeprecatedAt set',
    @Expected = N'1',
    @Actual   = @DepStr;
GO

-- =============================================
-- Test: Update on deprecated row — Status=0
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);
DECLARE @TargetId BIGINT;

SELECT @TargetId = Id FROM Oee.ShiftSchedule WHERE Name = N'First Shift Updated';

CREATE TABLE #R7 (Status BIT, Message NVARCHAR(500));
INSERT INTO #R7 EXEC Oee.ShiftSchedule_Update
    @Id                = @TargetId,
    @Name              = N'Try update deprecated',
    @StartTime         = '06:00:00',
    @EndTime           = '14:00:00',
    @DaysOfWeekBitmask = 31,
    @EffectiveFrom     = '2026-01-01',
    @AppUserId         = 1;
SELECT @S = Status, @M = Message FROM #R7;
DROP TABLE #R7;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Update[Deprecated]: status is 0',
    @Expected = N'0',
    @Actual   = @SStr;

EXEC test.Assert_Contains
    @TestName    = N'ShiftSchedule_Update[Deprecated]: message mentions deprecated',
    @HaystackStr = @M,
    @NeedleStr   = N'deprecated';
GO

-- =============================================
-- Test: Deprecate already-deprecated — Status=0
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);
DECLARE @TargetId BIGINT;

SELECT @TargetId = Id FROM Oee.ShiftSchedule WHERE Name = N'First Shift Updated';

CREATE TABLE #R8 (Status BIT, Message NVARCHAR(500));
INSERT INTO #R8 EXEC Oee.ShiftSchedule_Deprecate
    @Id        = @TargetId,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #R8;
DROP TABLE #R8;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'ShiftSchedule_Deprecate[Already]: status is 0',
    @Expected = N'0',
    @Actual   = @SStr;

EXEC test.Assert_Contains
    @TestName    = N'ShiftSchedule_Deprecate[Already]: message mentions already',
    @HaystackStr = @M,
    @NeedleStr   = N'already';
GO

-- =============================================
-- Cleanup
-- =============================================
DELETE FROM Oee.ShiftSchedule
WHERE Name IN (N'First Shift', N'First Shift Updated', N'First Shift Dup',
               N'Bad Bitmask Zero', N'Bad Bitmask 200');
GO

EXEC test.EndTestFile;
GO
