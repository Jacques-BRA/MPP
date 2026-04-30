# Arc 2 Model Revisions — 2026-04-23 Session Decisions

**Purpose:** Full accounting of design decisions reached on 2026-04-23 that drive the Arc 2 phased plan refresh, Data Model v1.9, FDS updates, and Open Issues Register changes. Produced at session end so the next session can execute the refresh with zero missing context.

**Status:** Decisions locked unless flagged "Open". Implementation pass queued for next session.

**Triggering events this session:**
1. Phase G (G.3 + G.4 + Initials realignment + G.5) landed and committed (`534f55c`).
2. MPP delivered five Flexware ERD PNGs + a 10-sheet table-structures workbook (production-data dump). Reviewed for implications against our design.
3. Walkthrough of four architectural decisions (Tool integration, IdentifierFormat, dashboard flags, UserInterfaceScript). All resolved.
4. Deep-dive on Die Cast cavity model reshaped ProductionEvent + Lot schemas.

---

## Section 1 — Decision Ledger

### Decision 1: OI-26 (UserInterfaceScript) — CLOSED, DELETED

**Status:** Closed. To be **removed entirely** from the Open Issues Register at the next refresh pass — not marked resolved, deleted. No trace.

**Rationale:** Flexware's `UserInterfaceScript` table stores runtime JavaScript in `Script NVARCHAR(MAX)` rows, referenced from dashboard-configuration columns (`MoveButtonUserInterfaceScriptID`, etc.). The pattern ships new runtime behavior by INSERTing DB rows — bypassing version control, code review, and diff.

**Our answer:** LocationAttribute on Terminal/Workstation-tier Locations + Perspective session-scoped scripts cover every legitimate use case for per-workstation behavior variance. Runtime code lives in Ignition project files, version-controlled. DB-stored-code pattern not reproduced.

**Consequence:** Remove OI-26 on next OIR refresh. Do not mention it.

---

### Decision 2: Dashboard configuration tables (Flexware pattern) — NOT REPRODUCED

**Direction (Jacques' framing):** "These look like artifacts of how they attempted to dynamically render dashboards. We will be defining these with clarity for each terminal based on Ignition Perspective best practice and explicit build out (area function)."

**What this means concretely:**
- **Per-terminal-function purpose-built Perspective views** — Die Cast terminal view, Trim Station view, Machining IN view, Machining OUT view, Sort Cage view, Shipping view, Hold Management view, Weigh Station view, etc. Zone-based routing (Arc 2 Plan B11) picks the right view by terminal Location.
- **Flexware's `*DashboardConfiguration` family is NOT reproduced** — `LotTrackingDashboardConfiguration`, `LotCreateDashboardConfiguration`, `WorkOrderDashboardConfiguration`, `FinalAssemblyDashboardConfiguration`, `CreateAllocationDashboardConfiguration`, `SortDashboardConfiguration`, `MaterialLabelPrintDashboardConfiguration`, `WorkstationDashboardConfiguration`. None of these translate into our schema.
- **Flexware BIT flags on those tables NOT reproduced** — `PopulateInProcessQuantityOnItemSelection`, `PopulateFixedQuantityOnItemSelection`, `FixedQuantityToPopulate`, `AssemblyLotScanningIsEnabled`, `PopulateMaterialDefaultBasketQuantity`, `LotHistoryAtSourceLocationIsActive`, etc. If the Trim view needs different populate behavior than the Assembly view, they're different views — not a configurable flag.

**LocationAttribute usage remains legitimate** for genuine business policies only:
| Attribute | Scope | Purpose |
|---|---|---|
| `DefaultScreen` | Terminal/Workstation tier | B11 zone-based routing (already in plan) |
| `RequireCastPartAllocationOverride` | Cell tier | OI-28 business rule |
| `LinesideLimit` | Cell tier | OI-12 lineside cap (already in model) |
| `TrackingMode` | Cell tier | Pending MPP enumeration at Phase 0 |
| `IpAddress` | Terminal tier | Already in model |

Not for UI config. Not for dashboard behavior. Business policies only.

**WorkOrder BIT flags from Flexware** (`IsCameraProcessingEnabled`, `IsScaleProcessingEnabled`, `GroupTargetWeight`, `GroupTargetWeightTolerance`, `TargetWeightUnitOfMeasureID`, `RecipeNumber`, `TrayQuantity`, `ReturnableDunnageCode`, `Customer`) — treated as a Phase 0 MPP input. Ask MPP which are live in production. Live ones become columns on `Workorder.WorkOrder` when Arc 2 Phase 1 creates that table; dead ones don't ship. Most look like weight-based container closure and will be subsumed by OI-02 resolution.

**Consequence for Arc 2 refresh:** Remove any lingering generic-dashboard-configuration pattern references. Phase-per-phase narratives describe their purpose-built Perspective views explicitly.

---

### Decision 3: `Lots.IdentifierSequence` — NEW TABLE (OI-31 OPEN)

**Status:** Design locked. Seed values pending MPP cutover confirmation. Open Issue **OI-31** created.

**Why a table, not a workaround:** Flexware's `IdentifierFormat` drives two counters critical to cutover continuity:
| Flexware row | Format | Range | Last value (sampled) | Reset |
|---|---|---|---|---|
| Lot Format | `MESL{0:D7}` | 1–9,999,999 | **1,710,932** | none |
| Serialized Item Format | `MESI{0:D7}` | 1–9,999,999 | 2,492 | none |

These are MPP-internal identifiers (LTT barcodes + serialized-part IDs), NOT Honda AIM shipper IDs (those come from `AIM.GetNextNumber`). Migration must seed new-MES counters at **or above** Flexware's last values at cutover moment to avoid collisions with LOTs still in circulation.

Cutover reality: both counters will have advanced past the numbers shown in the workbook by the time we cut over. Migration script fetches `LastCounterValue` from Flexware on cutover day.

**Schema (lands in Arc 2 Phase 1 migration):**
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

**Companion proc `Lots.IdentifierSequence_Next`:** Accepts `@Code`. Atomically increments `LastValue` via `UPDATE Lots.IdentifierSequence SET LastValue = LastValue + 1, UpdatedAt = SYSUTCDATETIME() OUTPUT inserted.LastValue, inserted.FormatString INTO #Result WHERE Code = @Code`. Formats the result using the `.NET`-style format string. Validates against `EndingValue` (raise a business-rule error if rollover would breach the cap without explicit reset policy).

**Seeds at cutover (to confirm values from Flexware on the day):**
- `Code='Lot'`, `FormatString='MESL{0:D7}'`, `LastValue=<Flexware.LastCounterValue>`
- `Code='SerializedItem'`, `FormatString='MESI{0:D7}'`, `LastValue=<Flexware.LastCounterValue>`

**OI-31 — open questions for MPP at Phase 0:**
1. Format continuity: Keep `MESL{0:D7}` / `MESI{0:D7}`, or mint new prefixes in the replacement MES? (Default: keep.)
2. Additional counters in use we haven't seen (container barcodes, shipping print sequences, anything non-AIM)?
3. Reset policy: currently none, but are there line-specific or shift-specific counter-reset rules MPP wants us to honor that weren't implemented in Flexware?
4. Rollover policy at 9,999,999: at current burn rate, Lots hit rollover in ~30+ years. Is that planned for, or do we want a warning/error mechanism?

---

### Decision 4: Tool + Cavity promoted onto `Lots.Lot`

**Status:** Locked. Replaces the Data Model v1.4 hot-column pattern on `Workorder.ProductionEvent`.

**Original problem:** Data Model v1.4 put `DieIdentifier NVARCHAR(50)` + `CavityNumber INT` as hot typed columns on `ProductionEvent`. At the time, `Tools.Tool` did not exist. After Phase B (2026-04-21, locked) made Tool first-class with immutable `Code`, the NVARCHAR stamp became pure denormalization with no information gain AND a failure mode (drift between stamp and Tool.Code).

**Decisive context (confirmed by Jacques this session):** A 16-cavity die produces **16 independent parallel LOTs, not sublots**. Each LOT has one Tool + one Cavity. Each LOT fills at its own rate. Operators visit the terminal periodically, not per-shot. LOT creation is lazy — the LOT is born when the operator logs it.

Given that every LOT's Tool+Cavity is fixed at LOT creation and never changes, the right place for Tool info is on the LOT itself.

**Schema changes (Data Model v1.9):**

**`Lots.Lot` — ADD:**
```
ToolId        BIGINT  NULL  REFERENCES Tools.Tool(Id)
ToolCavityId  BIGINT  NULL  REFERENCES Tools.ToolCavity(Id)
```

- **Required at `Lot_Create`** for die-cast-origin LOTs. Validated against `Tools.ToolAssignment_ListActiveByCell` (Tool must be currently mounted on the cell) + Cavity belongs to Tool + Cavity is Active status.
- **NULL for all other origins**: RECEIVED (from vendor), trim / machining intermediate LOTs, assembly LOTs, serialized-part LOTs.
- **NULL after `Lot_Merge`** on blended-origin merged LOTs (can't denormalize multiple Tools into one FK — OI-05 revised post-sort merge).

**`Workorder.ProductionEvent` — DOES NOT carry Tool/Cavity.** Derivable via `ProductionEvent.LotId → Lot.ToolId/ToolCavityId`.

**Downstream LOTs do NOT inherit Tool info.** Genealogy traversal handles Honda-trace queries:
```sql
-- "Every finished part that contains material from die ABC123"
WITH Origin AS (
    SELECT Id FROM Lots.Lot WHERE ToolId = @HondaRecallToolId
),
Descendants AS (
    SELECT ChildLotId FROM Lots.LotGenealogy WHERE ParentLotId IN (SELECT Id FROM Origin)
    UNION ALL
    SELECT g.ChildLotId FROM Lots.LotGenealogy g
    INNER JOIN Descendants d ON d.ChildLotId = g.ParentLotId
)
SELECT DISTINCT ChildLotId FROM Descendants
OPTION (MAXRECURSION 100);
```
Not a hot path. No denormalization needed.

**Rationale (why NULL-downstream beats carry-forward):**
1. Many:1 consumption (assembly) can't denormalize multiple Tool origins into a single column.
2. Tool info is already available via genealogy; denormalization creates drift risk.
3. Tool is a die-cast-origin fact; trim/machining/assembly operations don't produce against dies.

**Die Cast terminal UX consequence (Jacques' decision):**
- On Cell selection, screen auto-populates the currently mounted Tool (from `ToolAssignment_ListActiveByCell`).
- Operator validation is **required only at Die Cast** (confirm auto-populated tool matches the physical die).
- An **Edit** button on Die Cast screen triggers an **elevated action** to re-run `ToolAssignment_Release` + `ToolAssignment_Assign` inline, correcting the system of record if physical die differs from what's mounted.
- Other areas (trim, machining, assembly) do NOT require operator Tool validation at this level.

---

### Decision 5: `Workorder.ProductionEvent` — Checkpoint Shape (FINAL)

**Status:** Locked. Authoritative source: FRS §2.1.2 (operator-driven capture, not PLC).

**Operator model:** Operators are NOT at the terminal for every shot. Checkpoints are:
- Checkout from die cast (physically moving LOT out of the machine)
- Check-in to trim shop (receiving from upstream; frequently combined with checkout for expedience)
- Complete + move (operator-driven close)
- Checkpoint at quality operation transitions

Each checkpoint fires one `ProductionEvent` row. The event carries the cumulative counters as-of-that-moment; deltas are derived by comparing against the previous event for the same LOT.

**Schema (Arc 2 Phase 1 CREATE):**
```
Workorder.ProductionEvent
    Id                   BIGINT        IDENTITY(1,1) PK
    LotId                BIGINT        FK → Lots.Lot              (NOT NULL)
    OperationTemplateId  BIGINT        FK → Parts.OperationTemplate  (NOT NULL — captures FDS-03-017a contract)
    EventAt              DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
    ShotCount            INT           NULL       -- cumulative at event time (open item — see below)
    ScrapCount           INT           NULL       -- cumulative at event time
    ScrapSourceId        BIGINT        FK → Workorder.ScrapSource  NULL   (OI-20 — only non-NULL when this event drove a scrap action)
    WeightValue          DECIMAL(12,4) NULL
    WeightUomId          BIGINT        FK → Parts.Uom              NULL
    AppUserId            BIGINT        FK → Location.AppUser       (NOT NULL — who captured this event)
    -- ProductionEventValue children handle extensible DataCollectionField capture
```

**What's deliberately NOT on this table:**
- No `CellLocationId` — derivable from `LotMovement` at `EventAt` timestamp. Redundant and silly (Jacques' framing).
- No `StartedAt` / `EndedAt` — the "start" of this event's interval is the previous event for the same LOT. Derived via `LAG()` window function. Avoids dangling "started-but-not-ended" rows entirely.
- No `DieIdentifier` / `CavityNumber` — Lot.ToolId / Lot.ToolCavityId are the system of record.
- No `ToolId` / `ToolCavityId` — derived from Lot.

**Required index:** `(LotId, EventAt DESC)` — makes "previous event for this LOT" a single-row seek.

**Sample delta query:**
```sql
SELECT
    pe.Id,
    pe.EventAt,
    pe.ShotCount,
    pe.ShotCount - LAG(pe.ShotCount) OVER (PARTITION BY pe.LotId ORDER BY pe.EventAt) AS ShotsSinceLast,
    pe.ScrapCount - LAG(pe.ScrapCount) OVER (PARTITION BY pe.LotId ORDER BY pe.EventAt) AS ScrapSinceLast
FROM Workorder.ProductionEvent pe
WHERE pe.LotId = @LotId
ORDER BY pe.EventAt;
```

**Open Item — ShotCount semantics (OPEN; proposed direction: cumulative):**
- **Leading direction:** ShotCount is cumulative (counter reading at event time). Deltas derived. A missed event doesn't compound errors — next event carries truth.
- **Alternative Jacques surfaced:** Total might be derived from the total number of LOTs produced (cavity produces N LOTs of known size each → aggregate shot count from Lot quantities, not a separate counter).
- **TBD:** Confirm during Phase 0 whether we need the counter column at all, or whether LOT-quantity aggregation is the source of truth for "shots per die" reporting.
- **Default until decided:** Keep `ShotCount INT NULL` in the schema per the direction above, document it as provisional, and resolve during Arc 2 Phase 3 implementation when the operator screen is being built.

---

### Decision 6: Die Cast Cavity-Parallel LOT Pattern — OI-09 CLOSED

**Status:** OI-09 closes at next OIR refresh pass.

**Pattern (codified into Data Model v1.9):**
A die-cast machine mounting a Tool with N active cavities produces **N parallel independent LOTs**:
- Each LOT has `ToolId` + `ToolCavityId` set at creation.
- Each LOT fills at its own rate (scrap + cavity health + shutdowns vary).
- Each LOT closes independently (operator-driven complete + move).
- **No parent/child FK** between them — they're peers. Genealogy is flat at die cast.
- One LTT barcode per LOT (one physical basket = one LOT = one label).

**Distinct from Machining sub-LOT split (stays in Arc 2 Phase 5):**
- Machining OUT sometimes breaks a parent LOT into N child sub-LOTs at `Item.DefaultSubLotQty`.
- Parent→children recorded in `LotGenealogy` as SPLIT rows.
- Parent LOT transitions to CLOSED via `Lot_UpdateStatus`.

The 2026-04-20 meeting note "sublot pattern: parent FK, per-cavity concurrent lots, labels persist" conflated two things. Cavity-parallel LOTs at die cast **are not sublots** — they're peers. Machining sub-LOT split **is a sublot pattern**. Two distinct workflows.

---

### Decision 7: LOT Creation Timing — LAZY / OPERATOR-DRIVEN

**Status:** Locked.

**Pattern:** `Lot_Create` fires whenever the operator is at the terminal and decides to log a LOT. The system does not prescribe when. Valid moments include:
- On physical completion of a basket (go to terminal to log + move it).
- After completing a prior LOT and before starting the next (pre-emptive creation).
- Any other moment the operator chooses.

**Consequence:** Physical-but-unlogged baskets exist until the operator logs them. Phase 3 UI / procs **must not** require a LOT to exist for an in-progress cavity. The LOT simply isn't there yet.

**Consequence:** Tool + Cavity assignment happens at LOT create time (operator selects/confirms which cavity). Not at any abstract "run start" event.

---

### Decision 8: LOT Close Semantics

**Status:** Locked.

| LOT origin | Close behavior |
|---|---|
| Component LOTs (Die Cast, Trim, intermediate Machining) | **Explicit operator-driven close.** "Complete + move" is a combined UI action — transition LOT status to Complete AND move to next location atomically. No auto-close. Cavity state changes (e.g., broken cavity → Closed) do NOT auto-close the LOT; partial basket sits as Complete when operator decides. |
| Finished-goods LOTs (Assembly end-products that go into shipping Containers) | **May auto-close on container fill.** Phase 6 (Assembly + MIP + Container) owns this detail. `Container_Complete` action closes the associated LOT. |

---

### Decision 9: Basket vs Container — DISTINCT CONCEPTS (Data Model v1.9)

**Status:** Locked. Column repurpose, not a schema addition.

**Taxonomy:**
| Concept | Used at | Capacity defined by |
|---|---|---|
| **Basket** | Die Cast / Trim / intermediate Machining LOTs. One LOT = one basket. One LTT label per basket. | Item-level integer |
| **Container** | Finished-goods shipping (assembly end-products → shipper). Tray-per-container × parts-per-tray math applies. | `Parts.ContainerConfig` (existing) |

**Decision (Jacques leans A, locked):**
**Repurpose `Parts.Item.MaxLotSize` as the basket-capacity field.**
- One LOT = one basket, so "max parts per LOT" = "basket capacity" by definition.
- Rename in docs and Config Tool Item screen to **`PartsPerBasket`** for clarity. No schema column-rename required at first; data-model label and Config Tool UI caption both change. A future migration can add a formal rename later if desired.
- Zero schema delta. No new column. Existing `MaxLotSize INT NULL` stays as-is; meaning clarified.

**Distinct from OI-12 scope clarification:**
OI-12 original framing ("Lineside inventory caps. Max parts per basket + lineside quantity limit") is actually two things:
- **Max parts per basket** → `Parts.Item.MaxLotSize` (repurposed, per this decision).
- **Lineside quantity limit** → `LinesideLimit` LocationAttribute on Cell (already in model; already in Phase G migration).

OI-12 itself remains Revised status pending MPP confirmation, but the schema answer is now fully in place.

**Distinct from `Parts.ContainerConfig.MaxParts` (OI-12, shipped in G.1):**
`MaxParts` on ContainerConfig is about shipping containers — it caps total pieces in a container when tray × parts-per-tray math would otherwise over-count. Legitimately container-scoped. Stays.

---

### Decision 10: Post-Merge LOT — NULL Tool/Cavity

**Status:** Locked.

After `Lot_Merge` (OI-05 revised — post-sort only, same-part, cross-die allowed if rank-compatible), the merged LOT has blended-origin material from multiple source LOTs. `ToolId` + `ToolCavityId` both become **NULL** on the merged LOT — can't denormalize multiple Tools into a single FK. Tool-specific trace reconstructed via genealogy of the pre-merge source LOTs.

---

## Section 2 — Non-Die Tool Assignment: Future Consideration (Not Blocking)

**Flagged but not blocking MVP.** The current `Tools.ToolAssignment` schema (migration 0010) has:
```sql
CREATE UNIQUE INDEX UQ_ToolAssignment_ActiveCell
    ON Tools.ToolAssignment (CellLocationId)
    WHERE ReleasedAt IS NULL;
```

This enforces **one active mounted Tool per Cell.** Correct for Die Cast. Wrong for:
- **Machining** — multiple cutters, fixtures, jigs simultaneously.
- **Trim** — trim dies + deburr tools + jigs.
- **Assembly** — fixtures + jigs + gauges.

**Impact for MVP:** None. Tool tracking is Die-focused for MVP. This constraint doesn't bite until non-Die Tool types become live (post-MVP).

**Future-adjustment path when it matters:** Either scope the UNIQUE to `(Cell, ToolType='Die')` filtered only on Die-type Tools, OR drop the Cell UNIQUE entirely and let Tool uniqueness (already filtered UNIQUE on Tool) carry the rule. Schema-level refactor with one migration + proc updates.

**Documentation target:** Note this limitation in `MPP_MES_DATA_MODEL.md` §7 Tools — "Cell-level filtered UNIQUE is Die-only; expand when non-Die Tool types go live."

---

## Section 3 — Open Issues Register Changes

To be applied in the next refresh pass:

| OI | Action | Detail |
|---|---|---|
| **OI-09** | ⬜ Open → ✅ Closed | Die Cast cavity-parallel LOTs codified into Data Model v1.9 (`Lot.ToolId` + `Lot.ToolCavityId`). Machining sub-LOT split stays separate (Arc 2 Phase 5). |
| **OI-12** | 🔶 Revised → Resolution pending MPP | Schema split clarified: basket capacity = `Item.MaxLotSize` (repurposed as PartsPerBasket); lineside limit = `LinesideLimit` LocationAttribute. Both already in model. MPP validation pending. |
| **OI-26** | ⬜ Open → **DELETE** | Remove entirely. Not marked Closed or Superseded — **deleted**. |
| **OI-31 (NEW)** | — → ⬜ Open | `Lots.IdentifierSequence` — schema proposed, seed values pending Flexware cutover snapshot. Format carry-forward and additional counters pending MPP confirmation. |
| **OI-05** | 🔶 Revised | No change to status — confirm post-merge Tool=NULL rule in the spec text. |

---

## Section 4 — Data Model v1.9 Delta Summary

**New in v1.9 (vs v1.8, rev 2026-04-22):**

1. **`Lots.Lot` ADDs:**
   - `ToolId BIGINT NULL REFERENCES Tools.Tool(Id)`
   - `ToolCavityId BIGINT NULL REFERENCES Tools.ToolCavity(Id)`
   - Rules: required at `Lot_Create` for die-cast-origin; NULL elsewhere; NULL after `Lot_Merge`; downstream LOTs do not carry.

2. **`Workorder.ProductionEvent` NEW TABLE (Arc 2 Phase 1 creates):**
   - Checkpoint shape per Decision 5.
   - No CellLocationId, no DieIdentifier, no CavityNumber, no Start/End.
   - `ShotCount` cumulative (open item — might migrate to derived-from-LOT-quantity).
   - Index: `(LotId, EventAt DESC)`.

3. **`Lots.IdentifierSequence` NEW TABLE (Arc 2 Phase 1 creates):**
   - Plus companion proc `IdentifierSequence_Next @Code`.
   - Seeded at cutover with `Lot`/`SerializedItem` rows carried over from Flexware.

4. **`Parts.Item.MaxLotSize` — semantic repurpose:**
   - Documentation + Config Tool label becomes `PartsPerBasket`.
   - No column rename yet (deferred).
   - Clarify: this is the basket capacity for intermediate LOTs (die cast / trim / machining).

5. **Note added in §7 Tools:** non-Die Tool assignment needs Cell UNIQUE relaxation when non-Die Tool types activate (post-MVP).

**Not changing in v1.9:**
- ProductionEventValue (still handles extensible DataCollectionField capture)
- LotGenealogy (parent/child FKs unchanged; handles downstream Tool trace via traversal)
- Workorder.ScrapSource (2 rows, Inventory + Location — G.1 already landed)
- Tools.* schema (no changes — locked in G.1/G.2)

---

## Section 5 — FDS Delta (v0.10 → v0.11)

**Sections requiring updates in the next refresh:**

| § | What changes |
|---|---|
| §3.5 Operation data collection (FDS-03-017a, 03-018) | Update signature: no `DieIdentifier`/`CavityNumber` on event; derive from Lot. |
| §4 User Authentication & Session Management | Already current (Phase C locked). No change. |
| §5.1 LOT Creation | Add die-cast-origin rule: `Lot_Create` requires `@ToolId` + `@ToolCavityId` for Cells with a mounted Tool; validates via `ToolAssignment_ListActiveByCell`. |
| §5.3 Start + Complete | Clarify LOT creation is operator-driven and lazy. Cavity-parallel LOTs (N per active cavity) but only materialize when operator logs each. |
| §5.4 Sub-LOT Splitting | Keep Machining sub-LOT split. Remove any cavity-parallel language (that's not sublots). |
| §5.5 LOT Merging | Add rule: merged LOTs have `ToolId`/`ToolCavityId` NULL. |
| §6.8 ScrapSource usage | Add: ScrapSource on ProductionEvent only when event drove a scrap action. |
| §6.10 Work Orders | Reference three-WO-type model (already in v0.10). Add WO BIT-flag ingestion note from Phase 0 MPP input. |
| NEW § | Identifier sequences — document `Lots.IdentifierSequence` and format conventions (`MESL{0:D7}`, `MESI{0:D7}`). |
| NEW § or update | Tools system of record — explicitly say Tool/Cavity live on Lot, derivable on Event via JOIN. Forbid carry-forward to downstream LOTs. |
| §11 Audit | No change — FDS-11-011 convention holds. |

---

## Section 6 — User Journeys Delta (v0.7 → v0.8)

**Arc 1 (Config Tool) — no change.**

**Arc 2 scenes to revise:**
- **Carlos at Die Cast** — scene narrates auto-populated Tool on Cell selection. Elevated Edit override when physical ≠ system. LOTs created lazily when Carlos logs each basket, not at run start.
- **Diane at Trim Shop** — "check-in" fires `ProductionEvent` capturing cumulative ShotCount + ScrapCount since the LOT's last event (which was Carlos's checkout). Delta derived by the system.
- **Machining OUT (sub-LOT split)** — sub-LOT split narrative stays; parent→children via `LotGenealogy` at `Item.DefaultSubLotQty`. Tool info NOT carried from parent (parent is a machined LOT, not die cast; Tool is already NULL).
- **Sort Cage (Diane)** — merge scene: post-merge LOT has NULL Tool. Honda trace query path documented.

---

## Section 7 — Arc 2 Plan Refresh Punch List

Spec at `docs/superpowers/specs/2026-04-16-arc2-phased-plan-design.md` (dated 2026-04-16). Predates every post-2026-04-20-meeting decision and all Phase G work.

**Required updates before Arc 2 `writing-plans` skill can run:**

| Phase | Change |
|---|---|
| Phase 0 (Customer Validation Gate) | Open-items list is stale. OI-03 + OI-06 already closed. OI-09 closes per this session. New Phase 0 items: OI-31 (IdentifierFormat carry-forward), WorkOrder BIT-flag enumeration, TrackingMode enumeration, historical data migration plan. Re-scope accordingly. |
| Phase 1 (Foundation) | Auth narrative says "AD-backed clock# + PIN" — **REWRITE** to Phase C initials-only model. Add `AppUser_GetByInitials` as the primary lookup proc. Add IdentifierSequence seed step at cutover. |
| Phase 2 (LOT Lifecycle) | `Lot_Create` signature: add `@ToolId` + `@ToolCavityId` params (optional, required-by-origin-check). `Lot_Merge`: null Tool on merged row. |
| Phase 3 (Die Cast) | Wholesale update. Reference `Tools.Tool` + `Tools.ToolCavity` as system of record. Terminal UX: auto-populate Tool from active assignment; elevated Edit. LOTs are N parallel per cavity. `Lot_Create` requires Tool+Cavity. `ProductionEvent_Record` implements checkpoint shape. |
| Phase 4 (Movement + Trim + Receiving) | Trim check-in fires `ProductionEvent` with cumulative counters. ScrapSource=Location for scrap-from-workstation events. |
| Phase 5 (Machining with Sub-LOT Split) | Keep sub-LOT split as-is (separate concept from cavity-parallel LOTs). Remove any language that implied "sublots at die cast". |
| Phase 6 (Assembly + MIP + Container) | `ContainerConfig.MaxParts` (already shipped) referenced. Finished-goods LOT auto-close on container-fill. 1-line BOM consumption (OI-11 reversal — no `ItemTransform`). |
| Phase 7 (Hold + Sort Cage + Shipping + AIM) | `Workorder.ScrapSource` (2 rows — Inventory/Location, OI-20) referenced in scrap event narratives. Merge narrative uses rank compat (OI-05 revised) + null-Tool rule. |
| Phase 8 (Downtime + Shift) | Already structured correctly. Minor: reference Phase 8 Oee tables already delivered (G.1 era). |
| Cross-cutting | B11 zone-based routing still valid. Add new cross-cutting rule: "Per-terminal-function Perspective views; no generic dashboard-configuration engine; LocationAttribute used for business policies only, never UI config." |
| Out of scope | Add: "UserInterfaceScript DB-stored-runtime-code pattern (Flexware). Not reproduced." |

**Refresh approach:** In the next session, invoke the `writing-plans` skill (or just do an in-place edit pass) on the spec file OR on `MPP_MES_PHASED_PLAN_PLANT_FLOOR.md` (whichever is the live target). Output target is the live plan doc, not just the spec.

---

## Section 8 — Phase 0 MPP Input Needs (Consolidated)

Items to bring to the next MPP review:

1. **OI-31 (IdentifierSequence):** Format carry-forward? Other counters we haven't seen? Reset policy? Rollover policy?
2. **WorkOrder BIT flags (Flexware):** Which are live in production? `IsCameraProcessingEnabled`, `IsScaleProcessingEnabled`, `GroupTargetWeight` (+tolerance + UOM), `RecipeNumber`, `TrayQuantity`, `ReturnableDunnageCode`, `Customer`, `IsActive`.
3. **WorkCell policy flags:** `TrackingMode` (enumerate values), confirm `RequireCastPartAllocationOverride` behavior (OI-28).
4. **Historical data migration:** Cutover approach. Which entities migrate (LOTs, SerializedItems, ProductionOrders, Containers, Genealogy). Discrepancy review process for unmatched rows (e.g., Flexware `LotAttribute.DIE NAME` values with no matching `Tools.Tool.Code`).
5. **ShotCount semantics:** Cumulative counter on ProductionEvent, or derived from aggregated LOT quantities? (Open item per Decision 5.)
6. **Workstation `DefaultScreen` attribute seeding:** List of terminal-function Perspective views + which terminal routes to which.
7. **Honda AIM integration contract:** Confirm `GetNextNumber` return format, `PlaceOnHold` / `ReleaseFromHold` / `UpdateAim` full signatures, error recovery expectations.
8. **Label template scope:** Flexware has 3 templates (CONTAINER, LOT, CONTAINER_HOLD). Confirm ours will match that count + any new ones needed (Sort Cage, Hold, Void).
9. **Open items from prior list (OI-02, OI-04, OI-05, OI-07, OI-08, OI-11 confirmation, OI-13, OI-14, OI-15–23):** Status check — several revised/proposed at the 2026-04-20 meeting; confirm resolution and close where possible.

---

## Section 9 — Refactor Commit Plan for Next Session

Suggested commit sequence when the refresh pass executes:

1. `docs(oir): close OI-09 + OI-26, open OI-31` — Open Issues Register v2.7.
2. `docs(data-model): v1.9 — Tool/Cavity on Lot, ProductionEvent shape, IdentifierSequence` — Data Model v1.8 → v1.9.
3. `docs(fds): v0.11 — Tool on Lot, checkpoint events, identifier sequences` — FDS v0.10 → v0.11.
4. `docs(user-journeys): v0.8 — Carlos/Diane die cast & trim narrative updates` — User Journeys v0.7 → v0.8.
5. `docs(arc2): refresh phased plan for post-meeting + Phase G decisions` — update spec at `docs/superpowers/specs/2026-04-16-arc2-phased-plan-design.md` OR write the live plan.
6. `docs: regenerate ERD + docx artifacts` — per standing Phase F pattern.

---

## Section 10 — Untouched / Still Valid from Prior Sessions

Just to be explicit — the following do **NOT** need revisions from this session's decisions:

- Phase C security rewrite (initials + AD elevation) — locked in migration 0012, all procs current.
- Tools schema (§7 Data Model) — locked via G.1/G.2; only v1.9 addition is the downstream note about non-Die Tool assignment.
- All Phase 1–8 Config Tool procs — 216 procs, 853 tests, all passing.
- ContainerConfig.MaxParts + the Phase E additive consumption metadata — shipped in G.1/G.3.
- Audit streams (ConfigLog / FailureLog / OperationLog / InterfaceLog) and FDS-11-011 JDBC convention — locked.
- OI-11 reversal (no `Parts.ItemTransform`; 1-line BOM carries Casting→Trim) — locked.
- BIGINT/NVARCHAR/UpperCamelCase/DeprecatedAt conventions — locked.

---

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 0.1 | 2026-04-23 | Blue Ridge Automation | Initial writeup — full accounting of 2026-04-23 session decisions. Next-session refresh pass ready to execute. |
