# MPP MES — Data Model Reference

**Version:** v1.8 working draft
**Schemas:** 8 | **Tables:** ~73
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
| 1.8 | 2026-04-22 | Blue Ridge Automation | **Phase E Group 1 — schema additions from the 2026-04-22 legacy-screenshot gap analysis.** Five items: (1) **OI-11** — new `Parts.ItemTransform` table for Casting → Trim part-number rename (source item, destination item, event-level traceability via FK to `Workorder.ProductionEvent`), supports Honda genealogy across the Trim Shop boundary where the part changes identity. (2) **OI-12** — `Parts.ContainerConfig.MaxParts INT NULL` (per-container cap — rejects scan-in beyond this limit to stop operators over-scanning). Lineside inventory quantity cap modelled as a new `LocationAttribute` (`LinesideLimit`) attached to Cell definitions via the existing `Location.LocationAttributeDefinition` pattern — no schema change, just a seed entry. (3) **OI-18** — `Parts.ItemLocation` extended with consumption metadata: `MinQuantity INT NULL`, `MaxQuantity INT NULL`, `DefaultQuantity INT NULL`, `IsConsumptionPoint BIT NOT NULL DEFAULT 0`. Drives the runtime Allocations grid at the workstation (quantities the operator is hinted to scan in) and distinguishes consumption points (inputs to the cell) from production points (outputs). (4) **OI-19** — `Parts.Item.CountryOfOrigin NVARCHAR(2) NULL` (ISO 3166-1 alpha-2). Honda compliance field surfaced in the Flexware Material configuration. (5) **OI-20** — new `Workorder.ScrapSource` read-only code table (seeded `Inventory` + `Location` at Phase G) and `Workorder.ProductionEvent.ScrapSourceId BIGINT NULL FK → ScrapSource.Id`. Enforced nullable because only scrap events populate it; captures the Flexware "Scrap from inventory" vs "Scrap from the selected location" distinction on the Lot Details screen. `Audit.LogEntityType` gains 2 rows (ItemTransform, ScrapSource). All five changes are additive — no breaking changes to existing procs or tests. SQL lands in Phase G migration `0010_phase9_tools_and_workorder.sql` alongside the Tools schema. Discovery items (OI-24..30) parked for MPP input. Source: `Meeting_Notes/2026-04-20_OI_Review_Status_Summary.md` v1.1 §"Additional discovered gaps" + `MPP_MES_Open_Issues_Register.md` v2.5. |
| 1.7 | 2026-04-21 | Blue Ridge Automation | **Phase B Tool Management schema — Tool promoted to a first-class polymorphic subsystem (OI-10 superseded).** New `Tools` schema with 10 tables: `ToolType` (seeded read-only — Die/Cutter/Jig/Gauge/AssemblyFixture/TrimTool, `HasCavities` flag), `ToolAttributeDefinition` (per-type attribute schema mirroring `Location.LocationAttributeDefinition`), `Tool` (system of record for tool identity, nullable `DieRankId` for Die-type only, no shot counter — derived from `ProductionEvent`), `ToolAttribute` (values), `ToolCavity` (child of Tool for HasCavities types, 3-state Active/Closed/Scrapped status), `ToolAssignment` (append-only check-in/out history against Cells, filtered UNIQUE on active assignment), `ToolStatusCode` + `ToolCavityStatusCode` (read-only code tables), `DieRank` (empty seed — MPP Quality owes the list), `DieRankCompatibility` (empty seed — merge proc rejects cross-die merges until populated, supervisor AD override per FDS-04-007). `Workorder` gains `WorkOrderType` code table (Demand/Maintenance/Recipe, seeded read-only) and two columns on `Workorder.WorkOrder`: `WorkOrderTypeId BIGINT NOT NULL DEFAULT Demand-Id` (existing rows backfill to Demand) and `ToolId BIGINT NULL FK → Tools.Tool` (Maintenance WOs only — enforced at proc layer, not CHECK, because Recipe WOs legitimately have NULL ToolId). `Audit.LogEntityType` gets 8 new seed rows (Tool, ToolAttributeDefinition, ToolAttribute, ToolCavity, ToolAssignment, DieRank, DieRankCompatibility, WorkOrderType). Maintenance WO *flow* is FUTURE — schema hook only in MVP. Tool-life threshold alarms are FUTURE (scheduled Gateway Script pattern). Block concept (from 2026-04-20 meeting) dropped from Tools — handled by ISA-95 hierarchy + `Parts.ItemLocation` per Phase D / OI-08 addenda. Phase G migration `0010_phase9_tools_and_workorder.sql` delivers the SQL (~35 procs, ~60 tests); same migration drops the legacy `Location.AppUser.ClockNumber` + `.PinHash` columns deferred from Phase C. Full design spec: `docs/superpowers/specs/2026-04-21-tool-management-design.md` v0.2. |
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
| LinesideLimit | INT | No | pieces | Maximum total pieces allowed on this lineside location at one time (sum across all open LOTs). Scan-in mutation rejects when cumulative lineside quantity would exceed this. Added v1.8 (OI-12). Complements `Parts.ContainerConfig.MaxParts` which caps per-container; `LinesideLimit` caps per-location. |

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
| CountryOfOrigin | NVARCHAR(2) | NULL | ISO 3166-1 alpha-2 country code (e.g., `US`, `JP`, `MX`). Honda compliance surface — appears on genealogy and shipping output. Added v1.8 (OI-19). |
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

Part-to-location eligibility (which parts can run on which machines) **plus consumption metadata** for runtime Allocations (added v1.8, OI-18).

v1.8 extends this junction with four columns surfaced in the legacy Flexware "Compatible work cells" configuration: `MinQuantity`, `MaxQuantity`, `DefaultQuantity`, and `IsConsumptionPoint`. These drive the runtime Allocations grid at the workstation — when a LOT is scanned into a Cell flagged `IsConsumptionPoint = 1`, the UI pre-populates `DefaultQuantity`, validates the scan against `MinQuantity`/`MaxQuantity`, and rejects over-scanning. Output cells (produce-at) carry `IsConsumptionPoint = 0`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| ItemId | BIGINT | FK → Item.Id, NOT NULL | |
| LocationId | BIGINT | FK → Location.Id, NOT NULL | Machine or work cell |
| MinQuantity | INT | NULL | Minimum pieces per scan-in at this Cell for this Item. Added v1.8 (OI-18). |
| MaxQuantity | INT | NULL | Maximum pieces per scan-in — rejects over-scan. Added v1.8 (OI-18). |
| DefaultQuantity | INT | NULL | Pre-populated quantity on the Allocations scan form. Added v1.8 (OI-18). |
| IsConsumptionPoint | BIT | NOT NULL, DEFAULT 0 | `1` = this Cell consumes this Item (input); `0` = this Cell produces this Item (output) or is merely eligible. Added v1.8 (OI-18). |
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
| MaxParts | INT | NULL | Hard cap on pieces per container regardless of trays/parts math. Scan-in mutation rejects when cumulative container quantity would exceed this. Added v1.8 (OI-12) to stop lineside over-scanning. |
| IsSerialized | BIT | NOT NULL, DEFAULT 0 | |
| ClosureMethod | NVARCHAR(20) | NULL | `BY_COUNT` or `BY_WEIGHT`. Added in Phase 4 pending OI-02 closure. |
| TargetWeight | DECIMAL(10,4) | NULL | Target weight for BY_WEIGHT closure. Added in Phase 4 pending OI-02 closure. |
| DunnageCode | NVARCHAR(50) | NULL | Returnable dunnage identifier |
| CustomerCode | NVARCHAR(50) | NULL | Honda customer code |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### ItemTransform

Records a **part-identity change** across a process boundary — most notably the Casting → Trim Shop rename, where the same physical piece carries a different part number on each side of the transform. Genealogy must bridge the two identities so Honda queries resolve from the shipped part number back to the cast part number.

Added v1.8 (OI-11). Append-only event-style table.

> **⚠ Implementation deferred to Arc 2 Phase 1** (discovered 2026-04-22 during Phase G scoping). This table has FKs into `Lots.Lot` (`SourceLotId`, `DestinationLotId`) and `Workorder.ProductionEvent` (`ProductionEventId`) — neither of those parent tables exists yet (Phases 1–8 built only the Config Tool side; runtime Lot / ProductionEvent tables are Arc 2 Phase 1). `ItemTransform` will be CREATED by Arc 2 Phase 1's migration alongside its parent tables, not ALTERed in later. The schema spec here is final; the SQL DDL and procs (`ItemTransform_Record`, `_GetBySourceLot`, `_GetByDestinationLot`) land in Arc 2 Phase 1. `Audit.LogEntityType` seed row for ItemTransform is reserved in the Phase G migration (Id=39) so Arc 2 doesn't need to touch the audit seed.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| SourceItemId | BIGINT | FK → Item.Id, NOT NULL | The part number before the transform (e.g., the Casting part). |
| DestinationItemId | BIGINT | FK → Item.Id, NOT NULL | The part number after the transform (e.g., the Trim Shop part). |
| SourceLotId | BIGINT | FK → Lots.Lot.Id, NOT NULL | LOT consumed on the source side. |
| DestinationLotId | BIGINT | FK → Lots.Lot.Id, NOT NULL | LOT produced on the destination side. |
| ProductionEventId | BIGINT | FK → Workorder.ProductionEvent.Id, NULL | Event that captured the transform (if any — trim crossing may not always be mediated by a ProductionEvent). |
| LocationId | BIGINT | FK → Location.Id, NOT NULL | Cell where the transform was recorded (typically the first Trim Shop cell). |
| Quantity | INT | NOT NULL | Pieces transformed. |
| OperatorId | BIGINT | FK → AppUser.Id, NOT NULL | Who triggered / stamped the transform (initials). |
| TerminalLocationId | BIGINT | FK → Location.Id (Terminal), NULL | Terminal from which the action was recorded. |
| RecordedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

**Index:** `IX_ItemTransform_SourceLotId (SourceLotId)` and `IX_ItemTransform_DestinationLotId (DestinationLotId)` — genealogy walks hit both directions.

**Rule:** `SourceItemId <> DestinationItemId` (CHECK enforced at proc layer).

**Integration with genealogy:** `Lots.LotGenealogy` retains the physical parent/child relationship across the transform; `ItemTransform` layers the *part-identity* change on top. A full Honda trace joins through both tables.

### ✅ Resolved (v1.7): Tool Life Tracking → §7 Tools Schema

> **Scope Matrix row 26** (Tool Life, FRS 5.6.6) is resolved by the dedicated **§7 Tools Schema** added in v1.7 as part of the Phase B Tool Management refactor (see `docs/superpowers/specs/2026-04-21-tool-management-design.md`). Tools are now a first-class polymorphic subsystem — `Tools.Tool` holds tool identity; `Tools.ToolCavity` tracks per-cavity status; `Tools.ToolAssignment` is the append-only check-in/out history against Cells. Shot counts derive from `Workorder.ProductionEvent` (no live counter column). Tool-life threshold alarms remain **FUTURE** — delivered later via a scheduled Gateway Script that reads the derived shot counts.
>
> **Historical context (pre-v1.7):** The gap was originally left open because MPP hadn't confirmed whether tool life needed its own event history or could ride on `LocationAttribute`. The 2026-04-20 MPP review resolved it in favour of a dedicated subsystem so that dies, cutters, jigs, gauges, and trim tools all share a consistent identity and maintenance hook.

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
> - `WorkOrder`, `WorkOrderStatus`, `WorkOrderOperation`, `OperationStatus`, `WorkOrderType` — **MVP-LITE** (auto-generated, invisible to operators, no WO screens — per OI-07 resolution)
> - `ProductionEvent`, `ProductionEventValue`, `ConsumptionEvent`, `RejectEvent`, `ScrapSource` — **MVP** (Production Data Acquisition is included and expanded)
> - Maintenance WO *flow* (screens, state machine, scheduling) — **FUTURE** (schema hook is MVP — `WorkOrderType` seed + nullable `ToolId` on `WorkOrder`)
>
> **OI-07 status (2026-04-20 MPP review):** Confirmed revised — three WO types exist: **Demand** (production, existing MVP-LITE behaviour), **Maintenance** (targets a Tool, FUTURE flow but schema hook is MVP), **Recipe** (configuration/recipe context, hidden from operator). Demand WOs remain invisible background bookkeeping. Operators never see or interact with any WO type in the MVP. All WO tables are populated but no WO-specific Perspective screens are built. Production events function independently via nullable `WorkOrderOperationId` FKs.
>
> Production events have nullable FKs to `WorkOrderOperation`, allowing them to function independently even if the work order capability is deferred.

Internal work order context, production events, consumption tracking.

### WorkOrderStatus

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Created, InProgress, Completed, Cancelled |
| Name | NVARCHAR(100) | NOT NULL | |

### ScrapSource

Read-only code table distinguishing the two scrap entry paths surfaced in the legacy Flexware Lot Details screen: **Inventory** (scrapping unallocated stock on a LOT) vs **Location** (scrapping in-process material at a specific workstation). Added v1.8 (OI-20). Seeded at migration time.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | `Inventory`, `Location` |
| Name | NVARCHAR(100) | NOT NULL | |
| Description | NVARCHAR(500) | NULL | |

**Seed data (Phase G migration):**

| Code | Name | Description |
|---|---|---|
| Inventory | Scrap From Inventory | Scrap of unallocated pieces on a LOT — no workstation context. Used by the Lot Details "Scrap from inventory" button. |
| Location | Scrap From Location | Scrap of in-process pieces at a specific Cell — workstation context required. Used by the workstation "Scrap from the selected location" button. |

### OperationStatus

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Pending, InProgress, Completed, Skipped |
| Name | NVARCHAR(100) | NOT NULL | |

### WorkOrderType

Read-only code table. Seeded at migration time. Added in v1.7 (Phase B) to support the three-type WO model confirmed at the 2026-04-20 OI-07 review.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | `Demand`, `Maintenance`, `Recipe` |
| Name | NVARCHAR(100) | NOT NULL | |
| Description | NVARCHAR(500) | NULL | |

**Seed data (Phase G migration):**

| Code | Name | Description |
|---|---|---|
| Demand | Demand Work Order | Production work orders (existing MVP-LITE behaviour; auto-generated, invisible to operators). |
| Maintenance | Maintenance Work Order | Targets a Tool (via `WorkOrder.ToolId`). **FUTURE** — no flow, screens, or procs in MVP; schema hook only. Ben owes the maintenance-engine scope. |
| Recipe | Recipe Work Order | Configuration / recipe context. Hidden from operator. |

### WorkOrder

Auto-generated internal work order. Operators never see this. v1.7 adds `WorkOrderTypeId` (discriminator) and `ToolId` (Maintenance-only, nullable).

> **⚠ Implementation deferred to Arc 2 Phase 1** (discovered 2026-04-22 during Phase G scoping). The `Workorder.WorkOrder` table itself does not yet exist — Phases 1–8 built only the `WorkOrderStatus` + `OperationStatus` code tables. The v1.7 Phase B spec wrote these as *ALTER ADD COLUMN*, but there's no table to ALTER. Arc 2 Phase 1 CREATEs `Workorder.WorkOrder` with `WorkOrderTypeId` (FK → `Workorder.WorkOrderType`, created in Phase G) and `ToolId` (FK → `Tools.Tool`, created in Phase G) baked in from day one. The column contract described below is authoritative — it's just the DDL verb that changes from ALTER to CREATE.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| WoNumber | NVARCHAR(50) | NOT NULL, UNIQUE | System-generated |
| WorkOrderTypeId | BIGINT | FK → WorkOrderType.Id, NOT NULL | Added v1.7. Phase G migration backfills existing rows to `Demand`. Existing create procs default to `Demand` so Phase 1–8 callers need no changes. |
| ItemId | BIGINT | FK → Item.Id, NOT NULL | |
| RouteTemplateId | BIGINT | FK → RouteTemplate.Id, NOT NULL | The route version active at creation |
| WorkOrderStatusId | BIGINT | FK → WorkOrderStatus.Id, NOT NULL | |
| ToolId | BIGINT | FK → Tools.Tool.Id, NULL | Added v1.7. Populated only when `WorkOrderTypeId = Maintenance`. Enforced at the proc layer (no hard CHECK — `Recipe` WOs legitimately have NULL `ToolId`). |
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

> **⚠ Implementation deferred to Arc 2 Phase 1** (discovered 2026-04-22). Like `Workorder.WorkOrder`, this table does not yet exist in the codebase. Arc 2 Phase 1 CREATEs it with the full column list below, including the v1.8 `ScrapSourceId` (FK → `Workorder.ScrapSource`, created in Phase G). The column contract is authoritative; the DDL verb is CREATE, not ALTER.

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
| ScrapSourceId | BIGINT | FK → ScrapSource.Id, NULL | Populated only when this event represents a scrap action; identifies whether the scrap came from unallocated inventory (`Inventory`) or from in-process material at a workstation (`Location`). NULL for non-scrap events. Added v1.8 (OI-20). |
| DieIdentifier | NVARCHAR(50) | NULL | Die name/number captured from the machine's `LocationAttribute` value at event time. Retained as an immutable historical snapshot (survives tool rename/replacement). v1.7 promoted Tool to a first-class entity (§7 Tools Schema) — a parallel `ToolId BIGINT FK → Tools.Tool` may be added in a later phase for query/analytics joins, but this NVARCHAR column stays as the as-captured string. |
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

## 7. Tools Schema — MIXED SCOPE

> **Scope:**
> - `ToolType`, `ToolAttributeDefinition`, `Tool`, `ToolAttribute`, `ToolCavity`, `ToolAssignment`, status code tables, `DieRank`, `DieRankCompatibility` — **MVP**
> - Configuration Tool CRUD screens for all of the above — **MVP** (Phase 9 of the Config Tool phased plan)
> - Maintenance WO *flow* (screens / scheduling / state machine) — **FUTURE** (schema hook is the `Workorder.WorkOrderType=Maintenance` seed + nullable `Workorder.WorkOrder.ToolId` — see §4)
> - Tool-life threshold alarms — **FUTURE** (scheduled Gateway Script pattern when MPP asks; no schema changes required — shot counts derive from `Workorder.ProductionEvent`)
> - Cross-plant tool transfer history — **FUTURE** (single-plant MVP)
> - Tool photograph / document attachments — **FUTURE**

Added v1.7 as part of the Phase B Tool Management refactor. Promotes **Tool** from the pre-v1.7 `LocationAttribute` historical-snapshot pattern (where `Workorder.ProductionEvent.DieIdentifier` is just an `NVARCHAR` copy of the machine's current die-attribute value) to a **first-class polymorphic subsystem** covering dies, cutters, jigs, gauges, assembly fixtures, trim tools — any discrete piece of production equipment that has its own identity and lifecycle, can be checked in/out of Cells, carries type-specific attributes, optionally has cavities, and may be the target of a (FUTURE) maintenance work order.

Full design spec: `docs/superpowers/specs/2026-04-21-tool-management-design.md` v0.2.

### Design Overview — polymorphic pattern (mirrors Location)

The Tools model follows the same polymorphism Location uses, but with one layer removed. Location needed two header tables (`LocationType` for the ISA-95 tier + `LocationTypeDefinition` for polymorphic kinds within a tier) because it has both a fixed hierarchy AND polymorphic kinds within the hierarchy. Tools are a **grouping**, not a hierarchy — there is no tier structure — so the equivalent pattern collapses to one `ToolType` header table plus the attribute-definition and value tables:

```
Tools.ToolType                   -- polymorphic kinds (Die, Cutter, Jig, Gauge, AssemblyFixture, TrimTool)
Tools.ToolAttributeDefinition    -- attribute schema per kind
Tools.Tool                       -- concrete tools
Tools.ToolAttribute              -- attribute values
Tools.ToolCavity                 -- cavity children (only for HasCavities types)
Tools.ToolAssignment             -- check-in/out history against Cells
```

If sub-categories ever become useful (e.g., splitting "Die" into "Single-Cavity Die" vs "Multi-Cavity Die"), that's the point to introduce a `ToolSubType` table — not now.

**Block concept** (raised in the 2026-04-20 meeting, "assign them to blocks" for fast die-cast changeover): deliberately **not** modelled in the Tools schema. Location-eligibility for a part running on a machine is already covered by the ISA-95 hierarchy + `Parts.ItemLocation`. Phase D's OI-08 addenda confirms hierarchical resolution: an Item that's eligible on an Area propagates to every Cell under that Area without explicit rows.

### ToolType

Polymorphic kinds. Read-only in MVP — seeded at migration time, no CRUD procs. Follows the precedent set by `Location.LocationType` / `Location.LocationTypeDefinition`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | `Die`, `Cutter`, `Jig`, `Gauge`, `AssemblyFixture`, `TrimTool` |
| Name | NVARCHAR(100) | NOT NULL | Display name |
| Description | NVARCHAR(500) | NULL | |
| Icon | NVARCHAR(100) | NULL | Perspective tree component icon (matches `LocationTypeDefinition.Icon` pattern; NULL at deployment, populated via Config Tool) |
| HasCavities | BIT | NOT NULL, DEFAULT 0 | `ToolCavity` rows are only valid for Tools whose type has this flag set |
| SortOrder | INT | NOT NULL, DEFAULT 0 | UI ordering |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | Soft delete |

**Seed data (Phase G migration):**

| Code | Name | HasCavities | Notes |
|---|---|---|---|
| Die | Die Cast Die | 1 | Dies used on die cast machines |
| Cutter | Machining Cutter | 0 | Tool heads / inserts on CNC machines |
| Jig | Assembly Jig | 0 | Fixtures on assembly stations |
| Gauge | Inspection Gauge | 0 | Measurement tools |
| AssemblyFixture | Assembly Fixture | 0 | Trim-shop and assembly fixtures |
| TrimTool | Trim Shop Tool | 0 | Trim-specific tooling |

### ToolAttributeDefinition

Attribute schema per tool type. Mirrors `Location.LocationAttributeDefinition`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| ToolTypeId | BIGINT | FK → ToolType.Id, NOT NULL | Which kind this attribute applies to |
| Code | NVARCHAR(50) | NOT NULL | Attribute code (e.g., `CycleTimeSec`, `Tonnage`, `InsertCount`) |
| Name | NVARCHAR(100) | NOT NULL | Display label |
| DataType | NVARCHAR(20) | NOT NULL | `String`, `Integer`, `Decimal`, `Boolean`, `Date` (matches `LocationAttributeDefinition.DataType` values) |
| IsRequired | BIT | NOT NULL, DEFAULT 0 | |
| SortOrder | INT | NOT NULL, DEFAULT 0 | Up/down arrow ordering — no drag-and-drop per UI convention |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | Soft delete |

**Unique:** `UQ_ToolAttributeDefinition_ActiveTypeCode` — filtered UNIQUE `(ToolTypeId, Code)` where `DeprecatedAt IS NULL`.

**Seed:** none. Ships empty; engineering adds `CycleTimeSec`, `CavityCount`, `Tonnage`, etc. via the Config Tool as real tools arrive (same empty-at-rollout pattern as `LocationAttributeDefinition`).

### Tool

Concrete tools. System of record for tool identity.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| ToolTypeId | BIGINT | FK → ToolType.Id, NOT NULL | Polymorphic type |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | Die number, cutter ID, etc. (e.g., `DC-042`) |
| Name | NVARCHAR(100) | NOT NULL | Human-friendly name |
| Description | NVARCHAR(500) | NULL | |
| DieRankId | BIGINT | FK → DieRank.Id, NULL | Die-type only; NULL for all other types. Application-level validation enforces this — no CHECK because the "die-type only" rule needs a join |
| StatusCodeId | BIGINT | FK → ToolStatusCode.Id, NOT NULL | Active / UnderRepair / Scrapped / Retired |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| CreatedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| UpdatedByUserId | BIGINT | FK → AppUser.Id, NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | Soft delete — separate from `StatusCode = Retired` (Retired is the business state; DeprecatedAt is the row-lifecycle state) |

**No shot counter column.** Shot counts derive from `Workorder.ProductionEvent` group-by `(Tool, Cavity)`. Rationale: avoids the double-write + drift problem between an aggregate column and the event stream; leaves all reset-logic to a future Gateway script rather than embedding it in every write path.

### ToolAttribute

Attribute values. Mirrors `Location.LocationAttribute`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| ToolId | BIGINT | FK → Tool.Id, NOT NULL | |
| ToolAttributeDefinitionId | BIGINT | FK → ToolAttributeDefinition.Id, NOT NULL | |
| Value | NVARCHAR(500) | NOT NULL | Stored as text; interpreted per definition's `DataType` |
| UpdatedAt | DATETIME2(3) | NULL | |
| UpdatedByUserId | BIGINT | FK → AppUser.Id, NULL | |

**Unique:** `UQ_ToolAttribute_ToolAttributeDefinition` — UNIQUE `(ToolId, ToolAttributeDefinitionId)`. One value per attribute per tool.

### ToolCavity

Child of Tool. Only valid for Tools whose `ToolType.HasCavities = 1` — application-level validation enforces, no CHECK.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| ToolId | BIGINT | FK → Tool.Id, NOT NULL | Parent die |
| CavityNumber | INT | NOT NULL | 1, 2, 3, … up to the die's cavity count |
| StatusCodeId | BIGINT | FK → ToolCavityStatusCode.Id, NOT NULL | Active / Closed / Scrapped |
| Description | NVARCHAR(500) | NULL | Per-cavity notes (e.g., "small porosity tendency") |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| CreatedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | |
| UpdatedByUserId | BIGINT | FK → AppUser.Id, NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | Soft delete |

**Unique:** `UQ_ToolCavity_ActiveToolCavityNumber` — filtered UNIQUE `(ToolId, CavityNumber)` where `DeprecatedAt IS NULL`.

**Status semantics:**
- **Active** — cavity producing acceptable parts.
- **Closed** — cavity physically shut off (die still runs on remaining cavities).
- **Scrapped** — cavity physically destroyed (die may still run on remaining cavities, or die itself may be scrapped — the two are independent state changes).

Shoot-and-scrap behaviour (producing rejected parts each cycle from a degraded cavity) is **not** a cavity state — it's operational behaviour captured at `Workorder.RejectEvent`. Cavity stays Active until someone decides to Close or Scrap it.

Cavity numbers are immutable after creation (only `StatusCodeId` is editable via the runtime proc surface); the spec only exposes `_Create`, `_UpdateStatus`, `_Deprecate` — no general `_Update`.

### ToolAssignment

Append-only check-in / out history. A Tool can be mounted on a Cell; release closes the row by setting `ReleasedAt`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| ToolId | BIGINT | FK → Tool.Id, NOT NULL | |
| CellLocationId | BIGINT | FK → Location.Location.Id, NOT NULL | Cell the tool is mounted on (application validates the Location is Cell-tier) |
| AssignedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| ReleasedAt | DATETIME2(3) | NULL | NULL = currently mounted |
| AssignedByUserId | BIGINT | FK → AppUser.Id, NOT NULL | Supervisor who mounted (elevated action per FDS-04-007) |
| ReleasedByUserId | BIGINT | FK → AppUser.Id, NULL | Supervisor who released (elevated action per FDS-04-007) |
| Notes | NVARCHAR(500) | NULL | |

**Unique:** `UQ_ToolAssignment_ActiveToolMount` — filtered UNIQUE on `ToolId` where `ReleasedAt IS NULL`. A tool can only be mounted on one Cell at a time; mounting elsewhere requires releasing the previous assignment first.

**Elevated action:** Tool mount / release is in the FDS-04-007 elevated-action list (per-action AD elevation prompt, no session-sticky elevation).

### ToolStatusCode

Read-only code table. Seeded at migration time.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Active / UnderRepair / Scrapped / Retired |
| Name | NVARCHAR(100) | NOT NULL | |
| Description | NVARCHAR(500) | NULL | |

**Seed data:**

| Code | Name | Notes |
|---|---|---|
| Active | Active | In service |
| UnderRepair | Under Repair | Removed from service for repair |
| Scrapped | Scrapped | Physically destroyed / discarded |
| Retired | Retired | End-of-life, archived |

### ToolCavityStatusCode

Read-only code table. Seeded at migration time.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Active / Closed / Scrapped |
| Name | NVARCHAR(100) | NOT NULL | |
| Description | NVARCHAR(500) | NULL | |

**Seed data:**

| Code | Name | Notes |
|---|---|---|
| Active | Active | Producing acceptable parts |
| Closed | Closed | Shut off; die runs without this cavity |
| Scrapped | Scrapped | Physically destroyed |

### DieRank

Code table. Ships **empty** — MPP Quality owes the authoritative ranking scheme (the 2026-04-20 meeting proposed A–E but MPP hasn't confirmed).

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Engineering populates via Config Tool once MPP Quality delivers |
| Name | NVARCHAR(100) | NOT NULL | |
| Description | NVARCHAR(500) | NULL | |
| SortOrder | INT | NOT NULL, DEFAULT 0 | Up/down arrow ordering |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

**Seed data:** none. The Configuration Tool has a Die Rank admin screen for Engineering to populate.

### DieRankCompatibility

Junction. Ships **empty** — MPP Quality owes the compatibility matrix.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| RankAId | BIGINT | FK → DieRank.Id, NOT NULL | |
| RankBId | BIGINT | FK → DieRank.Id, NOT NULL | |
| CanMix | BIT | NOT NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |

**Unique:** `UQ_DieRankCompatibility_Pair` — UNIQUE `(RankAId, RankBId)`. Application-level convention: pairs are stored canonicalised (smaller `Id` first) so a single lookup covers both directions.

**Merge validation rule (OI-05):** `Lots.Lot_Merge` consults this table on cross-die merges:
- Same die on both lots → merge proceeds (no rank involvement).
- Different dies → merge is **rejected** with message "Cross-die merges require die rank compatibility rules — contact MPP Quality" *until the matrix is populated*.
- Once populated, merge succeeds when the pair's `CanMix = 1`, else the rejection is specific ("Die rank {A} cannot mix with die rank {B}").
- **Supervisor override:** the standard FDS-04-007 AD elevation prompt unlocks the merge regardless of the matrix state (same pattern as every other gated action).

### Cross-references

- **Workorder.WorkOrder.ToolId** (§4) — nullable FK into `Tools.Tool`. Populated only for `WorkOrderType = Maintenance` (enforced at proc layer; Recipe WOs legitimately have NULL `ToolId`).
- **Workorder.ProductionEvent.DieIdentifier** (§4) — historical NVARCHAR snapshot of the die at event time. Not an FK. A parallel `ToolId BIGINT FK` may be added in a later phase for analytics joins; the NVARCHAR stays as the as-captured value (survives tool rename/replacement).
- **Audit.LogEntityType** (§8) — 8 new seed rows in Phase G for Tool, ToolAttributeDefinition, ToolAttribute, ToolCavity, ToolAssignment, DieRank, DieRankCompatibility, and `Workorder.WorkOrderType`. Every `Tools.*` mutation proc logs to `Audit.ConfigLog` on success and `Audit.FailureLog` on rejection.
- **Audit.LogEntityType** (§8) — v1.8 adds 2 further seed rows in Phase G: `ItemTransform` (Parts.ItemTransform, OI-11) and `ScrapSource` (Workorder.ScrapSource, OI-20).

---

## 8. Audit Schema — `MVP`

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
