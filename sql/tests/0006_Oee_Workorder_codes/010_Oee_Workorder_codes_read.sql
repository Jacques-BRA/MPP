-- =============================================
-- File:         0006_Oee_Workorder_codes/010_Oee_Workorder_codes_read.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Rewritten:    2026-04-14 (Ignition JDBC refactor)
-- Description:
--   Tests for Oee and Workorder schema reference code tables (Phase 3 read-only).
--   Covers 3 tables, each with _List and _Get procs:
--     - Oee.DowntimeSourceCode     (3 seeded rows)
--     - Workorder.OperationStatus  (4 seeded rows)
--     - Workorder.WorkOrderStatus  (4 seeded rows)
-- =============================================

EXEC test.BeginTestFile @FileName = N'0006_Oee_Workorder_codes/010_Oee_Workorder_codes_read.sql';
GO

-- =============================================
-- == Oee.DowntimeSourceCode ==================================
-- =============================================

DECLARE @Count INT;
CREATE TABLE #R (Id BIGINT, Code NVARCHAR(50), Name NVARCHAR(100));
INSERT INTO #R EXEC Oee.DowntimeSourceCode_List;
SELECT @Count = COUNT(*) FROM #R;
DROP TABLE #R;
EXEC test.Assert_RowCount
    @TestName      = N'DowntimeSourceCode_List: 3 rows returned by proc',
    @ExpectedCount = 3,
    @ActualCount   = @Count;
GO

DECLARE @Count INT;
CREATE TABLE #R (Id BIGINT, Code NVARCHAR(50), Name NVARCHAR(100));
INSERT INTO #R EXEC Oee.DowntimeSourceCode_Get @Id = 1;
SELECT @Count = COUNT(*) FROM #R;
DROP TABLE #R;
EXEC test.Assert_RowCount
    @TestName      = N'DowntimeSourceCode_Get(1): 1 row returned',
    @ExpectedCount = 1,
    @ActualCount   = @Count;
GO


-- =============================================
-- == Workorder.OperationStatus ===============================
-- =============================================

DECLARE @Count INT;
CREATE TABLE #R (Id BIGINT, Code NVARCHAR(50), Name NVARCHAR(100));
INSERT INTO #R EXEC Workorder.OperationStatus_List;
SELECT @Count = COUNT(*) FROM #R;
DROP TABLE #R;
EXEC test.Assert_RowCount
    @TestName      = N'OperationStatus_List: 4 rows returned by proc',
    @ExpectedCount = 4,
    @ActualCount   = @Count;
GO

DECLARE @Count INT;
CREATE TABLE #R (Id BIGINT, Code NVARCHAR(50), Name NVARCHAR(100));
INSERT INTO #R EXEC Workorder.OperationStatus_Get @Id = 1;
SELECT @Count = COUNT(*) FROM #R;
DROP TABLE #R;
EXEC test.Assert_RowCount
    @TestName      = N'OperationStatus_Get(1): 1 row returned',
    @ExpectedCount = 1,
    @ActualCount   = @Count;
GO


-- =============================================
-- == Workorder.WorkOrderStatus ===============================
-- =============================================

DECLARE @Count INT;
CREATE TABLE #R (Id BIGINT, Code NVARCHAR(50), Name NVARCHAR(100));
INSERT INTO #R EXEC Workorder.WorkOrderStatus_List;
SELECT @Count = COUNT(*) FROM #R;
DROP TABLE #R;
EXEC test.Assert_RowCount
    @TestName      = N'WorkOrderStatus_List: 4 rows returned by proc',
    @ExpectedCount = 4,
    @ActualCount   = @Count;
GO

DECLARE @Count INT;
CREATE TABLE #R (Id BIGINT, Code NVARCHAR(50), Name NVARCHAR(100));
INSERT INTO #R EXEC Workorder.WorkOrderStatus_Get @Id = 1;
SELECT @Count = COUNT(*) FROM #R;
DROP TABLE #R;
EXEC test.Assert_RowCount
    @TestName      = N'WorkOrderStatus_Get(1): 1 row returned',
    @ExpectedCount = 1,
    @ActualCount   = @Count;
GO


-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
