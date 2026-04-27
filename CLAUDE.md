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

## Current State (as of 2026-04-24)

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
- **UJ insufficiency noted** — Jacques flagged 2026-04-24 that UJ entries lack the options/impact depth of OI entries. Enrichment pass queued before next MPP review.

Source-of-truth docs: `MPP_MES_DATA_MODEL.md` v1.9h, `MPP_MES_FDS.md` v0.11i, `MPP_MES_Open_Issues_Register.md` v2.12, `MPP_MES_USER_JOURNEYS.md` v0.8, `MPP_MES_PHASED_PLAN_PLANT_FLOOR.md` v0.2b, `MPP_MES_ERD.html` (current through v1.9h, Master tab regen queued), `MPP_MES_SEEDING_REGISTRY.md` v1.0. Arc 2 revisions spec at `docs/superpowers/specs/2026-04-23-arc2-model-revisions.md` (still untracked in working tree). Phase G capability snapshot: `Meeting_Notes/2026-04-22_Phase_G_Capabilities_Summary.md`.

- **Data model:** v1.8 (rev 2026-04-22) — 8 schemas, ~72 tables. **v1.8 — Phase E additive changes:** `Parts.Item.CountryOfOrigin NVARCHAR(2)` (OI-19), `Parts.ItemLocation` + `MinQuantity` / `MaxQuantity` / `DefaultQuantity` / `IsConsumptionPoint` (OI-18), `Parts.ContainerConfig.MaxParts` (OI-12), Cell `LinesideLimit` LocationAttribute (OI-12), new `Workorder.ScrapSource` code table (OI-20; `Workorder.ProductionEvent.ScrapSourceId` FK baked in by Arc 2 Phase 1 — ProductionEvent table doesn't exist yet). **OI-11 resolved via 1-line BOM** (no new schema) — Casting → Trim rename is a degenerate 1-line BOM consumption; `Parts.ItemTransform` was drafted then reverted 2026-04-22 as fully redundant with `Workorder.ConsumptionEvent`. `Audit.LogEntityType` +1 row in Phase G (ScrapSource; ItemTransform reservation dropped). All additive — no breaking changes. Phase G migration `0010_phase9_tools_and_workorder.sql` landed 2026-04-22 (Tools schema + 2 code tables + 3 Parts ALTERs + 9 LogEntityType rows; 779/779 tests still pass). BIGINT PKs/FKs everywhere, NVARCHAR (no VARCHAR). Location schema uses three-tier polymorphic model. Audit schema has 4 log streams. All enum/status columns are code-table backed with FKs. User attribution via `BIGINT FK → AppUser.Id`. OperationTemplate data collection is configurable via junction (no hardcoded BIT flags). HoldEvent is a single place/release lifecycle table. SortOrder on Location.Location with MoveUp/MoveDown. v1.4 closed the template→event capture gap: `Workorder.ProductionEvent` gained `OperationTemplateId` FK + hot typed columns (`DieIdentifier`, `CavityNumber`, `WeightValue`+`WeightUomId`) and new `Workorder.ProductionEventValue` child table for extensible `DataCollectionField` capture. v1.5 added the Phase 8 Oee reference tables (`DowntimeReasonType` seed-only, `DowntimeReasonCode`, `ShiftSchedule` with `DaysOfWeekBitmask INT`, `Shift` runtime). **v1.6 (2026-04-21):** `Location.AppUser` realigned to the initials-based security model — `Initials NOT NULL UNIQUE`, `AdAccount` nullable with filtered UNIQUE, CHECK binding `IgnitionRole` to `AdAccount` presence; `ClockNumber` + `PinHash` flagged legacy for Phase G removal. **v1.7 (2026-04-21) — Phase B data-model rollup landed.** New `Tools` schema (§7) with 10 tables: `ToolType` (seeded read-only, `HasCavities` flag), `ToolAttributeDefinition`, `Tool` (nullable `DieRankId` — Die-type only, no shot counter), `ToolAttribute`, `ToolCavity` (3-state Active/Closed/Scrapped), `ToolAssignment` (append-only check-in/out with filtered UNIQUE on active mount), `ToolStatusCode` + `ToolCavityStatusCode` (read-only), `DieRank` + `DieRankCompatibility` (both empty seed — MPP Quality owes). `Workorder.WorkOrder` gains `WorkOrderTypeId` (NOT NULL DEFAULT `Production`-Id per OI-07 correction 2026-04-24; originally defaulted to `Demand`-Id, corrected in v1.9b) and nullable `ToolId` FK → Tools.Tool. New `Workorder.WorkOrderType` code table — **v1.9b seed is 1 row (`Production`)**. The originally-shipped 3-row seed (`Demand`/`Maintenance`/`Recipe`) was corrected when Jacques clarified the 2026-04-20 meeting note had been mis-recorded: the "Recipe" line was describing the same Production flow; `Demand` and `Maintenance` are genuinely separate future WO types (planned PM + emergency) but are FUTURE — not built in this project. Code table stays as a future hook. SQL seed correction migration queued. Audit Schema renumbered to §8. Phase G migration `0010_phase9_tools_and_workorder.sql` delivers the SQL + drops legacy AppUser.ClockNumber + PinHash.
- **FDS:** v0.10 (rev 2026-04-22) working draft — all 15 sections + appendix placeholders. **v0.10 — Phase E:** §5.10 Part Identity Change Casting→Trim via 1-line BOM (FDS-05-033; the earlier draft's FDS-05-034/-035 plus the proposed `Parts.ItemTransform` table were retired 2026-04-22 as redundant with `Workorder.ConsumptionEvent`), new §12.5 Global Trace Tool (FDS-12-012..014, OI-15), +requirements across §§1.4 (FDS-01-013 BOM source), 3.1 (CountryOfOrigin), 3.5 (FDS-03-018 consumption metadata), 3.6 (FDS-03-019 MaxParts, 03-020 LinesideLimit, 03-021 tray-divisibility), 4.3 (admin remove-item in elevated list), 5.1 (FDS-05-031 computed lot quantities), 5.3 (FDS-05-032 partial start/complete), 6.8 (FDS-06-023a ScrapSource), 6.10 (FDS-06-028 auto-finish-on-target, 06-029 tray-divisibility at close), 8.2 (FDS-08-007a Hold Management screen), 14 (FDS-14-005 Flexware BOM import). §4 User Authentication & Session Management **fully rewritten (Phase C, 2026-04-21)**: operators identified by initials only, per-action AD elevation, no clock # / PIN, dedicated vs shared terminal modes, 30-min idle re-confirmation. §11 Audit has 4 log streams with code-string audit proc signatures. FDS-11-011 codifies the Ignition JDBC single-result-set convention. FDS-03-017a codifies the data-collection capture contract. **Phase D (2026-04-21) rewrote six sections:** §2.5 Terminals (OI-08 addenda — TerminalMode attribute, machine-context lock, tablet design input), §5.4 Sub-LOT Splitting (OI-09 sublot pattern formalised — parent FK, per-cavity concurrent sublots, label parent reference), §5.5 LOT Merging (OI-05 revised — post-sort only, same part, cross-die via `Tools.DieRankCompatibility` with supervisor override, FIFO-by-cavity), §6.10 Work Orders (OI-07 revised — three WO types Demand/Maintenance/Recipe, Maintenance flow FUTURE), §9.4 Shift Management (OI-03 closed — availability derived from events, no minute adjustments), §10.3 Non-Serialized Line Integration (OI-04 revised — line-stop not LOT-hold, 10-consecutive-fail escalation, CRT 200%-inspect workflow). Of 14 open items (10 original + 4 new from 2026-04-20 meeting): 3 resolved (OI-01, 03, 06), 6 in revised/in-review (OI-02, 04, 05, 07, 08-addenda, 09-addenda), 4 open including 4 new (OI-11, 12, 13, 14), 1 superseded (OI-10 rolled into Phase B Tool Management spec).
- **User Journeys:** v0.7 (rev 2026-04-22) — 19 assumptions. UJ-01 (Operator Identity & Elevation) closed 2026-04-21 per FDS §4 rewrite; Carlos Die Cast narrative updated to show initials-based presence. UJ-12 and UJ-15 closed with addenda mapped to OI-08 and OI-09. **v0.7:** Arc 2 Trim Shop scene now shows the Casting→Trim part-identity change as a normal 1-line BOM consumption (OI-11 resolved 2026-04-22 — initial draft wrote `Parts.ItemTransform`, reverted as redundant with `ConsumptionEvent`). Sort Cage scene shows Diane using the Track tile (OI-15) + making the explicit Scrap-from-Location choice (OI-20). Config Tool arc reflects Draft/Published/Deprecated versioning, OperationTemplate DataCollectionField junction, Location SortOrder + MoveUp/MoveDown, HoldEvent lifecycle.
- **Open Issues Register:** v2.6 **sectioned markdown** (`MPP_MES_Open_Issues_Register.md`) + regenerated docx. Per-OI subsections replace the old grid table. **v2.5 (2026-04-22):** added OI-15 through OI-30 from the 2026-04-22 legacy-Flexware-MES screenshot gap analysis. **v2.6 (2026-04-22):** OI-11 moved ⬜ Open → ✅ Resolved via 1-line BOM (no new `Parts.ItemTransform` table). 49 items total (30 Part A + 19 Part B); 9 resolved, 9 in review, 30 open, 1 superseded. Regenerate docx via `pandoc MPP_MES_Open_Issues_Register.md -o MPP_MES_Open_Issues_Register.docx --reference-doc=reference.docx && node style_docx_tables.js MPP_MES_Open_Issues_Register.docx`.
- **ERD:** Interactive HTML with 8 tabs, **updated 2026-04-22 for Data Model v1.8** in the per-schema Parts and Workorder tabs (ItemTransform, ScrapSource, consumption metadata, CountryOfOrigin, MaxParts, ScrapSourceId). Master ERD tab still reflects v1.5 — full Master regeneration remains queued (the per-schema tabs are the source of truth for current state).
- **Phased Development Plan (Configuration Tool):** v1.7 — 8 phases, **all 8 built and tested**. 2026-04-21 update: AppUser admin screens and procs realigned to the initials-based model (`AppUser_GetByClockNumber` → `_GetByInitials`, `AppUser_SetPin` dropped from spec as legacy, User Management modal gains a Class toggle with no PIN field). SP template uses `RAISERROR` (not `THROW`) in CATCH blocks with nested TRY/CATCH for failure logging. No drag-and-drop in any UI — up/down arrow buttons for all sortable lists. All DB references schema-qualified. Separate file: `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md`. Task list derived as `MPP_MES_TASK_LIST_CONFIG_TOOL.csv`.
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

## Remaining Tasks

See `MPP_MES_SUMMARY.md` "Remaining Tasks" section for the full list. Key items as of 2026-04-24:

**Integration queue from Jacques's OIR v2.10 review (per-item commits):**
1. ✅ **OI-12 `MaxParts` move** — landed (commit `47a4e25`).
2. ✅ **OI-18 `Parts.ItemLocation` hierarchy cascade** — landed (commit `0f7f40f`).
3. ✅ **OI-08 Terminal mode by Location assignment** — landed (commit `7a9d87e`).
4. ✅ **OI-23 `Lots.v_LotDerivedQuantities` view** — landed (commit `e393b7d`).
5. ✅ **OI-16 PLC confirmation BIT + `RequiresCompletionConfirm` LocationAttribute** — landed (commit `55427f5`).
6. ✅ **OI-21 Pausable LOT (`Lots.PauseEvent`)** — landed (commit `15edd5e`, 2026-04-27 design lock).
7. ✅ **UJ-04 AIM Shipper ID local pool (`Lots.AimShipperIdPool` + `AimPoolConfig`)** — landed (commit `82df891`, 2026-04-27 design lock).
8. **OI-13 Flexware BOM export** — moved to seeding registry as **S-06** (no longer framed as a build blocker; it's a deployment-time data dependency).

**SQL correction migrations queued (not yet landed):**
- **OI-07** — rename `WorkOrderType` seed `Demand`→`Production`, DELETE Ids 2 + 3; update test `sql/tests/0019_Parts_ConsumptionMetadata_And_ScrapSource/010_Phase_E_additives.sql`.
- **OI-12** (per #1 above).

**Arc 2 Plan follow-up:**
- Phases 2–8 in-place rewrite (currently overlay-only after Phase 0/1 rewrite on 2026-04-24).

**Decision blockers (not seed-data — these genuinely gate downstream work):**
1. **Ben** — OI-31 rollout shape decision (single-line vs full-cutover vs shadow); memo at `Meeting_Notes/2026-04-24_OI-31_Single-Line_Deployment_Impact.md`.
2. **Tom (security SME)** — final elevated-action list validation (FDS-04-007).

**Seed-data items — tracked in `MPP_MES_SEEDING_REGISTRY.md` (NOT blockers).** S-01 through S-11 cover plant equipment, downtime/defect codes, OPC tags, parts master, BOM export (OI-13), die ranks + compatibility, label types, identifier sequence baselines, and AIM pool tuning. The registry is the single source of truth for what's owed, received, loaded, or verified — see status badges and per-item detail there. Only S-08 (DieRankCompatibility) is a true blocker (with a supervisor-override workaround); everything else builds in parallel.

**Non-SQL work:**
3. Complete FDS appendices (currently placeholder references).
4. Map scope matrix rows + paper production sheet fields to FDS sections.
5. UJ enrichment pass — Jacques flagged entries lack the options/impact depth of OI entries.
6. Ignition Perspective frontend build not started.

**OIR status:** 28 resolved, 3 in review, 18 open, 1 superseded. Discovery items (OI-24, OI-25, OI-27, OI-28, OI-29, OI-30) still awaiting MPP input for the next review.

## Conventions

- **SQL:** Follow `sql_best_practices_mes.md` and `sql_version_control_guide.md` — UpperCamelCase tables and columns, `BIGINT` surrogate `Id` PKs, `NVARCHAR` (never VARCHAR), `DeprecatedAt` soft deletes, `DATETIME2(3)`, `DECIMAL` not `FLOAT`, all enum/status values code-table backed with FK, user attribution via `BIGINT FK → AppUser.Id` (never free-text), append-only events.
- **SP template:** ⚠️ **REFACTOR IN PROGRESS** — Converting from `OUTPUT` params to `SELECT`-based returns for Ignition JDBC compatibility. See "Ignition JDBC Compatibility" section above. Old pattern: `@Status BIT OUTPUT` + `@Message NVARCHAR(500) OUTPUT`. New pattern: local variables + final `SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;`. Three-tier error hierarchy, `RAISERROR` (not `THROW`) in CATCH blocks with nested failure logging. See `sql/scripts/_TEMPLATE_stored_procedure.sql`.
- **UI:** No drag-and-drop anywhere — up/down arrow buttons for all sortable lists.
- **FDS requirements:** Numbered `FDS-XX-NNN` (section-sequence). Keywords per RFC 2119: SHALL, SHALL NOT, SHOULD, MAY, FUTURE.
- **Scope tags:** Every section and table is tagged MVP, MVP-EXPANDED, CONDITIONAL, or FUTURE.
- **FRS crosswalk:** FDS requirements reference originating FRS IDs in parentheses, e.g., `(FRS 3.9.6)`.
