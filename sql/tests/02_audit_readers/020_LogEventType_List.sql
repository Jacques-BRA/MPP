-- =============================================
-- File:         02_audit_readers/020_LogEventType_List.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Audit.LogEventType_List.
--   Covers: successful execution and seed row count.
--
--   Pre-conditions:
--     - Migration 0001 applied (audit lookup seeds present)
--     - Audit.LogEventType_List deployed
-- =============================================

EXEC test.BeginTestFile @FileName = N'02_audit_readers/020_LogEventType_List.sql';
GO

-- =============================================
-- Test 1: Proc executes and returns seed rows.
--   Verify at least 20 event types present.
-- =============================================
CREATE TABLE #EventTypes (
    Id          BIGINT,
    Code        NVARCHAR(50),
    Name        NVARCHAR(100),
    Description NVARCHAR(500)
);

INSERT INTO #EventTypes
EXEC Audit.LogEventType_List;

-- Assert 1a: at least 20 event types returned
DECLARE @RowCount    INT = (SELECT COUNT(*) FROM #EventTypes);
DECLARE @Condition1a BIT = CASE WHEN @RowCount >= 20 THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'LogEventType_List: at least 20 event types returned',
    @Condition = @Condition1a;

-- Assert 1b: Created event type exists
DECLARE @HasCreated BIT = CASE WHEN EXISTS (SELECT 1 FROM #EventTypes WHERE Code = N'Created') THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'LogEventType_List: Created event type exists',
    @Condition = @HasCreated;

DROP TABLE #EventTypes;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
