# Phase G — Capability Summary (G.1 + G.2 delivered 2026-04-22)

**Document:** MPP-MES-PHASE-G-CAP-2026-04-22
**Version:** 1.0
**Date:** 2026-04-22
**Prepared By:** Blue Ridge Automation
**Audience:** Internal — snapshot of capability added by Phase G sub-phases G.1 (migration) and G.2 (Tools + Workorder code-table procs)

---

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 1.0 | 2026-04-22 | Blue Ridge Automation | Initial snapshot covering the G.1 migration (`0010_phase9_tools_and_workorder.sql`) and the G.2 stored-procedure layer (45 new procs, stored proc count 171 → 216). 779/779 existing tests still pass. Companion to commits `a43481f` (G.1 migration), `56ceb4a` (OI-11 revert to 1-line BOM), `d0910f3` (G.2 procs). |

---

## Context

Phase G of the 2026-04-20 OI review refactor delivers the SQL side of the new Tool Management subsystem (Phase B spec) plus additive Phase E changes (OI-12/18/19/20). Split into sub-phases:

- **G.1 — Migration** (✅ done, commit `a43481f`) — Tools schema, 2 Workorder code tables, Parts ALTERs, Audit seed rows
- **G.2 — Tools + Workorder code-table procs** (✅ done, commit `d0910f3`) — 45 stored procedures
- **G.3 — Phase E additive procs** (queued) — ~5 procs: extend ItemLocation, Item, ContainerConfig for new columns
- **G.4 — AppUser legacy-column cleanup** (queued) — coordinated drop of ClockNumber + PinHash
- **G.5 — Test suites** (queued) — ~60 assertions across ~7 new test suites

This note snapshots what's now *executable* via the stored-proc layer. Deferred to Arc 2 Phase 1: `Workorder.WorkOrder` and `Workorder.ProductionEvent` column adds (tables don't exist yet).

---

## What G.1 + G.2 Together Enable

### Tool identity management (system of record)

| Capability | Proc(s) |
|---|---|
| Create a Tool with type, code, name, rank, status | `Tool_Create` |
| Look up a Tool by Id or Code (barcode scan) | `Tool_Get`, `Tool_GetByCode` |
| List / filter Tools by Type and Status | `Tool_List` |
| Update mutable fields (Name, Description, DieRankId) | `Tool_Update` |
| Transition business state (Active / UnderRepair / Scrapped / Retired) | `Tool_UpdateStatus` |
| Soft-delete a Tool (row lifecycle) — rejected when mounted | `Tool_Deprecate` |

**Business rules enforced at the proc layer (not just schema):**
- `DieRankId` only settable on Die-type tools (rejected with friendly message for non-Die).
- `Code` unique globally (even across deprecated rows).
- Deprecation blocked when an active `ToolAssignment` exists — Release first.

### Polymorphic attribute schema (runtime-extensible, no schema changes)

| Capability | Proc(s) |
|---|---|
| Add / edit / deprecate attribute definitions per ToolType | `ToolAttributeDefinition_Create/Update/Deprecate` |
| Reorder attribute definitions (up/down arrows) | `ToolAttributeDefinition_MoveUp/MoveDown` |
| List the attribute schema for a ToolType | `ToolAttributeDefinition_ListByType` |
| Get / Upsert / Remove attribute values on a Tool | `ToolAttribute_Get*`, `_Upsert`, `_Remove` |

**Integrity rules:**
- `DataType` CHECK pins to `{ String, Integer, Decimal, Boolean, Date }`.
- `ToolAttribute_Upsert` validates the attribute definition belongs to the Tool's ToolType (prevents cross-type writes).
- `SortOrder` auto-assigned on create; editable via MoveUp/MoveDown.

### Die cavity tracking (die cast only)

| Capability | Proc(s) |
|---|---|
| Register cavities 1..N on a Die | `ToolCavity_Create` |
| List cavities on a Tool | `ToolCavity_ListByTool` |
| Transition cavity state (Active / Closed / Scrapped) | `ToolCavity_UpdateStatus` |
| Soft-delete a cavity row | `ToolCavity_Deprecate` |

**Integrity rules:**
- `ToolCavity_Create` rejects when the parent Tool's `ToolType.HasCavities = 0`.
- `(ToolId, CavityNumber)` unique among active rows (filtered UNIQUE at DB; pre-checked at proc).
- 3-state status per Phase B spec: `Active` (producing), `Closed` (shut off, die runs without it), `Scrapped` (destroyed).

### Mount / unmount lifecycle (supervisor-elevated shop-floor action)

| Capability | Proc(s) |
|---|---|
| Mount a Tool on a Cell (supervisor AD-elevated) | `ToolAssignment_Assign` |
| Release the active assignment for a Tool | `ToolAssignment_Release` |
| Query "what tool is currently on this Cell?" | `ToolAssignment_ListActiveByCell` |
| Full check-in/out history for a Tool | `ToolAssignment_ListByTool`, `_History` (with From/To window) |

**Integrity rules:**
- `CellLocationId` validated via LocationTypeDefinition → LocationType join — must be Cell-tier.
- Filtered UNIQUE at DB on `(ToolId)` where `ReleasedAt IS NULL` — only one active assignment per Tool.
- Filtered UNIQUE at DB on `(CellLocationId)` where `ReleasedAt IS NULL` — only one active assignment per Cell.
- Procs pre-check both for friendly error messages before DB unique-violation fires.
- Append-only table — no UPDATE to move assignments; operator Releases then Assigns again.

### Die rank compatibility matrix (gates OI-05 merges)

| Capability | Proc(s) |
|---|---|
| Admin CRUD on DieRank rows with sort ordering | `DieRank_Create/Update/Deprecate/MoveUp/MoveDown` |
| List / Get DieRank rows | `DieRank_List`, `_Get` |
| Upsert a compatibility pair (A, B) → CanMix | `DieRankCompatibility_Upsert` |
| Look up a pair compatibility (direction-independent) | `DieRankCompatibility_GetPair` |
| Browse the full matrix | `DieRankCompatibility_List` |
| Remove a pair | `DieRankCompatibility_Remove` |

**Integrity rules:**
- `DieRankCompatibility` stores only canonical pairs — CHECK constraint enforces `RankAId <= RankBId`.
- `_Upsert` and `_GetPair` canonicalise input (smaller-Id, larger-Id) before lookup/write, so `(A,B)` and `(B,A)` always resolve to the same row.
- `DieRank_Deprecate` rejects if any Tool references the rank *or* any compatibility row references it — forces the admin to clean dependents first.
- Initial seed is empty; merge validation (Arc 2) rejects cross-die merges with supervisor AD override until MPP Quality populates the matrix.

### Code-table reads (Config Tool dropdowns)

| Table | Read procs | Seed |
|---|---|---|
| `Tools.ToolStatusCode` | `_List` | 4 rows: Active, UnderRepair, Scrapped, Retired |
| `Tools.ToolCavityStatusCode` | `_List` | 3 rows: Active, Closed, Scrapped |
| `Tools.ToolType` | `_List`, `_Get` | 6 rows: Die, Cutter, Jig, Gauge, AssemblyFixture, TrimTool |
| `Workorder.WorkOrderType` | `_List`, `_Get` | 3 rows: Demand, Maintenance, Recipe |
| `Workorder.ScrapSource` | `_List`, `_Get` | 2 rows: Inventory, Location |

---

## Capability Gains vs Design Targets

| Design target (Phase B spec §Stored procedure surface) | Delivered? |
|---|---|
| `Tools.ToolType` — _List, _Get | ✅ Both |
| `Tools.ToolAttributeDefinition` — full CRUD + sort | ✅ 7 procs |
| `Tools.Tool` — full CRUD + GetByCode + UpdateStatus | ✅ 7 procs |
| `Tools.ToolAttribute` — per-tool CRUD | ✅ 3 procs (ListByTool, Upsert, Remove) |
| `Tools.ToolCavity` — per-tool CRUD + status transitions | ✅ 4 procs |
| `Tools.ToolAssignment` — assign / release / history | ✅ 5 procs |
| `Tools.DieRank` — full CRUD + sort | ✅ 7 procs |
| `Tools.DieRankCompatibility` — matrix editor | ✅ 4 procs (list, get-pair, upsert, remove) |
| Status code tables — _List | ✅ ToolStatusCode + ToolCavityStatusCode |
| `Workorder.WorkOrderType` — _List | ✅ + added _Get for parity |
| `Workorder.ScrapSource` — _List | ✅ + added _Get for parity |

Over-delivered by 2: added `_Get` procs on WorkOrderType and ScrapSource for symmetry with other code tables. Total 45 procs (spec estimated ~35).

---

## What G.2 Enables for Downstream Work

### Configuration Tool frontend (Arc 1 add)
The full backend exists for these Phase 9 Perspective screens:

- **Tool Browser** — filter tree by ToolType, detail pane (`Tool_List` + `Tool_Get`)
- **Tool Editor** — dynamic attribute form driven by `ToolAttributeDefinition_ListByType`, cavity panel driven by `ToolCavity_ListByTool`
- **Tool Assignment History** — timeline via `ToolAssignment_History`
- **Tool Attribute Definition Editor** — CRUD + sort arrows
- **Die Rank Management** — empty-seeded table ready for MPP Quality's list
- **Die Rank Compatibility Matrix** — grid editor on `DieRankCompatibility_Upsert`

### Arc 2 Plant Floor dependencies that will FK into Phase G output
- `Workorder.WorkOrder.WorkOrderTypeId` FK → `Workorder.WorkOrderType` (created here) — Arc 2 Phase 1 bakes into CREATE TABLE.
- `Workorder.WorkOrder.ToolId` FK → `Tools.Tool` (created here) — same.
- `Workorder.ProductionEvent.ScrapSourceId` FK → `Workorder.ScrapSource` (created here) — same.
- Arc 2's `Lots.Lot_Merge` proc consults `Tools.DieRankCompatibility_GetPair` for OI-05 cross-die merge validation.

---

## Conventions Verified

- **Single result set** per proc (`SELECT Status, Message [, NewId]`) — no OUTPUT params. FDS-11-011 compliance.
- **Three-tier error hierarchy** — parameter validation → business rule → CATCH with RAISERROR.
- **Every exit path** emits the result SELECT (rejections included).
- **Audit-in-transaction / failure-out-of-transaction** with nested TRY/CATCH around the failure log so audit breakage can't mask the real error.
- **Code-string audit** — `@LogEntityTypeCode = N'Tool'`, `@LogEventTypeCode = N'Created'`.
- **LogEntityTypeCode values** resolved to the 9 new seed rows in migration 0010 (Ids 31–39).
- **EXEC parameters use @variables, never inline expressions** — one violation caught during testing (`ISNULL(@ExistingId, 0)` as EXEC param in `DieRankCompatibility_Upsert`), refactored to a pre-computed `@AuditId`.
- **RAISERROR, not THROW** in CATCH blocks per the `feedback_sql_patterns.md` memory.

---

## Build & Test

| Metric | Before G.2 | After G.2 |
|---|---|---|
| Versioned migrations | 10 | 10 |
| Stored procedures | 171 | **216** (+45) |
| Tables | 59 | 59 |
| Passing tests | 779 | **779** (no regression) |
| New tests added | — | 0 (Phase G.5 will add ~60) |

Reset + test cycle time: ~10s on SQL Server 2025 local.

---

## What's Queued

- **G.3** — Phase E additive procs (~5 files): extend `Parts.ItemLocation_Add` for consumption metadata + new `_SetConsumptionMetadata`, extend `Parts.Item_Update` for `CountryOfOrigin`, extend `Parts.ContainerConfig_Update` for `MaxParts`.
- **G.4** — AppUser legacy-column cleanup: drop `ClockNumber` + `PinHash` + their two legacy procs (`AppUser_SetPin`, `AppUser_GetByClockNumber`), update `AppUser_Create/_Update/_Get` etc. to remove those references. Coordinated across ~6 proc files + one mini-migration.
- **G.5** — Test suites (~7 files, ~60 assertions): `0013_Tools_Types`, `0014_Tools_Tool`, `0015_Tools_Cavity`, `0016_Tools_Assignment`, `0017_Tools_Attribute`, `0018_Tools_DieRank`, `0019_Parts_ConsumptionMetadata`.

Arc 2 Phase 1 picks up from there — creates `Lots.Lot` + runtime `Workorder` tables with the Phase B / Phase E columns baked in.

---

## References

- Migration: `sql/migrations/versioned/0010_phase9_tools_and_workorder.sql`
- Procs: `sql/migrations/repeatable/R__Tools_*.sql` (41 files) + `R__Workorder_{WorkOrderType,ScrapSource}_*.sql` (4 files)
- Design spec: `docs/superpowers/specs/2026-04-21-tool-management-design.md` v0.3
- Refactor plan: `memory/project_mpp_oi_refactor.md`
- Data Model: `MPP_MES_DATA_MODEL.md` v1.8-rev (§7 Tools schema)
- FDS: `MPP_MES_FDS.md` v0.10-rev (Tool Management referenced across §§2.5 OI-08, 5.5 OI-05, 6.10 OI-07, 5.10 OI-11)
- Open Issues Register: `MPP_MES_Open_Issues_Register.md` v2.6
