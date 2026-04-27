# Tool Management — Design Spec (Phase B of the 2026-04-20 OI review refactor)

**Status:** Draft for review — shipped in Phase G (commit `534f55c`). Retained as a design record; supersessions noted inline.
**Owner:** Jacques Potgieter
**Date:** 2026-04-21 (original); OI-07 correction addendum 2026-04-24
**Supersedes:** OI-10 in `MPP_MES_Open_Issues_Register.md` v2.4
**Implementation target:** Phase G SQL migration `0010_phase9_tools_and_workorder.sql` (shipped 2026-04-22)

> **⚠ Correction note added 2026-04-24 (OIR v2.9 / Data Model v1.9b / FDS v0.11b):** This spec originally described `Workorder.WorkOrderType` seeded with 3 rows (`Demand` / `Maintenance` / `Recipe`) and called out `WorkOrder.ToolId` as populated only for `Maintenance` WOs. Jacques clarified that the 2026-04-20 meeting note behind that taxonomy was mis-recorded — the "Recipe" line was describing the Production flow (the pre-existing MVP-LITE bookkeeping). Under MPP's actual taxonomy, the only active WO type is **Production** (renamed from "Demand"). `Demand` (planned PM) and `Maintenance` (emergency) are genuinely separate future WO types but are OUT OF SCOPE for this project. Recipe is deleted. The code-table mechanism remains as a future hook. See OIR OI-07 for the full narrative. The strike-through edits below mark the superseded lines; the shipped Phase G migration's 3-row seed is corrected via a follow-up versioned migration (queued, not yet executed).

## Purpose

Promote **Tool** from a `LocationAttribute` historical snapshot (the v1.4 pattern, where `Workorder.ProductionEvent.DieIdentifier` is just a `NVARCHAR(50)` copy of the machine's current die attribute) to a **first-class polymorphic subsystem** modelled on the existing `LocationType / LocationTypeDefinition / LocationAttributeDefinition` pattern. Covers dies, cutters, jigs, gauges, assembly fixtures, trim tools — any discrete piece of production equipment that:

- has its own identity and lifecycle independent of the Cell it's mounted on,
- can be checked in / out of Cells (mounted, removed, swapped),
- carries type-specific attributes (cycle time for dies, insert count for cutters, etc.),
- can optionally have cavities (dies do; most others don't),
- may be the target of a (FUTURE) maintenance work order.

## Background — decisions driving this design

These came out of the 2026-04-20 MPP review and the 2026-04-21 Phase B Q&A with Jacques. Each shapes a schema choice:

| Decision | Source | Schema impact |
|---|---|---|
| Polymorphism across Die Cast / Machining / Assembly / Trim tools | Jacques 2026-04-21 Q2 | `ToolType` + `ToolAttributeDefinition` mirrors Location pattern |
| Cavities are registered, don't get replaced; mid-life failures either shoot-and-scrap (operational, no state) or get shut off (persistent Closed) | Jacques 2026-04-21 Q1 | `ToolCavity` child table, Status = Active / Closed / Scrapped |
| Die rank is a property of the whole die, not the cavity | Jacques 2026-04-21 Q2 | `DieRankId` FK on `Tool` (nullable, Die-type only) |
| Blocks are NOT a tool concept — they're location-eligibility, which the existing ISA-95 tier + `Parts.ItemLocation` already handles | Jacques 2026-04-21 Q3 | **Nothing.** Phase D / OI-08 addenda confirms hierarchical resolution. |
| Maintenance WOs are FUTURE; only need a clean schema hook | Jacques 2026-04-21 Q4 | Add `WorkOrderType` code table + nullable `ToolId` on `Workorder.WorkOrder` |
| Shot counts derive from `ProductionEvent`, no live counter | Jacques 2026-04-21 Q5 | No `ToolShotEvent` table, no counter column |
| Tool-life threshold alarms are FUTURE | Jacques 2026-04-21 Q4 follow-up | Scheduled Gateway Script pattern; schema unchanged |
| Die-rank compatibility matrix is TBD (MPP Quality owes) | Jacques 2026-04-21 Q6 | `DieRank` + `DieRankCompatibility` code tables seeded empty; merge rule rejects with supervisor override until populated |
| Merge validation default: reject with override | Jacques 2026-04-21 Q5 | Merge proc rejects cross-die merges; FDS-04-007 elevation prompt unlocks |

## Scope

**In scope (MVP):**
- Tool, ToolType, ToolAttributeDefinition, ToolAttribute, ToolCavity
- ToolAssignment (check-in / out history)
- Tool status + cavity status code tables
- Die rank tables (empty seed)
- Configuration Tool CRUD for the above (Phase G SQL produces the procs; Arc 1 frontend consumes them)
- Workorder.WorkOrderType code table; `Workorder.WorkOrder` gains `WorkOrderTypeId` + nullable `ToolId`

**Out of scope (FUTURE):**
- Maintenance WO flow / screens / procs (schema hook only)
- Tool-life threshold alarms / scheduled script (FUTURE — scheduled Gateway Script pattern when MPP asks for it)
- Tool transfer history across plants (single-plant MVP)
- Block / location-group concepts (handled by the existing ISA-95 hierarchy via `Parts.ItemLocation`, per Phase D / OI-08 addenda)

**Not in this spec:**
- The Plant Floor screens that consume these entities (operator tool check-in/out, tool changeover flow) — those land in the Arc 2 Plant Floor phased plan
- The SQL migration itself — Phase G writes `0010_phase9_tools_and_workorder.sql`
- Test suites — written alongside Phase G

## Design

### Polymorphic pattern (mirrors Location)

The existing Location model:

```
Location.LocationType           -- 5 ISA-95 tiers (Enterprise, Site, Area, WorkCenter, Cell)
Location.LocationTypeDefinition -- polymorphic kinds under each tier (DieCastMachine, CNCMachine, Terminal, ...)
Location.LocationAttributeDefinition -- attribute schema per Definition
Location.Location               -- concrete rows
Location.LocationAttribute      -- attribute values
```

The Tools model:

```
Tools.ToolType        -- polymorphic kinds (Die, Cutter, Jig, Gauge, AssemblyFixture, TrimTool, ...)
Tools.ToolAttributeDefinition   -- attribute schema per kind
Tools.Tool                      -- concrete tools
Tools.ToolAttribute             -- attribute values
Tools.ToolCavity                -- cavity children (only for HasCavities types)
Tools.ToolAssignment            -- check-in/out history against Cells
```

`ToolType` is a **grouping**, not a hierarchy. Tools don't have an ISA-95-style tier structure (Enterprise → Site → Area → WorkCenter → Cell) — they're just categorised. That's why there's no separate "TypeDefinition" table like Location has; Location needed two tables because it has both a fixed hierarchy AND polymorphic kinds within the hierarchy. Tools have only the polymorphic kind. If a sub-category ever becomes useful (e.g., splitting "Die" into "Single-Cavity Die" vs "Multi-Cavity Die"), that's the point to introduce a `ToolType`-under-`ToolType` or a `ToolSubType` table — not now.

### Table specifications

#### `Tools.ToolType`

Polymorphic kinds. Seeded at migration time; read-only in MVP (no CRUD procs), following the precedent set by `Location.LocationType` / `Location.LocationTypeDefinition`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | `Die`, `Cutter`, `Jig`, `Gauge`, `AssemblyFixture`, `TrimTool` |
| Name | NVARCHAR(100) | NOT NULL | Display name |
| Description | NVARCHAR(500) | NULL | |
| Icon | NVARCHAR(100) | NULL | Perspective tree component icon (matches `LocationTypeDefinition.Icon` pattern) |
| HasCavities | BIT | NOT NULL DEFAULT 0 | `Tools.ToolCavity` rows are only valid for Tools whose type has this = 1 |
| SortOrder | INT | NOT NULL DEFAULT 0 | UI ordering |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | Soft delete |

**Seed data** (Phase G migration):

| Code | Name | HasCavities | Notes |
|---|---|---|---|
| Die | Die Cast Die | 1 | Dies used on die cast machines |
| Cutter | Machining Cutter | 0 | Tool heads / inserts on CNC machines |
| Jig | Assembly Jig | 0 | Fixtures on assembly stations |
| Gauge | Inspection Gauge | 0 | Measurement tools |
| AssemblyFixture | Assembly Fixture | 0 | Trim-shop and assembly fixtures |
| TrimTool | Trim Shop Tool | 0 | Trim-specific tooling |

#### `Tools.ToolAttributeDefinition`

Attribute schema per type. Mirrors `Location.LocationAttributeDefinition`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| ToolTypeId | BIGINT | FK → ToolType, NOT NULL | Which kind this attribute applies to |
| Code | NVARCHAR(50) | NOT NULL | Attribute code (e.g., `CycleTimeSec`, `Tonnage`, `InsertCount`) |
| Name | NVARCHAR(100) | NOT NULL | Display label |
| DataType | NVARCHAR(20) | NOT NULL | `String`, `Integer`, `Decimal`, `Boolean`, `Date` (matches existing `LocationAttributeDefinition.DataType` values) |
| IsRequired | BIT | NOT NULL DEFAULT 0 | |
| SortOrder | INT | NOT NULL DEFAULT 0 | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

UNIQUE `(ToolTypeId, Code)` filtered on `DeprecatedAt IS NULL`.

No seed data in the migration — attribute definitions get added via the Configuration Tool over time. The Phase B work ships the table empty; engineering adds `CycleTimeSec`, `CavityCount`, `Tonnage`, etc. as real tools arrive.

#### `Tools.Tool`

Concrete tools. The system of record for tool identity.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| ToolTypeId | BIGINT | FK → ToolType, NOT NULL | Polymorphic type |
| Code | NVARCHAR(50) | NOT NULL, UNIQUE | Die number, cutter ID, etc. (e.g., `DC-042`) |
| Name | NVARCHAR(100) | NOT NULL | Human-friendly name |
| Description | NVARCHAR(500) | NULL | |
| DieRankId | BIGINT | FK → Tools.DieRank, NULL | Die-type only; NULL for all other types. Application-level validation enforces this. |
| StatusCodeId | BIGINT | FK → Tools.ToolStatusCode, NOT NULL | Active / UnderRepair / Scrapped / Retired |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| CreatedByUserId | BIGINT | FK → Location.AppUser, NOT NULL | |
| UpdatedByUserId | BIGINT | FK → Location.AppUser, NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | Soft delete (separate from `StatusCode = Retired` — Retired is the business state; DeprecatedAt is the row-lifecycle state) |

No shot counter. Derived from `Workorder.ProductionEvent` group-by.

#### `Tools.ToolAttribute`

Attribute values. Mirrors `Location.LocationAttribute`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| ToolId | BIGINT | FK → Tool, NOT NULL | |
| ToolAttributeDefinitionId | BIGINT | FK → ToolAttributeDefinition, NOT NULL | |
| Value | NVARCHAR(500) | NOT NULL | Stored as text; interpreted per definition's `DataType` |
| UpdatedAt | DATETIME2(3) | NULL | |
| UpdatedByUserId | BIGINT | FK → Location.AppUser, NULL | |

UNIQUE `(ToolId, ToolAttributeDefinitionId)`.

#### `Tools.ToolCavity`

Child of Tool. Only valid for Tools whose type has `HasCavities = 1`. Application-level validation enforces.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| ToolId | BIGINT | FK → Tool, NOT NULL | Parent die |
| CavityNumber | INT | NOT NULL | 1, 2, 3, … up to the die's cavity count |
| StatusCodeId | BIGINT | FK → Tools.ToolCavityStatusCode, NOT NULL | Active / Closed / Scrapped |
| Description | NVARCHAR(500) | NULL | Optional per-cavity notes (e.g., "small porosity tendency") |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |
| CreatedByUserId | BIGINT | FK → Location.AppUser, NOT NULL | |
| UpdatedByUserId | BIGINT | FK → Location.AppUser, NULL | |
| DeprecatedAt | DATETIME2(3) | NULL | Soft delete |

UNIQUE `(ToolId, CavityNumber)` filtered on `DeprecatedAt IS NULL`.

**Status semantics:**
- **Active** — cavity producing acceptable parts
- **Closed** — cavity physically shut off (die still runs on remaining cavities)
- **Scrapped** — cavity physically destroyed (die may still run on the remaining cavities, or die itself may be scrapped — the two are independent state changes)

Shoot-and-scrap behaviour (producing rejected parts each cycle from a degraded cavity) is NOT a cavity state — it's operational behaviour captured at the `Workorder.RejectEvent` level. The cavity stays Active until someone decides to Close or Scrap it.

#### `Tools.ToolAssignment`

Append-only check-in / out history. A Tool can be mounted on a Cell; when it's released the row is closed by setting `ReleasedAt`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| ToolId | BIGINT | FK → Tool, NOT NULL | |
| CellLocationId | BIGINT | FK → Location.Location, NOT NULL | Cell the tool is mounted on (validated to be a Cell-tier Location) |
| AssignedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| ReleasedAt | DATETIME2(3) | NULL | NULL = currently mounted |
| AssignedByUserId | BIGINT | FK → Location.AppUser, NOT NULL | Supervisor who mounted (elevated action) |
| ReleasedByUserId | BIGINT | FK → Location.AppUser, NULL | Supervisor who released (elevated action) |
| Notes | NVARCHAR(500) | NULL | |

Filtered UNIQUE: one active row per Tool where `ReleasedAt IS NULL`. A tool can only be mounted on one Cell at a time; mounting elsewhere requires releasing the previous assignment first.

**Elevated action:** Tool mount / release is in the FDS-04-007 elevated-action list. Supervisor AD auth required.

#### `Tools.ToolStatusCode` — code table

| Code | Name | Notes |
|---|---|---|
| Active | Active | In service |
| UnderRepair | Under Repair | Removed from service for repair |
| Scrapped | Scrapped | Physically destroyed / discarded |
| Retired | Retired | End-of-life, archived |

Read-only after seed.

#### `Tools.ToolCavityStatusCode` — code table

| Code | Name | Notes |
|---|---|---|
| Active | Active | Producing acceptable parts |
| Closed | Closed | Shut off; die runs without this cavity |
| Scrapped | Scrapped | Physically destroyed |

Read-only after seed.

#### `Tools.DieRank` — code table, seeded empty

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| Code | NVARCHAR(20) | NOT NULL, UNIQUE | Proposed values A–E per meeting notes, but MPP Quality owes the authoritative list |
| Name | NVARCHAR(100) | NOT NULL | |
| Description | NVARCHAR(500) | NULL | |
| SortOrder | INT | NOT NULL DEFAULT 0 | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| DeprecatedAt | DATETIME2(3) | NULL | |

**Seed data:** none. The table ships empty pending MPP Quality's ranking scheme. The Configuration Tool has a Die Rank admin screen for Engineering to populate.

#### `Tools.DieRankCompatibility` — junction, seeded empty

| Column | Type | Constraints | Description |
|---|---|---|---|
| Id | BIGINT | PK IDENTITY | |
| RankAId | BIGINT | FK → DieRank, NOT NULL | |
| RankBId | BIGINT | FK → DieRank, NOT NULL | |
| CanMix | BIT | NOT NULL | |
| CreatedAt | DATETIME2(3) | NOT NULL, DEFAULT GETDATE() | |
| UpdatedAt | DATETIME2(3) | NULL | |

UNIQUE `(RankAId, RankBId)`. Application-level convention: store canonicalised pairs (smaller Id first) so a single lookup covers both directions.

**Merge validation rule (OI-05):** `Lots.Lot_Merge` consults this table for cross-die merges. Behaviour until the table is populated:

- Two lots with the same die: merge proceeds (no rank involvement).
- Two lots with different dies: merge is **rejected** with message "Cross-die merges require die rank compatibility rules — contact MPP Quality."
- **Supervisor override:** the standard FDS-04-007 AD elevation prompt unlocks the merge regardless of the compat table's state.

### Workorder tie-in

Two changes to the existing `Workorder` schema. Both delivered in Phase G alongside the Tools tables.

#### `Workorder.WorkOrderType` — new code table

| Code | Name | Description |
|---|---|---|
| Demand | Demand WO | Production work orders (existing MVP-lite behaviour) |
| Maintenance | Maintenance WO | Targets a Tool. **FUTURE** — no flow / screens / procs in MVP; schema hook only. |
| Recipe | Recipe WO | Configuration / recipe context; hidden from operator. |

Seeded at migration time, read-only.

#### `Workorder.WorkOrder` — schema additions

Add two columns to the existing table:

| Column | Type | Constraints | Description |
|---|---|---|---|
| WorkOrderTypeId | BIGINT | FK → WorkOrderType, NOT NULL DEFAULT ~~Demand~~ **Production**-Id (corrected v1.9b) | Backfill existing rows to ~~`Demand`~~ **`Production`**. |
| ToolId | BIGINT | FK → Tools.Tool, NULL | ~~NULL unless `WorkOrderTypeId = Maintenance`.~~ **Future-Maintenance schema hook only (v1.9b correction). Not populated or enforced in MVP; reserved for a future maintenance-engine project.** |

The default-to-Demand backfill lets the Phase 7 procs keep working unchanged — existing production work orders continue as Demand type without touching the create/update procs. When Maintenance WOs arrive (FUTURE), new procs handle the ToolId flow.

### Stored procedure surface (spec only — Phase G writes them)

Following the existing naming conventions (`<Entity>_List`, `_Get`, `_Create`, `_Update`, `_Deprecate`) and the single-result-set Ignition JDBC convention (FDS-11-011).

**`Tools.ToolType`** — read-only:
- `_List (@IncludeDeprecated BIT = 0)` → rowset
- `_Get (@Id)` → rowset (0-1)

**`Tools.ToolAttributeDefinition`** — full CRUD:
- `_ListByType`, `_Get`, `_Create`, `_Update`, `_Deprecate`, `_MoveUp`, `_MoveDown`

**`Tools.Tool`** — full CRUD:
- `_List (@ToolTypeId, @StatusCode NVARCHAR(20) NULL, @IncludeDeprecated BIT = 0)`
- `_Get`, `_GetByCode`, `_Create`, `_Update`, `_Deprecate`, `_UpdateStatus (@Id, @StatusCode, @AppUserId)`

**`Tools.ToolAttribute`** — per-tool attribute CRUD:
- `_ListByTool`, `_Upsert (@ToolId, @AttributeDefinitionId, @Value, @AppUserId)`, `_Remove`

**`Tools.ToolCavity`** — per-tool cavity CRUD:
- `_ListByTool`, `_Create (@ToolId, @CavityNumber, @AppUserId)`, `_UpdateStatus (@Id, @StatusCode, @AppUserId)`, `_Deprecate`
- No full `_Update` — cavity numbers are immutable after creation; only status changes.

**`Tools.ToolAssignment`** — check-in/out:
- `_ListByTool`, `_ListActiveByCell (@CellLocationId)`, `_Assign (@ToolId, @CellLocationId, @AppUserId)`, `_Release (@ToolId, @AppUserId)`, `_History (@ToolId, @From, @To)`

**`Tools.DieRank`** — full CRUD (Admin screen):
- `_List`, `_Get`, `_Create`, `_Update`, `_Deprecate`, `_MoveUp`, `_MoveDown`

**`Tools.DieRankCompatibility`** — matrix editor:
- `_List`, `_GetPair (@RankAId, @RankBId)`, `_Upsert (@RankAId, @RankBId, @CanMix, @AppUserId)`, `_Remove`

**Status code tables** — `_List` only (read-only).

**`Workorder.WorkOrderType`** — `_List` only (read-only).

Total: ~35 new procs in Phase G. Order of magnitude matches other MVP phases.

### Configuration Tool frontend (spec only — Arc 1 addition)

New screens for Phase 9:

| View | Purpose |
|---|---|
| **Tool Browser** | Admin list of Tools with filter by Type + Status. Tree view grouped by ToolType on the left; detail pane on the right. |
| **Tool Editor** | Create / Edit a Tool. Form renders the Type's `ToolAttributeDefinition` rows dynamically. For Die-type, cavity registration panel with up/down arrow `CavityNumber` ordering; per-cavity status toggle. `DieRankId` dropdown shown only when ToolType = Die. |
| **Tool Assignment History** | Timeline of a Tool's check-in / out events. Links to each Cell. |
| **Tool Attribute Definition Editor** | Engineering screen to add / edit attribute definitions per ToolType. Up/down arrow sort. |
| **Die Rank Management** | Admin CRUD on `DieRank` rows. Initially empty — MPP Quality populates. |
| **Die Rank Compatibility Matrix** | Grid editor for `DieRankCompatibility` — rank list on both axes, checkbox for CanMix. Blocks saving until all pairs are set. |

All screens follow the existing Config Tool conventions — Ignition Named Query → stored proc, `Audit.Audit_LogConfigChange` on every mutation, up/down arrow for sort order (no drag-and-drop per `feedback_no_drag_drop.md` memory).

### Migration plan (Phase G)

One migration file: `sql/migrations/0010_phase9_tools_and_workorder.sql`. Runs after Phase 8.

> **⚠ Scope re-discovery 2026-04-22 — `Workorder.WorkOrder` doesn't exist yet.** Phases 1–8 built only the Config Tool SQL side; `Workorder.WorkOrder` and related runtime tables (WorkOrderOperation, ProductionEvent, ConsumptionEvent, RejectEvent) are Arc 2 Plant Floor deliverables (Arc 2 Phase 1 per `docs/superpowers/specs/2026-04-16-arc2-phased-plan-design.md`). The original step 7 "ALTER `Workorder.WorkOrder`" therefore has no table to target. **Phase G re-scopes to Path 3** (narrow + design-note deferrals). The column contract (`WorkOrderTypeId`, `ToolId`) stands unchanged — Arc 2 Phase 1 simply bakes it into `CREATE TABLE Workorder.WorkOrder` instead of an ALTER.

Phase G delivers (revised):

1. Create `Tools` schema if not exists.
2. Create code tables: `ToolStatusCode`, `ToolCavityStatusCode`, `DieRank` (empty), `DieRankCompatibility` (empty).
3. Create `ToolType` with seed rows (Die / Cutter / Jig / Gauge / AssemblyFixture / TrimTool).
4. Create `ToolAttributeDefinition` (empty).
5. Create `Tool`, `ToolAttribute`, `ToolCavity`, `ToolAssignment` with FKs + filtered unique indexes.
6. Create `Workorder.WorkOrderType` with seed ~~(Demand / Maintenance / Recipe)~~ **(single row: `Production` — corrected v1.9b OI-07, was originally 3 rows Demand/Maintenance/Recipe)** — **standalone code table, no FK back into WorkOrder at this stage** (WorkOrder doesn't exist; Arc 2 adds the reverse FK when it creates WorkOrder).
7. Create `Workorder.ScrapSource` with seed (Inventory / Location) — same pattern, standalone code table ready for Arc 2 to FK into.
8. ALTER Phase E additive columns (all land on existing tables): `Parts.Item.CountryOfOrigin`, `Parts.ContainerConfig.MaxParts`, `Parts.ItemLocation` consumption cols (Min/Max/DefaultQuantity + IsConsumptionPoint).
9. DROP legacy `Location.AppUser.ClockNumber` + `PinHash` columns (Phase C deferred cleanup).
10. Add `Audit.LogEntityType` seed rows: Tool, ToolAttributeDefinition, ToolAttribute, ToolCavity, ToolAssignment, DieRank, DieRankCompatibility, WorkOrderType, **ItemTransform (reserved for Arc 2)**, **ScrapSource** — 10 new rows total (Ids 31–40). Reserving the ItemTransform row here means Arc 2 doesn't need to touch the audit seed when it CREATEs the table.

**Deferred to Arc 2 Phase 1** (all three have FK dependencies on tables Arc 2 creates):

- `Parts.ItemTransform` — FKs into `Lots.Lot` (×2) + `Workorder.ProductionEvent`. Arc 2 CREATEs the table alongside its parent tables; the column contract in the Data Model v1.8 is final.
- `Workorder.WorkOrder.WorkOrderTypeId BIGINT NOT NULL FK → WorkOrderType` + `ToolId BIGINT NULL FK → Tools.Tool` — Arc 2 bakes into CREATE TABLE.
- `Workorder.ProductionEvent.ScrapSourceId BIGINT NULL FK → ScrapSource` — Arc 2 bakes into CREATE TABLE.

Procs are deployed via the repeatable procs pipeline after the migration runs — **~30 new proc files in Phase G** (down from ~35 — `ItemTransform_Record` and its siblings land in Arc 2).

**AppUser legacy column cleanup** (deferred from Phase C): same migration drops `Location.AppUser.ClockNumber` and `Location.AppUser.PinHash` columns, and drops the `Location.AppUser_SetPin` and `Location.AppUser_GetByClockNumber` procs (via repeatable-proc removal).

### Test plan (Phase G)

One new test folder: `sql/tests/0013_Tools_and_WorkOrderType/`. Expected coverage:
- ToolType read-only behaviour
- ToolAttributeDefinition full CRUD including polymorphic type scoping
- Tool CRUD including the nullable DieRankId constraint (reject on non-Die type setting a rank)
- ToolCavity CRUD including the HasCavities parent validation
- ToolAssignment assign / release / re-assign flows including the one-active-per-tool filtered unique
- DieRankCompatibility symmetry rule (canonical pair storage)
- Lots.Lot_Merge cross-die reject + supervisor override path (add to existing merge tests)
- Workorder.WorkOrder WorkOrderTypeId defaulting behaviour on existing create procs

Target: ~60 new assertions. Full-suite target after Phase G: ~840 passing.

## Scope tags

| Item | Scope |
|---|---|
| Tools schema + CRUD procs | MVP |
| Tool Assignment (check-in/out) | MVP |
| Die Rank tables + Matrix UI | MVP (tables) / MVP (UI, empty until MPP populates) |
| Tool-life threshold alarms | FUTURE — scheduled Gateway Script pattern |
| Maintenance WO flow / screens | FUTURE — schema hook is MVP, flow is FUTURE |
| Cross-plant tool transfer | FUTURE |
| Tool photograph / document attachments | FUTURE |

## Open hand-offs after Phase B spec approval

| Owner | Deliverable | Blocks |
|---|---|---|
| MPP Quality | Die rank list + full compatibility matrix | OI-05 merge rules take full effect (override-only until delivered) |
| Ben (MPP) | Maintenance-engine scope (WO lifecycle, scheduling, integration points) | FUTURE Maintenance WO flow in Phase G+ |
| MPP Engineering | `ToolAttributeDefinition` population for each ToolType (cycle time, tonnage, insert count, etc.) | Tool Editor has empty attribute lists until populated (same as `LocationAttributeDefinition` was at its rollout) |
| MPP Engineering | Initial Tool inventory (existing die list, machining cutters, etc.) with cavity counts for dies | Tool Browser shows empty until populated; can happen post-cutover |

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 0.1 | 2026-04-21 | Blue Ridge Automation | Initial Phase B design spec. All six 2026-04-21 Q&A decisions incorporated. Block concept dropped (lives in ISA-95 hierarchy + `Parts.ItemLocation`, not Tools). Cavity status retained as 3-state (Active / Closed / Scrapped) per Jacques's final call. |
| 0.2 | 2026-04-21 | Blue Ridge Automation | Renamed `ToolTypeDefinition` → `ToolType` per Jacques's push-back: Tools are a grouping, not a hierarchy, so there's no need for the two-table pattern Location uses. `ToolAttributeDefinition.ToolTypeDefinitionId` FK renamed to `ToolTypeId`; `Tool.ToolTypeDefinitionId` FK renamed to `ToolTypeId`. If sub-categories are ever needed the pattern has room to grow. |
| 0.3 | 2026-04-22 | Blue Ridge Automation | **Scope re-discovery during Phase G implementation kick-off.** Original spec said "ALTER `Workorder.WorkOrder`" to add `WorkOrderTypeId` + `ToolId`; grep of the codebase confirms `Workorder.WorkOrder`, `WorkOrderOperation`, and `ProductionEvent` don't yet exist — they're Arc 2 Plant Floor deliverables (Arc 2 Phase 1 per the Arc 2 phased plan). Phase G re-scoped to **Path 3** (narrow + design-note): the Tools schema and the two standalone code tables (`WorkOrderType`, `ScrapSource`) still land in Phase G; the three dependent schema changes (`ItemTransform` table, WorkOrder.WorkOrderTypeId/ToolId columns, ProductionEvent.ScrapSourceId column) defer to Arc 2 Phase 1 where they bake into `CREATE TABLE` statements rather than `ALTER`. Column contracts unchanged — only the DDL verb moves. `Audit.LogEntityType` ItemTransform seed row (Id=39) still added in Phase G so Arc 2 doesn't have to touch the audit seed. See the updated "Migration plan (Phase G)" section above for the revised step list. |
