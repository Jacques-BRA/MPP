# Arc 2 (Plant Floor MES) Phased Plan — Design Spec

**Project:** MPP MES Replacement
**Document purpose:** Brief for writing `MPP_MES_PHASED_PLAN_PLANT_FLOOR.md` — the Arc 2 delivery plan parallel to the completed Arc 1 Configuration Tool plan.
**Date:** 2026-04-16
**Status:** Brainstormed and agreed; ready to feed into the `writing-plans` skill.

---

## 1. Intent

Produce a phased delivery plan for Arc 2 (Plant Floor MES) that mirrors the Arc 1 Configuration Tool plan in structure, conventions, and rigor, while accommodating the distinct characteristics of plant-floor work: real-time operator interaction, PLC/OPC tag handshakes, external system integrations (AIM, Zebra printers, OmniServer scales, TOPServer), Gateway scripts, and richer state-management demands.

The plan document itself — `MPP_MES_PHASED_PLAN_PLANT_FLOOR.md` — is the deliverable of the next step (writing-plans skill). This spec defines what that plan should look like, phase-by-phase scope, and the conventions it will codify.

## 2. Scope of the Plan Document

**In scope:**

- SQL migrations and stored procedures for Arc 2 tables (most tables already defined in data model v1.5; stored procs and minor column additions are TODO).
- Test suites covering every new proc.
- Ignition Perspective views described at **functional level** (purpose, audience, one-liner description) — no wireframes, no Perspective JSON.
- Ignition Gateway scripts (AIM integration, PLC tag watchers, shift-boundary ticks, print-job dispatchers) with name, purpose, trigger, and external system contract.
- PLC/OPC touchpoints described **descriptively** ("reads `PartSN` tag from MIP, writes `PartValid` back; handles `HardwareInterlockEnable=false` by accepting `PartSN='NoRead'`") — **not** bit-level addresses or register maps. Bit-level detail stays in `5GO_AP4_Automation_Touchpoint_Agreement.pdf` and FRS Appendix C.
- External integrations: AIM HTTP/SOAP calls, Zebra ZPL print jobs, scale tag reads. Documented by contract, logged via `Audit.Audit_LogInterface`.

**Out of scope for this plan (deferred to separate workstreams):**

- OEE Snapshot calculation (FUTURE — not represented in this plan).
- PD Reports replacement (Die Shot, Rejects, Downtime, Production — UJ-19 concern; handled as a parallel Reporting workstream).
- Macola and Intelex integrations (FUTURE).
- Actual Ignition Perspective JSON project exports, pixel-level mockups.
- Bit-level OPC tag addresses and PLC register maps.

## 3. Document Structure

The plan file `MPP_MES_PHASED_PLAN_PLANT_FLOOR.md` lives at the repo root as a sibling to `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md`. A Word companion is produced via the same pandoc + `style_docx_tables.js` pipeline.

Top-level chapters (mirrors Arc 1 plan):

1. Header block — title, ID, project, version, date
2. **Revision History** table — living doc
3. **Purpose** — positions this as Arc 2 (Plant Floor), parallel to completed Arc 1 Config Tool plan; names audience (operators, supervisors, quality, shipping) vs. Arc 1's (engineers, IT, production control)
4. **Architecture Pattern** — Ignition Perspective + Gateway Scripts + SQL procs composition on the floor. Contrasts with Arc 1 (CRUD-over-procs). Adds Gateway Scripts as a first-class layer for PLC tag watchers, AIM calls, timers, and Zebra print jobs.
5. **Cross-Cutting Concerns** — Arc 1's rules inherited verbatim; Arc 2 additions (Section 5 below) appended.
6. **Stored Procedure Template & Conventions** — references Arc 1 plan's section by link; no duplication. Notes any Arc 2-specific deltas (expected: none — same template).
7. **Phase Map & Dependencies** — ASCII graph showing Phase 0 gate → Phase 1 foundation → fan-out to Phases 2–7 workflow phases, with Phase 8 (Downtime + Shift) as a parallel track branching off Phase 1.
8. **Phase 0 through Phase 8** — each phase section follows the phase template (Section 4 below).
9. **Out of Scope** — explicit deferrals (OEE Snapshot, PD Reports replacement, Macola/Intelex, bit-level OPC protocol).
10. **Open Items Affecting This Plan** — rolled up, linked to Open Issues Register.
11. **Related Documents** — User Journeys, Data Model, FDS, Arc 1 Plan, touchpoint agreement, seed CSVs.

## 4. Phase Template

Every phase section follows this internal structure:

1. **Goal** — one sentence
2. **Dependencies** — prior phases + external prerequisites
3. **Data Model Changes** — new columns/tables (expected to be small; most Arc 2 tables exist)
4. **Open Items Affecting This Phase** — inline callouts with working-assumption text (fallback behavior if blocker not resolved before phase starts)
5. **State & Workflow** — narrative walkthrough of every operator interaction in the phase, covering:
   - State transitions (e.g., `Lot.LotStatusId` Good → Hold; `Container.ContainerStatusId` Open → Complete → Shipped)
   - Write sequence — which procs fire in which order, which tables get written
   - Validation gates — what blocks and when (`BlocksProduction` interlock, eligibility check, already-on-hold guard)
   - Cascade effects — e.g., "hold placement → `HoldEvent_Place` → calls `Lot_UpdateStatus` → writes `LotStatusHistory` → logs `OperationLog` → if container contains this LOT, Gateway script calls AIM `PlaceOnHold`"
   - Error paths and recovery
   This is the richest section of each phase — where the business logic lives.
6. **API Layer** — stored procs in Arc 1's 6-column table: Procedure / Parameters / Notes / Dependencies / Executed When / Output
7. **Gateway Scripts** — name, purpose, trigger, external system contract, audit calls
8. **Perspective Views** — functional one-liners (no wireframes, no JSON)
9. **Test Coverage** — scenarios covered, rough count target
10. **Acceptance Criteria** — completion checklist

## 5. Cross-Cutting Conventions for Arc 2

Arc 1's rules carry forward unchanged (audit streams, code-table-backed status, soft-delete, optimistic locking, no drag-drop, BIGINT/NVARCHAR, single result set per proc, RAISERROR in nested CATCH). Arc 2 adds:

**B1 — Operator session context binding.**
Every plant-floor mutation proc accepts `@AppUserId` + `@TerminalLocationId`. Procs validate both exist and are active; `FailureLog` captures the pair on any rejection. Session state (inactivity timeout, re-auth for high-security actions) is enforced at the Ignition Perspective layer, not in procs.

**B2 — BlocksProduction interlock discipline.**
Any mutation that advances a LOT (movement, production event, consumption, split/merge, container add) first calls a shared guard `Lots.Lot_AssertNotBlocked(@LotId)`. The guard inspects `Lot.LotStatusId → LotStatusCode.BlocksProduction`. Hold, Scrap, and Closed trip it. Failing the guard is a business rule violation, not an exception.

**B3 — Open-event invariant.**
`DowntimeEvent` and `HoldEvent` carry nullable `EndedAt` / `ReleasedAt`. Invariant: at most one open event per resource (one open downtime per machine, one open hold per LOT). `_Start` / `_Place` procs enforce it. Attempting a second open event on the same resource is a business rule violation with a clear message.

**B4 — Gateway script layer contract.**
Gateway scripts call procs the same way Perspective does — parameterized Named Queries. Gateway scripts do NOT execute direct DML. External I/O (AIM HTTP/SOAP, Zebra printer socket writes, OPC reads/writes via TOPServer/OmniServer) happens **only** in Gateway scripts; stored procs never leave the database. Every external call is bracketed by `Audit.Audit_LogInterface` calls (request, response, error). No outbox pattern — direct calls with full audit trail (OI-01).

**B5 — PLC descriptive boundary.**
Phase narratives describe PLC touchpoints in prose. Bit-level addresses and register maps stay in `5GO_AP4_Automation_Touchpoint_Agreement.pdf` and FRS Appendix C — referenced, not duplicated.

**B6 — Print job contract.**
ZPL generation lives in Gateway scripts (template + data returned by procs). The proc inserts the `LotLabel` / `ShippingLabel` audit row with `ZplContent` populated. Gateway script dispatches to the physical printer and captures the print-success ack back into the audit row. Void labels use `IsVoid=1` + `VoidedAt`, never delete.

**B7 — Late-binding reason codes.**
`DowntimeEvent.DowntimeReasonCodeId` may be NULL at `_Start` time when PLC detects a stop before classification. `_End` may proceed without a reason. Unclassified downtime is flagged on the shift supervisor dashboard, not blocked at proc level. `_AssignReason` proc fills it in later.

**B8 — Genealogy traversal.**
`Lots.Lot_GetGenealogyTree` uses a recursive CTE with `OPTION (MAXRECURSION 100)`. Tree depth beyond 100 returns a business rule violation with "genealogy exceeds supported depth" — real plant data never approaches this.

**B9 — Test pattern extension for open-state events.**
Arc 1's INSERT-EXEC into a temp table covers mutations. Arc 2 adds "open-state" assertions — after `_Start`, tests query the base table to assert `EndedAt IS NULL`; after `_End`, assert `EndedAt IS NOT NULL`. No schema change; documented test pattern extension.

**B10 — Serial number migration audit.**
Placeholder pending UJ-05 resolution in Phase 0. Plan commits to capturing the chosen pattern (void-and-recreate vs update-in-place with `ContainerSerialHistory` table) in the Cross-Cutting Concerns section before Phase 6 (Assembly) starts.

**B11 — Zone-based default screen routing.**
On Perspective session startup, the session's client IP resolves to a Terminal-type `Location` via the existing `IpAddress` `LocationAttribute`. The Terminal's zone (its parent Area, resolved via the Location hierarchy) plus a new `DefaultScreen` `LocationAttributeDefinition` on the `Terminal` `LocationTypeDefinition` drives the initial Perspective view shown to any operator who logs in there. A Trim Shop terminal opens to the Trim Station Screen; a Shipping Dock terminal opens to the Shipping Screen. Login itself (clock# + PIN) is orthogonal — the default-screen lookup happens alongside (or, per Phase 0's auth decision, before) auth. No DDL change; `DefaultScreen` is seeded as a new `LocationAttributeDefinition` through Arc 1's Config Tool (or a migration row). Phase 1 delivers `Location.Terminal_GetByIpAddress` proc plus the `Terminal_ResolveFromSession` Gateway script that stashes zone + default-screen in session props.

## 6. Phase List (Approach 1 — 9 phases)

**Phase 0 — Customer Validation Gate.** No code. Resolves structural blockers: OI-06 (auth + session model + inactivity + re-auth), UJ-10 (shift boundary carryover rules), UJ-16 (`HardwareInterlockBypassed` flag location — `ContainerSerial` / `ProductionEvent` / both), UJ-05 (sort cage serial migration — void-recreate vs update-in-place + `ContainerSerialHistory` yes/no). Lower-priority items (OI-02 closure, UJ-17 vision, UJ-11/UJ-19 paper-vs-real-time commitment) attempted opportunistically. Output: decision log appended to Open Issues Register; any schema deltas feed the next migration. Artifacts: facilitator deck, decision log, MPP sign-off.

**Phase 1 — Shop Floor Foundation.** Terminal session (AD-backed clock# + PIN, inactivity timeout, easy-logout, re-auth for high-security actions), terminal-scan binding (OI-08 — shared terminals), IP-based zone resolution and default screen routing (B11). Shift runtime: `Shift_Start`, `Shift_End`, `Shift_GetActive` (resolver queries `ShiftSchedule.DaysOfWeekBitmask` against current time). LOT core skeleton: `Lot_Create`, `Lot_Get`, `Lot_List`, minimal `Lot_UpdateStatus`, `Lot_MoveTo` — the bare surface downstream phases bolt onto. Common `Audit.Audit_LogOperation` contract for all subsequent plant-floor procs. Perspective: Login, Terminal Selector, Home router. Gateway: AD auth resolver, session timer, shift-boundary tick, `Terminal_ResolveFromSession`. Depends on Phase 0 decisions.

**Phase 2 — LOT Lifecycle Completion.** Full LOT surface: `Lot_Update`, `Lot_UpdateStatus` with `LotStatusHistory` append, `Lot_MoveTo` with `LotMovement` append, `Lot_UpdateAttribute` with `LotAttributeChange` append. Genealogy: `LotGenealogy_RecordSplit`/`_RecordMerge`/`_RecordConsumption`; `Lot_GetGenealogyTree` (recursive CTE, MAXRECURSION 100); `_GetParents`/`_GetChildren` for one-hop. Labels: `LotLabel_Print` + `LotLabel_Reprint` with `PrintReasonCode`. Perspective: LOT search + detail, genealogy tree viewer, reprint dialog. Gateway: Zebra ZPL LTT dispatcher. Depends on Phase 1.

**Phase 3 — Die Cast Operator Station.** First end-to-end producer: scan fresh LTT → `Lot_Create` (MANUFACTURED origin, `LotName`=LTT barcode) → form captures die/cavity/part/shot counts/weight → `ProductionEvent_Record` writes hot columns + `ProductionEventValue` children per `OperationTemplateField` config (implements FDS-03-017a) → `RejectEvent_Record` for NG pieces with defect code → `LotLabel_Print` fires ZPL. State & Workflow narrates eligibility check (part on machine), barcode uniqueness, reasonability, user-permit. Perspective: Die Cast LOT Entry (scanner-driven touch layout), reject entry. Gateway: ZPL dispatcher (reused), optional PLC shot-count reader (descriptive). Inline: OI-10 tool life (if resolved early, add shot-count attribute updates). Depends on Phases 1–2.

**Phase 4 — Movement + Trim + Receiving.** Composite phase sharing the scan-and-adjust pattern. Movement: `Lot_MoveTo` from any station's scan screen. Trim: weight→piece-count helper (`Item.UnitWeight`), `LotAttributeChange` records delta, `ProductionEvent` captures weight + derived count. Receiving: `Lot_CreateReceived` (RECEIVED origin, vendor lot number, MinSerial/MaxSerial, bulk count), off-site via same proc over VPN (UJ-06 resolved). Perspective: generic Movement Scan Screen (reusable), Trim Station Screen, Receiving Dock Screen. Gateway: OmniServer scale tag read (descriptive), optional PLC cycle reader at Trim. Depends on Phases 1–3.

**Phase 5 — Machining with Sub-LOT Split.** Two-touch IN/OUT workflow. IN: scan parent LTT → movement + event start marker. OUT: `Lot_Split` auto-creates N child LOTs at `Item.DefaultSubLotQty`, writes SPLIT `LotGenealogy` rows, transitions parent to CLOSED via `Lot_UpdateStatus`, prints child LTTs. Auto-split confirmation allows quantity override or cancel (UJ-03 — auto with override, Phase 0 gate). FIFO queue: `Lot_GetWipQueueByLocation` ordered by arrival; operator override allowed (FRS 2.2.4). `RejectEvent` at OOT pieces. Perspective: Machining IN, Machining OUT with split confirmation. Gateway: optional PLC cycle reader. Depends on Phases 1–3.

**Phase 6 — Assembly + MIP + Container Pack.** Biggest integration phase. `ConsumptionEvent_Record` links source LOT(s) → produced serial/container piece, with material verification against active `Bom` version (UJ-09 fallback: BOM-based). `SerializedPart_Create` captures laser-etched serials. `Container_Create` at line start; `ContainerTray_Add` as trays fill; `ContainerSerial_Add` places each serial; `Container_Complete` when full → Gateway calls AIM `GetNextNumber` → writes `AimShipperId`. MIP handshake: Gateway watches `DataReady=1`, reads `PartSN`, calls `SerializedPart_Validate`, writes `PartValid=1`. `HardwareInterlockEnable=false` path accepts `PartSN='NoRead'`, sets `HardwareInterlockBypassed=1` per Phase 0 (UJ-16) decision. Inline: OI-02 scale-driven closure (fallback: count-based unless `ContainerConfig.ClosureMethod='Weight'`), UJ-17 vision conflict (fallback: auto-hold + supervisor override per OI-04). Non-serialized lines use `ContainerName` + count-based closure path. Perspective: Assembly Operator Screen with real-time MIP status, container fill indicator, BOM verification. Gateway: MIP watcher, AIM `GetNextNumber`, ZPL shipping label dispatcher. Depends on Phases 1–5.

**Phase 7 — Hold + Sort Cage + Shipping + AIM.** Quality supervisor + shipping + primary downstream AIM. `HoldEvent_Place` (HoldTypeCode: Quality, CustomerComplaint, Precautionary) trips `Lot_UpdateStatus → Hold` (BlocksProduction=1). Multi-LOT hold supported. Container hold: `Container_UpdateStatus → Hold` + Gateway AIM `PlaceOnHold`. Sort Cage: open container, part-by-part disposition, re-container workflow. Serial migration (per FRS 2.1.10, 2.2.7) uses the pattern chosen in Phase 0 (UJ-05). `ShippingLabel_Void` + AIM cancel for old shipper IDs; new `ShippingLabel_Print` for new containers. `HoldEvent_Release` flips LOT status back; Gateway AIM `ReleaseFromHold`. Shipping: `Container_Ship` gate (Complete, not Hold, AimShipperId present), dock scan, Shipped location move, truck manifest. Perspective: Hold Management (multi-select + search), Sort Cage Workflow, Shipping Dock, Manifest viewer. Gateway: AIM `PlaceOnHold`/`ReleaseFromHold`/`UpdateAim(serial, previousSerial)`, `GetNextNumber` if deferred, manifest print. Depends on Phases 1–3, 6.

**Phase 8 — Downtime + Shift Boundary (parallel track to 3–7).** Builds from Phase 1 foundation; does not block workflow phases. `DowntimeEvent_Start`/`_End` — manual (operator) and PLC-driven (Gateway watches machine status tag); `DowntimeSourceCode` = Manual or PLC. Late-binding `DowntimeReasonCode_Assign` — reason nullable at start, filled later; unclassified downtime surfaces on supervisor dashboard. Warm-up shots (UJ-14): `DowntimeEvent.ShotCount` captured when `DowntimeReasonType=Setup`. Shift boundary: Gateway tick at schedule boundary calls `Shift_End` then `Shift_Start`; open downtime carries across per Phase 0 (UJ-10) rule. Perspective: Downtime Entry (quick scan + reason picker), Supervisor Dashboard (open downtimes, unclassified, shift totals). Gateway: per-machine PLC downtime watcher, shift-boundary scheduler. Depends on Phase 1 only.

## 7. Dependency Map

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

**Direct dependencies:**

| Phase | Directly depends on |
|---|---|
| 0 | — |
| 1 | 0 |
| 2 | 1 |
| 3 | 1, 2 |
| 4 | 1, 2, 3 |
| 5 | 1, 2, 3 |
| 6 | 1, 2, 3, 4, 5 |
| 7 | 1, 2, 3, 6 |
| 8 | 1 (parallel to 2–7) |

## 8. Non-Goals

Explicitly excluded from the plan document:

- OEE Snapshot calculation — deferred; not represented as a phase.
- PD Reports replacement (Die Shot, Rejects, Downtime, Production) — separate Reporting workstream.
- Macola and Intelex integrations — FUTURE.
- Pixel-level Perspective mockups and Perspective JSON project exports.
- Bit-level OPC tag addresses, register maps, PLC ladder logic.
- Production-grade PLC firmware for machines that don't yet have MES-compatible interfaces.

## 9. Success Criteria for the Plan Document

1. Another engineer can read the plan and start implementing any phase without needing the original author present.
2. Every operator interaction on the plant floor (per User Journeys Arc 2) is covered by at least one phase's State & Workflow narrative.
3. Every Arc 2 data-model table has at least one owning phase responsible for its mutation surface.
4. Every Open Item affecting plant-floor work is either gated in Phase 0 or has an inline fallback-assumption callout in its affected phase.
5. The plan document mirrors Arc 1's structure closely enough that a reader familiar with the Arc 1 plan feels immediate continuity.

## 10. Next Step

After user review and approval of this spec, invoke the `superpowers:writing-plans` skill to produce `MPP_MES_PHASED_PLAN_PLANT_FLOOR.md` itself.

---

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 0.1 | 2026-04-16 | Blue Ridge Automation | Initial design spec — scope, structure, phase template, cross-cutting conventions, 9-phase list, dependency map. |
