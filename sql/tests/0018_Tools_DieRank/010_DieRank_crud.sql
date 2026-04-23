-- =============================================
-- File:         0018_Tools_DieRank/010_DieRank_crud.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-23
-- Description:
--   Tests for Tools.DieRank and Tools.DieRankCompatibility:
--     DieRank CRUD; sort via MoveUp/MoveDown
--     DieRankCompatibility canonical-pair Upsert (A,B) == (B,A)
--     GetPair direction-independent lookup
--     Remove; List
-- =============================================

EXEC test.BeginTestFile @FileName = N'0018_Tools_DieRank/010_DieRank_crud.sql';
GO

-- =============================================
-- Setup: create three ranks (A, B, C)
-- =============================================
CREATE TABLE #RA (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RA EXEC Tools.DieRank_Create
    @Code = N'DR-A', @Name = N'Rank A', @AppUserId = 1;
DROP TABLE #RA;

CREATE TABLE #RB (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RB EXEC Tools.DieRank_Create
    @Code = N'DR-B', @Name = N'Rank B', @AppUserId = 1;
DROP TABLE #RB;

CREATE TABLE #RC (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RC EXEC Tools.DieRank_Create
    @Code = N'DR-C', @Name = N'Rank C', @AppUserId = 1;
DROP TABLE #RC;
GO

-- =============================================
-- Test 1: DieRank_List returns 3 rows in SortOrder
-- =============================================
CREATE TABLE #L (Id BIGINT, Code NVARCHAR(20), Name NVARCHAR(100),
                 Description NVARCHAR(500), SortOrder INT,
                 CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3));
INSERT INTO #L EXEC Tools.DieRank_List;

DECLARE @Count INT = (SELECT COUNT(*) FROM #L WHERE Code LIKE N'DR-%');
EXEC test.Assert_RowCount
    @TestName = N'[DieRank_List] 3 new ranks returned',
    @ExpectedCount = 3, @ActualCount = @Count;

-- SortOrder: DR-A should come before DR-B (assert by comparing SortOrders directly)
DECLARE @A INT = (SELECT SortOrder FROM #L WHERE Code = N'DR-A');
DECLARE @B INT = (SELECT SortOrder FROM #L WHERE Code = N'DR-B');
DECLARE @ALess BIT = CASE WHEN @A < @B THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName = N'[DieRank_List] DR-A SortOrder < DR-B SortOrder',
    @Condition = @ALess;
DROP TABLE #L;
GO

-- =============================================
-- Test 2: MoveDown — DR-A should swap with DR-B
-- =============================================
DECLARE @AId BIGINT = (SELECT Id FROM Tools.DieRank WHERE Code = N'DR-A');

CREATE TABLE #MV (Status BIT, Message NVARCHAR(500));
INSERT INTO #MV EXEC Tools.DieRank_MoveDown @Id = @AId, @AppUserId = 1;
DECLARE @S BIT = (SELECT Status FROM #MV);
DECLARE @SStr NVARCHAR(1) = CAST(@S AS NVARCHAR(1));
DROP TABLE #MV;

EXEC test.Assert_IsEqual
    @TestName = N'[DieRank_MoveDown] Status is 1',
    @Expected = N'1', @Actual = @SStr;

DECLARE @NewA INT = (SELECT SortOrder FROM Tools.DieRank WHERE Code = N'DR-A');
DECLARE @NewB INT = (SELECT SortOrder FROM Tools.DieRank WHERE Code = N'DR-B');
DECLARE @Swapped BIT = CASE WHEN @NewA > @NewB THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName = N'[DieRank_MoveDown] A now sorts after B',
    @Condition = @Swapped;
GO

-- =============================================
-- Test 3: Compatibility Upsert canonicalises (B, A) -> (A, B)
-- =============================================
DECLARE @AId BIGINT = (SELECT Id FROM Tools.DieRank WHERE Code = N'DR-A');
DECLARE @BId BIGINT = (SELECT Id FROM Tools.DieRank WHERE Code = N'DR-B');

CREATE TABLE #U1 (Status BIT, Message NVARCHAR(500));
INSERT INTO #U1 EXEC Tools.DieRankCompatibility_Upsert
    @RankA = @BId, @RankB = @AId, @CanMix = 1, @AppUserId = 1;
DECLARE @S BIT = (SELECT Status FROM #U1);
DECLARE @SStr NVARCHAR(1) = CAST(@S AS NVARCHAR(1));
DROP TABLE #U1;

EXEC test.Assert_IsEqual
    @TestName = N'[Compat Upsert (B,A)] Status is 1',
    @Expected = N'1', @Actual = @SStr;

-- Canonical storage: RankAId = lesser Id
DECLARE @LoId BIGINT = CASE WHEN @AId <= @BId THEN @AId ELSE @BId END;
DECLARE @HiId BIGINT = CASE WHEN @AId <= @BId THEN @BId ELSE @AId END;

DECLARE @RowCount INT;
SELECT @RowCount = COUNT(*) FROM Tools.DieRankCompatibility
WHERE RankAId = @LoId AND RankBId = @HiId;
EXEC test.Assert_RowCount
    @TestName = N'[Compat Upsert] row stored in canonical order',
    @ExpectedCount = 1, @ActualCount = @RowCount;

-- Second Upsert with reversed order — should be idempotent (same row, updated CanMix)
CREATE TABLE #U2 (Status BIT, Message NVARCHAR(500));
INSERT INTO #U2 EXEC Tools.DieRankCompatibility_Upsert
    @RankA = @AId, @RankB = @BId, @CanMix = 0, @AppUserId = 1;
DROP TABLE #U2;

SELECT @RowCount = COUNT(*) FROM Tools.DieRankCompatibility
WHERE (RankAId = @LoId AND RankBId = @HiId)
   OR (RankAId = @HiId AND RankBId = @LoId);
EXEC test.Assert_RowCount
    @TestName = N'[Compat Upsert] still exactly 1 row (idempotent)',
    @ExpectedCount = 1, @ActualCount = @RowCount;

DECLARE @CurrentCanMix BIT;
SELECT @CurrentCanMix = CanMix FROM Tools.DieRankCompatibility
WHERE RankAId = @LoId AND RankBId = @HiId;
DECLARE @CanMixStr NVARCHAR(1) = CAST(@CurrentCanMix AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[Compat Upsert] CanMix updated to 0',
    @Expected = N'0', @Actual = @CanMixStr;
GO

-- =============================================
-- Test 4: GetPair is direction-independent
-- =============================================
DECLARE @AId BIGINT = (SELECT Id FROM Tools.DieRank WHERE Code = N'DR-A');
DECLARE @BId BIGINT = (SELECT Id FROM Tools.DieRank WHERE Code = N'DR-B');

CREATE TABLE #P (Id BIGINT, RankAId BIGINT, RankACode NVARCHAR(20),
                 RankBId BIGINT, RankBCode NVARCHAR(20),
                 CanMix BIT, CreatedAt DATETIME2(3), UpdatedAt DATETIME2(3));
INSERT INTO #P EXEC Tools.DieRankCompatibility_GetPair
    @RankA = @BId, @RankB = @AId;
DECLARE @Count INT = (SELECT COUNT(*) FROM #P);
EXEC test.Assert_RowCount
    @TestName = N'[GetPair (B,A)] returns 1 row',
    @ExpectedCount = 1, @ActualCount = @Count;
DROP TABLE #P;
GO

-- =============================================
-- Test 5: Compatibility Remove hard-deletes the row
-- =============================================
DECLARE @AId BIGINT = (SELECT Id FROM Tools.DieRank WHERE Code = N'DR-A');
DECLARE @BId BIGINT = (SELECT Id FROM Tools.DieRank WHERE Code = N'DR-B');

CREATE TABLE #RM (Status BIT, Message NVARCHAR(500));
INSERT INTO #RM EXEC Tools.DieRankCompatibility_Remove
    @RankA = @AId, @RankB = @BId, @AppUserId = 1;
DECLARE @S BIT = (SELECT Status FROM #RM);
DECLARE @SStr NVARCHAR(1) = CAST(@S AS NVARCHAR(1));
DROP TABLE #RM;

EXEC test.Assert_IsEqual
    @TestName = N'[Compat Remove] Status is 1',
    @Expected = N'1', @Actual = @SStr;

DECLARE @LoId BIGINT = CASE WHEN @AId <= @BId THEN @AId ELSE @BId END;
DECLARE @HiId BIGINT = CASE WHEN @AId <= @BId THEN @BId ELSE @AId END;
DECLARE @RowCount INT;
SELECT @RowCount = COUNT(*) FROM Tools.DieRankCompatibility
WHERE RankAId = @LoId AND RankBId = @HiId;
EXEC test.Assert_RowCount
    @TestName = N'[Compat Remove] row gone',
    @ExpectedCount = 0, @ActualCount = @RowCount;
GO

EXEC test.PrintSummary;
GO
