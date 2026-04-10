# MPP FRS — Annotated Markdown Reference

**Document:** Madison Precision Products MES — Functional Requirement Specification  
**Original Author:** Isaac Bennett, Flexware Innovation  
**Original Version:** 1.0, dated 3/15/2024  
**Converted by:** Blue Ridge Automation for internal reference use  

---

## ⚠️ Important Context

This FRS was written by Flexware Innovation for their **SparkMES™** framework, which Blue Ridge Automation does not have access to. This document is being used as a **requirements reference only** — it describes *what* the system needs to do, not *how* Blue Ridge will implement it.

Throughout these files, two annotation types identify areas requiring attention:

| Annotation | Meaning |
|---|---|
| `⚠️ SPARK DEPENDENCY` | Requirement explicitly references SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively. |
| `📝 BLUE RIDGE NOTE` | Flags where a design decision is needed before implementation can begin. |

Sections 5, Appendix G, J, and K are flagged at the **section level** — the entire content is Spark-framework-specific and should be read for architectural intent only.

---

## File Index

### Core Sections

| File | Contents | Spark Flags | Notes |
|---|---|---|---|
| `00_glossary.md` | Term definitions used throughout the FRS | 2 | Reference first — establishes LOT, LTT, Container, Heat, etc. |
| `01_introduction.md` | Project background and scope | 1 | Short. Good orientation read. |
| `02_process_overview.md` | Full plant process flow — Die Cast → Trim → Machining → Assembly → Delivery | 0 | **Most important for domain understanding.** Covers LOT tracking, Sort Cage, AIM integration, PLC interface. |
| `03_mes_functional_requirements.md` | All numbered MES requirements (3.x.x) | 6 | **Primary development reference.** 18 subsections covering UI, security, inventory, lot tracking, routing, scheduling, quality, logging. |
| `04_no_good_part_handling.md` | No-good/reject part process definition | 0 | Short but important for quality workflow design. |
| `05_spark_technical_overview.md` | Flexware's SparkMES architecture, deployment topology, Ignition modules | ⚠️ WHOLE SECTION | **Read for intent only.** Describes what Spark provides — useful for understanding target architecture but none of it applies to Blue Ridge's stack directly. |
| `06_deployment_plan.md` | MVP scope, phasing, FAT/commissioning plan | 4 | Relevant for project planning. MVP list gives a useful priority stack. |

### Appendices

| File | Contents | Notes |
|---|---|---|
| `appendix_a_architecture.md` | Current legacy MES architecture (Manufacturing Director / WPF) | Baseline state. Shows current PLC integration patterns and barcode flows. |
| `appendix_b_machines.md` | Machine list by product line with operation codes | Critical for plant model config. Maps lines → machines → operations. |
| `appendix_c_opc_tags.md` | OPC tag list from PLCs | Reference for PLC integration design. Tag names, types, addresses. |
| `appendix_d_downtime_codes.md` | Downtime reason code list by line | Needed for downtime/OEE module config. |
| `appendix_e_defect_codes.md` | Defect/reject reason codes | Needed for quality and non-conformance module config. |
| `appendix_f_productivity_db.md` | MPP's existing Productivity Database (PD) UI description | Context on what reporting MPP currently has. |
| `appendix_g_fwi_event_manager.md` | Flexware's Event Manager (EM) framework — full spec | ⚠️ SPARK SECTION — Read for design intent. EM is a Spark-native event dispatch system. Blue Ridge will need an equivalent (SignalR / custom event bus). |
| `appendix_h_legacy_ui_screens.md` | Legacy MES screen grab descriptions | Low value for new development. Reference for UX expectations. |
| `appendix_i_work_instructions.md` | Legacy MES operator work instructions | Reference for operator workflow requirements. |
| `appendix_j_mes_base2.md` | MES Base2 core routines (Spark framework internals) | ⚠️ SPARK SECTION — Internal Spark SQL/logic patterns. Study for data model insight, not for implementation. |
| `appendix_k_mes_em_routines.md` | Event Manager core routines | ⚠️ SPARK SECTION — Spark-internal. Reference only. |
| `appendix_l_aim_interface.md` | AIM EDI system integration spec | Needed for Honda supply chain / shipping label integration. |
| `appendix_m_mes_reports.md` | Report list and descriptions | Reference for reporting module scope. |
| `appendix_n_macola.md` | Macola ERP physical inventory (MRO) | Background context on ERP integration. Low priority for MVP. |

---

## Recommended Reading Order

For getting up to speed quickly:

1. `00_glossary.md` — know the vocabulary first
2. `02_process_overview.md` — understand the full plant process
3. `03_mes_functional_requirements.md` — the actual requirements
4. `06_deployment_plan.md` — MVP scope and phasing
5. `05_spark_technical_overview.md` — architecture intent (Spark-specific, read critically)

For PLC/integration work:
- `appendix_c_opc_tags.md` + `appendix_l_aim_interface.md`

For plant model configuration:
- `appendix_b_machines.md` + `appendix_d_downtime_codes.md` + `appendix_e_defect_codes.md`

---

## How to Use These Files in Chat

Drop any single file into a conversation to query it in context. Example prompts:

- *"Based on section 2.2, how should I model the LOT/Sub-LOT relationship in my database schema?"*
- *"In 03_mes_functional_requirements, which requirements under INVENTORY AND LOT TRACKING are Spark-coupled vs. platform-agnostic?"*
- *"Walk me through what the Sort Cage process requires from MES — what state transitions need to be tracked?"*
- *"Given that I'm building on .NET/ASP.NET Core + Ignition + SignalR, how would I replicate the Event Manager pattern described in Appendix G?"*

---

*This reference collection was generated by Blue Ridge Automation for internal development use. The source document remains proprietary to Flexware Innovation / Madison Precision Products.*
