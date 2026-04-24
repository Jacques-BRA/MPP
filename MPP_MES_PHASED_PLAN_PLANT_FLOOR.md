# MPP MES — Phased Delivery Plan: Arc 2 (Plant Floor MES)

**Document ID:** MPP-PLAN-ARC2-v0.2
**Project:** Madison Precision Products MES Replacement
**Contractor:** Blue Ridge Automation
**Version:** 0.2 (2026-04-24)
**Status:** Working draft — design spec at `docs/superpowers/specs/2026-04-16-arc2-phased-plan-design.md` (v0.1) and `docs/superpowers/specs/2026-04-23-arc2-model-revisions.md` (v0.1 — authoritative for post-Phase-G decisions)

> **Reader note (v0.2):** The individual phase sections below predate the 2026-04-23 Arc 2 model revisions. Read the new **§"v0.2 Alignment Overlay"** immediately after this header before executing any phase — it captures the deltas (auth model, Tool/Cavity on Lot, ProductionEvent checkpoint shape, IdentifierSequence, dashboard-pattern rejection) that supersede or refine the per-phase narratives. Phase-by-phase rewrites remain queued for a future revision pass.

---

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 0.1 | 2026-04-16 | Blue Ridge Automation | Initial draft — nine phases (0 customer validation gate through 8 downtime + shift). Mirrors Arc 1 plan structure. Codifies Arc 2 cross-cutting conventions B1–B11. |
| 0.2 | 2026-04-24 | Blue Ridge Automation | **Alignment overlay for post-Phase-G decisions (Phase C security rewrite + 2026-04-23 Arc 2 model revisions).** v0.1 predates every post-2026-04-20 meeting outcome and all Phase G work. Rather than rewrite 1700 lines in place, v0.2 adds a new §"v0.2 Alignment Overlay" after the front matter that captures the deltas phase-by-phase: Phase 0 open-items list refreshed (OI-03, OI-06, OI-09 closed; new OI-31 opened; new discovery items — WorkOrder BIT flags, TrackingMode, historical data migration, ShotCount semantics); Phase 1 auth narrative rewrites from clock# + PIN to initials-only Phase C model, `AppUser_GetByInitials` added, `Lots.IdentifierSequence` seeded at cutover; Phase 2 `Lot_Create` gains `@ToolId` + `@ToolCavityId` (optional, required-by-origin-check), `Lot_Merge` nulls Tool on merged row; Phase 3 wholesale — Tools.Tool / ToolCavity become system of record, terminal UX auto-populates Tool from active assignment + elevated Edit, cavity-parallel LOTs are peers (not sublots), `ProductionEvent_Record` implements checkpoint shape; Phase 4 trim check-in fires checkpoint ProductionEvent, ScrapSource=Location for scrap-from-workstation events; Phase 5 sub-LOT split unchanged (Machining-only); Phase 6 ContainerConfig.MaxParts + finished-goods LOT auto-close on container fill + 1-line BOM consumption; Phase 7 Workorder.ScrapSource usage, rank-based merges (OI-05) + post-merge-NULL-Tool; Phase 8 already correct. Two new cross-cutting rules codified: **purpose-built Perspective views per terminal function** (no generic dashboard-configuration engine; LocationAttribute for business policies only), and **UserInterfaceScript DB-stored-runtime-code pattern NOT reproduced**. Phase 0 customer-validation gate expanded with 9 consolidated MPP input items. Source: `docs/superpowers/specs/2026-04-23-arc2-model-revisions.md` §§7–9. |

---

## Purpose

This document is the phased delivery plan for **Arc 2 (Plant Floor MES)** — the operator-facing portion of the MPP MES replacement. It is the sibling of `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md` (Arc 1), which is complete.

**Arc 1** built the Configuration Tool: the engineering-facing surface where plant, items, routes, BOMs, quality specs, and reference vocabularies (shifts, downtime codes, defect codes) are authored. Arc 1 is delivered across eight phases and ships 9 versioned migrations, 171 repeatable stored procedures, and 779 passing tests.

**Arc 2** builds the Plant Floor MES: the operator-facing surface that runs against Arc 1's configured master data. Its audiences are **shop-floor operators, supervisors, quality staff, and shipping staff**, interacting through Ignition Perspective touch terminals, barcode scanners, and PLC-integrated production machinery. Arc 2 captures LOT lifecycle from die-cast origination through containerized shipment to Honda, with traceable genealogy at every step.

This plan is unblocked with one explicit precondition: **Phase 0 (Customer Validation Gate) must complete before Phase 1 implementation begins.** Phase 0 is a facilitation workshop with MPP stakeholders that resolves four structural decisions whose wrong answer would force a phase rebuild.

## v0.2 Alignment Overlay

**Authoritative as of 2026-04-24.** Supersedes the corresponding parts of the per-phase narratives below. Read this whole section before executing any phase.

### A. Security model (Phase 1 rewrite)

v0.1 describes clock# + PIN login. **That is obsolete.** Phase C (2026-04-21) replaced it end-to-end:

- Operators are identified by **initials only** (no clock number, no PIN) entered at a shop-floor terminal. Initials establish an operator **presence context** that stamps `AppUserId` on events via `Location.AppUser_GetByInitials`.
- Interactive users (Quality, Supervisor, Engineering, Admin) continue to authenticate via Active Directory.
- **Elevated actions** require per-action AD re-prompts (FDS-04-007). No session-sticky elevation. No 5-minute timeout. No re-auth-for-sensitive flag on Terminal.
- **Dedicated vs Shared terminal modes** via `LocationAttribute` (`TerminalMode` = `Dedicated` / `Shared`). Dedicated persists presence through the shift with a 30-minute idle re-confirmation overlay ("Operate as CM? Yes / No — change"). Shared terminals prompt on first action and on machine change.
- **Pre-populated defeasible Initials field** on every mutation screen.
- Operator `AppUser` rows are managed in the Configuration Tool (Admin screen); they carry no AD account.

Phase 1 delivers `Location.AppUser_GetByInitials` and the Initials-presence context bootstrapping. The v0.1 `AppUser_AuthenticateByClockAndPin` proc is not built. Migration `0012_phase_c_security.sql` (already landed in Phase G) dropped `AppUser.ClockNumber` + `PinHash` columns — do not reference them from any Arc 2 proc.

### B. Tool / Cavity on Lot, not on ProductionEvent

`Lots.Lot` carries `ToolId BIGINT NULL FK → Tools.Tool` and `ToolCavityId BIGINT NULL FK → Tools.ToolCavity` as of Data Model v1.9 (Arc 2 Phase 1 migration). Rules:

- **Required at `Lot_Create` for die-cast-origin LOTs.** `Lots.Lot_Create` signature SHALL include `@ToolId BIGINT = NULL, @ToolCavityId BIGINT = NULL`. If `@LotOriginTypeCode = 'Manufactured'` and the scanned Cell has an active `Tools.ToolAssignment`, both params are required and validated. Other origins pass NULL.
- **NULL on merged LOTs.** `Lots.Lot_Merge` writes `ToolId = NULL, ToolCavityId = NULL` on the resulting merged row. Downstream Honda-trace reconstructs Tool context via `LotGenealogy` walk of pre-merge source LOTs.
- **Downstream LOTs do NOT carry.** Trim / Machining intermediate / Assembly LOTs created via `ConsumptionEvent` have NULL `ToolId` / `ToolCavityId`. Genealogy walk is the system of record for Tool-filtered reports.
- **`Workorder.ProductionEvent` does NOT carry Tool or Cavity.** Derived via `ProductionEvent.LotId → Lot.ToolId / Lot.ToolCavityId`. Pre-v0.2 plan references to `DieIdentifier` / `CavityNumber` hot columns on ProductionEvent are superseded.

### C. ProductionEvent is a checkpoint table (Arc 2 Phase 1 CREATE)

Per FDS-03-017a revised + FDS-06-003 revised (v0.11):

- Columns: `Id`, `LotId`, `OperationTemplateId`, `WorkOrderOperationId` (nullable), `EventAt`, `ShotCount` (cumulative), `ScrapCount` (cumulative), `ScrapSourceId` (nullable), `WeightValue`, `WeightUomId`, `AppUserId`, `TerminalLocationId`, `Remarks`.
- **Not on the table:** `LocationId`, `ItemId`, `DieIdentifier`, `CavityNumber`, `StartedAt`, `EndedAt`, per-event `GoodCount` / `NoGoodCount`.
- **Required index:** `(LotId, EventAt DESC)` — "previous event for this LOT" must be a single-row seek.
- **Deltas via `LAG()`:** `ShotsSinceLast = ShotCount - LAG(ShotCount) OVER (PARTITION BY LotId ORDER BY EventAt)`. A missed checkpoint doesn't compound errors.
- **ShotCount is OPEN** — may migrate to derived-from-aggregated-LOT-quantity before Phase 3 implementation. Default until decided: keep column, mark provisional.

### D. `Lots.IdentifierSequence` table (Arc 2 Phase 1 CREATE)

New table + proc per OI-31 / FDS-16-001..003. Replaces Flexware `IdentifierFormat`. Arc 2 Phase 1 migration CREATEs the table with the column contract in Data Model v1.9 §3 Lots, plus companion proc `Lots.IdentifierSequence_Next @Code`. Seeded at cutover with `Lot` (`MESL{0:D7}`) and `SerializedItem` (`MESI{0:D7}`); `LastValue` sampled from Flexware on cutover day. Every LOT-create / SerializedPart-create path calls `IdentifierSequence_Next` — no ad-hoc counter maintenance anywhere.

### E. Cavity-parallel LOTs are peers, not sublots

A die-cast machine mounting a Tool with N active cavities produces **N parallel independent LOTs**, each with `ToolCavityId` set at creation. No parent/child FK between them; genealogy is flat at Die Cast. Each fills at its own rate; each closes independently via explicit operator Complete + Move.

The v0.1 plan Phase 5 language around "sub-LOT split" is **Machining-only**. Phase 3 Die Cast narrative must not reproduce sublot mechanics for cavity-parallel LOTs — they're first-class LOTs.

### F. Lazy, operator-driven LOT creation

`Lot_Create` fires whenever the operator decides to log a LOT — not at any prescribed moment. Valid moments: basket-full, before starting the next LOT, any other moment the operator chooses. The MES SHALL NOT auto-create N LOTs at run start. Phase 3 UI / procs SHALL NOT require a LOT row to exist for an in-progress cavity. Physical-but-unlogged baskets are normal.

### G. LOT close semantics

- **Component LOTs** (Die Cast, Trim, intermediate Machining): explicit operator-driven close. "Complete + Move" is a combined UI action — status transition + movement in one atomic proc. No auto-close.
- **Finished-goods LOTs** (Assembly end-products packed into shipping Containers): MAY auto-close on `Container_Complete`. Phase 6 owns the detail.

### H. Purpose-built Perspective views per terminal function

Die Cast terminal view, Trim Station view, Machining IN view, Machining OUT view, Sort Cage view, Shipping view, Hold Management view, Weigh Station view, etc. B11 zone-based routing picks the right view by terminal Location + `DefaultScreen` LocationAttribute.

**Flexware's `*DashboardConfiguration` family is NOT reproduced** (`LotTrackingDashboardConfiguration`, `LotCreateDashboardConfiguration`, `WorkOrderDashboardConfiguration`, `FinalAssemblyDashboardConfiguration`, `CreateAllocationDashboardConfiguration`, `SortDashboardConfiguration`, `MaterialLabelPrintDashboardConfiguration`, `WorkstationDashboardConfiguration`). If the Trim view needs different populate behavior than Assembly, they are different views — not a configurable flag. **LocationAttribute is for business policies only** (DefaultScreen, TerminalMode, LinesideLimit, TrackingMode, IpAddress, RequireCastPartAllocationOverride). Not UI config. Not dashboard behavior.

### I. UserInterfaceScript — NOT reproduced

Flexware's pattern of storing runtime JavaScript in a DB table and executing it from dashboard save-buttons is explicitly out of scope. Any per-terminal behavior variance lives in Ignition project scripts or Perspective view-level event handlers, version-controlled. OI-26 was deleted (not Resolved) to remove this path from consideration.

### J. Non-Die Tool Assignment — known limitation

`Tools.ToolAssignment` has two filtered unique indexes today: `UQ_ToolAssignment_ActiveTool` (correct for all tool types) and `UQ_ToolAssignment_ActiveCell` (Die-Cast-correct; wrong for Machining / Trim / Assembly where multiple tools coexist per cell). Not blocking for MVP. Post-MVP adjustment: scope the Cell UNIQUE to `ToolType = Die` or drop it. Documented in Data Model v1.9 §7 Tools.

### K. Phase 0 open-items refresh

The v0.1 Phase 0 table is stale. Use this consolidated list for the Phase 0 workshop:

**Closed (no action needed):**

- OI-01 Event outbox (direct-call-with-logging per v0.9 resolution)
- OI-03 Shift runtime adjustments (event-derived availability, no minute adjustments)
- OI-06 / UJ-01 Operator identity (Phase C — initials + AD elevation)
- OI-09 Multi-part / cavity-parallel LOTs (peers with `ToolCavityId`, not sublots)
- OI-11 Casting → Trim (1-line BOM consumption, no new schema)

**Gating — must resolve at Phase 0 (wrong answer rebuilds a phase):**

| Item | Question | Why it gates |
|---|---|---|
| **OI-31** (NEW) | IdentifierSequence format carry-forward + cutover `LastValue` values. Any additional counters (container barcodes, shipping print sequences) in use? Reset policy? Rollover policy at 9,999,999? | Phase 1 migration seeds `Lots.IdentifierSequence.LastValue` at cutover-day values; wrong seed = LTT collisions with live Flexware LOTs. |
| **OI-02 / UJ-13** | Weight vs count container closure. Is scale-driven closure the design? | Phase 6 non-serialized container lifecycle; most Flexware WO BIT flags are subsumed by this decision. |
| **OI-05 / UJ-08** | Full die-rank compatibility matrix owed by MPP Quality. | Phase 7 `Lot_Merge` rejects cross-die merges until matrix loaded; supervisor override is the only path otherwise. |
| **OI-07 / UJ-07** | Maintenance WO engine scope (Ben owes). Lifecycle, scheduling, integration with MPP maintenance team's existing tooling. | Phase G delivered the schema hook (FUTURE flow); Maintenance WO Perspective work doesn't start until Ben closes this. |
| **OI-08 / UJ-12 addenda** | Final `TrackingMode` enumeration on Cell (values?) + Part ↔ Machine validity model confirmation. | Phase 3 / 4 terminal UX + scan-in guard depends on these. |
| **UJ-05** | Sort Cage serial migration — void-and-recreate or update-in-place with new `ContainerSerialHistory` table? | Phase 7 Sort Cage flow; update-in-place requires a new table. |
| **UJ-10** | Shift boundary rules — carryover of open downtime events, partial containers, in-progress LOTs. | Phase 1 `Shift_End` / Phase 8 boundary ticker cannot be built without this. |
| **UJ-16** | `HardwareInterlockBypassed` flag location — `ContainerSerial` / `ProductionEvent` / both. | Phase 6 Assembly schema + procs. |
| **FDS-06-030 WorkOrder BIT-flag enumeration** | Which Flexware WorkOrder flags are live in production (`IsCameraProcessingEnabled`, `IsScaleProcessingEnabled`, `GroupTargetWeight` + tolerance + UOM, `RecipeNumber`, `TrayQuantity`, `ReturnableDunnageCode`, `Customer`)? | Phase 1 `Workorder.WorkOrder` CREATE column list. Dead flags don't ship. |
| **Historical data migration** | Cutover approach — which entities migrate (LOTs, SerializedItems, ProductionOrders, Containers, Genealogy). Discrepancy review for unmatched rows (e.g., Flexware `LotAttribute.DIE NAME` with no matching `Tools.Tool.Code`). | Phase 1 migration-script + pre-flight validation design. |
| **ShotCount semantics** | ProductionEvent.ShotCount = cumulative counter OR derived from aggregated LOT quantities? | Phase 3 operator-screen design + reporting path. |
| **Workstation `DefaultScreen` seeding** | List of terminal-function Perspective views + which terminal routes to which. | Phase 1 seed data for B11 routing. |
| **Honda AIM integration contract** | Confirm `GetNextNumber` format, `PlaceOnHold` / `ReleaseFromHold` / `UpdateAim` signatures, error recovery expectations. | Phase 7 shipping Gateway scripts. |
| **Label template scope** | Flexware has 3 templates (CONTAINER, LOT, CONTAINER_HOLD). Ours matches + any new (Sort Cage, Hold, Void)? | Phase 6 / 7 label print procs + ZPL templates. |

**Opportunistic items** (resolve if MPP available; fallbacks exist): UJ-04 non-serialized container lifecycle, UJ-09 material verification, UJ-11 / UJ-19 paper-to-screen transition, UJ-17 vision vs barcode, OI-02 opportunistic pre-validation.

### L. Cross-cutting overlay — convention additions

Appended to Arc 2 cross-cutting conventions B1–B11:

- **B12 — Purpose-built Perspective views.** No generic dashboard-configuration engine. One view per terminal function; B11 routing picks by Terminal Location. LocationAttribute for business policies only, never UI config.
- **B13 — Tool/Cavity system of record.** Lives on `Lots.Lot`. Never duplicated on `ProductionEvent`, `ConsumptionEvent`, or any derived LOT. Honda-trace queries walk `LotGenealogy` to the origin LOT and read Tool/Cavity from there.
- **B14 — Checkpoint-shape events.** `Workorder.ProductionEvent` is a checkpoint table. Cumulative counters + `LAG()` deltas. No per-event `GoodCount` / `NoGoodCount`; no `StartedAt` / `EndedAt`; no `CellLocationId`. See §C above.
- **B15 — Identifier minting via `IdentifierSequence_Next`.** All LOT LTTs, serialized-item IDs, and future non-AIM counters go through `Lots.IdentifierSequence_Next @Code`. No ad-hoc identifier generation.
- **B16 — Lazy LOT creation.** No auto-create of LOTs at run start. Operator drives timing. Phase 3 UI / procs must not require a LOT row for in-progress production.

---

## Architecture Pattern

Arc 1 used Ignition Named Queries calling stored procedures, with Perspective views as thin CRUD forms over the proc layer. Arc 2 builds on that architecture but adds two more layers, both of which are first-class in this plan:

**Ignition Gateway Scripts.** Many plant-floor events originate outside Perspective sessions: PLC tags change, OmniServer scales publish values, timers tick at shift boundaries, and external systems (AIM, Zebra printers) expect direct calls. These live in Ignition Gateway scripts — long-running background scripts that watch OPC tags, poll queues, and issue HTTP/SOAP calls. Gateway scripts call stored procs for DB work; they never execute DML directly.

**PLC/OPC Touchpoints.** Plant-floor workflows tangle with assembly PLC handshakes (MIP), scales (OmniServer), and vision systems (Cognex). This plan describes PLC touchpoints **functionally** — what tag is read, what is written, what the handshake semantics are — but defers bit-level OPC addresses and register maps to `reference/5GO_AP4_Automation_Touchpoint_Agreement.pdf` and FRS Appendix C.

The three layers compose as:

```
  Perspective View (touch UI)
       │         │
       │ (Named Query)           (Named Query)
       ▼         ▼                      ▼
  Stored Proc (SQL)   ◀─── calls ───  Gateway Script (Python)
                                          │        │
                                          ▼        ▼
                                     OPC/PLC   AIM / Zebra / etc.
```

Stored procs remain the authoritative write path — no Gateway script or Perspective binding performs DML directly. Every external I/O (AIM HTTP, Zebra socket write, OPC tag write-back) is bracketed with `Audit.Audit_LogInterface` calls so the external conversation is reconstructible forever.

## Cross-Cutting Concerns

Arc 1's conventions carry forward unchanged and apply to every Arc 2 proc. They are not repeated here; see `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md` § Cross-Cutting Concerns. In summary: audit streams (ConfigLog, OperationLog, InterfaceLog, FailureLog), code-table-backed status everywhere, soft-delete via `DeprecatedAt` (never hard DELETE except where explicitly documented — `BomLine`, `RouteStep`), optimistic locking via `@RowVersion` on Update, `SortOrder` + `_MoveUp`/`_MoveDown` instead of drag-drop, BIGINT/NVARCHAR everywhere, single result set per proc (no OUTPUT parameters), `RAISERROR` in nested CATCH blocks (not `THROW`), user attribution via `@AppUserId BIGINT`.

Arc 2 adds the following eleven conventions. These are normative for every phase of this plan.

### B1 — Operator session context binding

Every Arc 2 mutation proc accepts both `@AppUserId BIGINT` and `@TerminalLocationId BIGINT` as required parameters. Procs validate both exist and are active (AppUser not deprecated, Terminal Location not deprecated, Location of type `Terminal`). On any rejection, `Audit.FailureLog` captures both values along with the attempted parameters.

Session lifecycle (inactivity timeout, re-auth for high-security actions, logout) is **enforced at the Ignition Perspective layer**, not in procs. Procs treat every call as equally authoritative; Perspective is responsible for ensuring the caller is authenticated and the session has not expired.

### B2 — `BlocksProduction` interlock discipline

Any proc that advances a LOT through the process — `Lot_MoveTo`, `ProductionEvent_Record`, `ConsumptionEvent_Record`, `Lot_Split`, `Lot_Merge`, `ContainerSerial_Add`, `Container_Create` — first calls the shared guard `Lots.Lot_AssertNotBlocked(@LotId)`. The guard reads `Lot.LotStatusId → LotStatusCode.BlocksProduction`. Any status with `BlocksProduction=1` (Hold, Scrap, Closed) trips the guard. A tripped guard is a **business rule violation**, not an exception: the caller receives `Status=0, Message='LOT 2026-04-06-0001 is in status Hold and cannot progress'`, the attempt is logged to FailureLog, and no partial writes occur.

The guard is delivered in Phase 1 (as part of the LOT core skeleton) and reused across all downstream phases.

### B3 — Open-event invariant

`Oee.DowntimeEvent` and `Quality.HoldEvent` both carry nullable `EndedAt` / `ReleasedAt` columns. The invariant: **at most one open event per resource at any time**. For `DowntimeEvent`, the resource is the machine `Location`; for `HoldEvent`, the resource is the `Lot` (or the optional `NonConformance`). `_Start` / `_Place` procs enforce the invariant with an explicit pre-check:

```sql
IF EXISTS (SELECT 1 FROM Oee.DowntimeEvent
           WHERE LocationId = @LocationId AND EndedAt IS NULL)
BEGIN
    SET @Status = 0;
    SET @Message = CONCAT('Machine ', @LocationName, ' already has an open downtime event');
    -- log failure, return
END
```

Attempting a second open event is a business rule violation, not an exception. `_End` / `_Release` procs reject if no open event exists.

### B4 — Gateway script layer contract

Gateway scripts call stored procs the same way Perspective views do — through parameterized Named Queries. Gateway scripts **MUST NOT** execute raw DML via `system.db.runUpdateQuery` or inline SQL. External I/O (AIM HTTP/SOAP, Zebra printer socket writes, OPC read/write via TOPServer or OmniServer) happens **only** in Gateway scripts; stored procs never reach outside the database.

Every external call is bracketed by two `Audit.Audit_LogInterface` calls: one before the call (Direction='Outbound', RequestPayload populated, ResponsePayload NULL), one after (update the same row with ResponsePayload and any error). Critical failures are additionally logged to `Audit.FailureLog`. No outbox pattern — direct calls with a full audit trail (per OI-01 resolution).

### B5 — PLC descriptive boundary

Phase narratives describe what Gateway scripts read from and write to PLC tags in prose: tag names (e.g., `PartSN`, `PartValid`, `DataReady`, `HardwareInterlockEnable`, `CycleComplete`), semantics (edge-triggered vs. level-triggered), and handshake steps. **Bit-level OPC addresses, data types, register numbers, and PLC ladder logic stay out of this plan.** They live in `reference/5GO_AP4_Automation_Touchpoint_Agreement.pdf` and FRS Appendix C. Gateway script implementation references those documents; the plan references them by path.

### B6 — Print job contract

ZPL generation for labels (LTT, shipping label, master label) is assembled in Gateway scripts from a template file plus data returned by the originating stored proc. The stored proc (`LotLabel_Print`, `ShippingLabel_Print`, etc.) writes the audit row with the full rendered `ZplContent` and returns its Id; the Gateway script reads the Id, dispatches the ZPL content to the physical Zebra printer (via socket), and records the print acknowledgement back on the same row (not via a second insert). Void labels use `IsVoid=1` + `VoidedAt` + `VoidedByUserId`; rows are never deleted.

### B7 — Late-binding reason codes

`Oee.DowntimeEvent.DowntimeReasonCodeId` is **nullable**. When a PLC detects a machine stop before an operator classifies it, `DowntimeEvent_Start` inserts the row with NULL reason. `DowntimeEvent_End` succeeds with a NULL reason. Unclassified downtime is flagged on the shift-supervisor dashboard and on shift-end reporting — it is not blocked at proc level. A separate `DowntimeReasonCode_Assign` proc fills the reason later; it refuses to overwrite an already-assigned reason (supervisors must correct by other means).

### B8 — Genealogy traversal

`Lots.Lot_GetGenealogyTree(@LotId, @Direction)` uses a recursive CTE with `OPTION (MAXRECURSION 100)`. The `@Direction` parameter takes `'Ancestors'` (walk ParentLot → ParentLot → ...) or `'Descendants'` (walk children via `LotGenealogy`). Tree depth beyond 100 hops is a business rule violation with the message `genealogy tree exceeds supported depth of 100`. Real plant genealogy never approaches this bound; the cap is a defensive recursion guard.

### B9 — Test pattern extension for open-state events

Arc 1's test pattern covered mutations with a temp-table capture of the result shape (`Status / Message / NewId`). Arc 2 extends this for open-state events: after `_Start` / `_Place`, tests assert `EndedAt IS NULL` (or `ReleasedAt IS NULL`) directly against the underlying table:

```sql
DECLARE @OpenCount INT;
SELECT @OpenCount = COUNT(*)
FROM Oee.DowntimeEvent
WHERE LocationId = @LocationId AND EndedAt IS NULL;
IF @OpenCount <> 1
    RAISERROR('Expected exactly 1 open DowntimeEvent, got %d', 16, 1, @OpenCount);
```

After `_End` / `_Release`, tests assert the same row's `EndedAt IS NOT NULL`.

### B10 — Serial number migration audit

Deferred to Phase 0 decision on UJ-05. Once resolved (void-and-recreate **or** update-in-place with a new `Lots.ContainerSerialHistory` table), this convention is appended to the plan before Phase 6 starts, with the exact procs and write sequence for Sort Cage re-containerization.

### B11 — Zone-based default screen routing

On Perspective session startup, the client IP resolves to a Terminal-type `Location` row by querying its existing `IpAddress` `LocationAttribute`. The Terminal's zone (parent Area in the `Location` hierarchy) plus a new `DefaultScreen` `LocationAttributeDefinition` on the `Terminal` `LocationTypeDefinition` drives the initial Perspective view shown to any operator who logs in at that station.

A Trim Shop terminal opens to the Trim Station Screen; a Shipping Dock terminal opens to the Shipping Screen; a Die Cast terminal opens to the Die Cast LOT Entry Screen. Operator presence (initials) is orthogonal — the default-screen lookup happens on session start, before any initials entry or per-action elevation.

No DDL change is required. The `DefaultScreen` attribute is seeded as a new `LocationAttributeDefinition` row on the `Terminal` `LocationTypeDefinition` (via migration or via the existing Arc 1 Config Tool). Phase 1 delivers `Location.Terminal_GetByIpAddress` and the `Terminal_ResolveFromSession` Gateway script that stashes Zone + DefaultScreen in session props for the Home router view to consume.

## Stored Procedure Template and Conventions

Arc 2 procs follow the same template, error hierarchy, audit placement rules, and code-review checklist defined in `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md` § Stored Procedure Template and Conventions. The template is reproduced in full there; it is not duplicated here. Cited fresh reminders:

- Three-tier error hierarchy (parameter validation → business rule → unexpected exception)
- `SET NOCOUNT ON; SET XACT_ABORT ON;` at top of every mutation proc
- Parameter validation and business-rule checks **before** `BEGIN TRANSACTION`; only the mutation wrapped in transaction
- Success audit call (`Audit.Audit_LogOperation` for Arc 2 plant-floor procs) **inside** the transaction, before `COMMIT`
- Failure audit call (`Audit.Audit_LogFailure`) outside transactions, in a nested TRY/CATCH around the failure-log insert so a failed audit-write cannot interfere with the primary rollback
- Final `SELECT @Status AS Status, @Message AS Message[, @NewId AS NewId];` on every exit path (no OUTPUT parameters — FDS-11-011)
- `RAISERROR` not `THROW` in nested CATCH blocks
- All DB references schema-qualified (`Lots.Lot`, `Audit.Audit_LogOperation`)

One Arc 2 divergence: the primary audit sink for mutation procs is **`Audit.OperationLog`** (via `Audit.Audit_LogOperation`), not `Audit.ConfigLog` (via `Audit.Audit_LogConfigChange`). This is the core distinction between the two arcs. Config Tool mutations describe engineering-authored rules; Plant Floor mutations describe operator-observed events. The two audit streams are read by different supervisory queries.

## Phase Map and Dependencies

```
Phase 0 (customer validation gate)
    │
    ▼
Phase 1 (foundation) ──────────────────────────────────▶ Phase 8 (Downtime + Shift)  [parallel]
    │
    ▼
Phase 2 (LOT lifecycle)
    │
    ▼
Phase 3 (Die Cast) ───────────────────────────┐
    │                                          │
    ├──────────────▶ Phase 4 (Move + Trim + Rx)│
    │                          │               │
    └──────────────▶ Phase 5 (Machining)       │
                               │               │
                               ▼               │
                         Phase 6 (Assembly + MIP + Container)
                               │               │
                               ▼               │
                         Phase 7 (Hold + Sort Cage + Shipping + AIM) ◀┘
```

**Direct dependency table:**

| Phase | Directly depends on | Unblocks |
|---|---|---|
| 0 | — | 1 |
| 1 | 0 | 2, 8 |
| 2 | 1 | 3 |
| 3 | 1, 2 | 4, 5, 7 |
| 4 | 1, 2, 3 | 6 |
| 5 | 1, 2, 3 | 6 |
| 6 | 1, 2, 3, 4, 5 | 7 |
| 7 | 1, 2, 3, 6 | — |
| 8 | 1 | — (parallel track) |

Phase 8 runs in parallel to Phases 2–7 as soon as Phase 1 lands. A small team can parallelize 4/5 (both depend only on 3) and can start 8 alongside 2.

---

# Phase 0 — Customer Validation Gate

**Goal:** Resolve four structural decisions whose wrong answer would force a phase rebuild in Arc 2, plus opportunistically close lower-risk open items.

**Dependencies:** None. Phase 0 blocks Phase 1 implementation but can run in parallel with Arc 1 post-delivery work.

**Status:** Unblocked. Requires MPP stakeholder availability for workshop facilitation.

## Data Model Changes

None directly — Phase 0 produces decisions, not DDL. Any DDL deltas flowing from Phase 0 decisions are captured in the Phase 1 migration (0010).

## Open Items Affecting This Phase

This phase **is** the open items phase. Its goal is to resolve:

**Already closed — do NOT re-litigate in the Phase 0 workshop:**

- **OI-01** Event outbox pattern — direct-call-with-logging, no outbox (v0.9 resolution).
- **OI-03** Shift runtime adjustments — availability derived from events, no minute adjustments (2026-04-20).
- **OI-06 / UJ-01** Operator identity & elevation — initials-only presence + per-action AD elevation (Phase C, 2026-04-21). Clock# + PIN are dead; do not raise them in the workshop.
- **OI-09** Multi-cavity / cavity-parallel LOTs — N cavities produce N parallel peer LOTs with `Lot.ToolCavityId` set (Data Model v1.9). Machining sub-LOT split remains a separate pattern.
- **OI-10** Tool life tracking — superseded by Phase B Tool Management; shot counts derive from `Workorder.ProductionEvent` group-by Tool/Cavity (Phase G).
- **OI-11** Casting → Trim part identity — 1-line BOM consumption (Bom + ConsumptionEvent + LotGenealogy); no new schema.
- **OI-26** UserInterfaceScript — deleted; DB-stored-runtime-code pattern explicitly not reproduced.

**Gating (must resolve at Phase 0 — wrong answer rebuilds a phase):**

| Item | Question | Why it gates |
|---|---|---|
| **OI-31** (new 2026-04-23) | `Lots.IdentifierSequence` cutover seed values + format carry-forward. Keep `MESL{0:D7}` / `MESI{0:D7}`, or mint new prefixes? Additional counters in use (container barcodes, shipping print sequences) that we haven't seen? Reset policy? Rollover policy at 9,999,999? | Phase 1 migration seeds `LastValue`; wrong seed = LTT collisions with live Flexware LOTs at cutover. |
| **FDS-06-030 WorkOrder BIT-flag enumeration** | Which Flexware WorkOrder flags are live in production (`IsCameraProcessingEnabled`, `IsScaleProcessingEnabled`, `GroupTargetWeight` + tolerance + UOM, `RecipeNumber`, `TrayQuantity`, `ReturnableDunnageCode`, `Customer`)? | Phase 1 `Workorder.WorkOrder` CREATE column list. Dead flags don't ship. |
| **Historical data migration** | Cutover approach — which entities migrate (LOTs, SerializedItems, ProductionOrders, Containers, Genealogy). Discrepancy review for unmatched rows (e.g., Flexware `LotAttribute.DIE NAME` with no matching `Tools.Tool.Code`). | Phase 1 migration-script + pre-flight validation design. |
| **OI-02 / UJ-13** Weight vs count container closure | Is scale-driven closure the design? | Phase 6 non-serialized container lifecycle; most Flexware WorkOrder BIT flags are subsumed by this decision. |
| **OI-05 / UJ-08** Die-rank compatibility matrix | Full compatibility matrix owed by MPP Quality. | Phase 7 `Lot_Merge` rejects cross-die merges until matrix loaded; supervisor override is the only path otherwise. |
| **OI-07 / UJ-07** Maintenance WO engine scope | Ben owes lifecycle, scheduling, integration with MPP maintenance team's tooling. | Phase G delivered the schema hook (FUTURE flow); Maintenance WO Perspective work doesn't start until Ben closes this. |
| **OI-08 / UJ-12 addenda** | Final `TrackingMode` enumeration on Cell (values?) + Part ↔ Machine validity model confirmation. | Phase 3 / 4 terminal UX + scan-in guard depends on these. |
| **ShotCount semantics** | `Workorder.ProductionEvent.ShotCount` = cumulative counter OR derived from aggregated LOT quantities? | Phase 3 operator-screen design + reporting path. |
| **Workstation `DefaultScreen` seeding** | List of terminal-function Perspective views + which terminal routes to which. | Phase 1 seed data for B11 routing. |
| **UJ-10** Shift boundary carryover rules | Open downtime events carried across? Partial containers? In-progress LOTs? | Phase 1 (`Shift_Start`/`_End`) and Phase 8 (boundary ticker) cannot be built without this. |
| **UJ-16** `HardwareInterlockBypassed` flag location | `ContainerSerial`, `ProductionEvent`, or both? | Phase 6 Assembly schema + procs. |
| **UJ-05** Sort Cage serial migration | Void-and-recreate OR update-in-place with new `Lots.ContainerSerialHistory` audit table? | Phase 7 Sort Cage walk; update-in-place requires a new table. |
| **Honda AIM integration contract** | Confirm `GetNextNumber` format, `PlaceOnHold` / `ReleaseFromHold` / `UpdateAim` signatures, error recovery expectations. | Phase 7 shipping Gateway scripts. |
| **Label template scope** | Flexware has 3 templates (CONTAINER, LOT, CONTAINER_HOLD). Confirm ours matches + any new needed (Sort Cage, Hold, Void). | Phase 6 / 7 label print procs + ZPL templates. |

**Opportunistic (resolve if MPP available — fallbacks exist):**

| Item | Current fallback if unresolved |
|---|---|
| UJ-04 non-serialized container lifecycle | Auto-create on LOT arrival; AIM shipper ID at last route step pre-closure. Subsumed by OI-02 resolution. |
| UJ-09 material verification | BOM-based verification; reject substitutes. |
| UJ-11 / UJ-19 paper-vs-real-time | Assume real-time at each station; if MPP chooses phased rollout, deployment-order decision only. |
| UJ-17 vision vs barcode confirmation | Barcode canonical; vision mismatch triggers line-stop + 10-fail escalation (per OI-04 revised). |

## State & Workflow

Phase 0 is a facilitated workshop, not a technical build. The workflow is:

1. **Pre-work.** Blue Ridge drafts a facilitator deck summarizing each gating item: the question, the candidate answers, the design implication of each answer, and Blue Ridge's recommended default. Deck distributed to MPP 3 business days before workshop.
2. **Workshop.** 2–3 hour session with MPP stakeholders (operations, quality, IT, production-control). Each gating item is walked, discussed, and decided. Opportunistic items covered if time permits. Every decision is logged in-room.
3. **Decision log capture.** Decisions appended to `MPP_MES_Open_Issues_Register.docx` with signed-off dates. Each decision references its OI/UJ number.
4. **Schema delta capture.** Any DDL additions (new columns, new attribute-definition rows, new code-table entries) are documented and folded into the Phase 1 migration file (`sql/migrations/versioned/0010_phase1_shop_floor_foundation.sql`).
5. **Plan convention update.** B10 (serial migration audit) is rewritten with the chosen pattern before Phase 6 starts.

## API Layer (Named Queries → Stored Procedures)

None — no code deliverables in this phase.

## Gateway Scripts

None.

## Perspective Views

None.

## Test Coverage

No test suite additions.

## Phase 0 complete when

- [ ] Workshop held with MPP representatives.
- [ ] Decision log for OI-31 (identifier sequences), FDS-06-030 (WO BIT flags), historical data migration, OI-02, OI-05 matrix, OI-07 Maintenance scope, OI-08 addenda, ShotCount semantics, DefaultScreen seeding, UJ-10, UJ-16, UJ-05, AIM contract, and label templates appended to Open Issues Register with signed-off dates.
- [ ] B10 convention rewritten with the chosen serial-migration pattern (UJ-05).
- [ ] Any DDL deltas captured in the Arc 2 Phase 1 migration (note: `0010_phase9_tools_and_workorder.sql` is already consumed by Phase G; Arc 2 Phase 1 lands as `0013_arc2_phase1_shop_floor_foundation.sql` or equivalent next-unclaimed number).
- [ ] Opportunistic items resolved or explicitly deferred with a documented fallback.

---

# Phase 1 — Shop Floor Foundation

**Goal:** Deliver the cross-cutting infrastructure that every downstream Arc 2 phase depends on — operator session, terminal binding, IP-based zone routing, shift runtime, LOT core skeleton, and the shared operation-log audit contract.

**Dependencies:** Phase 0 (customer validation gate) complete. Arc 1 SQL complete (all tables referenced exist, Audit procs operational).

**Status:** Blocked on Phase 0.

## Data Model Changes

**Migration `sql/migrations/versioned/0013_arc2_phase1_shop_floor_foundation.sql`** (next unclaimed number — Phase G consumed `0010`–`0012`):

**New tables (Arc 2 — introduced here, per Data Model v1.9):**

- `Workorder.WorkOrder` — CREATE with v1.7 / v1.9 column contract: `Id`, `WoNumber`, `WorkOrderTypeId` (FK → `Workorder.WorkOrderType`), `ItemId`, `RouteTemplateId`, `WorkOrderStatusId`, `ToolId` (FK → `Tools.Tool`, NULL — Maintenance only), `CreatedAt`, `CompletedAt`. Plus the FDS-06-030 Phase-0-confirmed BIT-flag columns (live flags only).
- `Workorder.WorkOrderOperation` — CREATE per Data Model §4.
- `Workorder.ProductionEvent` — CREATE per Data Model v1.9 checkpoint shape: `Id`, `LotId`, `OperationTemplateId`, `WorkOrderOperationId` (NULL), `EventAt`, `ShotCount` (NULL, cumulative — open per Decision 5), `ScrapCount` (NULL, cumulative), `ScrapSourceId` (NULL), `WeightValue`, `WeightUomId`, `AppUserId`, `TerminalLocationId`, `Remarks`. Required index `(LotId, EventAt DESC)`. No `LocationId`, no `ItemId`, no `DieIdentifier`, no `CavityNumber`, no `GoodCount` / `NoGoodCount`, no `StartedAt` / `EndedAt`.
- `Workorder.ProductionEventValue` — CREATE per Data Model §4 (child of ProductionEvent, extensible `DataCollectionField` capture).
- `Workorder.ConsumptionEvent` — CREATE per Data Model §4.
- `Workorder.RejectEvent` — CREATE per Data Model §4.
- `Lots.IdentifierSequence` — CREATE per Data Model v1.9 §3 (OI-31). Seed `Lot` (`MESL{0:D7}`) + `SerializedItem` (`MESI{0:D7}`) rows with `LastValue` set from the cutover-day Flexware snapshot (Phase 0 delivers the values).

**ALTERs (Arc 2 Phase 1):**

- `Lots.Lot` ADD `ToolId BIGINT NULL FK → Tools.Tool(Id)` and `ToolCavityId BIGINT NULL FK → Tools.ToolCavity(Id)`. Required at `Lot_Create` for die-cast-origin LOTs; NULL elsewhere; NULL after `Lot_Merge`. Pre-v1.9 `DieNumber` / `CavityNumber` NVARCHAR columns remain for cutover transition but are populated only for legacy-imported rows — new rows write to the FKs.

**LocationAttributeDefinition seeds on the `Terminal` `LocationTypeDefinition`:**

- `DefaultScreen` (NVARCHAR — Perspective route path, e.g., `'/shop-floor/die-cast-entry'`).
- `TerminalMode` (NVARCHAR — `'Dedicated'` or `'Shared'`; default per Phase 0 decision, ~80% Dedicated / 20% Shared per OI-08).

**What is NOT seeded (per Phase C security rewrite):**

- No `IdleTimeoutSeconds` attribute — there is no shift-start login to time out. Operator presence is persistent on Dedicated terminals; Shared terminals prompt on first action or machine change. The 30-minute idle re-confirmation overlay on Dedicated terminals is Perspective-layer behaviour, not a DB attribute.
- No `RequiresReauthForSensitive` attribute — elevation is per-action AD prompt (FDS-04-007) for every elevated action, everywhere. No per-terminal opt-out.

**Other migration tasks:**

- Add `Location.Location.IpAddress`-attribute-index if missing (read-heavy lookup in `Terminal_GetByIpAddress`).
- Seed a fallback `Terminal` `Location` row representing the global default (used when an unregistered IP connects).
- If UJ-10 resolves to a rule-coded approach at Phase 0, add a small `Oee.ShiftBoundaryCarryoverRuleCode` code table (3 seeded rows: `CloseAtEnd`, `CarryOpen`, `AssociateWithStartShift`) and reference it from `Oee.ShiftSchedule` as a nullable FK. If UJ-10 resolves to a single project-wide rule, skip the code table and hard-code the behavior in `Shift_End`.

**Tables used (existing from Arc 1 / Phase G):**

| Table | Role |
|---|---|
| `Location.Location` | Terminal location lookup by IP |
| `Location.LocationAttribute` | `IpAddress`, `DefaultScreen`, `TerminalMode` values per Terminal |
| `Location.LocationAttributeDefinition` | Definition of Terminal attributes |
| `Location.AppUser` | Initials-based operator presence resolver; interactive users carry AD account |
| `Tools.Tool`, `Tools.ToolCavity`, `Tools.ToolAssignment` | System of record for Tool identity; Lot.ToolId / Lot.ToolCavityId FK to these |
| `Oee.ShiftSchedule` | Active-shift resolver input |
| `Oee.Shift` | Runtime shift instances (append-only) |
| `Lots.Lot` | LOT header — minimal CRUD in this phase (Phase 2 expands) |
| `Lots.LotStatusHistory` | Append on status change |
| `Lots.LotMovement` | Append on move |
| `Lots.LotStatusCode` | `BlocksProduction` flag source |
| `Audit.OperationLog` | Destination for all plant-floor mutation audit calls |
| `Audit.FailureLog` | Destination for rejected calls |

## Open Items Affecting This Phase

| Item | Assumption used |
|---|---|
| OI-31 identifier sequences | Resolved in Phase 0 — cutover-day `LastValue` for Lot + SerializedItem; format carry-forward confirmed; any additional counters added to the seed. |
| OI-06 / UJ-01 operator identity | **Closed (Phase C, 2026-04-21).** Initials-based presence + per-action AD elevation. No clock# + PIN, no 5-minute timeout, no session-sticky elevation. Phase 1 delivers `AppUser_GetByInitials`. Do not re-open. |
| UJ-10 shift boundary | Resolved in Phase 0 — carryover rule drives the `Shift_End` / `Shift_Start` implementation. |
| FDS-06-030 WorkOrder BIT flags | Resolved in Phase 0 — live flag column list on `Workorder.WorkOrder` CREATE. |
| Historical data migration | Resolved in Phase 0 — entity list, pre-flight validation, discrepancy review process. |
| OI-08 addenda | `TerminalMode` seeded per Cell per Phase 0 direction (Dedicated / Shared default). |

## State & Workflow

### Session establishment (terminal startup)

An Ignition Perspective session starts when a Perspective client connects to the Gateway. The Gateway invokes the `Terminal_ResolveFromSession` script with the client's IP.

1. Gateway calls `Location.Terminal_GetByIpAddress(@IpAddress = '10.12.7.34')`.
2. Proc queries `Location.LocationAttribute` for `AttributeName = 'IpAddress' AND Value = @IpAddress`, joins to the parent `Location` row (which must be `LocationType = 'Terminal'`), and returns:
   - `TerminalLocationId` (the Terminal Location's Id)
   - `TerminalName` (Location.Name — e.g., `'DC-TERM-05'`)
   - `ZoneLocationId` + `ZoneName` (the Terminal's parent Area — e.g., `'Die Cast'`)
   - `DefaultScreen` (from `LocationAttribute`, e.g., `'/shop-floor/die-cast-entry'`)
   - `TerminalMode` (from `LocationAttribute`, `'Dedicated'` or `'Shared'`, default `'Dedicated'`)
3. If no Terminal matches the IP, proc returns the fallback Terminal's attributes. The Gateway script flags the session as "unregistered terminal" and routes to a generic Terminal Selector screen.
4. Gateway stashes these values in Perspective session props: `session.custom.terminal.*`.
5. Perspective's Home router view reads `session.custom.terminal.defaultScreen` and navigates to that path.

No DB mutation during session establishment. No audit log — this is a read-only lookup.

### Operator presence (initials-based — per Phase C / FDS §4)

**There is no login, no clock number, no PIN.** Operators are identified on a terminal by their **initials**, which establish a persistent operator presence context that pre-populates a defeasible Initials field on every mutation screen.

**Dedicated terminals (~80% of the plant, 1:1 with a Cell):**

1. Operator scans or types their initials (e.g., `CM`) on the shift-start handoff screen or on first touch after the machine sits idle.
2. Perspective calls `Location.AppUser_GetByInitials @Initials='CM'`.
3. Proc returns the `AppUser` row (Id, Initials, DisplayName, UserClass). Empty result set = initials unknown — Perspective shows an inline error ("Initials CM not recognised — ask Admin to add this operator in the Configuration Tool") and does not proceed.
4. On success, Perspective stashes `session.custom.user.*` with `{appUserId, initials, displayName, userClass}`. Presence persists through the shift.
5. **30-minute idle re-confirmation.** A Perspective view-side timer resets on every interaction. At 30 minutes idle, the next touch shows a modal: *"Operate as CM? Yes / No — change."* On `Yes`, presence continues. On `No — change`, Perspective clears the session's initials and the operator scans/types fresh initials. The timer is a Perspective concern — no DB state.

**Shared terminals (~20% of the plant — multi-station trim terminals, supervisor kiosks, etc.):**

1. Presence is prompted **on first action and on every machine-context change**. The Initials field at the top of every mutation screen is never pre-populated.
2. Operator enters initials inline on the screen being submitted. Each mutation carries its own `@AppUserId` resolved by `AppUser_GetByInitials` at submit time.
3. No persistent `session.custom.user.*` on shared terminals — every action is standalone.

**Machine-context lock (both terminal modes — per FDS-02-011):** The terminal's machine context is locked to the Cell resolved from the scan. Operators cannot navigate off-machine via a dropdown — changing context requires a fresh scan at the terminal (force-print / re-scan workflow).

**Pre-populated defeasible Initials field:** Every mutation screen shows an Initials field pre-populated from `session.custom.user.initials` (Dedicated) or empty (Shared). Operator can override before submit — e.g., when a pair-working colleague enters data on behalf of the primary operator. The value at submit time is what stamps the event.

### Elevated actions (per FDS-04-007)

Elevated actions (place hold, release hold, scrap LOT, void shipping label, Tool mount / release, admin remove-item, override a BOM-driven destination, supervisor merge override) require a **per-action Active Directory authentication**. On invocation:

1. Perspective shows the AD credential modal (AD username + password, integrated auth where available).
2. Perspective calls `Location.AppUser_AuthenticateAd @AdAccount='jdoe', @Password='...'` (proc delegates to Ignition's AD binding; returns the matching `AppUser.Id` + role list; NULL if invalid or role not permitted).
3. On success, the elevated action proceeds with the authenticated user's `@AppUserId` — this value stamps the mutation; the original operator-presence `@AppUserId` stays for non-elevated events. The elevation does NOT open a sticky session — next elevated action re-prompts.
4. Every elevation attempt (success and failure) writes to `Audit.OperationLog` with `LogEventType='ElevationGranted'` or `Audit.FailureLog` with `LogEventType='ElevationDenied'`.

No "re-auth" flag on Terminal, no 5-minute-window session stickiness, no PIN fallback. Elevation is always per-action.

### Shift runtime

Shift boundaries are driven by a Gateway script tick (`ShiftBoundaryTicker`, runs every 60 seconds):

1. Ticker calls `Oee.Shift_GetActive(@LocationId, @NowUtc)`.
2. Proc looks up `Oee.ShiftSchedule` rows active on today's day-of-week (per `DaysOfWeekBitmask`) with `EffectiveFrom <= @NowUtc` and `DeprecatedAt IS NULL`. Returns the one matching the current time-of-day window.
3. Ticker also calls `Oee.Shift_GetOpen(@ShiftScheduleId)` to see if there's an open `Shift` row for this schedule.
4. If the active schedule has no open `Shift` row, ticker calls `Oee.Shift_Start(@ShiftScheduleId, @ActualStart = @NowUtc)`. Proc inserts the Shift row, logs OperationLog.
5. If the previously-active schedule has an open `Shift` row but the active schedule is different (i.e., boundary crossed), ticker calls `Oee.Shift_End(@ShiftId, @ActualEnd = @NowUtc)` on the outgoing Shift. Proc updates the row, logs OperationLog.
6. UJ-10 carryover rule (resolved Phase 0) drives whether open `DowntimeEvent` rows are closed at shift end or carried forward.

### LOT core skeleton

Phase 1 delivers minimal LOT procs — enough to let Phase 3 (Die Cast) create its first LOT. Full LOT lifecycle (`Lot_Update`, `Lot_UpdateAttribute`, genealogy) is Phase 2.

`Lot_Create` flow (narrated from Phase 3's perspective — the proc is delivered here). Aligned to Data Model v1.9 + FDS-05-034 / FDS-05-035:

1. Operator takes a basket from a machine's active cavity and scans a fresh pre-printed LTT barcode at the terminal. Perspective builds the parameter set: `@LotName = NULL` (proc mints via `IdentifierSequence_Next @Code='Lot'`), `@ItemId`, `@LotOriginTypeId`, `@CurrentLocationId` (Cell), `@PieceCount`, `@ToolId` (NULL for non-die-cast origins; required for Die Cast — Perspective auto-populates from `ToolAssignment_ListActiveByCell` and operator confirms), `@ToolCavityId` (same rule), `@Weight`, `@WeightUomId`, `@VendorLotNumber` (Received only), `@AppUserId`, `@TerminalLocationId`.
2. Proc validates parameters (no NULLs on required, FKs resolve).
3. Proc validates business rules:
   - `@Item` eligible at `@CurrentLocationId` via `Parts.ItemLocation` (`DeprecatedAt IS NULL`).
   - Piece count within `Parts.Item.MaxLotSize` (now labeled `PartsPerBasket` in UX copy; see Data Model v1.9).
   - If `@LotOriginTypeCode = 'Manufactured'` and the Cell has an active `Tools.ToolAssignment` (die-cast-origin check):
     - `@ToolId` and `@ToolCavityId` are required (per FDS-05-034).
     - `Tools.ToolAssignment` exists for `@ToolId` on `@CurrentLocationId` with `ReleasedAt IS NULL`.
     - `@ToolCavityId` belongs to `@ToolId`.
     - `ToolCavity.StatusCode = 'Active'`.
   - Non-die-cast origins (Received, Trim / Machining intermediate, Assembly, Serialized) SHALL pass NULL Tool/Cavity — proc does not require them.
4. `BEGIN TRANSACTION`.
5. Proc calls `Lots.IdentifierSequence_Next @Code='Lot'` which atomically increments `LastValue` and returns the formatted string (e.g., `MESL1710935`). This is `@MintedLotName`.
6. Proc inserts `Lots.Lot` row with `LotName = @MintedLotName`, `LotStatusId = 'Good'`, `ToolId`, `ToolCavityId`. Returns new `Id` as `@NewId`.
7. Proc inserts `Lots.LotStatusHistory` row: `OldStatusId = NULL`, `NewStatusId = 'Good'`, `ChangedByUserId = @AppUserId`, `TerminalLocationId = @TerminalLocationId`.
8. Proc calls `Audit.Audit_LogOperation` with `LogEntityTypeCode='Lot'`, `LogEventTypeCode='LotCreated'`, `EntityId=@NewId`, `Description='Created LOT <LotName> at <LocationName>'` (plus Tool/Cavity in description for die-cast-origin LOTs).
9. `COMMIT`.
10. Final `SELECT @Status, @Message, @NewId, @MintedLotName`.

If any validation fails, no transaction opens, `Audit.Audit_LogFailure` is called with the attempted parameters (Tool/Cavity included), and the proc returns early. Note: `IdentifierSequence_Next` is invoked **inside** the transaction so that a rolled-back LOT doesn't burn a counter value.

### `Lot_AssertNotBlocked` shared guard

Procedure called by every downstream proc that advances a LOT:

```sql
CREATE OR ALTER PROCEDURE Lots.Lot_AssertNotBlocked
    @LotId BIGINT,
    @Status BIT = NULL OUTPUT,   -- NOT USED — for future compat
    @Message NVARCHAR(500) = NULL OUTPUT
AS
-- Returns one of:
--   SELECT 1 AS IsBlocked, 'LOT <name> is in status <status> and cannot progress' AS Message;
--   SELECT 0 AS IsBlocked, NULL AS Message;
```

Callers read the `IsBlocked` flag. This is an **internal proc** (no audit, no FailureLog); callers that receive `IsBlocked=1` log their own rejection via FailureLog and return early.

## API Layer (Named Queries → Stored Procedures)

### Location — Terminal resolution

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Location.Terminal_GetByIpAddress` | `@IpAddress NVARCHAR(45)` | Reads `LocationAttribute` where `AttributeName='IpAddress'`; joins to parent Terminal Location and its parent Area. Returns fallback Terminal if no match. Falls back gracefully, never errors on unknown IP. | `Location.Location`, `Location.LocationAttribute`, `Location.LocationType`, `Location.LocationTypeDefinition` | Perspective session start, via Gateway script | Rowset: `TerminalLocationId, TerminalName, ZoneLocationId, ZoneName, DefaultScreen, IdleTimeoutSeconds, RequiresReauthForSensitive` |
| `Location.Terminal_List` | (none) | Admin query — all Terminal-type Locations with attributes. Used by an admin screen (not operator-facing). | `Location.Location`, `Location.LocationAttribute` | Admin browsing Terminal inventory | Rowset per Terminal |

### AppUser — initials-based presence + AD elevation

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Location.AppUser_GetByInitials` | `@Initials NVARCHAR(10)` | Resolves initials to an active `AppUser` row. Empty result set = unknown initials (per FDS-11-011 single-result-set convention). No audit on lookup (initials-presence is not a security event). Used by Perspective on shift-start (Dedicated terminals) and on every Shared-terminal mutation. | `Location.AppUser` | Shift-start handoff; shared-terminal submit; 30-min idle re-confirm | Single row: `Id, Initials, DisplayName, UserClass, IgnitionRole` (or empty set if unknown). |
| `Location.AppUser_AuthenticateAd` | `@AdAccount NVARCHAR(100)`, `@TerminalLocationId BIGINT`, `@ActionCode NVARCHAR(50)` (e.g., `'HoldPlace'`, `'Scrap'`, `'ToolMount'`) | **Elevation proc.** Delegates the credential check to Ignition's AD binding (the Perspective modal submits `@AdAccount + password` against Ignition; if Ignition validates, it calls this proc with `@AdAccount` only). Proc looks up the matching `AppUser.AdAccount` (filtered UNIQUE), verifies the user is not deprecated, verifies `IgnitionRole` matches the role permitted for `@ActionCode`, and returns the `AppUserId`. On any reject, writes `Audit.FailureLog` with `LogEventType='ElevationDenied'`. On success, writes `Audit.OperationLog` with `LogEventType='ElevationGranted'` (per FDS-04-007). | `Location.AppUser`, `Audit.Audit_LogOperation`, `Audit.Audit_LogFailure` | Every elevated action per FDS-04-007 | Single row: `Status BIT, Message NVARCHAR(500), AppUserId BIGINT` (NULL on failure). |
| `Location.AppUser_GetRoles` | `@AppUserId BIGINT` | Returns the `IgnitionRole` for interactive users; empty result for operator-class users (no role). Used by Perspective to gate elevated-screen visibility. | `Location.AppUser` | On elevation success | Rowset of role strings. |

> **Explicitly NOT delivered:** `AppUser_AuthenticateByClockAndPin` is **removed from this phase plan** — clock# + PIN is not part of the design. Phase G migration `0012_phase_c_security.sql` already dropped `AppUser.ClockNumber` and `AppUser.PinHash` columns (landed 2026-04-23 as part of `534f55c`). Any Phase 3+ proc that references those columns is a bug.

### Shift — runtime instances

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Oee.Shift_Start` | `@ShiftScheduleId BIGINT`, `@ActualStart DATETIME2(3)`, `@Remarks NVARCHAR(500) NULL`, `@AppUserId BIGINT`, `@TerminalLocationId BIGINT` | Inserts a new `Oee.Shift` row. Rejects if an open Shift (ActualEnd NULL) already exists for this ShiftSchedule (per B3). Logs `OperationLog` with `LogEventType='ShiftStarted'`. | `Oee.Shift`, `Oee.ShiftSchedule`, `Audit.Audit_LogOperation` | Gateway ShiftBoundaryTicker | `Status, Message, NewId` |
| `Oee.Shift_End` | `@ShiftId BIGINT`, `@ActualEnd DATETIME2(3)`, `@Remarks NVARCHAR(500) NULL`, `@AppUserId BIGINT`, `@TerminalLocationId BIGINT` | Closes the Shift: updates `ActualEnd`. Rejects if ActualEnd already set (per B3). Logs `OperationLog` with `LogEventType='ShiftEnded'`. UJ-10 carryover logic (closing or carrying open DowntimeEvents) is applied here based on the Phase 0 decision. | `Oee.Shift`, `Oee.DowntimeEvent`, `Audit.Audit_LogOperation` | Gateway ShiftBoundaryTicker or manual override | `Status, Message` |
| `Oee.Shift_GetActive` | `@LocationId BIGINT` (optional — for location-specific schedule filtering), `@NowUtc DATETIME2(3) = SYSDATETIME()` | Returns the schedule active at `@NowUtc` matching the day-of-week bitmask. Does not create a Shift row. | `Oee.ShiftSchedule` | Gateway ShiftBoundaryTicker; supervisor dashboard | Single row: `ShiftScheduleId, ShiftScheduleName, StartTime, EndTime, DaysOfWeekBitmask` or empty |
| `Oee.Shift_GetOpen` | `@ShiftScheduleId BIGINT` | Returns the open Shift (if any) for this schedule. Used by the ticker to detect whether a Shift_Start is needed. | `Oee.Shift` | Gateway ShiftBoundaryTicker | Single row: `ShiftId, ActualStart` or empty |

### Lot — core skeleton (minimal; Phase 2 expands)

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Lots.Lot_Create` | `@ItemId BIGINT`, `@LotOriginTypeId BIGINT`, `@CurrentLocationId BIGINT`, `@PieceCount INT`, `@Weight DECIMAL(12,4) NULL`, `@WeightUomId BIGINT NULL`, `@ToolId BIGINT NULL`, `@ToolCavityId BIGINT NULL`, `@VendorLotNumber NVARCHAR(100) NULL`, `@MinSerialNumber INT NULL`, `@MaxSerialNumber INT NULL`, `@AppUserId BIGINT`, `@TerminalLocationId BIGINT` | Creates a Lot with status 'Good'. Mints `LotName` via `Lots.IdentifierSequence_Next @Code='Lot'` inside the transaction. Validates `Item` eligibility at `@CurrentLocationId`, piece count ≤ `Parts.Item.MaxLotSize` (aka `PartsPerBasket`). Validates Tool/Cavity per FDS-05-034 for die-cast-origin LOTs (active ToolAssignment on Cell; cavity belongs to tool; cavity Active). Inserts initial `LotStatusHistory` row. Audit via `Audit.Audit_LogOperation`. No `@LotName`, no `@DieNumber`, no `@CavityNumber` NVARCHAR params (legacy — those are dropped from the contract). | `Lots.Lot`, `Lots.LotStatusHistory`, `Lots.IdentifierSequence`, `Parts.Item`, `Parts.ItemLocation`, `Tools.Tool`, `Tools.ToolCavity`, `Tools.ToolAssignment`, `Lots.LotOriginType`, `Lots.LotStatusCode`, `Audit.Audit_LogOperation` | Phase 3+ station produces a new LOT | `Status, Message, NewId, MintedLotName NVARCHAR(50)` |
| `Lots.IdentifierSequence_Next` | `@Code NVARCHAR(30)` | Atomically increments `LastValue` and returns the formatted identifier string. Raises on unknown `@Code` or on rollover breach. Called by Lot_Create, SerializedPart_Create, and any future counter path. Single-result-set (per FDS-11-011). | `Lots.IdentifierSequence` | Any identifier minting path | Single row: `Value NVARCHAR(50)`. |
| `Lots.Lot_Get` | `@LotId BIGINT NULL`, `@LotName NVARCHAR(50) NULL` (one required) | Returns the Lot row. Empty result set = not found (per FDS-11-011). | `Lots.Lot` | Any screen displaying a LOT | Single row of Lot columns |
| `Lots.Lot_List` | `@ItemId BIGINT NULL`, `@CurrentLocationId BIGINT NULL`, `@LotStatusId BIGINT NULL`, `@LimitRows INT = 100` | Filterable listing. Read-only, no audit. | `Lots.Lot` | LOT search screen | Rowset of Lot columns |
| `Lots.Lot_UpdateStatus` | `@LotId BIGINT`, `@NewLotStatusId BIGINT`, `@Reason NVARCHAR(500) NULL`, `@AppUserId BIGINT`, `@TerminalLocationId BIGINT`, `@RowVersion ROWVERSION` | Updates `Lot.LotStatusId` with optimistic-lock check. Inserts `LotStatusHistory` row. Rejects no-op (new = current). Phase 2 extends — Phase 1 only accepts Good → Closed transitions as preparation for Phase 7 hold logic. | `Lots.Lot`, `Lots.LotStatusHistory`, `Lots.LotStatusCode`, `Audit.Audit_LogOperation` | Phase 2+ for general transitions; Phase 7 for holds | `Status, Message` |
| `Lots.Lot_MoveTo` | `@LotId BIGINT`, `@ToLocationId BIGINT`, `@AppUserId BIGINT`, `@TerminalLocationId BIGINT` | Updates `Lot.CurrentLocationId` and inserts `LotMovement` row with `FromLocationId` = prior value, `ToLocationId` = new. Calls `Lot_AssertNotBlocked` first (per B2). | `Lots.Lot`, `Lots.LotMovement`, `Lots.Lot_AssertNotBlocked`, `Audit.Audit_LogOperation` | Any station that receives a scanned LOT | `Status, Message` |
| `Lots.Lot_AssertNotBlocked` | `@LotId BIGINT` | Internal shared guard. Returns `IsBlocked BIT, Message NVARCHAR(500)`. No audit. Called by every advancing proc (B2). | `Lots.Lot`, `Lots.LotStatusCode` | Every mutation that advances a LOT | Single row: `IsBlocked BIT, Message NVARCHAR(500)` |

### Audit — shared operation logger (may already exist from Arc 1; verify)

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Audit.Audit_LogOperation` | `@AppUserId BIGINT`, `@TerminalLocationId BIGINT`, `@LocationId BIGINT NULL` (context location), `@LogSeverityCode NVARCHAR(20) = 'Info'`, `@LogEventTypeCode NVARCHAR(100)`, `@LogEntityTypeCode NVARCHAR(50)`, `@EntityId BIGINT`, `@Description NVARCHAR(1000)`, `@OldValue NVARCHAR(MAX) NULL`, `@NewValue NVARCHAR(MAX) NULL` | Inserts into `Audit.OperationLog`. Resolves code strings to FK ids internally. Returns no result set (per JDBC refactor — audit writers silent). | `Audit.OperationLog`, code-resolver internals | Every Arc 2 mutation proc | (none) |

## Gateway Scripts

| Script | Purpose | Trigger | External System | Audit |
|---|---|---|---|---|
| `Terminal_ResolveFromSession` | On Perspective session start, read client IP, call `Terminal_GetByIpAddress`, stash Terminal / Zone / DefaultScreen / TerminalMode into `session.custom.terminal.*`. If unregistered IP, fall back to global-default Terminal and flag the session. | Perspective session startup event | — | — (read-only) |
| `PresenceIdleWatcher` (Perspective view-side script, not Gateway) | **Dedicated terminals only.** Per-view 30-minute idle detector resets on any interaction. At timeout, shows the "Operate as [XY]? Yes / No — change" modal described in §"Operator presence". On `No — change`, clears `session.custom.user.*` and routes to initials entry. No DB mutation. Shared terminals do not use this — they prompt per-action. | Perspective interaction events | — | — |
| `ShiftBoundaryTicker` | Every 60 seconds: for each configured schedule, resolve active schedule, detect boundary crossings, call `Shift_End` on outgoing + `Shift_Start` on incoming. Also applies UJ-10 carryover rule to open DowntimeEvents. | Gateway timer (60s) | — | Interface log on any downtime-carryover decision |

> **Removed:** `AdAuthenticator` Gateway script is not needed — AD credential validation is delegated to Ignition's built-in AD binding (invoked by the Perspective elevation modal), with `AppUser_AuthenticateAd` performing only the post-validation role check + audit write.

## Perspective Views

| View | Purpose |
|---|---|
| Initials Entry (Dedicated terminals) | Shift-start handoff and 30-minute re-confirm modal. Operator scans or types initials. Submits `AppUser_GetByInitials`; inline error on unknown. Sets `session.custom.user.*` on success. No password, no PIN. |
| Terminal Selector | Shown only for unregistered-IP sessions. Operator selects terminal from a list or scans a terminal barcode. Updates `session.custom.terminal.*` from a manual selection proc. |
| Home Router | Stateless: reads `session.custom.terminal.defaultScreen` and navigates. Falls back to a generic Home tile grid if DefaultScreen is NULL. Not a user-visible screen in normal operation — it's a routing pass-through. |
| 30-Min Idle Re-Confirm Modal | Dedicated terminals only. Message: *"Operate as CM? Yes / No — change."* `Yes` continues presence; `No — change` clears and returns to Initials Entry. |
| Per-Mutation Initials Field | Every mutation screen shows a prominent Initials field, pre-populated from `session.custom.user.initials` on Dedicated terminals, empty on Shared. Operator can override before submit. The value at submit time stamps the event. |
| Elevation Modal (per-action AD) | Triggered by elevated actions per FDS-04-007 (hold place/release, scrap, Tool mount, void shipping label, admin remove-item, BOM-destination override, supervisor merge override). AD username + password inline; integrated auth via Ignition AD binding where available. On success, action proceeds with the elevated `@AppUserId`; no sticky session. Every attempt logged to `OperationLog` / `FailureLog`. |

## Test Coverage

New test suite at `sql/tests/0013_PlantFloor_Foundation/` with files:

| File | Covers |
|---|---|
| `010_Terminal_GetByIpAddress.sql` | Known IP resolves to correct Terminal + Zone + DefaultScreen + TerminalMode; unknown IP returns fallback; Terminal without DefaultScreen attribute returns NULL DefaultScreen; deprecated Terminal not returned. |
| `020_AppUser_GetByInitials.sql` | Known initials return the AppUser row; unknown initials return empty result set; deprecated AppUser returns empty; case-insensitive matching if configured; mixed-class lookup (operator + interactive) covered. |
| `025_AppUser_AuthenticateAd.sql` | Valid AD account + permitted role + valid action code returns AppUserId + OperationLog 'ElevationGranted'; wrong role rejects with FailureLog 'ElevationDenied'; deprecated AD user rejects; unknown `@ActionCode` rejects; missing `@AdAccount` rejects. |
| `030_Shift_lifecycle.sql` | `Shift_Start` creates row; `Shift_Start` rejects when open Shift exists (B3); `Shift_End` closes row; `Shift_End` rejects when no open Shift; `Shift_GetActive` returns schedule by day-of-week bitmask; `Shift_GetOpen` returns open Shift if one exists. |
| `035_IdentifierSequence.sql` | `IdentifierSequence_Next` increments LastValue atomically; returns correctly formatted string for `MESL{0:D7}` and `MESI{0:D7}` patterns; raises on unknown @Code; raises on rollover breach at EndingValue; concurrent callers see strictly-increasing values (no gaps, no duplicates). |
| `040_Lot_Create.sql` | Valid manufacture creates Lot + LotStatusHistory with Tool/Cavity set; minted `LotName` matches `MESL{0:D7}` format; die-cast-origin LOT without @ToolId rejects; die-cast-origin LOT with @ToolId not mounted on Cell rejects; cavity not belonging to tool rejects; cavity in Closed/Scrapped state rejects; non-die-cast-origin LOT with NULL Tool/Cavity accepted; ineligible Item-at-Location rejects; piece count over `MaxLotSize` rejects; missing `@AppUserId` rejects; IdentifierSequence counter advances on each successful create and rolls back on failed creates. |
| `050_Lot_Get_List.sql` | `Lot_Get` by Id and by LotName returns Tool/Cavity FKs; empty result for non-existent; `Lot_List` filters by ToolId work; limit applied. |
| `060_Lot_UpdateStatus.sql` | Valid transition applies; stale `@RowVersion` rejects; no-op (same status) rejects; invalid target status rejects. |
| `070_Lot_MoveTo.sql` | Valid move updates CurrentLocationId + inserts LotMovement; move from unblocked Lot succeeds; move from blocked Lot (Hold/Scrap/Closed) rejects via `Lot_AssertNotBlocked`. |
| `080_Lot_AssertNotBlocked.sql` | Good returns `IsBlocked=0`; Hold/Scrap/Closed return `IsBlocked=1` with correct Message; non-existent Lot returns `IsBlocked=1` with 'LOT not found' message. |

Target: 75–95 passing tests in suite 0013 (up from v0.1 target of 60–80 — Tool/Cavity validation + IdentifierSequence + AD elevation add ~15 test assertions).

## Phase 1 complete when

- [ ] Migration `0013_arc2_phase1_shop_floor_foundation.sql` (or next unclaimed number) applied to dev; `Workorder.WorkOrder` / `WorkOrderOperation` / `ProductionEvent` / `ProductionEventValue` / `ConsumptionEvent` / `RejectEvent` CREATE'd per Data Model v1.9 shapes; `Lots.IdentifierSequence` created and seeded from Phase 0 cutover values; `Lots.Lot` ALTER'd to add `ToolId` + `ToolCavityId`; new LocationAttributeDefinition rows seeded on Terminal type (`DefaultScreen`, `TerminalMode`).
- [ ] All repeatable procs present and up-to-date: `R__Location_Terminal_*`, `R__Location_AppUser_GetByInitials`, `R__Location_AppUser_AuthenticateAd`, `R__Location_AppUser_GetRoles`, `R__Oee_Shift_Start`, `R__Oee_Shift_End`, `R__Oee_Shift_GetActive`, `R__Oee_Shift_GetOpen`, `R__Lots_IdentifierSequence_Next`, `R__Lots_Lot_Create`, `R__Lots_Lot_Get`, `R__Lots_Lot_List`, `R__Lots_Lot_UpdateStatus`, `R__Lots_Lot_MoveTo`, `R__Lots_Lot_AssertNotBlocked`.
- [ ] **No proc anywhere in the repo references `AppUser.ClockNumber` or `AppUser.PinHash`** (both columns dropped by Phase G migration `0012`). Grep verification: `grep -ri 'ClockNumber\|PinHash\|AuthenticateByClockAndPin' sql/` returns zero hits. If non-zero, this is a phase-complete blocker.
- [ ] All tests in `sql/tests/0013_PlantFloor_Foundation/` pass (target 75–95).
- [ ] Reset script (`Reset-DevDatabase.ps1`) discovers and applies the new migration and runs the new test suite.
- [ ] Gateway script `Terminal_ResolveFromSession` implemented and tested against Perspective sessions from known + unknown IPs.
- [ ] Gateway script `ShiftBoundaryTicker` implemented; verified end-to-end against a dev ShiftSchedule that crosses a boundary within the test window.
- [ ] Perspective views: Initials Entry, Terminal Selector, Home Router, 30-Min Idle Re-Confirm Modal, Elevation Modal all built. Home Router resolves `session.custom.terminal.defaultScreen` correctly for every seeded terminal; Elevation Modal wired to Ignition's AD binding + `AppUser_AuthenticateAd`.
- [ ] `Audit.Audit_LogOperation` code string → FK resolution verified for `LogEventType` values: `'ShiftStarted'`, `'ShiftEnded'`, `'LotCreated'`, `'LotStatusChanged'`, `'LotMoved'`, `'ElevationGranted'`. `Audit.Audit_LogFailure` verified for `'ElevationDenied'`. Any missing `Audit.LogEventType` rows seeded in the migration.
- [ ] Downstream phases can call `Lot_Create` (with Tool/Cavity FKs), `IdentifierSequence_Next`, `AppUser_GetByInitials`, `AppUser_AuthenticateAd`, `Lot_MoveTo`, `Lot_UpdateStatus`, and `Lot_AssertNotBlocked` against the delivered contract.
- [ ] **End-to-end integration check**: a dev operator scans initials at a dev Dedicated Terminal, presence persists, the operator creates a die-cast LOT (Tool auto-populated from active ToolAssignment, operator confirms, cavity selected), the LOT is minted with `MESL{0:D7}` name, a placeholder elevated action (e.g., admin remove-item stub) triggers the AD Elevation Modal and logs both OperationLog + FailureLog rows appropriately.

---

# Phase 2 — LOT Lifecycle Completion

**Goal:** Fill out the complete LOT surface — all mutation procs, append-only history streams, full genealogy (split/merge/consumption), and label reprint — so downstream operator-station phases compose from a stable LOT API.

**Dependencies:** Phase 1 (foundation). No new table DDL; all tables exist in data model v1.5.

**Status:** Blocked on Phase 1.

## Data Model Changes

No DDL changes expected. Phase 2 indexes any hot-read paths exposed by testing (e.g., `Lots.LotGenealogy(ParentLotId)` and `Lots.LotGenealogy(ChildLotId)` may need explicit indexes if not already present). Index additions roll into migration `0011_phase2_lot_lifecycle.sql`.

**Tables used (all exist from Arc 1):**

| Table | Role |
|---|---|
| `Lots.Lot` | Header — expanded update surface |
| `Lots.LotStatusHistory` | Append on every `Lot_UpdateStatus` |
| `Lots.LotMovement` | Append on every `Lot_MoveTo` |
| `Lots.LotAttributeChange` | Append on every `Lot_UpdateAttribute` |
| `Lots.LotGenealogy` | Append on Split / Merge / Consumption |
| `Lots.GeneologyRelationshipType` | Code table — Split, Merge, Consumption |
| `Lots.LotLabel` | Append on every label print/reprint |
| `Lots.PrintReasonCode` | Code table — Initial, ReprintDamaged, Split, Merge, SortCageReIdentify |
| `Lots.LabelTypeCode` | Code table — Primary, Container, Master, Void |

## Open Items Affecting This Phase

| Item | Fallback |
|---|---|
| UJ-08 merge rules | Ship with hard-coded rule: `Lot_Merge` requires same `ItemId` and same `DieNumber`. If MPP demands configurability, a `Lots.MergeRule` table is added post-MVP. |
| B10 serial migration | Not yet relevant — Phase 6 consumes this. Confirm B10 is finalized before Phase 6 starts. |

## State & Workflow

### Full `Lot_Update`

`Lot_Update` is distinct from `Lot_UpdateStatus`. It covers mutations to LOT header fields other than status — piece count correction, weight correction, operator-entered die/cavity correction, vendor-lot-number correction for received LOTs. Each field change is captured as a separate `LotAttributeChange` row so the before/after audit is field-level.

1. Perspective sends the full LOT payload with the operator's intended new values.
2. Proc validates optimistic lock via `@RowVersion`.
3. Proc validates `Lot_AssertNotBlocked` (per B2 — even "corrections" on a held LOT are not allowed; release the hold first).
4. Proc compares each mutable field. For each changed field:
   - Insert `LotAttributeChange` row with `AttributeName`, `OldValue`, `NewValue`, `ChangedByUserId`, `TerminalLocationId`, `ChangedAt`.
5. Update the `Lot` row with the new values; `UpdatedByUserId`, `UpdatedAt`, `RowVersion` auto-updated.
6. Audit via `Audit_LogOperation` with `LogEventType='LotUpdated'`, a description summarizing the field count changed, and `Changes` JSON attached.

### Genealogy — three shapes

**Split.** One parent LOT becomes multiple child LOTs. Parent piece count drops to 0 (or residual — e.g., a 48-piece parent splits into two 24-piece children, parent goes to 0 and status → Closed; if sorting splits out 12 suspect pieces from a 48-piece parent, parent goes to 36 with status Good, child LOT carries 12 and can be scrapped separately).

`Lot_Split` sequence (delivered in this phase, consumed by Phase 5 Machining and Phase 7 Sort Cage):

1. Parameter validation, `Lot_AssertNotBlocked` on the parent.
2. Business rule: sum of child piece counts ≤ parent piece count.
3. For each child spec in the payload:
   - Call `Lot_Create` with `ParentLotId = @ParentLotId`, origin-type = same as parent (the child is still Manufactured if the parent was Manufactured).
   - Capture the new child Lot Id.
   - Insert a `LotGenealogy` row: `ParentLotId`, `ChildLotId`, `RelationshipTypeId = 'Split'`, `PieceCount` = the child's share, `EventUserId`, `TerminalLocationId`.
4. Reduce parent piece count by the total split quantity via `Lot_UpdateAttribute`. If residual is 0, `Lot_UpdateStatus` on parent → `Closed`.
5. Audit via `Audit_LogOperation` with `LogEventType='LotSplit'`, description listing child LotNames.
6. Return child Lot Ids as a rowset (not as `@NewId` — many children).

**Merge.** Multiple source LOTs combine into one output. Per UJ-08, merge rules are hard-coded in this MVP (same Item, same Die). Output LOT carries the sum of source piece counts.

`Lot_Merge` sequence:

1. Parameter validation: ≥2 source LOTs listed.
2. `Lot_AssertNotBlocked` on each source.
3. Business rule (hard-coded): all sources share `ItemId` and `DieNumber`.
4. Create the merged output via `Lot_Create` (origin = same as sources).
5. For each source:
   - Insert `LotGenealogy` row: `ParentLotId = sourceId`, `ChildLotId = outputId`, `RelationshipTypeId = 'Merge'`, `PieceCount = source's contribution`.
   - `Lot_UpdateStatus` source → `Closed` (all pieces migrated to the output).
6. Audit with `LogEventType='LotMerged'`.
7. Return output Lot Id.

**Consumption.** One or more source LOTs are consumed to produce a child LOT or to fill a serialized part's container. Handled by `LotGenealogy_RecordConsumption` in this phase (low-level) and invoked by Phase 6's `ConsumptionEvent_Record` (higher-level).

`LotGenealogy_RecordConsumption` is narrow: given a source LOT, a produced LOT or container tray position, and a piece count, insert the `LotGenealogy` row with `RelationshipTypeId='Consumption'`. Phase 6 wires this into the Assembly workflow with surrounding validation (BOM check, interlock bypass handling, container-tray placement).

### Genealogy traversal

`Lot_GetGenealogyTree` walks the graph recursively. Given a starting LOT, the `@Direction` parameter selects:

- `'Ancestors'` — walk upward via `Lot.ParentLotId` (for direct parent chain) AND via `LotGenealogy.ChildLotId = current` (to find MERGE-parents). Return distinct ancestors.
- `'Descendants'` — walk downward via `LotGenealogy.ParentLotId = current`. Return all children, grandchildren, etc., with their relationship types.
- `'Both'` — union of Ancestors and Descendants.

Depth bound: `OPTION (MAXRECURSION 100)` (per B8). The returned rowset includes depth, relationship type, and whether each node is still active (`DeprecatedAt IS NULL`).

### Label reprint

`LotLabel_Reprint` captures a new `LotLabel` row with a `PrintReasonCode` explaining why a reprint was needed (label damaged, LOT attribute corrected, split generated a new child LTT, merge issued a new parent). The original `LotLabel` row is not modified — labels are append-only. Perspective's reprint dialog forces a reason selection; the Gateway ZPL dispatcher renders and prints as with `LotLabel_Print`.

### Attribute edits audit

Every mutation to a mutable LOT field — piece count, weight, die, cavity, vendor lot number — produces a `LotAttributeChange` row. This is the traceability backbone for Honda audits: years later, every field's history is queryable. `Lot_GetAttributeHistory` walks this and is used by the LOT detail screen's "history" tab.

## API Layer (Named Queries → Stored Procedures)

### Lot — expanded mutations

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Lots.Lot_Update` | `@LotId BIGINT`, `@PieceCount INT NULL`, `@Weight DECIMAL(10,4) NULL`, `@WeightUomId BIGINT NULL`, `@DieNumber NVARCHAR(50) NULL`, `@CavityNumber INT NULL`, `@VendorLotNumber NVARCHAR(100) NULL`, `@RowVersion ROWVERSION`, `@AppUserId`, `@TerminalLocationId` | Full header update. Inserts one `LotAttributeChange` row per changed field. Rejects on stale `@RowVersion`. `Lot_AssertNotBlocked`. | `Lots.Lot`, `Lots.LotAttributeChange`, `Lots.Lot_AssertNotBlocked`, `Audit.Audit_LogOperation` | LOT detail screen edit | `Status, Message` |
| `Lots.Lot_UpdateAttribute` | `@LotId BIGINT`, `@AttributeName NVARCHAR(50)`, `@NewValue NVARCHAR(500)`, `@AppUserId`, `@TerminalLocationId` | Single-field update helper. Mostly used by internal callers (Lot_Split reducing parent piece count). Field-validation against an allow-list. | `Lots.Lot`, `Lots.LotAttributeChange`, `Audit.Audit_LogOperation` | Internal from Lot_Split, Lot_Merge, Trim weight adjustment | `Status, Message` |
| `Lots.Lot_Split` | `@ParentLotId BIGINT`, `@ChildrenJson NVARCHAR(MAX)` (JSON array of `{pieceCount, currentLocationId, dieNumber?, cavityNumber?}`), `@AppUserId`, `@TerminalLocationId` | Creates N child LOTs, inserts SPLIT `LotGenealogy` rows, reduces parent piece count, closes parent if residual=0. Rejects if sum(children) > parent. `Lot_AssertNotBlocked` on parent. | `Lots.Lot`, `Lots.LotGenealogy`, `Lots.Lot_Create`, `Lots.Lot_UpdateAttribute`, `Lots.Lot_UpdateStatus`, `Audit.Audit_LogOperation` | Phase 5 Machining OUT, Phase 7 Sort Cage | Rowset of child Lot rows (Id, LotName, PieceCount) + leading `Status, Message` row (shape: results multiplexed — see note) |
| `Lots.Lot_Merge` | `@SourceLotIdsJson NVARCHAR(MAX)` (JSON array of source Lot Ids), `@OutputItemId BIGINT`, `@OutputLocationId BIGINT`, `@AppUserId`, `@TerminalLocationId` | Combines sources into one output. Hard-coded rule: same Item, same Die. Closes all sources. Inserts MERGE `LotGenealogy` rows. `Lot_AssertNotBlocked` on each source. | `Lots.Lot`, `Lots.LotGenealogy`, `Lots.Lot_Create`, `Lots.Lot_UpdateStatus`, `Audit.Audit_LogOperation` | Operator-initiated merge (rare; MVP) | `Status, Message, NewId` (output Lot Id) |
| `Lots.LotGenealogy_RecordConsumption` | `@SourceLotId BIGINT`, `@ConsumedPieceCount INT`, `@ProducedLotId BIGINT NULL`, `@ProducedContainerId BIGINT NULL`, `@ProducedSerialNumber NVARCHAR(100) NULL`, `@AppUserId`, `@TerminalLocationId` | Internal — inserts CONSUMPTION `LotGenealogy` row. Called from Phase 6 `ConsumptionEvent_Record`. Not called directly from Perspective. | `Lots.LotGenealogy`, `Audit.Audit_LogOperation` | Internal from Phase 6 | `Status, Message, NewId` (genealogy row Id) |

**Note on `Lot_Split` result shape:** Because `Lot_Split` creates N children, the natural return is a rowset of child rows. To keep FDS-11-011 (single result set) intact, `Lot_Split` returns a single result set with columns: `Status BIT, Message NVARCHAR(500), ChildLotId BIGINT, ChildLotName NVARCHAR(50), PieceCount INT`. On failure, one row with Status=0 and NULL child columns. On success, N rows all with Status=1 and child fields populated. Callers iterate the result set.

### Genealogy traversal

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Lots.Lot_GetGenealogyTree` | `@LotId BIGINT`, `@Direction NVARCHAR(20) = 'Both'` | Recursive CTE walking ancestors / descendants. `OPTION (MAXRECURSION 100)`. Returns flat rowset with depth. | `Lots.Lot`, `Lots.LotGenealogy` | Genealogy viewer screen; Quality supervisor tracing a complaint | Rowset: `LotId, LotName, Depth, RelationshipTypeCode, ItemId, ItemCode, CurrentLocationId, LotStatusCode, DeprecatedAt` |
| `Lots.Lot_GetParents` | `@LotId BIGINT` | One-hop up. Faster than full tree for simple displays. | `Lots.Lot`, `Lots.LotGenealogy` | LOT detail screen, "parents" section | Rowset of parent Lots |
| `Lots.Lot_GetChildren` | `@LotId BIGINT` | One-hop down. | `Lots.Lot`, `Lots.LotGenealogy` | LOT detail screen, "children" section | Rowset of child Lots |
| `Lots.Lot_GetAttributeHistory` | `@LotId BIGINT` | All `LotAttributeChange` + `LotStatusHistory` + `LotMovement` rows for a LOT, unioned and ordered by time. | `Lots.LotAttributeChange`, `Lots.LotStatusHistory`, `Lots.LotMovement` | LOT detail screen "history" tab | Rowset: `EventAt, EventType, OldValue, NewValue, FromLocation, ToLocation, ByUser` |

### Labels

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Lots.LotLabel_Print` | `@LotId BIGINT`, `@LabelTypeCodeId BIGINT`, `@PrintReasonCodeId BIGINT`, `@ZplContent NVARCHAR(MAX)`, `@AppUserId`, `@TerminalLocationId` | Records the print. Gateway script calls this with the pre-rendered ZPL. Returns the new `LotLabelId` for the Gateway to update with the print ack. | `Lots.LotLabel`, `Lots.PrintReasonCode`, `Lots.LabelTypeCode`, `Audit.Audit_LogOperation` | Phase 3+ when producing a new LOT or reprinting | `Status, Message, NewId` |
| `Lots.LotLabel_Reprint` | `@LotId BIGINT`, `@OriginalLabelId BIGINT`, `@PrintReasonCodeId BIGINT` (must NOT be `Initial`), `@ZplContent NVARCHAR(MAX)`, `@AppUserId`, `@TerminalLocationId` | Append-only — no modification of the original label. Validates the reason is a non-Initial reason. | `Lots.LotLabel`, `Lots.PrintReasonCode`, `Audit.Audit_LogOperation` | Operator reprint dialog | `Status, Message, NewId` |
| `Lots.LotLabel_List` | `@LotId BIGINT NULL`, `@LocationId BIGINT NULL`, `@DateFrom DATETIME2(3) NULL`, `@DateTo DATETIME2(3) NULL` | Filterable listing for supervisor. Returns print history. | `Lots.LotLabel` | Supervisor label audit screen | Rowset of LotLabel rows |

## Gateway Scripts

| Script | Purpose | Trigger | External System | Audit |
|---|---|---|---|---|
| `LttZplDispatcher` | Renders an LTT ZPL from a template + data returned by `Lot_Get` / `Lot_Create`. Opens a socket to the destination Zebra printer (resolved from Terminal's `PrimaryZebraPrinter` attribute), writes the ZPL, captures print-ack, updates `LotLabel.PrintedAt` via a proc call. | Called after `Lot_Create` or `LotLabel_Reprint` returns | Zebra printer (9100/TCP) | `InterfaceLog` with `SystemName='Zebra'`, `Direction='Outbound'`; on failure adds FailureLog entry. |

## Perspective Views

| View | Purpose |
|---|---|
| LOT Search | Filterable list with scan-a-barcode prefilter. Lands on LOT Detail for a matched hit. |
| LOT Detail | Full LOT record — header, status, movement history, attribute history, parent/child links, label print history. Header editable (calls `Lot_Update`) behind re-auth. |
| Genealogy Tree Viewer | Tree-style visualization of `Lot_GetGenealogyTree` results. Click a node to jump to its detail. Toggle Ancestors/Descendants/Both. |
| Reprint Dialog (modal) | Triggered from LOT Detail. Reason-code picker (excludes Initial). Calls `LotLabel_Reprint`. |

## Test Coverage

New test suite at `sql/tests/0014_PlantFloor_LotLifecycle/` with files:

| File | Covers |
|---|---|
| `010_Lot_Update.sql` | Valid update inserts one `LotAttributeChange` per changed field; no change = no insert; stale `@RowVersion` rejects; blocked LOT rejects (B2). |
| `020_Lot_UpdateAttribute.sql` | Single-field update inserts one row; unknown attribute name rejects; locked LOT rejects. |
| `030_Lot_Split.sql` | N children created with correct piece counts; parent reduced; parent closed when residual=0; SPLIT `LotGenealogy` rows correct; over-split rejects; blocked parent rejects. |
| `040_Lot_Merge.sql` | Output LOT created with summed piece count; all sources closed; MERGE `LotGenealogy` rows correct; mismatched Item rejects; mismatched Die rejects; blocked source rejects. |
| `050_Lot_GetGenealogyTree.sql` | Single-level ancestor returned; multi-level ancestor walks parent chain and MERGE edges; descendant walks SPLIT + CONSUMPTION edges; `MAXRECURSION` bound respected. |
| `060_Lot_GetParents_GetChildren.sql` | One-hop up and down return expected rowsets. |
| `070_Lot_GetAttributeHistory.sql` | Union of AttributeChange + StatusHistory + Movement ordered by time; correct event-type labels. |
| `080_LotLabel_Print_Reprint.sql` | `LotLabel_Print` creates row; `LotLabel_Reprint` rejects Initial reason; `LotLabel_List` filters by LotId, LocationId, and date range. |

Target: 80–100 passing tests in suite 0014.

## Phase 2 complete when

- [ ] Migration `0011_phase2_lot_lifecycle.sql` applied (indexes for genealogy hot paths if needed).
- [ ] All repeatable procs for Lot full mutations, genealogy, and labels present and current.
- [ ] All tests in `sql/tests/0014_PlantFloor_LotLifecycle/` pass (target 80–100).
- [ ] `LttZplDispatcher` Gateway script dispatches to a dev Zebra printer and captures ack.
- [ ] Perspective LOT Search, Detail, Genealogy Tree Viewer, and Reprint Dialog implemented and manually smoke-tested.
- [ ] End-to-end: operator creates a LOT in Phase 1's stub flow, edits the piece count on the Detail screen, splits it into two children, prints a reprint — all audit rows correct.

---

# Phase 3 — Die Cast Operator Station

**Goal:** Deliver the first end-to-end producer workflow — a Die Cast machine operator scans a fresh LTT, enters production data, records rejects, and prints the LTT label. Implements the FDS-03-017a data-collection capture contract end to end.

**Dependencies:** Phase 1 (session, LOT core), Phase 2 (LotLabel_Print helper).

**Status:** Blocked on Phases 1–2.

## Data Model Changes

**Migration `sql/migrations/versioned/0012_phase3_die_cast.sql`:**

- Seed any missing `Audit.LogEventType` rows used by Phase 3 procs: `ProductionRecorded`, `Rejected`, `LotLabelPrinted` (most already exist from Arc 1 — verify and seed any gaps).
- Seed dev test rows in `Parts.OperationTemplate` + `Parts.OperationTemplateField` representing a minimal Die Cast operation (`DieCastShot`) with required DataCollectionFields: `DieIdentifier`, `CavityNumber`, `WeightValue`, `GoodCount`, `NoGoodCount`, `WarmupShotCount` (UJ-14). Seed data lives in `sql/seeds/seed_operation_templates_die_cast.sql`.
- If OI-10 tool life is resolved Phase 0 as a `LocationAttribute` on the DieCastMachine type, seed the attribute definition (`ShotsSinceLastChange`, `MaxShotsPerTool`). Otherwise, no-op.

**Tables used:**

| Table | Role |
|---|---|
| `Lots.Lot` | New LOT created per shot batch |
| `Lots.LotStatusHistory`, `Lots.LotMovement`, `Lots.LotAttributeChange` | Append-only side effects |
| `Lots.LotLabel` | LTT print record |
| `Workorder.ProductionEvent` | One row per event — hot columns captured |
| `Workorder.ProductionEventValue` | Child rows for non-hot DataCollectionFields |
| `Workorder.RejectEvent` | Reject count per defect code |
| `Parts.OperationTemplate`, `Parts.OperationTemplateField`, `Parts.DataCollectionField` | Drives what the UI asks for and what gets captured |
| `Parts.Item`, `Parts.ItemLocation` | Eligibility check |
| `Quality.DefectCode` | Reject defect assignment |
| `Audit.OperationLog`, `Audit.FailureLog` | Audit destinations |

## Open Items Affecting This Phase

| Item | Fallback |
|---|---|
| OI-10 tool life | If unresolved, shot counts captured in `ProductionEventValue` as a DataCollectionField; no running total maintained; supervisor queries history on demand. If Phase 0 chose LocationAttribute approach, `ProductionEvent_Record` increments the `ShotsSinceLastChange` attribute. |
| UJ-14 warm-up shots | Warm-up shots captured as a `DataCollectionField` on the DieCastShot operation template (`WarmupShotCount` field value on `ProductionEventValue`). Separately, when a setup-type `DowntimeEvent` is closed, Phase 8's `DowntimeEvent_End` captures the accumulated warm-up shots on `DowntimeEvent.ShotCount`. |
| UJ-11 paper-vs-real-time | Assume real-time. If MPP phases rollout, this station ships first; others follow. Design unchanged. |

## State & Workflow

### Die Cast LOT creation walkthrough

Carlos is running DC machine #7, part 5G0, die #42, cavity B. The basket has 48 good parts and 3 rejects from the last shot cycle.

1. Perspective session is already on the Die Cast LOT Entry screen (DefaultScreen for this terminal, set by Phase 1 routing).
2. Carlos peels a pre-printed LTT sticker off the stack. It has a barcode, e.g., `2026-04-06-0001`, already printed. He sticks it on the basket.
3. He taps the barcode input on the screen and scans the LTT with the station's USB scanner. Perspective's scan binding sets a `lttBarcode` input field.
4. The screen reveals the data entry form. It pulls the active OperationTemplate for Die Cast at this machine (Perspective calls `OperationTemplate_GetActiveForLocation(@LocationId)` — a read proc from Arc 1). The form dynamically renders the fields configured on the template:
   - `DieIdentifier` (text, required)
   - `CavityNumber` (int, required)
   - `WeightValue` (decimal, optional)
   - `GoodCount` (int, required, default 0)
   - `NoGoodCount` (int, required, default 0)
   - `WarmupShotCount` (int, optional, default 0)
5. Carlos enters `Die=42`, `Cavity=B`, `GoodCount=48`, `NoGoodCount=0`.
6. He submits. Perspective calls `ProductionEvent_Record` with the full payload.
7. `ProductionEvent_Record` (narrative below) creates the Lot, writes the ProductionEvent, writes any ProductionEventValue children, and returns `Status=1, Message='OK', NewLotId=<id>, NewProductionEventId=<id>`.
8. Perspective then calls `LotLabel_Print` (from Phase 2) with the pre-rendered ZPL for the LTT, which logs the label and returns a `LotLabelId`.
9. Perspective hands the ZPL + LotLabelId to the `LttZplDispatcher` Gateway script. Script dispatches to the station's Zebra printer. On success, script calls `LotLabel_ConfirmPrint(@LotLabelId)` (internal — may just update `PrintedAt` on the row).
10. The LTT prints beside Carlos. He sticks it on the basket next to the fresh LTT and wheels it out of die cast.

### `ProductionEvent_Record` — the contract

This is the FDS-03-017a capture proc. It is the single write path for production data at any operator station. Phase 3 delivers it with Die-Cast-specific test coverage; Phases 4–6 exercise it at other stations without additional proc work.

Signature (conceptual):

```sql
CREATE OR ALTER PROCEDURE Workorder.ProductionEvent_Record
    @LotId BIGINT NULL,              -- NULL => create Lot first
    @LotName NVARCHAR(50) NULL,      -- Required if @LotId is NULL
    @ItemId BIGINT NULL,             -- Required if @LotId is NULL
    @LotOriginTypeCode NVARCHAR(50) NULL, -- Required if @LotId is NULL; typically 'Manufactured'
    @LocationId BIGINT,              -- Machine where event occurred
    @OperationTemplateId BIGINT,     -- Drives DataCollectionField validation
    @DieIdentifier NVARCHAR(50) NULL,
    @CavityNumber INT NULL,
    @WeightValue DECIMAL(10,4) NULL,
    @WeightUomId BIGINT NULL,
    @GoodCount INT,
    @NoGoodCount INT,
    @Remarks NVARCHAR(500) NULL,
    @DataCollectionValuesJson NVARCHAR(MAX) NULL,  -- Array of {fieldName, value, numericValue?, uomId?}
    @AppUserId BIGINT,
    @TerminalLocationId BIGINT
```

Execution sequence:

1. Parameter validation:
   - If `@LotId IS NULL`, `@LotName`, `@ItemId`, `@LotOriginTypeCode` must all be present (creating a new LOT).
   - If `@LotId IS NOT NULL`, the LOT must exist and `@ItemId` must match (or be NULL for identity check).
   - `@LocationId`, `@OperationTemplateId`, `@AppUserId`, `@TerminalLocationId` all required and exist.
2. Business rule: `@Item` is eligible at `@LocationId` (`Parts.ItemLocation`).
3. Business rule: `@OperationTemplate` is active (not deprecated) and its `LocationId` matches `@LocationId`'s Area (or is `NULL` meaning universal).
4. `Lot_AssertNotBlocked` if `@LotId` is provided.
5. Validate `@DataCollectionValuesJson`:
   - Parse the JSON.
   - For every field on `Parts.OperationTemplateField` for this operation: if `IsRequired=1`, the field must appear in the JSON OR be captured by a hot column (`GoodCount`, `NoGoodCount`, `DieIdentifier`, `CavityNumber`, `WeightValue`). Missing required → reject.
   - For every field in the JSON: it must exist on `Parts.DataCollectionField` AND be configured for this OperationTemplate (`Parts.OperationTemplateField`). Otherwise reject.
   - Duplicate fields in JSON → reject.
   - A JSON field that duplicates a hot column (e.g., JSON contains `GoodCount`) → reject with a clear "use the hot parameter" message.
6. `BEGIN TRANSACTION`.
7. If `@LotId IS NULL`: call `Lot_Create` with the LOT parameters. Capture `@LotId` from the returned `NewId`.
8. Insert the `ProductionEvent` row with hot columns + `OperationTemplateId` + `@AppUserId` + `@TerminalLocationId` + `RecordedAt = SYSDATETIME()`. Capture `@NewProductionEventId`.
9. For each field in `@DataCollectionValuesJson`: insert `ProductionEventValue` row with `ProductionEventId = @NewProductionEventId`, `DataCollectionFieldId`, `Value`, `NumericValue` (if the field's data-type is numeric), `UomId` (if applicable).
10. If `@NoGoodCount > 0` and no corresponding `RejectEvent` was passed explicitly, mirror pattern: Phase 3 lets the operator enter rejects in a separate call (`RejectEvent_Record`), so `ProductionEvent_Record` writes the count but does NOT create a RejectEvent automatically. The operator enters defect codes in a follow-on action.
11. Update the `Lot` — `PieceCount` increments by `@GoodCount` (or is set to `@GoodCount` for a newly-created Lot), `CurrentLocationId = @LocationId`.
12. Audit via `Audit_LogOperation` with `LogEventType='ProductionRecorded'`, description includes `GoodCount`, `NoGoodCount`, and LotName.
13. `COMMIT`.
14. Final `SELECT @Status=1, @Message='OK', @NewLotId, @NewProductionEventId`.

### `RejectEvent_Record`

The operator enters rejects as a follow-on action from the Die Cast screen — separate call, separate transaction. This keeps the primary production event small and lets rejects be entered repeatedly (multiple defect codes per reject batch).

1. Validate params: `@LotId` exists, `@DefectCodeId` exists, `@Quantity > 0`, `@ProductionEventId` (optional) exists and belongs to `@LotId`.
2. `Lot_AssertNotBlocked`.
3. Insert `Workorder.RejectEvent` row with `LotId`, `DefectCodeId`, `Quantity`, `ChargeToArea`, `ProductionEventId` (nullable — rejects without event-binding allowed).
4. Audit with `LogEventType='Rejected'`, description includes defect code and quantity.
5. Return `Status, Message, NewId`.

Rejects do NOT change the LOT's piece count — the rejects were never "in" the LOT's count to begin with (FRS Section 4). The operator can also choose not to enter rejects at every step (FRS: reject recording is optional).

### Die Cast shot counts (UJ-14)

Warm-up shots are captured via `WarmupShotCount` DataCollectionField on the DieCastShot template. The value lands on `ProductionEventValue`. A separate warm-up shots accumulator on `DowntimeEvent.ShotCount` — populated in Phase 8 when a Setup-type downtime event closes — captures the total per setup episode, useful for OEE.

### Tool life tracking (OI-10 contingent)

If Phase 0 resolves OI-10 as a `LocationAttribute` approach: `ProductionEvent_Record` optionally increments `ShotsSinceLastChange` on the machine's `LocationAttribute` row after a successful production event (if the attribute exists for this machine type). If threshold crossed (`>= MaxShotsPerTool`), Perspective shows a tool-change alert. No new proc needed — a helper call to the Arc 1 `LocationAttribute_SetValue` proc does the increment.

If Phase 0 chose a dedicated `Parts.Die` table, that work is scoped as a separate mini-phase post-MVP; Phase 3 ships unchanged.

## API Layer (Named Queries → Stored Procedures)

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Workorder.ProductionEvent_Record` | See signature above | The FDS-03-017a capture proc. Creates a LOT if needed, writes the event + values, increments piece count, audits. Optional tool-life increment. | `Lots.Lot`, `Lots.Lot_Create`, `Workorder.ProductionEvent`, `Workorder.ProductionEventValue`, `Parts.OperationTemplate`, `Parts.OperationTemplateField`, `Parts.DataCollectionField`, `Parts.Item`, `Parts.ItemLocation`, `Location.LocationAttribute` (tool life optional), `Audit.Audit_LogOperation` | Any producer station | `Status, Message, NewLotId, NewProductionEventId` |
| `Workorder.RejectEvent_Record` | `@LotId BIGINT`, `@ProductionEventId BIGINT NULL`, `@DefectCodeId BIGINT`, `@Quantity INT`, `@ChargeToArea NVARCHAR(50) NULL`, `@Remarks NVARCHAR(500) NULL`, `@AppUserId`, `@TerminalLocationId` | Records a reject. Does not change Lot.PieceCount. | `Workorder.RejectEvent`, `Quality.DefectCode`, `Audit.Audit_LogOperation` | Follow-on action after production event | `Status, Message, NewId` |
| `Workorder.ProductionEvent_List` | `@LotId BIGINT NULL`, `@LocationId BIGINT NULL`, `@DateFrom DATETIME2(3) NULL`, `@DateTo DATETIME2(3) NULL`, `@LimitRows INT = 500` | Read proc. Returns event rows with hot columns; does not join to values child table (separate call if needed). | `Workorder.ProductionEvent` | Supervisor dashboard; Die Shot report | Rowset |
| `Workorder.ProductionEvent_Get` | `@ProductionEventId BIGINT` | Single event with its child `ProductionEventValue` rows; returned as two result sets? Per FDS-11-011 single result set, return a flattened rowset one row per value + header column carried. Or return header-only here and use `ProductionEventValue_List` for the children. Choose the latter. | `Workorder.ProductionEvent` | LOT detail drill-down | Single header row |
| `Workorder.ProductionEventValue_List` | `@ProductionEventId BIGINT` | All value rows for a single event. | `Workorder.ProductionEventValue`, `Parts.DataCollectionField` | LOT detail, event drill-down | Rowset: `FieldName, Value, NumericValue, Uom` |
| `Workorder.RejectEvent_List` | `@LotId BIGINT NULL`, `@LocationId BIGINT NULL`, `@DefectCodeId BIGINT NULL`, `@DateFrom DATETIME2(3) NULL`, `@DateTo DATETIME2(3) NULL` | Read proc. | `Workorder.RejectEvent`, `Quality.DefectCode` | Rejects report | Rowset |

## Gateway Scripts

| Script | Purpose | Trigger | External System | Audit |
|---|---|---|---|---|
| `LttZplDispatcher` (already delivered Phase 2) | Reused — Phase 3 invokes it after a successful `ProductionEvent_Record` + `LotLabel_Print` pair. | After `LotLabel_Print` returns | Zebra printer | `InterfaceLog` |
| `DieCastShotCountReader` (optional — OI-10 contingent) | If PLC exposes a shot-count tag, this script reads it on cycle-complete edge and calls `LocationAttribute_SetValue` to update `ShotsSinceLastChange`. Descriptive: reads `ShotCount` tag from DC PLC, writes to LocationAttribute. | PLC `CycleComplete=1` edge | PLC (TOPServer) | — (logged in Audit.OperationLog via the proc) |

## Perspective Views

| View | Purpose |
|---|---|
| Die Cast LOT Entry | Scanner-driven touch layout. Barcode scan binds to `@LotName`. Form renders from active OperationTemplate. Submits to `ProductionEvent_Record` + `LotLabel_Print`. |
| Reject Entry (inline panel on Die Cast screen) | DefectCode picker filtered to Die Cast area. Quantity entry. Submits to `RejectEvent_Record`. |
| Production Event History (modal on LOT Detail) | Lists events for a LOT via `ProductionEvent_List`; drill into each event for its ProductionEventValue rows via `ProductionEventValue_List`. |

## Test Coverage

New test suite at `sql/tests/0015_PlantFloor_DieCast/`:

| File | Covers |
|---|---|
| `010_ProductionEvent_Record_happy_path.sql` | Creates Lot + event + values; increments piece count; audits correctly. |
| `020_ProductionEvent_Record_existing_lot.sql` | Adds event to existing Lot; piece count increments. |
| `030_ProductionEvent_Record_validation.sql` | Missing required DataCollectionField rejects; unknown field rejects; duplicate hot-field-in-JSON rejects; ineligible Item rejects; blocked Lot rejects. |
| `040_ProductionEvent_Record_templates.sql` | Deprecated OperationTemplate rejects; active OperationTemplate accepts; template tied to wrong Area rejects. |
| `050_RejectEvent_Record.sql` | Valid reject creates row; invalid defect code rejects; negative quantity rejects; blocked Lot rejects; Lot piece count unchanged. |
| `060_ProductionEvent_List_Get.sql` | Filter by Lot, Location, date range works; Get returns single row; ProductionEventValue_List returns child rows. |
| `070_Tool_life_increment.sql` (if OI-10 LocationAttribute) | Increments `ShotsSinceLastChange`; reset via `LocationAttribute_SetValue` works. |

Target: 100–140 passing tests in suite 0015 (the proc is large; many validation branches).

## Phase 3 complete when

- [ ] Migration `0012_phase3_die_cast.sql` applied; seed operation template + fields for DieCastShot present.
- [ ] `Workorder.ProductionEvent_Record`, `Workorder.RejectEvent_Record`, and read procs delivered and pass tests.
- [ ] All tests in `sql/tests/0015_PlantFloor_DieCast/` pass (target 100–140).
- [ ] Perspective Die Cast LOT Entry screen implemented; dynamic field render from OperationTemplate verified.
- [ ] End-to-end walkthrough: operator scans LTT → fills form → submits → Lot created → event written → LTT prints on dev Zebra → LOT Detail shows the event and its values.
- [ ] Reject entry inline panel functional; RejectEvent rows visible in Rejects Report stub.
- [ ] If OI-10 resolved as LocationAttribute: tool-life increment wired and verified.

---

# Phase 4 — Movement + Trim + Receiving

**Goal:** Composite phase covering three operator station patterns that share a single mechanic: scan a LOT and either move it, adjust its piece count (weight-based at Trim), or create a received LOT (Receiving).

**Dependencies:** Phase 1 (Lot_MoveTo, session), Phase 2 (LotAttributeChange audit), Phase 3 (ProductionEvent_Record reused at Trim).

**Status:** Blocked on Phases 1–3.

## Data Model Changes

**Migration `sql/migrations/versioned/0013_phase4_movement_trim_receiving.sql`:**

- Seed dev `Parts.OperationTemplate` rows for `TrimShopOperation` and `ReceivingInspection` with appropriate `OperationTemplateField` entries.
- Seed any `Audit.LogEventType` rows for `LotMoved` (already from Phase 1), `LotReceived`, `WeightReconciled` (add any gaps).
- Seed a new `LocationAttributeDefinition` row on the Trim Shop Machine type for `PrimaryScale` (NVARCHAR — OPC tag path of the station's scale).

**Tables used:**

| Table | Role |
|---|---|
| `Lots.Lot` | Updated via move, weight reconciliation, or new received LOT |
| `Lots.LotMovement`, `Lots.LotAttributeChange`, `Lots.LotStatusHistory` | Append streams |
| `Workorder.ProductionEvent` / `ProductionEventValue` | Captures Trim production (weight snapshot, piece count before/after) |
| `Parts.Item.UnitWeight` | Source for weight-to-count conversion |
| `Parts.OperationTemplate`, `Parts.OperationTemplateField` | Trim / Receiving templates |
| `Location.LocationAttribute` | Scale OPC tag path per Trim station |
| `Audit.OperationLog`, `Audit.InterfaceLog` (scale reads) | Audit |

## Open Items Affecting This Phase

| Item | Fallback |
|---|---|
| OI-02 / UJ-13 closure weight on containers | Not consumed at Trim directly; Trim reads weight but does not close containers. Deferred to Phase 6. |
| UJ-11 paper-vs-real-time | Real-time assumed. |

## State & Workflow

### Movement Scan Screen — reusable pattern

Almost every station that receives a LOT needs a move-scan entry point. Rather than build a different one per station, Phase 4 delivers a generic `Movement Scan Screen` that any terminal can route to. It takes:

1. Scan LTT barcode.
2. Perspective calls `Lot_Get(@LotName = scannedBarcode)`.
3. On found: `Lot_AssertNotBlocked`, then call `Lot_MoveTo(@LotId, @ToLocationId = session.custom.terminal.terminalLocationId, @AppUserId, @TerminalLocationId)`. On success, LOT's `CurrentLocationId` is now the terminal's Location.
4. Screen flips to station-specific mode — Trim UI, Machining IN UI, Assembly receive UI — driven by the terminal's zone.
5. On not-found or blocked: show clear error, beep, log to FailureLog.

Phase 4 delivers the Movement Scan Screen as a Perspective embedded view; each station's screen embeds it at the top and renders station-specific content below after a successful scan.

### Trim Shop — weight-based piece count

The operator sets the basket on the scale. OmniServer publishes `ScaleWeight` on the station's OPC tag. A Gateway script reads the tag on a debounced-stable signal and posts the weight to the Perspective session as a live binding.

1. Operator scans LTT at the Trim terminal. Movement Scan Screen fires `Lot_MoveTo` (Die Cast → Trim Shop); the Trim UI opens.
2. UI shows: current LOT's piece count, current item's `UnitWeight`, the live scale weight.
3. UI computes: `derivedPieceCount = round(netWeight / unitWeight)`. Operator reviews the derived count vs. current piece count. Per FRS 2.2.3, they can update the count; MES takes no further action on the discrepancy but logs the change.
4. Operator submits the trim-out action. Perspective calls `ProductionEvent_Record`:
   - `@LotId = existingLotId`
   - `@LocationId = trimStationLocationId`
   - `@OperationTemplateId = TrimShopOperation`
   - `@WeightValue = netWeight`, `@WeightUomId = LB or KG uom Id`
   - `@GoodCount = derivedPieceCount` (or operator-overridden)
   - `@NoGoodCount = 0` (Trim does not reject in MVP — sorter cage is separate)
   - `@DataCollectionValuesJson` includes any TrimShopOperation-specific fields (e.g., `NetWeight`, `PriorPieceCount`, `TareWeight`)
5. `ProductionEvent_Record` writes the event, writes ProductionEventValue rows, updates the Lot's piece count to the new count (which records a `LotAttributeChange` row for the before/after), and moves the Lot's `CurrentLocationId` to the Trim station.

The weight-to-count helper is a small proc used by the UI for its live binding (not in the transactional write path):

```
Lots.Lot_WeightToPieceCount(@ItemId, @NetWeightValue, @NetWeightUomId)
    → returns @DerivedPieceCount, assuming linear unit weight;
      errors if Item.UnitWeight is NULL or UOM mismatch.
```

### Receiving Dock — pass-through parts

A truck arrives with 500 units of 6MA Cam Holder housings. The receiving operator has a packing slip with vendor lot number `VND-88721`.

1. Operator is at the Receiving Dock terminal (DefaultScreen = Receiving Dock Screen).
2. Receiving Dock Screen: scan Item barcode (part number), enter vendor lot number, enter piece count, select origin type (`Received` or `ReceivedOffsite` for remote-receiving per UJ-06).
3. Submit. Perspective calls `Lot_CreateReceived`:

```
Lots.Lot_CreateReceived(
    @ItemId, @VendorLotNumber, @PieceCount,
    @MinSerialNumber NULL, @MaxSerialNumber NULL,
    @CurrentLocationId = receivingDockLocationId,
    @LotOriginTypeCode = 'Received' | 'ReceivedOffsite',
    @AppUserId, @TerminalLocationId)
```

4. Proc validates: vendor-lot-number not duplicate across open received lots for this Item; piece count positive; `@LotOriginTypeCode` in allowed set.
5. Proc generates a `LotName` internally — convention: `RCV-<YYYYMMDD>-<nnnn>` — and calls `Lot_Create` (Phase 1) with the generated name. Received LOTs don't carry LTT stickers peeled from the pre-printed stack; the MES generates the LTT on creation and prints it.
6. After Lot creation, Perspective calls `LotLabel_Print` with a Received-style ZPL template and dispatches to the Receiving Dock Zebra.
7. Audit via `Audit_LogOperation` with `LogEventType='LotReceived'`.

**Off-site receiving** uses the same `Lot_CreateReceived` proc over VPN — no code difference per UJ-06 resolution. The off-site operator's terminal just has a different `IpAddress` and `DefaultScreen`.

### Supplier-identified serial ranges

For received LOTs where the supplier has pre-numbered parts in a contiguous serial range, `@MinSerialNumber` and `@MaxSerialNumber` are populated. These feed into Phase 6 Assembly's consumption logic — an assembled output serial that consumes a piece from a received LOT can record `ConsumedSerialNumber` if traceable. Phase 4 captures the range; Phase 6 uses it.

## API Layer (Named Queries → Stored Procedures)

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Lots.Lot_WeightToPieceCount` | `@ItemId BIGINT`, `@NetWeightValue DECIMAL(10,4)`, `@NetWeightUomId BIGINT` | Helper (read-only). Converts weight to derived count using `Item.UnitWeight`. Errors (empty result) if UnitWeight NULL or UOM unit mismatch. | `Parts.Item`, `Parts.Uom` | Live UI binding at Trim | Single row: `DerivedPieceCount INT, UnitWeight DECIMAL, UnitWeightUomName` |
| `Lots.Lot_CreateReceived` | `@ItemId BIGINT`, `@VendorLotNumber NVARCHAR(100)`, `@PieceCount INT`, `@MinSerialNumber NVARCHAR(100) NULL`, `@MaxSerialNumber NVARCHAR(100) NULL`, `@CurrentLocationId BIGINT`, `@LotOriginTypeCode NVARCHAR(50)` (Received or ReceivedOffsite), `@AppUserId`, `@TerminalLocationId` | Wraps `Lot_Create` with the received-LOT semantics. Generates `LotName` as `RCV-YYYYMMDD-NNNN`. Validates vendor-lot uniqueness for this Item within the active (non-deprecated) set. | `Lots.Lot_Create`, `Lots.LotOriginType`, `Parts.Item`, `Audit.Audit_LogOperation` | Receiving Dock Screen | `Status, Message, NewLotId, NewLotName` |
| `Lots.Lot_ScanAtStation` | `@LotName NVARCHAR(50)`, `@StationLocationId BIGINT`, `@AppUserId BIGINT`, `@TerminalLocationId BIGINT` | Thin wrapper combining `Lot_Get` + `Lot_AssertNotBlocked` + `Lot_MoveTo`. Used by the Movement Scan Screen. One round-trip to DB instead of three. Returns the LOT's details on success. | `Lots.Lot_Get`, `Lots.Lot_AssertNotBlocked`, `Lots.Lot_MoveTo`, `Audit.Audit_LogOperation` | Every station with a scan entry | Single row: `Status, Message, LotId, LotName, ItemCode, ItemName, PieceCount, LotStatusCode` |

**Note:** `ProductionEvent_Record` (Phase 3) is the write path for Trim's weight/count capture; no new proc needed. Phase 4 contributes an `OperationTemplate` seed for Trim and the `PrimaryScale` LocationAttribute definition.

## Gateway Scripts

| Script | Purpose | Trigger | External System | Audit |
|---|---|---|---|---|
| `ScaleTagReader` | Per Trim station, watches the `PrimaryScale` OPC tag (OmniServer publisher path). Debounces stability. Pushes live weight to the session's Perspective client for the Trim binding. Does not call any proc directly — writes only to session props. | OPC tag change event | OmniServer (scale publisher) | `InterfaceLog` once per read session; not per-sample |
| `ReceivingZplDispatcher` | Variant of `LttZplDispatcher` for received LOTs — different ZPL template. May be merged with the base dispatcher via a template-type parameter. | Called after `Lot_CreateReceived` | Zebra printer at Receiving Dock | `InterfaceLog` |

## Perspective Views

| View | Purpose |
|---|---|
| Movement Scan Screen (reusable embedded view) | Scan LTT → `Lot_ScanAtStation` → station UI opens. |
| Trim Station Screen | Embeds Movement Scan. Shows current LOT, UnitWeight, live scale weight, derived piece count. Submits to `ProductionEvent_Record`. |
| Receiving Dock Screen | Part-number scan + vendor-lot entry + count + origin-type selector. Submits to `Lot_CreateReceived`. Prints LTT on success. |
| Off-Site Receiving Screen (VPN) | Same as Receiving Dock Screen with the `ReceivedOffsite` origin-type preset. |

## Test Coverage

New test suite at `sql/tests/0016_PlantFloor_Movement_Trim_Receiving/`:

| File | Covers |
|---|---|
| `010_Lot_ScanAtStation.sql` | Happy path: scan-and-move; blocked LOT rejects; unknown LotName rejects; moves to current location is a no-op (allowed). |
| `020_Lot_WeightToPieceCount.sql` | Valid weight → count; NULL UnitWeight rejects; UOM mismatch rejects. |
| `030_Lot_CreateReceived.sql` | Creates LOT with `Received` or `ReceivedOffsite` origin; auto-generates LotName; vendor-lot uniqueness enforced per Item; invalid origin code rejects. |
| `040_ProductionEvent_at_Trim.sql` | `ProductionEvent_Record` at a Trim OperationTemplate accepts weight + derived count; LotAttributeChange captures piece count before/after; Lot moves to Trim station. |
| `050_Received_lot_serial_range.sql` | `@MinSerialNumber` / `@MaxSerialNumber` persisted; range validation (Min ≤ Max) on create. |

Target: 60–80 passing tests in suite 0016.

## Phase 4 complete when

- [ ] Migration `0013_phase4_movement_trim_receiving.sql` applied; Trim and Receiving OperationTemplates seeded; PrimaryScale LocationAttributeDefinition present.
- [ ] `Lot_ScanAtStation`, `Lot_CreateReceived`, `Lot_WeightToPieceCount` procs delivered and pass tests.
- [ ] All tests in `sql/tests/0016_PlantFloor_Movement_Trim_Receiving/` pass.
- [ ] Perspective Movement Scan Screen, Trim Station Screen, Receiving Dock Screen implemented.
- [ ] Gateway `ScaleTagReader` reads a dev OmniServer scale publisher and feeds a live Trim binding.
- [ ] End-to-end: Die Cast LOT from Phase 3 moves to Trim, weight captured, piece count adjusted; a new received LOT created at Receiving Dock, LTT prints.

---

# Phase 5 — Machining with Sub-LOT Split

**Goal:** Deliver the Machining station's two-touch IN/OUT workflow, auto-split mechanics with operator override, FIFO queue with manual override, and reject capture for out-of-tolerance pieces.

**Dependencies:** Phase 1 (foundation), Phase 2 (`Lot_Split`), Phase 3 (`ProductionEvent_Record`, `RejectEvent_Record`), Phase 4 (Movement Scan pattern).

**Status:** Blocked on Phases 1–3. Phase 4 parallel — can run after Phase 3 independently.

## Data Model Changes

**Migration `sql/migrations/versioned/0014_phase5_machining.sql`:**

- Seed `Parts.OperationTemplate` rows for `MachiningIn` and `MachiningOut` with appropriate DataCollectionFields (`Fixture`, `Program`, `CycleTimeSeconds`, etc. — final set confirmed with MPP).
- Seed any missing `Audit.LogEventType` rows: `MachiningInScanned`, `LotSplit` (already from Phase 2 likely), `MachiningOutCompleted`.

**Tables used:** No new tables. Leverages existing `Lots.Lot`, `LotGenealogy`, `ProductionEvent`, `RejectEvent`.

## Open Items Affecting This Phase

| Item | Fallback |
|---|---|
| UJ-03 sub-LOT split auto vs manual | Phase 0 resolved to auto-split with operator override. Fallback if unresolved: auto-split at `DefaultSubLotQty`, operator confirms or edits. |

## State & Workflow

### FIFO queue semantics

Each Machining Area has an arrival-ordered queue of LOTs awaiting machining. The queue is populated by `Lot_MoveTo` events whose destination is a Machining Area (or a specific Machining machine, depending on how MPP partitions the queue).

`Lot_GetWipQueueByLocation` returns the LOTs at the given location in ascending `LastMovementAt` order. Perspective's Machining IN screen shows this queue; the operator can select any LOT from it (not just the first). When they select a non-first LOT, Perspective prompts "this is not the oldest LOT — continue?" to nudge FIFO compliance without enforcing it (per FRS 2.2.4).

### Machining IN — arrival capture

1. Operator at a CNC machine scans the LTT of an incoming basket.
2. Perspective calls `Lot_ScanAtStation` (Phase 4). LOT moves to this machine's Location (specific machine, not the Machining Area — basket is now at machine).
3. UI opens the Machining IN screen. It shows the LOT, the active MachiningIn OperationTemplate, any prompt fields (e.g., `Fixture`, `Program`).
4. Operator fills the form and submits. Perspective calls `ProductionEvent_Record` with `@OperationTemplateId = MachiningIn`, `@GoodCount = 0` (no production yet — this is an arrival marker), `@NoGoodCount = 0`.
5. `ProductionEvent_Record` writes the event with the operator's captured fields in `ProductionEventValue` (fixture, program, etc.). The LOT's `PieceCount` does not change.
6. Audit as `MachiningInScanned`.

### Machining OUT — completion with auto-split

The machine runs. Parts come off. Operator counts good + bad.

1. At OUT, operator scans LTT. `Lot_ScanAtStation` verifies still-at-this-machine (or re-establishes if machine was used elsewhere in between).
2. UI opens Machining OUT screen. It shows `GoodCount`, `NoGoodCount` inputs.
3. Operator fills: e.g., `GoodCount=48`, `NoGoodCount=1`.
4. UI also presents the split preview: given `Parts.Item.DefaultSubLotQty = 24` for this Item, the split-preview shows "Creates 2 sub-LOTs of 24 each".
5. Operator reviews. They can:
   - **Accept auto-split** — default action. Submit proceeds with 2×24 split.
   - **Edit split quantities** — e.g., change to `[20, 28]` or `[48]` (no split) before submitting.
   - **Cancel split** — skip the split; LOT stays whole. Flagged visually.
6. Operator submits. Perspective calls the composite `MachiningOut_Record` proc:

```
Workorder.MachiningOut_Record(
    @ParentLotId, @LocationId, @OperationTemplateId,
    @GoodCount, @NoGoodCount,
    @SplitChildrenJson NULL | JSON array of {pieceCount, currentLocationId},
    @DataCollectionValuesJson,
    @AppUserId, @TerminalLocationId)
```

7. `MachiningOut_Record` executes:
   - Call `ProductionEvent_Record` (internal) with the MachiningOut operation. This writes the event + values, increments the parent's piece count by `@GoodCount` — wait, clarification: at Machining, `GoodCount` is a through-count, the piece is already in the LOT and being processed. Treat the Machining out event as a pass-through, not an increment: set `@PieceCount` behavior on `ProductionEvent_Record` based on the OperationTemplate type. Option: a flag on `OperationTemplate` (`IsPieceCountIncrement`) that says whether this template adds pieces (Die Cast = yes) or passes them through (Machining = no). Phase 3's `ProductionEvent_Record` honors this flag; Phase 5 seeds MachiningIn / MachiningOut with `IsPieceCountIncrement=0`.
   - If `@NoGoodCount > 0`, record is captured on the event; operator can enter defect codes via follow-on `RejectEvent_Record` calls (same as Die Cast).
   - If `@SplitChildrenJson` present and non-empty: call `Lot_Split` (Phase 2) to create the children. Each child's `@CurrentLocationId` is the same Machining machine (they'll move elsewhere later via scan). Parent is reduced; if residual=0, parent goes to Closed.
8. Audit via `Audit_LogOperation` with `LogEventType='MachiningOutCompleted'`, description includes child counts.
9. Return `Status, Message, ProductionEventId, ChildLotIds[]` (one row per child, Phase 2's multi-row pattern).

### Reject capture at Machining

Same as Die Cast — separate `RejectEvent_Record` call after the main OUT event. The operator selects defect codes from a Machining-Area-filtered DefectCode picker (e.g., `MS-OOT-01 Dimensional`, `MS-TOOLMARK-02`).

### LOT selection from queue — override

If the operator picks a non-first LOT from the queue, the Perspective confirmation dialog captures an optional reason. The captured reason is written to the MachiningIn ProductionEvent's `ProductionEventValue` as a `QueueOverrideReason` field. Enables later supervisor analysis of override patterns.

### Rework LOTs

Machining may process a rework LOT returning from Sort Cage (Phase 7). Rework LOTs appear in the queue if their `CurrentLocationId` is a Machining location. No special handling — they look identical in the queue.

## API Layer

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Lots.Lot_GetWipQueueByLocation` | `@LocationId BIGINT`, `@IncludeChildren BIT = 0` (for Machining Area instead of specific machine) | Returns queue ordered by `LastMovementAt ASC`. Read-only. `@IncludeChildren=1` descends to child Locations (an Area sums its Machines). | `Lots.Lot`, `Lots.LotMovement`, `Location.Location` | Machining IN screen | Rowset: Lot fields + `ArrivedAt`, `HoldFlag` (from BlocksProduction) |
| `Workorder.MachiningOut_Record` | See narrative above | Composite: calls `ProductionEvent_Record` (internal) + optional `Lot_Split`. Single transaction. | `Workorder.ProductionEvent_Record`, `Lots.Lot_Split`, `Audit.Audit_LogOperation` | Machining OUT screen | Multi-row rowset: header row with `Status, Message, ProductionEventId`; additional rows for each child LOT |

**Note:** `ProductionEvent_Record` receives a small upgrade in Phase 5: honors `Parts.OperationTemplate.IsPieceCountIncrement` flag. If 0, does not increment `Lot.PieceCount` on the parent. Phase 3 deliverable gets this flag added in the Phase 3 proc source; migration 0012 (Phase 3) seeds `DieCastShot.IsPieceCountIncrement=1`; migration 0014 (Phase 5) seeds MachiningIn / MachiningOut with `IsPieceCountIncrement=0`.

That flag needs a column in `Parts.OperationTemplate` — which means a retroactive DDL addition:

**Migration `0014_phase5_machining.sql` also adds:**

```sql
ALTER TABLE Parts.OperationTemplate
    ADD IsPieceCountIncrement BIT NOT NULL DEFAULT 1;
```

and backfills seed rows (`DieCastShot`=1, `TrimShopOperation`=1, `MachiningIn`=0, `MachiningOut`=0, `ReceivingInspection`=0).

## Gateway Scripts

| Script | Purpose | Trigger | External System | Audit |
|---|---|---|---|---|
| `MachiningCycleReader` (optional — per machine integration) | Reads `CycleComplete` edge from PLC, stamps a cycle-time value onto the active ProductionEvent via a helper proc. Optional — operator can enter cycle time manually. | PLC tag edge | PLC (TOPServer) | — |

## Perspective Views

| View | Purpose |
|---|---|
| Machining IN | Queue list (calls `Lot_GetWipQueueByLocation`); scan-or-pick flow; operator selects a LOT, fills MachiningIn template fields, submits `ProductionEvent_Record`. Override-reason prompt on non-FIFO selection. |
| Machining OUT | Shows the LOT at this machine. Inputs: GoodCount, NoGoodCount, template fields. Split preview panel (rendered from `Item.DefaultSubLotQty`) with accept/edit/cancel options. Submits `MachiningOut_Record`. After success: child LTTs print via `LttZplDispatcher`. Reject entry inline. |

## Test Coverage

New test suite at `sql/tests/0017_PlantFloor_Machining/`:

| File | Covers |
|---|---|
| `010_Lot_GetWipQueueByLocation.sql` | Queue returned in arrival order; `@IncludeChildren=1` covers child Locations; blocked LOTs flagged. |
| `020_MachiningOut_Record_no_split.sql` | Single LOT through (no split); ProductionEvent written; parent LOT piece count unchanged (IsPieceCountIncrement=0). |
| `030_MachiningOut_Record_with_split.sql` | Split 48 → [24, 24]; parent closed; 2 SPLIT genealogy rows; 2 child LOTs created at same machine. |
| `040_MachiningOut_Record_partial_split.sql` | Split 48 → [20, 28]; parent at 0 (closed); 2 children with correct counts. |
| `050_MachiningOut_Record_cancel_split.sql` | No split (whole LOT progresses); parent stays open; no SPLIT genealogy rows. |
| `060_MachiningOut_Record_validation.sql` | Over-split (children > parent) rejects; blocked parent rejects; deprecated OperationTemplate rejects; missing `@SplitChildrenJson` when auto-split expected is allowed (accept-default). |
| `070_IsPieceCountIncrement_flag.sql` | DieCastShot increments piece count; MachiningIn/Out do not; TrimShopOperation's behavior confirmed. |

Target: 60–90 passing tests in suite 0017.

## Phase 5 complete when

- [ ] Migration `0014_phase5_machining.sql` applied; `IsPieceCountIncrement` column added; MachiningIn/MachiningOut templates seeded.
- [ ] `Lot_GetWipQueueByLocation` and `MachiningOut_Record` procs delivered; `ProductionEvent_Record` updated to honor `IsPieceCountIncrement`.
- [ ] All tests in `sql/tests/0017_PlantFloor_Machining/` pass.
- [ ] Perspective Machining IN and Machining OUT screens implemented with split preview UI.
- [ ] End-to-end: Die Cast LOT scanned at Machining IN → machined → MachiningOut with split produces two child LTTs on dev Zebra; parent auto-closes when residual=0.

---

# Phase 6 — Assembly + MIP + Container Pack

**Goal:** Deliver the most integration-heavy phase: PLC/MIP handshake for serialized assembly, BOM-validated consumption, serialized part tracking with hardware-interlock-bypass handling, container packing with per-tray position tracking, non-serialized line support, and the first AIM outbound call for `GetNextNumber`.

**Dependencies:** Phase 1 (foundation), Phase 2 (LotGenealogy consumption), Phase 3 (ProductionEvent), Phase 4 (Movement), Phase 5 (Split — rework may flow back through Machining).

**Status:** Blocked on Phases 1–5.

## Data Model Changes

**Migration `sql/migrations/versioned/0015_phase6_assembly.sql`:**

- Apply UJ-16 decision from Phase 0. Most likely outcome (option b + a): add `HardwareInterlockBypassed BIT NOT NULL DEFAULT 0` to both `Workorder.ProductionEvent` **and** `Lots.ContainerSerial`. Alternative: single location per Phase 0 choice.
- Add `Parts.ContainerConfig.ClosureMethodCodeId BIGINT NULL` FK to a new `Parts.ContainerClosureMethodCode` code table (seeded with: `Count`, `Weight`, `ManualClose`). OI-02 currently has a nullable `ClosureMethod NVARCHAR(20)` on `ContainerConfig`; this migration migrates that free-text column to a proper code-table FK. Backfill: existing rows with text value mapped to the new code; drop the old NVARCHAR column after backfill.
- Apply B10 outcome from Phase 0. If update-in-place was chosen for serial migration, create `Lots.ContainerSerialHistory` table:

```sql
CREATE TABLE Lots.ContainerSerialHistory (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    ContainerSerialId BIGINT NOT NULL FK → Lots.ContainerSerial,
    OldContainerId BIGINT NOT NULL FK → Lots.Container,
    NewContainerId BIGINT NOT NULL FK → Lots.Container,
    OldTrayId BIGINT NULL FK → Lots.ContainerTray,
    NewTrayId BIGINT NULL FK → Lots.ContainerTray,
    OldTrayPosition INT NULL,
    NewTrayPosition INT NULL,
    ChangeReason NVARCHAR(500) NOT NULL,
    ChangedByUserId BIGINT NOT NULL FK → Location.AppUser,
    TerminalLocationId BIGINT NOT NULL FK → Location.Location,
    ChangedAt DATETIME2(3) NOT NULL DEFAULT SYSDATETIME()
);
```

- Seed `Parts.OperationTemplate` rows for `SerializedAssembly` and `NonSerializedAssembly` with their DataCollectionField sets.
- Seed `Audit.LogEventType` entries: `ConsumptionRecorded`, `SerialCreated`, `ContainerCreated`, `ContainerCompleted`, `AimGetNextNumberCalled`.

## Open Items Affecting This Phase

| Item | Fallback / Resolution |
|---|---|
| UJ-16 `HardwareInterlockBypassed` flag | Phase 0 decision — column(s) added in migration 0015. If unresolved, ship with both ProductionEvent and ContainerSerial columns (safest). |
| UJ-05 serial migration | Phase 0 decision — B10 rewritten. If update-in-place: `ContainerSerialHistory` table added. If void-and-recreate: no new table; `ContainerSerial_Add` + `ShippingLabel_Void` suffice. |
| OI-02 container closure | Fallback: count-based closure if `ContainerConfig.ClosureMethodCodeId` is Count or NULL; weight-based if Weight; manual close if ManualClose. `Container_Complete` checks the configured method. |
| UJ-17 vision vs barcode | Fallback: barcode canonical. If vision data returns a mismatch, auto-place a LOT hold (Phase 7) with reason `VisionMismatch` and supervisor override (re-auth required). |
| UJ-09 material verification | Fallback: BOM-based. Consumption validates the source LOT's ItemId matches an active `BomLine.ChildItemId` of the output's active `Bom`. |

## State & Workflow

### Serialized assembly line (5G0)

The line has a PLC running the assembly machine, a laser etcher for serial numbers, and a Zebra printer at the container close point. An MIP (Machine Integration Panel) exposes OPC tags that the Gateway script watches.

MIP tags (descriptive — actual addresses in `5GO_AP4_Automation_Touchpoint_Agreement.pdf`):

- `DataReady` — BIT; PLC sets to 1 when a part is ready for validation.
- `PartSN` — string; PLC writes the laser-etched serial, or `"NoRead"` if interlock bypassed.
- `PartValid` — BIT; MES writes 1 after successful validation.
- `HardwareInterlockEnable` — BIT; if 0, PLC proceeds without waiting for `PartValid`.
- `ContainerFull` — BIT (some lines); PLC signals when the container is at its physical capacity.

Gateway script `MipHandshakeWatcher` runs one instance per assembly line. On `DataReady` edge 0→1:

1. Read `PartSN` and `HardwareInterlockEnable`.
2. If `HardwareInterlockEnable=0`: call `SerializedPart_AcceptBypassed(@LineLocationId, @PartSN=NoRead, ...)` — creates a `SerializedPart` row with `HardwareInterlockBypassed=1`, no validation, emits InterfaceLog entry. Write `PartValid=1` (though the PLC won't wait).
3. Else (interlock enabled): call `SerializedPart_Validate(@LineLocationId, @PartSN, @ItemId, @SourceLotIds, ...)`. Proc validates:
   - `@PartSN` not already in `SerializedPart`.
   - `@PartSN` format matches expected pattern for this Item.
   - Source LOTs all match active BOM lines (material verification).
4. If valid: call `ConsumptionEvent_Record` (composite) to write:
   - `ConsumptionEvent` rows linking each source LOT piece consumed.
   - `LotGenealogy` CONSUMPTION rows.
   - `SerializedPart` row with the new serial.
   - `ContainerSerial_Add` row placing the serial in the active container's next tray position.
5. Write `PartValid=1` back to the PLC.
6. If the container is now full (by count, weight, or PLC `ContainerFull=1` signal): call `Container_Complete`. That proc calls `AimGetNextNumber` (Gateway script) → writes `AimShipperId` → triggers `ShippingLabel_Print` (Phase 7 delivers this proc; Phase 6 invokes its stub).

If validation fails: write `PartValid=0`. PLC rejects the part. FailureLog entry. Operator gets an alert on the Assembly Operator Screen.

### Non-serialized assembly line (6B2, RPY)

Simpler path. The PLC exposes `PartDisposition` (Pass/Fail) and `ContainerName`, not individual serials. The Gateway watcher treats each pass-disposition event as a count-increment:

1. On `PartDisposition=Pass` edge: call `ConsumptionEvent_Record` with `@ProducedPieceCount=1` and no serial number. `LotGenealogy` CONSUMPTION row without serial.
2. Increment the active container's count.
3. When count or weight closure threshold hit: `Container_Complete`.

Non-serialized lines don't create `SerializedPart` rows. They still create `Container`, `ContainerTray`, and `ShippingLabel` rows.

### Scale-driven container closure (OI-02)

If `ContainerConfig.ClosureMethodCodeId = Weight`, `Container_Complete` verifies the container's scale reading matches `ContainerConfig.TargetWeight ± tolerance`. The tolerance is a `ContainerConfig` attribute (Phase 6 adds it if Phase 0 resolves the spec). If outside tolerance: reject the close, show operator alert.

If `Count`: closure triggered when `ContainerTray.PieceCount` sum equals `ContainerConfig.TraysPerContainer * PartsPerTray`.

If `ManualClose`: operator presses a "Close Container" button; no automatic trigger.

### BOM-based material verification (UJ-09)

When a source LOT is scanned at the assembly line (or the PLC publishes it), the MES validates:

1. The line's output Item has an active Bom (`Bom.DeprecatedAt IS NULL AND Bom.PublishedAt IS NOT NULL`).
2. The source LOT's `ItemId` matches one of the `BomLine.ChildItemId` entries for that Bom.

If the source doesn't match: reject, hold the output LOT, alert operator (UJ-17 vision mismatch pattern reused).

### Sort Cage flow-back (preview — Phase 7 delivers)

Sort Cage can update `ContainerSerial` rows. In Phase 6's delivery, `ContainerSerial_Add` is the only write path. In Phase 7, the update/remove/history procs land. Phase 6 leaves the data model ready (including `ContainerSerialHistory` if chosen).

### `ConsumptionEvent_Record` proc (composite)

Signature:

```
Workorder.ConsumptionEvent_Record(
    @SourceLotId BIGINT,
    @ConsumedPieceCount INT,
    @ConsumedItemId BIGINT,
    @ProducedItemId BIGINT,
    @ProducedLotId BIGINT NULL,           -- For non-serialized into-Lot flows
    @ProducedContainerId BIGINT,
    @ProducedContainerTrayId BIGINT NULL,
    @ProducedSerialNumber NVARCHAR(100) NULL,
    @TrayPosition INT NULL,
    @HardwareInterlockBypassed BIT = 0,
    @LocationId BIGINT,
    @AppUserId BIGINT,
    @TerminalLocationId BIGINT
)
```

Sequence:

1. Validate params.
2. `Lot_AssertNotBlocked` on `@SourceLotId`.
3. Material verification (BOM check — UJ-09).
4. Insert `Workorder.ConsumptionEvent` row.
5. Call `Lots.LotGenealogy_RecordConsumption` (Phase 2) with the CONSUMPTION relationship.
6. Decrement `@SourceLotId` piece count by `@ConsumedPieceCount`. If count hits 0, update status to Closed via `Lot_UpdateStatus`.
7. If `@ProducedSerialNumber` is present: call `SerializedPart_Create` (internal) with `HardwareInterlockBypassed`. Then call `ContainerSerial_Add` with `@TrayPosition`.
8. Update `ContainerTray.PieceCount` += 1 (for serialized) or += `@ConsumedPieceCount` (for non-serialized pass-through). Update `Container` rollup counts if materialized.
9. Audit `LogEventType='ConsumptionRecorded'`.
10. Return `Status, Message, ConsumptionEventId, SerializedPartId (if any), ContainerSerialId (if any)`.

## API Layer

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Workorder.ConsumptionEvent_Record` | See narrative | Composite consumption + genealogy + serialization + container placement. Single transaction. | `Workorder.ConsumptionEvent`, `Lots.LotGenealogy_RecordConsumption`, `Lots.SerializedPart`, `Lots.ContainerSerial`, `Lots.ContainerTray`, `Lots.Container`, `Lots.Lot_UpdateStatus`, `Lots.Lot_AssertNotBlocked`, `Parts.Bom`, `Parts.BomLine`, `Audit.Audit_LogOperation` | MIP handshake; non-serialized line; manual assembly recording | `Status, Message, ConsumptionEventId, SerializedPartId, ContainerSerialId` |
| `Lots.SerializedPart_Validate` | `@PartSN NVARCHAR(100)`, `@ItemId BIGINT`, `@LineLocationId BIGINT` | Pre-check before accepting a serial from the PLC. Verifies uniqueness, format, item-at-line eligibility. Does NOT create the row. | `Lots.SerializedPart`, `Parts.Item`, `Parts.ItemLocation` | MIP handshake before PartValid | `Status, Message` |
| `Lots.SerializedPart_Create` | `@PartSN NVARCHAR(100)` (or NULL for NoRead), `@ItemId BIGINT`, `@LotId BIGINT` (produced LOT; may be NULL if container-only), `@ContainerId BIGINT NULL`, `@HardwareInterlockBypassed BIT`, `@AppUserId`, `@TerminalLocationId` | Creates the serial row. Internal — called by `ConsumptionEvent_Record`. | `Lots.SerializedPart`, `Audit.Audit_LogOperation` | Internal from ConsumptionEvent_Record | `Status, Message, NewId` |
| `Lots.Container_Create` | `@ItemId BIGINT`, `@ContainerConfigId BIGINT`, `@SourceLotId BIGINT NULL`, `@CurrentLocationId BIGINT`, `@ContainerIdBarcode NVARCHAR(100)`, `@AppUserId`, `@TerminalLocationId` | Creates the Container row with status Open. Generates `ContainerIdBarcode` if NULL (pattern: `CTR-YYYYMMDD-NNNN`). | `Lots.Container`, `Lots.ContainerStatusCode`, `Parts.Item`, `Parts.ContainerConfig`, `Audit.Audit_LogOperation` | Line start or when previous container completes | `Status, Message, NewId` |
| `Lots.ContainerTray_Add` | `@ContainerId BIGINT`, `@TrayNumber INT`, `@AppUserId`, `@TerminalLocationId` | Adds a tray to a container. PieceCount starts 0. `TrayNumber` unique within container. | `Lots.ContainerTray`, `Audit.Audit_LogOperation` | When a new tray is started | `Status, Message, NewId` |
| `Lots.ContainerSerial_Add` | `@ContainerId BIGINT`, `@ContainerTrayId BIGINT NULL`, `@SerializedPartId BIGINT`, `@TrayPosition INT NULL`, `@HardwareInterlockBypassed BIT`, `@AppUserId`, `@TerminalLocationId` | Places a serial into a tray position. Validates position not occupied in this container, serial not already in another container. | `Lots.ContainerSerial`, `Lots.ContainerTray`, `Audit.Audit_LogOperation` | Internal from ConsumptionEvent_Record | `Status, Message, NewId` |
| `Lots.Container_Complete` | `@ContainerId BIGINT`, `@AppUserId`, `@TerminalLocationId` | Validates closure: count or weight per `ContainerConfig.ClosureMethodCodeId`. Transitions status Open → Complete. Triggers AIM `GetNextNumber` via Gateway (which writes `AimShipperId` back). After AIM response, invokes `ShippingLabel_Print` (also delivered in this phase — see next row) to record the initial shipping label. | `Lots.Container`, `Lots.ContainerTray`, `Parts.ContainerConfig`, `Lots.ShippingLabel_Print`, `Audit.Audit_LogOperation` | When container reaches closure condition | `Status, Message, AimShipperId` (populated by Gateway after call) |
| `Lots.ShippingLabel_Print` | `@ContainerId`, `@LabelTypeCodeId`, `@PrintReasonCodeId`, `@ZplContent NVARCHAR(MAX)`, `@AppUserId`, `@TerminalLocationId` | Writes the ShippingLabel audit row with full ZPL content. Gateway dispatches the physical print. Delivered in Phase 6 because `Container_Complete` invokes it. Phase 7 adds `ShippingLabel_Void` and list / reprint flows on top of it. | `Lots.ShippingLabel`, `Lots.LabelTypeCode`, `Lots.PrintReasonCode`, `Audit.Audit_LogOperation` | `Container_Complete` success path; Phase 7 Sort Cage re-pack | `Status, Message, NewId` |
| `Lots.Container_Get` | `@ContainerId BIGINT NULL`, `@ContainerIdBarcode NVARCHAR(100) NULL` | Read proc. Returns container + roll-up counts. | `Lots.Container`, `Lots.ContainerTray` | Screens that display container state | Single row |
| `Lots.Container_List` | Various filters | Read proc. | `Lots.Container` | Supervisor dashboards | Rowset |

If UJ-05 resolved to update-in-place (B10):

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Lots.ContainerSerial_RelocateInPlace` | `@ContainerSerialId BIGINT`, `@NewContainerId BIGINT`, `@NewContainerTrayId BIGINT NULL`, `@NewTrayPosition INT NULL`, `@ChangeReason NVARCHAR(500)`, `@AppUserId`, `@TerminalLocationId` | Updates ContainerSerial in place, writes ContainerSerialHistory audit row. Phase 7 actually exercises this; Phase 6 delivers the proc. | `Lots.ContainerSerial`, `Lots.ContainerSerialHistory`, `Audit.Audit_LogOperation` | Phase 7 Sort Cage workflow | `Status, Message` |

## Gateway Scripts

| Script | Purpose | Trigger | External System | Audit |
|---|---|---|---|---|
| `MipHandshakeWatcher` (one instance per serialized line) | Watches `DataReady`, `HardwareInterlockEnable`, `PartSN`; orchestrates SerializedPart_Validate / SerializedPart_Create / ConsumptionEvent_Record; writes `PartValid` back. | OPC tag edges | PLC via TOPServer | `InterfaceLog` with `SystemName='MIP'` |
| `NonSerializedAssemblyWatcher` (one instance per non-serialized line) | Watches `PartDisposition`; calls ConsumptionEvent_Record on Pass. Increments container count. | OPC tag edges | PLC via TOPServer | `InterfaceLog` with `SystemName='PLC'` |
| `AimGetNextNumberCaller` | Called by `Container_Complete` in the success path. Issues AIM `GetNextNumber` HTTP/SOAP request with container info. On response, updates `Container.AimShipperId`. | Inside `Container_Complete` success handler | AIM | `InterfaceLog` with `SystemName='AIM'`, `Direction='Outbound'` |
| `AssemblyZebraDispatcher` | Renders container shipping label ZPL from template + container data; dispatches to the container-close Zebra. Updates `ShippingLabel.PrintedAt`. | Called by Container_Complete success path | Zebra printer | `InterfaceLog` with `SystemName='Zebra'` |
| `ContainerScaleReader` (optional — weight closure lines) | Publishes container weight to the Assembly Screen's live binding; provides the value used by `Container_Complete` for weight-based closure check. | OPC tag change | OmniServer | `InterfaceLog` (per-session) |
| `VisionMismatchLogger` (optional — UJ-17 affected lines) | On vision-vs-barcode mismatch, logs to `InterfaceLog` with severity Warning and alerts the operator on the Assembly Screen. Auto-hold on mismatch is **not** wired in Phase 6 — `HoldEvent_Place` ships in Phase 7. Once Phase 7 lands, this script is upgraded to `VisionMismatchHandler` that calls `HoldEvent_Place` automatically. | Vision system event | Cognex vision system | `InterfaceLog` |

## Perspective Views

| View | Purpose |
|---|---|
| Assembly Operator Screen (serialized line variant) | Real-time MIP status panel (DataReady, HardwareInterlockEnable, PartSN, PartValid, container fill). Current container's tray grid. Source-LOT bay with scanned LTTs. BOM verification indicator. Alert panel for mismatches/holds. |
| Assembly Operator Screen (non-serialized variant) | Simpler layout: PartDisposition counter, container fill, source-LOT bay. Same alert panel. |
| Assembly Supervisor Overview | Line status, active container, fill %, recent MIP events, interlock-bypass flag sightings. |
| Container Detail (modal) | Opens from Assembly screen or from a container search. Shows tray grid with serials, source LOTs consumed, AimShipperId, status. |

## Test Coverage

New test suite at `sql/tests/0018_PlantFloor_Assembly/`:

| File | Covers |
|---|---|
| `010_SerializedPart_Validate.sql` | Unique PartSN accepts; duplicate rejects; bad format rejects (regex check if configured); item-at-line ineligible rejects. |
| `020_SerializedPart_Create.sql` | Insert row; NoRead (NULL PartSN with HardwareInterlockBypassed=1) accepted; audit correct. |
| `030_Container_Create.sql` | Creates container with generated ContainerIdBarcode; ContainerConfig required; ItemId required. |
| `040_ContainerTray_Add.sql` | Adds tray; duplicate TrayNumber rejects. |
| `050_ContainerSerial_Add.sql` | Places serial in tray position; duplicate position rejects; serial already in another container rejects; HardwareInterlockBypassed propagates. |
| `060_ConsumptionEvent_Record.sql` | Composite: source piece count decrements; CONSUMPTION genealogy row written; if serial provided, SerializedPart + ContainerSerial created; BOM verification rejects wrong source Item; blocked source rejects. |
| `070_Container_Complete_count.sql` | Count-based closure passes when full; rejects when under capacity; ClosureMethod=Count path. |
| `080_Container_Complete_weight.sql` | Weight-based closure validates against TargetWeight; outside tolerance rejects. |
| `090_Container_Complete_manual.sql` | ManualClose skips auto-validation; operator close succeeds. |
| `100_ContainerSerial_RelocateInPlace.sql` (if B10 update-in-place) | Relocates serial; ContainerSerialHistory row written; OldContainer/NewContainer correct. |
| `110_HardwareInterlockBypassed_flag.sql` | Flag propagates from ConsumptionEvent_Record → ContainerSerial (and/or ProductionEvent, per Phase 0 scope). |

Target: 150–200 passing tests in suite 0018 (biggest phase, most branches).

## Phase 6 complete when

- [ ] Migration `0015_phase6_assembly.sql` applied: UJ-16 flag column(s) added; `ContainerClosureMethodCode` code table + FK; ContainerSerialHistory (if B10 update-in-place); operation templates seeded.
- [ ] All Assembly procs delivered: `ConsumptionEvent_Record`, `SerializedPart_Validate` + `_Create`, `Container_Create` + `_Complete`, `ContainerTray_Add`, `ContainerSerial_Add`, `ContainerSerial_RelocateInPlace` (if B10).
- [ ] All tests in `sql/tests/0018_PlantFloor_Assembly/` pass (target 150–200).
- [ ] `MipHandshakeWatcher`, `NonSerializedAssemblyWatcher`, `AimGetNextNumberCaller`, `AssemblyZebraDispatcher` Gateway scripts implemented against dev PLC simulator / AIM mock endpoint.
- [ ] Perspective Assembly Operator Screens (serialized + non-serialized variants) implemented.
- [ ] End-to-end on dev bench: operator scans source LOT → PLC simulator fires DataReady → MES validates, writes serial, fills tray → container auto-completes → AIM mock returns ShipperId → container shipping label prints.
- [ ] HardwareInterlockEnable=0 bypass path verified: NoRead serial accepted, bypass flag set on downstream rows.
- [ ] Vision mismatch simulation logs to InterfaceLog and alerts operator (auto-hold wiring deferred to Phase 7 after `HoldEvent_Place` ships).

---

# Phase 7 — Hold + Sort Cage + Shipping + AIM

**Goal:** Deliver the quality-supervisor and shipping workflows, plus the remaining AIM outbound integrations. Hold placement with multi-LOT support, Sort Cage re-containerization with serial migration (per Phase 0 pattern), shipping-label void/reprint, final ship gate, and truck manifest.

**Dependencies:** Phase 1 (foundation), Phase 2 (LOT lifecycle, labels), Phase 3 (reject / events), Phase 6 (Container + ContainerSerial + ShippingLabel scaffolding).

**Status:** Blocked on Phases 1–3 and 6.

## Data Model Changes

**Migration `sql/migrations/versioned/0016_phase7_hold_sort_shipping.sql`:**

- Seed `Audit.LogEventType` entries: `HoldPlaced`, `HoldReleased`, `ContainerHeld`, `ContainerReleased`, `ShippingLabelPrinted`, `ShippingLabelVoided`, `ContainerShipped`, `AimPlaceOnHoldCalled`, `AimReleaseFromHoldCalled`, `AimUpdateAimCalled`.
- Seed `Quality.HoldTypeCode` rows if not already: `Quality`, `CustomerComplaint`, `Precautionary`, `VisionMismatch` (from UJ-17 fallback).
- Apply any B10 (serial migration) schema deltas not already applied in Phase 6.
- Seed `Lots.PrintReasonCode` rows for shipping-label scenarios: `InitialShipping`, `ReprintDamaged`, `SortCageReIdentify`, `AimResync`.

**Tables used:** `Quality.HoldEvent`, `Quality.HoldTypeCode`, `Lots.Container`, `Lots.ContainerSerial`, `Lots.ContainerSerialHistory` (if B10), `Lots.ShippingLabel`, `Lots.LabelTypeCode`, `Lots.Lot`, `Lots.LotStatusHistory`, `Audit.*`.

## Open Items Affecting This Phase

| Item | Fallback / Resolution |
|---|---|
| UJ-05 Sort Cage migration | Phase 0 decision applied here. Write paths differ by choice. |
| UJ-17 vision handling | Auto-hold reason = `VisionMismatch`; supervisor override requires re-auth. |
| OI-02 closure affects Sort Cage | Re-containerized outputs re-apply closure method; if Weight, new scale reading required. |

## State & Workflow

### Hold placement (multi-LOT)

Quality supervisor Diane gets a call from Honda. She opens the Hold Management screen.

1. Diane filters LOTs (by Item `5G0`, date range yesterday 14:00–22:00, status = Good or Scrap). Multi-select available.
2. She selects 12 candidate LOTs. Clicks "Place on Hold".
3. Modal: select `HoldTypeCode` (`CustomerComplaint`), enter reason (`Honda dimensional concern, pending investigation`), re-authenticates.
4. Perspective iterates the selection, calling `HoldEvent_Place` for each:

```
Quality.HoldEvent_Place(
    @LotId, @HoldTypeCodeId, @NonConformanceId NULL (MVP: always NULL),
    @Reason NVARCHAR(500), @AppUserId, @TerminalLocationId)
```

5. Each call:
   - `Lot_AssertNotBlocked` — if already held, reject (B3 open-event invariant).
   - Insert `Quality.HoldEvent` row with `PlacedAt = SYSDATETIME()`, `ReleasedAt NULL`.
   - Call `Lot_UpdateStatus` → `Hold` (with internal no-op suppression for LOTs already Hold — edge case).
   - Audit `HoldPlaced`.

6. For each held LOT, Perspective also checks `Lots.Container` rows where `LotId = this LOT`. For each container not already shipped: call `Container_UpdateStatus → Hold` and trigger Gateway `AimPlaceOnHoldCaller` with the container's `AimShipperId`. AIM's ack is logged to `InterfaceLog`.
7. Result screen shows: 12 LOTs held, 3 containers flagged, AIM acknowledgements logged.

### Hold release

1. After investigation, Diane clears the hold. Hold Management screen lets her filter open holds and select the ones to release.
2. Perspective calls `HoldEvent_Release` per LOT:

```
Quality.HoldEvent_Release(
    @HoldEventId, @ReleaseRemarks NVARCHAR(500),
    @AppUserId, @TerminalLocationId)
```

3. Proc updates the `HoldEvent` row: `ReleasedByUserId`, `ReleasedAt = SYSDATETIME()`, `ReleaseRemarks`.
4. Proc calls `Lot_UpdateStatus` → `Good` (or whatever the pre-hold status was; captured by HoldEvent — but MVP fallback is always restore to `Good`).
5. For containers that were held: Perspective calls `Container_UpdateStatus → Complete` and Gateway `AimReleaseFromHoldCaller`.
6. Audit `HoldReleased`.

### Sort Cage re-containerization

Diane identifies that the issue is localized to cavity A of die 42 from yesterday's second shift. Three LOTs affected, two already in containers at dock.

1. **WIP LOT split** — she opens one LOT in LOT Detail, uses `Lot_Split` (Phase 2) to carve out the 12 suspect pieces. The suspect child's status → `Scrap` via `Lot_UpdateStatus`. Parent returns to `Good` if she releases its hold.

2. **Container unpacking and re-containerization** — for the two containers at the dock:
   - Diane moves the containers to the Sort Cage location (`Container_UpdateStatus` to Hold or leave held; update `CurrentLocationId` via a helper).
   - Opens Sort Cage Workflow screen for one container.
   - Screen shows the tray grid (from `ContainerSerial_List`). Each serial is selectable with Pass / Fail / Rework buttons.
   - Operator inspects each part. Marks some Pass, some Fail.
     - **Pass** → serial gets migrated to a new "good" output container.
     - **Fail** → serial's `SerializedPart` gets its `LotId` reassigned to a new Scrap LOT (created on-demand).
     - **Rework** → serial gets placed in a rework container that routes back through Machining.
   - Perspective tracks the decisions in session state until Diane "commits" the re-container.

3. **On commit** — one of two patterns per Phase 0 UJ-05:

   - **Pattern A (void-and-recreate):** Original ShippingLabel voided via `ShippingLabel_Void`; Gateway `AimUpdateAimCaller` calls AIM `UpdateAim(serial, previousSerial)` per Appendix L. The original `Container` status goes `Void`. New `Container` rows created for Good / Scrap / Rework outputs. New `SerializedPart` rows... no, same physical part — do we recreate? Likely we keep the same `SerializedPart` but move it to the new container via `ContainerSerial_Add`. The old `ContainerSerial` row stays (historical — container was voided, serial "left" when container was voided).
   - **Pattern B (update-in-place):** `ContainerSerial_RelocateInPlace` (Phase 6 proc) called per serial, with `@ChangeReason = 'SortCageSort'`, migrating to new container. `ContainerSerialHistory` rows capture old vs. new. Original container still exists as a historical record; a final `Container_Close` state may be Void, Complete, or a new status `Depleted`.

   Per Phase 0 decision, one of these is chosen. Plan convention B10 captures the specifics.

4. **New shipping labels** — for each new output container (Good ones), `ShippingLabel_Print` with `LabelTypeCode='Container'` and `PrintReasonCode='SortCageReIdentify'`. If the Good output container is ready to ship, Gateway `AimGetNextNumberCaller` gets a new ShipperId.

5. **AIM reconciliation** — per FRS Appendix L, `UpdateAim(serial, previousSerial)` is called for each serial that migrated. Gateway handles the sequence per Phase 0 decision.

### Shipping

The good containers — released from hold, re-sorted as needed — are loaded on the truck.

1. Shipping operator at the Shipping Dock scans each container's shipping label barcode.
2. Perspective calls `Container_Ship`:

```
Lots.Container_Ship(
    @ContainerId, @TruckId NVARCHAR(50) NULL, @ManifestId BIGINT NULL,
    @AppUserId, @TerminalLocationId)
```

3. Proc validates:
   - Container status = Complete (not Hold, not Void).
   - AimShipperId present (non-NULL).
   - Not already Shipped.
4. Update container status → Shipped. Update `CurrentLocationId` → Shipping Dock (or a "Shipped" abstract location).
5. Audit `ContainerShipped`.

A simple truck-manifest table may be added later; for MVP, Container_Ship records the `TruckId` on the container header and Perspective produces a printable manifest from a list of containers with the same TruckId.

### Re-auth for high-security actions

Placing holds, releasing holds, voiding labels, scrapping LOTs all require re-authentication per Phase 1's session model. The re-auth modal confirms the operator's identity for the specific action. No session-level state change.

## API Layer

### Hold management

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Quality.HoldEvent_Place` | `@LotId`, `@HoldTypeCodeId`, `@NonConformanceId NULL`, `@Reason NVARCHAR(500)`, `@AppUserId`, `@TerminalLocationId` | Creates HoldEvent (open). Updates Lot status → Hold via `Lot_UpdateStatus`. B3 invariant: rejects if open hold exists. | `Quality.HoldEvent`, `Lots.Lot_UpdateStatus`, `Lots.Lot_AssertNotBlocked`, `Audit.Audit_LogOperation` | Hold Management screen | `Status, Message, NewId` |
| `Quality.HoldEvent_Release` | `@HoldEventId`, `@ReleaseRemarks`, `@AppUserId`, `@TerminalLocationId` | Updates HoldEvent with ReleasedAt/By. Updates Lot status → Good (MVP fallback). | `Quality.HoldEvent`, `Lots.Lot_UpdateStatus`, `Audit.Audit_LogOperation` | Hold Management release action | `Status, Message` |
| `Quality.HoldEvent_List` | `@LotId NULL`, `@HoldTypeCodeId NULL`, `@IsOpen BIT NULL`, `@DateFrom NULL`, `@DateTo NULL` | Read proc. Filterable. | `Quality.HoldEvent`, `Quality.HoldTypeCode`, `Lots.Lot` | Supervisor search | Rowset |
| `Quality.HoldEvent_Get` | `@HoldEventId` | Single row. | `Quality.HoldEvent` | Hold detail | Single row |

### Container state transitions (Phase 7 additions)

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Lots.Container_UpdateStatus` | `@ContainerId`, `@NewContainerStatusId`, `@Reason NVARCHAR(500) NULL`, `@AppUserId`, `@TerminalLocationId` | Transitions container status. Validates legal transitions (Open→Complete→Shipped; any→Hold; any→Void). Rejects no-op. | `Lots.Container`, `Lots.ContainerStatusCode`, `Audit.Audit_LogOperation` | Hold or re-sort or ship | `Status, Message` |
| `Lots.Container_Ship` | See narrative | Final ship gate. | `Lots.Container`, `Lots.Container_UpdateStatus`, `Audit.Audit_LogOperation` | Shipping Dock scan | `Status, Message` |

### Shipping labels

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Lots.ShippingLabel_Void` | `@ShippingLabelId`, `@VoidReason NVARCHAR(500)`, `@AppUserId`, `@TerminalLocationId` | Marks IsVoid=1, VoidedAt, VoidedByUserId. Never deletes. | `Lots.ShippingLabel`, `Audit.Audit_LogOperation` | Sort Cage, operator correction | `Status, Message` |
| `Lots.ShippingLabel_List` | Filters | Read proc. | `Lots.ShippingLabel` | Supervisor audit | Rowset |

**Note:** `Lots.ShippingLabel_Print` is delivered in Phase 6 (it is invoked by `Container_Complete`); Phase 7 adds the Void + List / reprint flows that wrap it. The Sort Cage Workflow in this phase invokes `ShippingLabel_Void` followed by `ShippingLabel_Print` (from Phase 6) with `PrintReasonCode='SortCageReIdentify'`.

### Sort Cage re-container (composite)

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Lots.Container_SortCageReContainer` | `@SourceContainerId`, `@DispositionsJson NVARCHAR(MAX)` (array of `{serializedPartId, disposition: Pass\|Fail\|Rework, newContainerId?}`), `@AppUserId`, `@TerminalLocationId` | Composite — iterates dispositions, moves serials per Phase 0 pattern. For Pass/Rework, call `ContainerSerial_RelocateInPlace` (B) or void-and-recreate flow (A). For Fail, also update affected `SerializedPart.LotId` to new scrap LOT. Emits one `ContainerSerialHistory` row per serial (if pattern B). Voids source container (Pattern A) or leaves it marked `Depleted` (Pattern B). | Many — see narrative | Sort Cage Workflow commit | `Status, Message` |

## Gateway Scripts

| Script | Purpose | Trigger | External System | Audit |
|---|---|---|---|---|
| `AimPlaceOnHoldCaller` | Calls AIM `PlaceOnHold(aimShipperId)`. Logs request + response. | Called from Container_UpdateStatus when status = Hold AND container was already shipped to AIM | AIM | `InterfaceLog` |
| `AimReleaseFromHoldCaller` | Calls AIM `ReleaseFromHold(aimShipperId)`. | Called from Container_UpdateStatus when status returns from Hold | AIM | `InterfaceLog` |
| `AimUpdateAimCaller` | Calls AIM `UpdateAim(serial, previousSerial)` per Appendix L. Used during Sort Cage serial migration. | Called from Container_SortCageReContainer per migrated serial | AIM | `InterfaceLog` |
| `AimGetNextNumberCaller` (delivered Phase 6, reused) | Reused in Phase 7 for new Good output containers from Sort Cage. | After Container_Complete success | AIM | `InterfaceLog` |
| `ShippingZplDispatcher` | Renders shipping label ZPL; dispatches to dock Zebra. Updates ShippingLabel.PrintedAt. | After ShippingLabel_Print returns | Zebra | `InterfaceLog` |
| `ManifestPrinter` | Renders truck manifest (list of containers with same TruckId); dispatches to dock printer as PDF or ZPL. | Manifest print action on Shipping Dock | Printer | `InterfaceLog` |

## Perspective Views

| View | Purpose |
|---|---|
| Hold Management | Multi-filter LOT search; multi-select; hold place / release flow with re-auth modal. |
| Hold Detail | Single HoldEvent detail — reason, placed/released timestamps, affected containers, release action. |
| Sort Cage Workflow | Container tray grid with disposition buttons per serial; session-state pending dispositions; commit action invokes `Container_SortCageReContainer`. |
| Shipping Dock | Scan shipping label barcode → `Container_Ship`; lists loaded containers; truck ID entry; print manifest action. |
| Manifest Viewer | Printable manifest for a given TruckId. |
| Shipping Label Audit | Filter / search ShippingLabel history; show void chains. |

## Test Coverage

New test suite at `sql/tests/0019_PlantFloor_Hold_Sort_Shipping/`:

| File | Covers |
|---|---|
| `010_HoldEvent_Place.sql` | Creates HoldEvent open; updates Lot status; B3 rejects duplicate open; blocked LOT rejects (Closed/Scrap already). |
| `020_HoldEvent_Release.sql` | Updates ReleasedAt; restores Lot status; rejects if already released. |
| `030_Container_UpdateStatus.sql` | Legal transitions pass; illegal reject; no-op rejects. |
| `040_Container_Ship.sql` | Shipping succeeds when Complete + AimShipperId present; Hold rejects; Void rejects; already Shipped rejects. |
| `050_ShippingLabel_Print_Void.sql` | Print creates row; void marks IsVoid; void of already-void rejects. |
| `060_Container_SortCageReContainer_patternA.sql` (if void-and-recreate) | Original container voided; ContainerSerial left; new container created with ContainerSerial_Add; AIM update logged. |
| `070_Container_SortCageReContainer_patternB.sql` (if update-in-place) | ContainerSerial relocated; ContainerSerialHistory row per serial; original container marked Depleted. |
| `080_Hold_cascades_to_containers.sql` | HoldEvent_Place on a LOT with shipped containers triggers Container_UpdateStatus=Hold for each. |

Target: 120–160 passing tests in suite 0019.

## Phase 7 complete when

- [ ] Migration `0016_phase7_hold_sort_shipping.sql` applied; LogEventType + HoldTypeCode + PrintReasonCode seeds present; B10 schema applied (if update-in-place).
- [ ] Hold, Container status, ShippingLabel, and Sort Cage procs delivered.
- [ ] All tests in `sql/tests/0019_PlantFloor_Hold_Sort_Shipping/` pass (target 120–160).
- [ ] Gateway scripts `AimPlaceOnHoldCaller`, `AimReleaseFromHoldCaller`, `AimUpdateAimCaller`, `ShippingZplDispatcher`, `ManifestPrinter` implemented against AIM mock + dev Zebra.
- [ ] Perspective Hold Management, Sort Cage Workflow, Shipping Dock, Manifest views implemented.
- [ ] End-to-end: multi-LOT hold → container hold cascades → sort cage reclassifies serials → new containers ship → AIM calls logged.
- [ ] B10 convention text in this document matches the delivered pattern (A or B).

---

# Phase 8 — Downtime + Shift Boundary (Parallel Track)

**Goal:** Capture machine downtime events (manual and PLC-driven), support late-binding reason assignment, capture warm-up / setup shot counts, and apply shift-boundary rules for open downtime continuity. Runs in parallel with Phases 2–7 as soon as Phase 1 foundation lands.

**Dependencies:** Phase 1 (foundation — Shift runtime, LOT core). No direct dependency on Phases 2–7.

**Status:** Blocked on Phase 1 only; a separate team can develop Phase 8 concurrently with Phases 2–7.

## Data Model Changes

**Migration `sql/migrations/versioned/0017_phase8_downtime_shift.sql`:**

- Seed `Audit.LogEventType` entries: `DowntimeStarted`, `DowntimeEnded`, `DowntimeReasonAssigned`, `ShiftBoundaryCarryover`.
- If not already present from Arc 1: seed `Oee.DowntimeSourceCode` rows (`Manual`, `PLC`). (These were seeded in Arc 1 Phase 8; verify.)
- If Phase 0 produced a `ShiftBoundaryCarryoverRuleCode` or similar code table, seed its rows here.

**Tables used:** `Oee.DowntimeEvent`, `Oee.DowntimeSourceCode`, `Oee.DowntimeReasonCode`, `Oee.DowntimeReasonType`, `Oee.Shift`, `Oee.ShiftSchedule`, `Audit.OperationLog`, `Audit.InterfaceLog` (PLC events).

## Open Items Affecting This Phase

| Item | Fallback / Resolution |
|---|---|
| UJ-10 shift boundary carryover | Phase 0 decision applied in `Shift_End` and in the boundary ticker. Fallback: leave open `DowntimeEvent` rows open across shift boundaries (no auto-close); supervisor can manually close if stale. |
| UJ-14 warm-up shots | Captured on `DowntimeEvent.ShotCount` when `DowntimeReasonType='Setup'`. Already seeded schema — Phase 8 ensures the procs honor it. |

## State & Workflow

### Manual downtime entry

Carlos's die sticks at 6:45am. He taps "Record Downtime" on the Die Cast screen's always-visible panel.

1. Modal opens with:
   - Machine name (pre-populated from terminal's zone).
   - Start time (pre-filled with current timestamp; editable backward within a reasonable window).
   - Reason picker — filtered to DowntimeReasonCodes whose `Area` matches this machine's parent Area.
   - Setup sub-form: if selected reason's `DowntimeReasonType='Setup'`, a `ShotCount` input appears (UJ-14).
   - Notes textarea.
2. He selects `EQ-DIE-STICK`, notes "die fouled", submits. Perspective calls `DowntimeEvent_Start`:

```
Oee.DowntimeEvent_Start(
    @LocationId, @DowntimeSourceCodeId=Manual, @DowntimeReasonCodeId,
    @ShotCount NULL, @StartedAt, @Remarks,
    @AppUserId, @TerminalLocationId)
```

3. Proc validates:
   - `Location` exists and is a Machine-type.
   - B3: no open DowntimeEvent already exists for this Location.
   - If reason provided, reason's Area matches machine's Area.
4. Insert row with `EndedAt NULL`, audit as `DowntimeStarted`.

### Ending downtime

At 6:57am Carlos clears the die. Taps "End Downtime" (same panel).

1. Confirmation modal: "End downtime EQ-DIE-STICK at 06:57? Notes?"
2. Submit. Perspective calls `DowntimeEvent_End(@DowntimeEventId, @EndedAt, @Remarks, @AppUserId, @TerminalLocationId)`.
3. Proc validates: event exists and is open; `@EndedAt > @StartedAt`.
4. If the active reason type = `Setup` and ShotCount was not captured, Perspective may prompt for ShotCount now (UJ-14).
5. Update `EndedAt`, append Remarks. Audit `DowntimeEnded`.

### PLC-driven downtime

The PLC on a machine exposes a `MachineStopped` tag. A per-machine Gateway script watches the edge.

1. Gateway `DowntimePlcWatcher` detects `MachineStopped=1`.
2. Calls `DowntimeEvent_Start(@LocationId, @DowntimeSourceCodeId=PLC, @DowntimeReasonCodeId=NULL, ...)` — reason NULL per B7 (late-binding).
3. Insert event. Audit.
4. Operator sees the event on their screen with a "Classify" button.
5. When operator selects a reason and submits: Perspective calls `DowntimeReasonCode_Assign(@DowntimeEventId, @DowntimeReasonCodeId, @ShotCount NULL, @AppUserId, @TerminalLocationId)`. Proc validates reason not already assigned; updates the row; audit.
6. On `MachineStopped=0` edge: Gateway calls `DowntimeEvent_End`. Reason may still be NULL — that's allowed per B7.

### Shift boundary carryover

At shift boundary (e.g., 14:00 Mon–Fri), the `ShiftBoundaryTicker` (Phase 1) fires. Per Phase 0's UJ-10 rule, one of these behaviors applies:

- **Close open downtimes at shift end.** Any open `DowntimeEvent` rows have `EndedAt = shift's ActualEnd` written; new events started for the new shift if the machine is still down (the PLC watcher will restart on the next edge).
- **Carry open downtimes across.** Open `DowntimeEvent` rows stay open. When they eventually end, they may span shift boundaries. OEE calculation (FUTURE) would proration by shift.
- **Hybrid — open downtime associated with the starting shift.** Assign `ShiftId` on the DowntimeEvent when started; reports group by ShiftId regardless of clock time.

Phase 0 chooses. Plan text codifies. Phase 8 delivers the behavior the chosen rule specifies.

### Warm-up / setup shot capture

Setup-type downtime (tooling changeover) involves warm-up shots. Per UJ-14:

1. When starting a Setup-type downtime, the operator may capture the initial `ShotCount` (or 0).
2. Warm-up shots run during downtime. They're captured separately from production shots — either as `ProductionEventValue.WarmupShotCount` on the associated Die Cast template (Phase 3 provides the field), or as an incremented counter on the open DowntimeEvent.
3. When ending the Setup downtime, the final `ShotCount` is recorded on the DowntimeEvent. Good production shots that follow are written via normal `ProductionEvent_Record` calls.

### Supervisor dashboard

`Supervisor Dashboard` view shows per-location per-shift:

- Open downtime events.
- Unclassified (reason NULL) downtime events.
- Total downtime duration in current shift.
- Production event count and piece count totals.

Drill-down from dashboard opens event lists for export / review. (Full OEE calculations are FUTURE — this dashboard is the MVP approximation.)

## API Layer

| Procedure | Parameters | Notes | Dependencies | Executed When | Output |
|---|---|---|---|---|---|
| `Oee.DowntimeEvent_Start` | `@LocationId`, `@DowntimeSourceCodeId`, `@DowntimeReasonCodeId NULL`, `@ShotCount NULL`, `@StartedAt DATETIME2(3)`, `@Remarks NULL`, `@AppUserId`, `@TerminalLocationId` | Creates open event. B3 invariant: one open per Location. | `Oee.DowntimeEvent`, `Oee.DowntimeSourceCode`, `Oee.DowntimeReasonCode`, `Oee.Shift`, `Audit.Audit_LogOperation` | Manual operator, PLC edge | `Status, Message, NewId` |
| `Oee.DowntimeEvent_End` | `@DowntimeEventId`, `@EndedAt DATETIME2(3)`, `@ShotCount NULL`, `@Remarks NULL`, `@AppUserId`, `@TerminalLocationId` | Closes open event. Validates > StartedAt. | `Oee.DowntimeEvent`, `Audit.Audit_LogOperation` | Operator or PLC | `Status, Message` |
| `Oee.DowntimeReasonCode_Assign` | `@DowntimeEventId`, `@DowntimeReasonCodeId`, `@ShotCount NULL`, `@AppUserId`, `@TerminalLocationId` | Late-binding reason. Refuses to overwrite an assigned reason. Validates reason's Area matches Location's Area. | `Oee.DowntimeEvent`, `Oee.DowntimeReasonCode`, `Audit.Audit_LogOperation` | Operator or supervisor classifying | `Status, Message` |
| `Oee.DowntimeEvent_List` | `@LocationId NULL`, `@ShiftId NULL`, `@IsOpen BIT NULL`, `@DateFrom NULL`, `@DateTo NULL`, `@IsUnclassified BIT NULL` | Read proc with filters. | `Oee.DowntimeEvent`, `Oee.DowntimeReasonCode` | Supervisor dashboard, reports | Rowset |
| `Oee.DowntimeEvent_Get` | `@DowntimeEventId` | Single row. | `Oee.DowntimeEvent` | Event detail drill-down | Single row |
| `Oee.DowntimeEvent_CarryAcrossShift` | `@OutgoingShiftId`, `@IncomingShiftId`, `@CarryoverRule NVARCHAR(50)` | Internal helper — implements Phase 0 UJ-10 rule when `Shift_End` fires. Called by `Shift_End` in its expanded form (Phase 8 extends Phase 1's Shift_End). | `Oee.DowntimeEvent`, `Audit.Audit_LogOperation` | Internal from Shift_End | `Status, Message, CarryoverCount INT` |

## Gateway Scripts

| Script | Purpose | Trigger | External System | Audit |
|---|---|---|---|---|
| `DowntimePlcWatcher` (one per machine with PLC integration) | Watches `MachineStopped` or equivalent tag; calls `DowntimeEvent_Start` on rising edge, `DowntimeEvent_End` on falling edge. | OPC tag edges | PLC (TOPServer) | `InterfaceLog` entries |
| `ShiftBoundaryTicker` (delivered Phase 1, extended here) | Phase 8 extends the Phase 1 ticker to invoke `DowntimeEvent_CarryAcrossShift` per Phase 0 rule. | 60s timer | — | `InterfaceLog` for carryover decisions |

## Perspective Views

| View | Purpose |
|---|---|
| Downtime Entry (embedded panel on station screens) | Always-visible Record Downtime / End Downtime / Classify Event actions. |
| Supervisor Dashboard | Per-machine per-shift downtime counts, durations, unclassified flags. Drill into event lists. |
| Downtime Event List | Filterable list with export. |
| Downtime Event Detail | Single event — timeline, reason, shots, remarks, edit (re-auth required). |

## Test Coverage

New test suite at `sql/tests/0020_PlantFloor_Downtime_Shift/`:

| File | Covers |
|---|---|
| `010_DowntimeEvent_Start.sql` | Creates open row; B3 rejects duplicate open; rejects if Location not a Machine; Setup type with ShotCount stored. |
| `020_DowntimeEvent_End.sql` | Closes event; rejects if EndedAt < StartedAt; rejects if already ended. |
| `030_DowntimeReasonCode_Assign.sql` | Assigns reason to unclassified event; rejects overwrite; rejects Area mismatch. |
| `040_DowntimeEvent_carryover_closeAtEnd.sql` (rule A) | Shift_End closes open events when rule = CloseAtEnd. |
| `050_DowntimeEvent_carryover_carryOpen.sql` (rule B) | Shift_End leaves open events; event can span boundary. |
| `060_DowntimeEvent_carryover_associateWithStart.sql` (rule C) | ShiftId captured at Start; never updated by boundary. |
| `070_Warmup_ShotCount_capture.sql` | UJ-14: Setup downtime event captures ShotCount; non-Setup rejects ShotCount silently (ignored or enforced NULL per design). |

Target: 60–90 passing tests in suite 0020.

## Phase 8 complete when

- [ ] Migration `0017_phase8_downtime_shift.sql` applied; LogEventType seeds present; Phase 0 carryover rule code-table (if any) seeded.
- [ ] `DowntimeEvent_Start`, `_End`, `DowntimeReasonCode_Assign`, `DowntimeEvent_CarryAcrossShift`, `_List`, `_Get` procs delivered.
- [ ] Phase 1's `ShiftBoundaryTicker` extended to call carryover helper per Phase 0 rule.
- [ ] All tests in `sql/tests/0020_PlantFloor_Downtime_Shift/` pass (target 60–90).
- [ ] Gateway `DowntimePlcWatcher` implemented against dev PLC simulator (one watcher config per machine).
- [ ] Perspective Downtime Entry panel and Supervisor Dashboard implemented.
- [ ] End-to-end: PLC simulator machine-stopped event creates an unclassified DowntimeEvent; operator classifies it; event ends on PLC edge; reports show correct shift association.

---

## Out of Scope

Explicitly excluded from this plan — handled elsewhere or deferred:

- **OEE Snapshot calculation.** `Oee.OeeSnapshot` table exists in the data model as FUTURE scope. No Phase is dedicated to it; no stored procs, no Gateway scripts. Post-MVP workstream.
- **PD Reports replacement.** The four legacy Productivity Database reports (Die Shot, Rejects, Downtime, Production) are a separate Reporting workstream driven from the data captured here. Ignition Reporting module or an equivalent tool will consume the `ProductionEvent`, `RejectEvent`, `DowntimeEvent`, and `Shift` tables directly.
- **Macola integration.** FUTURE — not in this plan.
- **Intelex integration.** FUTURE — NCM/Failure Analysis remains in Intelex separately.
- **Pixel-level Perspective mockups and Perspective JSON project exports.** Functional view descriptions only. Mockup production, if done, is a parallel workstream.
- **Bit-level OPC tag addresses and PLC ladder logic.** See `reference/5GO_AP4_Automation_Touchpoint_Agreement.pdf` and FRS Appendix C.
- **Production-grade PLC firmware changes.** Assumed complete by PLC integrator before Phase 6 commissioning.
- **Dedicated `Parts.Die` + `Parts.DieLifeEvent` tables.** Deferred unless Phase 0 escalates OI-10. Default is LocationAttribute-based shot counts.

## Open Items Affecting This Plan

| Item | Status as of 2026-04-16 | Phase affected | Resolution path |
|---|---|---|---|
| OI-06 / UJ-01 Auth & session | Pending MPP | Phase 1 | Phase 0 workshop |
| UJ-10 Shift boundary carryover | Open | Phases 1, 8 | Phase 0 workshop |
| UJ-16 HardwareInterlockBypassed scope | Pending internal + MPP | Phase 6 | Phase 0 workshop |
| UJ-05 Sort Cage serial migration | Open | Phase 7 (B10 convention) | Phase 0 workshop |
| OI-02 / UJ-13 Container closure | Open | Phase 6 | Opportunistic Phase 0; fallback in plan |
| UJ-17 Vision vs barcode | Pending internal | Phase 6 | Opportunistic Phase 0; fallback in plan |
| UJ-11 / UJ-19 Paper vs real-time, PD replacement | Open | All operator phases | Deployment rollout decision — not a design blocker |
| UJ-08 LOT merge rules | Open | Phase 2 | MVP ships hardcoded; refactor post-MVP if required |
| OI-10 Tool life tracking | Open | Phase 3 | Opportunistic Phase 0; fallback in plan |
| UJ-03 Sub-LOT split auto vs manual | Pending internal | Phase 5 | Auto with override chosen; Phase 0 confirms |

See `MPP_MES_Open_Issues_Register.docx` for full text and decision history.

## Related Documents

| Document | Relevance |
|---|---|
| `MPP_MES_SUMMARY.md` | Project index, scope matrix overview |
| `MPP_MES_DATA_MODEL.md` (v1.5) | Every table referenced in this plan |
| `MPP_MES_FDS.md` (v0.7) | Functional Design Specification — FDS-03-017a, FDS-11-011, all others referenced |
| `MPP_MES_USER_JOURNEYS.md` (v0.5) | Arc 2 narrative — this plan is the execution map for the Arc 2 journey |
| `MPP_MES_ERD.html` | Visual ERD — confirm FK linkages |
| `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md` (v1.6) | Arc 1 plan — the predecessor and the source of Cross-Cutting Concerns and the Stored Procedure Template |
| `MPP_MES_Open_Issues_Register.docx` | Open items tracking |
| `sql_best_practices_mes.md` | SQL conventions |
| `sql_version_control_guide.md` | Migration + reset workflow |
| `reference/5GO_AP4_Automation_Touchpoint_Agreement.pdf` | PLC/MIP bit-level protocol |
| `reference/MPP_FRS_Draft.pdf` | Source FRS, Appendix C (OPC tags) and Appendix L (AIM methods) especially |
| `docs/superpowers/specs/2026-04-16-arc2-phased-plan-design.md` | Design spec for this plan |







