# MPP MES — Phased Development Plan: Configuration Tool

**Document:** MPP-MES-DEVPLAN-CONFIG-001
**Project:** Madison Precision Products MES Replacement
**Prepared By:** Blue Ridge Automation
**Version:** 0.1
**Date:** 2026-04-10

---

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 0.1 | 2026-04-10 | Blue Ridge Automation | Initial phased plan covering 8 configuration tool phases. Each phase scopes data model, API layer (Named Queries → stored procedures), and Perspective frontend requirements. Conceptual — no SQL scripts produced. |

---

## Purpose

This document scopes the **Configuration Tool** half of the MES build (Arc 1 from `MPP_MES_USER_JOURNEYS.md`). The Configuration Tool is the engineering- and admin-facing application that engineers, supervisors, and IT staff use to set up the plant model, item master, BOMs, routes, quality specs, and reference codes **before any LOT moves on the shop floor**.

It is intentionally separated from the Plant Floor build (Arc 2). Per the open-issues analysis on 2026-04-10, **none of the 29 open issues are blocking on Configuration Tool decisions** — Arc 1 is unblocked and can proceed in parallel with Arc 2 customer/Ben validation work.

This document is **conceptual ideation**, not implementation:
- No SQL scripts are produced.
- Stored procedures are listed by name and signature, not implemented.
- Ignition Perspective screens are described in functional terms, not designed.
- Effort estimates are deliberately omitted — these will come during planning with the new collaborator.

---

## Architecture Pattern

### Ignition vs. .NET — what's different about the API layer

In a traditional .NET MES application, the API layer would be a REST/gRPC service exposing CRUD endpoints, with an ORM (Entity Framework, Dapper) talking to the database. Authentication would be middleware, audit logging would be cross-cutting filters, and the frontend (React, Angular, WPF) would consume JSON.

In the Ignition Perspective architecture, **the "API layer" is Ignition Named Queries**:

- Each CRUD operation is an Ignition **Named Query** defined in the Gateway.
- Each Named Query is a **parameterized call to a stored procedure** in SQL Server. We never embed inline SQL in Perspective views or Gateway scripts (parameterization is non-negotiable per the security guidance in `sql_best_practices_mes.md`).
- The stored procedure is where business logic, validation, soft-delete logic, and audit logging live. The procedure writes a row to `Audit.ConfigLog` for every mutation it performs.
- Perspective views invoke Named Queries via `system.db.runNamedQuery()` (Gateway scripts) or via the **Named Query Binding** on a Perspective component (UI-driven).
- Authentication is handled by Ignition's built-in identity provider (AD + Ignition roles). The currently authenticated user is read from the session and passed to the stored procedure as `@AppUserId` for audit attribution.
- The `terminal_location_id` for Configuration Tool work is typically the engineering workstation's `Location` record (Cell-tier, definition = `Terminal`, parented under a `SupportArea` or office area).

**Standard Named Query → Stored Procedure mapping:**

| Operation | Named Query name | Stored Procedure | Notes |
|---|---|---|---|
| List | `<Entity>.List` | `<Entity>_List` | Optional filter parameters; returns rows |
| Get one | `<Entity>.Get` | `<Entity>_Get` | Single row by Id |
| Create | `<Entity>.Create` | `<Entity>_Create` | Returns new Id; writes ConfigLog row |
| Update | `<Entity>.Update` | `<Entity>_Update` | Validates, writes ConfigLog row |
| Soft-delete | `<Entity>.Deprecate` | `<Entity>_Deprecate` | Sets `DeprecatedAt`; writes ConfigLog row |
| New version | `<Entity>.CreateNewVersion` | `<Entity>_CreateNewVersion` | For versioned entities (BOMs, routes, quality specs) |

**Stored procedure naming convention:** `<Entity>_<Action>` — no Microsoft `sp_` prefix (avoids name-resolution overhead reserved for system procs). Pascal-case matching the table names per the project naming convention.

> **Note on `sql_best_practices_mes.md`:** That doc still references `snake_case` and `deprecated_at` lowercase. It predates the 2026-04-09 naming convention change to UpperCamelCase. It needs a refresh pass before the new collaborator starts — schedule that as a follow-up task.

---

## Cross-Cutting Concerns (Apply to Every Phase)

These rules apply to every entity in every phase. The plan does not repeat them per phase.

1. **Audit attribution.** Every Create/Update/Deprecate stored procedure takes `@AppUserId INT` and writes a row to `Audit.ConfigLog` capturing the user, the entity type and Id, the action, the old and new values where applicable, and the timestamp.
2. **Soft delete only.** Hard `DELETE` is forbidden for any table with downstream references. Use `DeprecatedAt` (set non-null to deactivate). Procedures should validate that an entity has no active dependents before deprecating.
3. **Versioning where applicable.** BOMs, route templates, quality specs, and operation templates all carry `VersionNumber` + `EffectiveFrom` + `DeprecatedAt`. Production records reference the version that was active at the time, not the latest.
4. **No reference loops.** Validate parent-child relationships server-side (e.g., a `Location.ParentLocationId` cannot equal its own `Id`, and the chain cannot cycle).
5. **Code-table-backed status.** Any status or type field is an FK to a code table, not a free-text column or magic integer.
6. **Parameterized procedure calls.** Named Queries always use named parameters. No string concatenation, no dynamic SQL on the Perspective side.
7. **Optimistic locking** on Update procedures: pass `@RowVersion` (or `@UpdatedAt`) and the procedure rejects the update if it doesn't match. Prevents lost updates from concurrent edits.
8. **Server-side validation.** Validation lives in the stored procedure, not just the Perspective form. The frontend may pre-validate for UX, but the proc is the authority.
9. **`AppUser` must exist before any other CRUD work.** Every Create/Update/Deprecate references a user. Phase 2 establishes this baseline before Phase 4+ depends on it.
10. **Perspective permissions.** Each Configuration Tool screen is gated by an Ignition role (Engineering, Admin). Operators cannot reach Configuration screens — enforced at the Perspective view security level, not just hidden.

---

## Phase Map and Dependencies

```
Phase 1 (Plant Model)
  ├──→ Phase 2 (Identity & Audit Foundation)        (depends only on Phase 1's Location for terminal attribution)
  │     └──→ Phase 3 (Reference Lookups)            (small fixed code tables; no real deps)
  │           ├──→ Phase 4 (Item Master & Container Config)
  │           │     ├──→ Phase 5 (Process Definition: Routes & Operations)
  │           │     │     └──→ Phase 6 (BOM Management)
  │           │     └──→ Phase 7 (Quality Configuration)
  │           └──→ Phase 8 (Operations Reference Data: Downtime, Shifts, OPC)
```

Phases 1, 2, and 3 are **foundation** and must run roughly in order. Phases 4–8 can be parallelized once 1–3 are done; the only hard dependency among them is Phase 6 (BOMs) needing Phase 4 (Items).

---

## Phase 1 — Foundation: Plant Model & Location Schema

**Goal:** Stand up the three-tier polymorphic location model and load the seed machine list. Without this, nothing else can be created.

**Dependencies:** None.

**Status:** Unblocked. Ready to start.

### Data Model

Tables involved (all from the `Location` schema, per `MPP_MES_DATA_MODEL.md` §1):

| Table | Role |
|---|---|
| `LocationType` | The 5 ISA-95 tiers (Enterprise, Site, Area, WorkCenter, Cell). Seeded at deployment, read-only thereafter. |
| `LocationTypeDefinition` | Polymorphic kinds within a tier (Terminal, DieCastMachine, CNCMachine, ProductionArea, etc.). Seeded with initial set, extensible by Engineering role. |
| `LocationAttributeDefinition` | Per-kind attribute schema (e.g., `Tonnage` for `DieCastMachine`, `IpAddress` for `Terminal`). |
| `Location` | Instances. Self-referential via `ParentLocationId`. Every row references one `LocationTypeDefinition`. |
| `LocationAttribute` | Attribute values per location. FK enforces that the attribute definition belongs to the location's own definition. |

**Seed data to load (Phase 1):**
- 5 `LocationType` rows (hard-coded at deployment)
- ~15 initial `LocationTypeDefinition` rows (per `MPP_MES_DATA_MODEL.md` Phase 1 seed table)
- ~20 initial `LocationAttributeDefinition` rows (Tonnage, NumberOfCavities, IpAddress, DefaultPrinter, etc.)
- The MPP plant root: 1 Enterprise row, 1 Site row, 5 Area rows (Die Cast, Trim Shop, Machine Shop, Production Control, Quality Control)
- All ~209 machines from `reference/seed_data/machines.csv` as `Location` records under appropriate Areas, with `LocationTypeDefinition` resolved from the machine's process (e.g., DieCast# → `DieCastMachine`, MS Machine → `CNCMachine`)
- Tonnage and cycle time values from `machines.csv` columns loaded as `LocationAttribute` rows

### API Layer (Named Queries → Stored Procedures)

`LocationType` (read-only):
- `LocationType_List` — returns all 5 tiers
- `LocationType_Get @Id`

`LocationTypeDefinition` (full CRUD):
- `LocationTypeDefinition_List @LocationTypeId NULL` — optional filter by tier
- `LocationTypeDefinition_Get @Id`
- `LocationTypeDefinition_Create @LocationTypeId, @Code, @Name, @Description, @AppUserId`
- `LocationTypeDefinition_Update @Id, @Name, @Description, @AppUserId`
- `LocationTypeDefinition_Deprecate @Id, @AppUserId` (rejects if any active `Location` references it)

`LocationAttributeDefinition` (full CRUD, scoped to a definition):
- `LocationAttributeDefinition_ListByDefinition @LocationTypeDefinitionId`
- `LocationAttributeDefinition_Get @Id`
- `LocationAttributeDefinition_Create @LocationTypeDefinitionId, @AttributeName, @DataType, @IsRequired, @DefaultValue, @Uom, @SortOrder, @Description, @AppUserId`
- `LocationAttributeDefinition_Update @Id, @AttributeName, @DataType, @IsRequired, @DefaultValue, @Uom, @SortOrder, @Description, @AppUserId`
- `LocationAttributeDefinition_Deprecate @Id, @AppUserId` (rejects if any `LocationAttribute` references it)

`Location` (full CRUD + tree queries):
- `Location_List @ParentLocationId NULL, @LocationTypeDefinitionId NULL` — children of a parent and/or filtered by kind
- `Location_GetTree @RootLocationId` — recursive CTE returning the hierarchy from a root down
- `Location_GetAncestors @LocationId` — recursive CTE returning ancestors from this location up to the Enterprise root
- `Location_GetDescendantsOfType @LocationId, @LocationTypeId` — e.g., "all Cells under the Die Cast Area"
- `Location_Get @Id` — returns location plus all its current `LocationAttribute` values
- `Location_Create @LocationTypeDefinitionId, @ParentLocationId, @Name, @Code, @Description, @AppUserId`
- `Location_Update @Id, @Name, @Code, @Description, @AppUserId`
- `Location_Deprecate @Id, @AppUserId` (rejects if any active `Lot.CurrentLocationId`, `LotMovement`, etc. reference it)

`LocationAttribute` (per-instance attribute values):
- `LocationAttribute_GetByLocation @LocationId` — returns all current values for a location
- `LocationAttribute_Set @LocationId, @LocationAttributeDefinitionId, @AttributeValue, @AppUserId` — upsert (insert or update one row); validates that the definition belongs to the location's definition
- `LocationAttribute_Clear @LocationId, @LocationAttributeDefinitionId, @AppUserId` — remove a value (set to NULL or delete the row, depending on whether definition is `IsRequired`)

Seed loading (one-time):
- `Location_BulkLoadMachinesFromSeed @CsvData NVARCHAR(MAX), @AppUserId` — accepts the `machines.csv` content as a delimited blob, parses, and creates `Location` rows under the appropriate Areas. Or loaded via a separate Ignition Gateway script that calls `Location_Create` per row. (Implementation choice deferred — both work.)

### Frontend (Perspective Views)

| View | Purpose |
|---|---|
| **Plant Hierarchy Browser** | Tree component (Perspective Tree or custom recursive accordion) showing the plant model from Enterprise → Site → Area → WorkCenter → Cell. Click a node to load its details in a side panel. Drag-to-reparent (with audit log) optional for v1. |
| **Location Details Panel** | Right-side drawer triggered by selecting a tree node. Shows Name, Code, Description, Type/Definition (read-only after create), Parent (read-only after create), and a **dynamic attributes form** rendered from the location's `LocationAttributeDefinition` set. Save invokes `Location_Update` and `LocationAttribute_Set` for each changed attribute. |
| **Add Location Modal** | Triggered from a tree node's context menu. Form: select a `LocationTypeDefinition` (dropdown filtered by what's valid as a child of the parent's tier), enter Name, Code, Description. Submit invokes `Location_Create`. |
| **Location Type Definition Editor** | Engineering/Admin only. List of all `LocationTypeDefinition` rows grouped by `LocationType`. Add/edit definitions, with an embedded sub-table of `LocationAttributeDefinition` rows (the attribute schema). |
| **Bulk Seed Loader** | One-time-use screen (or Gateway script) for loading `machines.csv` into `Location` rows. Shows a preview table from the CSV, lets the engineer map process types to definitions (e.g., MachDesc starting with "DieCast" → `DieCastMachine`), and triggers the bulk load. |

### Phase 1 complete when

- 5 `LocationType` rows seeded
- ~15 `LocationTypeDefinition` rows seeded with their attribute schemas
- The MPP plant tree exists from Enterprise root down to all 209 machines
- Tonnage, cycle time, and NumberOfCavities attribute values from `machines.csv` are loaded as `LocationAttribute` rows
- Engineering can browse the tree, click a machine, and see/edit its attributes
- Engineering can add a new `LocationTypeDefinition` (e.g., "TestStand" if a new kind is needed)
- Every mutation lands in `Audit.ConfigLog` with the user's clock number recorded

---

## Phase 2 — Identity & Audit Foundation

**Goal:** Establish `AppUser` records and the audit log lookup tables. Without this, no other phase can record `CreatedByUserId` / `UpdatedByUserId` references or audit log entries.

**Dependencies:** Phase 1 (need at least one `Location` of definition `Terminal` for engineering workstations).

**Status:** Unblocked. Should run immediately after Phase 1.

### Data Model

| Table | Role |
|---|---|
| `AppUser` | One row per MES user. Backed by AD identity. Captures clock number + PIN hash for shop-floor convenience login. Referenced for audit attribution everywhere. |
| `Audit.LogSeverity` | Code table: Info, Warning, Error, Critical. Seeded. |
| `Audit.LogEventType` | Code table: LotCreated, LotMoved, ProductionRecorded, ConfigChanged, etc. Seeded with the initial set, extensible. |
| `Audit.LogEntityType` | Code table: Location, Item, Lot, BOM, etc. Seeded from the entity table list. |
| `Audit.ConfigLog` | The destination for all Configuration Tool audit entries. Every mutation in every phase writes here. |

### API Layer

`AppUser`:
- `AppUser_List @IncludeDeprecated BIT = 0` — returns active users by default
- `AppUser_Get @Id`
- `AppUser_GetByAdAccount @AdAccount` — for session resolution at login
- `AppUser_GetByClockNumber @ClockNumber` — for shop-floor login
- `AppUser_Create @AdAccount, @DisplayName, @ClockNumber, @PinHash, @IgnitionRole, @AppUserId` (admin creates user; the `@AppUserId` is the admin's Id for audit)
- `AppUser_Update @Id, @DisplayName, @ClockNumber, @PinHash, @IgnitionRole, @AppUserId`
- `AppUser_Deprecate @Id, @AppUserId` — rejects if there are active Lot rows referencing this user as creator (or whatever soft-delete dependency rule applies)
- `AppUser_SetPin @Id, @PinHash, @AppUserId` — separate proc for password resets to avoid surfacing it in the general Update flow

Audit lookup tables (read-only after seeding):
- `LogSeverity_List`
- `LogEventType_List`
- `LogEntityType_List`

`Audit.ConfigLog` (read-only from Configuration Tool — written only by other procs):
- `ConfigLog_List @StartDate, @EndDate, @LogEntityTypeId NULL, @AppUserId NULL` — paged, filterable
- `ConfigLog_GetByEntity @LogEntityTypeId, @EntityId` — "show me everything that's ever been changed about this Item / Location / BOM"

### Frontend (Perspective Views)

| View | Purpose |
|---|---|
| **User Management** | Admin-only screen. List of `AppUser` rows with filter (active/deprecated). Add User modal: enter AD account, display name, clock number, optional initial PIN, Ignition role. Edit User modal: same fields plus "Deprecate" action. |
| **PIN Reset** | Self-service or admin: a separate flow to set a new PIN, with confirmation field. Hashes the PIN before calling `AppUser_SetPin`. Pin storage uses `pin_hash` (per `MPP_MES_DATA_MODEL.md`), not plaintext. |
| **Audit Log Browser** | Admin-only. Filterable view of `Audit.ConfigLog` with filters for entity type, user, date range. Click a row to expand and see the old/new values diff. Deep-link from any other Config Tool screen ("View audit history for this Item"). |

### Phase 2 complete when

- All MPP MES users exist in `AppUser` with their AD accounts and clock numbers
- The audit lookup tables are seeded
- The Audit Log Browser shows entries from Phase 1's seed loading work
- Every Phase 1 stored procedure has been retroactively wired to write `ConfigLog` rows with proper `AppUserId` attribution
- Admin can reset a user's PIN

---

## Phase 3 — Reference Lookups

**Goal:** Stand up the small fixed code tables that everything else FKs to. These are mostly seed-once-and-forget.

**Dependencies:** Phase 2 (need `AppUser` for audit attribution on the few that allow user-managed rows).

**Status:** Unblocked. Small phase — could be one engineer-day of CRUD scaffolding.

### Data Model

| Table | Role | Mutability |
|---|---|---|
| `Uom` | Units of measure (EA, LB, KG, IN, MM, PCS, etc.) | Engineering can add new ones |
| `ItemType` | Raw Material, Component, Sub-Assembly, Finished Good, Pass-Through | Mostly fixed; rarely extended |
| `LotOriginType` | Manufactured, Received, ReceivedOffsite | Fixed; seeded only |
| `LotStatusCode` | Good, Hold, Scrap, Closed | Fixed; seeded only |
| `ContainerStatusCode` | Open, Complete, Shipped, Hold, Void | Fixed; seeded only |
| `GenealogyRelationshipType` | Split, Merge, Consumption | Fixed; seeded only |
| `OperationStatus` | Pending, InProgress, Completed, Skipped | Fixed; seeded only |
| `WorkOrderStatus` | (per the workorder schema) | Fixed; seeded only |

### API Layer

For each of the above tables:

**Read-only tables (everything except `Uom` and `ItemType`):**
- `<Entity>_List`
- `<Entity>_Get @Id`

**Mutable tables (`Uom`, `ItemType`):**
- `<Entity>_List @IncludeDeprecated BIT = 0`
- `<Entity>_Get @Id`
- `<Entity>_Create @Code, @Name, @Description, @AppUserId`
- `<Entity>_Update @Id, @Name, @Description, @AppUserId`
- `<Entity>_Deprecate @Id, @AppUserId`

### Frontend (Perspective Views)

| View | Purpose |
|---|---|
| **Reference Data Manager** | A single screen with tabs (or a dropdown selector) for each of the lookup tables. Each tab is a simple list-with-edit grid. Read-only tables show a disabled "Add" button and an info note explaining they're seeded. |

This phase is intentionally minimal. The frontend is a generic CRUD grid that loads its columns from a config block per entity. Engineering rarely visits this screen — it's a "set it and forget it" phase.

### Phase 3 complete when

- All listed tables exist with their seed data loaded
- The Reference Data Manager screen lists every table and lets engineering CRUD the mutable ones
- Audit log entries appear for any mutations on `Uom` or `ItemType`

---

## Phase 4 — Item Master & Container Config

**Goal:** The "what we make" master data. Every part number that MPP produces or receives.

**Dependencies:** Phase 1 (locations referenced by `ItemLocation` later), Phase 2 (audit), Phase 3 (UOM, ItemType).

**Status:** Unblocked.

### Data Model

| Table | Role |
|---|---|
| `Item` | The master part list. Each row is one MPP part number. Carries description, item type, default sub-lot quantity, max lot size, unit weight, UOM, optional Macola cross-reference. |
| `ContainerConfig` | Per-finished-good packing rules: trays per container, parts per tray, serialized flag, dunnage code, customer code. Note OI-02 may add `ClosureMethod` and `TargetWeight` columns. |

### API Layer

`Item`:
- `Item_List @ItemTypeId NULL, @SearchText NULL, @IncludeDeprecated BIT = 0`
- `Item_Get @Id`
- `Item_GetByPartNumber @PartNumber` — for lookups during BOM/route construction
- `Item_Create @PartNumber, @ItemTypeId, @Description, @MacolaPartNumber, @DefaultSubLotQty, @MaxLotSize, @UomId, @UnitWeight, @WeightUomId, @AppUserId`
- `Item_Update @Id, @Description, @MacolaPartNumber, @DefaultSubLotQty, @MaxLotSize, @UomId, @UnitWeight, @WeightUomId, @AppUserId` (note: `PartNumber` and `ItemTypeId` are immutable after create — would create downstream chaos to change them; if the engineer needs to change a part number, they deprecate the old one and create a new one)
- `Item_Deprecate @Id, @AppUserId` — rejects if there are active `Bom`, `RouteTemplate`, `ItemLocation`, or `ContainerConfig` references

`ContainerConfig`:
- `ContainerConfig_GetByItem @ItemId` — usually one config per item
- `ContainerConfig_Create @ItemId, @TraysPerContainer, @PartsPerTray, @IsSerialized, @DunnageCode, @CustomerCode, @AppUserId`
- `ContainerConfig_Update @Id, @TraysPerContainer, @PartsPerTray, @IsSerialized, @DunnageCode, @CustomerCode, @AppUserId`
- `ContainerConfig_Deprecate @Id, @AppUserId`

### Frontend (Perspective Views)

| View | Purpose |
|---|---|
| **Item Master List** | Filterable table of all items: search by part number, filter by item type, toggle deprecated visibility. Columns: PartNumber, Description, ItemType, UOM, MacolaPartNumber, UnitWeight, DefaultSubLotQty. Click a row to open the Item Editor. |
| **Item Editor** | Form view for create/update. Layout: left column = required fields (PartNumber, ItemType, UOM); right column = optional (Macola ref, weight, sub-lot qty, max lot size). Bottom: tabs for "Container Config", "BOM" (Phase 6 link), "Routes" (Phase 5 link), "Quality Specs" (Phase 7 link), "Audit History". |
| **Container Config Sub-tab** | Embedded in Item Editor. For finished goods only — disable for raw materials and components. Form fields: trays per container, parts per tray, serialized flag, dunnage code, customer code. |
| **Item Picker (reusable component)** | Modal/inline picker used throughout the rest of the Configuration Tool (BOMs, routes, eligibility map). Searchable by part number or description. Returns the `Item.Id`. |

### Phase 4 complete when

- Every existing MPP part number is loaded into `Item` (initial load — manual via the Item Editor or bulk-load if MPP has an Excel export)
- Every finished good has a `ContainerConfig` record
- Engineering can create a new part, edit an existing one, deprecate one no longer in production
- The Item Picker component is reusable from the rest of the Configuration Tool

---

## Phase 5 — Process Definition: Routes & Operations

**Goal:** Define how each part flows through the plant — which operations, in what order, at which areas, collecting what data.

**Dependencies:** Phase 1 (Locations and Areas), Phase 4 (Items), Phase 2 (audit).

**Status:** Unblocked.

### Data Model

| Table | Role |
|---|---|
| `RouteTemplate` | The route header per item. Versioned. Each row links one `Item` to a route version. |
| `RouteStep` | The ordered steps in a route. Each step references an `OperationTemplate`. |
| `OperationTemplate` | The reusable definition of an operation: name, area, data collection flags (collects_die_info, collects_cavity_info, collects_weight, requires_material_verification, etc.). Versioned independently of routes. |
| `ItemLocation` | The eligibility map: which items can run on which Cells. |

Note: per FDS-03-009, route steps do **not** prescribe a specific machine — they reference an `OperationTemplate` which has an `AreaLocationId`, and the operator picks the Cell at runtime from the `ItemLocation` eligibility set.

### API Layer

`OperationTemplate` (versioned):
- `OperationTemplate_List @AreaLocationId NULL, @ActiveOnly BIT = 1`
- `OperationTemplate_Get @Id`
- `OperationTemplate_Create @Name, @AreaLocationId, @CollectsDieInfo, @CollectsCavityInfo, @CollectsWeight, @CollectsGoodCount, @CollectsBadCount, @RequiresMaterialVerification, @RequiresSerialNumber, @AppUserId` — creates version 1
- `OperationTemplate_CreateNewVersion @ParentOperationTemplateId, ..., @EffectiveFrom, @AppUserId` — creates a new version, does NOT modify the previous one
- `OperationTemplate_Deprecate @Id, @AppUserId` — soft-delete a specific version

`RouteTemplate` (versioned):
- `RouteTemplate_ListByItem @ItemId, @ActiveOnly BIT = 1` — usually one active route per item
- `RouteTemplate_Get @Id` — returns route header plus all its steps in order
- `RouteTemplate_GetActiveForItem @ItemId, @AsOfDate DATETIME2 = NULL` — used by production code to pick the version active at a given time
- `RouteTemplate_Create @ItemId, @Name, @EffectiveFrom, @AppUserId` — creates an empty route version 1
- `RouteTemplate_CreateNewVersion @ParentRouteTemplateId, @EffectiveFrom, @AppUserId`
- `RouteTemplate_Deprecate @Id, @AppUserId`

`RouteStep`:
- `RouteStep_ListByRoute @RouteTemplateId`
- `RouteStep_Add @RouteTemplateId, @SequenceNumber, @OperationTemplateId, @AppUserId`
- `RouteStep_Update @Id, @SequenceNumber, @OperationTemplateId, @AppUserId`
- `RouteStep_Remove @Id, @AppUserId`
- `RouteStep_Reorder @RouteTemplateId, @StepIds NVARCHAR(MAX) /*comma-delimited new order*/, @AppUserId` — drag-and-drop reorder support

`ItemLocation` (eligibility map):
- `ItemLocation_ListByItem @ItemId` — "where can this part run?"
- `ItemLocation_ListByLocation @LocationId` — "what parts can run on this machine?"
- `ItemLocation_Add @ItemId, @LocationId, @AppUserId`
- `ItemLocation_Remove @ItemId, @LocationId, @AppUserId`

### Frontend (Perspective Views)

| View | Purpose |
|---|---|
| **Operation Template Library** | List of all operation templates grouped by Area. Add new template button. Click a template to see/edit its data collection flags. Shows version history for each template. |
| **Route Builder** | Master-detail view tied to an Item. Left: list of routes for the item with version dropdown. Right: ordered list of steps, each showing the operation template name and its area. Drag-and-drop to reorder steps, button to insert/remove steps. "New Version" button creates a new route version (preserving the old). |
| **Eligibility Map Editor** | Two-pane view: items on the left, locations on the right, with a center matrix showing which items are eligible at which Cells. Click a cell in the matrix to toggle eligibility. Filter both lists by area or part type. |
| **Operation Template Editor** | Form view triggered from the Library. Fields for all the data collection flags (boolean switches), area dropdown (filtered to Area-tier locations), name, description. "Save as new version" creates a fresh version. |

### Phase 5 complete when

- Every active MPP item has at least one `RouteTemplate` with at least one `RouteStep`
- The `ItemLocation` eligibility map is populated for every item-cell combination MPP runs
- Engineering can create a new route version when an existing route changes — old production records still reference the old version
- Operators (in Phase 4 of the Plant Floor build) will be able to query "which Cells can run this Item?" via `ItemLocation_ListByItem`

---

## Phase 6 — BOM Management

**Goal:** Versioned bills of material. Required for assembly operations to validate material consumption.

**Dependencies:** Phase 4 (Items).

**Status:** Unblocked.

### Data Model

| Table | Role |
|---|---|
| `Bom` | Header table. One row per `(ParentItemId, VersionNumber)`. Versioned. |
| `BomLine` | Component lines. Each row = one component item with quantity per parent. |

### API Layer

`Bom`:
- `Bom_ListByParentItem @ParentItemId, @ActiveOnly BIT = 1`
- `Bom_Get @Id` — returns header plus all lines in sort order
- `Bom_GetActiveForItem @ParentItemId, @AsOfDate DATETIME2 = NULL`
- `Bom_Create @ParentItemId, @VersionNumber, @EffectiveFrom, @AppUserId`
- `Bom_CreateNewVersion @ParentBomId, @EffectiveFrom, @AppUserId` — copies all lines from the prior version
- `Bom_Deprecate @Id, @AppUserId`

`BomLine`:
- `BomLine_ListByBom @BomId`
- `BomLine_Add @BomId, @ChildItemId, @QtyPer, @UomId, @SortOrder, @AppUserId`
- `BomLine_Update @Id, @QtyPer, @UomId, @SortOrder, @AppUserId`
- `BomLine_Remove @Id, @AppUserId`

### Frontend (Perspective Views)

| View | Purpose |
|---|---|
| **BOM Editor** | Master-detail view tied to an Item (linked from the Item Editor in Phase 4). Left: BOM version selector with effective dates. Right: editable grid of `BomLine` rows — child item picker (reuses the Phase 4 Item Picker), quantity per, UOM, sort order. "New Version" button copies the current BOM and bumps the version. |
| **BOM Comparison** | View two versions of the same BOM side-by-side, showing line-level diffs (added, removed, changed quantities). Useful before activating a new version. |
| **Where-Used Report** | "Show me every BOM that uses this child item." Useful when deprecating a part — engineering can see what would be impacted. |

### Phase 6 complete when

- Every assembled MPP product has at least one BOM with at least one component line
- Engineering can create a new BOM version when a design change happens, and the old version is preserved
- The Where-Used report is functional

---

## Phase 7 — Quality Configuration

**Goal:** Define quality specifications and load defect codes. Quality specs are versioned per item/operation; defect codes are reference data.

**Dependencies:** Phase 1 (Areas referenced by defect codes), Phase 4 (Items referenced by quality specs), Phase 5 (Operation Templates optionally referenced by quality specs).

**Status:** Unblocked.

### Data Model

| Table | Role |
|---|---|
| `QualitySpec` | Header per spec — name, optional item, optional operation template. |
| `QualitySpecVersion` | Versioned spec body. |
| `QualitySpecAttribute` | The measurable attributes per spec version: name, data type, target value, lower limit, upper limit, UOM, sample trigger. |
| `DefectCode` | Reference list: code, description, area, excused flag. Loaded from `defect_codes.csv` (153 rows). |

### API Layer

`QualitySpec` (versioned):
- `QualitySpec_List @ItemId NULL, @OperationTemplateId NULL`
- `QualitySpec_Get @Id` — header plus active version plus attributes
- `QualitySpec_Create @Name, @ItemId NULL, @OperationTemplateId NULL, @AppUserId`
- `QualitySpec_Deprecate @Id, @AppUserId`

`QualitySpecVersion`:
- `QualitySpecVersion_ListBySpec @QualitySpecId`
- `QualitySpecVersion_GetActive @QualitySpecId, @AsOfDate DATETIME2 = NULL`
- `QualitySpecVersion_Create @QualitySpecId, @VersionNumber, @EffectiveFrom, @AppUserId` — creates an empty version
- `QualitySpecVersion_CreateNewVersion @ParentVersionId, @EffectiveFrom, @AppUserId` — copies attributes
- `QualitySpecVersion_Deprecate @Id, @AppUserId`

`QualitySpecAttribute`:
- `QualitySpecAttribute_ListByVersion @QualitySpecVersionId`
- `QualitySpecAttribute_Add @QualitySpecVersionId, @AttributeName, @DataType, @TargetValue, @LowerLimit, @UpperLimit, @UomId, @SampleTrigger, @SortOrder, @AppUserId`
- `QualitySpecAttribute_Update @Id, ..., @AppUserId`
- `QualitySpecAttribute_Remove @Id, @AppUserId`

`DefectCode` (loaded from seed data):
- `DefectCode_List @AreaLocationId NULL, @IncludeDeprecated BIT = 0`
- `DefectCode_Get @Id`
- `DefectCode_Create @Code, @Description, @AreaLocationId, @IsExcused, @AppUserId`
- `DefectCode_Update @Id, @Description, @AreaLocationId, @IsExcused, @AppUserId`
- `DefectCode_Deprecate @Id, @AppUserId`
- `DefectCode_BulkLoadFromSeed @CsvData NVARCHAR(MAX), @AppUserId` — initial load from `defect_codes.csv`

### Frontend (Perspective Views)

| View | Purpose |
|---|---|
| **Quality Spec Library** | List of all specs with filters by item, by operation. Click to open the editor. |
| **Quality Spec Editor** | Master-detail view. Left: spec header + version selector. Right: editable grid of attributes (name, data type, target, lower limit, upper limit, UOM, sample trigger). "New Version" button. |
| **Defect Code Manager** | List of all defect codes grouped by area. Filter by area, search by code or description. Add/edit/deprecate codes. Bulk-load button (one-time) for the seed CSV. |

### Phase 7 complete when

- 153 defect codes from `defect_codes.csv` are loaded into `DefectCode`
- Engineering has created at least one quality spec for the highest-volume items
- The spec versioning workflow is verified — production records will FK to the active version at run time

---

## Phase 8 — Operations Reference Data

**Goal:** Load downtime reason codes, configure shift schedules, and catalog OPC tags. Mostly seed loading from the CSVs we extracted.

**Dependencies:** Phase 1 (Areas referenced by downtime codes), Phase 2 (audit).

**Status:** Unblocked.

### Data Model

| Table | Role |
|---|---|
| `DowntimeReasonType` | The 6 fixed types: Equipment, Miscellaneous, Mold, Quality, Setup, Unscheduled. Seeded. |
| `DowntimeReasonCode` | The ~660 reason codes (353 active rows in our CSV) by area and type. Loaded from `downtime_reason_codes.csv`. |
| `ShiftSchedule` | Named shift patterns: First Shift 6am–2pm M-F, Second Shift 2pm–10pm, Weekend OT, etc. |
| `Shift` | Actual instances created from schedules (this is mostly populated at runtime; configuration tool only manages the schedules). |
| (no SQL table for OPC tags) | OPC tag catalog from `opc_tags.csv` drives Ignition OPC connection configuration, not a SQL table. |

### API Layer

`DowntimeReasonType`:
- `DowntimeReasonType_List`

`DowntimeReasonCode`:
- `DowntimeReasonCode_List @AreaLocationId NULL, @DowntimeReasonTypeId NULL, @IncludeDeprecated BIT = 0`
- `DowntimeReasonCode_Get @Id`
- `DowntimeReasonCode_Create @Code, @Description, @AreaLocationId, @DowntimeReasonTypeId, @IsExcused, @AppUserId`
- `DowntimeReasonCode_Update @Id, @Description, @AreaLocationId, @DowntimeReasonTypeId, @IsExcused, @AppUserId`
- `DowntimeReasonCode_Deprecate @Id, @AppUserId`
- `DowntimeReasonCode_BulkLoadFromSeed @CsvData NVARCHAR(MAX), @AppUserId`

`ShiftSchedule`:
- `ShiftSchedule_List @ActiveOnly BIT = 1`
- `ShiftSchedule_Get @Id`
- `ShiftSchedule_Create @Name, @StartTime, @EndTime, @DaysOfWeek, @EffectiveFrom, @AppUserId`
- `ShiftSchedule_Update @Id, @Name, @StartTime, @EndTime, @DaysOfWeek, @EffectiveFrom, @AppUserId`
- `ShiftSchedule_Deprecate @Id, @AppUserId`

### Frontend (Perspective Views)

| View | Purpose |
|---|---|
| **Downtime Reason Code Manager** | List grouped by area, with filter by type. Add/edit/deprecate codes. Bulk-load button (one-time) for seed CSV. Note the parse warning about ~25 codes with empty `TypeId` — those should be flagged in the UI for engineering to assign types before going live. |
| **Shift Schedule Editor** | List of named shift schedules with start/end times, days of week, effective date. Calendar-style preview for the next 2 weeks. |
| **OPC Tag Reference** | A read-only browser of `opc_tags.csv` content. NOT a SQL table — this view loads the CSV directly or pulls it from the Ignition resource folder. Helps engineering see what tags are defined for OmniServer/TOPServer when setting up new lines or troubleshooting. |

### Phase 8 complete when

- 6 `DowntimeReasonType` rows seeded
- 353 `DowntimeReasonCode` rows loaded from the CSV
- Engineering has reviewed and assigned types to the ~25 codes with empty `TypeId` (per `parse_warnings.md`)
- At least the 3 standard MPP shift schedules are defined (First, Second, Weekend OT)
- The OPC Tag Reference is browseable as documentation

---

## Out of Scope

Items intentionally excluded from this Configuration Tool plan:

- **All Plant Floor screens** (Arc 2): LOT creation, production recording, downtime entry, hold management, sort cage, etc. — covered by a separate Phased Plan to be written.
- **Reporting**: production reports, downtime reports, OEE roll-ups. These are a separate effort that consumes data from the configured master.
- **External integrations**: Macola (FUTURE), Intelex (FUTURE), AIM (Plant Floor concern, not Configuration Tool).
- **PLC integration setup**: TOPServer/OmniServer connection config lives in Ignition's OPC settings, not the Configuration Tool. The OPC Tag Reference (Phase 8) is documentation, not configuration.
- **Tool Life tracking** (OI-10): Open question on whether it's `LocationAttribute` or a dedicated table. Once resolved, it slots into Phase 1 (if attribute) or a new sub-phase under Phase 1 (if dedicated table).
- **WO management screens** (OI-07): Resolved as MVP-Lite — auto-generated, invisible to operators, no WO screens. The `workorder` schema tables exist and Plant Floor production code populates them, but the Configuration Tool has no `WorkOrder_Create` proc or screen.
- **Audit Log advanced search**: Phase 2 covers basic browsing. Saved searches, scheduled audit reports, and compliance exports are a future enhancement.

---

## Open Items That Could Affect This Plan

None of these block Phase 1 from starting, but they should be tracked and may shift scope when resolved:

- **OI-02 (Weight container closure):** If MPP confirms the recommendation, Phase 4 (Container Config) gets two new fields: `ClosureMethod` and `TargetWeight`. The procs and screen forms add those fields. Small impact.
- **OI-05 (LOT merge business rules):** If the rules end up configurable, a new sub-phase appears (likely under Phase 6 or as a Phase 7 addition) to define and store merge rule sets. If hard-coded, no Configuration Tool impact.
- **OI-10 (Tool Life tracking):** Determines whether tool-life data lands in `LocationAttribute` (Phase 1, no extra work) or a new dedicated `ToolLife` table (new sub-phase under Phase 1).
- **`sql_best_practices_mes.md` refresh:** That document still references `snake_case` and `deprecated_at` lowercase from before the 2026-04-09 naming convention change. It needs an update before the new collaborator starts following it as a guide.

---

## Related Documents

| Document | Relevance |
|---|---|
| `MPP_MES_USER_JOURNEYS.md` | Arc 1 narrative — the configuration tool experience this plan builds toward |
| `MPP_MES_DATA_MODEL.md` | Authoritative table and column reference for every entity in this plan |
| `MPP_MES_FDS.md` | Numbered functional requirements; this plan implements §2 (Plant Model), §3 (Master Data), §4 (Auth), §8.8 (Quality Spec Management), §9.4 (Shifts) |
| `MPP_MES_ERD.html` | Visual schema reference |
| `reference/seed_data/` | CSVs for Phase 1, 7, 8 bulk-load steps (machines, defect codes, downtime codes, OPC tags) |
| `reference/seed_data/parse_warnings.md` | Notes on partial machine rows (Phase 1) and untyped downtime codes (Phase 8) that need engineering review |
| `sql_best_practices_mes.md` | Referenced for soft-delete pattern, versioning pattern, code-table-backed status. Note: needs UpperCamelCase update before collaborator onboarding. |
