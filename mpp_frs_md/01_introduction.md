# Section 1 — Introduction

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.


---


> ⚠️ **SPARK DEPENDENCY** — References SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively.


           1 I N TRODU CTION
           Madison Precision Products, Inc. (MPP) provides Die Cast Aluminum products used primarily in the auto
           industry, most often for Honda. The facility is located in Madison, Indiana.
           MPP will be replacing the legacy MES solution with a modern MES built on current technology improving
           its long-term viability and supportability. The new solution will incorporate Inductive Automation’s
           Ignition software which provides SCADA capabilities and is the foundation upon which FWI’s
           SparkMESTM solution is built. FWI’s SparkMESTM will be configured and customized as necessary to
           replicate the current MES solutions behavior and support the functional requirements specified in the
           following sections of this document.
           This Functional Requirements Specification document (FRS) will target the following objectives:
                1) Document the current MES solution capabilities that must be retained.
                2) Document desired MES enhancements and additional requirements that MPP identifies.
                3) Identify and evaluate MES Integration opportunities to eliminate manual information entry into
                   multiple systems.
                4) Identify and evaluate MES Integration opportunities to integrate/replace other legacy
                   applications. (e.g. The current Productivity database which houses the downtime and
                   performance analysis data repository.)
                5) Add Scada features including:
                   a) Process data collection.
                   b) Time based sample data historian.
                   c) Additional dashboard displays.
                6) Provide budgetary estimates for the replacement SparkMES TM based solution.
                7) Provide a high-level transition plan and schedule.


> 📝 **BLUE RIDGE NOTE** — Identify the equivalent capability in your stack before implementing.


