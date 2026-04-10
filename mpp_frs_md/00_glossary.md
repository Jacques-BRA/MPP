# Glossary

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.


---



## TABLE OF FIGURES


> ⚠️ **SPARK DEPENDENCY** — References SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively.


           Figure 1 Madison Plant Layout ................................................................................................................... 11
           Figure 2 Existing MES Landscape Block Diagram ........................................................................................ 12
           Figure 3 Generalized MPP Production Process ........................................................................................... 13
           Figure 4 Paper based Sample Part Quality Record ..................................................................................... 22
           Figure 5 Example LOT/Container Barcode Label ........................................................................................ 24
           Figure 6 LOT Tracking Ticket (LTT) .............................................................................................................. 29
           Figure 5-1 Future Spark MES Environment ................................................................................................. 57
           Figure 5-2 Expected Deployment Architecture .......................................................................................... 59
           Figure 5-3 - Standard Ignition Architecture ................................................................................................ 60
           Figure 5-4 - Ignition Reporting Module Sample .......................................................................................... 62


> 📝 **BLUE RIDGE NOTE** — Identify the equivalent capability in your stack before implementing.




## GLOSSARY


           The following is a glossary of terms used within this document.



            Term                       Definition



            AIM EDI                    AIM is a business application used mainly for EDI? **
                                       such as those using make to order and other related sales models.
                                       https://www.aimcom.com/edi-software/



            Basket                     A reusable device for collecting and moving parts within the factory (not used
                                       for shipping finished goods)



            BOM                        A bill of materials (BOM) is an extensive list of raw materials, components, and
                                       instructions required to construct, manufacture, or repair a product or service.
                                       A bill of materials usually appears in a hierarchical format, with the highest level
                                       displaying the finished product and the bottom level showing individual
                                       components and materials.



            Container                  A construct capable of containing a number of parts or finished goods. E.g.,
                                       part bins, shipping containers, etc.



            Finished Good              The final item being produced and shipped to a customer. AKA “End Item”



            Genealogy                  The records kept for a produced part that identifies all of the parts used to
                                       make the product and the history of all work don on each part used in the final
                                       assembled part.



            Heat                       A single mass of material produced from a furnace or melting facility with
                                       common metallurgical properties.



            HMI                        Human Machine Interface – graphical software used to help with controls of
                                       equipment and processes.



            Ingot/Pig                  A large single piece of Aluminum material that is charged into the melting
                                       process.



            Item                       A part or product used or manufactured at the site. The term applies for raw
                                       materials, component parts, sub-assemblies, finished goods, etc.



            LOT                        A collection of one or more product pieces tracked as a unit. For example, a
                                       group of 1000 Cam Covers with the same process history. AKA Parent LOT.



            LTT                        Lot Tracking Ticket



            Legacy MES                 Existing Manufacturing Director based MES solution – built on Windows
                                       Presentation Foundation and Microsoft .NET



            LOAD                       A collection of products being placed on an outbound truck when shipping
                                       materials.



            Macola ERP                 Enterprise Resource Planning software covering the areas of finance, HR,
                                       manufacturing, supply chain, services, procurement, and others. At its most
                                       basic level, ERP helps to efficiently manage all these processes in an integrated
                                       system. The ERP system is often referred to as the system of record of the
                                       organization.



            MES                        Manufacturing Execution System



            OEE                        Overall Equipment Effectiveness. A key metric that measures three primary
                                       aspects of production; Availability, Performance, and Quality.



            PD                         AKA “MPP Production Database” or Productivity Database – an MPP custom
                                       database application that support production, downtime, performance (OEE)
                                       and defect/Non-conformance tracking.



            PLC                        Programmable Logic Controller – an industrial computer system used to control
                                       and monitor devices and equipment.



            Production                 The Production Database (also known as the Productivity Database) is a local
            Database (PD)              application that store production data, manufacturing performance data,
                                       downtime durations/reasons and non-conformance data for Reporting
                                       purposes



            REST API                   A REST API (also known as RESTful API) is an application programming interface
                                       (API or web API) that conforms to the constraints of REST architectural style and
                                       allows for interaction with RESTful web services. REST stands for
                                       representational state transfer.



            SCADA                      Supervisory control and data acquisition (SCADA) is a control system
                                       architecture comprising computers, networked data communications and
                                       graphical user interfaces for high-level supervision of machines and processes.
                                       It also covers sensors and other devices, such as programmable logic
                                       controllers, which interface with process plant or machinery.



            Shipping                   Honda requires part specific dunnage/shipping containers that must be
            Container                  identified with a shipping label assigned by Honda.



> ⚠️ **SPARK DEPENDENCY** — References SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively.


            SparkMESTM                 A MES tool kit used to build MES solutions leveraging Inductive Automation’s
                                       Ignition Platform


> 📝 **BLUE RIDGE NOTE** — Identify the equivalent capability in your stack before implementing.



            SQL                        SQL stands for Structured Query Language which is basically a language used by
                                       Databases. This language allows to handle the information using tables and
                                       shows a language to query these tables and other objects related (views,
                                       functions, procedures, etc.).



            Sub LOT                    A portion of a LOT being tracked separately but maintaining its relationship with
                                       the original (parent) LOT. AKA Child LOT.



            WIP                        Work-in-progress (WIP) is a production and supply-chain management term
                                       describing partially finished goods awaiting completion.


