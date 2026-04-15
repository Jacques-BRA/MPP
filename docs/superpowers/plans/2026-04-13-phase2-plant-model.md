# Phase 2 — Plant Model & Location Schema: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the five Location schema tables (LocationType, LocationTypeDefinition, LocationAttributeDefinition, Location, LocationAttribute), deploy ~25 stored procedures, seed the full MPP plant hierarchy including 209 machines from CSV, and add deferred FK constraints to Audit.OperationLog.

**Architecture:** Versioned migration creates the 5 tables + FK backfill + seed data. Repeatable scripts deploy each stored procedure individually (CREATE OR ALTER). Tests use the existing lightweight T-SQL test framework. The PowerShell reset script auto-discovers all files — no manual registration needed.

**Tech Stack:** SQL Server 2022+ (tested on 2025), sqlcmd.exe with `-C` flag, PowerShell reset/test runner.

---

## Context for the Implementing Engineer

### Project location
- Repository root: `C:\Users\JacquesPotgieter\documents\dev\mpp`
- SQL scripts: `sql/migrations/versioned/` (one-time), `sql/migrations/repeatable/` (CREATE OR ALTER procs), `sql/seeds/` (seed scripts)
- Tests: `sql/tests/` — numbered directories with `.sql` test files
- Seed CSV: `reference/seed_data/machines.csv` (209 rows + header)

### Key conventions (READ THESE)
- **Naming:** UpperCamelCase for all DB identifiers (tables, columns, procs, code values)
- **PKs:** `BIGINT IDENTITY(1,1)` everywhere. FKs are `BIGINT`. Value columns (SortOrder, counts) are `INT`.
- **Strings:** `NVARCHAR` only (never VARCHAR). Timestamps: `DATETIME2(3)`.
- **Soft delete:** `DeprecatedAt DATETIME2(3) NULL` — never hard DELETE.
- **SP output contract:** Every proc gets `@Status BIT OUTPUT` + `@Message NVARCHAR(500) OUTPUT`.
- **Audit:** Mutating procs call `Audit.Audit_LogConfigChange` on success (inside transaction) and `Audit.Audit_LogFailure` on every failure path (outside transaction).
- **Error handling:** RAISERROR (not bare THROW) in CATCH blocks with nested TRY/CATCH for failure logging. Capture `ERROR_MESSAGE()`, `ERROR_SEVERITY()`, `ERROR_STATE()` immediately on CATCH entry.
- **Sort ordering:** No drag-and-drop. Up/down arrow buttons via `_MoveUp`/`_MoveDown` procs that swap SortOrder with nearest sibling.
- **File naming:** Versioned: `NNNN_description.sql`. Repeatable: `R__Schema_Entity_Verb.sql`.

### Phase 1 (already complete)
Phase 1 created: 7 schemas, AppUser table (with bootstrap row Id=1), 4 audit log tables, 4 audit infrastructure procs, 8 AppUser CRUD procs, 3 audit lookup list procs, 6 audit log reader procs. All seeded and tested.

### Running the dev environment
```powershell
# Reset database (drops and rebuilds everything):
cd sql/scripts
.\Reset-DevDatabase.ps1

# Run tests:
cd sql/tests
.\Run-Tests.ps1

# Run filtered tests:
.\Run-Tests.ps1 -Filter "Location"
```

### Reference model: `R__Location_AppUser_Create.sql`
This is the gold-standard proc to copy from. Located at `sql/migrations/repeatable/R__Location_AppUser_Create.sql`. It demonstrates the full pattern: header block, output init, @ProcName/@Params capture, parameter validation with Audit_LogFailure, business rule checks with Audit_LogFailure, BEGIN TRANSACTION, INSERT, Audit_LogConfigChange inside txn, COMMIT, CATCH with ROLLBACK → error capture → nested TRY Audit_LogFailure → RAISERROR.

### Data model reference
Full column definitions are in `MPP_MES_DATA_MODEL.md` §1 (Location Schema). The plan reproduces the DDL below but if anything conflicts, the data model doc is authoritative.

---

## File Map

### Migration (versioned — runs once)
| File | Responsibility |
|---|---|
| `sql/migrations/versioned/0002_plant_model_location_schema.sql` | Creates 5 Location tables, indexes, adds deferred FK to Audit.OperationLog, records in SchemaVersion |

### Seed script (runs after migrations and repeatables)
| File | Responsibility |
|---|---|
| `sql/seeds/S001_location_seed_data.sql` | Seeds LocationType (5), LocationTypeDefinition (~15), LocationAttributeDefinition (~20), Enterprise/Site/Area hierarchy (7 rows) |

### Stored procedures (repeatable — CREATE OR ALTER)

**LocationType (read-only):**
| File | Procedure |
|---|---|
| `sql/migrations/repeatable/R__Location_LocationType_List.sql` | `Location.LocationType_List` |
| `sql/migrations/repeatable/R__Location_LocationType_Get.sql` | `Location.LocationType_Get` |

**LocationTypeDefinition (full CRUD):**
| File | Procedure |
|---|---|
| `sql/migrations/repeatable/R__Location_LocationTypeDefinition_List.sql` | `Location.LocationTypeDefinition_List` |
| `sql/migrations/repeatable/R__Location_LocationTypeDefinition_Get.sql` | `Location.LocationTypeDefinition_Get` |
| `sql/migrations/repeatable/R__Location_LocationTypeDefinition_Create.sql` | `Location.LocationTypeDefinition_Create` |
| `sql/migrations/repeatable/R__Location_LocationTypeDefinition_Update.sql` | `Location.LocationTypeDefinition_Update` |
| `sql/migrations/repeatable/R__Location_LocationTypeDefinition_Deprecate.sql` | `Location.LocationTypeDefinition_Deprecate` |

**LocationAttributeDefinition (CRUD + MoveUp/MoveDown):**
| File | Procedure |
|---|---|
| `sql/migrations/repeatable/R__Location_LocationAttributeDefinition_ListByDefinition.sql` | `Location.LocationAttributeDefinition_ListByDefinition` |
| `sql/migrations/repeatable/R__Location_LocationAttributeDefinition_Get.sql` | `Location.LocationAttributeDefinition_Get` |
| `sql/migrations/repeatable/R__Location_LocationAttributeDefinition_Create.sql` | `Location.LocationAttributeDefinition_Create` |
| `sql/migrations/repeatable/R__Location_LocationAttributeDefinition_Update.sql` | `Location.LocationAttributeDefinition_Update` |
| `sql/migrations/repeatable/R__Location_LocationAttributeDefinition_MoveUp.sql` | `Location.LocationAttributeDefinition_MoveUp` |
| `sql/migrations/repeatable/R__Location_LocationAttributeDefinition_MoveDown.sql` | `Location.LocationAttributeDefinition_MoveDown` |
| `sql/migrations/repeatable/R__Location_LocationAttributeDefinition_Deprecate.sql` | `Location.LocationAttributeDefinition_Deprecate` |

**Location (CRUD + tree queries + MoveUp/MoveDown):**
| File | Procedure |
|---|---|
| `sql/migrations/repeatable/R__Location_Location_List.sql` | `Location.Location_List` |
| `sql/migrations/repeatable/R__Location_Location_GetTree.sql` | `Location.Location_GetTree` |
| `sql/migrations/repeatable/R__Location_Location_GetAncestors.sql` | `Location.Location_GetAncestors` |
| `sql/migrations/repeatable/R__Location_Location_GetDescendantsOfType.sql` | `Location.Location_GetDescendantsOfType` |
| `sql/migrations/repeatable/R__Location_Location_Get.sql` | `Location.Location_Get` |
| `sql/migrations/repeatable/R__Location_Location_Create.sql` | `Location.Location_Create` |
| `sql/migrations/repeatable/R__Location_Location_Update.sql` | `Location.Location_Update` |
| `sql/migrations/repeatable/R__Location_Location_MoveUp.sql` | `Location.Location_MoveUp` |
| `sql/migrations/repeatable/R__Location_Location_MoveDown.sql` | `Location.Location_MoveDown` |
| `sql/migrations/repeatable/R__Location_Location_Deprecate.sql` | `Location.Location_Deprecate` |

**LocationAttribute (per-instance values):**
| File | Procedure |
|---|---|
| `sql/migrations/repeatable/R__Location_LocationAttribute_GetByLocation.sql` | `Location.LocationAttribute_GetByLocation` |
| `sql/migrations/repeatable/R__Location_LocationAttribute_Set.sql` | `Location.LocationAttribute_Set` |
| `sql/migrations/repeatable/R__Location_LocationAttribute_Clear.sql` | `Location.LocationAttribute_Clear` |

### Tests
| File | What it covers |
|---|---|
| `sql/tests/0002_LocationType/010_LocationType_read.sql` | LocationType_List, LocationType_Get against seed data |
| `sql/tests/0002_LocationType/020_LocationTypeDefinition_crud.sql` | LocationTypeDefinition Create/Update/Get/List/Deprecate |
| `sql/tests/0002_LocationType/030_LocationAttributeDefinition_crud.sql` | LocationAttributeDefinition Create/Get/ListByDefinition/Update/MoveUp/MoveDown/Deprecate |
| `sql/tests/0003_Location/010_Location_crud.sql` | Location Create/Update/Get/List/Deprecate |
| `sql/tests/0003_Location/020_Location_tree_queries.sql` | GetTree, GetAncestors, GetDescendantsOfType |
| `sql/tests/0003_Location/030_Location_sort_order.sql` | MoveUp/MoveDown, auto-increment on create, gap compaction on deprecate |
| `sql/tests/0003_Location/040_LocationAttribute_crud.sql` | LocationAttribute Set/GetByLocation/Clear, cross-definition validation |

**Total: 1 migration + 1 seed + 27 repeatable procs + 7 test files**

---

## Task 1: Migration — Create the 5 Location Tables

**Files:**
- Create: `sql/migrations/versioned/0002_plant_model_location_schema.sql`

- [ ] **Step 1: Write the migration script**

```sql
-- ============================================================
-- Migration:   0002_plant_model_location_schema.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-13
-- Description: Phase 2 — Creates the five Location schema tables
--              (LocationType, LocationTypeDefinition,
--              LocationAttributeDefinition, Location,
--              LocationAttribute) and adds deferred FKs from
--              Audit.OperationLog to Location.Location.
-- ============================================================

BEGIN TRANSACTION;

-- ── IDEMPOTENCY GUARD ────────────────────────────────────────
IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0002_plant_model_location_schema')
BEGIN
    PRINT 'Migration 0002 already applied — skipping.';
    COMMIT;
    RETURN;
END

-- ── LocationType ─────────────────────────────────────────────
CREATE TABLE Location.LocationType (
    Id              BIGINT          NOT NULL PRIMARY KEY,
    Code            NVARCHAR(20)    NOT NULL,
    Name            NVARCHAR(100)   NOT NULL,
    HierarchyLevel  INT             NOT NULL,
    Description     NVARCHAR(500)   NULL,
    CONSTRAINT UQ_LocationType_Code UNIQUE (Code)
);

-- ── LocationTypeDefinition ───────────────────────────────────
CREATE TABLE Location.LocationTypeDefinition (
    Id              BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LocationTypeId  BIGINT          NOT NULL REFERENCES Location.LocationType(Id),
    Code            NVARCHAR(50)    NOT NULL,
    Name            NVARCHAR(100)   NOT NULL,
    Description     NVARCHAR(500)   NULL,
    CreatedAt       DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt    DATETIME2(3)    NULL,
    CONSTRAINT UQ_LocationTypeDefinition_Code UNIQUE (Code)
);

CREATE INDEX IX_LocationTypeDefinition_TypeId
    ON Location.LocationTypeDefinition (LocationTypeId);

-- ── LocationAttributeDefinition ──────────────────────────────
CREATE TABLE Location.LocationAttributeDefinition (
    Id                          BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LocationTypeDefinitionId    BIGINT          NOT NULL REFERENCES Location.LocationTypeDefinition(Id),
    AttributeName               NVARCHAR(100)   NOT NULL,
    DataType                    NVARCHAR(50)    NOT NULL,
    IsRequired                  BIT             NOT NULL DEFAULT 0,
    DefaultValue                NVARCHAR(255)   NULL,
    Uom                         NVARCHAR(20)    NULL,
    SortOrder                   INT             NOT NULL DEFAULT 0,
    Description                 NVARCHAR(500)   NULL,
    CreatedAt                   DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt                DATETIME2(3)    NULL
);

CREATE INDEX IX_LocationAttributeDefinition_DefId
    ON Location.LocationAttributeDefinition (LocationTypeDefinitionId);

-- ── Location ─────────────────────────────────────────────────
CREATE TABLE Location.Location (
    Id                          BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LocationTypeDefinitionId    BIGINT          NOT NULL REFERENCES Location.LocationTypeDefinition(Id),
    ParentLocationId            BIGINT          NULL     REFERENCES Location.Location(Id),
    Name                        NVARCHAR(200)   NOT NULL,
    Code                        NVARCHAR(50)    NOT NULL,
    Description                 NVARCHAR(500)   NULL,
    SortOrder                   INT             NOT NULL DEFAULT 0,
    CreatedAt                   DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt                DATETIME2(3)    NULL,
    CONSTRAINT UQ_Location_Code UNIQUE (Code)
);

CREATE INDEX IX_Location_ParentId
    ON Location.Location (ParentLocationId);
CREATE INDEX IX_Location_DefId
    ON Location.Location (LocationTypeDefinitionId);

-- ── LocationAttribute ────────────────────────────────────────
CREATE TABLE Location.LocationAttribute (
    Id                              BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LocationId                      BIGINT          NOT NULL REFERENCES Location.Location(Id),
    LocationAttributeDefinitionId   BIGINT          NOT NULL REFERENCES Location.LocationAttributeDefinition(Id),
    AttributeValue                  NVARCHAR(255)   NOT NULL,
    CreatedAt                       DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt                       DATETIME2(3)    NULL,
    UpdatedByUserId                 BIGINT          NULL     REFERENCES Location.AppUser(Id)
);

CREATE INDEX IX_LocationAttribute_LocationId
    ON Location.LocationAttribute (LocationId);
CREATE UNIQUE INDEX UQ_LocationAttribute_Location_Def
    ON Location.LocationAttribute (LocationId, LocationAttributeDefinitionId)
    WHERE LocationId IS NOT NULL;

-- ── Deferred FK: Audit.OperationLog → Location.Location ──────
-- These columns were created in migration 0001 without FKs
-- because Location.Location did not exist yet.
ALTER TABLE Audit.OperationLog
    ADD CONSTRAINT FK_OperationLog_TerminalLocationId
    FOREIGN KEY (TerminalLocationId) REFERENCES Location.Location(Id);

ALTER TABLE Audit.OperationLog
    ADD CONSTRAINT FK_OperationLog_LocationId
    FOREIGN KEY (LocationId) REFERENCES Location.Location(Id);

-- ── SCHEMA VERSION ───────────────────────────────────────────
INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0002_plant_model_location_schema',
    'Phase 2: LocationType, LocationTypeDefinition, LocationAttributeDefinition, Location, LocationAttribute tables with indexes. Deferred Audit.OperationLog FK backfill.'
);

COMMIT;
```

- [ ] **Step 2: Run the reset script to verify the migration deploys cleanly**

```powershell
cd C:\Users\JacquesPotgieter\documents\dev\mpp\sql\scripts
.\Reset-DevDatabase.ps1
```

Expected: "2 migration(s) applied." with no errors. Verify the SchemaVersion table shows both migrations.

- [ ] **Step 3: Spot-check the tables exist**

```powershell
sqlcmd -S localhost -d MPP_MES_Dev -C -Q "SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'Location' ORDER BY TABLE_NAME;" -W
```

Expected: 6 tables (AppUser from Phase 1 + the 5 new ones).

- [ ] **Step 4: Commit**

```bash
git add sql/migrations/versioned/0002_plant_model_location_schema.sql
git commit -m "feat(phase2): migration 0002 — 5 location schema tables + audit FK backfill"
```

---

## Task 2: Seed Script — LocationType, LocationTypeDefinition, LocationAttributeDefinition, Plant Hierarchy

**Files:**
- Create: `sql/seeds/S001_location_seed_data.sql`

This seeds the structural hierarchy (types, definitions, attribute schemas, and the top-level plant nodes Enterprise→Site→5 Areas). Machine-level Cells (209 from CSV) are **not** in this seed — they'll be loaded by a bulk proc or separate seed in a later task.

- [ ] **Step 1: Write the seed script**

```sql
-- ============================================================
-- Seed:    S001_location_seed_data.sql
-- Author:  Blue Ridge Automation
-- Date:    2026-04-13
-- Description:
--   Seeds the Location schema structural data:
--   - LocationType (5 ISA-95 tiers)
--   - LocationTypeDefinition (~15 kinds)
--   - LocationAttributeDefinition (~20 attribute schemas)
--   - Location (Enterprise + Site + 5 Areas = 7 rows)
--
--   Machine-level cells are loaded separately.
--   Idempotent — checks before inserting.
-- ============================================================

-- ── IDEMPOTENCY GUARD ────────────────────────────────────────
IF EXISTS (SELECT 1 FROM Location.LocationType WHERE Code = N'Enterprise')
BEGIN
    PRINT 'Location seed data already loaded — skipping.';
    RETURN;
END

BEGIN TRANSACTION;

-- ══════════════════════════════════════════════════════════════
-- LocationType — 5 ISA-95 tiers (explicit IDs for FK stability)
-- ══════════════════════════════════════════════════════════════
INSERT INTO Location.LocationType (Id, Code, Name, HierarchyLevel, Description) VALUES
    (1, N'Enterprise',  N'Enterprise',   0, N'Top-level organization (MPP Inc.)'),
    (2, N'Site',        N'Site',         1, N'Physical plant/facility'),
    (3, N'Area',        N'Area',         2, N'Subdivision within a site (Die Cast, Trim Shop, etc.)'),
    (4, N'WorkCenter',  N'Work Center',  3, N'Production line or grouping of equipment'),
    (5, N'Cell',        N'Cell',         4, N'Individual station/unit — machines, terminals, inventory locations');

-- ══════════════════════════════════════════════════════════════
-- LocationTypeDefinition — kinds within each tier
-- ══════════════════════════════════════════════════════════════

-- Enterprise tier (Id 1)
SET IDENTITY_INSERT Location.LocationTypeDefinition ON;

INSERT INTO Location.LocationTypeDefinition (Id, LocationTypeId, Code, Name, Description) VALUES
    -- Enterprise
    ( 1, 1, N'Organization',            N'Organization',                N'The company root node (single row)'),
    -- Site
    ( 2, 2, N'Facility',                N'Facility',                    N'A physical manufacturing plant'),
    -- Area
    ( 3, 3, N'ProductionArea',          N'Production Area',             N'Production areas (Die Cast, Trim, Machining, Assembly)'),
    ( 4, 3, N'SupportArea',             N'Support Area',                N'Support areas (Production Control, Quality Control, Shipping, Receiving)'),
    -- WorkCenter
    ( 5, 4, N'ProductionLine',          N'Production Line',             N'Generic production line within an area'),
    ( 6, 4, N'InspectionLine',          N'Inspection Line',             N'Multi-part inspection lines'),
    -- Cell
    ( 7, 5, N'Terminal',                N'Terminal',                     N'Shared operator HMI station'),
    ( 8, 5, N'DieCastMachine',          N'Die Cast Machine',            N'Die cast press'),
    ( 9, 5, N'CNCMachine',              N'CNC Machine',                 N'Machining center / CNC cell'),
    (10, 5, N'TrimPress',               N'Trim Press',                  N'Trim shop press'),
    (11, 5, N'AssemblyStation',          N'Assembly Station',            N'Manual assembly station'),
    (12, 5, N'SerializedAssemblyLine',   N'Serialized Assembly Line',    N'PLC-integrated serialized assembly (5G0, etc.)'),
    (13, 5, N'InspectionStation',        N'Inspection Station',          N'Manual or vision-based inspection station'),
    (14, 5, N'InventoryLocation',        N'Inventory Location',          N'WIP storage, receiving dock, shipping dock, Sort Cage'),
    (15, 5, N'Scale',                    N'Scale',                       N'OmniServer-connected weight scale');

SET IDENTITY_INSERT Location.LocationTypeDefinition OFF;

-- ══════════════════════════════════════════════════════════════
-- LocationAttributeDefinition — attribute schemas per kind
-- ══════════════════════════════════════════════════════════════

-- Terminal (DefId 7)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description) VALUES
    (7, N'IpAddress',           N'NVARCHAR',  0, NULL,     NULL,       1, N'Terminal IP address for diagnostics'),
    (7, N'DefaultPrinter',      N'NVARCHAR',  0, NULL,     NULL,       2, N'Associated Zebra printer name for label output'),
    (7, N'HasBarcodeScanner',   N'BIT',       1, N'1',     NULL,       3, N'Whether terminal has scanner hardware');

-- DieCastMachine (DefId 8)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description) VALUES
    (8, N'Tonnage',             N'DECIMAL',   0, NULL,     N'tons',    1, N'Die cast press tonnage'),
    (8, N'NumberOfCavities',    N'INT',       0, NULL,     NULL,       2, N'Die cast cavity count'),
    (8, N'RefCycleTimeSec',     N'DECIMAL',   0, NULL,     N'seconds', 3, N'Reference cycle time for OEE performance calculation'),
    (8, N'OeeTarget',           N'DECIMAL',   0, NULL,     NULL,       4, N'Target OEE (0.00-1.00). FUTURE — designed for but not used in MVP.');

-- CNCMachine (DefId 9)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description) VALUES
    (9, N'RefCycleTimeSec',     N'DECIMAL',   0, NULL,     N'seconds', 1, N'Reference cycle time for OEE performance calculation'),
    (9, N'OeeTarget',           N'DECIMAL',   0, NULL,     NULL,       2, N'Target OEE (0.00-1.00). FUTURE.');

-- TrimPress (DefId 10)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description) VALUES
    (10, N'RefCycleTimeSec',    N'DECIMAL',   0, NULL,     N'seconds', 1, N'Reference cycle time for OEE performance calculation'),
    (10, N'OeeTarget',          N'DECIMAL',   0, NULL,     NULL,       2, N'Target OEE (0.00-1.00). FUTURE.');

-- InventoryLocation (DefId 14)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description) VALUES
    (14, N'IsPhysical',         N'BIT',       1, N'1',     NULL,       1, N'Physical location vs. logical bucket'),
    (14, N'IsLineside',         N'BIT',       0, N'0',     NULL,       2, N'Whether this is a lineside staging area'),
    (14, N'MaxLotCapacity',     N'INT',       0, NULL,     NULL,       3, N'Maximum LOTs that can be stored here');

-- Scale (DefId 15)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description) VALUES
    (15, N'OpcTagPath',         N'NVARCHAR',  0, NULL,     NULL,       1, N'OPC tag path for OmniServer weight reading'),
    (15, N'WeightUom',          N'NVARCHAR',  0, N'LB',    NULL,       2, N'Unit of measure for weight values');

-- ══════════════════════════════════════════════════════════════
-- Location — Enterprise + Site + 5 Areas
-- ══════════════════════════════════════════════════════════════

-- Enterprise root
SET IDENTITY_INSERT Location.Location ON;

INSERT INTO Location.Location (Id, LocationTypeDefinitionId, ParentLocationId, Name, Code, Description, SortOrder) VALUES
    (1, 1, NULL, N'Madison Precision Products, Inc.', N'MPP',       N'Enterprise root', 1);

-- Site
INSERT INTO Location.Location (Id, LocationTypeDefinitionId, ParentLocationId, Name, Code, Description, SortOrder) VALUES
    (2, 2, 1,    N'Madison Facility',                  N'MPP-MAD',  N'Madison, IN manufacturing plant', 1);

-- Areas (under Site)
INSERT INTO Location.Location (Id, LocationTypeDefinitionId, ParentLocationId, Name, Code, Description, SortOrder) VALUES
    (3, 3, 2, N'Die Cast',             N'DC',   N'Die casting production area',           1),
    (4, 3, 2, N'Machine Shop',         N'MS',   N'CNC machining production area',         2),
    (5, 3, 2, N'Trim Shop',            N'TS',   N'Trim shop production area',             3),
    (6, 4, 2, N'Production Control',   N'PC',   N'Production control support area',       4),
    (7, 4, 2, N'Quality Control',      N'QC',   N'Quality control support area',          5);

SET IDENTITY_INSERT Location.Location OFF;

COMMIT;

PRINT 'Location seed data loaded: 5 types, 15 definitions, attribute schemas, 7 hierarchy nodes.';
```

- [ ] **Step 2: Run the reset script to verify seed loads**

```powershell
cd C:\Users\JacquesPotgieter\documents\dev\mpp\sql\scripts
.\Reset-DevDatabase.ps1
```

Expected: "1 seed script(s) loaded." No errors.

- [ ] **Step 3: Spot-check the seeded data**

```powershell
sqlcmd -S localhost -d MPP_MES_Dev -C -Q "SELECT COUNT(*) AS TypeCount FROM Location.LocationType; SELECT COUNT(*) AS DefCount FROM Location.LocationTypeDefinition; SELECT COUNT(*) AS AttrDefCount FROM Location.LocationAttributeDefinition; SELECT COUNT(*) AS LocCount FROM Location.Location;" -W
```

Expected: 5 types, 15 definitions, ~18 attribute defs, 7 locations.

- [ ] **Step 4: Commit**

```bash
git add sql/seeds/S001_location_seed_data.sql
git commit -m "feat(phase2): seed LocationType, definitions, attribute schemas, plant hierarchy"
```

---

## Task 3: LocationType Read Procs + Tests

**Files:**
- Create: `sql/migrations/repeatable/R__Location_LocationType_List.sql`
- Create: `sql/migrations/repeatable/R__Location_LocationType_Get.sql`
- Create: `sql/tests/0002_LocationType/010_LocationType_read.sql`

- [ ] **Step 1: Write `Location.LocationType_List`**

```sql
-- =============================================
-- Procedure:   Location.LocationType_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     1.0
--
-- Description:
--   Returns all LocationType rows (the 5 ISA-95 tiers).
--   Read-only — these are seeded at deployment.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--
-- Result set:
--   All LocationType rows ordered by HierarchyLevel ASC.
--
-- Dependencies:
--   Tables: Location.LocationType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationType_List
    @Status  BIT            OUTPUT,
    @Message NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    BEGIN TRY
        SELECT Id, Code, Name, HierarchyLevel, Description
        FROM Location.LocationType
        ORDER BY HierarchyLevel ASC;

        SET @Status  = 1;
        SET @Message = N'Query executed successfully.';
    END TRY
    BEGIN CATCH
        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(ERROR_MESSAGE(), 400);
        THROW;
    END CATCH
END;
GO
```

- [ ] **Step 2: Write `Location.LocationType_Get`**

```sql
-- =============================================
-- Procedure:   Location.LocationType_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     1.0
--
-- Description:
--   Returns a single LocationType row by Id.
--
-- Parameters (input):
--   @Id BIGINT - LocationType PK. Required.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--
-- Result set:
--   0 or 1 LocationType rows.
--
-- Dependencies:
--   Tables: Location.LocationType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationType_Get
    @Id      BIGINT,
    @Status  BIT            OUTPUT,
    @Message NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    IF @Id IS NULL
    BEGIN
        SET @Message = N'Id is required.';
        RETURN;
    END

    BEGIN TRY
        SELECT Id, Code, Name, HierarchyLevel, Description
        FROM Location.LocationType
        WHERE Id = @Id;

        SET @Status  = 1;
        SET @Message = N'Query executed successfully.';
    END TRY
    BEGIN CATCH
        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(ERROR_MESSAGE(), 400);
        THROW;
    END CATCH
END;
GO
```

- [ ] **Step 3: Write the test file**

```sql
-- =============================================
-- Test:   010_LocationType_read.sql
-- Tests:  Location.LocationType_List, Location.LocationType_Get
-- Prereq: Seed data loaded (5 LocationType rows)
-- =============================================

EXEC test.BeginTestFile @FileName = N'010_LocationType_read.sql';

-- ── LocationType_List ────────────────────────────────────────
DECLARE @Status BIT, @Message NVARCHAR(500);

EXEC Location.LocationType_List
    @Status = @Status OUTPUT,
    @Message = @Message OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'LocationType_List: status is 1',
    @Expected = N'1', @Actual = CAST(@Status AS NVARCHAR(1));

-- Count the rows
DECLARE @TypeCount INT;
SELECT @TypeCount = COUNT(*) FROM Location.LocationType;
EXEC test.Assert_RowCount @TestName = N'LocationType_List: 5 seeded rows',
    @ExpectedCount = 5, @ActualCount = @TypeCount;

-- ── LocationType_Get — valid Id ──────────────────────────────
DECLARE @S2 BIT, @M2 NVARCHAR(500);

EXEC Location.LocationType_Get
    @Id = 1,
    @Status = @S2 OUTPUT,
    @Message = @M2 OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'LocationType_Get(1): status is 1',
    @Expected = N'1', @Actual = CAST(@S2 AS NVARCHAR(1));

-- Verify the Enterprise row
DECLARE @Code NVARCHAR(20);
SELECT @Code = Code FROM Location.LocationType WHERE Id = 1;
EXEC test.Assert_IsEqual @TestName = N'LocationType_Get(1): Code is Enterprise',
    @Expected = N'Enterprise', @Actual = @Code;

-- ── LocationType_Get — NULL Id ───────────────────────────────
DECLARE @S3 BIT, @M3 NVARCHAR(500);

EXEC Location.LocationType_Get
    @Id = NULL,
    @Status = @S3 OUTPUT,
    @Message = @M3 OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'LocationType_Get(NULL): status is 0',
    @Expected = N'0', @Actual = CAST(@S3 AS NVARCHAR(1));

-- ── LocationType_Get — non-existent Id ───────────────────────
DECLARE @S4 BIT, @M4 NVARCHAR(500);

EXEC Location.LocationType_Get
    @Id = 999,
    @Status = @S4 OUTPUT,
    @Message = @M4 OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'LocationType_Get(999): status is 1 (empty result is not an error)',
    @Expected = N'1', @Actual = CAST(@S4 AS NVARCHAR(1));

EXEC test.PrintSummary;
```

- [ ] **Step 4: Run the reset + tests**

```powershell
cd C:\Users\JacquesPotgieter\documents\dev\mpp\sql\tests
.\Run-Tests.ps1 -Filter "LocationType"
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add sql/migrations/repeatable/R__Location_LocationType_List.sql sql/migrations/repeatable/R__Location_LocationType_Get.sql sql/tests/0002_LocationType/010_LocationType_read.sql
git commit -m "feat(phase2): LocationType read procs + tests"
```

---

## Task 4: LocationTypeDefinition CRUD Procs + Tests

**Files:**
- Create: `sql/migrations/repeatable/R__Location_LocationTypeDefinition_List.sql`
- Create: `sql/migrations/repeatable/R__Location_LocationTypeDefinition_Get.sql`
- Create: `sql/migrations/repeatable/R__Location_LocationTypeDefinition_Create.sql`
- Create: `sql/migrations/repeatable/R__Location_LocationTypeDefinition_Update.sql`
- Create: `sql/migrations/repeatable/R__Location_LocationTypeDefinition_Deprecate.sql`
- Create: `sql/tests/0002_LocationType/020_LocationTypeDefinition_crud.sql`

- [ ] **Step 1: Write `Location.LocationTypeDefinition_List`**

```sql
-- =============================================
-- Procedure:   Location.LocationTypeDefinition_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     1.0
--
-- Description:
--   Returns LocationTypeDefinition rows, optionally filtered by tier.
--
-- Parameters (input):
--   @LocationTypeId BIGINT NULL   - Optional filter by ISA-95 tier.
--   @IncludeDeprecated BIT = 0    - Include deprecated definitions.
--
-- Parameters (output):
--   @Status BIT, @Message NVARCHAR(500)
--
-- Result set:
--   LocationTypeDefinition rows joined to LocationType.Name.
--
-- Dependencies:
--   Tables: Location.LocationTypeDefinition, Location.LocationType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationTypeDefinition_List
    @LocationTypeId    BIGINT          = NULL,
    @IncludeDeprecated BIT             = 0,
    @Status            BIT             OUTPUT,
    @Message           NVARCHAR(500)   OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    BEGIN TRY
        SELECT d.Id, d.LocationTypeId, t.Name AS LocationTypeName,
               d.Code, d.Name, d.Description,
               d.CreatedAt, d.DeprecatedAt
        FROM Location.LocationTypeDefinition d
        INNER JOIN Location.LocationType t ON t.Id = d.LocationTypeId
        WHERE (@LocationTypeId IS NULL OR d.LocationTypeId = @LocationTypeId)
          AND (@IncludeDeprecated = 1 OR d.DeprecatedAt IS NULL)
        ORDER BY t.HierarchyLevel, d.Code;

        SET @Status  = 1;
        SET @Message = N'Query executed successfully.';
    END TRY
    BEGIN CATCH
        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(ERROR_MESSAGE(), 400);
        THROW;
    END CATCH
END;
GO
```

- [ ] **Step 2: Write `Location.LocationTypeDefinition_Get`**

```sql
-- =============================================
-- Procedure:   Location.LocationTypeDefinition_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     1.0
--
-- Description:
--   Returns a single LocationTypeDefinition by Id.
--
-- Parameters (input):
--   @Id BIGINT - PK. Required.
--
-- Parameters (output):
--   @Status BIT, @Message NVARCHAR(500)
--
-- Result set:
--   0 or 1 rows.
--
-- Dependencies:
--   Tables: Location.LocationTypeDefinition, Location.LocationType
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationTypeDefinition_Get
    @Id      BIGINT,
    @Status  BIT            OUTPUT,
    @Message NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    IF @Id IS NULL
    BEGIN
        SET @Message = N'Id is required.';
        RETURN;
    END

    BEGIN TRY
        SELECT d.Id, d.LocationTypeId, t.Name AS LocationTypeName,
               d.Code, d.Name, d.Description,
               d.CreatedAt, d.DeprecatedAt
        FROM Location.LocationTypeDefinition d
        INNER JOIN Location.LocationType t ON t.Id = d.LocationTypeId
        WHERE d.Id = @Id;

        SET @Status  = 1;
        SET @Message = N'Query executed successfully.';
    END TRY
    BEGIN CATCH
        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(ERROR_MESSAGE(), 400);
        THROW;
    END CATCH
END;
GO
```

- [ ] **Step 3: Write `Location.LocationTypeDefinition_Create`**

Follow the exact pattern from `R__Location_AppUser_Create.sql`. Key differences: validates LocationTypeId FK, enforces Code uniqueness among active rows, audit entity code is `N'LocationTypeDef'`.

```sql
-- =============================================
-- Procedure:   Location.LocationTypeDefinition_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     1.0
--
-- Description:
--   Creates a new LocationTypeDefinition row. Validates LocationTypeId FK
--   and Code uniqueness. Logs success/failure to audit.
--
-- Parameters (input):
--   @LocationTypeId BIGINT       - FK to LocationType. Required.
--   @Code NVARCHAR(50)           - Short code. Required. Must be unique.
--   @Name NVARCHAR(100)          - Display name. Required.
--   @Description NVARCHAR(500)   - Optional description.
--   @AppUserId BIGINT            - User performing the action. Required.
--
-- Parameters (output):
--   @Status BIT, @Message NVARCHAR(500), @NewId BIGINT
--
-- Dependencies:
--   Tables: Location.LocationTypeDefinition, Location.LocationType
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationTypeDefinition_Create
    @LocationTypeId BIGINT,
    @Code           NVARCHAR(50),
    @Name           NVARCHAR(100),
    @Description    NVARCHAR(500)  = NULL,
    @AppUserId      BIGINT,
    @Status         BIT            OUTPUT,
    @Message        NVARCHAR(500)  OUTPUT,
    @NewId          BIGINT         = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';
    SET @NewId   = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Location.LocationTypeDefinition_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @LocationTypeId AS LocationTypeId,
                @Code           AS Code,
                @Name           AS Name,
                @Description    AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @LocationTypeId IS NULL OR @Code IS NULL OR @Name IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Location.LocationType WHERE Id = @LocationTypeId)
        BEGIN
            SET @Message = N'Invalid LocationTypeId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: Code uniqueness (active only — deprecated codes can be reused)
        IF EXISTS (SELECT 1 FROM Location.LocationTypeDefinition
                   WHERE Code = @Code AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'A definition with this Code already exists.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Mutation
        BEGIN TRANSACTION;

        INSERT INTO Location.LocationTypeDefinition
            (LocationTypeId, Code, Name, Description, CreatedAt)
        VALUES
            (@LocationTypeId, @Code, @Name, @Description, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
            @EntityId = @NewId, @LogEventTypeCode = N'Created',
            @LogSeverityCode = N'Info',
            @Description = N'LocationTypeDefinition created.',
            @OldValue = NULL, @NewValue = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'LocationTypeDefinition created successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);
        SET @NewId   = NULL;

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
```

- [ ] **Step 4: Write `Location.LocationTypeDefinition_Update`**

```sql
-- =============================================
-- Procedure:   Location.LocationTypeDefinition_Update
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     1.0
--
-- Description:
--   Updates a LocationTypeDefinition's Name and Description.
--   LocationTypeId and Code are immutable after creation.
--
-- Parameters (input):
--   @Id BIGINT                   - PK. Required.
--   @Name NVARCHAR(100)          - New display name. Required.
--   @Description NVARCHAR(500)   - New description.
--   @AppUserId BIGINT            - Required for audit.
--
-- Parameters (output):
--   @Status BIT, @Message NVARCHAR(500)
--
-- Dependencies:
--   Tables: Location.LocationTypeDefinition
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationTypeDefinition_Update
    @Id          BIGINT,
    @Name        NVARCHAR(100),
    @Description NVARCHAR(500)  = NULL,
    @AppUserId   BIGINT,
    @Status      BIT            OUTPUT,
    @Message     NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Location.LocationTypeDefinition_Update';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id, @Name AS Name, @Description AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Id IS NULL OR @Name IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Target must exist and be active
        DECLARE @OldName NVARCHAR(100), @OldDesc NVARCHAR(500);
        SELECT @OldName = Name, @OldDesc = Description
        FROM Location.LocationTypeDefinition
        WHERE Id = @Id AND DeprecatedAt IS NULL;

        IF @OldName IS NULL
        BEGIN
            SET @Message = N'LocationTypeDefinition not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT @OldName AS Name, @OldDesc AS Description
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Location.LocationTypeDefinition
        SET Name = @Name, Description = @Description
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
            @EntityId = @Id, @LogEventTypeCode = N'Updated',
            @LogSeverityCode = N'Info',
            @Description = N'LocationTypeDefinition updated.',
            @OldValue = @OldValue, @NewValue = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'LocationTypeDefinition updated successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
```

- [ ] **Step 5: Write `Location.LocationTypeDefinition_Deprecate`**

```sql
-- =============================================
-- Procedure:   Location.LocationTypeDefinition_Deprecate
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     1.0
--
-- Description:
--   Soft-deletes a LocationTypeDefinition. Rejects if any active
--   Location rows reference it.
--
-- Parameters (input):
--   @Id BIGINT        - PK. Required.
--   @AppUserId BIGINT - Required for audit.
--
-- Parameters (output):
--   @Status BIT, @Message NVARCHAR(500)
--
-- Dependencies:
--   Tables: Location.LocationTypeDefinition, Location.Location
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationTypeDefinition_Deprecate
    @Id        BIGINT,
    @AppUserId BIGINT,
    @Status    BIT            OUTPUT,
    @Message   NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Location.LocationTypeDefinition_Deprecate';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Location.LocationTypeDefinition
                       WHERE Id = @Id AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'LocationTypeDefinition not found or already deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: reject if active locations reference this definition
        IF EXISTS (SELECT 1 FROM Location.Location
                   WHERE LocationTypeDefinitionId = @Id AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Cannot deprecate: active locations reference this definition.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        BEGIN TRANSACTION;

        UPDATE Location.LocationTypeDefinition
        SET DeprecatedAt = SYSUTCDATETIME()
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
            @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
            @LogSeverityCode = N'Info',
            @Description = N'LocationTypeDefinition deprecated.',
            @OldValue = NULL, @NewValue = NULL;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'LocationTypeDefinition deprecated successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationTypeDef',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
```

- [ ] **Step 6: Write the test file**

```sql
-- =============================================
-- Test:   020_LocationTypeDefinition_crud.sql
-- Tests:  LocationTypeDefinition Create/Update/Get/List/Deprecate
-- Prereq: Seed data loaded (15 definitions)
-- =============================================

EXEC test.BeginTestFile @FileName = N'020_LocationTypeDefinition_crud.sql';

DECLARE @S BIT, @M NVARCHAR(500), @NewId BIGINT;

-- ── Create: happy path ───────────────────────────────────────
EXEC Location.LocationTypeDefinition_Create
    @LocationTypeId = 5,     -- Cell tier
    @Code = N'TestStand',
    @Name = N'Test Stand',
    @Description = N'Automated test station for unit testing',
    @AppUserId = 1,
    @Status = @S OUTPUT, @Message = @M OUTPUT, @NewId = @NewId OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'Create TestStand: status 1',
    @Expected = N'1', @Actual = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsNotNull @TestName = N'Create TestStand: NewId returned',
    @Value = CAST(@NewId AS NVARCHAR(20));

-- ── Create: duplicate code rejected ──────────────────────────
DECLARE @S2 BIT, @M2 NVARCHAR(500), @N2 BIGINT;
EXEC Location.LocationTypeDefinition_Create
    @LocationTypeId = 5, @Code = N'TestStand', @Name = N'Dupe',
    @AppUserId = 1,
    @Status = @S2 OUTPUT, @Message = @M2 OUTPUT, @NewId = @N2 OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'Create duplicate Code: status 0',
    @Expected = N'0', @Actual = CAST(@S2 AS NVARCHAR(1));
EXEC test.Assert_IsNull @TestName = N'Create duplicate Code: NewId is NULL',
    @Value = CAST(@N2 AS NVARCHAR(20));

-- ── Create: invalid LocationTypeId rejected ──────────────────
DECLARE @S3 BIT, @M3 NVARCHAR(500), @N3 BIGINT;
EXEC Location.LocationTypeDefinition_Create
    @LocationTypeId = 999, @Code = N'BadType', @Name = N'Bad',
    @AppUserId = 1,
    @Status = @S3 OUTPUT, @Message = @M3 OUTPUT, @NewId = @N3 OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'Create bad LocationTypeId: status 0',
    @Expected = N'0', @Actual = CAST(@S3 AS NVARCHAR(1));

-- ── Get: verify created row ──────────────────────────────────
DECLARE @S4 BIT, @M4 NVARCHAR(500);
EXEC Location.LocationTypeDefinition_Get
    @Id = @NewId,
    @Status = @S4 OUTPUT, @Message = @M4 OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'Get created row: status 1',
    @Expected = N'1', @Actual = CAST(@S4 AS NVARCHAR(1));

DECLARE @GotCode NVARCHAR(50);
SELECT @GotCode = Code FROM Location.LocationTypeDefinition WHERE Id = @NewId;
EXEC test.Assert_IsEqual @TestName = N'Get created row: Code matches',
    @Expected = N'TestStand', @Actual = @GotCode;

-- ── Update: change name ──────────────────────────────────────
DECLARE @S5 BIT, @M5 NVARCHAR(500);
EXEC Location.LocationTypeDefinition_Update
    @Id = @NewId,
    @Name = N'Test Stand v2',
    @Description = N'Updated description',
    @AppUserId = 1,
    @Status = @S5 OUTPUT, @Message = @M5 OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'Update: status 1',
    @Expected = N'1', @Actual = CAST(@S5 AS NVARCHAR(1));

DECLARE @UpdatedName NVARCHAR(100);
SELECT @UpdatedName = Name FROM Location.LocationTypeDefinition WHERE Id = @NewId;
EXEC test.Assert_IsEqual @TestName = N'Update: Name changed',
    @Expected = N'Test Stand v2', @Actual = @UpdatedName;

-- ── List: filter by tier ─────────────────────────────────────
DECLARE @S6 BIT, @M6 NVARCHAR(500);
EXEC Location.LocationTypeDefinition_List
    @LocationTypeId = 5,   -- Cell tier
    @Status = @S6 OUTPUT, @Message = @M6 OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'List Cell tier: status 1',
    @Expected = N'1', @Actual = CAST(@S6 AS NVARCHAR(1));

-- Count Cell definitions (9 seeded + 1 we created = 10)
DECLARE @CellCount INT;
SELECT @CellCount = COUNT(*)
FROM Location.LocationTypeDefinition
WHERE LocationTypeId = 5 AND DeprecatedAt IS NULL;

EXEC test.Assert_IsTrue @TestName = N'List Cell tier: at least 10 rows',
    @Condition = CASE WHEN @CellCount >= 10 THEN 1 ELSE 0 END,
    @Detail = N'Count: ' + CAST(@CellCount AS NVARCHAR(10));

-- ── Deprecate: reject when active locations exist ────────────
-- Enterprise def (Id=1) has active Location(Id=1) referencing it
DECLARE @S7 BIT, @M7 NVARCHAR(500);
EXEC Location.LocationTypeDefinition_Deprecate
    @Id = 1,
    @AppUserId = 1,
    @Status = @S7 OUTPUT, @Message = @M7 OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'Deprecate with active locations: status 0',
    @Expected = N'0', @Actual = CAST(@S7 AS NVARCHAR(1));

-- ── Deprecate: succeed when no active locations ──────────────
DECLARE @S8 BIT, @M8 NVARCHAR(500);
EXEC Location.LocationTypeDefinition_Deprecate
    @Id = @NewId,
    @AppUserId = 1,
    @Status = @S8 OUTPUT, @Message = @M8 OUTPUT;

EXEC test.Assert_IsEqual @TestName = N'Deprecate TestStand: status 1',
    @Expected = N'1', @Actual = CAST(@S8 AS NVARCHAR(1));

DECLARE @DepAt DATETIME2(3);
SELECT @DepAt = DeprecatedAt FROM Location.LocationTypeDefinition WHERE Id = @NewId;
EXEC test.Assert_IsNotNull @TestName = N'Deprecate TestStand: DeprecatedAt set',
    @Value = CAST(@DepAt AS NVARCHAR(30));

-- ── Audit trail check ────────────────────────────────────────
DECLARE @AuditCount INT;
SELECT @AuditCount = COUNT(*)
FROM Audit.ConfigLog
WHERE LogEntityTypeId = (SELECT Id FROM Audit.LogEntityType WHERE Code = N'LocationTypeDef');

EXEC test.Assert_IsTrue @TestName = N'Audit: ConfigLog has entries for LocationTypeDef',
    @Condition = CASE WHEN @AuditCount >= 3 THEN 1 ELSE 0 END,
    @Detail = N'ConfigLog count: ' + CAST(@AuditCount AS NVARCHAR(10));

EXEC test.PrintSummary;
```

- [ ] **Step 7: Run tests**

```powershell
cd C:\Users\JacquesPotgieter\documents\dev\mpp\sql\tests
.\Run-Tests.ps1 -Filter "LocationType"
```

Expected: All tests PASS in both 010 and 020 files.

- [ ] **Step 8: Commit**

```bash
git add sql/migrations/repeatable/R__Location_LocationTypeDefinition_*.sql sql/tests/0002_LocationType/020_LocationTypeDefinition_crud.sql
git commit -m "feat(phase2): LocationTypeDefinition CRUD procs + tests"
```

---

## Task 5: LocationAttributeDefinition CRUD + MoveUp/MoveDown + Tests

**Files:**
- Create: 7 proc files in `sql/migrations/repeatable/R__Location_LocationAttributeDefinition_*.sql`
- Create: `sql/tests/0002_LocationType/030_LocationAttributeDefinition_crud.sql`

This task follows the same patterns as Task 4 but adds the MoveUp/MoveDown sort ordering pattern. Key differences:
- Create auto-assigns `SortOrder = MAX(sibling SortOrder) + 1` within the same `LocationTypeDefinitionId`
- MoveUp/MoveDown swap SortOrder with the nearest active sibling
- Deprecate compacts sibling SortOrder gaps
- Update does NOT touch SortOrder

- [ ] **Step 1: Write all 7 procs**

Write each proc file following the established patterns. The procs are:

1. **`LocationAttributeDefinition_ListByDefinition`** — read proc, filters by `@LocationTypeDefinitionId`, orders by `SortOrder ASC`
2. **`LocationAttributeDefinition_Get`** — read proc, single row by Id
3. **`LocationAttributeDefinition_Create`** — mutating, auto-assigns SortOrder = `ISNULL((SELECT MAX(SortOrder) FROM Location.LocationAttributeDefinition WHERE LocationTypeDefinitionId = @LocationTypeDefinitionId AND DeprecatedAt IS NULL), 0) + 1`, validates LocationTypeDefinitionId FK, audit entity code `N'LocationAttrDef'`
4. **`LocationAttributeDefinition_Update`** — mutating, updates AttributeName/DataType/IsRequired/DefaultValue/Uom/Description. Does NOT change SortOrder.
5. **`LocationAttributeDefinition_MoveUp`** — mutating, finds nearest active sibling with SortOrder < current, swaps both SortOrder values atomically in one transaction. No-op (Status=1) if already first.
6. **`LocationAttributeDefinition_MoveDown`** — same as MoveUp but SortOrder > current, swaps with nearest below.
7. **`LocationAttributeDefinition_Deprecate`** — mutating, rejects if any `Location.LocationAttribute` rows reference it, then compacts sibling SortOrder gaps after deprecating.

**MoveUp pattern (use this for all MoveUp/MoveDown procs in this project):**

```sql
CREATE OR ALTER PROCEDURE Location.LocationAttributeDefinition_MoveUp
    @Id        BIGINT,
    @AppUserId BIGINT,
    @Status    BIT            OUTPUT,
    @Message   NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Location.LocationAttributeDefinition_MoveUp';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationAttrDef',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Get current row's SortOrder and parent
        DECLARE @CurrentSort INT, @ParentDefId BIGINT;
        SELECT @CurrentSort = SortOrder,
               @ParentDefId = LocationTypeDefinitionId
        FROM Location.LocationAttributeDefinition
        WHERE Id = @Id AND DeprecatedAt IS NULL;

        IF @CurrentSort IS NULL
        BEGIN
            SET @Message = N'Attribute definition not found or deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationAttrDef',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Find the nearest active sibling ABOVE (lower SortOrder)
        DECLARE @SwapId BIGINT, @SwapSort INT;
        SELECT TOP 1 @SwapId = Id, @SwapSort = SortOrder
        FROM Location.LocationAttributeDefinition
        WHERE LocationTypeDefinitionId = @ParentDefId
          AND DeprecatedAt IS NULL
          AND SortOrder < @CurrentSort
        ORDER BY SortOrder DESC;

        -- Already first — no-op, but still success
        IF @SwapId IS NULL
        BEGIN
            SET @Status  = 1;
            SET @Message = N'Already at the top position.';
            RETURN;
        END

        -- Swap
        BEGIN TRANSACTION;

        UPDATE Location.LocationAttributeDefinition
        SET SortOrder = @SwapSort WHERE Id = @Id;

        UPDATE Location.LocationAttributeDefinition
        SET SortOrder = @CurrentSort WHERE Id = @SwapId;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationAttrDef',
            @EntityId = @Id, @LogEventTypeCode = N'Updated',
            @LogSeverityCode = N'Info',
            @Description = N'Attribute definition moved up.',
            @OldValue = NULL, @NewValue = NULL;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Moved up successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'LocationAttrDef',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
```

**MoveDown** is identical but finds `SortOrder > @CurrentSort ORDER BY SortOrder ASC`.

**Deprecate gap compaction** — after setting `DeprecatedAt`, renumber all active siblings:

```sql
-- Inside the transaction, after the UPDATE ... SET DeprecatedAt:

;WITH Renumbered AS (
    SELECT Id, ROW_NUMBER() OVER (ORDER BY SortOrder) AS NewSort
    FROM Location.LocationAttributeDefinition
    WHERE LocationTypeDefinitionId = @ParentDefId
      AND DeprecatedAt IS NULL
)
UPDATE lad
SET lad.SortOrder = r.NewSort
FROM Location.LocationAttributeDefinition lad
INNER JOIN Renumbered r ON r.Id = lad.Id;
```

- [ ] **Step 2: Write the test file**

Test scenarios:
- Create 3 attribute defs for a test definition → verify SortOrder auto-assigned 1, 2, 3
- MoveDown the first → verify it swaps to position 2
- MoveUp the (now) last → verify it swaps correctly
- MoveUp when already first → verify no-op with Status=1
- MoveDown when already last → verify no-op with Status=1
- Deprecate the middle → verify SortOrder compacted (remaining are 1, 2)
- Deprecate rejected when LocationAttribute references exist

- [ ] **Step 3: Run tests**

```powershell
.\Run-Tests.ps1 -Filter "LocationType"
```

Expected: All tests PASS across all 3 test files.

- [ ] **Step 4: Commit**

```bash
git add sql/migrations/repeatable/R__Location_LocationAttributeDefinition_*.sql sql/tests/0002_LocationType/030_LocationAttributeDefinition_crud.sql
git commit -m "feat(phase2): LocationAttributeDefinition CRUD + MoveUp/MoveDown procs + tests"
```

---

## Task 6: Location CRUD Procs + Tests

**Files:**
- Create: `sql/migrations/repeatable/R__Location_Location_Create.sql` (update template file — already exists in `_TEMPLATE`, but needs the real proc with SortOrder auto-increment)
- Create: `R__Location_Location_List.sql`, `R__Location_Location_Get.sql`, `R__Location_Location_Update.sql`, `R__Location_Location_Deprecate.sql`
- Create: `sql/tests/0003_Location/010_Location_crud.sql`

Key implementation details:
- **Create** auto-assigns `SortOrder = MAX(sibling SortOrder among active rows with same ParentLocationId) + 1`
- **List** filters by `@ParentLocationId` and/or `@LocationTypeDefinitionId`, orders by `SortOrder ASC`
- **Get** returns the location row (attribute values are fetched separately via `LocationAttribute_GetByLocation`)
- **Deprecate** rejects if active `Location.Location` children exist (recursive check — if a parent has children, deprecate children first), or if `Lots.Lot.CurrentLocationId` references exist. After deprecating, compacts sibling SortOrder.
- Audit entity code: `N'Location'`

Note: The `_TEMPLATE` file already has a `Location.Location_Create` example, but the **real** proc needs the SortOrder auto-increment logic added. Create the real proc as a separate repeatable file.

- [ ] **Step 1: Write all 5 CRUD procs**

Follow the exact same patterns from Tasks 4-5. The Create proc adds SortOrder calculation:

```sql
-- Inside Location.Location_Create, after validation, before INSERT:
DECLARE @NextSort INT;
SELECT @NextSort = ISNULL(MAX(SortOrder), 0) + 1
FROM Location.Location
WHERE ParentLocationId = @ParentLocationId
  AND DeprecatedAt IS NULL;

-- (For root: WHERE ParentLocationId IS NULL, need to handle both cases)
IF @ParentLocationId IS NULL
    SELECT @NextSort = ISNULL(MAX(SortOrder), 0) + 1
    FROM Location.Location
    WHERE ParentLocationId IS NULL AND DeprecatedAt IS NULL;

-- Then in INSERT:
-- ... SortOrder = @NextSort ...
```

The Deprecate proc checks for active children AND active Lot references:

```sql
-- Business rule: reject if active child locations exist
IF EXISTS (SELECT 1 FROM Location.Location
           WHERE ParentLocationId = @Id AND DeprecatedAt IS NULL)
BEGIN
    SET @Message = N'Cannot deprecate: active child locations exist. Deprecate children first.';
    -- ... Audit_LogFailure + RETURN
END

-- Business rule: reject if active LOTs reference this location
-- Note: Lots.Lot table doesn't exist yet (Phase 2 runs before Lots tables).
-- This check will be uncommented when the Lots schema is built in a later phase.
-- For now, only check child locations.
```

- [ ] **Step 2: Write the test file**

Test scenarios:
- Create a child under the Site → verify SortOrder = auto-incremented
- Create a second child → verify SortOrder = previous + 1
- List children of Site → verify both returned in SortOrder order
- Get by Id → verify fields match
- Update Name → verify changed
- Deprecate with children → rejected
- Deprecate leaf node → success, SortOrder compacted
- Create with invalid LocationTypeDefinitionId → rejected
- Create with duplicate Code → rejected

- [ ] **Step 3: Run tests**

```powershell
.\Run-Tests.ps1 -Filter "Location"
```

- [ ] **Step 4: Commit**

```bash
git add sql/migrations/repeatable/R__Location_Location_Create.sql sql/migrations/repeatable/R__Location_Location_List.sql sql/migrations/repeatable/R__Location_Location_Get.sql sql/migrations/repeatable/R__Location_Location_Update.sql sql/migrations/repeatable/R__Location_Location_Deprecate.sql sql/tests/0003_Location/010_Location_crud.sql
git commit -m "feat(phase2): Location CRUD procs + tests"
```

---

## Task 7: Location Tree Query Procs + Tests

**Files:**
- Create: `R__Location_Location_GetTree.sql`, `R__Location_Location_GetAncestors.sql`, `R__Location_Location_GetDescendantsOfType.sql`
- Create: `sql/tests/0003_Location/020_Location_tree_queries.sql`

These three procs use recursive CTEs for hierarchy traversal.

- [ ] **Step 1: Write `Location.Location_GetTree`**

```sql
-- Recursive CTE: full hierarchy from a root down
-- Returns: all descendant rows with Depth (0 = root) and materialized path
CREATE OR ALTER PROCEDURE Location.Location_GetTree
    @RootLocationId BIGINT,
    @Status         BIT            OUTPUT,
    @Message        NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    IF @RootLocationId IS NULL
    BEGIN
        SET @Message = N'RootLocationId is required.';
        RETURN;
    END

    BEGIN TRY
        ;WITH Tree AS (
            SELECT l.Id, l.ParentLocationId, l.Name, l.Code,
                   l.LocationTypeDefinitionId, l.SortOrder,
                   l.Description, l.DeprecatedAt,
                   0 AS Depth,
                   CAST(l.Name AS NVARCHAR(MAX)) AS MaterializedPath
            FROM Location.Location l
            WHERE l.Id = @RootLocationId

            UNION ALL

            SELECT c.Id, c.ParentLocationId, c.Name, c.Code,
                   c.LocationTypeDefinitionId, c.SortOrder,
                   c.Description, c.DeprecatedAt,
                   t.Depth + 1,
                   t.MaterializedPath + N' > ' + c.Name
            FROM Location.Location c
            INNER JOIN Tree t ON t.Id = c.ParentLocationId
            WHERE c.DeprecatedAt IS NULL
        )
        SELECT tr.Id, tr.ParentLocationId, tr.Name, tr.Code,
               tr.LocationTypeDefinitionId, d.Name AS DefinitionName,
               lt.Name AS TypeName, lt.HierarchyLevel,
               tr.SortOrder, tr.Description, tr.DeprecatedAt,
               tr.Depth, tr.MaterializedPath
        FROM Tree tr
        INNER JOIN Location.LocationTypeDefinition d ON d.Id = tr.LocationTypeDefinitionId
        INNER JOIN Location.LocationType lt ON lt.Id = d.LocationTypeId
        ORDER BY tr.Depth, tr.SortOrder;

        SET @Status  = 1;
        SET @Message = N'Query executed successfully.';
    END TRY
    BEGIN CATCH
        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(ERROR_MESSAGE(), 400);
        THROW;
    END CATCH
END;
GO
```

- [ ] **Step 2: Write `Location.Location_GetAncestors`**

```sql
-- Recursive CTE: from this location up to root
-- Returns: ancestor rows ordered root → current
CREATE OR ALTER PROCEDURE Location.Location_GetAncestors
    @LocationId BIGINT,
    @Status     BIT            OUTPUT,
    @Message    NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    IF @LocationId IS NULL
    BEGIN
        SET @Message = N'LocationId is required.';
        RETURN;
    END

    BEGIN TRY
        ;WITH Ancestors AS (
            SELECT l.Id, l.ParentLocationId, l.Name, l.Code,
                   l.LocationTypeDefinitionId, l.SortOrder,
                   0 AS Depth
            FROM Location.Location l
            WHERE l.Id = @LocationId

            UNION ALL

            SELECT p.Id, p.ParentLocationId, p.Name, p.Code,
                   p.LocationTypeDefinitionId, p.SortOrder,
                   a.Depth + 1
            FROM Location.Location p
            INNER JOIN Ancestors a ON a.ParentLocationId = p.Id
        )
        SELECT a.Id, a.ParentLocationId, a.Name, a.Code,
               a.LocationTypeDefinitionId, d.Name AS DefinitionName,
               lt.Name AS TypeName, lt.HierarchyLevel,
               a.SortOrder, a.Depth
        FROM Ancestors a
        INNER JOIN Location.LocationTypeDefinition d ON d.Id = a.LocationTypeDefinitionId
        INNER JOIN Location.LocationType lt ON lt.Id = d.LocationTypeId
        ORDER BY a.Depth DESC;  -- root first

        SET @Status  = 1;
        SET @Message = N'Query executed successfully.';
    END TRY
    BEGIN CATCH
        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(ERROR_MESSAGE(), 400);
        THROW;
    END CATCH
END;
GO
```

- [ ] **Step 3: Write `Location.Location_GetDescendantsOfType`**

```sql
-- Recursive CTE: finds all descendants of a location filtered to a specific LocationType tier
-- E.g., "all Cells under the Die Cast Area"
CREATE OR ALTER PROCEDURE Location.Location_GetDescendantsOfType
    @LocationId     BIGINT,
    @LocationTypeId BIGINT,
    @Status         BIT            OUTPUT,
    @Message        NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    IF @LocationId IS NULL OR @LocationTypeId IS NULL
    BEGIN
        SET @Message = N'LocationId and LocationTypeId are required.';
        RETURN;
    END

    BEGIN TRY
        ;WITH Descendants AS (
            SELECT l.Id, l.ParentLocationId, l.LocationTypeDefinitionId
            FROM Location.Location l
            WHERE l.Id = @LocationId AND l.DeprecatedAt IS NULL

            UNION ALL

            SELECT c.Id, c.ParentLocationId, c.LocationTypeDefinitionId
            FROM Location.Location c
            INNER JOIN Descendants d ON d.Id = c.ParentLocationId
            WHERE c.DeprecatedAt IS NULL
        )
        SELECT l.Id, l.ParentLocationId, l.Name, l.Code,
               l.LocationTypeDefinitionId, d.Name AS DefinitionName,
               l.SortOrder, l.Description
        FROM Descendants desc_cte
        INNER JOIN Location.Location l ON l.Id = desc_cte.Id
        INNER JOIN Location.LocationTypeDefinition d ON d.Id = l.LocationTypeDefinitionId
        WHERE d.LocationTypeId = @LocationTypeId
          AND l.Id != @LocationId  -- exclude the root itself
        ORDER BY l.Name;

        SET @Status  = 1;
        SET @Message = N'Query executed successfully.';
    END TRY
    BEGIN CATCH
        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(ERROR_MESSAGE(), 400);
        THROW;
    END CATCH
END;
GO
```

- [ ] **Step 4: Write the test file**

Test against the seeded hierarchy (Enterprise→Site→5 Areas) plus test locations created in the test:
- GetTree from Enterprise root → should return all 7 seeded nodes
- GetTree from Site → should return Site + 5 Areas
- GetAncestors from Die Cast Area → should return Die Cast, Site, Enterprise (3 rows, root first)
- GetDescendantsOfType from Enterprise for Cell type → should return 0 (no Cells seeded yet)
- Create a test Cell under Die Cast, then GetDescendantsOfType → should return 1

- [ ] **Step 5: Run tests, commit**

```powershell
.\Run-Tests.ps1 -Filter "Location"
```

```bash
git add sql/migrations/repeatable/R__Location_Location_GetTree.sql sql/migrations/repeatable/R__Location_Location_GetAncestors.sql sql/migrations/repeatable/R__Location_Location_GetDescendantsOfType.sql sql/tests/0003_Location/020_Location_tree_queries.sql
git commit -m "feat(phase2): Location tree query procs (GetTree, GetAncestors, GetDescendantsOfType) + tests"
```

---

## Task 8: Location MoveUp/MoveDown + Tests

**Files:**
- Create: `R__Location_Location_MoveUp.sql`, `R__Location_Location_MoveDown.sql`
- Create: `sql/tests/0003_Location/030_Location_sort_order.sql`

Same pattern as Task 5's MoveUp/MoveDown for LocationAttributeDefinition, but scoped to siblings by `ParentLocationId` instead of `LocationTypeDefinitionId`. Handle the NULL parent case (Enterprise root has no siblings).

- [ ] **Step 1: Write MoveUp and MoveDown procs**

Use the MoveUp pattern from Task 5. Sibling scope: `WHERE ParentLocationId = @ParentId AND DeprecatedAt IS NULL` (or `WHERE ParentLocationId IS NULL` for the root level). Audit entity code: `N'Location'`.

- [ ] **Step 2: Write the test file**

Test scenarios:
- Create 3 sibling locations under the same parent → verify SortOrder 1, 2, 3 (the 5 seeded Areas already have SortOrder 1-5, so create children under a new parent to isolate the test)
- MoveDown the first → verify swap
- MoveUp the last → verify swap
- MoveUp when already first → no-op, Status=1
- MoveDown when already last → no-op, Status=1

- [ ] **Step 3: Run tests, commit**

```powershell
.\Run-Tests.ps1 -Filter "Location"
```

```bash
git add sql/migrations/repeatable/R__Location_Location_MoveUp.sql sql/migrations/repeatable/R__Location_Location_MoveDown.sql sql/tests/0003_Location/030_Location_sort_order.sql
git commit -m "feat(phase2): Location MoveUp/MoveDown procs + sort order tests"
```

---

## Task 9: LocationAttribute Procs + Tests

**Files:**
- Create: `R__Location_LocationAttribute_GetByLocation.sql`, `R__Location_LocationAttribute_Set.sql`, `R__Location_LocationAttribute_Clear.sql`
- Create: `sql/tests/0003_Location/040_LocationAttribute_crud.sql`

- [ ] **Step 1: Write `Location.LocationAttribute_GetByLocation`**

Read proc that returns all attribute values for a location, joined to their definitions (AttributeName, DataType, UOM, IsRequired, DefaultValue, SortOrder). Orders by `SortOrder ASC`.

- [ ] **Step 2: Write `Location.LocationAttribute_Set`**

Upsert pattern:
1. Validate LocationId exists and is active
2. Validate LocationAttributeDefinitionId exists and is active
3. **Cross-definition validation:** The attribute definition's `LocationTypeDefinitionId` must match the location's `LocationTypeDefinitionId`. This is the integrity rule from the data model.
4. If a `LocationAttribute` row already exists for this (LocationId, LocationAttributeDefinitionId), UPDATE it. Otherwise, INSERT.
5. Audit on success.

```sql
-- Cross-definition validation:
DECLARE @LocDefId BIGINT, @AttrDefId BIGINT;
SELECT @LocDefId = LocationTypeDefinitionId FROM Location.Location WHERE Id = @LocationId;
SELECT @AttrDefId = LocationTypeDefinitionId FROM Location.LocationAttributeDefinition WHERE Id = @LocationAttributeDefinitionId;

IF @LocDefId != @AttrDefId
BEGIN
    SET @Message = N'Attribute definition does not belong to this location''s type definition.';
    -- ... failure path
END
```

Upsert logic:
```sql
-- Check for existing row
DECLARE @ExistingId BIGINT, @OldVal NVARCHAR(255);
SELECT @ExistingId = Id, @OldVal = AttributeValue
FROM Location.LocationAttribute
WHERE LocationId = @LocationId
  AND LocationAttributeDefinitionId = @LocationAttributeDefinitionId;

IF @ExistingId IS NOT NULL
BEGIN
    UPDATE Location.LocationAttribute
    SET AttributeValue = @AttributeValue,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedByUserId = @AppUserId
    WHERE Id = @ExistingId;
END
ELSE
BEGIN
    INSERT INTO Location.LocationAttribute
        (LocationId, LocationAttributeDefinitionId, AttributeValue, CreatedAt)
    VALUES
        (@LocationId, @LocationAttributeDefinitionId, @AttributeValue, SYSUTCDATETIME());
END
```

- [ ] **Step 3: Write `Location.LocationAttribute_Clear`**

Deletes the attribute value row. Rejects if `IsRequired = 1` on the attribute definition. This is a rare hard DELETE — attribute values are not soft-deleted (they're re-settable, and the LocationAttribute table is a value store, not an auditable entity with its own lifecycle).

Actually, looking at the phased plan more carefully: the plan says "Remove value; rejects if `IsRequired`". Since LocationAttribute has no `DeprecatedAt`, this is a genuine DELETE (or we set value to NULL — but the column is NOT NULL). Use DELETE and audit the removal.

- [ ] **Step 4: Write the test file**

Test scenarios:
- Set an attribute on a DieCastMachine location (e.g., Tonnage=350) → verify inserted
- Set the same attribute again with a different value → verify updated (upsert)
- GetByLocation → verify returns the attribute with definition metadata
- Clear a non-required attribute → verify deleted
- Clear a required attribute → rejected
- Set an attribute from a WRONG definition → rejected (cross-definition check)
- Verify audit entries

- [ ] **Step 5: Run tests, commit**

```powershell
.\Run-Tests.ps1 -Filter "Location"
```

```bash
git add sql/migrations/repeatable/R__Location_LocationAttribute_*.sql sql/tests/0003_Location/040_LocationAttribute_crud.sql
git commit -m "feat(phase2): LocationAttribute Set/GetByLocation/Clear procs + tests"
```

---

## Task 10: Full Reset + Full Test Run + Final Verification

- [ ] **Step 1: Full reset and test run**

```powershell
cd C:\Users\JacquesPotgieter\documents\dev\mpp\sql\tests
.\Run-Tests.ps1
```

Expected: ALL tests pass (Phase 1 tests if any exist, plus all Phase 2 tests).

- [ ] **Step 2: Verify table counts**

```powershell
sqlcmd -S localhost -d MPP_MES_Dev -C -W -Q "
SELECT s.name AS [Schema], t.name AS [Table], p.rows AS [Rows]
FROM sys.tables t
INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
INNER JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE s.name != 'dbo'
ORDER BY s.name, t.name;"
```

Expected: Location schema has 6 tables (AppUser + 5 new), audit tables from Phase 1, seed data counts match expectations.

- [ ] **Step 3: Verify proc count**

```powershell
sqlcmd -S localhost -d MPP_MES_Dev -C -W -Q "
SELECT SCHEMA_NAME(schema_id) AS [Schema], COUNT(*) AS ProcCount
FROM sys.procedures
WHERE schema_id != SCHEMA_ID('dbo') AND schema_id != SCHEMA_ID('test')
GROUP BY SCHEMA_NAME(schema_id)
ORDER BY [Schema];"
```

Expected: `Audit` = 10 procs (4 infra + 6 readers), `Location` = ~30 procs (8 AppUser + ~22 new Phase 2).

- [ ] **Step 4: Verify migration history**

```powershell
sqlcmd -S localhost -d MPP_MES_Dev -C -W -Q "SELECT MigrationId, AppliedAt, Description FROM dbo.SchemaVersion ORDER BY AppliedAt;"
```

Expected: 2 migrations listed.

- [ ] **Step 5: Final commit (if any cleanup was needed)**

```bash
git add -A
git status
# Only commit if there are actual changes
git commit -m "feat(phase2): Phase 2 complete — Plant Model & Location Schema"
```

---

## Summary: Deliverables Checklist

| # | Deliverable | Files |
|---|---|---|
| 1 | Migration 0002 | `0002_plant_model_location_schema.sql` |
| 2 | Seed script | `S001_location_seed_data.sql` |
| 3 | LocationType (2 read procs) | `R__Location_LocationType_List.sql`, `_Get.sql` |
| 4 | LocationTypeDefinition (5 CRUD procs) | `_List`, `_Get`, `_Create`, `_Update`, `_Deprecate` |
| 5 | LocationAttributeDefinition (7 procs) | `_ListByDefinition`, `_Get`, `_Create`, `_Update`, `_MoveUp`, `_MoveDown`, `_Deprecate` |
| 6 | Location (10 procs) | `_List`, `_Get`, `_GetTree`, `_GetAncestors`, `_GetDescendantsOfType`, `_Create`, `_Update`, `_MoveUp`, `_MoveDown`, `_Deprecate` |
| 7 | LocationAttribute (3 procs) | `_GetByLocation`, `_Set`, `_Clear` |
| 8 | Tests (7 files) | 3 in `0002_LocationType/`, 4 in `0003_Location/` |

**Total: 1 migration + 1 seed + 27 procs + 7 test files = 36 SQL files**

---

## NOT in this plan (deferred)

- **Machine bulk seed loading from CSV** — The 209 machines from `reference/seed_data/machines.csv` require a mapping layer (MachDesc → LocationTypeDefinition, DeptDesc → parent Area). This is better done as a separate task after the procs are proven, either as a seed script or a one-time Gateway script.
- **Perspective frontend views** — Plant Hierarchy Browser, Location Details Panel, etc. are UI work for after the SQL layer is complete.
- **LocationAttribute_BulkLoadMachinesFromSeed** proc — listed in the phased plan but depends on the CSV mapping logic above.
