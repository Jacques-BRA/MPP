-- =============================================
-- File:         0008_Parts_Item/020_ContainerConfig_crud.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Parts.ContainerConfig CRUD procs:
--     Parts.ContainerConfig_GetByItem
--     Parts.ContainerConfig_Create
--     Parts.ContainerConfig_Update
--     Parts.ContainerConfig_Deprecate
--
--   Covers: GetByItem empty + populated, Create happy + NULL required
--   + invalid ItemId + duplicate active config (filtered unique index
--   UQ_ContainerConfig_ActiveItemId), Update happy + missing Id,
--   Deprecate happy, Create-after-deprecate allowed, audit trail.
--
--   Pre-conditions:
--     - Migration 0001 applied (AppUser, Audit schema, bootstrap user Id=1)
--     - Parts schema migration applied (Parts.Item, Parts.ContainerConfig,
--       Parts.ItemType seeds 1-5, Parts.Uom seeds 1-6)
--     - Filtered unique index UQ_ContainerConfig_ActiveItemId present
--       (prevents >1 active ContainerConfig per ItemId)
--     - All Parts.ContainerConfig_* procs deployed
--     - Parts.Item_Create proc deployed (used for setup)
-- =============================================

EXEC test.BeginTestFile @FileName = N'0008_Parts_Item/020_ContainerConfig_crud.sql';
GO

-- =============================================
-- Setup: create a FinishedGood Item to attach container configs to.
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @ItemId BIGINT;

EXEC Parts.Item_Create
    @ItemTypeId  = 4,                     -- FinishedGood
    @PartNumber  = N'TEST-CC-001',
    @Description = N'Container Config Host Item',
    @UomId       = 1,
    @AppUserId   = 1,
    @Status      = @S OUTPUT,
    @Message     = @M OUTPUT,
    @NewId       = @ItemId OUTPUT;
GO

-- =============================================
-- Test 1: ContainerConfig_GetByItem - no rows initially
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1),
        @ItemId BIGINT;

SELECT @ItemId = Id FROM Parts.Item WHERE PartNumber = N'TEST-CC-001';

CREATE TABLE #Cc0 (
    Id                 BIGINT,
    ItemId             BIGINT,
    TraysPerContainer  INT,
    PartsPerTray       INT,
    IsSerialized       BIT,
    DunnageCode        NVARCHAR(50),
    CustomerCode       NVARCHAR(50),
    ClosureMethod      NVARCHAR(20),
    TargetWeight       DECIMAL(10,4),
    CreatedAt          DATETIME2(3),
    UpdatedAt          DATETIME2(3),
    DeprecatedAt       DATETIME2(3)
);

INSERT INTO #Cc0
EXEC Parts.ContainerConfig_GetByItem @ItemId = @ItemId;

DECLARE @Cnt INT = (SELECT COUNT(*) FROM #Cc0);
EXEC test.Assert_RowCount
    @TestName      = N'[GetByItemEmpty] Returns 0 rows',
    @ExpectedCount = 0,
    @ActualCount   = @Cnt;

DROP TABLE #Cc0;
GO

-- =============================================
-- Test 2: ContainerConfig_Create happy path
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1),
        @ItemId BIGINT,
        @NewId BIGINT;

SELECT @ItemId = Id FROM Parts.Item WHERE PartNumber = N'TEST-CC-001';

EXEC Parts.ContainerConfig_Create
    @ItemId            = @ItemId,
    @TraysPerContainer = 4,
    @PartsPerTray      = 25,
    @IsSerialized      = 0,
    @DunnageCode       = N'DUN-001',
    @CustomerCode      = N'CUST-HON',
    @ClosureMethod     = N'Strap',
    @TargetWeight      = 125.5000,
    @AppUserId         = 1,
    @Status            = @S OUTPUT,
    @Message           = @M OUTPUT,
    @NewId             = @NewId OUTPUT;

SET @SStr = CAST(@S AS NVARCHAR(1));

EXEC test.Assert_IsEqual
    @TestName = N'[CreateHappy] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @NewIdStr NVARCHAR(20) = CAST(@NewId AS NVARCHAR(20));
EXEC test.Assert_IsNotNull
    @TestName = N'[CreateHappy] NewId is not NULL',
    @Value    = @NewIdStr;

DECLARE @RowCount INT;
SELECT @RowCount = COUNT(*) FROM Parts.ContainerConfig WHERE Id = @NewId;
EXEC test.Assert_RowCount
    @TestName      = N'[CreateHappy] Row exists',
    @ExpectedCount = 1,
    @ActualCount   = @RowCount;
GO

-- =============================================
-- Test 3: ContainerConfig_Create - NULL required param (ItemId)
--   Status=0.
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1),
        @NewId BIGINT;

EXEC Parts.ContainerConfig_Create
    @ItemId            = NULL,
    @TraysPerContainer = 1,
    @PartsPerTray      = 1,
    @IsSerialized      = 0,
    @DunnageCode       = N'DUN-X',
    @CustomerCode      = N'CUST-X',
    @AppUserId         = 1,
    @Status            = @S OUTPUT,
    @Message           = @M OUTPUT,
    @NewId             = @NewId OUTPUT;

SET @SStr = CAST(@S AS NVARCHAR(1));

EXEC test.Assert_IsEqual
    @TestName = N'[CreateNullItem] Status is 0',
    @Expected = N'0',
    @Actual   = @SStr;

DECLARE @NewIdStr NVARCHAR(20) = CAST(@NewId AS NVARCHAR(20));
EXEC test.Assert_IsNull
    @TestName = N'[CreateNullItem] NewId is NULL',
    @Value    = @NewIdStr;
GO

-- =============================================
-- Test 4: ContainerConfig_Create - invalid ItemId
--   Status=0.
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1),
        @NewId BIGINT;

EXEC Parts.ContainerConfig_Create
    @ItemId            = 999999,
    @TraysPerContainer = 1,
    @PartsPerTray      = 1,
    @IsSerialized      = 0,
    @DunnageCode       = N'DUN-X',
    @CustomerCode      = N'CUST-X',
    @AppUserId         = 1,
    @Status            = @S OUTPUT,
    @Message           = @M OUTPUT,
    @NewId             = @NewId OUTPUT;

SET @SStr = CAST(@S AS NVARCHAR(1));

EXEC test.Assert_IsEqual
    @TestName = N'[CreateBadItem] Status is 0',
    @Expected = N'0',
    @Actual   = @SStr;
GO

-- =============================================
-- Test 5: ContainerConfig_Create duplicate active config for same Item
--   Second active create for same ItemId must fail (filtered unique index
--   UQ_ContainerConfig_ActiveItemId). Proc should return status=0 with
--   a friendly message, whether pre-checked or caught via CATCH.
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1),
        @ItemId BIGINT,
        @NewId BIGINT;

SELECT @ItemId = Id FROM Parts.Item WHERE PartNumber = N'TEST-CC-001';

EXEC Parts.ContainerConfig_Create
    @ItemId            = @ItemId,
    @TraysPerContainer = 2,
    @PartsPerTray      = 10,
    @IsSerialized      = 0,
    @DunnageCode       = N'DUN-DUP',
    @CustomerCode      = N'CUST-DUP',
    @AppUserId         = 1,
    @Status            = @S OUTPUT,
    @Message           = @M OUTPUT,
    @NewId             = @NewId OUTPUT;

SET @SStr = CAST(@S AS NVARCHAR(1));

EXEC test.Assert_IsEqual
    @TestName = N'[CreateDupActive] Status is 0',
    @Expected = N'0',
    @Actual   = @SStr;

DECLARE @NewIdStr NVARCHAR(20) = CAST(@NewId AS NVARCHAR(20));
EXEC test.Assert_IsNull
    @TestName = N'[CreateDupActive] NewId is NULL',
    @Value    = @NewIdStr;
GO

-- =============================================
-- Test 6: ContainerConfig_GetByItem returns the created row
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1),
        @ItemId BIGINT;

SELECT @ItemId = Id FROM Parts.Item WHERE PartNumber = N'TEST-CC-001';

CREATE TABLE #Cc1 (
    Id                 BIGINT,
    ItemId             BIGINT,
    TraysPerContainer  INT,
    PartsPerTray       INT,
    IsSerialized       BIT,
    DunnageCode        NVARCHAR(50),
    CustomerCode       NVARCHAR(50),
    ClosureMethod      NVARCHAR(20),
    TargetWeight       DECIMAL(10,4),
    CreatedAt          DATETIME2(3),
    UpdatedAt          DATETIME2(3),
    DeprecatedAt       DATETIME2(3)
);

INSERT INTO #Cc1
EXEC Parts.ContainerConfig_GetByItem @ItemId = @ItemId;

DECLARE @ActiveCount INT = (SELECT COUNT(*) FROM #Cc1 WHERE DeprecatedAt IS NULL);
EXEC test.Assert_RowCount
    @TestName      = N'[GetByItem] One active row returned',
    @ExpectedCount = 1,
    @ActualCount   = @ActiveCount;

DROP TABLE #Cc1;
GO

-- =============================================
-- Test 7: ContainerConfig_Update happy path
--   TraysPerContainer changes, UpdatedAt is not NULL.
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1),
        @ItemId BIGINT,
        @CcId BIGINT;

SELECT @ItemId = Id FROM Parts.Item WHERE PartNumber = N'TEST-CC-001';
SELECT @CcId = Id FROM Parts.ContainerConfig
    WHERE ItemId = @ItemId AND DeprecatedAt IS NULL;

EXEC Parts.ContainerConfig_Update
    @Id                = @CcId,
    @TraysPerContainer = 8,
    @PartsPerTray      = 25,
    @IsSerialized      = 0,
    @DunnageCode       = N'DUN-001',
    @CustomerCode      = N'CUST-HON',
    @ClosureMethod     = N'Strap',
    @TargetWeight      = 150.0000,
    @AppUserId         = 1,
    @Status            = @S OUTPUT,
    @Message           = @M OUTPUT;

SET @SStr = CAST(@S AS NVARCHAR(1));

EXEC test.Assert_IsEqual
    @TestName = N'[UpdateHappy] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @StoredTrays INT,
        @StoredUpdatedAt DATETIME2(3);

SELECT
    @StoredTrays     = TraysPerContainer,
    @StoredUpdatedAt = UpdatedAt
FROM Parts.ContainerConfig
WHERE Id = @CcId;

DECLARE @TraysStr NVARCHAR(20) = CAST(@StoredTrays AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName = N'[UpdateHappy] TraysPerContainer = 8',
    @Expected = N'8',
    @Actual   = @TraysStr;

DECLARE @UpdatedAtNotNull NVARCHAR(1) = CASE WHEN @StoredUpdatedAt IS NOT NULL THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[UpdateHappy] UpdatedAt is not NULL',
    @Expected = N'1',
    @Actual   = @UpdatedAtNotNull;
GO

-- =============================================
-- Test 8: ContainerConfig_Update - missing Id
--   Status=0.
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1);

EXEC Parts.ContainerConfig_Update
    @Id                = NULL,
    @TraysPerContainer = 1,
    @PartsPerTray      = 1,
    @IsSerialized      = 0,
    @DunnageCode       = N'DUN',
    @CustomerCode      = N'CUST',
    @AppUserId         = 1,
    @Status            = @S OUTPUT,
    @Message           = @M OUTPUT;

SET @SStr = CAST(@S AS NVARCHAR(1));

EXEC test.Assert_IsEqual
    @TestName = N'[UpdateNullId] Status is 0',
    @Expected = N'0',
    @Actual   = @SStr;
GO

-- =============================================
-- Test 9: ContainerConfig_Deprecate happy path
--   DeprecatedAt is set.
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1),
        @ItemId BIGINT,
        @CcId BIGINT;

SELECT @ItemId = Id FROM Parts.Item WHERE PartNumber = N'TEST-CC-001';
SELECT @CcId = Id FROM Parts.ContainerConfig
    WHERE ItemId = @ItemId AND DeprecatedAt IS NULL;

EXEC Parts.ContainerConfig_Deprecate
    @Id        = @CcId,
    @AppUserId = 1,
    @Status    = @S OUTPUT,
    @Message   = @M OUTPUT;

SET @SStr = CAST(@S AS NVARCHAR(1));

EXEC test.Assert_IsEqual
    @TestName = N'[DeprecateHappy] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @DepAt DATETIME2(3);
SELECT @DepAt = DeprecatedAt FROM Parts.ContainerConfig WHERE Id = @CcId;

DECLARE @DepAtNotNull NVARCHAR(1) = CASE WHEN @DepAt IS NOT NULL THEN N'1' ELSE N'0' END;
EXEC test.Assert_IsEqual
    @TestName = N'[DeprecateHappy] DeprecatedAt is not NULL',
    @Expected = N'1',
    @Actual   = @DepAtNotNull;
GO

-- =============================================
-- Test 10: After deprecate, Create succeeds for same Item
--   (filtered unique index only covers active rows).
-- =============================================
DECLARE @S    BIT,
        @M    NVARCHAR(500),
        @SStr NVARCHAR(1),
        @ItemId BIGINT,
        @NewId BIGINT;

SELECT @ItemId = Id FROM Parts.Item WHERE PartNumber = N'TEST-CC-001';

EXEC Parts.ContainerConfig_Create
    @ItemId            = @ItemId,
    @TraysPerContainer = 6,
    @PartsPerTray      = 30,
    @IsSerialized      = 1,
    @DunnageCode       = N'DUN-002',
    @CustomerCode      = N'CUST-HON',
    @ClosureMethod     = N'Lid',
    @TargetWeight      = 200.0000,
    @AppUserId         = 1,
    @Status            = @S OUTPUT,
    @Message           = @M OUTPUT,
    @NewId             = @NewId OUTPUT;

SET @SStr = CAST(@S AS NVARCHAR(1));

EXEC test.Assert_IsEqual
    @TestName = N'[CreateAfterDep] Status is 1',
    @Expected = N'1',
    @Actual   = @SStr;

DECLARE @NewIdStr NVARCHAR(20) = CAST(@NewId AS NVARCHAR(20));
EXEC test.Assert_IsNotNull
    @TestName = N'[CreateAfterDep] NewId is not NULL',
    @Value    = @NewIdStr;

-- There should now be exactly 1 active + 1 deprecated row for the item
DECLARE @ActiveCount INT;
SELECT @ActiveCount = COUNT(*) FROM Parts.ContainerConfig
    WHERE ItemId = @ItemId AND DeprecatedAt IS NULL;
EXEC test.Assert_RowCount
    @TestName      = N'[CreateAfterDep] Exactly 1 active row for Item',
    @ExpectedCount = 1,
    @ActualCount   = @ActiveCount;
GO

-- =============================================
-- Test 11: Audit trail - ConfigLog has entries for ContainerConfig
-- =============================================
DECLARE @AuditCount INT;
SELECT @AuditCount = COUNT(*)
FROM Audit.ConfigLog cl
INNER JOIN Audit.LogEntityType let ON let.Id = cl.LogEntityTypeId
WHERE let.Code = N'ContainerConfig';

DECLARE @AuditCond BIT = CASE WHEN @AuditCount >= 3 THEN 1 ELSE 0 END;
EXEC test.Assert_IsTrue
    @TestName  = N'[Audit] ConfigLog has >= 3 ContainerConfig entries',
    @Condition = @AuditCond;
GO

-- =============================================
-- Cleanup: delete test ContainerConfig rows and the host Item
-- =============================================
DELETE cc
FROM Parts.ContainerConfig cc
INNER JOIN Parts.Item i ON i.Id = cc.ItemId
WHERE i.PartNumber LIKE N'TEST-CC-%';

DELETE FROM Parts.Item WHERE PartNumber LIKE N'TEST-CC-%';
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
