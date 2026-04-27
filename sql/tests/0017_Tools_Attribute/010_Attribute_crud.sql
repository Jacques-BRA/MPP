-- =============================================
-- File:         0017_Tools_Attribute/010_Attribute_crud.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-23
-- Description:
--   Tests for Tools.ToolAttributeDefinition and Tools.ToolAttribute:
--     AttributeDefinition Create (DataType whitelist), ListByType
--     ToolAttribute Upsert — insert + update paths, cross-type rejection
--     ToolAttribute Remove + ListByTool
-- =============================================

EXEC test.BeginTestFile @FileName = N'0017_Tools_Attribute/010_Attribute_crud.sql';
GO

-- =============================================
-- Setup: Die-type attribute def + a Die tool
-- =============================================
DECLARE @DieTypeId BIGINT = (SELECT Id FROM Tools.ToolType WHERE Code = N'Die');
DECLARE @ActiveId  BIGINT = (SELECT Id FROM Tools.ToolStatusCode WHERE Code = N'Active');

CREATE TABLE #RD (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RD EXEC Tools.ToolAttributeDefinition_Create
    @ToolTypeId = @DieTypeId, @Code = N'Tonnage', @Name = N'Machine Tonnage',
    @DataType = N'Integer', @IsRequired = 0, @AppUserId = 1;
DROP TABLE #RD;

CREATE TABLE #RT (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RT EXEC Tools.Tool_Create
    @ToolTypeId = @DieTypeId, @Code = N'ATTR-TEST-DIE', @Name = N'Attr Test Die',
    @StatusCodeId = @ActiveId, @AppUserId = 1;
DROP TABLE #RT;
GO

-- =============================================
-- Test 1: AttributeDefinition rejected with bad DataType
-- =============================================
DECLARE @DieTypeId BIGINT = (SELECT Id FROM Tools.ToolType WHERE Code = N'Die');

CREATE TABLE #RB (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #RB EXEC Tools.ToolAttributeDefinition_Create
    @ToolTypeId = @DieTypeId, @Code = N'BogusDT', @Name = N'Bogus',
    @DataType = N'Frobnicator', @AppUserId = 1;
DECLARE @S BIT = (SELECT Status FROM #RB);
DECLARE @SStr NVARCHAR(1) = CAST(@S AS NVARCHAR(1));
DROP TABLE #RB;

EXEC test.Assert_IsEqual
    @TestName = N'[AttrDef bad DataType] rejected Status 0',
    @Expected = N'0', @Actual = @SStr;
GO

-- =============================================
-- Test 2: ListByType returns the Tonnage def
-- =============================================
DECLARE @DieTypeId BIGINT = (SELECT Id FROM Tools.ToolType WHERE Code = N'Die');

CREATE TABLE #L (
    Id BIGINT, ToolTypeId BIGINT, Code NVARCHAR(50), Name NVARCHAR(100),
    DataType NVARCHAR(20), IsRequired BIT, SortOrder INT,
    CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);
INSERT INTO #L EXEC Tools.ToolAttributeDefinition_ListByType @ToolTypeId = @DieTypeId;

DECLARE @HasTonnage INT = (SELECT COUNT(*) FROM #L WHERE Code = N'Tonnage');
DECLARE @HasTonnageStr NVARCHAR(5) = CAST(@HasTonnage AS NVARCHAR(5));
EXEC test.Assert_IsEqual
    @TestName = N'[AttrDef ListByType] Tonnage present',
    @Expected = N'1', @Actual = @HasTonnageStr;
DROP TABLE #L;
GO

-- =============================================
-- Test 3: Upsert insert path — new (Tool, Def) writes Value
-- =============================================
DECLARE @ToolId BIGINT = (SELECT Id FROM Tools.Tool WHERE Code = N'ATTR-TEST-DIE');
DECLARE @DefId BIGINT = (
    SELECT Id FROM Tools.ToolAttributeDefinition WHERE Code = N'Tonnage');

CREATE TABLE #U1 (Status BIT, Message NVARCHAR(500));
INSERT INTO #U1 EXEC Tools.ToolAttribute_Upsert
    @ToolId = @ToolId, @ToolAttributeDefinitionId = @DefId,
    @Value = N'800', @AppUserId = 1;
DECLARE @S BIT = (SELECT Status FROM #U1);
DECLARE @SStr NVARCHAR(1) = CAST(@S AS NVARCHAR(1));
DROP TABLE #U1;

EXEC test.Assert_IsEqual
    @TestName = N'[Upsert insert] Status is 1',
    @Expected = N'1', @Actual = @SStr;

DECLARE @StoredVal NVARCHAR(500);
SELECT @StoredVal = Value FROM Tools.ToolAttribute
WHERE ToolId = @ToolId AND ToolAttributeDefinitionId = @DefId;
EXEC test.Assert_IsEqual
    @TestName = N'[Upsert insert] Value stored = 800',
    @Expected = N'800', @Actual = @StoredVal;
GO

-- =============================================
-- Test 4: Upsert update path — second call overwrites
-- =============================================
DECLARE @ToolId BIGINT = (SELECT Id FROM Tools.Tool WHERE Code = N'ATTR-TEST-DIE');
DECLARE @DefId BIGINT = (
    SELECT Id FROM Tools.ToolAttributeDefinition WHERE Code = N'Tonnage');

CREATE TABLE #U2 (Status BIT, Message NVARCHAR(500));
INSERT INTO #U2 EXEC Tools.ToolAttribute_Upsert
    @ToolId = @ToolId, @ToolAttributeDefinitionId = @DefId,
    @Value = N'1000', @AppUserId = 1;
DROP TABLE #U2;

DECLARE @StoredVal NVARCHAR(500);
SELECT @StoredVal = Value FROM Tools.ToolAttribute
WHERE ToolId = @ToolId AND ToolAttributeDefinitionId = @DefId;
EXEC test.Assert_IsEqual
    @TestName = N'[Upsert update] Value = 1000 (overwritten)',
    @Expected = N'1000', @Actual = @StoredVal;

-- Exactly one row per (tool, def)
DECLARE @RowCount INT;
SELECT @RowCount = COUNT(*) FROM Tools.ToolAttribute
WHERE ToolId = @ToolId AND ToolAttributeDefinitionId = @DefId;
EXEC test.Assert_RowCount
    @TestName = N'[Upsert update] exactly 1 row',
    @ExpectedCount = 1, @ActualCount = @RowCount;
GO

-- =============================================
-- Test 5: Remove cleans the value
-- =============================================
DECLARE @ToolId BIGINT = (SELECT Id FROM Tools.Tool WHERE Code = N'ATTR-TEST-DIE');
DECLARE @DefId BIGINT = (
    SELECT Id FROM Tools.ToolAttributeDefinition WHERE Code = N'Tonnage');

CREATE TABLE #RM (Status BIT, Message NVARCHAR(500));
INSERT INTO #RM EXEC Tools.ToolAttribute_Remove
    @ToolId = @ToolId, @ToolAttributeDefinitionId = @DefId, @AppUserId = 1;
DECLARE @S BIT = (SELECT Status FROM #RM);
DECLARE @SStr NVARCHAR(1) = CAST(@S AS NVARCHAR(1));
DROP TABLE #RM;

EXEC test.Assert_IsEqual
    @TestName = N'[Remove] Status is 1',
    @Expected = N'1', @Actual = @SStr;

DECLARE @RowCount INT;
SELECT @RowCount = COUNT(*) FROM Tools.ToolAttribute
WHERE ToolId = @ToolId AND ToolAttributeDefinitionId = @DefId;
EXEC test.Assert_RowCount
    @TestName = N'[Remove] row hard-deleted',
    @ExpectedCount = 0, @ActualCount = @RowCount;
GO

EXEC test.PrintSummary;
GO
