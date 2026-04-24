# MPP MES — Functional Design Specification

**Document:** FDS-MPP-MES-001
**Project:** Madison Precision Products MES Replacement
**Prepared By:** Blue Ridge Automation
**Client:** Madison Precision Products, Inc. (Madison, IN)
**Version:** 0.11g — Working Draft
**Date:** 2026-04-24

---

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 0.1 | 2026-04-06 | Blue Ridge Automation | Initial working draft — front matter, architecture, plant model, master data |
| 0.2 | 2026-04-09 | Blue Ridge Automation | Propagated OI/UJ design decisions. Resolved OI-01 (no outbox), OI-08 (shared terminals as location type), OI-09 (one part at a time). Updated §1.4/1.6 (direct calls + logging), §2.5 (terminal as location type, machine barcode scan), §3.6 (closed OI-09), §4.2 (5-min timeout session model), §5.4 (auto-split into 2 sublots), §5.5 (configurable merge rules), §6.3 (warm-up as downtime), §6.5 (interlock bypass flag), §6.6 (scale feedback), §6.10 (WO MVP-lite), §10.3 (vision auto-hold + override). Added FRS references to OI register. |
| 0.3 | 2026-04-09 | Blue Ridge Automation | Naming convention changed from snake_case to UpperCamelCase for all DB identifiers (tables, columns, code values). Merged Department into Area per ISA-95 — Department location type removed, 5 departments become Area-type locations. Added Enterprise (level 0) to hierarchy. Updated §2.2 (FDS-02-001) hierarchy table, §2.3 (FDS-02-003), all defect/downtime filtering references. |
| 0.4 | 2026-04-10 | Blue Ridge Automation | Major restructure of location model: split `LocationType` (5 ISA-95 tiers) from `LocationTypeDefinition` (polymorphic kinds) and introduced `LocationAttributeDefinition` for attribute schemas per kind. Terminal, DieCastMachine, CNCMachine, InventoryLocation, etc. are now `LocationTypeDefinition` rows under the `Cell` type. Rewrote §2.1–2.5. Added §5.3 FDS-05-008 explicit login→scan-location→scan-lot movement workflow. Updated FDS-05-004 and FDS-05-020 to clarify Die Cast uses pre-printed LTTs (no Initial print event). Expanded FDS-06-019 with Pattern A (inline reject) vs Pattern B (split-to-scrap) scrap handling. Added FDS-07-019 clarifying Sort Cage is NOT a LOT merge event. Added bordered + alternating row Word table styling via pandoc reference doc. |
| 0.5 | 2026-04-10 | Blue Ridge Automation | §11 Audit & Logging expanded: added fourth log stream `Audit.FailureLog` for attempted-but-rejected operations (new FDS-11-004). High-Fidelity Interface Logging renumbered from FDS-11-004 to FDS-11-005 to make room. Added FDS-11-008 documenting the code-string signatures for the four shared audit procs. Renumbered FDS-11-007 → FDS-11-009 (Retention Policy) and FDS-11-008 → FDS-11-010 (BIGINT Primary Keys) to accommodate. Normalized vocabulary examples in FDS-11-006/007 updated to UpperCamelCase (`Created`/`Updated`/`Deprecated`/`LotCreated` etc. instead of UPPER_SNAKE). |
| 0.7 | 2026-04-15 | Blue Ridge Automation | **Production data collection capture.** Closed a gap where `OperationTemplate` + `OperationTemplateField` + `DataCollectionField` defined *what* to collect but nothing persisted *what was actually collected* when a LOT passed through. Updated §3.4 (FDS-03-012 operation-template definition — replaced stale `Collects*`/`Requires*` BIT-flag table with the `OperationTemplateField` → `DataCollectionField` junction wording that matches data model rev 0.7+). Updated §6.2 (FDS-06-001 die cast screen — now driven by `OperationTemplateField` rows rather than flags) and FDS-06-003 (die cast production event — now captures `OperationTemplateId`, `DieIdentifier`, `CavityNumber`, `WeightValue`/`WeightUomId` as hot columns plus N `ProductionEventValue` children for any other configured field). Added new FDS-03-017a specifying how the Perspective screen resolves operation-template fields into inputs and writes the header+children transactionally. Data model aligned at v1.4 (new `Workorder.ProductionEventValue` table + `ProductionEvent` extensions). |
| 0.6 | 2026-04-15 | Blue Ridge Automation | Reflects Phase 5/6 SQL completion and the Ignition JDBC stored-procedure convention change. Data model realigned to v1.3: added HoldEvent place/release lifecycle table, SortOrder + MoveUp/MoveDown pattern on `Location.Location`, OperationTemplate→DataCollectionField junction (replacing hardcoded BIT flags), and seven new code tables backing all former enum/status columns. Versioning pattern for RouteTemplate, OperationTemplate, and Bom standardized on the three-state `Draft / Published / Deprecated` model (PublishedAt + DeprecatedAt). Added FDS-11-011 documenting the Ignition JDBC single-result-set convention: stored procedures SHALL NOT use `OUTPUT` parameters; mutation procs SHALL return `SELECT Status, Message, NewId` as their sole result set, read procs SHALL return a single result set (empty = not found), and the four shared audit writers SHALL emit no result set (they run inside caller transactions and would otherwise break INSERT-EXEC with ROLLBACK). |
| 0.11g | 2026-04-24 | Blue Ridge Automation | **§6.10 OI-16 — PLC confirmation BIT + `RequiresCompletionConfirm` LocationAttribute.** Per Jacques's 2026-04-24 OIR review, Auto-Finish on Target (FDS-06-028) gains two additions: (1) a PLC confirmation BIT that must fire before the WO-close event — belt-and-suspenders with the cumulative-count threshold (count crosses target AND PLC confirms, not either-or); (2) a per-Terminal `RequiresCompletionConfirm` LocationAttribute that toggles a large "Confirm Completion" button UX vs a passive popup ("WorkOrder/Tray/Container Completed"). Some lines require physical operator acknowledgement at a fixed 1:1 terminal, others don't. FDS-06-028 extended. New `LocationAttributeDefinition` seed row on `Terminal` LocationTypeDefinition. ERD + Arc 2 Plan Phase 6 updated. |
| 0.11f | 2026-04-24 | Blue Ridge Automation | **§5.1 OI-23 — LOT derived quantities implemented as a view, not materialized columns.** Per Jacques's 2026-04-24 OIR review: use a SQL view (`Lots.v_LotDerivedQuantities`) computing `TotalInProcess` and `InventoryAvailable` at read time from `Lots.Lot.PieceCount` + `Workorder.ProductionEvent` + `Workorder.ConsumptionEvent` aggregations. No materialized columns on `Lots.Lot`; no update-on-write. FDS-05-031 rewritten to specify the view-backed derivation and drop the "may be materialized in a future phase" option. Data Model v1.9e documents the view. Arc 2 Plan Phase 2 migration gains the view creation. |
| 0.11e | 2026-04-24 | Blue Ridge Automation | **§2.5 / §4 OI-08 terminal-mode-by-assignment rule.** Per Jacques's 2026-04-24 OIR review: the Terminal's **parent Location tier determines its mode** — no separate `TerminalMode` LocationAttribute needed. A Terminal whose parent Location is a WorkCenter (or Cell) is Dedicated; a Terminal whose parent Location is an Area is Shared. FDS-02-010 rewritten with the parent-tier-derived rule. FDS-04-003 rewritten to match (same Dedicated/Shared semantics, different derivation). The `TerminalMode` LocationAttribute is superseded; the `DedicatedMachineLocationId` attribute is also retired (the machine context IS the parent when Dedicated). FDS-02-011 machine-context-lock rule unchanged. Arc 2 Plan Phase 1 `Terminal_ResolveFromSession` proc spec already updated. ERD Location tab scope notes follow. No data-model schema change. |
| 0.11d | 2026-04-24 | Blue Ridge Automation | **§3.5 OI-18 extension — ItemLocation hierarchy cascade.** Per Jacques's 2026-04-24 OIR review, `Parts.ItemLocation.LocationId` is broadened to support Area / WorkCenter / Cell tiers. Eligibility at a specific Cell = exact-match row OR any ancestor row. FDS-03-014 (Eligibility Map) rewritten with the cascade algorithm. FDS-03-015 (Eligibility Management) extended with Config Tool UI note for tier selection. FDS-03-018 (Consumption Metadata) clarified — metadata lives on the ItemLocation row at whatever tier is declared; when a Cell scan-in resolves to an ancestor ItemLocation row, that row's consumption metadata applies. New helper proc `Parts.ItemLocation_IsEligible` specified. No column changes — the existing generic `LocationId` FK already supports any tier. |
| 0.11c | 2026-04-24 | Blue Ridge Automation | **§3 OI-12 correction — `MaxParts` reclassified as a Part attribute.** Per Jacques's 2026-04-24 OIR review, the `MaxParts` cap belongs on `Parts.Item`, not on `Parts.ContainerConfig` — it's evaluated when inventory is checked into a Location, against the Part identity. FDS-03-019 rewritten: target is `Parts.Item.MaxParts` (per-Item per-Location cap); validation fires on `LotMovement` to a Cell, summing existing pieces of this Item already at the destination Location + incoming quantity. Complementary FDS-03-020 (Location-scoped `LinesideLimit`) unchanged; the two caps are orthogonal. Data Model v1.9c carries the column relocation. SQL correction migration queued (DROP `Parts.ContainerConfig.MaxParts`, ADD `Parts.Item.MaxParts`, test 0019 update). |
| 0.11b | 2026-04-24 | Blue Ridge Automation | **§6.10 WorkOrderType correction (OI-07).** Jacques clarified 2026-04-24 that the 2026-04-20 "Recipe" meeting note was mis-recorded — it was describing the **Production** work orders (MVP-LITE, invisible to operators) already in the design, not a separate type. Under MPP's taxonomy, `Demand` = planned PM and `Maintenance` = emergency, both genuinely separate but both FUTURE (out of scope for this project). §6.10 edits: FDS-06-022 renamed "Work Order Auto-Generation (Demand Type)" → "(Production Type)"; FDS-06-025 seed table reduced from 3 active rows to 1 (`Production`), with `Demand` and `Maintenance` moved to a FUTURE-only list; FDS-06-026 Maintenance FUTURE section retained as the schema-hook reference; **FDS-06-027 Recipe Work Orders — DELETED entirely** (no such concept exists); FDS-06-028 auto-finish language updated from "Demand Work Orders" → "Production Work Orders". Data model v1.9b, OIR v2.9, Arc 2 Plan v0.2, and ERD updated in matching commits. SQL seed correction queued (versioned migration + test 0019 update) — not executed this turn. |
| 0.11 | 2026-04-24 | Blue Ridge Automation | **Arc 2 model revisions (2026-04-23 session) — Tool/Cavity on Lot, ProductionEvent checkpoint shape, Identifier Sequences, cavity-parallel LOT pattern codified.** New requirements land across §§3.4, 5.1, 5.2, 5.3, 5.4, 5.5, 6.2, 6.10, plus a new section on identifier sequences:<br><br>• **§3.4 FDS-03-017a rewritten** — `ProductionEvent` is now a checkpoint shape (cumulative `ShotCount`/`ScrapCount`, no `DieIdentifier`/`CavityNumber`/`LocationId`/`ItemId`/per-event `GoodCount`/`NoGoodCount`). `Lot.ToolId`/`Lot.ToolCavityId` are the system of record — derived at read time via join, not stored on the event.<br>• **§5.1 FDS-05-003 revised** — `Lot.ToolId` + `Lot.ToolCavityId` added to the LOT attributes table. Pre-v0.11 `DieNumber`/`CavityNumber` NVARCHAR attributes marked legacy.<br>• **§5.1 FDS-05-034 (NEW)** — Die-cast-origin LOTs SHALL require `ToolId` + `ToolCavityId` at `Lot_Create`, validated against active `Tools.ToolAssignment` on the Cell + `ToolCavity` belongs to Tool + Cavity Active.<br>• **§5.1 FDS-05-035 (NEW)** — Tools system-of-record rule: Tool / Cavity live on `Lot`, NOT on `ProductionEvent`. Downstream LOTs do NOT carry the FKs — Honda-trace via `LotGenealogy` recursive traversal.<br>• **§5.2 FDS-05-004 revised** — Die Cast LOT creation step now auto-populates Tool from `ToolAssignment_ListActiveByCell`; operator confirms; elevated Edit triggers inline `ToolAssignment_Release`/`_Assign`. Other areas (trim, machining, assembly) do not require operator Tool validation at LOT create.<br>• **§5.3 FDS-05-036 (NEW)** — LOT creation is **lazy and operator-driven**. No auto-create of N LOTs at run start. Physical-but-unlogged baskets exist until the operator logs them. Tool+Cavity assignment happens at `Lot_Create` time.<br>• **§5.3 FDS-05-037 (NEW)** — LOT close semantics: Component LOTs (Die Cast, Trim, intermediate Machining) close via explicit operator "Complete + Move" action — combined status transition + movement in one atomic UI action. Cavity state changes do NOT auto-close LOTs. Finished-goods LOTs MAY auto-close on container fill (§6 — Container_Complete).<br>• **§5.4 restated** — Cavity-parallel LOTs at Die Cast are **peers, not sublots** (N active cavities → N parallel independent LOTs, no parent/child FK). Machining sub-LOT split remains a sublot pattern (parent FK + split genealogy). The 2026-04-20 FDS-05-023 per-cavity-sublot requirement is superseded — per-cavity LOTs are now first-class LOTs with `ToolCavityId` set.<br>• **§5.5 FDS-05-030 (NEW)** — Post-merge LOT SHALL have `ToolId = NULL` and `ToolCavityId = NULL` — blended-origin material can't denormalize multiple Tools into a single FK pair. Tool-specific trace reconstructed via `LotGenealogy` walk of pre-merge source LOTs.<br>• **§6.2 FDS-06-003 revised** — Die Cast `ProductionEvent` capture aligned to checkpoint shape (cumulative counters + delta via `LAG()`; no per-event `GoodCount`/`NoGoodCount`; no `DieIdentifier`/`CavityNumber` on event — derived from Lot).<br>• **§6.10 FDS-06-030 (NEW)** — Phase 0 MPP input item: WorkOrder BIT-flag enumeration (Flexware `IsCameraProcessingEnabled`, `IsScaleProcessingEnabled`, `GroupTargetWeight`, `GroupTargetWeightTolerance`, `TargetWeightUnitOfMeasureID`, `RecipeNumber`, `TrayQuantity`, `ReturnableDunnageCode`, `Customer`). Live flags become columns on `Workorder.WorkOrder` at Arc 2 Phase 1 CREATE; dead flags don't ship.<br>• **NEW §16 Identifier Sequences** — `Lots.IdentifierSequence` table + `IdentifierSequence_Next @Code` proc. Seeded at cutover from Flexware `LastCounterValue` for `Lot` (`MESL{0:D7}`) and `SerializedItem` (`MESI{0:D7}`). FDS-16-001..003.<br>• **Cross-cutting guidance** — Per-terminal-function purpose-built Perspective views; LocationAttribute used for business policies only, never UI config. Flexware's `*DashboardConfiguration` family and `UserInterfaceScript` DB-stored-code pattern are NOT reproduced.<br><br>Source: `docs/superpowers/specs/2026-04-23-arc2-model-revisions.md`. Companion changes: Data Model v1.9, User Journeys v0.8, Arc 2 phased plan refresh. |
| 0.10-rev | 2026-04-22 | Blue Ridge Automation | **OI-11 reversal.** The initial v0.10 draft added §5.10 + FDS-05-033..035 covering a new `Parts.ItemTransform` table to bridge the Casting → Trim part rename. On review the table was redundant with `Workorder.ConsumptionEvent` (every column duplicated). §5.10 retained as a section but rewritten: the Casting → Trim boundary is modelled as a **degenerate 1-line BOM consumption** (trim part has cast part as its sole component at QtyPer=1). FDS-05-033..035 consolidated into a single FDS-05-033 describing the BOM-driven scan-in flow. No new schema — existing `Parts.Bom`, `Workorder.ConsumptionEvent`, and `Lots.LotGenealogy` carry it. OI-11 moves to ✅ Resolved in the Open Issues Register v2.6. Data Model v1.8 updated accordingly (ItemTransform table section replaced with a ✅ Resolved callout). |
| 0.10 | 2026-04-22 | Blue Ridge Automation | **Phase E of the 2026-04-20 OI review refactor — design + doc additions for OI-11..23.** Closes 13 items discovered across the 2026-04-20 MPP meeting (OI-11..14) and the 2026-04-22 legacy-MES screenshot review (OI-15..23). New sections: §3.6 extended with FDS-03-019 per-container MaxParts cap (OI-12) and FDS-03-020 lineside inventory cap (OI-12); §3.5 extended with FDS-03-018 ItemLocation consumption metadata (OI-18); §3.1 FDS-03-001 extended for Country of Origin (OI-19); §5.10 Part Identity Change — Casting to Trim, new subsection with FDS-05-033..035 (OI-11); §5.1 FDS-05-031 LOT computed quantities (TotalInProcess, InventoryAvailable) (OI-23); §5.3 FDS-05-032 partial start / partial complete confirmation (OI-21); §6.8 FDS-06-023a Scrap Source distinction (Inventory vs Location) (OI-20); §6.10 FDS-06-028 auto-finish-on-target WO + FDS-06-029 tray-divisibility validation (OI-16, OI-17); §8.2 FDS-08-007a dedicated Hold Management screen (OI-22); §12.5 Global Trace Tool, new subsection with FDS-12-009..011 (OI-15); §1.4 FDS-01-013 BOM import from Flexware @ .919 (OI-13); §4.3 Elevation Model extended with admin remove-item entry (OI-14); §14 Data Migration extended with Flexware BOM one-shot import (OI-13). Data model companion change: v1.7 → v1.8 adds `Parts.ItemTransform`, `Workorder.ScrapSource`, `Parts.ContainerConfig.MaxParts`, `Parts.ItemLocation` consumption cols, `Parts.Item.CountryOfOrigin`, `Workorder.ProductionEvent.ScrapSourceId`. All changes additive — no breaking re-numbering. Discovery items OI-24..30 remain parked for MPP input. Source: `MPP_MES_Open_Issues_Register.md` v2.5, `Meeting_Notes/2026-04-20_OI_Review_Status_Summary.md` v1.1. |
| 0.9 | 2026-04-21 | Blue Ridge Automation | **Phase D of the 2026-04-20 OI review refactor — six FDS sections rewritten.** §2.5 Terminals gains OI-08 addenda: `TerminalMode` LocationAttribute (Dedicated ≈80% / Shared ≈20%) via FDS-02-010, terminal machine-context lock (FDS-02-011, no UI navigation off-machine), part↔machine validity via `Parts.ItemLocation` (FDS-02-012), mobile-friendly tablet design input for Die Cast (FDS-02-013), Honda RFID forward-compatibility note (FDS-02-014 FUTURE). §5.4 Sub-LOT Splitting — formalised the sublot pattern for OI-09 addenda: general parent-FK + sublot semantics (FDS-05-022), per-cavity concurrent sublots at Die Cast (FDS-05-023), sublot label parent reference (FDS-05-024); retained existing auto-split workflow as one specific case. §5.5 LOT Merging — OI-05 revised: replaced loose "configurable" wording with concrete rules: post-sort only (FDS-05-023), same-part-number (FDS-05-024), die-rank compatibility via `Tools.DieRankCompatibility` with supervisor AD override (FDS-05-025), quality-status gating with no override for mixed status (FDS-05-026), machining FIFO-by-cavity is not a merge (FDS-05-027). §6.10 Work Orders — OI-07 three-type model: Demand / Maintenance / Recipe; `WorkOrderType` code table (FDS-06-025); Demand retains MVP-LITE auto-generation; Maintenance is `FUTURE` flow with schema hook only (FDS-06-026); Recipe is hidden from operator (FDS-06-027). §9.4 Shift Management — OI-03 closed: availability **derived from events**, not adjustable start/end columns; import schedules from MPP spreadsheet (FDS-09-012); break logging is end-of-shift only, no live per-break entry (FDS-09-013); early starts auto-increase availability because events drive runtime (FDS-09-014). §10.3 Non-Serialized Line Integration — OI-04 revised: line-stop semantics replace LOT auto-hold (FDS-10-005 rewritten), 10-consecutive-fail leader escalation with configurable threshold (FDS-10-009), failure-type branching (wrong part → immediate flag; wrong orientation → threshold only — FDS-10-010), hold-release paths via Quality or CRT (FDS-10-011), Controlled Run Tag workflow with mandatory 200%-inspect and missed-CRT re-run rule (FDS-10-012). Related Documents table updated to reference data model v1.7 (8 schemas, ~70 tables). Open Items Register grid refreshed to show revised statuses and the four new items (OI-11 part rename at Casting→Trim, OI-12 lineside inventory caps, OI-13 BOM source Flexware@.919, OI-14 admin remove-item). |
| 0.8 | 2026-04-21 | Blue Ridge Automation | **Security model rewrite (OI-06 closed — Phase C of the 2026-04-20 OI review refactor).** Replaced §4 Authentication & Session Management end-to-end. Operators no longer authenticate — they are identified by **initials** entered at the terminal (no clock number, no PIN), which establish an operator presence context that stamps `AppUserId` on events. Interactive users (Quality, Supervisor, Engineering, Admin) continue to authenticate via Active Directory. All clock-number and PIN terminology removed. Elevated actions are per-action AD re-prompts (no 5-minute-timeout, no session-sticky elevation). Introduced dedicated-vs-shared terminal modes via `LocationAttribute`. Added 30-minute idle re-confirmation overlay. Added pre-populated-and-defeasible initials field on every mutation screen. Operator `AppUser` rows are managed via the Configuration Tool (Admin screen). Updated §1.6 FDS-01-010. New FDS-04-009, FDS-04-010. |

---

## Approval

| Role | Name | Signature | Date |
|---|---|---|---|
| Blue Ridge — Project Lead | | | |
| MPP — Engineering | | | |
| MPP — Production Control | | | |
| MPP — Quality | | | |
| MPP — IT | | | |

---

## Scope Statement

This FDS describes how Blue Ridge Automation will implement the MES requirements defined in the Flexware FRS v1.0 (3/15/2024) using the Ignition platform and SQL Server 2022. It is the design document — the FRS says *what* the system needs to do; this FDS says *how*.

**In scope:** All items marked MVP and MVP-EXPANDED in the MPP Scope Matrix, plus CONDITIONAL items as approved. See the Scope Matrix Cross-Reference in Section 1.3 for the complete list.

**Not in scope (FUTURE):** OEE dashboards/KPIs, NCM/Failure Analysis, scheduling, raw material tracking, ERP integration (Macola), SCADA integration, Quality system integration (Intelex), process dashboards, process reporting, maintenance work orders, leak tests, torque checks, no-go part inventory. These capabilities are designed for in the data model but will not be implemented, tested, or delivered in this phase.

**Scope authority:** `reference/MPP_Scope_Matrix.xlsx` is the definitive in/out boundary. Any scope change requires written agreement from both parties.

**Related documents:**

| Document | Purpose |
|---|---|
| Flexware FRS v1.0 (3/15/2024) | Functional requirements (what the system needs to do) |
| `MPP_MES_SUMMARY.md` | System summary with scope flags and data model overview |
| `MPP_MES_DATA_MODEL.md` | Column-level data model specification v1.7 (8 schemas, ~70 tables — adds Tools schema and `Workorder.WorkOrderType` in Phase B rollup) |
| `MPP_MES_ERD.html` | Interactive ERD with scope badges |
| `MPP_MES_USER_JOURNEYS.md` | Narrative user journeys with validated assumptions |
| `sql_best_practices_mes.md` | SQL design conventions guiding the schema |
| `reference/MPP_Scope_Matrix.xlsx` | Scope authority |

---

## Document Conventions

**Requirement keywords** per RFC 2119:

| Keyword | Meaning |
|---|---|
| **SHALL** | Mandatory — must be implemented and tested |
| **SHALL NOT** | Prohibited — must not be implemented |
| **SHOULD** | Recommended — implement unless there is a documented reason not to |
| **MAY** | Optional — may be implemented at Blue Ridge's discretion |
| **FUTURE** | Designed for but not delivered in this phase |

**Requirement numbering:** `FDS-XX-NNN` where XX is the section number and NNN is sequential within that section. Example: `FDS-05-012` is the 12th requirement in Section 5.

**FRS crosswalk:** Where an FDS requirement traces to a specific FRS requirement, the FRS ID is noted in parentheses. Example: `(FRS 3.9.6)`.

**Scope tags:** Each section and sub-section is tagged with its scope status: `MVP`, `MVP-EXPANDED`, `CONDITIONAL`, or `FUTURE`.

---

## Glossary

### Production Terms

| Term | Definition |
|---|---|
| **LOT** | A collection of parts tracked as a single unit through the plant. Also called Parent LOT. Identified by a unique LTT barcode. |
| **Sub-LOT** | A portion of a LOT split off for downstream processing. Maintains permanent genealogy link to parent. Also called Child LOT. |
| **LTT** | LOT Tracking Ticket — the physical barcoded label attached to a basket or container of parts. Pre-printed by MPP. |
| **Heat** | A single furnace/melt mass with common metallurgical properties. Not tracked in MES (tracked in Macola ERP). |
| **Basket** | A reusable device for moving parts within the factory. Not a shipping container. |
| **Container** | A Honda-specified shipping container packed with finished goods in trays. Receives an AIM shipper ID. |
| **Tray** | A subdivision within a shipping container. Each tray holds a configured number of parts. |
| **Dunnage** | Returnable packing materials specified by Honda per product. |
| **Finished Good** | A final product ready for shipment to the customer (Honda). |
| **WIP** | Work-in-progress — partially finished goods between operations. |
| **Pass-Through Part** | A part received from an external vendor that MPP does not manufacture, only assembles. Enters MES at receiving. |
| **Genealogy** | The complete record of all parts, materials, and work history that produced a given part. Queryable in both directions (parent→child, child→parent). |
| **FIFO** | First-in-first-out — the default queue order for LOTs at machining operations. Operator-overridable. |

### Quality Terms

| Term | Definition |
|---|---|
| **Hold** | A quality status that prevents further manufacturing operations on a LOT. Can be precautionary or triggered by customer complaint. |
| **NCM** | Non-Conformance Management — formal defect tracking with disposition codes. FUTURE capability. |
| **Sort Cage** | A physical plant location where held containers are unpacked, parts re-inspected, and re-packed. |
| **Defect Code** | A coded reason for a rejected part (~145 codes organized by area). |
| **Disposition** | The decision made about non-conforming parts: USE_AS_IS, REWORK, SCRAP, RETURN_TO_VENDOR. FUTURE capability. |

### System Terms

| Term | Definition |
|---|---|
| **MES** | Manufacturing Execution System — this system. |
| **Manufacturing Director** | The legacy WPF/.NET MES being replaced. |
| **Ignition** | Inductive Automation's industrial platform. Hosts the MES application. |
| **Perspective** | Ignition's web-based HMI module. All operator screens are Perspective views. |
| **Gateway** | The Ignition server process that hosts projects, connects to databases, and serves Perspective sessions. |
| **Perspective Workstation** | A dedicated kiosk-mode Perspective client. Used on fixed shop-floor terminals. |
| **OPC UA** | Open Platform Communications Unified Architecture — the protocol for PLC/device communication. |
| **OmniServer** | OPC server handling scale/weight integrations. |
| **TOPServer** | OPC server handling assembly PLC integrations (Mitsubishi). |
| **MIP** | Machine Integration Panel — the PLC-side handshake interface at assembly stations. |
| **AIM** | Honda's EDI system for shipping. Provides shipper IDs and manages hold notifications. |
| **Macola** | MPP's ERP system. FUTURE integration target. |
| **Intelex** | MPP's existing QC document management system. FUTURE integration target. |
| **PD / Productivity Database** | Legacy custom application for production/downtime/OEE data entry. MES replaces this. |
| **AD** | Active Directory — the identity provider for user authentication. |
| **ZPL** | Zebra Programming Language — the label format for Zebra barcode printers. |

### Data Model Terms

| Term | Definition |
|---|---|
| **Schema** | A logical grouping of related tables in the database. The MES has 7 schemas: location, parts, lots, workorder, quality, oee, audit. |
| **Surrogate PK** | Auto-incrementing integer primary key. Natural keys (lot names, part numbers) are unique-indexed columns, not PKs. |
| **Soft Delete** | `DeprecatedAt` timestamp — non-null means inactive. No physical row deletion. |
| **Code Table** | A lookup table backing a status or type field (e.g., `LotStatusCode`). Prevents magic integers and free-text drift. |
| **Append-Only** | Tables where rows are only inserted, never updated or deleted. Used for events, movements, and logs. |
| **Adjacency List** | A self-referential FK pattern (`ParentId → SameTable.Id`) enabling recursive hierarchy queries via CTEs. Used for location hierarchy and LOT genealogy. |

---

## 1. System Architecture Overview — `MVP`

### 1.1 Architecture Principles

| Principle | Implementation |
|---|---|
| **Single platform** | All MES functionality runs on Ignition. No external application servers, middleware, or custom services outside the Ignition ecosystem (except SQL Server). |
| **Web-native UI** | All operator and engineering screens are Ignition Perspective views, served via browser or Perspective Workstation to shop-floor terminals. No desktop clients. |
| **Database as system of record** | SQL Server 2022 is the authoritative store for all transactional MES data. Ignition Tag Historian handles time-series process data separately. |
| **Event-sourced traceability** | Every state change (LOT creation, movement, status transition, production event, consumption) is recorded as an immutable append-only event. Current state is derived from events. |
| **Logged external interfaces** | External system calls (AIM, Zebra printers) are executed directly from the Ignition scripting layer. Every call — request payload, response payload, and any error condition — is logged to `Audit.InterfaceLog`. High-fidelity logging can be toggled per FRS 3.17.4. No outbox table or background worker is required. (FRS 3.17.4, Spark Dependency B.12) |
| **Separation of concerns** | Plan layer (what should happen) is separated from execution layer (what is happening) and evidence layer (what did happen). See Data Flow Summary in Section 1.4. |

### 1.2 System Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                        PLANT NETWORK                            │
│                                                                 │
│  ┌──────────────┐     ┌──────────────────┐    ┌─────────────┐  │
│  │  Ignition     │     │  SQL Server 2022 │    │  Ignition   │  │
│  │  Gateway      │────▶│  Standard Ed.    │    │  Tag        │  │
│  │  Server       │     │                  │    │  Historian   │  │
│  │  (Primary)    │     │  MES Database    │    │  (on GW)    │  │
│  │               │     │  (7 schemas)     │    │             │  │
│  │  Win Server   │     │  Win Server      │    │             │  │
│  │  4+ cores     │     │  4+ cores        │    │             │  │
│  │  16GB RAM     │     │  32GB RAM        │    │             │  │
│  └──────┬───────┘     └──────────────────┘    └─────────────┘  │
│         │                                                       │
│    ┌────┴────────────────────────────────┐                      │
│    │         Ignition Perspective         │                      │
│    │         (Web Sessions)               │                      │
│    └────┬──────┬──────┬──────┬───────────┘                      │
│         │      │      │      │                                   │
│    ┌────┴┐ ┌──┴──┐ ┌─┴──┐ ┌┴─────┐                            │
│    │DC   │ │Trim │ │Mach│ │Assy  │  Shared terminals            │
│    │Terms│ │Terms│ │Terms│ │Terms │  (fewer than machines;       │
│    └──┬──┘ └──┬──┘ └──┬─┘ └──┬───┘   machine resolved by scan)  │
│       │       │       │      │                                   │
│  ┌────┴───────┴───────┴──────┴───────────────────┐              │
│  │              OPC / Device Layer                 │              │
│  │                                                 │              │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  │              │
│  │  │OmniServer │  │TOPServer  │  │ Zebra     │  │              │
│  │  │(Scales)   │  │(PLCs -    │  │ Printers  │  │              │
│  │  │           │  │ Mitsubishi│  │ (ZPL)     │  │              │
│  │  └───────────┘  └───────────┘  └───────────┘  │              │
│  └────────────────────────────────────────────────┘              │
│                                                                  │
│  ┌──────────────────┐                                           │
│  │  AIM (Honda EDI) │  ◀── via event outbox, async              │
│  └──────────────────┘                                           │
└──────────────────────────────────────────────────────────────────┘
```

#### FDS-01-001 — Ignition Gateway
The system SHALL run on a single Ignition Gateway Server on Windows Server 2019 or later (minimum 4 cores, 16GB RAM). The Gateway SHALL host the Perspective project, OPC device connections, Tag Historian, Gateway Scheduled Scripts, and all MES application logic.

#### FDS-01-002 — Database Server
The system SHALL use Microsoft SQL Server 2022 Standard Edition on a dedicated Windows Server instance (minimum 4 cores, 32GB RAM). The MES database SHALL use the 7-schema structure defined in `MPP_MES_DATA_MODEL.md`.

#### FDS-01-003 — Redundancy
Gateway redundancy is NOT included in current scope. The system SHOULD be architected so that a redundant gateway can be added in a future phase without schema or application changes.

#### FDS-01-004 — Development/Test Environment
A separate development/test Ignition Gateway SHALL be provisioned, mirroring production specifications. The development database MAY share the production SQL Server instance as a separate database, or reside on a dedicated instance.

### 1.3 Scope Matrix Cross-Reference

The definitive scope boundary is `reference/MPP_Scope_Matrix.xlsx`. The complete 37-row cross-reference with data model coverage is maintained in `MPP_MES_SUMMARY.md` Section "Scope Assessment." This FDS implements all MVP and MVP-EXPANDED items, and CONDITIONAL items where noted.

### 1.4 Data Flow Architecture

The MES operates across four logical layers. Each layer has distinct immutability and access patterns:

```
PLAN LAYER (what should happen — mutable, versioned)
    Parts.Item → Parts.RouteTemplate → Parts.RouteStep → Parts.OperationTemplate
    "This product follows this route, collecting this data at each stop"

EXECUTION LAYER (what is happening — mutable current state)
    Workorder.WorkOrder → Workorder.WorkOrderOperation
    "This LOT is being processed at this location, at this step"

EVIDENCE LAYER (what did happen — immutable, append-only)
    Workorder.ProductionEvent    "This many good/bad parts came out"
    Workorder.ConsumptionEvent   "These source LOTs were consumed to make this output"
    Workorder.RejectEvent        "Here's why the bad parts were bad"

TRACEABILITY LAYER (the permanent record — immutable, append-only)
    Lots.LotGenealogy            "Parent/child relationships from splits, merges, consumption"
    Lots.LotMovement             "Where this LOT has been"
    Lots.LotStatusHistory        "Quality status transitions"
    Lots.SerializedPart          "Individual serial numbers traced to source LOTs"
    Lots.ShippingLabel           "What shipped to Honda, with AIM shipper IDs"
```

#### FDS-01-005 — Event Immutability
Evidence layer and traceability layer records SHALL be append-only. Once written, they SHALL NOT be updated or deleted. Corrections are recorded as new events, not overwrites. (FRS 3.5.4, 3.9.6)

#### FDS-01-006 — External Interface Dispatch Pattern
External system calls (AIM API, Zebra label printing) SHALL be executed directly from the Ignition scripting layer (Gateway Scripts or Perspective session event handlers). All calls — request payload, response payload, and any error condition — SHALL be logged to `Audit.InterfaceLog`. High-fidelity logging (full request/response capture) SHALL be configurable per FRS 3.17.4. (FRS 3.17.4, 5.5.1, Spark Dependency B.12)

> ✅ **RESOLVED — OI-01:** The FRS requires logging of interface activity (FRS 3.17.4), not an event outbox or async dispatch pattern. External calls are made directly from the Ignition application layer with results logged to `InterfaceLog`. No outbox table, no background worker. This keeps the architecture simple and the database focused on MES transactional data.

#### FDS-01-007 — Tag Historian Separation
Process data (PLC tag values, scale readings, cycle time measurements) SHALL be stored in Ignition's Tag Historian, not in the MES SQL database. The MES SQL layer stores transactional records (LOTs, events, movements); the Historian stores time-series data. The two systems are complementary, not duplicative. (FRS 3.4.10, 5.5.1)

#### FDS-01-013 — BOM Source System at Cutover — `MVP`

**OI-13 resolution (pending MPP IT confirmation of export format):** Authoritative Bills of Material for MPP parts live in the legacy **Flexware application at IP `.919`** — the predecessor MES being replaced by this project. The new MES `Parts.Bom` and `Parts.BomLine` tables SHALL be seeded from a one-shot export of the Flexware BOM master at cutover.

- **Transfer mode:** One-shot CSV or Excel export handed off by MPP IT at cutover — no ongoing integration, since Flexware is being retired as part of the same rollout.
- **Bulk-load proc:** A dedicated `Parts.Bom_BulkLoadFromSeed` stored procedure SHALL accept the export payload (JSON) and populate `Parts.Bom` + `Parts.BomLine` in a single transaction, idempotent on re-run, mirroring the pattern of `Oee.DowntimeReasonCode_BulkLoadFromSeed` (§9.3).
- **Versioning:** All imported BOMs enter as `VersionNumber = 1` in the Published state (`PublishedAt` set at import time). Post-cutover revisions follow the standard three-state clone-to-modify lifecycle (FDS-03-005).
- **Validation:** Every child item reference SHALL resolve to a `Parts.Item` row already imported; unresolved references abort the entire import transaction with a specific error listing the missing items.

Detail and data migration plan live in §14. Export format specification is the open action item on MPP IT.

### 1.5 OPC Connection Architecture

#### FDS-01-008 — OPC Server Connections
The Ignition Gateway SHALL connect to the following OPC servers:

| OPC Server | Purpose | Protocol | Lines Served |
|---|---|---|---|
| **OmniServer** | Scale/weight integration | OPC DA/UA bridge | Trim Shop scales, inspection line scales (59B, 5PA, 5G0 weight stations) |
| **TOPServer v5** | Assembly PLC integration | OPC DA/UA bridge | 5G0 Assembly (Fronts/Rears), PNA Assembly, serialized lines |
| **Cognex In-Sight** | Vision system part confirmation | OPC DA | Die Cast barcode decode, select assembly stations |
| **Mitsubishi MIP PLCs** | Machine Integration Panels | Via TOPServer | 6B2, 6MA, RPY, 6FB cam holder lines |

#### FDS-01-009 — OPC Tag Namespace
All OPC tags SHALL be organized under a consistent namespace: `[OPCServer]/[LineName].[DeviceName].[TagName]`. Tag definitions are maintained in Appendix D (OPC Tag Map).

### 1.6 Security Architecture

#### FDS-01-010 — Authentication
**Interactive users** (Quality, Supervisor, Engineering, Admin) SHALL authenticate via Active Directory. The Ignition Gateway SHALL be configured with an AD User Source. **Operators** SHALL NOT authenticate — they are identified by initials entered at a shop-floor terminal and stamped on events (see §4). Operator `AppUser` rows exist for attribution only and are managed through the Configuration Tool; they carry no AD account. (FRS 5.3)

#### FDS-01-011 — Authorization
Role-based access control SHALL be managed through Ignition's internal security system. AD groups SHALL map to Ignition security roles. Screen and function-level permissions SHALL be enforced via Ignition security zones. No custom RBAC tables in the MES database. (FRS Spark Dependency B.8)

#### FDS-01-012 — Audit Attribution
Every state-changing action SHALL be attributed to a user and terminal location. The `AppUser.Id` and `TerminalLocationId` (FK to `Location` where type = Terminal) are recorded on all mutable and event records. Actions performed by system processes (scheduled scripts, PLC-triggered events) SHALL use a designated system user account.

### 1.7 Database Design Conventions

The MES database follows these conventions consistently. Full column-level specifications are in `MPP_MES_DATA_MODEL.md`.

| Convention | Rule |
|---|---|
| Naming | `UpperCamelCase` singular nouns for tables and columns (e.g., `LocationType`, `PieceCount`) |
| Primary keys | Surrogate `INT IDENTITY` — natural keys are `UNIQUE`-indexed columns |
| Soft deletes | `DeprecatedAt DATETIME2(3) NULL` — non-null = inactive |
| Timestamps | `DATETIME2(3)` everywhere — millisecond precision |
| Measurements | `DECIMAL(x,y)` — never `FLOAT`; UOM as an explicit companion column |
| Status fields | FK to code table — no magic integers or free-text |
| Mutable records | `CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy` |
| Immutable records | `CreatedAt` only (or domain-specific timestamp like `RecordedAt`) — no update columns |
| Hierarchies | Adjacency list with self-referential FK; queried via recursive CTEs |
| Versioning | BOMs, routes, and quality specs carry `VersionNumber` + `EffectiveFrom` + `DeprecatedAt` |
| High-volume logs | `BIGINT IDENTITY` PKs on audit tables |

---

## 2. Plant Model & Location Hierarchy — `MVP`

### 2.1 Design Overview

The plant model implements the ISA-95 equipment hierarchy using a polymorphic three-tier classification:

1. **`LocationType`** — broad ISA-95 category (Enterprise, Site, Area, Work Center, Cell). Five rows total.
2. **`LocationTypeDefinition`** — specific *kind* within a type (e.g., for type `Cell`: Terminal, DieCastMachine, CNCMachine, InventoryLocation). Every location has a definition; different definitions carry different attribute schemas.
3. **`LocationAttributeDefinition`** — attribute schema per definition (e.g., `Terminal` has `IpAddress`, `DefaultPrinter`; `DieCastMachine` has `Tonnage`, `NumberOfCavities`).

Every physical and logical place in the plant — from the enterprise itself down to individual machines, terminals, staging areas, and the Sort Cage — is a row in the single `Location` table, differentiated by its `LocationTypeDefinition`. The hierarchy is queried with recursive CTEs on `ParentLocationId` (adjacency list). (FRS 3.3.1–3.3.4, 3.7.1)

**Why three tiers instead of two?** In the previous design, `LocationType` was used both as an ISA-95 tier marker AND a discriminator between "kinds" (Machine vs. Terminal vs. InventoryLocation). That conflated two concerns: *where in the hierarchy this sits* (an ISA-95 question) with *what kind of thing this is* (a polymorphism question). Splitting them gives clean separation: `LocationType` answers "what tier?" and `LocationTypeDefinition` answers "what kind?" Attribute schemas attach to the definition, not the tier — so a `Terminal` and a `DieCastMachine` can both be Cells but carry completely different attribute sets.

### 2.2 Location Type Hierarchy

#### FDS-02-001 — ISA-95 Location Types
The system SHALL seed five `LocationType` rows at deployment, corresponding to the ISA-95 equipment hierarchy tiers. These SHALL NOT be editable by operators or engineering users.

| Code | Name | HierarchyLevel | Description |
|---|---|---|---|
| Enterprise | Enterprise | 0 | Top-level organization — the company as a whole |
| Site | Site | 1 | A physical manufacturing plant/facility |
| Area | Area | 2 | Subdivision within a site (production areas, support areas) |
| WorkCenter | Work Center | 3 | Production line or grouping of equipment |
| Cell | Cell | 4 | Individual station or unit — machines, terminals, inventory locations, scales |

> **ISA-95 note:** The prior "Department" concept has been merged into Area — at MPP, every organizational department (Die Cast, Trim Shop, Machine Shop, Production Control, Quality Control) maps 1:1 to a physical area of the plant. Area-type locations serve both the physical hierarchy role and the organizational grouping role (defect codes, downtime reason codes, and operation templates reference Areas). ISA-95's "Machine" and "Work Cell" distinction has been collapsed into the single `Cell` tier — the distinction between a CNC machine and a manual assembly station is captured by `LocationTypeDefinition`, not by a separate hierarchy level.

#### FDS-02-002 — Hierarchy Enforcement
The system SHOULD validate that child locations have a `HierarchyLevel` greater than or equal to their parent's level, determined by joining through `LocationTypeDefinition` to `LocationType`. The system SHALL NOT enforce strict sequential levels — a Cell MAY be a direct child of an Area if no Work Center level exists for that area.

#### FDS-02-003 — Areas as Instances
MPP's five operational areas SHALL be created as `Location` instances at deployment, each with an appropriate `LocationTypeDefinition` (`ProductionArea` or `SupportArea`):

| Area Name | Definition | Role |
|---|---|---|
| Die Cast | ProductionArea | Die cast operations (LOT origin point) |
| Trim Shop | ProductionArea | Trim operations |
| Machine Shop | ProductionArea | CNC machining operations |
| Production Control | SupportArea | Scheduling, shipping, receiving |
| Quality Control | SupportArea | Inspection, holds, sort cage |

Areas are referenced by defect codes, downtime reason codes, and operation templates for filtering. Die Cast screens show only Die Cast defect codes; Machine Shop screens show only Machine Shop codes. (FRS 3.3.2, 3.7.1)

### 2.3 Polymorphic Kinds and Configurable Attributes

#### FDS-02-004 — Location Type Definitions (Kinds)
Within each `LocationType`, the system SHALL support one or more `LocationTypeDefinition` rows representing the specific *kinds* of location that exist at that tier. Every `Location` instance references exactly one `LocationTypeDefinition`, which determines both its ISA-95 tier (via `LocationTypeId`) and its attribute schema (via attached `LocationAttributeDefinition` rows).

**Analogy:** If `LocationType` is "Writing Implements," `LocationTypeDefinition` rows are "Pen," "Pencil," "Marker" — each with distinct attributes. A specific "Bic ballpoint, black" is a `Location` of definition "Pen."

For MPP, the initial seeded definitions are:

| LocationType | Definition Code | Purpose |
|---|---|---|
| Enterprise | Organization | The company root node (single instance) |
| Site | Facility | A physical manufacturing plant |
| Area | ProductionArea | Die Cast, Trim Shop, Machine Shop, Assembly |
| Area | SupportArea | Production Control, Quality Control |
| WorkCenter | ProductionLine | Generic production line within an area |
| WorkCenter | InspectionLine | Multi-part inspection lines (e.g., MS1FM-1028) |
| Cell | Terminal | Shared operator HMI station |
| Cell | DieCastMachine | Die cast press |
| Cell | CNCMachine | Machining center |
| Cell | TrimPress | Trim shop press |
| Cell | AssemblyStation | Manual assembly station |
| Cell | SerializedAssemblyLine | PLC-integrated serialized assembly (5G0, etc.) |
| Cell | InspectionStation | Manual or vision-based inspection station |
| Cell | InventoryLocation | WIP, Receiving Dock, Shipping Dock, Sort Cage |
| Cell | Scale | OmniServer-connected weight scale |

Definitions are extensible — engineering users MAY add new definitions via the configuration tool without schema changes.

#### FDS-02-005 — Attribute Schemas per Definition
Each `LocationTypeDefinition` carries its own set of `LocationAttributeDefinition` rows specifying the attributes that instances of that kind can have. Different definitions within the same type carry entirely different attribute sets. The example below shows three Cell-tier definitions and their distinct attribute schemas.

**Example 1 — `Cell` → `Terminal` definition:**

| AttributeName | DataType | Required | Uom | Description |
|---|---|---|---|---|
| IpAddress | VARCHAR | No | — | Terminal IP for diagnostics |
| DefaultPrinter | VARCHAR | No | — | Associated Zebra printer name for label output |
| HasBarcodeScanner | BIT | Yes | — | Whether terminal has scanner hardware |

**Example 2 — `Cell` → `DieCastMachine` definition:**

| AttributeName | DataType | Required | Uom | Description |
|---|---|---|---|---|
| Tonnage | DECIMAL | No | tons | Die cast press tonnage |
| NumberOfCavities | INT | No | — | Die cast cavity count |
| RefCycleTimeSec | DECIMAL | No | seconds | Reference cycle time for OEE performance calculation |
| OeeTarget | DECIMAL | No | — | Target OEE (0.00–1.00). FUTURE — designed for but not used in MVP. |

**Example 3 — `Cell` → `InventoryLocation` definition:**

| AttributeName | DataType | Required | Uom | Description |
|---|---|---|---|---|
| IsPhysical | BIT | Yes | — | Physical location vs. logical bucket |
| IsLineside | BIT | No | — | Whether this is a lineside staging area |
| MaxLotCapacity | INT | No | — | Maximum LOTs that can be stored here |

Note that all three are Cells — same ISA-95 tier, same `LocationType` — but their attribute schemas are completely disjoint. This is the polymorphism the three-tier model enables.

#### FDS-02-006 — Attribute Value Integrity
A `LocationAttribute.LocationAttributeDefinitionId` SHALL reference an attribute definition whose `LocationTypeDefinitionId` matches the containing location's `LocationTypeDefinitionId`. An operator SHALL NOT be able to set a `Tonnage` value on a Terminal, because `Tonnage` belongs to the `DieCastMachine` definition, not the `Terminal` definition. This integrity rule is enforced in application logic (no single-column SQL constraint can express it without denormalization).

### 2.4 Seed Data — Cells

#### FDS-02-007 — Machine Seed Data
The ~230 machines from FRS Appendix B SHALL be loaded as seed data during deployment. Each machine SHALL be created as a `Location` record with an appropriate Cell-tier `LocationTypeDefinition` (e.g., `DieCastMachine`, `CNCMachine`, `TrimPress`), parented under the appropriate Area or Work Center, with attribute values populated from the appendix (tonnage, cycle times where available).

### 2.5 Terminals

> ✅ **RESOLVED — OI-08 / UJ-12 with 2026-04-20 addenda:** Terminals are a mix of **dedicated** (≈80% — 1:1 with a Cell) and **shared** (≈20% — e.g., trim shop with multiple stations served by one terminal). `Terminal` remains a `LocationTypeDefinition` under the `Cell` type. The dedicated-vs-shared mode is captured as a `LocationAttribute` on each Terminal (see FDS-02-010) and drives presence behaviour (§4). Operators cannot navigate a terminal off its mounted-machine context — a new machine context requires an explicit re-scan. Part ↔ machine validity is enforced via `Parts.ItemLocation` (§3.5). Honda plans to place RFID tags on container labels in the future; the MES SHALL stay RFID-agnostic (FUTURE).

#### FDS-02-008 — Terminal as Cell Kind
Each Ignition Perspective client station on the shop floor SHALL be registered as a `Location` record with `LocationTypeDefinition` = `Terminal` (which resolves to `LocationType` = `Cell`), parented under the appropriate Area in the hierarchy. Terminal-specific configuration (IP address, default Zebra printer, barcode scanner availability, **terminal mode** per FDS-02-010) SHALL be stored as `LocationAttribute` entries referencing the attribute definitions attached to the `Terminal` definition (see FDS-02-005 Example 1).

#### FDS-02-009 — Machine Context via Barcode Scan
The operator's first action at any terminal in a new session SHALL be to scan a machine barcode or QR code. The system SHALL resolve the scanned value to a `Location` record whose `LocationTypeDefinition` is a machine kind (`DieCastMachine`, `CNCMachine`, `TrimPress`, `AssemblyStation`, etc.) and use that Cell as the production context for subsequent operations in the session. Event tables carry two location references:

- `TerminalLocationId` — FK → `Location.Id` where the definition is `Terminal` (where the operator is standing)
- `LocationId` — FK → `Location.Id` where the definition is a machine kind (which machine they scanned)

On **Dedicated** terminals (FDS-02-010) the machine context SHALL be the Terminal Location's parent Location (itself a WorkCenter or Cell tier) — no per-session scan required. On **Shared** terminals the operator SHALL scan the machine barcode at the start of the session and SHALL re-scan to switch machines — direct in-UI navigation between machines SHALL NOT be offered (FDS-02-011).

#### FDS-02-010 — Terminal Mode Determined by Location Assignment — `MVP` (revised v0.11e)

A Terminal's mode (Dedicated or Shared) is **derived from the tier of its parent Location in the ISA-95 hierarchy**. No separate `TerminalMode` attribute is configured.

| Terminal's parent Location tier | Mode | Behavior |
|---|---|---|
| **WorkCenter** or **Cell** | **Dedicated** | Terminal is bound to a specific cell / workcenter context. Machine context is the parent Location — never prompted, never scanned. Operator initials persist through the shift with 30-min idle re-confirmation (FDS-04-006). Example: `DC-07-TERM` Terminal whose parent is `DC-07` Die Cast Machine (Cell tier). |
| **Area** | **Shared** | Terminal serves multiple Cells under an Area. Machine context (the specific Cell within the Area) SHALL be prompted on first action and whenever the operator switches Cells via a barcode re-scan. Initials presence SHALL be re-prompted on first action after idle, and on machine-context change. Example: `TRIM-TERM-A` Terminal whose parent is `Trim Shop` Area, serving all Cells under it. |

The Gateway `Terminal_ResolveFromSession` proc SHALL read the Terminal Location's parent tier via the Location hierarchy and return `TerminalMode` as a derived result (not a stored attribute). Configuration Tool Location admin screens SHALL let Engineering attach a Terminal under any WorkCenter, Cell, or Area — the mode follows automatically.

**Rationale (Jacques's 2026-04-24 framing):** The mode **is** the assignment. A Terminal parked under a specific Cell IS a dedicated terminal for that Cell; a Terminal parked under an Area IS a shared terminal for that Area. Encoding mode as a separate attribute is redundant with the tree structure and invites drift between the two.

FUTURE: an `AutoReleaseOnIdle` attribute may be added to tune the re-confirmation interval per terminal — out of MVP.

#### FDS-02-011 — Terminal Machine-Context Lock
The UI SHALL NOT offer a dropdown, search, or other navigation control that lets the operator change the active machine context without a physical barcode re-scan. A "Force print" or equivalent workflow that requires switching to a different machine SHALL trigger the machine-scan prompt and write the new `LocationId` on any subsequent events. This prevents inadvertent cross-machine event attribution (the primary failure mode raised by MPP in the 2026-04-20 review).

#### FDS-02-012 — Part ↔ Machine Validity
The set of parts eligible to run on a given machine SHALL be governed by the existing `Parts.ItemLocation` eligibility junction (FDS-03-014). Scan-in workflows SHALL reject a LOT whose `ItemId` is not eligible on the active machine's `LocationId`, with a clear error message ("Part 59B is not configured to run on DC-07"). Eligibility is Engineering-owned in the Configuration Tool; no duplicate table is needed for terminals.

#### FDS-02-013 — Mobile-Friendly Design Input
MPP plans to deploy **tablets** in the Die Cast area. Perspective views used on Die Cast screens SHALL be designed with tablet-friendly layouts (touch targets ≥ 44 px, one-handed operation where practical, portrait-orientation support). This is not a per-screen MVP requirement but an ongoing design constraint — tablet rollout can happen post-cutover without re-designing screens.

#### FDS-02-014 — Honda RFID Forward-Compatibility — `FUTURE`
Honda plans to add RFID tags to container labels at a future date. The MES SHALL NOT embed assumptions that prevent RFID integration (e.g., hard-coding barcode as the only identifier input). `Lots.LotLabel` and `ShippingLabel` schemas already accept label identifier strings without prescribing the capture method; an RFID reader MAY feed the same identifier the barcode scanner does. No MVP work is required; this requirement is a design guardrail.

---

## 3. Master Data Management — `MVP`

### 3.1 Item Master

#### FDS-03-001 — Item Records
Every part number that MPP manufactures, receives, or ships SHALL have an `Item` record. Each item SHALL have: part number (unique), description, item type, Macola cross-reference number (optional — FUTURE integration), counting UOM, unit weight, weight UOM, default sub-lot quantity, max lot size, and **Country of Origin (ISO 3166-1 alpha-2)**. (FRS 3.4.1–3.4.5; OI-19)

> **OI-19 (new v0.10):** Country of Origin is a Honda compliance field surfaced on the legacy Flexware Material configuration. Stored as `Parts.Item.CountryOfOrigin NVARCHAR(2) NULL` (nullable because MPP's current parts list may not have values for every row at cutover; the Configuration Tool will expose a maintenance screen to backfill).

#### FDS-03-002 — Item Types
Items SHALL be classified by type. The following types SHALL be seeded:

| Type | Description | Example |
|---|---|---|
| Raw Material | Input materials | Aluminum ingot (tracked in Macola only, not MES per FRS 3.9.1) |
| Component | Manufactured intermediate part | 5G0 casting (pre-machining) |
| Sub-Assembly | Partially assembled product | 5G0 machined casting with pins |
| Finished Good | Shippable end product | 5G0 Front Cover Assembly |
| Pass-Through | Vendor-supplied, not manufactured by MPP | 6MA Cam Holder housing |

#### FDS-03-003 — Item Deprecation
Items SHALL NOT be deleted. Inactive items SHALL be soft-deleted via `DeprecatedAt`. Deprecated items SHALL NOT appear in operator selection lists but SHALL remain queryable for historical traceability.

### 3.2 Bills of Material

#### FDS-03-004 — BOM Structure
Each assembled product SHALL have a versioned BOM defining its component parts. BOMs SHALL support: parent item, version number, effective date, and soft delete. BOM lines SHALL specify: child item, quantity per parent, UOM, and sort order. (FRS 3.4.2)

#### FDS-03-005 — BOM Versioning
When a BOM is revised, a new version SHALL be created with a new `EffectiveFrom` date. The previous version SHALL be soft-deleted (`DeprecatedAt` set). Production records SHALL FK to the BOM version active at time of manufacture, ensuring historical accuracy. (FRS Spark Dependency B.3)

#### FDS-03-006 — Single-Level BOMs
BOMs SHALL be single-level (one parent → multiple children). Multi-level BOM explosion is NOT required for MVP. If multi-level is needed in the future, recursive CTE queries across single-level BOMs provide the capability without schema changes.

### 3.3 Route Templates

#### FDS-03-007 — Route Structure
Each manufactured item SHALL have a versioned route template defining the ordered sequence of operations it passes through. Routes SHALL support: item, version number, name, effective date, and soft delete. (FRS 3.11.1–3.11.4)

#### FDS-03-008 — Route Steps
Each route template SHALL contain ordered route steps. Each step SHALL reference an operation template (what data to collect) and carry a sequence number and required flag.

#### FDS-03-009 — Route Steps Do Not Prescribe Machines
Route steps SHALL reference an operation template, which defines the area and data collection requirements. Route steps SHALL NOT reference a specific machine or location. The operator selects from eligible machines at runtime based on the `ItemLocation` eligibility map. (FRS 3.11.6; confirmed per architectural review 2026-04-06)

#### FDS-03-010 — Route Versioning
When a route is revised, a new version SHALL be created. Production records SHALL FK to the route version active at time of execution. (FRS Spark Dependency B.4)

#### FDS-03-011 — Operation Sequence Flexibility
The system SHALL allow insertion and deletion of operations within a route during execution (FRS 3.11.10). This enables handling parts that skip steps or require additional operations beyond the standard route.

### 3.4 Operation Templates

#### FDS-03-012 — Operation Template Design
Operation templates define what data to collect at a type of operation. They are reusable across products and versioned (Draft/Published/Deprecated). Each template SHALL specify:

| Field | Purpose |
|---|---|
| Code, VersionNumber | Identity within a version family |
| Name | Human-readable label |
| AreaLocationId | Area this operation belongs to (for defect/downtime code filtering) |
| Description | Optional notes |
| *(data collection requirements)* | Defined by `OperationTemplateField` rows referencing `DataCollectionField` — not hardcoded on the template itself |

Data collection requirements are modeled as a one-to-many junction (`Parts.OperationTemplateField`) linking the template to zero-or-more `Parts.DataCollectionField` rows, each with an `IsRequired` flag. `DataCollectionField` is an extensible vocabulary seeded with the initial set (MaterialVerification, SerialNumber, DieInfo, CavityInfo, Weight, GoodCount, BadCount) and expandable by engineering without schema changes. (Replaces the `Collects*` / `Requires*` BIT flags from earlier drafts per data model rev 0.7.)

#### FDS-03-013 — Operation Templates Drive Screen Behavior
The Perspective production screen SHALL dynamically render input fields based on the operation template's `OperationTemplateField` rows. A Die Cast screen shows die/cavity/weight fields; an Assembly screen shows serial number and material verification fields. The same screen component is reused — the junction rows control which sections are visible and whether each field is required. (FRS 3.11.6)

#### FDS-03-017a — Data Collection Capture at Event Time (Checkpoint Shape, v0.11)

When a LOT passes through an operation, the MES writes one **checkpoint event** per operator logging action. Events carry **cumulative** counters (`ShotCount`, `ScrapCount`); deltas are derived by the reader via `LAG()` window function over `(LotId, EventAt)`. Operators are NOT at the terminal per shot — checkpoints are coarse (checkout from die cast, check-in to trim, complete + move, quality-operation transitions). A missed checkpoint does not compound errors; the next event carries truth.

1. On screen load, the client SHALL read `OperationTemplateField` rows for the active template to determine the visible inputs.
2. On submit, the Arc 2 Phase 1 `ProductionEvent_Record` stored procedure SHALL, in one transaction:
   a. Insert one `Workorder.ProductionEvent` header row carrying `LotId`, `OperationTemplateId`, `EventAt`, cumulative `ShotCount` / `ScrapCount` (as-of-event), `ScrapSourceId` (only for scrap-driving checkpoints, per FDS-06-023a), optional `WeightValue` + `WeightUomId`, `AppUserId`, and `TerminalLocationId`.
   b. Insert one `Workorder.ProductionEventValue` child row per non-hot `DataCollectionField` configured on the template, keyed by `(ProductionEventId, DataCollectionFieldId)`, with both the string `Value` and the typed `NumericValue` / `UomId` where applicable.
   c. Reject the submission if any `IsRequired = 1` field on the template is missing from the payload.
   d. Reject the submission if the payload duplicates a hot-column field (`ShotCount`, `ScrapCount`, `WeightValue`) in `ProductionEventValue`.
3. **Tool + Cavity are NOT on `ProductionEvent`.** They live on `Lots.Lot` (`ToolId`, `ToolCavityId`) per FDS-05-035. Reports, exports, and Honda-trace queries derive tool context via `ProductionEvent.LotId → Lot.ToolId / Lot.ToolCavityId`.
4. **Cell / location is NOT on `ProductionEvent`.** It is derivable from `LotMovement` at `EventAt` timestamp — no redundant column on the event.

### 3.5 Part-to-Location Eligibility

#### FDS-03-014 — Eligibility Map with Hierarchy Cascade — `MVP` (revised v0.11d)
The `Parts.ItemLocation` table SHALL define which parts can run where. `LocationId` SHALL accept **any Location tier** — Area, WorkCenter, or Cell.

When an operator scans a LOT into a specific Cell, the MES SHALL validate eligibility by walking UP the Location hierarchy from the scanned Cell:

1. Check for a matching `ItemLocation` row at the scanned Cell directly.
2. If none, check at the Cell's parent WorkCenter (if a WorkCenter tier exists between Cell and Area).
3. If none, check at the parent Area.
4. If none, check at the Site.
5. If no match is found anywhere in the chain, the MES SHALL reject the scan-in with a clear error message.

The helper proc `Parts.ItemLocation_IsEligible(@ItemId, @CellLocationId)` SHALL encapsulate this walk. It returns `IsEligible BIT` + the resolved `ItemLocationId` (of the matching row, whichever tier) + the matching `LocationId` tier, so callers can pick up the consumption metadata from the matching row.

Engineering configures eligibility at the coarsest appropriate tier — e.g., "Part 5G0 eligible across all of Die Cast Area" is one row, not one row per Cell. Engineering MAY also declare Cell-specific overrides (the Cell-level row takes precedence because it matches first).

(FRS 3.4.7)

#### FDS-03-015 — Eligibility Management — `MVP` (revised v0.11d)
Engineering users SHALL be able to add, update, and remove `ItemLocation` rows via the Configuration Tool Eligibility screen. The screen SHALL let the user pick the target Location at any tier (Area / WorkCenter / Cell) when creating a row. Consumption metadata (Min/Max/Default/IsConsumptionPoint) inputs are shown whenever `IsConsumptionPoint` is enabled. Changes SHALL be logged to `Audit.ConfigLog`.

#### FDS-03-018 — Consumption Metadata on Item-Location Eligibility — `MVP` (revised v0.11d)

**OI-18 (extended 2026-04-24):** Each `ItemLocation` row SHALL carry optional **consumption metadata** that drives the runtime Allocations grid at the workstation:

| Field | Purpose |
|---|---|
| `MinQuantity` | Minimum pieces per scan-in of this Item at this Cell |
| `MaxQuantity` | Maximum pieces per scan-in — rejects over-scan (complements FDS-03-019 per-Item MaxParts cap) |
| `DefaultQuantity` | Pre-populated quantity on the Allocations scan form |
| `IsConsumptionPoint` | `1` = the matched tier consumes this Item (input); `0` = produces this Item (output) or eligibility-only |

**Interaction with hierarchy cascade (FDS-03-014):** Consumption metadata lives on the specific `ItemLocation` row that matches, regardless of tier. When an operator scans a LOT into a Cell and eligibility resolves to an ancestor-tier row (e.g., a Die Cast Area row), that ancestor row's consumption metadata applies — there is no independent per-Cell override of metadata absent its own row. Engineering uses a Cell-tier row only when per-Cell metadata differs from what the Area row expresses.

At scan-in, the MES SHALL pre-populate `DefaultQuantity` and validate `MinQuantity ≤ entered ≤ MaxQuantity`. Workstations flagged `IsConsumptionPoint = 1` for a given Item SHALL show that Item in the Allocations grid; others SHALL NOT. These fields SHALL be editable by engineering via the Configuration Tool. Legacy Flexware surfaces these as the "Compatible work cells" columns on the Material configuration screen.

### 3.6 Container Configuration

#### FDS-03-016 — Container Config
Each finished good that ships to Honda SHALL have a container configuration record specifying: trays per container, parts per tray, whether serialized, dunnage code, and customer code. This configuration drives automatic container lifecycle management on the shop floor. (FRS 3.9.7)

#### FDS-03-017 — Container Closure Logic
The system SHALL close a container automatically when the configured capacity is reached. For serialized lines, closure is triggered by part count (tracked per serial). For non-serialized lines, closure MAY be triggered by part count or weight, configurable per container config.

> ✅ **RESOLVED — OI-09 / UJ-15:** Multi-part inspection lines (e.g., MS1FM-1028 running 59B, 5PA, 6NA variants) operate one part number at a time. The operator selects the active LOT for consumption, which determines the part number. Container configuration is resolved per part number. No mixed-part containers. Changeover between part numbers is an operator action, not a concurrent process.

#### FDS-03-019 — Per-Item Per-Location Piece Cap — `MVP`

**OI-12 (revised 2026-04-24):** `Parts.Item.MaxParts INT NULL` SHALL hard-cap the total pieces of this Item allowed at any single Location at any one time. Scan-in mutations (LotMovement of a LOT to a Cell) SHALL:

1. Sum existing pieces of this Item across all non-Closed LOTs currently at the destination Location.
2. Add the incoming LOT's piece count.
3. Reject when the result would exceed `Parts.Item.MaxParts`.

Rationale: MPP reports operators over-scanning material into Cells to minimise re-scans; a configurable per-Item per-Location cap blocks the workaround at the source-of-truth level (the Part), not at the container-packing level. `MaxParts` is NULL-capable for Items that don't require a hard cap.

**Orthogonal to FDS-03-020** (`LinesideLimit` LocationAttribute, Location-scoped across all Items): `MaxParts` caps one Item at one Location; `LinesideLimit` caps the total staging capacity of a Location across everything. Both fire; either can reject the scan-in.

> **Historical note:** An earlier v0.10 draft placed `MaxParts` on `Parts.ContainerConfig` (per-container cap). Jacques's 2026-04-24 OIR review clarified that `MaxParts` is a Part attribute, evaluated at check-in — not a container-packing attribute. Corrected in v0.11c.

#### FDS-03-020 — Lineside Inventory Cap — `MVP`

**OI-12 (new v0.10):** Each Cell (workstation, line-side inventory location) MAY carry a `LinesideLimit` `LocationAttribute` that caps the total pieces across *all* open LOTs of any Item present at that Cell. The scan-in mutation SHALL sum current lineside quantity + incoming scan quantity and reject if the result would exceed `LinesideLimit`. Complements FDS-03-019: the per-container cap stops bloat of one container; the lineside cap stops multiple containers from compounding past a physical staging limit. `LinesideLimit` is a per-Cell LocationAttribute (NOT a per-Item configuration) because the physical constraint is floor space, not part identity.

#### FDS-03-021 — Tray-Divisibility Validation on Work Order — `MVP`

**OI-17 (new v0.10):** The MES SHALL validate at WorkOrder Create / Edit time that the WO target quantity is **evenly divisible by** the Item's `ContainerConfig.PartsPerTray` (and, where applicable, by `TraysPerContainer × PartsPerTray`). Non-divisible targets SHALL be rejected with a specific error code ("Target quantity {X} is not evenly divisible by tray quantity {Y}"). The same check SHALL fire at WO Close: if actual good count is not divisible by the tray quantity, the close is blocked (supervisor AD elevation can override per FDS-04-007 — the override reason is logged). Surfaced as a legacy Flexware error: *"Container processing error — Work order target quantity exceeded. Ensure target quantity is evenly divisible by the tray quantity."*

---

## 4. User Identity, Authentication & Elevation — `MVP`

> ✅ **RESOLVED — OI-06 / UJ-01 (2026-04-20):** Operators do not authenticate. They are identified on a terminal by their initials, which are stamped onto every event. Elevated actions (holds, overrides, scrap, maintenance WOs, admin edits) require an Active Directory login at the moment of action — no session-sticky elevation, no clock-number/PIN convenience login. The 5-minute-timeout proposal is dropped.

### 4.1 Identity Model

#### FDS-04-001 — Two Identity Classes
The MES SHALL recognise two classes of `Location.AppUser`:

| Class | AdAccount | Initials | IgnitionRole | How they identify |
|---|---|---|---|---|
| Operator | NULL | NOT NULL | NULL | Initials entered at a shop-floor terminal |
| Interactive User (Quality, Supervisor, Engineering, Admin) | NOT NULL | NOT NULL | NOT NULL | Active Directory login |

Every event and mutation SHALL stamp `AppUserId` — never free-text initials or names. Initials are a natural key used at the UI layer only; the database records the resolved `AppUserId`.

#### FDS-04-002 — Operator Initials Capture
When an operator approaches a shop-floor terminal to perform their first action, the UI SHALL prompt for initials. The MES SHALL look up the `AppUser` by initials and establish an **operator presence context** on that terminal's Perspective session. No password is verified. The presence context SHALL apply to subsequent events until:

- another operator enters different initials, or
- the terminal has been idle for 30 minutes and the operator answers "No" to the re-confirmation prompt.

Operator presence is NOT an authenticated session. It is a stamping context. The operator cannot perform elevated actions from within it.

#### FDS-04-003 — Terminal Mode: Dedicated vs Shared — `MVP` (revised v0.11e)
Terminal mode is **derived from the Terminal Location's parent tier** in the ISA-95 hierarchy per FDS-02-010 — it is not configured as a separate attribute.

- **Dedicated terminals** (Terminal's parent Location is a WorkCenter or Cell; approx. 80% of the plant). The presence context persists across idle gaps, subject only to the 30-minute re-confirmation prompt. Initials do not clear unless explicitly changed.
- **Shared terminals** (Terminal's parent Location is an Area; trim shop and similar multi-station contexts). The presence context SHALL be requested on first action after any idle period longer than the presence-timeout and SHALL also be re-prompted when the operator scans a machine barcode that differs from the previous machine context (per FDS-02-008 machine-barcode-scan pattern).

#### FDS-04-004 — Interactive User Authentication
Interactive users (Quality, Supervisor, Engineering, Admin) SHALL authenticate via Ignition's Active Directory User Source. AD groups SHALL map to the Ignition roles in FDS-04-008. Operators SHALL NOT exist in AD.

There is no shop-floor-terminal convenience login. An interactive user authorising an elevated action from a shop-floor terminal SHALL enter AD credentials via the elevation prompt described in FDS-04-006. (A badge-scan or RFID-based elevation mechanism is a documented future enhancement aligned with Honda's RFID-on-labels initiative — see OI-08 addenda — but is not in MVP scope.)

### 4.2 Event Attribution on Mutations

#### FDS-04-005 — Pre-Populated Initials Field
Every shop-floor mutation screen (LOT creation, production event, downtime, inspection, container close, etc.) SHALL include an **Initials** field pre-populated from the terminal's presence context. The operator MAY override this value before submission — for example, when a pair-working partner is recording on their behalf.

On submission, the MES SHALL resolve the submitted initials to an `AppUserId` via the `Location.AppUser_GetByInitials` proc. If the initials are unknown or resolve to a deprecated user, the MES SHALL block the submission with a clear validation message; it SHALL NOT auto-create users from unknown initials.

#### FDS-04-006 — 30-Minute Presence Re-Confirmation
After 30 minutes of terminal inactivity, the next operator interaction SHALL trigger a re-confirmation overlay:

> **Operate as [XY]?**
> [ Yes ] [ No — change ]

- **Yes** continues with the existing presence context. Dedicated terminals retain initials through the shift via repeated Yes answers.
- **No — change** opens the initials entry screen. The previous context is cleared.

The 30-minute value SHALL be a Configuration Tool setting (not hard-coded) so MPP can tune it.

### 4.3 Elevation Model

#### FDS-04-007 — Elevated Actions Require Active Directory Authentication
Actions with quality, financial, safety, or master-data impact SHALL require a fresh AD authentication at the moment of action, regardless of operator presence. The action control SHALL open an elevation prompt that accepts AD username and password. On successful authentication the action SHALL be stamped with the authenticating interactive user's `AppUserId`, NOT the operator presence context. On cancel the action SHALL not execute and the UI SHALL return to the prior state.

Elevation is not session-sticky. Each elevated action re-prompts. This removes the 5-minute-timeout concept entirely — elevation is per-action, not per-session.

The initial elevated-action list (the full set will be validated by Tom, MPP's security SME, before Arc 2 screen design freezes):

- Place a LOT on hold
- Release a LOT from hold
- Override a vision or interlock failure
- Scrap a LOT or container
- Void or reprint a shipping label
- Merge or split LOTs outside of the normal sort workflow
- Issue or close a maintenance work order against a tool
- Deprecate an `AppUser`, `Item`, `Bom`, `RouteTemplate`, `OperationTemplate`, `ContainerConfig`, or `Tool`
- Adjust inventory via the admin remove-item action (OI-14)

#### FDS-04-008 — Ignition Role Mapping
Interactive-user roles configured in Ignition's identity provider map to AD groups:

| Role | Backed by AD | Capabilities |
|---|---|---|
| Quality | ✅ | Hold placement/release, inspection entry, LOT splitting for disposition, CRT issuance and release |
| Supervisor | ✅ | All Quality + LOT merge, shipping label void/reprint, interlock/vision override, maintenance WO create/close |
| Engineering | ✅ | Master data — Items, BOMs, Routes, Operation Templates, Container Configs, Tools, Die Ranks |
| Admin | ✅ | All capabilities + AppUser management, Terminal configuration, admin remove-item |

**Operator** is not an Ignition role — it is the absence of any interactive authentication. Shop-floor terminal screens accept operator presence and permit non-elevated actions; elevated actions trigger the FDS-04-007 AD prompt regardless.

#### FDS-04-009 — Screen-Level Security
- Shop-floor terminal screens SHALL be accessible without interactive authentication; operator presence is sufficient.
- Shop-floor screens SHALL NOT expose Configuration Tool or master-data functions.
- Configuration Tool, Supervisor dashboards, and Engineering screens SHALL require AD-backed authentication on page entry.
- Elevated action controls (buttons, menu items) SHALL be visible on shop-floor screens but SHALL trigger the FDS-04-007 prompt on activation. Unauthorised users cancel out.

#### FDS-04-010 — Operator AppUser Lifecycle
Operator `AppUser` rows SHALL be managed by the Configuration Tool (Admin-only screen). MPP has no AD accounts for operators; their rows carry `AdAccount = NULL`, `Initials = NOT NULL, UNIQUE`, and no Ignition role. When an operator's initials would collide with an existing row, the Admin SHALL enter disambiguating initials (e.g., three- or four-character codes). Deprecation follows the standard `DeprecatedAt` soft-delete pattern; events referencing deprecated operators retain the historical `AppUserId`.

---

## 5. LOT Lifecycle & Genealogy — `MVP`

### 5.1 LOT Identity

#### FDS-05-001 — LOT Uniqueness
Each LOT SHALL have a unique `LotName` — the barcode number printed on the physical LTT. LOT names SHALL be system-enforced unique via a database unique constraint. (FRS 3.9.6)

#### FDS-05-002 — LTT Pre-Printing
MPP pre-prints LTT barcodes in batches (FRS 2.2.1). The MES SHALL NOT pre-register LOT IDs before they are scanned. When an operator scans an LTT barcode to create a LOT, the system SHALL create the record at that moment. If the barcode has already been used (duplicate), the system SHALL reject the creation with a clear error. This means LTT barcodes are a pool of unused identifiers — the MES does not manage their inventory.

> **Note:** If MPP requires LTT inventory management (tracking which barcodes have been printed but not yet used), this would be a configuration screen addition. Currently out of scope based on FRS 2.2.1.

#### FDS-05-003 — LOT Attributes
Each LOT SHALL carry:

| Attribute | Source | Description |
|---|---|---|
| LotName | LTT barcode scan | Unique identifier (minted from `Lots.IdentifierSequence`, `Code=Lot`, per §16) |
| ItemId | Operator selection | Which part number |
| LotOriginTypeId | System-determined | Manufactured, RECEIVED, or RECEIVED_OFFSITE |
| LotStatusId | System-managed | Current quality status (GOOD, HOLD, SCRAP, CLOSED) |
| PieceCount | Operator entry | Current count (decremented by consumption, adjusted at Trim) |
| MaxPieceCount | From item master | Reasonability ceiling |
| Weight | Operator entry or scale | Total weight |
| ToolId | System + operator confirm | FK → `Tools.Tool.Id`. Required for die-cast-origin LOTs per FDS-05-034. NULL elsewhere. |
| ToolCavityId | System + operator confirm | FK → `Tools.ToolCavity.Id`. Required for die-cast-origin LOTs per FDS-05-034. NULL elsewhere. |
| DieNumber | Legacy (v0.10) | Retained for cutover; superseded by `ToolId`. Slated for removal. |
| CavityNumber | Legacy (v0.10) | Retained for cutover; superseded by `ToolCavityId`. Slated for removal. |
| VendorLotNumber | Operator entry | Received LOTs only |
| CurrentLocationId | System-tracked | Updated on every movement |

(FRS 3.9.6, 2.2.2)

#### FDS-05-034 — Die-Cast-Origin Tool + Cavity Required on Lot Create — `MVP` (v0.11)

At `Lots.Lot_Create` for die-cast-origin LOTs, the caller SHALL supply `@ToolId` and `@ToolCavityId`. The proc SHALL validate:

1. A `Tools.ToolAssignment` row exists for `@ToolId` with `CellLocationId = @CellLocationId` (from the scanned Cell) and `ReleasedAt IS NULL` — i.e., the Tool is currently mounted on the cell.
2. `@ToolCavityId` references a `Tools.ToolCavity` row where `ToolId = @ToolId`.
3. The cavity's `StatusCodeId` resolves to `Active` (not Closed, not Scrapped).

Failure of any check SHALL reject with a specific error code. Non-die-cast origins (Received, Trim / Machining intermediate, Assembly, Serialized) SHALL pass NULL for both and the proc SHALL NOT require them. (OI-09 closed)

#### FDS-05-035 — Tools System of Record — On Lot, Not On ProductionEvent — `MVP` (v0.11)

Tool and Cavity SHALL live on `Lots.Lot`, never on `Workorder.ProductionEvent`. Reports and exports that need Tool context on an event SHALL derive it via `ProductionEvent.LotId → Lot.ToolId / Lot.ToolCavityId`.

**Downstream LOTs SHALL NOT carry the Tool FKs.** A finished-goods LOT's `ToolId` / `ToolCavityId` are NULL even though its Die-Cast genealogy ancestors have them set. Honda-trace queries (every finished part that contains material from die ABC123) walk `Lots.LotGenealogy` recursively from the origin Die-Cast LOTs to their descendants — not a hot path, no denormalization needed:

```sql
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

(OI-09 closed)

#### FDS-05-031 — LOT Computed Quantities (TotalInProcess, InventoryAvailable) — `MVP` (revised v0.11f)

**OI-23 (revised 2026-04-24):** The Lot Details screen SHALL surface two derived quantities in the header:

- **TotalInProcess** — sum of pieces currently held at all non-terminal workstations (pieces started at a location but not yet completed out of it). Derived from `Workorder.ProductionEvent` aggregation: `Σ StartedCount − Σ CompletedCount − Σ ScrappedCount`, grouped by `(LotId, LocationId)`.
- **InventoryAvailable** — pieces still available on the LOT for consumption or scrap (neither in-process nor consumed). Derived as: `Lot.PieceCount − TotalInProcess − Σ ConsumedCount`.

Both values SHALL be computed via a **SQL view `Lots.v_LotDerivedQuantities`**, not materialized columns on `Lots.Lot`. The view projects `(LotId, TotalInProcess, InventoryAvailable)` by joining `Lots.Lot` with aggregations over `Workorder.ProductionEvent` (checkpoint counters) and `Workorder.ConsumptionEvent` (consumed quantities). Read procs (e.g., `Lots.Lot_Get`, Lot Details screen queries) SHALL join the view to the base `Lots.Lot` table at read time.

Rationale: view-based derivation keeps a single source of truth — the event tables — and eliminates drift between stored aggregates and the underlying events. No on-write maintenance code paths on every `ProductionEvent_Record` / `ConsumptionEvent_Record` mutation. If query performance becomes an issue post-MVP, the view MAY be replaced by an indexed view or materialized table without changing caller contracts.

Legacy Flexware exposes these as header fields on its Lot Details screen.

### 5.2 LOT Creation Workflows

#### FDS-05-004 — Manufactured LOT Creation (Die Cast) — revised v0.11
At Die Cast, the operator SHALL:
1. Fill a basket with parts from the active cavity of the die cast machine.
2. Attach a **pre-printed LTT barcode sticker** to the basket (LTTs are printed in batches outside the MES per FRS 2.2.1).
3. Scan the LTT barcode at the MES terminal — this scan creates the LOT record; the physical label already exists.
4. On Cell selection, the screen SHALL **auto-populate the currently mounted Tool** from `Tools.ToolAssignment_ListActiveByCell(@CellLocationId)`. Operator SHALL confirm the populated Tool matches the physical die. **Edit** (elevated action per FDS-04-007) SHALL trigger inline `Tools.ToolAssignment_Release` + `Tools.ToolAssignment_Assign` to correct the system of record when physical ≠ system.
5. Operator SHALL select the active `ToolCavityId` producing this basket (cavity dropdown filtered to cavities where `Tool.Id = @ToolId` AND `StatusCode = Active`). Part number is implied by the current order / schedule; piece count is operator-entered.
6. The MES SHALL validate: piece count ≤ `Item.MaxLotSize` (now labeled `PartsPerBasket` — basket capacity), part is eligible on this Cell, Tool + Cavity per FDS-05-034.
7. The MES SHALL create the LOT with origin type Manufactured, status Good, location = scanned Cell (per FDS-02-009), `ToolId` and `ToolCavityId` set.
8. The MES SHALL write a `Workorder.ProductionEvent` checkpoint row with cumulative `ShotCount` / `ScrapCount` as-of-this-basket-close (per FDS-03-017a checkpoint shape).
9. The MES SHALL **NOT** trigger an `Initial` label print — the label was pre-printed. (See FDS-05-020 for print reason policy.)
10. The MES SHALL log the creation to `Audit.OperationLog`.

**Note:** Other areas (Trim, Machining, Assembly) do NOT require operator Tool validation at LOT create — their LOTs carry NULL `ToolId` / `ToolCavityId`.

> 🔶 **PENDING CUSTOMER VALIDATION — UJ-02:** Confirms that LTT tags at Die Cast are pre-printed and the first scan creates the record. No in-MES print for Die Cast LOT creation.

#### FDS-05-005 — Received LOT Creation (Pass-Through Parts)
At the Receiving Dock, the operator SHALL:
1. Scan or manually enter the vendor reference (PO number, packing slip, etc.)
2. Enter: part number, vendor lot number, piece count
3. The MES SHALL create the LOT with origin type Received, status Good, location = Receiving Dock
4. The MES SHALL **print an LTT label** via the Receiving Dock terminal's associated Zebra printer (this is an `Initial` print event per FDS-05-020 — no pre-printed tag exists for vendor material)
5. The operator SHALL affix the printed label to the basket/container
6. Once created, the received LOT SHALL behave identically to a manufactured LOT for all downstream operations (movement, consumption, holds, genealogy)

(FRS 2.1.1, 2.1.12)

#### FDS-05-006 — Off-Site Received LOT Creation
Off-site receiving SHALL use the same Perspective application accessed remotely (VPN or published Ignition Gateway). The workflow is identical to FDS-05-005 except: origin type = ReceivedOffsite, and the location is the off-site inventory location. (See User Journey Assumption #6 for network/offline considerations)

### 5.3 LOT Movement

#### FDS-05-007 — Movement Tracking
Every time a LOT physically moves to a new location, the system SHALL record an immutable `LotMovement` event: LOT, from-location, to-location, moved-by user, terminal location, timestamp. The LOT's `CurrentLocationId` SHALL be updated to reflect the new location. (FRS 3.9.8)

#### FDS-05-008 — Movement Workflow
A LOT movement is always initiated by an operator at a terminal. The explicit workflow SHALL be:

1. **Presence** — The terminal already has an operator presence context established via initials (per §4). If 30 minutes have elapsed, the operator confirms or changes presence via the re-confirmation overlay. The terminal's `TerminalLocationId` is the `Location` where the operator is standing.
2. **Scan Location** — Operator scans the machine/location barcode for the destination (the Cell where the LOT is arriving). The system resolves the scanned code to a `Location.Id` and verifies it is a valid production context (Cell-tier, appropriate definition).
3. **Scan LOT** — Operator scans the LOT's LTT barcode. The system looks up the LOT by `LotName`, validates it is not CLOSED, and reads its current `CurrentLocationId` as the from-location.
4. **Record Movement** — The system writes a `LotMovement` row (from-location, to-location, resolved `AppUserId` from the pre-populated initials, terminal location, timestamp) and updates the LOT's `CurrentLocationId` to the scanned destination.
5. **Confirm** — The screen displays the movement confirmation and transitions to the appropriate next action (production recording, inspection, split, etc.) based on the destination's `LocationTypeDefinition`.

The presence → scan location → scan lot sequence ensures that every movement has a clear operator, source, and destination — and that audit attribution is unambiguous.

**Implicit movement:** The system SHALL also infer a movement when a LOT is consumed or produced at a machine without a prior explicit scan. For example, if an assembly operator records consumption of a source LOT currently at the WIP staging area, the system SHALL implicitly write a `LotMovement` from WIP → the assembly Cell before writing the `ConsumptionEvent`. This keeps the traceability record complete without requiring redundant scans.

#### FDS-05-036 — Lazy, Operator-Driven LOT Creation — `MVP` (v0.11)

LOT creation SHALL be **lazy and operator-driven**. The MES SHALL NOT auto-create N LOTs at run start, nor prescribe when an operator must log a new LOT. Valid moments for `Lot_Create` include: on physical completion of a basket (operator goes to terminal to log + move it), after completing a prior LOT and before starting the next (pre-emptive creation), or any other moment the operator chooses.

Physical-but-unlogged baskets exist until the operator logs them. The Arc 2 Phase 3 Die Cast UX and associated procs SHALL NOT require a LOT row to exist for an in-progress cavity. Tool + Cavity assignment happens at `Lot_Create` time, not at any abstract "run start" event.

#### FDS-05-037 — LOT Close Semantics — `MVP` (v0.11)

LOT close behavior SHALL vary by origin:

| LOT origin | Close behavior |
|---|---|
| **Component LOTs** (Die Cast, Trim, intermediate Machining) | **Explicit operator-driven close.** "Complete + Move" SHALL be a combined UI action — status transition + movement in one atomic proc call. Cavity state changes (e.g., broken cavity → Closed) SHALL NOT auto-close the LOT; a partial basket sits at `Lot.LotStatusCode = Closed` only when the operator closes it. |
| **Finished-goods LOTs** (Assembly end-products packed into shipping Containers) | MAY auto-close on container fill. The `Container_Complete` action SHALL close the associated LOT as part of its transaction. Detailed in §6 container workflow and §7 shipping. |

No other close paths are defined. Scrapped material SHALL still move through either explicit Pattern-A reject (FDS-06-019) or Pattern-B split-to-scrap — not via auto-close.

#### FDS-05-032 — Partial Start and Partial Complete — `MVP`

**OI-21 (new v0.10):** Start and Complete at a workstation SHALL be independent operations with independent quantities. An operator MAY start N pieces at a workstation now and complete M of them (where M ≤ N) later — including across shift boundaries. The `Workorder.ProductionEvent_Record` proc SHALL accept independent Start and Complete event emission. Derivation of in-process quantities (FDS-05-031) and runtime workstation WIP grids SHALL work by event replay of Start / Complete / Scrap events, not by maintaining a running counter that assumes atomic start-and-complete. Legacy Flexware surfaces this as separate "Start lot quantity" and "Complete lot quantity" fields on the Move Lot screen. The implementation SHALL be verified against this requirement before Arc 2 screen design freezes.

### 5.4 Sub-LOT Splitting

> ✅ **REVISED — OI-09 closed (2026-04-23):** The 2026-04-20 addenda conflated two distinct workflows. Restated in v0.11:
> - **Cavity-parallel LOTs at Die Cast are peers, NOT sublots.** A die with N active cavities produces **N parallel independent LOTs**. Each LOT has `ToolId` + `ToolCavityId` set at creation (FDS-05-034), fills at its own rate, closes independently. No parent/child FK between cavity peers. One LTT barcode per LOT. Genealogy is flat at Die Cast. See §5.2 FDS-05-004 for creation flow.
> - **Machining sub-LOT split IS a sublot pattern.** The workflow below (FDS-05-022, -024, -009..011) remains authoritative for Machining OUT. Parent FK + split genealogy + sublot labels.
> - **Basket-level sublots** from the 2026-04-20 addenda are absorbed by the Die Cast cavity-parallel-LOT model (one basket = one LOT = one label) or by the Machining sub-LOT split below.

#### FDS-05-022 — Sublot Pattern (Machining)
A sublot SHALL be a `Lots.Lot` row with a non-NULL `ParentLotId` FK. Sublots carry an independent `LotNumber` (from the LTT barcode scanned at creation), their own piece count, status, and movement history, but trace back to the parent via the FK plus a `LotGenealogy` row with `RelationshipType = Split`. Sublots SHALL persist for the full LOT lifecycle — they are never re-merged back into the parent, and their labels travel with the physical container. The parent LOT's piece count SHALL be decremented by the total pieces split off; the parent reaches `LotStatusCode = Closed` when its piece count hits zero (all pieces split off to sublots or consumed).

Sublots created under FDS-05-022 inherit the parent's `ToolId` / `ToolCavityId` (both typically NULL for Machining-origin parents). If the parent is unusually die-cast-origin and is split at Machining, the children SHALL carry `ToolId = NULL` and `ToolCavityId = NULL` — the Tool/Cavity identity is already recorded on the parent LOT's row and on the genealogy edge; sublots are Machining LOTs, not die cast.

#### FDS-05-023 — [Superseded v0.11]
~~Per-cavity sublots at Die Cast~~ — superseded by the cavity-parallel-LOT-as-peer pattern. Each cavity produces a first-class LOT with its own `ToolId`/`ToolCavityId` per FDS-05-034. See §5.2 FDS-05-004 for creation. This requirement slot is retained empty to avoid renumbering downstream requirements.

#### FDS-05-024 — Sublot Labels
Every sublot LTT label SHALL display both the sublot's own `LotNumber` and the `ParentLotNumber`. The `Lots.LotLabel` row SHALL carry a `ParentLotId` reference column (nullable — non-sublot labels have no parent) for label-regeneration and audit purposes. The operator-visible genealogy view SHALL let a user enter either number and see the other. Label reprint workflows (FDS-05-020) for a sublot SHALL preserve the parent reference.

#### FDS-05-009 — Machining Auto-Split Workflow

> 🔶 **PENDING INTERNAL REVIEW — UJ-03:** Reconciled with OI-09 sublot pattern per FDS-05-022 — the auto-split at Machining IN is one specific case of the broader sublot pattern. Still needs review with Ben on the even-split default vs. alternative defaults.

On arrival at the Machining IN screen, when a LOT is scanned, the system SHALL present an auto-split confirmation dialog:
1. Calculate an even 2-way split of the parent LOT's piece count (e.g., 50 → 25/25; 51 → 26/25)
2. Display the proposed split with editable quantities — the operator confirms or adjusts
3. On confirmation, create two child LOT records per FDS-05-022 (sublot pattern), each requiring the operator to scan a fresh LTT barcode
4. Decrement the parent LOT's piece count by the total pieces split off
5. If all pieces are split off, set the parent LOT's status to `Closed`
6. Write `LotGenealogy` records with relationship type `Split` for each parent→child link
7. Print LTT labels for each child sublot — labels follow the FDS-05-024 parent-reference rule
8. Log all operations to `Audit.OperationLog`

The operator MAY cancel the auto-split and process the LOT without splitting. The operator MAY also adjust the number of sublots (not limited to 2) or the quantities before confirming. (FRS 2.1.4, 2.2.5, 3.9.12)

#### FDS-05-010 — Uneven Split Handling
If the parent LOT's piece count is odd, the system SHALL propose the closest even split (e.g., 51 → 26/25). The operator MAY adjust these sizes before confirming. The total of all child quantities SHALL equal the parent's piece count.

#### FDS-05-011 — Split Genealogy Permanence
The parent→child relationship created by a split SHALL be permanent and immutable. Child sublots SHALL carry a `ParentLotId` FK for direct adjacency queries, and `LotGenealogy` records for graph traversal. Both directions (parent→children, child→parent) SHALL be queryable. This applies equally to auto-split sublots (FDS-05-009), per-cavity sublots (FDS-05-023), and basket-level sublots created ad-hoc at container close.

### 5.5 LOT Merging — `MVP`

> 🔶 **REVISED — OI-05 (2026-04-20):** MPP delivered concrete merge rules at the 2026-04-20 review:
> - Merges SHALL be allowed only **after sort is complete** (post-inspection stage; Sort Cage output merges are not permitted — see FDS-07-019).
> - Same **part number** SHALL be required.
> - Same **die** → merge proceeds.
> - Different dies → merge proceeds only when the pair's rank is compatible per `Tools.DieRankCompatibility` (Phase B Tools schema).
> - **Machining** is FIFO-by-cavity — not a merge operation.
> - Quality-status mixing SHALL be blocked (no merging `Hold` with `Good`).
> - Piece counts SHALL be additive; merged LOTs SHALL NOT be un-mergeable.
>
> Supervisor AD elevation (FDS-04-007) unlocks merges that would otherwise be rejected. Full die-rank compatibility matrix is still owed by MPP Quality — until delivered, cross-die merges are rejected with a clear message and the supervisor override is the only path.

#### FDS-05-012 — Merge Capability
The system SHALL support merging multiple LOTs into a single new LOT. The `LotGenealogy` table records the relationship using `RelationshipType = Merge`. Merge rules SHALL be enforced in the `Lots.Lot_Merge` stored procedure — no frontend-only validation. (FRS 3.9.13)

#### FDS-05-025 — Post-Sort Requirement
`Lots.Lot_Merge` SHALL reject any merge where one or more source LOTs have not completed their configured sort/inspection operation. The check SHALL be: for every source LOT, a `Workorder.ProductionEvent` or `Quality.QualityResult` exists whose operation template is marked as a sort / inspection terminator on the LOT's route template. If the route has no sort step, merges on LOTs from that route are not permitted (every merge-eligible part SHALL have a sort step configured). (OI-05 revised; FRS 3.13.1)

#### FDS-05-026 — Part Number Match
`Lots.Lot_Merge` SHALL reject any merge where source LOTs do not share the same `ItemId`. Different part numbers SHALL NOT be merged under any circumstance, including supervisor override. (OI-05 revised; FRS 3.9.13)

#### FDS-05-027 — Die Rank Compatibility
Cross-die merges SHALL be gated by `Tools.DieRankCompatibility` (Phase B Tools schema):

1. Resolve each source LOT's die via the `DieIdentifier` captured on the originating `Workorder.ProductionEvent` (optionally joined to `Tools.Tool` once the analytics FK is added — see Data Model v1.7 §7 cross-references).
2. If all source LOTs share the same die, the compatibility check is bypassed; proceed to FDS-05-028 (Quality Status Gating).
3. If the source LOTs span different dies, look up each distinct pair in `Tools.DieRankCompatibility`. If **every** pair has `CanMix = 1`, the merge proceeds.
4. If any pair is missing from the matrix OR has `CanMix = 0`, the merge SHALL be rejected with the message "Die ranks for dies [X] and [Y] are not compatible for merge" (or "...not configured for merge" when the row is missing).
5. A Supervisor or Quality user MAY override the rejection via the FDS-04-007 AD elevation prompt. Overridden merges SHALL record the overriding user and the rejected rule set on the resulting `LotGenealogy` row's `Notes` column.

Until MPP Quality delivers the full `DieRankCompatibility` matrix (seeded empty in Phase B), all cross-die merges SHALL fall through to the supervisor override path. (OI-05 revised; couples to Phase B Tools schema.)

#### FDS-05-028 — Quality Status Gating
`Lots.Lot_Merge` SHALL reject any merge where the source LOTs do not share the same `LotStatusCode` value, except that `Closed` LOTs SHALL never participate in a merge (they are already fully consumed). Specifically: merging a `Hold` LOT with a `Good` LOT SHALL be rejected. Supervisor override via FDS-04-007 is NOT allowed for mixed quality status — a held LOT must be released via the hold-release workflow (§8.2) before it can be merged. (OI-05 revised)

#### FDS-05-029 — Machining Is Not a Merge — FIFO-by-Cavity
The machining workflow SHALL NOT issue merge events. When multiple cavity-parallel LOTs (`Lot.ToolCavityId` set) arrive at a machining cell, the cell SHALL process them first-in-first-out (FIFO) keyed by LOT `CreatedAt`, grouped by `ToolCavityId`. Each LOT retains its identity through the machining operation; no `LotGenealogy` `Merge` row is written. (OI-05 revised; FRS 3.13.1)

#### FDS-05-030 — Post-Merge LOT Has NULL Tool / Cavity — `MVP` (v0.11)

After a successful `Lots.Lot_Merge`, the resulting merged LOT SHALL have `ToolId = NULL` and `ToolCavityId = NULL` — blended-origin material from multiple source LOTs cannot be denormalized into a single Tool/Cavity FK pair. Tool-specific trace SHALL be reconstructed via `Lots.LotGenealogy` traversal of the pre-merge source LOTs (each of which retains its own Tool/Cavity FKs immutably). The merge proc SHALL NOT attempt to pick a "representative" Tool. (OI-09 closed; Decision 10)

### 5.6 LOT Status Transitions

#### FDS-05-013 — Status Codes
LOT quality status SHALL be managed via the `LotStatusCode` table with the following seeded values:

| Code | Name | BlocksProduction | Description |
|---|---|---|---|
| Good | Good | false | LOT is available for production |
| Hold | Hold | true | LOT is held — no production operations allowed |
| Scrap | Scrap | true | LOT is scrapped — permanently removed from production |
| Closed | Closed | true | LOT is fully consumed or split — no pieces remain |

(FRS 3.16.3)

#### FDS-05-014 — Status Transition Rules
The system SHALL enforce these transition rules:

```
GOOD → HOLD     (quality hold placed)
GOOD → CLOSED   (all pieces consumed or split off)
GOOD → SCRAP    (quality disposition)
HOLD → GOOD     (hold released by authorized user)
HOLD → SCRAP    (held LOT scrapped after investigation)
HOLD → CLOSED   (held LOT fully consumed via authorized disposition)
SCRAP → (none)  (terminal state)
CLOSED → (none) (terminal state)
```

#### FDS-05-015 — Status History
Every status transition SHALL be recorded as an immutable `LotStatusHistory` event: LOT, old status, new status, reason, changed-by user, terminal, timestamp. (FRS 3.16.4)

### 5.7 Genealogy

#### FDS-05-016 — Genealogy Graph
The `LotGenealogy` table SHALL record every parent→child relationship with: parent LOT, child LOT, relationship type (SPLIT, MERGE, CONSUMPTION), piece count transferred, user, terminal, and timestamp.

#### FDS-05-017 — Bidirectional Query
The system SHALL support genealogy queries in both directions:
- **Forward:** Given a parent LOT, find all descendants (children, grandchildren, serialized parts, containers, shipping labels)
- **Backward:** Given a serial number, container, or child LOT, trace back through all ancestors to the original manufactured or received LOT

These queries SHALL use recursive CTEs on the `LotGenealogy` adjacency list. (FRS 3.13.2)

#### FDS-05-018 — Genealogy Report
The system SHALL provide a genealogy report (screen and printable) that, given any LOT, sub-LOT, serial number, or container, displays the complete tree: source LOTs, operations performed, operators, machines, timestamps, and shipping destination. This is the primary Honda traceability deliverable.

### 5.8 LOT Label Management

#### FDS-05-019 — Label Print Tracking
Every LTT label print SHALL be recorded in the `LotLabel` table with: LOT, print reason, ZPL content, printer name, printed-by user, terminal, and timestamp.

#### FDS-05-020 — Print Reasons
The system SHALL track these label print reasons:

| Reason | Trigger | Applies To |
|---|---|---|
| Initial | LOT creation | Received LOTs (pass-through, off-site), system-generated LOTs with no pre-printed tag |
| ReprintDamaged | Operator requests reprint of damaged/unreadable label | Any LOT |
| Split | New child LOT created from split | Sub-LOTs from a parent |
| Merge | New merged LOT created | Output LOT from a merge operation |
| SortCageReIdentify | Re-identification during Sort Cage re-pack | Containers being re-sorted |

> 🔶 **PENDING CUSTOMER VALIDATION — Initial Print for Die Cast:** Die Cast LOTs do NOT trigger an `Initial` print event in the MES. Per UJ-02, LTT tags at Die Cast are pre-printed in batches by MPP (per FRS 2.2.1) — the physical label is already on the basket when the operator scans it to create the LOT record. The first scan creates the LOT; the MES does not print the label because the label already exists. This assumption needs MPP validation before go-live.
>
> The `Initial` print reason still applies to:
> - **Received LOTs** (pass-through parts): no pre-printed tag exists for vendor material, so the MES generates and prints an LTT at receiving time
> - **Off-site receiving**: same as above
> - **Any system-generated LOT without a pre-printed tag** (edge case — e.g., emergency re-identification)

(FRS 3.13.1, 2.2.1, UJ-02)

### 5.9 LOT Attribute Auditing

#### FDS-05-021 — Attribute Change Log
Every change to a LOT attribute (piece count, weight, die number, cavity number, status) SHALL be recorded in the `LotAttributeChange` table: LOT, attribute name, old value, new value, changed-by user, terminal, timestamp. This is in addition to the domain-specific history tables (status history, movement history). (FRS 3.9.6)

### 5.10 Part Identity Change — Casting to Trim — `MVP` (OI-11 resolved 2026-04-22)

Per MPP Engineering (2026-04-20 meeting): a part **changes identity** as it crosses from Casting into the Trim Shop — the physical piece is the same but carries a different part number on each side of the boundary. Honda genealogy queries MUST resolve across this rename so a shipped part traces back to its cast origin.

> **OI-11 resolution (2026-04-22):** The v0.10 draft initially added a dedicated `Parts.ItemTransform` table + FDS-05-033..035 to bridge the rename. On review the table was redundant — every column duplicated `Workorder.ConsumptionEvent`, and the Casting → Trim boundary is a **degenerate 1-line BOM consumption**. The existing `Parts.Bom`, `Workorder.ConsumptionEvent`, and `Lots.LotGenealogy` machinery covers this case without new schema. FDS-05-033..035 retired; the single requirement below replaces them.

#### FDS-05-033 — Casting → Trim Rename via 1-Line BOM — `MVP`

The trim-side `Parts.Item` SHALL be defined with a single-line `Parts.Bom` whose `BomLine.ChildItemId` references the cast-side `Item` at `QtyPer = 1`. At the first Trim Shop Cell, when an operator scans a cast-side LOT into the Cell, the MES SHALL:

1. Look up finished items produced at this Cell (via `Parts.ItemLocation` where `IsConsumptionPoint = 0` and the Item has a published `Parts.Bom`).
2. For each such item, check whether its BOM's single line references the scanned LOT's Item. The matching finished item is the destination part.
3. Prompt the operator to confirm: *"This LOT is {sourcePart}. Receive as {destinationPart}?"* with Yes / No controls.
4. On **Yes**: create a new destination LOT under the trim part (operator scans a fresh LTT), write a `Workorder.ConsumptionEvent` with `ConsumedItemId = cast`, `ProducedItemId = trim`, `PieceCount = N` piece-for-piece (plus a `Workorder.RejectEvent` for any yield loss), and a `Lots.LotGenealogy` row with `RelationshipType = Consumption` linking source and destination LOTs.
5. On **No / Cancel**: abort the scan-in. Operator may re-scan or escalate (supervisor AD elevation per FDS-04-007 required for any override of the BOM-implied destination).

**Backward trace** (Honda genealogy): standard `Lots.LotGenealogy` walk from the shipped trim LOT recovers the cast LOT via the `Consumption` edge, then onwards to the cast machine / die / cavity / operator / timestamp. No special join or ItemTransform lookup — trace works exactly as for any assembly consumption.

**Why this is enough:** the trim part is a *new Item master record*, so the part-number distinction is already captured. The source-and-destination semantics are captured by `ConsumptionEvent.ConsumedItemId` vs `ProducedItemId`. The piece mapping is captured by `ConsumptionEvent.PieceCount`. Operator, terminal, location, and timestamp are all existing columns. A dedicated "rename" table adds no information the consumption model doesn't already carry.

---

## 6. Production Execution — `MVP-EXPANDED`

### 6.1 Design Overview

Production execution records what happens on the shop floor — shots fired, parts made, parts rejected, materials consumed. The evidence is captured as immutable events (`ProductionEvent`, `ConsumptionEvent`, `RejectEvent`) that are never updated or deleted.

Work orders (`CONDITIONAL` scope) provide optional bookkeeping context. All event tables have nullable FKs to `WorkOrderOperation`, so production tracking functions fully with or without work orders enabled.

This section replaces the paper production sheets (DCFM-1589/1785/2003 and MS1FM-series) and the legacy Productivity Database manual data entry workflow. Operators enter data at the point of action in real time, eliminating the 2-hour post-shift clerk entry pattern. (FRS 3.5.4, 5.6.6)

### 6.2 Die Cast Workflow

#### FDS-06-001 — Die Cast Production Screen
The Die Cast production screen SHALL be driven by the active operation template's `OperationTemplateField` rows (typically configured with `DieInfo`, `CavityInfo`, `Weight`, `GoodCount`, `BadCount` for die cast operations). Fields flagged `IsRequired = 1` on the junction SHALL be mandatory on submit. The screen SHALL present:
- LOT selection (scan LTT barcode or select from active LOTs at this machine)
- Part number (entered by operator at LOT creation per FDS-05-004)
- Shot counts: total shots, good shots, warm-up shots (per paper form fields DCFM-1785)
- Good piece count
- Reject entry: defect code (filtered to Die Cast area codes), quantity, remarks (optional per operation — FRS Section 4)
- Weight (manual entry or automatic from OmniServer scale where available)

#### FDS-06-002 — Die Cast Validation
Before recording production, the system SHALL validate:
- The LOT status is GOOD (not HOLD, SCRAP, or CLOSED)
- The item is eligible for this machine (`ItemLocation` check)
- The piece count does not exceed the item's max lot size
- If any validation fails, the system SHALL display a clear error and prevent the recording

#### FDS-06-003 — Die Cast Production Event — revised v0.11 (checkpoint shape)
On operator submission at a Die Cast checkpoint (e.g., basket close, end-of-shift handoff, scrap-from-location action), the system SHALL (per FDS-03-017a, in one transaction):
1. Write an immutable `Workorder.ProductionEvent` row carrying `LotId`, `OperationTemplateId`, `EventAt`, cumulative `ShotCount` / `ScrapCount` as-of-this-moment, optional `ScrapSourceId` (non-NULL only when this checkpoint is a scrap-driving action), optional `WeightValue` + `WeightUomId`, `AppUserId`, `TerminalLocationId`.
2. Write one `Workorder.ProductionEventValue` child row per non-hot `DataCollectionField` configured on the active operation template.
3. Update the LOT's `PieceCount` to reflect the current good count (derivation: `ShotCount - ScrapCount` since last event, plus any adjustments).
4. Log to `Audit.OperationLog`.

Reports that need per-event good-count deltas SHALL compute `ShotsSinceLast = ShotCount - LAG(ShotCount) OVER (PARTITION BY LotId ORDER BY EventAt)`. Reports that need Tool/Cavity context SHALL join to `Lots.Lot` on `ProductionEvent.LotId` and read `Lot.ToolId` / `Lot.ToolCavityId` (per FDS-05-035).

> 🔶 **PENDING INTERNAL REVIEW — UJ-14:** Warm-up shots are tracked as a downtime sub-category rather than on the production event. The Die Cast operator logs warm-up time as a `DowntimeEvent` with `ReasonType` = Setup and records the warm-up shot count in the `ShotCount` column on that downtime event. Good/bad production shot counts remain on the `ProductionEvent`. This separates warm-up activity (time + shots wasted) from production activity (good parts made). Needs review with Ben.

### 6.3 Trim Shop Workflow

#### FDS-06-004 — Trim Shop LOT Processing
When a LOT arrives at the Trim Shop, the operator SHALL scan the LTT barcode. The system SHALL record a `LotMovement` to the Trim area. (FRS 2.2.3)

#### FDS-06-005 — Weight-Based Piece Count Estimation
The Trim Shop screen SHALL support weight-based piece count estimation:
1. Operator reads the basket weight from the scale (manual entry or OmniServer integration)
2. The system SHALL calculate a theoretical piece count: `Weight / Item.UnitWeight`
3. If the calculated count differs from the LOT's current `PieceCount`, the system SHALL display both values and allow the operator to accept the new count or keep the existing count
4. The system SHALL NOT block production if the count changes — it logs the adjustment (FRS 2.2.3: "MES takes no specific action if the LOT quantity has changed")
5. Any count adjustment SHALL be recorded in `LotAttributeChange`

#### FDS-06-006 — Trim Production Event
On completion, the system SHALL write a `ProductionEvent` for the Trim operation, confirming the LOT passed through this step.

### 6.4 Machining Workflow

#### FDS-06-007 — Machining IN
The Machining IN screen SHALL allow the operator to scan a LOT's LTT barcode to receive it at a machining center. The system SHALL:
1. Record a `LotMovement` to the machine's location
2. Display the LOT's current piece count and item details
3. Show the FIFO queue of LOTs waiting at this machine (ordered by arrival time), with operator ability to override the queue order (FRS 2.2.4)

#### FDS-06-008 — Machining OUT
The Machining OUT screen SHALL support two actions:
1. **Production recording** — good count, reject count with defect codes (Machine Shop area codes), operator, timestamp
2. **Sub-LOT splitting** — per FDS-05-009 through FDS-05-011

The operator MAY perform production recording and splitting in a single workflow (record machining results, then split the output into sub-LOTs for downstream operations). (FRS 2.2.5)

#### FDS-06-009 — Machining Production Event
On submission, the system SHALL write a `ProductionEvent` and update the LOT's piece count. If rejects are entered, a `RejectEvent` SHALL be written for each defect code used.

### 6.5 Assembly Workflow — Serialized Lines

#### FDS-06-010 — Serialized Assembly (PLC-Integrated)
On serialized assembly lines (e.g., 5G0 Fronts/Rears), the MES SHALL integrate with the PLC via Machine Integration Panel (MIP) using the handshake protocol defined in Section 10. For each part cycle:
1. The PLC signals `DataReady=1`
2. The MES reads the serial number from `PartSN`
3. The MES validates: serial number is not a duplicate, format is correct, source LOT is not on HOLD
4. The MES writes `PartValid=1` (or `0` on failure) back to the PLC
5. On success, the MES SHALL:
   - Write a `ConsumptionEvent` (source LOT(s) → produced serial number)
   - Create a `SerializedPart` record linking the serial to its source LOT and item
   - Decrement the source LOT(s) piece count(s) per the BOM
   - Place the serial into the current container tray (`ContainerSerial` record)
   - Write a `LotGenealogy` record with relationship type CONSUMPTION

(FRS 2.1.7, 2.1.10; Touchpoint Agreement Section 1.4)

#### FDS-06-011 — Serialized Assembly Material Identification
Before production begins on a serialized line, the operator SHALL identify the source LOT(s) being consumed (FRS 3.10.6). If the operation template has `RequiresMaterialVerification = true`, the operator SHALL scan each source LOT's LTT barcode. The system SHALL perform a **BOM-based verification** (FRS 3.4.2):
- The source LOT's item SHALL match a component in the active BOM version for the product being assembled
- The source LOT status SHALL be GOOD
- The source LOT SHALL have sufficient piece count
- If the scanned LOT's item does not appear in the BOM, the system SHALL reject the material with a clear error

> 🔶 **PENDING CUSTOMER VALIDATION — UJ-09:** Material verification uses BOM-based checking — the system validates that the scanned source LOT's part number matches a BOM component. Substitute parts are rejected. Needs MPP confirmation.

#### FDS-06-012 — Hardware Interlock Bypass
When the automation sets `HardwareInterlockEnable=false`, the MIP SHALL write `PartSN="NoRead"` and the machine proceeds without MES serial validation (per Touchpoint Agreement 1.1). The system SHALL:
- Still record the production event
- Log the `NoRead` serial as a flag for quality review
- Record that the hardware interlock was bypassed (see data model discussion below)
- NOT block production — this is a valid operating mode, not an error condition

> 🔶 **PENDING INTERNAL REVIEW — UJ-16:** A `HardwareInterlockBypassed` flag is needed to record that serial validation was skipped. Two placement options are under discussion: (a) on `ContainerSerial` — marks the specific serial assignment, (b) on `ProductionEvent` — marks the broader production event. The circumstances under which MPP bypasses the interlock are not yet understood. Both options presented for discussion with Ben. See data model for details.

### 6.6 Assembly Workflow — Non-Serialized Lines

#### FDS-06-013 — Non-Serialized Assembly
On non-serialized lines (e.g., 6B2 Cam Holder, RPY Assembly Sets), the operator SHALL:
1. Identify source LOT(s) by scanning LTT barcodes
2. Enter the good count produced
3. The system SHALL write `ConsumptionEvent` records linking source LOTs to the output LOT or container
4. The system SHALL decrement source LOT piece counts per the BOM quantity-per

For lines with PLC integration (MicroLogix1400 PLCs per Appendix C), `PartDisposition` flags and `ContainerName` tags provide automated validation without individual serial tracking.

#### FDS-06-014 — Non-Serialized Container Filling
On non-serialized lines, containers SHALL be filled by count (operator enters quantity placed in container) or by weight (scale integration via OmniServer where available). The container closes when the configured capacity is reached. (See Open Item OI-02 below)

> 🔶 **PENDING CUSTOMER VALIDATION — OI-02:** Non-serialized lines should receive feedback from a scale. Blue Ridge recommends adding `ClosureMethod` (BY_COUNT / BY_WEIGHT) and `TargetWeight` fields to `ContainerConfig` so the MES can drive closure logic using OPC scale data (`TargetWeightValue`, `TargetWeightMetFlag` via OmniServer). Needs MPP confirmation that scale-driven closure is the desired behavior (vs. PLC-only "container full" signal).

### 6.7 Production Events

#### FDS-06-015 — Production Event Immutability
Production events SHALL be append-only. Once written, a `ProductionEvent` record SHALL NOT be modified or deleted. If a correction is needed, a new compensating event SHALL be recorded (e.g., a negative adjustment event with remarks explaining the correction). (FRS 3.5.4)

#### FDS-06-016 — Production Event Fields
Each `ProductionEvent` SHALL record: LOT, location (machine), item, good count, no-good count, operator, terminal, timestamp, and optional remarks. The `WorkOrderOperationId` FK is nullable — production events function independently of work orders.

### 6.8 Reject Events and Scrap Handling

#### FDS-06-017 — Reject Recording
The system SHALL allow operators to record reject/scrap counts associated with a LOT and defect code. Reject entry is optional — MPP may elect not to record rejects at every manufacturing step (FRS Section 4). The system SHALL allow but SHALL NOT require reject entry at each operation.

#### FDS-06-018 — Reject Event Fields
Each `RejectEvent` SHALL record: associated production event (nullable), LOT, defect code, quantity, charge-to area (optional), remarks, operator, and timestamp.

#### FDS-06-019 — Reject Data Classification and Scrap Handling Patterns
Per FRS Section 4, reject/scrap data is retained for analysis but is not considered part of the permanent production record in the same way that good counts are. The `RejectEvent` table is append-only and queryable, but reports and dashboards SHOULD distinguish between production records (permanent) and reject analysis records (analytical).

**Scrapping parts does NOT always require splitting the LOT.** The system SHALL support two patterns, and the operator workflow SHALL select the appropriate one:

**Pattern A — Inline Reject (default):**
The operator records production with good and bad counts in a single transaction. `ProductionEvent` captures the good count; `RejectEvent` captures the bad count with defect code(s). The LOT's `PieceCount` reflects only good parts. The bad parts are physically discarded without their own LOT record. No split, no status change.

- **When to use:** Routine scrap at production time (porosity, cold shut, out-of-tolerance). Parts are discarded immediately. No traceable disposition required.
- **Data footprint:** `ProductionEvent` + `RejectEvent`. LOT `PieceCount` decremented. No `LotGenealogy` record.

**Pattern B — Split-to-Scrap (exception):**
The operator splits the LOT into good and bad sub-LOTs (per FDS-05-010). The bad sub-LOT transitions to status `Scrap` via a `LotStatusHistory` event. The good sub-LOT continues through production. Full genealogy of the scrapped sub-LOT is preserved in `LotGenealogy`.

- **When to use:** When traceable disposition of scrapped parts is required — e.g., Honda recall scenarios where specific bad lots must be identifiable, regulatory or quality investigation scrap, Sort Cage rejecting parts that already carry shipper IDs.
- **Data footprint:** `LotGenealogy` split record, new child LOT, `LotStatusHistory` transition to Scrap, optional `RejectEvent` for defect code tracking.

**Guidance for screen design:** The Die Cast and Machining production screens SHALL default to Pattern A — operators enter good/bad counts in one transaction. Pattern B is invoked only from quality workflows (Hold screen, Sort Cage screen) where a supervisor or quality user is already in a split-capable context. Operators do not choose between patterns on a production screen; the screen determines the pattern by context.

**Relationship to Hold workflow:** Per the 2026-04-06 design decision, parts held for investigation are placed on `Hold` (not `Scrap`) and split from the parent LOT (per FDS-05-010 and FDS-08-007). Pattern B's split-to-scrap is for parts that have already been dispositioned as scrap — it is NOT the entry point for quality investigations. Investigations go through Hold, and only transition to Scrap after disposition.

#### FDS-06-023a — Scrap Source Distinction (Inventory vs Location) — `MVP`

**OI-20 (new v0.10):** Scrap events SHALL carry a `ScrapSource` discriminator via `Workorder.ProductionEvent.ScrapSourceId` FK → `Workorder.ScrapSource`. The code table is read-only, seeded with two rows:

- **Inventory** — scrapping unallocated pieces on a LOT. Triggered from the Lot Details screen "Scrap from inventory" button. No workstation context required. Deducts from `InventoryAvailable` (FDS-05-031).
- **Location** — scrapping in-process pieces at a specific Cell. Triggered from the workstation "Scrap from the selected location" button. Workstation context required. Deducts from `TotalInProcess` at that Cell.

The `ScrapSourceId` column SHALL be NULL for non-scrap production events and NOT NULL for scrap events (enforced at the proc layer in `Workorder.ProductionEvent_Record`). Reports distinguishing inventory vs location scrap (for OEE and scrap-rate analytics) SHALL use this discriminator.

(FRS Section 4, 3.16.10)

### 6.9 Consumption Events

#### FDS-06-020 — Consumption Tracking
Every time source material is consumed to produce output, the system SHALL write an immutable `ConsumptionEvent` recording: source LOT, produced LOT (or container), consumed item, produced item, piece count, location, operator, terminal, tray (if applicable), produced serial number (if serialized), and timestamp.

#### FDS-06-021 — Consumption Genealogy
Each consumption event SHALL also generate a `LotGenealogy` record with relationship type Consumption, linking the source LOT to the output LOT or serialized part. This is the backbone of Honda traceability — every finished good traces back to every component LOT consumed. (FRS 3.13.2)

### 6.10 Work Orders — `MVP-LITE` (with Demand + Maintenance flows `FUTURE`)

> 🔶 **REVISED — OI-07 (2026-04-24 correction of 2026-04-20):** MVP ships **one active WO type — `Production`** — preserving the existing MVP-LITE bookkeeping (auto-generated on LOT start, invisible to operators). The 2026-04-20 meeting note was mis-recorded; the "Recipe" line was describing this same Production flow, not a separate type. Under MPP's actual taxonomy, `Demand` (planned preventative maintenance) and `Maintenance` (emergency maintenance) are genuinely separate future WO types — neither is being built in this project. The `Workorder.WorkOrderType` code table remains as a future hook so the maintenance engine project can INSERT `Demand` and `Maintenance` rows without schema change. The nullable `ToolId` FK on `Workorder.WorkOrder` remains as the Maintenance-targets-a-tool hook. FDS-06-027 Recipe has been **deleted** — there is no such concept.

#### FDS-06-022 — Work Order Auto-Generation (Production Type)
The system SHALL auto-generate **Production-type** internal work orders when production activity begins on a LOT. Operators SHALL NOT see, create, or interact with Production work orders directly — they remain invisible bookkeeping. Auto-generation semantics are unchanged from the pre-v0.9 MVP-Lite design. Production WOs SHALL be created with `WorkOrderType.Code = Production` and `ToolId = NULL`. (FRS 3.1.5)

#### FDS-06-023 — Work Order Structure
Each work order SHALL carry:

- `WorkOrderType` discriminator (currently only `Production` is active; `Demand` and `Maintenance` are FUTURE rows, not seeded in MVP) — FK to `Workorder.WorkOrderType`
- `ItemId` — FK to the part being produced (NOT NULL for Production; MAY be NULL for future Maintenance if the WO targets a tool rather than a part)
- `RouteTemplateId` — FK to the route template version active at creation
- `ToolId` — FK to `Tools.Tool`, nullable. Reserved for future Maintenance WOs targeting a specific Tool; not populated in MVP.
- `WorkOrderStatus` — (Created → InProgress → Completed / Cancelled)

Work order operations SHALL be created for each route step, tracking: planned step, actual location, status (Pending → InProgress → Completed / Skipped), start/completion times, and operator.

#### FDS-06-024 — Work Order Independence from Evidence
Production events, consumption events, and reject events SHALL function fully without work orders. The `WorkOrderOperationId` FK on these tables is nullable. If work orders are deferred or absent (including any future Demand or Maintenance WOs that have no ProductionEvents), the evidence layer operates standalone.

#### FDS-06-025 — WorkOrderType Code Table
The `Workorder.WorkOrderType` code table SHALL be seeded at migration time with **one** active read-only row:

| Code | Name | MVP Scope |
|---|---|---|
| Production | Production Work Order | `MVP-LITE` — auto-generated, invisible to operators (FDS-06-022). |

**FUTURE types — NOT seeded in MVP** (the code-table mechanism exists as a hook; future maintenance-engine project INSERTs these rows without a schema change):

| Code | Purpose | Status |
|---|---|---|
| Demand | Planned preventative maintenance. | `FUTURE` — out of scope for this project. |
| Maintenance | Emergency maintenance. | `FUTURE` — out of scope for this project. |

Existing `Workorder.WorkOrder` rows created before v1.7 SHALL be backfilled to `Production`. Create-proc defaults SHALL set `WorkOrderTypeId = Production` so Phase 1–8 callers keep working unchanged.

> **SQL correction follow-up (queued):** Phase G migration `0010_phase9_tools_and_workorder.sql` shipped the `WorkOrderType` seed with 3 rows (`Demand`/`Maintenance`/`Recipe`). A follow-up versioned migration SHALL rename Id=1 `Demand`→`Production`, DELETE Id=2 (`Maintenance`) and Id=3 (`Recipe`), and correct the test in `sql/tests/0019_Parts_ConsumptionMetadata_And_ScrapSource/010_Phase_E_additives.sql` (currently asserts 3 rows + Code='Demand'). Not executed this turn; tracked in OIR OI-07.

#### FDS-06-026 — Future Maintenance-Engine Schema Hooks — `FUTURE`
The system reserves two schema hooks for a future maintenance-engine project scoped separately from this MES:

1. **`Workorder.WorkOrderType`** code table — new rows for `Demand` (planned PM) and `Maintenance` (emergency) can be INSERTed without DDL change. Ben / MPP scope the business rules at that time.
2. **`Workorder.WorkOrder.ToolId`** nullable FK → `Tools.Tool.Id` — allows a future Maintenance WO to reference the specific Tool it targets. Not populated or enforced in MVP.

**Neither flow ships in MVP.** No Perspective screens, no state machine, no scheduling, no integration with the MPP maintenance team's existing tooling. The Configuration Tool does NOT surface any admin UI for creating these WOs. This FDS section exists so the data model commitment is explicit: the hooks are stable and survive the MVP build.

*(FDS-06-027 Recipe Work Orders — **DELETED 2026-04-24** per OI-07 correction. The 2026-04-20 meeting note was mis-recorded; there is no Recipe WO concept. Requirement slot left vacant to avoid renumbering.)*

#### FDS-06-028 — Auto-Finish on Target (Camera / Scale) — `MVP` (extended v0.11g)

**OI-16 (Jacques additions, 2026-04-24):** Production Work Orders SHALL support two automatic-finish modes, configurable per WO:

- **Camera-count mode** — the WO carries a target piece count + a tray quantity. Cumulative `ProductionEvent.ShotCount` − `ScrapCount` (derived via `LAG()` over checkpoint events per FDS-06-003) across all events under the WO is compared against the target on every write. When the cumulative count reaches the target, the `Workorder.ProductionEvent_Record` proc SHALL check the PLC confirmation BIT (per **Requirement 1** below). If BIT is set, the proc emits a WO-close event (transitions `WorkOrderStatus` to `Completed`) in the same transaction as the event write. Driven by Cognex camera output through FDS-03-017a capture.
- **Scale-weight mode** — the WO carries a target weight. Cumulative `ProductionEvent.WeightValue` is compared against the target on every write; on hit (AND PLC confirmation BIT set), the same auto-close fires. Driven by scale input through OmniServer.

Auto-finish SHALL be configurable per WO (an explicit enable flag on `Workorder.WorkOrder`). If neither mode is enabled, the WO closes only via explicit operator or supervisor action. Integration with FDS-03-021 (tray divisibility) is enforced at Create — a WO enabling camera auto-finish with a non-divisible target is rejected at the Configuration Tool entry point.

Legacy Flexware surfaces this as the "Camera system automatic processing options (Enabled / Tray quantity / Part recipe number)" and "Scale system automatic processing options (Enabled / Target set quantity)" blocks on the Work Order configuration screen.

**Requirement 1 — PLC confirmation BIT (belt-and-suspenders).** The PLC SHALL write a confirmation BIT (exact tag address TBD by integration team; reserved name `CompletionConfirmed` on the Machine Integration Panel) when it has itself determined the target was reached (camera count matched or scale target met). The MES Gateway script observing the OPC tags SHALL NOT fire the WO-close solely on the cumulative count crossing — both the count crossing AND the PLC `CompletionConfirmed` BIT SHALL be true. This prevents spurious closes from miscount races or clock drift on event timestamps. If the BIT fails to assert within a configurable window after the count crosses, the Gateway SHALL write `Audit.InterfaceLog` flagging the discrepancy for operator review; no auto-close fires until the BIT asserts.

**Requirement 2 — `RequiresCompletionConfirm` LocationAttribute (per-Terminal UX toggle).** A new `LocationAttributeDefinition` SHALL be seeded on the `Terminal` `LocationTypeDefinition`:

| Attribute | Type | Purpose |
|---|---|---|
| `RequiresCompletionConfirm` | BIT | When set on a Dedicated (1:1 fixed) Terminal, the Perspective auto-finish completion flow SHALL present a large "Confirm Completion" button the operator must physically press before the WO / Tray / Container close proceeds. When NOT set (or NULL), the flow shows a passive popup ("WorkOrder Completed" / "Tray Completed" / "Container Completed" — whichever is relevant) and proceeds without operator gesture. |

Rationale: some production lines require explicit operator acknowledgement at close moments (MPP's existing operational habit on specific cells); others don't. The attribute lets Engineering configure per Terminal. Only meaningful on Dedicated terminals (FDS-02-010) — Shared terminals always require operator interaction per their mode.

**Seed behavior:** `RequiresCompletionConfirm` is nullable with NULL semantically equivalent to `0` (no confirm button). Engineering sets it to `1` only where the operational workflow demands acknowledgement.

#### FDS-06-029 — Tray-Divisibility Validation on WO Close — `MVP`

**OI-17 (new v0.10):** At WO Close (whether manual or via FDS-06-028 auto-finish), the MES SHALL verify that cumulative `GoodCount` is evenly divisible by `PartsPerTray` from the Item's `ContainerConfig`. A non-divisible result SHALL block the close with error *"Work order target quantity exceeded. Ensure target quantity is evenly divisible by the tray quantity"* (matching the legacy Flexware wording). Supervisor AD elevation per FDS-04-007 overrides the block (reason logged to `Audit.OperationLog`). Also validated at WO Create per FDS-03-021; re-validated at Close because `ProductionEvent` writes can push actual count below or past the planned target.

> **Note (v0.11):** "Cumulative `GoodCount` across the WO" is computed by summing `ShotCount - ScrapCount` deltas across all `ProductionEvent` rows whose `LotId` is associated with the WO (via `WorkOrderOperationId` or, when that is NULL, via LOT-WO matching on `ItemId` + time window). The v0.11 ProductionEvent reshape removed the per-event `GoodCount` column — it is derived from the cumulative counters.

#### FDS-06-030 — WorkOrder BIT-Flag Enumeration at Phase 0 — `MVP` (Arc 2 Phase 0 input, v0.11)

The legacy Flexware `WorkOrder` table carries a set of BIT / attribute flags whose MVP status is unknown. Arc 2 Phase 0 SHALL confirm with MPP which of the following are live in production; live flags become columns on `Workorder.WorkOrder` at the Arc 2 Phase 1 `CREATE`; dead flags do not ship:

| Flexware flag / field | Proposed home if live |
|---|---|
| `IsCameraProcessingEnabled` | `Workorder.WorkOrder` (configurable per FDS-06-028) |
| `IsScaleProcessingEnabled` | `Workorder.WorkOrder` (configurable per FDS-06-028) |
| `GroupTargetWeight`, `GroupTargetWeightTolerance`, `TargetWeightUnitOfMeasureID` | `Workorder.WorkOrder` (subsumed by OI-02 resolution when that closes) |
| `RecipeNumber` | `Workorder.WorkOrder` (`WorkOrderType = Recipe`) |
| `TrayQuantity` | `Workorder.WorkOrder` (couples to `Parts.ContainerConfig.PartsPerTray` — one source of truth required) |
| `ReturnableDunnageCode` | `Workorder.WorkOrder` OR `Parts.ContainerConfig` — scope decision at Phase 0 |
| `Customer` | `Workorder.WorkOrder` — if Honda-only, redundant |
| `IsActive` | implied by `WorkOrderStatus` — likely redundant |

Most of these appear to be weight-based container-closure flags that OI-02 resolution subsumes. Phase 0 confirms live-vs-dead; Phase 1 CREATE includes only live columns.

---

## 7. Container Management & Shipping — `MVP`

### 7.1 Design Overview

Finished goods are packed into Honda-specified containers with trays, labeled with AIM-issued shipper IDs, and loaded onto trucks. The container lifecycle is: OPEN (being filled) → COMPLETE (full, labeled) → SHIPPED (on the truck) → or diverted to HOLD / VOID for quality disposition.

Container configuration (trays per container, parts per tray, serialized flag, dunnage code) is defined per product in the `ContainerConfig` table and drives automatic fill/close behavior.

### 7.2 Container Lifecycle

#### FDS-07-001 — Container Creation
Containers SHALL be created when:
- **Serialized lines:** Automatically when the first part enters a new container (MES creates the container, assigns a name, starts filling)
- **Non-serialized lines:** When the operator initiates packing for a LOT, or automatically when the previous container closes

Each container SHALL reference: item, container config, status, source LOT, current location, and AIM shipper ID (assigned at closure).

#### FDS-07-002 — Container Status Codes
Container status SHALL be managed via `ContainerStatusCode`:

| Code | Name | Description |
|---|---|---|
| Open | Open | Container is being filled |
| Complete | Complete | Full, AIM shipper ID assigned, label printed |
| Shipped | Shipped | Loaded on truck, left the dock |
| Hold | Hold | Quality hold — cannot ship |
| Void | Void | Cancelled — shipping label voided |

#### FDS-07-003 — Container Filling — Serialized Lines
On serialized lines, each part cycle (per FDS-06-010) SHALL:
1. Place the `SerializedPart` into the current open container
2. Create a `ContainerSerial` record with container, tray, serial, and tray position
3. Increment the current tray's `PieceCount`
4. When the tray is full (per `ContainerConfig.PartsPerTray`), advance to the next tray
5. When all trays are full (per `ContainerConfig.TraysPerContainer`), close the container

#### FDS-07-004 — Container Filling — Non-Serialized Lines
On non-serialized lines, the operator SHALL assign a piece count to the container. The system SHALL:
1. Create `ContainerTray` records as trays are filled
2. Close the container when the configured capacity is reached
3. On lines with weight-based tracking, the system MAY use the scale reading to validate the piece count before closure

#### FDS-07-005 — Container Closure
When a container reaches capacity, the system SHALL:
1. Set container status to COMPLETE
2. Request an AIM shipper ID via `GetNextNumber` (see Section 13 — External Interfaces)
3. Store the `AimShipperId` on the container record
4. Generate and print a ZPL shipping label via the terminal's Zebra printer
5. Record the `ShippingLabel` print (container, shipper ID, ZPL content, timestamp)
6. Log to `Audit.OperationLog` and queue the AIM call to `Audit.InterfaceLog`

### 7.3 Shipping Labels

#### FDS-07-006 — Shipping Label Generation
Each completed container SHALL receive a shipping label containing the AIM shipper ID, part number, quantity, and Honda-required fields. The label SHALL be generated as ZPL and sent to the Zebra printer associated with the terminal.

#### FDS-07-007 — Shipping Label Tracking
Every shipping label print, void, and reprint SHALL be recorded in the `ShippingLabel` table: container, AIM shipper ID, label type, ZPL content, void flag, printed/voided timestamps, and printed-by user.

#### FDS-07-008 — Shipping Label Void
When a shipping label is voided (e.g., container sent to Sort Cage), the system SHALL:
1. Set `IsVoid = 1` and record `VoidedAt` on the shipping label record
2. Notify AIM of the void via the appropriate interface call
3. The voided label SHALL remain in the database for audit trail — it is NOT deleted

#### FDS-07-009 — Shipping Label Reprint
If a shipping label is damaged or unreadable, an authorized user SHALL be able to reprint it. The reprint SHALL be tracked as a new `ShippingLabel` record (the original is NOT modified). (FRS 3.13.1)

### 7.4 AIM Integration

#### FDS-07-010 — AIM Shipper ID Request
When a container is complete, the system SHALL call AIM `GetNextNumber` to obtain a shipper ID. The request and response SHALL be logged to `Audit.InterfaceLog`. If AIM is unavailable, the system SHALL queue the request for retry (per FDS-01-006 dispatch pattern). The container SHALL remain in COMPLETE status with a null `AimShipperId` until the AIM call succeeds — the label SHALL NOT print until the shipper ID is assigned.

#### FDS-07-011 — AIM Hold Notification
When a container is placed on hold, the system SHALL call AIM `PlaceOnHold` with the shipper ID. When released, the system SHALL call AIM `ReleaseFromHold`. Both calls SHALL be logged to `Audit.InterfaceLog`. (FRS 2.3.1)

#### FDS-07-012 — AIM Update for Re-Sort
When containers are re-packed at the Sort Cage with serial number migration, the system SHALL call AIM `UpdateAim` with the new serial and previous serial parameters (per Appendix L method signature) to update Honda's records. (FRS 2.1.10)

### 7.5 Shipping Dock Workflow

#### FDS-07-013 — Shipping Validation
At the Shipping Dock, the operator SHALL scan each container's shipping label before loading onto the truck. The system SHALL validate:
- Container status is COMPLETE (not HOLD, not VOID, not already SHIPPED)
- AIM shipper ID is assigned and valid
- If validation fails, the system SHALL prevent loading and display the reason

#### FDS-07-014 — Ship Confirmation
On successful validation, the system SHALL:
1. Set container status to SHIPPED
2. Record a `LotMovement` for the source LOT to the Shipped location
3. Log to `Audit.OperationLog`

### 7.6 Container Holds

#### FDS-07-015 — Container Hold
A quality-authorized user SHALL be able to place a hold on one or more containers. The system SHALL:
1. Set container status to HOLD
2. Record the hold number (optional reference)
3. Call AIM `PlaceOnHold` (FDS-07-011)
4. Held containers SHALL NOT be loadable at the Shipping Dock

#### FDS-07-016 — Container Hold Release
A quality-authorized user SHALL be able to release a held container. The system SHALL:
1. Set container status back to COMPLETE
2. Call AIM `ReleaseFromHold`
3. The container is now eligible for shipping

### 7.7 Sort Cage — `MVP-EXPANDED`

#### FDS-07-017 — Sort Cage Workflow
When held containers are sent to the Sort Cage for re-inspection:
1. The containers SHALL be moved to the Sort Cage location (`LotMovement`)
2. Operators unpack and inspect each part
3. Good parts SHALL be re-packed into new containers
4. For serialized parts, the MES SHALL support part replacement — updating `ContainerSerial` records to reflect the new container and tray position (FRS 2.1.10, 2.2.7)
5. New LTT labels SHALL print for any new LOTs created during re-sort (print reason: SORT_CAGE)
6. New shipping labels SHALL print for re-packed containers
7. Old shipping labels SHALL be voided (FDS-07-008)
8. AIM SHALL be updated for serial migrations via `UpdateAim` (FDS-07-012)

#### FDS-07-018 — Sort Cage Scope Boundary
The Sort Cage workflow uses holds (MVP) and LOT splits (MVP) as the operational tools for quality disposition. Formal NCM disposition codes and rework routing are FUTURE capabilities. In MVP, the Sort Cage separates good from bad parts via split, scrap, and re-pack — not via formal non-conformance records.

#### FDS-07-019 — Sort Cage Is Not a LOT Merge Event
Sort Cage operations SHALL NOT generate `LotGenealogy` merge records. A merge in our model combines multiple LOTs into a new output LOT. Sort Cage operations do something different:

- **Container re-pack:** Good parts are moved from a held container into one or more new containers. For **serialized** parts, this updates `ContainerSerial` assignments (which container/tray each serial is in) without changing the serial-to-LOT ancestry. The `SerializedPart.LotId` FK remains pointing to the original source LOT. Traceability is preserved through the serial, not through container or LOT identity.
- **Scrap disposition:** Parts identified as defective during Sort Cage inspection follow the Pattern B split-to-scrap workflow (FDS-06-019) — split from the held LOT, transition to `Scrap` status. This creates a `LotGenealogy` Split record, not a Merge record.
- **Shipper ID migration:** When a re-packed container receives a new AIM shipper ID, the system calls AIM `UpdateAim` with the `previousSerial` parameter (per FDS-07-012) to maintain Honda's record of the serial-to-shipper mapping. This is an integration concern, not a data model genealogy concern.

**Key principle:** For serialized parts, the permanent record of "this serial came from that LOT" lives in `SerializedPart`, not in container membership. Sort Cage operations rearrange container membership without touching that permanent record, so no merge genealogy is created.

> 🔶 **PENDING CUSTOMER VALIDATION — UJ-05:** Sort Cage serial migration is still open pending MPP input on whether audit trail requirements call for a `ContainerSerialHistory` table. The "Sort Cage is not a merge" design stands regardless of that decision — the merge/no-merge question is independent of the audit trail question.

**Edge case to validate with MPP:** If Sort Cage workflow pools parts from multiple containers (different source LOTs) into a single new container, the new container would hold serials from multiple source LOTs. This is NOT a LOT merge — the source LOTs still exist independently, and each serial still traces to its original LOT via `SerializedPart`. The `ContainerSerial` junction table already supports mixed-LOT containers. Confirm with MPP whether this pooling actually happens in the real Sort Cage workflow.

---

---

## 8. Quality & Hold Management — MIXED SCOPE

### 8.1 Design Overview

Quality management in MVP delivers three capabilities: hold management (MVP-EXPANDED), inspections with versioned specs (MVP), and optionally sampling workflows (CONDITIONAL). Non-conformance management and failure analysis are FUTURE — the tables exist but are not populated or surfaced in MVP.

MPP currently uses Intelex for formal NCM/failure analysis. The MES hold system and Intelex operate independently; future integration is designed for but not delivered.

### 8.2 Hold Management — `MVP-EXPANDED`

#### FDS-08-001 — Hold Placement
A quality-authorized user SHALL be able to place a hold on one or more LOTs. Each hold SHALL record: LOT, hold type, reason, placed-by user, and timestamp. Hold types SHALL include: QUALITY, CUSTOMER_COMPLAINT, PRECAUTIONARY. (FRS 3.16.10)

#### FDS-08-002 — Hold Effect
When a LOT's status transitions to HOLD, the `BlocksProduction` flag on the HOLD status code SHALL prevent manufacturing operation completion activities against that LOT. Any attempt to record production against a held LOT SHALL be rejected with a clear message. (FRS 3.16.10)

#### FDS-08-003 — Hold Release
A quality-authorized user SHALL be able to release a hold. The system SHALL record: released-by user, released-at timestamp, and release remarks on the `HoldEvent` record. The LOT status SHALL transition from HOLD back to GOOD. (FRS 3.16.11)

#### FDS-08-004 — Hold Without NCM
A hold SHALL NOT require an associated non-conformance record. The `NonConformanceId` FK on `HoldEvent` is nullable. Precautionary holds (e.g., customer complaint pending investigation) are placed without formal NCM. (FRS 2.1.8)

#### FDS-08-005 — Partial Disposition via Split
When investigation reveals only a portion of a held LOT is defective, the user SHALL split the LOT (per FDS-05-009) to isolate suspect parts. The suspect child LOT can be scrapped while the remainder is released. Genealogy permanently records the split. This is the MVP mechanism for partial quality disposition.

#### FDS-08-006 — Bulk Hold
The Hold Management screen SHALL support searching for LOTs by criteria (part number, die number, cavity number, date range, location) and placing holds on multiple LOTs in a single action. Each LOT SHALL receive its own `HoldEvent` record. (FRS 3.16.10)

#### FDS-08-007 — Container Hold Integration
Hold management SHALL integrate with container holds (FDS-07-015/016) and AIM hold notifications (FDS-07-011). When a LOT that is the source of a completed container is held, the system SHOULD alert the user that associated containers exist and may need to be held as well.

#### FDS-08-007a — Dedicated Hold Management Screen — `MVP-EXPANDED`

**OI-22 (new v0.10):** The MES SHALL expose a dedicated **Hold Management** Perspective screen reachable from the home tile bar (mirroring the top-level Hold tile in the legacy Flexware MES). The screen SHALL provide:

- **Active holds list** — all LOTs currently in `LotStatusCode = Hold`, sorted by `HoldEvent.PlacedAt` descending, filterable by Area, Line, Cell, Part Number, Hold Type, and Placed-By user.
- **Active container holds list** — all containers currently in `ContainerStatusCode = Hold`, same filtering set, with an indicator when the container references a source LOT also on hold.
- **Place Hold action** — opens a form accepting LOT selection (scan or multi-select from list), hold type, reason. Submit requires AD elevation per FDS-04-007. Writes one `HoldEvent` per selected LOT and transitions each LOT's status to `Hold`.
- **Release Hold action** — operator selects one or more active holds, enters release remarks, and submits. Requires AD elevation. Writes the release side of each `HoldEvent` and transitions LOT status back to `Good`.
- **Bulk Hold / Bulk Release** — follows FDS-08-006 search + multi-select semantics.
- **Navigation** — each row in the active holds list SHALL link to the corresponding Lot Details screen (read-only view with genealogy and the governing `HoldEvent` highlighted).

The Hold Management screen is the **operator-visible surface** — not a Configuration Tool function. Role requirement: the screen SHALL be accessible to Quality and Supervisor roles without elevation to *view*; Place and Release actions trigger FDS-04-007 per-action elevation. Admins MAY override any hold via the same elevation prompt.

### 8.3 Inspections — `MVP`

#### FDS-08-008 — Quality Spec Management
Engineering users SHALL create and version quality specs via the configuration tool. Each spec SHALL define: name, associated item (optional), associated operation template (optional), and a list of measurable attributes. (FRS 3.16.1)

#### FDS-08-009 — Quality Spec Versioning
When a spec is revised, a new version SHALL be created with a new effective date. The previous version SHALL be soft-deleted. Inspection records SHALL FK to the spec version active at time of inspection, ensuring historical accuracy. (FRS 3.16.2)

#### FDS-08-010 — Quality Spec Attributes
Each spec version SHALL define measurable attributes with: name, data type, UOM, target value, lower limit, upper limit, required flag, and sort order. The inspection screen SHALL render input fields dynamically based on these attribute definitions.

#### FDS-08-011 — Inspection Recording
When an inspector takes a sample from a LOT, the system SHALL:
1. Create a `QualitySample` record: LOT, spec version (active at time of sampling), location, sample trigger (SHIFT_START, DIE_CHANGE, TOOL_CHANGE, etc.), inspector, timestamp
2. For each spec attribute, create a `QualityResult` record: measured value, UOM, pass/fail (auto-calculated from limits)
3. Calculate the overall sample result (PASS if all required attributes pass, FAIL if any required attribute fails)
4. Log to `Audit.OperationLog`

#### FDS-08-012 — Failed Inspection Handling
If an inspection fails, the system SHALL alert the inspector. The system SHALL NOT automatically place a hold — the inspector or quality supervisor decides the appropriate action (hold, continue monitoring, split suspect parts). This preserves human judgment in quality decisions.

#### FDS-08-013 — Quality Attachments
Inspectors SHALL be able to attach files (CSV, XLSX, PDF, PNG, JPG) to quality samples. Attachments SHALL be stored on the file system with metadata tracked in `QualityAttachment`: file name, type, path, uploaded-at, uploaded-by.

### 8.4 Sampling Workflows — `CONDITIONAL`

#### FDS-08-014 — Sample Triggers
If sampling is included, the system SHALL support configurable sample triggers: SHIFT_START, DIE_CHANGE, TOOL_CHANGE, TIME_INTERVAL, and MANUAL. The system SHOULD prompt operators to take a sample when a trigger condition is met.

#### FDS-08-015 — Sample Results as Representative
Quality samples are assumed representative of the entire LOT. A passing sample releases the LOT for continued production; a failing sample flags the LOT for quality review. (FRS 2.1.9)

### 8.5 Defect Codes — `MVP`

#### FDS-08-016 — Defect Code Management
The ~145 defect codes from FRS Appendix E SHALL be loaded as seed data. Each code SHALL be associated with an area (Die Cast, Machine Shop, Trim Shop, Production Control, Quality Control, HSP). The `IsExcused` flag SHALL be set per the appendix for future OEE quality calculations.

#### FDS-08-017 — Area Filtering
Production screens SHALL filter defect codes by the area of the current operation. A Die Cast screen shows only Die Cast defect codes; a Machine Shop screen shows only Machine Shop codes.

### 8.6 Non-Conformance Management — `FUTURE`

#### FDS-08-018 — NCM Scope Boundary
The `NonConformance` table EXISTS in the data model but SHALL NOT be populated or surfaced in MVP screens. When activated in a future phase, it provides: structured defect disposition (PENDING, USE_AS_IS, REWORK, SCRAP, RETURN_TO_VENDOR), linkage to LOTs and defect codes, resolution tracking, and file attachments. The nullable FK between `HoldEvent` and `NonConformance` enables activation without schema changes.

---

## 9. Downtime Tracking — MIXED SCOPE

### 9.1 Design Overview

Downtime tracking captures when machines stop producing and why. The MES records discrete start/end events — a more granular model than the legacy paper forms, which track cumulative minutes subtracted from a base runtime. The ~660 downtime reason codes from FRS Appendix D are loaded as seed data.

OEE calculation from downtime data is FUTURE.

### 9.2 Downtime Events — `MVP`

#### FDS-09-001 — Manual Downtime Entry
Operators SHALL be able to log downtime events manually: machine (auto-populated from terminal location), reason code (filtered by area and type), start time, end time, and remarks. (FRS 3.15.1)

#### FDS-09-002 — PLC-Triggered Downtime
Where PLC integration exists, the system SHALL create downtime events automatically when the PLC signals a machine stop (`source=PLC`). The `DowntimeReasonCodeId` MAY be null on PLC-triggered events — the operator assigns the reason code after the fact. (FRS 3.15.2)

#### FDS-09-003 — Open Downtime Events
A downtime event is "open" when `EndedAt` is NULL. The system SHALL display open events prominently on the machine's production screen. When the machine resumes, the operator (or PLC) closes the event by setting `EndedAt`.

#### FDS-09-004 — Downtime Event Immutability
Downtime events SHALL be append-only. The `StartedAt` timestamp SHALL NOT be overwritten after creation. If a correction is needed, the event's `EndedAt` and `DowntimeReasonCodeId` MAY be updated (these are the only mutable fields — they represent deferred information, not corrections to immutable facts).

#### FDS-09-005 — Downtime Reason Code Filtering
The downtime entry screen SHALL filter reason codes by:
1. Area (matching the machine's area in the location hierarchy)
2. Reason type (Equipment, Mold, Quality, Setup, Miscellaneous, Unscheduled)

The operator selects the type first, then the specific code within that type.

### 9.3 Downtime Reason Codes — `MVP`

#### FDS-09-006 — Reason Code Seed Data
The ~660 downtime reason codes from FRS Appendix D SHALL be loaded as seed data. Each code SHALL carry: code, description, area, reason type, and `IsExcused` flag.

#### FDS-09-007 — Reason Types
The following reason types SHALL be seeded: Equipment, Miscellaneous, Mold, Quality, Setup, Unscheduled. (FRS Appendix D)

### 9.4 Shift Management — `MVP`

> ✅ **RESOLVED — OI-03 (2026-04-20):** Shift availability is **derived from events**, not from operator-entered minute adjustments. The MES captures **events + durations**; available time = shift duration − total downtime. No `+30`-minute "through-lunch" entries, no `+110`-minute 10-hour-overtime fields. MPP-authored schedules (currently a 5–6 spreadsheet rollup) SHALL be imported; MPP owes the spreadsheet template. Shifts run Monday–Friday at consistent start times; lines run different durations. Early starts automatically increase availability because events drive runtime. Operators log breaks once at end-of-shift via a single uptime/downtime categorisation — no live per-break entry.

#### FDS-09-008 — Shift Schedules
Engineering users SHALL configure shift schedules: name, start time, end time, days-of-week bitmask, and effective date. Common patterns: First Shift (6:00am–2:00pm M–F), Second Shift (2:00pm–10:00pm M–F), Weekend Overtime. Schedule data SHALL be imported from MPP's authoring spreadsheet at cutover (FDS-09-012) and maintained via the Configuration Tool thereafter. Shift-schedule rows persist across time via the `EffectiveFrom` column; old schedules are soft-deleted via `DeprecatedAt`, not overwritten.

#### FDS-09-009 — Shift Instances, Event-Derived Runtime
The system SHALL create actual `Oee.Shift` instances from schedules as each shift begins. Each shift instance records: schedule reference, date, scheduled start, scheduled end. **Actual runtime SHALL be derived from events**, not stored as adjustable start/end columns:

- **Available time** = `(SheduledEnd − ScheduledStart) − SUM(downtime spans within the shift window)`.
- **Downtime total** = sum of `Oee.DowntimeEvent` durations whose `StartedAt` falls within the shift window.
- **Runtime / availability ratio** = `Available / (ScheduledEnd − ScheduledStart)`.

The system SHALL NOT accept operator-entered minute adjustments (no "+30 for running through lunch", no "+110 for 10-hour OT"). Any effort that occurred outside the scheduled window — e.g., early-start production — is captured by the production event timestamps themselves (FDS-09-014).

#### FDS-09-010 — Shift-Downtime Association
Downtime events SHALL be associated with a shift instance (`ShiftId` FK). If a downtime event spans a shift boundary, it SHALL be associated with the shift in which it started. The system SHALL NOT auto-split events across shifts.

> **Note:** This addresses User Journey Assumption #10 (shift boundary handling). Open downtime events at shift change remain open — the incoming shift operator closes them when the machine resumes. They do not auto-close and re-open.

#### FDS-09-012 — Shift Schedule Import
At cutover, shift schedules SHALL be imported from MPP's authoring spreadsheet (a 5–6-file rollup consolidated into a single schedule sheet — MPP to share the template). Import fields: shift name, start time, end time, days-of-week, effective date, associated lines/areas. The import proc SHALL be idempotent — re-running it with a revised spreadsheet updates existing `Oee.ShiftSchedule` rows and adds new rows without duplicating. Manual Configuration Tool edits post-import SHALL be audit-logged with the edit reason. FUTURE: live integration with MPP's scheduling tool is out of MVP scope.

#### FDS-09-013 — Break Logging
Operators SHALL NOT log breaks live during a shift. At end-of-shift (or at the operator's choosing), a single end-of-shift view SHALL let the operator categorise the shift's idle spans as `Break` / `Lunch` / `Downtime` / `Changeover`. The categorisation writes `Oee.DowntimeEvent` rows with appropriate `DowntimeReasonCode` values spanning the identified idle time. This design avoids the paper-form-era friction of per-break entry while preserving the downtime classification Honda needs for OEE reporting. (OI-03 resolution; FRS 3.15.2)

#### FDS-09-014 — Early-Start Behaviour
When production events are captured with `RecordedAt` **earlier** than the shift's scheduled start, the MES SHALL accept those events without rejection. Availability reporting SHALL use the time-window bounded by the earliest event and the shift's scheduled end (effectively expanding the window backwards). MPP explicitly requested this behaviour at the 2026-04-20 review — early starts increase availability because events drive runtime, and operators should not be penalised for starting early. A shift that is NOT run (zero events across the entire scheduled window) SHALL still instantiate an `Oee.Shift` row and report as zero-run for auditability.

### 9.5 OEE — `FUTURE`

#### FDS-09-011 — OEE Scope Boundary
The `OeeSnapshot` table EXISTS in the data model but SHALL NOT be populated in MVP. When activated, a Gateway Scheduled Script SHALL calculate Availability x Performance x Quality per machine per shift and write materialized snapshots. All source data (downtime events, production events, shift instances) is already captured by MVP — activation requires only the calculation job, no new data capture.

---

## 10. PLC/OPC Integration — `MVP`

### 10.1 Design Overview

The MES integrates with shop-floor equipment via OPC servers. Two primary patterns exist: the Machine Integration Panel (MIP) handshake for assembly lines, and direct tag reads for scales and sensors. All PLC communication flows through the Ignition Gateway's OPC connections.

### 10.2 MIP Handshake Protocol — Serialized Lines

#### FDS-10-001 — MIP Touch Points
For serialized assembly lines (5G0 Fronts/Rears), the MES SHALL implement the following handshake per the 5GO_AP4 Automation Touchpoint Agreement:

| Tag | Direction | Type | Purpose |
|---|---|---|---|
| DataReady | Plc → MES | BOOL | Plc signals a part cycle is complete |
| TransInProc | MES → PLC | BOOL | MES acknowledges processing |
| PartSN | Plc → MES | STRING | Serial number (laser-etched or barcode read) |
| PartValid | MES → PLC | BOOL | MES validation result (1=pass, 0=fail) |
| HardwareInterlockEnable | Plc → MES | BOOL | Whether MES validation is required |
| MESInterlockEnable | MES → PLC | BOOL | Whether MES interlock is active |
| WatchDog | MES ↔ PLC | BOOL | Heartbeat for connection health |
| ContainerCount | MES → PLC | INT | Current container piece count |
| PartType | MES → PLC | STRING | Current part number for display |
| AlarmMsg | MES → PLC | STRING | Alarm text (Low Inventory, Invalid PartSN, Duplicate PartSN) |

(Touchpoint Agreement Section 1.1–1.4)

#### FDS-10-002 — MIP Transaction Flow
For each part cycle:
1. PLC sets `DataReady=1`
2. MES sets `TransInProc=1` (acknowledging)
3. MES reads `PartSN` and `HardwareInterlockEnable`
4. If `HardwareInterlockEnable=true`: MES validates serial, writes `PartValid` result
5. If `HardwareInterlockEnable=false`: MES accepts `PartSN="NoRead"`, skips validation (FDS-06-012)
6. MES records consumption event, serialized part, container serial (per FDS-06-010)
7. MES updates `ContainerCount`
8. MES clears `TransInProc=0`

#### FDS-10-003 — MES Alarms
The MES SHALL write alarm messages to `AlarmMsg` for:
- **Low Inventory Level** — source LOT piece count below configurable threshold
- **Invalid PartSN** — serial number fails format validation
- **Duplicate PartSN** — serial number already exists in the system

### 10.3 Non-Serialized Line Integration

> 🔶 **REVISED — OI-04 (2026-04-20):** MPP rejected the earlier "auto-hold LOT + supervisor override" direction at the 2026-04-20 review. The revised model stops the operation, not the LOT: production halts until the specific issue is rectified, escalates to a leader after 10 consecutive failures, and branches by failure type (wrong part → leader flag; wrong orientation → no escalation). Hold release goes through either Quality or the Controlled Run Tag (CRT) workflow — CRT-released material requires a 200%-inspect downstream. Supervisor elevation everywhere uses the per-action AD prompt from FDS-04-007 (no PIN).

#### FDS-10-004 — Disposition-Based Lines
For non-serialized lines with MicroLogix1400 PLCs (6B2, 6MA, RPY, 6FB per Appendix C), the MES SHALL read `PartDisposition` flags and `ContainerName` tags. These provide pass/fail validation without individual serial tracking.

#### FDS-10-005 — Vision / Operator Conflict — Line-Stop Semantics
On lines with Cognex vision systems, the MES SHALL read `VisionPartNumber` tags for automated part number confirmation. If the vision-confirmed value conflicts with the operator-entered value, or if a PartDisposition fail flag is raised, the system SHALL:

1. **Stop the operation** — assert a line-stop signal to the PLC and block further MES-side scans at that station. The LOT SHALL NOT be placed on `Hold` — `Lots.LotStatusCode` is untouched by line-stop.
2. Display a blocking popup describing the specific conflict (e.g., "Vision says 59B, operator scanned 5PA — stopped").
3. Route to escalation per FDS-10-009 / FDS-10-010 based on failure count and failure type.
4. Log the conflict to `Audit.OperationLog` with `LogEventType = LineStopped` and a `FailureLog` row capturing the conflicting values.
5. Resume only when the issue is rectified (FDS-10-011) — either the operator corrects the part identification and the vision agrees on the next cycle, or Quality / Supervisor releases via FDS-10-011 / FDS-10-012.

Stopping the operation (not the LOT) preserves LOT status continuity for downstream operations and avoids mass-hold cascades when a single cell misreads a part. (OI-04 revised; FRS 3.16.10 semantics retained at the event level.)

#### FDS-10-009 — 10-Consecutive-Fail Escalation
The MES SHALL track consecutive validation failures per Cell per active part (consecutive = not interrupted by a successful validation). On the **10th consecutive failure**, the system SHALL:

1. Auto-escalate to the line leader — `LogEventType = LeaderEscalationFlagged`; a Perspective notification badge fires on the Supervisor dashboard referencing the cell and failure pattern.
2. Require supervisor AD elevation (FDS-04-007) before production can resume on that cell.
3. Reset the consecutive-fail counter to zero on the next successful validation or on supervisor override.

The 10-fail threshold is configurable via a `LocationAttribute` (`LineStopConsecutiveFailThreshold INT`, default `10`) on Cell-tier Locations so engineering can tune per line.

#### FDS-10-010 — Failure-Type Branching
Not every failure type requires leader escalation. The system SHALL branch as follows:

| Failure type | Line stop? | Leader flag? |
|---|---|---|
| Wrong part (vision ≠ operator) | Yes | Yes — immediately on first failure (OI-04 direction: this is a traceability-critical error) |
| Wrong orientation (vision detects flipped/rotated part) | Yes | No — operator corrects and retries, no escalation unless FDS-10-009 10-fail threshold is hit |
| PartDisposition fail (PLC-side reject flag) | Yes | No — counts toward the FDS-10-009 threshold |
| Raw-material / barcode mis-scan | No (operator just re-scans) | No |

The branching rule SHALL be configurable per defect type via `Quality.DefectCode.LeaderFlagOnFirstOccurrence BIT` (new column, nullable — NULL means "no immediate flag, use FDS-10-009 threshold"). Seed data sets wrong-part defect codes to `1`; orientation and disposition codes to `0` or NULL.

#### FDS-10-011 — Hold Release Path
When a LOT is on `Hold` (not line-stopped — separate concept), release SHALL go through one of two paths:

1. **Quality release:** A user in the `Quality` Ignition role authenticates via FDS-04-007 AD elevation and marks the hold as resolved. The hold's `HoldEvent` row is closed (`ReleasedAt = SYSUTCDATETIME()`); the LOT's `LotStatusCode` returns to `Good`. Used when the hold reason has been physically resolved (e.g., parts re-inspected and found conforming).
2. **Controlled Run Tag (CRT) release:** See FDS-10-012 — a Quality user releases the hold with a CRT, which forces a 200%-inspect downstream. Used when the parts are likely acceptable but need explicit verification at the next operation.

Supervisor AD elevation (FDS-04-007) is required for both paths. Operators SHALL NOT release holds directly. (OI-04 revised; FRS 3.16.10)

#### FDS-10-012 — Controlled Run Tag (CRT) Workflow
A Controlled Run Tag (CRT) is a Quality-issued hold release that commits a downstream 200%-inspect obligation on the affected material. When Quality issues a CRT release:

1. The `Quality.HoldEvent` row closes with `ReleaseDispositionCode = ControlledRunTag`; the LOT's `LotStatusCode` returns to `Good` but the LOT carries a **CRT flag** — new column `Lots.Lot.CrtActive BIT NOT NULL DEFAULT 0` (Phase G data-model addenda).
2. The next operation downstream of the CRT release SHALL perform a 200%-inspect — Quality Spec attributes captured twice per part and reconciled. The operator-facing screen SHALL force the double-capture when `CrtActive = 1`.
3. On completion of the 200%-inspect, `CrtActive` clears and a `Quality.QualityResult` row is written with `InspectionResultCode = CrtCompleted`.
4. If the CRT run was NOT inspected when executed (material passed through without the 200% check), the material SHALL be flagged for **re-run through the process** — a new `Quality.HoldEvent` is created with `HoldReason = MissedCrtInspect` and the LOT returns to `Hold`. This is the "if not when run, it needs to be run through again" rule from the 2026-04-20 notes.
5. All CRT activity logs to `Audit.OperationLog` with dedicated event types (`CrtIssued`, `CrtCompleted`, `CrtMissed`).

The CRT Perspective workflow lives in the Quality module (FDS §8.2 addenda in Phase E) — this FDS requirement captures the PLC-side and escalation-side behaviour only. (OI-04 revised; FRS 3.16.10 + MPP 2026-04-20 "CRT = 200% inspect")

### 10.4 Scale Integration

#### FDS-10-006 — OmniServer Scale Reads
The MES SHALL read weight values from OmniServer-connected scales for:
- Trim Shop LOT weight estimation (FDS-06-005)
- Inspection line container weight verification
- Assembly line weight-based validation where applicable

Tag pattern: `OmniServer/[LineName].[ScaleName].NET_NetWeightValue`

### 10.5 Barcode Integration

#### FDS-10-007 — Barcode Scanners
Barcode scanners at terminals SHALL operate as keyboard wedge devices — scan data is injected into the active input field on the Perspective screen. No custom scanner driver integration is required. The MES SHALL validate scanned data (LTT barcode format, AIM shipper ID format) on the server side after entry.

#### FDS-10-008 — Zebra Printer Integration
ZPL label generation and printing SHALL be handled via Ignition's built-in TCP socket or serial communication to Zebra printers. Each terminal record specifies its associated printer. ZPL templates SHALL be configurable (not hard-coded) to accommodate label format changes.

---

## 11. Audit & Logging — `MVP`

### 11.1 Design Overview

Every state-changing action in the MES is logged. **Four** log types serve different audiences: operation logs for shop-floor actions, configuration logs for engineering/admin changes, interface logs for external system communications, and **failure logs for attempted-but-rejected operations**. All logs are immutable, append-only, with BIGINT PKs for high-volume append. (FRS 3.5.14)

All audit writes flow through four shared stored procedures (`Audit_LogConfigChange`, `Audit_LogOperation`, `Audit_LogInterfaceCall`, `Audit_LogFailure`). Entity-specific procs never write to log tables directly — they call the shared procs. This gives a single source of truth for how audit entries are written and makes the audit schema refactor-friendly.

### 11.2 Log Types

#### FDS-11-001 — Operation Log
Every shop-floor action SHALL be logged to `Audit.OperationLog`: LOT creation, movement, split, merge, production recording, consumption, hold placement/release, container operations, label prints, downtime entry. Each record SHALL include: timestamp, user, terminal, location, severity, event type, entity type, entity ID, description, and old/new values where applicable. Writes occur via `Audit_LogOperation` inside the mutating proc's transaction — atomic with the data.

#### FDS-11-002 — Configuration Log
Every engineering and admin change SHALL be logged to `Audit.ConfigLog`: item creation/modification, BOM changes, route changes, quality spec changes, defect code changes, downtime code changes, location changes, terminal changes, user changes. Each record SHALL include: timestamp, user, severity, event type, entity type, entity ID, description, and a structured changes field (JSON or diff format). Writes occur via `Audit_LogConfigChange` inside the mutating proc's transaction — atomic with the data.

#### FDS-11-003 — Interface Log
Every external system communication SHALL be logged to `Audit.InterfaceLog`: AIM calls (GetNextNumber, UpdateAim, PlaceOnHold, ReleaseFromHold), Zebra print jobs, and any future integration calls. Each record SHALL include: timestamp, system name (AIM, ZEBRA, PLC, MACOLA, INTELEX), direction (INBOUND/OUTBOUND), event type, description, and optionally request/response payloads when high-fidelity logging is enabled. Writes occur via `Audit_LogInterfaceCall`.

#### FDS-11-004 — Failure Log
Every attempted but **rejected** mutating stored procedure call SHALL be logged to `Audit.FailureLog`. This includes parameter-validation failures, business-rule violations (e.g., "cannot deprecate due to active dependents"), FK mismatches, and unexpected exceptions caught by a CATCH handler. Each record SHALL include: attempted timestamp, user, entity type, entity ID (nullable for Create attempts), event type, failure reason (the user-facing message), procedure name, and a JSON snapshot of the input parameters. Writes occur via `Audit_LogFailure` — called from validation-failure paths before `RETURN`, and from CATCH handlers after `ROLLBACK` (wrapped in nested TRY/CATCH so a failure-log write failure does not mask the original error).

The failure log complements `ConfigLog` and `OperationLog`: those tables record what succeeded; `FailureLog` records what was attempted and blocked. The Configuration Tool provides a dedicated Failure Log Browser with filters (entity, user, procedure, date range) and dashboard tiles for "Top Rejection Reasons" and "Top Failing Procedures" to support root-cause analysis and UX improvement. Not having this visibility is a known pain point in the legacy MES.

#### FDS-11-005 — High-Fidelity Interface Logging
The system SHALL support a configurable high-fidelity mode for interface logging. When enabled, full request and response payloads SHALL be stored in the `RequestPayload` and `ResponsePayload` columns. When disabled, only the summary description is logged. High-fidelity mode SHALL be toggleable per target system without restart.

### 11.3 Normalized Vocabularies

#### FDS-11-006 — Event Type Vocabulary
All log tables SHALL use the normalized `LogEventType` table for the event type field. This prevents free-text drift across Ignition scripts. Event types SHALL be seeded at deployment and include: `Created`, `Updated`, `Deprecated`, `LotCreated`, `LotMoved`, `LotSplit`, `LotMerged`, `LotStatusChanged`, `ProductionRecorded`, `ConsumptionRecorded`, `RejectRecorded`, `HoldPlaced`, `HoldReleased`, `ContainerCreated`, `ContainerClosed`, `ContainerShipped`, `LabelPrinted`, `LabelVoided`, `DowntimeStarted`, `DowntimeEnded`, `AimCall`, `ConfigChanged`, and others as needed.

#### FDS-11-007 — Entity Type Vocabulary
All log tables SHALL use the normalized `LogEntityType` table. Entity types SHALL include: `Lot`, `Container`, `SerializedPart`, `WorkOrder`, `Item`, `Location`, `LocationTypeDefinition`, `AppUser`, `Bom`, `RouteTemplate`, `OperationTemplate`, `QualitySpec`, `DefectCode`, `DowntimeReasonCode`, `QualitySample`, `HoldEvent`, `DowntimeEvent`, `ShippingLabel`, and others as needed.

#### FDS-11-008 — Code-String Signatures for Shared Audit Procs
The four shared audit procedures SHALL accept the event type, entity type, and severity as code strings (e.g., `'Location'`, `'Created'`, `'Info'`) rather than integer IDs. Each shared proc SHALL resolve the code strings to internal IDs via the seeded lookup tables. This keeps entity-specific procs self-documenting and removes hard-coded integer constants from the CRUD layer. A code-string that does not resolve SHALL cause the shared proc to raise an error (indicating a seeding gap or a typo).

#### FDS-11-011 — Ignition JDBC Single-Result-Set Convention
All stored procedures consumed by Ignition Named Queries SHALL return exactly one result set and SHALL NOT declare `OUTPUT` parameters. The Ignition JDBC driver surfaces `OUTPUT` parameters as the first result set and discards any subsequent `SELECT`, so `OUTPUT`-based signatures are incompatible with the platform.

- **Mutation procs** (Create / Update / Delete / Deprecate / Publish / MoveUp / MoveDown / etc.) SHALL declare `@Status`, `@Message`, and any returned identifier (`@NewId`, `@NewVersionId`, …) as local variables and SHALL emit a single final `SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;` at every exit point. The CATCH block SHALL populate these locals, `RAISERROR` for observability, then fall through to the same terminal `SELECT`.
- **Read procs** SHALL return a single result set. An empty result set is the contract for "not found" — read procs SHALL NOT return `@Status`/`@Message` and SHALL NOT raise for missing rows.
- **The four shared audit writers** (`Audit.Audit_LogConfigChange`, `Audit.Audit_LogFailure`, `Audit.Audit_LogInterfaceCall`, `Audit.Audit_LogOperation`) SHALL NOT emit any result set. They execute inside caller-owned transactions; emitting a result set breaks the `INSERT … EXEC` + `ROLLBACK` pattern used by mutation tests and callers.
- **Callers** SHALL consume mutation results via `INSERT … EXEC @t (Status, Message, NewId) EXEC …` (or the Ignition equivalent) and SHALL treat `Status = 0` together with a non-NULL `Message` as the failure contract.

### 11.4 Data Retention

#### FDS-11-009 — Retention Policy
All MES data SHALL be retained for a minimum of 20 years (Honda traceability requirement). Online data (hot storage in SQL Server) SHALL be retained for a minimum of 6 months. Data older than 6 months MAY be archived to a secondary store, but SHALL remain queryable for genealogy and audit purposes.

#### FDS-11-010 — BIGINT Primary Keys
The four log tables (`OperationLog`, `ConfigLog`, `InterfaceLog`, `FailureLog`) SHALL use BIGINT IDENTITY primary keys to support high-volume append patterns over the 20-year retention period.

---

## 12. Reporting — `MVP`

### 12.1 Design Overview

The MES SHALL provide reports that replace the legacy Productivity Database reports and support Honda traceability requirements. Reports SHALL be delivered via Ignition's Reporting Module (PDF/HTML/CSV) and Perspective embedded views.

### 12.2 Traceability Reports

#### FDS-12-001 — LOT Genealogy Report
Given any LOT, sub-LOT, serial number, or container, the system SHALL display the complete genealogy tree: all source LOTs, operations performed, operators, machines, timestamps, defect codes, and shipping destination. This is the primary Honda traceability deliverable. (FRS 3.13.2)

#### FDS-12-002 — Serialized Item Search
Given a serial number, the system SHALL return: item, source LOT(s), production date/time, operator, machine, container, shipper ID, and ship date. (FRS 3.13.2)

#### FDS-12-003 — Container Search
Given a container name or AIM shipper ID, the system SHALL return: item, piece count, source LOT(s), serial numbers (if serialized), container status, ship date, and hold history.

#### FDS-12-004 — LOT Search
The system SHALL provide a LOT search screen with filters: part number, date range, die number, cavity number, status, location, and origin type. Results SHALL display LOT details with drill-down to genealogy, movements, and production events.

### 12.3 Production Reports (Replacing Productivity DB)

#### FDS-12-005 — Die Shot Report
A report of total shots, good shots, warm-up shots, and reject counts per die per shift. Replaces the paper DCFM production sheet summary. (FRS 5.6.6)

#### FDS-12-006 — Rejects Report
A report of reject counts by defect code, area, machine, and date range. Replaces the PD rejects data entry and reporting. (FRS 3.5.4)

#### FDS-12-007 — Downtime Report
A report of downtime events by reason code, reason type, area, machine, and date range. Includes total downtime minutes per shift. Replaces the PD downtime data entry and reporting. (FRS 3.15.0)

#### FDS-12-008 — Production Report
A summary report of production output by part number, machine, shift, and date range. Includes good count, reject count, and yield. Replaces the PD production report. (FRS 3.5.4)

### 12.4 Operational Reports

#### FDS-12-009 — In-Process LOT Tracking
A real-time view of all active LOTs: current location, piece count, status, age (time since creation). Filterable by area, part number, and status.

#### FDS-12-010 — Hold Status Report
A report of all LOTs and containers currently on hold: hold type, reason, placed-by, duration on hold. Supports quality management workflow.

#### FDS-12-011 — Shipping History
A report of shipped containers by date range, part number, and AIM shipper ID. Supports Honda ASN reconciliation.

### 12.5 Global Trace Tool — `MVP` (new in v0.10, OI-15)

#### FDS-12-012 — Home-Tile Trace Access
The MES home screen SHALL expose a **Track** tile (mirroring the legacy Flexware top-level Track tile) that opens a Global Trace operator tool accessible from any context — Configuration Tool, shop-floor terminal, or Supervisor dashboard. Access requires no elevation because all results are read-only.

#### FDS-12-013 — Trace Input
The Global Trace screen SHALL accept a single input field labeled *"LOT / Serial / Container / Shipper ID"* that resolves any of the following:

- LOT `LotName` (LTT barcode)
- Sub-LOT `LotName`
- Serialized part serial number (`SerializedPart.SerialNumber`)
- Container `ContainerName`
- AIM shipper ID (`ContainerShippingLabel.ShipperId`)

Resolution SHALL be unambiguous — if the input matches multiple record types (e.g., a number used as both a LOT name and a container name), the screen SHALL prompt the user to disambiguate via a type selector. Scan input (barcode reader) SHALL be accepted in addition to keyboard entry.

#### FDS-12-014 — Trace Output
On resolution, the Global Trace screen SHALL display:

1. **Header panel** — identifier type, identifier value, current status, current location, creation timestamp, item/part number.
2. **Genealogy tree** — full forward + backward tree (FDS-05-017), rendered as an expandable hierarchy with clickable nodes that re-scope the trace to the clicked entity. Honda-critical field.
3. **Production history** — all `ProductionEvent`, `ConsumptionEvent`, and `RejectEvent` rows, chronological.
4. **Movement history** — all `LotMovement` rows.
5. **Holds / Quality dispositions** — all `HoldEvent` rows and `LotStatusHistory` transitions.
6. **Shipping history** — for any ancestor/descendant container, shipper ID, ship date, destination.

Each section SHALL have a **Print / Export** action producing a Honda-ready PDF or CSV. The Honda traceability PDF format is defined in FDS-12-001 (LOT Genealogy Report); the Global Trace screen is a faster operator-facing entry point to the same backing query with an interactive UI layered on top.

Role requirement: the Global Trace screen SHALL be accessible to Operators (no login required — view-only), Quality, Supervisor, Engineering, and Admin. All views are read-only; no mutations on this screen. Operators reaching the screen from a shop-floor terminal SHALL see an "Open on Supervisor dashboard" option for deep drilling.

---

## 13. External System Interfaces — MIXED SCOPE

### 13.1 AIM (Honda EDI) — `MVP`

#### FDS-13-001 — AIM Interface Methods
The MES SHALL implement the following AIM interface calls:

| Method | Trigger | Direction | Purpose |
|---|---|---|---|
| GetNextNumber | Container closure | MES → AIM | Request shipper ID for completed container |
| UpdateAim | Sort Cage re-pack | MES → AIM | Update serial/container mapping after re-sort |
| PlaceOnHold | Container hold | MES → AIM | Notify Honda of held shipment |
| ReleaseFromHold | Container release | MES → AIM | Notify Honda of released shipment |

(FRS 2.3.1, Appendix L)

#### FDS-13-002 — AIM Error Handling
If an AIM call fails, the system SHALL:
1. Log the failure to `Audit.InterfaceLog` with error details
2. Queue the call for retry (per FDS-01-006 dispatch pattern)
3. Alert the shipping operator that the AIM call is pending
4. The container SHALL remain in its current status until the AIM call succeeds

#### FDS-13-003 — AIM Availability
The system SHALL handle AIM unavailability gracefully. Containers can be completed and staged but SHALL NOT print shipping labels until an AIM shipper ID is assigned. Production SHALL NOT be blocked by AIM outages.

### 13.2 Macola ERP — `FUTURE`

#### FDS-13-004 — Macola Scope Boundary
Macola ERP integration is FUTURE. The data model supports it (Item.MacolaPartNumber cross-reference, `InterfaceLog` for communications), but no integration is implemented in MVP. When activated, the expected interface is CSV import of Items/BOMs from Macola and possible production data export.

### 13.3 Intelex (Quality Management) — `FUTURE`

#### FDS-13-005 — Intelex Scope Boundary
Intelex integration is FUTURE. MPP currently uses Intelex for NCM/failure analysis independently of the MES. When activated, the expected interface is REST API for synchronizing hold events and quality data between MES and Intelex.

### 13.4 SCADA / Process Dashboards — `FUTURE`

#### FDS-13-006 — SCADA Scope Boundary
SCADA process dashboards and process reporting are FUTURE. Process data is captured by Ignition Tag Historian (FDS-01-007) and is available for future dashboard development without additional MES changes.

---

## 14. Data Migration — `CONDITIONAL`

### 14.1 Overview

Data migration covers two sources: the legacy Manufacturing Director MES and the Productivity Database. Migration scope is conditional on MPP approval (80-hour quote per Scope Matrix row 2).

#### FDS-14-001 — Seed Data (MVP — Not Conditional)
The following seed data SHALL be loaded regardless of migration scope decision:
- Location hierarchy (~230 machines, areas, inventory locations)
- Item master (all active part numbers)
- Defect codes (~145 codes from Appendix E)
- Downtime reason codes (~660 codes from Appendix D)
- Shift schedules
- Quality specs (active versions)
- Container configurations (per product)

This is configuration data, not migration — it is required for the system to function.

#### FDS-14-002 — Legacy MES Migration (Conditional)
If approved, migration from Manufacturing Director SHALL include:
- Active in-flight LOTs (current WIP) — LOT identity, piece count, location, status
- LOT genealogy for in-flight LOTs (parent/child relationships)
- Open containers and their contents

Historical production data (completed LOTs, shipped containers) MAY be migrated for reporting continuity, scoped during migration planning.

#### FDS-14-003 — Productivity DB Migration (Conditional)
If approved, migration from the Productivity Database SHALL include historical production summaries for reporting continuity. The PD data structure differs from the MES schema — a transformation layer is required.

#### FDS-14-004 — Migration Validation
All migrated data SHALL be validated against the source system before go-live. Validation SHALL include: record counts, LOT status verification, genealogy integrity checks, and sample-based detail verification.

#### FDS-14-005 — Flexware BOM Import (OI-13) — `MVP`

**OI-13 (new v0.10):** Per MPP IT, authoritative Bills of Material live in the legacy **Flexware application at IP `.919`** — the predecessor MES being replaced by this project. The new MES `Parts.Bom` and `Parts.BomLine` tables SHALL be seeded from a **one-shot export** of the Flexware BOM master at cutover. See FDS-01-013 for the architectural placement; this requirement covers the migration-mechanics detail.

- **Export format (specification owed by MPP IT):** CSV or Excel, one row per BOM line. Required columns: `ParentPartNumber`, `ChildPartNumber`, `Quantity`, `Uom`, `SortOrder`, `EffectiveFrom` (optional — defaults to cutover date if absent), `BomVersion` (optional — defaults to 1). Filename convention and delimiter TBD with MPP IT.
- **Pre-flight validation:** Before running the bulk-load proc, the migration script SHALL verify that every `ParentPartNumber` and `ChildPartNumber` resolves to an active `Parts.Item` row. Unresolved references SHALL produce a pre-flight report identifying the missing items; the import SHALL NOT run until the missing items are imported (via the Parts.Item seed path) or flagged as out-of-scope.
- **Bulk-load proc:** `Parts.Bom_BulkLoadFromSeed` SHALL accept the export payload as a single JSON parameter (same pattern as `Oee.DowntimeReasonCode_BulkLoadFromSeed`, §9.3). Idempotent on re-run: unchanged BOMs skip, new BOMs insert with `PublishedAt` set at cutover, changed BOMs produce a new version via `Bom_CreateNewVersion`.
- **Cutover handoff:** MPP IT delivers the Flexware export CSV/Excel once, at the cutover date. No ongoing integration, polling, or re-sync — Flexware is retired as part of the same rollout.

**Open action:** MPP IT to deliver the Flexware export format specification + a sample export file. Bulk-load proc design lands in Phase E; proc implementation lands in Phase G once the format is specified.

---

## 15. Deployment & Commissioning — `MVP`

### 15.1 Deployment Approach

#### FDS-15-001 — Phased Rollout
The MES SHALL be deployed in phases, starting with a single area (recommended: Die Cast, as it is the LOT origin point). Each phase SHALL include: configuration, operator training, shadow commissioning, and go-live. Subsequent areas (Trim, Machining, Assembly, Shipping) SHALL be added in production flow order.

#### FDS-15-002 — Shadow Commissioning
Before go-live in each area, the new MES SHALL run in parallel with the legacy system. Operators SHALL duplicate LOT entries and movements in both systems. The shadow period SHALL validate: WIP state generation, LOT traceability, and report accuracy against legacy data. (FRS 6.1.4)

#### FDS-15-003 — Factory Acceptance Testing (FAT)
FAT SHALL be conducted off-site using simulated production data. FAT criteria SHALL include:
- LOT creation, movement, split, and merge workflows
- Production event recording and consumption tracking
- Container lifecycle through to shipping label print
- Hold placement, Sort Cage re-pack, and release
- AIM interface calls (simulated)
- Genealogy report accuracy (full tree from serial → raw material)
- All interlock validations (hold blocks production, eligibility checks, duplicate serial rejection)

#### FDS-15-004 — Site Acceptance Testing (SAT)
SAT SHALL be conducted on-site with live equipment. SAT criteria SHALL include all FAT criteria plus:
- PLC/MIP handshake with actual assembly lines
- Scale integration with actual OmniServer connections
- Zebra printer integration with actual printers
- Barcode scanner functionality at actual terminals
- AIM interface with live AIM system
- Performance under actual production volume

#### FDS-15-005 — Go-Live Support
Go-live SHALL include on-site support for the first 5 days of production (24-hour coverage). Remote support SHALL continue for 30 days after go-live.

#### FDS-15-006 — Rollback Plan
A documented rollback plan SHALL exist for each deployment phase. The legacy system SHALL remain operational during the shadow period. If the new MES encounters critical issues, the affected area SHALL revert to the legacy system with no data loss.

### 15.2 Change Management

#### FDS-15-007 — Process Change: Real-Time Data Entry
The MES replaces the legacy pattern of paper-first, clerk-entry-later with real-time operator data entry at the machine. This is a fundamental process change that requires: operator training, terminal placement review, and management commitment. The MES does NOT require a data entry clerk — all production data is captured at point-of-action. (FRS 5.6.6)

#### FDS-15-008 — Operator Training
Each area SHALL receive operator training before shadow commissioning begins. Training SHALL cover: terminal login, LOT creation, production recording, reject entry, downtime logging, and the screens specific to that area's operation templates.

---

## 16. Identifier Sequences — `MVP` (new in v0.11, OI-31)

Flexware's `IdentifierFormat` table drives two MPP-internal counters (Lot LTT barcode + SerializedItem ID) that are critical to cutover continuity. The replacement MES SHALL provide equivalent functionality via a dedicated sequence table.

#### FDS-16-001 — IdentifierSequence Table

The MES SHALL own a `Lots.IdentifierSequence` table with the column contract defined in Data Model v1.9 §3. Seeded sequences:

| Code | FormatString | StartingValue | EndingValue | Purpose |
|---|---|---|---|---|
| `Lot` | `MESL{0:D7}` | 1 | 9,999,999 | LOT LTT barcode — printed on every basket, scanned at every movement |
| `SerializedItem` | `MESI{0:D7}` | 1 | 9,999,999 | Serialized-part ID for finished goods (5G0 Fronts/Rears etc.) |

Additional sequences MAY be added via Configuration Tool (Admin-elevated per FDS-04-007) as MPP business needs emerge. Honda AIM shipper IDs are explicitly OUT of scope — those are issued by `AIM.GetNextNumber` and recorded on `Lots.ShippingLabel` / `Lots.Container`, not minted by the MES.

#### FDS-16-002 — IdentifierSequence_Next Proc

`Lots.IdentifierSequence_Next @Code` SHALL:

1. Start a transaction, atomically `UPDATE Lots.IdentifierSequence SET LastValue = LastValue + 1, UpdatedAt = SYSUTCDATETIME() OUTPUT inserted.LastValue, inserted.FormatString INTO #Result WHERE Code = @Code`.
2. Raise a business-rule error if no rows match (`@Code` unknown).
3. Raise a business-rule error if `LastValue > EndingValue` (rollover breach without explicit reset policy).
4. Format the result using the `.NET`-style format string — e.g., `string.Format('MESL{0:D7}', 1710933) = 'MESL1710933'`. Implemented as `CONCAT(prefix, RIGHT(REPLICATE('0', width) + CAST(value AS NVARCHAR(20)), width))` or equivalent in T-SQL.
5. Return a single result set `(Value NVARCHAR(50))` per the Ignition JDBC single-result-set convention (FDS-11-011). No OUTPUT parameter.

All identifier-minting paths (Lot create, SerializedItem create, future counters) SHALL go through this proc — no ad-hoc counter maintenance.

#### FDS-16-003 — Cutover-Day Seeding

The Arc 2 Phase 1 migration SHALL include a seeding step that fetches `LastCounterValue` from the Flexware `IdentifierFormat` table at cutover and seeds `Lots.IdentifierSequence.LastValue` at **or above** the Flexware value for each sequence, preventing LTT collisions with in-circulation LOTs.

Baseline values sampled 2026-04-23 (subject to drift — re-sample on cutover day): `Lot=1,710,932`, `SerializedItem=2,492`.

**Open items (OI-31):** Format carry-forward (keep `MESL`/`MESI`, or mint new prefixes in the replacement MES?), reset policy (currently none in Flexware; any line/shift-specific rules MPP wants honored going forward?), rollover policy at 9,999,999 (~30+ years at current burn rate for Lots).

**Counter inventory confirmed:** The Flexware `IdentifierFormat` table is the authoritative list. MPP's export shows exactly two rows — Lot (`MESL{0:D7}`) and SerializedItem (`MESI{0:D7}`). Other Flexware tables that reference `IdentifierFormat` via FK do so without populated format rows. No additional counters in scope.

---

## Appendices

### Appendix A: Machine List
> Seed data from FRS Appendix B. ~230 machines organized by area with attributes (tonnage, cycle times). To be populated during deployment configuration.

### Appendix B: Downtime Reason Codes
> Seed data from FRS Appendix D. ~660 codes organized by area and type (Equipment, Mold, Quality, Setup, Miscellaneous, Unscheduled). To be loaded during deployment.

### Appendix C: Defect Codes
> Seed data from FRS Appendix E. ~145 codes organized by area (Die Cast, Machine Shop, Trim Shop, Production Control, Quality Control, HSP). To be loaded during deployment.

### Appendix D: OPC Tag Map
> Complete OPC tag listing from FRS Appendix C, organized by OPC server (OmniServer, TOPServer) and line. Extended with tag-to-MES-field mappings.

### Appendix E: MIP Touch Point Specifications
> Touch point definitions from the 5GO_AP4 Automation Touchpoint Agreement, extended to all integrated assembly lines. Includes transaction flow diagrams per line type.

### Appendix F: FRS Requirements Crosswalk
> Every FRS 3.x.x requirement mapped to the FDS section and requirement ID that addresses it. Ensures complete coverage.

### Appendix G: Scope Matrix Crosswalk
> Every Scope Matrix row mapped to the FDS section, scope tag (MVP/CONDITIONAL/FUTURE), and implementation status.

### Appendix H: Paper Production Sheet Mapping
> Every field from the DCFM and MS1FM paper production sheets mapped to the MES screen, data model table, and column that captures it. Validates that no paper field is lost in the digital transition.

---

## Open Items Register

> This grid is a status summary. Full per-item design rationale, options considered, and revised-decision text live in `MPP_MES_Open_Issues_Register.md` v2.4 — the authoritative source regenerated after the 2026-04-20 MPP review.

| ID | Section | Description | Decision Owner | Status |
|---|---|---|---|---|
| **OI-01** | 1.6 | External interface dispatch: direct calls + `InterfaceLog`, no outbox | Blue Ridge / MPP IT | ✅ Resolved |
| **OI-02** | 6.6 | Weight-based container closure: scale feedback on non-serialized lines (`ClosureMethod`, `TargetWeight` nullable on `ContainerConfig` pending customer validation) | Blue Ridge / MPP Engineering | 🔶 Pending Customer Validation |
| **OI-03** | 9.4 | Shift runtime adjustments — **Resolved 2026-04-20:** availability derived from events, no minute adjustments, schedule import from MPP spreadsheet | MPP Production Control | ✅ Resolved |
| **OI-04** | 10.3 | Vision / operator conflict — **Revised 2026-04-20:** line-stop (not LOT-hold), 10-consecutive-fail escalation, branch by failure type, CRT 200%-inspect release | MPP Engineering / Quality | 🔶 Revised — In Review |
| **OI-05** | 5.5 | LOT merge rules — **Revised 2026-04-20:** post-sort only, same part, cross-die gated by `Tools.DieRankCompatibility` (matrix empty pending MPP Quality), FIFO-by-cavity on machining | MPP Production Control / Quality | 🔶 Revised — Matrix pending |
| **OI-06** | 4 (entire) | Operator identity — **Resolved 2026-04-21 (Phase C):** initials-only operator presence, per-action AD elevation for interactive users, no PIN/clock number | MPP Operations | ✅ Resolved |
| **OI-07** | 6.10 | Work order scope — **Revised 2026-04-20:** three WO types (Demand / Maintenance / Recipe), Maintenance flow FUTURE (schema hook only), Ben owes maintenance-engine scope | MPP / Ben (MPP) | 🔶 Revised — Ben owes scope |
| **OI-08** | 2.5 | Terminals — **Closed 2026-04-24:** dedicated vs shared derived from Terminal's parent Location tier (WorkCenter/Cell → Dedicated; Area → Shared); machine-context lock; part↔machine validity via `Parts.ItemLocation`; tablets in Casting | MPP IT / Operations | ✅ Closed |
| **OI-09** | 3.6, 5.4 | Multi-part lines — **Revised 2026-04-20 (addenda):** sublot pattern formalised (parent FK, per-cavity concurrent sublots, label parent reference), "one part at a time" still holds | MPP Engineering | 🔶 Revised — Addenda |
| **OI-10** | §7 Tools | Tool Life tracking — **Superseded 2026-04-21:** rolled into Phase B Tool Management design spec (Tools schema now first-class, v1.7 data model §7) | Blue Ridge / MPP Engineering | ⏹ Superseded |
| **OI-11** | TBD (Phase E) | Part identity change at Casting → Trim Shop — **New 2026-04-20:** parts get renamed crossing that boundary; genealogy bridge via `Parts.ItemTransform` proposed | MPP Engineering / Blue Ridge | ⬜ Open (new) |
| **OI-12** | 3 addenda (Phase E) | Lineside inventory caps — **New 2026-04-20:** max parts per basket (`ContainerConfig.MaxParts`) + lineside quantity limit (Cell `LocationAttribute`) | MPP Operations / Blue Ridge | ⬜ Open (new) |
| **OI-13** | 1.4 / 3 (Phase E) | BOM source — **New 2026-04-20:** authoritative BOMs live in the Flexware app at IP `.919`; one-shot export into `Parts.Bom` at cutover | MPP IT / Blue Ridge | ⬜ Open (new, HIGH) |
| **OI-14** | 4.3 (elevated actions) | Admin remove-item capability — **New 2026-04-20:** super-user scope in Configuration Tool; detail design in Phase E | Blue Ridge | ⬜ Open (new, LOW) |
