-- =============================================
-- File:         03_appuser/040_AppUser_GetByClockNumber.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Location.AppUser_GetByClockNumber.
--   Covers: active user found by ClockNumber, deprecated user filtered out
--   (WHERE DeprecatedAt IS NULL), non-existent clock number returns 0 rows.
--
--   Pre-conditions:
--     - Migration 0001 applied (Location.AppUser seed present)
--     - Location.AppUser_GetByClockNumber deployed (v2.0, no OUTPUT params)
--     - Location.AppUser_Create deployed (v2.0, returns SELECT)
--     - Location.AppUser_Deprecate deployed
-- =============================================

EXEC test.BeginTestFile @FileName = N'03_appuser/040_AppUser_GetByClockNumber.sql';
GO

-- =============================================
-- Setup: Create a test user with CLK999 clock number.
-- =============================================
CREATE TABLE #CreateSetup (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #CreateSetup
EXEC Location.AppUser_Create
    @AdAccount    = N'test.clk999.040',
    @DisplayName  = N'Test CLK999 040',
    @ClockNumber  = N'CLK999',
    @PinHash      = NULL,
    @IgnitionRole = NULL,
    @AppUserId    = 1;
DROP TABLE #CreateSetup;
GO

-- =============================================
-- Test 1: Active user found by ClockNumber. Expect exactly 1 row.
-- =============================================
CREATE TABLE #ByClock1 (
    Id           BIGINT,
    AdAccount    NVARCHAR(100),
    DisplayName  NVARCHAR(200),
    ClockNumber  NVARCHAR(20),
    PinHash      NVARCHAR(255),
    IgnitionRole NVARCHAR(100),
    CreatedAt    DATETIME2(3),
    DeprecatedAt DATETIME2(3)
);

INSERT INTO #ByClock1
EXEC Location.AppUser_GetByClockNumber @ClockNumber = N'CLK999';

DECLARE @RowCount1 INT = (SELECT COUNT(*) FROM #ByClock1);
DROP TABLE #ByClock1;

EXEC test.Assert_RowCount
    @TestName      = N'GetByClockNumber active: 1 row returned',
    @ExpectedCount = 1,
    @ActualCount   = @RowCount1;
GO

-- =============================================
-- Test 2: Deprecated user is filtered out (WHERE DeprecatedAt IS NULL → 0 rows).
-- =============================================
DECLARE @TargetId   BIGINT;
DECLARE @DepStatus  BIT           = 0;
DECLARE @DepMessage NVARCHAR(500) = NULL;

SELECT @TargetId = Id FROM Location.AppUser WHERE AdAccount = N'test.clk999.040';

CREATE TABLE #RDep (Status BIT, Message NVARCHAR(500));
INSERT INTO #RDep
EXEC Location.AppUser_Deprecate
    @Id        = @TargetId,
    @AppUserId = 1;
SELECT @DepStatus = Status, @DepMessage = Message FROM #RDep;
DROP TABLE #RDep;
GO

CREATE TABLE #ByClock2 (
    Id           BIGINT,
    AdAccount    NVARCHAR(100),
    DisplayName  NVARCHAR(200),
    ClockNumber  NVARCHAR(20),
    PinHash      NVARCHAR(255),
    IgnitionRole NVARCHAR(100),
    CreatedAt    DATETIME2(3),
    DeprecatedAt DATETIME2(3)
);

INSERT INTO #ByClock2
EXEC Location.AppUser_GetByClockNumber @ClockNumber = N'CLK999';

DECLARE @RowCount2 INT = (SELECT COUNT(*) FROM #ByClock2);
DROP TABLE #ByClock2;

EXEC test.Assert_RowCount
    @TestName      = N'GetByClockNumber deprecated: 0 rows returned',
    @ExpectedCount = 0,
    @ActualCount   = @RowCount2;
GO

-- =============================================
-- Test 3: Non-existent ClockNumber returns 0 rows.
-- =============================================
CREATE TABLE #ByClock3 (
    Id           BIGINT,
    AdAccount    NVARCHAR(100),
    DisplayName  NVARCHAR(200),
    ClockNumber  NVARCHAR(20),
    PinHash      NVARCHAR(255),
    IgnitionRole NVARCHAR(100),
    CreatedAt    DATETIME2(3),
    DeprecatedAt DATETIME2(3)
);

INSERT INTO #ByClock3
EXEC Location.AppUser_GetByClockNumber @ClockNumber = N'CLK000000';

DECLARE @RowCount3 INT = (SELECT COUNT(*) FROM #ByClock3);
DROP TABLE #ByClock3;

EXEC test.Assert_RowCount
    @TestName      = N'GetByClockNumber non-existent: 0 rows returned',
    @ExpectedCount = 0,
    @ActualCount   = @RowCount3;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
