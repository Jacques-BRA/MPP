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
| 0.2 | 2026-04-10 | Blue Ridge Automation | Reformatted API Layer sections from bulleted lists to tables (Procedure / Parameters / Notes) for Word readability. Added explicit Seed Data tables to Phases 1, 7, and 8 with row counts and source CSVs. No content changes — purely a presentation pass. |
| 0.3 | 2026-04-10 | Blue Ridge Automation | Restructured the phase ordering: new Phase 1 is **Identity & Audit Foundation** (formerly Phase 2), and the old Phase 1 (Plant Model) is now Phase 2. Added 3 shared **audit infrastructure procedures** (`Audit_LogConfigChange`, `Audit_LogOperation`, `Audit_LogInterfaceCall`) that every CRUD proc in every later phase must call instead of writing audit entries inline. Documented the bootstrap admin user (`Id = 1`, inserted via migration script) to break the chicken-and-egg dependency. Added a **Dependencies** column to every API table across all 8 phases — shows which other procs and tables each procedure relies on, plus which mutating procs call `Audit_LogConfigChange`. Updated cross-cutting concerns to reflect the shared-audit-proc pattern. |
| 0.4 | 2026-04-10 | Blue Ridge Automation | Added **Executed When** and **Output** columns to every API table across all 8 phases. *Executed When* describes the user/system trigger that causes each proc to run (e.g., "Plant Hierarchy Browser expands a tree node", "Admin submits Add User modal", "Plant Floor production code looks up the active route for this LOT"). *Output* documents what each proc returns — rowset shape, scalar type, or rowcount — making the API contract explicit for the engineer building Named Queries. API tables now have 6 columns: Procedure / Parameters / Notes / Dependencies / Executed When / Output. |

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

1. **Audit attribution via shared procs.** Every Create/Update/Deprecate stored procedure takes `@AppUserId INT` and **calls the shared `Audit_LogConfigChange` proc** (defined in Phase 1) to write a row to `Audit.ConfigLog`. The shared proc is the single source of truth for how audit entries are written — entity-specific procs do not write to `ConfigLog` directly. This means a future change to the audit schema only touches `Audit_LogConfigChange`, not 100+ entity procs.
2. **Soft delete only.** Hard `DELETE` is forbidden for any table with downstream references. Use `DeprecatedAt` (set non-null to deactivate). Procedures should validate that an entity has no active dependents before deprecating.
3. **Versioning where applicable.** BOMs, route templates, quality specs, and operation templates all carry `VersionNumber` + `EffectiveFrom` + `DeprecatedAt`. Production records reference the version that was active at the time, not the latest.
4. **No reference loops.** Validate parent-child relationships server-side (e.g., a `Location.ParentLocationId` cannot equal its own `Id`, and the chain cannot cycle).
5. **Code-table-backed status.** Any status or type field is an FK to a code table, not a free-text column or magic integer.
6. **Parameterized procedure calls.** Named Queries always use named parameters. No string concatenation, no dynamic SQL on the Perspective side.
7. **Optimistic locking** on Update procedures: pass `@RowVersion` (or `@UpdatedAt`) and the procedure rejects the update if it doesn't match. Prevents lost updates from concurrent edits.
8. **Server-side validation.** Validation lives in the stored procedure, not just the Perspective form. The frontend may pre-validate for UX, but the proc is the authority.
9. **`AppUser` and audit infrastructure exist before any other phase.** Phase 1 establishes the bootstrap admin user (`Id = 1`, inserted via the migration script) and the shared audit procs. No CRUD work in Phases 2–8 can be written until Phase 1 is complete.
10. **Perspective permissions.** Each Configuration Tool screen is gated by an Ignition role (Engineering, Admin). Operators cannot reach Configuration screens — enforced at the Perspective view security level, not just hidden.

---

## Phase Map and Dependencies

```
Phase 1 (Identity & Audit Foundation — AppUser, Audit infrastructure procs)
  └──→ Phase 2 (Plant Model & Location Schema)
        └──→ Phase 3 (Reference Lookups)
              ├──→ Phase 4 (Item Master & Container Config)
              │     ├──→ Phase 5 (Process Definition: Routes & Operations)
              │     │     └──→ Phase 6 (BOM Management)
              │     └──→ Phase 7 (Quality Configuration)
              └──→ Phase 8 (Operations Reference Data: Downtime, Shifts, OPC)
```

Phases 1, 2, and 3 are **foundation** and must run in order. **Phase 1 is the new bedrock** — the audit infrastructure procs (`Audit_LogConfigChange` etc.) must exist before any other CRUD proc can be written, since every Create/Update/Deprecate proc in every later phase calls them. Phases 4–8 can be parallelized once 1–3 are done; the only hard dependency among them is Phase 6 (BOMs) needing Phase 4 (Items).

**Bootstrap problem solved:** The very first `AppUser` row (a system/admin account, `Id = 1`) is inserted directly via the deployment migration script — not via `AppUser_Create` — to break the chicken-and-egg dependency on `@AppUserId` for audit attribution. All subsequent admin accounts are created by this bootstrap user.

---

## Phase 1 — Identity & Audit Foundation

**Goal:** Establish the audit log infrastructure and the `AppUser` table. Every other phase calls into this — every Create/Update/Deprecate proc anywhere in the system invokes one of the shared audit procs defined here. Without this phase, no other CRUD work can be written.

**Dependencies:** None. This is the bedrock.

**Status:** Unblocked. **Must be the first thing built.**

### Bootstrap Note

The very first `AppUser` row (a system/admin account) is inserted directly via the deployment migration script — not via `AppUser_Create` — to break the chicken-and-egg dependency on `@AppUserId` for audit attribution. By convention, this row has `Id = 1`, `AdAccount = 'system.bootstrap'`, and `IgnitionRole = 'Admin'`. All subsequent admin accounts are created by this bootstrap user.

The audit lookup tables (`LogSeverity`, `LogEventType`, `LogEntityType`) are also seeded by the migration script, since the audit infrastructure procs need them to exist before they can write any rows.

### Data Model

| Table | Role |
|---|---|
| `AppUser` | One row per MES user. Backed by AD identity. Captures clock number + PIN hash for shop-floor convenience login. Referenced for audit attribution everywhere. |
| `Audit.LogSeverity` | Code table: Info, Warning, Error, Critical. Seeded. |
| `Audit.LogEventType` | Code table: ConfigChanged, LotCreated, LotMoved, ProductionRecorded, etc. Seeded with the initial set, extensible. |
| `Audit.LogEntityType` | Code table: Location, Item, Lot, BOM, AppUser, etc. Seeded from the entity table list. |
| `Audit.ConfigLog` | Destination for all Configuration Tool audit entries. Every config mutation writes here via `Audit_LogConfigChange`. |
| `Audit.OperationLog` | Destination for plant-floor mutations (used by Arc 2, but the proc lives here). Every shop-floor action writes via `Audit_LogOperation`. |
| `Audit.InterfaceLog` | Destination for external system calls (AIM, Zebra, Macola, etc.). Every external call writes via `Audit_LogInterfaceCall`. |

### Audit Infrastructure Procedures

These are the **shared audit procs** that every other CRUD proc in the system calls. They are the single source of truth for how audit entries are written. If the audit schema changes, these are the only procs that change — everything else just keeps calling them.

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Audit_LogConfigChange` | `@AppUserId, @LogEntityTypeId, @EntityId, @LogEventTypeId, @LogSeverityId, @Description, @OldValue NVARCHAR(MAX) NULL, @NewValue NVARCHAR(MAX) NULL` | Writes one row to `Audit.ConfigLog`. **Called by every Create/Update/Deprecate proc in every Configuration Tool phase.** | `Audit.ConfigLog`, `Audit.LogEntityType`, `Audit.LogEventType`, `Audit.LogSeverity`, `AppUser` | Inside any Configuration Tool mutation proc, just before returning | Scalar: new `ConfigLog.Id` (BIGINT). Typically ignored by callers. |
| `Audit_LogOperation` | `@AppUserId, @TerminalLocationId, @LocationId, @LogEntityTypeId, @EntityId, @LogEventTypeId, @LogSeverityId, @Description, @OldValue NVARCHAR(MAX) NULL, @NewValue NVARCHAR(MAX) NULL` | Writes one row to `Audit.OperationLog`. Called by every plant-floor mutation in the Arc 2 build (LOT creation, movement, production recording, holds, etc.). **Defined here, used in the Plant Floor phased plan.** | `Audit.OperationLog`, `Location`, `AppUser`, audit lookups | Inside any Plant Floor mutation proc (Arc 2), just before returning | Scalar: new `OperationLog.Id` (BIGINT). Typically ignored by callers. |
| `Audit_LogInterfaceCall` | `@SystemName VARCHAR(50), @Direction VARCHAR(10), @LogEventTypeId, @Description, @RequestPayload NVARCHAR(MAX) NULL, @ResponsePayload NVARCHAR(MAX) NULL, @ErrorCondition NVARCHAR(200) NULL, @IsHighFidelity BIT = 0` | Writes one row to `Audit.InterfaceLog`. Called by every AIM, Zebra, Macola, or Intelex call. Per FRS 3.17.4, `@IsHighFidelity` controls whether the full request/response payloads are stored or just the metadata. | `Audit.InterfaceLog`, audit lookups | Inside any external-system call wrapper (before and/or after the HTTP/API request) | Scalar: new `InterfaceLog.Id` (BIGINT). Typically ignored by callers. |

### API Layer (Named Queries → Stored Procedures)

**`AppUser`** (full CRUD + lookup variants):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `AppUser_List` | `@IncludeDeprecated BIT = 0` | Active users by default | `AppUser` | User Management screen loads | Rowset: `AppUser` rows |
| `AppUser_Get` | `@Id` | | `AppUser` | Edit User modal opens | Rowset (0-1): one `AppUser` row |
| `AppUser_GetByAdAccount` | `@AdAccount` | Session resolution at AD login | `AppUser` | User opens a Perspective session and Ignition resolves their AD identity | Rowset (0-1): one `AppUser` row |
| `AppUser_GetByClockNumber` | `@ClockNumber` | Shop-floor login lookup | `AppUser` | Operator enters clock number + PIN at a shop-floor terminal (Arc 2 usage) | Rowset (0-1): one `AppUser` row |
| `AppUser_Create` | `@AdAccount, @DisplayName, @ClockNumber, @PinHash, @IgnitionRole, @AppUserId` | `@AppUserId` is the admin creating the row | `AppUser`, calls `Audit_LogConfigChange` | Admin submits Add User modal | Scalar: new `AppUser.Id` (INT) |
| `AppUser_Update` | `@Id, @DisplayName, @ClockNumber, @IgnitionRole, @AppUserId` | PIN changes go through `_SetPin` | `AppUser`, calls `Audit_LogConfigChange` | Admin saves Edit User form | Rowcount (0 on optimistic-lock mismatch) |
| `AppUser_SetPin` | `@Id, @PinHash, @AppUserId` | Separate proc keeps PIN out of the general Update flow | `AppUser`, calls `Audit_LogConfigChange` (with redacted `@OldValue`/`@NewValue`) | User or admin submits PIN Reset form (hashed client-side first) | Rowcount |
| `AppUser_Deprecate` | `@Id, @AppUserId` | Rejects if active records reference this user as creator | `AppUser`, calls `Audit_LogConfigChange` | Admin clicks Deprecate on a user row | Rowcount (0 if rejected due to active dependents) |

**Audit lookup tables** (read-only after seeding):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `LogSeverity_List` | — | Info, Warning, Error, Critical | `Audit.LogSeverity` | Audit Log Browser filter dropdown loads | Rowset: `LogSeverity` rows |
| `LogEventType_List` | — | ConfigChanged, LotCreated, LotMoved, ProductionRecorded, etc. | `Audit.LogEventType` | Audit Log Browser filter dropdown loads | Rowset: `LogEventType` rows |
| `LogEntityType_List` | — | Location, Item, Lot, BOM, AppUser, etc. | `Audit.LogEntityType` | Audit Log Browser filter dropdown loads | Rowset: `LogEntityType` rows |

**`Audit.ConfigLog`** (read-only from the Configuration Tool — written only by `Audit_LogConfigChange`):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `ConfigLog_List` | `@StartDate, @EndDate, @LogEntityTypeId NULL, @AppUserId NULL` | Paged, filterable | `Audit.ConfigLog`, `AppUser`, `Audit.LogEntityType` | Audit Log Browser loads or user changes filters | Rowset: `ConfigLog` rows joined to `AppUser.DisplayName` and `LogEntityType.Name` |
| `ConfigLog_GetByEntity` | `@LogEntityTypeId, @EntityId` | "Show me everything ever changed about this Item / Location / BOM" | `Audit.ConfigLog` | User clicks "View Audit History" on any Configuration Tool screen | Rowset: `ConfigLog` rows for one entity, ordered newest first |

### Frontend (Perspective Views)

| View | Purpose |
|---|---|
| **User Management** | Admin-only. List of `AppUser` rows with filter (active/deprecated). Add User modal: enter AD account, display name, clock number, optional initial PIN, Ignition role. Edit User modal: same fields plus "Deprecate" action. |
| **PIN Reset** | Self-service or admin flow: set a new PIN with confirmation field. Hashes the PIN client-side before calling `AppUser_SetPin`. PIN storage uses `PinHash`, never plaintext. |
| **Audit Log Browser** | Admin-only. Filterable view of `Audit.ConfigLog` with filters for entity type, user, date range. Click a row to expand and see the old/new values diff. Deep-linkable from every other Config Tool screen ("View audit history for this Item"). |

### Phase 1 complete when

- The bootstrap `AppUser` row exists (`Id = 1`, system account)
- The audit lookup tables are seeded (severity, event types, entity types)
- The 3 audit infrastructure procs (`Audit_LogConfigChange`, `Audit_LogOperation`, `Audit_LogInterfaceCall`) are deployed and tested
- The full `AppUser` CRUD is wired through Named Queries — and every mutating proc calls `Audit_LogConfigChange`
- Admin can create a real engineering admin user via the User Management screen
- Admin can browse the audit log via the Audit Log Browser
- Every later phase's CRUD proc template **must** include a `CALL Audit_LogConfigChange(...)` step before returning

---

## Phase 2 — Plant Model & Location Schema

**Goal:** Stand up the three-tier polymorphic location model and load the seed machine list. Without this, nothing else can be physically configured.

**Dependencies:** Phase 1 (audit infrastructure procs and at least one `AppUser` for `@AppUserId` attribution).

**Status:** Unblocked once Phase 1 is complete.

### Data Model

Tables involved (all from the `Location` schema, per `MPP_MES_DATA_MODEL.md` §1):

| Table | Role |
|---|---|
| `LocationType` | The 5 ISA-95 tiers (Enterprise, Site, Area, WorkCenter, Cell). Seeded at deployment, read-only thereafter. |
| `LocationTypeDefinition` | Polymorphic kinds within a tier (Terminal, DieCastMachine, CNCMachine, ProductionArea, etc.). Seeded with initial set, extensible by Engineering role. |
| `LocationAttributeDefinition` | Per-kind attribute schema (e.g., `Tonnage` for `DieCastMachine`, `IpAddress` for `Terminal`). |
| `Location` | Instances. Self-referential via `ParentLocationId`. Every row references one `LocationTypeDefinition`. |
| `LocationAttribute` | Attribute values per location. FK enforces that the attribute definition belongs to the location's own definition. |

**Seed data to load:**

| Table | Source | Rows | Notes |
|---|---|---|---|
| `LocationType` | hard-coded | 5 | Enterprise, Site, Area, WorkCenter, Cell |
| `LocationTypeDefinition` | hard-coded | ~15 | Organization, Facility, ProductionArea, SupportArea, ProductionLine, InspectionLine, Terminal, DieCastMachine, CNCMachine, TrimPress, AssemblyStation, SerializedAssemblyLine, InspectionStation, InventoryLocation, Scale |
| `LocationAttributeDefinition` | hard-coded | ~20 | Per definition: Tonnage, NumberOfCavities, RefCycleTimeSec on `DieCastMachine`; IpAddress, DefaultPrinter, HasBarcodeScanner on `Terminal`; etc. |
| `Location` (Enterprise) | hard-coded | 1 | Madison Precision Products, Inc. |
| `Location` (Site) | hard-coded | 1 | Madison facility |
| `Location` (Area) | hard-coded | 5 | Die Cast, Trim Shop, Machine Shop, Production Control, Quality Control |
| `Location` (Cell) | `reference/seed_data/machines.csv` | 209 | Machines mapped to Cell-tier definitions by process (DieCast# → `DieCastMachine`, MS Machine → `CNCMachine`, etc.) |
| `LocationAttribute` | from `machines.csv` columns | ~600 | Tonnage, RefCycleTimeSec, NumberOfCavities per Cell where present |

### API Layer (Named Queries → Stored Procedures)

**`LocationType`** (read-only — seeded at deployment):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `LocationType_List` | — | Returns all 5 tiers | `LocationType` | Engineering opens a form that needs a tier dropdown (e.g., creating a new LocationTypeDefinition) | Rowset: 5 `LocationType` rows |
| `LocationType_Get` | `@Id` | Single tier | `LocationType` | Rarely called directly; mostly used via joins from other procs | Rowset (0-1): one `LocationType` row |

**`LocationTypeDefinition`** (full CRUD):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `LocationTypeDefinition_List` | `@LocationTypeId NULL` | Optional filter by tier | `LocationTypeDefinition`, `LocationType` | Location Type Definition Editor loads; Add Location modal populates its kind dropdown | Rowset: `LocationTypeDefinition` rows with tier name |
| `LocationTypeDefinition_Get` | `@Id` | | `LocationTypeDefinition` | Engineering opens a definition for editing | Rowset (0-1): one definition row |
| `LocationTypeDefinition_Create` | `@LocationTypeId, @Code, @Name, @Description, @AppUserId` | Returns new `Id` | `LocationType` (FK), calls `Audit_LogConfigChange` | Engineering submits "New Definition" in the Editor | Scalar: new `LocationTypeDefinition.Id` (INT) |
| `LocationTypeDefinition_Update` | `@Id, @Name, @Description, @AppUserId` | `LocationTypeId` is immutable after create | calls `Audit_LogConfigChange` | Engineering saves changes to a definition | Rowcount |
| `LocationTypeDefinition_Deprecate` | `@Id, @AppUserId` | Rejects if any active `Location` references it | reads `Location`, calls `Audit_LogConfigChange` | Engineering clicks Deprecate on a definition | Rowcount (0 if rejected due to active dependents) |

**`LocationAttributeDefinition`** (full CRUD, scoped to a parent definition):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `LocationAttributeDefinition_ListByDefinition` | `@LocationTypeDefinitionId` | Attribute schema for one kind | `LocationAttributeDefinition` | Engineering opens a definition in the Editor; Location Details Panel renders the dynamic attribute form | Rowset: attribute definition rows |
| `LocationAttributeDefinition_Get` | `@Id` | | `LocationAttributeDefinition` | Edit Attribute form opens | Rowset (0-1): one attribute definition row |
| `LocationAttributeDefinition_Create` | `@LocationTypeDefinitionId, @AttributeName, @DataType, @IsRequired, @DefaultValue, @Uom, @SortOrder, @Description, @AppUserId` | | `LocationTypeDefinition` (FK), calls `Audit_LogConfigChange` | Engineering adds an attribute to a definition | Scalar: new `LocationAttributeDefinition.Id` (INT) |
| `LocationAttributeDefinition_Update` | `@Id, @AttributeName, @DataType, @IsRequired, @DefaultValue, @Uom, @SortOrder, @Description, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering edits an attribute | Rowcount |
| `LocationAttributeDefinition_Deprecate` | `@Id, @AppUserId` | Rejects if any `LocationAttribute` references it | reads `LocationAttribute`, calls `Audit_LogConfigChange` | Engineering removes an attribute from a definition | Rowcount (0 if rejected) |

**`Location`** (full CRUD + tree queries):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Location_List` | `@ParentLocationId NULL, @LocationTypeDefinitionId NULL` | Children and/or filtered by kind | `Location`, `LocationTypeDefinition` | Plant Hierarchy Browser expands a tree node to list its children | Rowset: `Location` rows with definition name and tier |
| `Location_GetTree` | `@RootLocationId` | Recursive CTE: full hierarchy from a root down | `Location` (recursive) | Plant Hierarchy Browser initial load from the Enterprise root, or a deep refresh | Rowset: all descendant `Location` rows with `Depth` and materialized path |
| `Location_GetAncestors` | `@LocationId` | Recursive CTE: from this location up to root | `Location` (recursive) | Breadcrumb navigation renders the path from root to the selected node | Rowset: ancestor `Location` rows ordered root→current |
| `Location_GetDescendantsOfType` | `@LocationId, @LocationTypeId` | E.g., "all Cells under the Die Cast Area" | `Location` (recursive), `LocationTypeDefinition` | Eligibility Map Editor loads Cells for an area; Plant Floor looks up eligible machines (Arc 2 usage) | Rowset: matching descendant `Location` rows |
| `Location_Get` | `@Id` | Returns location + all current `LocationAttribute` values | `Location`, `LocationAttribute`, `LocationAttributeDefinition` | User clicks a tree node to load its details panel | Rowset: one `Location` row plus a second rowset of its attribute values, OR a single joined rowset with one row per attribute |
| `Location_Create` | `@LocationTypeDefinitionId, @ParentLocationId, @Name, @Code, @Description, @AppUserId` | | `LocationTypeDefinition` (FK), `Location` (parent FK), calls `Audit_LogConfigChange` | Engineering submits Add Location modal | Scalar: new `Location.Id` (INT) |
| `Location_Update` | `@Id, @Name, @Code, @Description, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering saves Location Details Panel changes | Rowcount |
| `Location_Deprecate` | `@Id, @AppUserId` | Rejects if active `Lot.CurrentLocationId` or `LotMovement` references exist | reads `Lot`, `LotMovement`, calls `Audit_LogConfigChange` | Engineering clicks Deprecate on a location node | Rowcount (0 if rejected) |

**`LocationAttribute`** (per-instance values):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `LocationAttribute_GetByLocation` | `@LocationId` | All current values for one location | `LocationAttribute`, `LocationAttributeDefinition` | Loading the Location Details Panel's attribute form | Rowset: attribute rows joined to their definitions (name, data type, UOM, required flag) |
| `LocationAttribute_Set` | `@LocationId, @LocationAttributeDefinitionId, @AttributeValue, @AppUserId` | Upsert; validates definition belongs to location's kind | `Location`, `LocationAttributeDefinition`, calls `Audit_LogConfigChange` | User saves a changed attribute value in the Details Panel (one call per changed attribute) | Rowcount |
| `LocationAttribute_Clear` | `@LocationId, @LocationAttributeDefinitionId, @AppUserId` | Remove value; rejects if `IsRequired` | `LocationAttributeDefinition`, calls `Audit_LogConfigChange` | User clears a non-required attribute | Rowcount (0 if rejected) |

**Seed loading** (one-time):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Location_BulkLoadMachinesFromSeed` | `@CsvData NVARCHAR(MAX), @AppUserId` | Loads `machines.csv`. Alternative: Ignition Gateway script calling `Location_Create` per row. | calls `Location_Create` per row (transitively `Audit_LogConfigChange`) | Engineer runs the Bulk Seed Loader screen during initial deployment (one-time) | Scalar: count of rows inserted, or a result set summarizing inserts/failures |

### Frontend (Perspective Views)

| View | Purpose |
|---|---|
| **Plant Hierarchy Browser** | Tree component (Perspective Tree or custom recursive accordion) showing the plant model from Enterprise → Site → Area → WorkCenter → Cell. Click a node to load its details in a side panel. Drag-to-reparent (with audit log) optional for v1. |
| **Location Details Panel** | Right-side drawer triggered by selecting a tree node. Shows Name, Code, Description, Type/Definition (read-only after create), Parent (read-only after create), and a **dynamic attributes form** rendered from the location's `LocationAttributeDefinition` set. Save invokes `Location_Update` and `LocationAttribute_Set` for each changed attribute. |
| **Add Location Modal** | Triggered from a tree node's context menu. Form: select a `LocationTypeDefinition` (dropdown filtered by what's valid as a child of the parent's tier), enter Name, Code, Description. Submit invokes `Location_Create`. |
| **Location Type Definition Editor** | Engineering/Admin only. List of all `LocationTypeDefinition` rows grouped by `LocationType`. Add/edit definitions, with an embedded sub-table of `LocationAttributeDefinition` rows (the attribute schema). |
| **Bulk Seed Loader** | One-time-use screen (or Gateway script) for loading `machines.csv` into `Location` rows. Shows a preview table from the CSV, lets the engineer map process types to definitions (e.g., MachDesc starting with "DieCast" → `DieCastMachine`), and triggers the bulk load. |

### Phase 2 complete when

- 5 `LocationType` rows seeded
- ~15 `LocationTypeDefinition` rows seeded with their attribute schemas
- The MPP plant tree exists from Enterprise root down to all 209 machines
- Tonnage, cycle time, and NumberOfCavities attribute values from `machines.csv` are loaded as `LocationAttribute` rows
- Engineering can browse the tree, click a machine, and see/edit its attributes
- Engineering can add a new `LocationTypeDefinition` (e.g., "TestStand" if a new kind is needed)
- Every mutation lands in `Audit.ConfigLog` with the user's clock number recorded

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

### API Layer (Named Queries → Stored Procedures)

Each table follows one of two standard patterns based on whether engineering can extend it.

**Read-only pattern** (`LotOriginType`, `LotStatusCode`, `ContainerStatusCode`, `GenealogyRelationshipType`, `OperationStatus`, `WorkOrderStatus`):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `<Entity>_List` | — | Returns all rows | `<Entity>` table | Reference Data Manager tab loads; dropdown populates on any other screen needing this code table (e.g., LOT status dropdown on plant-floor screens) | Rowset: all `<Entity>` rows |
| `<Entity>_Get` | `@Id` | Single row | `<Entity>` table | Detail view of a specific row (rare) | Rowset (0-1): one `<Entity>` row |

**Mutable pattern** (`Uom`, `ItemType` — engineering can add new entries):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `<Entity>_List` | `@IncludeDeprecated BIT = 0` | | `<Entity>` table | Reference Data Manager tab loads; dropdown population on other screens (Item Master needs Uom + ItemType) | Rowset: `<Entity>` rows |
| `<Entity>_Get` | `@Id` | | `<Entity>` table | Edit modal opens | Rowset (0-1): one row |
| `<Entity>_Create` | `@Code, @Name, @Description, @AppUserId` | Returns new `Id` | calls `Audit_LogConfigChange` | Admin submits Add modal | Scalar: new `<Entity>.Id` (INT) |
| `<Entity>_Update` | `@Id, @Name, @Description, @AppUserId` | `Code` is immutable | calls `Audit_LogConfigChange` | Admin saves Edit form | Rowcount |
| `<Entity>_Deprecate` | `@Id, @AppUserId` | Rejects on active dependents | reads referencing tables, calls `Audit_LogConfigChange` | Admin clicks Deprecate | Rowcount (0 if rejected) |

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

### API Layer (Named Queries → Stored Procedures)

**`Item`**:

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Item_List` | `@ItemTypeId NULL, @SearchText NULL, @IncludeDeprecated BIT = 0` | Filterable list | `Item`, `ItemType`, `Uom` | Item Master List loads; Item Picker component loads | Rowset: `Item` rows joined to `ItemType.Name` and `Uom.Code` |
| `Item_Get` | `@Id` | | `Item` | Item Editor opens | Rowset (0-1): one `Item` row |
| `Item_GetByPartNumber` | `@PartNumber` | For BOM/route construction lookups | `Item` | BOM/route construction validates a typed or scanned part number; Plant Floor validates a scanned source LOT's part (Arc 2 usage) | Rowset (0-1): one `Item` row |
| `Item_Create` | `@PartNumber, @ItemTypeId, @Description, @MacolaPartNumber, @DefaultSubLotQty, @MaxLotSize, @UomId, @UnitWeight, @WeightUomId, @AppUserId` | Returns new `Id` | `ItemType` (FK), `Uom` (FK), calls `Audit_LogConfigChange` | Engineering submits New Item form | Scalar: new `Item.Id` (INT) |
| `Item_Update` | `@Id, @Description, @MacolaPartNumber, @DefaultSubLotQty, @MaxLotSize, @UomId, @UnitWeight, @WeightUomId, @AppUserId` | `PartNumber` and `ItemTypeId` are immutable — to change, deprecate and recreate | `Uom` (FK), calls `Audit_LogConfigChange` | Engineering saves Item Editor changes | Rowcount |
| `Item_Deprecate` | `@Id, @AppUserId` | Rejects if active `Bom`, `RouteTemplate`, `ItemLocation`, or `ContainerConfig` references exist | reads `Bom`, `RouteTemplate`, `ItemLocation`, `ContainerConfig`, calls `Audit_LogConfigChange` | Engineering clicks Deprecate on an item | Rowcount (0 if rejected) |

**`ContainerConfig`**:

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `ContainerConfig_GetByItem` | `@ItemId` | Usually one config per item | `ContainerConfig` | Container Config tab opens in Item Editor; Plant Floor container lifecycle needs the packing rules (Arc 2 usage) | Rowset (0-1): one `ContainerConfig` row |
| `ContainerConfig_Create` | `@ItemId, @TraysPerContainer, @PartsPerTray, @IsSerialized, @DunnageCode, @CustomerCode, @AppUserId` | OI-02 may add `@ClosureMethod` and `@TargetWeight` | `Item` (FK), calls `Audit_LogConfigChange` | Engineering saves a new container config for a finished good | Scalar: new `ContainerConfig.Id` (INT) |
| `ContainerConfig_Update` | `@Id, @TraysPerContainer, @PartsPerTray, @IsSerialized, @DunnageCode, @CustomerCode, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering edits an existing container config | Rowcount |
| `ContainerConfig_Deprecate` | `@Id, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering removes a container config | Rowcount |

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

### API Layer (Named Queries → Stored Procedures)

**`OperationTemplate`** (versioned):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `OperationTemplate_List` | `@AreaLocationId NULL, @ActiveOnly BIT = 1` | Filter by area | `OperationTemplate`, `Location` | Operation Template Library loads; Route Builder dropdown populates when adding a step | Rowset: `OperationTemplate` rows joined to area name |
| `OperationTemplate_Get` | `@Id` | | `OperationTemplate` | Engineering opens a template in the Editor | Rowset (0-1): one template row |
| `OperationTemplate_Create` | `@Name, @AreaLocationId, @CollectsDieInfo, @CollectsCavityInfo, @CollectsWeight, @CollectsGoodCount, @CollectsBadCount, @RequiresMaterialVerification, @RequiresSerialNumber, @AppUserId` | Creates version 1 | `Location` (Area FK), calls `Audit_LogConfigChange` | Engineering submits New Template form | Scalar: new `OperationTemplate.Id` (INT) |
| `OperationTemplate_CreateNewVersion` | `@ParentOperationTemplateId, ..., @EffectiveFrom, @AppUserId` | New version preserves the previous | reads `OperationTemplate`, calls `Audit_LogConfigChange` | Engineering clicks "Save as New Version" | Scalar: new version `OperationTemplate.Id` (INT) |
| `OperationTemplate_Deprecate` | `@Id, @AppUserId` | Soft-deletes a specific version | reads `RouteStep`, calls `Audit_LogConfigChange` | Engineering deprecates a template version | Rowcount (0 if rejected due to active route steps) |

**`RouteTemplate`** (versioned):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `RouteTemplate_ListByItem` | `@ItemId, @ActiveOnly BIT = 1` | Usually one active route per item | `RouteTemplate` | Route Builder opens for an item; Item Editor's Routes tab loads | Rowset: `RouteTemplate` rows ordered by version |
| `RouteTemplate_Get` | `@Id` | Returns route header + steps in order | `RouteTemplate`, `RouteStep`, `OperationTemplate` | Opening a specific route version in the Route Builder | Rowset: one route header + joined rowset of ordered steps with operation names |
| `RouteTemplate_GetActiveForItem` | `@ItemId, @AsOfDate DATETIME2 = NULL` | Picks version active at a given moment | `RouteTemplate` | Plant Floor production code looks up "what route governs this LOT right now?" (Arc 2 usage) | Rowset (0-1): one active route header |
| `RouteTemplate_Create` | `@ItemId, @Name, @EffectiveFrom, @AppUserId` | Empty route, version 1 | `Item` (FK), calls `Audit_LogConfigChange` | Engineering creates a first route for an item | Scalar: new `RouteTemplate.Id` (INT) |
| `RouteTemplate_CreateNewVersion` | `@ParentRouteTemplateId, @EffectiveFrom, @AppUserId` | Copies steps from prior version | reads `RouteTemplate`, `RouteStep`; calls `Audit_LogConfigChange` | Engineering clicks "New Version" in Route Builder | Scalar: new version `RouteTemplate.Id` (INT) |
| `RouteTemplate_Deprecate` | `@Id, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering deprecates a route version | Rowcount |

**`RouteStep`**:

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `RouteStep_ListByRoute` | `@RouteTemplateId` | | `RouteStep`, `OperationTemplate` | Route Builder displays steps for the current route | Rowset: `RouteStep` rows joined to operation name, ordered by `SequenceNumber` |
| `RouteStep_Add` | `@RouteTemplateId, @SequenceNumber, @OperationTemplateId, @AppUserId` | | `RouteTemplate` (FK), `OperationTemplate` (FK), calls `Audit_LogConfigChange` | Engineering adds a step in Route Builder | Scalar: new `RouteStep.Id` (INT) |
| `RouteStep_Update` | `@Id, @SequenceNumber, @OperationTemplateId, @AppUserId` | | `OperationTemplate` (FK), calls `Audit_LogConfigChange` | Engineering edits a step's operation or sequence | Rowcount |
| `RouteStep_Remove` | `@Id, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering removes a step from a route | Rowcount |
| `RouteStep_Reorder` | `@RouteTemplateId, @StepIds NVARCHAR(MAX), @AppUserId` | Comma-delimited new order — drag-and-drop reorder support | calls `Audit_LogConfigChange` | User drops a step in a new position in the Route Builder | Rowcount: total steps reordered |

**`ItemLocation`** (eligibility map):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `ItemLocation_ListByItem` | `@ItemId` | "Where can this part run?" | `ItemLocation`, `Location` | Item Editor's Eligibility tab loads; Plant Floor validates a machine selection for a LOT (Arc 2 usage) | Rowset: `Location` rows eligible for this item |
| `ItemLocation_ListByLocation` | `@LocationId` | "What parts can run on this machine?" | `ItemLocation`, `Item` | Eligibility Map Editor loads machine column; Plant Floor machine screen shows available parts (Arc 2 usage) | Rowset: `Item` rows eligible on this location |
| `ItemLocation_Add` | `@ItemId, @LocationId, @AppUserId` | | `Item` (FK), `Location` (FK), calls `Audit_LogConfigChange` | Engineering checks a cell in the Eligibility Map matrix | Rowcount (1 if inserted, 0 if already existed) |
| `ItemLocation_Remove` | `@ItemId, @LocationId, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering unchecks a cell in the Eligibility Map matrix | Rowcount |

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

### API Layer (Named Queries → Stored Procedures)

**`Bom`** (versioned):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Bom_ListByParentItem` | `@ParentItemId, @ActiveOnly BIT = 1` | All BOM versions for a parent item | `Bom` | BOM tab opens in Item Editor; BOM Editor version selector loads | Rowset: `Bom` rows ordered by version |
| `Bom_Get` | `@Id` | Header + all lines in sort order | `Bom`, `BomLine`, `Item` | Opening a BOM version in the BOM Editor | Rowset: one `Bom` header + joined rowset of `BomLine` rows with child item names |
| `Bom_GetActiveForItem` | `@ParentItemId, @AsOfDate DATETIME2 = NULL` | Picks version active at a given moment | `Bom` | Plant Floor assembly validates material against the BOM active at run time (Arc 2 usage) | Rowset (0-1): one active `Bom` header |
| `Bom_Create` | `@ParentItemId, @VersionNumber, @EffectiveFrom, @AppUserId` | Empty BOM, no lines | `Item` (FK), calls `Audit_LogConfigChange` | Engineering creates a first BOM for an item | Scalar: new `Bom.Id` (INT) |
| `Bom_CreateNewVersion` | `@ParentBomId, @EffectiveFrom, @AppUserId` | Copies all lines from the prior version | reads `Bom`, `BomLine`; calls `Audit_LogConfigChange` | Engineering clicks "New Version" in the BOM Editor | Scalar: new version `Bom.Id` (INT) |
| `Bom_Deprecate` | `@Id, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering deprecates a BOM version | Rowcount |

**`BomLine`**:

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `BomLine_ListByBom` | `@BomId` | | `BomLine`, `Item`, `Uom` | BOM Editor renders the component lines for the active version | Rowset: `BomLine` rows joined to child item name and UOM code, ordered by `SortOrder` |
| `BomLine_Add` | `@BomId, @ChildItemId, @QtyPer, @UomId, @SortOrder, @AppUserId` | | `Bom` (FK), `Item` (FK), `Uom` (FK), calls `Audit_LogConfigChange` | Engineering adds a component line via the Item Picker | Scalar: new `BomLine.Id` (INT) |
| `BomLine_Update` | `@Id, @QtyPer, @UomId, @SortOrder, @AppUserId` | | `Uom` (FK), calls `Audit_LogConfigChange` | Engineering edits qty per, UOM, or sort order | Rowcount |
| `BomLine_Remove` | `@Id, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering removes a component line | Rowcount |

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

**Seed data to load:**

| Table | Source | Rows | Notes |
|---|---|---|---|
| `DefectCode` | `reference/seed_data/defect_codes.csv` | 153 | Codes 100–145 by department: Die Cast, Trim Shop, Machine Shop, Production Control, Quality Control, HSP. Includes `IsExcused` flag. |

### API Layer (Named Queries → Stored Procedures)

**`QualitySpec`** (header):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `QualitySpec_List` | `@ItemId NULL, @OperationTemplateId NULL` | Filter by item or operation | `QualitySpec` | Quality Spec Library loads; Item Editor's Quality Specs tab loads | Rowset: `QualitySpec` rows |
| `QualitySpec_Get` | `@Id` | Header + active version + attributes | `QualitySpec`, `QualitySpecVersion`, `QualitySpecAttribute` | Opening a spec in the Editor | Rowset: one `QualitySpec` header + joined rowsets for active version and its attributes |
| `QualitySpec_Create` | `@Name, @ItemId NULL, @OperationTemplateId NULL, @AppUserId` | | `Item` (FK, optional), `OperationTemplate` (FK, optional), calls `Audit_LogConfigChange` | Engineering creates a new quality spec | Scalar: new `QualitySpec.Id` (INT) |
| `QualitySpec_Deprecate` | `@Id, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering deprecates a spec | Rowcount |

**`QualitySpecVersion`** (versioned body):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `QualitySpecVersion_ListBySpec` | `@QualitySpecId` | | `QualitySpecVersion` | Quality Spec Editor version dropdown loads | Rowset: `QualitySpecVersion` rows ordered by version |
| `QualitySpecVersion_GetActive` | `@QualitySpecId, @AsOfDate DATETIME2 = NULL` | Picks version active at a given time | `QualitySpecVersion` | Plant Floor inspection screen loads "what spec governs this inspection right now?" (Arc 2 usage) | Rowset (0-1): one active version row |
| `QualitySpecVersion_Create` | `@QualitySpecId, @VersionNumber, @EffectiveFrom, @AppUserId` | Empty version | `QualitySpec` (FK), calls `Audit_LogConfigChange` | Engineering creates a first version of a spec | Scalar: new `QualitySpecVersion.Id` (INT) |
| `QualitySpecVersion_CreateNewVersion` | `@ParentVersionId, @EffectiveFrom, @AppUserId` | Copies attributes from prior version | reads `QualitySpecVersion`, `QualitySpecAttribute`; calls `Audit_LogConfigChange` | Engineering clicks "New Version" in the Spec Editor | Scalar: new version `QualitySpecVersion.Id` (INT) |
| `QualitySpecVersion_Deprecate` | `@Id, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering deprecates a spec version | Rowcount |

**`QualitySpecAttribute`**:

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `QualitySpecAttribute_ListByVersion` | `@QualitySpecVersionId` | | `QualitySpecAttribute`, `Uom` | Spec Editor renders the attribute grid for the active version | Rowset: attribute rows joined to UOM code, ordered by `SortOrder` |
| `QualitySpecAttribute_Add` | `@QualitySpecVersionId, @AttributeName, @DataType, @TargetValue, @LowerLimit, @UpperLimit, @UomId, @SampleTrigger, @SortOrder, @AppUserId` | | `QualitySpecVersion` (FK), `Uom` (FK), calls `Audit_LogConfigChange` | Engineering adds a measurable attribute to a spec version | Scalar: new `QualitySpecAttribute.Id` (INT) |
| `QualitySpecAttribute_Update` | `@Id, @AttributeName, @DataType, @TargetValue, @LowerLimit, @UpperLimit, @UomId, @SampleTrigger, @SortOrder, @AppUserId` | | `Uom` (FK), calls `Audit_LogConfigChange` | Engineering edits an attribute's target/limits | Rowcount |
| `QualitySpecAttribute_Remove` | `@Id, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering removes an attribute from a spec version | Rowcount |

**`DefectCode`** (full CRUD + bulk seed):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `DefectCode_List` | `@AreaLocationId NULL, @IncludeDeprecated BIT = 0` | Filter by area | `DefectCode`, `Location` | Defect Code Manager loads; Plant Floor reject entry populates its defect dropdown filtered to the current area (Arc 2 usage) | Rowset: `DefectCode` rows joined to area name |
| `DefectCode_Get` | `@Id` | | `DefectCode` | Edit modal opens | Rowset (0-1): one defect code row |
| `DefectCode_Create` | `@Code, @Description, @AreaLocationId, @IsExcused, @AppUserId` | | `Location` (Area FK), calls `Audit_LogConfigChange` | Engineering adds a new defect code | Scalar: new `DefectCode.Id` (INT) |
| `DefectCode_Update` | `@Id, @Description, @AreaLocationId, @IsExcused, @AppUserId` | `Code` is immutable | `Location` (Area FK), calls `Audit_LogConfigChange` | Engineering edits a defect code | Rowcount |
| `DefectCode_Deprecate` | `@Id, @AppUserId` | | reads `RejectEvent`, calls `Audit_LogConfigChange` | Engineering deprecates a defect code | Rowcount |
| `DefectCode_BulkLoadFromSeed` | `@CsvData NVARCHAR(MAX), @AppUserId` | Initial load from `defect_codes.csv` | calls `DefectCode_Create` per row (transitively `Audit_LogConfigChange`) | Engineer clicks "Bulk Load" during initial deployment (one-time) | Scalar: count of rows inserted |

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

**Seed data to load:**

| Table | Source | Rows | Notes |
|---|---|---|---|
| `DowntimeReasonType` | hard-coded | 6 | Equipment, Miscellaneous, Mold, Quality, Setup, Unscheduled |
| `DowntimeReasonCode` | `reference/seed_data/downtime_reason_codes.csv` | 353 | DC=86, MS=242, TS=25. **Note:** ~25 rows have empty `TypeId` per `parse_warnings.md` — engineering must assign types before go-live. |
| (Ignition OPC config) | `reference/seed_data/opc_tags.csv` | 161 | Drives Ignition OPC connection config (OmniServer + TOPServer), not a SQL table. 71 Omni + 90 TOP rows. |

### API Layer (Named Queries → Stored Procedures)

**`DowntimeReasonType`** (read-only — seeded):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `DowntimeReasonType_List` | — | Returns 6 fixed types | `DowntimeReasonType` | Downtime Reason Code Manager filter dropdown loads; Plant Floor downtime entry screen populates its type dropdown (Arc 2 usage) | Rowset: 6 `DowntimeReasonType` rows |

**`DowntimeReasonCode`** (full CRUD + bulk seed):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `DowntimeReasonCode_List` | `@AreaLocationId NULL, @DowntimeReasonTypeId NULL, @IncludeDeprecated BIT = 0` | Filter by area and/or type | `DowntimeReasonCode`, `Location`, `DowntimeReasonType` | Downtime Reason Code Manager loads; Plant Floor operator picks a reason code filtered to their area (Arc 2 usage) | Rowset: `DowntimeReasonCode` rows joined to area name and type name |
| `DowntimeReasonCode_Get` | `@Id` | | `DowntimeReasonCode` | Edit modal opens | Rowset (0-1): one reason code row |
| `DowntimeReasonCode_Create` | `@Code, @Description, @AreaLocationId, @DowntimeReasonTypeId, @IsExcused, @AppUserId` | | `Location` (Area FK), `DowntimeReasonType` (FK), calls `Audit_LogConfigChange` | Engineering adds a new downtime code | Scalar: new `DowntimeReasonCode.Id` (INT) |
| `DowntimeReasonCode_Update` | `@Id, @Description, @AreaLocationId, @DowntimeReasonTypeId, @IsExcused, @AppUserId` | | `Location` (Area FK), `DowntimeReasonType` (FK), calls `Audit_LogConfigChange` | Engineering edits a downtime code (including assigning a type to a previously untyped row) | Rowcount |
| `DowntimeReasonCode_Deprecate` | `@Id, @AppUserId` | | reads `DowntimeEvent`, calls `Audit_LogConfigChange` | Engineering deprecates a downtime code | Rowcount |
| `DowntimeReasonCode_BulkLoadFromSeed` | `@CsvData NVARCHAR(MAX), @AppUserId` | Initial load from `downtime_reason_codes.csv` | calls `DowntimeReasonCode_Create` per row (transitively `Audit_LogConfigChange`) | Engineer clicks "Bulk Load" during initial deployment (one-time) | Scalar: count of rows inserted |

**`ShiftSchedule`**:

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `ShiftSchedule_List` | `@ActiveOnly BIT = 1` | | `ShiftSchedule` | Shift Schedule Editor loads; Plant Floor shift context resolution at login (Arc 2 usage) | Rowset: `ShiftSchedule` rows |
| `ShiftSchedule_Get` | `@Id` | | `ShiftSchedule` | Edit modal opens | Rowset (0-1): one shift schedule row |
| `ShiftSchedule_Create` | `@Name, @StartTime, @EndTime, @DaysOfWeek, @EffectiveFrom, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering adds a new shift schedule | Scalar: new `ShiftSchedule.Id` (INT) |
| `ShiftSchedule_Update` | `@Id, @Name, @StartTime, @EndTime, @DaysOfWeek, @EffectiveFrom, @AppUserId` | | calls `Audit_LogConfigChange` | Engineering edits a shift schedule | Rowcount |
| `ShiftSchedule_Deprecate` | `@Id, @AppUserId` | | reads `Shift`, calls `Audit_LogConfigChange` | Engineering deprecates a shift schedule | Rowcount |

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
