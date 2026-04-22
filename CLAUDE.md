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

## Current State (as of 2026-04-22)

**2026-04-20 OI review refactor largely complete through Phase G.2.** Phases C (security rewrite), A (OI register refresh), B (Tool Management design spec + data-model rollup), D (remaining FDS updates), and E (design + doc additions for OI-11..23) are complete. Phase F text-side docx regeneration + ERD refresh done 2026-04-22 in v1.8 form. **Phase G SQL:** G.1 migration (`0010_phase9_tools_and_workorder.sql`) landed 2026-04-22 (Tools schema + 2 Workorder code tables + Parts ALTERs + 9 Audit.LogEntityType seed rows); G.2 delivered 45 stored procs (Tools subsystem CRUD + Workorder code-table reads). Stored proc count 171 → 216. 779/779 existing tests still pass. OI-11 resolved 2026-04-22 via 1-line BOM (no `Parts.ItemTransform` table — fully redundant with `ConsumptionEvent`). Discovery items OI-24..30 parked for the next MPP review. Phase G.3 (Phase E additive procs ~3 files), G.4 (AppUser legacy DROP), G.5 (~60 test assertions) still queued. Full plan in `memory/project_mpp_oi_refactor.md`. Phase G capability snapshot: `Meeting_Notes/2026-04-22_Phase_G_Capabilities_Summary.md`. Phase B Tool-design decisions live in `docs/superpowers/specs/2026-04-21-tool-management-design.md` v0.3.

- **Data model:** v1.8 (rev 2026-04-22) — 8 schemas, ~72 tables. **v1.8 — Phase E additive changes:** `Parts.Item.CountryOfOrigin NVARCHAR(2)` (OI-19), `Parts.ItemLocation` + `MinQuantity` / `MaxQuantity` / `DefaultQuantity` / `IsConsumptionPoint` (OI-18), `Parts.ContainerConfig.MaxParts` (OI-12), Cell `LinesideLimit` LocationAttribute (OI-12), new `Workorder.ScrapSource` code table (OI-20; `Workorder.ProductionEvent.ScrapSourceId` FK baked in by Arc 2 Phase 1 — ProductionEvent table doesn't exist yet). **OI-11 resolved via 1-line BOM** (no new schema) — Casting → Trim rename is a degenerate 1-line BOM consumption; `Parts.ItemTransform` was drafted then reverted 2026-04-22 as fully redundant with `Workorder.ConsumptionEvent`. `Audit.LogEntityType` +1 row in Phase G (ScrapSource; ItemTransform reservation dropped). All additive — no breaking changes. Phase G migration `0010_phase9_tools_and_workorder.sql` landed 2026-04-22 (Tools schema + 2 code tables + 3 Parts ALTERs + 9 LogEntityType rows; 779/779 tests still pass). BIGINT PKs/FKs everywhere, NVARCHAR (no VARCHAR). Location schema uses three-tier polymorphic model. Audit schema has 4 log streams. All enum/status columns are code-table backed with FKs. User attribution via `BIGINT FK → AppUser.Id`. OperationTemplate data collection is configurable via junction (no hardcoded BIT flags). HoldEvent is a single place/release lifecycle table. SortOrder on Location.Location with MoveUp/MoveDown. v1.4 closed the template→event capture gap: `Workorder.ProductionEvent` gained `OperationTemplateId` FK + hot typed columns (`DieIdentifier`, `CavityNumber`, `WeightValue`+`WeightUomId`) and new `Workorder.ProductionEventValue` child table for extensible `DataCollectionField` capture. v1.5 added the Phase 8 Oee reference tables (`DowntimeReasonType` seed-only, `DowntimeReasonCode`, `ShiftSchedule` with `DaysOfWeekBitmask INT`, `Shift` runtime). **v1.6 (2026-04-21):** `Location.AppUser` realigned to the initials-based security model — `Initials NOT NULL UNIQUE`, `AdAccount` nullable with filtered UNIQUE, CHECK binding `IgnitionRole` to `AdAccount` presence; `ClockNumber` + `PinHash` flagged legacy for Phase G removal. **v1.7 (2026-04-21) — Phase B data-model rollup landed.** New `Tools` schema (§7) with 10 tables: `ToolType` (seeded read-only, `HasCavities` flag), `ToolAttributeDefinition`, `Tool` (nullable `DieRankId` — Die-type only, no shot counter), `ToolAttribute`, `ToolCavity` (3-state Active/Closed/Scrapped), `ToolAssignment` (append-only check-in/out with filtered UNIQUE on active mount), `ToolStatusCode` + `ToolCavityStatusCode` (read-only), `DieRank` + `DieRankCompatibility` (both empty seed — MPP Quality owes). `Workorder.WorkOrder` gains `WorkOrderTypeId` (NOT NULL DEFAULT Demand-Id, backfilled) and nullable `ToolId` FK → Tools.Tool. New `Workorder.WorkOrderType` code table (Demand/Maintenance/Recipe). Maintenance WO flow is FUTURE — schema hook only. Audit Schema renumbered to §8. Phase G migration `0010_phase9_tools_and_workorder.sql` delivers the SQL + drops legacy AppUser.ClockNumber + PinHash.
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

See `MPP_MES_SUMMARY.md` "Remaining Tasks" section for the full list. Key items:
1. Complete FDS appendices (currently placeholder references)
2. Resolve remaining open items requiring MPP input (see Open Issues Register for current status)
3. Map scope matrix rows and paper production sheet fields to FDS sections
4. Validate data model against FDS
5. Begin Arc 2 (Plant Floor) plan — data-collection capture contract (FDS-03-017a, `Workorder.ProductionEvent_Record`) is the key first target once prerequisites are sequenced.
6. Run `Oee.DowntimeReasonCode_BulkLoadFromSeed` against the 353-row downtime CSV once MPP confirms the three DeptCode→Area mappings (DC, MS, TS) in production.
7. Load machines.csv seed data into Location rows (209 machines — procs exist, mapping needed)
8. Load defect_codes.csv seed data into `Quality.DefectCode` (153 codes — procs exist, mapping to Area needed)
9. Load MPP parts list into `Parts.Item` once MPP supplies the export (bulk-load proc deferred)
10. MPP shipping-staff validation of `Lots.LabelTypeCode` seed values (Primary/Container/Master/Void — currently proposed, not authoritative)
11. MPP customer validation of OI-02: scale-driven container closure (`ClosureMethod` + `TargetWeight` columns exist nullable on `Parts.ContainerConfig` pending decision)

## Conventions

- **SQL:** Follow `sql_best_practices_mes.md` and `sql_version_control_guide.md` — UpperCamelCase tables and columns, `BIGINT` surrogate `Id` PKs, `NVARCHAR` (never VARCHAR), `DeprecatedAt` soft deletes, `DATETIME2(3)`, `DECIMAL` not `FLOAT`, all enum/status values code-table backed with FK, user attribution via `BIGINT FK → AppUser.Id` (never free-text), append-only events.
- **SP template:** ⚠️ **REFACTOR IN PROGRESS** — Converting from `OUTPUT` params to `SELECT`-based returns for Ignition JDBC compatibility. See "Ignition JDBC Compatibility" section above. Old pattern: `@Status BIT OUTPUT` + `@Message NVARCHAR(500) OUTPUT`. New pattern: local variables + final `SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;`. Three-tier error hierarchy, `RAISERROR` (not `THROW`) in CATCH blocks with nested failure logging. See `sql/scripts/_TEMPLATE_stored_procedure.sql`.
- **UI:** No drag-and-drop anywhere — up/down arrow buttons for all sortable lists.
- **FDS requirements:** Numbered `FDS-XX-NNN` (section-sequence). Keywords per RFC 2119: SHALL, SHALL NOT, SHOULD, MAY, FUTURE.
- **Scope tags:** Every section and table is tagged MVP, MVP-EXPANDED, CONDITIONAL, or FUTURE.
- **FRS crosswalk:** FDS requirements reference originating FRS IDs in parentheses, e.g., `(FRS 3.9.6)`.
