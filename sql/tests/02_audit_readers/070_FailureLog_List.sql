-- =============================================
-- File:         02_audit_readers/070_FailureLog_List.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Audit.FailureLog_List.
--   Covers: date range returns rows, and ProcedureName filter
--   restricts results to matching rows only.
--
--   Pre-conditions:
--     - Migration 0001 applied (audit lookup seeds present)
--     - Location.AppUser Id=1 (system.bootstrap) present
--     - Audit.Audit_LogFailure deployed
--     - Audit.FailureLog_List deployed
--     - FailureLog already contains rows from 060_FailureLog_GetByEntity.sql
--       (or this file seeds its own rows below)
-- =============================================

EXEC test.BeginTestFile @FileName = N'02_audit_readers/070_FailureLog_List.sql';
GO

-- =============================================
-- Setup: Insert rows with a unique ProcedureName so the
--   ProcedureName filter test has a clean set to verify.
--   Two rows use Test070.Unique_Proc; one uses a different name.
-- =============================================
EXEC Audit.Audit_LogFailure
    @AppUserId           = 1,
    @LogEntityTypeCode   = N'AppUser',
    @EntityId            = 88,
    @LogEventTypeCode    = N'Created',
    @FailureReason       = N'Test 070: row A - duplicate AdAccount',
    @ProcedureName       = N'Test070.Unique_Proc',
    @AttemptedParameters = N'{"AdAccount":"test070a"}';

EXEC Audit.Audit_LogFailure
    @AppUserId           = 1,
    @LogEntityTypeCode   = N'AppUser',
    @EntityId            = 88,
    @LogEventTypeCode    = N'Updated',
    @FailureReason       = N'Test 070: row B - user not found',
    @ProcedureName       = N'Test070.Unique_Proc',
    @AttemptedParameters = N'{"Id":88}';

EXEC Audit.Audit_LogFailure
    @AppUserId           = 1,
    @LogEntityTypeCode   = N'Location',
    @EntityId            = 88,
    @LogEventTypeCode    = N'Created',
    @FailureReason       = N'Test 070: row C - name conflict',
    @ProcedureName       = N'Test070.Other_Proc',
    @AttemptedParameters = NULL;
GO

-- =============================================
-- Test 1: Date range query returns rows.
--   Wide window: 1 hour ago to 1 hour from now.
--   Expect at least 1 row returned.
-- =============================================
DECLARE @Start DATETIME2(3) = DATEADD(HOUR, -1, SYSUTCDATETIME());
DECLARE @End   DATETIME2(3) = DATEADD(HOUR,  1, SYSUTCDATETIME());

CREATE TABLE #List1 (
    Id                  BIGINT,
    AttemptedAt         DATETIME2(3),
    AppUserId           BIGINT,
    UserDisplayName     NVARCHAR(200),
    LogEntityTypeId     BIGINT,
    LogEntityTypeName   NVARCHAR(100),
    EntityId            BIGINT,
    LogEventTypeId      BIGINT,
    LogEventTypeName    NVARCHAR(100),
    FailureReason       NVARCHAR(500),
    ProcedureName       NVARCHAR(200),
    AttemptedParameters NVARCHAR(MAX)
);

INSERT INTO #List1
EXEC Audit.FailureLog_List
    @StartDate = @Start,
    @EndDate   = @End;

-- Assert 1a: at least 1 row returned (setup rows are within the window)
DECLARE @TotalCount  INT = (SELECT COUNT(*) FROM #List1);
DECLARE @Condition1a BIT = CASE WHEN @TotalCount >= 1 THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'FailureLog_List date range: at least 1 row returned',
    @Condition = @Condition1a;

DROP TABLE #List1;
GO

-- =============================================
-- Test 2: ProcedureName filter returns only matching rows.
--   Filter on Test070.Unique_Proc - expect exactly 2 setup rows
--   and zero rows with a different ProcedureName.
-- =============================================
DECLARE @Start DATETIME2(3) = DATEADD(HOUR, -1, SYSUTCDATETIME());
DECLARE @End   DATETIME2(3) = DATEADD(HOUR,  1, SYSUTCDATETIME());

CREATE TABLE #List2 (
    Id                  BIGINT,
    AttemptedAt         DATETIME2(3),
    AppUserId           BIGINT,
    UserDisplayName     NVARCHAR(200),
    LogEntityTypeId     BIGINT,
    LogEntityTypeName   NVARCHAR(100),
    EntityId            BIGINT,
    LogEventTypeId      BIGINT,
    LogEventTypeName    NVARCHAR(100),
    FailureReason       NVARCHAR(500),
    ProcedureName       NVARCHAR(200),
    AttemptedParameters NVARCHAR(MAX)
);

INSERT INTO #List2
EXEC Audit.FailureLog_List
    @StartDate     = @Start,
    @EndDate       = @End,
    @ProcedureName = N'Test070.Unique_Proc';

-- Assert 2a: all returned rows match the filter proc name
DECLARE @NonMatchCount INT = (
    SELECT COUNT(*)
    FROM #List2
    WHERE ProcedureName <> N'Test070.Unique_Proc'
);
DECLARE @NonMatchStr NVARCHAR(5) = CAST(@NonMatchCount AS NVARCHAR(5));
EXEC test.Assert_IsEqual
    @TestName = N'FailureLog_List proc filter: all rows match filter',
    @Expected = N'0',
    @Actual   = @NonMatchStr;

-- Assert 2b: exactly 2 rows from this file's setup match
DECLARE @SetupMatchCount INT = (
    SELECT COUNT(*)
    FROM #List2
    WHERE FailureReason LIKE N'Test 070:%'
);
EXEC test.Assert_RowCount
    @TestName      = N'FailureLog_List proc filter: 2 setup rows returned',
    @ExpectedCount = 2,
    @ActualCount   = @SetupMatchCount;

DROP TABLE #List2;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
