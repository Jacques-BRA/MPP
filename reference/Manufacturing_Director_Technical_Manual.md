<!--
  Generated from: reference/Manufacturing Director Technical Manual.pdf
  Source: Flexware Innovation, project 2008178_VTS_VCMTraceabilitySystem (Feb 2009)
  Pipeline: pdftotext -enc UTF-8 -layout  |  convert_mdtm_to_md.js
  Images NOT extracted in text-first pass — install Poppler and run
  `pdfimages -png -p -f <N> -l <N> <PDF> <outdir>` to pull screenshots on demand.
-->

# Manufacturing Director — Technical Manual

> **Legacy reference only.** This is the 2009 Flexware Manufacturing Director technical
> manual for the VCM Traceability System installed at Madison Precision Products —
> the system being replaced by the new Ignition + SQL Server MES. Content preserved
> verbatim from the source PDF; running footers and TOC stripped, headings promoted
> from the original outline numbering. Screenshots are not included; `<!-- Page N -->`
> markers reference the source-PDF page for cross-referencing.
<!-- Page 1 -->

MES – Technical Manual

Madison Precision Products

 2008 _ VTS_VCMTraceabilitySystem

Flexware Innovation, Inc.  Reference SOP ENG0025_Template_TechUserManual.doc
9128 Technology Ln.
Indianapolis, IN 46038
Office: (317) 813-5400
Fax:(317) 813-2121

<!-- Page 8 -->

# 1.0 Introduction

## 1.1 Purpose

       The “Machine Integration – Technical Manual” document contains detailed configuration
       information of all machine integration devices (software, hardware, communication, etc.) for
       the implementation of VTS Traceability System. This document is intended to compliment
       the “Machine Integration – User Manual” document.

## 1.2 Definitions, Acronyms and Abbreviations

         Item                                       Definition

2D                Two Dimensional
Cognex            Manufacture of camera and imaging software
CPU               Central Processing Unit
CSQ               Computer Systems Quality
DHCP              Dynamic Host Configuration Protocol
Flexware          Publisher of Manufacturing Director software
GTIN              Global Trade Identification Number
I/O               Inputs and Outputs
LAN               Local Area Network
Manufacturing     Software package consisting of operator interface and configuration
Director          tools, used to store product information and to download
                  parameters to and from camera and printer.
MD                Manufacturing Director
OCV               Optical Character Verification
OLE               Object Linking and Embedding
OPC               OLE for Process Control
PC                Personal Computer
PLC               Programmable Logic Controller
URL               Universal Resource Locator

<!-- Page 9 -->

# 2.0 Machine Integration Overview

## 2.1 System Connectivity

              The dataflow through the system can be separated into three levels.

              The first level is the “Device/Control” layer. This is where data is collected from the shop
              floor from devices such as Cognex In-Sight Sensors and DataMan ID Readers. The data is
              then stored in PLC memory in a format that can be accessed by OPC Servers. The first level
              also houses the HMI displays and Vorne Boards that are used to provide visual feedback of
              the MES transaction process to the operators.

              The second level is the “Supervisory” layer. This layer houses the two OPC servers used in
              the system; Cognex In-Sight OPC Server and Mitsubishi OPC Server. The Cognex server
              communicates directly to the job file in the In-Sight Sensors located in Casting lines 1 and 2
              and the Mitsubishi server communicates to the Mitsubishi PLCs located in Machining and
              Assembly. The OPC server acts as the communication bridge between the shop floor devices
              and Manufacturing Director. The devices send/receive data to the servers and MD also
              send/receive data to the servers.

              The third level is the “Execution” layer. This is where the data is collected from level 2 and
              stored into local databases. Manufacturing Director then takes this data and begins the part
              transaction process. Once the transaction is complete, MD sends new information down to
              level 2 where it is distributed among the shop floor devices. Level 3 also maintains the
              production process and is used to print labels to the Zebra Label Printers and communicate to
              the Manufacturing Director Terminals located on the shop floor.

              The following is a diagram showing the three levels of operation and the process dataflow.

Level 03                                                                                                                                                            I
Execution                                                                  J

Level 2      Manufacturing Director™ Terminals G                           H                                         Assembly Raw Material Scanner
Supervisory                                                                                                                      Typical in Areas:
                  Typical for Terminals in Areas:                                                  Assembly
                 Casting                                                                   Typical for Operations:         Line 1 Assembly
                 Assembly                                                             Container Pack on Line 1             Line 2 Assembly
                 Machining                                                            Container Pack on Line 2

                                                                       E   F

                                                    Cognex InSight               Mitsubishi
                                                       OPC Server               OPC Server

Level 0/1             A                    Vorne Board  B                                       C  Mitsubishi                                D                         Mitsubishi
Device / Vorne Board                                                                                            HMI                                                                 HMI
Control               InSight Vision                     Mitsubishi FX     DataMan ID                                                  InSight Vision
                           Sensor                                             Reader                                 Vorne Board Sensor
                                                                      HMI

                            Casting                     Machining                      Assembly In                             Assembly Out
                  Typical for Operations:       Typical for Operations:         Typical for Operations:                   Typical for Operations:
             Casting 1                     Line 1 Deburr 1                 Line 1 CIR-Clip Assy                      Line 1 Mounting Bolt Assy
             Casting 2                     Line 1 Deburr 2                 Line 1 Lost Motion Spring Assy            Line 2 Mounting Bolt Assy
                                           Line 2 Deburr                   Line 2 CIR-Clip Assy

<!-- Page 10 -->

### 2.1.1 Casting (A)

Task                                          Operation
  1
  2   Cognex In-Sight sensor acquires image of barcode.
      Logic in In-Sight sensor (job file) verifies condition of barcode and assigns a
  3   part state. Decode Error = a state of 0, Successful Decode = a state of 1
  4   Data Ready bit is turned on in In-Sight sensor to let MES know there is a new
  5   part.
      MD creates and completes part at the casting operation.
      Vorne Display Boards: displays updated production data based on discrete
      signals from the Casting control panel.

### 2.1.2 Machining (B)

Task                                                         Operation
  1
  2   Cognex DataMan ID Reader decodes serial number from the 2D Data Matrix
  3
      bar code and sends to the Mitsubishi PLC.
  4
      Mitsubishi PLC stores part serial number data.
  5
      Data Ready is set in the Mitsubishi PLC upon receiving the part serial
      number.

      Data Ready triggers MD:

      MD checks if the part exists, if not then the part is created and it is
      recorded that the part was started and completed at the operation.

      If the part exists then MD checks the Part Interlock logic set for this

      part:          Part must have a valid SN format
          o          Overall Disposition of the part must Good and must not be
          o          Scrap or Suspect
                     Note: The part could have a Casting Part Status of Invalid but
                     this would not produce a part Invalid at this operation if the
                     overall part disposition is Good.

      If the interlock logic determines the part status is Invalid the HMI
      displays “Bad Part”. This part is not to be run through the process but
      placed in a tote for supervision to review.

      If the interlock logic determines the part status is Valid the HMI will
      display “Good Part” and the part is to be placed on the in-feed
      conveyor.

      MD will also record that the part was started and completed at the

      machining operation upon a part status of Valid.

      Vorne Display Boards: displays updated production data based on discrete
      signals from the OP40 machines at each line.

### 2.1.3 Assembly In – Line 2 Cir-Clip Assembly (C)

Task                                          Operation
  1
  2   Cognex DataMan ID Reader decodes serial number from the 2D Data Matrix
      bar code and sends to the Mitsubishi PLC.
      Mitsubishi PLC stores part serial number data.

<!-- Page 11 -->

3     Data Ready is set in the Mitsubishi PLC upon receiving the part serial
      number.

      Data Ready triggers MD:

      MD checks if the part exists, if not then the part is created and it is

      recorded that the part was started and completed at the operation.

      If the part exists then MD checks the Part Interlock logic set for this

      part:

      o Part must have a valid SN format

      o Overall Disposition of the part must Good and must not be

                Scrap or Suspect

                Note: The part could have a Part Status of Invalid relating to

4               a previous operation (Casting or Machining) but this would
                not produce a part Invalid if the overall disposition of the part

                is Good.

      If the interlock logic determines the part status is Invalid the HMI

      displays “MES ERROR”. This part is not to be run through the

      process but placed in a tote for supervision to review.

      If the interlock logic determines the part status is Valid the HMI will

      display “PART VALID” and the part will be allowed to run into the

      process.

      MD will also record that the part was started and completed at the

      machining operation upon a part status of Valid.

### 2.1.4 Assembly In – Line 1 Cir-Clip Assembly (C)

Task                                          Operation
  1
  2   Cognex DataMan ID Reader decodes serial number from the 2D Data Matrix
  3   bar code and sends to the Mitsubishi PLC.
      Mitsubishi PLC stores part serial number data.
  4   Data Ready is set in the Mitsubishi PLC upon receiving the part serial
      number.
      Data Ready triggers MD:

               MD checks if the part exists, if not then the part is created and it is
               recorded that the part was started and completed at the operation.
               If the part exists then MD checks the Part Interlock logic set for this
               part:

                    o Part must have a valid SN format
                    o Overall Disposition of the part must be “Good” and must not

                         be “Scrap” or “Suspect”
                         Note: The part could have a Part Status of Invalid relating to
                         a previous operation (Casting or Machining) but this would
                         not produce a part Invalid if the overall disposition of the part
                         is Good.
               If Cir-Clip machine process produces a clip insert error then the part
               status of the Cir-Clip operation is set to Invalid.
               If the interlock logic determines that the part status is Invalid the part
               is to be placed in a tote for supervision to review.
               If the interlock logic determines the part status is Valid the part is to
               be queued for the next operation.

<!-- Page 12 -->

      MD will also record that the part was started and completed at the
      machining operation upon a part status of Valid.

### 2.1.5 Assembly In – Line 1 Lost Motion (C)

Task                                          Operation
  1
  2   Cognex DataMan ID Reader decodes serial number from the 2D Data Matrix
  3   bar code and sends to the Mitsubishi PLC.
      Mitsubishi PLC stores part serial number data.
  4   Data Ready is set in the Mitsubishi PLC upon receiving the part serial
      number.
      Data Ready triggers MD:

               The following MD interlock logic is checked at this station:
                    o The part must have been successfully processed at Cir-Clip,
                         Cir-Clip part status must be Valid.
                    o Overall Disposition of the part must be “Good” and must not
                         be “Scrap” or “Suspect”
                         Note: The part could have a Part Status of Invalid relating to
                         a previous operation (Casting or Machining) but this would
                         not produce a part Invalid if the overall disposition of the part
                         is Good.

               If the interlock logic determines that the part status is Invalid the part
               is to be placed in a tote for supervision to review.
               If the interlock logic determines the part status is Valid the part will
               be accepted into the assembly line for processing.
               MD will also record that the part was started and completed at this
               operation upon a part status of Valid.

### 2.1.6 Assembly Out (Line 1/2) (D)

Task                                          Operation
  1
  2   Cognex In-Sight Sensor decodes serial number from the 2D Data Matrix bar
  3   code and sends to the Mitsubishi PLC.
      Mitsubishi PLC stores part serial number data.
  4   Part Start is set in the Mitsubishi PLC upon receiving the part serial number.
      Part Start triggers MD:

               MD checks if the part exists, if not then the part is created and it is
               recorded that the part was started this operation.
               The following MD interlock logic is checked at this station:

                    o Part must have a valid SN format
                    o Overall Disposition of the part must be “Good” and must not

                         be “Scrap” or “Suspect”
                         Note: The part could have a Part Status of Invalid relating to
                         a previous operation (Casting or Machining) but this would
                         not produce a part Invalid if the overall disposition of the part
                         is Good.
               If the interlock logic determines that the part status is Invalid the

<!-- Page 13 -->

        machine will not process the part and the operator is to remove the

        part from the system and placed in a tote for supervision to review.

        If the interlock logic determines the part status is Valid the part will

        be accepted into machine for processing.

        Data Ready triggers MD:

        MD checks the status of this Part Status bit in the PLC to determineif

        the part is a good part.

        If the Part Status bit is off this means it is a bad part and the Part

5       Status is Invalid and the machine is interlocked and the operator is to
        remove the part and place it in a tote for supervision review.

        If the Part Status bit is on this means it is a good part and the Part

        Status is Valid. MD will record the completion of the part processing

        and the machine will place the part on the out-feed conveyor by the

        machine.

5 Vorne Display displays updated production data.

### 2.1.7 Cognex In-Sight OPC Server (E)

Task                                            Operation

  1     Data is received from In-Sight Sensors in Casting Lines 1 and 2.
  2     Data is sent to MD.
  3     Transaction status data is received by MD.
  4     Transaction status data is sent to Casting Lines 1 and 2.

### 2.1.8 Mitsubishi OPC Server (F)

Task                                            Operation
  1
  2     Data is received from PLCs in Machining Lines and Assembly Lines
  3     Data is sent to MD.
        Transaction status data is received by MD.
  4     Transaction status data is sent to PLCs in Machining Lines and Assembly
        Lines

### 2.1.9 Manufacturing Director Terminals (G)

Task                                            Operation

  1     MES data is retrieved from the MD database.
  2     MES data is displayed to the Operator.
  3     Operators can track and modify parts and containers.

### 2.1.10 Assembly Printers (H)

Step #                                                       Task

1       MD populates the label with MES data and sends label to the printer in ZPL
        format.

<!-- Page 14 -->

2       Zebra Label Printer prints the container labels for completed containers in
        Assembly Out lines 1 and 2.

### 2.1.11 Assembly Raw Material Scanner (I)

Step #                                              Task

   1    Data is scanned from container labels.
   2    Data is sent to MD.
   3    MES data is received from MD.

<!-- Page 15 -->

# 3.0 Manufacturing Director™ - System Components

## 3.1 Manufacturing Director™ - Modeling Client
         The Modeling Client allows for the flexibility of the Manufacturing Director™ system to form to
         the facilities production “model”. Flexware has base models defined that fit the typical MES track
         and trace solution but these models will be modified for each implementation.

             A production system‟s model typically does not changed after an implementation is in
             place and should not be altered unless Flexware Innovation, Inc. is consulted prior to
             any changes being made.

## 3.2 Manufacturing Director™ - Configuration Client
         The Configuration Client is used to configure the various aspects of the system. This includes, but
         is not limited to, defining users and roles, products and product families, physical plant floor
         components, and tracking components.

### 3.2.1 Configuring Product Type and Part Level
                        Example: Change D/C Part Level
                        To change the D/C Part Level of a product (e.g., from 20- -01 to 21- -)
                             1. Find and select the product you want to update in the Manufacturing
                                  Director™ Configuration Client.

<!-- Page 17 -->

2. Click the Edit button to display the product‟s properties

<!-- Page 18 -->

3. Change the D/C Part Level to 21- - and click the OK button to save the
    product.

<!-- Page 19 -->

### 3.2.2 Example: Change Product Name
         To change the name of a product (e.g., from 1243A-R70 –A020-C1 to 1243A-R70 –
         A020-C2)

              1. Find and select the product you want to update in the Manufacturing
                   Director™ Configuration Client.

<!-- Page 20 -->

2. Click the Edit button to display the product‟s properties.

<!-- Page 21 -->

3. Change the Name to 1243A-R70 –A020-C2 and click the OK button to save
    the product.

<!-- Page 22 -->

4. Find and select the Assembly Out Shop Floor Client in the Manufacturing
    Director™ Configuration Client.

<!-- Page 23 -->

5. Click the Edit button to display the shop floor client‟s properties.

<!-- Page 24 -->

6. Switch to the Components tab and select the Tracking navigation group in
    the upper left and select the Tracking Component in the lower right.

<!-- Page 25 -->

7. Click the Properties… button in the lower right.

<!-- Page 26 -->

8. Switch to the Events tab.

<!-- Page 27 -->

9. Select the BeforeStart event and click the ellipsis (…) button to the right to
    display the BeforeStart Event Handler Properties dialog.

10. In the script change 1243A-R70 –A020-C1 to 1243A-R70 –A020-C2. This
    name must match EXACTLY the name of the product as defined in the
    Configuration Client.

11. Click the OK button on the BeforeStart Event Handler Properties dialog.

12. Click the OK button on the Entity Component Editor dialog.

13. Click the OK button on the Assembly Out Shop Floor Client Properties
    dialog.

14. Perform the steps 4 – 13 for the Assembly In Shop Floor Client in the
    Manufacturing Director™ Configuration Client.

<!-- Page 28 -->

15. Open Execution Management™ Administration and expand the tree to
    see the events for the 100 – Lost Motion Spring Assembly and 200 –
    Mounting Bolt Assembly tasks under the 300 – Assembly 1 line.

<!-- Page 29 -->

16. Expand the 100 – Data Ready event under 100 – Lost Motion Spring
    Assembly and select the Actions folder.

<!-- Page 30 -->

   17. Double-click the Process Part action on the right side to display the
       properties for the action.

.

<!-- Page 31 -->

18. Switch to the Type tab.

<!-- Page 32 -->

19. Click the Edit Script button to display the Script Editor for the action.

<!-- Page 33 -->

20. Scroll down to find the product translation part of the script and update the
    desired product name. This name must match EXACTLY the name of the
    product as defined in the Configuration Client.

<!-- Page 34 -->

21. Click the OK button on the Script Editor to save the script changes.
22. Click the OK button on the Action Properties to save the action changes.
23. Repeat steps 15-21 for the 100 – Part Start event under 200 – Mounting

    Bolt Assembly.
24. Click Start then Run...
25. Type services.msc and click the OK button.

                      26. Find and right-click the Execution Management Server service.
                    27. Click Restart to restart the service and load the new configuration.

## 3.3 Manufacturing Director™ - Shop Floor Client

  The Shop Floor Client is the main interface between plant-floor operators and the system. It
  allows users to perform actions such as starting orders, entering quality data, viewing historical
  serial number information, and receiving system events.

## 3.4 Manufacturing Director™ - Dispatch Client

  The Dispatching Client is where production schedules are created and managed. Within
  production schedules, production orders (i.e., manufacturing orders) are created and dispatched to
  work centers as individual work orders.

### 3.4.1 Dispatch Client - Implementation Specific Details

            Production Schedule: There is one Production Schedule for the VCM implementation;
            “Current Schedule”. This schedule is static and currently does not change. In the future if
            the production model changes and it is desirable to produce by production schedules this
            tool would be used to manually and/or automatically manage the schedules from the
            ERP.

             The Production Schedule “Planned Start Time” and the “Planned End Time”
             must be set outside of the time of production. Since the schedule is static the
             time range is opened up to a point far in the future; 1/1/2018.

            Production Orders: There is a Production Order defined for each of the part types: Pre-
            Assembled Bridge Order, R72 Bridge Order, R70 FR Bridge Order, R70 RR Bridge
            Order. These production orders are static and do not change. In the future if the

<!-- Page 35 -->

            production model changes and it is desirable to produce by production orders this tool
            would be used to manually and/or automatically manage the schedules from the ERP.

             The Production Order “Planned Start Time” and the “Planned End Time” must
             be set outside of the time of production. Since the orders are static the time
             range is opened up to a point far in the future; 1/1/2013.
             The Production Order must be dispatched to a work center, as a Work Order,
             for part processing.

            Work Orders: Work orders are process at the Shop Floor Client.

            See Appendix E for General Use definition of the Dispatch client.

## 3.5 Execution Management Server

  Execution Management (EM) provides an interface layer between traditional business and
  Manufacturing Execution (MES) systems and manufacturing shop-floor automation systems. EM
  can be configured to react to changes in shop-floor automation system information from, for
  example, PLCs, barcode readers, and RFID tag readers, to provide configurable intelligent
  execution. EM accepts automation input, in the form of OPC events, from one or more OPC
  servers and responds to those events in such a way as is configured via the Administration
  Console (EMAdmin) and monitored via the Management Console (EMMgr). These tools are
  available via “Start>All Programs>Flexware Innovation>Execution Management”.

## 3.6 Manufacturing Director™ Security

  Manufacturing Director™ security uses locally defined security accounts and Microsoft network
  Active Directory user groups. The local and network roles and users are defined below.

  Manufacturing Director™ Roles:

  The following Manufacturing Director™ roles are required for the current solution.

            Administrator
            Assembly Area Operators
            Assembly Area Supervisors
            Background Processors
            Casting Area Operators
            Casting Area Supervisors
            Machining Area Operators
            Machining Area Supervisors
            Modelers
            Report Viewer
            Schedulers

  Local User Accounts:

  The following local user accounts can be used instead of the Active Directory user accounts:

<!-- Page 36 -->

          Name                                                User Name     Password
      Administrator                                          Administrator  password
 Assembly Operator 1
Assembly Supervisor 1                                             AO1           ao1
   Casting Operator 1                                             AS1           as1
 Casting Supervisor 1                                             CO1           co1
 Machining Operator 1                                             CS1           cs1
Machining Supervisor 1                                            MO1          mo1
       ReportUser                                                 MS1          ms1
                                                              ReportUser    reportuser

### 3.6.1 Active Directory User Groups and User Roster

         In order to add and remove users from the Active Directory Users Groups contact IT and
         tell them the User Name and what Active Directory Group they are to be added to or
         removed from.

         MES-Operators – Active Directory Group
             Users:
                   <no users in this group at this time>

         MES-Supervisors – Active Directory Group
             Users:
                   Jeremy Lauderbaugh
                   David Ward
                   Rob McIntosh
                   Arun Viswanathan
                   Kevin Parker
                   Brandy Douglas
                   Brandy Jones

         MES-ReportUser – Active Directory Group
             Users:
                   Tomoyuki Ueno
                   Brandi Owens

         MES-Administrator – Active Directory Group
             Users:
                   Russell Cosby

Note: See Appendix: “17.0 Configuring Users” for a general description of configuration user
accounts.

<!-- Page 38 -->

## 3.7 Manufacturing Director Reporting

       Manufacturing Director™ reporting utilizes SQL Server Reporting Services as the
       environment to host reports which are accessible to any computer on the organizations LAN.
       Users must have an Manufacturing Director™ security account or must have their Windows
       user account placed in the “MES-ReportUser” domain group managed by IT.

       The reports available are:

                 Supply Part Reports – Queried by a specified Date Time range

                 Tool Change Report – Queried by a specified Date Time range

                 Tracking Reports (Container and Genealogy/Serial Number) – Queried by the
                 specific Container or Serial Number

       Access the reports by following this link:

        http://192.168.1.153/ManufacturingDirector/Reports/Default.aspx

       The IPAddress 192.168.1.153 is the Manufacturing Director™ server,
       “FLEXWARE_SERVER”.

<!-- Page 39 -->

## 3.8 Raw Material Mobile Scanning
### 3.8.1 Start Application

                                                                From the Start menu, click the
                                                                 Supply Part Inventory link to

                                                                       start the application.

                                                             This button begins the process of
                                                             allocating additional materials to

                                                                  the supply part inventory.

                                                             This button begin the process of
                                                                 looking up information on

                                                               existing supply part inventory
                                                                             records.

The File menu gives an „exit‟
option to allow the program to

             be closed.

                                                                      .

<!-- Page 40 -->

### 3.8.1 Look Up Supply Part Inventory Material Information

                                                                Enter information into some, all, or none of the fields. If
                                                                 some or all of the fields are entered, the results will be
                                                                limited by the information given. If none of the fields are
                                                                entered, then all results will be returned. The bar code
                                                                  scanner can be used, where possible, to enter data.
                                                                 Note: only „Active‟ and “Queued‟ results are returned.

                                                                       Press the Search button to find data based
                                                                                     on the entered criteria.

                                                                       The Clear button will clear all fields of data.

                                                                        The Menu button will return the program
                                                                                       to the main menu.

   Results from searching are displayed here. Each box
    contains an individual record and can be selected to
  have its details viewed. Note the orange border on the
   selected record. If there are no results based on the

       search criteria, the no results will be displayed.

          Clicking on an individual field allows its
     information to be viewed, in case that field is to

              long to be viewed on a single line.

          Click the Details button to view the selected
                         record‟s information.

                                                                     Record details are displayed here.

                                                                  Clicking on an individual field allows its
                                                             information to be viewed, in case that field is to

                                                                     long to be viewed on a single line.

                                                               Press the Back button to return to the previous
                                                              screen and view additional records, or press the

                                                                   Menu button to return to the main menu.

<!-- Page 41 -->

### 3.8.2 Allocate Supply Part Inventory Materials

                                                             Enter appropriate information into all of the fields, using
                                                                the barcode scanner where possible. Note: at this
                                                               point, the Part Number data is expected to be in the

                                                            format that the barcode stores the information. There is
                                                              another internal step that makes the transformation of
                                                              the format. It is highly suggested to use the barcode

                                                                          scanner to enter this piece of data.

                                                               Press the OK button to continue with allocating
                                                                these materials into the supply part inventory.

                                                                  Review the information before making the
                                                              allocation. Notice the transformed format of the

                                                                    Part Number from the previous format.

                                                                     Clicking on an individual field allows its
                                                                information to be viewed, in case that field is to

                                                                         long to be viewed on a single line.

                                                                  Press the Allocate to make the allocation
                                                                 of materials into the supply part inventory.

<!-- Page 42 -->

### 3.8.3 Error – No Search Results Displayed

                                                              No search results displayed. This is the case
                                                             that no results were found for the given search
                                                              criteria. The solution is to change the search

                                                               criteria to be correct, or it could be the case
                                                                that there simply are no results to display.

                                                    Error Finding Location

                                                              Error finding location. The location information
                                                              entered does not match the location “Short
                                                          Name” configured in Manufacturing Director™.
                                                              Enter the correct location information into the
                                                              field and try again.

<!-- Page 43 -->

### 3.8.4 Error – Invalid Part Number

                                                                      Invalid Part Number entered or Part Number
                                                                          not valid for given Location/Equipment.
                                                                         Contact your system administrator if you
                                                                                   believe this to be in error.

<!-- Page 44 -->

### 3.8.5 Barcode Scanner Ceases to Function

 If the barcode scanner ceases to function during normal operation of the software, try returning to
 the Main Menu and begin again from there. The software should reinitialize the barcode reading
 capabilities.

                                                 Error Connecting to Server

                                                                An error occurred while attempting to
                                                               connect to the server. Check network
                                                             connectivity and configuration information
                                                                in the application‟s configuration file.

<!-- Page 45 -->

## 3.9 Server Installation Details (FLEXWARE_SERVER)
  Typically if something critical happens to the Manufacturing Director™ server installation it
  would be rebuilt from system backups and a step by step installation process would not be
  required.

### 3.9.1 Base System
                           Microsoft Windows 2003 Server
                           Microsoft SQL Server 2005 w/Reporting Services
                           IIS Installed and Enabled

### 3.9.2 Restore System and EMMD Databases
                 Depending upon the extent in which the system needs recovered the following
                 databases may need to be restored:
                           “master”
                           “msdb”
                           “EMMD”
                           “ReportServer”
                           Get latest full database backups of these databases from the Manufacturing
                           Director™ Server or from IT file backups
                           Restored the database backup files as required
                                o EMMD database transaction logs may need to be recovered in
                                    addition to the database backup to get back to the closest point in
                                    time if needed.
                                o Run „EMMD Schema Logins - Users - Permissions.sql‟ against
                                    EMMD database

### 3.9.3 Update Log Paths
                      Verify that the folder %MD%\Logs exists
                      Using notepad, open
                           %MD%\Flexware.ExecutionManagement.Agent.Server.exe.config
                      Locate „appSettings/LogDirectory‟
                      Modify value: enter fully expanded, absolute path to %MD%\Logs
                      Save (and close) notepad

<!-- Page 46 -->

              Restart service: Execution Management Server Agent (may not be available yet)
              Using notepad, open

                   %MD%\ Flexware.ExecutionManagement.MessageRouter.Server.exe.config
              Locate „appSettings/RouterLogDirectory„
              Modify value: enter fully expanded, absolute path to %MD%\Logs
              Save (and close) notepad
              Restart service: Execution Management Message Router

### 3.9.4 Restore Reporting Files
         Restore implementation specific reporting RDL files. This is done through Reporting
         Services. Do not attempt this unless familiar with reporting services.

### 3.9.5 Install EM Agent Service
              Open „Command Prompt‟ from Start | All Programs | Accessories
              Navigate to %MD% directory
                   Verify presence of Flexware.ExecutionManagement.Agent.Server.exe
              Use InstallUtil to install service:
                   c:\windows\microsoft.net\framework\v2.0.50727\installutil
                   Flexware.ExecutionManagement.Agent.Server.exe
              Watch for “The Commit phase completed successfully” and „The transacted
              install has completed” messages.

### 3.9.6 Install MXOPC Server
              Install MX OPC Server from media
              Restore the MXOPC Server configuration file:
              “MXConfiguratoe_2008_630_01.mdb (or the most recent configuration file)

### 3.9.7 Install InSight OPC Server
              Install MX OPC Server from media
              Restore the MXOPC Server configuration file:
              “MXConfiguratoe_2008_630_01.mdb (or the most recent configuration file)

<!-- Page 47 -->

## 3.10 Database Maintenance

### 3.10.1 Maintenance Plans and Jobs
                 The Maintenance Plans are configured through Microsoft SQL Server Management
                 Studio.

#### 3.10.1.1 Overview

The MPP solution has two Maintenance Plans:

EMMD Backups – handles full and transaction log backups of the EMMD database.
In addition to providing more granular disaster recovery, frequent transaction log
backups keep the transaction log file from growing excessively large.

The EMMD Backups Maintenance Plan also backs up the “master”, “msdb”, and
“ReportServer” databases.

The configuration of these maintenance plans is stored in the “msdb” database.

<!-- Page 48 -->

EMMD Purge – handles deletion of production-related log data that is stored in the
EMMD database. There are two such log tables: Log_Event, which records all
events received from the shop floor, and Log_Action , which records all responses to
those events. These tables should be purged on a regular basis to prevent the data file
from growing excessively large. The information is useful for system debugging, so
it is recommended that at least a month of this data be retained.

#### 3.10.1.2 Scheduling

This section contains conceptual and detailed information. While conceptual
information should be accurate, the detailed information (specific times and
reoccurrence schedules) could change outside of this document. Reference the
Maintenance Plans in SQL Server and their respective jobs in SQL Server Agent for
up-to-date information.

New maintenance plan schedules are best created inside the maintenance plan.
Existing maintenance plan schedules can be edited inside the maintenance plan, or by
modifying the SQL Agent job itself.

EMMD Backups – This maintenance plan has two sub-plans: a Full Backup sub-
plan and a Transaction Log Backup sub-plan.

The full backup (EMMD Backups.Full Backup) is scheduled to run daily, at
10:00pm. This yields one self-contained BAK file, per day, which can be used to
restore to up to the last 10:00pm. There is nothing particular about 10:00pm. Any
time when production is at a minimum is sufficient.

The transaction log backup (EMMD Backups .Transaction Log Backup) is scheduled
to run hourly, for every hour except 10:00pm. This yields one TRN file, per hour (23
per day) which can be used to restore up to any given hour. There is nothing
particular about 1 hour. Business requirements must determine the interval. The
frequency of transaction backup directly affects:

         File size: more often means small log file

         Duration: more often means quicker backup

         Impact: more often means less work each backup and reduced effect on
         performance

         Recovery: more often means more granular recovery and less data loss

         Ease of recovery: more often means more files to restore during recovery

<!-- Page 49 -->

Regardless of the frequency, be sure to skip the interval when the full backup is
executing.

Please see SQL Server documentation or MSDN Library for more information on
backup strategies.

EMMD Purge – This maintenance plan is scheduled to run at 9:30pm. There is
nothing particular about 9:30pm, other than it is just before the full backup. Since the
purge is deleting the oldest data (which has already been backed-up many times) it
can occur before the full backup, thereby reducing the backup size. As with any
purge, it should be executed during a down or off-peak time in order to reduce impact
on the live system. Breaks, shift changes, and late nights/early mornings are good
candidates.

This plan executes a stored procedure in the EMMD database. The number of days
of data to retain is passed as an argument to the stored procedure. The default is 28
days. This number may be increased if disk space allows. Reducing this number is
not recommended.

#### 3.10.1.3 Monitoring

The SQL Server Agent Job Activity Monitor (in SQL Server Management Studio)
should be used regularly to check job execution history. Any failures are out of norm
and should be investigated immediately.

#### 3.10.1.4 File Backup

The EMMD Backup maintenance plan only generates files on the local hard drive.
Other IT processes or software should be used to copy or archive the backup files to
another location.

Backup files are output to an EMMD folder in the standard SQL Server backup
location:

       C:\Program Files\Microsoft SQL Server\MSSQL.1\MSSQL\Backup

The actual database files should be excluded from any direct access by backup
software. These files are located in the standard SQL Server data location:

       C:\Program Files\Microsoft SQL Server\MSSQL.1\MSSQL\Data

#### 3.10.1.5 File Cleanup

The EMMD Backup maintenance plan (Full Backup sub-plan) handles file cleanup.
Whenever a full backup is created, any BAK or TRN files older than 4 weeks are
deleted.

The cleanup of transaction log files is handled with the full backup for usability
purposes. A TRN file without the prior backup file is useless.

<!-- Page 50 -->

There is a possibility of data loss by allowing SQL Server to handle file clean up.
Should the external process fail, SQL Server will continue to delete files that have
expired. Ideally, the external process that archives the files should somehow indicate
its success or failure. If desired, the file cleanup steps can be removed from the
maintenance plan.

<!-- Page 51 -->

# 4.0 System Details and User Accounts                         FLEXWARE_SERVER
                                                             MPPNET.com
## 4.1 Application Server                                 192.168.1.153
                                                             255.255.255.0
                  Application Server                         192.168.1.1
                  Computer Name:                             153.121.200.154
                  Domain:                                    153.121.200.21
                  IP Address:
                  Subnet Mask:                               flexware
                  Default Gateway:                           flexdogs
                  Preferred DNS Server:                      (Local) Administrators
                  Alternate DNS Server:
                  User Accounts                              FlexAdmin
                  Username:                                  flexdogs
                  Password:                                  (Local) Administrators
                  Group:
                                                             administrator
                  Username:                                  password
                  Password:                                  (Local) Administrators
                  Group:
                                                             Windows 2003 Server R2 Service Pack 2
                  Username:                                  SQL Server 2005 Service Pack 2
                  Password:                                  TOP Server v4.280.435
                  Group:                                     Mitsubishi Suite
                  Software                                   User Configurable Driver
                  Operating System:                          Build 3.2.183.0
                  Database:
                                                             C:\Flexware\Support
                  OPC Servers:
                  Manufacturing Director:                    DELLSQLSERVER
                  Support                                    153.121.200.163
                  Support Folder:                            Contact IT

## 4.2 Macola Server (ERP)                                Base2

                  Macola Server                              Assembly Out #1 (Bolt Assembly)
                  Computer Name:                             Assembly1_Out
                  IP Address:                                InSight 5100
                  SQL Server Login:                          3.40.00 (318)
                  Database                                   00-d0-24-01-ce-c7
                  Database Name:

## 4.3 Cognex Insight Cameras

                  Device:
                  Name:
                  Model Number:
                  Firmware Version:
                  MAC Address:

<!-- Page 52 -->

IP Address:                                                  192.168.1.129
Serial Number:                                               Z72236369
Monitor Version:                                             2.01
Device:                                                      Assembly Out #2 (Bolt Assembly)
Name:                                                        Assembly2_Out
Model Number:                                                InSight 5110
Firmware Version:                                            4.01.00 (226)
MAC Address:                                                 00-d0-24-02-1a-c5
IP Address:                                                  192.168.1.147
Serial Number:                                               Z81524961
Monitor Version:                                             2.03
Device:                                                      Casting #1
Name:                                                        Casting1Cognex
Model Number:                                                InSight 5110
Firmware Version:                                            3.30.01 (346)
MAC Address:                                                 00-d0-24-01-85-7d
IP Address:                                                  192.168.1.121
Serial Number:                                               Z62877921
Monitor Version:                                             2.00
Device:                                                      Casting #3
Name:                                                        Casting2Cognex
Model Number:                                                InSight 5110
Firmware Version:                                            3.40.02 (464)
MAC Address:                                                 00-d0-24-01-f1-b8
IP Address:                                                  192.168.1.139
Serial Number:                                               Z74366477
Monitor Version:                                             2.01

## 4.4 Shop Floor Clients

MD accounts aren’t documented anywhere, so you’d have to look in the MD configuration client

Device:                                                      Casting 1 Client PC
Computer Name:                                               NEO-4D5E48
Domain:                                                      WORKGROUP
IP Address:                                                  192.168.1.109
Local Username:                                              MESUser
Local Password:                                              password
Startup Group Contain                                        Shop Floor Client RDP Shortcut
RDP Terminal Session                                         MESUser
RDP Terminal Session to
FLEXWARE_SERVER UserName:                                    MD_CAST_U_1
RDP Terminal Session to
FLEXWARE_SERVER Password:                                    password
                                                             MD_CAST_U_1 user profile on FLEXWARE_SERVER contains the
User Profile Configuration                                   SFC shortcut on the desktop and in the startup group:
                                                             "C:\Program Files (x86)\Flexware Innovation\Manufacturing
Shortcut to SFC –“Target”:                                   Director\Flexware.ManufacturingDirector.ShopFloor.Client.exe"
                                                             /S:FLEXWARE_SERVER /D:EMMD /m:CASTER1 /w:f
Shortcut to SFC – “Start In”:                                "C:\Program Files (x86)\Flexware Innovation\Manufacturing
                                                             Director"

<!-- Page 53 -->

Device:                                                      Casting 2 Client PC
Computer Name:                                               NEO-4D5E66
Domain:                                                      WORKGROUP
IP Address:                                                  192.168.1.134
Local Username:                                              MESUser
Local Password:                                              password
Startup Group Contain                                        Shop Floor Client RDP Shortcut
RDP Terminal Session                                         MESUser
RDP Terminal Session to
FLEXWARE_SERVER UserName:                                    MD_CAST_U_2
RDP Terminal Session to
FLEXWARE_SERVER Password:                                    password
                                                             MD_CAST_U_2 user profile on FLEXWARE_SERVER contains the
User Profile Configuration                                   SFC shortcut on the desktop and in the startup group:
                                                             "C:\Program Files (x86)\Flexware Innovation\Manufacturing
Shortcut to SFC –“Target”:                                   Director\Flexware.ManufacturingDirector.ShopFloor.Client.exe"
                                                             /S:FLEXWARE_SERVER /D:EMMD /m:CASTER2 /w:f
Shortcut to SFC – “Start In”:                                "C:\Program Files (x86)\Flexware Innovation\Manufacturing
Device:                                                      Director"
Computer Name:                                               Machining Client PC
Domain:                                                      NEO-4D5E57
IP Address:                                                  WORKGROUP
Local Username:                                              192.168.1.110
Local Password:                                              MESUser
Startup Group Contain                                        password
RDP Terminal Session                                         Shop Floor Client RDP Shortcut
RDP Terminal Session to                                      MESUser
FLEXWARE_SERVER UserName:
RDP Terminal Session to                                      MD_MACHINING_U_1
FLEXWARE_SERVER Password:
                                                             password
User Profile Configuration                                   MD_MACHINING_U_1 user profile on FLEXWARE_SERVER
                                                             contains the SFC shortcut on the desktop and in the startup
Shortcut to SFC –“Target”:                                   group:
                                                             "C:\Program Files (x86)\Flexware Innovation\Manufacturing
Shortcut to SFC – “Start In”:                                Director\Flexware.ManufacturingDirector.ShopFloor.Client.exe"
Device:                                                      /S:FLEXWARE_SERVER /D:EMMD /m:MACHINING1 /w:f
Computer Name:                                               "C:\Program Files (x86)\Flexware Innovation\Manufacturing
Domain:                                                      Director"
IP Address:                                                  Assembly In Client PC
Local Username:                                              NEO-4D5E7E
Local Password:                                              WORKGROUP
Startup Group Contain                                        192.168.1.107
RDP Terminal Session                                         MESUser
RDP Terminal Session to                                      password
FLEXWARE_SERVER UserName:                                    Shop Floor Client RDP Shortcut
RDP Terminal Session to                                      MESUser
FLEXWARE_SERVER Password:
                                                             MD_AI_U_1

                                                             password

<!-- Page 54 -->

User Profile Configuration                                   MD_AI_U_1 user profile on FLEXWARE_SERVER contains the
                                                             SFC shortcut on the desktop and in the startup group:
Shortcut to SFC –“Target”:                                   "C:\Program Files (x86)\Flexware Innovation\Manufacturing
                                                             Director\Flexware.ManufacturingDirector.ShopFloor.Client.exe"
Shortcut to SFC – “Start In”:                                /S:FLEXWARE_SERVER /D:EMMD /m:ASSEMBLYIN1 /w:f
Device:                                                      "C:\Program Files (x86)\Flexware Innovation\Manufacturing
Computer Name:                                               Director"
Domain:                                                      Assembly Out Client PC
IP Address:                                                  NEO-4D5FC1
Local Username:                                              WORKGROUP
Local Password:                                              192.168.1.108
Startup Group Contain                                        MESUser
RDP Terminal Session                                         password
RDP Terminal Session to                                      Shop Floor Client RDP Shortcut
FLEXWARE_SERVER UserName:                                    MESUser
RDP Terminal Session to
FLEXWARE_SERVER Password:                                    MD_AO_U_1

User Profile Configuration                                   password
                                                             MD_AO_U_1 user profile on FLEXWARE_SERVER contains the
Shortcut to SFC –“Target”:                                   SFC shortcut on the desktop and in the startup group:
                                                             "C:\Program Files (x86)\Flexware Innovation\Manufacturing
Shortcut to SFC – “Start In”:                                Director\Flexware.ManufacturingDirector.ShopFloor.Client.exe"
                                                             /S:FLEXWARE_SERVER /D:EMMD /m:ASSEMBLYOUT1 /w:f
                                                             "C:\Program Files (x86)\Flexware Innovation\Manufacturing
                                                             Director"

## 4.5 Vorne Displays                                           Casting 1 Vorne
                                                             XL800
         Device:                                             192.168.1.101
         Model Number:                                       Casting 2 Vorne
         IP Address:                                         XL800
         Device:                                             192.168.1.142
         Model Number:                                       Machining Vorne 1
         IP Address:                                         XL800
         Device:                                             192.168.1.102
         Model Number:                                       Machining Vorne 2
         IP Address:                                         XL800
         Device:                                             192.168.1.103
         Model Number:                                       Machining Vorne 3
         IP Address:                                         XL800
         Device:                                             192.168.1.141
         Model Number:                                       Assembly Out 1 Vorne
         IP Address:                                         XL800
         Device:                                             192.168.1.104
         Model Number:                                       Assembly Out 2 Vorne
         IP Address:                                         XL800
         Device:                                             192.168.1.140
         Model Number:
         IP Address:
         User Accounts

<!-- Page 55 -->

         Username:                                           Supervisor
         Password:                                           porthos

         Username:                                           Administrator
         Password:                                           aragorn

## 4.6 Assembly Raw Material Scanner                            Hand Held Scanner #1
                                                             Hand Held Scanner #1
         Device:                                             Motorola MC-9090-G
         Name:                                               192.168.1.118
         Model Number:                                       Hand Held Scanner #2
         IP Address:                                         Hand Held Scanner #2
         Device:                                             Motorola MC-9090-G
         Name:                                               192.168.1.119
         Model Number:                                       Hand Held Scanner #3
         IP Address:                                         Hand Held Scanner #3
         Device:                                             Motorola MC-9090-G
         Name:                                               192.168.1.120
         Model Number:
         IP Address:                                         Assembly Out 1 Zebra Printer
                                                             Zebra 2844
## 4.7 Zebra Label Printer                                      192.168.1.144
                                                             Assembly Out 2 Zebra Printer
         Device:                                             Zebra 2844
         Model Number:                                       192.168.1.145
         IP Address:
         Device:
         Model Number:
         IP Address:

<!-- Page 56 -->

# 5.0 Casting

## 5.1 Drawings
              Refer to Drawing Documentation.

## 5.2 Architecture
              Refer to Appendix B – System Architecture.

## 5.3 Device Communication Settings

### 5.3.1 Insight Camera
                        The Insight camera is configured for Ethernet to communication the Insight OPC
                        Server. Refer to Appendix A - IP Addresses.

<!-- Page 57 -->

# 6.0 Machining

## 6.1 Drawings
              Refer to Drawing Documentation.

## 6.2 Architecture
              Refer to Appendix B – System Architecture.

## 6.3 Device Communication Settings

### 6.3.1 Machining PLC (FX3U)
                        PLC communication is configured for Ethernet communication. Refer to Appendix
                        A - IP Addresses.

Serial Port Settings                                         Settings

Communication Type                                           Serial
Baud Rate                                                    19.2
Data Bits                                                    8
Stop Bits                                                    1
Parity                                                       None

### 6.3.2 DM 7500 Hand Held Scanner

         The DM100 fixed scanner is configured to send Serial Number data to the Machining
         FX PLC thru the serial port on the GOT 1020.

Parameter                                                    Settings

Communication Type                                           Serial
Baud Rate                                                    19.2
Data Bits                                                    8
Stop Bits                                                    1
Parity                                                       None

<!-- Page 58 -->

# 7.0 Line 1 Assembly

## 7.1 Drawings
              Refer to Drawing Documentation.

## 7.2 Architecture
              Refer to Appendix B – System Architecture.

## 7.3 Process Data Flow

### 7.3.1 Assembly Cir-Clip
                        Refer to Appendix D – Process Data Flow Diagram (Assembly In).

### 7.3.2 Assembly (Lost Motion)
                        Refer to Appendix D – Process Data Flow Diagram (Assembly In).

### 7.3.3 Assembly Out (Bolt Assembly)
                        Refer to Appendix C – Process Data Flow Diagram (Assembly Out).

## 7.4 Device Communication Settings

### 7.4.1 Assembly Cir-Clip

#### 7.4.1.1 Cir-Clip PLC (A Series)
                        PLC communication is configured for Ethernet communication. Refer to Appendix
                        A - IP Addresses.

#### 7.4.1.2 DM 100 Fixed Scanner
                        The DM100 fixed scanner is configured to send Serial Number data to the Cir-Clip
                        PLC (FX3U) thru the serial port.

Serial Port Settings                                         Settings

Communication Type                                           Serial
Baud Rate                                                    9600
Data Bits                                                    8
Stop Bits                                                    1
Parity                                                       None

<!-- Page 59 -->

7.4.1.3 GOT 940
The Cir-Clip GOT 940 is only configured to monitor data from the Cir-Clip PLC.

#### 7.4.1.4 Cir-Clip PLC (FX3U)
PLC communication is configured for Ethernet communication. Refer to Appendix
A - IP Addresses.

Serial Port Settings                                         Settings

Communication Type                                           Serial
Baud Rate                                                    9600
Data Bits                                                    8
Stop Bits                                                    1
Parity                                                       None

### 7.4.2 Assembly In (Lost Motion)

#### 7.4.2.1 Lost Motion PLC (Q Series)

PLC communication is configured for Ethernet communication. Refer to Appendix
A - IP Addresses.

#### 7.4.2.2 DM 100 Fixed Scanner

The DM100 fixed scanner is configured to send Serial Number data to the PLC thru
the GOT1000 serial port.

Serial Port Settings                                         Settings

Communication Type                                           Serial
Baud Rate                                                    9600
Data Bits                                                    8
Stop Bits                                                    1
Parity                                                       None

#### 7.4.2.3 DM 7500 Hand Held Scanner

Parameter                                                    Settings
Communication                                                USB

#### 7.4.2.4 GOT 1000                                             Settings

 Serial Port Settings                                        Serial
 Communication Type                                          9600
 Baud Rate                                                   8
 Data Bits                                                   1
 Stop Bits

<!-- Page 60 -->

Parity                                                       None

### 7.4.3 Assembly Out (Bolt Assembly)

#### 7.4.3.1 Bolt Assembly PLC (Q Series)

PLC communication is configured for Ethernet communication. Refer to Appendix
A - IP Addresses.

#### 7.4.3.2 InSight Camera                                       Settings

 Parameter                                                   Serial
 Communication Type                                          9600
 Baud Rate                                                   8
 Data Bits                                                   1
 Stop Bits                                                   None
 Parity

#### 7.4.3.3 DM 7500 Hand Held Scanner

Parameter                                                    Settings
Communication                                                USB

<!-- Page 61 -->

# 8.0 Line 2 Assembly

## 8.1 Drawings
              Refer to Drawing Documentation.

## 8.2 Architecture
              Refer to Refer to Appendix B – System Architecture.

## 8.3 Process Data Flow

### 8.3.1 Assembly Cir-Clip
                        Refer to Appendix D – Process Data Flow Diagram (Assembly In).

### 8.3.2 Assembly Out (Bolt Assembly)
                        Refer to Appendix C – Process Data Flow Diagram (Assembly Out).

## 8.4 Device Communication Settings

### 8.4.1 Line 2 Main PLC (Q Series)
                        Refer to Appendix A - IP Addresses.

### 8.4.2 Assembly In (Cir-Clip)

#### 8.4.2.1 Cir-Clip PLC (Q Series)
                        PLC communication is configured for MelSec Network thru Ethernet communication
                        on the Line 2 Main PLC.

Parameter                                                    Settings
MELSEC Network                                               3
Station Number                                               2

#### 8.4.2.2 DM 100 Fixed Scanner

The DM100 fixed scanner is configured to send Serial Number data to the PLC thru
the GOT1000 serial port.

Serial Port Settings                                         Settings
Communication Type                                           Serial

<!-- Page 62 -->

Baud Rate                                                    9600
Data Bits                                                    8
Stop Bits                                                    1
Parity                                                       None

#### 8.4.2.3 GOT 1000                                             Settings

 Serial Port Settings                                        Serial
 Communication Type                                          9600
 Baud Rate                                                   8
 Data Bits                                                   1
 Stop Bits                                                   None
 Parity

### 8.4.3 Assembly Out (Bolt Assembly)

#### 8.4.3.1 Bolt Assembly PLC (Q Series)

PLC communication is configured for MelSec Network thru Ethernet communication
on the Line 2 Main PLC.

Parameter                                                    Settings
MELSEC Network                                               3
Station Number                                               8

#### 8.4.3.2 DM 7500 Hand Held Scanner

Parameter                                                    Settings
Communication                                                USB

#### 8.4.3.3 Insight Camera                                       Settings

 Parameter                                                   Serial
 Communication Type                                          9600
 Baud Rate                                                   8
 Data Bits                                                   1
 Stop Bits                                                   None
 Parity

<!-- Page 63 -->

# 9.0 Device Configuration

## 9.1 Cognex In-Sight Sensor
              The following job files are loaded on startup into the Cognex In-Sight Sensors using the In-
              Sight Explorer 3.3.2 Software.

                         File Name                                            Location

Casting1Cognex.job                                           Casting Line 1
Casting2Cognex.job                                           Casting Line 2
Assembly1_Out.job                                            Assembly Out - Line 1
Assembly2_Out.job                                            Assembly Out - Line 2

Source Code is to be backed up and maintained by Madison Precision.

## 9.2 DataMan 100 Fixed Scanner

       The following configuration files are loaded into the Cognex DataMan ID Readers using the
       DataMan 3.1.0 Setup Tool.

                         File Name                                            Location
Assembly1_DataMan.cfg                                        Assembly In - Line 1
Assembly2_DataMan.cfg                                        Assembly In – Line 2

Vision Sensor Source Code is to be backed up and maintained by Madison Precision.

### 9.2.1 Load Configuration File
         To configure the DataMan 100 fixed scanners:
                   Connect the DM100 to the PC via the USB Communications cable
                   Open Start | All Programs | Cognex | DataMan Setup Tool v3.1.0 | Setup
                   Tool
                   Click Scan Ports to find the correct port information
                   Click Connect

The “Status” icon should now display “Connected” and menu items will
display in the left pane.

<!-- Page 64 -->

                   Select File | Open Configuration
                   Select System | Save settings
                   Select Connect To Reader in left window
                   Click on Disconnect
                   Disconnect USB Communications cable from DM100

### 9.2.2 Modify Device Settings
         To configure the DataMan 100 fixed scanners:
                   Connect the DM100 to the PC via the USB Communications cable
                   Open Start | All Programs | Cognex | DataMan Setup Tool v3.1.0 | Setup
                   Tool
                   Click Scan Ports to find the correct port information
                   Click Connect

                           The “Status” icon should now display “Connected” and menu items will
                           display in the left pane.
                           To modify device setting, click on menu selections on left pane and change
                           desired parameters.
                           Select System | Save settings
                           Select Connect To Reader in left window
                           Click on Disconnect
                           Disconnect USB Communications cable from DM100

## 9.3 DataMan 7500 – Handheld Scanner (Machining)
       To Reset the DM7500 Handheld scanner to default settings, scan the “Reset” configuration
       code followed by the “Configure” code located by the hand scanners at all three lines at
       Machining station.

### 9.3.1 Load Configuration File
                 To configure the DataMan 7500 Handheld scanners:

<!-- Page 65 -->

Connect the DM7500 to the PC via the RS232 Communications cable
Open Start | All Programs | Cognex | DataMan Setup Tool v3.1.0 | Setup
Tool
Click Scan Ports to find the correct port information
Click Connect

                   The “Status” icon should now display “Connected” and menu items will
                   display in the left pane.
                   Select File | Open Configuration
                   Select System | Save settings
                   Select Connect To Reader in left window
                   Click on Disconnect
                   Disconnect USB Communications cable from DM7500

### 9.3.2 Modify Device Settings
         To configure the DataMan 7500 Handheld scanners:
                   Connect the DM7500 to the PC via the RS232 Communications cable
                   Open Start | All Programs | Cognex | DataMan Setup Tool v3.1.0 | Setup
                   Tool
                   Click Scan Ports to find the correct port information
                   Click Connect

The “Status” icon should now display “Connected” and menu items will
display in the left pane.

To modify device setting, click on menu selections on left pane and change
desired parameters.

<!-- Page 66 -->

                           Select System | Save settings
                           Select Connect To Reader in left window
                           Click on Disconnect
                           Disconnect USB Communications cable from DM7500

## 9.4 GOT 1000/1020 HMI Display
       To configure the serial port setting on the GOT HMI displays:

### 9.4.1 Upload Application
                           Open Start | All Programs | Melsoft Application | GT Designer2
                           Select Open
                           Browse to GOT project application
                           Click Open
                           Connect to GOT display using the USB communication cable
                           Select Communication | To/From GOT
                           Select Project Upload -> Computer
                           Select Get Lastest
                           Select Upload
                           Select Project | Save As to save current backup of GOT application

### 9.4.2 Download Application Changes
                           Make Application changes
                           Connect to GOT display using the USB communication cable
                           Select Communication | To/From GOT
                           Select Project Download -> GOT
                           Select modified items in project tree
                           Select Download
                           Select Close
                           Select Project | Save As to save current backup of GOT application

<!-- Page 67 -->

## 9.5 GOT 940 HMI Display
       To configure the serial port setting on the GOT HMI displays:

### 9.5.1 Upload Application
                   Open Start | All Programs | Melsoft Application | GT Designer2
                   Select Open
                   Browse to GOT project application
                   Click Open
                   Connect to GOT display using the Serial communication cable
                   Select Communication | To/From GOT
                   Select Project Upload -> Computer
                   Select Get Lastest
                   Select Upload
                   Select Project | Save As to save current backup of GOT application

### 9.5.2 Download Application Changes
                   Make Application changes
                   Connect to GOT display using the Serial communication cable
                   Select Communication | To/From GOT
                   Select Project Download -> GOT
                   Select modified items in project tree
                   Select Download
                   Select Close
                   1111Select Project | Save As to save current backup of GOT application

## 9.6 FX3U PLC

       The FX Configurator-EN application is used to view and make changes to the Ethernet
       module communication settings.

### 9.6.1 Load Ethernet Configuration File
                   Open Start | All Programs | MelSoft Application | FX Configurator-EN
                   Select Open | File

<!-- Page 68 -->

                   Browse to configuration file location
                   Click Open
                   Click Transfer Setup
                   Select connecting interface settings
                   Click OK
                   Click Write

### 9.6.2 Modify Device Ethernet Settings
                   Open Start | All Programs | MelSoft Application | FX Configurator-EN
                   Click Transfer Setup
                   Select connecting interface settings
                   Click Read
                   Modify desired device settings: Operational Settings (PLC IP Address) or
                   Open Settings (Configure TCP connections)
                   Click Write
                   Select File | Save

## 9.7 Vorne XL800 Display Board
       The Vorne XL800 display board must be properly configured to conform to pre-defined
       standards and formats. This is done by exporting configuration files from existing displays
       and importing the file into a display that is un-configured.
       Note: The XL800 must be using a firmware version of 3.0 or greater in order to be able
       to export a configuration file. Instructions on upgrade the device firmware is outlined
       in section 4.8.1.3.

### 9.7.1 Importing Configuration Files
                           Open a standard web browser

                           Enter the IP address into the web browser address bar http://192.168.1.xxx/

                           Click Login

                           Select Administrator from drop down list

                           Enter password

                           Click Log In

<!-- Page 69 -->

Click Communication | More Options
Click Import Configuration
Locate and import .xml configuration file
Click Production Monitor to view current data

### 9.7.2 List of Existing Configuration Files

The following configuration files are pre-loaded into the designated Vorne XL
display boards.

File Name                                                    Location

“XL_Configuration_Casting.xml”                               Casting Lines 1 and 2
“XL_Configuration_Assembly.xml”                              Assembly Out Lines 1 and 2
“XL_Configuration_Machining.xml”                             Machining Lines 1, 2 and 3

### 9.7.3 Exporting Configuration Files
                   Open a standard web browser
                   Enter the IP address into the web browser address bar http://192.168.1.xxx/
                   Click Login
                   Select Administrator from drop down list
                   Enter password
                   Click Log In
                   Click Communication | More Options
                   Click Export Configuration to File
                   Choose name and location for .xml file

### 9.7.4 Update Firmware to XL Release 3.0
         Firmware will only need to be done updated if the firmware of the device is older
         than 3.0. Current device firmware is displayed when the device is rebooted.
                   Load the XL Tools CD in the CD-ROM drive
                   Click Firmware Update
                   Run Update XL Firmware to Release 3.bat
                   Enter IP Address
                   Click Enter
                   Click Enter to start the update

<!-- Page 70 -->

## 9.8 In-Sight OPC Server
       The Cognex In-Sight OPC Server 4.1.0 is used for EM communication with the In-Sight
       Sensors located at Casting Lines 1 and 2. Changes can be made to the configuration of the
       server by opening the “Configuration Editor” by clicking the icon in the Server tab.

       The currently configured sensors will be displayed in the Configuration Editor and their
       respective OPC tags. Although both sets of OPC tags have the same tag name, they are only
       configured to one Cognex Sensor and its IP address. Below is the list of configured tags for
       each sensor and what they will look like during normal conditions.

## 9.9 Mitsubishi OPC Server

       The Mitsubishi OPC Server is used for EM communications with PLCs located in Machining
       and Assembly. Each PLC location corresponds to a unique device name in the OPC server
       with its own OPC tags. All changes to the Mitsubishi OPC Server is made by using the
       MXConfigurator software with the database of “MXConfiguratoe_2008_630_01.mdb”.

### 9.9.1 Running the Server

                 The Mitsubishi OPC Server is configured to go into mode on startup and to use the
                 “MXConfigurator_2008_630_01.mdb” database file. The play, stop, and light bulb
                 icons located in the menu bar provide indication for the current server state. The
                 green arrow will be depressed when the server is in run mode. The red square will be
                 depressed when the server is stopped. No communication between the Server and
                 PLCs will take place when the server is stopped. The light bulb is depressed to make
                 the current database active for the server. Finally, the glasses icon is used to monitor
                 OPC tags. Select the desired device to monitor and click the glasses icon. The OPC
                 tags will be displayed below.

<!-- Page 71 -->

### 9.9.2 Devices
         Below is a list of the devices that are configured in the Mitsubishi OPC Server.

#### 9.9.2.1 Adding a New Device
         New devices can be created in the MXConfigurator tool by right-clicking in the
         window and selecting “New MX Device”.

         Clicking this option will open the Communication Setting Wizard. The Wizard is
         used to configure the communication parameters for both the PC and PLC side.
### 9.9.3 Tags
         Once a device is created, OPC tags need to be added to send/receive data to the PLC.
         Shown below are the tags that have been configured for the L1_Machining device.
         Many attributes need to be selected while adding new tags such as PLC address,
         Access Rights, Data Type, and Polling Method. The tags shown below demonstrate
         typical tag properties for all PLC devices.

#### 9.9.3.1 Adding a New Tag

New tags can be created in the MXConfigurator tool by right-clicking in the window
and selecting “New DataTag”.

<!-- Page 72 -->

Clicking this option will open the Tag Properties Window. The window is used to
configure the parameters associated with the tag such as I/O Address and Data Type.

## 9.10 Zebra Label Printer

       The zebra label template is located in the Manufacturing Director™ program folder. Changes
       to the label are to be made with a ZPL editor (i.e., Loftware).

       Refer to the Zebra Manuals for more information regarding printer setup and configuration of
       network settings.

<!-- Page 73 -->

# 10.0 Tools And Software

       The following tools and software are available and needed to make modifications or to monitor
       devices on the line:

Device                                                       Tools and Software
DM100                                                        DataMan Setup Tool v3.1.0
DM7500                                                       DataMan Setup Tool v3.1.0
Insight Camera                                               In-Sight Explorer 3.3.2

Vorne XL800                                                  Web Browser (Microsoft Internet Explorer 6, Microsoft
                                                             Internet Explorer 7, or Mozilla Firefox 2. Although
GOT 940                                                      Internet Explorer 6 is supported, it is not recommended, as
GOT 1000                                                     performance is substantially improved with Internet
GOT 1020                                                     Explorer 7.)
A Series PLC                                                 GT Designer2 v2.77F
Q Series PLC                                                 GT Designer2 v2.77F
FX3U PLC                                                     GT Designer2 v2.77F
                                                             GX Developer v8.55H
                                                             GX Developer v8.55H
                                                             GX Developer v8.55H
                                                             FX Configurator-EN v1.00 (Ethernet IP Configuration)

<!-- Page 74 -->

# 11.0 Support

       Flexware Innovation, Inc. offers high-quality technical support. If you have a question, please
       contact us at:
       Flexware Innovation, Inc.
       9128 Technology Lane
       Fishers, IN 46038

        Office: 317-813-5400
        Fax: 317-813-2121
        http://www.flexwareinnovation.com

       Services and prices are subject to Flexware‟s then current prices, terms and conditions and are
       subject to change without notice.

Flexware Innovation, Inc.  Reference SOP ENG0025_Template_TechUserManual.doc
9128 Technology Ln.
Indianapolis, IN 46038
Office: (317) 813-5400
Fax:(317) 813-2121

<!-- Page 75 -->

# 12.0 Appendix A – IP Addresses

Area         Name                                            Line # MAC Address          IP Address
Lost Motion  LEP                                                                         153.121.200.192
Lost Motion  LEP Printer                                            1                    153.121.200.193
Casting      Casting Vorne XL                                       1                    192.168.1.101
Machining    Maching Vorne XL #1                                    1                    192.168.1.102
Machining    Maching Vorne XL #2                                    1                    192.168.1.103
Assembly     Assy Vorne XL                                                               192.168.1.104
Assembly     Cisco Access Point                                     1                    192.168.1.105
Assembly     Assy Comtrol                                           1                    192.168.1.106
Assembly     Assy OIT 1                                             1                    192.168.1.107
Assembly     Assy OIT 2                                             1                    192.168.1.108
Casting      Casting OIT 1                                          1                    192.168.1.109
Machining    Machining OIT 1                                        1 00:30:DE:01:43:33  192.168.1.110
Casting      Casting GB #1                                          1 00:30:DE:01:43:80  192.168.1.111
Machining    Machining GB 1                                         1 00:30:DE:01:41:67  192.168.1.112
Machining    Machining GB 2                                         1                    192.168.1.113
Assembly     Cir Clip FX                                            1 00:30:DE:01:43:25  192.168.1.114
Assembly     Assy GB #2                                             1                    192.168.1.115
Assembly     Assy LEP                                               1                    192.168.1.116
Assembly     Assy LEP Printer                                       1                    192.168.1.117
Assembly     Hand Held #1                                           1                    192.168.1.118
Assembly     Hand Held #2                                           1                    192.168.1.119
Assembly     Hand Held #3                                           1                    192.168.1.120
Casting      Cognex Camera                                          1                    192.168.1.121
Assembly     C-Clip OIT Lantronix                                   1                    192.168.1.122
Assembly     Washer OIT Lantronix                                   1                    192.168.1.123
Casting      Casting OIT Lantronix                                  1                    192.168.1.124
Casting      Data Collection Lantronix                              1                    192.168.1.125
Machining    Machining OIT Lantronix                                2                    192.168.1.126
Machining    Machining FX PLC                                       1                    192.168.1.127
Machining    Machining FX PLC                                       1                    192.168.1.128
Assembly     Bolt Install Cognex                                    1                    192.168.1.129
Assembly     Assy C-Clip PLC                                        1                    192.168.1.130
Assembly     Assy Main PLC                                          1                    192.168.1.131
Assembly     Assy Bolt PLC                                          1                    192.168.1.132
Casting      Repair OIT Lantronix                                                        192.168.1.133

<!-- Page 76 -->

Casting      Repair OIT                                      1                      192.168.1.134
R70          LEP                                                 00:30:DE:01:C2:8A  192.168.1.135
R70          LEP Printer                                                            192.168.1.136
Thermo Case  LEP                                                 00:30:DE:01:37:CE  192.168.1.137
Thermo Case  LEP Printer                                                            192.168.1.138
Casting      Cognex Camera                                   2                      192.168.1.139
Assembly     Bolt Assembly (out) Vorne XL                    2                      192.168.1.140
Machinning   OP30 Vorne XL                                   2                      192.168.1.141
Casting      Casting 2 Vorne XL                              2                      192.168.1.142
Spare        Spare                                                                  192.168.1.143
Assembly     Assembly Out Zebra Printer                      1                      192.168.1.144
Assembly     Assembly Out Zebra Printer                      2                      192.168.1.145
Spare        Spare                                                                  192.168.1.146
Assembly     Assembly Out Cognex Camera                      2                      192.168.1.147
Machining    Maching FX #3                                   3                      192.168.1.148
Spare        Spare                                                                  192.168.1.149
Assembly     Assembly Line Main PLC                          2                      192.168.1.150
Spare        Spare                                                                  192.168.1.151
Spare        Spare                                                                  192.168.1.152
Server       Flexware Server                                                        192.168.1.153
Spare        Spare                                                                  192.168.1.154
Spare        Spare                                                                  192.168.1.155

Highlighted IP Addresses could not be found with a network ping. These items were offline or no longer
exist in the system.

<!-- Page 77 -->

# 13.0 Appendix B – System Architecture

Flexware Server                            Line 2 Casting                                                                                                                                                                                                                Machining
IP: 192.168.1.153

       Manufacturing
       Director (MD)
       Insight OPC
       MX OPC
       GX Developer
       GT Designer2

                                                                                                                                                VORN                                                  VORN                                                  VORN
#### 192.168.1.102 192.168.1.103                                         192.168.1.141

                                                                                                                                               OP30-1                                                OP30-2                                                OP30-2

                                                           Hand-Held  Hand-Held                    GOT 1020                                               GOT 1020                                              GOT 1020
                                                            Scanner    Scanner
                                 Insight        VORN        DM7500     DM7500                                  Serial  Serial  Hand-Held                              Serial  Serial  Hand-Held                             Serial  Serial  Hand-Held
                                Camera     192.168.1.142                                                                        Scanner                                                Scanner                                               Scanner
                   Servers  192.168.1.139                    Casting  Machining                       Deburr 1                  DM7500                       Deburr 2                  DM7500                      Deburr 1                  DM7500
Ethernet Network                              Casting 2     Terminal   Terminal                    192.168.1.128                                          192.168.1.127                                         192.168.1.148

                                                                                                        FX3U                                                   FX3U                                                  FX3U

                                 Insight        VORN                  Assembly In                        Main               CClip                 Bolt                   VORN                          Main                                      VORN
                                Camera     192.168.1.101                Terminal                   192.168.1.131       192.168.1.130       192.168.1.132            192.168.1.104                192.168.1.150                              192.168.1.140
#### 192.168.1.121 Assembly Out                                                            Assembly Out
                                              Casting 2                Hand-Held                      Series Q            Series A            Series Q                                              Series Q
                                                                        Scanner
                                                                        DM7500                                                 GOT 940     GOT 1100

                                                                                                                             CClip              Insight
#### 192.168.1.114 Camera
                                                                                                                                           192.168.1.129
                                                                                                                            FX3U
                                                                                                                                           Zebra Printer
                                                                                                                                   Serial  192.168.1.144

                                                                                                                       Fixed Scanner
                                                                                                                           DM100

                                           Line 1 Casting

                                                                      Assembly Out                 MELSEC Network 1                        GOT 1100       Serial Fixed Scanner                   MELSEC Network 3                   GOT 1100  Serial Fixed Scanner
                                                                         Terminal                                                                                         DM100                                                     GOT 1100                  DM100
                                                                                                                 LostMotion                                                                                        CClip
                                                                        Hand-Held                                 Station 2                                                                                     Station 2                                      Insight   Zebra Printer
                                                                         Scanner                                  Series Q                                                                                      Series Q                                      Camera     192.168.1.145
                                                                         DM7500                                                                                                                                                                           192.168.1.147
                                                                                                                RockerArm1                                                                                          Bolt
                                                                                                                  Station 3                                                                                     Station 8
                                                                                                                  Series Q                                                                                      Series Q

Ethernet Network                                                                    Motorola Hand               RockerArm2
MelSec Network                                                                           Held #1                  Station 4
Serial                                                                                                            Series Q
                                                                                    192.168.1.118
                                                                                                                RockerArm3
                                                                                    Motorola Hand                 Station 5
                                                                                         Held #1                  Series Q

#### 192.168.1.119 RockArm4-6
                                                                                                                  Station 6
                                                                                    Motorola Hand                 Series Q
                                                                                         Held #1
                                                                                                                   RRShaft
#### 192.168.1.120 Station 8/9?

                                                                               Wireless                           Series Q
                                                           Raw Material Scanners
                                                                                                                   FRShaft
                                                                                                               Station 9/10?

                                                                                                                  Series Q

                                                                                                                 Inspection
                                                                                                                 Station 11
                                                                                                                  Series Q

                                                                                                                                                          Line 1 Assembly                                                                                                Line 2 Assembly

Flexware Innovation, Inc.   Reference SOP ENG0025_Template_TechUserManual.doc
9128 Technology Ln.
Indianapolis, IN 46038
Office: (317) 813-5400
Fax:(317) 813-2121

<!-- Page 78 -->

# 14.0 Appendix C – Process Data Flow Diagram (Assembly Out)

     Step 0
MES - WAITING

   FOR PART

     Step 1
MES - COGNEX

    TRIGGER

SN Read          Bad                  No   Retrigger
Good/Fail                                 Count = 20
                      Camera Bypass

         Good                  Yes                        No           Step 4
                                                                  MES - SN READ
     Step 2                Step 5         MES Bypass
MES - SN READ         MES – CAMERA                                        FAIL

      GOOD                 BYPASS

       Step 6                                       Yes
MES -PART START
                                                Step 3
                                          MES – IN BYPASS                                                                   No

                                            SN READ FAIL                                                    Camera Bypass

                                      No    Transaction                                                              Yes
                                          in Process from
                      MES Bypass                                                                               Step 14
                                                 MES                                                          MES – MES
                             Yes                                                                               BYPQASS
                                          Part Valid from     Invalid              Step 13
                        Step 14                 MES                              MES - PART                 Release Part
                      MES – MES
                       BYPQASS                                                     INVALID

                                                           Valid

                                                Step 12
                                          MES - PART VALID

                                          Process Part                             Transaction
                                                                                 in Process from
                                             Step 11
                                            MES -DATA                                   MES

                                               READY                             Part Valid from   Invalid                        Step 13
                                                                                       MES                                      MES - PART
                                                            No                                                                              Remove Part
                                                                                                                                  INVALID
                                            MES Bypass
                                                                                 Valid
                                                   Yes

                                             Step 14
                                            MES – MES
                                             BYPQASS

                                                                                       Step 12
                                                                                 MES - PART VALID

                                                                                 Release Part

Flexware Innovation, Inc.                                         Reference SOP ENG0025_Template_TechUserManual.doc
9128 Technology Ln.
Indianapolis, IN 46038
Office: (317) 813-5400
Fax:(317) 813-2121

<!-- Page 79 -->

# 15.0 Appendix D – Process Data Flow Diagram (Assembly In)

     Step 0
MES - WAITING

   FOR PART

     Step 1
MES - COGNEX

    TRIGGER

SN Read        Bad                  No   Retrigger
Good/Fail                               Count = 20
                    Camera Bypass

         Good                Yes                        No           Step 4
                                                                MES - SN READ
     Step 2              Step 5         MES Bypass
MES - SN READ       MES – CAMERA                                        FAIL

      GOOD               BYPASS

 Step 11                                          Yes
MES -DATA
                                              Step 3
   READY                                MES – IN BYPASS

                                          SN READ FAIL                                                     No

                                    No    Transaction                                      Camera Bypass
                                        in Process from
                    MES Bypass                                                                      Yes
                                               MES
                           Yes                                                                Step 14
                                                                                             MES – MES
                      Step 14                                                                 BYPQASS
                    MES – MES
                     BYPQASS            Part Valid from     Invalid              Step 13
                                              MES                              MES - PART

                                                                                 INVALID

                                                         Valid

                                              Step 12
                                        MES - PART VALID

                                        Release Part

                                                                                                               Remove Part

<!-- Page 80 -->

# 16.0 Appendix E –Creating a New Production Order for the New
     Product

       Manufacturing Director contains the Dispatching Client where production schedules are created
       and managed. Within production schedules, production orders (i.e., manufacturing orders) are
       created and dispatched to work centers as individual work orders.

## 16.1 Using the Dispatching Client
       In the Dispatching Client the schedulable level (e.g., Sites) will display in the server explorer tree.
       In this system only one schedule is used and it is always open. Click on the “Production Schedules”
       folder to display the Production Schedule Management screen. From here the production
       schedule can be viewed.
       In the server explorer tree, click on the production schedule to view the Production Order
       Management screen and the Work Center Grid.
       Click Add to create a new production order, or select a production order and click edit to modify.
       This will display the Production Order Definition window. It is not necessary to use the Comment
       or Attributes tab. On the General tab fill in:

              Name
              Planned Start Time
              Planned End Time
              State (set to Scheduled)
              Quantity Required
       On the Product Specification tab select the appropriate product specification.
       On the Route tab select the only route available and click Select.
       The following sections describe in more details each of the screen mentioned above:
              Production Schedule Management
              Production Order Management
              Production Order Definition (General)
              Production Order Definition (Product Specification)
              Production Order Definition (Route)

## 16.2 Production Schedule Management
       There is only one production schedule in the system. It will always be open.

<!-- Page 81 -->

### 16.2.1 How to Access:

    From the Dispatching Client:

         1. Select a Production Schedules folder in the explorer tree. The Production
              Schedule Management screen displays on the right.

### 16.2.2 Overview:

    The Production Schedule Management window allows for the creating, viewing,
    modifying, deleting of production schedules.

### 16.2.3 Details:

    The production schedules can be filtered based upon state.

    The functionality for the Add, Edit, Delete, and Properties buttons described in the Fields
    & Buttons section can also be accessed with the right click option.

### 16.2.4 Prerequisites:
    See the Dispatching Client Overview section.

### 16.2.5 Fields & Buttons:

Name &         Description & Use
Type
Add     Description:

 Type:         Add a production schedule.
Button
        Use:

               Click Add. The Production Schedule Definition window will display.

<!-- Page 82 -->

Name &             Description & Use
Type
Edit        Description:

 Type:             Displays the Production Schedule Definition window pre-populated with
Button             the selected production schedule.

Delete      Use:

 Type:                              1. Select a production schedule from the list.
Button                              2. Click Edit.

            Description:

                   Delete a production schedule.
                   NOTE: Once it is deleted there is no getting it back (unless you go to a
                   database backup).

            Use:

                                    1. Select a production schedule from the list.
                                    2. Click Delete. Confirmation is required via a pop-up.

Properties                          3. Click Yes to delete the entity or click No to cancel.

 Type:      Description:
Button
                   Displays the Production Schedule Definition window pre-populated with
Refresh            the selected production schedule in read only mode.

 Type:      Use:
Button
                                    1. Select a production schedule from the list.
                                    2. Click Properties.

            Description:

                   Refreshes the list of production schedules.

            Use:

                   Click Refresh.

<!-- Page 83 -->

     Name &         Description & Use
     Type
     Filter  Description:

Type: Drop-         Defines the schedules which will be displayed. If a state is checked with
                    the Filter drop-down the schedules with that state will be displayed.
    Down

             Use:

             Click Filter.
             Click a state to toggle it to either to be checked or not checked.

Selection
List

Type: List Description:
                         The list of all the production schedules that are configured.

                         The columns which display are defined in the Modeling Client.

                    Use:

                         Select an order and click Edit, Copy, Delete, or Properties.

### 16.2.6 Do Next:

         After production schedules are created, click on a production schedule in the tree view to
         display the Production Order Management screen. Use the Production Order
         Management screen to view/manage the production orders associated with the production
         schedule.

### 16.2.7 See Also:

    Parent Window:
         Dispatching Client

    Other Tabs:
         None

    Child Windows:
         Production Schedule Definition (General)

    Other:
         Dispatching Client Overview

<!-- Page 84 -->

## 16.3 Production Order Management

### 16.3.1 How to Access:
            From Dispatching Client:

                 Select a specific production schedule in the server explorer tree. The Production
                 Order Management screen displays on the right.

### 16.3.2 Overview:
            The Production Order Management screen allows for creating, viewing, modifying, and
            deleting production orders.

### 16.3.3 Details:
            The right side of the Dispatching Client window, when Production Order Management is
            displayed, is divided into three panes, horizontally.

                 The top pane allows management of production orders (this is the section described
                 in this section.

                 The middle pane shows a grid of the work centers configured for the selected order.
                 (See also, Work Center Grid)

                 The bottom pane shows the details of a work order when selected in the grid.
The orders can be filtered based upon state with the State drop-down list.
Production orders can be re-ordered by using the Move Up and Move Down buttons.
Production orders can be sorted using the Filter/Sort right click option when a production order is
selected or when a header field is selected.

<!-- Page 85 -->

### 16.3.4 Prerequisites:
         Create schedules.

### 16.3.5 Fields & Buttons:

Name & Type  Description & Use

Add          Description:

             Add a production order.

 Type:       Use:
Button
                    Click Add. The Production Order Definition window will display.

Edit         Description:

 Type:              Displays the Production Order Definition window pre-populated with the
Button              selected production order.

             Use:

                                     1. Select a production order from the list.
                                     2. Click Edit.

<!-- Page 86 -->

Name & Type            Description & Use

Delete           Description:

                       Delete a production order.

 Type:                 NOTE: Once it is deleted there is no getting it back (unless you go to a
Button                 database backup).

                 Use:

                                                             1. Select a production order from the list.

                                                             2. Click Delete. The Confirmation Required pop-up will
                                                                 display.

     Properties                          3. Click Yes to delete the entity or click No to cancel to
       Type:                                  deletion.
     Button
                 Description:
      Move Up
Type: Button            Displays the Production Order Definition window pre-populated with the
                        selected production order in read only mode.

                 Use:

                                         1. Select a production order from the list.
                                         2. Click Properties.

                 Description:

                        Moves the selected order up one position.

                 Use:

                                         1. Select an order in the list.
                                         2. Select the Move up button. The order changes position with

                                              the order above it.
                        The top order cannot be moved up.

<!-- Page 87 -->

Name & Type     Description & Use

                Description:

Move Down              Moves the selected order down one position.

                Use:

Type: Button    1. Select an order in the list.

                2. Select the Move Down button. The order changes position with the order
                below it.

                The bottom order cannot be moved down.

Refresh         Description:

                Refreshes the list of production orders.

 Type:          Use:
Button
                       Click Refresh.

State           Description:

Type: Drop-            Defines the orders which will be displayed. If a state is checked with the State
                       drop-down the schedules with that state will be displayed.
    Down
                Use:

                                        1. Click State.

                                                             2. Click a state to toggle it to either to be checked or not
                                                                 checked.

Selection List

Type: List

                Description:

                       The list of all the production orders that are configured.
                       The columns which display are defined in the Modeling Client.

                Use:

                              Select an order and click Edit, Copy, Delete, or Properties.
                              Or right click and select one of the following options:
                              Edit – displays the Production Order Definition window
                              Delete – removes the production order

<!-- Page 88 -->

Name & Type  Description & Use

                     Filter/Sort

                         o Column: xxx - where xxx is the column. The orders will be
                              sorted by the selected column.

                         o Add Filter… - displays the Filter Configuration window. Refer
                              to the Help tab in this window for details on using the filter
                              features.

             o Sort Ascending

                       This column – sort all orders sorting on this column
                           only

                       Include this column – sort all orders retaining the sort
                           order of other columns and then sorting on this column

                       NOTE: When sorting is defined an addition menu bar
                           will display. Use the Reset button on this menu to clear
                           or defined sorting. The default sorting will be displayed.

                 o Sort Descending

                            This column – sort all orders sorting on this column
                                only

                            Include this column – sort all orders retaining the sort
                                order of other columns and then sorting on this column

             Change State – changes the state of the production order to and from
             Scheduled and Released

             Change Hold – puts the production order on hold. To remove the hold,
             go to the Production Order Definition window.

             Dispatch – displays the Production Order Dispatch window

<!-- Page 89 -->

Name & Type  Description & Use

                    WIP Status – displays the WIP Status window

                    Properties – displays the Production Order Definition window in read
                     only mode

### 16.3.6 Do Next:

    Define and modify the production order definitions on the Production Order Definition
    window.

### 16.3.7 See Also:

Parent Window:
  Dispatching Client

Other Tabs:
  None

Child Windows:
  Production Order Definition (Attributes)
  Production Order Definition (Comment)
  Production Order Definition (General)
  Production Order Definition (Product Specification)
  Production Order Definition (Route)
  Production Schedule Definition (General)
  Dispatch
  Work Center Grid

Other:
  Dispatching Client Overview

<!-- Page 90 -->

## 16.4 Production Order Definition (General)

### 16.4.1 How to Access:

    From Dispatching Client:

       1. Select a specific production schedule in the explorer view. The Production Order
            Management screen displays on the right.

       2. From the Production Order Management screen, use one of the following methods:

                      Click Add.

                      Select an existing production order and click Edit or Properties (button or
                      right clicking).

                           o Edit will allow modifications to be made.

                           o Properties will display the window as read only.

                      Double click on an existing production order and it will display as read
                      only.

       3. From the Production Order Definition window, select the General tab (it is
            displayed upon startup).

<!-- Page 91 -->

### 16.4.2 Overview:
    The Production Order Definition window defines the details of a production order.

### 16.4.3 Details:
    The General tab configures the basic information regarding the order.

### 16.4.4 Prerequisites:
    None

### 16.4.5 Fields & Buttons:

Name &               Description & Use
Type

Name        Description:

                     The name of the production order.

Type: Text  Use:

    Field          Click in the field and type.

Description Description:

                     The description of the production order.

Type: Text  Use:

    Field          Click in the field and type.

Planned     Description:
Start Time
                   The date and time when processing of the production order is planned to
                   start.

Type: Date and Use:

Time Field           Type a properly formatted date (and optionally the time)

                     Click the drop-down, and use the calendar. Time, if desired, must be
                     typed manually.

<!-- Page 92 -->

Name &                Description & Use
Type

Planned End Description:

Time                  The date and time when processing of the production order is planned to

                      end.

Type: Date and Use:

Time Field            Type a properly formatted date (and optionally the time)

                      Click the drop-down, and use the calendar. Time, if desired, must be
                      typed manually.

State           Description:

                      Sets the state of the production order.

Type: Drop-           The available states include:
                        Scheduled – not visible to the Shop Floor Client
    Down Field

                      Released – available to Shop Floor Client for processing

                      Queued – ready to process; may be partially processed

                      Started – currently being processed

                      Suspended – processing prohibited

                      Complete – the required quantity has been satisfied

                      Closed – no further action allowed

                Use:

                      Type the first letter of a state.

                      Or, click the drop-down list and select the desired state.

Actual Start    Description:
Time
                       The date and time when processing of the production order actually
                       started.

Type: Date and Use:

Time Field            Type a properly formatted date (and optionally the time)

                      Click the drop-down, and use the calendar. Time, if desired, must be
                      typed manually.

<!-- Page 93 -->

Name &                Description & Use
Type

Actual End      Description:
Time
                       The date and time when processing of the production order actually ended.

                Use:

Type: Date and        Type a properly formatted date (and optionally the time)

    Time Field        Click the drop-down, and use the calendar. Time, if desired, must be
                      typed manually.

Quantity        Description:
Required
                       The quantity that is required to be created in order to satisfy the production
                       order.

Type: Number    Use:

    Field              Click in the field and type.

Quantity        Description:
Complete
                       The quantity that is complete.

Type: Number    Use:

    Field              Click in the field and type.

Hold            Description:

                      If True, the production order is on hold.

Type: True /           If False, the production order is not on hold.

    False       Use:

                      Type “T” or “F”.

                      Or, click the drop-down list and select either True or False.

Is Enabled Description:

                      Determines if the production order is enabled.

Type:           Use:

    True/False           Type “T” or “F”.

                      Click the drop-down list and select either True or False.

<!-- Page 94 -->

Name &          Description & Use
Type

Is              Description:
Instantiable
                       Determines if the production order is instantiable, that is, if there can be
                       instances of the production order.

Type:           Use:

    True/False           Type “T” or “F”.

                Click the drop-down list and select either True or False.

OK              Description:

                Closes the window and saves any configuration changes.

 Type:          Use:
Button
                       Click OK. The window will close and changes will be saved.

Cancel          Description:

 Type:                 Closes the window and does not save any configuration changes.
Button
                Use:

                       Click Cancel. The window will close and changes will not be saved.

### 16.4.6 Do Next:

            Define the configuration on each tab.

            Then dispatch the order.

### 16.4.7 See Also:

Parent Window:
  Production Order Management

Other Tabs:
  Production Order Definition (Attributes)
  Production Order Definition (Comment)
  Production Order Definition (Product Specification)
  Production Order Definition (Route)

Child Windows:
  None

Other:
  Dispatching Client Overview

<!-- Page 95 -->

## 16.5 Production Order Definition (Product Specification)

### 16.5.1 How to Access:

    From Dispatching Client:

       1. Select a specific production schedule in the explorer view. The Production Order
            Management screen displays on the right.

       2. From the Production Order Management screen, use one of the following methods:

                      Click Add.

                      Select an existing production order and click Edit or Properties (button or
                      right clicking).

                           o Edit will allow modifications to be made.

                           o Properties will display the window as read only.

                      Double click on an existing production order and it will display as read
                      only.

       3. From the Production Order Definition window, select the Product Specification
            tab.

<!-- Page 96 -->

### 16.5.2 Overview:
        The Production Order Definition window defines the details of a production order.

### 16.5.3 Details:

        The Product Specification tab defines what is being produced for the production order.

        Multiple versions may be available for each product specification, so use care when
        selecting a specification.

### 16.5.4 Prerequisites:

        Define product specification in the Configuration Client on the Product Specification
        Management screen.

### 16.5.5 Fields & Buttons:

Name &               Description & Use
Type

Production Description:

Specification        Contains the tree view of all available product specifications. The selection

                     from this list determines “what” will be created by the production order.

Type: List           The selected product specification is listed at the bottom of the window.

               Use:

                     Expand the tree and select the desired product specification.

OK             Description:

                     Closes the window and saves any configuration changes.

 Type:         Use:
Button
                      Click OK. The window will close and changes will be saved.

Cancel         Description:

 Type:                Closes the window and does not save any configuration changes.
Button
               Use:

                      Click Cancel. The window will close and changes will not be saved.

### 16.5.6 Do Next:
        Define the configuration on each tab.

<!-- Page 97 -->

            Then dispatch the order.

### 16.5.7 See Also:

            Parent Window:

               Production Order Management

            Other Tabs:

               Production Order Definition (Attributes)
               Production Order Definition (Comment)
               Production Order Definition (General)
               Production Order Definition (Route)

            Child Windows:

               None

            Other:

               Dispatching Client Overview

## 16.6 Production Order Definition (Route)

  There will be just one master route to select on this screen. Select the master route and click
  Select.

<!-- Page 98 -->

      NOTE: The details of how to use the Route tab when the selected route is
      displayed is not explained in this section but in the Master Route Definition
      section.

      See the subsection “Operation & Routes Overview” in the “Configuration
      Client Overview” section.

### 16.6.1 How to Access:

    From Dispatching Client:

       1. Select a specific production schedule in the explorer view. The Production Order
            Management screen displays on the right.

       2. From the Production Order Management screen, use one of the following methods:

                      Click Add.

                      Select an existing production order and click Edit or Properties (button or
                      right clicking).

                           o Edit will allow modifications to be made.

                           o Properties will display the window as read only.

<!-- Page 99 -->

                          Double click on an existing production order and it will display as read
                          only.

            3. From the Production Order Definition window, select the Route tab.

### 16.6.2 Overview:
    The Production Order Definition window defines the details of a production order.

### 16.6.3 Details:

    The Route tab defines where and how the production order is going to be executed.

    When first creating the production order the available master routes and product routes
    will be listed. Select a route and click the Select button. The selected route will display in
    the tab. At this point the route can be modified. If any fields are modified, changes made
    at the master and product levels will not override the changes at this level (the order
    level). But if changes are not made to a field, changes made at the master and product
    level will show up here, until the state of this production order is no longer set to
    Scheduled.

    See the subsection “Operation & Routes Overview” in the “Configuration Client
    Overview” section.

### 16.6.4 Prerequisites:
    Define master routes and/or product routes in the Configuration Client.

### 16.6.5 Fields & Buttons:

Name &      Description & Use
Type

Route

Type: List

            Description:

                   List of all available routes for this production order.

            Use:

                   Select the route and click Select.

<!-- Page 100 -->

     Name &          Description & Use
     Type
     Select   Description:
Type: Button
                     Saves the selected route.
     Change
     Route             NOTE: The details of how to use the Route tab when the selected
Type: Button           route is displayed is not explained in this section but in the Master
     OK                Route Definition section.
       Type:
     Button   Use:

                     Select the route and click Select.

              Description:

                     Displays the list of all available routes for this production order.

              Use:

                     Click Change Route.

              Description:

                     Closes the window and saves any configuration changes.

              Use:

                     Click OK. The window will close and changes will be saved.

Cancel        Description:

 Type:               Closes the window and does not save any configuration changes.
Button
              Use:

                     Click Cancel. The window will close and changes will not be saved.

### 16.6.6 Do Next:
    Define the configuration on each tab.
    Then dispatch the order.

### 16.6.7 See Also:
    Parent Window:
    Production Order Management
    Other Tabs:

<!-- Page 101 -->

            Production Order Definition (Attributes)
            Production Order Definition (Comment)
            Production Order Definition (General)
            Production Order Definition (Product Specification)

            Child Windows:
            Master Route Definition (General)
            Master Route Definition (Related Items)

            Other:
            Dispatching Client Overview
            Master Route Definition

## 16.7 Creating a New Work Order for the New Production Order

  The work center grid displays the work orders in the work centers to which they have been
  dispatched. Dispatching is done in two different ways. Either, by dragging and dropping a
  production order to the work center grid; or, by right clicking on a production order and selecting
  Dispatch. The work orders are displayed in the time frame they are planned.

  This system has two work cells so the work order will need to be dispatched to each work center.

  The Work Center Dispatch form displays when the production order is dropped to the work
  center grid or when a production order is right clicked and Dispatch is selected. On this form, all
  operations required by the production order are displayed. Only those operations supported by the
  work center will be enabled. Of the supported operations, one or more may be configured for
  dispatch.

  Once dispatched, the attributes of a work order can be modified by right clicking on the work
  order in the work center grid and selecting Edit. The Work Order window will display.

  The following sections describe in more details each of the screen mentioned above:

         Dispatch

         Dispatching Client

         Work Center Grid

         Work Order (Attribute)

         Work Order (General)

         Work Order (Tasks)

<!-- Page 102 -->

## 16.8 Dispatch

### 16.8.1 How to Access:

    This window can be accessed in two ways and each way displays basically the same
    window:

         Production Order Dispatch: On the Production Order Management screen, right
         click a production order and select Dispatch.

         Work Center Dispatch: On the Production Order Management screen, drag a
         production order to the grid and drop it in the appropriate work cell at the time the
         order is to start.

    On the Work Center Dispatch only the operations for the work center into which the
    order was dropped will be active. And the Work Center column will not appear.

### 16.8.2 Overview:

    The Dispatch window is where production orders are dispatched to work centers as work
    orders.

<!-- Page 103 -->

### 16.8.3 Details:
    See the Dispatching Client Overview.

### 16.8.4 Prerequisites:
    See the Dispatching Client Overview.

### 16.8.5 Fields & Buttons:

     Name & Type           Description & Use
     Production
     Order          Description:

Type: Link                 The production order from which this work order was created.

                    Use:

                           Click the production order and the Production Order Definition will
                           display in read only mode.

     Product        Description:
Type: Link
                           The product from which this work order was created.
     Product
     Specification  Use:
Type: Link
                           Click the product and the Product Definition will display in read only
                           mode.

                    Description:

                           The product specification from which this work order was created.

                    Use:

                           Click the product specification and the Product Specification Definition
                           will display in read only mode.

     Order Route    Description:
Type: Link
                           The route from which this work order was created.
     Quantity
     Required       Use:
Type: Text Only
                           Click the route and the Route Definition will display in read only
                           mode.

                    Description:

                           The required quantity which was defined in the production order.

                    Use:

                           This is informational only.

<!-- Page 104 -->

     Name & Type         Description & Use
     Work Center
Type: Text Only   Description:

     Split               The work center in which the work order was dropped into on the grid.
Type: Button
                         This option is only listed on the Work Center Dispatch window,
     Delete              not on the Production Order Dispatch window.
Type: Button
                  Use:

                         This is informational only.

                  Description:

                         Splits the current row.
                         Use this to create additional operations that can be dispatched
                         separately, to different work centers, at different times.
                         The selected operation‟s quantity will be split in half. Then the
                         quantities can be adjusted by hand as necessary.
                         Shortcut Key: Ctrl +S

                  Use:

                         Select the operation to be split, and then click the Split button.

                  Description:

                         Deletes the current row.
                         Shortcut Key: Ctrl +L

                  Use:

                         Select the operation to be deleted, and then click the Delete button.

     Dispatch     Description:
Type: Button
                         Dispatches all the rows that have a checkmark in the dispatch check
                         box (at the front of each row in the list of operations).

                         Shortcut Key: Ctrl +D

                  Use:

                                          1. Click Dispatch. The Dispatch Confirmation dialog
                                               displays.

                                          2. Review the information in the Dispatch
                                               Confirmation dialog and either click OK or Cancel.

<!-- Page 105 -->

     Name & Type           Description & Use
     Show Details
Type: Button        Description:

     Use Entry             Controls visibility of the Work Order Details and Operation Details
     Form                  tabs at the bottom of the window.
Type: Button               The button toggles the tabs visible or invisible.
                           Shortcut Key: Ctrl +H
          Dispatch
     check box      Use:
Type: Check Box
                           Click Show Details.
     Operation
Type: Text Only     Description:

                           Determines where work order details are entered, either in-line or in the
                           details section. The button toggles where the details are entered.
                           By clicking the Use Entry Form button the fields in the grid will be
                           active or the fields on the Work Order Details tab will be active.
                           The Show Details button must be “on” for the Use Entry Form button
                           to be active.
                           Shortcut Key: Ctrl +E

                    Use:

                           Click use Entry Form.

                    Description:

                           Indicates if the operation will be dispatched. Work orders with a check
                           mark will be dispatched. Work orders without a checkmark will not be
                           dispatched.
                           The checkmark can be added either in the list or on the Work Order
                           Details tab. See “Use Entry Form” button.

                    Use:

                           Click on in the check box.

                    Description:

                           The operation that will be used to create the work order.

                    Use:

                           This is informational only.

<!-- Page 106 -->

Name & Type             Description & Use

Quantity          Description:

                        The quantity that will be processed by this operation.

Type: Text Field        As a default, the quantity is set to the entire required quantity for each
                        operation.

                  Use:

                        Enter a value.

State             Description:

                        Defines the state of the work order after dispatched.

Type: Drop-Down Use:
                                    Click on the down arrow and select a state.

Work Center Description:

                        The work center where this operation will be preformed.

Type: Drop-Down         The Work Center field does not display on the Work Center
                        Dispatch window, only on the Production Order Dispatch window.

                  Use:

                        Click on the down arrow and select a work center.

Planned Start Description:

                        The planned start date and time for the operation.

Type: Date Field Use:

                        In the Date field:

                                                             1. Click in the field and the drop-down date picker will
                                                                 display.

                                                             2. On the calendar select the day.

                                                             3. At the bottom of the calendar type the time value, or
                                                                 use the up/down arrows to modify the time value.

<!-- Page 107 -->

     Name & Type         Description & Use
     Planned End
Type: Date Field  Description:

     Comment             Set the planned end date and time for the operation.
Type: Text
                  Use:
     Work Order
     Details tab         In the Date field:
Type: Area
                                          1. Click in the field and the drop-down date picker will
     Operation                                 display.
     Details tab
Type: Area                                2. On the calendar select the day.

                                          3. At the bottom of the calendar type the time value, or
                                               use the up/down arrows to modify the time value.

                  Description:

                         Comments can be entered that will be displayed on the Work Order,
                         Attributes tab.

                  Use:

                         Type in the comment field.

                  Description:

                         Displays information about the selected operation.

                         The Validation column displays current errors and warnings or
                         displays “Valid” if there are no errors or warnings.

                         If the Use Entry Form option is selected the fields to the right will
                         displayed. The fields can be modified and the changes will display in
                         the list above. This fields work the same as in the list. See the above
                         help for details on each specific field.

                         If the Use Entry Form option is off the fields will not appear, only the
                         Validation column is displayed.

                  Use:

                         Click on the Work Order Details tab. (The Show Details button must
                         be on.)

                  Description:

                         Displays information about the selected operation.

                  Use:

                         Click on the Operation Details tab.

<!-- Page 108 -->

### 16.8.6 Do Next:

    Use the Dispatching Client grid or Shop Floor Client to view and manage the work
    orders.

### 16.8.7 See Also:

    Parent Window:
    Production Order Management

    Other Tabs:
    None

    Child Windows:
    Dispatching Client
    Production Order Definition (Attributes)
    Production Order Definition (Comment)
    Production Order Definition (General)
    Production Order Definition (Product Specification)
    Production Order Definition (Route)
    Product Definition
    Product Specification Definition (General)
    Product Specification Definition (Parameter Details)
    Order Route Definition

    Other:
    Dispatching Client Overview

<!-- Page 109 -->

## 16.9 Dispatching Client

### 16.9.1 How to Access:

    To start the Dispatching Client:

         From the Start Menu, select:
          All Programs  Flexware Innovation  Manufacturing Director  Dispatching
         Client

         Or, click on the file Flexware.ManufacturingDirector.Dispatching.Client.exe. In a
         default installation, it will be in the following directory:

         C:\Program Files\Flexware Innovation\Manufacturing Director

### 16.9.2 Overview:

    The Dispatching Client is where production schedules are created and managed. Within
    production schedules, production orders (i.e., manufacturing orders) are created and
    dispatched to work centers as individual work orders.

<!-- Page 110 -->

### 16.9.3 Details:
    See the Dispatching Client Overview section.

### 16.9.4 Prerequisites:
    See the Dispatching Client Overview section.

### 16.9.5 Fields & Buttons:

Name & Type                          Description & Use

File  Exit   Description:

                                     Closes the window.

Type: Menu Item Use:

                                     Click File and select Exit.

View  Server Description:

Explorer                             Displays or hides the Server Explorer section of the window (the tree on

                                     the left).

Type: Menu Item Use:

                                     Click View and select Server Explorer.

                                     Or, press F7 function key on the keyboard.

View         Description:
Activity Log
                     Displays or hides the activity log at the bottom of the window.

                               Use:  Click View and select Activity Log.

Type: Menu Item

                                     Or, press F8 function key on the keyboard.

<!-- Page 111 -->

Name & Type      Description & Use

Tools           Description:
Options
                        Displays the options window.
(Production
Schedules &
Production
Orders)

Type: Menu Item

                 Use:

                        Click Tools and select Options. Click on Production Schedules or
                        Production Orders and the State Filters will display to the right for
                        the production schedules or orders.

                               Click the box before each state to add or remove a check mark
                               from the box. When a check is displayed in the box, each schedule
                               or order in that state will be displayed on the Production Schedule
                               Management or Production Order Management screen.

                               Under “Automatically refresh when” click the box before Filter
                               is changed to add or remove a check mark from the box. When a
                               check is displayed in the box, the list of production schedules or
                               orders will be updated each time the filter is modified. If the box
                               is not checked the Refresh button must be clicked before the list
                               is updated.

                               Under “Automatically refresh when” click the box before
                               Message is received to add or remove a check mark from the box.
                               When a check is displayed in the box, the list of production
                               schedules or orders will be updated each time a message is
                               received.

<!-- Page 112 -->

Name & Type      Description & Use

Tools           Description:
Options
                        Displays the options window.
(Dispatch Area)

Type: Menu Item

                 Use:

                        Click Tools and select Options. Click on Dispatch Area and the
                        following options will display to the right.

                               When “Show relative path to work center” is checked the
                               specific paths will be displayed in the grid to the left.

                 When checked this will display:

                 When it is not checked this would display:

                 To customize the timeline, check “Snap dropped location to ##
                 minutes”.

                 Set “Look Backward” and “Look Forward” the number of day the
                 grid is to scroll back and forward.

Help  About     Description:
Manufacturing
Director                Displays the About Manufacturing Director box which lists the
Dispatch                software version number.
Client
                 Use:

Type: Menu Item  Click Help and select About Manufacturing Director Dispatch
                 Client.

<!-- Page 113 -->

Name & Type    Description & Use

Server         Description:
Explorer Tree
                      Displayed on the left side of the Dispatching Client is the Server
                      Explorer Tree.

Type: Tree

                      Note: Use View Server Explorer or the F7 function key to display
                      or hide the Server Explorer Tree.

               Use:

                             Click the + (plus signs) to expand the levels of the tree. Click the
                             – (minus signs) to collapse the levels of the tree.

                             In the tree, under sites click on Production Schedules and the
                             Production Schedule Management screen displays to the right.
                             Click on a specific production schedule and the Production
                             Order Management screen displays to the right.

                             Right click on any level and different options will be displayed.

                             Refresh – all levels under the selected level will be refreshed. The
                              levels will collapse.

                             Modify Server – See the section Add a New Server.

                             Remove Server – the selected server will be removed from the
                              tree. This does not affect the state of the database.

<!-- Page 114 -->

Name & Type         Description & Use

Production   Description:
Schedule
Management          Manage the production schedules defined within the system.

Type: Area

Production   Use:
Order
Management          To display, click on a Production Schedules folder in the Server
                    Explorer Tree.
                    See also, Production Schedule Management.

             Description:

                    Manage the production orders defined within the system.

Type: Area

                  Use:

                        To display, click on a specific production schedule in the Server
                        Explorer Tree.
                        See also, Production Order Management and Work Center Grid.

### 16.9.6 Do Next:
    See the Dispatching Client Overview section.

<!-- Page 115 -->

### 16.9.7 See Also:

            Parent Window:
            None

            Other Tabs:
            None

            Child Windows:
            Production Order Management
            Production Schedule Management
            Work Center Grid

            Other:
            Dispatching Client Overview
            Add a New Server

## 16.10 Work Center Grid

### 16.10.1 How to Access:

    The work Center grid is displayed when the Production Order Management screen is
    displayed.

    As production orders are dispatched they are graphically displayed on the grid.

<!-- Page 116 -->

### 16.10.2 Overview:
    The work center grid displays work orders on a timeline sorted by location.

### 16.10.3 Details:
    Production orders are dispatched and displayed on the grid either with the Production
    Order Dispatch window or the Work Center Dispatch window.
         Production Order Dispatch: On the Production Order Management screen, right
         click a production order and select Dispatch. On the Production Order Dispatch
         window work orders are dispatched and displayed on the gird.
         Work Center Dispatch: On the Production Order Management screen, drag a
         production order to the grid and drop it in the appropriate work cell at the time the
         order is to start. On the Work Center Dispatch window work orders are dispatched
         and displayed on the grid.

    Details Displayed:
    When work orders are selected on the grid the details about that work order are listed
    below the grid.

    Right Click Pop-up:
    Right click on a work order in the grid and the following pop-up displays. See the Fields
    & Button section for details on these options. Note that depending on the current state of
    the work order different options may be available in the pop-up list.

Color Status:
The work orders are colors according to their current state.

<!-- Page 117 -->

Grid Formats:
Besides color, work orders display the planned start and end times verses the actual start
and end times. The solid boxes represent the actual start and end times while the dashed
lined boxes represent the planned start and end times. The dashed lines between the two
boxes connect boxes that represent the same work order.

Configuration Options:
See the ToolsOptions, OptionsDispatch Area configuration options.

Work Centers:
       When “Show relative path to work center” is checked the specific paths will be
       displayed in the grid to the left.

       When checked this will display:

<!-- Page 118 -->

When it is not checked this would display:

Timeline:
To customize the timeline, check “Snap dropped location to ## minutes”.

The date/time range of the grid can be defined. Set Look Backward and Look Forward the
number of day the grid is to scroll back and forward.

### 16.10.4 Prerequisites:
    See the Dispatching Client Overview.

### 16.10.5 Fields & Buttons:

Name & Type      Description & Use

Zoom

Type: Drop-Down

     Now         Description:
Type: Button
                        Rescales the grid.

                        When 100% is selected the range of one day will be displayed in the
                        part of the grid that is currently displayed. Use the scroll bar to
                        display additional time forward and backward.

                        The higher the percentage selected the more the graph will zoom in
                        and display less time span at in a current view. Choose a lower
                        percentage to zoom out and see a larger range of time.

                        Use the Configuration Options to define the range of the entire
                        scrollable window.

                 Use:

                        Click the drop-down and select the percentage to view.

                 Description:

                        Resets the grid to display the current time.

                        “Now” is represented on the grid with a red vertical line.

                 Use:

                        Click Now.

<!-- Page 119 -->

     Name & Type          Description & Use
     Refresh
Type: Button       Description:
     Edit
Type: Drop-Down           Refresh the grid.

     Delete        Use:
Type: Drop-Down
                          Click Refresh.

                   Description:

                          Displays the Work Order window for the selected work order.

                   Use:

                                           1. Right click on a work order in the grid.
                                           2. Select Edit.

                   Description:

                          Delete a work order.
                          NOTE: Once it is deleted there is no getting it back (unless you go
                          to a database backup).

                   Use:

                                           1. Right click on a work order in the grid.
                                           2. Select Delete. Confirmation is required via a pop-

                                                up.

     Change State                          3. Click Yes to delete the work order or click No to
Type: Drop-Down                                 cancel.

                   Description:

                          Changes the state of the selected work order.

                   Use:

                                           1. Right click on a work order in the grid.
                                           2. Select Change State.
                                           3. Select an available state.

<!-- Page 120 -->

     Name & Type         Description & Use
     Change Hold
                  Description:
Type: Drop-Down
                         Change the hold status of the selected work order.

                         The Hold Work Order option toggles the on-hold status.

                         In the grid a production order or a work order with an on-hold status
                         will be pink.

                         The Change HoldHold Production Order indicates if the
                         production order is on-hold or is not on-hold. A check mark
                         indicates the production order is on-hold.

     Properties   Use:
Type: Drop-Down
                                          1. Right click on a work order in the grid.
                                          2. Select Change HoldHold Work Order.

                  Description:

                         Displays the Work Order window pre-populated with the selected
                         work order in read only mode.

                  Use:

                                          1. Right click on a work order in the grid.
                                          2. Select Properties.

### 16.10.6 Do Next:

    Use the Dispatching Client grid or Shop Floor Client to view and manage the work
    orders.

### 16.10.7 See Also:

    Parent Window:
    Dispatching Client

    Other Tabs:
    None

    Child Windows:

<!-- Page 121 -->

            Dispatch
            Work Order (Attribute)
            Work Order (General)
            Work Order (Tasks)

            Other:
            Dispatching Client Overview
            Production Order Definition (Attributes)
            Production Order Definition (Comment)
            Production Order Definition (General)
            Production Order Definition (Product Specification)
            Production Order Definition (Route)
            Production Order Management
            Production Schedule Definition (General)
            Production Schedule Management

## 16.11 Work Order (Attribute)

<!-- Page 122 -->

### 16.11.1 How to Access:

         1. Right click on a work order in the Work Center grid and the following pop-up
              displays.

    2. Select Edit and the Work Order window will display.

    3. Click the Attributes tab.

Select Properties in the pop-up and a read only version of the Work Order window will
display.

### 16.11.2 Overview:

    The Work Order window displays information about the work order. Dates, states,
    comments, and quantity counts can be updated here.

### 16.11.3 Details:
    See the Dispatching Client Overview.

### 16.11.4 Prerequisites:
    See the Dispatching Client Overview.

### 16.11.5 Fields & Buttons:

     Name &         Description & Use
     Type
     State   Description:

Type: Drop-         Set the state of the work order.
                    States may be changed automatically by the Shop Floor Client.
    Down            For rules around the setting of states see the Dispatching Client
                    Overview section.

             Use:

                    Select a state from the drop-down list.

<!-- Page 123 -->

Name &      Description & Use
Type

Planned     Description:
Start Time
                   The date and time when processing of the work order is planned to start.

Type: Date         If this date is changed the work order on the grid will move accordingly.

            Use:

            Click the drop-down, and use the calendar to select a
            month, day, and year.

            Or, click on each field and type to make a change.

            For the month type the number that represents the month
            (i.e., 1 for January, 12 for December)

            For the year just type the last digit or two of the year. It
            will assume 2000.

Planned End Description:

Time        The date and time when processing of the work order is planned to end.

Type: Date         If this date is changed the work order on the grid will move accordingly.

            Use:

            Click the drop-down, and use the calendar to select a
            month, day, and year.

            Or, click on each field and type to make a change.

            For the month type the number that represents the month
            (i.e., 1 for January, 12 for December)

            For the year just type the last digit or two of the year. It
            will assume 2000.

<!-- Page 124 -->

Name &            Description & Use
Type

Actual Start Description:

Time              The date and time when processing of the work order actually started.

Type: Date        The Shop Floor Client may populate this field automatically.

                  To set this field for the first time click the checkmark box and the current
                  date and time will display in the field.

                  If this date is changed the work order on the grid will move accordingly.

            Use:

                  Click the drop-down, and use the calendar to select a
                  month, day, and year.

                  Or, click on each field and type to make a change.

                  For the month type the number that represents the month
                  (i.e., 1 for January, 12 for December)

                  For the year just type the last digit or two of the year. It
                  will assume 2000.

Actual End  Description:
Time
                   The date and time when processing of the work order actually ended.

Type: Date        The Shop Floor Client may populate this field automatically.

                  To set this field for the first time click the checkmark box and the current
                  date and time will display in the field.

                  If this date is changed the work order on the grid will move accordingly.

            Use:

                  Click the drop-down, and use the calendar to select a
                  month, day, and year.

                  Or, click on each field and type to make a change.

                  For the month type the number that represents the month
                  (i.e., 1 for January, 12 for December)

                  For the year just type the last digit or two of the year. It
                  will assume 2000.

<!-- Page 125 -->

Name &         Description & Use
Type

Quantity       Description:
Required
                      Defines the quantity required for this work order.

Type: Numeric         This is defined in the production order but can be changed on the Dispatch
                      window.
    Filed
               Use:

               Type in a value.

Quantity To Description:

Make           Defines the quantity yet to make for this work order.

Type: Numeric  Use:

    Filed             Type in a value.

Quantity       Description:
Started
                      Defines the quantity started for this work order.

Type: Numeric  Use:

    Filed             Type in a value.

Quantity In- Description:

process        Defines the quantity in-process for this work order.

Type: Numeric  Use:

    Filed             Type in a value.

Quantity       Description:
Queued
                      Defines the quantity queued for this work order.

Type: Numeric  Use:

    Filed             Type in a value.

Quantity       Description:
Complete
Good                  Defines the quantity that is complete and good for this work order.

               Use:

Type: Numeric  Type in a value.

    Filed

<!-- Page 126 -->

Name &               Description & Use
Type

Quantity       Description:
Complete
Bad                   Defines the quantity that is complete and bad for this work order.

               Use:

Type: Numeric        Type in a value.

    Filed

Comment Description:

                     Free form comment.

Type: Text           If comments were entered on the Production Order Dispatch or Work
                     Order Dispatch windows before dispatching, they will display here.

               Use:

                     Type text.

OK             Description:

                     Closes the window and saves any configuration changes.

 Type:         Use:
Button
                      Click OK. The window will close and changes will be saved.

Cancel         Description:

 Type:                Closes the window and does not save any configuration changes.
Button
               Use:

                      Click Cancel. The window will close and changes will not be saved.

### 16.11.6 Do Next:
Define the configuration on each tab.
Use the Dispatching Client grid or Shop Floor Client to view and manage the work orders.

### 16.11.7 See Also:
            Parent Window:
            Work Center Grid
            Other Tabs:
            Work Order (General)

<!-- Page 127 -->

            Work Order (Tasks)
            Child Windows:
            None
            Other:
            Dispatching Client Overview

## 16.12 Work Order (General)

### 16.12.1 How to Access:

         1. Right click on a work order in the Work Center grid and the following pop-up
              displays.

<!-- Page 128 -->

    2. Select Edit and the Work Order window will display.

Select Properties in the pop-up and a read only version of the Work Order window will
display.

### 16.12.2 Overview:
    The Work Order window displays information about the work order.
    The “Hold” state can be changed on this tab.
    Access to a read only version of the following windows can be accessed by
    clicking on the corresponding links:
            Production Order Definition (Route)
            Product Definition (General)
            Product Specification Definition (General)
            Order Route Definition
           Work Cell Definition (General)

### 16.12.3 Details:
    See the Dispatching Client Overview.

### 16.12.4 Prerequisites:
    See the Dispatching Client Overview.

### 16.12.5 Fields & Buttons:

Name &  Description & Use
Type

<!-- Page 129 -->

Name &         Description & Use
Type

Production     Description:
Order
                      The production order from which this work order was created.

Type: Link     Use:

                      Click the production order and the Production Order Definition will
                      display in read only mode.

Product        Description:

                      The product from which this work order was created.

Type: Link     Use:

                      Click the product and the Product Definition will display in read only
                      mode.

Product        Description:

Specification  The product specification from which this work order was created.

Type: Link     Use:

                      Click the product specification and the Product Specification Definition
                      will display in read only mode.

Order Route Description:
                           The route from which this work order was created.

Type: Link     Use:

                      Click the route and the Order Route Definition will display in read only
                      mode.

Order          Description:
Operation
                      Display the order operation.

Type: Text     Use:

    Only              This is informational only.

Work Cell      Description:

                      The route from which this work order was created.

Type: Text     Use:

    Only              Click the work cell and the Work Cell Definition will display in read only
                      mode.

<!-- Page 130 -->

   Name &             Description & Use
   Type
   Production  Description:
   Order Hold
                      Indicates if the parent production order is on hold.
Type: Text            In the grid a work order with a on-hold state will be pink.

  Only         Use:

                      This is informational only.

     Hold      Description:
Type: Drop-
                      Change the hold status of the selected work order.
    Down              The hold status can also be set from the right click drop-down on the grid.
                      In the grid a work order with an on-hold state will be pink.
     OK
       Type:   Use:
     Button
                      From the drop-down select Yes or No.

               Description:

                      Closes the window and saves any configuration changes.

               Use:

                      Click OK. The window will close and changes will be saved.

Cancel         Description:

 Type:                Closes the window and does not save any configuration changes.
Button
               Use:

                      Click Cancel. The window will close and changes will not be saved.

### 16.12.6 Do Next:

    Define the configuration on each tab.

    Use the Dispatching Client grid or Shop Floor Client to view and manage the work
    orders.

### 16.12.7 See Also:

    Parent Window:
    Work Center Grid
    Production Order Management

<!-- Page 131 -->

            Other Tabs:
            Work Order (Attribute)
            Work Order (Tasks)

            Child Windows:
            Production Order Definition (Route)
            Product Definition (General)
            Product Specification Definition (General)
            Order Route Definition
            Work Cell Definition (General)

            Other:
            Dispatching Client Overview

## 16.13 Work Order (Tasks)

### 16.13.1 How to Access:

         1. Right click on a work order in the Work Center grid and the following pop-up
              displays.

<!-- Page 132 -->

         2. Select Edit and the Work Order window will display.
         3. Click the Tasks tab.
    Select Properties in the pop-up and a read only version of the Work Order window will
    display.

### 16.13.2 Overview:
    The Work Order window displays information about the work order. Dates, states,
    comments, and quantity counts can be updated here.

### 16.13.3 Details:
    The Task tab is just informational. Nothing can be modified.
    Across the top of the Task summary are the tasks defined for the work order, followed
    by the status of each task, and finally the duration of each task.
    The durations will be in red text if they do not fall within the planned time for the task.
    The durations are listed in the format dd:hh:mm:ss (days:hours:minutes:seconds).
    The following are examples from the Tasks tab:

<!-- Page 133 -->

        There are four durations listed for each task:

               Actual Time – The first time listed is the time from Actual Start Time to Actual
               End Time or to now if the task does not have an end time. The time is will be
               followed with two asterisks (**) if current time is used in place of Actual End
               Time.

               Plan Time – The time in the parentheses () is the Plan Time as specified in the
               production order route for the order task. If the Plan Time field is blank the value is
               be all zeros.

               Minimum Time & Maximum Time – The time in the square brackets [] is the
               Minimum Time and Maximum Time as specified in the production order route for
               the order task. If these fields are blank the values will be all zeros.

### 16.13.4 Prerequisites:
    See the Dispatching Client Overview.

### 16.13.5 Fields & Buttons:

Name &         Description & Use
Type
OK      Description:

 Type:         Closes the window and saves any configuration changes.
Button
        Use:

               Click OK. The window will close and changes will be saved.

Cancel  Description:

 Type:         Closes the window and does not save any configuration changes.
Button
        Use:

               Click Cancel. The window will close and changes will not be saved.

<!-- Page 134 -->

### 16.13.6 Do Next:

    Define the configuration on each tab.

    Use the Dispatching Client grid or Shop Floor Client to view and manage the work
    orders.

### 16.13.7 See Also:

    Parent Window:
    Work Center Grid

    Other Tabs:
    Work Order (Attribute)
    Work Order (General)

    Child Windows:
    None

    Other:
    Dispatching Client Overview

<!-- Page 135 -->

# 17.0 Configuring Users

       Users are defined on the User Definition screen. Names, passwords, and their rolls are defined here.
       The following sections describe in more details each of the screen mentioned above:

                User Management
                User Definition (General)
                User Definition (Member Of)

## 17.1 User Management

### 17.1.1 How to Access:
From Configuration Client:

  Select Security in the explorer view.
  Select Users in the explorer view. The User Management screen displays on the right.

### 17.1.2 Overview:
The User Management window is where users are defined and managed.

### 17.1.3 Details:

Users provide access to Manufacturing Director Clients. Users are assigned Roles to set their
authorization level.

### 17.1.4 Prerequisites:
None

### 17.1.5 Fields & Buttons:

Name &  Description & Use
Type

<!-- Page 136 -->

Name &             Description & Use
Type

Add     Description:

                   Add user. The Users Definition window will display.

Type: Button Use:
                             Click Add.

Edit    Description:

                   Edit a user. The Users Definition window will display.

Type: Button Use:

                                         1. Select the user to be edited.

                                         2. Click Edit.

Copy               Description:

                             Copy a user. The Copy window will display.
Type: Button Use:

                                              1. Select the unit of measure to be copied.
                                              2. Click Copy. The Copy window will display.

Delete  Description:

                   Delete a user.

Type: Button Use:

                                         1. Select a user from the list.

                                         2. Click Delete. A Confirmation pop-up will displayed.

                                         3. Click Yes to delete the entity or click No to cancel to
                                             deletion.

<!-- Page 137 -->

Name &        Description & Use
Type

Properties Description:

Type: Button         Displays the User Definition window pre-populated with the selected unit of
                     measure. The values in the window will be read only.

              Use:

                         1. Select a unit of measure from the list.

                         2. Click Properties. The User Definition window will display
                             with the configuration for the unit of measure which was
                             selected.

Selection     Description:
List
                     The list of all the users that are configured.

Type: List           The columns which display are defined in the Modeling Client.

              Use:

              Right-click in the list area and select Add to display the Shift Definition
              window.

              Select an entity and right-click. The Edit, Copy, Delete and Properties
              options will display. The Edit and Properties option will display the User
              Definition window. The Delete option will remove the entity after Yes is
              selected on the Confirmation pop-up. The Copy option will display the copy
              window.

### 17.1.6 Do Next:
    Define and modify users on the User Definition window.

### 17.1.7 See Also:

    Parent Windows:
    None

    Other Tabs:
    None

    Child Windows:
    User Definition (General)
    User Definition (Member Of)

    Other:
    None

<!-- Page 138 -->

## 17.2 User Definition (General)

### 17.2.1 How to Access:
    From Configuration Client:
       Select Security in the explorer view.
       Select Users in the explorer view. The User Management screen displays on the right.
            o Click Add or select a user and click Edit.

          To see this window in Read Only view:
            Double click on a user.
            Or, select a user and click Properties.

### 17.2.2 Overview:
    The User Management window is where users are defined and managed.

<!-- Page 139 -->

### 17.2.3 Details:

    Users provide access to Manufacturing Director Clients. Users are assigned Roles to set
    their authorization level.

### 17.2.4 Prerequisites:
    None

### 17.2.5 Fields & Buttons:

     Name &              Description & Use
     Type
     Name         Description:

Type: Text               A name of the user.

    Field         Use:

                         Click in the field and type.

     Username     Description:

Type: Text               Login username.

    Field         Use:

                         Click in the field and type.

     Description  Description:

Type: Text               The description of the user. This is optional.

    Field         Use:

                         Click in the field and type.

     Password     Description:

Type: Text               Password of the user.

    Field         Use:

                         Click in the field and then click the ellipse. The Password Entry form will
                         display.

<!-- Page 140 -->

     Name &               Description & Use
     Type
     Is            Description:
     Instantiable
                          Not applicable. This field should always be set to False.
Type:
                   Use:
    True/False
                            In the field, type an “F” and False will automatically fill in.
     Is Current           OR
     Revision
                            Click the drop-down list and select False.
Type:
                   Description:
    True/False
                          If True, this revision will be the current one, the one used by the program.
     Is Enabled
                   Use:
Type:
                            In the field, type either a “T” or an “F” and True or False will
    True/False              automatically fill in.
                          OR
     OK                     Click the drop-down list and select either True or False.

       Type:       Description:
     Button
                          If True, the revision will be enabled for use.

                   Use:

                            In the field, type either a “T” or an “F” and True or False will
                            automatically fill in.
                          OR
                            Click the drop-down list and select either True or False.

                   Description:

                          Closes the window and saves any configuration changes.

                   Use:

                          Click OK. The window will close and changes will be saved.

<!-- Page 141 -->

Name &         Description & Use
Type
Cancel  Description:

 Type:         Closes the window and does not save any configuration changes.
Button
        Use:

               Click Cancel. The window will close and changes will not be saved.

### 17.2.6 Do Next:

    Define the configuration on each tab.

### 17.2.7 See Also:

    Parent Window:
    Users Management

    Other Tabs:
    Users Definition (Member Of)

    Child Window:
    None

    Other:
    None

<!-- Page 142 -->

## 17.3 User Definition (Member Of)

### 17.3.1 How to Access:
    From Configuration Client:
       Select Security in the explorer view.
       Select Users in the explorer view. The User Management screen displays on the right.
            o Click Add or select a user and click Edit.
                     1. Set Is Instantiable to true.
                     2. Click the Attributes Tab.

To see this window in Read Only view:
  Double click on a user.
  Or, select a user and click Properties.

<!-- Page 143 -->

### 17.3.2 Overview:
           The User Management window is where users are defined and managed.

### 17.3.3 Details:

           Users provide access to Manufacturing Director Clients. Users are assigned Roles to set
           their authorization level.

### 17.3.4 Prerequisites:
           Define roles on the Roles Management screen.

### 17.3.5 Fields & Buttons:

Name &               Description & Use
Type

Member Of Description:

                     Lists all defined roles.

Type:          Use:

Checkbox list        Select checkbox next to roles user is associated with.

### 17.3.6 Do Next:

           Define the configuration on each tab.

### 17.3.7 See Also:

           Parent Window:
           Users Management

           Other Tabs:
           Users Definition (General)

           Child Window:
           None

           Other:
           None

<!-- Page 144 -->

# 18.0 Appendix F – Bill of Materials

Vendor                                   Bill of Materials
Kirby Risk
            Part Description
Allied      Cognex - Dataman – DMR-100X-00, PN: 808-0009-1 Rev A
Automation  Cognex - DataMan Basic Accessory Kit - DM100-BAK-000
            Cognex - I/O Module - DM100-IOBOX-000
            Cognex - DM100-UBRK-000 - Universal Mounting Bracket
            Cognex - Dataman Model: DM7500 – Dataman hand held scanner
            Cognex - Dataman RS232 Cable: DM42206139-04 (For Dataman DM7500 hand held
            scanner
            Cognex - DataMan – DM42206416-01 – DataMan 7500 USB Cable
            CGNX CCB-84901-1004-10 COGCBL 10M ENET
            Pand C1WH6 - 6ft
            Pand G1x2WH6 - 6ft
            AB 1492J3 IEC 1-Circuit Feed-Through Block
            AB 1492ERL35 Screwless End Retainers
            AB 1492EBJ3 End barrier Gray
            AB 1492JG3 IEC 1-CKT Feed-Through Grd Blk
            IS5110-00 In-Sight® 5110 ID Reader Vision Sensor
            CCB-84901-0901-02 In-Sight Std. I/O Module Cable, 2M (6')
            LFC-25F1 Fujinon 2/3 " 25mm Lens F/1.4
            LTC-PL Polarizing Lens Filter
            LNS-CVR38-2 In-Sight® Lens Cover Kit 5000 Series 38mm
            CIO-1350-XX Breakout Module
            NTRO 104TX - 4 Port 10/100BaseTX Industrial Ethernet Switch
            Sola SDP1-24-100T 30W 24V DIN Plastic 115/230VIN
            LFC-25F1 Fujinon 2/3" 25mm lens
            CGNX DMPS5U-41 COG DATAMAN 7500 PWR Supply 5V US

            Mitsubishi FX3U-16MT/DSS 8 in/8 source out PLC
            Mitsubishi FX3U-ENET high speed ethernet module
            Mitsubishi FX3U-232-BD RS232 Adapter module
            GT1020-LBD 3.7inch monochrome touchscreen
            GT10-C30R4-8P 3 meter RS422 cable
            SC-Q programming cable for GT1020
            SC-09 programming cable for FX
            GX-DEV-C1 PLC programming software
            GT-WORKS2-C1 HMI development software
            GX-CONFIG-C1 software
            USB Bulkhead Interfaces – M22-USB-SA Moeller
            RJ45 Socket – M22-RJ45-SA Moeller
            MEAU QJ71E71-000
            MEAU QJ71E71-000 Returned
            MEAU GT10-C100R4-8P
            Mitsubishi FX3U-16MT/DSS
            MEAU FX3U-ENET

<!-- Page 145 -->

ScanSource  Mitsubishi FX3U-232-BD
Vorne       MEAU MX-OPC-C1
L-comm.com
            Zebra 284Z-10400-0001
CDW
            Display Board XL800-32080T

            DGB9FT DB9 Female Conector for Field termination
            SDRA9AG Right Angle Assembled D-sub Hood kit, D89/HD15 metal
            SDC9M Assembled D-sub Hood Kit, D89/HD15 metalized chrome
            DGB9F Slimline Gender Changer, D89 Female/Female
            DGB9M Slimline Gender Changer, D89 Male/Male
            DS4-100 4 Conductor 24 AWG Bulk Cable, 100 ft Coil
            SD9P Solder Cup D-Sub Connector, DB9 Male
            SD9S Solder cup D-Sub Connector, DB9 Female

            MS MBL SQL SRV STD 2005 X64 (MFG #:MBL-228-04103
            MS MBL SQL USER CAL 2005 (MFG#:MBL-359-01822)
