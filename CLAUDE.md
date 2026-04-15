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
| 6 | `MPP_MES_Open_Issues_Register.docx` | Word document (v2.3) consolidating all open items and design decisions. Part A: 10 FDS open items (OI-01–OI-10). Part B: 19 user journey items (UJ-01–UJ-19). Includes FRS/FDS reference crosswalk and status tags per item. | When resolving open items or preparing for MPP meetings |
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

## Current State (as of 2026-04-15)

- **Data model:** v1.3 — 7 schemas, ~60 tables. BIGINT PKs/FKs everywhere, NVARCHAR (no VARCHAR). Location schema uses three-tier polymorphic model. Audit schema has 4 log streams. All enum/status columns are code-table backed with FKs (7 new code tables added 2026-04-13). User attribution via `BIGINT FK → AppUser.Id` (no free-text CreatedBy). OperationTemplate data collection is configurable via junction table (no hardcoded BIT flags). HoldEvent is a single place/release lifecycle table (same pattern as DowntimeEvent). SortOrder on Location.Location with MoveUp/MoveDown pattern. Tool life tracking remains a gap (OI-10).
- **FDS:** v0.6 working draft — all 15 sections + appendix placeholders. §11 Audit has 4 log streams with code-string audit proc signatures. FDS-11-011 codifies the Ignition JDBC single-result-set convention (no OUTPUT params; mutations return `SELECT Status, Message, NewId`; audit writers silent). Of 10 open items: 3 resolved, 4 pending customer validation, 1 pending internal review (Ben), 2 remain open.
- **User Journeys:** v0.5 — 19 assumptions with decision text and status tags; Config Tool arc updated for Draft/Published/Deprecated versioning (RouteTemplate, OperationTemplate, Bom), OperationTemplate DataCollectionField junction, Location SortOrder + MoveUp/MoveDown, and HoldEvent lifecycle.
- **Open Issues Register:** Word doc v2.3 with 29 items total. Full FRS/FDS reference crosswalk added.
- **ERD:** Interactive HTML with 8 tabs, regenerated for data model v1.3.
- **Phased Development Plan (Configuration Tool):** v0.9 — 8 phases. SP template uses `RAISERROR` (not `THROW`) in CATCH blocks with nested TRY/CATCH for failure logging. No drag-and-drop in any UI — up/down arrow buttons for all sortable lists. All DB references schema-qualified. Separate file: `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md`. Task list derived as `MPP_MES_TASK_LIST_CONFIG_TOOL.csv` (100 tasks, ~470h).
- **SQL scripts:** Phases 1–7 complete and tested. `/sql/` folder with 8 versioned migrations + 158 repeatable procs. **710 passing tests** across 19 test suites (lower raw count than pre-refactor because INSERT-EXEC assertions collapse prior pairs of Status+RowCount checks into single proc-output assertions). PowerShell reset script (`Reset-DevDatabase.ps1`) auto-discovers and runs all scripts via `sqlcmd.exe`, creates dev-only `ignition` SQL login with `db_owner` on every reset. Tested successfully on SQL Server 2025.
- **SQL workflow:** `sql_version_control_guide.md` — general-purpose top half + MPP-specific overlay (naming, SP template, schema layout, AI rules). PowerShell reset script replaces the old SQLCMD-mode `.sql` approach.
- **Word output:** All markdown docs have bordered + alternating-row styled Word versions. Regenerate via `pandoc ... --reference-doc=reference.docx` + `node style_docx_tables.js <file.docx>`.
- **Seed data:** 876 rows extracted from FRS Appendices B/C/D/E into CSVs in `reference/seed_data/`, plus auto-generated `reference/seed_data.xlsx`. Per-appendix Node.js parsers in `reference/seed_data/parsers/` handle multi-line wrapped descriptions. Source PDF is `reference/MPP_FRS_Draft.pdf`.
- **NOT started:** Ignition project, Perspective screens, Phase 8 SQL scripts, **seed data loading** (CSVs ready — machines.csv not yet loaded into Location rows; MPP parts list not yet provided; defect_codes.csv not yet loaded), PLC integration.

## Ignition JDBC Compatibility — READ PROCS DONE, MUTATIONS PENDING

**Problem discovered 2026-04-14:** Stored procedures with `OUTPUT` parameters AND a `SELECT` result set do not work with Ignition Named Queries. The JDBC driver reads OUTPUT params as the first result set and ignores the actual data.

**Root cause:** SQL Server returns OUTPUT params as a separate result set. Ignition's JDBC driver reads the first result set (the OUTPUT params) and stops, never seeing the SELECT data.

**Solution — SP signature refactor:**
- **Read procs:** Remove OUTPUT params entirely. Empty result = not found.
- **Mutation procs:** Convert `@Status/@Message/@NewId OUTPUT` to local variables, add final `SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;`
- **Audit procs (4):** Remove result set returns — they are internal helpers called by mutation procs and must not emit result sets (causes INSERT-EXEC + ROLLBACK conflicts).
- **2-result-set procs:** Drop the second result set (Ignition Named Queries only read the first; callers use the sibling List proc instead).

### Conversion Progress (as of 2026-04-14 end of session)

**All read procs converted (58 of 58):** Audit (8), Location (15), Lots (12), Oee (2), Workorder (4), Parts (23 — Uom/ItemType/DataCollectionField/Item/ContainerConfig/ItemLocation/OperationTemplate+Field/RouteTemplate+Step/Bom+Line/Bom_WhereUsedByChildItem), Quality (8 code-table + 6 spec) — includes DefectCode and QualitySpec/Version/Attribute read procs.

**Mutation procs converted so far (1):** `Location.AppUser_Create` (pilot). Returns `SELECT Status, Message, NewId` instead of OUTPUT params.

**Audit writer procs (4):** `Audit.Audit_LogConfigChange`, `Audit.Audit_LogFailure`, `Audit.Audit_LogInterfaceCall`, `Audit.Audit_LogOperation` — had their `SELECT @NewLogId` returns stripped (they run inside mutation-proc transactions, so emitting a result set breaks INSERT-EXEC + ROLLBACK).

**Test files rewritten:** All read-proc test sections across 17 test files converted to INSERT-EXEC temp table pattern. Row counts now come from proc output (not base-table queries), which is stricter coverage. NULL-Id assertion blocks dropped per design decision (empty result is the contract).

**Proc-logic bug fixed:** `Audit.ConfigLog_List`, `Audit.FailureLog_List`, `Audit.FailureLog_GetTopReasons` — when passed an invalid `@LogEntityTypeCode`, the filter resolved to NULL and silently became "no filter" (returned all rows). Added a `RETURN;` short-circuit so invalid optional filters correctly return an empty result.

**Remaining mutation procs (~71):** Not started. Requires the `SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;` pattern at every exit point. More complex surgery than read procs: preserve transactional semantics, audit log placement, and RAISERROR re-raise in CATCH. Location (15), Parts (42), Quality (14).

**Remaining test file updates:** ~71 mutation-proc tests will need conversion to INSERT-EXEC pattern when the corresponding procs are converted.

### Test patterns (post-refactor)

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
1. **Complete SP refactor for Ignition JDBC compatibility** — all 58 read procs done, 1 mutation proc done (AppUser_Create pilot), ~71 mutation procs remaining (Location 15 + Parts 42 + Quality 14). See "Ignition JDBC Compatibility" section.
2. Complete FDS appendices (currently placeholder references)
3. Resolve remaining open items requiring MPP input (see Open Issues Register for current status)
4. Map scope matrix rows and paper production sheet fields to FDS sections
5. Validate data model against FDS
6. Generate Phase 8+ SQL scripts (Phases 1–7 complete and tested)
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
