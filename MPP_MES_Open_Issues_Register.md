# MPP MES — Open Issues Register

**Document:** FDS-MPP-MES-OIR-001
**Version:** 2.12 — Working Draft
**Date:** 2026-04-27
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
| 2.12 | 2026-04-27 | Blue Ridge Automation | **UJ-04 design locked — AIM Shipper ID local pool (zero-latency container closure).** Follow-up to v2.10's "queue async" Decision-with-addition. The Claude-proposed async-queue model (container completes in pending state, queue drains and back-fills `AimShipperId`) was rejected by Jacques on 2026-04-27 because it still introduces latency at close time. Replaced with a **pre-fetched local pool**: a background Gateway script keeps `Lots.AimShipperIdPool` topped up to a configurable target depth; `Container_Complete` claims one row FIFO synchronously inside its own transaction — sub-millisecond, never blocked on AIM. Empty pool = **hard fail** (close rejects, operator sees error, line stops; no soft fallback). Once consumed, IDs are permanently terminal — no return-to-pool on void / re-pack (Honda treats every issued ID as consumed regardless). Honda does not expire IDs. Two new tables (`Lots.AimShipperIdPool` + single-row `Lots.AimPoolConfig`) and four supporting procs (`_Claim` / `_Topup` / `_GetDepth` / `_GetByContainer` plus Config `_Get` / `_Update`). Configuration Tool exposes the four configurable thresholds (TargetBufferDepth=50, TopupThreshold=30, AlarmWarningDepth=20, AlarmCriticalDepth=10). Two-tier alarm: supervisor wallboard tile at Warning, supervisor alarm + IT notification at Critical. Downstream commits in this revision: Data Model v1.9h, FDS v0.11i (FDS-07-005 rewrite, FDS-07-008 amendment, FDS-07-010 rewrite, FDS-07-010a/b/c NEW), ERD Lots tab. SQL deferred to Arc 2 Phase 7 alongside the Container schema CREATE. No count changes (UJ-04 was already counted Resolved in v2.10 — this is a body refinement closing the design). |
| 2.11 | 2026-04-27 | Blue Ridge Automation | **OI-21 design locked — Pausable LOT at Workstation as `Lots.PauseEvent`, not a `WorkOrderStatus` extension.** Follow-up to the v2.10 Decision-with-addition that left four open questions for Claude + Jacques. Decision body rewritten with the locked design: pause is a `(Lot, Location)` event recorded in a new append-only `Lots.PauseEvent` table mirroring `Quality.HoldEvent`. Pause is orthogonal to `WorkOrderStatus`, `OperationStatus`, and `LotStatusCode` — no enum extension on any of those. The same LOT MAY be paused at multiple Cells simultaneously (Machining + Assembly partial-progress); filtered UNIQUE blocks duplicate **open** pauses for `(LotId, LocationId)` only. **No auto-prompt** when starting a different LOT at the same Cell (rationale: Assembly auto-loads from upstream Machining FIFO — an unconditional resume prompt would interrupt the normal flow). Every workstation screen surfaces a **Paused-LOT indicator** (count + tap-through to detail list) for explicit operator-driven resume. **No TTL** — paused LOTs persist across shifts and operators; resume MAY be performed by a different operator from the one who paused. PausedReason and ResumedRemarks both optional. WO/Operation/Lot status do not transition on pause; no DowntimeEvent is written. Downstream commits in this revision: Data Model v1.9g (new `Lots.PauseEvent` table contract), FDS v0.11h (FDS-05-038 NEW under §5.3), ERD Lots tab. SQL deferred to Arc 2 Phase 1 alongside the rest of the Lots schema CREATE — procs `Lots.LotPause_Place / _Resume / _GetByLocation / _GetCountsByLocation`. No count changes to the Resolved/InReview/Open totals (OI-21 was already counted Resolved in v2.10 — this is a body refinement that closes the four open design questions). |
| 2.10 | 2026-04-24 | Blue Ridge Automation | **Jacques OIR review annotations applied.** Jacques annotated v2.8 of this register and returned it; this revision folds every inline "Decision (4/24/2026):" note back into the register source with matching status changes. 17 items moved Resolved (OI-02, -04, -05, -08, -12, -13, -14, -15, -16, -17, -18, -19, -20, -21, -22, -23, -32b). 2 UJs closed (UJ-02, UJ-04). Several carry modifications that trigger downstream data-model / FDS / ERD updates: **OI-12** — `MaxParts` reclassified as a `Parts.Item` attribute (not `ContainerConfig`). **OI-17** — tray-divisibility reclassified as a Finished-Good Part attribute. **OI-18** — `Parts.ItemLocation` extended to support Area / WorkCenter / Cell hierarchy (not Cell-only) with compatibility validation cascading up the hierarchy at check-in. **OI-16** — adds expected PLC confirmation BIT and a new Terminal-scoped `LocationAttribute` toggling a "Confirm Completion" button style (large button on designated lines vs passive popup). **OI-21** — adds a **Pausable WorkOrder** concept (resume prompt on starting a new job while one is paused). **OI-23** — derivation implemented as a view (not materialized columns). **OI-32b** closed: `Parts.ItemType` suffices; no Material Classes table. **OI-32** remains open — Jacques challenged the framing; clarification response logged in Decision narrative. **OI-08** closes with new terminal-mode-by-assignment rule: Terminal assigned to a WorkCenter → Dedicated + no location scan; Terminal assigned to an Area → Shared + location selection is the first step of every interaction. Count shifts: Resolved 5 → 22, In Review 6 → 1 (OI-07 only, mid-revision), Open 20 → 8, Part B Resolved 4 → 6, Part B In Review 3 → 2, Part B Open 12 → 10 (UJ-02 and UJ-04 closed). **UJ insufficiency noted but not addressed this revision** — Jacques flagged that the UJ entries lack the options/impact depth of the OI entries; a separate enrichment pass is queued. **Downstream doc integration queued as a list (data model, FDS, ERD, Arc 2 Plan) but not executed in this commit** — each "Section needs Integrated into other Docs" note from Jacques becomes its own targeted commit. |
| 2.9 | 2026-04-24 | Blue Ridge Automation | **OI-07 rewritten — WorkOrderType corrected to `Production` only; `Recipe` deleted; `Demand` and `Maintenance` reclassified as FUTURE hooks.** Jacques clarified that the 2026-04-20 meeting note "recipe work orders to not be operator visible" was a mis-recording — the "Recipe" line was actually about the **Production** work orders already modelled (MVP-lite, auto-generated, invisible to operators). There is no separate Recipe concept. The existing WO our design supports is Production. Under MPP's framing, **Demand** (planned preventative maintenance) and **Maintenance** (emergency maintenance) are genuinely separate future WO types — but building them is out of scope for this project; the data model only needs to **not block** their future addition. OI-07 scope narrows accordingly: the `Workorder.WorkOrderType` code table remains in the schema as a future hook (new rows can be INSERTed for Demand/Maintenance when Ben scopes the maintenance engine), but the seed is corrected to a single `Production` row. `Recipe` is stripped from every doc, seed, proc comment, and test description. Downstream effects: FDS §6.10 rewritten (FDS-06-022 rename, FDS-06-027 Recipe deleted, FDS-06-025 seed table updated), Data Model §4 seed table updated, ERD Workorder tab + Master tab updated. **SQL follow-up queued** (not executed this turn): a correction migration is needed to rename the shipped `WorkOrderType` seed row `Demand`→`Production`, DELETE `Recipe`, and DELETE `Maintenance` (re-addable later), plus a test update in `sql/tests/0019_Parts_ConsumptionMetadata_And_ScrapSource/010_Phase_E_additives.sql` (current test asserts 3 seed rows + Code='Demand'). |
| 2.8 | 2026-04-24 | Blue Ridge Automation | **Legacy MES Storyboards review additions.** Review of `reference/NewInput/Madison MES - Storyboards.pdf` (2012 Flexware) + `5GO-AP4 IPAddresses.xlsx` against v1.9 / v0.11 / v0.8 / v2.7 design: 43/52 legacy capabilities covered (83%), 5 partial (10%), 4 gaps (7%), 0 out-of-scope. Two register updates: (1) **OI-32 NEW / ⬜ Open** — Material Allocation operator screen. Flexware has a dedicated pre-PLC allocation workflow (`MaterialAllocationMenuView` / `CreateView` / `UpdateView`) gated by `Workstation.MaterialAllocationRequired` BIT; we have the data (OI-18 ItemLocation metadata) but no operator screen. Phase 6 Assembly gates on resolving this. Couples to UJ-09. (2) **OI-32b NEW / ⬜ Open (discovery)** — Material Classes as a first-class entity. Flexware's `Material.MaterialClassID` FK may cover Honda-customer groupings our `Parts.ItemType` misses. Phase 0 confirmation of live usage needed. Full review report at `reference/NewInput/REVIEW_2026-04-24.md`. OI-31 "extend counters" inference from the review was **reverted** — Jacques confirmed the `IdentifierFormat` export he provided (Lot + SerializedItem, 2 rows) is the complete live counter list, not a sample. Design confirmations: DashboardConfiguration / UserInterfaceScript / clock# + PIN rejections validated — no functional loss. |
| 2.7 | 2026-04-24 | Blue Ridge Automation | **Arc 2 model revisions (2026-04-23 session) landed.** OI-09 ✅ Closed — Die Cast cavity-parallel LOTs codified into Data Model v1.9 via `Lot.ToolId` + `Lot.ToolCavityId` (N active cavities → N parallel independent LOTs, not sublots). Machining sub-LOT split remains a separate concept in FDS §5.4. **OI-26 DELETED** (not Resolved, not Superseded — removed entirely). Flexware's `UserInterfaceScript` DB-stored-runtime-code pattern is not reproduced: LocationAttribute on Terminal/Workstation tier + Perspective session-scoped scripts cover every legitimate use case; runtime code lives in Ignition project files, version-controlled. **OI-31 NEW / ⬜ Open** — `Lots.IdentifierSequence` table (Flexware `IdentifierFormat` equivalent, carries `MESL{0:D7}` Lot and `MESI{0:D7}` SerializedItem counters). Schema locked; seed values pending Flexware cutover snapshot. OI-05 confirmed — post-merge LOT has NULL Tool / Cavity (blended-origin can't denormalize). Source decisions: `docs/superpowers/specs/2026-04-23-arc2-model-revisions.md`. Downstream commits in the same refresh pass: Data Model v1.9, FDS v0.11, User Journeys v0.8, Arc 2 phased plan refresh. |

---

## Summary

**Part A counts (30 items):**

| Priority | ✅ Resolved | 🔶 In Review | ⬜ Open | Superseded | **Total** |
|---|---|---|---|---|---|
| HIGH | 3 (OI-01, OI-02, OI-05) | 1 (OI-07) | 2 (OI-13→resolved, OI-15→resolved, remaining: none HIGH still open) | 0 | **6** |
| MEDIUM | 13 (OI-03, OI-04, OI-06, OI-08, OI-09, OI-11, OI-12, OI-16, OI-17, OI-18, OI-21, OI-22, OI-31) | 0 | 4 (OI-24, OI-28, OI-30, OI-32) | 0 | **17** |
| LOW | 6 (OI-14, OI-19, OI-20, OI-23, OI-32b, plus OI-13 resolved HIGH moved up) | 0 | 4 (OI-25, OI-27, OI-29) | 0 | **10** |
| — | 0 | 0 | 0 | 1 (OI-10) | **1** |
| **Total** | **22** | **1** | **8** | **1** | **32** |

> **Note on the count table:** Jacques's 2026-04-24 batch resolved OI-13 (HIGH) + OI-15 (HIGH) but there are no other HIGH items still Open. Resolved column bumps significantly. Corrected row totals below:
>
> - Resolved (22) = OI-01, -02, -03, -04, -05, -06, -08, -09, -11, -12, -13, -14, -15, -16, -17, -18, -19, -20, -21, -22, -23, -32b
> - In Review (1) = OI-07 (mid-correction — see v2.9 entry)
> - Open (8) = OI-24, -25, -27, -28, -29, -30, -31, -32
> - Superseded (1) = OI-10

**Part B counts (19 items):**

| Priority | ✅ Resolved | 🔶 In Review | ⬜ Open | **Total** |
|---|---|---|---|---|
| HIGH | 2 (UJ-01, UJ-04) | 0 | 5 (UJ-07, UJ-08, UJ-11, UJ-13, UJ-18, UJ-19) | **7** |
| MEDIUM | 3 (UJ-02, UJ-12, UJ-15) | 2 (UJ-03, UJ-14) | 5 (UJ-05, UJ-09, UJ-10, UJ-16, UJ-17) | **11** |
| LOW | 1 (UJ-06) | 0 | 0 | **1** |
| **Total** | **6** | **2** | **10** | **19** |

**Grand total:** 51 items (32 Part A + 19 Part B). 28 resolved, 3 in review, 18 open, 1 superseded + 1 superseded-style (OI-10).

> **Note on UJ descriptions:** Jacques flagged 2026-04-24 that UJ entries lack the options/impact/reference depth of the OI entries. A separate enrichment pass is queued before the next MPP review — not addressed in v2.10.

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

### OI-02 — Weight-based container closure — ✅ Resolved (2026-04-24)

**Priority:** HIGH
**Owner:** Blue Ridge / MPP Engineering
**FDS §:** 6.6
**References:** FDS-06-014, FDS-03-017; FRS 3.6.6, 3.9.7; Appendix C (OPC Tags: `TargetWeightValue`, `TargetWeightMetFlag`)

**Description:** On non-serialized / inspection lines, does `Parts.ContainerConfig` need a `ClosureMethod` (`BY_COUNT` vs `BY_WEIGHT`) and a `TargetWeight` field?

**Options considered:**
- (a) Add `ClosureMethod` + `TargetWeight` to `ContainerConfig`.
- (b) Weight closure handled entirely in the PLC — MES responds to a "container full" signal only.

**Proposed decision (pending customer validation):** Non-serialized lines should receive feedback from a scale. The two columns (`ClosureMethod`, `TargetWeight`) were added as nullable to `ContainerConfig` in Phase 4 pending confirmation.

**Decision (2026-04-24):** Proposed decision confirmed by Jacques. `ClosureMethod` + `TargetWeight` on `Parts.ContainerConfig` stay. Non-serialized lines drive closure via scale feedback per FDS-06-014. **Integration queued:** remove "pending validation" language from FDS §6.6 / §3.6; ERD Parts tab card updated to drop the "pending" caveat. UJ-13 (duplicate open item) also closes.

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

### OI-04 — Vision system conflict resolution — ✅ Resolved (2026-04-24)

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

**Decision (2026-04-24):** Proposed decision confirmed by Jacques. FDS §10.3 rewrite from 2026-04-21 (FDS-10-005, -009, -010, -011, -012) is the authoritative spec. **Integration queued:** UJ-17 (duplicate open item) closes.

---

### OI-05 — LOT merge business rules — ✅ Resolved (2026-04-24)

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

**Addendum (2026-04-23):** Post-merge LOT has **NULL `ToolId` + `ToolCavityId`** on `Lots.Lot` — blended-origin material cannot denormalize multiple Tool origins into a single FK pair. Tool-specific trace reconstructed via genealogy of the pre-merge source LOTs (`Lots.LotGenealogy` walk).

Implementation couples to the Phase B Tool Management design because die rank lives on the Tool / Cavity entity. Data model will grow a `Tools.DieRankCompatibility` lookup seeded from the MPP matrix. FDS §5.5 rewrite in Phase D.

**Decision (2026-04-24):** Revised decision + 2026-04-23 post-merge-NULL-Tool addendum both confirmed by Jacques. `Tools.DieRankCompatibility` matrix still owed by MPP Quality; supervisor AD override is the only cross-die merge path until the matrix loads. **Integration queued:** UJ-08 (duplicate open item) closes.

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

### OI-07 — Work order scope — 🔶 In Review (revised 2026-04-24)

**Priority:** HIGH (active); FUTURE hooks are LOW
**Owner:** MPP / Blue Ridge (Ben is SME for the future Demand / Maintenance engine)
**FDS §:** 6.10
**References:** FDS-06-022, FDS-06-023, FDS-06-024, FDS-06-025, FDS-06-026; FRS 3.1.5, 3.10.1, 3.10.2, 3.10.5; Spark Dep. B.5

**Description:** Include Work Orders in MVP or defer entirely? Biggest CONDITIONAL decision.

**Options considered:**
- (a) Include — auto-generated, invisible to operators.
- (b) Defer — all WO tables exist but are not populated.
- (c) MVP-lite — create WOs but no operator-facing screens.

**Decision (2026-04-24 correction of 2026-04-20):** **MVP-LITE with a single active type — `Production`.** Plus a code-table hook that allows future Demand (planned PM) and Maintenance (emergency) types to be added without schema change. Recipe is deleted entirely.

**The 2026-04-20 meeting note was mis-recorded.** The raw note read:

```
Ben has more information about work orders
maintenance engine
demand work orders, maintenance work orders
recipe work orders to not be operator visible
```

Jacques clarified 2026-04-24: the "recipe work orders to not be operator visible" line was actually describing the **Production** work orders already in our design (MVP-lite, auto-generated on LOT start, invisible to operators). There is no separate Recipe concept and there never was. The earlier three-type `Demand` / `Maintenance` / `Recipe` model (FDS v0.10, Data Model v1.7) grew out of extrapolating those four meeting-note words into a full taxonomy — a drafter's error.

**Under MPP's actual taxonomy:**

| Type | Meaning | MVP status |
|---|---|---|
| **Production** | The existing auto-generated, per-LOT, invisible-to-operators bookkeeping (formerly mis-named "Demand"). | **MVP-LITE** — built, auto-generated, no operator screens. |
| **Demand** | Planned preventative maintenance. | **FUTURE** — not in scope for this project. |
| **Maintenance** | Emergency maintenance. | **FUTURE** — not in scope for this project. |

The existing **MVP-lite behaviour does not change.** What changes is:
- The code value in `Workorder.WorkOrderType` is renamed `Demand` → `Production`.
- `Recipe` is deleted from the code table and from every doc.
- `Maintenance` is also removed from the current seed (it was only a placeholder for a future flow). The code table **mechanism** stays as the schema hook — future MPP work can INSERT `Demand` and `Maintenance` rows without a schema change.
- The nullable `ToolId` FK on `Workorder.WorkOrder` stays as a schema hook for future Maintenance WOs targeting a Tool. No flow or proc enforcement in MVP.

**Data model impact:** `Workorder.WorkOrderType` remains. Seed shrinks from 3 rows to 1 row (`Production`).

**SQL correction follow-up (queued, not executed this turn):**
1. New versioned migration (next unclaimed number, e.g., `0013_workordertype_correction.sql`): `UPDATE Workorder.WorkOrderType SET Code='Production', Name='Production Work Order', Description='...' WHERE Id=1`; `DELETE WHERE Id IN (2, 3);` — leaves a single-row seed.
2. Update `sql/tests/0019_Parts_ConsumptionMetadata_And_ScrapSource/010_Phase_E_additives.sql` — current test asserts 3 seed rows + presence of Code='Demand'. Should assert 1 seed row + Code='Production'.
3. Update repeatable proc comments for `R__Workorder_WorkOrderType_List.sql` and `R__Workorder_WorkOrderType_Get.sql` (comment-only change landing this turn).

**Ben's maintenance-engine scope** is NOT gating this project. When MPP later scopes a maintenance MES project, they can INSERT the new `Demand` (planned PM) and `Maintenance` (emergency) code rows and build the flow on top of the existing schema hook. Until then, leave the code table single-seeded.

---

### OI-08 — Terminal architecture — ✅ Resolved (2026-04-24)

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

**Decision (2026-04-24) — new clarification from Jacques:** The Terminal's **Location assignment determines its mode**:
- **Terminal assigned to a WorkCenter (or Cell)** → `TerminalMode = Dedicated`. Machine context is pre-known from the Location hierarchy. No location scan/select required at the start of an interaction.
- **Terminal assigned to an Area** → `TerminalMode = Shared`. Location selection / scanning is the mandatory first step of every interaction (operator picks the destination Cell from the Area's Cells).

This supersedes the earlier `TerminalMode` LocationAttribute approach with a simpler rule: the Location the Terminal is attached to *is* the signal. If a Terminal is a child of a WorkCenter Location in the hierarchy, it's Dedicated by definition; a child of an Area is Shared. No separate attribute value required.

**Integration queued:** FDS §2.5 (FDS-02-010 `TerminalMode` LocationAttribute) rewritten to derive from Terminal parent-Location tier instead of being a separately-seeded attribute. Arc 2 Plan Phase 1 `Terminal_ResolveFromSession` proc reads the parent tier and returns Dedicated/Shared accordingly. Data Model Phase 9 migration may drop the `TerminalMode` `LocationAttributeDefinition` seed if fully superseded (verify during integration). UJ-12 already closed.

---

### OI-09 — Multi-part lines & cavity-parallel LOTs — ✅ Closed (2026-04-23)

**Priority:** MEDIUM
**Owner:** MPP Engineering
**FDS §:** 3.6, 5.1, 5.3, 5.4
**References:** FDS-03-016, FDS-03-017; FRS 3.9.7, 3.16.1, 3.16.2; MS1FM-1028 (multi-part line example)

**Description:** On lines that run multiple part numbers (MS1FM-1028 → 59B / 5PA / 6NA), how are containers handled? And separately: how do cavity-parallel LOTs at die cast work?

**Earlier decision (2026-04-09, retained):** One part at a time per line. Operator selects the active LOT for consumption, which determines the part number. No mixed-part containers. Changeover is an operator action.

**Decision (2026-04-23) — cavity-parallel LOTs codified:** A die-cast machine mounting a Tool with N active cavities produces **N parallel independent LOTs, not sublots**:

- Each LOT is created **lazily** at operator logging time with `ToolId` + `ToolCavityId` set (new FKs on `Lots.Lot` in Data Model v1.9).
- Each LOT fills at its own rate (scrap + cavity health + shutdowns vary).
- Each LOT closes independently via explicit operator action (Complete + Move).
- **No parent/child FK** between them — they're peers. Genealogy is flat at die cast.
- One LTT barcode per LOT (one physical basket = one LOT = one label).

**Distinct from Machining sub-LOT split (remains in FDS §5.4):**
- Machining OUT sometimes breaks a parent LOT into N child sub-LOTs at `Item.DefaultSubLotQty`.
- Parent→children recorded in `LotGenealogy` as SPLIT rows; parent transitions to CLOSED via `Lot_UpdateStatus`.

The 2026-04-20 meeting note conflated cavity-parallel LOTs with sub-LOT splitting — they are two distinct workflows. Cavity-parallel LOTs at die cast are peers, not sublots. Machining sub-LOT split is a legitimate sublot pattern.

Implementation lands in Data Model v1.9 (Lot.ToolId / Lot.ToolCavityId), FDS v0.11 (§§5.1, 5.3, 5.4 revisions), User Journeys v0.8 (Carlos Die Cast scene), and Arc 2 Plan Phase 3 (Die Cast terminal UX).

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

### OI-12 — Lineside inventory caps — ✅ Resolved with modification (2026-04-24)

**Priority:** MEDIUM
**Owner:** MPP Operations / Blue Ridge
**FDS §:** TBD (§3 addenda in Phase E)
**References:** Meeting notes 2026-04-20; FRS 3.6.6 (container config)

**Description:** Operators game the current system by scanning in a large quantity of parts-to-consume at once so they don't have to re-scan as often. MPP wants a cap:
- **Max parts per basket** (ContainerConfig-level).
- **Max lineside inventory quantity** (per Cell / workstation).

Exceeding either limit should reject the scan-in.

**Proposed direction:** Add `MaxParts INT NULL` to `Parts.ContainerConfig`. Add a `LinesideLimit` concept as a `LocationAttribute` on Cells. Validation fires in the scan-in mutation proc. Designed in Phase E, implemented in Phase G.

**Decision (2026-04-24) — modification from Jacques:** Proposed decision is **fundamentally inaccurate** on the `MaxParts` placement. **`MaxParts` is a Part attribute, not a ContainerConfig attribute** — it's evaluated when inventory is checked into a Location, against the Part identity, not against the container's packing recipe. The lineside-limit concept (per-Cell `LinesideLimit` `LocationAttribute`) stays — that is a Location concern. But the per-basket-type cap moves off `Parts.ContainerConfig` and onto `Parts.Item`.

**Integration queued:**
- **Data Model v1.9b** (or next rev): DROP `Parts.ContainerConfig.MaxParts` column (shipped in Phase G migration `0010`); ADD `Parts.Item.MaxParts INT NULL` — cap of pieces allowed to check into any single Location for this Item. Validation: on `LotMovement` to a Cell, sum pieces already at the destination Cell of this Item + incoming quantity ≤ `Parts.Item.MaxParts`.
- **FDS-03-019** rewritten to target `Parts.Item`, not `Parts.ContainerConfig`.
- **FDS-03-020** (Lineside cap via `LocationAttribute`) stays as-is.
- **SQL correction migration queued**: drop `Parts.ContainerConfig.MaxParts`, add `Parts.Item.MaxParts`, update test `sql/tests/0019_Parts_ConsumptionMetadata_And_ScrapSource/`. Coordinate with the OI-07 correction migration.
- **ERD Parts tab** — move the `MaxParts` annotation from `ContainerConfig` to `Item`.

---

### OI-13 — BOM source system — ✅ Resolved with caveat (2026-04-24)

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

**Decision (2026-04-24) — caveat from Jacques:** Proposed direction confirmed with **two-pull** timing: (1) first export pulled **NOW** for dev integration + validation (load into dev DB; verify parts/BOMs resolve correctly; surface missing items and data gaps before cutover); (2) cutover-day re-export + re-run of the bulk-load migration to catch any changes MPP made in the interim. This converts the "one-shot at cutover" into a rehearsed two-phase process — dev load is the rehearsal, cutover load is the production run.

**Integration queued:**
- FDS-14-005 Flexware BOM Import — update "Cutover handoff" bullet to describe the two-pull timing.
- **Action needed NOW:** coordinate with MPP IT for the first Flexware export delivery. Pre-flight validation proc (`Parts.Bom_BulkLoadFromSeed`) design starts immediately.

---

### OI-14 — Admin remove-item capability — ✅ Resolved (2026-04-24)

**Priority:** LOW
**Owner:** Blue Ridge
**FDS §:** 4.3 (elevated actions) + Config Tool phased plan
**References:** Meeting notes 2026-04-20

**Description:** Admin needs to be able to **remove items** (LOTs, Containers, inventory rows) directly — for cleanup, mis-entry correction, and general "oops" recovery that can't flow through normal deprecate paths.

**Proposed direction:** Admin-only Configuration Tool screen with full audit trail. Already listed in FDS-04-007 elevated-action list (Phase C). Detail design in Phase E; proc in Phase G.

**Decision (2026-04-24):** Proposed direction confirmed by Jacques. **Integration queued:** Config Tool phased plan — add admin remove-item screen to Phase 9 or later Config Tool pass; SQL procs to land in the next Phase G-equivalent batch for Arc 2.

---

### OI-15 — Global Trace / Track screen — ✅ Resolved (2026-04-24)

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

**Decision (2026-04-24):** Proposed direction confirmed by Jacques. FDS-12-012 / -013 / -014 Global Trace Tool is authoritative. **Integration queued:** Arc 2 Plan Phase 7 (or earlier Phase that ships the home-tile router) to include the Track tile wiring.

---

### OI-16 — Auto-finish-on-target WO semantics — ✅ Resolved with additions (2026-04-24)

**Priority:** MEDIUM
**Owner:** Blue Ridge / MPP Engineering
**FDS §:** 6.10 addendum + data-collection capture contract (FDS-03-017a)
**References:** Screenshot review 2026-04-22 (image 7, Work Order "Camera system automatic processing" + "Scale system automatic processing"); FRS 3.10

**Description:** Legacy WO configuration exposes **Camera system automatic processing** (tray quantity + part recipe number) and **Scale system automatic processing** (target set quantity) with an explicit "automatically finish when target is reached" semantic. FDS-03-017a covers capturing counts and weights but does not specify the auto-close behaviour at the WO boundary.

**Proposed direction:** Extend §6.10 and `Workorder.ProductionEvent_Record` to fire a WO-close event when cumulative ProductionEvent count (camera) or cumulative weight (scale) reaches the WO target. Configurable per WO.

**Decision (2026-04-24) — additions from Jacques:** Proposed direction confirmed with two additions:

1. **Expect a PLC confirmation BIT.** When camera / scale target is reached, the PLC writes a confirmation BIT; our Gateway script observes the BIT (not just the cumulative count) before firing the auto-close. Belt-and-suspenders: count crosses target AND PLC affirms, not either-or.

2. **Confirm-button style is a per-Terminal `LocationAttribute`.** Some production lines require the operator to physically press a large "Confirm Completion" button at a fixed 1:1 terminal before the WO / Tray / Container closes (manual acknowledgement step). Other lines just show a passive popup ("WorkOrder completed" / "Tray completed" / "Container completed" — whichever is relevant) and proceed. This is configurable per Terminal via a new `LocationAttribute` (e.g., `RequiresCompletionConfirm BIT`) on the Terminal Location.

**Integration queued:**
- **Data Model:** new `LocationAttributeDefinition` seed row for `RequiresCompletionConfirm` on the `Terminal` `LocationTypeDefinition`.
- **FDS-06-028** extended with the PLC-confirmation-BIT requirement and the `RequiresCompletionConfirm` LocationAttribute rule.
- **Arc 2 Plan Phase 6** Perspective Assembly view gains the conditional confirm-button vs popup renderer driven by `session.custom.terminal.requiresCompletionConfirm`.

---

### OI-17 — Tray-divisibility validation on WO close — ✅ Resolved with modification (2026-04-24)

**Priority:** MEDIUM
**Owner:** Blue Ridge
**FDS §:** 6.10
**References:** Screenshot review 2026-04-22 (image 30, "Work order target quantity exceeded. Ensure target quantity is evenly divisible by the tray quantity.")

**Description:** Legacy MES enforces a business rule at container close: target quantity must be evenly divisible by tray quantity, otherwise the container cannot be processed. Rule is not captured in the current FDS or data model.

**Proposed direction:** Validate at WO Create / Edit (target `MOD` tray = 0) and re-validate at Close. Enforced in `Workorder.WorkOrder_*` mutation procs with a specific error code.

**Decision (2026-04-24) — modification from Jacques:** Tray-divisibility is a **Finished-Good Part attribute**. The PartsPerTray value (or the tray-divisibility rule) belongs on `Parts.Item` (or `Parts.ContainerConfig` as already modelled — needs verification during integration), not as free-standing WO validation logic. Validation still fires at WO Create / Edit / Close, but the authoritative source of the tray quantity is the Part, accessed via its ContainerConfig for shipping math.

**Integration queued:**
- **Data Model:** confirm `Parts.ContainerConfig.PartsPerTray` is the authoritative tray quantity (it is — no schema change needed). Document the rule: "WO target must be evenly divisible by `Parts.ContainerConfig.PartsPerTray` of the WO's finished-good Item."
- **FDS-03-021** (WO-create tray-divisibility validation) and **FDS-06-029** (WO-close tray-divisibility validation) — both explicitly reference `Parts.ContainerConfig.PartsPerTray` as the source; confirm FDS language and update if not already explicit.

---

### OI-18 — Parts.ItemLocation consumption metadata — ✅ Resolved with extension (2026-04-24)

**Priority:** MEDIUM
**Owner:** Blue Ridge / MPP Engineering
**FDS §:** 3 (Master Data) + §5/6 consumption flows
**References:** Screenshot review 2026-04-22 (image 12, Material "Compatible work cells" table with Min Quantity / Max Quantity / Default Quantity / Consumption Point columns)

**Description:** Legacy Material → Compatible Work Cells mapping carries four extra attributes — **Min Quantity**, **Max Quantity**, **Default Quantity**, and **Consumption Point (BIT)**. These feed the runtime Allocations grid at the workstation. Our `Parts.ItemLocation` is a plain boolean eligibility junction.

**Proposed direction:** Extend `Parts.ItemLocation` with `MinQuantity INT NULL`, `MaxQuantity INT NULL`, `DefaultQuantity INT NULL`, `IsConsumptionPoint BIT NOT NULL DEFAULT 0`. Designed in Phase E; SQL in Phase G.

**Decision (2026-04-24) — extension from Jacques:** Proposed decision confirmed, with an additional hierarchy requirement. `Parts.ItemLocation` must support designation at **Area / WorkCenter / Cell** granularity — not Cell-only. The junction row's `LocationId` FK can point at any Location tier (Area, WorkCenter, or Cell); when a Part is checked into a specific Cell, the compatibility check cascades up: if the Part has an `ItemLocation` row for *any* ancestor Location of the scanned Cell (including the Cell itself), the Part is eligible there.

This enables rules like "Part 5G0 is eligible across all of Die Cast Area" with a single row, without enumerating every Cell.

The consumption metadata (Min / Max / Default / IsConsumptionPoint) **retains** — these are orthogonal to the hierarchy extension. **Does NOT duplicate OI-12's work** per Jacques's review:
- **OI-12** = per-Location runtime inventory cap (`Parts.Item.MaxParts` evaluated at check-in; per-Cell `LinesideLimit` LocationAttribute).
- **OI-18** = design-time eligibility + consumption-point quantities (Min/Max/Default for the Allocations grid UX).

**Integration queued:**
- **Data Model v1.9c (or next rev):** `Parts.ItemLocation.LocationId` — no schema change (already a generic `FK → Location.Id`); document the hierarchy-cascade rule. The scan-in guard is the place where the cascade is enforced.
- **FDS-03-014 / -015 / -018** — rewrite the eligibility checks to include the Area/WorkCenter/Cell cascade logic.
- **New SQL helper proc** (`Parts.ItemLocation_IsEligible(@ItemId, @CellLocationId)` or equivalent) that walks the Location hierarchy from `@CellLocationId` upward looking for a matching `ItemLocation` row.
- **Config Tool Eligibility screen** (existing) — UI additions to allow selecting the target Location at any tier when creating an `ItemLocation` row.

---

### OI-19 — Parts.Item.CountryOfOrigin — ✅ Resolved (2026-04-24)

**Priority:** LOW (effort) / HIGH (compliance)
**Owner:** Blue Ridge
**FDS §:** 3 (Master Data)
**References:** Screenshot review 2026-04-22 (image 13, Material configuration "Country of origin" field)

**Description:** Legacy Item carries a Country of Origin code. Honda compliance may require it on genealogy / shipping output. Not currently modelled.

**Proposed direction:** Add `CountryOfOrigin NVARCHAR(2) NULL` (ISO 3166-1 alpha-2) to `Parts.Item`. Designed in Phase E; SQL in Phase G.

**Decision (2026-04-24):** Proposed direction confirmed by Jacques. Column already shipped in Phase G migration. **Integration queued:** FDS §3.1 language can drop any "pending" framing.

---

### OI-20 — Scrap source enum (Inventory vs Location) — ✅ Resolved (2026-04-24)

**Priority:** LOW
**Owner:** Blue Ridge
**FDS §:** 5 + ProductionEvent spec
**References:** Screenshot review 2026-04-22 (image 31, "Scrap from inventory" vs "Scrap from the selected location" buttons on Lot Details)

**Description:** Legacy Lot Details screen exposes two distinct scrap paths: scrap from *inventory* (unallocated stock on a lot) vs scrap from a *selected location* (in-process at a specific workstation). Our current `Workorder.ProductionEvent.Type = Scrap` does not capture the distinction.

**Proposed direction:** Add a `ScrapSource` code table (Inventory / Location) and `ScrapSourceId BIGINT NULL` on `Workorder.ProductionEvent`. Designed in Phase E; SQL in Phase G.

**Decision (2026-04-24):** Proposed direction confirmed by Jacques. `Workorder.ScrapSource` code table + `ProductionEvent.ScrapSourceId` FK — both already in Data Model v1.9 / shipped via Phase G migration. FDS-06-023a is authoritative.

---

### OI-21 — Partial start / partial complete at a workstation + Pausable LOT — ✅ Resolved (2026-04-27, design locked)

**Priority:** MEDIUM
**Owner:** Blue Ridge / Ben
**FDS §:** 5.3 (FDS-05-032 partial start/complete + FDS-05-038 Pausable LOT)
**References:** Screenshot review 2026-04-22 (image 33, Tumbling Move Lot with separate "Start lot quantity" and "Complete lot quantity" fields; "0 in inventory available to start, 11 available to complete")

**Description:** Legacy Move Lot UX allows starting N-of-M pieces now and completing the remainder later — start and complete quantities are decoupled per lot per workstation. Beyond that, MPP wants the operator to be able to deliberately **pause** a partially-progressed LOT at a Cell to attend to a different LOT at the same Cell, and return to it later (potentially across shifts, potentially with a different operator).

**Decision (2026-04-24) — partial start/complete confirmed by Jacques:** `Workorder.ProductionEvent` already supports independent Start and Complete event emission with derived WIP — FDS-05-032 is authoritative. (No changes to ProductionEvent shape required by this OI.)

**Decision (2026-04-27) — Pausable LOT design locked (Claude + Jacques discussion):** the four open design questions from the v2.10 entry are answered as follows.

**Q1 — Where does Pause live in the schema?** **Not on `WorkOrderStatus`, not on `OperationStatus`, not on `LotStatusCode`.** Pause is a `(Lot, Location)` lifecycle event — a new append-only `Lots.PauseEvent` table mirroring `Quality.HoldEvent`'s open + close lifecycle. Rationale: WO and WOO are MVP-LITE / invisible to operators (OI-07); a `Paused` row on `WorkOrderStatus` would awkwardly couple operator workflow state to bookkeeping that operators never see. `LotStatusCode` (Good / Hold / Scrap / Closed) is for LOT quality state, not for transient operator focus shifts. A dedicated `PauseEvent` table gives direct `LotId` + `LocationId` for the wallboard counter and detail-list queries, and full pause/resume history (not just current state).

**Q2 — Cross-location concurrency?** **Allowed.** The same LOT MAY be paused at multiple Cells simultaneously (e.g., a Machining LOT mid-progress at one Cell, paused there to handle Assembly work at another Cell). The schema-level filtered UNIQUE on `(LotId, LocationId) WHERE ResumedAt IS NULL` enforces at most one **open** pause per `(LotId, LocationId)` pair only — multiple Locations are independent.

**Q3 — Resume UX trigger?** **No auto-prompt.** When an operator selects or scans a fresh LOT at a Cell that has a paused LOT open, the system SHALL NOT automatically prompt "resume paused LOT?". Rationale (Jacques): Assembly auto-loads the next LOT from upstream Machining FIFO — an unconditional resume prompt would interrupt the normal flow. Instead, every workstation screen SHALL surface a **Paused-LOT indicator** showing the current open-pause count at that Cell. Tapping the indicator opens a list (LotName, Part, PausedAt, PausedByUserId) and allows the operator to resume any paused LOT explicitly. Resume MAY be performed by a different operator from the one who paused.

**Q4 — TTL / cleanup?** **None.** Paused LOTs persist indefinitely. No auto-resume, no auto-cancel. Cleanup of long-paused LOTs is an operational concern handled outside the system (supervisor sweep, "long-paused LOTs" report).

**Other locked decisions:**
- `PausedReason` is **optional** (`NVARCHAR(500) NULL`) — operators MAY pause without entering one.
- `ResumedRemarks` is also optional.
- No FK to `WorkOrderOperation` — `LotId` + `LocationId` is sufficient; the WO/WOO link is recoverable via `ProductionEvent.LotId` if ever needed for reporting.
- Pause does NOT write a `Oee.DowntimeEvent` — the Cell is not down (another LOT may be running).
- Pause does NOT transition `WorkOrderStatus`, `OperationStatus`, or `LotStatusCode`.

**Integration landed (this commit):**
- **Data Model v1.9g** — new `Lots.PauseEvent` table contract (mirrors `Quality.HoldEvent`): `LotId`, `LocationId`, `PausedByUserId`, `PausedAt`, optional `PausedReason`, nullable `ResumedByUserId/ResumedAt/ResumedRemarks`. CHECK pairing on resume cols + filtered UNIQUE on `(LotId, LocationId) WHERE ResumedAt IS NULL` + supporting indexes. `Audit.LogEntityType` +1 row (`PauseEvent`) at Arc 2 Phase 1.
- **FDS v0.11h** — FDS-05-038 (NEW) under §5.3.
- **ERD** — Lots tab `PauseEvent` table card + mermaid box + relationships to `Lot`, `Location`, `AppUser`.

**Integration queued (Arc 2 Phase 1 SQL):**
- Versioned migration adds `Lots.PauseEvent` table + constraints alongside the rest of the Lots schema CREATE.
- Repeatable procs: `Lots.LotPause_Place`, `_Resume`, `_GetByLocation`, `_GetCountsByLocation`.
- Test suite: open / open-conflict / cross-location concurrency / resume / resume-no-open-pause / counter / detail-list.
- Arc 2 Plan Phase 3 / 4 wires the wallboard indicator into every Cell-level Perspective view.

---

### OI-22 — Dedicated Hold Management screen — ✅ Resolved (2026-04-24)

**Priority:** MEDIUM
**Owner:** Blue Ridge / MPP Quality
**FDS §:** 5.7 (Holds)
**References:** Screenshot review 2026-04-22 (image 1, top-level "Hold" tile)

**Description:** Legacy MES gives Holds a top-level navigation tile. Our FDS §5.7 specifies the `HoldEvent` place/release lifecycle but does not explicitly mandate a dedicated Hold-management screen — it may currently be implicit via per-lot hold buttons only.

**Proposed direction:** Add a Hold Management Perspective screen: list of all active holds, filterable by area / line / lot / hold reason, with place / release actions (supervisor-elevated). Designed in Phase E.

**Decision (2026-04-24):** Proposed direction confirmed by Jacques. FDS-08-007a is authoritative. **Integration queued:** Arc 2 Plan Phase 7 (or earlier) to include the Hold tile + screen wiring.

---

### OI-23 — Lot computed TotalInProcess / InventoryAvailable — ✅ Resolved with modification (2026-04-24)

**Priority:** LOW
**Owner:** Blue Ridge
**FDS §:** 5
**References:** Screenshot review 2026-04-22 (image 31, Lot Details header "Total in-process" and "Inventory available")

**Description:** Legacy Lot Details surfaces two derived figures in the header: **Total in-process** (sum across workstations) and **Inventory available** (unconsumed stock on the lot). Our FDS implies these are derivable from `ProductionEvent` but does not specify the exact derivation or whether they should be materialized for UI performance.

**Proposed direction:** Document the derivation in FDS §5 and decide materialized-column-vs-view. If materialized, update on every ProductionEvent write. Designed in Phase E.

**Decision (2026-04-24) — modification from Jacques:** Use a **view**, calculate on view update. Not materialized columns.

**Integration queued:**
- **Data Model:** no columns added to `Lots.Lot` for these derivations. Instead, create `Lots.v_LotDerivedQuantities` (or similar) as a SQL view that computes `TotalInProcess` and `InventoryAvailable` from `Lots.Lot.PieceCount` + `Workorder.ProductionEvent` + `Workorder.ConsumptionEvent` aggregations. Read-only.
- **FDS-05-031** rewritten to specify "view-backed derivation" and drop any "materialized-column option."
- **Arc 2 Plan Phase 2** — add the view creation to the LOT-lifecycle SQL migration.

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

### OI-31 — Identifier sequence table + format carry-forward — ⬜ Open (new, 2026-04-23)

**Priority:** MEDIUM
**Owner:** MPP IT / Blue Ridge
**FDS §:** New § (Identifier Sequences) + §1.4 interfaces
**References:** Arc 2 model revisions spec (`docs/superpowers/specs/2026-04-23-arc2-model-revisions.md` §3); Flexware `IdentifierFormat` table (sampled values `MESL{0:D7}`=1,710,932 for Lot and `MESI{0:D7}`=2,492 for SerializedItem); FRS 3.9.6 (LTT barcode format)

**Description:** Flexware `IdentifierFormat` drives two counters critical to cutover continuity: the Lot LTT barcode (`MESL{0:D7}`) and the serialized-item ID (`MESI{0:D7}`). Both are **MPP-internal identifiers** (not Honda AIM shipper IDs — those come from `AIM.GetNextNumber`). Our current design has no equivalent table; identifiers have been treated as ad-hoc.

**Schema (Arc 2 Phase 1 migration, Data Model v1.9):**

```sql
CREATE TABLE Lots.IdentifierSequence (
    Id                   BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code                 NVARCHAR(30) NOT NULL,
    Name                 NVARCHAR(100) NOT NULL,
    Description          NVARCHAR(500) NULL,
    FormatString         NVARCHAR(50) NOT NULL,    -- .NET string.Format, e.g., 'MESL{0:D7}'
    StartingValue        BIGINT       NOT NULL DEFAULT 1,
    EndingValue          BIGINT       NOT NULL DEFAULT 9999999,
    LastValue            BIGINT       NOT NULL DEFAULT 0,
    ResetIntervalMinutes INT          NULL,        -- unused at MPP today; nullable for future
    LastResetAt          DATETIME2(3) NULL,
    UpdatedAt            DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_IdentifierSequence_Code UNIQUE (Code)
);
```

Companion proc `Lots.IdentifierSequence_Next @Code` atomically increments `LastValue`, formats the result using the `.NET`-style format string, and raises a business-rule error if `EndingValue` would be breached.

**Cutover seeding:** Migration script fetches Flexware `LastCounterValue` on cutover day and seeds at or above those values to avoid LTT collisions with in-circulation LOTs. Sampled baseline values (subject to drift): `Lot=1,710,932`, `SerializedItem=2,492`.

**Open questions for MPP (Phase 0):**
1. **Format continuity** — keep `MESL{0:D7}` / `MESI{0:D7}`, or mint new prefixes in the replacement MES? (Default: keep.)
2. **Reset policy** — currently none in Flexware; any line-specific or shift-specific counter-reset rules MPP wants honored going forward?
3. **Rollover policy at 9,999,999** — at current burn rate, Lots hit rollover in ~30+ years. Planned for, or do we want a warning/error mechanism earlier?

**Counter inventory:** The Flexware `IdentifierFormat` export Jacques provided (2026-04-23) contains exactly two rows — `Lot` (`MESL{0:D7}`, `LastCounterValue=1,710,932`) and `SerializedItem` (`MESI{0:D7}`, `LastCounterValue=2,492`). No other live counters. Any FK references to `IdentifierFormat` from other Flexware tables (WorkOrder, ProductionOrder, etc.) are schema placeholders with no populated format rows.

**Proposed direction:** Implement schema as shown in Arc 2 Phase 1. Phase 0 resolves the three open questions above before cutover-day seeding. `Lots.IdentifierSequence_Next` replaces ad-hoc identifier generation for LOT and SerializedItem minting; no additional counters needed.

---

### OI-32 — Material Allocation operator screen — ⬜ Open (new, 2026-04-24)

**Priority:** MEDIUM
**Owner:** Blue Ridge / Ben
**FDS §:** 5.11 or §6.6a (new section — Allocate Material workflow)
**References:** Legacy Storyboards PDF screen-map family (`MaterialAllocationMenuView` / `MaterialAllocationView` / `MaterialAllocationCreateView` / `MaterialAllocationUpdateView` / `BomComponentDetailsView`); `reference/Flexware_MES_DashboardConfiguration.png` (`Workstation.MaterialAllocationRequired BIT`); Review report §4 Gap 1 at `reference/NewInput/REVIEW_2026-04-24.md`; couples to UJ-09 (material verification at assembly) and OI-18 (ItemLocation consumption metadata)

**Description:** Flexware has a dedicated pre-production **Material Allocation** capability separate from scan-time material verification. An operator (or changeover technician) pre-allocates N baskets of a BOM component to a specific Cell; the allocation shows up on a grid at the workstation; the PLC handshake consumes **against** the allocation rather than against raw LOT scans. Flexware `Workstation.MaterialAllocationRequired BIT` gates whether this is mandatory per terminal.

Our current design has the **data** for allocation via OI-18 (`Parts.ItemLocation.MinQuantity` / `MaxQuantity` / `DefaultQuantity` / `IsConsumptionPoint`) but **no explicit operator screen** and no `Workorder.MaterialAllocation` lifecycle table. FDS-06-011 covers verify-on-scan but not pre-allocate.

**Options considered:**
- (a) Build `Workorder.MaterialAllocation` table (Cell, Item, AllocatedQuantity, ConsumedQuantity, AppUserId, AllocatedAt, ReleasedAt) + Perspective Allocate Material screen + consumption gate in `ConsumptionEvent_Record`.
- (b) Confirm MPP doesn't use the step and close as "intentionally not reproduced."
- (c) Allocate implicitly on first scan (current FDS posture) but expose a read-only "current allocations at this cell" grid on the Assembly view for operator awareness.

**Proposed direction:** Phase 0 question to Ben: *"Do operators pre-allocate baskets of material to Assembly / Machining cells before production begins, or is allocation implicit in the first LTT scan?"* If yes → Option (a), gates Phase 6 Assembly design. If no → Option (b) or (c) documented and closed.

**Impact if unresolved:** Arc 2 Plan Phase 6 (Assembly + MIP + Container) cannot finalize design.

**Clarification exchange (2026-04-24):**

**Jacques's pushback:** *"Parts are 'checked into' Line side storage that can then be consumed by the station or Cell. The line side storage is a typedefinition of Cell. I clearly don't understand the tension with consumption here. Please elucidate."*

**Response (Blue Ridge, 2026-04-24):** The tension I flagged does not exist in our model — your framing is right. In Flexware, `MaterialAllocation` is a separate pre-production workflow step where an operator (or changeover tech) declares "these N baskets are allocated to this cell" as a dedicated action *before* the PLC handshake runs. The allocation exists as a DB row (`MaterialAllocationView` / `MaterialAllocationCreateView`) even though the baskets are just physically staged. It is a workflow artifact of Flexware's data model, not a real-world step.

Under our design:
- **Lineside storage IS a `LocationTypeDefinition` under Cell** — per your 2026-04-24 note.
- An operator "checks in" a LOT to that lineside Cell via a normal `LotMovement` event (the scan-in you describe).
- When the production Cell consumes from the lineside LOT, our `ConsumptionEvent` captures it with full genealogy.
- The operator's "what's at my lineside" grid is answered by a simple read query (`Lots.Lot_ListByLocation @LocationId = <lineside cell id>`), not a separate allocation table.
- The Flexware `Workstation.MaterialAllocationRequired BIT` is satisfied in our model by the act of scanning the LOT into the lineside Cell — the movement itself IS the allocation.

**Revised resolution:** Close OI-32 as **not-reproduced** on the same grounds as OI-32b. No new `Workorder.MaterialAllocation` table needed. No separate Allocate-Material Perspective screen needed. The Flexware concept collapses cleanly into our existing LOT-at-location + ConsumptionEvent model.

**Decision pending:** Jacques to confirm the revised "close as not-reproduced" framing before flipping the status tag. Status stays ⬜ Open until explicit confirmation.

**Integration queued (once closed):**
- **Review report** (`reference/NewInput/REVIEW_2026-04-24.md` §4 Gap 1) — add strike-through + closure note.
- No data model / FDS additions required.

---

### OI-32b — Material Classes — ✅ Resolved / Closed (2026-04-24)

**Priority:** LOW
**Owner:** MPP Engineering / Blue Ridge
**FDS §:** 3 (Master Data) — addendum if retained
**References:** Legacy Storyboards PDF Configuration Menu; `reference/Flexware_MES_ContainerTracking.png` (`Material.MaterialClassID` FK); Review report §4 Gap 2 at `reference/NewInput/REVIEW_2026-04-24.md`

**Description:** Flexware has a `Material` → `MaterialClassID` FK driving a "Material Classes" tile in Configuration. Our data model has `Parts.ItemType` (Cast / Machined / Assembled / Received) which is coarser. `MaterialClass` in Flexware could hold Honda-customer-specific categorisation or finer ItemType granularity — purpose unclear from the 2012 storyboards.

**Options:**
- (a) If Honda-customer groupings → add `Parts.Item.CustomerCode NVARCHAR(50) NULL`.
- (b) If finer ItemType slice → add `Parts.ItemSubType` code table + FK.
- (c) Legacy residue — document the deliberate omission and close.

**Proposed direction:** Phase 0 discovery-only question to MPP Engineering. Low-effort phone call. Resolution drives a small schema delta at most.

**Decision (2026-04-24):** Closed by Jacques — "Don't worry about the language difference, our `Parts.ItemType` will suffice." No `MaterialClass` table. No `Parts.Item.CustomerCode` column. `Parts.ItemType` (Cast / Machined / Assembled / Received / …) is the authoritative grouping.

**Integration queued:** Review report (`reference/NewInput/REVIEW_2026-04-24.md` §4 Gap 2) — add strike-through + closure note. No data model or FDS changes.

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

### UJ-02 — LOT creation flow at Die Cast — ✅ Resolved (2026-04-24)

**Priority:** MEDIUM
**Blocks:** Die Cast LOT creation screen
**Maps to:** (own item)
**References:** FDS-05-001, FDS-05-002; FRS 3.9.6, 2.2.1, 2.2.2

**Decision:** LTT tags are pre-printed; first scan of a barcode creates the LOT record. No pre-registration, no tag inventory feature. Confirms FDS-05-002. Pending MPP validation.

**Decision (2026-04-24):** Confirmed to close by Jacques. FDS-05-002 + FDS-05-036 (lazy operator-driven creation, v0.11) are authoritative.

---

### UJ-03 — Sub-LOT split trigger — 🔶 In Review

**Priority:** MEDIUM
**Blocks:** Machining OUT screen
**Maps to:** (interacts with OI-09 sublot addenda)
**References:** FDS-05-008 through FDS-05-011; FRS 3.9.12, 2.1.4, 2.2.5

**Decision:** Auto-split on arrival at machining, defaulting to 50/50, with operator override. Sublots treated via `Lots.LotGenealogy` (relationship = Split). Needs review with Ben, and reconciliation with the sublot pattern now in OI-09 addenda.

---

### UJ-04 — Container lifecycle + AIM Shipper ID pool — ✅ Resolved (2026-04-27, design locked)

**Priority:** HIGH
**Blocks:** Assembly / Shipping screens
**Maps to:** OI-02
**References:** FDS-07-005, FDS-07-008, FDS-07-010 (rewritten), FDS-07-010a/b/c (NEW); FRS 3.6.6, 3.9.7

**Decision (2026-04-09):** Auto-create container on LOT arrival; AIM shipper ID requested at the last route step for the part prior to LOT closure.

**Decision (2026-04-24) — addition from Jacques (superseded):** "Queue AIM requests asynchronously so production isn't held up by integration latency." Closed UJ-04 to ✅ Resolved with the queue-pattern integration item.

**Decision (2026-04-27) — design locked (Claude + Jacques discussion):** the queue-pattern path was reconsidered and rejected. Even with an async queue, container close briefly transits a pending-ShipperID state before the queue drain back-fills the ID — and pending-state containers can't ship until they get an ID. The cleaner pattern is a **pre-fetched local pool**: AIM Shipper IDs are fetched ahead of time by a background script and consumed FIFO at container close. Container close becomes synchronous and zero-latency.

**Six locked answers (the questions Jacques resolved):**

**Q1 — Empty-pool behavior?** **Hard fail.** If the pool is empty when `Container_Complete` runs, `Lots.AimShipperIdPool_Claim` raises and the close transaction rolls back. The operator sees a clear error; the line is blocked from completing further containers until the pool refills. No soft-fallback "complete with NULL ID" path. Rationale: trucks can't ship without valid AIM IDs, so allowing further closes against an empty pool would just create a pile of un-shippable containers and obscure the actual integration outage.

**Q2 — Per-line scope?** **All Assembly Lines have dedicated terminals.** AIM Shipper IDs attach to **Containers only**, never to sub-assemblies, sub-LOTs, or any other entity. Other Container-completion paths (Die Cast, Trim, intermediate Machining containers if they exist) do not consume AIM IDs.

**Q3 — Buffer sizing.** **Configurable via Configuration Tool.** Single-row `Lots.AimPoolConfig` table with four operator-tunable thresholds (Admin-elevated). Defaults: `TargetBufferDepth = 50`, `TopupThreshold = 30`, `AlarmWarningDepth = 20`, `AlarmCriticalDepth = 10`. CHECK constraint enforces strict ordering (`Critical < Warning < Topup < Target`). Tunable post-deployment based on observed throughput and AIM responsiveness.

**Q4 — AIM ID expiration.** **None.** Honda does not expire AIM Shipper IDs — pool rows can sit indefinitely without staleness. No `ExpiresAt` column on `AimShipperIdPool`; no expiration sweep.

**Q5 — Voided container ID lifecycle.** **Permanent consumption — no reuse.** Once `AimShipperIdPool.ConsumedAt` is set, the row is terminal. Voided / re-packed containers do not return their original ID to the pool — Honda treats every issued ID as consumed regardless. The re-packed container draws a fresh ID from the pool via FDS-07-005's synchronous `_Claim`. FDS-07-008 amended explicitly with this rule.

**Q6 — Failed-topup escalation.** **Two-tier — supervisor alarm + IT notification.** Wallboard tile turns yellow at `AvailableCount < AlarmWarningDepth` (default 20). Supervisor alarm + IT notification fires at `AvailableCount < AlarmCriticalDepth` (default 10), with severity upgraded to "POOL EXHAUSTED — line stops imminent" if depth hits zero. Notifications carry `AvailableCount`, `OldestAvailableAt`, and the most recent `Audit.InterfaceLog` AIM-failure entry. Recovery clears alarms automatically.

**Other locked decisions:**
- **Schema home:** `Lots.AimShipperIdPool` + `Lots.AimPoolConfig`. Container is in Lots; pool follows.
- **Concurrency:** `UPDATE TOP (1) WITH (UPDLOCK, READPAST, ROWLOCK) ... OUTPUT inserted.AimShipperId ORDER BY FetchedAt`. `READPAST` lets concurrent claims skip in-flight locks instead of blocking — two simultaneous closes return two distinct IDs.
- **Provenance:** `AimShipperIdPool.FetchedInterfaceLogId` FK → `Audit.InterfaceLog`. End-to-end traceability from a `Container.AimShipperId` back to the precise AIM `GetNextNumber` call that issued it.
- **Topup cadence:** Gateway timer ~30s. No backoff — the script just re-evaluates depth every cycle.
- **Container/Sub-assembly attribution:** AIM IDs ONLY at Container.

**Integration landed (this commit):**
- **Data Model v1.9h** — new `Lots.AimShipperIdPool` table (FetchedAt, FetchedInterfaceLogId, ConsumedAt/ByContainerId/ByUserId; CHECK pairing the consumed cols; filtered UNIQUE-style indexes for FIFO + traceability) + new single-row `Lots.AimPoolConfig` (four tunables with CHECK ordering, seeded 50/30/20/10).
- **FDS v0.11i** — FDS-07-005 rewritten (synchronous claim, no inline AIM call), FDS-07-008 amended (no ID reuse on void), FDS-07-010 rewritten (pool model + topup state machine), FDS-07-010a NEW (empty-pool hard fail), FDS-07-010b NEW (alarm thresholds + IT notification), FDS-07-010c NEW (Configuration Tool exposure).
- **ERD** — Lots tab adds `AimShipperIdPool` and `AimPoolConfig` cards + mermaid boxes + relationships to Container / AppUser / Audit.InterfaceLog.

**Integration queued (Arc 2 Phase 7):**
- Versioned migration creates both tables alongside `Lots.Container`. `Audit.LogEntityType` +2 rows.
- Repeatable procs: `Lots.AimShipperIdPool_Claim / _Topup / _GetDepth / _GetByContainer` + `Lots.AimPoolConfig_Get / _Update`.
- Test suite covering: FIFO claim ordering, concurrent-claim distinct-ID guarantee, empty-pool hard fail, no-reuse-on-void, config CHECK enforcement, topup INSERT, depth count.
- Gateway timer script (Phase 7) implements the topup loop + alarm evaluation.

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
