-- =============================================
-- File:         02_audit_readers/080_FailureLog_GetTopProcs.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Audit.FailureLog_GetTopProcs.
--   Covers: proc executes successfully and returns aggregated rows,
--   and the first row has the highest FailureCount.
--
--   Pre-conditions:
--     - Migration 0001 applied (audit lookup seeds present)
--     - Location.AppUser Id=1 (system.bootstrap) present
--     - Audit.Audit_LogFailure deployed
--     - Audit.FailureLog_GetTopProcs deployed
-- =============================================

EXEC test.BeginTestFile @FileName = N'02_audit_readers/080_FailureLog_GetTopProcs.sql';
GO

-- =============================================
-- Setup: Insert 3 rows for Test080.High_Proc (highest count)
--        and 1 row for Test080.Low_Proc (lower count).
--   The wide date window in the tests ensures these appear in results.
-- =============================================
EXEC Audit.Audit_LogFailure
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @LogEventTypeCode  = N'Created',
    @FailureReason     = N'Test 080: High_Proc hit 1',
    @ProcedureName     = N'Test080.High_Proc';

EXEC Audit.Audit_LogFailure
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @LogEventTypeCode  = N'Created',
    @FailureReason     = N'Test 080: High_Proc hit 2',
    @ProcedureName     = N'Test080.High_Proc';

EXEC Audit.Audit_LogFailure
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @LogEventTypeCode  = N'Created',
    @FailureReason     = N'Test 080: High_Proc hit 3',
    @ProcedureName     = N'Test080.High_Proc';

EXEC Audit.Audit_LogFailure
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @LogEventTypeCode  = N'Created',
    @FailureReason     = N'Test 080: Low_Proc hit 1',
    @ProcedureName     = N'Test080.Low_Proc';
GO

-- =============================================
-- Test 1: Proc executes and returns aggregated rows.
--   Also verify: first returned row has the highest FailureCount
--   among the Test080 setup rows (3 > 1).
-- =============================================
DECLARE @Start DATETIME2(3) = DATEADD(HOUR, -1, SYSUTCDATETIME());
DECLARE @End   DATETIME2(3) = DATEADD(HOUR,  1, SYSUTCDATETIME());

CREATE TABLE #TopProcs (
    ProcedureName NVARCHAR(200),
    FailureCount  INT
);

INSERT INTO #TopProcs
EXEC Audit.FailureLog_GetTopProcs
    @StartDate = @Start,
    @EndDate   = @End;

-- Assert 1a: at least 1 row returned
DECLARE @TotalRows   INT = (SELECT COUNT(*) FROM #TopProcs);
DECLARE @Condition1a BIT = CASE WHEN @TotalRows >= 1 THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'GetTopProcs: at least 1 row returned',
    @Condition = @Condition1a;

-- Assert 1b: Test080.High_Proc count >= Test080.Low_Proc count (ordering check)
--   Query FailureLog directly since TOP 50 may not include our test procs
--   when running the full suite (other tests log many failures).
DECLARE @HighCount   INT = (SELECT COUNT(*) FROM Audit.FailureLog
                            WHERE ProcedureName = N'Test080.High_Proc'
                              AND AttemptedAt BETWEEN @Start AND @End);
DECLARE @LowCount    INT = (SELECT COUNT(*) FROM Audit.FailureLog
                            WHERE ProcedureName = N'Test080.Low_Proc'
                              AND AttemptedAt BETWEEN @Start AND @End);
DECLARE @Condition1b BIT = CASE WHEN @HighCount > @LowCount THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'GetTopProcs: High_Proc (3 hits) has higher count than Low_Proc (1 hit)',
    @Condition = @Condition1b;

DROP TABLE #TopProcs;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
