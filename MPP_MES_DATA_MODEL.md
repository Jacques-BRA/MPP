# MPP MES — Data Model Reference

**Version:** Working draft
**Schemas:** 7 | **Tables:** ~50
**Target:** Microsoft SQL Server 2022 Standard Edition

---

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 0.1 | 2026-04-02 | Blue Ridge Automation | Initial data model — 7 schemas, ~50 tables |
| 0.2 | 2026-04-09 | Blue Ridge Automation | Eliminated `Terminal` table — terminals are now `Location` records (type=Terminal) with config as `LocationAttribute`. Renamed `TerminalId` FKs to `TerminalLocationId` across all event tables. Added `ShotCount` to `DowntimeEvent` for warm-up tracking (UJ-14). Added hardware interlock bypass flag discussion on `ContainerSerial` (UJ-16). Updated workorder schema scope to MVP-LITE (OI-07). |
| 0.3 | 2026-04-09 | Blue Ridge Automation | Naming convention changed from snake_case to UpperCamelCase for all DB identifiers. Merged Department into Area per ISA-95 — `DepartmentLocationId` FKs renamed to `AreaLocationId`, `ChargeToDepartment` renamed to `ChargeToArea`. Added Enterprise (level 0) to `LocationType`. Updated `LocationType` seed rows. |
| 0.4 | 2026-04-10 | Blue Ridge Automation | Major restructure of location schema: `LocationType` reduced to 5 ISA-95 tiers (Enterprise, Site, Area, WorkCenter, Cell). `LocationTypeDefinition` repurposed from "attribute definitions" to "polymorphic kinds" (Terminal, DieCastMachine, CNCMachine, etc. — all under Cell). New `LocationAttributeDefinition` table holds attribute schemas per kind. `Location.LocationTypeId` replaced by `Location.LocationTypeDefinitionId`. `LocationAttribute.LocationTypeDefinitionId` renamed to `LocationAttributeDefinitionId`. Added seed data tables for LocationType, LocationTypeDefinition, and sample LocationAttributeDefinition sets. |
| 0.4.1 | 2026-04-10 | Blue Ridge Automation | Consistency pass: normalized terminal FK columns on append-only Lot event tables (LotGenealogy, LotStatusHistory, LotMovement, LotAttributeChange) to `TerminalLocationId` — were previously `EventTerminalId` / `ChangedAtTerminalId` / `MovedAtTerminalId`. Fixed stale UPPER_CASE code values in column descriptions (Split/Merge/Consumption, Good/Hold/Scrap/Closed, Open/Complete/Shipped/Hold/Void, Manufactured/Received/ReceivedOffsite, Initial/ReprintDamaged/Split/Merge/SortCageReIdentify, UseAsIs/Rework/etc.). Fixed snake_case in UJ-14 warm-up note and UJ-16 interlock bypass note. |
| 0.5 | 2026-04-10 | Blue Ridge Automation | Added `Audit.FailureLog` table to track attempted-but-rejected stored procedure calls (parameter validation failures, business-rule violations, caught exceptions). Complements ConfigLog/OperationLog which track successful mutations. 4 indexes defined (AttemptedAt, AppUser, EntityEvent, ProcedureName). Written by the new `Audit_LogFailure` shared proc from every validation-failure path and every CATCH handler in mutating procs. |
| 0.5.1 | 2026-04-13 | Blue Ridge Automation | Added `SortOrder INT NOT NULL DEFAULT 0` column to `Location.Location` table for display ordering among siblings. Auto-incremented on creation, updated via MoveUp/MoveDown operations. |
| 0.6 | 2026-04-13 | Blue Ridge Automation | **Data type standardization across all ~51 tables.** All primary keys changed from `INT` to `BIGINT IDENTITY`. All foreign keys changed from `INT` to `BIGINT` to match. All `VARCHAR(N)` columns changed to `NVARCHAR(N)` (Unicode support for Honda EDI data). Audit `EntityId` columns (OperationLog, ConfigLog, FailureLog) changed to `BIGINT` to match arbitrary PK references. Non-PK/FK value columns (SortOrder, SequenceNumber, PieceCount, VersionNumber, counts, quantities) remain `INT`. `BIT`, `DECIMAL`, and `DATETIME2(3)` columns unchanged. ERD updated to match. |
| 1.1 | 2026-04-14 | Blue Ridge Automation | **OperationTemplate versioning — schema change.** Added `VersionNumber INT NOT NULL DEFAULT 1` to `Parts.OperationTemplate`; changed `UNIQUE (Code)` → `UNIQUE (Code, VersionNumber)`. Supports the clone-to-modify workflow: `_CreateNewVersion` inserts a new row sharing the Code with `VersionNumber = MAX(siblings)+1`, copies the parent's `OperationTemplateField` rows, and historical `RouteStep` rows continue pointing at the parent's Id so production traceability is preserved. Mirrors the versioning pattern already used by `RouteTemplate` and (later) `Bom` / `QualitySpec`. Schema plumbing delivered as part of Phase 5 — see Phased Plan v1.3. |
| 1.6 | 2026-04-21 | Blue Ridge Automation | **AppUser schema realigned to the initials-based security model (OI-06 closed — Phase C of the 2026-04-20 OI review refactor).** `AppUser` now carries `Initials NVARCHAR(10) NOT NULL UNIQUE` as its universal shop-floor stamp. `AdAccount` becomes NULL-capable (filtered UNIQUE where NOT NULL) so Operator-class rows can exist without an AD identity. Added CHECK constraint `IgnitionRole IS NULL OR AdAccount IS NOT NULL`. `ClockNumber` and `PinHash` columns marked legacy — they remain in the Phase 1–8 live schema but will be dropped in the Phase G Tool & Security migration, along with the `AppUser_SetPin` and `AppUser_GetByClockNumber` procs. No changes to event tables — user attribution via `AppUserId` FK already resolves transparently from initials at the UI layer. |
| 1.5 | 2026-04-15 | Blue Ridge Automation | **Phase 8 Oee reference tables built.** Migration `0009_phase8_oee_reference.sql` creates `Oee.DowntimeReasonType` (6 seeded rows, read-only), `Oee.DowntimeReasonCode` (mutable, FK to Area Location + nullable ReasonType + nullable SourceCode), `Oee.ShiftSchedule` (mutable, `DaysOfWeekBitmask INT` with Mon=1…Sun=64 and CHECK 1-127, `TIME(0)` start/end), and `Oee.Shift` (runtime instances). +1 `Audit.LogEntityType` row (ShiftSchedule at Id=30). 13 new procs including a JSON-fed `DowntimeReasonCode_BulkLoadFromSeed` that maps CSV `DeptCode` (DC/MS/TS) to three caller-supplied Area Location Ids and generates unique `Code` as `{DeptCode}-{NNNN}` from zero-padded `ReasonId`. Dev seed updated with Trim Shop Area row. 779/779 tests passing. |
| 1.4 | 2026-04-15 | Blue Ridge Automation | **Production data collection capture — closing the template→event gap.** `OperationTemplate` + `OperationTemplateField` + `DataCollectionField` define *what* to collect at an operation, but nothing persisted *what was actually collected* when a LOT passed through. Fixed by extending `Workorder.ProductionEvent` and adding a new child table: (1) added `OperationTemplateId BIGINT FK → Parts.OperationTemplate NOT NULL` to tie each event to the template it executed under (previously only inferable via WorkOrderOperation→RouteStep, which is unreliable given OI-07's background-only work orders); (2) added hot typed columns `DieIdentifier NVARCHAR(50) NULL` (die name/number captured from the machine's `LocationAttribute` value at event time — NOT an FK to Location; OI-10 tool life may later add a parallel `DieId BIGINT FK` if a `Die` table is introduced), `CavityNumber INT NULL`, `WeightValue DECIMAL(10,3) NULL`, `WeightUomId BIGINT FK → Parts.Uom NULL`; (3) new `Workorder.ProductionEventValue` child keyed by `(ProductionEventId, DataCollectionFieldId)` with `Value NVARCHAR(255)` + `NumericValue DECIMAL(18,4) NULL` for any field not promoted to a hot column (extensible vocabulary path). UI behavior: the die-cast screen reads `OperationTemplateField` to render the required inputs; submit writes one `ProductionEvent` header + N `ProductionEventValue` children. Phase 8 procs to implement. |
| 1.3 | 2026-04-14 | Blue Ridge Automation | **Phase 6 BOM Management built + Phase 5 Draft/Published retrofit.** Migration `0007_bom_and_route_publish.sql` creates `Parts.Bom` (versioned, Draft/Published/Deprecated states via `PublishedAt DATETIME2(3) NULL` + existing `DeprecatedAt`) and `Parts.BomLine` (no soft-delete — hard DELETE with SortOrder compaction; filtered unique index `UQ_BomLine_Bom_ChildItem` prevents duplicate child references in one BOM). Same migration ALTERs `Parts.RouteTemplate` to add `PublishedAt DATETIME2(3) NULL` — retroactive three-state model for Phase 5. Drafts are mutable but invisible to production; `_GetActiveForItem` procs filter `PublishedAt IS NOT NULL`. Published rows are immutable — BomLine/RouteStep mutations reject on published parents. New procs: `Bom_{Publish, ListByParentItem, Get, GetActiveForItem, Create, CreateNewVersion, Deprecate, WhereUsedByChildItem}` (8), `BomLine_{Add, Update, MoveUp, MoveDown, Remove, ListByBom}` (6), `RouteTemplate_Publish` (1) = 15 new procs. Phase 5 retrofit also updated 5 RouteStep mutation procs to reject on published parents. Audit.LogEntityType +1 (BomLine at Id=27). Audit.FailureLog_GetTopReasons enhanced with optional `@ProcedureName` filter (legitimate production feature + test-noise mitigation). 2 new test files + 1 updated (Phase 5), ~100 new assertions. Full suite now 737/737. |
| 1.2 | 2026-04-14 | Blue Ridge Automation | **Phase 5 Process Definition built and tested.** Migration `0006_routes_operations_eligibility.sql` creates 5 tables: `Parts.OperationTemplate` (versioned, clone-to-modify), `Parts.OperationTemplateField`, `Parts.RouteTemplate` (versioned per Item), `Parts.RouteStep` (no soft-delete — hard DELETE scoped to un-deprecated parent routes; production history preserved via the immutable route snapshot), `Parts.ItemLocation` (eligibility junction with active/deprecated toggle). Filtered unique indexes enforce active-set semantics: `UQ_OperationTemplate_Code_Version`, `UQ_OperationTemplateField_ActiveTemplateField`, `UQ_RouteTemplate_Item_Version`, `UQ_ItemLocation_ActiveItemLocation`. 21 new stored procedures: OperationTemplate ×5 + OperationTemplateField ×3 + RouteTemplate ×5 + RouteStep ×6 + ItemLocation ×4 (ListByItem/Add + reactivate/ListByLocation/Remove). 3 new test files, ~145 new assertions. Full suite now 637/637 passing. One test correctness fix along the way: historical-AsOfDate test needed v1.EffectiveFrom backdated so the AsOf window actually catches v1 (Create and CreateNewVersion ran milliseconds apart in test). |
| 1.0 | 2026-04-14 | Blue Ridge Automation | **Phase 4 Item Master + Container Config built and tested.** Migration `0005_item_master_container_config.sql` creates `Parts.Item` with full user attribution (`CreatedAt`, `UpdatedAt`, `CreatedByUserId FK`, `UpdatedByUserId FK`) and `Parts.ContainerConfig` with Honda packing rules plus the OI-02 columns `ClosureMethod NVARCHAR(20) NULL` and `TargetWeight DECIMAL(10,4) NULL` added proactively as nullable pending MPP customer validation of scale-driven container closure. Filtered unique index `UQ_ContainerConfig_ActiveItemId` enforces one active config per Item at the schema level. 10 new stored procedures (6 Item + 4 ContainerConfig), ~80 new tests. Bulk-load proc deferred — will be written once MPP supplies a parts-list export format. Also fixed `Parts.Uom_Deprecate` column reference bug (was checking `DefaultUomId`, corrected to `UomId OR WeightUomId`). Full suite now 509/509 passing. |
| 0.9 | 2026-04-13 | Blue Ridge Automation | **Phase 3 reference lookups built and tested.** Migration `0004_phase3_reference_lookups.sql` creates 16 code tables across 5 schemas: `Lots.LotOriginType`, `Lots.LotStatusCode` (with `BlocksProduction` flag), `Lots.ContainerStatusCode`, `Lots.GenealogyRelationshipType`, `Lots.PrintReasonCode`, `Lots.LabelTypeCode`, `Quality.InspectionResultCode`, `Quality.SampleTriggerCode`, `Quality.HoldTypeCode`, `Quality.DispositionCode`, `Oee.DowntimeSourceCode`, `Workorder.OperationStatus`, `Workorder.WorkOrderStatus`, `Parts.Uom`, `Parts.ItemType`, `Parts.DataCollectionField`. Read-only tables (13) carry just `{Id, Code, Name}` (+ `BlocksProduction` on LotStatusCode). Mutable tables (3) carry `{Id, Code, Name, Description, CreatedAt, DeprecatedAt}`. All seeded with deterministic Ids. `Workorder.WorkOrderStatus` seed values were PascalCased (Created/InProgress/Completed/Cancelled — the data model had stale UPPER_SNAKE_CASE). `Lots.LabelTypeCode` values were proposed from Honda shipping conventions (Primary/Container/Master/Void) as the data model didn't enumerate them. Added 2 new `Audit.LogEntityType` rows (Uom, ItemType). 41 new stored procedures (26 read-only List/Get + 15 mutable CRUD). 117 new tests (440 total now passing). |
| 0.8 | 2026-04-13 | Blue Ridge Automation | Added `Icon NVARCHAR(100) NULL` column to `LocationTypeDefinition` for Perspective Tree component icon mapping. Values are intentionally left NULL at deployment — they'll be populated via the Config Tool once the `LocationTypeDefinition` CRUD frontend is built. The Jython tree builder falls back to a default icon when NULL. Added seed script (`sql/seeds/seed_locations.sql`) with 12 Location rows spanning all 5 ISA-95 tiers for dev/test. |
| 0.7 | 2026-04-13 | Blue Ridge Automation | **Architectural refactor — 4 changes for polymorphism, consistency, and template portability.** (1) **Free-text enums → code tables:** Added 7 new code tables (`Lots.PrintReasonCode`, `Lots.LabelTypeCode`, `Quality.InspectionResultCode`, `Quality.SampleTriggerCode`, `Quality.HoldTypeCode`, `Quality.DispositionCode`, `Oee.DowntimeSourceCode`) and replaced corresponding `NVARCHAR` columns with `BIGINT FK` references on `LotLabel`, `ShippingLabel`, `QualitySample`, `NonConformance`, `DowntimeEvent`. (2) **CreatedBy/UpdatedBy → FK:** Replaced 8 free-text `NVARCHAR` user-attribution columns with `BIGINT FK → AppUser.Id` across `Item`, `Bom`, `RouteTemplate`, `QualitySpecVersion`, `LocationAttribute`, `QualityAttachment`, `NonConformance`, `Lot`, `ShippingLabel`. (3) **HoldEvent refactored:** Retained as a single table (same place/release lifecycle as `DowntimeEvent`). Replaced free-text `HoldType NVARCHAR` with `HoldTypeCodeId BIGINT FK → HoldTypeCode.Id`. (4) **OperationTemplate data collection configurable:** Removed 7 hardcoded `BIT` flags, added `Parts.DataCollectionField` code table and `Parts.OperationTemplateField` junction with `IsRequired` and `DeprecatedAt`. Net: +11 new tables, −1 removed (`HoldEvent`), ~60 tables total. Conventions updated: enum/status code-table rule broadened, user-attribution convention added. ERD and Phased Plan updated to match. |

---

## Conventions

- `UpperCamelCase` singular noun table and column names (e.g., `LocationType`, `PieceCount`, `CreatedAt`)
- Surrogate `BIGINT Id` primary keys (auto-increment) — natural keys are unique-indexed columns
- `DeprecatedAt DATETIME2(3) NULL` for soft deletes (non-null = inactive)
- `DATETIME2(3)` for all timestamps (millisecond precision)
- `DECIMAL(x,y)` for measurements — never `FLOAT`
- UOM as an explicit column on every quantitative field
- All enum and status values are code-table backed with FK — no free-text enums, no magic integers
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy` on mutable entities
- Append-only tables (events, movements, logs) have `CreatedAt` only — no updates
- User attribution via `BIGINT FK → AppUser.Id` — never free-text username strings

---

## 1. Location Schema — `MVP`

> **Scope:** All tables MVP. Foundation schema — every other schema references location.

Self-referential ISA-95 plant hierarchy with a three-tier classification model: **Type** (ISA-95 tier) → **Definition** (polymorphic kind within a tier) → **Attribute** (configurable metadata per kind).

### Design Overview

The location model uses three classification tables to support polymorphic location kinds within each ISA-95 hierarchy tier:

1. **`LocationType`** — the broad ISA-95 category (Enterprise, Site, Area, Work Center, Cell). Five rows total. Defines the hierarchy tier.
2. **`LocationTypeDefinition`** — the specific *kind* of a location within a type. For the `Cell` type, definitions include `Terminal`, `DieCastMachine`, `CNCMachine`, `InventoryLocation`, `Scale`, etc. Every location has a definition.
3. **`LocationAttributeDefinition`** — the attribute schema for a given kind. A `Terminal` definition has attributes like `IpAddress`, `DefaultPrinter`, `HasBarcodeScanner`. A `DieCastMachine` definition has `Tonnage`, `NumberOfCavities`, `RefCycleTimeSec`. Different definitions carry different attribute sets.
4. **`Location`** — an actual node in the plant model. FKs to `LocationTypeDefinition` (which determines both its type and its attribute schema) and to its parent location.
5. **`LocationAttribute`** — attribute values for a specific location, constrained by its definition's attribute schema.

**Analogy:** If `LocationType` is "Writing Implements," then `LocationTypeDefinition` rows are "Pen," "Pencil," "Marker" — each with their own attributes. A specific "Bic ballpoint, black" is a `Location` of definition "Pen."

### LocationType

The five ISA-95 equipment hierarchy tiers. Seeded at deployment; not operator-editable.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Short code (Enterprise, Site, Area, WorkCenter, Cell) |
| Name | NVARCHAR(100) | NOT NULL | Display name |
| HierarchyLevel | INT | NOT NULL | 0=Enterprise, 1=Site, 2=Area, 3=WorkCenter, 4=Cell |
| Description | NVARCHAR(500) | NULL | |

**Seeded rows:**

| Code | Name | HierarchyLevel | Description |
|---|---|---|---|
| Enterprise | Enterprise | 0 | Top-level organization (MPP Inc.) |
| Site | Site | 1 | Physical plant/facility |
| Area | Area | 2 | Subdivision within a site (Die Cast, Trim Shop, Machine Shop, Production Control, Quality Control) |
| WorkCenter | Work Center | 3 | Production line or grouping of equipment (ISA-95 Work Center) |
| Cell | Cell | 4 | Individual station/unit (ISA-95 Work Unit) — machines, terminals, inventory locations, scales |

### LocationTypeDefinition

Polymorphic *kinds* within each `LocationType`. Every `Location` row references one definition, which determines both its ISA-95 tier (via `LocationTypeId`) and its attribute schema (via the attached `LocationAttributeDefinition` rows).

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LocationTypeId | BIGINT | FK → LocationType.Id, NOT NULL | Which ISA-95 tier this kind belongs to |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | Short code (e.g., Terminal, DieCastMachine) |
| Name | NVARCHAR(100) | NOT NULL | Display name |
| Description | NVARCHAR(500) | NULL | |
| Icon | NVARCHAR(100) | NULL | Perspective icon path (e.g., `material/precision_manufacturing`). Used by tree components. NULL falls back to a default. |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

**Seeded definitions (initial set — extensible):**

| LocationType | Definition Code | Purpose |
|---|---|---|
| Enterprise | Organization | The company root node (single row) |
| Site | Facility | A physical manufacturing plant |
| Area | ProductionArea | Production areas (Die Cast, Trim, Machining, Assembly) |
| Area | SupportArea | Support areas (Production Control, Quality Control, Shipping, Receiving) |
| WorkCenter | ProductionLine | Generic production line within an area |
| WorkCenter | InspectionLine | Multi-part inspection lines (e.g., MS1FM-1028) |
| Cell | Terminal | Shared operator HMI station |
| Cell | DieCastMachine | Die cast press |
| Cell | CNCMachine | Machining center / CNC cell |
| Cell | TrimPress | Trim shop press |
| Cell | AssemblyStation | Manual assembly station |
| Cell | SerializedAssemblyLine | PLC-integrated serialized assembly (5G0, etc.) |
| Cell | InspectionStation | Manual or vision-based inspection station |
| Cell | InventoryLocation | WIP storage, receiving dock, shipping dock, Sort Cage |
| Cell | Scale | OmniServer-connected weight scale |

### LocationAttributeDefinition

Attribute schema per `LocationTypeDefinition`. Each definition carries its own set of configurable attributes.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LocationTypeDefinitionId | BIGINT | FK → LocationTypeDefinition.Id, NOT NULL | Which kind this attribute belongs to |
| AttributeName | NVARCHAR(100) | NOT NULL | e.g., `Tonnage`, `IpAddress`, `DefaultPrinter` |
| DataType | NVARCHAR(50) | NOT NULL | INT, DECIMAL, BIT, VARCHAR |
| IsRequired | BIT | NOT NULL, DEFAULT 0 | Must every location of this definition carry a value? |
| DefaultValue | NVARCHAR(255) | NULL | Default if not explicitly set |
| Uom | NVARCHAR(20) | NULL | Unit of measure for this attribute |
| SortOrder | INT | NOT NULL, DEFAULT 0 | Display ordering on config screens |
| Description | NVARCHAR(500) | NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

**Example attribute sets (illustrative — not exhaustive):**

*For `Cell` → `Terminal` definition:*

| AttributeName | DataType | Required | Uom | Description |
|---|---|---|---|---|
| IpAddress | NVARCHAR | No | — | Terminal IP address for diagnostics |
| DefaultPrinter | NVARCHAR | No | — | Associated Zebra printer name for label output |
| HasBarcodeScanner | BIT | Yes | — | Whether terminal has scanner hardware |

*For `Cell` → `DieCastMachine` definition:*

| AttributeName | DataType | Required | Uom | Description |
|---|---|---|---|---|
| Tonnage | DECIMAL | No | tons | Die cast press tonnage |
| NumberOfCavities | INT | No | — | Die cast cavity count |
| RefCycleTimeSec | DECIMAL | No | seconds | Reference cycle time for OEE performance calculation |
| OeeTarget | DECIMAL | No | — | Target OEE (0.00–1.00). FUTURE — designed for but not used in MVP. |

*For `Cell` → `InventoryLocation` definition:*

| AttributeName | DataType | Required | Uom | Description |
|---|---|---|---|---|
| IsPhysical | BIT | Yes | — | Physical location vs. logical bucket |
| IsLineside | BIT | No | — | Whether this is a lineside staging area |
| MaxLotCapacity | INT | No | — | Maximum LOTs that can be stored here |

### Location

Every node in the plant model — self-referential hierarchy. Each location references a single `LocationTypeDefinition`, which determines both its ISA-95 tier and its attribute schema.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LocationTypeDefinitionId | BIGINT | FK → LocationTypeDefinition.Id, NOT NULL | Determines both ISA-95 tier (via join) and attribute schema |
| ParentLocationId | BIGINT | FK → Location.Id, NULL | Parent in hierarchy (NULL = root/Enterprise) |
| Name | NVARCHAR(200) | NOT NULL | Display name |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | Short identifier (barcode-scannable for machines) |
| Description | NVARCHAR(500) | NULL | |
| SortOrder | INT | NOT NULL, DEFAULT 0 | Display ordering among siblings. Auto-incremented on creation, updated via move-up/move-down operations. |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

> Note: `LocationType` is not stored directly on `Location`; it's derivable via `LocationTypeDefinition.LocationTypeId`. Hierarchy queries use `ParentLocationId` (adjacency list) and join through `LocationTypeDefinition` when tier-based filtering is needed.

### LocationAttribute

Actual attribute values per location, constrained by the location's definition.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LocationId | BIGINT | FK → Location.Id, NOT NULL | |
| LocationAttributeDefinitionId | BIGINT | FK → LocationAttributeDefinition.Id, NOT NULL | Which attribute (must belong to the location's definition) |
| AttributeValue | NVARCHAR(255) | NOT NULL | Stored as string, parsed per `LocationAttributeDefinition.DataType` |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| UpdatedByUserId | BIGINT | FK → AppUser.Id, NULL | |

**Integrity rule:** A `LocationAttribute.LocationAttributeDefinitionId` SHALL reference an attribute definition whose `LocationTypeDefinitionId` matches the location's `LocationTypeDefinitionId`. Enforced via application logic or trigger — no direct SQL constraint expresses this without a redundant column.

### Terminals in the New Model

> ✅ **RESOLVED — OI-08 / UJ-12:** Terminals are shared, not 1:1 with machines. Operators scan a machine barcode/QR code as the first step of any interaction.

In the polymorphic model, `Terminal` is a `LocationTypeDefinition` under the `Cell` type — it's one of many kinds of Cells. A `DieCastMachine` is another kind of Cell. Both are Cell-tier locations but carry entirely different attribute schemas.

Event tables carry two location references when both operator position and machine context matter:
- `TerminalLocationId` — FK → `Location.Id` where the definition is `Terminal` (where the operator is standing)
- `LocationId` — FK → `Location.Id` where the definition is a machine kind (which machine they scanned)

### AppUser

MES users in two classes (FDS §4):

- **Operator** rows — `AdAccount` NULL, `IgnitionRole` NULL. Identified by initials entered at a terminal; no authentication. Managed via the Configuration Tool Admin screen.
- **Interactive User** rows (Quality, Supervisor, Engineering, Admin) — `AdAccount` NOT NULL, `IgnitionRole` NOT NULL. Authenticate via Active Directory.

Roles managed in Ignition (mapped to AD groups for interactive users).

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Initials | NVARCHAR(10) | NOT NULL, UNIQUE | Shop-floor identification stamp. All classes carry this. Initials populate the Initials field on every shop-floor mutation screen. |
| AdAccount | NVARCHAR(100) | NULL, filtered UNIQUE where NOT NULL | Active Directory identity. NULL for Operator class, NOT NULL for Interactive Users. |
| DisplayName | NVARCHAR(200) | NOT NULL | |
| IgnitionRole | NVARCHAR(100) | NULL | NULL for Operator class. References Ignition's internal role config for Interactive Users. |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

**Check constraint:** `IgnitionRole IS NULL OR AdAccount IS NOT NULL` — an Operator (no AD) cannot carry an Ignition role; roles apply only to AD-backed users.

**Legacy columns to be removed in the Phase G Tool & Security migration** (Phase G of the 2026-04-20 OI review refactor): `ClockNumber NVARCHAR(20)` and `PinHash NVARCHAR(255)` are no longer used by the design. They remain in the live schema from Phases 1–8 and will be dropped alongside the related procs (`AppUser_SetPin`, `AppUser_GetByClockNumber`) when Phase G runs.

---

## 2. Parts Schema — `MVP`

> **Scope:** All tables MVP. Master data schema — items, BOMs, routes, and container configs support core LOT lifecycle and shipping.

Item master, bills of material, routes, operation templates, container configurations.

### ItemType

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Name | NVARCHAR(100) | NOT NULL | Raw Material, Component, Sub-Assembly, Finished Good, Pass-Through |
| Description | NVARCHAR(500) | NULL | |

### Uom

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(10) | NOT NULL, UNIQUE | EA, LB, KG, etc. |
| Name | NVARCHAR(50) | NOT NULL | |

### Item

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ItemTypeId | BIGINT | FK → ItemType.Id, NOT NULL | |
| PartNumber | NVARCHAR(50) | NOT NULL, UNIQUE | MPP part number |
| Description | NVARCHAR(500) | NULL | |
| MacolaPartNumber | NVARCHAR(50) | NULL | ERP cross-reference |
| DefaultSubLotQty | INT | NULL | Default pieces per sub-LOT split |
| MaxLotSize | INT | NULL | Reasonability check ceiling |
| UomId | BIGINT | FK → Uom.Id, NOT NULL | Counting UOM |
| UnitWeight | DECIMAL(10,4) | NULL | Weight per piece |
| WeightUomId | BIGINT | FK → Uom.Id, NULL | Weight UOM |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| CreatedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| UpdatedByUserId | BIGINT | FK → AppUser.Id, NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### Bom

Versioned bill of materials header. **Three-state lifecycle** via `PublishedAt` + `DeprecatedAt`: Draft (both NULL) → Published (`PublishedAt` NOT NULL) → Deprecated (`DeprecatedAt` NOT NULL). Drafts are mutable but invisible to production's `GetActiveForItem`. Published BOMs are immutable — lines can't be added/updated/moved/removed; use `_CreateNewVersion` to fork a new Draft. Same model as `RouteTemplate`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ParentItemId | BIGINT | FK → Item.Id, NOT NULL | The product this BOM is for |
| VersionNumber | INT | NOT NULL | Versioning within the (ParentItemId) family. UNIQUE(ParentItemId, VersionNumber). |
| EffectiveFrom | DATETIME2(3) | NOT NULL | When this version becomes active (gated by PublishedAt for production selection) |
| PublishedAt | DATETIME2(3) | NULL | NULL = Draft (mutable, invisible to production). Non-NULL = Published (immutable, visible). Set by `Bom_Publish`. |
| DeprecatedAt | DATETIME2(3) | NULL | Non-NULL = Retired. |
| CreatedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

### BomLine

Individual components within a BOM.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| BomId | BIGINT | FK → Bom.Id, NOT NULL | |
| ChildItemId | BIGINT | FK → Item.Id, NOT NULL | Component part |
| QtyPer | DECIMAL(10,4) | NOT NULL | Quantity per parent |
| UomId | BIGINT | FK → Uom.Id, NOT NULL | |
| SortOrder | INT | NOT NULL, DEFAULT 0 | |

### RouteTemplate

Versioned manufacturing route for a product. **Three-state lifecycle** via `PublishedAt` + `DeprecatedAt` (same pattern as `Bom`): Draft → Published → Deprecated. Drafts are mutable (RouteSteps can be added/updated/moved/removed) but invisible to production. Published routes are immutable.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ItemId | BIGINT | FK → Item.Id, NOT NULL | |
| VersionNumber | INT | NOT NULL | UNIQUE(ItemId, VersionNumber). |
| Name | NVARCHAR(200) | NOT NULL | |
| EffectiveFrom | DATETIME2(3) | NOT NULL | |
| PublishedAt | DATETIME2(3) | NULL | NULL = Draft. Non-NULL = Published (immutable). Set by `RouteTemplate_Publish`. |
| DeprecatedAt | DATETIME2(3) | NULL | |
| CreatedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

### RouteStep

Ordered steps within a route.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| RouteTemplateId | BIGINT | FK → RouteTemplate.Id, NOT NULL | |
| OperationTemplateId | BIGINT | FK → OperationTemplate.Id, NOT NULL | What happens at this step |
| SequenceNumber | INT | NOT NULL | Execution order |
| IsRequired | BIT | NOT NULL, DEFAULT 1 | |
| Description | NVARCHAR(500) | NULL | |

### OperationTemplate

Defines what data to collect at a type of operation. Reusable across products. **Versioned** via `Code` + `VersionNumber` — multiple rows share a Code to represent the evolution of one operation over time. See the clone-to-modify workflow in the Phase 5 `_CreateNewVersion` proc.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL | Operation family code (e.g., DIE-CAST-801T). Multiple rows may share this value across versions. |
| VersionNumber | INT | NOT NULL, DEFAULT 1 | Version within the Code family. UNIQUE(Code, VersionNumber) enforces one row per version. |
| Name | NVARCHAR(100) | NOT NULL | |
| AreaLocationId | BIGINT | FK → Location.Id, NOT NULL | Area (ISA-95 Area, organizational grouping) |
| Description | NVARCHAR(500) | NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### DataCollectionField

Extensible vocabulary of data collection capabilities. Seeded with initial set, extensible by engineering.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | MaterialVerification, SerialNumber, DieInfo, CavityInfo, Weight, GoodCount, BadCount |
| Name | NVARCHAR(100) | NOT NULL | |
| Description | NVARCHAR(500) | NULL | |

### OperationTemplateField

Junction: which data collection fields an operation template requires. Replaces the former hardcoded BIT flags on `OperationTemplate`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| OperationTemplateId | BIGINT | FK → OperationTemplate.Id, NOT NULL | |
| DataCollectionFieldId | BIGINT | FK → DataCollectionField.Id, NOT NULL | |
| IsRequired | BIT | NOT NULL, DEFAULT 1 | Whether this field is mandatory or optional for this operation |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### ItemLocation

Part-to-location eligibility (which parts can run on which machines).

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ItemId | BIGINT | FK → Item.Id, NOT NULL | |
| LocationId | BIGINT | FK → Location.Id, NOT NULL | Machine or work cell |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### ContainerConfig

Honda-specified packing rules per product.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ItemId | BIGINT | FK → Item.Id, NOT NULL | |
| TraysPerContainer | INT | NOT NULL | |
| PartsPerTray | INT | NOT NULL | |
| IsSerialized | BIT | NOT NULL, DEFAULT 0 | |
| DunnageCode | NVARCHAR(50) | NULL | Returnable dunnage identifier |
| CustomerCode | NVARCHAR(50) | NULL | Honda customer code |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### ⚠ Known Gap: Tool Life Tracking

> **Scope Matrix row 26** lists Tool Life as **Included** (FRS 5.6.6), but no dedicated table exists in the current data model. Options to address:
> 1. **`LocationAttribute`** — track tool shot counts and replacement thresholds as configurable attributes on Machine-type locations (leverages existing infrastructure)
> 2. **Dedicated `ToolLife` table** — if tool life requires its own event history (install date, shot count, replacement events), a purpose-built table in the `Parts` or `Oee` schema would be cleaner
>
> **Recommendation:** Gather requirements from MPP on what Tool Life tracking means operationally before deciding. If it's just "alert when shot count exceeds threshold," option 1 suffices. If it needs history and replacement workflows, option 2 is needed.

---

## 3. Lots Schema — `MVP`

> **Scope:** All tables MVP. Core tracking entity schema. Serialization is MVP-EXPANDED (expanded beyond legacy two-line support).
>
> **Note on pass-through parts:** Receiving pass-through parts into MES is MVP (Scope Matrix row 3) — supported via `LotOriginType` Received/ReceivedOffsite. Full in-plant pass-through tracking workflows are noted as Future (Scope Matrix row 20). The existing `Lot` + `LotMovement` tables handle both; the future work is operational workflow design, not schema.

LOT lifecycle, genealogy, containers, serialized parts, shipping.

### LotOriginType

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(30) | NOT NULL, UNIQUE | Manufactured, Received, ReceivedOffsite |
| Name | NVARCHAR(100) | NOT NULL | |

### LotStatusCode

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Good, Hold, Scrap, Closed |
| Name | NVARCHAR(100) | NOT NULL | |
| BlocksProduction | BIT | NOT NULL, DEFAULT 0 | Hold = true, drives interlocks |

### GenealogyRelationshipType

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Split, Merge, Consumption |
| Name | NVARCHAR(100) | NOT NULL | |

### Lot

The central tracking entity.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LotName | NVARCHAR(50) | NOT NULL, UNIQUE | The LTT barcode number |
| ItemId | BIGINT | FK → Item.Id, NOT NULL | |
| LotOriginTypeId | BIGINT | FK → LotOriginType.Id, NOT NULL | How it entered MES |
| LotStatusId | BIGINT | FK → LotStatusCode.Id, NOT NULL | Current quality status |
| PieceCount | INT | NOT NULL | Current count |
| MaxPieceCount | INT | NULL | Reasonability ceiling |
| Weight | DECIMAL(12,4) | NULL | |
| WeightUomId | BIGINT | FK → Uom.Id, NULL | |
| DieNumber | NVARCHAR(50) | NULL | Die cast LOTs only |
| CavityNumber | NVARCHAR(50) | NULL | Die cast LOTs only |
| VendorLotNumber | NVARCHAR(100) | NULL | Received LOTs only |
| MinSerialNumber | INT | NULL | Vendor serial range (received bulk parts) |
| MaxSerialNumber | INT | NULL | |
| ParentLotId | BIGINT | FK → Lot.Id, NULL | Adjacency list link for sub-LOTs |
| CurrentLocationId | BIGINT | FK → Location.Id, NOT NULL | Where this LOT is now |
| CreatedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| CreatedAtTerminalId | BIGINT | FK → Location.Id (Terminal), NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| UpdatedByUserId | BIGINT | FK → AppUser.Id, NULL | |

### LotGenealogy

Edge table for the genealogy graph. Adjacency list supporting recursive CTE traversal.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ParentLotId | BIGINT | FK → Lot.Id, NOT NULL | |
| ChildLotId | BIGINT | FK → Lot.Id, NOT NULL | |
| RelationshipTypeId | BIGINT | FK → GenealogyRelationshipType.Id, NOT NULL | Split, Merge, Consumption |
| PieceCount | INT | NULL | Pieces transferred in this relationship |
| EventUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | BIGINT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| EventAt | DATETIME2(3) | NOT NULL | |

### LotStatusHistory

Immutable log of every status transition.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LotId | BIGINT | FK → Lot.Id, NOT NULL | |
| OldStatusId | BIGINT | FK → LotStatusCode.Id, NOT NULL | |
| NewStatusId | BIGINT | FK → LotStatusCode.Id, NOT NULL | |
| Reason | NVARCHAR(500) | NULL | |
| ChangedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | BIGINT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| ChangedAt | DATETIME2(3) | NOT NULL | |

### LotMovement

Append-only location change log.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LotId | BIGINT | FK → Lot.Id, NOT NULL | |
| FromLocationId | BIGINT | FK → Location.Id, NULL | NULL on first placement |
| ToLocationId | BIGINT | FK → Location.Id, NOT NULL | |
| MovedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | BIGINT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| MovedAt | DATETIME2(3) | NOT NULL | |

### LotAttributeChange

Audit log for attribute modifications.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LotId | BIGINT | FK → Lot.Id, NOT NULL | |
| AttributeName | NVARCHAR(100) | NOT NULL | e.g., PieceCount, Weight |
| OldValue | NVARCHAR(255) | NULL | |
| NewValue | NVARCHAR(255) | NOT NULL | |
| ChangedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | BIGINT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| ChangedAt | DATETIME2(3) | NOT NULL | |

### PrintReasonCode

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | Initial, ReprintDamaged, Split, Merge, SortCageReIdentify |
| Name | NVARCHAR(100) | NOT NULL | |

### LabelTypeCode

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | |
| Name | NVARCHAR(100) | NOT NULL | |

### LotLabel

LTT barcode label print/reprint tracking.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LotId | BIGINT | FK → Lot.Id, NOT NULL | |
| PrintReasonCodeId | BIGINT | FK → PrintReasonCode.Id, NOT NULL | Why this label was printed |
| ZplContent | NVARCHAR(MAX) | NULL | Full ZPL payload |
| PrinterName | NVARCHAR(100) | NULL | |
| PrintedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | BIGINT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| PrintedAt | DATETIME2(3) | NOT NULL | |

### ContainerStatusCode

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Open, Complete, Shipped, Hold, Void |
| Name | NVARCHAR(100) | NOT NULL | |

### Container

Shipping containers for finished goods.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ContainerName | NVARCHAR(50) | NOT NULL, UNIQUE | |
| ItemId | BIGINT | FK → Item.Id, NOT NULL | |
| ContainerConfigId | BIGINT | FK → ContainerConfig.Id, NULL | |
| ContainerStatusId | BIGINT | FK → ContainerStatusCode.Id, NOT NULL | |
| LotId | BIGINT | FK → Lot.Id, NULL | Source LOT |
| CurrentLocationId | BIGINT | FK → Location.Id, NOT NULL | |
| AimShipperId | NVARCHAR(50) | NULL | From AIM system |
| HoldNumber | NVARCHAR(50) | NULL | Sort Cage hold reference |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |

### ContainerTray

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ContainerId | BIGINT | FK → Container.Id, NOT NULL | |
| TrayNumber | INT | NOT NULL | |
| PieceCount | INT | NOT NULL | |

### SerializedPart

Individual laser-etched serial numbers.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| SerialNumber | NVARCHAR(50) | NOT NULL, UNIQUE | |
| ItemId | BIGINT | FK → Item.Id, NOT NULL | |
| LotId | BIGINT | FK → Lot.Id, NOT NULL | Source LOT |
| ContainerId | BIGINT | FK → Container.Id, NULL | Current container |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

### ContainerSerial

Junction: serial numbers in container tray positions.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ContainerId | BIGINT | FK → Container.Id, NOT NULL | |
| ContainerTrayId | BIGINT | FK → ContainerTray.Id, NULL | |
| SerializedPartId | BIGINT | FK → SerializedPart.Id, NOT NULL | |
| TrayPosition | INT | NULL | Position within tray |

> 🔶 **PENDING INTERNAL REVIEW — UJ-16:** When `HardwareInterlockEnable=false`, parts enter containers without MES serial validation. A flag is needed to record that interlock was bypassed and serial validation was skipped. Two options under discussion:
>
> **(a)** Add `HardwareInterlockBypassed BIT DEFAULT 0` to `ContainerSerial` — marks the specific serial-to-container assignment that skipped validation.
>
> **(b)** Add `HardwareInterlockBypassed BIT DEFAULT 0` to `ProductionEvent` — marks the broader production event as having occurred without interlock.
>
> The circumstances under which MPP bypasses the interlock are not yet understood. Both options are presented for discussion with Ben. The flag may belong on both tables if bypass affects traceability at both levels.

### ShippingLabel

Container shipping label print/void history.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ContainerId | BIGINT | FK → Container.Id, NOT NULL | |
| AimShipperId | NVARCHAR(50) | NOT NULL | From AIM |
| LabelTypeCodeId | BIGINT | FK → LabelTypeCode.Id, NOT NULL | |
| ZplContent | NVARCHAR(MAX) | NULL | Full ZPL payload |
| IsVoid | BIT | NOT NULL, DEFAULT 0 | |
| PrintedAt | DATETIME2(3) | NULL | |
| VoidedAt | DATETIME2(3) | NULL | |
| PrintedByUserId | BIGINT | FK → AppUser.Id, NULL | |

---

## 4. Workorder Schema — MIXED SCOPE

> **Scope:**
> - `WorkOrder`, `WorkOrderStatus`, `WorkOrderOperation`, `OperationStatus` — **MVP-LITE** (auto-generated, invisible to operators, no WO screens — per OI-07 resolution)
> - `ProductionEvent`, `ConsumptionEvent`, `RejectEvent` — **MVP** (Production Data Acquisition is included and expanded)
>
> 🔶 **PENDING CUSTOMER VALIDATION — OI-07:** Work orders are included as invisible bookkeeping (auto-generated behind the scenes). Operators never see or interact with WOs. All WO tables are populated but no WO-specific Perspective screens are built. Production events function independently via nullable `WorkOrderOperationId` FKs.
>
> Production events have nullable FKs to `WorkOrderOperation`, allowing them to function independently even if the work order capability is deferred.

Internal work order context, production events, consumption tracking.

### WorkOrderStatus

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | CREATED, IN_PROGRESS, COMPLETED, CANCELLED |
| Name | NVARCHAR(100) | NOT NULL | |

### OperationStatus

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Pending, IN_PROGRESS, COMPLETED, SKIPPED |
| Name | NVARCHAR(100) | NOT NULL | |

### WorkOrder

Auto-generated internal work order. Operators never see this.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| WoNumber | NVARCHAR(50) | NOT NULL, UNIQUE | System-generated |
| ItemId | BIGINT | FK → Item.Id, NOT NULL | |
| RouteTemplateId | BIGINT | FK → RouteTemplate.Id, NOT NULL | The route version active at creation |
| WorkOrderStatusId | BIGINT | FK → WorkOrderStatus.Id, NOT NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| CompletedAt | DATETIME2(3) | NULL | |

### WorkOrderOperation

Individual operation execution — the actual step that happened.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| WorkOrderId | BIGINT | FK → WorkOrder.Id, NOT NULL | |
| RouteStepId | BIGINT | FK → RouteStep.Id, NOT NULL | The planned step |
| LocationId | BIGINT | FK → Location.Id, NULL | Where it actually ran |
| OperationStatusId | BIGINT | FK → OperationStatus.Id, NOT NULL | |
| SequenceNumber | INT | NOT NULL | |
| StartedAt | DATETIME2(3) | NULL | |
| CompletedAt | DATETIME2(3) | NULL | |
| OperatorId | BIGINT | FK → AppUser.Id, NULL | |

### ProductionEvent

Immutable record of production output and of the data collection required by the operation template. One row per LOT-passes-through-operation. Hot data collection fields (die, cavity, weight, counts) are typed columns on this table; any additional `DataCollectionField` configured on the operation template is captured in child `ProductionEventValue` rows.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| WorkOrderOperationId | BIGINT | FK → WorkOrderOperation.Id, NULL | |
| OperationTemplateId | BIGINT | FK → Parts.OperationTemplate.Id, NOT NULL | The versioned operation template this event executed under. Direct FK so events remain queryable even when work orders are absent (OI-07 background-only WOs). |
| LotId | BIGINT | FK → Lot.Id, NOT NULL | |
| LocationId | BIGINT | FK → Location.Id, NOT NULL | Machine/cell where the operation ran |
| ItemId | BIGINT | FK → Item.Id, NOT NULL | |
| GoodCount | INT | NOT NULL | |
| NoGoodCount | INT | NOT NULL, DEFAULT 0 | |
| DieIdentifier | NVARCHAR(50) | NULL | Die name/number captured from the machine's `LocationAttribute` value at event time. Not an FK (dies are currently a location-attribute concept, not a first-class entity). If OI-10 resolves to a dedicated `Die` table, a parallel `DieId BIGINT FK` will be added — this column remains as the historical snapshot. |
| CavityNumber | INT | NULL | Cavity captured when the operation template requires `CavityInfo` |
| WeightValue | DECIMAL(10,3) | NULL | Captured when operation template requires `Weight` (e.g., scale-driven container closure, OI-02) |
| WeightUomId | BIGINT | FK → Parts.Uom.Id, NULL | Required whenever `WeightValue` is set |
| OperatorId | BIGINT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | BIGINT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| RecordedAt | DATETIME2(3) | NOT NULL | |
| Remarks | NVARCHAR(500) | NULL | |

### ProductionEventValue

Child of `ProductionEvent` — holds any `DataCollectionField` value configured on the operation template but *not* promoted to a typed column on `ProductionEvent`. Lets engineering extend the data collection vocabulary without schema changes. One row per field collected for a given event.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ProductionEventId | BIGINT | FK → ProductionEvent.Id, NOT NULL, ON DELETE CASCADE | |
| DataCollectionFieldId | BIGINT | FK → Parts.DataCollectionField.Id, NOT NULL | Which field this value satisfies |
| Value | NVARCHAR(255) | NOT NULL | String representation (canonical storage) |
| NumericValue | DECIMAL(18,4) | NULL | Populated when the field is numeric — enables range queries without parsing `Value` |
| UomId | BIGINT | FK → Parts.Uom.Id, NULL | Required when the field is a measurement |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

**Unique constraint:** `UNIQUE (ProductionEventId, DataCollectionFieldId)` — a given field is captured once per event.

**Rule:** fields already represented as typed columns on `ProductionEvent` (GoodCount, NoGoodCount, DieIdentifier, CavityNumber, WeightValue) SHALL NOT also be written to `ProductionEventValue`. The Phase 8 write proc enforces this.

### ConsumptionEvent

Records which source LOTs were consumed to produce output.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| WorkOrderOperationId | BIGINT | FK → WorkOrderOperation.Id, NULL | |
| SourceLotId | BIGINT | FK → Lot.Id, NOT NULL | What was consumed |
| ProducedLotId | BIGINT | FK → Lot.Id, NULL | Output LOT (if applicable) |
| ProducedContainerId | BIGINT | FK → Container.Id, NULL | Output container (if applicable) |
| ConsumedItemId | BIGINT | FK → Item.Id, NOT NULL | |
| ProducedItemId | BIGINT | FK → Item.Id, NOT NULL | |
| PieceCount | INT | NOT NULL | |
| LocationId | BIGINT | FK → Location.Id, NOT NULL | |
| OperatorId | BIGINT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | BIGINT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| TrayId | BIGINT | FK → ContainerTray.Id, NULL | |
| ProducedSerialNumber | NVARCHAR(50) | NULL | |
| ConsumedAt | DATETIME2(3) | NOT NULL | |

### RejectEvent

Detailed reject/scrap records.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ProductionEventId | BIGINT | FK → ProductionEvent.Id, NULL | |
| LotId | BIGINT | FK → Lot.Id, NOT NULL | |
| DefectCodeId | BIGINT | FK → DefectCode.Id, NOT NULL | |
| Quantity | INT | NOT NULL | |
| ChargeToArea | NVARCHAR(100) | NULL | Area responsible for the reject |
| Remarks | NVARCHAR(500) | NULL | |
| OperatorId | BIGINT | FK → AppUser.Id, NOT NULL | |
| RecordedAt | DATETIME2(3) | NOT NULL | |

---

## 5. Quality Schema — MIXED SCOPE

> **Scope:**
> - `DefectCode` — **MVP** (supports reject tracking in Production Data Acquisition)
> - `QualitySpec`, `QualitySpecVersion`, `QualitySpecAttribute` — **MVP** (Inspections included)
> - `QualitySample`, `QualityResult` — **MVP** for inspections; **CONDITIONAL** for expanded sampling workflows (Scope Matrix row 9)
> - `QualityAttachment` — **MVP** (supports inspections and holds)
> - `HoldEvent` — **MVP-EXPANDED** (Holds included and expanded)
> - `NonConformance` — **FUTURE** — *NCM/Failure Analysis is not in current scope. Table retained because it completes the hold→NCM design separation. When activated, provides structured defect disposition without schema changes.*

Specification-driven inspections, non-conformance, hold management.

### DefectCode

~170 reject/defect reason codes.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | |
| Description | NVARCHAR(500) | NOT NULL | |
| AreaLocationId | BIGINT | FK → Location.Id, NOT NULL | Area (ISA-95 Area, organizational grouping) |
| IsExcused | BIT | NOT NULL, DEFAULT 0 | Affects OEE quality calculation |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### QualitySpec

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Name | NVARCHAR(200) | NOT NULL | |
| ItemId | BIGINT | FK → Item.Id, NULL | |
| OperationTemplateId | BIGINT | FK → OperationTemplate.Id, NULL | |
| Description | NVARCHAR(500) | NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

### QualitySpecVersion

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| QualitySpecId | BIGINT | FK → QualitySpec.Id, NOT NULL | |
| VersionNumber | INT | NOT NULL | |
| EffectiveFrom | DATETIME2(3) | NOT NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | |
| CreatedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

### QualitySpecAttribute

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| QualitySpecVersionId | BIGINT | FK → QualitySpecVersion.Id, NOT NULL | |
| AttributeName | NVARCHAR(100) | NOT NULL | |
| DataType | NVARCHAR(50) | NOT NULL | |
| Uom | NVARCHAR(20) | NULL | |
| TargetValue | DECIMAL(18,6) | NULL | |
| LowerLimit | DECIMAL(18,6) | NULL | |
| UpperLimit | DECIMAL(18,6) | NULL | |
| IsRequired | BIT | NOT NULL, DEFAULT 1 | |
| SortOrder | INT | NOT NULL, DEFAULT 0 | |

### QualitySample

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LotId | BIGINT | FK → Lot.Id, NOT NULL | |
| QualitySpecVersionId | BIGINT | FK → QualitySpecVersion.Id, NOT NULL | Version active at time of sampling |
| LocationId | BIGINT | FK → Location.Id, NULL | |
| SampleTriggerCodeId | BIGINT | FK → SampleTriggerCode.Id, NULL | What triggered this sample |
| SampledByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| SampledAt | DATETIME2(3) | NOT NULL | |
| InspectionResultCodeId | BIGINT | FK → InspectionResultCode.Id, NOT NULL | Pass/Fail outcome |
| Remarks | NVARCHAR(500) | NULL | |

### QualityResult

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| QualitySampleId | BIGINT | FK → QualitySample.Id, NOT NULL | |
| QualitySpecAttributeId | BIGINT | FK → QualitySpecAttribute.Id, NOT NULL | |
| MeasuredValue | NVARCHAR(255) | NOT NULL | |
| Uom | NVARCHAR(20) | NULL | |
| IsPass | BIT | NOT NULL | |

### QualityAttachment

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| QualitySampleId | BIGINT | FK → QualitySample.Id, NULL | |
| NonConformanceId | BIGINT | FK → NonConformance.Id, NULL | |
| FileName | NVARCHAR(255) | NOT NULL | |
| FileType | NVARCHAR(50) | NOT NULL | CSV, XLSX, PDF, PNG, JPG |
| FilePath | NVARCHAR(500) | NOT NULL | |
| UploadedAt | DATETIME2(3) | NOT NULL | |
| UploadedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |

### InspectionResultCode

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Pass, Fail |
| Name | NVARCHAR(100) | NOT NULL | |

### SampleTriggerCode

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | ShiftStart, DieChange, ToolChange, FirstPiece, LastPiece, etc. |
| Name | NVARCHAR(100) | NOT NULL | |
| Description | NVARCHAR(500) | NULL | |

### HoldTypeCode

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | Quality, CustomerComplaint, Precautionary |
| Name | NVARCHAR(100) | NOT NULL | |

### DispositionCode

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | Pending, UseAsIs, Rework, Scrap, ReturnToVendor |
| Name | NVARCHAR(100) | NOT NULL | |

### NonConformance

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LotId | BIGINT | FK → Lot.Id, NOT NULL | |
| DefectCodeId | BIGINT | FK → DefectCode.Id, NOT NULL | |
| Quantity | INT | NOT NULL | |
| DispositionCodeId | BIGINT | FK → DispositionCode.Id, NOT NULL | Current disposition |
| Remarks | NVARCHAR(500) | NULL | |
| ReportedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | BIGINT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| ReportedAt | DATETIME2(3) | NOT NULL | |
| ResolvedAt | DATETIME2(3) | NULL | |
| ResolvedByUserId | BIGINT | FK → AppUser.Id, NULL | |

### HoldEvent

A hold placed on a LOT. Same lifecycle pattern as `DowntimeEvent` — created on placement, updated on release. Active holds have `ReleasedAt IS NULL`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LotId | BIGINT | FK → Lot.Id, NOT NULL | |
| NonConformanceId | BIGINT | FK → NonConformance.Id, NULL | Nullable — holds can be precautionary |
| HoldTypeCodeId | BIGINT | FK → HoldTypeCode.Id, NOT NULL | Quality, CustomerComplaint, Precautionary |
| Reason | NVARCHAR(500) | NOT NULL | |
| PlacedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| PlacedAt | DATETIME2(3) | NOT NULL | |
| ReleasedByUserId | BIGINT | FK → AppUser.Id, NULL | |
| ReleasedAt | DATETIME2(3) | NULL | NULL while hold is active |
| ReleaseRemarks | NVARCHAR(500) | NULL | |

---

## 6. OEE Schema — MIXED SCOPE

> **Scope:**
> - `DowntimeReasonType`, `DowntimeReasonCode` — **MVP** (Downtime included)
> - `ShiftSchedule`, `Shift` — **MVP** (supports downtime context and production reporting)
> - `DowntimeEvent` — **MVP** (Downtime included)
> - `OeeSnapshot` — **FUTURE** — *OEE is not in current scope. Table retained because it is purely derivative of MVP data (downtime events + production events + shift instances). Activation requires only a scheduled calculation job — no new data capture.*

Downtime tracking, shift management, materialized OEE metrics.

### DowntimeReasonType

Read-only, seeded in migration `0009`. 6 fixed rows.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(30) | NOT NULL, UNIQUE | Equipment, Miscellaneous, Mold, Quality, Setup, Unscheduled |
| Name | NVARCHAR(100) | NOT NULL | |

### DowntimeReasonCode

~353 active seed rows from `downtime_reason_codes.csv` (DC=86, MS=239, TS=25). Loaded via `Oee.DowntimeReasonCode_BulkLoadFromSeed`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Generated as `{DeptCode}-{NNNN}` (e.g., `DC-0003`) by the bulk-load proc from the CSV's `DeptCode` + zero-padded `ReasonId`. Engineering-created codes are free-form. |
| Description | NVARCHAR(500) | NOT NULL | |
| AreaLocationId | BIGINT | FK → Location.Id, NOT NULL | Area (organizational grouping) |
| DowntimeReasonTypeId | BIGINT | FK → DowntimeReasonType.Id, NULL | NULL allowed — CSV rows with missing TypeDesc load as NULL and engineering backfills via `_Update` before go-live |
| DowntimeSourceCodeId | BIGINT | FK → DowntimeSourceCode.Id, NULL | CSV carries no source column; always NULL at initial load |
| IsExcused | BIT | NOT NULL, DEFAULT 0 | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT SYSUTCDATETIME() | |
| CreatedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| UpdatedAt | DATETIME2(3) | NULL | |
| UpdatedByUserId | BIGINT | FK → AppUser.Id, NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### ShiftSchedule

Named shift patterns (First Shift 6a–2p M-F, Second Shift 2p–10p, Weekend OT, etc.).

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Name | NVARCHAR(100) | NOT NULL, UNIQUE | |
| Description | NVARCHAR(500) | NULL | |
| StartTime | TIME(0) | NOT NULL | |
| EndTime | TIME(0) | NOT NULL | Shift spans midnight when `EndTime < StartTime` (runtime handles this) |
| DaysOfWeekBitmask | INT | NOT NULL, CHECK 1-127 | Mon=1, Tue=2, Wed=4, Thu=8, Fri=16, Sat=32, Sun=64. Mon-Fri = 31; Sat+Sun = 96. |
| EffectiveFrom | DATE | NOT NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT SYSUTCDATETIME() | |
| CreatedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| UpdatedAt | DATETIME2(3) | NULL | |
| UpdatedByUserId | BIGINT | FK → AppUser.Id, NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### Shift

Runtime shift instances — written by Arc 2 (plant-floor shift controller) when a scheduled shift starts. The Config Tool only reads via `Oee.Shift_List` for admin visibility.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ShiftScheduleId | BIGINT | FK → ShiftSchedule.Id, NOT NULL | |
| ActualStart | DATETIME2(3) | NOT NULL | |
| ActualEnd | DATETIME2(3) | NULL | NULL while the shift is active |
| Remarks | NVARCHAR(500) | NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT SYSUTCDATETIME() | |

### DowntimeSourceCode

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Manual, PLC |
| Name | NVARCHAR(100) | NOT NULL | |

### DowntimeEvent

Append-only. Never overwrite started_at.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LocationId | BIGINT | FK → Location.Id, NOT NULL | Machine |
| DowntimeReasonCodeId | BIGINT | FK → DowntimeReasonCode.Id, NULL | May be assigned later |
| ShiftId | BIGINT | FK → Shift.Id, NULL | |
| StartedAt | DATETIME2(3) | NOT NULL | |
| EndedAt | DATETIME2(3) | NULL | NULL while event is open |
| DowntimeSourceCodeId | BIGINT | FK → DowntimeSourceCode.Id, NOT NULL | How this event was recorded |
| OperatorId | BIGINT | FK → AppUser.Id, NULL | |
| ShotCount | INT | NULL | Die cast warm-up/setup shot count (when reason_type = Setup) |
| Remarks | NVARCHAR(500) | NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

> 🔶 **PENDING INTERNAL REVIEW — UJ-14:** Warm-up shots are tracked as a downtime sub-category (`DowntimeReasonType` = Setup) with the `ShotCount` column on the `DowntimeEvent` record itself. This keeps warm-up time and shot count in a single record. The Die Cast production screen records good/bad shot counts on the `ProductionEvent`; warm-up shot counts go here. Needs review with Ben.

### OeeSnapshot

Materialized OEE per machine per shift. Derivative, not system of record.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| LocationId | BIGINT | FK → Location.Id, NOT NULL | Machine |
| ShiftId | BIGINT | FK → Shift.Id, NOT NULL | |
| SnapshotDate | DATE | NOT NULL | |
| Availability | DECIMAL(5,4) | NOT NULL | 0.0000 – 1.0000 |
| Performance | DECIMAL(5,4) | NOT NULL | |
| QualityRate | DECIMAL(5,4) | NOT NULL | |
| Oee | DECIMAL(5,4) | NOT NULL | availability × performance × quality_rate |
| PlannedProductionTimeMin | INT | NOT NULL | |
| ActualRunTimeMin | INT | NOT NULL | |
| TotalDowntimeMin | INT | NOT NULL | |
| GoodCount | INT | NOT NULL | |
| TotalCount | INT | NOT NULL | |
| RejectCount | INT | NOT NULL | |
| CalculatedAt | DATETIME2(3) | NOT NULL | |

---

## 7. Audit Schema — `MVP`

> **Scope:** All tables MVP. Foundational — 20-year retention requirement applies across all scope phases.

Immutable, append-only logging. BIGINT PKs for high-volume append.

### LogSeverity

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | ERROR, WARNING, INFO |
| Name | NVARCHAR(100) | NOT NULL | |

### LogEventType

Normalized vocabulary for what happened. Shared across all log tables.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | LotCreated, LotMoved, ProductionRecorded, HoldPlaced, etc. |
| Name | NVARCHAR(200) | NOT NULL | |
| Description | NVARCHAR(500) | NULL | |

### LogEntityType

Normalized vocabulary for what was affected. Shared across operation_log and config_log.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | LOT, CONTAINER, WORK_ORDER, ITEM, LOCATION, etc. |
| Name | NVARCHAR(200) | NOT NULL | |
| Description | NVARCHAR(500) | NULL | |

### OperationLog

Every shop-floor action.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK, IDENTITY | |
| LoggedAt | DATETIME2(3) | NOT NULL | |
| UserId | BIGINT | FK → AppUser.Id, NULL | |
| TerminalLocationId | BIGINT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| LocationId | BIGINT | FK → Location.Id, NULL | Machine/location context |
| LogSeverityId | BIGINT | FK → LogSeverity.Id, NOT NULL | |
| LogEventTypeId | BIGINT | FK → LogEventType.Id, NOT NULL | |
| LogEntityTypeId | BIGINT | FK → LogEntityType.Id, NOT NULL | |
| EntityId | BIGINT | NULL | PK of the affected entity |
| Description | NVARCHAR(1000) | NOT NULL | |
| OldValue | NVARCHAR(500) | NULL | |
| NewValue | NVARCHAR(500) | NULL | |

### ConfigLog

Engineering and admin configuration changes.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK, IDENTITY | |
| LoggedAt | DATETIME2(3) | NOT NULL | |
| UserId | BIGINT | FK → AppUser.Id, NULL | |
| LogSeverityId | BIGINT | FK → LogSeverity.Id, NOT NULL | |
| LogEventTypeId | BIGINT | FK → LogEventType.Id, NOT NULL | |
| LogEntityTypeId | BIGINT | FK → LogEntityType.Id, NOT NULL | |
| EntityId | BIGINT | NULL | |
| Description | NVARCHAR(1000) | NOT NULL | |
| Changes | NVARCHAR(MAX) | NULL | JSON or structured diff |

### InterfaceLog

External system communications.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK, IDENTITY | |
| LoggedAt | DATETIME2(3) | NOT NULL | |
| SystemName | NVARCHAR(50) | NOT NULL | AIM, PLC, MACOLA, INTELEX |
| Direction | NVARCHAR(10) | NOT NULL | Inbound, OUTBOUND |
| LogEventTypeId | BIGINT | FK → LogEventType.Id, NOT NULL | |
| Description | NVARCHAR(1000) | NOT NULL | |
| RequestPayload | NVARCHAR(MAX) | NULL | When high-fidelity logging enabled |
| ResponsePayload | NVARCHAR(MAX) | NULL | |
| ErrorCondition | NVARCHAR(200) | NULL | |
| ErrorDescription | NVARCHAR(1000) | NULL | |
| IsHighFidelity | BIT | NOT NULL, DEFAULT 0 | |

### FailureLog

Records attempted but **rejected** stored procedure calls — parameter validation failures, business rule violations, FK mismatches, and unexpected exceptions caught by a CATCH handler. Complements `ConfigLog` and `OperationLog`: those tables record what *succeeded*, `FailureLog` records what was *attempted and blocked*. Used for UX improvement (surface common rejection reasons), abuse detection, and root-cause analysis.

Every shared audit proc writes here on failure. Mutating stored procs call `Audit_LogFailure` from any validation-failure path **and** from their CATCH handler (outside the rolled-back transaction, so the failure record survives).

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK, IDENTITY | |
| AttemptedAt | DATETIME2(3) | NOT NULL, DEFAULT SYSUTCDATETIME() | When the call was attempted |
| AppUserId | BIGINT | FK → AppUser.Id, NOT NULL | Who attempted the action |
| LogEntityTypeId | BIGINT | FK → LogEntityType.Id, NOT NULL | What kind of entity (e.g., Location, Item, Bom) |
| EntityId | BIGINT | NULL | Target entity Id; NULL for Create attempts where no Id exists yet |
| LogEventTypeId | BIGINT | FK → LogEventType.Id, NOT NULL | What action was attempted (Created, Updated, Deprecated, etc.) |
| FailureReason | NVARCHAR(500) | NOT NULL | The `@Message` value returned to the caller |
| ProcedureName | NVARCHAR(200) | NOT NULL | Fully-qualified proc name (e.g., `Location.Location_Create`) |
| AttemptedParameters | NVARCHAR(MAX) | NULL | JSON snapshot of the input parameters for debugging |

**Indexes:**

| Index | Columns | Purpose |
|---|---|---|
| IX_FailureLog_AttemptedAt | `AttemptedAt DESC` | Recent failures dashboard |
| IX_FailureLog_AppUser | `AppUserId, AttemptedAt DESC` | Per-user failure history |
| IX_FailureLog_EntityEvent | `LogEntityTypeId, LogEventTypeId, AttemptedAt DESC` | "Top rejection reasons by entity type" |
| IX_FailureLog_ProcedureName | `ProcedureName, AttemptedAt DESC` | "Which procs are failing most" |
