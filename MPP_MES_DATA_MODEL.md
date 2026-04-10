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

---

## Conventions

- `UpperCamelCase` singular noun table and column names (e.g., `LocationType`, `PieceCount`, `CreatedAt`)
- Surrogate `INT Id` primary keys (auto-increment) — natural keys are unique-indexed columns
- `DeprecatedAt DATETIME2(3) NULL` for soft deletes (non-null = inactive)
- `DATETIME2(3)` for all timestamps (millisecond precision)
- `DECIMAL(x,y)` for measurements — never `FLOAT`
- UOM as an explicit column on every quantitative field
- Status fields backed by code tables with FK — no magic integers or free-text
- `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy` on mutable entities
- Append-only tables (events, movements, logs) have `CreatedAt` only — no updates

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
| Id | INT | PK | |
| Code | VARCHAR(20) | NOT NULL, UNIQUE | Short code (Enterprise, Site, Area, WorkCenter, Cell) |
| Name | VARCHAR(100) | NOT NULL | Display name |
| HierarchyLevel | INT | NOT NULL | 0=Enterprise, 1=Site, 2=Area, 3=WorkCenter, 4=Cell |
| Description | VARCHAR(500) | NULL | |

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
| Id | INT | PK | |
| LocationTypeId | INT | FK → LocationType.Id, NOT NULL | Which ISA-95 tier this kind belongs to |
| Code | VARCHAR(50) | NOT NULL, UNIQUE | Short code (e.g., Terminal, DieCastMachine) |
| Name | VARCHAR(100) | NOT NULL | Display name |
| Description | VARCHAR(500) | NULL | |
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
| Id | INT | PK | |
| LocationTypeDefinitionId | INT | FK → LocationTypeDefinition.Id, NOT NULL | Which kind this attribute belongs to |
| AttributeName | VARCHAR(100) | NOT NULL | e.g., `Tonnage`, `IpAddress`, `DefaultPrinter` |
| DataType | VARCHAR(50) | NOT NULL | INT, DECIMAL, BIT, VARCHAR |
| IsRequired | BIT | NOT NULL, DEFAULT 0 | Must every location of this definition carry a value? |
| DefaultValue | VARCHAR(255) | NULL | Default if not explicitly set |
| Uom | VARCHAR(20) | NULL | Unit of measure for this attribute |
| SortOrder | INT | NOT NULL, DEFAULT 0 | Display ordering on config screens |
| Description | VARCHAR(500) | NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

**Example attribute sets (illustrative — not exhaustive):**

*For `Cell` → `Terminal` definition:*

| AttributeName | DataType | Required | Uom | Description |
|---|---|---|---|---|
| IpAddress | VARCHAR | No | — | Terminal IP address for diagnostics |
| DefaultPrinter | VARCHAR | No | — | Associated Zebra printer name for label output |
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
| Id | INT | PK | |
| LocationTypeDefinitionId | INT | FK → LocationTypeDefinition.Id, NOT NULL | Determines both ISA-95 tier (via join) and attribute schema |
| ParentLocationId | INT | FK → Location.Id, NULL | Parent in hierarchy (NULL = root/Enterprise) |
| Name | VARCHAR(200) | NOT NULL | Display name |
| Code | VARCHAR(50) | NOT NULL, UNIQUE | Short identifier (barcode-scannable for machines) |
| Description | VARCHAR(500) | NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

> Note: `LocationType` is not stored directly on `Location`; it's derivable via `LocationTypeDefinition.LocationTypeId`. Hierarchy queries use `ParentLocationId` (adjacency list) and join through `LocationTypeDefinition` when tier-based filtering is needed.

### LocationAttribute

Actual attribute values per location, constrained by the location's definition.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| LocationId | INT | FK → Location.Id, NOT NULL | |
| LocationAttributeDefinitionId | INT | FK → LocationAttributeDefinition.Id, NOT NULL | Which attribute (must belong to the location's definition) |
| AttributeValue | VARCHAR(255) | NOT NULL | Stored as string, parsed per `LocationAttributeDefinition.DataType` |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| UpdatedBy | VARCHAR(100) | NULL | |

**Integrity rule:** A `LocationAttribute.LocationAttributeDefinitionId` SHALL reference an attribute definition whose `LocationTypeDefinitionId` matches the location's `LocationTypeDefinitionId`. Enforced via application logic or trigger — no direct SQL constraint expresses this without a redundant column.

### Terminals in the New Model

> ✅ **RESOLVED — OI-08 / UJ-12:** Terminals are shared, not 1:1 with machines. Operators scan a machine barcode/QR code as the first step of any interaction.

In the polymorphic model, `Terminal` is a `LocationTypeDefinition` under the `Cell` type — it's one of many kinds of Cells. A `DieCastMachine` is another kind of Cell. Both are Cell-tier locations but carry entirely different attribute schemas.

Event tables carry two location references when both operator position and machine context matter:
- `TerminalLocationId` — FK → `Location.Id` where the definition is `Terminal` (where the operator is standing)
- `LocationId` — FK → `Location.Id` where the definition is a machine kind (which machine they scanned)

### AppUser

MES users backed by Active Directory. Roles managed in Ignition.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| AdAccount | VARCHAR(100) | NOT NULL, UNIQUE | Active Directory identity |
| DisplayName | VARCHAR(200) | NOT NULL | |
| ClockNumber | VARCHAR(20) | NULL | Shop-floor identification |
| PinHash | VARCHAR(255) | NULL | Hashed PIN for terminal auth |
| IgnitionRole | VARCHAR(100) | NULL | References Ignition's internal role config |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

---

## 2. Parts Schema — `MVP`

> **Scope:** All tables MVP. Master data schema — items, BOMs, routes, and container configs support core LOT lifecycle and shipping.

Item master, bills of material, routes, operation templates, container configurations.

### ItemType

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Name | VARCHAR(100) | NOT NULL | Raw Material, Component, Sub-Assembly, Finished Good, Pass-Through |
| Description | VARCHAR(500) | NULL | |

### Uom

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Code | VARCHAR(10) | NOT NULL, UNIQUE | EA, LB, KG, etc. |
| Name | VARCHAR(50) | NOT NULL | |

### Item

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| ItemTypeId | INT | FK → ItemType.Id, NOT NULL | |
| PartNumber | VARCHAR(50) | NOT NULL, UNIQUE | MPP part number |
| Description | VARCHAR(500) | NULL | |
| MacolaPartNumber | VARCHAR(50) | NULL | ERP cross-reference |
| DefaultSubLotQty | INT | NULL | Default pieces per sub-LOT split |
| MaxLotSize | INT | NULL | Reasonability check ceiling |
| UomId | INT | FK → Uom.Id, NOT NULL | Counting UOM |
| UnitWeight | DECIMAL(10,4) | NULL | Weight per piece |
| WeightUomId | INT | FK → Uom.Id, NULL | Weight UOM |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| CreatedBy | VARCHAR(100) | NOT NULL | |
| UpdatedBy | VARCHAR(100) | NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### Bom

Versioned bill of materials header.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| ParentItemId | INT | FK → Item.Id, NOT NULL | The product this BOM is for |
| VersionNumber | INT | NOT NULL | |
| EffectiveFrom | DATETIME2(3) | NOT NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | |
| CreatedBy | VARCHAR(100) | NOT NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

### BomLine

Individual components within a BOM.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| BomId | INT | FK → Bom.Id, NOT NULL | |
| ChildItemId | INT | FK → Item.Id, NOT NULL | Component part |
| QtyPer | DECIMAL(10,4) | NOT NULL | Quantity per parent |
| UomId | INT | FK → Uom.Id, NOT NULL | |
| SortOrder | INT | NOT NULL, DEFAULT 0 | |

### RouteTemplate

Versioned manufacturing route for a product.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| ItemId | INT | FK → Item.Id, NOT NULL | |
| VersionNumber | INT | NOT NULL | |
| Name | VARCHAR(200) | NOT NULL | |
| EffectiveFrom | DATETIME2(3) | NOT NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | |
| CreatedBy | VARCHAR(100) | NOT NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

### RouteStep

Ordered steps within a route.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| RouteTemplateId | INT | FK → RouteTemplate.Id, NOT NULL | |
| OperationTemplateId | INT | FK → OperationTemplate.Id, NOT NULL | What happens at this step |
| SequenceNumber | INT | NOT NULL | Execution order |
| IsRequired | BIT | NOT NULL, DEFAULT 1 | |
| Description | VARCHAR(500) | NULL | |

### OperationTemplate

Defines what data to collect at a type of operation. Reusable across products.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Name | VARCHAR(100) | NOT NULL | |
| Code | VARCHAR(20) | NOT NULL, UNIQUE | |
| AreaLocationId | INT | FK → Location.Id, NOT NULL | Area (ISA-95 Area, organizational grouping) |
| RequiresMaterialVerification | BIT | NOT NULL, DEFAULT 0 | |
| RequiresSerialNumber | BIT | NOT NULL, DEFAULT 0 | |
| CollectsDieInfo | BIT | NOT NULL, DEFAULT 0 | |
| CollectsCavityInfo | BIT | NOT NULL, DEFAULT 0 | |
| CollectsWeight | BIT | NOT NULL, DEFAULT 0 | |
| CollectsGoodCount | BIT | NOT NULL, DEFAULT 1 | |
| CollectsBadCount | BIT | NOT NULL, DEFAULT 1 | |
| Description | VARCHAR(500) | NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### ItemLocation

Part-to-location eligibility (which parts can run on which machines).

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| ItemId | INT | FK → Item.Id, NOT NULL | |
| LocationId | INT | FK → Location.Id, NOT NULL | Machine or work cell |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### ContainerConfig

Honda-specified packing rules per product.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| ItemId | INT | FK → Item.Id, NOT NULL | |
| TraysPerContainer | INT | NOT NULL | |
| PartsPerTray | INT | NOT NULL | |
| IsSerialized | BIT | NOT NULL, DEFAULT 0 | |
| DunnageCode | VARCHAR(50) | NULL | Returnable dunnage identifier |
| CustomerCode | VARCHAR(50) | NULL | Honda customer code |
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
| Id | INT | PK | |
| Code | VARCHAR(30) | NOT NULL, UNIQUE | Manufactured, Received, ReceivedOffsite |
| Name | VARCHAR(100) | NOT NULL | |

### LotStatusCode

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Code | VARCHAR(20) | NOT NULL, UNIQUE | Good, Hold, Scrap, Closed |
| Name | VARCHAR(100) | NOT NULL | |
| BlocksProduction | BIT | NOT NULL, DEFAULT 0 | Hold = true, drives interlocks |

### GenealogyRelationshipType

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Code | VARCHAR(20) | NOT NULL, UNIQUE | Split, Merge, Consumption |
| Name | VARCHAR(100) | NOT NULL | |

### Lot

The central tracking entity.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| LotName | VARCHAR(50) | NOT NULL, UNIQUE | The LTT barcode number |
| ItemId | INT | FK → Item.Id, NOT NULL | |
| LotOriginTypeId | INT | FK → LotOriginType.Id, NOT NULL | How it entered MES |
| LotStatusId | INT | FK → LotStatusCode.Id, NOT NULL | Current quality status |
| PieceCount | INT | NOT NULL | Current count |
| MaxPieceCount | INT | NULL | Reasonability ceiling |
| Weight | DECIMAL(12,4) | NULL | |
| WeightUomId | INT | FK → Uom.Id, NULL | |
| DieNumber | VARCHAR(50) | NULL | Die cast LOTs only |
| CavityNumber | VARCHAR(50) | NULL | Die cast LOTs only |
| VendorLotNumber | VARCHAR(100) | NULL | Received LOTs only |
| MinSerialNumber | INT | NULL | Vendor serial range (received bulk parts) |
| MaxSerialNumber | INT | NULL | |
| ParentLotId | INT | FK → Lot.Id, NULL | Adjacency list link for sub-LOTs |
| CurrentLocationId | INT | FK → Location.Id, NOT NULL | Where this LOT is now |
| CreatedByUserId | INT | FK → AppUser.Id, NOT NULL | |
| CreatedAtTerminalId | INT | FK → Location.Id (Terminal), NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| UpdatedBy | VARCHAR(100) | NULL | |

### LotGenealogy

Edge table for the genealogy graph. Adjacency list supporting recursive CTE traversal.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| ParentLotId | INT | FK → Lot.Id, NOT NULL | |
| ChildLotId | INT | FK → Lot.Id, NOT NULL | |
| RelationshipTypeId | INT | FK → GenealogyRelationshipType.Id, NOT NULL | Split, Merge, Consumption |
| PieceCount | INT | NULL | Pieces transferred in this relationship |
| EventUserId | INT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | INT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| EventAt | DATETIME2(3) | NOT NULL | |

### LotStatusHistory

Immutable log of every status transition.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| LotId | INT | FK → Lot.Id, NOT NULL | |
| OldStatusId | INT | FK → LotStatusCode.Id, NOT NULL | |
| NewStatusId | INT | FK → LotStatusCode.Id, NOT NULL | |
| Reason | VARCHAR(500) | NULL | |
| ChangedByUserId | INT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | INT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| ChangedAt | DATETIME2(3) | NOT NULL | |

### LotMovement

Append-only location change log.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| LotId | INT | FK → Lot.Id, NOT NULL | |
| FromLocationId | INT | FK → Location.Id, NULL | NULL on first placement |
| ToLocationId | INT | FK → Location.Id, NOT NULL | |
| MovedByUserId | INT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | INT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| MovedAt | DATETIME2(3) | NOT NULL | |

### LotAttributeChange

Audit log for attribute modifications.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| LotId | INT | FK → Lot.Id, NOT NULL | |
| AttributeName | VARCHAR(100) | NOT NULL | e.g., PieceCount, Weight |
| OldValue | VARCHAR(255) | NULL | |
| NewValue | VARCHAR(255) | NOT NULL | |
| ChangedByUserId | INT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | INT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| ChangedAt | DATETIME2(3) | NOT NULL | |

### LotLabel

LTT barcode label print/reprint tracking.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| LotId | INT | FK → Lot.Id, NOT NULL | |
| PrintReason | VARCHAR(100) | NOT NULL | Initial, ReprintDamaged, Split, Merge, SortCageReIdentify |
| ZplContent | VARCHAR(MAX) | NULL | Full ZPL payload |
| PrinterName | VARCHAR(100) | NULL | |
| PrintedByUserId | INT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | INT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| PrintedAt | DATETIME2(3) | NOT NULL | |

### ContainerStatusCode

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Code | VARCHAR(20) | NOT NULL, UNIQUE | Open, Complete, Shipped, Hold, Void |
| Name | VARCHAR(100) | NOT NULL | |

### Container

Shipping containers for finished goods.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| ContainerName | VARCHAR(50) | NOT NULL, UNIQUE | |
| ItemId | INT | FK → Item.Id, NOT NULL | |
| ContainerConfigId | INT | FK → ContainerConfig.Id, NULL | |
| ContainerStatusId | INT | FK → ContainerStatusCode.Id, NOT NULL | |
| LotId | INT | FK → Lot.Id, NULL | Source LOT |
| CurrentLocationId | INT | FK → Location.Id, NOT NULL | |
| AimShipperId | VARCHAR(50) | NULL | From AIM system |
| HoldNumber | VARCHAR(50) | NULL | Sort Cage hold reference |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |

### ContainerTray

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| ContainerId | INT | FK → Container.Id, NOT NULL | |
| TrayNumber | INT | NOT NULL | |
| PieceCount | INT | NOT NULL | |

### SerializedPart

Individual laser-etched serial numbers.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| SerialNumber | VARCHAR(50) | NOT NULL, UNIQUE | |
| ItemId | INT | FK → Item.Id, NOT NULL | |
| LotId | INT | FK → Lot.Id, NOT NULL | Source LOT |
| ContainerId | INT | FK → Container.Id, NULL | Current container |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

### ContainerSerial

Junction: serial numbers in container tray positions.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| ContainerId | INT | FK → Container.Id, NOT NULL | |
| ContainerTrayId | INT | FK → ContainerTray.Id, NULL | |
| SerializedPartId | INT | FK → SerializedPart.Id, NOT NULL | |
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
| Id | INT | PK | |
| ContainerId | INT | FK → Container.Id, NOT NULL | |
| AimShipperId | VARCHAR(50) | NOT NULL | From AIM |
| LabelType | VARCHAR(50) | NOT NULL | |
| ZplContent | VARCHAR(MAX) | NULL | Full ZPL payload |
| IsVoid | BIT | NOT NULL, DEFAULT 0 | |
| PrintedAt | DATETIME2(3) | NULL | |
| VoidedAt | DATETIME2(3) | NULL | |
| PrintedBy | VARCHAR(100) | NULL | |

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
| Id | INT | PK | |
| Code | VARCHAR(20) | NOT NULL, UNIQUE | CREATED, IN_PROGRESS, COMPLETED, CANCELLED |
| Name | VARCHAR(100) | NOT NULL | |

### OperationStatus

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Code | VARCHAR(20) | NOT NULL, UNIQUE | Pending, IN_PROGRESS, COMPLETED, SKIPPED |
| Name | VARCHAR(100) | NOT NULL | |

### WorkOrder

Auto-generated internal work order. Operators never see this.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| WoNumber | VARCHAR(50) | NOT NULL, UNIQUE | System-generated |
| ItemId | INT | FK → Item.Id, NOT NULL | |
| RouteTemplateId | INT | FK → RouteTemplate.Id, NOT NULL | The route version active at creation |
| WorkOrderStatusId | INT | FK → WorkOrderStatus.Id, NOT NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| CompletedAt | DATETIME2(3) | NULL | |

### WorkOrderOperation

Individual operation execution — the actual step that happened.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| WorkOrderId | INT | FK → WorkOrder.Id, NOT NULL | |
| RouteStepId | INT | FK → RouteStep.Id, NOT NULL | The planned step |
| LocationId | INT | FK → Location.Id, NULL | Where it actually ran |
| OperationStatusId | INT | FK → OperationStatus.Id, NOT NULL | |
| SequenceNumber | INT | NOT NULL | |
| StartedAt | DATETIME2(3) | NULL | |
| CompletedAt | DATETIME2(3) | NULL | |
| OperatorId | INT | FK → AppUser.Id, NULL | |

### ProductionEvent

Immutable record of production output.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| WorkOrderOperationId | INT | FK → WorkOrderOperation.Id, NULL | |
| LotId | INT | FK → Lot.Id, NOT NULL | |
| LocationId | INT | FK → Location.Id, NOT NULL | |
| ItemId | INT | FK → Item.Id, NOT NULL | |
| GoodCount | INT | NOT NULL | |
| NoGoodCount | INT | NOT NULL, DEFAULT 0 | |
| OperatorId | INT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | INT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| RecordedAt | DATETIME2(3) | NOT NULL | |
| Remarks | VARCHAR(500) | NULL | |

### ConsumptionEvent

Records which source LOTs were consumed to produce output.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| WorkOrderOperationId | INT | FK → WorkOrderOperation.Id, NULL | |
| SourceLotId | INT | FK → Lot.Id, NOT NULL | What was consumed |
| ProducedLotId | INT | FK → Lot.Id, NULL | Output LOT (if applicable) |
| ProducedContainerId | INT | FK → Container.Id, NULL | Output container (if applicable) |
| ConsumedItemId | INT | FK → Item.Id, NOT NULL | |
| ProducedItemId | INT | FK → Item.Id, NOT NULL | |
| PieceCount | INT | NOT NULL | |
| LocationId | INT | FK → Location.Id, NOT NULL | |
| OperatorId | INT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | INT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| TrayId | INT | FK → ContainerTray.Id, NULL | |
| ProducedSerialNumber | VARCHAR(50) | NULL | |
| ConsumedAt | DATETIME2(3) | NOT NULL | |

### RejectEvent

Detailed reject/scrap records.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| ProductionEventId | INT | FK → ProductionEvent.Id, NULL | |
| LotId | INT | FK → Lot.Id, NOT NULL | |
| DefectCodeId | INT | FK → DefectCode.Id, NOT NULL | |
| Quantity | INT | NOT NULL | |
| ChargeToArea | VARCHAR(100) | NULL | Area responsible for the reject |
| Remarks | VARCHAR(500) | NULL | |
| OperatorId | INT | FK → AppUser.Id, NOT NULL | |
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
| Id | INT | PK | |
| Code | VARCHAR(20) | NOT NULL, UNIQUE | |
| Description | VARCHAR(500) | NOT NULL | |
| AreaLocationId | INT | FK → Location.Id, NOT NULL | Area (ISA-95 Area, organizational grouping) |
| IsExcused | BIT | NOT NULL, DEFAULT 0 | Affects OEE quality calculation |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### QualitySpec

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Name | VARCHAR(200) | NOT NULL | |
| ItemId | INT | FK → Item.Id, NULL | |
| OperationTemplateId | INT | FK → OperationTemplate.Id, NULL | |
| Description | VARCHAR(500) | NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

### QualitySpecVersion

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| QualitySpecId | INT | FK → QualitySpec.Id, NOT NULL | |
| VersionNumber | INT | NOT NULL | |
| EffectiveFrom | DATETIME2(3) | NOT NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | |
| CreatedBy | VARCHAR(100) | NOT NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

### QualitySpecAttribute

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| QualitySpecVersionId | INT | FK → QualitySpecVersion.Id, NOT NULL | |
| AttributeName | VARCHAR(100) | NOT NULL | |
| DataType | VARCHAR(50) | NOT NULL | |
| Uom | VARCHAR(20) | NULL | |
| TargetValue | DECIMAL(18,6) | NULL | |
| LowerLimit | DECIMAL(18,6) | NULL | |
| UpperLimit | DECIMAL(18,6) | NULL | |
| IsRequired | BIT | NOT NULL, DEFAULT 1 | |
| SortOrder | INT | NOT NULL, DEFAULT 0 | |

### QualitySample

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| LotId | INT | FK → Lot.Id, NOT NULL | |
| QualitySpecVersionId | INT | FK → QualitySpecVersion.Id, NOT NULL | Version active at time of sampling |
| LocationId | INT | FK → Location.Id, NULL | |
| SampleTrigger | VARCHAR(100) | NULL | SHIFT_START, DIE_CHANGE, TOOL_CHANGE, etc. |
| SampledByUserId | INT | FK → AppUser.Id, NOT NULL | |
| SampledAt | DATETIME2(3) | NOT NULL | |
| OverallResult | VARCHAR(20) | NOT NULL | PASS, FAIL |
| Remarks | VARCHAR(500) | NULL | |

### QualityResult

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| QualitySampleId | INT | FK → QualitySample.Id, NOT NULL | |
| QualitySpecAttributeId | INT | FK → QualitySpecAttribute.Id, NOT NULL | |
| MeasuredValue | VARCHAR(255) | NOT NULL | |
| Uom | VARCHAR(20) | NULL | |
| IsPass | BIT | NOT NULL | |

### QualityAttachment

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| QualitySampleId | INT | FK → QualitySample.Id, NULL | |
| NonConformanceId | INT | FK → NonConformance.Id, NULL | |
| FileName | VARCHAR(255) | NOT NULL | |
| FileType | VARCHAR(50) | NOT NULL | CSV, XLSX, PDF, PNG, JPG |
| FilePath | VARCHAR(500) | NOT NULL | |
| UploadedAt | DATETIME2(3) | NOT NULL | |
| UploadedBy | VARCHAR(100) | NOT NULL | |

### NonConformance

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| LotId | INT | FK → Lot.Id, NOT NULL | |
| DefectCodeId | INT | FK → DefectCode.Id, NOT NULL | |
| Quantity | INT | NOT NULL | |
| Disposition | VARCHAR(50) | NOT NULL | Pending, UseAsIs, Rework, Scrap, ReturnToVendor |
| Remarks | VARCHAR(500) | NULL | |
| ReportedByUserId | INT | FK → AppUser.Id, NOT NULL | |
| TerminalLocationId | INT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| ReportedAt | DATETIME2(3) | NOT NULL | |
| ResolvedAt | DATETIME2(3) | NULL | |
| ResolvedBy | VARCHAR(100) | NULL | |

### HoldEvent

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| LotId | INT | FK → Lot.Id, NOT NULL | |
| NonConformanceId | INT | FK → NonConformance.Id, NULL | Nullable — holds can be precautionary |
| HoldType | VARCHAR(50) | NOT NULL | Quality, CUSTOMER_COMPLAINT, PRECAUTIONARY |
| Reason | VARCHAR(500) | NOT NULL | |
| PlacedByUserId | INT | FK → AppUser.Id, NOT NULL | |
| PlacedAt | DATETIME2(3) | NOT NULL | |
| ReleasedByUserId | INT | FK → AppUser.Id, NULL | |
| ReleasedAt | DATETIME2(3) | NULL | |
| ReleaseRemarks | VARCHAR(500) | NULL | |

---

## 6. OEE Schema — MIXED SCOPE

> **Scope:**
> - `DowntimeReasonType`, `DowntimeReasonCode` — **MVP** (Downtime included)
> - `ShiftSchedule`, `Shift` — **MVP** (supports downtime context and production reporting)
> - `DowntimeEvent` — **MVP** (Downtime included)
> - `OeeSnapshot` — **FUTURE** — *OEE is not in current scope. Table retained because it is purely derivative of MVP data (downtime events + production events + shift instances). Activation requires only a scheduled calculation job — no new data capture.*

Downtime tracking, shift management, materialized OEE metrics.

### DowntimeReasonType

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Name | VARCHAR(100) | NOT NULL | Equipment, Miscellaneous, Mold, Quality, Setup, Unscheduled |

### DowntimeReasonCode

~660 reason codes.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Code | VARCHAR(20) | NOT NULL | |
| Description | VARCHAR(500) | NOT NULL | |
| AreaLocationId | INT | FK → Location.Id, NOT NULL | Area (organizational grouping) |
| DowntimeReasonTypeId | INT | FK → DowntimeReasonType.Id, NULL | |
| IsExcused | BIT | NOT NULL, DEFAULT 0 | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### ShiftSchedule

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Name | VARCHAR(100) | NOT NULL | |
| StartTime | TIME | NOT NULL | |
| EndTime | TIME | NOT NULL | |
| DaysOfWeek | VARCHAR(20) | NOT NULL | e.g., "MTWTF", "MTWRF" |
| EffectiveFrom | DATETIME2(3) | NOT NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | |

### Shift

Actual shift instances.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| ShiftScheduleId | INT | FK → ShiftSchedule.Id, NOT NULL | |
| ShiftDate | DATE | NOT NULL | |
| ActualStart | DATETIME2(3) | NOT NULL | |
| ActualEnd | DATETIME2(3) | NULL | |

### DowntimeEvent

Append-only. Never overwrite started_at.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| LocationId | INT | FK → Location.Id, NOT NULL | Machine |
| DowntimeReasonCodeId | INT | FK → DowntimeReasonCode.Id, NULL | May be assigned later |
| ShiftId | INT | FK → Shift.Id, NULL | |
| StartedAt | DATETIME2(3) | NOT NULL | |
| EndedAt | DATETIME2(3) | NULL | NULL while event is open |
| Source | VARCHAR(20) | NOT NULL | Manual, PLC |
| OperatorId | INT | FK → AppUser.Id, NULL | |
| ShotCount | INT | NULL | Die cast warm-up/setup shot count (when reason_type = Setup) |
| Remarks | VARCHAR(500) | NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |

> 🔶 **PENDING INTERNAL REVIEW — UJ-14:** Warm-up shots are tracked as a downtime sub-category (`DowntimeReasonType` = Setup) with the `ShotCount` column on the `DowntimeEvent` record itself. This keeps warm-up time and shot count in a single record. The Die Cast production screen records good/bad shot counts on the `ProductionEvent`; warm-up shot counts go here. Needs review with Ben.

### OeeSnapshot

Materialized OEE per machine per shift. Derivative, not system of record.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| LocationId | INT | FK → Location.Id, NOT NULL | Machine |
| ShiftId | INT | FK → Shift.Id, NOT NULL | |
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
| Id | INT | PK | |
| Code | VARCHAR(20) | NOT NULL, UNIQUE | ERROR, WARNING, INFO |
| Name | VARCHAR(100) | NOT NULL | |

### LogEventType

Normalized vocabulary for what happened. Shared across all log tables.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Code | VARCHAR(50) | NOT NULL, UNIQUE | LotCreated, LotMoved, ProductionRecorded, HoldPlaced, etc. |
| Name | VARCHAR(200) | NOT NULL | |
| Description | VARCHAR(500) | NULL | |

### LogEntityType

Normalized vocabulary for what was affected. Shared across operation_log and config_log.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | INT | PK | |
| Code | VARCHAR(50) | NOT NULL, UNIQUE | LOT, CONTAINER, WORK_ORDER, ITEM, LOCATION, etc. |
| Name | VARCHAR(200) | NOT NULL | |
| Description | VARCHAR(500) | NULL | |

### OperationLog

Every shop-floor action.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK, IDENTITY | |
| LoggedAt | DATETIME2(3) | NOT NULL | |
| UserId | INT | FK → AppUser.Id, NULL | |
| TerminalLocationId | INT | FK → Location.Id (Terminal), NULL | Terminal where action was performed |
| LocationId | INT | FK → Location.Id, NULL | Machine/location context |
| LogSeverityId | INT | FK → LogSeverity.Id, NOT NULL | |
| LogEventTypeId | INT | FK → LogEventType.Id, NOT NULL | |
| LogEntityTypeId | INT | FK → LogEntityType.Id, NOT NULL | |
| EntityId | INT | NULL | PK of the affected entity |
| Description | VARCHAR(1000) | NOT NULL | |
| OldValue | VARCHAR(500) | NULL | |
| NewValue | VARCHAR(500) | NULL | |

### ConfigLog

Engineering and admin configuration changes.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK, IDENTITY | |
| LoggedAt | DATETIME2(3) | NOT NULL | |
| UserId | INT | FK → AppUser.Id, NULL | |
| LogSeverityId | INT | FK → LogSeverity.Id, NOT NULL | |
| LogEventTypeId | INT | FK → LogEventType.Id, NOT NULL | |
| LogEntityTypeId | INT | FK → LogEntityType.Id, NOT NULL | |
| EntityId | INT | NULL | |
| Description | VARCHAR(1000) | NOT NULL | |
| Changes | VARCHAR(MAX) | NULL | JSON or structured diff |

### InterfaceLog

External system communications.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK, IDENTITY | |
| LoggedAt | DATETIME2(3) | NOT NULL | |
| SystemName | VARCHAR(50) | NOT NULL | AIM, PLC, MACOLA, INTELEX |
| Direction | VARCHAR(10) | NOT NULL | Inbound, OUTBOUND |
| LogEventTypeId | INT | FK → LogEventType.Id, NOT NULL | |
| Description | VARCHAR(1000) | NOT NULL | |
| RequestPayload | VARCHAR(MAX) | NULL | When high-fidelity logging enabled |
| ResponsePayload | VARCHAR(MAX) | NULL | |
| ErrorCondition | VARCHAR(200) | NULL | |
| ErrorDescription | VARCHAR(1000) | NULL | |
| IsHighFidelity | BIT | NOT NULL, DEFAULT 0 | |
