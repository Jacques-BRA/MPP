# Section 5 — Future SparkMES Technical Overview

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.



> ⚠️ **SPARK SECTION — HIGH DEPENDENCY**  

> This entire section describes Flexware's SparkMES framework. Blue Ridge does not have access to this framework.  

> Use this section to understand the **intended architecture and capability** only.  

> Every subsection will require a Blue Ridge-native design decision.


---


           5 F UT URE S PA RK MES T M T E CHNI CA L O VE RV IEW
           The future MES for the MPP facility will replace the existing MES features and PD solution. The MES will
           be built upon the Flexware Spark MES framework. Key characteristics of the MES will be:
                    Flexibility
                    Extensibility
                    Traceability
           The new MES will rely upon a set of SQL Server Databases which will incorporate required portions of
           the existing MPP SQL Server Database and a new Spark MES Database.
           A contextual view of the future Spark MES environment is shown in the following diagram.



                                                Figure 5-1 Future Spark MES Environment



           The new MES will be constructed to use Ignition as its execution engine. Ignition’s integral features for
           managing Database connectivity will be key to the MES operation. It will maintain a connection to the
           required SQL Server Databases which will host the following types of information.
                    Master Data
                    Work Order Information
                    Product Genealogy
                    Quality Information
                    Spark configuration Information
                    Spark Real-Time Information
                    Logging Information (Event & Audit)
           The security provided for the new MES will be a hybrid consisting of both Active Directory and Ignition
           security features. Security groups will be established to control access to screens and functions within
           the SparkMESTM environment. This information will also be used for audit logging purposes to
           incorporate the ID of the user executing operations and the terminal from which the operation was
           initiated.
           SparkMESTM provides a rich set of features allowing the MPP environment to be logically modeled to
           follow the operational flow of its production facilities. Each location of execution within MPP will be
           modeled to incorporate its unique details through configurable attributes, data requirements, and
           quality related observations.
           The execution component of SparkMESTM will allow the operations personnel to perform their
           respective actions at each location via a web-based user interface provided through any device capable
           of hosting a modern web browser such as MS Edge, Chrome, Safari, or Firefox. Spark has the ability to
           write data to and read data from process automation and measurement equipment; however, the initial
           solution will be limited to manual actions like the current CIM application. Subsequent phases will
           provide connectivity to process equipment.
           Traceability is also provided by SparkMESTM so that the complete genealogy for products is maintained
           from the receipt of incoming material at the MPP facility to the shipment of the final product to the
           customer.




## ANTICIPATED MPP DEPLOYMENT ENVIRONMENT


           Based upon information obtained from MPP regarding current versions of Ignition and SQL Server the
           deployment environment expected later this year would closely resemble the architecture illustrated in
           the following figure.



                                               Figure 5-2 Expected Deployment Architecture



           The Flexware Team will perform initial development on Flexware ESXi resources until such time that the
           target servers are available to for use.
           The following section defines the needed systems and software requirements for the new Ignition
           platform to support the requirements defined in section 3.




### 5.1.1 SQL SERVER


           A virtual or physical server running a current version of Microsoft Windows Server as an operating
           system and using Microsoft SQL Server 2019 Standard edition, or newer, will be used to hold the MES
           Database(s).
           Minimum Hardware Requirements:
                    64-bit CPU with a minimum of 4 cores
                    32GB of RAM
                    60GB of storage




### 5.1.2 IGNITION GATEWAY SERVER


           The Ignition Gateway server is the core service of the Ignition system hosting SparkMES TM. Here, the
           software manages tags, connectivity to Databases, alarming, and runs scripting to interact with tag data
           and Databases. Ignition’s Perspective web-based applications will use the gateway to “serve” HMI client
           pages to the user stations. Ignition’s historian will be leveraged for time-series/trend data collection.
           The server will be set up as a Windows Server build, running a single instance of an Ignition Gateway.
           Minimum specs to support the system include:
                    64-bit CPU with a minimum of 4 cores
                    16GB of RAM
                    40GB of storage
           A standard deployment includes a single Ignition Server (running the gateway) which connects to all
           Databases and provides web-based HMI visualization using Ignition Perspective. A basic structure of a
           standard deployment is shown below:



                                                Figure 5-3 - Standard Ignition Architecture




### 5.1.3 OPTIONAL REDUNDANCY


           Ignition can OPTIONALLY run in a server level redundant mode, where the gateway server is running on
           two separate servers (a primary and a backup). This provides the ability to run backend services as well
           as perspective displays using the backup server in the case the primary is offline or down for
           maintenance. The redundant server would be an identical specification to the primary. This is an option
           and not a requirement. Ignition Gateway Redundancy is NOT currently planned to be incorporated in
           this project.




### 5.1.4 DEVELOPMENT AND TEST ENVIRONMENT SERVER


           Ignition’s default “free” two-hour development license is recommended for this project to reduce costs;
           however, it is advisable to instantiate a separate stand-alone development/test server for this purpose.
           This should be similar in size and capability to the production server so that it can stand in for the
           production environment in an emergency.
           Initially, the development SparkMESTM Database can share the production database server.




## IGNITION BASE PLATFORM FOR MES SOLUTION


           This section identifies the Ignition software components needed to support the requirements for this
           solution.




### 5.2.1 IGNITION PLATFORM


           The Ignition platform is the foundation for every Ignition system; it includes powerful features and core
           drivers to connect all your industrial data and devices into one central hub. Features include:
                    Unlimited Tags - Use as many tags as you need for devices, Databases, and anything else.
                    Unlimited Designer Clients - Get your whole team to develop projects, even at the same time.
                    Powerful Connectivity - Connect to any major PLC and Database with built-in SQL Database
                     connectivity and the included OPC UA Server Module and core drivers.
                    Included Core Drivers - Modbus Driver, UDP and TCP Driver, BACnet Driver, Allen-Bradley Driver
                     Suite, Siemens Driver Suite, DNP3 Driver, Omron Driver
           Optionally, a redundant backup gateway can be added to protect your system from downtime caused by
           system failure or server maintenance. The backup gateway needs the same modules as a primary
           gateway but is priced at a 50% rate. This can be added on later when required. The redundant gateway
           will need to be installed on a separate server from the primary.




### 5.2.2 PERSPECTIVE VISUALIZATION


           The visualization module for cutting-edge modern industrial applications. Quickly build full-featured
           industrial applications for monitoring and control, using the latest mobile-responsive, pure-web
           technology. Perspective applications are build-once, run-anywhere-compatible with three distinct
           deployment technologies that give you a wide range of options. Deploy directly to web-browsers for a
           modern, pure-web experience. Leverage the native mobile applications to gain access to hardware
           features such as the device’s accelerometer, Bluetooth connectivity, geolocation, barcode scanning, and
           more. Finally, leverage Perspective Workstation to add full kiosk mode and multi-monitor support,
           perfect for control rooms, touch panels, and HMIs. Perspective gives you total freedom to visualize and
           control your process however you want, on whatever device you want.
           Perspective applications can be deployed directly to a web browser or can leverage native applications
           for a richer experience on mobile and thick-client devices. Perspective is best with Unlimited Sessions
           and is recommended for future growth.




### 5.2.3 REPORTING MODULE


           The Ignition Reporting Module is a standalone reporting solution that simplifies and enhances the
           reporting process from beginning to end. Generate reports from existing files or create them from
           scratch. Pull data from a variety of sources, and design reports with a simple-to-use interface. Add
           charts, graphs, tables, crosstabs, shapes, and other components for visual impact. Save your reports in
           PDF, HTML, CSV, and RTF file formats, and set up automatic scheduling and delivery.
           Use all of these powerful capabilities to quickly create many common types of reports such as
           production management, efficiency monitoring, downtime tracking, SPC, QA, OEE management, and
           historical data analysis.



                                              Figure 5-4 - Ignition Reporting Module Sample




### 5.2.4 TAG HISTORIAN MODULE


           The Tag Historian Module for Ignition allows you to turn a SQL Database into a high-performance time-
           series tag historian. It requires minimal work to implement and is simple to use, even if you aren’t very
           experienced with SQL Databases. The power, ease of use, and incomparable price-to-performance ratio
           of the Tag Historian Module make it the clear choice for storing your organization’s valuable historical
           information. This includes the following features:
                    Store History with a Click - With the Tag Historian Module, you can store history on a tag to your
                     Database with the click of a mouse – no complex configuration, tuning, or data modeling
                     required.
                    Create Tables Effortlessly - The module creates and manages tables for you, so you don’t need
                     to be knowledgeable about Database management to use it.
                    Easy Query Binding - Use the data intuitively throughout Ignition with simple, visual query
                     binding screens – no need to write SQL or complex queries.
                    Powerful Historian Engine - The module’s high-powered historian engine automatically supports
                     compression, partitioning, interpolation, and aggregation for any SQL Database.
                    Make Data More Accessible - By recording your data to a SQL Database, the module makes your
                     process data available to any application with Database access.
                    Real-Time Charts and Trends - Combine with the Vision Module to simply pull the information
                     you need into individual charts and graphs.




## FLEXWARE’S SPARKMESTM FRAMEWORK


           Flexware has developed a foundational software framework that we refer to as SPARK. The “SPARK
           Framework” leverages core Ignition assets that have been generated internally over the past several
           years. The framework includes valuable codebases and visual tools from Database schemas, security
           modeling, end-user configuration tools to visual design structures. SPARK is an Ignition based jump-start
           that contains basic MES functionality built with Ignition script and Microsoft SQL Server. SPARK provides
           the basic features of track and trace, operations and performance that are common to MES solutions,
           but specifically tailored around the Ignition platform.
           Basic features supported by SPARK include:
                1.   Plant physical Model
                2.   Material Management, LOT tracking, Inventory management
                3.   Product Definition/Bom Management
                4.   Manufacturing Route planning
                5.   Work Order execution
                6.   Tracking and Genealogy
                7.   Browser based UIs designed to support multiple users
                8.   Role based access to features
                9.   Delivery of Work Instructions



                10. Capturing Process Data automatically and manually
                11. User tracking/logging
                12. Timestamped event logging for time study support
                13. Non-conformance and Rework Routing planning, data capture, tracking
                14. Downtime Event Definition, capture and analysis
                15. Historization via Ignition Historical Database



           This foundation allows Flexware to develop and deploy basic MES functionality quickly while allowing us
           to extend and customize the user interface to maximize the fit and function within each factory. Spark is
           intended to be modified to work the way your organization works.



           Sparks perspective base user interface can be configured to provide the same look and feel as the
           current MES support screens. However, we believe there will be LOTs of opportunities to improve the
           overall user experience using Spark and Ignition.



                     USER INTERFACE PCS & THIN CLIENTS, TABLETS AND CELL PHONES
           PCs and Thin clients are easily supported by Ignition Perspective. It is expected that the existing user
           stations will be configured to use a modern web browser to display the Ignition Perspective HMI
           application screens. Alternate UI equipment (Bricks, etc.) can be discussed if desired and a separate
           proposal will be required to offer new operator HMI stations.
           FWI is currently planning to utilize all existing Operator HMI stations and support equipment in the
           new Solution.




## PROCESS INTERFACE AND PRINTING DEVICES



### 5.5.1 PROCESS CONTROL EQUIPMENT INTERFACE


           MES will use the same OPC and direct ethernet messaging to communicate with the process automation
           PLCs, cameras, scales, and the AIM system that are currently in use. The new Ignition platform supports
           additional interface technologies and may be leveraged to add additional data collection points that will
           be stored in the Ignition Historian.
           MPP technicians can add additional points to the system for historization and to extend the data
           available for operator display and reporting.




### 5.5.2 AIM SYSTEM AND HONDA SUPPLY CHAIN INTERFACE


           The new MES will utilize the same communications with the AIM solution.
           AIM Computer solutions provides the EDI communication that Honda requires from MPP. AIM is a
           Honda certified software partner.
           MPP receives the EDI 830 transaction planning schedule. They use this data to plan their production
           scheduling.



           Once a batch at MPP is ready to ship to Honda, they send an advanced shipping notification (856 EDI
           transaction) back to Honda. This ASN 856 EDI transaction includes the shipping container identifier, the
           part numbers and the correlating Honda identifier for the shipment. These numbers are all traceable
           back to the lot.




### 5.5.3 BAR CODE READERS AND PRINTERS


           Many of the locations where operator terminals are provided are equipped with bar code scanners
           and/or Zebra bar code printers.
           The 2D bar code scanners are used for scanning the bar code label attached to the material LOTs within
           the MPP facility. The labels contain pertinent information such as:
                    Lot Number
                    Part Number
                    Serial Number
                    Etc.
           The use of the bar code scanner helps reduce the risk of typing or selection errors at the terminal.
           Bar code printers are stationed at locations where it is common to produce new LOTs or split LOTs
           requiring updated and additional labels for the LOTs. The printers used are manufactured by Zebra
           Technologies and MES will utilize the existing ZPL language-based configuration files.
           The Replacement system will utilize the exiting barcode readers and printers.




## POSSIBLE FUTURE MES ENHANCEMENTS


           The new MES platform presents opportunities for improvement beyond the modernization of the MES
           solution itself. The following sections summarize some such opportunities.
           In some cases, FWI has included separate line items in the ROM Estimate section for a few of these
           opportunities where sufficient information is available to support an estimate.




### 5.6.1 PROCESS DATA COLLECTION


           The new Ignition based infrastructure will have the ability for generalized process data historization.
           Ignition’s time-based data historian can be used to collect general data from the process and provide
           user’s the ability to visualize the data on trends, reports, and dashboards. This can be extended over the
           life of the system, adding data points as needed as the system evolves.
           Some examples for consideration include:
                    Aluminum Ingot data (identification and time of addition)
                    Molten aluminum delivery cycle data (target machine, time of filling, etc.)
                    Die Shot counts and machine data (temperatures, pressures, etc.)
                    Automated test equipment results/measurements



                    Torque values
                    Leak Test results
                    Etc.
           This is a capability of the new system, but no firm requirements have been expressed at this time and
           no custom configuration will be included in the accompanying proposal.




### 5.6.2 TABLET/CELL PHONE BASED MES USE CASES


           The Ignition Perspective package supports the development of HMI screens that are viewable on Tablet
           or Cell phone-based HMI displays. These devices typically connect to the Ignition Gateway via a local Wi-
           Fi network. Remote Cellphone access to the Ignition Gateway server would require the appropriate
           firewall and VPN facilities to be in place. Cell phone and Tablet based use cases can be supported and
           suitable HMI screens can be developed for this new solution.
           Some possibilities include Alarming and Alerts, message/escalation, process monitoring, etc.
           This is a capability of the new system, but requirements are unclear at this time and no custom
           configuration will be included in the accompanying proposal. Cell phone notification of alarm
           conditions can be supported via the Twilio Module which will be included in the proposed solution.




### 5.6.3 NONCONFORMANCE MANAGEMENT AND FAILURE ANALYSIS


           SparkMESTM includes Nonconformance Management (NCM) and Failure Analysis (FA) features that allow
           placing materials into a quality hold state, tracking those parts through a failure analysis and
           remediation processes and assigning a final disposition to the nonconforming part/LOT. This solution
           allows for associating comments and documents (pictures, spreadsheets, pdfs, etc.) needed to
           document the circumstances and remediation process. Nonconforming parts can be resolved to a
           variety of states including use “as repaired”, return to vendor, scrap, quarantine, etc.
           Using SparkMESTM NCM tool, operators can create quality holds from the shop floor and prevent
           escapement of no good parts into the process by interlocking MES with the quality system at the
           moment a nonconformance is recognized in production.




### 5.6.4 EXTENDED PASS-THROUGH PART SUPPORT


                Pass through parts are often received at remote sites and then moved to MPP. It would be
                possible to provide MES screen access at the remote site through which an operator can
                access MES inventory screens to receive the pass-through LOT into inventory.
                MES can allow:



                         Operator receiving parts at the remote site (create the LOT, and gather the serial
                          number range, and consider it inventory at that site).
                         keep an inventory image of the parts received at the site.
                         provide the inventory move screen to move the lot from the remote site to the main site
                          (and possibly vice versa).



                         Print labels for the LOT at the remote or local site.
                         provide traceability of the LOT through shipping.




### 5.6.5 QUALITY SAMPLE RECORDS


           SparkMESTM can keep quality sample records as part of the LOT history providing traceability of
           quality samples if desired. Quality representatives can identify samples and associate test results
           to the samples within the MES system as they are evaluated. This activity can tie into the non-
           conformance records and support tracking additional remediation steps if necessary.




### 5.6.6 PRODUCTIVITY DATABASE FUNCTIONAL INTEGRATION


           A primary goal for the MES system is to reduce the amount of data transcription between systems.
           Currently entering data into the Productivity Database application is a primary point of duplicate data
           entry. The new MES should replace the functions currently provided by the Productivity Database
           application.
           These include:
                    Downtime event recording and reporting.
                    Production recording and reporting.
                    Die Use tracking.
                    Quality dispositioning and Non-conformance tracking and reporting.
                    Machine productivity reporting
           See Appendix F for screen grabs from the Productivity DB user interface.
           The existing PD solution supports production record keeping, Die Maintenance Management, Downtime
           Tracking (DT), No Good part and SCRAP tracking. Operations relies on several reports that leverage the
           PD data for daily operations and performance improvement. Some of the more vital reports are daily
           rejects, Die shot life and Casting area downtime. Some other areas like the machining area are not
           recording downtime but MPP would like to capture this data in the future.
           The PD is separate from MES and requires manual entry of all data. MPP would like to eliminate the
           manual entry of this data if possible and leverage MES to support the production reports.
           The following sections summarize existing PD solution functions. These functions are to be replicated in
           the new MES using modern methods with possible user support enhancements.
           5.6.6.1 G ENERAL U SER I NTERFACE
           The PD has a custom Microsoft ASP.NET user interface that presents data entry forms with minor data
           integrity support features (see Appendix F). Data entry is a combination of free form fields and drop-
           down selections that limit entries to prescribed values.
           The PD user interface is built using custom Microsoft ASP web pages with C# code behind. The PD
           interface provides a dedicated data entry form for each of 4 areas; Die Cast, Trim Shop, Machining, and



           Quality Control.



           5.6.6.2 P RODUCTION R EPORTING – P RODUCTION D ATA E NTRY , G OOD AND N O G OOD PARTS
           The PD data entry forms support clerks entering a summary of production data (Lots, good part count
           and No-Good part count on a shift basis for each Area. See Appendix F for a depiction of the form and its
           content.



           5.6.6.3 P RODUCTION R EPORTING – D IE M AINTENANCE
           The data entry for the Die Cast area PD data entry forms support Die usage monitoring implicitly by
           capturing the number of Good/no-good parts processed by each Die during the shift. Die usage tracking
           is a critical feature of the PD application that helps in maintenance planning and scheduling.
           See Appendix F for a depiction of the form and its content.



           5.6.6.4 P RODUCTION D ELAY /D OWNTIME D ATA
           The PD data entry screen for the Die cast area supports entry of up to seven (7) Downtime events
           including specifying the reason, duration, charge-To department, and comments for each.
           See Appendix F for a depiction of the form and its content.



           5.6.6.5 R EJECT (N O G OOD P ART ) AND N ON - CONFORMANCE D ATA
           The PD data entry form for the Die Cast, Trim Shop, and Machining allow the clerk to enter 10 to 15
           reject records including a Reject Code, Quantity, and “Charge To Department” for each event.
           See Appendix F for a depiction of the form and its content.




### 5.6.7 INTELEX


           Currently Intelex is used for:



                    Quality management, Holds and corrective action tracking (non-conformance, MRB, rework and
                     remediation tracking, etc.)
                    Document management in support of ISO 9001:2015



           Spark does not currently include Document Management features.
           Spark includes Non-Conformance Management (NCM) capabilities that would allow tightly coupling
           NCM and MES in order to provide better containment control and traceability of non-conformant parts
           in the process.



           There are currently no integrations between Intelex and any other system. Intelex required duplicated
           activities when managing LOT Quality Hold situations.
           It might be possible to have the new MES create Hold records in Intelex or export hold information that
           can be imported into Intelex to create hold records. Intelex has provides 3 REST APIs that may be able
           to support creating Intelex Hold records.




### 5.6.8 MACOLA ERP INTEGRATION


           Macola ERP is business operations and accounting software for manufacturing and distribution
           companies. ERP is enterprise resource planning software with a unified database for many business
           processes. ERP systems for manufacturers and distributors, like Macola 10, are also called MRP (material
           requirements planning) systems.
           The current MES does not integrate to Macola for MES activities; consequently, production data must
           be hand entered into the Macola system to relive inventory and fulfill orders.
                         At one point, MES was extended to provide manual data entry screens that
                         interacted with the Macola database (see Appendix N); however this is no longer
                         being used and is not required for this MES upgrade.
           MPP would like to reconsider interfacing with the MES system if it can reduce the amount manual data
           entry and paper handling at the Madison facility. MACOLA users may be able to export Items and BOMs
           to a CSV and the new MES must have the ability to ingest CSVs to introduce Items and BOMs.
           MPP would like to reconsider interfacing with the MES system if it can reduce the amount manual data
           entry and paper handling at the Madison facility. This activity would include reporting production data
           to the Macola database and reporting LOT Creation and movements within MPP. This possible
           interface is for future consideration and will be quoted separately if MPP would like to add this
           feature.




### 5.6.9 MACHINE-SIDE MES OPERATOR TERMINALS


           MPP may install a number of machine-side MES operator stations to allow additional local data entry,
           reduce data latency and improve overall efficiency. Flexware recommends that MPP consider
           leveraging thin client technology in the future to reduce the cost of each station while providing a
           machine that can withstand the harshness of the environment.
           Thin Client MES operator terminals are not in the scope of supply for this project but can be quoted
           separately upon request.
           Intelex is purely a document management system. There is no other functionality and no traceability of
           quality data back to LOTS.


