# MPP MES — Spark Dependency Register
**For:** Blue Ridge Automation (Internal Use)  
**Based On:** MPP MES FRS v1.0 (Flexware, 3/15/2024)  
**Purpose:** Identify every place where the FRS assumes SparkMES™ framework capabilities, and map each to a Blue Ridge design decision.

---

## How to Use This Document

This register separates three distinct categories:

| Category | Meaning |
|---|---|
| **Direct Dependency** | A numbered requirement in Section 3 explicitly names SparkMES or Flexware. These must be re-specified. |
| **Architectural Dependency** | A capability that Spark provides as a built-in platform feature. The FRS assumes it will "just work." Blue Ridge must build or configure an equivalent. |
| **Platform-Agnostic** | Requirements that describe *what* the system does — not *how* Spark does it. These can be implemented directly. |

The numbered requirements (146 total in Section 3) are largely **platform-agnostic**. The Spark coupling is mostly architectural — living in the platform layer underneath those requirements. That's actually good news: the requirements are implementable. The work is in designing the platform features Spark would have provided.

---

## Part A — Direct Spark Dependencies (Section 3)

These are numbered requirements that explicitly reference SparkMES or Flexware. They must be restated for Blue Ridge's stack.

| Req ID | Subsection | Original Requirement | Spark Assumption | Blue Ridge Restatement |
|---|---|---|---|---|
| **3.1.4** | GENERAL | Master Data shall be manually entered into SparkMES™. ◊ | Spark has a built-in Master Data management UI and configuration framework. | Blue Ridge will provide Master Data management screens in Perspective. Define which entities constitute Master Data (parts, locations, routes, downtime codes, etc.) and build corresponding admin UIs. |
| **3.1.6** | GENERAL | The SQL Server instance hosting the SparkMES™ Database shall be Microsoft SQL Server 2022 Standard Edition. | Spark has a defined, versioned database schema bundled with the framework. | Blue Ridge will own the full database schema. SQL Server 2022 Standard Edition target is **retained** — no change to the infrastructure spec. Schema design is a Blue Ridge deliverable. |
| **3.3.1** | SECURITY | The new Spark MES will rely upon a mixed security model consisting of access to Active Directory (AD) and to a local Ignition user source for maintenance of clock numbers and PINs. | Spark's security module integrates AD roles with Ignition's internal user source and surfaces this as role-based screen/function access plus audit logging. | Blue Ridge will implement the same hybrid model natively in Ignition: AD for employee authentication + Ignition User Source for clock number / PIN management. Role mapping and audit logging are custom implementations. See also 3.3.x requirements for detail. |

> **📝 BLUE RIDGE NOTE — 3.1.4:** The ◊ symbol on 3.1.4 means MPP is responsible for Master Data entry, not the integrator. The requirement is about providing the UI for them to do so — not about who populates it.

---

## Part B — Architectural Spark Dependencies

These are platform capabilities that Spark provides as built-ins. They are not called out by requirement ID — they are simply *assumed* to exist because Spark is the platform. Each one represents a design decision for Blue Ridge.

Section 5.3 of the FRS describes 15 capabilities the Spark framework provides. Each is mapped below.

---

### B.1 — Plant Physical Model

**What Spark provides:** A configurable plant model with attributes per location, data requirements, and quality observations. Operators are presented with location-appropriate UIs automatically.

**FRS References:** Section 5.3 (SparkMES Framework), Section 3 — PLANT MODEL (reqs 3.6.x), Section 2.1 (process flow)

**Blue Ridge Approach:**
> _Design decision needed. Suggested: ISA-95 Location Model (Enterprise → Site → Area → Work Center → Work Unit) implemented as a database table hierarchy. Each work center/unit carries its own config (part association, operation type, downtime codes, etc.). Perspective screens load context dynamically based on the logged-in terminal's assigned location._

---

### B.2 — LOT Tracking, Inventory Management & Material Management

**What Spark provides:** Core tracking of LOTs, Sub-LOTs, containers, and piece counts through the full manufacturing flow. Split/merge operations. LOT quality status (GOOD → HOLD → SCRAP → CLOSED).

**FRS References:** Section 2.2 (LOT/Container/Piece Tracking), Section 3 — INVENTORY, LOT TRACKING AND GENEALOGY (reqs 3.8.x, 3.9.x), Appendix J (Base2 data model)

**Blue Ridge Approach:**
> _Design decision needed. Core data entities: LOT, SubLot, Container, LotStatusHistory, LotSplitEvent. Ledger-first pattern recommended — all state changes recorded as immutable events with current state derived. This is the most complex domain model in the system._

---

### B.3 — Product Definition & BOM Management

**What Spark provides:** Item/part definition, BOM hierarchy (Finished Good → Assembly → Component → Raw Material), and part-to-operation mapping for routing.

**FRS References:** Section 3 — MASTER DATA (reqs 3.5.x), Section 3 — ROUTING AND OPERATIONS (reqs 3.10.x)

**Blue Ridge Approach:**
> _Design decision needed. Minimum viable: Item master + BOM table + Route template. Complexity depends on whether Blue Ridge needs to handle multi-level BOMs or only the flat part-to-LOT association MPP currently uses._

---

### B.4 — Manufacturing Route Planning

**What Spark provides:** Route templates defining the sequence of operations for each product. Runtime routing enforces the sequence and tracks completion.

**FRS References:** Section 3 — ROUTING AND OPERATIONS (reqs 3.10.x), Section 2.1 (process flow by station type)

**Blue Ridge Approach:**
> _Design decision needed. MPP's process is largely fixed (Die Cast → Trim → Machining → Assembly → Delivery) with line-specific variations. A route template table referencing ordered work center steps is likely sufficient. Dynamic routing may not be required for MVP._

---

### B.5 — Work Order Execution (Auto-Generated)

**What Spark provides:** Self-generated work order context that operators never see or interact with. WOs are created internally by Spark when production activity is triggered, providing context for production and consumption tracking.

**FRS References:** Req 3.1.5 ("MES may leverage self-generated work orders, if necessary, behind the scenes"), Section 3 — WORK ORDER CONTEXT, PRODUCTION AND CONSUMPTION TRACKING, Section 5 prose ("SparkMES™ will create any required WO context internally without operator interaction")

**Blue Ridge Approach:**
> _Design decision needed. Since operators never interact with WOs (req 3.1.5), this is an internal bookkeeping mechanism. Recommended: implicit production context record created when a LOT is started at an operation, linked to the part number and route step. No formal "Work Order" UI needed for MVP — model it as a ProductionEvent or OperationRecord._

---

### B.6 — Product Genealogy & Traceability

**What Spark provides:** Complete genealogy from incoming raw material to outgoing finished good. Parent LOT → Sub-LOT → serialized part linkages. Maintained through all split/merge/assembly operations.

**FRS References:** Section 2.1.7 (Part Serialization), Section 3 — INVENTORY, LOT TRACKING AND GENEALOGY (reqs 3.8.x), Section 2.2.5 (LOT/Sub-LOT in Machining and Assembly), Appendix J (Base2 genealogy tables)

**Blue Ridge Approach:**
> _Design decision needed. Critical requirement for MPP. Must support: LOT-to-LOT parent-child (split operations), LOT-to-serialized-part (assembly), and container-to-LOT links. A LotGenealogy edge table (parent_lot_id → child_lot_id, relationship_type, timestamp) is the recommended pattern. Must be queryable in both directions._

---

### B.7 — Browser-Based Operator UI

**What Spark provides:** Perspective-based web UI automatically served to any modern browser. Responsive to device type (PC, tablet, phone). Location-context-aware.

**FRS References:** Req 3.1.2 (Perspective), Section 5.2.2 (Perspective Visualization), Section 5.4 (UI Devices)

**Blue Ridge Approach:**
> _No design gap — Blue Ridge uses Ignition Perspective natively. This is a direct platform match._  
> **ACTION:** Confirm Ignition license tier includes Perspective module for target gateway.

---

### B.8 — Role-Based Access Control

**What Spark provides:** Screen-level and function-level access control based on AD security groups and Ignition roles. Also used for audit trail attribution.

**FRS References:** Req 3.3.1, Section 3 — SECURITY (reqs 3.3.x), Section 5 (SparkMES security model)

**Blue Ridge Approach:**
> _Design decision needed. Define the role matrix: which roles (Operator, Supervisor, Quality, Maintenance, Admin) map to which screens and actions. Implement via Ignition's security zones + role-based tag/component permissions. AD group → Ignition role mapping in gateway config._

---

### B.9 — Work Instructions Delivery

**What Spark provides:** Contextual work instructions surfaced to the operator at each station based on the current operation.

**FRS References:** Section 5 (Spark feature list item 9), Section 3 — USER INTERFACE (SCREENS, DASHBOARDS, REPORTS)

**Blue Ridge Approach:**
> _Scope to be confirmed. FRS does not define detailed WI requirements. MPP may have existing WI documents (PDF/paper). Minimum viable: a Perspective component that displays a linked document or image per operation. Full WI management system is a likely future enhancement._

---

### B.10 — Process Data Capture (Auto & Manual)

**What Spark provides:** PLC/OPC tag reads stored as process data against production events. Manual data entry by operators at stations.

**FRS References:** Section 2.1.8 (Inspection — camera pass/fail via OPC), Section 2.3.2 (PLC Interface), Section 3 — PERFORMANCE AND DOWNTIME DATA COLLECTION, Section 5.5.1 (Process Control Equipment Interface)

**Blue Ridge Approach:**
> _Partially platform-native. OPC UA / direct Ethernet tags via Ignition's built-in device drivers. Manual operator entries via Perspective forms. The design work is: defining which tags map to which production events, and how process data records are structured in the database._

---

### B.11 — User Tracking & Audit Logging

**What Spark provides:** Timestamped log of user actions (who did what, from which terminal, when). Used for audit trails and time study support.

**FRS References:** Section 3 — LOGGING (reqs 3.14.x), Section 5 (Spark feature list items 11, 12)

**Blue Ridge Approach:**
> _Design decision needed. Implement an AuditLog table: user_id, terminal_id, action_type, entity_type, entity_id, old_value, new_value, timestamp. Populate via server-side script hooks on all state-changing operations. Do not rely on client-side logging._

---

### B.12 — Timestamped Event Logging

**What Spark provides:** The FWI Event Manager (EM) — a structured event dispatch and logging system. Events are defined, fired, queued, and processed asynchronously. Used for time study, diagnostics, and integration triggers.

**FRS References:** Appendix G (FWI Event Manager full spec), Appendix K (EM Core Routines), Section 5 (Spark feature list item 12)

**Blue Ridge Approach:**
> _This is the most significant architectural gap. The EM is a Spark-native message bus. Blue Ridge's equivalent options:_
> - _**Recommended:** Custom event outbox table + background worker (Gateway Scheduled Script or .NET service) for asynchronous processing. Simpler to reason about, inspectable in SQL._
> - _**Alternative:** SignalR hub for real-time event dispatch to connected clients, paired with a persisted event log table._
> _Read Appendix G carefully before designing. The EM handles state transitions, integration triggers, and async side-effects — this pattern must be replicated._

---

### B.13 — Non-Conformance & Rework Routing

**What Spark provides:** Configurable routing plans for non-conforming parts. Data capture for defect type, disposition, and rework actions. Tied to LOT quality status.

**FRS References:** Section 2.1.9 (QC Sampling and No-Good Parts), Section 4 (No-Good Part Handling Process), Section 3 — QUALITY (reqs 3.16.x), Section 5.6.3 (Future: NonConformance Management)

**Blue Ridge Approach:**
> _Design decision needed. Note that Section 5.6.3 lists "NonConformance Management and Failure Analysis" as a **future enhancement**, not MVP scope. MVP may only require: LOT quality status transitions (GOOD → HOLD → SCRAP/CLOSED) + a basic defect code entry form. Full NC workflow is post-MVP._

---

### B.14 — Downtime Event Capture & Analysis

**What Spark provides:** Downtime reason code entry (manual and automated), duration tracking per machine/line, OEE calculation, and reporting.

**FRS References:** Section 3 — PERFORMANCE AND DOWNTIME DATA COLLECTION (reqs 3.13.x), Appendix D (Downtime Reason Codes)

**Blue Ridge Approach:**
> _Design decision needed. Core entities: DowntimeEvent (machine_id, start_time, end_time, reason_code_id, operator_id). OEE = Availability × Performance × Quality, calculated per shift/line. The MPP Production Database (PD) currently handles this — see Appendix F. Determine if Blue Ridge absorbs this into MES or integrates with the existing PD._

---

### B.15 — Historization via Ignition Tag Historian

**What Spark provides:** Time-series historian for OEE trends, production counts, and process data. Leverages Ignition's Tag Historian module. Data preserved across system upgrades.

**FRS References:** Req 3.12.x (Historization and Legacy MES Data Preservation), Section 5.2.4 (Tag Historian Module), Section 5 prose ("FWI will investigate the possibility of porting legacy data")

**Blue Ridge Approach:**
> _Partially platform-native. Ignition's Tag Historian handles time-series data natively — no custom design needed for new data. The open question is **legacy MES data migration** (req 3.12.x). The existing Manufacturing Director database has production history MPP may want preserved. Define migration scope with MPP before committing to an approach._

---

## Part C — Platform-Agnostic Capabilities (No Spark Design Gap)

These capabilities are described in the FRS without any Spark coupling. Blue Ridge can implement them directly against the requirements.

| Capability Area | Section 3 Subsection | Req Count | Notes |
|---|---|---|---|
| General Infrastructure | GENERAL (non-Spark reqs) | 5 | 3.1.1 (Ignition base), 3.1.2 (Perspective), 3.1.3 (SQL Server), 3.1.5 (no operator WO interaction), 3.1.7 (transaction logging) |
| Server Hardware | SERVER AND OPERATIONS EQUIPMENT | 1 | Hardware specs. Carry forward from Section 5.1 |
| UI General Standards | USER INTERFACE (GENERAL) | Many | Screen layout, color, navigation, branding standards |
| UI Screens & Reports | USER INTERFACE (SCREENS, DASHBOARDS, REPORTS) | Many | Specific screen definitions and report formats |
| Inventory Mgmt / Receiving / Shipping | INVENTORY MANAGEMENT, RECEIVING, AND SHIPPING | Many | Receiving, container creation, shipping label, AIM interface |
| Work Order Scheduling | WORK ORDER SCHEDULING | 6 | Production schedule display. No Spark coupling. |
| Reporting & Barcode Printing | REPORTING & BAR CODE PRINTING | Many | ZPL label printing, Ignition Reporting module |
| Quality Data Entry | QUALITY | Many | Sample recording, quality status, test results |
| Logging | LOGGING | 4 | Req 3.14.x — transaction logging detail |

---

## Part D — Key Cross-References for Design Work

When designing Blue Ridge's platform architecture, these FRS sections are the most critical reads:

| What you're designing | Primary FRS Reference | Notes |
|---|---|---|
| LOT data model | Section 2.2 + Appendix J (Base2) | Appendix J shows Spark's actual DB schema. Use as inspiration, not as-is. |
| Event/async processing | Appendix G (FWI Event Manager) | Read the full 29-page spec. This is what you're replacing. |
| Security model | Req 3.3.x + Section 5.3 (security description) | AD + Ignition hybrid. Role matrix must be defined with MPP. |
| PLC integration | Appendix C (OPC tags) + Section 2.3.2 | Existing tag names and PLC interface patterns. |
| AIM integration | Appendix L (AIM Interface) + Section 2.3.1 | Honda supply chain EDI. Critical for shipping. |
| Barcode label format | Section 2.1.11 + existing ZPL files | MPP has existing ZPL configs. Reuse them. |
| Plant model / location hierarchy | Section 2.1 (all subsections) + Appendix B | Full location list. Use as input to ISA-95 location model config. |

---

## Summary Scorecard

| | Count | Notes |
|---|---|---|
| Total Section 3 requirements | 146 | |
| Directly Spark-coupled (explicit keyword) | 3 | Restated in Part A |
| Architectural platform gaps to design | 15 | Addressed in Part B |
| Platform-agnostic requirements | ~138 | Implementable directly |
| Entire sections that are Spark-only | 4 | Section 5, Appendix G, J, K — reference only |
| Blue Ridge design decisions outstanding | **15** | One per Part B item |

---

*Generated by Blue Ridge Automation for internal development planning. Source document proprietary to Flexware Innovation / Madison Precision Products.*
