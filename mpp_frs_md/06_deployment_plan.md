# Section 6 — MPP Deployment Plan

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.


---


           6 MPP D E PLOYME NT P LA N
           This section proposes a pathway for migrating MPP from the existing MES solution to the new solution.
           The MES solution will be developed using Agile methodologies design to bring a minimum viable product
           on line as early as possible, and then enhance and embellish that solution through a series of
           development sprints that brings on process improvements and additional features.




## MINIMUM VIABLE PRODUCT


           The minimum Viable Product (MVP) is an initial deployment that provides the functionality required to
           cover the mission critical features of the existing MES system In the MPP solution, this includes provide
           the LOT tracking and Process interlock features covered by the existing system and the ability to model
           the new Astemo Line, but leaves any additional features from section 5.6 to future updates.




### 6.1.1 MVP DEVELOPMENT


> ⚠️ **SPARK DEPENDENCY** — References SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively.


           MVP features development includes:
                1. Base Spark Configuration
                        a. Plant Model
                        b. Characteristics/Attribute definition
                        c. LOT Attribute definition
                        d. Item master
                        e. BOM
                        f. Products
                        g. Routing
                        h. Downtime Reasons
                        i. OEE relationships
                        j. Non-Conformance
                2. Operator Interface customization
                        a. Inventory interface.
                        b. Execution Interface
                3. OPC Tag configuration
                4. Initial Dashboards and Reports


> 📝 **BLUE RIDGE NOTE** — Identify the equivalent capability in your stack before implementing.




### 6.1.2 MVP INITIAL CONFIGURATION AND TRAINING


> ⚠️ **SPARK DEPENDENCY** — References SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively.


           Flexware will work with MPP subject matter experts (SMEs) to re-create the initial configuration and
           train the SMEs in the use of the system. These SMEs will carry out further training of the broader
           engineering and operations staff.
           For estimation purposes, we have included costs based on the following assumptions:
                    Training will be provided via remote/Net meetings.
                    16 total hours of “train the trainer” (SME) training will be provided over a series of meetings
                     focusing on specific use cases (engineering configuration, operations, IT support, etc.)


> 📝 **BLUE RIDGE NOTE** — Identify the equivalent capability in your stack before implementing.




### 6.1.3 MVP FACTORY ACCEPTANCE TESTING


           A Factory Acceptance Test will be designed to demonstrate the solution prior to deployment. A series of
           machine/process simulators will be developed leveraging Ignition’s script engine to stand in for
           examples of the actual machines in the factory. These simulations will allow for the demonstration of
           interconnections and interlocks to prove the interconnected behavior is verifiable.




### 6.1.4 MVP SHADOW COMMISSIONING


> ⚠️ **SPARK DEPENDENCY** — References SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively.


           The replacement MES will be deployed into MPP servers and made available to one or more areas to
           work in parallel to the existing MES. This will require duplicate LOT entries for production and LOT
           movements for specific areas to prove the system generates the expected reports and logs.
                    First, the side-by-side behavior will be by area (e.g., duplicate activities logging LOTs into the Die
                     Cast area and observing the WIP state),
                    Second, the side-by-side will be by taking one or more specific LOT’s through the entire
                     manufacturing process, verifying traceability, etc.
           Shadow commissioning will include ingesting LOT inventory data from the existing MES and seeding it
           into the new MES Inventory state.
           Shadow Commissioning will include exporting existing MES production data to the Reporting Database
           FWI will provide onsite support for portions of the shadow commissioning activities. Shadow
           commissioning is expected to be during normal daytime business hours. For estimation purposes, we
           have included costs based on the following assumptions:
                    Software installation will be accomplished via remote access to target computer systems.
                    One FWI engineer on-site for 4 – 8-hour days to provide training and oversee testing.
                    Ongoing remote support throughout this phase to support additional testing.


> 📝 **BLUE RIDGE NOTE** — Identify the equivalent capability in your stack before implementing.




### 6.1.5 MVP SHADOW COMMISSIONING ALTERNATE


           Another shadow commissioning approach might be to build a process for sending event messages from
           the legacy MES to the new MES as LOT’s are processed. These event messages would act like operators
           using the new MES solution e.g., when a user creates a LOT in the legacy system, that data would be
           sent and processed in the new MES achieving the same objective as though the data was entered into
           the new system via the UI. This approach would require the following messages at a minimum:
                    Lot Creation
                    Lot Move
                    Lot Allocation/Machine/Assembly IN
                    Lot Deallocation / Machine Out
                    End Item Production / Assembly Out
                    Container rejection
                    Container reprocessing




### 6.1.6 MVP COMMISSIONING


> ⚠️ **SPARK DEPENDENCY** — References SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively.


           The MVP instance will be commissioned and access to the old MES instance will be disabled. The old
           MES will stay intact for a period of time until MPP decides that it is unnecessary. The Legacy MES
           database will be retained indefinitely (online or off-line) to support any future LOT part investigations.
           FWI will provide on-site around the clock support for one 5-day period to accommodate the
           commissioning activities.
           For estimation purposes, we have included costs based on the following assumptions:
                    Two FWI engineer on-site for 4 – 12-hour days to provide training and oversee testing-
                     engineers to split schedules to provide 24-hour coverage.
                    Ongoing remote support throughout this phase


> 📝 **BLUE RIDGE NOTE** — Identify the equivalent capability in your stack before implementing.




## ENHANCEMENT SPRINTS


           Enhancement sprints will include development of any remaining functionality described in section 3 and
           functionality not provided by the existing MES solution including section 5.6 items if requested by MPP.
           Additional features and usability enhancements will be deployed through a series of sprints each
           including development, testing, and commissioning support as needed.
           Note that these additional deployments are less intrusive than the MVP deployment and commissioning
           since the new foundation is in place.
           For estimation purposes, we have included costs based on the following assumptions:
                    Post MVP Sprint development will be remotely supported and will follow a typical Develop, Test,
                     Deploy pattern.
                    Remote support of the MVP solution will be provided during the enhancement sprint cycles.


