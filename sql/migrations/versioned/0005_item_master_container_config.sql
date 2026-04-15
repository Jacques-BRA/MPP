-- ============================================================
-- Migration:   0005_item_master_container_config.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-14
-- Description: Phase 4 — Item Master & Container Config.
--
--              Creates Parts.Item (the MPP part master) and
--              Parts.ContainerConfig (Honda-specified packing rules
--              per finished good).
--
--              Parts.Item carries full user attribution: CreatedAt,
--              UpdatedAt, CreatedByUserId, UpdatedByUserId FKs to
--              Location.AppUser, matching the data model v0.9 spec
--              and establishing the pattern for all core entity
--              tables in later phases (Bom, RouteTemplate, QualitySpec,
--              Lot).
--
--              ContainerConfig includes the OI-02 columns —
--              ClosureMethod and TargetWeight — added proactively as
--              NULLable pending MPP customer validation. If MPP
--              confirms scale-driven container closure, the columns
--              are ready; if they don't, harmless.
--
--              A filtered unique index on ContainerConfig.ItemId
--              (active rows only) enforces "one active config per
--              finished good" at the schema level.
-- ============================================================

BEGIN TRANSACTION;

-- Guard: skip if already applied
IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0005_item_master_container_config')
BEGIN
    PRINT 'Migration 0005 already applied — skipping.';
    COMMIT;
    RETURN;
END

-- ============================================================
-- == Parts.Item ==============================================
-- ============================================================

CREATE TABLE Parts.Item (
    Id               BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ItemTypeId       BIGINT         NOT NULL REFERENCES Parts.ItemType(Id),
    PartNumber       NVARCHAR(50)   NOT NULL,
    Description      NVARCHAR(500)  NULL,
    MacolaPartNumber NVARCHAR(50)   NULL,
    DefaultSubLotQty INT            NULL,
    MaxLotSize       INT            NULL,
    UomId            BIGINT         NOT NULL REFERENCES Parts.Uom(Id),
    UnitWeight       DECIMAL(10,4)  NULL,
    WeightUomId      BIGINT         NULL     REFERENCES Parts.Uom(Id),
    CreatedAt        DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt        DATETIME2(3)   NULL,
    CreatedByUserId  BIGINT         NOT NULL REFERENCES Location.AppUser(Id),
    UpdatedByUserId  BIGINT         NULL     REFERENCES Location.AppUser(Id),
    DeprecatedAt    DATETIME2(3)    NULL,
    CONSTRAINT UQ_Item_PartNumber UNIQUE (PartNumber)
);

CREATE INDEX IX_Item_ItemTypeId       ON Parts.Item (ItemTypeId);
CREATE INDEX IX_Item_UomId            ON Parts.Item (UomId);
CREATE INDEX IX_Item_MacolaPartNumber ON Parts.Item (MacolaPartNumber) WHERE MacolaPartNumber IS NOT NULL;


-- ============================================================
-- == Parts.ContainerConfig ===================================
-- ============================================================

CREATE TABLE Parts.ContainerConfig (
    Id                BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ItemId            BIGINT         NOT NULL REFERENCES Parts.Item(Id),
    TraysPerContainer INT            NOT NULL,
    PartsPerTray      INT            NOT NULL,
    IsSerialized      BIT            NOT NULL DEFAULT 0,
    DunnageCode       NVARCHAR(50)   NULL,
    CustomerCode      NVARCHAR(50)   NULL,
    -- OI-02 (Pending Customer Validation): scale-driven container closure.
    -- NULL today; populated once MPP confirms the behavior.
    ClosureMethod     NVARCHAR(20)   NULL,       -- Expected values: 'ByCount', 'ByWeight'
    TargetWeight      DECIMAL(10,4)  NULL,       -- Target closure weight when ClosureMethod = 'ByWeight'
    CreatedAt         DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt         DATETIME2(3)   NULL,
    DeprecatedAt      DATETIME2(3)   NULL
);

-- One active ContainerConfig per Item — filtered unique index
CREATE UNIQUE INDEX UQ_ContainerConfig_ActiveItemId
    ON Parts.ContainerConfig (ItemId)
    WHERE DeprecatedAt IS NULL;

CREATE INDEX IX_ContainerConfig_ItemId ON Parts.ContainerConfig (ItemId);


-- == VERSION TRACKING ========================================

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0005_item_master_container_config',
    'Phase 4: Parts.Item (full user attribution) + Parts.ContainerConfig (with OI-02 nullable columns ClosureMethod/TargetWeight)'
);

COMMIT;
