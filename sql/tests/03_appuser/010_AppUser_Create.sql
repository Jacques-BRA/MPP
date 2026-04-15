-- =============================================
-- File:         03_appuser/010_AppUser_Create.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Location.AppUser_Create.
--   Covers: happy path (all params), NULL AdAccount, NULL DisplayName,
--   duplicate AdAccount, and minimal params (optional fields all NULL).
--
--   Pre-conditions:
--     - Migration 0001 applied (Location.AppUser, Audit.ConfigLog,
--       Audit.FailureLog, audit lookup seeds all present)
--     - All audit infrastructure procs deployed
--     - Location.AppUser_Create proc deployed
--     - Bootstrap user Id=1 exists
-- =============================================

EXEC test.BeginTestFile @FileName = N'03_appuser/010_AppUser_Create.sql';
GO

-- =============================================
-- Test 1: Happy path - create user with all params
--   Assert Status=1, NewId not NULL.
--   Verify row stored with correct column values.
--   Verify ConfigLog entry written for the new user.
-- =============================================

-- Capture result from proc
CREATE TABLE #Result1 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Result1
EXEC Location.AppUser_Create
    @AdAccount    = N'DOMAIN\jdoe',
    @DisplayName  = N'John Doe',
    @ClockNumber  = N'C00123',
    @PinHash      = N'$2b$10$hashedvalue',
    @IgnitionRole = N'Operator',
    @AppUserId    = 1;

DECLARE @S     BIT           = (SELECT Status FROM #Result1);
DECLARE @SStr  NVARCHAR(1)   = CAST(@S AS NVARCHAR(1));
DECLARE @NewId BIGINT        = (SELECT NewId FROM #Result1);
DROP TABLE #Result1;

EXEC test.Assert_IsEqual
    @TestName = N'[HappyPath] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @NewIdStr NVARCHAR(20) = CAST(@NewId AS NVARCHAR(20));
EXEC test.Assert_IsNotNull
    @TestName = N'[HappyPath] NewId is not NULL',
    @Value    = @NewIdStr;

-- Verify row exists in AppUser
DECLARE @RowCount INT;
SELECT @RowCount = COUNT(*)
FROM Location.AppUser
WHERE Id = @NewId;

EXEC test.Assert_RowCount
    @TestName      = N'[HappyPath] AppUser row exists',
    @ExpectedCount = 1,
    @ActualCount   = @RowCount;

-- Verify column values stored correctly
DECLARE @StoredAdAccount    NVARCHAR(100),
        @StoredDisplayName  NVARCHAR(200),
        @StoredClockNumber  NVARCHAR(20),
        @StoredIgnitionRole NVARCHAR(100),
        @StoredDeprecatedAt DATETIME2(3);

SELECT
    @StoredAdAccount    = AdAccount,
    @StoredDisplayName  = DisplayName,
    @StoredClockNumber  = ClockNumber,
    @StoredIgnitionRole = IgnitionRole,
    @StoredDeprecatedAt = DeprecatedAt
FROM Location.AppUser
WHERE Id = @NewId;

EXEC test.Assert_IsEqual
    @TestName = N'[HappyPath] AdAccount stored correctly',
    @Expected = N'DOMAIN\jdoe',
    @Actual   = @StoredAdAccount;

EXEC test.Assert_IsEqual
    @TestName = N'[HappyPath] DisplayName stored correctly',
    @Expected = N'John Doe',
    @Actual   = @StoredDisplayName;

EXEC test.Assert_IsEqual
    @TestName = N'[HappyPath] ClockNumber stored correctly',
    @Expected = N'C00123',
    @Actual   = @StoredClockNumber;

EXEC test.Assert_IsEqual
    @TestName = N'[HappyPath] IgnitionRole stored correctly',
    @Expected = N'Operator',
    @Actual   = @StoredIgnitionRole;

DECLARE @DepAtStr NVARCHAR(1) = CASE WHEN @StoredDeprecatedAt IS NULL THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[HappyPath] DeprecatedAt is NULL (active)',
    @Expected = N'1',
    @Actual   = @DepAtStr;

-- Verify ConfigLog entry written for this entity
DECLARE @ConfigLogCount INT;
SELECT @ConfigLogCount = COUNT(*)
FROM Audit.ConfigLog cl
INNER JOIN Audit.LogEntityType let ON let.Id = cl.LogEntityTypeId
WHERE let.Code = N'AppUser'
  AND cl.EntityId = @NewId;

EXEC test.Assert_RowCount
    @TestName      = N'[HappyPath] ConfigLog entry written',
    @ExpectedCount = 1,
    @ActualCount   = @ConfigLogCount;
GO

-- =============================================
-- Test 2: NULL AdAccount - rejected
--   Status=0, NewId is NULL, message set.
-- =============================================
CREATE TABLE #Result2 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Result2
EXEC Location.AppUser_Create
    @AdAccount   = NULL,
    @DisplayName = N'No Account User',
    @AppUserId   = 1;

DECLARE @S2    BIT         = (SELECT Status FROM #Result2);
DECLARE @SStr2 NVARCHAR(1) = CAST(@S2 AS NVARCHAR(1));
DECLARE @NewId2 BIGINT     = (SELECT NewId FROM #Result2);
DROP TABLE #Result2;

EXEC test.Assert_IsEqual
    @TestName = N'[NullAdAccount] Status is 0',
    @Expected = N'0',
    @Actual   = @SStr2;

DECLARE @NewIdStr2 NVARCHAR(20) = CAST(@NewId2 AS NVARCHAR(20));
EXEC test.Assert_IsNull
    @TestName = N'[NullAdAccount] NewId is NULL',
    @Value    = @NewIdStr2;
GO

-- =============================================
-- Test 3: NULL DisplayName - rejected
--   Status=0.
-- =============================================
CREATE TABLE #Result3 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Result3
EXEC Location.AppUser_Create
    @AdAccount   = N'DOMAIN\nodisplay',
    @DisplayName = NULL,
    @AppUserId   = 1;

DECLARE @S3    BIT         = (SELECT Status FROM #Result3);
DECLARE @SStr3 NVARCHAR(1) = CAST(@S3 AS NVARCHAR(1));
DROP TABLE #Result3;

EXEC test.Assert_IsEqual
    @TestName = N'[NullDisplayName] Status is 0',
    @Expected = N'0',
    @Actual   = @SStr3;

-- Confirm no row was inserted
DECLARE @RowCount3 INT;
SELECT @RowCount3 = COUNT(*)
FROM Location.AppUser
WHERE AdAccount = N'DOMAIN\nodisplay';

EXEC test.Assert_RowCount
    @TestName      = N'[NullDisplayName] No row inserted',
    @ExpectedCount = 0,
    @ActualCount   = @RowCount3;
GO

-- =============================================
-- Test 4: Duplicate AdAccount - second call rejected
--   Create same AdAccount twice.
--   Second call: Status=0, NewId NULL.
--   Verify FailureLog entry written for the duplicate attempt.
-- =============================================

-- First call - should succeed
CREATE TABLE #Result4a (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Result4a
EXEC Location.AppUser_Create
    @AdAccount   = N'DOMAIN\dupuser',
    @DisplayName = N'Duplicate User',
    @AppUserId   = 1;

DECLARE @S4a    BIT         = (SELECT Status FROM #Result4a);
DECLARE @SStr4a NVARCHAR(1) = CAST(@S4a AS NVARCHAR(1));
DROP TABLE #Result4a;

EXEC test.Assert_IsEqual
    @TestName = N'[DuplicateAdAccount] First create: Status is 1',
    @Expected = N'1',
    @Actual   = @SStr4a;

-- Snapshot FailureLog count before the duplicate attempt
DECLARE @FailCountBefore INT;
SELECT @FailCountBefore = COUNT(*)
FROM Audit.FailureLog fl
INNER JOIN Audit.LogEntityType let ON let.Id = fl.LogEntityTypeId
WHERE let.Code = N'AppUser'
  AND fl.ProcedureName = N'Location.AppUser_Create';

-- Second call with the same AdAccount - should be rejected
CREATE TABLE #Result4b (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Result4b
EXEC Location.AppUser_Create
    @AdAccount   = N'DOMAIN\dupuser',
    @DisplayName = N'Duplicate User Again',
    @AppUserId   = 1;

DECLARE @S4b    BIT         = (SELECT Status FROM #Result4b);
DECLARE @SStr4b NVARCHAR(1) = CAST(@S4b AS NVARCHAR(1));
DECLARE @NewId4b BIGINT     = (SELECT NewId FROM #Result4b);
DROP TABLE #Result4b;

EXEC test.Assert_IsEqual
    @TestName = N'[DuplicateAdAccount] Second create: Status is 0',
    @Expected = N'0',
    @Actual   = @SStr4b;

DECLARE @NewId4bStr NVARCHAR(20) = CAST(@NewId4b AS NVARCHAR(20));
EXEC test.Assert_IsNull
    @TestName = N'[DuplicateAdAccount] Second create: NewId is NULL',
    @Value    = @NewId4bStr;

-- Verify FailureLog entry was written for the duplicate attempt
DECLARE @FailCountAfter INT;
SELECT @FailCountAfter = COUNT(*)
FROM Audit.FailureLog fl
INNER JOIN Audit.LogEntityType let ON let.Id = fl.LogEntityTypeId
WHERE let.Code = N'AppUser'
  AND fl.ProcedureName = N'Location.AppUser_Create';

DECLARE @FailDiff INT = @FailCountAfter - @FailCountBefore;
EXEC test.Assert_RowCount
    @TestName      = N'[DuplicateAdAccount] FailureLog entry written for duplicate',
    @ExpectedCount = 1,
    @ActualCount   = @FailDiff;
GO

-- =============================================
-- Test 5: Minimal params - only required params, optional all NULL
--   ClockNumber, PinHash, IgnitionRole all NULL.
--   Status=1. Verify NULLs stored.
-- =============================================
CREATE TABLE #Result5 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Result5
EXEC Location.AppUser_Create
    @AdAccount   = N'DOMAIN\minimaluser',
    @DisplayName = N'Minimal User',
    @AppUserId   = 1;

DECLARE @S5    BIT         = (SELECT Status FROM #Result5);
DECLARE @SStr5 NVARCHAR(1) = CAST(@S5 AS NVARCHAR(1));
DECLARE @NewId5 BIGINT     = (SELECT NewId FROM #Result5);
DROP TABLE #Result5;

EXEC test.Assert_IsEqual
    @TestName = N'[MinimalParams] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr5;

DECLARE @NewId5Str NVARCHAR(20) = CAST(@NewId5 AS NVARCHAR(20));
EXEC test.Assert_IsNotNull
    @TestName = N'[MinimalParams] NewId is not NULL',
    @Value    = @NewId5Str;

-- Verify optional columns are NULL
DECLARE @StoredClock5     NVARCHAR(20),
        @StoredPin5       NVARCHAR(255),
        @StoredRole5      NVARCHAR(100);

SELECT
    @StoredClock5 = ClockNumber,
    @StoredPin5   = PinHash,
    @StoredRole5  = IgnitionRole
FROM Location.AppUser
WHERE Id = @NewId5;

EXEC test.Assert_IsNull
    @TestName = N'[MinimalParams] ClockNumber is NULL',
    @Value    = @StoredClock5;

EXEC test.Assert_IsNull
    @TestName = N'[MinimalParams] PinHash is NULL',
    @Value    = @StoredPin5;

EXEC test.Assert_IsNull
    @TestName = N'[MinimalParams] IgnitionRole is NULL',
    @Value    = @StoredRole5;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
