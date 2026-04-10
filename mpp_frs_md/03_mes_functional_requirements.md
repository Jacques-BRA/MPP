# Section 3 — MES Functional Requirements

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.


---


> ⚠️ **SPARK DEPENDENCY** — References SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively.


           3 MES F UN CTION A L R E QUIR EME NT S
           This section identifies the major requirements needed by the proposed MES solution. These
           requirements are based on the existing MES solution capabilities and behaviors, and additional
           requirements for a new SparkMESTM based replacement the leverages the Inductive Automation Ignition
           platform.
           Items marked with a ◊ represent requirements that are handled by MPP.


> 📝 **BLUE RIDGE NOTE** — Identify the equivalent capability in your stack before implementing.




## GENERAL


           General requirements are as follows:



                 ID        Requirement



            3.1.1          The new MES will rely upon Ignition as the basis for all its supporting applications.



            3.1.2          User interface displays shall be developed in Perspective (web-browser HTML5 based).



            3.1.3          Microsoft Sql Server shall be the database engine used by the application.



> ⚠️ **SPARK DEPENDENCY** — This requirement references SparkMES or Flexware-specific functionality.


            3.1.4          Master Data shall be manually entered into SparkMESTM. ◊


> 📝 **BLUE RIDGE NOTE** — Determine the equivalent implementation in your stack.


            3.1.5          Formal work orders are not being used by MPP and operators should not be required to
                           log in or out of work orders to start/complete, or report production. MES may leverage
                           self-generated work orders, if necessary, behind the scenes to provide context to
                           production activity.



> ⚠️ **SPARK DEPENDENCY** — This requirement references SparkMES or Flexware-specific functionality.


            3.1.6          The SQL Server instance hosting the SparkMESTM Database shall be Microsoft SQL Server


> 📝 **BLUE RIDGE NOTE** — Determine the equivalent implementation in your stack.


                           2022 Standard Edition



            3.1.7          MES must maintain a log of data transactions, process events, operator actions, etc. to
                           support diagnostic and reporting use cases.




## SERVER AND OPERATIONS EQUIPMENT


           The following are equipment/computer requirements.



                 ID        Requirement



            3.2.1          A SQL Server Database (Windows Server 2019 or newer) will be required. Microsoft SQL
                           Server Standard Edition will be required as a minimum. ◊



            3.2.2          Windows Server 2019 Standard Edition (or higher) will be required for the Ignition
                           Gateway as a minimum. ◊



            3.2.3          2D Barcode Scanners shall be used that can be connected to PCs or thin clients and act as
                           a keyboard wedge for scanning of material barcode tags. ◊



            3.2.4          Barcode label printers will be provided and configured by MPP. ◊



            3.2.5          Dedicated Barcode readers, Optical Character Recognition, or Radio Frequency
                           Identification devices will be accessed via Ignition Tags using supported protocols or
                           through a REST API to a Web Service.




## SECURITY


           The following are security requirements for the application.



                 ID        Requirement



> ⚠️ **SPARK DEPENDENCY** — This requirement references SparkMES or Flexware-specific functionality.


            3.3.1          The new Spark MES will rely upon a mixed security model consisting of access to Active


> 📝 **BLUE RIDGE NOTE** — Determine the equivalent implementation in your stack.


                           Directory (AD) and to a local Ignition user source for maintenance of clock numbers and
                           PINs.



            3.3.2          Access to the Ignition Gateway configuration & status pages shall be governed by use of
                           AD accounts and their assigned roles within AD.



            3.3.3          Access to the Ignition Designer and the projects maintained by it shall be governed by AD
                           account and role assignments.



            3.3.4          MES will support role-based access to MES screens and features and the ability to
                           manage user/role assignments.



            3.3.5



                      USER INTERFACE (GENERAL)
           Ignition’s Perspective Module will be the foundation for developing the user interface. All efforts will be
           made to provide a user interface that is intuitive in nature. Being a web-based UI there may be some
           aspects of the UI that might be implemented differently than was done on the older character cell UI.
           The Perspective based UI will be available to appropriately authorized users from any device supporting
           a “Modern” Web Client that has access to the Ignition Gateway web services. A modern web client is
           any of the following browsers:



                    Microsoft Edge
                    Firefox
                    Google Chrome
                    Safari
                    Opera
                    Mozilla
           Perspective supports different types of portable interfaces including tablets and smart phones. For this
           project, perspective screens will be designed around the expected user interface size and resolution, but
           with an awareness of the potential viewability on other devices. This replacement project is focused on
           like for like, so specific tablet or smart phone screen designs are not required but may be added in a
           future upgrade.
           The following are requirements for the HMI application interfaces that must be provided.



            Reference          Description



            3.4.1              Screens shall be generated using Perspective in HTML5.



            3.4.2              Screens will be designed for standard monitors on the shop floor and will use an
                               agreed upon aspect ratio and resolution to be determined early in the project.



            3.4.3              Screens will be viewable via Cell phone or tablets, but will not be required to be
                               designed specifically to these form factors.



            3.4.4              An audit logging facility is to be provided which allows recording of all events occurring
                               in MES. Audit log entries must contain the following items of data related to the entry
                               as a minimum.
                                          Date/Time Stamp of the entry including time zone
                                          User associated with the entry (logged in user or service account)
                                          UI station the user was logged into when applicable
                                          Operation/Machine related to the event when applicable
                                          Entry severity (Error, Warning, Informational)
                                          Descriptive message text



            3.4.5              A SQL Server database will contain item master data for the MES Application. MES will
                               have the ability to add and edit Item master data.



            3.4.6              Item master data will include information such as:
                                          Part number
                                          Part Description
                                          Bill of Material (BOM) for Produced End Items
                                          Cost centers
                                          Departments
                                          Work Centers
                                          Warehouses (Locations)
                                          Machine Numbers
                                          Units of Measure
                                          Work Order Status Codes
                                          Operation Codes
                                          Item Types
                                          Application Users
                                          User Roles
                                          Alarm Types
                                          There may be other base data needed that will become apparent during
                                           implementation



            3.4.7              The system must maintain a collection of quality items for quality data collection
                               points throughout the facility.



            3.4.8              The system will include a general alarm display screen that integrates with the
                               standard Ignition alarm facilities and supports traditional Ack and shelving capabilities.
                               {Direct process measurement data tags may not be implemented until a future
                               project}



            3.4.9              Tags will be configured as alarming using the Ignition alarm configuration where
                               appropriate.



            3.4.10             The system will include configuration of Ignitions Historian components and a general
                               trend screen will be provided for viewing time-based historian data.



            3.4.11             MES shall be constructed to restrict access to screens and functionality based upon
                               roles assigned to users. Only users possessing the appropriate required roles will be
                               allowed access to MES functionality via the UI.



                     USER INTERFACE (SCREENS, DASHBOARDS, REPORTS)
           This section covers the general structure of the user interface screens provided to the MPP user
           community.



                    ID         Description



            3.5.1              MES UI will provide a panel containing the common components for all the user
                               interface screens. These components would support operator data viewing and entry
                               of:
                                          Production Downtime events (if configured)
                                          Production Recording (count confirmation)
                                          Report Rejects (No-Good part)
                                          Print/re-print Barcode Tag/Label
                                          Material/Lot creation and Transfer/movement
                               These may be presented as tabs or other mechanism to isolate the functionality



            3.5.2              The MES UI will provide visibility of a variety of operational data and functions that are
                               common across all production areas and machine types providing the following
                               location/operation relevant types of operations data.
                                          LOT number
                                          LOT Status
                                          Current Part Number
                                          LOT/Operational History
                                          Available LOT Inventory
                                          Machine Number
                                          Serial number (where appropriate)
                                          Downtime/Delay History
                                          Current User
                                          Screen Exit (Back)



            3.5.3              The MES will provide a Production Recording UI screen which is specific to the needs of
                               each “unique” operation/machine type which allows for user entry of required
                               production information.
                               NOTE: Operations requiring material ID verification must not allow the operation to be
                               started until these entries have been confirmed.



            3.5.4              Each Production Recording screen will provide the user with the following
                               order/material based general information.
                                          Date/Time/Shift Indications
                                          Machine identification
                                          Part Number
                                          LOT number
                                          Die Number
                                          Cavity Number
                                          Good count/no good count
                                          Logged in user identification.



            3.5.5              The MES Production Recording screens must provide capability for the following
                               functions to be carried out.
                                          Screen Exit (Back)
                                          Completion of processing for a LOT
                                          Good Count entry
                                          Bad Count entry
                                          Reject/Non-conformance reporting.
                                          Material identification verification (when required)
                                          Machine/die/cavity information (when appropriate)
                                          Quality Sample Instruction viewing
                                          Remaining processes/operations viewing.
                                          Reviewing completed operations/history



            3.5.6              The MES Production Recording screens must present data and accept data as
                               configured in the MES operation Template for the operation currently active at any
                               station. For example, an assembly operation template will be configured to accept.
                                          Material ID Verification
                                          Good Count
                                          Bad Count
                                          Reject /Non-conformance Reason
                                          Machine
                                          Die
                                          Cavity
                                          Remarks entry



            3.5.7                  An Inventory LOT maintenance screen will allow operators to:
                                          Create new material LOTs
                                          Enter/update LOT piece counts (requires appropriate use Rights/Roles)
                                          Enter/update LOT weight (requires appropriate use Rights/Roles)
                                          Place LOTs on quality hold
                                          Remove quality Hold conditions from LOTs (requires appropriate use
                                           Rights/Roles)
                                          Move LOTs from one inventory location to another
                                          Receive material into inventory location
                                          Ship /Packout Material LOTs
                                          Create Shipping Containers
                                          Assign Materials to Shipping Containers
                                          Request Shipping Container IDs from AIM system
                                          Print Labels for LOTs
                                          Print Labels for shipping Containers
                                          Record Serial number ranges for LOTs
                                   Record individual Serial numbers to Parts in LOTs or Containers.



            3.5.8              The MES User Interface will support the creation of dashboards and graphical displays;
                               however, at this time there are no requirements for graphical (SCADA) or machine
                               control screens. MES must support the eventual creation of such screens when future
                               automation upgrades are brought online.



            3.5.9              MES will include an inventory display screen that allows operations to determine
                               where LOTs currently reside (recognizing that material waiting for the completion of a
                               transfer operation may have an ambiguous location)



            3.5.10             MES Data Reporting screens will support Reporting via data exports to PDF or MS Excel
                               files.



            3.5.11             MES UI Menus must be extensible to provide access to customer developed screens
                               and dashboards.



            3.5.12             MES will expose a means of implementing Roles Based access controls to the screen
                               features and a means of defining Roles and associating users to those roles.



            3.5.13             Input of item serial numbers, part numbers, LOT numbers, etc. will normally be
                               acquired by scanning barcodes that provide the necessary details. In the event a
                               barcode cannot be scanned, manual entry must be allowed. Drop Down Lists will be
                               used where needed to limit data entry to a specific set of available options.



            3.5.14             MES data may be surfaced by through Microsoft SQL Server Reporting Services report
                               or a Business intelligence tool; however, report requirements have not been provided
                               at this time. MPP will be responsible for mapping existing reports to the MES data
                               exports for reporting. ◊



            3.5.15




## MASTER DATA


           MES will support all required master data locally. Eventually, master data may be retrieved from
           external systems.



                 ID        Requirement



            3.6.1          Part Data shall be manually entered into MES or entered via CSV/Spreadsheet



            3.6.2          Product Definitions shall be manually created in MES or entered via CSV/Spreadsheet



            3.6.3          Part/product attributes must include a default Sub-Lot Quantity identifying the typical
                           number of parts that are split into a single Sub-Lot



            3.6.4          A Part attribute will be used to hold the associated Macola part number.
                           [note Macola parts have base part number which is 3 characters in length. Macola
                           appends a -a 3 digit number to the base part number to indicate the state of
                           manufacturing, or a 3 character code representing the customer for a finished good.]



            3.6.5          Product Bill of Materials shall be manually created in MES or entered via
                           CSV/Spreadsheet



            3.6.6          Master data for each product includes the following shipping container configuration
                           data
                                      how many trays in a container,
                                      how many products in a tray
                                      are the trays serialized
                                      etc.



            3.6.7          Production Route shall be manually created in MES



            3.6.8          A Plant Model shall be manually created In MES and will include:
                           Plant, Area, Line, Machine, and logical Inventory Locations



            3.6.9          The MPP Plant model will support creating a logical representation of off-site inventory
                           locations



            3.6.10         Downtime reason codes will be manually configured in MES



            3.6.11         Non-conformance quality dispositions will be manually configured in MES




## PLANT MODEL


           MES will support defining a plant model to assist in organizing work flow routing, data collection,
           machine performance, and inventory locations.



                 ID        Requirement



            3.7.1          MES shall include a configurable plant model that supports an ISA S95 hierarchical model
                           for locations, areas, lines, machines, etc.



            3.7.2          Plant model objects (e.g. lines, Machines etc.) will have configurable attributes that will
                           be defined as needed to support the overall requirements. It is presumed that this will
                           include support for:
                                      Product/Part to Line mapping/constraints
                                      Incoming LOT staging area queue depth
                                      Nominal cycle time
                                      Etc.



            3.7.3



                      INVENTORY MANAGEMENT, RECEIVING, AND SHIPPING
           MES will maintain an inventory state reflecting the presumed location of all LOTS that MES is aware of.



                 ID        Requirement



            3.8.1          MES shall support an Inventory model that includes theoretical/non-physical locations



            3.8.2          MES shall maintain an inventory model that correlates to the physical inventory locations
                           in the plant (site, area, line, etc.) at the level of specificity that is required to support
                           tracking without requiring an unnecessary burden on operations.



            3.8.3          The MES Inventory model shall support Lineside staging/storage at each operation.



            3.8.4          MES receiving of material at MPP shall allow printing of bar-coded tags for identification
                           of the incoming LOT/parts.



            3.8.5          MES shall track materials in inventory as the operators report production or the
                           movement of LOTs through the process – Note that the inventory location may be logical
                           and may span multiple physical areas of the plant.



            3.8.6          MES shall support tracking the movement of LOTs using fixed or handheld Barcode
                           readers, RFID tag readers, etc. that may become available over time.



            3.8.7          MES Inventory screens shall support locating LOTs in Inventory by LOT ID, Part number,
                           inventory Location, and/or Material characteristic.



            3.8.8          Inventory Movements logs shall include timestamps of when the movement occurred



            3.8.9          Inventory Movements logs shall include user identification who entered the movement



            3.8.10         Changes in LOT attributes (LOT weight, quantity, etc.) shall be logged and available for
                           reporting.



            3.8.11



                     INVENTORY, LOT TRACKING AND GENEALOGY
           This section covers requirements pertaining to material inventory management throughout its life at the
           MPP facility.



            Reference          Description



            3.9.1              MES will not track aluminum Ingots as part of a produced part’s genealogy.



            3.9.2              Dies can have multiple cavities for different parts e.g., one die may have 12 total
                               cavities for 3 separate parts.
                               MES must record the Die# and Cavity# as part of each LOT’s production record or LOTs
                               created in the Die Cast area.



            3.9.3              All LOT’s shall be assigned a Lot IS (Lot #) that will be printed as human readable and as
                               a bar code on a physical LOT Tracking Ticket that shall be attached to the basket of
                               parts making up the LOT.



            3.9.4              LOT IDs shall be Unique and shall conform to a format supplied by MPP



            3.9.5              MES shall assign a MES LOT # to a LOT of materials received from outside vendors and
                               shall record the manufacturers LOT information as part of that LOT’s permanent
                               records



            3.9.6              MES LOTs shall have the following LOT attributes (at a minimum):
                                          MPP Part Number
                                          Piece Count
                                          Maximum Piece Count
                                          Minimum Serial Number (for vendor serialized bulk parts)
                                          Maximum serial Number for LOT (for vendor serialized bulk parts)
                                          LOT weight (reflecting the sum of the weights of all related pieces)
                                          Vendor Lot Number
                                           Hold State



            3.9.7              The LOT ID will be used as the LOT Name.



            3.9.8              LOT auditing will be provided to record all changes in LOT Attribute data (e.g., weight,
                               count, location, identification, etc.).



            3.9.9              The ability to modify LOT Attribute data must be restricted to suitably authorized
                               users. All such actions are to be recorded in the audit log with the inclusion of the
                               logged-in user and the station from which the action was taken. This is considered
                               auditing.



            3.9.10             Inventory locations may contain many items and material LOTs.



            3.9.11             LOTs will be associated with the Inventory location where the LOT can be found when
                               in storage, or the entry area of the next operation to be performed on that LOT. For
                               example, a LOT is presumed to be moved to the next process location (e.g. Trim) upon
                               the completion of the current operation (e.g., Die Cast).



            3.9.12             LOTs can be split into Sub-LOTs. MES must retail the Sub-Lot to Parent LOT relationship
                               and maintain a complete genealogy of the material. [Audited]



            3.9.13             LOTs can be merged into a new LOT. Specific rules apply to this operation as well. MPP
                               will provide further LOT Combine business logic.



            3.9.14             MES must track LOT Splits (Sub-LOTs) and be able to present the genealogy of any LOT
                               back to its originating LOT. [Audited]



            3.9.15             MES must provide a means of manually adjusting the inventory data for any LOT in
                               inventory. The feature is accessible to suitably authorized users. [Audited]



            3.9.16             MES will provide a means for manual reconciliation of the inventory state, including re-
                               identifying a LOT or its associated data, changing its location, or changing its quality
                               status (e.g., mark it as scrap). The feature is accessible to suitably authorized users.
                               [Audited]



            3.9.17             LOT history will be managed by MES for the MPP facility including complete genealogy
                               for the life (Process History) of each LOT.



            3.9.18             A Specific LOT can be prohibited from running on a certain assembly line due to slight
                               tolerance or other machining issues.



            3.9.19             MES should maintain a Max LOT Size attribute for each part to support reasonability
                               checks on data entries. E.g., disallow an operator from adjusting a LOT piece count
                               above a reasonable level.



            3.9.20             All changes to LOT attributes shall be logged in MES Log tables



> ⚠️ **SPARK DEPENDENCY** — References SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively.


                      WORK ORDER CONTEXT, PRODUCTION AND CONSUMPTION TRACKING
           MPP generally does not use work order to manage production at the facility. Conceptually, MPP treats
           daily part production as though it occurs against and always open order for an infinite amount of each
           product. SparkMESTM will create any required WO context internally without operator interaction.
           Work orders are available from the ERP and will be used to create corresponding MES work orders. The
           following section describes Work order data that is needed by the MES.


> 📝 **BLUE RIDGE NOTE** — Identify the equivalent capability in your stack before implementing.



                 ID        Requirement



            3.10.1         MES will create MES Work Orders as needed based upon Shop floor data from the
                           operator or automation. [The ERP system is not generating MES work orders]



            3.10.2         MES will have the capability of receiving and integrating Work Orders from an external
                           ERP system.



            3.10.3         Operator or machine reported part production will be aggregated to the (internal) MES
                           work Order created for the specified part being manufactured



            3.10.4         MES Work Orders will treat the assigned LOT IDs in one of the following ways:
                                      as Serial Numbers related to the Work Order or
                                      as Sub Orders parented by the Work Order, or
                                      as LOT#s associated with the Work Order
                           This detail will be decided during the implementation phase.



            3.10.5         MES Work Order Operation Execution screens will provide work order context data along
                           with the specific data related to the current operation as needed in order to support
                           manufacturing objectives.



            3.10.6         Operators will Identify the LOT(s) of material(s) that is in use at the entry side of a
                           line/machine



            3.10.7         MES will consume parts from the identified LOT as the machine/Line cycles
                           decrementing the LOT available piece count, until the operator changes the available
                           LOT number or the MES LOT part count is depleted.



            3.10.8         MES will not require that a LOT be fully depleted before another LOT can replace it in the
                           line.



            3.10.9         MES will maintain LOT traceability of parts/assemblies consumed into the produced
                           product/tray



            3.10.10        MES will record production events (good count/no-good count) and make that data
                           available for reporting. Production records will include such data as:



                                      produced part
                                      Good Parts produced
                                      No-good parts produced
                                      Downtime data (when captured)
                                      Production start/stop time (when captured)
                                      Machine ID (when appropriate)
                                      Die ID (when appropriate)
                                      Cavity ID (when appropriate)
                                      operator ID reporting production



            3.10.11        MES will record Part Consumption events as parts are consumed into finished goods and
                           make that data available for reporting. Consumption records will include such data as:
                                      Consumed Part Number
                                      Lot Number
                                      Part Count
                                      Consumption Timestamp
                                      Line/Machine ID
                                      End Item/Finished Good Part Number
                                      Produced LOT or Container ID
                                      Produced Tray ID (when appropriate)
                                      Serial number of Produced Part (when available)




## ROUTING AND OPERATIONS


           Routing within MPP is very simple, but work can be performed on a variety of equipment and lines
           (although machines are typically dedicated to producing/processing small collection of the possible
           parts).
           The following data elements are managed by the new MES.



                 ID        Requirement



            3.11.1         MES will support the definition of a MES Operation Template for each process required
                           to transform the raw materials into finished goods.



            3.11.2         MES must allow the creation, editing, and deletion of MES Operations Templates that
                           can be performed on specific machines or process lines. [Audited]



            3.11.3         A MES Operation Template will be associate with each operation that can be executed at
                           a given Work Center, line, or machine.



            3.11.4         MES Operation Templates may be associated with different manufacturing Work
                           Centers/lines that can perform the same operation.



            3.11.5         MES Operations will be maintained solely within MES.



            3.11.6         MES Operation Templates will support the configuration of Data Presentation, Data
                           Entry, tooling requirements, work Instruction references, material consumption and
                           serial number collection information.



            3.11.7         MES Work Order Operation Execution screens will leverage the MES operation template
                           to determine what process data to collect or present to/from the Operator or what
                           materials are consumed, etc. when an operation is active or completed.



            3.11.8         MES internal Work Orders will constitute an “active” routing that will be managed by
                           MES



            3.11.9         MES will be providing a mechanism for modifying the originally planned routing as
                           required during processing.



            3.11.10        MES must allow the deletion and Insertion of operations associated with a work order
                           during execution to accommodate production/process changes. [Audited]



            3.11.11        MES Operations are required to be performed in the sequence specified in the route.



            3.11.12        MES Work Order sequence of operations must be editable by personnel with proper
                           authorization including the deletion (skipping) or addition of operations. [Audited]



            3.11.13        MES must record all operations planned or executed for each work order. [Audited]




## WORK ORDER SCHEDULING


                 ID        Requirement



            3.12.1         An overall Operating Schedule (intended LOT Processing order) is maintained external to
                           MES. MES observes the schedule by operators reporting production activity.
                           MES scheduling will be considered as a future phase of MES development.



            3.12.2         MES Work orders may be kept in the background as needed but will not be exposed to
                           the operator.



            3.12.3         A schedule for a specific line/work center will be the list of work orders that are ready to
                           be run on that line (I.e., their next Operation in the planned route is an operation at this
                           Work center) presented in ascending planned completion date.



            3.12.4         The MES Work Order Summary Screen will be filterable by Line or Station/Operation



            3.12.5         Each Operation OIT will have visibility into the work orders that have LOTs ready to be
                           processed at that operation.



            3.12.6         Operators will be allowed to process orders available at a station out of order (i.e., they
                           do not have to follow the planned execution order).




## REPORTING & BAR CODE PRINTING


           The requirements in this section apply to reports that are provided by MES and any output in the form
           of barcoded Labels.



                   ID          Requirement



            3.13.1             The MES must print barcode labels per operator directive as required at any bar code
                               printer location. Reasons for this may be any of the following:
                                          Reprint a damaged LOT label.
                                          Print a new label as required for LOT split or merge operations.
                                          Identifying new LOTs created as the result of rejected or held material.
                                          Printing of new labels for newly received material.
                                          Re-identifying LOTs in the Sort Cage
                                          Printing Final shipping labels



            3.13.2             MES must provide a LOT genealogy report that provides all traceable events recorded
                               by the MES (production reporting data, parent/child/End Item relationship, etc.). This
                               report may be requested by End Item Serial Number, Lot Number, Sub Lot Number.
                               This report will be viewable from a MES screen and will support export to excel or PDF.



            3.13.3             The Genealogy report’s target item/Lot selection process must include:
                                          selection by Filtered Lot Numbers,
                                          Time of production reporting event at specified process,
                                          Material Received date (for pass through material), etc.



            3.13.4             MES will include Non-Conformance data when available including all NCM activities
                               and details. This report will be viewable from a MES screen and will support export to
                               excel or PDF.



            3.13.5




## HISTORIZATION AND LEGACY MES DATA PRESERVATION


> ⚠️ **SPARK DEPENDENCY** — References SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively.


           The MES system must keep Part, LOT, and serial number genealogy information for all LOTS managed by
           the MES system as part of the permanent records. The existing MES system data must be available for
           permanent records, reporting and investigation. Note that FWI will investigate the possibility of porting
           the legacy MES production history to the new reporting structures to allow historical data reports to
           seamlessly cover the history of both MES solutions.


> 📝 **BLUE RIDGE NOTE** — Identify the equivalent capability in your stack before implementing.



                 ID        Requirement



            3.14.1         Genealogy data for LOTs and Serialized parts must be maintained as part of the
                           permanent production records.



            3.14.2         MES data must be available from online storage for a minimum of 6 months.



            3.14.3         MES must retain production records for no less than 20 years in either an Online or
                           offline repository (offline might be full backup datasets).



            3.14.4         Legacy MES LOT traceability data must be retained and be available as part of the MPP
                           permanent production records.



            3.14.5         Access to Legacy MES data can be limited to preserving the existing SQL Server database
                           and SSRS reports



            3.14.6         The Legacy MES database must be revved up to the current SLQ Server Version used by
                           the new MES solution prior to sunsetting the Legacy solution.



            3.14.7         MES will maintain time-based historian tags representing the current product being
                           produced, the part at a machine, and the LOT in use at each machine



            3.14.8         The new MES must initialize the Die shot counting process with the current die shot
                           count information at the time of commissioning




## PERFORMANCE AND DOWNTIME DATA COLLECTION


           At present Line performance requirements are not fully captured. The MES solution must support the
           ability to configure OEE performance and Downtime classifications and allow the future development of
           performance metrics on a line or a specific work Center. Traditional OEE metrics may not be useful for
           MPP; however, Downtime pareto reports and the ability to analyze recorded downtime events and
           durations is important to MPP.



                 ID        Requirement



            3.15.1         MES will support the configuring OEE configuration Criteria for each Machine, Work
                           Center, and Line in the plant model.



            3.15.2         A Work Schedule shall be maintained in MES for use in determining OEE and Identifying
                           operating vs nonoperating hours. The work schedule will be organized into shifts and
                           MES must be capable of supporting a variety of shift arrangements.



            3.15.3         MES must provide a means of configuring down time reasons and associating them with
                           specific equipment.



            3.15.4         Downtime events can be triggered manually by operators or automatically determined
                           from machine inputs.



            3.15.5         MES shall provide a dashboard/display/report that provides a pareto of the amount of
                           Down time attributed to specific reasons. This display will support filtering by
                           line/operation or reason code.



            3.15.6         Downtime event data will be exportable to CSV type files from the Downtime display
                           screen




## QUALITY


           The following data elements are managed by the system.



                 ID        Requirement



            3.16.1         MES must support recording quality information provided by operators or intelligent test
                           equipment including the part number, LOT number, and Serial number for the sampled
                           part when available.



            3.16.2         MES will provide a configurable way to specify the data entries expected for a particular
                           quality operation.



            3.16.3         MES LOTs will maintain a quality status condition that is initially set to GOOD.
                           Other LOT status shall include:
                                      HOLD
                                      CLOSED
                                      SCRAP
                           Other status value will be determined in the development phase of the project.



            3.16.4         Quality sampling when required can be performed on any portion of a LOT, and the
                           sample results are assumed to be representative of all parts in that LOT.



            3.16.5         A record of any quality related sample parts will be managed by MES as part of the LOT
                           historical data records.



            3.16.6         MES will support entry/recording of an operator entered summary of testing performed
                           along with the ability to upload supporting files (CSV, .XLSX, .PDF, PNG, .JPG, etc.) as part
                           of the production records associated with a LOT or Serialized Part.



            3.16.7         MES must maintain the linkage of the quality results through all LOT split operations.



            3.16.8         MES must support collecting multiple quality records for the same LOT.



            3.16.9         MES will support receiving Quality data from Ignition tags connect to the Quality
                           support/test equipment.



            3.16.10        LOTs must support being placed on Quality hold by a quality representative which will
                           prevent any further manufacturing operation completion activities until the hold is
                           removed.




## LOGGING


           The MES solution will maintain logs of system and operator action for diagnostic and traceability
           investigations.



                 ID        Requirement



            3.17.1         MES must maintain a log of Operations/Execution actions that includes:
                                      Operator/User ID
                                      Time of action
                                      Event/Action Type
                                      Event/Action description
                                      Situational data as appropriate (LOT affected, quantities, machine, etc.)
                                      Error Condition
                                      Error Description



            3.17.2         MES will keep a log of Engineering Configuration Actions that includes:
                                      Operator/User ID
                                      Time of action
                                      Event/Action Type
                                      Event/Action description
                                      Situational data as appropriate (changes made to configuration objects, e.g.
                                       Plant Locations, Items, Products, Revisions, BOMs, Characteristics, etc.)
                                      Error Condition
                                      Error Description



            3.17.3         MES will keep an Interface log containing External System Interface communications
                           activities and errors that includes:
                                      Time of action
                                      Event/Action Type
                                      Event/Action description
                                      Error Condition
                                      Error Description



            3.17.4         MES will include a configuration setting to enable/disable High-Fidelity logging of
                           interface activity that includes recording of data sent and received from external systems
                           for enhanced diagnostic purposes.


