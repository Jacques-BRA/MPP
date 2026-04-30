# MPP MES Replacement Project

## Project Context

Blue Ridge Automation is building a replacement MES for **Madison Precision Products** (Honda Tier 2 die cast aluminum supplier, Madison IN). Replacing the legacy WPF/.NET "Manufacturing Director" MES with an **Ignition Perspective + SQL Server 2022** system.

**Client:** Madison Precision Products, Inc. (Madison, IN)
**Contractor:** Blue Ridge Automation
**Domain:** Aluminum die casting — LOT traceability from raw aluminum through shipping. Honda requires full genealogy for every part.

## Key Terminology

- **FDS** = Functional Design Specification — Blue Ridge's design document ("how we build it")
- **FRS** = Functional Requirement Specification — Flexware's document ("what it needs to do"). We did NOT write the FRS; we are implementing against it.
- **LOT** = A collection of parts tracked as a unit through the plant, identified by a barcoded LTT (LOT Tracking Ticket)
- **LTT** = LOT Tracking Ticket — physical barcoded label on baskets/containers
- **AIM** = Honda's EDI system for shipping IDs and hold notifications
- **MIP** = Machine Integration Panel — PLC-side handshake interface at assembly stations
- **PD / Productivity Database** = Legacy custom app for production/downtime data entry that MES replaces

## Document Map — Read Order for New Agents

Start here and work down. Each document builds on the previous.

| # | Document | What It Is | When to Read |
|---|---|---|---|
| 0 | `README.md` | Project map for humans (and Claude) — folder structure, regeneration workflow, current status | First-time orientation |
| 1 | `MPP_MES_SUMMARY.md` | **Start here.** Master summary: project context, production flow, scope matrix (MVP/CONDITIONAL/FUTURE), data model overview, design decisions, reference doc findings, session notes, remaining tasks | Always — this is the project index |
| 2 | `MPP_MES_DATA_MODEL.md` | Column-level specification for every table across 7 schemas (~50 tables). DDL-ready. | When you need to understand or modify the schema |
| 3 | `MPP_MES_FDS.md` | Functional Design Specification v0.6 — all 15 sections + appendices. Numbered requirements (FDS-XX-NNN), FRS crosswalk, scope tags. Has its own Open Items Register (OI-01 through OI-10) at the bottom. | When working on design specifications or implementation |
| 4 | `MPP_MES_USER_JOURNEYS.md` | Two narrative arcs (Configuration Tool + Plant Floor "day in the life"). 19 validated assumptions/open decisions with an impact matrix. | When designing screens or understanding operator workflows |
| 5 | `MPP_MES_ERD.html` | Interactive ERD — 8 tabs (one per schema + master), table descriptions, pan/zoom, dark theme | Visual reference for schema relationships |
| 6 | `MPP_MES_Open_Issues_Register.md` (source) + `MPP_MES_Open_Issues_Register.docx` (generated) | v2.4 register with per-OI subsections (rebuilt 2026-04-21). Part A: 14 FDS open items (OI-01–OI-14). Part B: 19 user journey items (UJ-01–UJ-19). Regenerate docx via `pandoc MPP_MES_Open_Issues_Register.md -o MPP_MES_Open_Issues_Register.docx --reference-doc=reference.docx && node style_docx_tables.js MPP_MES_Open_Issues_Register.docx`. Edit the markdown source only. | When resolving open items or preparing for MPP meetings |
| 7 | `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md` | Phased development plan for the Configuration Tool (Arc 1) — 8 phases covering data model, Ignition Named Queries → stored proc layer, and Perspective frontend. Includes the Stored Procedure Template and Conventions section with the full template, error hierarchy, audit placement rules, and code-review checklist. | When planning Configuration Tool work or writing stored procedures |
| 8 | `MPP_MES_TASK_LIST_CONFIG_TOOL.csv` | 100-task derivative of the Phased Plan with estimates, dependencies, and status columns. Excel workbook at `MPP_MES_TASK_LIST_CONFIG_TOOL.xlsx` with three sheets (Tasks, By Phase, By Category). | When tracking Configuration Tool execution |
| 9 | `sql_best_practices_mes.md` | SQL design conventions and MES-specific patterns. Pre-existing — authored by Jacques. Governs all schema design decisions. Note: still references snake_case from before the 2026-04-09 convention change — needs refresh. | When writing or reviewing SQL |
| 10 | `sql_version_control_guide.md` | SQL version control workflow: migrations, SchemaVersion tracking, dev iteration loop, reset scripts, seed data, deployment process. General-purpose top half + MPP-specific overlay (naming, SP template, schema layout, AI rules). Companion to doc #9 — #9 covers *what SQL should look like*, #10 covers *how changes flow through environments*. | When writing migrations, setting up dev DBs, onboarding new engineers, or generating SQL with AI assistance |
| 11 | `MPP_MES_SEEDING_REGISTRY.md` (source) + `MPP_MES_SEEDING_REGISTRY.docx` (generated) | Single source of truth for seed data items sourced from outside Blue Ridge (MPP IT, Quality, Engineering, Honda, vendors). Status legend (Owed → Received → Loaded(Dev) → Verified(Cutover)), per-item detail (source, owner, target, mapping needs, loading proc, acceptance criteria). **Seed items are NOT design / SQL blockers** — they are deployment-time prerequisites collected in parallel with build. Internal code-table seeds baked into migrations are NOT tracked here. | When MPP delivers data, when assessing what's ready for cutover, when scoping work that depends on external data |

## Reference Material

| Location | Contents |
|---|---|
| `reference/MPP_FRS_Draft.pdf` | **Source FRS PDF** (Flexware v1.0, 6.7 MB). Use `pdftotext -table` for extracting tabular appendices. Page indexes: A=73-80, B=81-86, C=87-91, D=92-105, E=106-110, F=111-114, G=115-143. |
| `mpp_frs_md/` | 22 annotated FRS markdown files (older extract). Lower fidelity than `pdftotext -table` directly from PDF — prefer the PDF source for tabular content. |
| `mpp_frs_md/SPARK_DEPENDENCY_REGISTER.md` | Analysis of SparkMES dependencies and Blue Ridge design decisions for each |
| `reference/MPP_Scope_Matrix.xlsx` | **Scope authority** — the definitive in/out boundary. 37 rows: MVP, CONDITIONAL, FUTURE. |
| `reference/Excel Prod Sheets.xlsx` | Paper production sheet templates (what MES replaces) |
| `reference/MS1FM-*.xlsx` (11 files) | Line-specific production sheets with defect codes and shipping label tracking |
| `reference/5GO_AP4_Automation_Touchpoint_Agreement.pdf` | PLC integration spec — MIP touch points, handshake flows |
| `reference/seed_data/` | **Seed data CSVs** extracted from FRS Appendices B/C/D/E. 876 rows total — machines (209), opc_tags (161), downtime_reason_codes (353), defect_codes (153). README + parse_warnings inside. |
| `reference/seed_data.xlsx` | Auto-generated Excel workbook with all 4 seed CSVs as sheets (filter/sort UI). Regenerate via `node reference/seed_data/build_seed_workbook.js`. |

## Architecture at a Glance

- **Platform:** Ignition Gateway (Perspective for UI, Tag Historian for time-series, Gateway Scripts for background processing)
- **Database:** SQL Server 2022 Standard Edition, 7 schemas: `location`, `parts`, `lots`, `workorder`, `quality`, `oee`, `audit`
- **Auth:** Active Directory + Ignition roles. Clock number + PIN for shop floor. No custom RBAC tables.
- **PLC/OPC:** OmniServer (scales), TOPServer (assembly PLCs), Cognex (vision). MIP handshake for serialized lines.
- **External:** AIM (Honda EDI) via direct calls logged to `InterfaceLog` (per OI-01 resolution — no outbox). Zebra printers via ZPL.
- **Design patterns:** ISA-95 hierarchy with polymorphic three-tier location model (`LocationType` → `LocationTypeDefinition` → `LocationAttributeDefinition`), adjacency list genealogy, spec-driven quality, versioned BOMs/routes/specs, append-only event tables, materialized OEE snapshots (FUTURE), `DeprecatedAt` soft deletes, surrogate `Id` PKs everywhere.

## Scope Boundaries

| Status | Count | Rule |
|---|---|---|
| **MVP / MVP-EXPANDED** | 17 | Build and deliver |
| **CONDITIONAL** | 5 | Build only if MPP approves (Work Orders, Data Migration, Sampling, SCADA Alarming) |
| **FUTURE** | 15 | Schema supports it, but do NOT implement, populate, or test. Tables may exist as placeholders. |

When in doubt about scope, check `reference/MPP_Scope_Matrix.xlsx` — it is the authority.

## Current State (as of 2026-04-30)

**2026-04-20 OI review refactor fully landed (all phases A/B/C/D/E/F/G complete).** Post-refactor work through 2026-04-24:
- **Arc 2 Model Revisions (2026-04-23 session)** — 6 commits on 2026-04-23 lifted doc set to Data Model v1.9 / FDS v0.11 / UJ v0.8 / OIR v2.7 / Arc 2 Plan v0.2. Tool/Cavity promoted to `Lots.Lot`; ProductionEvent reshaped to checkpoint form; new `Lots.IdentifierSequence` table; `MaxLotSize` repurposed as `PartsPerBasket`; OI-09 closed (cavity-parallel LOTs as peers); OI-26 deleted; OI-31 opened.
- **2026-04-24 corrections + integrations:**
  - ERD full rebuild — every tab fully current to v1.9; Master tab rebuilt from v1.5 baseline; Audit `bigbigint` typos + OEE column mismatches fixed; Tools cross-schema FKs drawn (commits `2a91da0`, `70d0f37`).
  - Phase 0 + Phase 1 of Arc 2 Plan rewritten in-place (clock# + PIN removed from body, not just overlay) — commit `9121502`.
  - **OI-07 correction** — `WorkOrderType` corrected to single `Production` row; Demand + Maintenance moved to FUTURE hooks; Recipe deleted (commit `ce3e080`). The 2026-04-20 meeting note behind the original three-type model was mis-recorded.
  - **Storyboards + IPAddresses review** (commit `7550bb8`) — 2012 Flexware docs reviewed against v1.9 design. 83% coverage. Report at `reference/NewInput/REVIEW_2026-04-24.md`. OI-32 Material Allocation + OI-32b Material Classes opened.
  - **OI-31 single-line deployment memo for Ben** — `Meeting_Notes/2026-04-24_OI-31_Single-Line_Deployment_Impact.md`. Three mitigation options (prefix split recommended).
  - **Jacques's OIR review batch applied** (commit `6865d8d`, OIR v2.10) — 17 Part A OIs moved Resolved (OI-02, -04, -05, -08, -12, -13, -14, -15, -16, -17, -18, -19, -20, -21, -22, -23, -32b) + 2 UJ closures (UJ-02, UJ-04). Downstream per-item integration queue in progress.
- **Phase G SQL:** All five sub-phases (G.1–G.5) landed by 2026-04-23 (terminal commit `534f55c`). **853/853 tests passing** across 20+ test suites. Two correction migrations queued: **OI-07** (rename `WorkOrderType` seed Demand→Production + DELETE Recipe/Maintenance rows + update test 0019) and **OI-12** (DROP `Parts.ContainerConfig.MaxParts`, ADD `Parts.Item.MaxParts`).
- **Discovery OI items still Open:** OI-24 (Automation tile), OI-25 (Notifications), OI-27 (Supply part flag), OI-28 (cast-override cell flag), OI-29 (Workstation Category), OI-30 (Reports enumeration), OI-31 (IdentifierSequence — awaits Ben on rollout shape), OI-32 (Material Allocation — Jacques challenged the premise, Blue Ridge clarification response awaiting his confirmation).
- **Integration queue from OIR v2.10 — 7 of 8 landed** (2026-04-27): (1) OI-12 MaxParts ✅ `47a4e25`, (2) OI-18 ItemLocation cascade ✅ `0f7f40f`, (3) OI-08 Terminal mode ✅ `7a9d87e`, (4) OI-23 Lot derivations view ✅ `e393b7d`, (5) OI-16 PLC confirm + RequiresCompletionConfirm ✅ `55427f5`, (6) OI-21 Pausable LOT — design locked + landed ✅ `15edd5e`, (7) UJ-04 AIM pool — design locked + landed ✅ `82df891`. (8) OI-13 BOM export moved to seeding registry as S-06.
- **UJ enrichment + closure batch 2026-04-27** — 13 UJ entries enriched to OI-style depth in v2.13 (commit `483948e`); Jacques reviewed the docx and closed 10 in v2.14 (commit `a2b58f5`): UJ-07/-08/-11/-13/-14/-16 (Option A defaults), UJ-09 (Option C — strict + supervisor override), UJ-10 (Option D — shift-end summary), UJ-17 (Option A — ConfirmationMethod LocationAttribute), UJ-18 (Gateway-script-async architectural — FDS-01-014 + print-dispatch async pattern + ShippingLabel +5 print-state cols). Part B status: 16 Resolved, 1 In Review (UJ-03), 2 Open (UJ-05, UJ-19).
- **2026-04-28 working sessions — FDS continuity + clarity pass + indexing review.** FDS lifted from v0.11j → **v0.11m** across multiple amend-in-place sessions. Major edits: §1.4 layer diagram → table; §1.7 FDS-01-007 historian-DB-separation guidance added; §2.5 Cell Context Selection (scan **or** dropdown — was scan-only); FDS-02-010 mode-derivation table refreshed (Cell→Dedicated, WC→Shared, Area→Shared); FDS-02-012 expanded with BOM-derived eligibility (no per-component-per-Cell row explosion); §3.6 + §6.6 closure granularity corrected to **tray-level** (FDS-03-017 / FDS-06-013 / FDS-06-014 rewritten — `ClosureMethod` extended with `ByVision`); §5.10 + FDS-05-033 part-identity rename moved one step downstream from Casting→Trim to **Trim→Machining**; §5.4/§6.3/§6.4 Trim→Machining workflow reframe (sub-LOT split at Trim OUT not Machining IN; Machining OUT auto-completes via PLC and auto-moves to coupled Assembly Cell via new `CoupledDownstreamCellLocationId` LocationAttribute); §9.4 end-of-shift time entry (lunch + breaks only, ~15-min header window, dedicated = button press, shared = button + initials + select + submit); FDS-07-006b reframed from per-session bound-query to **Gateway-broadcast-with-session-filter** (one DB query per 5s regardless of terminal count); FDS-10-010 stranded "new column" callout removed (the `Quality.DefectCode.LeaderFlagOnFirstOccurrence` column never landed; branching is hardcoded by event-type); document-wide strip of project-execution decoration (Arc 2 / Phase N / version trailers / "Implementation deferred" admonitions / anti-pattern "we are not doing X" callouts / requirement-deletion tombstones). **Two new entries in embedded FDS Open Items Register: OI-33** (FDS-07-010a hard-fail behavior — customer validation, HIGH) and **OI-34** (How should MPP leverage authored production schedules beyond shift-window timing? — MEDIUM). **NOT YET synced to canonical OIR v2.14** — that's outstanding.
- **2026-04-28 standalone FDS Change Log doc** — `MPP_MES_FDS_CHANGELOG.md` + `.docx` created. Pre-release pattern: change log lives in companion doc while FDS is in active development; reintegrates into FDS at customer-review release. FDS body now has only a brief pointer to the changelog, no in-doc revision-history table.
- **2026-04-28 data model v1.9j** — `Parts.ContainerConfig.ClosureMethod` extended with `ByVision` value; UpperCamelCase casing applied (`ByCount` / `ByWeight` / `ByVision`); OI-02 caveat retired. Multiple data-model follow-ups flagged from FDS work but NOT yet landed: `Lots.ShippingLabel.BannerAcknowledgedAt DATETIME2(3) NULL`, `CoupledDownstreamCellLocationId` LocationAttributeDefinition seed under MachiningCell type, plus the indexing pass below.
- **2026-04-28 data model indexing & query-perf review** — full report at `Meeting_Notes/2026-04-28_DataModel_Indexing_Scaling_Review.md`. Phase 1–8 already-built schemas have good index coverage; the gap is the **deferred Arc 2 tables** (Lots event tables, Workorder.ConsumptionEvent / RejectEvent, Oee.DowntimeEvent, Quality.HoldEvent) — 14 tables × multiple indexes each need to be pinned in the data model spec before Arc 2 Phase 1 CREATE migrations are written. Three architectural concerns also flagged: 20-year audit retention strategy (partition vs archive job — not spec'd in FDS-11), `v_LotDerivedQuantities` materialization criteria, recursive-CTE depth limit on `LotGenealogy`. None of these are urgent; all are pre-Arc-2-Phase-1 decisions.
- **2026-04-30 — Arc 2 Plant Floor mockup + FDS amendments.** Substantial day building the operator-facing UI mockup and correcting two FDS sections.
  - **`mockup/plantFloor.html` + `mockup/plantFloor.css` + extracted `mockup/styles.css`** — 12 terminal/lot routes covering every operator surface in the Phased Plan v1.0: `home`, `terminal/initials`, `terminal/cell-context`, `terminal/diecast`, `terminal/trim-in`, `terminal/trim-out`, `terminal/machining-in`, `terminal/assembly`, `terminal/assembly-ns`, `terminal/sort-cage` (Serialized + Non-Serialized variants), `terminal/receiving`, `terminal/shipping`, `terminal/end-of-shift`, `lot/detail`. Home Page has plant-hierarchy tree dock + tabbed details panel (Location Details + LOT Search + Genealogy Lookup + Hold Management + Supervisor Dashboard with AIM Pool Wallboard tile). Cross-cutting modals: Elevation, BOM Rename, Idle Re-Confirm, Material Substitute Override, Change Cell Context. Print Failure Banner. Header has elevation toggle (mockup demo affordance), app-title-as-home-link, breadcrumb (terminal routes only), Config Tool nav-out (elevated only). Polymorphism via Flex Repeater + Embedded View. Per-action AD elevation pattern with secondary-color treatment for elevated buttons. 1080p scroll-free with inner-repeater scroll modifiers for high-N entity lists. Touch-friendly (44 px minimum touch targets, 56 px header).
  - **FDS v0.11m → v0.11n** (commit `361f6a4`): **FDS-09-013** End-of-Shift Time Entry — selection mechanism corrected to button-toggle on both terminal modes. 3 toggleable buttons (Lunch · 30 min, Break 1 · 15 min, Break 2 · 15 min) tap-to-select / tap-to-deselect. No numeric duration entry. Differences between Dedicated and Shared scoped to identity capture only (Shared adds inline initials field + 3-button single-select Time Category — Regular / Overtime / Double-Time). Zero-button submission valid (operator skipped breaks → no DowntimeEvent rows).
  - **FDS v0.11n → v0.11o** (commit `d7f889f`): **FDS-06-014** ByVision row corrected — camera scans the FULL TRAY as a single image, ONE validation event per tray (not per piece). Four-tray container = four passing tray-scan events. Per-tray `ConsumptionEvent` semantics clarified. New OPC tag names: `TrayPresent`, `TrayValidationResult`, `TrayFullFlag`. Same mechanic applies in Sort Cage non-serialized re-pack (uses the same camera).
  - **Phased Plan v1.0 implication flagged** — Phase 1's "Terminal Selector" placeholder is structurally a Home Page (plant browser) for elevated desktop users, not a generic Terminal Selector. Mockup proves the model; Phased Plan + FDS will be updated at next pass to match. Companion FDS-02 paragraph also pending.
- **2026-04-29 — multi-doc reconciliation + scaling-gate tracking + Phased Plan rebuild + DM column add.** Five commits over the day landed substantial work:
  - **OIR sync + DM column adds** (commit `c7ca780`) — DM v1.9j → v1.9k. `Lots.ShippingLabel.BannerAcknowledgedAt DATETIME2(3) NULL` added (FDS-07-006b broadcast-script Acknowledge action). `CoupledDownstreamCellLocationId` LocationAttributeDefinition seeded under `CNCMachine` (FDS-06-008 auto-move target). OIR v2.14 → v2.15 — OI-33 (AIM pool empty-pool hard-fail customer validation, HIGH) + OI-34 (production schedules leverage, MEDIUM) folded from embedded FDS register into canonical OIR. OIR v2.15 → v2.16 — **OI-35 NEW (HIGH) "MUST DECIDE BEFORE ARC 2 PHASE 1 SQL BUILD"** — long-horizon scaling, retention, archiving strategy. 8 architectural decisions: per-table retention class, monthly partitioning, columnstore on aged partitions, materialized closure table for LotGenealogy, materialize TotalInProcess/InventoryAvailable on Lot, IdentifierSequence_Next locking model (row-locked vs SEQUENCE), OperationLog split (7yr general + 20yr LotEventLog), filtered indexes on hot subsets. Items 2/4/5/7 must be in CREATE migration. Last-responsible-moment posture confirmed by Jacques — Arc 2 Phase 1 SQL build does not commence until OI-35 is decided. Indexing review meeting note updated with Decision Gate callout.
  - **DM v1.9l + UJ v0.9 reconciliation** (commit `3851802`) — comprehensive sweep aligning DM and UJ to FDS v0.11m. DM v1.9k → v1.9l: ContainerConfig `ByVision` reframed as tray-level trigger; "Casting → Trim" subsection retitled "Trim → Machining" with full BOM example rewrite (5G0-TRIM Component + 5G0-MACHINED Sub-Assembly); `Parts.v_EffectiveItemLocation` view documented (Direct ∪ BomDerived per FDS-02-012); deferred event tables (WorkOrderOperation, ConsumptionEvent, RejectEvent, DowntimeEvent) renamed `OperatorId` → `AppUserId` consistent with SP template + ProductionEvent v1.9 reshape; UJ-14 + UJ-16 PENDING callouts converted to resolved-prose; 5 Arc 2 admonitions stripped (DM is the big-picture end-goal spec); WorkOrderType SQL correction marked landed; Tools cross-references rewritten. UJ v0.8 → v0.9: 4 high-impact scene rewrites — Trim Shop ("Trim is yield loss, not a rename" + "Trim OUT split + route to Machining FIFO" added); Machining scene (FIFO pick + BOM rename at IN, PLC-driven auto-move at OUT); 11:30am Assembly tray-level closure with three peer methods + configured-value references (no hardcoded 4×12); End of Shift FDS-09-013 single-submission rewrite ("Second shift badges in" removed). Assumption status flips: UJ-12, UJ-14, UJ-16, UJ-18 → ✅ Resolved.
  - **Phased Plan Plant Floor v0.3 → v1.0 full rebuild + DM v1.9m** (commit `cf11542`) — complete document rebuild from current source-of-truth docs. 1825 lines (down from v0.3's 2077). Phase shape preserved (9 phases, 0–8). Cross-Cutting Concerns B1–B17 lifted verbatim with B12 reframed for **Flex Repeater + Embedded View** as the polymorphic primitive (per Jacques's correction during review — top-level views are purpose-built, polymorphism lives at embedded-component level). NEW Seeding Registry — Phase Coupling section maps S-01..S-11 to phases. Phase 0 expanded with parallel **Architecture Decision Workshop** track (OI-35 — 8 decisions). Phase 1 bakes OI-35 architectural decisions into the migration on day one. Phase 3 Die Cast walkthrough corrected for **Shared terminal model** (operator selects active Cell context by scan or dropdown; Die Cast presses parented to Area/WorkCenter, not Cell). Phase 3 separate "Die Cast LOT Detail" view dropped — uses polymorphic Phase 2 LOT Detail. Phase 4 Trim OUT branches on `Parts.OperationTemplate.RequiresSubLotSplit` flag (split + per-child Cell routing OR move whole). Phase 5 Machining whole rewrite (FIFO pick + BOM rename at IN per FDS-05-033; PLC-driven auto-complete + auto-move via CoupledDownstreamCellLocationId at OUT per FDS-06-008; no operator OUT view). Phase 6 Assembly tray-level closure with three peer methods + atomic Container_Complete claiming AIM ID from Phase 7's pool. Phase 7 AIM pool topup loop + tier alarms + ContainerSerialHistory (UJ-05 default). Phase 8 FDS-09-013 end-of-shift entry + FDS-09-015 shift-end summary. Migration numbering rebased — Phase 1 lands at `0014_arc2_phase1_shop_floor_foundation.sql`. **DM v1.9l → v1.9m** companion: `Parts.OperationTemplate.RequiresSubLotSplit BIT NOT NULL DEFAULT 0` added; gives FDS-05-009 split decision a queryable home. Personas (Carlos/Diane/Maria) scrubbed throughout — neutral voice. SQL ALTER lands in Phase 4 migration `0017`.

Source-of-truth docs: `MPP_MES_DATA_MODEL.docx` **v1.9m** (2026-04-29 — RequiresSubLotSplit on OperationTemplate), `MPP_MES_FDS.docx` **v0.11o** (2026-04-30 — FDS-09-013 button-toggle EOS entry + FDS-06-014 ByVision per-tray scan; revision history in `MPP_MES_FDS_CHANGELOG.docx`), `MPP_MES_FDS_CHANGELOG.docx` (pre-release companion carrying revision history), `MPP_MES_Open_Issues_Register.docx` **v2.16** (2026-04-29 — OI-33, OI-34, OI-35 added; OI-35 is the HIGH-priority architecture gate for Arc 2 Phase 1 SQL), `MPP_MES_USER_JOURNEYS.docx` **v0.9** (2026-04-29 — FDS v0.11m reconciliation pass; 4 scene rewrites + 4 assumption closures), `MPP_MES_PHASED_PLAN_PLANT_FLOOR.docx` **v1.0** (2026-04-29 — full rebuild; 9 phases with Phase 0 dual-track + Phase 4 RequiresSubLotSplit branch + Phase 5 PLC-driven Machining OUT + Phase 6 tray-level closure), `MPP_MES_ERD.html` (current through v1.9i; pending refresh for v1.9j-m additions: ClosureMethod values, BannerAcknowledgedAt, CoupledDownstreamCellLocationId, RequiresSubLotSplit), `MPP_MES_SEEDING_REGISTRY.docx` v1.0. Arc 2 revisions spec at `docs/superpowers/specs/2026-04-23-arc2-model-revisions.md` (still untracked in working tree). Indexing review: `Meeting_Notes/2026-04-28_DataModel_Indexing_Scaling_Review.md` (Decision Gate callout for OI-35). Phase G capability snapshot: `Meeting_Notes/2026-04-22_Phase_G_Capabilities_Summary.md`.

- **Data model:** **v1.9m (rev 2026-04-29)** — 8 schemas, ~76 tables. Latest additions: `Parts.OperationTemplate.RequiresSubLotSplit BIT NOT NULL DEFAULT 0` (v1.9m — controls Phase 4 Trim OUT split-vs-move branch per FDS-05-009); v1.9l reconciliation pass against FDS v0.11m (deferred event tables aligned to AppUserId, `v_EffectiveItemLocation` view documented, ContainerConfig `ByVision` reframed as tray-level, "Trim → Machining" rename retitle, terminal-mode-by-tier wording, Arc 2 admonitions stripped); v1.9k (BannerAcknowledgedAt + CoupledDownstreamCellLocationId seed); v1.9j (ByVision ClosureMethod). Earlier landmarks: PauseEvent + AimShipperIdPool/Config + ShippingLabel print-state cols (v1.9g/h/i); Tool/Cavity on Lot + ProductionEvent checkpoint shape + IdentifierSequence (v1.9); WorkOrderType single Production seed (v1.9b); MaxParts on Parts.Item (v1.9c); ItemLocation cascade (v1.9d); v_LotDerivedQuantities view (v1.9e); RequiresCompletionConfirm (v1.9f). 8 schemas: Location, Parts, Lots, Workorder, Quality, OEE, Tools, Audit. BIGINT PKs/FKs everywhere, NVARCHAR. Location three-tier polymorphic model. Audit 4 log streams. All enum/status columns code-table backed with FKs. User attribution via `BIGINT FK → AppUser.Id`. AppUser initials-based security model. HoldEvent + PauseEvent + DowntimeEvent open + close lifecycle. SortOrder + MoveUp/MoveDown on Location.Location. Three-state Draft/Published/Deprecated versioning on Bom, RouteTemplate, OperationTemplate, QualitySpec.
- **FDS:** **v0.11o** (rev 2026-04-30) — all 15 sections. **v0.11o**: FDS-06-014 ByVision row — camera scans full tray as a single image, one validation event per tray. **v0.11n**: FDS-09-013 End-of-Shift entry — button-toggle selection on both terminal modes. **v0.11m**: continuity + clarity pass with workflow reframes (Trim→Machining rename, Trim OUT split, PLC-driven Machining OUT auto-move, tray-level closure). Multi-session continuity + clarity pass with three workflow reframes: sub-LOT split moved Machining IN → **Trim OUT** (FDS-05-009); part-identity rename moved Casting→Trim → **Trim→Machining** (FDS-05-033); Machining OUT became event-driven PLC-auto-complete + auto-move via `CoupledDownstreamCellLocationId` LocationAttribute (FDS-06-008). Container closure granularity moved container-level → **tray-level** with three peer methods (FDS-06-014). End-of-shift time entry single submission with shift-schedule durations, no minute adjustments (FDS-09-013). FDS-07-006b reframed as Gateway-broadcast-with-session-filter. Cross-cutting integration pattern (FDS-01-014, UJ-18) — Gateway-script-async via `system.util.sendMessage` / `sendRequestAsync`. Two new entries in embedded OI register: **OI-33** (FDS-07-010a hard-fail customer validation) + **OI-34** (production schedules leverage). Standalone changelog companion `MPP_MES_FDS_CHANGELOG.docx` carries revision history pre-release. §11 Audit four log streams + FDS-11-011 single-result-set convention. §4 security: initials-based + per-action AD elevation. FDS appendices remain placeholder.
- **User Journeys:** **v0.9 (rev 2026-04-29)** — 19 narrative assumptions across two arcs (Configuration Tool + Plant Floor). FDS v0.11m reconciliation: 4 high-impact scene rewrites (Trim Shop yield-loss + Trim OUT split-and-route; Machining scene FIFO pick + BOM rename + PLC OUT; 11:30am Assembly tray-level closure with three methods using configured `TraysPerContainer × PartsPerTray` not hardcoded; End of Shift FDS-09-013 single-submission with shift-schedule durations). Personas (Carlos/Diane) preserved as narrative anchors. UJ-12, UJ-14, UJ-16, UJ-18 → ✅ Resolved.
- **Open Issues Register:** **v2.16 (rev 2026-04-29)** — sectioned per-OI markdown. Counts: Part A 35 items (22 Resolved, 1 In Review = OI-07, 11 Open = OI-24/-25/-27/-28/-29/-30/-31/-32/-33/-34/-35, 1 Superseded = OI-10); Part B 19 items (16 Resolved, 1 In Review = UJ-03, 2 Open = UJ-05/UJ-19). v2.15 added OI-33 (AIM hard-fail customer validation, HIGH) + OI-34 (production schedules leverage, MEDIUM). v2.16 added **OI-35** (long-horizon scaling/retention/archiving, HIGH — "MUST DECIDE BEFORE ARC 2 PHASE 1 SQL BUILD"). Regenerate docx via `pandoc MPP_MES_Open_Issues_Register.md -o MPP_MES_Open_Issues_Register.docx --reference-doc=reference.docx && node style_docx_tables.js MPP_MES_Open_Issues_Register.docx`.
- **ERD:** Interactive HTML, 8 tabs. **Pending refresh** for the v1.9j–m doc additions: ClosureMethod values (`ByCount`/`ByWeight`/`ByVision`), `Lots.ShippingLabel.BannerAcknowledgedAt`, `CoupledDownstreamCellLocationId` LocationAttribute under `CNCMachine`, `Parts.OperationTemplate.RequiresSubLotSplit`. Per-schema tabs are the source of truth and remain canonical visual reference until next regen.
- **Phased Development Plan (Configuration Tool — Arc 1):** v1.7 — 8 phases, **all 8 built and tested**. SP template uses `RAISERROR` in CATCH blocks with nested TRY/CATCH. No drag-and-drop. All DB references schema-qualified. Separate file: `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md`. Task list at `MPP_MES_TASK_LIST_CONFIG_TOOL.csv`.
- **Phased Development Plan (Plant Floor — Arc 2):** **v1.0 (rev 2026-04-29) — full rebuild from v0.3.** 9 phases (0–8), 1825 lines. Phase 0 has parallel Customer Validation + Architecture Decision tracks (OI-35 — 8 architectural decisions gating Phase 1 SQL). Phase 1 bakes OI-35 decisions into the migration on day one. Phase 4 Trim OUT branches on `Parts.OperationTemplate.RequiresSubLotSplit`. Phase 5 Machining IN = FIFO pick + BOM rename; Machining OUT = PLC-driven auto-complete + auto-move. Phase 6 Assembly tray-level closure with three peer ClosureMethods. Phase 7 AIM pool topup + tier alarms. Phase 8 FDS-09-013 end-of-shift entry. Cross-Cutting Concerns B1–B17 normative. **Polymorphism principle:** top-level views are purpose-built per workflow; polymorphism lives at embedded-component level (Flex Repeater + Embedded View as canonical pattern). Migration numbering rebased: Phase 1 lands at `0014`. NEW Seeding Registry — Phase Coupling section maps S-01..S-11 to phases.
- **Phase B Tool Management design spec:** ✅ **Approved 2026-04-21** (commit `47ce9c7`). Full schema spec at `docs/superpowers/specs/2026-04-21-tool-management-design.md` v0.2. Implementation target: Phase G SQL migration `0010_phase9_tools_and_workorder.sql`. Same migration drops the legacy `AppUser.ClockNumber` and `.PinHash` columns.
- **Legacy PDF references:** `reference/Manufacturing Director Technical Manual.pdf` (2009 Flexware doc) was converted to searchable Markdown at `reference/Manufacturing_Director_Technical_Manual.md` on 2026-04-21. Converter `reference/scripts/convert_mdtm_to_md.js` reusable for future Flexware docs.
- **SQL scripts:** Phases 1–8 + G.1/G.2 complete. `/sql/` folder with **10 versioned migrations + 216 repeatable procs** (was 9/171 before 2026-04-22). **779 passing tests** across 20 test suites (no regressions from G.1 or G.2; new test suites for Tools/Phase E queued in G.5). Phase 8 adds 4 Oee tables (`DowntimeReasonType` seed-only, `DowntimeReasonCode` CRUD + JSON bulk-load, `ShiftSchedule` CRUD, `Shift` runtime-only with config-tool `_List`) and 13 new procs. PowerShell reset script (`Reset-DevDatabase.ps1`) auto-discovers and runs all scripts via `sqlcmd.exe`, creates dev-only `ignition` SQL login with `db_owner` on every reset. Tested successfully on SQL Server 2025.
- **SQL workflow:** `sql_version_control_guide.md` — general-purpose top half + MPP-specific overlay (naming, SP template, schema layout, AI rules). PowerShell reset script replaces the old SQLCMD-mode `.sql` approach.
- **Word output:** All markdown docs have bordered + alternating-row styled Word versions. Regenerate via `pandoc ... --reference-doc=reference.docx` + `node style_docx_tables.js <file.docx>`.
- **Seed data:** 876 rows extracted from FRS Appendices B/C/D/E into CSVs in `reference/seed_data/`, plus auto-generated `reference/seed_data.xlsx`. Per-appendix Node.js parsers in `reference/seed_data/parsers/` handle multi-line wrapped descriptions. Source PDF is `reference/MPP_FRS_Draft.pdf`.
- **NOT started:** Ignition project, Perspective screens, **seed data loading** (CSVs ready — machines.csv not yet loaded into Location rows; MPP parts list not yet provided; defect_codes.csv not yet loaded; downtime_reason_codes.csv has a bulk-load proc `Oee.DowntimeReasonCode_BulkLoadFromSeed` but hasn't been invoked against the 353-row CSV), PLC integration.

## Ignition JDBC Compatibility — REFACTOR COMPLETE

**Convention (FDS-11-011):** Stored procedures SHALL NOT use `OUTPUT` parameters. The Ignition JDBC driver reads OUTPUT params as the first result set and ignores subsequent SELECT data.

**Rules:**
- **Read procs:** No OUTPUT params. Empty result set = not found (no invented 404).
- **Mutation procs:** `@Status`, `@Message`, `@NewId` are local variables. Every exit path ends with `SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;` (drop `@NewId AS NewId` for Update/Deprecate — those return `SELECT Status, Message` only).
- **Audit writers (`Audit.Audit_Log*`):** Emit no result set — they run inside mutation-proc transactions; emitting would break INSERT-EXEC + ROLLBACK.
- **One result set per proc:** If the legacy design returned two, drop the second and have callers use the sibling List proc.

**Status:** Refactor complete across all 171 procs. Every new proc follows this convention.

### Test patterns

**Read procs:** INSERT-EXEC into a temp table matching the SELECT shape, assert row count from the temp table.
```sql
CREATE TABLE #R (Id BIGINT, Code NVARCHAR(50), Name NVARCHAR(100));
INSERT INTO #R EXEC Lots.ContainerStatusCode_List;
DECLARE @Count INT;
SELECT @Count = COUNT(*) FROM #R;
DROP TABLE #R;
-- Then assert @Count
```

**Mutation procs (converted):** Same pattern — INSERT-EXEC into `(Status, Message, NewId)` temp table.
```sql
CREATE TABLE #Result (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #Result EXEC Schema.Proc_Create @Param1 = ..., @AppUserId = 1;
SELECT @Status = Status, @NewId = NewId FROM #Result;
DROP TABLE #Result;
```

## Outstanding for Next Session — **present these first**

**Doc set is current end-to-end as of 2026-04-29.** All four primary docs synced to FDS v0.11m as source of truth: Data Model v1.9m, User Journeys v0.9, Open Issues Register v2.16, Phased Plan Plant Floor v1.0 (full rebuild). What's left:

### 🚨 GATE — OI-35 must resolve before Arc 2 Phase 1 SQL build commences

**Long-horizon scaling, retention, archiving strategy.** HIGH priority. Last-responsible-moment posture confirmed by Jacques 2026-04-29. Eight architectural decisions: per-table retention class (push back on 20-yr for Audit.OperationLog/InterfaceLog/FailureLog), monthly partitioning + sliding-window automation across ~14 high-volume event tables, columnstore on aged partitions (>90 days), materialized closure table for `Lots.LotGenealogy` (Honda audit O(1) vs recursive CTE at year 15), materialize `TotalInProcess` / `InventoryAvailable` columns onto `Lots.Lot` (supersedes OI-23 view choice at scale), `Lots.IdentifierSequence_Next` locking model (row-locked vs SQL Server `SEQUENCE`), split `Audit.OperationLog` into 7-yr general + 20-yr `Lots.LotEventLog`, filtered indexes on hot subsets. Items 2/4/5/7 must be in the CREATE migration — retrofitting partition schemes, closure tables, or materialization columns to populated 100M+ row tables is operationally expensive. Resolution path: internal Blue Ridge architecture review + MPP IT retention-policy negotiation (single meeting). Output: data model § "Scaling Decisions" + FDS-11 retention paragraph + Phase 1 migration content. Background at `Meeting_Notes/2026-04-28_DataModel_Indexing_Scaling_Review.md`.

### Phase 0 facilitation workshop with MPP — Track A (9 items)

Track A is the customer-validation gate. Track B is the architecture workshop above (OI-35).

1. **OI-31** — IdentifierSequence cutover seed values + Ben's rollout-shape decision (memo at `Meeting_Notes/2026-04-24_OI-31_Single-Line_Deployment_Impact.md`).
2. **FDS-06-030** — WorkOrder BIT-flag enumeration.
3. **Historical data migration** — entity list + pre-flight validation + discrepancy review.
4. **ShotCount semantics** — cumulative counter (current default) vs derived from aggregated LOT quantity.
5. **Workstation `DefaultScreen` + `ConfirmationMethod` seeding** — per-Cell Perspective-view list + per-Cell `ConfirmationMethod` value (Vision/Barcode/Both).
6. **Honda AIM Hold/Update contract detail** — `PlaceOnHold` / `ReleaseFromHold` / `UpdateAim` signatures + error recovery (UJ-04 GetNextNumber pool flow already locked).
7. **Label template scope** — Flexware has 3 templates (CONTAINER / LOT / CONTAINER_HOLD); confirm matches + any new (Sort Cage / Hold / Void). Couples to S-09 in Seeding Registry.
8. **OI-32 Material Allocation operator screen** — premise challenged in OIR v2.10; clarification queued.
9. **OI-33 AIM pool empty-pool hard-fail customer validation** — confirm hard-fail is the desired posture (production stops on affected lines until pool refills; no soft-fallback).

### Open Part B UJs

- **UJ-03** sublot split trigger — In Review (Ben pending). Resolved structurally via `Parts.OperationTemplate.RequiresSubLotSplit` (Phase 4); remaining Ben input is per-Item override quantities.
- **UJ-05** Sort Cage serial migration — default direction committed (update-in-place + `Lots.ContainerSerialHistory`); awaits MPP Quality + Honda compliance affirmation.
- **UJ-19** Productivity DB replacement — MPP names the four PD reports; couples to OI-30 Reports tile.

### Discovery items still Open (OIR Part A)

OI-24 Automation tile, OI-25 Notifications, OI-27 Supply part flag, OI-28 cast-override cell flag, OI-29 Workstation Category, OI-30 Reports enumeration, OI-34 production schedule leverage. Handled in respective phase walkthroughs as MPP brings input.

### SQL queue — Blue Ridge owns (gated on Phase 0)

1. ✅ **OI-07 + OI-12 correction migrations** — landed 2026-04-28 as `0013_oi07_oi12_corrections.sql`. 858/858 tests passing.
2. **Arc 2 Phase 1 SQL implementation** — lands at `0014_arc2_phase1_shop_floor_foundation.sql`. **GATED on Phase 0 — both tracks (Customer Validation + Architecture Decision)** before commencement. Phase 1 plan body is now authoritative — bakes OI-35 architectural decisions into the migration on day one (partition functions, closure table if elected, materialization columns if elected, OperationLog split if elected, filtered indexes per B8). Includes the Phase 4 Data Model column add `Parts.OperationTemplate.RequiresSubLotSplit` if not landed earlier as its own migration.
3. **Phases 2–8 SQL** — sequential per the rebuilt plan. Phase 4 migration `0017` includes the `RequiresSubLotSplit` ALTER if not already shipped.

### ERD refresh queue

ERD pending refresh for v1.9j–m additions: ClosureMethod values (`ByCount` / `ByWeight` / `ByVision`), `Lots.ShippingLabel.BannerAcknowledgedAt`, `CoupledDownstreamCellLocationId` LocationAttribute under `CNCMachine`, `Parts.OperationTemplate.RequiresSubLotSplit`. Per-schema tabs are the source of truth and remain canonical until next regen.

### Non-blocking polish

- Memory file revision-history-format trim: applied to FDS only; not yet to Data Model + OIR.
- FDS-06-028 wording sharpen — WO Auto-Finish (§6.10) prose still mentions "camera-count mode" pre-tray-reframe. Low priority.

---

## Remaining Tasks

See `MPP_MES_SUMMARY.md` "Remaining Tasks" section for the full list. Key items as of 2026-04-29:

**Decision blockers (not seed-data — these genuinely gate downstream work):**
1. **OI-35 Architecture Decision Workshop** — long-horizon scaling/retention/archiving. Blue Ridge architecture lead + MPP IT (retention-policy negotiation). Gates Arc 2 Phase 1 SQL build commencement.
2. **Phase 0 Customer Validation Workshop with MPP** — 9 gating items (see Outstanding section above). Gates Arc 2 Phase 1 SQL build commencement.
3. **Ben** — OI-31 rollout shape decision (single-line vs full-cutover vs shadow); memo at `Meeting_Notes/2026-04-24_OI-31_Single-Line_Deployment_Impact.md`.
4. **Tom (security SME)** — final elevated-action list validation (FDS-04-007).

**SQL queue:**
- ✅ **OI-07 + OI-12 correction migrations** — landed 2026-04-28 as `0013_oi07_oi12_corrections.sql`. 858/858 tests passing.
- **Arc 2 Phase 1 SQL** (`0014_arc2_phase1_shop_floor_foundation.sql`) — gated on Phase 0 (both tracks).
- **Phases 2–8 SQL** — sequential after Phase 1 per Phased Plan v1.0 (migrations `0015`–`0021`).

**Seed-data items — tracked in `MPP_MES_SEEDING_REGISTRY.md` (NOT blockers).** S-01 through S-11 cover plant equipment, downtime/defect codes, OPC tags, parts master, BOM export (OI-13/S-06), die ranks + compatibility, label types, identifier sequence baselines, and AIM pool tuning. Only S-08 (DieRankCompatibility) is a true blocker (with a supervisor-override workaround). Phase Coupling table now lives in the Phased Plan v1.0.

**Non-SQL work:**
1. Complete FDS appendices (currently placeholder references).
2. Map scope matrix rows + paper production sheet fields to FDS sections.
3. ERD refresh for v1.9j–m additions.
4. Ignition Perspective frontend build not started — gated on Phase 0 + Phase 1 SQL.

**OIR status (v2.16, 2026-04-29):** 38 resolved, 2 in review, 13 open, 1 superseded across 54 items. Open Part A discovery items: OI-24/-25/-27/-28/-29/-30 (MPP input pending). Open Part A architectural: OI-31/-32/-33/-34/-35 (Phase 0 workshop topics). Open Part B: UJ-05 (Sort Cage serial migration — MPP Quality + Honda), UJ-19 (PD replacement). In Review: OI-07 (correction landed; status flag pending close), UJ-03 (sublot trigger — Ben).

## Conventions

- **SQL:** Follow `sql_best_practices_mes.md` and `sql_version_control_guide.md` — UpperCamelCase tables and columns, `BIGINT` surrogate `Id` PKs, `NVARCHAR` (never VARCHAR), `DeprecatedAt` soft deletes, `DATETIME2(3)`, `DECIMAL` not `FLOAT`, all enum/status values code-table backed with FK, user attribution via `BIGINT FK → AppUser.Id` (never free-text), append-only events.
- **SP template:** ⚠️ **REFACTOR IN PROGRESS** — Converting from `OUTPUT` params to `SELECT`-based returns for Ignition JDBC compatibility. See "Ignition JDBC Compatibility" section above. Old pattern: `@Status BIT OUTPUT` + `@Message NVARCHAR(500) OUTPUT`. New pattern: local variables + final `SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;`. Three-tier error hierarchy, `RAISERROR` (not `THROW`) in CATCH blocks with nested failure logging. See `sql/scripts/_TEMPLATE_stored_procedure.sql`.
- **UI:** No drag-and-drop anywhere — up/down arrow buttons for all sortable lists.
- **FDS requirements:** Numbered `FDS-XX-NNN` (section-sequence). Keywords per RFC 2119: SHALL, SHALL NOT, SHOULD, MAY, FUTURE.
- **Scope tags:** Every section and table is tagged MVP, MVP-EXPANDED, CONDITIONAL, or FUTURE.
- **FRS crosswalk:** FDS requirements reference originating FRS IDs in parentheses, e.g., `(FRS 3.9.6)`.
