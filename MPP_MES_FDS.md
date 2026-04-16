# MPP MES — Functional Design Specification

**Document:** FDS-MPP-MES-001
**Project:** Madison Precision Products MES Replacement
**Prepared By:** Blue Ridge Automation
**Client:** Madison Precision Products, Inc. (Madison, IN)
**Version:** 0.7 — Working Draft
**Date:** 2026-04-15

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
| `MPP_MES_DATA_MODEL.md` | Column-level data model specification (7 schemas, ~50 tables) |
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
Users SHALL authenticate via Active Directory. The Ignition Gateway SHALL be configured with an AD User Source. Shop-floor terminal authentication SHALL use clock number + PIN lookup against the `Location.AppUser` table, which maps to an AD account. (FRS 5.3)

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

> ✅ **RESOLVED — OI-08 / UJ-12:** Terminals are shared (fewer terminals than machines). Operators scan a machine barcode/QR code as the first step of any interaction. In the polymorphic model, `Terminal` is a `LocationTypeDefinition` under the `Cell` type — it's one of many kinds of Cells.

#### FDS-02-008 — Terminal as Cell Kind
Each Ignition Perspective client station on the shop floor SHALL be registered as a `Location` record with `LocationTypeDefinition` = `Terminal` (which resolves to `LocationType` = `Cell`), parented under the appropriate Area in the hierarchy. Terminal-specific configuration (IP address, default Zebra printer, barcode scanner availability) SHALL be stored as `LocationAttribute` entries referencing the attribute definitions attached to the `Terminal` definition (see FDS-02-005 Example 1).

#### FDS-02-009 — Machine Context via Barcode Scan
Terminals are shared across machines. The operator's first action at any terminal SHALL be to scan a machine barcode or QR code. The system SHALL resolve the scanned value to a `Location` record whose `LocationTypeDefinition` is a machine kind (`DieCastMachine`, `CNCMachine`, `TrimPress`, `AssemblyStation`, etc.) and use that Cell as the production context for subsequent operations in the session. Event tables carry two location references:

- `TerminalLocationId` — FK → `Location.Id` where the definition is `Terminal` (where the operator is standing)
- `LocationId` — FK → `Location.Id` where the definition is a machine kind (which machine they scanned)

If the operator moves to a different machine, they scan the new machine's barcode to switch context. The terminal location remains the same throughout the session.

---

## 3. Master Data Management — `MVP`

### 3.1 Item Master

#### FDS-03-001 — Item Records
Every part number that MPP manufactures, receives, or ships SHALL have an `Item` record. Each item SHALL have: part number (unique), description, item type, Macola cross-reference number (optional — FUTURE integration), counting UOM, unit weight, weight UOM, default sub-lot quantity, and max lot size. (FRS 3.4.1–3.4.5)

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

#### FDS-03-017a — Data Collection Capture at Event Time
When a LOT passes through an operation, the system SHALL persist every field configured on the operation template as part of the production event:

1. On screen load, the client SHALL read `OperationTemplateField` rows for the active template to determine the visible inputs.
2. On submit, the Phase 8 `ProductionEvent_Record` stored procedure SHALL, in one transaction:
   a. Insert one `Workorder.ProductionEvent` header row carrying `OperationTemplateId` and the hot typed columns for fields that have been promoted (GoodCount, NoGoodCount, DieIdentifier, CavityNumber, WeightValue, WeightUomId).
   b. Insert one `Workorder.ProductionEventValue` child row per non-hot `DataCollectionField` configured on the template, keyed by `(ProductionEventId, DataCollectionFieldId)`, with both the string `Value` and the typed `NumericValue` / `UomId` where applicable.
   c. Reject the submission if any `IsRequired = 1` field on the template is missing from the payload.
   d. Reject the submission if the payload duplicates a hot-column field in `ProductionEventValue` (hot columns are the sole home for promoted fields).
3. `DieIdentifier` SHALL be captured from the machine's current `LocationAttribute` value at event time — it is the historical snapshot of the die mounted on the machine when the event occurred, not a reference to any die table (OI-10 pending).

### 3.5 Part-to-Location Eligibility

#### FDS-03-014 — Eligibility Map
The `ItemLocation` table SHALL define which parts can run on which machines. When an operator starts production at a machine, the MES SHALL validate that the selected item is eligible for that machine. If not eligible, the system SHALL reject the operation with a clear error message. (FRS 3.4.7)

#### FDS-03-015 — Eligibility Management
Engineering users SHALL be able to add and remove item-location eligibility records via the configuration tool. Changes SHALL be logged to `Audit.ConfigLog`.

### 3.6 Container Configuration

#### FDS-03-016 — Container Config
Each finished good that ships to Honda SHALL have a container configuration record specifying: trays per container, parts per tray, whether serialized, dunnage code, and customer code. This configuration drives automatic container lifecycle management on the shop floor. (FRS 3.9.7)

#### FDS-03-017 — Container Closure Logic
The system SHALL close a container automatically when the configured capacity is reached. For serialized lines, closure is triggered by part count (tracked per serial). For non-serialized lines, closure MAY be triggered by part count or weight, configurable per container config.

> ✅ **RESOLVED — OI-09 / UJ-15:** Multi-part inspection lines (e.g., MS1FM-1028 running 59B, 5PA, 6NA variants) operate one part number at a time. The operator selects the active LOT for consumption, which determines the part number. Container configuration is resolved per part number. No mixed-part containers. Changeover between part numbers is an operator action, not a concurrent process.

---

## 4. User Authentication & Session Management — `MVP`

### 4.1 Authentication Architecture

#### FDS-04-001 — Active Directory Integration
The Ignition Gateway SHALL be configured with an Active Directory User Source. All user authentication SHALL be performed against AD. The MES database SHALL NOT store passwords (except hashed PINs for terminal convenience login). (FRS 5.3)

#### FDS-04-002 — App User Records
Each MES user SHALL have an `AppUser` record in the MES database. This record exists for audit attribution (who did what), not for authentication. The `AdAccount` field links to the AD identity. (FRS Spark Dependency B.8)

#### FDS-04-003 — Clock Number + PIN Login
Shop-floor terminals SHALL support a convenience login mode: operator enters their clock number and a numeric PIN. The MES SHALL look up the `AppUser` record by clock number, verify the PIN hash, and establish a Perspective session under the corresponding AD identity. This avoids requiring operators to type AD credentials on a shop-floor keyboard. (FRS 3.6.1)

### 4.2 Session Lifecycle

> 🔶 **PENDING CUSTOMER VALIDATION — OI-06 / UJ-01:** Blue Ridge recommends login-on-first-action with 5-minute inactivity timeout. High-security actions require re-authentication. Zone-based authentication requirements are under investigation as an alternative. Needs MPP validation before screen design.

#### FDS-04-004 — Session Model
Operators SHALL authenticate on their first action at a terminal using clock number + PIN. The session SHALL remain active until the operator explicitly logs out or a configurable inactivity timeout expires (default: 5 minutes). An easy logout button SHALL be visible on all screens to support quick operator handoff at shared terminals.

#### FDS-04-005 — Elevated Actions
Actions with quality or financial impact (placing/releasing holds, scrapping LOTs, voiding shipping labels) SHALL require re-authentication regardless of session state. The system SHALL prompt for clock number + PIN before executing these actions, even if the operator has an active session. (FRS 3.3.1, 3.3.4)

#### FDS-04-006 — Multi-User Terminals
Since terminals are shared (per FDS-02-008), multiple operators will use the same terminal. The 5-minute timeout and prominent logout button ensure clean handoffs. Each operator authenticates individually via clock number + PIN. No full session restart is required — the system transitions directly from one user to another.

### 4.3 Role-Based Access

#### FDS-04-007 — Ignition Role Mapping
The following roles SHALL be configured in Ignition's identity provider:

| Role | Capabilities |
|---|---|
| Operator | LOT creation, production recording, downtime entry, container packing |
| Quality | All Operator capabilities + hold placement/release, inspection entry, LOT splitting for disposition |
| Supervisor | All Quality capabilities + LOT merge, shipping label void/reprint, override interlocks |
| Engineering | Master data management (items, BOMs, routes, operation templates, container configs) |
| Admin | All capabilities + user management, terminal configuration, system configuration |

#### FDS-04-008 — Screen-Level Security
Each Perspective view SHALL enforce role-based visibility. Operators SHALL NOT see engineering configuration screens. Quality functions (hold management, Sort Cage) SHALL be visible only to Quality and above. Administrative functions SHALL be visible only to Admin.

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
| LotName | LTT barcode scan | Unique identifier |
| ItemId | Operator selection | Which part number |
| LotOriginTypeId | System-determined | Manufactured, RECEIVED, or RECEIVED_OFFSITE |
| LotStatusId | System-managed | Current quality status (GOOD, HOLD, SCRAP, CLOSED) |
| PieceCount | Operator entry | Current count (decremented by consumption, adjusted at Trim) |
| MaxPieceCount | From item master | Reasonability ceiling |
| Weight | Operator entry or scale | Total weight |
| DieNumber | Operator entry | Die cast LOTs only |
| CavityNumber | Operator entry | Die cast LOTs only |
| VendorLotNumber | Operator entry | Received LOTs only |
| CurrentLocationId | System-tracked | Updated on every movement |

(FRS 3.9.6, 2.2.2)

### 5.2 LOT Creation Workflows

#### FDS-05-004 — Manufactured LOT Creation (Die Cast)
At Die Cast, the operator SHALL:
1. Fill a basket with parts from the die cast machine
2. Attach a **pre-printed LTT barcode sticker** to the basket (LTTs are printed in batches outside the MES per FRS 2.2.1)
3. Scan the LTT barcode at the MES terminal — this scan creates the LOT record; the physical label already exists
4. Manually enter: part number, die number, cavity number, piece count, and shot counts (total, good, warm-up) (FRS 2.2.2)
5. The MES SHALL validate: piece count ≤ max lot size, part is eligible on this machine
6. The MES SHALL create the LOT with origin type Manufactured, status Good, location = scanned machine (per FDS-02-009)
7. The MES SHALL write a `ProductionEvent` recording the good count
8. The MES SHALL **NOT** trigger an `Initial` label print — the label was pre-printed. (See FDS-05-020 for print reason policy)
9. The MES SHALL log the creation to `Audit.OperationLog`

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

1. **Login** — Operator authenticates at the terminal with clock number + PIN (per FDS-04-004). The session's `TerminalLocationId` is the `Location` where the operator is standing.
2. **Scan Location** — Operator scans the machine/location barcode for the destination (the Cell where the LOT is arriving). The system resolves the scanned code to a `Location.Id` and verifies it is a valid production context (Cell-tier, appropriate definition).
3. **Scan LOT** — Operator scans the LOT's LTT barcode. The system looks up the LOT by `LotName`, validates it is not CLOSED, and reads its current `CurrentLocationId` as the from-location.
4. **Record Movement** — The system writes a `LotMovement` row (from-location, to-location, user, terminal location, timestamp) and updates the LOT's `CurrentLocationId` to the scanned destination.
5. **Confirm** — The screen displays the movement confirmation and transitions to the appropriate next action (production recording, inspection, split, etc.) based on the destination's `LocationTypeDefinition`.

The login → scan location → scan lot sequence ensures that every movement has a clear operator, source, and destination — and that audit attribution is unambiguous.

**Implicit movement:** The system SHALL also infer a movement when a LOT is consumed or produced at a machine without a prior explicit scan. For example, if an assembly operator records consumption of a source LOT currently at the WIP staging area, the system SHALL implicitly write a `LotMovement` from WIP → the assembly Cell before writing the `ConsumptionEvent`. This keeps the traceability record complete without requiring redundant scans.

### 5.4 Sub-LOT Splitting

#### FDS-05-009 — Split Workflow

> 🔶 **PENDING INTERNAL REVIEW — UJ-03:** On arrival at machining, the system auto-splits into 2 even sublots with a confirmation dialog. Sublots are treated identically to lot splits in the data model (`LotGenealogy` with RelationshipType = Split). Needs review with Ben.

On arrival at the Machining IN screen, when a LOT is scanned, the system SHALL present an auto-split confirmation dialog:
1. Calculate an even 2-way split of the parent LOT's piece count (e.g., 50 → 25/25; 51 → 26/25)
2. Display the proposed split with editable quantities — the operator confirms or adjusts
3. On confirmation, create two child LOT records, each requiring the operator to scan a fresh LTT barcode
4. Decrement the parent LOT's piece count by the total pieces split off
5. If all pieces are split off, set the parent LOT's status to CLOSED
6. Write `LotGenealogy` records with relationship type Split for each parent→child link
7. Print LTT labels for each child sub-LOT
8. Log all operations to `Audit.OperationLog`

The operator MAY cancel the auto-split and process the LOT without splitting. The operator MAY also adjust the number of sublots (not limited to 2) or the quantities before confirming. (FRS 2.1.4, 2.2.5, 3.9.12)

#### FDS-05-010 — Uneven Split Handling
If the parent LOT's piece count is odd, the system SHALL propose the closest even split (e.g., 51 → 26/25). The operator MAY adjust these sizes before confirming. The total of all child quantities SHALL equal the parent's piece count.

#### FDS-05-011 — Split Genealogy Permanence
The parent→child relationship created by a split SHALL be permanent and immutable. Child sub-LOTs SHALL carry a `ParentLotId` FK for direct adjacency queries, and `LotGenealogy` records for graph traversal. Both directions (parent→children, child→parent) SHALL be queryable.

### 5.5 LOT Merging — `MVP` (Business Rules `PENDING MPP INPUT`)

#### FDS-05-012 — Merge Capability
The system SHALL support merging multiple LOTs into a single new LOT. The `LotGenealogy` table supports MERGE relationship type. However, the business rules governing when merges are allowed are TBD per FRS. (FRS 3.9.13)

> 🔶 **PENDING CUSTOMER VALIDATION — OI-05:** Blue Ridge recommends configurable merge rules. Examples for MPP to confirm or reject:
> - Same part number required?
> - Same die required?
> - Same cavity required?
> - Same quality status required (e.g., cannot merge GOOD + HOLD)?
> - Are piece counts additive?
> - Can a merged LOT be un-merged?
>
> Where these rules are defined (configuration screen vs. hard-coded) is also TBD — see UJ-08. The data model supports merges. The Perspective merge screen will not be built until rules are confirmed.

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

---

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

#### FDS-06-003 — Die Cast Production Event
On submission, the system SHALL (per FDS-03-017a, in one transaction):
1. Write an immutable `Workorder.ProductionEvent` header carrying `OperationTemplateId`, `LotId`, `LocationId`, `ItemId`, `GoodCount`, `NoGoodCount`, `DieIdentifier` (from the machine's `LocationAttribute`), `CavityNumber`, `WeightValue` + `WeightUomId`, `OperatorId`, `TerminalLocationId`, and `RecordedAt`.
2. Write one `Workorder.ProductionEventValue` child row per non-hot `DataCollectionField` configured on the active operation template.
3. Update the LOT's `PieceCount` to reflect the good count.
4. Log to `Audit.OperationLog`.

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

(FRS Section 4, 3.16.10)

### 6.9 Consumption Events

#### FDS-06-020 — Consumption Tracking
Every time source material is consumed to produce output, the system SHALL write an immutable `ConsumptionEvent` recording: source LOT, produced LOT (or container), consumed item, produced item, piece count, location, operator, terminal, tray (if applicable), produced serial number (if serialized), and timestamp.

#### FDS-06-021 — Consumption Genealogy
Each consumption event SHALL also generate a `LotGenealogy` record with relationship type Consumption, linking the source LOT to the output LOT or serialized part. This is the backbone of Honda traceability — every finished good traces back to every component LOT consumed. (FRS 3.13.2)

### 6.10 Work Orders — `MVP-LITE`

#### FDS-06-022 — Work Order Auto-Generation
If work order functionality is included, the system SHALL auto-generate internal work orders when production activity begins on a LOT. Operators SHALL NOT see, create, or interact with work orders directly — they are invisible bookkeeping. (FRS 3.1.5)

#### FDS-06-023 — Work Order Structure
Each work order SHALL link an item to a route template version. Work order operations SHALL be created for each route step, tracking: planned step, actual location, status (PENDING → IN_PROGRESS → COMPLETED / SKIPPED), start/completion times, and operator.

#### FDS-06-024 — Work Order Independence
Production events, consumption events, and reject events SHALL function fully without work orders. The `WorkOrderOperationId` FK on these tables is nullable. If work orders are deferred, the evidence layer operates standalone.

> 🔶 **PENDING CUSTOMER VALIDATION — OI-07 / UJ-07:** Work orders are included as invisible bookkeeping (MVP-lite). Auto-generated when production begins, operators never see them. No WO-specific screens. Work orders can also be derived from an external ERP system in the future (FRS 3.10.2), but the ERP integration spec is undefined. Lifecycle triggers (what creates a WO, span of one operation vs. full route) need customer discussion.

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

#### FDS-09-008 — Shift Schedules
Engineering users SHALL configure shift schedules: name, start time, end time, days of week, and effective date. Common patterns: First Shift (6:00am–2:00pm M–F), Second Shift (2:00pm–10:00pm M–F), Weekend Overtime.

#### FDS-09-009 — Shift Instances
The system SHALL create actual shift instances from schedules. Each shift instance records: schedule reference, date, actual start, and actual end. The actual times MAY differ from the schedule to accommodate overtime, early starts, and run-through-lunch adjustments.

> ⬜ **OPEN — OI-03:** Shift runtime adjustments. The legacy paper forms ask operators to add minutes for running through lunch (+30 min), breaks (+10 min), or overtime (+110 min for 10-hour days). How are these adjustments captured in the MES? Options: (a) adjust `Shift.ActualEnd` to reflect true end time, (b) add an adjustment field to the shift record, (c) derive runtime purely from downtime events (available time = shift duration − total downtime). Flagged for customer decision.

#### FDS-09-010 — Shift-Downtime Association
Downtime events SHALL be associated with a shift instance (`ShiftId` FK). If a downtime event spans a shift boundary, it SHALL be associated with the shift in which it started. The system SHALL NOT auto-split events across shifts.

> **Note:** This addresses User Journey Assumption #10 (shift boundary handling). Open downtime events at shift change remain open — the incoming shift operator closes them when the machine resumes. They do not auto-close and re-open.

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

#### FDS-10-004 — Disposition-Based Lines
For non-serialized lines with MicroLogix1400 PLCs (6B2, 6MA, RPY, 6FB per Appendix C), the MES SHALL read `PartDisposition` flags and `ContainerName` tags. These provide pass/fail validation without individual serial tracking.

#### FDS-10-005 — Vision System Integration
On lines with Cognex vision systems, the MES SHALL read `VisionPartNumber` tags for automated part number confirmation. If the vision-confirmed part number conflicts with the operator-entered part number, the system SHALL:
1. Place the LOT on HOLD automatically (FRS 3.16.10)
2. Display a popup alerting the operator to the conflict
3. Offer a supervisor override option — a supervisor authenticates (clock number + PIN) to release the hold and allow operations to continue
4. Log the conflict, hold event, and any override to `Audit.OperationLog`

> 🔶 **PENDING CUSTOMER VALIDATION — OI-04:** Blue Ridge recommends auto-hold + supervisor override popup for vision conflicts. The hold blocks production on that LOT until a supervisor intervenes. This ensures traceability of every conflict while not permanently stopping the line. Needs MPP validation of this workflow.

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

| ID | Section | Description | Decision Owner | Status |
|---|---|---|---|---|
| **OI-01** | 1.6 | External interface dispatch: direct calls + `InterfaceLog`, no outbox | Blue Ridge / MPP IT | ✅ Resolved |
| **OI-02** | 6.6 | Weight-based container closure: scale feedback on non-serialized lines | Blue Ridge / MPP Engineering | 🔶 Pending Customer Validation |
| **OI-03** | 9.4 | Shift runtime adjustments: how are lunch/break/overtime minutes captured? | MPP Production Control | ⬜ Open |
| **OI-04** | 10.3 | Vision system conflict: auto-hold LOT + supervisor override popup | MPP Engineering / Quality | 🔶 Pending Customer Validation |
| **OI-05** | 5.5 | LOT merge business rules: configurable, examples provided for MPP review | MPP Production Control / Quality | 🔶 Pending Customer Validation |
| **OI-06** | 4.2 | Session lifecycle: login on first action, 5-min timeout, re-badge for elevated actions | MPP Operations | 🔶 Pending Customer Validation |
| **OI-07** | 6.10 | Work order scope: included but hidden (MVP-lite, auto-generated, no WO screens) | MPP / Blue Ridge | 🔶 Pending Customer Validation |
| **OI-08** | 2.5 | Terminals: shared, machine barcode scan as first step, terminal as location type | MPP IT / Operations | ✅ Resolved |
| **OI-09** | 3.6 | Multi-part lines: one part at a time, operator selects LOT for consumption | MPP Engineering | ✅ Resolved |
| **OI-10** | — | Tool Life tracking: `LocationAttribute` vs. dedicated table (MVP per Scope Matrix row 26, FRS 5.6.6) | Blue Ridge / MPP Engineering | ⬜ Open |
