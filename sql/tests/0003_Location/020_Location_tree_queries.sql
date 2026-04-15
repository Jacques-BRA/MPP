-- =============================================
-- File:         0003_Location/020_Location_tree_queries.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Location tree query procs (GetTree, GetAncestors, GetDescendantsOfType).
--   Builds a test hierarchy, exercises recursive CTEs, validates depth,
--   materialized paths, ancestor chains, type filtering, and deprecated
--   node exclusion.
--
--   Pre-conditions:
--     - Migration 0002 applied (LocationType: 5 rows, LocationTypeDefinition: 15 rows)
--     - All Location CRUD procs deployed (Create, Deprecate)
--     - All 3 tree query procs deployed (GetTree, GetAncestors, GetDescendantsOfType)
--     - Bootstrap user Id=1 exists
--     - No Location rows are pre-seeded — tests create their own
--
--   Test hierarchy:
--     Enterprise (Organization, DefId=1)
--     +-- Site (Facility, DefId=2)
--         +-- Die Cast Area (ProductionArea, DefId=3)
--         |   +-- DC-Machine-1 (DieCastMachine, DefId=8)
--         |   +-- DC-Machine-2 (DieCastMachine, DefId=8)
--         +-- Machine Shop Area (ProductionArea, DefId=3)
--             +-- CNC-Machine-1 (CNCMachine, DefId=9)
-- =============================================

EXEC test.BeginTestFile @FileName = N'0003_Location/020_Location_tree_queries.sql';
GO

-- =============================================
-- Setup: Build the test hierarchy via Location_Create
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500), @NewId BIGINT;

-- Enterprise root
CREATE TABLE #RC1 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RC1
EXEC Location.Location_Create
    @LocationTypeDefinitionId = 1,
    @ParentLocationId         = NULL,
    @Name                     = N'Test Enterprise',
    @Code                     = N'T6-ENT',
    @Description              = N'Tree test enterprise',
    @AppUserId                = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #RC1;
DROP TABLE #RC1;

DECLARE @EnterpriseId BIGINT = @NewId;

-- Site
CREATE TABLE #RC2 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RC2
EXEC Location.Location_Create
    @LocationTypeDefinitionId = 2,
    @ParentLocationId         = @EnterpriseId,
    @Name                     = N'Test Site',
    @Code                     = N'T6-SITE',
    @Description              = N'Tree test site',
    @AppUserId                = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #RC2;
DROP TABLE #RC2;

DECLARE @SiteId BIGINT = @NewId;

-- Die Cast Area
CREATE TABLE #RC3 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RC3
EXEC Location.Location_Create
    @LocationTypeDefinitionId = 3,
    @ParentLocationId         = @SiteId,
    @Name                     = N'Die Cast Area',
    @Code                     = N'T6-DC',
    @AppUserId                = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #RC3;
DROP TABLE #RC3;

DECLARE @DieCastAreaId BIGINT = @NewId;

-- DC-Machine-1
CREATE TABLE #RC4 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RC4
EXEC Location.Location_Create
    @LocationTypeDefinitionId = 8,
    @ParentLocationId         = @DieCastAreaId,
    @Name                     = N'DC-Machine-1',
    @Code                     = N'T6-DCM1',
    @AppUserId                = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #RC4;
DROP TABLE #RC4;

DECLARE @DCMachine1Id BIGINT = @NewId;

-- DC-Machine-2
CREATE TABLE #RC5 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RC5
EXEC Location.Location_Create
    @LocationTypeDefinitionId = 8,
    @ParentLocationId         = @DieCastAreaId,
    @Name                     = N'DC-Machine-2',
    @Code                     = N'T6-DCM2',
    @AppUserId                = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #RC5;
DROP TABLE #RC5;

DECLARE @DCMachine2Id BIGINT = @NewId;

-- Machine Shop Area
CREATE TABLE #RC6 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RC6
EXEC Location.Location_Create
    @LocationTypeDefinitionId = 3,
    @ParentLocationId         = @SiteId,
    @Name                     = N'Machine Shop Area',
    @Code                     = N'T6-MS',
    @AppUserId                = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #RC6;
DROP TABLE #RC6;

DECLARE @MachineShopAreaId BIGINT = @NewId;

-- CNC-Machine-1
CREATE TABLE #RC7 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RC7
EXEC Location.Location_Create
    @LocationTypeDefinitionId = 9,
    @ParentLocationId         = @MachineShopAreaId,
    @Name                     = N'CNC-Machine-1',
    @Code                     = N'T6-CNC1',
    @AppUserId                = 1;
SELECT @S = Status, @M = Message, @NewId = NewId FROM #RC7;
DROP TABLE #RC7;

DECLARE @CNCMachine1Id BIGINT = @NewId;

-- Stash IDs into a temp table so subsequent batches can access them
IF OBJECT_ID('tempdb..#TreeTestIds') IS NOT NULL DROP TABLE #TreeTestIds;
CREATE TABLE #TreeTestIds (
    Label NVARCHAR(50) PRIMARY KEY,
    LocationId BIGINT NOT NULL
);
INSERT INTO #TreeTestIds (Label, LocationId) VALUES
    (N'Enterprise',       @EnterpriseId),
    (N'Site',             @SiteId),
    (N'DieCastArea',      @DieCastAreaId),
    (N'DCMachine1',       @DCMachine1Id),
    (N'DCMachine2',       @DCMachine2Id),
    (N'MachineShopArea',  @MachineShopAreaId),
    (N'CNCMachine1',      @CNCMachine1Id);
GO

-- =============================================
-- Test 1: GetTree from Enterprise root — all 7 nodes, Depth 0-3
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @RootId BIGINT;
SELECT @RootId = LocationId FROM #TreeTestIds WHERE Label = N'Enterprise';

-- Capture into temp table for assertions
IF OBJECT_ID('tempdb..#TreeResult') IS NOT NULL DROP TABLE #TreeResult;
CREATE TABLE #TreeResult (
    Id BIGINT, ParentLocationId BIGINT, Name NVARCHAR(200), Code NVARCHAR(50),
    LocationTypeDefinitionId BIGINT, DefinitionName NVARCHAR(200),
    TypeName NVARCHAR(200), HierarchyLevel INT, SortOrder INT,
    Description NVARCHAR(500), DeprecatedAt DATETIME2(3),
    Depth INT, MaterializedPath NVARCHAR(MAX),
    SortPath NVARCHAR(MAX), Icon NVARCHAR(100)
);

INSERT INTO #TreeResult
EXEC Location.Location_GetTree @RootLocationId = @RootId;

DECLARE @TreeCount INT;
SELECT @TreeCount = COUNT(*) FROM #TreeResult;
EXEC test.Assert_RowCount
    @TestName      = N'GetTree Enterprise: 7 nodes returned',
    @ExpectedCount = 7,
    @ActualCount   = @TreeCount;

-- Verify depth range
DECLARE @MinDepth INT, @MaxDepth INT;
SELECT @MinDepth = MIN(Depth), @MaxDepth = MAX(Depth) FROM #TreeResult;

DECLARE @MinDepthStr NVARCHAR(10) = CAST(@MinDepth AS NVARCHAR(10));
DECLARE @MaxDepthStr NVARCHAR(10) = CAST(@MaxDepth AS NVARCHAR(10));
EXEC test.Assert_IsEqual
    @TestName = N'GetTree Enterprise: min depth is 0',
    @Expected = N'0',
    @Actual   = @MinDepthStr;

EXEC test.Assert_IsEqual
    @TestName = N'GetTree Enterprise: max depth is 3',
    @Expected = N'3',
    @Actual   = @MaxDepthStr;

-- Verify MaterializedPath for a leaf node
DECLARE @LeafPath NVARCHAR(MAX);
SELECT @LeafPath = MaterializedPath FROM #TreeResult WHERE Code = N'T6-DCM1';
EXEC test.Assert_IsEqual
    @TestName = N'GetTree Enterprise: DC-Machine-1 path correct',
    @Expected = N'Test Enterprise > Test Site > Die Cast Area > DC-Machine-1',
    @Actual   = @LeafPath;

DROP TABLE #TreeResult;
GO

-- =============================================
-- Test 2: GetTree from Site — 6 nodes (Site + all descendants)
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @SiteId BIGINT;
SELECT @SiteId = LocationId FROM #TreeTestIds WHERE Label = N'Site';

IF OBJECT_ID('tempdb..#TreeResult') IS NOT NULL DROP TABLE #TreeResult;
CREATE TABLE #TreeResult (
    Id BIGINT, ParentLocationId BIGINT, Name NVARCHAR(200), Code NVARCHAR(50),
    LocationTypeDefinitionId BIGINT, DefinitionName NVARCHAR(200),
    TypeName NVARCHAR(200), HierarchyLevel INT, SortOrder INT,
    Description NVARCHAR(500), DeprecatedAt DATETIME2(3),
    Depth INT, MaterializedPath NVARCHAR(MAX),
    SortPath NVARCHAR(MAX), Icon NVARCHAR(100)
);

INSERT INTO #TreeResult
EXEC Location.Location_GetTree @RootLocationId = @SiteId;

DECLARE @TreeCount INT;
SELECT @TreeCount = COUNT(*) FROM #TreeResult;
EXEC test.Assert_RowCount
    @TestName      = N'GetTree Site: 6 nodes returned',
    @ExpectedCount = 6,
    @ActualCount   = @TreeCount;

DROP TABLE #TreeResult;
GO

-- =============================================
-- Test 3: GetTree from Die Cast Area — 3 nodes (area + 2 machines)
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @DCAreaId BIGINT;
SELECT @DCAreaId = LocationId FROM #TreeTestIds WHERE Label = N'DieCastArea';

IF OBJECT_ID('tempdb..#TreeResult') IS NOT NULL DROP TABLE #TreeResult;
CREATE TABLE #TreeResult (
    Id BIGINT, ParentLocationId BIGINT, Name NVARCHAR(200), Code NVARCHAR(50),
    LocationTypeDefinitionId BIGINT, DefinitionName NVARCHAR(200),
    TypeName NVARCHAR(200), HierarchyLevel INT, SortOrder INT,
    Description NVARCHAR(500), DeprecatedAt DATETIME2(3),
    Depth INT, MaterializedPath NVARCHAR(MAX),
    SortPath NVARCHAR(MAX), Icon NVARCHAR(100)
);

INSERT INTO #TreeResult
EXEC Location.Location_GetTree @RootLocationId = @DCAreaId;

DECLARE @TreeCount INT;
SELECT @TreeCount = COUNT(*) FROM #TreeResult;
EXEC test.Assert_RowCount
    @TestName      = N'GetTree DieCastArea: 3 nodes returned',
    @ExpectedCount = 3,
    @ActualCount   = @TreeCount;

DROP TABLE #TreeResult;
GO

-- =============================================
-- Test 4: GetTree — deprecated nodes excluded
--   Deprecate DC-Machine-2, re-run GetTree from Die Cast Area, verify only 2 nodes
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @DCM2Id BIGINT;
SELECT @DCM2Id = LocationId FROM #TreeTestIds WHERE Label = N'DCMachine2';

CREATE TABLE #RD1 (Status BIT, Message NVARCHAR(500));
INSERT INTO #RD1
EXEC Location.Location_Deprecate
    @Id        = @DCM2Id,
    @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #RD1;
DROP TABLE #RD1;

DECLARE @SStr NVARCHAR(1) = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual
    @TestName = N'Deprecate DC-Machine-2: status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

-- Now GetTree from Die Cast Area should return 2 nodes (area + DC-Machine-1 only)
DECLARE @DCAreaId BIGINT;
SELECT @DCAreaId = LocationId FROM #TreeTestIds WHERE Label = N'DieCastArea';

IF OBJECT_ID('tempdb..#TreeResult') IS NOT NULL DROP TABLE #TreeResult;
CREATE TABLE #TreeResult (
    Id BIGINT, ParentLocationId BIGINT, Name NVARCHAR(200), Code NVARCHAR(50),
    LocationTypeDefinitionId BIGINT, DefinitionName NVARCHAR(200),
    TypeName NVARCHAR(200), HierarchyLevel INT, SortOrder INT,
    Description NVARCHAR(500), DeprecatedAt DATETIME2(3),
    Depth INT, MaterializedPath NVARCHAR(MAX),
    SortPath NVARCHAR(MAX), Icon NVARCHAR(100)
);

INSERT INTO #TreeResult
EXEC Location.Location_GetTree @RootLocationId = @DCAreaId;

DECLARE @TreeCount INT;
SELECT @TreeCount = COUNT(*) FROM #TreeResult;
EXEC test.Assert_RowCount
    @TestName      = N'GetTree after deprecate: 2 nodes (area + 1 machine)',
    @ExpectedCount = 2,
    @ActualCount   = @TreeCount;

DROP TABLE #TreeResult;
GO

-- =============================================
-- Test 5: GetAncestors from DC-Machine-1 — 4 rows (self + 3 ancestors), root first
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @DCM1Id BIGINT;
SELECT @DCM1Id = LocationId FROM #TreeTestIds WHERE Label = N'DCMachine1';

IF OBJECT_ID('tempdb..#AncResult') IS NOT NULL DROP TABLE #AncResult;
CREATE TABLE #AncResult (
    Id BIGINT, ParentLocationId BIGINT, Name NVARCHAR(200), Code NVARCHAR(50),
    LocationTypeDefinitionId BIGINT, DefinitionName NVARCHAR(200),
    TypeName NVARCHAR(200), HierarchyLevel INT,
    Icon NVARCHAR(100), SortOrder INT, Depth INT
);

INSERT INTO #AncResult
EXEC Location.Location_GetAncestors @LocationId = @DCM1Id;

DECLARE @AncCount INT;
SELECT @AncCount = COUNT(*) FROM #AncResult;
EXEC test.Assert_RowCount
    @TestName      = N'GetAncestors DC-Machine-1: 4 rows returned',
    @ExpectedCount = 4,
    @ActualCount   = @AncCount;

-- Verify root first: first row (ordered by Depth DESC) should be Enterprise
DECLARE @FirstName NVARCHAR(200);
SELECT TOP 1 @FirstName = Name FROM #AncResult ORDER BY Depth DESC;
EXEC test.Assert_IsEqual
    @TestName = N'GetAncestors DC-Machine-1: first row is Enterprise',
    @Expected = N'Test Enterprise',
    @Actual   = @FirstName;

-- Verify last row is the node itself
DECLARE @LastName NVARCHAR(200);
SELECT TOP 1 @LastName = Name FROM #AncResult ORDER BY Depth ASC;
EXEC test.Assert_IsEqual
    @TestName = N'GetAncestors DC-Machine-1: last row is self',
    @Expected = N'DC-Machine-1',
    @Actual   = @LastName;

DROP TABLE #AncResult;
GO

-- =============================================
-- Test 6: GetAncestors from Enterprise (root) — 1 row (itself)
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @EntId BIGINT;
SELECT @EntId = LocationId FROM #TreeTestIds WHERE Label = N'Enterprise';

IF OBJECT_ID('tempdb..#AncResult') IS NOT NULL DROP TABLE #AncResult;
CREATE TABLE #AncResult (
    Id BIGINT, ParentLocationId BIGINT, Name NVARCHAR(200), Code NVARCHAR(50),
    LocationTypeDefinitionId BIGINT, DefinitionName NVARCHAR(200),
    TypeName NVARCHAR(200), HierarchyLevel INT,
    Icon NVARCHAR(100), SortOrder INT, Depth INT
);

INSERT INTO #AncResult
EXEC Location.Location_GetAncestors @LocationId = @EntId;

DECLARE @AncCount INT;
SELECT @AncCount = COUNT(*) FROM #AncResult;
EXEC test.Assert_RowCount
    @TestName      = N'GetAncestors Enterprise: 1 row returned (itself)',
    @ExpectedCount = 1,
    @ActualCount   = @AncCount;

DROP TABLE #AncResult;
GO

-- =============================================
-- Test 7: GetDescendantsOfType from Enterprise, type=Cell (Id=5)
--   Should return DC-Machine-1 and CNC-Machine-1 (DC-Machine-2 is deprecated)
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @EntId BIGINT;
SELECT @EntId = LocationId FROM #TreeTestIds WHERE Label = N'Enterprise';

IF OBJECT_ID('tempdb..#DescResult') IS NOT NULL DROP TABLE #DescResult;
CREATE TABLE #DescResult (
    Id BIGINT, ParentLocationId BIGINT, Name NVARCHAR(200), Code NVARCHAR(50),
    LocationTypeDefinitionId BIGINT, DefinitionName NVARCHAR(200),
    SortOrder INT, Description NVARCHAR(500), Icon NVARCHAR(100)
);

INSERT INTO #DescResult
EXEC Location.Location_GetDescendantsOfType
    @LocationId     = @EntId,
    @LocationTypeId = 5;

DECLARE @DescCount INT;
SELECT @DescCount = COUNT(*) FROM #DescResult;
EXEC test.Assert_RowCount
    @TestName      = N'GetDescendantsOfType Enterprise Cell: 2 machines returned',
    @ExpectedCount = 2,
    @ActualCount   = @DescCount;

-- Verify ordered by Name: CNC-Machine-1 first, DC-Machine-1 second
DECLARE @FirstDescName NVARCHAR(200), @SecondDescName NVARCHAR(200);
SELECT @FirstDescName = Name FROM #DescResult ORDER BY Name OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;
SELECT @SecondDescName = Name FROM #DescResult ORDER BY Name OFFSET 1 ROWS FETCH NEXT 1 ROWS ONLY;

EXEC test.Assert_IsEqual
    @TestName = N'GetDescendantsOfType Enterprise Cell: first is CNC-Machine-1',
    @Expected = N'CNC-Machine-1',
    @Actual   = @FirstDescName;

EXEC test.Assert_IsEqual
    @TestName = N'GetDescendantsOfType Enterprise Cell: second is DC-Machine-1',
    @Expected = N'DC-Machine-1',
    @Actual   = @SecondDescName;

DROP TABLE #DescResult;
GO

-- =============================================
-- Test 8: GetDescendantsOfType from Die Cast Area, type=Cell (Id=5)
--   Should return just DC-Machine-1 (DC-Machine-2 deprecated)
-- =============================================
DECLARE @S BIT, @M NVARCHAR(500);
DECLARE @DCAreaId BIGINT;
SELECT @DCAreaId = LocationId FROM #TreeTestIds WHERE Label = N'DieCastArea';

IF OBJECT_ID('tempdb..#DescResult') IS NOT NULL DROP TABLE #DescResult;
CREATE TABLE #DescResult (
    Id BIGINT, ParentLocationId BIGINT, Name NVARCHAR(200), Code NVARCHAR(50),
    LocationTypeDefinitionId BIGINT, DefinitionName NVARCHAR(200),
    SortOrder INT, Description NVARCHAR(500), Icon NVARCHAR(100)
);

INSERT INTO #DescResult
EXEC Location.Location_GetDescendantsOfType
    @LocationId     = @DCAreaId,
    @LocationTypeId = 5;

DECLARE @DescCount INT;
SELECT @DescCount = COUNT(*) FROM #DescResult;
EXEC test.Assert_RowCount
    @TestName      = N'GetDescendantsOfType DieCastArea Cell: 1 machine returned',
    @ExpectedCount = 1,
    @ActualCount   = @DescCount;

DECLARE @OnlyName NVARCHAR(200);
SELECT @OnlyName = Name FROM #DescResult;
EXEC test.Assert_IsEqual
    @TestName = N'GetDescendantsOfType DieCastArea Cell: is DC-Machine-1',
    @Expected = N'DC-Machine-1',
    @Actual   = @OnlyName;

DROP TABLE #DescResult;
GO

-- Test 9 (NULL param guards) removed: converted read procs no longer return
-- error status/message on NULL — they simply return an empty result set.
-- =============================================

-- =============================================
-- Cleanup: remove test data to restore clean state
-- =============================================
DELETE FROM Location.Location WHERE Code IN (N'T6-DCM1', N'T6-DCM2', N'T6-CNC1');
DELETE FROM Location.Location WHERE Code IN (N'T6-DC', N'T6-MS');
DELETE FROM Location.Location WHERE Code = N'T6-SITE';
DELETE FROM Location.Location WHERE Code = N'T6-ENT';

IF OBJECT_ID('tempdb..#TreeTestIds') IS NOT NULL DROP TABLE #TreeTestIds;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
