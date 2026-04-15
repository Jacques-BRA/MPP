-- =============================================
-- File:         02_audit_readers/010_LogEntityType_List.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Audit.LogEntityType_List.
--   Covers: successful execution and seed row count.
--
--   Pre-conditions:
--     - Migration 0001 applied (audit lookup seeds present)
--     - Audit.LogEntityType_List deployed
-- =============================================

EXEC test.BeginTestFile @FileName = N'02_audit_readers/010_LogEntityType_List.sql';
GO

-- =============================================
-- Test 1: Proc executes and returns seed rows.
--   Verify at least 24 entity types present.
-- =============================================
CREATE TABLE #EntityTypes (
    Id          BIGINT,
    Code        NVARCHAR(50),
    Name        NVARCHAR(100),
    Description NVARCHAR(500)
);

INSERT INTO #EntityTypes
EXEC Audit.LogEntityType_List;

-- Assert 1a: at least 24 entity types returned
DECLARE @RowCount INT = (SELECT COUNT(*) FROM #EntityTypes);
DECLARE @Condition1a BIT = CASE WHEN @RowCount >= 24 THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'LogEntityType_List: at least 24 entity types returned',
    @Condition = @Condition1a;

-- Assert 1b: Location entity type exists
DECLARE @HasLocation BIT = CASE WHEN EXISTS (SELECT 1 FROM #EntityTypes WHERE Code = N'Location') THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'LogEntityType_List: Location entity type exists',
    @Condition = @HasLocation;

DROP TABLE #EntityTypes;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
