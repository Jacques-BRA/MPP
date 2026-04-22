-- ============================================================
-- Migration:   0010_phase9_tools_and_workorder.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-22
-- Description: Phase G of the 2026-04-20 OI review refactor — Tool
--              Management subsystem + Phase E additive schema changes.
--
--              TOOLS SCHEMA (Phase B, OI-10 superseded):
--                 1. Tools.ToolStatusCode              (seed 4 read-only)
--                 2. Tools.ToolCavityStatusCode        (seed 3 read-only)
--                 3. Tools.ToolType                    (seed 6 read-only)
--                 4. Tools.ToolAttributeDefinition     (empty — Engineering populates)
--                 5. Tools.DieRank                     (empty — MPP Quality owes)
--                 6. Tools.DieRankCompatibility        (empty — MPP Quality owes)
--                 7. Tools.Tool                        (system of record)
--                 8. Tools.ToolAttribute               (values)
--                 9. Tools.ToolCavity                  (die cavities)
--                10. Tools.ToolAssignment              (check-in/out history)
--
--              WORKORDER CODE TABLES (Phase B + Phase E):
--                11. Workorder.WorkOrderType          (seed 3 read-only — Demand/Maintenance/Recipe)
--                12. Workorder.ScrapSource            (seed 2 read-only — Inventory/Location, OI-20)
--
--              PARTS SCHEMA ALTERS (Phase E additive):
--                - Parts.Item + CountryOfOrigin NVARCHAR(2) NULL       (OI-19)
--                - Parts.ContainerConfig + MaxParts INT NULL           (OI-12)
--                - Parts.ItemLocation + MinQuantity / MaxQuantity /
--                  DefaultQuantity INT NULL + IsConsumptionPoint BIT   (OI-18)
--
--              AUDIT SCHEMA:
--                - Audit.LogEntityType + 9 seed rows (Ids 31–39)
--
--              DEFERRED TO ARC 2 PHASE 1 (tables don't exist yet):
--                - Workorder.WorkOrder + WorkOrderTypeId  (WorkOrder table doesn't exist)
--                - Workorder.WorkOrder + ToolId           (same)
--                - Workorder.ProductionEvent + ScrapSourceId (ProductionEvent doesn't exist)
--              Arc 2 Phase 1 CREATEs these with the columns baked in
--              — see memory/project_mpp_oi_refactor.md for the
--              full hand-off list.
--
--              OI-11 RESOLUTION (2026-04-22, post G.1 review):
--                Casting → Trim part rename modelled as a normal
--                1-line BOM consumption (Trim part has Cast part as
--                its sole component). No dedicated `Parts.ItemTransform`
--                table — ConsumptionEvent + LotGenealogy already
--                capture the flow.
--
--              ALSO DEFERRED (coordinated proc updates required):
--                - DROP Location.AppUser.ClockNumber + PinHash
--                  The existing AppUser_Create / _Update / _Get /
--                  _GetByAdAccount / _List / _Deprecate procs reference
--                  these columns and must be updated before the DROP
--                  can run safely. Will be a follow-up mini-migration
--                  after G.2 proc updates.
-- ============================================================

BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0010_phase9_tools_and_workorder')
BEGIN
    PRINT 'Migration 0010 already applied — skipping.';
    COMMIT;
    RETURN;
END


-- ============================================================
-- == Tools schema ==========================================
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Tools')
    EXEC('CREATE SCHEMA [Tools]');


-- ============================================================
-- == Tools.ToolStatusCode — seed-only read-only ============
-- ============================================================

CREATE TABLE Tools.ToolStatusCode (
    Id          BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code        NVARCHAR(30)   NOT NULL,
    Name        NVARCHAR(100)  NOT NULL,
    Description NVARCHAR(500)  NULL,
    CONSTRAINT UQ_ToolStatusCode_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Tools.ToolStatusCode ON;
INSERT INTO Tools.ToolStatusCode (Id, Code, Name, Description) VALUES
    (1, N'Active',      N'Active',       N'In service — mounted or available for mount.'),
    (2, N'UnderRepair', N'Under Repair', N'Removed from service for repair or refurbishment.'),
    (3, N'Scrapped',    N'Scrapped',     N'Physically destroyed or discarded. Terminal state.'),
    (4, N'Retired',     N'Retired',      N'End-of-life, archived. Terminal state (distinct from DeprecatedAt row-lifecycle).');
SET IDENTITY_INSERT Tools.ToolStatusCode OFF;


-- ============================================================
-- == Tools.ToolCavityStatusCode — seed-only read-only ======
-- ============================================================

CREATE TABLE Tools.ToolCavityStatusCode (
    Id          BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code        NVARCHAR(30)   NOT NULL,
    Name        NVARCHAR(100)  NOT NULL,
    Description NVARCHAR(500)  NULL,
    CONSTRAINT UQ_ToolCavityStatusCode_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Tools.ToolCavityStatusCode ON;
INSERT INTO Tools.ToolCavityStatusCode (Id, Code, Name, Description) VALUES
    (1, N'Active',   N'Active',   N'Producing acceptable parts.'),
    (2, N'Closed',   N'Closed',   N'Physically shut off — die continues to run on remaining cavities.'),
    (3, N'Scrapped', N'Scrapped', N'Cavity physically destroyed. Die may still run on remaining cavities or be scrapped independently.');
SET IDENTITY_INSERT Tools.ToolCavityStatusCode OFF;


-- ============================================================
-- == Tools.ToolType — seed 6 rows, read-only ===============
-- ============================================================
-- HasCavities=1 gates Tools.ToolCavity children (currently Die only).
-- Mirrors Location.LocationTypeDefinition.Icon for Perspective tree
-- component rendering (NULL at deployment; populated via Config Tool).

CREATE TABLE Tools.ToolType (
    Id           BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code         NVARCHAR(50)   NOT NULL,
    Name         NVARCHAR(100)  NOT NULL,
    Description  NVARCHAR(500)  NULL,
    Icon         NVARCHAR(100)  NULL,
    HasCavities  BIT            NOT NULL DEFAULT 0,
    SortOrder    INT            NOT NULL DEFAULT 0,
    CreatedAt    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt DATETIME2(3)   NULL,
    CONSTRAINT UQ_ToolType_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Tools.ToolType ON;
INSERT INTO Tools.ToolType (Id, Code, Name, Description, HasCavities, SortOrder) VALUES
    (1, N'Die',             N'Die Cast Die',     N'Dies used on die cast machines. Have cavities.',           1, 10),
    (2, N'Cutter',          N'Machining Cutter', N'Tool heads / inserts on CNC machines.',                    0, 20),
    (3, N'Jig',             N'Assembly Jig',     N'Fixtures on assembly stations.',                           0, 30),
    (4, N'Gauge',           N'Inspection Gauge', N'Measurement tools used for quality sampling.',             0, 40),
    (5, N'AssemblyFixture', N'Assembly Fixture', N'Trim-shop and assembly fixtures.',                         0, 50),
    (6, N'TrimTool',        N'Trim Shop Tool',   N'Trim-specific tooling (e.g., trim dies, deburr tools).',   0, 60);
SET IDENTITY_INSERT Tools.ToolType OFF;


-- ============================================================
-- == Tools.ToolAttributeDefinition — mutable, empty ========
-- ============================================================
-- Engineering populates via the Configuration Tool. Attribute codes
-- are unique per ToolType (e.g., Die can have CycleTimeSec and
-- Tonnage; Cutter can have InsertCount). The filtered unique index
-- permits a deprecated row to coexist with a fresh active one.

CREATE TABLE Tools.ToolAttributeDefinition (
    Id           BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ToolTypeId   BIGINT         NOT NULL REFERENCES Tools.ToolType(Id),
    Code         NVARCHAR(50)   NOT NULL,
    Name         NVARCHAR(100)  NOT NULL,
    DataType     NVARCHAR(20)   NOT NULL,
    IsRequired   BIT            NOT NULL DEFAULT 0,
    SortOrder    INT            NOT NULL DEFAULT 0,
    CreatedAt    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt DATETIME2(3)   NULL,
    CONSTRAINT CK_ToolAttributeDefinition_DataType
        CHECK (DataType IN (N'String', N'Integer', N'Decimal', N'Boolean', N'Date'))
);

CREATE UNIQUE INDEX UQ_ToolAttributeDefinition_ActiveTypeCode
    ON Tools.ToolAttributeDefinition (ToolTypeId, Code)
    WHERE DeprecatedAt IS NULL;

CREATE INDEX IX_ToolAttributeDefinition_ToolType
    ON Tools.ToolAttributeDefinition (ToolTypeId) WHERE DeprecatedAt IS NULL;


-- ============================================================
-- == Tools.DieRank — mutable, EMPTY seed ===================
-- ============================================================
-- MPP Quality owes the authoritative list. Merge proc rejects
-- cross-die merges with supervisor override until this table is
-- populated (see Lots.Lot_Merge, Arc 2). Admin CRUD via
-- Configuration Tool.

CREATE TABLE Tools.DieRank (
    Id           BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code         NVARCHAR(20)   NOT NULL,
    Name         NVARCHAR(100)  NOT NULL,
    Description  NVARCHAR(500)  NULL,
    SortOrder    INT            NOT NULL DEFAULT 0,
    CreatedAt    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt DATETIME2(3)   NULL,
    CONSTRAINT UQ_DieRank_Code UNIQUE (Code)
);


-- ============================================================
-- == Tools.DieRankCompatibility — mutable, EMPTY seed ======
-- ============================================================
-- Junction on (RankAId, RankBId). Convention: store canonical pairs
-- (smaller Id first) so a single lookup covers both directions;
-- enforced at the proc layer. Empty at deployment; MPP Quality
-- populates via the Die Rank Matrix admin screen.

CREATE TABLE Tools.DieRankCompatibility (
    Id        BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    RankAId   BIGINT         NOT NULL REFERENCES Tools.DieRank(Id),
    RankBId   BIGINT         NOT NULL REFERENCES Tools.DieRank(Id),
    CanMix    BIT            NOT NULL,
    CreatedAt DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2(3)   NULL,
    CONSTRAINT UQ_DieRankCompatibility_Pair UNIQUE (RankAId, RankBId),
    CONSTRAINT CK_DieRankCompatibility_Canonical
        CHECK (RankAId <= RankBId)
);

CREATE INDEX IX_DieRankCompatibility_RankA ON Tools.DieRankCompatibility (RankAId);
CREATE INDEX IX_DieRankCompatibility_RankB ON Tools.DieRankCompatibility (RankBId);


-- ============================================================
-- == Tools.Tool — system of record =========================
-- ============================================================
-- No shot counter — derived from Workorder.ProductionEvent group-by
-- (Arc 2). DieRankId is Die-type only; application-level validation
-- in the Tool_Create / _Update procs enforces (Recipe / non-Die
-- rows legitimately NULL). DeprecatedAt is row-lifecycle (soft
-- delete); StatusCode = Retired / Scrapped is business state.

CREATE TABLE Tools.Tool (
    Id              BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ToolTypeId      BIGINT         NOT NULL REFERENCES Tools.ToolType(Id),
    Code            NVARCHAR(50)   NOT NULL,
    Name            NVARCHAR(100)  NOT NULL,
    Description     NVARCHAR(500)  NULL,
    DieRankId       BIGINT         NULL     REFERENCES Tools.DieRank(Id),
    StatusCodeId    BIGINT         NOT NULL REFERENCES Tools.ToolStatusCode(Id),
    CreatedAt       DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2(3)   NULL,
    CreatedByUserId BIGINT         NOT NULL REFERENCES Location.AppUser(Id),
    UpdatedByUserId BIGINT         NULL     REFERENCES Location.AppUser(Id),
    DeprecatedAt    DATETIME2(3)   NULL,
    CONSTRAINT UQ_Tool_Code UNIQUE (Code)
);

CREATE INDEX IX_Tool_ToolTypeId  ON Tools.Tool (ToolTypeId)   WHERE DeprecatedAt IS NULL;
CREATE INDEX IX_Tool_StatusCode  ON Tools.Tool (StatusCodeId) WHERE DeprecatedAt IS NULL;
CREATE INDEX IX_Tool_DieRankId   ON Tools.Tool (DieRankId)    WHERE DieRankId IS NOT NULL AND DeprecatedAt IS NULL;


-- ============================================================
-- == Tools.ToolAttribute — values ==========================
-- ============================================================
-- One value per (Tool, AttributeDefinition). Stored as text;
-- interpreted per the definition's DataType at the proc / UI layer.

CREATE TABLE Tools.ToolAttribute (
    Id                         BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ToolId                     BIGINT         NOT NULL REFERENCES Tools.Tool(Id),
    ToolAttributeDefinitionId  BIGINT         NOT NULL REFERENCES Tools.ToolAttributeDefinition(Id),
    Value                      NVARCHAR(500)  NOT NULL,
    UpdatedAt                  DATETIME2(3)   NULL,
    UpdatedByUserId            BIGINT         NULL     REFERENCES Location.AppUser(Id),
    CONSTRAINT UQ_ToolAttribute_ToolDefinition UNIQUE (ToolId, ToolAttributeDefinitionId)
);

CREATE INDEX IX_ToolAttribute_Tool ON Tools.ToolAttribute (ToolId);


-- ============================================================
-- == Tools.ToolCavity — die cavities =======================
-- ============================================================
-- Only valid for Tools whose ToolType.HasCavities = 1 — enforced
-- at the proc layer (no CHECK because the validation would require
-- a correlated subquery). CavityNumber is immutable after creation;
-- only StatusCodeId changes via Tool_UpdateCavityStatus.

CREATE TABLE Tools.ToolCavity (
    Id              BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ToolId          BIGINT         NOT NULL REFERENCES Tools.Tool(Id),
    CavityNumber    INT            NOT NULL,
    StatusCodeId    BIGINT         NOT NULL REFERENCES Tools.ToolCavityStatusCode(Id),
    Description     NVARCHAR(500)  NULL,
    CreatedAt       DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2(3)   NULL,
    CreatedByUserId BIGINT         NOT NULL REFERENCES Location.AppUser(Id),
    UpdatedByUserId BIGINT         NULL     REFERENCES Location.AppUser(Id),
    DeprecatedAt    DATETIME2(3)   NULL
);

CREATE UNIQUE INDEX UQ_ToolCavity_ActiveToolCavity
    ON Tools.ToolCavity (ToolId, CavityNumber)
    WHERE DeprecatedAt IS NULL;

CREATE INDEX IX_ToolCavity_Tool ON Tools.ToolCavity (ToolId) WHERE DeprecatedAt IS NULL;


-- ============================================================
-- == Tools.ToolAssignment — check-in/out history ===========
-- ============================================================
-- Append-only. AssignedAt is set when a Tool is mounted on a Cell;
-- ReleasedAt is set when the Tool is removed. One active
-- assignment per Tool (filtered unique on ReleasedAt IS NULL).
-- CellLocationId must reference a Cell-tier Location — enforced at
-- the proc layer.
-- Mount / release is FDS-04-007 elevated-action; AssignedByUserId
-- + ReleasedByUserId are AD-authenticated supervisor users.

CREATE TABLE Tools.ToolAssignment (
    Id                BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ToolId            BIGINT         NOT NULL REFERENCES Tools.Tool(Id),
    CellLocationId    BIGINT         NOT NULL REFERENCES Location.Location(Id),
    AssignedAt        DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    ReleasedAt        DATETIME2(3)   NULL,
    AssignedByUserId  BIGINT         NOT NULL REFERENCES Location.AppUser(Id),
    ReleasedByUserId  BIGINT         NULL     REFERENCES Location.AppUser(Id),
    Notes             NVARCHAR(500)  NULL
);

CREATE UNIQUE INDEX UQ_ToolAssignment_ActiveTool
    ON Tools.ToolAssignment (ToolId)
    WHERE ReleasedAt IS NULL;

CREATE UNIQUE INDEX UQ_ToolAssignment_ActiveCell
    ON Tools.ToolAssignment (CellLocationId)
    WHERE ReleasedAt IS NULL;

CREATE INDEX IX_ToolAssignment_Tool         ON Tools.ToolAssignment (ToolId, AssignedAt DESC);
CREATE INDEX IX_ToolAssignment_CellLocation ON Tools.ToolAssignment (CellLocationId, AssignedAt DESC);


-- ============================================================
-- == Workorder.WorkOrderType — seed 3 rows, read-only ======
-- ============================================================
-- Three-type model from OI-07 (2026-04-20 meeting). Standalone
-- code table — the reverse FK from Workorder.WorkOrder is added
-- when Arc 2 Phase 1 creates that table.

CREATE TABLE Workorder.WorkOrderType (
    Id          BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code        NVARCHAR(20)   NOT NULL,
    Name        NVARCHAR(100)  NOT NULL,
    Description NVARCHAR(500)  NULL,
    CONSTRAINT UQ_WorkOrderType_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Workorder.WorkOrderType ON;
INSERT INTO Workorder.WorkOrderType (Id, Code, Name, Description) VALUES
    (1, N'Demand',      N'Demand Work Order',      N'Production work orders. MVP-LITE: auto-generated on LOT start, invisible to operators.'),
    (2, N'Maintenance', N'Maintenance Work Order', N'Targets a Tools.Tool. FUTURE flow in MVP — schema hook only, no screens or procs. Ben owes scope.'),
    (3, N'Recipe',      N'Recipe Work Order',      N'Configuration / recipe context. Hidden from operator. Created by the Configuration Tool.');
SET IDENTITY_INSERT Workorder.WorkOrderType OFF;


-- ============================================================
-- == Workorder.ScrapSource — seed 2 rows, read-only ========
-- ============================================================
-- OI-20 (2026-04-22 screenshot review): distinguishes the two
-- scrap paths surfaced in the legacy Flexware Lot Details screen.
-- Standalone — reverse FK from Workorder.ProductionEvent added
-- when Arc 2 Phase 1 creates that table.

CREATE TABLE Workorder.ScrapSource (
    Id          BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code        NVARCHAR(20)   NOT NULL,
    Name        NVARCHAR(100)  NOT NULL,
    Description NVARCHAR(500)  NULL,
    CONSTRAINT UQ_ScrapSource_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Workorder.ScrapSource ON;
INSERT INTO Workorder.ScrapSource (Id, Code, Name, Description) VALUES
    (1, N'Inventory', N'Scrap From Inventory', N'Scrap of unallocated pieces on a LOT — no workstation context. Used by the Lot Details "Scrap from inventory" button.'),
    (2, N'Location',  N'Scrap From Location',  N'Scrap of in-process pieces at a specific Cell — workstation context required. Used by the workstation "Scrap from the selected location" button.');
SET IDENTITY_INSERT Workorder.ScrapSource OFF;


-- ============================================================
-- == Parts.Item — ADD CountryOfOrigin (OI-19) ===============
-- ============================================================
-- Honda compliance field. ISO 3166-1 alpha-2. Nullable because
-- MPP's current parts list may not have values for every row at
-- cutover — Configuration Tool Item edit screen exposes it for
-- backfill.

ALTER TABLE Parts.Item
    ADD CountryOfOrigin NVARCHAR(2) NULL;


-- ============================================================
-- == Parts.ContainerConfig — ADD MaxParts (OI-12) ===========
-- ============================================================
-- Hard cap on pieces per container regardless of tray/container
-- math. Scan-in mutation rejects when cumulative container quantity
-- would exceed MaxParts. NULL-capable for Items that don't need
-- the cap (they still observe tray/container math via
-- TraysPerContainer × PartsPerTray).

ALTER TABLE Parts.ContainerConfig
    ADD MaxParts INT NULL;


-- ============================================================
-- == Parts.ItemLocation — ADD consumption metadata (OI-18) ==
-- ============================================================
-- Mirrors the legacy Flexware "Compatible work cells" columns.
-- IsConsumptionPoint NOT NULL DEFAULT 0: existing rows default
-- to "eligible but not a consumption point" so the runtime
-- Allocations grid treats them as produce-at / eligible-at until
-- Engineering flags them as consumption inputs via the
-- Configuration Tool.

ALTER TABLE Parts.ItemLocation
    ADD MinQuantity       INT  NULL,
        MaxQuantity       INT  NULL,
        DefaultQuantity   INT  NULL,
        IsConsumptionPoint BIT NOT NULL DEFAULT 0 WITH VALUES;


-- ============================================================
-- == Audit.LogEntityType — 9 new seed rows (Ids 31–39) =====
-- ============================================================
-- Phase 8 ended at Id=30 (ShiftSchedule). Phase G adds:
--   31–37 — Tools schema mutable entities (ToolStatusCode /
--           ToolCavityStatusCode / ToolType are read-only — no
--           ConfigLog entries expected, so no LogEntityType rows)
--   38    — WorkOrderType (read-only but included for visibility
--           per Phase B spec — future Maintenance WO CRUD will log)
--   39    — ScrapSource (read-only code table; row for visibility)
--
-- OI-11 (Casting → Trim part rename) is resolved via normal BOM
-- consumption — no dedicated `Parts.ItemTransform` table. The 1-line
-- BOM (Trim part has Cast part as a component) + existing
-- ConsumptionEvent + LotGenealogy carries the full genealogy. No
-- audit seed row is needed.

INSERT INTO Audit.LogEntityType (Id, Code, Name, Description) VALUES
    (31, N'Tool',                  N'Tool',                    N'Tools.Tool — system of record for tool identity (dies, cutters, jigs, gauges, fixtures, trim tools).'),
    (32, N'ToolAttributeDefinition', N'Tool Attribute Def',     N'Tools.ToolAttributeDefinition — per-type attribute schema (cycle time, tonnage, insert count).'),
    (33, N'ToolAttribute',         N'Tool Attribute',           N'Tools.ToolAttribute — attribute values per tool.'),
    (34, N'ToolCavity',            N'Tool Cavity',              N'Tools.ToolCavity — die cavity registration and status (Active / Closed / Scrapped).'),
    (35, N'ToolAssignment',        N'Tool Assignment',          N'Tools.ToolAssignment — append-only check-in/out history against Cells.'),
    (36, N'DieRank',               N'Die Rank',                 N'Tools.DieRank — MPP Quality die ranking (e.g., A–E). Empty at deployment.'),
    (37, N'DieRankCompatibility',  N'Die Rank Compatibility',   N'Tools.DieRankCompatibility — cross-rank merge compatibility matrix. Empty at deployment.'),
    (38, N'WorkOrderType',         N'Work Order Type',          N'Workorder.WorkOrderType — Demand / Maintenance / Recipe discriminator. Read-only seed.'),
    (39, N'ScrapSource',           N'Scrap Source',             N'Workorder.ScrapSource — Inventory / Location discriminator for scrap events (OI-20). Read-only seed.');


-- ============================================================
-- == Record migration =======================================
-- ============================================================
INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0010_phase9_tools_and_workorder',
    'Phase G: Tools schema (10 tables), Workorder.WorkOrderType + ScrapSource code tables, Parts ALTERs (Item.CountryOfOrigin, ContainerConfig.MaxParts, ItemLocation +4 cols), +9 LogEntityType rows. Deferred to Arc 2 P1: Workorder.WorkOrder/ProductionEvent column adds. OI-11 resolved via 1-line BOM (no ItemTransform table). AppUser legacy drop deferred to coordinated follow-up.'
);

COMMIT TRANSACTION;
PRINT 'Migration 0010 completed: Tools schema (10 tables), 2 Workorder code tables (WorkOrderType seed 3, ScrapSource seed 2), 3 Parts ALTERs (Item.CountryOfOrigin, ContainerConfig.MaxParts, ItemLocation +4 cols), 9 LogEntityType seed rows. Arc 2 Phase 1 will CREATE the deferred tables with dependent columns baked in.';
