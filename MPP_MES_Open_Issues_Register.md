# MPP MES — Open Issues Register

**Document:** FDS-MPP-MES-OIR-001
**Version:** 2.6 — Working Draft
**Date:** 2026-04-22
**Prepared By:** Blue Ridge Automation
**Prepared For:** Madison Precision Products, Inc. (Madison, IN)

This register consolidates all open items and design decisions that gate Perspective screen design and implementation. Part A holds the FDS-numbered open items (OI-01 through OI-30). Part B holds the 19 User Journey assumptions/decisions (UJ-01 through UJ-19). Cross-references between the two parts are noted per-item.

---

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 2.1 | 2026-04-06 | Blue Ridge Automation | Initial register consolidating FDS open items and User Journey assumptions |
| 2.2 | 2026-04-08 | Blue Ridge Automation | FRS reference crosswalk added per-item; priorities normalized |
| 2.3 | 2026-04-09 | Blue Ridge Automation | First round of MPP review decisions applied — OI-01, UJ-06, UJ-15 closed; 10 items moved to In Review |
| 2.4 | 2026-04-21 | Blue Ridge Automation | **Phase A of the 2026-04-20 OI review refactor.** Closed OI-03 (shift runtime derived from events) and OI-06 (initials-based operator identity — see Phase C / FDS v0.8). Revised OI-04 (line-stop, not LOT-hold; 10-fail escalation; CRT 200% inspect), OI-05 (die-rank compatibility merge rules), OI-07 (three WO types, Maintenance targets Tools), OI-08 addenda (terminal locked to machine context; part↔machine validity map; mobile consideration), OI-09 addenda (sublot pattern with parent FK), OI-10 (superseded by Phase B Tool Management design). Added four new items: OI-11 (part rename at Casting → Trim), OI-12 (lineside inventory caps), OI-13 (BOM source = Flexware app @ IP .919), OI-14 (admin remove-item). Structural change: each OI and UJ now has its own subsection instead of living inside a giant grid table — easier to read, diff, and update. Source meeting notes at `Meeting_Notes/2026-04-20_OI_Review.md`. Running plan in `memory/project_mpp_oi_refactor.md`. |
| 2.5 | 2026-04-22 | Blue Ridge Automation | **Legacy MES screenshot review gap analysis.** 36 screenshots of the Flexware Madison MES reviewed against the current FDS / Data Model. 16 new Part A items added (OI-15 through OI-30): 9 concrete design additions (Track screen, auto-finish-on-target WO, tray-divisibility rule, ItemLocation consumption metadata, Country of Origin, scrap source enum, partial start/complete, Hold Management screen, Lot computed fields) and 7 discovery items to confirm with MPP (Automation tile scope, Notifications, per-workstation scripting, Supply Part flag, cast-override cell flag, Workstation Category grouping, Reports tile contents). Source summary at `Meeting_Notes/2026-04-20_OI_Review_Status_Summary.md` §"Additional discovered gaps". Legacy screenshots at `reference/MPP_Current_MES_screenshots.docx`. |
| 2.6 | 2026-04-22 | Blue Ridge Automation | **OI-11 resolved — Casting → Trim rename modelled via 1-line BOM, not `Parts.ItemTransform`.** Review of the v2.5 design surfaced that the proposed `Parts.ItemTransform` table duplicated every column of `Workorder.ConsumptionEvent`. The rename is a degenerate 1-line BOM consumption: trim part has cast part as its sole component at QtyPer=1; existing ConsumptionEvent + LotGenealogy machinery handles the flow and the Honda backward trace. OI-11 moves ⬜ Open → ✅ Resolved. Downstream corrections: Data Model v1.8-rev (ItemTransform table section replaced with a ✅ Resolved callout; `Audit.LogEntityType` seed shrinks from 10 to 9 rows; table count "~73" → "~72"), FDS v0.10-rev (§5.10 retained, rewritten around FDS-05-033 BOM-driven scan-in; FDS-05-034/-035 retired), User Journeys v0.7-rev (Trim Shop narrative simplified to normal consumption), Phase G migration `0010_phase9_tools_and_workorder.sql` (ItemTransform LogEntityType row dropped; ScrapSource shifted from Id=40 to Id=39; re-run green, 779/779 tests still pass). |

---

## Summary

**Part A counts (30 items):**

| Priority | ✅ Resolved | 🔶 In Review | ⬜ Open | Superseded | **Total** |
|---|---|---|---|---|---|
| HIGH | 1 (OI-01) | 3 (OI-02, OI-05, OI-07) | 2 (OI-13, OI-15) | 0 | **6** |
| MEDIUM | 4 (OI-03, OI-06, OI-09, OI-11) | 3 (OI-04, OI-08, OI-12) | 8 (OI-16, OI-17, OI-18, OI-21, OI-22, OI-24, OI-28, OI-30) | 0 | **15** |
| LOW | 0 | 0 | 8 (OI-14, OI-19, OI-20, OI-23, OI-25, OI-26, OI-27, OI-29) | 0 | **8** |
| — | 0 | 0 | 0 | 1 (OI-10) | **1** |
| **Total** | **5** | **6** | **18** | **1** | **30** |

**Part B counts (19 items):**

| Priority | ✅ Resolved | 🔶 In Review | ⬜ Open | **Total** |
|---|---|---|---|---|
| HIGH | 1 (UJ-01) | 0 | 6 (UJ-04, UJ-07, UJ-08, UJ-11, UJ-13, UJ-18, UJ-19) | **7** |
| MEDIUM | 2 (UJ-12, UJ-15) | 3 (UJ-02, UJ-03, UJ-14) | 6 (UJ-05, UJ-09, UJ-10, UJ-16, UJ-17) | **11** |
| LOW | 1 (UJ-06) | 0 | 0 | **1** |
| **Total** | **4** | **3** | **12** | **19** |

**Grand total:** 49 items (30 Part A + 19 Part B). 9 resolved, 9 in review, 30 open, 1 superseded.

---

# Part A — FDS Open Items

These items are called out inline in the FDS with `> **RESOLVED**` / `> **PENDING CUSTOMER VALIDATION**` / `> **OPEN**` callouts. Each requires a decision before its FDS section can be finalised.

---

### OI-01 — Event outbox dispatch pattern — ✅ Resolved

**Priority:** HIGH
**Owner:** Blue Ridge / MPP IT
**FDS §:** 1.6
**References:** FDS-01-006; FRS 3.17.4; FRS 5.5.1; Spark Dep. B.12

**Description:** SQL event outbox table vs. Ignition application-layer dispatch for external calls (AIM, printers, etc.).

**Options considered:**
- (a) SQL event outbox table in the Audit schema — persisted, survives restarts, queryable.
- (b) Ignition Gateway Scheduled Scripts / tag-based queuing — simpler, but queue state lives in memory / tags.

**Decision (2026-04-09):** Ignition application layer. Direct calls with an `Audit.InterfaceLog` write on every request and response — no outbox table. Removes a whole pattern from the FDS and keeps the dispatch flow in one place.

---

### OI-02 — Weight-based container closure — 🔶 In Review

**Priority:** HIGH
**Owner:** Blue Ridge / MPP Engineering
**FDS §:** 6.6
**References:** FDS-06-014, FDS-03-017; FRS 3.6.6, 3.9.7; Appendix C (OPC Tags: `TargetWeightValue`, `TargetWeightMetFlag`)

**Description:** On non-serialized / inspection lines, does `Parts.ContainerConfig` need a `ClosureMethod` (`BY_COUNT` vs `BY_WEIGHT`) and a `TargetWeight` field?

**Options considered:**
- (a) Add `ClosureMethod` + `TargetWeight` to `ContainerConfig`.
- (b) Weight closure handled entirely in the PLC — MES responds to a "container full" signal only.

**Proposed decision (pending customer validation):** Non-serialized lines should receive feedback from a scale. The two columns (`ClosureMethod`, `TargetWeight`) were added as nullable to `ContainerConfig` in Phase 4 pending confirmation.

---

### OI-03 — Shift runtime adjustments — ✅ Resolved (2026-04-20)

**Priority:** MEDIUM
**Owner:** MPP Production Control
**FDS §:** 9.4
**References:** FDS-09-009; FRS 3.15.2; DCFM Paper Sheets (lunch/break/OT adjustments)

**Description:** Legacy paper forms add minutes for running through lunch (+30), breaks (+10), or 10-hour overtime (+110). How are those adjustments captured in the MES?

**Options considered:**
- (a) Adjust `Oee.Shift.ActualEnd` to reflect the true end time.
- (b) Add an adjustment field to the shift record.
- (c) Derive runtime purely from downtime events (available time = shift duration − total downtime).

**Decision (2026-04-20):** Option (c). MES captures **event + duration**, never minute adjustments. Shift schedule imports from MPP's 5–6-spreadsheet rollup (customer to share the template). Shifts are Monday–Friday at fixed times; early starts automatically increase availability because events drive runtime. Operators register breaks at end of shift as a single uptime-vs-downtime categorisation — no live per-break entry. Implementation lands in Phase D (FDS §9.4 rewrite).

---

### OI-04 — Vision system conflict resolution — 🔶 In Review (revised)

**Priority:** MEDIUM
**Owner:** MPP Engineering / Quality
**FDS §:** 10.3
**References:** FDS-10-003, FDS-10-005; FRS 3.16.1, 3.16.9; Appendix C (OPC Tags: `VisionPartNumber`); FRS 2.1.8

**Description:** Cognex says part X, operator said part Y. What happens?

**Options considered:**
- (a) Block production until resolved.
- (b) Allow override with supervisor PIN.
- (c) Log discrepancy and continue.

**Revised decision (2026-04-20):** MPP pushed back on the earlier "auto-hold LOT + supervisor override" recommendation. New direction:
1. **Stop the operation/line** until the issue is rectified — do NOT place the LOT on hold.
2. **10-consecutive-fail escalation** — after 10 back-to-back failures the system escalates to a leader.
3. **Branch by failure type** — *wrong part* triggers leader flag; *wrong orientation* requires no escalation.
4. **Hold release** — Quality releases a hold; a Controlled Run Tag (CRT) requires a subsequent 200%-inspect; if the CRT run wasn't inspected when executed, material must re-run through the process.

Supervisor elevation uses the per-action AD prompt from FDS-04-007 (no PIN). Requires FDS §10.3 rewrite and a new escalation-state model. Work lands in Phase D.

---

### OI-05 — LOT merge business rules — 🔶 In Review (revised)

**Priority:** HIGH
**Owner:** MPP Production Control / Quality
**FDS §:** 5.5
**References:** FDS-05-012; FRS 3.9.13, 3.9.12, 3.13.1, 3.13.2

**Description:** What rules govern LOT merges? Same part only? Same die/cavity? Additive piece counts? Reversible?

**Revised decision (2026-04-20):** MPP provided concrete rules:
- Merges only allowed **after sort is complete**.
- Same part number, but **different dies are allowed only if die ranks are compatible** — e.g., rank A cannot be mixed; rank E can. Full compatibility matrix owed by MPP Quality.
- Machining is **FIFO by cavity**.
- An "IPP tag" is attached when a die arrives; IPP is an identifier only (details modelled as flexible Tool attributes under OI-10 → Phase B).

Implementation couples to the Phase B Tool Management design because die rank lives on the Tool / Cavity entity. Data model will grow a `Tools.DieRankCompatibility` lookup seeded from the MPP matrix. FDS §5.5 rewrite in Phase D.

---

### OI-06 — Operator identity & session model — ✅ Resolved (Phase C, 2026-04-21)

**Priority:** MEDIUM
**Owner:** MPP Operations
**FDS §:** 4 (entire)
**References:** FDS-04-001 through FDS-04-010; FRS 3.3.1, 3.3.4, 3.6.1; FRS 5.3; Spark Dep. B.8

**Description:** Session lifecycle for operators, quality, and supervisors. Badge-per-shift, badge-per-action, timeouts, re-auth triggers.

**Options considered:**
- (a) Badge once per shift — re-auth only for elevated actions.
- (b) Badge per transaction.
- (c) Hybrid.
- (d) *(added after 2026-04-20 meeting)* Operators don't authenticate at all; initials only.

**Decision (2026-04-20, implemented 2026-04-21):** Option (d). Operators are identified by **initials** entered at a shop-floor terminal (no clock number, no PIN), which establish an operator presence context that stamps `AppUserId` on events. Interactive users (Quality, Supervisor, Engineering, Admin) continue via Active Directory. Elevated actions are per-action AD re-prompts — no session-sticky elevation, no 5-minute timeout. Dedicated vs Shared terminal modes via `LocationAttribute`. 30-minute idle re-confirmation overlay ("Operate as [XY]? Y / N — change"). Pre-populated defeasible Initials field on every mutation screen. Operator `AppUser` rows are managed in the Configuration Tool (Admin screen). Tom (MPP security SME) still owes a final review of the elevated-action list (see FDS-04-007).

Delivered via FDS v0.8, Data Model v1.6, User Journeys v0.6, Config Tool phased plan v1.7 (commit `dbeac08`). Schema cleanup (drop legacy `ClockNumber` / `PinHash` columns) deferred to Phase G.

---

### OI-07 — Work order scope — 🔶 In Review (revised)

**Priority:** HIGH
**Owner:** MPP / Blue Ridge (Ben is SME)
**FDS §:** 6.10
**References:** FDS-06-022, FDS-06-023, FDS-06-024; FRS 3.1.5, 3.10.1, 3.10.2, 3.10.5; Spark Dep. B.5

**Description:** Include Work Orders in MVP or defer entirely? Biggest CONDITIONAL decision.

**Options considered:**
- (a) Include — auto-generated, invisible to operators.
- (b) Defer — all WO tables exist but are not populated.
- (c) MVP-lite — create WOs but no operator-facing screens.

**Revised decision (2026-04-20):** MVP-lite **with three explicit work-order types**:
- **Demand WO** — production work, auto-generated on LOT start, invisible to operators (existing MVP-lite story).
- **Maintenance WO** — **targets a Tool** (couples to Phase B Tool Management). Has its own engine per MPP; needs clarification from Ben on lifecycle, scheduling, and integration with the maintenance team's existing tooling.
- **Recipe WO** — hidden from the operator (recipe / configuration context).

Data model adds `Workorder.WorkOrderType` code table (Demand / Maintenance / Recipe) and a nullable `ToolId` FK on `Workorder.WorkOrder` to support Maintenance. Ben owes the maintenance-engine scope before Phase G (SQL) can proceed. FDS §6.10 rewrite in Phase D.

---

### OI-08 — Terminal architecture — 🔶 In Review (addenda after resolution)

**Priority:** MEDIUM
**Owner:** MPP IT / Operations
**FDS §:** 2.5
**References:** FDS-02-008, FDS-02-009; FRS 3.7.1, 3.7.2; Spark Dep. B.1; FRS Appendix B (~230 machines)

**Description:** Count of terminals (~230 1:1 with machines, or fewer shared)? If shared, how does the operator pick the active machine?

**Earlier decision (2026-04-09, retained as baseline):** Fewer shared terminals, with a machine barcode / QR scan as the first step of any interaction. `Terminal` is a `LocationTypeDefinition` under `Cell`; events carry both `TerminalLocationId` and `LocationId`.

**Addenda (2026-04-20):** MPP added more texture that needs to be folded into the design:
- **Terminal-to-cell mode.** About 80% of terminals are dedicated (1:1 with a Cell); the remaining 20% (e.g., trim shop with multiple stations on one terminal) are shared. Model this as a `LocationAttribute` on the Terminal (`TerminalMode` = `Dedicated` / `Shared`). Dedicated terminals persist the operator presence context through the shift; shared terminals prompt on first action and on machine change. Already captured in FDS §4 / Phase C.
- **Operator cannot navigate off-machine.** A terminal's machine context is locked unless the operator explicitly re-scans (force-print workflow). Not a free-for-all dropdown.
- **Part ↔ machine validity map.** Need a configurable mapping of which parts can run on which machines (extension of Phase 5's `Parts.ItemLocation` eligibility junction — likely sufficient; confirm in Phase D).
- **Tablets planned for casting.** Mobile-friendly layout is a design input, not just a nice-to-have. Affects Perspective view sizing.
- **Honda RFID on labels (future).** Honda plans RFID; the MES should not block that path. Out-of-scope for MVP but worth a forward-compatibility note in FDS §2.5.

Work lands in Phase D (FDS §2.5 addenda pass).

---

### OI-09 — Multi-part lines & sublots — 🔶 In Review (addenda after resolution)

**Priority:** MEDIUM
**Owner:** MPP Engineering
**FDS §:** 3.6, 5.4
**References:** FDS-03-016, FDS-03-017; FRS 3.9.7, 3.16.1, 3.16.2; MS1FM-1028 (multi-part line example)

**Description:** On lines that run multiple part numbers (MS1FM-1028 → 59B / 5PA / 6NA), how are containers handled? Mixed containers? Part-at-a-time?

**Earlier decision (2026-04-09, retained):** One part at a time. Operator selects the active LOT for consumption, which determines the part number. No mixed-part containers. Changeover is an operator action.

**Addenda (2026-04-20):** Meeting notes revealed a **sublot pattern** that needs explicit treatment:
- Each **cavity can produce a distinct lot simultaneously** (not contradictory to "one part at a time" because it's the same part number from different cavities).
- **Small baskets are broken down from a parent lot into sublots.** Each sublot has its own label with a parent-lot reference and persists through the process.

Schema impact: `Lots.Lot` adjacency-list parent FK likely already supports this (parent `Lot.Id` on `Lot` via `ParentLotId`), but the **label pattern** and **sublot workflows** are new — label printing and sublot-aware scan-in flows need explicit journey coverage. Work lands in Phase D (FDS §5.4 sublot addenda) and Phase E (Plant Floor phased plan sublot steps).

---

### OI-10 — Tool Life tracking — Superseded (rolled into Phase B)

**Priority:** HIGH
**Owner:** Blue Ridge / MPP Engineering
**FDS §:** 5.6 (new section in Phase B)
**References:** FRS 5.6.6, 3.14.8; Scope Matrix Row 26

**Description:** Where does Tool Life data live? Extend `LocationAttribute` vs. a dedicated table?

**Original options:**
- (a) Extend `LocationAttribute` with tool life attributes per machine.
- (b) Dedicated `ToolLife` table with shot counters, thresholds, reset events.
- (c) Hybrid — attribute for targets, event table for resets.

**Resolution path (2026-04-20):** Rolled into the **Phase B Tool Management design spec**. Tool is now a first-class subsystem: `Tools.Tool`, `Tools.ToolCavity`, die rank compatibility, check-in/out against Cells, shot counters (both materialized and event-append), maintenance WO linkage (OI-07). Six specific design questions are parked in `memory/project_mpp_tool_mgmt_design.md` awaiting Jacques's answers before the data-model work begins.

This item remains in the register for traceability but is no longer a stand-alone decision — its closure is the Phase B design spec landing.

---

### OI-11 — Part identity change at Casting → Trim Shop — ✅ Resolved (2026-04-22)

**Priority:** MEDIUM
**Owner:** MPP Engineering / Blue Ridge
**FDS §:** 5.10 (reframed around BOM-driven resolution)
**References:** Meeting notes 2026-04-20; derived from OI-05 / OI-10 context

**Description:** Per MPP, a part **changes its identity** as it moves from Casting to the Trim Shop — the part number is different on the two sides of that boundary, even though genealogy must tie them together.

**Options considered:**
- (a) Dedicated `Parts.ItemTransform` table (source Item + destination Item, with an `EventAt` and genealogy FKs).
- (b) Treat Trim as a renaming operation — add an attribute to the existing `LotGenealogy` flow.
- (c) Require BOM-driven resolution — the Trim part is a "produced from" of the Casting part.

**Decision (2026-04-22):** Option (c). Option (a) was initially chosen and drafted into Data Model v1.8 / FDS v0.10 / User Journeys v0.7; on review the `Parts.ItemTransform` table was fully redundant with `Workorder.ConsumptionEvent` — every column duplicated. The Casting → Trim boundary is a **degenerate 1-line BOM consumption**:

- Trim part's `Parts.Bom` has a single `BomLine` referencing the cast part at `QtyPer = 1`.
- At the first Trim Shop Cell, the MES uses `Parts.ItemLocation` + BOM lookup to find the destination trim part; prompts the operator to confirm receive-as; on confirm writes a normal `Workorder.ConsumptionEvent` (consumed cast / produced trim) + `Lots.LotGenealogy` row.
- Honda backward trace: same walk as any assembly consumption — shipped trim LOT → LotGenealogy → cast LOT → die / cavity / operator / timestamp.
- Yield loss (if any) handled normally via `Workorder.RejectEvent` on the source side.

**No new schema** — `Parts.ItemTransform` was removed from the v1.8 draft before any SQL landed. Affected docs updated to v1.8-rev / v0.10-rev / v0.7-rev; Phase G migration dropped the ItemTransform `Audit.LogEntityType` seed row (9 rows instead of 10; re-run green, 779/779 tests still pass).

---

### OI-12 — Lineside inventory caps — ⬜ Open (new)

**Priority:** MEDIUM
**Owner:** MPP Operations / Blue Ridge
**FDS §:** TBD (§3 addenda in Phase E)
**References:** Meeting notes 2026-04-20; FRS 3.6.6 (container config)

**Description:** Operators game the current system by scanning in a large quantity of parts-to-consume at once so they don't have to re-scan as often. MPP wants a cap:
- **Max parts per basket** (ContainerConfig-level).
- **Max lineside inventory quantity** (per Cell / workstation).

Exceeding either limit should reject the scan-in.

**Proposed direction:** Add `MaxParts INT NULL` to `Parts.ContainerConfig`. Add a `LinesideLimit` concept as a `LocationAttribute` on Cells. Validation fires in the scan-in mutation proc. Designed in Phase E, implemented in Phase G.

---

### OI-13 — BOM source system — ⬜ Open (new, HIGH)

**Priority:** HIGH
**Owner:** MPP IT / Blue Ridge
**FDS §:** 1.4 (Interfaces) / 3 (Master Data) — Phase E
**References:** Meeting notes 2026-04-20 ("BOMs are on the flexware app on 919")

**Description:** BOMs are authoritative in the legacy **Flexware application at IP `.919`** — the predecessor MES being replaced. The new MES's `Parts.Bom` seed data must come from there.

**Options:**
- (a) One-shot export from the Flexware app into a CSV / Excel file, bulk-loaded into the new MES at cutover.
- (b) Periodic re-sync from the Flexware app until MPP cuts over fully.
- (c) Live integration (ODBC / API / file drop) — unlikely to be worth it if Flexware is being retired.

**Proposed direction:** Option (a) — one-shot export at cutover. Document the export spec in FDS §1.4, add to the Reference Material list, and plan a bulk-load proc (similar to `Oee.DowntimeReasonCode_BulkLoadFromSeed`) once MPP delivers the export. Designed in Phase E; bulk-load proc in Phase G.

---

### OI-14 — Admin remove-item capability — ⬜ Open (new, LOW)

**Priority:** LOW
**Owner:** Blue Ridge
**FDS §:** 4.3 (elevated actions) + Config Tool phased plan
**References:** Meeting notes 2026-04-20

**Description:** Admin needs to be able to **remove items** (LOTs, Containers, inventory rows) directly — for cleanup, mis-entry correction, and general "oops" recovery that can't flow through normal deprecate paths.

**Proposed direction:** Admin-only Configuration Tool screen with full audit trail. Already listed in FDS-04-007 elevated-action list (Phase C). Detail design in Phase E; proc in Phase G.

---

### OI-15 — Global Trace / Track screen — ⬜ Open (new)

**Priority:** HIGH
**Owner:** Blue Ridge / MPP Operations
**FDS §:** TBD (new section in Phase E — likely §5 addendum or new §15 operator tools)
**References:** Screenshot review 2026-04-22 (`reference/MPP_Current_MES_screenshots.docx` image 1, "Track" top-level tile)

**Description:** Legacy MES has a top-level **Track** tile providing a non-workstation path to look up any LOT, serial number, or container and view its full genealogy. Our current FDS does not call out a global trace operator tool — trace today is implicit through the Lot Details screen but requires a workstation context.

**Options:**
- (a) Dedicated Perspective screen reachable from the home tile bar: input = LOT / serial / container ID, output = genealogy tree + lot details.
- (b) Rely on the Configuration Tool's Lot browser for supervisors / quality only.
- (c) Inline "search" box on the home page that drills into the Lot Details screen.

**Proposed direction:** Option (a). Honda traceability is the core mission of the project; operators, supervisors, and quality all need a zero-context lookup path. Designed in Phase E.

---

### OI-16 — Auto-finish-on-target WO semantics — ⬜ Open (new)

**Priority:** MEDIUM
**Owner:** Blue Ridge / MPP Engineering
**FDS §:** 6.10 addendum + data-collection capture contract (FDS-03-017a)
**References:** Screenshot review 2026-04-22 (image 7, Work Order "Camera system automatic processing" + "Scale system automatic processing"); FRS 3.10

**Description:** Legacy WO configuration exposes **Camera system automatic processing** (tray quantity + part recipe number) and **Scale system automatic processing** (target set quantity) with an explicit "automatically finish when target is reached" semantic. FDS-03-017a covers capturing counts and weights but does not specify the auto-close behaviour at the WO boundary.

**Proposed direction:** Extend §6.10 and `Workorder.ProductionEvent_Record` to fire a WO-close event when cumulative ProductionEvent count (camera) or cumulative weight (scale) reaches the WO target. Configurable per WO.

---

### OI-17 — Tray-divisibility validation on WO close — ⬜ Open (new)

**Priority:** MEDIUM
**Owner:** Blue Ridge
**FDS §:** 6.10
**References:** Screenshot review 2026-04-22 (image 30, "Work order target quantity exceeded. Ensure target quantity is evenly divisible by the tray quantity.")

**Description:** Legacy MES enforces a business rule at container close: target quantity must be evenly divisible by tray quantity, otherwise the container cannot be processed. Rule is not captured in the current FDS or data model.

**Proposed direction:** Validate at WO Create / Edit (target `MOD` tray = 0) and re-validate at Close. Enforced in `Workorder.WorkOrder_*` mutation procs with a specific error code.

---

### OI-18 — Parts.ItemLocation consumption metadata — ⬜ Open (new)

**Priority:** MEDIUM
**Owner:** Blue Ridge / MPP Engineering
**FDS §:** 3 (Master Data) + §5/6 consumption flows
**References:** Screenshot review 2026-04-22 (image 12, Material "Compatible work cells" table with Min Quantity / Max Quantity / Default Quantity / Consumption Point columns)

**Description:** Legacy Material → Compatible Work Cells mapping carries four extra attributes — **Min Quantity**, **Max Quantity**, **Default Quantity**, and **Consumption Point (BIT)**. These feed the runtime Allocations grid at the workstation. Our `Parts.ItemLocation` is a plain boolean eligibility junction.

**Proposed direction:** Extend `Parts.ItemLocation` with `MinQuantity INT NULL`, `MaxQuantity INT NULL`, `DefaultQuantity INT NULL`, `IsConsumptionPoint BIT NOT NULL DEFAULT 0`. Designed in Phase E; SQL in Phase G.

---

### OI-19 — Parts.Item.CountryOfOrigin — ⬜ Open (new)

**Priority:** LOW (effort) / HIGH (compliance)
**Owner:** Blue Ridge
**FDS §:** 3 (Master Data)
**References:** Screenshot review 2026-04-22 (image 13, Material configuration "Country of origin" field)

**Description:** Legacy Item carries a Country of Origin code. Honda compliance may require it on genealogy / shipping output. Not currently modelled.

**Proposed direction:** Add `CountryOfOrigin NVARCHAR(2) NULL` (ISO 3166-1 alpha-2) to `Parts.Item`. Designed in Phase E; SQL in Phase G.

---

### OI-20 — Scrap source enum (Inventory vs Location) — ⬜ Open (new)

**Priority:** LOW
**Owner:** Blue Ridge
**FDS §:** 5 + ProductionEvent spec
**References:** Screenshot review 2026-04-22 (image 31, "Scrap from inventory" vs "Scrap from the selected location" buttons on Lot Details)

**Description:** Legacy Lot Details screen exposes two distinct scrap paths: scrap from *inventory* (unallocated stock on a lot) vs scrap from a *selected location* (in-process at a specific workstation). Our current `Workorder.ProductionEvent.Type = Scrap` does not capture the distinction.

**Proposed direction:** Add a `ScrapSource` code table (Inventory / Location) and `ScrapSourceId BIGINT NULL` on `Workorder.ProductionEvent`. Designed in Phase E; SQL in Phase G.

---

### OI-21 — Partial start / partial complete at a workstation — ⬜ Open (new)

**Priority:** MEDIUM
**Owner:** Blue Ridge / Ben
**FDS §:** 5, 6
**References:** Screenshot review 2026-04-22 (image 33, Tumbling Move Lot with separate "Start lot quantity" and "Complete lot quantity" fields; "0 in inventory available to start, 11 available to complete")

**Description:** Legacy Move Lot UX allows starting N-of-M pieces now and completing the remainder later — start and complete quantities are decoupled per lot per workstation. Our current WIP model needs an explicit verification that this is supported.

**Proposed direction:** Verify and document `Workorder.ProductionEvent_Record` supports independent Start and Complete event emission with partial quantities (and correctly derives WIP via event replay). If not, extend. Designed in Phase E.

---

### OI-22 — Dedicated Hold Management screen — ⬜ Open (new)

**Priority:** MEDIUM
**Owner:** Blue Ridge / MPP Quality
**FDS §:** 5.7 (Holds)
**References:** Screenshot review 2026-04-22 (image 1, top-level "Hold" tile)

**Description:** Legacy MES gives Holds a top-level navigation tile. Our FDS §5.7 specifies the `HoldEvent` place/release lifecycle but does not explicitly mandate a dedicated Hold-management screen — it may currently be implicit via per-lot hold buttons only.

**Proposed direction:** Add a Hold Management Perspective screen: list of all active holds, filterable by area / line / lot / hold reason, with place / release actions (supervisor-elevated). Designed in Phase E.

---

### OI-23 — Lot computed TotalInProcess / InventoryAvailable — ⬜ Open (new)

**Priority:** LOW
**Owner:** Blue Ridge
**FDS §:** 5
**References:** Screenshot review 2026-04-22 (image 31, Lot Details header "Total in-process" and "Inventory available")

**Description:** Legacy Lot Details surfaces two derived figures in the header: **Total in-process** (sum across workstations) and **Inventory available** (unconsumed stock on the lot). Our FDS implies these are derivable from `ProductionEvent` but does not specify the exact derivation or whether they should be materialized for UI performance.

**Proposed direction:** Document the derivation in FDS §5 and decide materialized-column-vs-view. If materialized, update on every ProductionEvent write. Designed in Phase E.

---

### OI-24 — "Automation" top-level tile scope — ⬜ Open (new, discovery)

**Priority:** MEDIUM
**Owner:** MPP IT / Blue Ridge
**FDS §:** TBD
**References:** Screenshot review 2026-04-22 (image 1, top-level "Automation" tile — contents not captured in the provided screenshots)

**Description:** Legacy MES home page has an "Automation" tile. The screenshot set does not include its contents; likely OPC / interface management UI that overlaps with our `Audit.InterfaceLog`. Scope unknown.

**Proposed direction:** Ask MPP for screenshots or a walk-through of the Automation tile. Confirm any in-scope functionality is already covered by our interface-logging / OPC-tag management design. Discovery only — no design commitment until contents known.

---

### OI-25 — Notifications configuration scope — ⬜ Open (new, discovery)

**Priority:** LOW
**Owner:** MPP Operations / Blue Ridge
**FDS §:** Out-of-MVP (pending confirmation)
**References:** Screenshot review 2026-04-22 (image 10, Configuration "Setup > Notifications" tile)

**Description:** Legacy Configuration has a Notifications module for email / alert rules (likely fires on events such as hold placed, line stopped, etc.). Not in our design.

**Proposed direction:** Confirm MPP considers this out-of-MVP and that its absence is not a regression. If in-scope, schema and FDS §12 additions needed. Discovery only.

---

### OI-26 — Per-workstation dashboard scripting hook — ⬜ Open (new, discovery)

**Priority:** LOW
**Owner:** Blue Ridge
**FDS §:** Out-of-MVP (design choice)
**References:** Screenshot review 2026-04-22 (image 26, Lot creation dashboard "Edit Script" button for save-button click)

**Description:** Legacy workstation dashboards allow per-terminal custom scripting attached to button clicks. Ignition Perspective handles scripted behaviour at the project level via views / transforms — a one-to-one port is not idiomatic.

**Proposed direction:** Confirm no current script logic is load-bearing on production flow. If any exists, port the behaviour into Perspective project scripts or view-level event handlers rather than reproducing per-workstation script editing. Discovery only.

---

### OI-27 — Material "Supply part" flag purpose — ⬜ Open (new, discovery)

**Priority:** LOW
**Owner:** MPP Engineering
**FDS §:** 3 (Master Data)
**References:** Screenshot review 2026-04-22 (image 12, Material config "Supply part" BIT)

**Description:** Legacy Material configuration has a "Supply part" BIT. Purpose not obvious from the UI — possibly distinguishes supplier-provided components from in-house produced items. Not in our model.

**Proposed direction:** Ask MPP what a "Supply part" is and whether it drives any workflow (BOM expansion, shipping, etc.). If confirmed, add `IsSupplyPart BIT NOT NULL DEFAULT 0` to `Parts.Item`. Discovery only.

---

### OI-28 — Work Cell "Require override for cast parts" flag — ⬜ Open (new, discovery)

**Priority:** MEDIUM
**Owner:** MPP Engineering / Blue Ridge
**FDS §:** 10 (Automation) — relates to OI-04
**References:** Screenshot review 2026-04-22 (image 19, Work Cell config "Require override for cast parts" checkbox)

**Description:** Legacy Work Cell has a flag requiring supervisor override specifically for cast parts. Likely relates to the OI-04 vision-conflict / line-stop flow but at cell-level granularity — appears to force a supervisor AD prompt for any cast-part mutation at that cell.

**Proposed direction:** Confirm with MPP whether this is still needed and how it interacts with OI-04's line-stop / escalation model. If retained, add `RequiresCastOverride BIT` as a `LocationAttribute` on the Cell type. Discovery only.

---

### OI-29 — Workstation Category grouping orthogonal to Area/Line — ⬜ Open (new, discovery)

**Priority:** LOW
**Owner:** MPP Operations / Blue Ridge
**FDS §:** 2 (Physical Plant)
**References:** Screenshot review 2026-04-22 (image 22, Category configuration with Casting / Tumbling / 5A2 Line 1 / Sort / Shipping / Astemo / etc. two-level grouping independent of Area / Line)

**Description:** Legacy MES groups workstations by Category + Sub-category independently of the Area / Line / Cell physical hierarchy. Examples: "Sort", "Shipping", "Tumbling" appear as Categories alongside line-specific entries like "5A2 Line 1". Appears to be a UI navigation convenience.

**Proposed direction:** Confirm MPP operators rely on this grouping for floor navigation. Our Area / Line / Cell ISA-95 hierarchy should cover it — if not, add a `WorkstationCategory` attribute via `LocationAttribute`. Discovery only.

---

### OI-30 — "Reports" tile contents enumeration — ⬜ Open (new)

**Priority:** MEDIUM
**Owner:** MPP Production Control / Blue Ridge
**FDS §:** 15 (Reports) + UJ-19
**References:** Screenshot review 2026-04-22 (image 1, top-level "Reports" tile — contents not captured); UJ-19 (Productivity DB replacement)

**Description:** Legacy home page has a Reports tile. UJ-19 flags the four Productivity DB reports as a known requirement but the full Reports menu has not been enumerated — there may be additional reports MPP considers baseline.

**Proposed direction:** Walk through the legacy Reports tile with MPP and list every report, then match against our MVP reporting scope. Couples directly to UJ-19 closure.

---

# Part B — User Journey Assumptions & Decisions

These are the 19 assumptions from `MPP_MES_USER_JOURNEYS.md`. Each gates one or more Perspective screens. Cross-references to Part A items are noted per entry.

---

### UJ-01 — Operator identity & elevation model — ✅ Resolved (2026-04-21)

**Priority:** HIGH
**Blocks:** Every screen
**Maps to:** OI-06
**References:** FDS-04-001 through FDS-04-010; FRS 3.3.1, 3.3.4, 3.6.1; FRS 5.3; Spark Dep. B.8

**Decision:** See OI-06. Initials-based operator presence; per-action AD elevation.

---

### UJ-02 — LOT creation flow at Die Cast — 🔶 In Review

**Priority:** MEDIUM
**Blocks:** Die Cast LOT creation screen
**Maps to:** (own item)
**References:** FDS-05-001, FDS-05-002; FRS 3.9.6, 2.2.1, 2.2.2

**Decision:** LTT tags are pre-printed; first scan of a barcode creates the LOT record. No pre-registration, no tag inventory feature. Confirms FDS-05-002. Pending MPP validation.

---

### UJ-03 — Sub-LOT split trigger — 🔶 In Review

**Priority:** MEDIUM
**Blocks:** Machining OUT screen
**Maps to:** (interacts with OI-09 sublot addenda)
**References:** FDS-05-008 through FDS-05-011; FRS 3.9.12, 2.1.4, 2.2.5

**Decision:** Auto-split on arrival at machining, defaulting to 50/50, with operator override. Sublots treated via `Lots.LotGenealogy` (relationship = Split). Needs review with Ben, and reconciliation with the sublot pattern now in OI-09 addenda.

---

### UJ-04 — Container lifecycle on non-serialized lines — ⬜ Open

**Priority:** HIGH
**Blocks:** Assembly / Shipping screens
**Maps to:** OI-02
**References:** FDS-06-014, FDS-03-016; FRS 3.6.6, 3.9.7

**Decision:** Auto-create container on LOT arrival; AIM shipper ID requested at the last route step for the part prior to LOT closure. Pending discussion with Ben.

---

### UJ-05 — Sort Cage serial number migration — ⬜ Open

**Priority:** MEDIUM
**Blocks:** Sort Cage screen
**References:** FDS-07-018; FRS 2.1.10, 2.2.7

**Decision:** Highest traceability-loss risk of any sort scenario. Needs customer discussion. Schema supports update-in-place via `ContainerSerialHistory` but the business rule is undefined.

---

### UJ-06 — Off-site receiving — ✅ Resolved

**Priority:** LOW
**Blocks:** Off-site receiving app
**References:** No FRS coverage — MPP operational decision

**Decision (2026-04-09):** Online only, no concerns. Standard Perspective client via VPN. No offline mode needed.

---

### UJ-07 — Work order visibility and lifecycle — ⬜ Open

**Priority:** HIGH
**Blocks:** Production tracking architecture
**Maps to:** OI-07
**References:** FDS-06-022 through FDS-06-024; FRS 3.1.5, 3.10.1, 3.10.2, 3.10.5; Spark Dep. B.5

**Decision:** Pending Ben's input on WO triggers, span (per-operation vs. per-route), and optional ERP derivation path. Now coupled to the three-WO-type model from OI-07 revised.

---

### UJ-08 — LOT merge business rules — ⬜ Open

**Priority:** HIGH
**Blocks:** LOT merge screen
**Maps to:** OI-05
**References:** FDS-05-012; FRS 3.9.13

**Decision:** Configurable per part or die / cavity. Rules now partially supplied (rank compatibility, post-sort only, FIFO-by-cavity). Full die-rank matrix owed by MPP Quality.

---

### UJ-09 — Material verification at assembly — ⬜ Open

**Priority:** MEDIUM
**Blocks:** Assembly material ID screen
**References:** FDS-06-011; FRS 3.10.6, 3.16.1; FRS 3.4.2 (BOM structure)

**Decision:** BOM check on scan-in — reject substitutes. Pending customer validation.

---

### UJ-10 — Shift boundary handling — ⬜ Open

**Priority:** MEDIUM
**Blocks:** Downtime, container, production screens
**Maps to:** OI-03
**References:** FDS-09-009, FDS-09-010; FRS 3.15.2

**Decision:** Pending customer discussion. Now partially addressed by OI-03's event-derived runtime model — shift boundaries become pure timestamps, downtime events can freely span them.

---

### UJ-11 — Paper to screen transition — ⬜ Open

**Priority:** HIGH
**Blocks:** All production screens
**References:** FDS-15-007; FRS 5.6.6; Appendix F (Productivity DB)

**Decision:** Pending discussion with Ben. Question is whether some stations stay paper-first until tablets are deployed (OI-08 addenda).

---

### UJ-12 — Terminal-to-machine mapping — ✅ Resolved (addenda in OI-08)

**Priority:** MEDIUM
**Blocks:** All operator screens
**Maps to:** OI-08
**References:** FDS-02-008, FDS-02-009; FRS 3.7.1, 3.7.2; Spark Dep. B.1

**Decision:** Terminals are shared with a machine-barcode scan as the first step. 80% are dedicated (1:1) mode, 20% shared — see OI-08 addenda for the `TerminalMode` attribute and the terminal-lock behaviour.

---

### UJ-13 — Weight vs. count-based container closure — ⬜ Open

**Priority:** HIGH
**Blocks:** Container management screens
**Maps to:** OI-02
**References:** FDS-06-014, FDS-03-017; FRS 3.6.6, 3.9.7; Appendix C

**Decision:** Pending Ben — dual-mode closure logic per ContainerConfig (proposed: `ClosureMethod` + `TargetWeight`).

---

### UJ-14 — Warm-up shots and setup tracking — 🔶 In Review

**Priority:** MEDIUM
**Blocks:** Die Cast production screen
**References:** FDS-06-003; FRS 2.2.2; DCFM Paper Sheets

**Decision:** Treat as downtime sub-category. `ShotCount` added to `DowntimeEvent`. Pending Ben's final confirmation.

---

### UJ-15 — Multi-part-number lines — ✅ Resolved (addenda in OI-09)

**Priority:** MEDIUM
**Blocks:** Assembly / inspection screens
**Maps to:** OI-09
**References:** FDS-03-016, FDS-03-017; FRS 3.9.7, 3.16.1, 3.16.2; MS1FM-1028

**Decision:** "Select Part Number" pattern, not concurrent multi-part. See OI-09 addenda for the sublot pattern that concurrent same-part-different-cavity produces.

---

### UJ-16 — Hardware interlock bypass mode — ⬜ Open

**Priority:** MEDIUM
**Blocks:** Serialized assembly screens
**References:** FDS-06-009; Appendix C (OPC tag: `HardwareInterlockEnable`); Touchpoint Agreement §1.4

**Decision:** Add a bypass flag to the data model and mark affected serials as "serial validation skipped." Pending discussion with Ben.

---

### UJ-17 — Vision system vs. barcode confirmation — ⬜ Open

**Priority:** MEDIUM
**Blocks:** PLC-integrated production screens
**Maps to:** OI-04
**References:** FDS-10-003; FRS 3.16.9; Appendix C

**Decision:** Pending Ben. Now coupled to OI-04 revised (line-stop, 10-fail escalation, CRT workflow).

---

### UJ-18 — Event processing: sync vs. async — ⬜ Open

**Priority:** HIGH
**Blocks:** Every label-printing touchpoint
**Maps to:** OI-01
**References:** FDS-01-006; FRS 3.17.4; Spark Dep. B.12

**Decision:** FRS does not require the outbox pattern — just a log of all sent and received content (`Audit.InterfaceLog`). Pending Ben's validation of the direct-call-with-logging approach.

---

### UJ-19 — Productivity DB replacement & change management — ⬜ Open

**Priority:** HIGH
**Blocks:** All production screens, reporting
**References:** FDS-15-007; FRS 5.6.6; Appendix F (Productivity DB); DCFM / MS1FM Paper Sheets

**Decision:** Pending customer discussion. Four PD reports must be replicated; real-time entry at the machine is the default but some stations may need a paper-first-then-enter bridge.

---

## Notes

- The 2026-04-20 MPP review driving v2.4's changes is captured in `Meeting_Notes/2026-04-20_OI_Review.md`.
- The 2026-04-22 legacy screenshot review driving v2.5's additions (OI-15 through OI-30) is captured in `Meeting_Notes/2026-04-20_OI_Review_Status_Summary.md` §"Additional discovered gaps". Source screenshots at `reference/MPP_Current_MES_screenshots.docx`.
- Execution plan for Phases A–G is held in `memory/project_mpp_oi_refactor.md` (session-durable memory). Gap-analysis items (OI-15..30) fold into Phase E (design + doc) and Phase G (SQL) except where noted.
- Phase A (this register) was the first deliverable in the multi-session refactor. Phase B (Tool Management design spec) is complete; Phases C + D (security + FDS rewrites) are complete. Phase E now incorporates the 16 newly-discovered items alongside OI-11..14.
