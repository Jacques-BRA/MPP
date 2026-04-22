# 2026-04-20 MPP OI Review — Internal Status Summary

**Document:** MPP-MES-STATUS-2026-04-22
**Version:** 1.1
**Date:** 2026-04-22
**Prepared By:** Blue Ridge Automation
**Audience:** Internal Blue Ridge status meeting

Summary of changes from the 2026-04-20 MPP customer review, framed in terms of complexity impact and new work required. Companion to `Meeting_Notes/2026-04-20_OI_Review.md` (raw notes) and `MPP_MES_Open_Issues_Register.md` (v2.4 register).

---

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 1.0 | 2026-04-22 | Blue Ridge Automation | Initial internal status summary following 2026-04-20 MPP OI Review meeting. Captures scope shifts, new items, phase progress, blockers, and risks. |
| 1.1 | 2026-04-22 | Blue Ridge Automation | Added "Additional discovered gaps" section following 2026-04-22 review of `reference/MPP_Current_MES_screenshots.docx` (36 screenshots). Enumerates 9 concrete design additions + 7 discovery items now logged as OI-15 through OI-30 in the Open Issues Register v2.5. |

---

## Headline

The 2026-04-20 customer review closed 2 items, revised 6, reopened 2 with addenda, added 4 new items, and **promoted Tool Management from a single data-model attribute to a first-class subsystem**. Net effect: 4 of 7 planned refactor phases are already done; the remaining work is scoped but front-loaded with one large SQL migration.

---

## Scope shifts ranked by complexity impact

### Large — Tool Management (OI-10 → Phase B spec, Phase G SQL)

- **Before:** Tool was a single `LocationAttribute` carrying a die identifier.
- **After:** New `Tools` schema (10 tables): `Tool`, `ToolCavity`, `ToolAssignment` (check-in/out), `ToolAttribute`, two status code tables, `DieRank` + `DieRankCompatibility` matrix, polymorphic `ToolType`.
- **Why it matters:** Ripples into OI-05 (merge rules reference rank compatibility), OI-07 (Maintenance WOs target a Tool), and the sublot workflow (per-cavity lots). Design spec **already approved** (commit `47ce9c7`). SQL delivery is Phase G — est. ~35 procs + ~60 tests in a new migration `0010_phase9_tools_and_workorder.sql`.

### Large — Operator identity rewrite (OI-06, Phase C)

- **Before:** Clock number + PIN shop-floor login with session-sticky elevation.
- **After:** Initials-only presence (no login), per-action AD re-prompt for elevated actions, dedicated vs shared terminal modes, 30-min idle re-confirm.
- **Status:** **Already delivered** (commit `dbeac08`). Schema cleanup (drop `ClockNumber`/`PinHash`) deferred to Phase G — migration drops both columns in the same file that creates Tools.
- **Still open:** Tom owes final elevated-action list.

### Medium — Three Work Order types (OI-07)

- **Before:** Single "WO" concept, MVP-lite invisible-to-operators.
- **After:** `Demand` / `Maintenance` / `Recipe` types. Demand is as-designed. `Maintenance` WO targets a `ToolId` (schema hook only, flow is FUTURE). `Recipe` hidden from operator.
- **Impact:** Minor schema change (`Workorder.WorkOrderType` code table + nullable `ToolId`). Bigger unknown is Maintenance lifecycle — **Ben owes scope** before Phase G can close.

### Medium — LOT merge rules (OI-05)

- **Before:** Business rules undefined.
- **After:** Post-sort only, same part, cross-die allowed only when ranks are compatible (with supervisor AD override), FIFO-by-cavity on machining, quality-status gating with no override.
- **Impact:** Merge validation procedure couples to `Tools.DieRankCompatibility`. **MPP Quality still owes the full rank compatibility matrix** — the table is seeded empty with reject-with-override as the fallback.

### Medium — Vision conflict / CRT workflow (OI-04)

- **Before:** Proposed auto-LOT-hold + supervisor override.
- **After:** **Line-stop** (not LOT hold). 10-consecutive-fail escalation with configurable threshold. Branch by failure type (wrong-part → leader flag; wrong-orientation → no escalation). New `Lots.Lot.CrtActive` flag for 200% inspect workflow.
- **Impact:** Requires a new escalation-state model but no invasive schema churn. Delivered as part of Phase D FDS rewrite.

### Small — Sublots (OI-09 addenda)

- **Before:** "One part at a time" — assumed simple.
- **After:** Per-cavity concurrent sublots from a parent lot, each with its own label carrying a parent reference.
- **Impact:** Existing `Lots.Lot.ParentLotId` adjacency list already supports this. Work is primarily label design + sublot-aware scan flows.

### Small — Terminal modes (OI-08 addenda)

- **Before:** Shared terminals with machine-scan-first.
- **After:** 80% dedicated / 20% shared via `TerminalMode` LocationAttribute; terminal locked to machine context; tablets for casting (mobile design input); Honda RFID flagged FUTURE.
- **Impact:** Minor FDS §2.5 addenda, no schema changes beyond attribute seed rows.

### Resolved / simplification — Shift runtime (OI-03)

- **Before:** Debate over how to capture lunch/break/OT adjustments on paper forms.
- **After:** MES captures events + durations only, **never minute adjustments**. Runtime derives from events. Shift schedule imports from MPP's spreadsheet.
- **Impact:** Simpler than the original proposal. Phase 8 SQL already supports this.

---

## Four new items surfaced (previously unknown)

| OI | Priority | Complexity | Notes |
|---|---|---|---|
| OI-11 — Part rename Casting → Trim | MEDIUM | Medium — needs new `Parts.ItemTransform` table | Genealogy bridge across the rename boundary |
| OI-12 — Lineside inventory caps | MEDIUM | Small — `MaxParts` on ContainerConfig + `LinesideLimit` LocationAttribute | Prevents scan-in gaming |
| OI-13 — BOM source system | HIGH | Medium — one-shot export from Flexware (IP .919) at cutover | Need export format from MPP IT |
| OI-14 — Admin remove-item | LOW | Small — already in FDS-04-007 elevated actions list | Design + proc only |

---

## Work done vs. work remaining (the 7-phase refactor plan)

| Phase | Scope | Status |
|---|---|---|
| C — Security rewrite | OI-06: initials-only identity, AD elevation | Done (`dbeac08`) |
| A — OI register refresh | v2.4, rebuilt as sectioned markdown | Done (`1e68426`) |
| B — Tool Mgmt design spec | 10-table Tools schema, data-model v1.7 | Done (`47ce9c7` + `b3893d5`) |
| D — Remaining FDS rewrites | §§2.5, 5.4, 5.5, 6.10, 9.4, 10.3 | Done (`b3893d5`) |
| E — Cross-cutting OI-11..14 | Part rename, lineside caps, BOM import, admin delete | Queued (design + doc only) |
| F — Regenerate derived artifacts | ERD, Word docs, SUMMARY index refresh | Queued (housekeeping) |
| G — SQL Phase 9 | `0010_phase9_tools_and_workorder.sql` + ~35 procs + ~60 tests | Queued (largest remaining chunk) |

**Takeaway for the status meeting:** the documentation tier is ~80% through the refactor; the remaining implementation weight sits in Phase G (Tools + WorkOrderType SQL) which is a self-contained, multi-session effort.

---

## External blockers (what we can't close without)

1. **Tom (MPP security)** — final elevated-action validation pass (blocks final Phase C closeout on the FDS-04-007 list).
2. **Ben (MPP maintenance SME)** — Maintenance WO engine scope & lifecycle (blocks Phase G Maintenance flow beyond the schema hook).
3. **MPP Quality** — full die-rank compatibility matrix (Phase G seeds table empty with reject-with-override until received).
4. **MPP IT** — Flexware `.919` BOM export format (blocks OI-13 bulk-load design).
5. **MPP Production Control** — shift schedule spreadsheet template (helps Phase E but not blocking).

---

## Risk callouts

- **Phase G is the largest single piece of new SQL work since Phase 5.** Tool schema + WorkOrderType migration + procs + tests is a multi-session effort; don't underestimate. The design is locked, so it's execution risk, not design risk.
- **OI-11 (Casting → Trim rename)** was not anticipated — genealogy bridge design is net-new architectural work, not a mechanical change.
- **Die rank matrix lead time** — if MPP Quality slips on delivering the matrix, cross-die merges fall back to "always reject with supervisor override" at go-live, which may be too restrictive for the floor.

---

## Additional discovered gaps (2026-04-22 legacy screenshot review)

Source: `reference/MPP_Current_MES_screenshots.docx` — 36 screenshots of the Flexware Madison MES covering Landing, Orders, Configuration (Materials, Site, Workstations, Security), runtime Workstations (Casting, Tumbling, Sort), and Create flows. Reviewed against current FDS v0.9 + Data Model v1.7.

**Headline:** the big-ticket items (Orders, Site, Security, Casting create flow, Move Lot, Holds, Sort scan) are already covered in our design, often more rigorously (three-state BOM lifecycle, initials-based identity, Tools schema). 16 net-new items surfaced — 9 concrete additions + 7 discovery items — now logged as OI-15 through OI-30 in the Open Issues Register v2.5.

### Concrete design additions (9 items)

| OI | Priority | Gap | Proposed direction |
|---|---|---|---|
| OI-15 | HIGH | Global **Track** screen — non-workstation path to look up any LOT / serial / container and view genealogy | Dedicated Perspective home-tile screen. Honda traceability is the core mission. |
| OI-16 | MEDIUM | WO **auto-finish-on-target** semantics (camera count / scale weight target) | Extend `Workorder.ProductionEvent_Record` and §6.10 to fire WO-close when cumulative count / weight reaches WO target. |
| OI-17 | MEDIUM | **Tray-divisibility** validation on WO close (target must be evenly divisible by tray quantity) | Validate at WO Create/Edit and Close in `Workorder.WorkOrder_*`. |
| OI-18 | MEDIUM | `Parts.ItemLocation` missing **Min / Max / Default quantity + Consumption Point** | Add four columns; feeds runtime Allocations grid. Phase E design + Phase G SQL. |
| OI-19 | LOW effort / HIGH compliance | `Parts.Item.CountryOfOrigin` | Add `NVARCHAR(2) NULL` (ISO 3166-1 alpha-2). Honda genealogy output. |
| OI-20 | LOW | **Scrap source enum** (Inventory vs Location) — two distinct scrap paths | Add `ScrapSource` code table + `ScrapSourceId` on `Workorder.ProductionEvent`. |
| OI-21 | MEDIUM | **Partial start / partial complete** at a workstation (start N now, complete M later) | Verify `ProductionEvent_Record` supports decoupled Start and Complete; extend if not. |
| OI-22 | MEDIUM | Dedicated **Hold Management screen** (top-level tile in legacy) | Perspective screen listing active holds with supervisor-elevated place / release. |
| OI-23 | LOW | Lot derived **TotalInProcess / InventoryAvailable** exposed in header | Document derivation in §5; decide view-vs-materialized. |

### Discovery items to confirm with MPP (7 items)

| OI | Priority | Item | Why flag it |
|---|---|---|---|
| OI-24 | MEDIUM | **Automation** top-level tile contents unknown | Likely OPC / interface management. Need walk-through before ruling in or out. |
| OI-25 | LOW | **Notifications** configuration module | Email / alert rules. Probably out-of-MVP but confirm so it isn't a regression surprise. |
| OI-26 | LOW | Per-workstation **dashboard scripting hook** (Edit Script per save button) | Ignition Perspective handles scripting at project level — one-to-one port not idiomatic. Verify nothing load-bearing exists. |
| OI-27 | LOW | Material **Supply part** BIT purpose | Unknown. Ask MPP before ignoring. |
| OI-28 | MEDIUM | Work Cell **"Require override for cast parts"** flag | Ties to OI-04 line-stop / vision flow at cell granularity. Confirm retention. |
| OI-29 | LOW | **Workstation Category** grouping orthogonal to Area/Line | UI convenience (e.g., Sort / Shipping / Tumbling as peers of lines). Our ISA-95 hierarchy may already cover it. |
| OI-30 | MEDIUM | **Reports** tile full contents not enumerated | UJ-19 lists 4 PD reports but full menu unwalked. Avoid scope surprise at go-live. |

### Impact on plan

- Phase E (cross-cutting design) was already queued for OI-11..14; it now also carries OI-15..23 (concrete design). No new phase needed.
- Phase G (SQL migration `0010_phase9_tools_and_workorder.sql`) grows modestly — OI-18 (ItemLocation columns), OI-19 (CountryOfOrigin), OI-20 (ScrapSource) are small additive schema changes that can ride along. No additional migration file required.
- Discovery items (OI-24..30) produce one consolidated question list to bring to the next MPP review session. Three of them (OI-24, OI-28, OI-30) could reshape scope if answers come back unexpected — worth flagging on the agenda.

---

## References

- `Meeting_Notes/2026-04-20_OI_Review.md` — raw meeting notes (2026-04-20)
- `MPP_MES_Open_Issues_Register.md` — v2.5 register (OI-15..30 added 2026-04-22)
- `reference/MPP_Current_MES_screenshots.docx` — 36 legacy MES screenshots reviewed 2026-04-22
- `memory/project_mpp_oi_refactor.md` — 7-phase execution plan
- `docs/superpowers/specs/2026-04-21-tool-management-design.md` — Phase B design spec v0.2
- `MPP_MES_FDS.md` v0.9 — rewritten §§2.5, 4, 5.4, 5.5, 6.10, 9.4, 10.3
- `MPP_MES_DATA_MODEL.md` v1.7 — Tools schema + WorkOrderType
