-- =============================================
-- File:         02_audit_readers/030_LogSeverity_List.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Audit.LogSeverity_List.
--   Covers: successful execution and exact seed row count.
--
--   Pre-conditions:
--     - Migration 0001 applied (audit lookup seeds present)
--     - Audit.LogSeverity_List deployed
-- =============================================

EXEC test.BeginTestFile @FileName = N'02_audit_readers/030_LogSeverity_List.sql';
GO

-- =============================================
-- Test 1: Proc executes and returns exactly 4 severity levels.
-- =============================================
CREATE TABLE #Severities (
    Id   BIGINT,
    Code NVARCHAR(50),
    Name NVARCHAR(100)
);

INSERT INTO #Severities
EXEC Audit.LogSeverity_List;

-- Assert 1a: exactly 4 severity levels returned
DECLARE @RowCount    INT = (SELECT COUNT(*) FROM #Severities);
DECLARE @RowCountStr NVARCHAR(10) = CAST(@RowCount AS NVARCHAR(10));
EXEC test.Assert_IsEqual
    @TestName = N'LogSeverity_List: exactly 4 severity levels returned',
    @Expected = N'4',
    @Actual   = @RowCountStr;

-- Assert 1b: Info severity exists
DECLARE @HasInfo BIT = CASE WHEN EXISTS (SELECT 1 FROM #Severities WHERE Code = N'Info') THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'LogSeverity_List: Info severity exists',
    @Condition = @HasInfo;

DROP TABLE #Severities;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
