-- =============================================
-- File:         0002_LocationType/020_LocationAttributeDefinition_crud.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for LocationAttributeDefinition CRUD + MoveUp/MoveDown procs.
--   Covers: list by definition, get by Id, create (auto-SortOrder),
--   create invalid FK, update, move up/down, move boundary no-ops,
--   deprecate with SortOrder compaction, audit trail verification.
--
--   Pre-conditions:
--     - Migration 0002 applied (LocationAttributeDefinition seed: 16 rows)
--     - All 7 LocationAttributeDefinition procs deployed
--     - Bootstrap user Id=1 exists
-- =============================================

EXEC test.BeginTestFile @FileName = N'0002_LocationType/020_LocationAttributeDefinition_crud.sql';
GO

-- =============================================
-- Test 1: ListByDefinition for DieCastMachine (DefId 8) — 4 seeded rows
-- =============================================
DECLARE @Count INT;
CREATE TABLE #R (
    Id BIGINT, LocationTypeDefinitionId BIGINT, AttributeName NVARCHAR(100),
    DataType NVARCHAR(50), IsRequired BIT, DefaultValue NVARCHAR(200),
    Uom NVARCHAR(20), SortOrder INT, Description NVARCHAR(500),
    CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);
INSERT INTO #R EXEC Location.LocationAttributeDefinition_ListByDefinition @LocationTypeDefinitionId = 8;
SELECT @Count = COUNT(*) FROM #R;
DROP TABLE #R;
EXEC test.Assert_RowCount
    @TestName      = N'ListByDefinition(DieCast): 4 rows returned by proc',
    @ExpectedCount = 4,
    @ActualCount   = @Count;

-- Verify ordering: first row should have SortOrder = 1
DECLARE @FirstSort INT;
SELECT TOP 1 @FirstSort = SortOrder
FROM Location.LocationAttributeDefinition
WHERE LocationTypeDefinitionId = 8 AND DeprecatedAt IS NULL
ORDER BY SortOrder ASC;

DECLARE @FirstSortStr NVARCHAR(10) = CAST(@FirstSort AS NVARCHAR(10));
EXEC test.Assert_IsEqual
    @TestName = N'ListByDefinition(DieCast): first SortOrder is 1',
    @Expected = N'1',
    @Actual   = @FirstSortStr;
GO

-- =============================================
-- Test 2: Get by known Id — verify AttributeName matches
-- =============================================
DECLARE @Count INT;
DECLARE @AttrName NVARCHAR(100);
CREATE TABLE #R (
    Id BIGINT, LocationTypeDefinitionId BIGINT, AttributeName NVARCHAR(100),
    DataType NVARCHAR(50), IsRequired BIT, DefaultValue NVARCHAR(200),
    Uom NVARCHAR(20), SortOrder INT, Description NVARCHAR(500),
    CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);
INSERT INTO #R EXEC Location.LocationAttributeDefinition_Get @Id = 1;
SELECT @Count = COUNT(*), @AttrName = MAX(AttributeName) FROM #R;
DROP TABLE #R;
EXEC test.Assert_RowCount
    @TestName      = N'Get(1): 1 row returned',
    @ExpectedCount = 1,
    @ActualCount   = @Count;
EXEC test.Assert_IsEqual
    @TestName = N'Get(1): AttributeName is IpAddress',
    @Expected = N'IpAddress',
    @Actual   = @AttrName;
GO

-- =============================================
-- Test 3: Create 3 new attribute defs for DieCastMachine (DefId 8)
--   Verify SortOrder auto-assigned sequentially after existing seed data (max=4)
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);
DECLARE @NewId1 BIGINT, @NewId2 BIGINT, @NewId3 BIGINT;

-- Create first
CREATE TABLE #R3a (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #R3a
EXEC Location.LocationAttributeDefinition_Create
    @LocationTypeDefinitionId = 8,
    @AttributeName = N'TestAttr1',
    @DataType      = N'NVARCHAR',
    @IsRequired    = 0,
    @AppUserId     = 1;
SELECT @S = Status, @M = Message, @NewId1 = NewId FROM #R3a;
DROP TABLE #R3a;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'Create TestAttr1: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

-- Verify SortOrder = 5 (next after 4 seed rows)
DECLARE @Sort1 INT;
SELECT @Sort1 = SortOrder FROM Location.LocationAttributeDefinition WHERE Id = @NewId1;
DECLARE @Sort1Str NVARCHAR(10) = CAST(@Sort1 AS NVARCHAR(10));
EXEC test.Assert_IsEqual
    @TestName = N'Create TestAttr1: SortOrder is 5',
    @Expected = N'5',
    @Actual   = @Sort1Str;

-- Create second
CREATE TABLE #R3b (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #R3b
EXEC Location.LocationAttributeDefinition_Create
    @LocationTypeDefinitionId = 8,
    @AttributeName = N'TestAttr2',
    @DataType      = N'INT',
    @IsRequired    = 1,
    @DefaultValue  = N'42',
    @Uom           = N'units',
    @Description   = N'Test attribute 2',
    @AppUserId     = 1;
SELECT @S = Status, @M = Message, @NewId2 = NewId FROM #R3b;
DROP TABLE #R3b;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'Create TestAttr2: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @Sort2 INT;
SELECT @Sort2 = SortOrder FROM Location.LocationAttributeDefinition WHERE Id = @NewId2;
DECLARE @Sort2Str NVARCHAR(10) = CAST(@Sort2 AS NVARCHAR(10));
EXEC test.Assert_IsEqual
    @TestName = N'Create TestAttr2: SortOrder is 6',
    @Expected = N'6',
    @Actual   = @Sort2Str;

-- Create third
CREATE TABLE #R3c (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #R3c
EXEC Location.LocationAttributeDefinition_Create
    @LocationTypeDefinitionId = 8,
    @AttributeName = N'TestAttr3',
    @DataType      = N'DECIMAL',
    @AppUserId     = 1;
SELECT @S = Status, @M = Message, @NewId3 = NewId FROM #R3c;
DROP TABLE #R3c;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'Create TestAttr3: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @Sort3 INT;
SELECT @Sort3 = SortOrder FROM Location.LocationAttributeDefinition WHERE Id = @NewId3;
DECLARE @Sort3Str NVARCHAR(10) = CAST(@Sort3 AS NVARCHAR(10));
EXEC test.Assert_IsEqual
    @TestName = N'Create TestAttr3: SortOrder is 7',
    @Expected = N'7',
    @Actual   = @Sort3Str;
GO

-- =============================================
-- Test 4: Create with invalid LocationTypeDefinitionId — rejected
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);
DECLARE @NewId BIGINT;

CREATE TABLE #R4 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #R4
EXEC Location.LocationAttributeDefinition_Create
    @LocationTypeDefinitionId = 99999,
    @AttributeName = N'BadAttr',
    @DataType      = N'NVARCHAR',
    @AppUserId     = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #R4;
DROP TABLE #R4;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'Create invalid FK: status is 0',
    @Expected = N'0',
    @Actual   = @SStr;

EXEC test.Assert_IsEqual
    @TestName = N'Create invalid FK: message says invalid',
    @Expected = N'Invalid or deprecated LocationTypeDefinitionId.',
    @Actual   = @M;
GO

-- =============================================
-- Test 5: Update — change AttributeName, verify changed, SortOrder unchanged
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);

-- Get the Id of TestAttr1 (created in test 3)
DECLARE @TargetId BIGINT;
SELECT @TargetId = Id
FROM Location.LocationAttributeDefinition
WHERE AttributeName = N'TestAttr1' AND LocationTypeDefinitionId = 8;

-- Capture SortOrder before update
DECLARE @SortBefore INT;
SELECT @SortBefore = SortOrder
FROM Location.LocationAttributeDefinition
WHERE Id = @TargetId;

CREATE TABLE #R5 (Status BIT, Message NVARCHAR(500));
INSERT INTO #R5
EXEC Location.LocationAttributeDefinition_Update
    @Id            = @TargetId,
    @AttributeName = N'TestAttr1_Renamed',
    @DataType      = N'NVARCHAR',
    @IsRequired    = 1,
    @DefaultValue  = N'hello',
    @Uom           = N'mm',
    @Description   = N'Updated description',
    @AppUserId     = 1;
SELECT @S = Status, @M = Message FROM #R5;
DROP TABLE #R5;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'Update TestAttr1: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

-- Verify name changed
DECLARE @NewName NVARCHAR(100);
SELECT @NewName = AttributeName
FROM Location.LocationAttributeDefinition
WHERE Id = @TargetId;

EXEC test.Assert_IsEqual
    @TestName = N'Update TestAttr1: AttributeName changed',
    @Expected = N'TestAttr1_Renamed',
    @Actual   = @NewName;

-- Verify SortOrder unchanged
DECLARE @SortAfter INT;
SELECT @SortAfter = SortOrder
FROM Location.LocationAttributeDefinition
WHERE Id = @TargetId;

DECLARE @SortBeforeStr NVARCHAR(10) = CAST(@SortBefore AS NVARCHAR(10));
DECLARE @SortAfterStr NVARCHAR(10) = CAST(@SortAfter AS NVARCHAR(10));
EXEC test.Assert_IsEqual
    @TestName = N'Update TestAttr1: SortOrder unchanged',
    @Expected = @SortBeforeStr,
    @Actual   = @SortAfterStr;
GO

-- =============================================
-- Test 6: MoveDown the first created test attr (SortOrder 5) → swaps with SortOrder 6
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);

DECLARE @Attr1Id BIGINT, @Attr2Id BIGINT;
SELECT @Attr1Id = Id FROM Location.LocationAttributeDefinition
WHERE AttributeName = N'TestAttr1_Renamed' AND LocationTypeDefinitionId = 8;
SELECT @Attr2Id = Id FROM Location.LocationAttributeDefinition
WHERE AttributeName = N'TestAttr2' AND LocationTypeDefinitionId = 8;

CREATE TABLE #R6 (Status BIT, Message NVARCHAR(500));
INSERT INTO #R6
EXEC Location.LocationAttributeDefinition_MoveDown
    @Id        = @Attr1Id,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #R6;
DROP TABLE #R6;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'MoveDown TestAttr1: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

-- TestAttr1_Renamed should now have SortOrder 6, TestAttr2 should have SortOrder 5
DECLARE @Sort1After INT, @Sort2After INT;
SELECT @Sort1After = SortOrder FROM Location.LocationAttributeDefinition WHERE Id = @Attr1Id;
SELECT @Sort2After = SortOrder FROM Location.LocationAttributeDefinition WHERE Id = @Attr2Id;

DECLARE @Sort1AfterStr NVARCHAR(10) = CAST(@Sort1After AS NVARCHAR(10));
DECLARE @Sort2AfterStr NVARCHAR(10) = CAST(@Sort2After AS NVARCHAR(10));

EXEC test.Assert_IsEqual
    @TestName = N'MoveDown TestAttr1: now at SortOrder 6',
    @Expected = N'6',
    @Actual   = @Sort1AfterStr;

EXEC test.Assert_IsEqual
    @TestName = N'MoveDown TestAttr1: TestAttr2 now at SortOrder 5',
    @Expected = N'5',
    @Actual   = @Sort2AfterStr;
GO

-- =============================================
-- Test 7: MoveUp the last created test attr (TestAttr3, SortOrder 7) → swaps with SortOrder 6
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);

DECLARE @Attr1Id BIGINT, @Attr3Id BIGINT;
SELECT @Attr1Id = Id FROM Location.LocationAttributeDefinition
WHERE AttributeName = N'TestAttr1_Renamed' AND LocationTypeDefinitionId = 8;
SELECT @Attr3Id = Id FROM Location.LocationAttributeDefinition
WHERE AttributeName = N'TestAttr3' AND LocationTypeDefinitionId = 8;

-- TestAttr1_Renamed is at 6, TestAttr3 is at 7
CREATE TABLE #R7 (Status BIT, Message NVARCHAR(500));
INSERT INTO #R7
EXEC Location.LocationAttributeDefinition_MoveUp
    @Id        = @Attr3Id,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #R7;
DROP TABLE #R7;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'MoveUp TestAttr3: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

-- TestAttr3 should now have SortOrder 6, TestAttr1_Renamed should have SortOrder 7
DECLARE @Sort1After INT, @Sort3After INT;
SELECT @Sort1After = SortOrder FROM Location.LocationAttributeDefinition WHERE Id = @Attr1Id;
SELECT @Sort3After = SortOrder FROM Location.LocationAttributeDefinition WHERE Id = @Attr3Id;

DECLARE @Sort1AfterStr NVARCHAR(10) = CAST(@Sort1After AS NVARCHAR(10));
DECLARE @Sort3AfterStr NVARCHAR(10) = CAST(@Sort3After AS NVARCHAR(10));

EXEC test.Assert_IsEqual
    @TestName = N'MoveUp TestAttr3: now at SortOrder 6',
    @Expected = N'6',
    @Actual   = @Sort3AfterStr;

EXEC test.Assert_IsEqual
    @TestName = N'MoveUp TestAttr3: TestAttr1_Renamed now at SortOrder 7',
    @Expected = N'7',
    @Actual   = @Sort1AfterStr;
GO

-- =============================================
-- Test 8: MoveUp when already first — no-op, Status=1
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);

-- Seed row Id 4 = Tonnage for DieCast (SortOrder 1, first in DefId 8)
CREATE TABLE #R8 (Status BIT, Message NVARCHAR(500));
INSERT INTO #R8
EXEC Location.LocationAttributeDefinition_MoveUp
    @Id        = 4,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #R8;
DROP TABLE #R8;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'MoveUp already first: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

EXEC test.Assert_IsEqual
    @TestName = N'MoveUp already first: message says already at top',
    @Expected = N'Already at the top position.',
    @Actual   = @M;
GO

-- =============================================
-- Test 9: MoveDown when already last — no-op, Status=1
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);

-- TestAttr1_Renamed is now at SortOrder 7 (highest for DefId 8)
DECLARE @LastId BIGINT;
SELECT @LastId = Id FROM Location.LocationAttributeDefinition
WHERE AttributeName = N'TestAttr1_Renamed' AND LocationTypeDefinitionId = 8;

CREATE TABLE #R9 (Status BIT, Message NVARCHAR(500));
INSERT INTO #R9
EXEC Location.LocationAttributeDefinition_MoveDown
    @Id        = @LastId,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #R9;
DROP TABLE #R9;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'MoveDown already last: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

EXEC test.Assert_IsEqual
    @TestName = N'MoveDown already last: message says already at bottom',
    @Expected = N'Already at the bottom position.',
    @Actual   = @M;
GO

-- =============================================
-- Test 10: Deprecate one of the created ones → verify DeprecatedAt set
--   and sibling SortOrder compacted.
--   Before: TestAttr2(5), TestAttr3(6), TestAttr1_Renamed(7) among 7 total for DefId 8
--   Deprecate TestAttr3 → remaining active should be renumbered 1..6
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SStr NVARCHAR(1);

DECLARE @DeprecateId BIGINT;
SELECT @DeprecateId = Id FROM Location.LocationAttributeDefinition
WHERE AttributeName = N'TestAttr3' AND LocationTypeDefinitionId = 8;

CREATE TABLE #R10 (Status BIT, Message NVARCHAR(500));
INSERT INTO #R10
EXEC Location.LocationAttributeDefinition_Deprecate
    @Id        = @DeprecateId,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #R10;
DROP TABLE #R10;

SET @SStr = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'Deprecate TestAttr3: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

-- Verify DeprecatedAt is set
DECLARE @DepAt DATETIME2(3);
SELECT @DepAt = DeprecatedAt FROM Location.LocationAttributeDefinition WHERE Id = @DeprecateId;

DECLARE @DepAtNotNull NVARCHAR(1) = CASE WHEN @DepAt IS NOT NULL THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'Deprecate TestAttr3: DeprecatedAt is set',
    @Expected = N'1',
    @Actual   = @DepAtNotNull;

-- Verify remaining active count for DefId 8 = 6 (4 seed + 2 test)
DECLARE @ActiveCount INT;
SELECT @ActiveCount = COUNT(*)
FROM Location.LocationAttributeDefinition
WHERE LocationTypeDefinitionId = 8 AND DeprecatedAt IS NULL;

EXEC test.Assert_RowCount
    @TestName      = N'Deprecate TestAttr3: 6 active remain for DefId 8',
    @ExpectedCount = 6,
    @ActualCount   = @ActiveCount;

-- Verify SortOrder compacted: max SortOrder among active siblings should be 6
DECLARE @MaxSort INT;
SELECT @MaxSort = MAX(SortOrder)
FROM Location.LocationAttributeDefinition
WHERE LocationTypeDefinitionId = 8 AND DeprecatedAt IS NULL;

DECLARE @MaxSortStr NVARCHAR(10) = CAST(@MaxSort AS NVARCHAR(10));
EXEC test.Assert_IsEqual
    @TestName = N'Deprecate TestAttr3: max SortOrder compacted to 6',
    @Expected = N'6',
    @Actual   = @MaxSortStr;

-- Verify min SortOrder is 1 (no gaps at the start)
DECLARE @MinSort INT;
SELECT @MinSort = MIN(SortOrder)
FROM Location.LocationAttributeDefinition
WHERE LocationTypeDefinitionId = 8 AND DeprecatedAt IS NULL;

DECLARE @MinSortStr NVARCHAR(10) = CAST(@MinSort AS NVARCHAR(10));
EXEC test.Assert_IsEqual
    @TestName = N'Deprecate TestAttr3: min SortOrder is 1',
    @Expected = N'1',
    @Actual   = @MinSortStr;
GO

-- =============================================
-- Test 11: Audit trail — verify ConfigLog has entries for LocationAttrDef
-- =============================================
DECLARE @AuditCount INT;
SELECT @AuditCount = COUNT(*)
FROM Audit.ConfigLog cl
INNER JOIN Audit.LogEntityType let ON let.Id = cl.LogEntityTypeId
WHERE let.Code = N'LocationAttrDef';

-- We should have at least: 3 creates + 1 update + 2 moves + 1 deprecate = 7
DECLARE @HasAudit NVARCHAR(1) = CASE WHEN @AuditCount >= 7 THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'Audit trail: at least 7 ConfigLog entries for LocationAttrDef',
    @Expected = N'1',
    @Actual   = @HasAudit;
GO

-- =============================================
-- Cleanup: remove test data to restore seed state
-- =============================================
DELETE FROM Location.LocationAttributeDefinition
WHERE LocationTypeDefinitionId = 8
  AND AttributeName IN (N'TestAttr1_Renamed', N'TestAttr2', N'TestAttr3');

-- Restore seed SortOrder for DefId 8 (1,2,3,4)
;WITH Renumbered AS (
    SELECT Id, ROW_NUMBER() OVER (ORDER BY SortOrder) AS NewSort
    FROM Location.LocationAttributeDefinition
    WHERE LocationTypeDefinitionId = 8
      AND DeprecatedAt IS NULL
)
UPDATE lad
SET lad.SortOrder = r.NewSort
FROM Location.LocationAttributeDefinition lad
INNER JOIN Renumbered r ON r.Id = lad.Id;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
