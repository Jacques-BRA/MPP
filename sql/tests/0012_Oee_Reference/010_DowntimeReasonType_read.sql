-- =============================================
-- File:         0012_Oee_Reference/010_DowntimeReasonType_read.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-15
-- Description:
--   Tests for Oee.DowntimeReasonType_List (Phase 8 read-only seed).
--   Six fixed seeded rows at deterministic Ids 1-6:
--     1=Equipment, 2=Miscellaneous, 3=Mold,
--     4=Quality,   5=Setup,         6=Unscheduled.
-- =============================================

EXEC test.BeginTestFile @FileName = N'0012_Oee_Reference/010_DowntimeReasonType_read.sql';
GO

-- =============================================
-- Test: DowntimeReasonType_List returns exactly 6 rows
-- =============================================
DECLARE @Count INT;
CREATE TABLE #R (Id BIGINT, Code NVARCHAR(30), Name NVARCHAR(100));
INSERT INTO #R EXEC Oee.DowntimeReasonType_List;
SELECT @Count = COUNT(*) FROM #R;
DROP TABLE #R;
EXEC test.Assert_RowCount
    @TestName      = N'DowntimeReasonType_List: 6 rows returned by proc',
    @ExpectedCount = 6,
    @ActualCount   = @Count;
GO

-- =============================================
-- Test: Code='Equipment' has Id = 1
-- =============================================
DECLARE @Id BIGINT;
SELECT @Id = Id FROM Oee.DowntimeReasonType WHERE Code = N'Equipment';
DECLARE @IdStr NVARCHAR(20) = CAST(@Id AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName = N'DowntimeReasonType: Equipment has Id 1',
    @Expected = N'1',
    @Actual   = @IdStr;
GO

-- =============================================
-- Test: Code='Unscheduled' has Id = 6
-- =============================================
DECLARE @Id BIGINT;
SELECT @Id = Id FROM Oee.DowntimeReasonType WHERE Code = N'Unscheduled';
DECLARE @IdStr NVARCHAR(20) = CAST(@Id AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName = N'DowntimeReasonType: Unscheduled has Id 6',
    @Expected = N'6',
    @Actual   = @IdStr;
GO

-- =============================================
-- Test: All 6 expected codes present (via List proc)
-- =============================================
DECLARE @MatchCount INT;
CREATE TABLE #L (Id BIGINT, Code NVARCHAR(30), Name NVARCHAR(100));
INSERT INTO #L EXEC Oee.DowntimeReasonType_List;
SELECT @MatchCount = COUNT(*)
FROM #L
WHERE Code IN (N'Equipment', N'Miscellaneous', N'Mold',
               N'Quality',   N'Setup',         N'Unscheduled');
DROP TABLE #L;
EXEC test.Assert_RowCount
    @TestName      = N'DowntimeReasonType_List: all 6 expected codes present',
    @ExpectedCount = 6,
    @ActualCount   = @MatchCount;
GO

EXEC test.EndTestFile;
GO
