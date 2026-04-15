-- =============================================
-- File:         0010_Parts_Bom/020_BomLine_crud.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-14
-- Description:
--   Tests for Parts.BomLine procs:
--     Parts.BomLine_ListByBom
--     Parts.BomLine_Add
--     Parts.BomLine_Update
--     Parts.BomLine_MoveUp
--     Parts.BomLine_MoveDown
--     Parts.BomLine_Remove
--
--   Covers: Add happy (SortOrder auto 1..N), NULL/invalid BomId/
--   ChildItemId/UomId, self-reference rejection, duplicate ChildItemId
--   rejection, list-by-bom, Update happy + invalid UomId, MoveUp/
--   MoveDown + first-row no-op, Remove hard-delete + compact siblings,
--   published-BOM immutability lock on every mutator, audit trail.
--
--   Pre-conditions:
--     - Migration 0001-0006 applied
--     - AppUser Id=1 exists
--     - Parts.ItemType and Parts.Uom seeds present
--     - All Parts.Bom_* and Parts.BomLine_* procs deployed
-- =============================================

EXEC test.BeginTestFile @FileName = N'0010_Parts_Bom/020_BomLine_crud.sql';
GO

-- =============================================
-- Setup: parent + 3 child Items + Draft BOM v1
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @NewId BIGINT,
        @PId   BIGINT;

CREATE TABLE #Rc35 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc35
EXEC Parts.Item_Create
    @PartNumber  = N'TEST-BL-PARENT-001',
    @ItemTypeId  = 4,
    @Description = N'Test BomLine parent',
    @UomId       = 1,
    @AppUserId   = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #Rc35;
DROP TABLE #Rc35;

CREATE TABLE #Rc36 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc36
EXEC Parts.Item_Create
    @PartNumber  = N'TEST-BL-CHILD-001',
    @ItemTypeId  = 2,
    @Description = N'Test BL child 1',
    @UomId       = 1,
    @AppUserId   = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #Rc36;
DROP TABLE #Rc36;

CREATE TABLE #Rc37 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc37
EXEC Parts.Item_Create
    @PartNumber  = N'TEST-BL-CHILD-002',
    @ItemTypeId  = 2,
    @Description = N'Test BL child 2',
    @UomId       = 1,
    @AppUserId   = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #Rc37;
DROP TABLE #Rc37;

CREATE TABLE #Rc38 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc38
EXEC Parts.Item_Create
    @PartNumber  = N'TEST-BL-CHILD-003',
    @ItemTypeId  = 2,
    @Description = N'Test BL child 3',
    @UomId       = 1,
    @AppUserId   = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #Rc38;
DROP TABLE #Rc38;

SELECT @PId = Id FROM Parts.Item WHERE PartNumber = N'TEST-BL-PARENT-001';

CREATE TABLE #Rc1 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc1
EXEC Parts.Bom_Create
    @ParentItemId = @PId,
    @AppUserId    = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #Rc1;
DROP TABLE #Rc1;
GO

-- =============================================
-- Test 1: BomLine_Add 3 times - SortOrder 1, 2, 3 auto-assigned
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @C1    BIGINT,
        @C2    BIGINT,
        @C3    BIGINT,
        @Ln1   BIGINT,
        @Ln2   BIGINT,
        @Ln3   BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT @C1 = Id FROM Parts.Item WHERE PartNumber = N'TEST-BL-CHILD-001';
SELECT @C2 = Id FROM Parts.Item WHERE PartNumber = N'TEST-BL-CHILD-002';
SELECT @C3 = Id FROM Parts.Item WHERE PartNumber = N'TEST-BL-CHILD-003';

CREATE TABLE #Rc2 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc2
EXEC Parts.BomLine_Add
    @BomId = @BomId, @ChildItemId = @C1, @QtyPer = 1.0, @UomId = 1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message, @Ln1 = NewId FROM #Rc2;
DROP TABLE #Rc2;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnAdd1] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

CREATE TABLE #Rc3 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc3
EXEC Parts.BomLine_Add
    @BomId = @BomId, @ChildItemId = @C2, @QtyPer = 2.0, @UomId = 1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message, @Ln2 = NewId FROM #Rc3;
DROP TABLE #Rc3;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnAdd2] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

CREATE TABLE #Rc4 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc4
EXEC Parts.BomLine_Add
    @BomId = @BomId, @ChildItemId = @C3, @QtyPer = 3.0, @UomId = 1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message, @Ln3 = NewId FROM #Rc4;
DROP TABLE #Rc4;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnAdd3] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

-- All three Ids distinct
DECLARE @DistinctStr NVARCHAR(1) = CASE
    WHEN @Ln1 <> @Ln2 AND @Ln2 <> @Ln3 AND @Ln1 <> @Ln3
    THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[LnAdd] Three NewId values distinct',
    @Expected = N'1',
    @Actual   = @DistinctStr;

-- SortOrder 1, 2, 3 via direct query
DECLARE @S1 INT, @S2 INT, @S3 INT;
SELECT @S1 = SortOrder FROM Parts.BomLine WHERE Id = @Ln1;
SELECT @S2 = SortOrder FROM Parts.BomLine WHERE Id = @Ln2;
SELECT @S3 = SortOrder FROM Parts.BomLine WHERE Id = @Ln3;

DECLARE @S1Str NVARCHAR(20) = CAST(@S1 AS NVARCHAR(20));
DECLARE @S2Str NVARCHAR(20) = CAST(@S2 AS NVARCHAR(20));
DECLARE @S3Str NVARCHAR(20) = CAST(@S3 AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName = N'[LnAdd] Ln1 SortOrder = 1',
    @Expected = N'1',
    @Actual   = @S1Str;
EXEC test.Assert_IsEqual
    @TestName = N'[LnAdd] Ln2 SortOrder = 2',
    @Expected = N'2',
    @Actual   = @S2Str;
EXEC test.Assert_IsEqual
    @TestName = N'[LnAdd] Ln3 SortOrder = 3',
    @Expected = N'3',
    @Actual   = @S3Str;
GO

-- =============================================
-- Test 2: BomLine_Add NULL BomId
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1),
        @C1   BIGINT,
        @LnId BIGINT;

SELECT @C1 = Id FROM Parts.Item WHERE PartNumber = N'TEST-BL-CHILD-001';

CREATE TABLE #Rc5 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc5
EXEC Parts.BomLine_Add
    @BomId = NULL, @ChildItemId = @C1, @QtyPer = 1.0, @UomId = 1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message, @LnId = NewId FROM #Rc5;
DROP TABLE #Rc5;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnAddNull] Status is 0 (NULL BomId)',
    @Expected = N'0',
    @Actual   = @SStr;
GO

-- =============================================
-- Test 3: BomLine_Add invalid BomId
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1),
        @C1   BIGINT,
        @LnId BIGINT;

SELECT @C1 = Id FROM Parts.Item WHERE PartNumber = N'TEST-BL-CHILD-001';

CREATE TABLE #Rc6 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc6
EXEC Parts.BomLine_Add
    @BomId = 999999, @ChildItemId = @C1, @QtyPer = 1.0, @UomId = 1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message, @LnId = NewId FROM #Rc6;
DROP TABLE #Rc6;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnAddBadBom] Status is 0',
    @Expected = N'0',
    @Actual   = @SStr;
GO

-- =============================================
-- Test 4: BomLine_Add invalid ChildItemId
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @LnId  BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

CREATE TABLE #Rc7 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc7
EXEC Parts.BomLine_Add
    @BomId = @BomId, @ChildItemId = 999999, @QtyPer = 1.0, @UomId = 1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message, @LnId = NewId FROM #Rc7;
DROP TABLE #Rc7;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnAddBadChild] Status is 0',
    @Expected = N'0',
    @Actual   = @SStr;
GO

-- =============================================
-- Test 5: BomLine_Add self-reference (child = parent)
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @PId   BIGINT,
        @LnId  BIGINT;

SELECT @PId = Id FROM Parts.Item WHERE PartNumber = N'TEST-BL-PARENT-001';
SELECT @BomId = Id FROM Parts.Bom WHERE ParentItemId = @PId AND VersionNumber = 1;

CREATE TABLE #Rc8 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc8
EXEC Parts.BomLine_Add
    @BomId = @BomId, @ChildItemId = @PId, @QtyPer = 1.0, @UomId = 1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message, @LnId = NewId FROM #Rc8;
DROP TABLE #Rc8;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnAddSelf] Status is 0 (self-reference)',
    @Expected = N'0',
    @Actual   = @SStr;

DECLARE @SelfMsg NVARCHAR(1) = CASE
    WHEN @M LIKE N'%self%' OR @M LIKE N'%self-reference%' OR @M LIKE N'%same%'
    THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[LnAddSelf] Message indicates self-reference',
    @Expected = N'1',
    @Actual   = @SelfMsg;
GO

-- =============================================
-- Test 6: BomLine_Add duplicate ChildItemId on same BOM
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @C1    BIGINT,
        @LnId  BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT @C1 = Id FROM Parts.Item WHERE PartNumber = N'TEST-BL-CHILD-001';

CREATE TABLE #Rc9 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc9
EXEC Parts.BomLine_Add
    @BomId = @BomId, @ChildItemId = @C1, @QtyPer = 5.0, @UomId = 1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message, @LnId = NewId FROM #Rc9;
DROP TABLE #Rc9;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnAddDup] Status is 0 (duplicate child)',
    @Expected = N'0',
    @Actual   = @SStr;

DECLARE @DupMsg NVARCHAR(1) = CASE
    WHEN @M LIKE N'%already%' OR @M LIKE N'%already a line%'
    THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[LnAddDup] Message indicates already a line',
    @Expected = N'1',
    @Actual   = @DupMsg;
GO

-- =============================================
-- Test 7: BomLine_Add invalid UomId
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @C3    BIGINT,
        @LnId  BIGINT;

-- (CHILD-003 already added in setup Test 1 — use a new part? Use bad UomId
-- against some child not on BOM — but that's all 3 consumed. We expect the
-- UomId check to fire before the duplicate-child check. Using a duplicate
-- child WITH a bad UomId would also reject, but the message would be about
-- the UomId if that check runs first. Safer: create a fresh child.)
-- Use CHILD-001 with a nonexistent UomId; even if dup-check runs first the
-- status is still 0 — but we want to assert the invalid-Uom path. Instead,
-- create a throwaway child here.
CREATE TABLE #Rc39 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc39
EXEC Parts.Item_Create
    @PartNumber  = N'TEST-BL-CHILD-XTRA',
    @ItemTypeId  = 2,
    @Description = N'extra',
    @UomId       = 1,
    @AppUserId   = 1;
SELECT @S = Status, @M = Message, @LnId = NewId FROM #Rc39;
DROP TABLE #Rc39;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

DECLARE @CX BIGINT;
SELECT @CX = Id FROM Parts.Item WHERE PartNumber = N'TEST-BL-CHILD-XTRA';

CREATE TABLE #Rc10 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc10
EXEC Parts.BomLine_Add
    @BomId = @BomId, @ChildItemId = @CX, @QtyPer = 1.0, @UomId = 999999,
    @AppUserId = 1;
SELECT @S = Status, @M = Message, @LnId = NewId FROM #Rc10;
DROP TABLE #Rc10;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnAddBadUom] Status is 0',
    @Expected = N'0',
    @Actual   = @SStr;
GO

-- =============================================
-- Test 8: BomLine_ListByBom returns 3 rows in SortOrder
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

CREATE TABLE #LnList (
    Id BIGINT, BomId BIGINT, ChildItemId BIGINT,
    ChildPartNumber NVARCHAR(50), ChildDescription NVARCHAR(500),
    QtyPer DECIMAL(12,4), UomId BIGINT, UomCode NVARCHAR(20), SortOrder INT
);
INSERT INTO #LnList EXEC Parts.BomLine_ListByBom @BomId = @BomId;
DECLARE @Cnt INT = (SELECT COUNT(*) FROM #LnList);
DROP TABLE #LnList;

EXEC test.Assert_RowCount
    @TestName      = N'[LnList] 3 rows returned by proc',
    @ExpectedCount = 3,
    @ActualCount   = @Cnt;
GO

-- =============================================
-- Test 9: BomLine_Update happy path (change QtyPer)
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @Ln2   BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT @Ln2 = Id FROM Parts.BomLine WHERE BomId = @BomId AND SortOrder = 2;

CREATE TABLE #Ru12 (Status BIT, Message NVARCHAR(500));
INSERT INTO #Ru12
EXEC Parts.BomLine_Update
    @Id        = @Ln2,
    @QtyPer    = 42.5,
    @UomId     = 1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #Ru12;
DROP TABLE #Ru12;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnUpdate] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @Qty DECIMAL(10,4);
SELECT @Qty = QtyPer FROM Parts.BomLine WHERE Id = @Ln2;
DECLARE @QtyStr NVARCHAR(20) = CAST(@Qty AS NVARCHAR(20));
DECLARE @ExpStr NVARCHAR(20) = CAST(CAST(42.5 AS DECIMAL(10,4)) AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName = N'[LnUpdate] QtyPer updated to 42.5',
    @Expected = @ExpStr,
    @Actual   = @QtyStr;
GO

-- =============================================
-- Test 10: BomLine_Update invalid UomId
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @Ln2   BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT @Ln2 = Id FROM Parts.BomLine WHERE BomId = @BomId AND SortOrder = 2;

CREATE TABLE #Ru13 (Status BIT, Message NVARCHAR(500));
INSERT INTO #Ru13
EXEC Parts.BomLine_Update
    @Id        = @Ln2,
    @QtyPer    = 1.0,
    @UomId     = 999999,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #Ru13;
DROP TABLE #Ru13;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnUpdBadUom] Status is 0',
    @Expected = N'0',
    @Actual   = @SStr;
GO

-- =============================================
-- Test 11: BomLine_MoveUp on last row (SortOrder 3): swap with row 2
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @Ln3   BIGINT,
        @Ln2   BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT @Ln3 = Id FROM Parts.BomLine WHERE BomId = @BomId AND SortOrder = 3;
SELECT @Ln2 = Id FROM Parts.BomLine WHERE BomId = @BomId AND SortOrder = 2;

CREATE TABLE #Ru14 (Status BIT, Message NVARCHAR(500));
INSERT INTO #Ru14
EXEC Parts.BomLine_MoveUp
    @Id        = @Ln3,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #Ru14;
DROP TABLE #Ru14;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveUp3] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @N3 INT, @N2 INT;
SELECT @N3 = SortOrder FROM Parts.BomLine WHERE Id = @Ln3;
SELECT @N2 = SortOrder FROM Parts.BomLine WHERE Id = @Ln2;
DECLARE @N3Str NVARCHAR(20) = CAST(@N3 AS NVARCHAR(20));
DECLARE @N2Str NVARCHAR(20) = CAST(@N2 AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveUp3] Former row-3 is now SortOrder 2',
    @Expected = N'2',
    @Actual   = @N3Str;
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveUp3] Former row-2 is now SortOrder 3',
    @Expected = N'3',
    @Actual   = @N2Str;
GO

-- =============================================
-- Test 12: BomLine_MoveUp on first row: no-op (Status=1, "Already first")
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @Ln1   BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT @Ln1 = Id FROM Parts.BomLine WHERE BomId = @BomId AND SortOrder = 1;

CREATE TABLE #Ru15 (Status BIT, Message NVARCHAR(500));
INSERT INTO #Ru15
EXEC Parts.BomLine_MoveUp
    @Id        = @Ln1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #Ru15;
DROP TABLE #Ru15;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveUpFirst] Status is 1 (no-op)',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @FirstMsg NVARCHAR(1) = CASE
    WHEN @M LIKE N'%first%' OR @M LIKE N'%already%'
    THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveUpFirst] Message indicates already first',
    @Expected = N'1',
    @Actual   = @FirstMsg;

DECLARE @SeqAfter INT;
SELECT @SeqAfter = SortOrder FROM Parts.BomLine WHERE Id = @Ln1;
DECLARE @SeqAfterStr NVARCHAR(20) = CAST(@SeqAfter AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveUpFirst] SortOrder unchanged (still 1)',
    @Expected = N'1',
    @Actual   = @SeqAfterStr;
GO

-- =============================================
-- Test 13: BomLine_MoveDown on first row: 1 -> 2
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @Ln1   BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT @Ln1 = Id FROM Parts.BomLine WHERE BomId = @BomId AND SortOrder = 1;

CREATE TABLE #Ru16 (Status BIT, Message NVARCHAR(500));
INSERT INTO #Ru16
EXEC Parts.BomLine_MoveDown
    @Id        = @Ln1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #Ru16;
DROP TABLE #Ru16;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveDown1] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @New1 INT;
SELECT @New1 = SortOrder FROM Parts.BomLine WHERE Id = @Ln1;
DECLARE @New1Str NVARCHAR(20) = CAST(@New1 AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveDown1] Former row-1 now SortOrder 2',
    @Expected = N'2',
    @Actual   = @New1Str;
GO

-- =============================================
-- Test 14: BomLine_Remove on the middle row: hard-delete + compact
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @Rm    BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT @Rm = Id FROM Parts.BomLine WHERE BomId = @BomId AND SortOrder = 2;

CREATE TABLE #Ru17 (Status BIT, Message NVARCHAR(500));
INSERT INTO #Ru17
EXEC Parts.BomLine_Remove
    @Id        = @Rm,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #Ru17;
DROP TABLE #Ru17;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnRemove] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @Gone INT = (SELECT COUNT(*) FROM Parts.BomLine WHERE Id = @Rm);
EXEC test.Assert_RowCount
    @TestName      = N'[LnRemove] Row hard-deleted',
    @ExpectedCount = 0,
    @ActualCount   = @Gone;

DECLARE @Remain INT = (SELECT COUNT(*) FROM Parts.BomLine WHERE BomId = @BomId);
EXEC test.Assert_RowCount
    @TestName      = N'[LnRemove] 2 rows remain',
    @ExpectedCount = 2,
    @ActualCount   = @Remain;

DECLARE @MinS INT, @MaxS INT;
SELECT @MinS = MIN(SortOrder), @MaxS = MAX(SortOrder)
FROM Parts.BomLine WHERE BomId = @BomId;
DECLARE @MinSStr NVARCHAR(20) = CAST(@MinS AS NVARCHAR(20));
DECLARE @MaxSStr NVARCHAR(20) = CAST(@MaxS AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName = N'[LnRemove] Compacted: MIN(SortOrder) = 1',
    @Expected = N'1',
    @Actual   = @MinSStr;
EXEC test.Assert_IsEqual
    @TestName = N'[LnRemove] Compacted: MAX(SortOrder) = 2',
    @Expected = N'2',
    @Actual   = @MaxSStr;
GO

-- =============================================
-- Test 15: Publish the parent BOM
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

CREATE TABLE #Ru18 (Status BIT, Message NVARCHAR(500));
INSERT INTO #Ru18
EXEC Parts.Bom_Publish
    @Id        = @BomId,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #Ru18;
DROP TABLE #Ru18;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnPubSetup] Bom_Publish status is 1',
    @Expected = N'1',
    @Actual   = @SStr;
GO

-- =============================================
-- Test 16: BomLine_Add on published BOM rejected
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @CX    BIGINT,
        @LnId  BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT @CX = Id FROM Parts.Item WHERE PartNumber = N'TEST-BL-CHILD-XTRA';

CREATE TABLE #Rc11 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Rc11
EXEC Parts.BomLine_Add
    @BomId = @BomId, @ChildItemId = @CX, @QtyPer = 1.0, @UomId = 1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message, @LnId = NewId FROM #Rc11;
DROP TABLE #Rc11;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnAddPub] Status is 0 (published)',
    @Expected = N'0',
    @Actual   = @SStr;

DECLARE @PubMsg NVARCHAR(1) = CASE WHEN @M LIKE N'%published%' THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[LnAddPub] Message contains "published"',
    @Expected = N'1',
    @Actual   = @PubMsg;
GO

-- =============================================
-- Test 17: BomLine_Update on published BOM rejected
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @AnyLn BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT TOP 1 @AnyLn = Id FROM Parts.BomLine WHERE BomId = @BomId ORDER BY SortOrder;

CREATE TABLE #Ru19 (Status BIT, Message NVARCHAR(500));
INSERT INTO #Ru19
EXEC Parts.BomLine_Update
    @Id        = @AnyLn,
    @QtyPer    = 7.0,
    @UomId     = 1,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #Ru19;
DROP TABLE #Ru19;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnUpdPub] Status is 0 (published)',
    @Expected = N'0',
    @Actual   = @SStr;

DECLARE @PubMsg2 NVARCHAR(1) = CASE WHEN @M LIKE N'%published%' THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[LnUpdPub] Message contains "published"',
    @Expected = N'1',
    @Actual   = @PubMsg2;
GO

-- =============================================
-- Test 18: BomLine_MoveUp on published BOM rejected
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @LastLn BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT TOP 1 @LastLn = Id FROM Parts.BomLine WHERE BomId = @BomId ORDER BY SortOrder DESC;

CREATE TABLE #Ru20 (Status BIT, Message NVARCHAR(500));
INSERT INTO #Ru20
EXEC Parts.BomLine_MoveUp
    @Id        = @LastLn,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #Ru20;
DROP TABLE #Ru20;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveUpPub] Status is 0 (published)',
    @Expected = N'0',
    @Actual   = @SStr;

DECLARE @PubMsg3 NVARCHAR(1) = CASE WHEN @M LIKE N'%published%' THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveUpPub] Message contains "published"',
    @Expected = N'1',
    @Actual   = @PubMsg3;
GO

-- =============================================
-- Test 19: BomLine_MoveDown on published BOM rejected
-- =============================================
DECLARE @S      BIT,
        @M      NVARCHAR(500),
        @SStr   NVARCHAR(1),
        @BomId  BIGINT,
        @FirstLn BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT TOP 1 @FirstLn = Id FROM Parts.BomLine WHERE BomId = @BomId ORDER BY SortOrder;

CREATE TABLE #Ru21 (Status BIT, Message NVARCHAR(500));
INSERT INTO #Ru21
EXEC Parts.BomLine_MoveDown
    @Id        = @FirstLn,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #Ru21;
DROP TABLE #Ru21;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveDownPub] Status is 0 (published)',
    @Expected = N'0',
    @Actual   = @SStr;

DECLARE @PubMsg4 NVARCHAR(1) = CASE WHEN @M LIKE N'%published%' THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[LnMoveDownPub] Message contains "published"',
    @Expected = N'1',
    @Actual   = @PubMsg4;
GO

-- =============================================
-- Test 20: BomLine_Remove on published BOM rejected
-- =============================================
DECLARE @S     BIT,
        @M     NVARCHAR(500),
        @SStr  NVARCHAR(1),
        @BomId BIGINT,
        @AnyLn BIGINT;

SELECT @BomId = b.Id
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001' AND b.VersionNumber = 1;

SELECT TOP 1 @AnyLn = Id FROM Parts.BomLine WHERE BomId = @BomId ORDER BY SortOrder;

CREATE TABLE #Ru22 (Status BIT, Message NVARCHAR(500));
INSERT INTO #Ru22
EXEC Parts.BomLine_Remove
    @Id        = @AnyLn,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #Ru22;
DROP TABLE #Ru22;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'[LnRemovePub] Status is 0 (published)',
    @Expected = N'0',
    @Actual   = @SStr;

DECLARE @PubMsg5 NVARCHAR(1) = CASE WHEN @M LIKE N'%published%' THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[LnRemovePub] Message contains "published"',
    @Expected = N'1',
    @Actual   = @PubMsg5;
GO

-- =============================================
-- Test 21: Audit trail - ConfigLog has >= 3 entries for Code='BomLine'
-- =============================================
DECLARE @AuditCount INT;
SELECT @AuditCount = COUNT(*)
FROM Audit.ConfigLog cl
INNER JOIN Audit.LogEntityType let ON let.Id = cl.LogEntityTypeId
WHERE let.Code = N'BomLine';

DECLARE @AuditOk NVARCHAR(1) = CASE WHEN @AuditCount >= 3 THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[LnAudit] ConfigLog has >= 3 entries for Code=BomLine',
    @Expected = N'1',
    @Actual   = @AuditOk;
GO

-- =============================================
-- Cleanup (dependency-safe order)
-- =============================================
DELETE bl
FROM Parts.BomLine bl
INNER JOIN Parts.Bom b  ON b.Id = bl.BomId
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001';

DELETE b
FROM Parts.Bom b
INNER JOIN Parts.Item p ON p.Id = b.ParentItemId
WHERE p.PartNumber = N'TEST-BL-PARENT-001';

DELETE FROM Parts.Item WHERE PartNumber LIKE N'TEST-BL-PARENT-%'
                          OR PartNumber LIKE N'TEST-BL-CHILD-%';
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
