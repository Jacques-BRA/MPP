-- =============================================
-- File:         02_audit_readers/090_FailureLog_GetTopReasons.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Audit.FailureLog_GetTopReasons.
--   Covers: proc returns aggregated rows without entity filter,
--   entity type filter works, and invalid entity type returns 0 rows.
--
--   Pre-conditions:
--     - Migration 0001 applied (audit lookup seeds present)
--     - Location.AppUser Id=1 (system.bootstrap) present
--     - Audit.Audit_LogFailure deployed
--     - Audit.FailureLog_GetTopReasons deployed
-- =============================================

EXEC test.BeginTestFile @FileName = N'02_audit_readers/090_FailureLog_GetTopReasons.sql';
GO

-- =============================================
-- Setup: Insert rows with a unique reason so the aggregation test
--   has something predictable to verify.
--   Two rows share the same reason (Test090.Reason.High);
--   one row has a different reason (Test090.Reason.Low).
--   The test below uses a tight time window (~30s) to avoid competing
--   for the proc's TOP 50 slots with prior tests' FailureLog entries.
-- =============================================
EXEC Audit.Audit_LogFailure
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @LogEventTypeCode  = N'Created',
    @FailureReason     = N'Test090.Reason.High',
    @ProcedureName     = N'Test090.Proc';

EXEC Audit.Audit_LogFailure
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @LogEventTypeCode  = N'Updated',
    @FailureReason     = N'Test090.Reason.High',
    @ProcedureName     = N'Test090.Proc';

EXEC Audit.Audit_LogFailure
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @LogEventTypeCode  = N'Deprecated',
    @FailureReason     = N'Test090.Reason.Low',
    @ProcedureName     = N'Test090.Proc';
GO

-- =============================================
-- Test 1: No entity filter - returns aggregated rows.
--   Verify at least 1 row. Also verify that
--   Test090.Reason.High has a higher count than Test090.Reason.Low.
-- =============================================
DECLARE @Start DATETIME2(3) = DATEADD(SECOND, -30, SYSUTCDATETIME());
DECLARE @End   DATETIME2(3) = DATEADD(SECOND,  30, SYSUTCDATETIME());

CREATE TABLE #TopReasons1 (
    FailureReason NVARCHAR(500),
    FailureCount  INT
);

INSERT INTO #TopReasons1
EXEC Audit.FailureLog_GetTopReasons
    @StartDate     = @Start,
    @EndDate       = @End,
    @ProcedureName = N'Test090.Proc';

-- Assert 1a: at least 1 row returned
DECLARE @TotalRows1  INT = (SELECT COUNT(*) FROM #TopReasons1);
DECLARE @Condition1a BIT = CASE WHEN @TotalRows1 >= 1 THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'GetTopReasons no filter: at least 1 row returned',
    @Condition = @Condition1a;

-- Assert 1b: Test090.Reason.High (count 2) outranks Test090.Reason.Low (count 1)
DECLARE @HighCount   INT = (SELECT FailureCount FROM #TopReasons1 WHERE FailureReason = N'Test090.Reason.High');
DECLARE @LowCount    INT = (SELECT FailureCount FROM #TopReasons1 WHERE FailureReason = N'Test090.Reason.Low');
DECLARE @Condition1b BIT = CASE WHEN @HighCount > @LowCount THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'GetTopReasons no filter: High reason (2 hits) outranks Low reason (1 hit)',
    @Condition = @Condition1b;

DROP TABLE #TopReasons1;
GO

-- =============================================
-- Test 2: Valid entity type filter returns rows.
-- =============================================
DECLARE @Start DATETIME2(3) = DATEADD(SECOND, -30, SYSUTCDATETIME());
DECLARE @End   DATETIME2(3) = DATEADD(SECOND,  30, SYSUTCDATETIME());

CREATE TABLE #TopReasons2 (
    FailureReason NVARCHAR(500),
    FailureCount  INT
);

INSERT INTO #TopReasons2
EXEC Audit.FailureLog_GetTopReasons
    @StartDate         = @Start,
    @EndDate           = @End,
    @LogEntityTypeCode = N'AppUser';

-- Assert 2a: at least 1 row returned with valid entity filter
DECLARE @TotalRows2  INT = (SELECT COUNT(*) FROM #TopReasons2);
DECLARE @Condition2a BIT = CASE WHEN @TotalRows2 >= 1 THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'GetTopReasons entity filter AppUser: at least 1 row returned',
    @Condition = @Condition2a;

DROP TABLE #TopReasons2;
GO

-- =============================================
-- Test 3: Invalid entity type code returns 0 rows.
--   Read procs no longer return Status — invalid filters
--   simply produce empty result sets.
-- =============================================
DECLARE @Start DATETIME2(3) = DATEADD(SECOND, -30, SYSUTCDATETIME());
DECLARE @End   DATETIME2(3) = DATEADD(SECOND,  30, SYSUTCDATETIME());

CREATE TABLE #TopReasons3 (
    FailureReason NVARCHAR(500),
    FailureCount  INT
);

INSERT INTO #TopReasons3
EXEC Audit.FailureLog_GetTopReasons
    @StartDate         = @Start,
    @EndDate           = @End,
    @LogEntityTypeCode = N'BOGUS_ENTITY_TYPE';

-- Assert 3a: 0 rows returned for invalid entity type code
DECLARE @RowCount3 INT = (SELECT COUNT(*) FROM #TopReasons3);
EXEC test.Assert_RowCount
    @TestName      = N'GetTopReasons invalid entity code: 0 rows returned',
    @ExpectedCount = 0,
    @ActualCount   = @RowCount3;

DROP TABLE #TopReasons3;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
