# Section 2 — Process Overview

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.


---


           2 P RO CE SS O VERVIEW
           This section defines the existing processes within the MPP facility. In addition, it will note deficiencies in
           the current system and how the new system will overcome known issues where possible.
           Figure 3 provides a plant overview. Note that the machines and operations in each area currently being
           relocated as MPP develops new lines for new customers.



           Figure 1 Madison Plant Layout



           Figure 2 Existing MES Landscape Block Diagram



           Figure 2 Existing MES Landscape Block Diagram shows the systems involved and generalized connectivity
           of MES and other systems at MPP. As depicted, MES interacts with operators, and PLCs, Cameras, and
           scales through OPC servers. Clerks take manually entered production reports from the operators and
           enter data into the Macola (ERP), Intellex (QC), and Productivity Data platforms.
           MES communicates to the AIM solution to trigger final shipping labels and obtain tracking information.




## PART MANUFACTURING AND PROCESS FLOW


           MPP is a Tier 2 automotive part supplier that produces Die Cast parts. Most parts produced at MPP start
           in the Die Cast area, go through the stages in Figure 3 Generalized MPP Production Process; however,
           parts may skip stages or repeat stages if necessary. “Pass Thru” parts are parts that are manufactured
           elsewhere, received at MPP and included in an assembly or repackaged and shipped from MPP.



           Figure 3 Generalized MPP Production Process




### 2.1.1 MATERIAL RECEIVING


           The current MES solution does not support the material receiving process.
           The receiving area is where material is received from outside the facility into the local storage areas.
           Material received may be ingots, raw materials, dunnage materials, pass-through parts, etc. These parts
           are received through systems outside of the MES solution.
           Information received for the incoming material is processed through the MACOLA ERP system. The
           incoming material has barcoded labels for received pallets, boxes, Containers, etc. Incoming material is
           LOT traced and although some may have unique serial numbers, the MPP systems do not track the
           received material serial numbers.
           MPP requests that new MES support material receiving for pass through parts and LOT identification in
           MES.




### 2.1.2 DIE CAST


           The Die Cast areas include raw aluminum stock management and melting furnaces which feed molten
           material to the Die Cast Machines. The raw aluminum pigs are not tracked by the existing MES.



           Two Die casting areas exist in the current factory lay out. One area (block 1) includes machines 1-11 and
           61, and the other (block 2) includes machines 73-77. The Die Cast machines are of varying sizes with the
           larger machines used to generate the larger parts or to produce more parts simultaneously. A die cast
           machine can produce one part, multiples of the same part, or a collection of different parts during a
           single shot (press).



           The Dies sets in each machine have a limited shot (cycle) count lifespan and must be refurbished after
           the specified shot limit. Operators manually collect the shot and trim press counts from a Die Cast
           machine and enter the count into the PD for tracking and reporting.
           Part of the Die Cast machine is a trim press. This trims the excess aluminum from the casting. This excess
           is placed in a bin that is remelted. The trim cast has a counter, and this will tell the operator the correct
           number of parts that have been cast. Both the Die Cast machine and the Trim press have counters. The
           Die cast counter counts the number of castings including warmups. The Trim press also has a counter,
           and this count is used to track all good parts coming out of the casting machine. (Trim Press is different
           than the Trim Shop)
           Note that MES WIP LOT identification starts here for manufactured parts. MES LOTS must maintain the
           awareness of the Die number and the Die cavity that was used to produce the part.
           The Die cast area includes the following machines. These machines are not currently connected to the
           MES solution.



            MachID MachineNo MachDesc                       Tonnage
                  1        1 DieCast#1                          125
                  2        2 DieCast#2                          125
                  3        3 DieCast#3                          125
                  4        4 DieCast#4                          350
                  5        5 Diecast#5                          350
                  6        6 Diecast#6                          350
                  7        7 DieCast#7                          250
                  8        8 DieCast#8                          350
                  9        9 DieCast#9                          350
                10        10 DieCast#10                         350
                11        11 DieCast#11                         250
                12        12 DieCast#12                         250
                13        61 DieCast#61                         350
                14        62 DieCast#62                         350
                15        63 DieCast#63                         350
                16        64 DieCast#64                         350
                17        65 DieCast#65                         350
                18        66 DieCast#66                         500
                19        67 DieCast#67                         500
                20        70 DieCast#70                         350
                21        73 DieCast#73                        1250
                22        74 DieCast#74                         800
                23        75 DieCast#75                        1650
                24        76 DieCast#76                        1250
                41        77 Diecast#77                         700



                   25              113 Debur#113
                   26              114 Debur#114
                   32               32 DC Assoc




### 2.1.3 TRIM SHOP/ PART CLEANING


           Parts coming out of the Die Cast machine typically need to be cleaned to remove flashing and remove
           any surface roughness. Large parts may be cleaned up as each part is produced at the exit of the Die
           Cast machine. Small parts are typically cast in quantities and at a rate that makes cleaning up at the
           machine impractical. All parts receive some level of post cast cleanup.
           Part Clean processes include Deburring, Tumbling, and Shot Blasting. Parts can be cleaned using 1 or
           more of these processes potentially more than once. Operators report Trim Shop work against the WIP
           LOTs created in the Die Cast area.
           Small parts going through these cleaning processes are weighed to generate an estimated part count
           instead of counting them individually. This theoretical count is used when reporting that a LOT of
           Material has completed on one of these processes.
           Large parts are physically counted as they are produced and are not weighed for estimation purposes.
           These parts are usually placed into bins that have separate layers for parts instead of just a bulk bin.
           These LOTS will not usually have Trim Shop work reported against them.
           Each bin of parts arrives at the Trim Shop with the LOT label applied in the Die Cast area. The operators
           update the LOT Tag with the number of parts that were processed (either actual count or estimated
           count)




### 2.1.4 MACHINING


           The machine shop hosts numerous machining, assembly prep, and assembly processes. In this area,
           rough part surfaces are machined to final specifications, additional features may be cut into the part,
           and parts may be placed in fixtures that feed automated assembly machines. Assembled parts (Finished
           goods) can be staged for shipment to the customer in this area. MES tracks the material processed in
           this area and maintains the LOT genealogy of parts integrated into Finished Goods.



           After machining, incoming LOTs may be split into Sub-LOTs, which must maintain their parent LOT
           relationship. Smaller parts like cam holders, rocker shafts, etc., are typically divided into sub-LOTs and
           used in several different assembly stations for various end item parts. Sub-LOTs are created for a variety
           of reasons, including isolated transfer to assembly (to prevent contact with other metal parts), WIP
           organization due to differences in work schedules across different parts of the plant, and part allocation
           when the same part can be used on multiple lines/assemblies.



           The creation of sub-LOTs serves a couple of purposes:



                1. After machining, the parts need to be placed in containers to stay clean and unblemished. These
                   containers keep the parts separated, preventing them from touching each other.
                2. The assembly process is typically the bottleneck, and parts may need to be staged in the WIP
                   area until assembly requires them. Once the parts awaiting assembly are machined, they are
                   placed in containers (sub-LOTs) to keep them separated, and a label is printed for those parts
                   that need to be placed in WIP. This label ties these parts back to the original parent lot.
           MES must support a configurable sub-lot size (count) for each component part to track when to produce
           a label for a sub-lot as the parent LOT is processed. This sub-lot size is a default presented on the user
           interface and can be adjusted by the operator when producing a sub-lot.
           The machine shop includes the following machines.
                                                              Min      Ref    Prod                             Planned
                         Mach                                  Per    Cycle    Per     Cycle        OEE          Qty
            Mach ID       No       Mach Desc                  Shift   Time    Shift    Time        Target       100p
              30          30       MS Assoc                   480               0
              33          535      Leak Test                  450               0
              34         1165      Leak Test                  450               0
              35          798      First Cut                  450               0
              36          880      First Cut                  450               0
              37          908      First Cut                  450               0
              38          909      First Cut                  450               0
              39          910      Leak Test                  450               0
              46         1166      PNA Op 10-1                 91             753
              47         1167      PNA Op 10-2                 91             753
              48         1168      PNA Op 10-3                 91             753
              49         1169      PNA Op 10-4                 91             753
              50         1170      PNA Op 10-5                 91             753
              51         1171      PNA Op 10-6                 91             753
              52         1172      PNA Op 10-7                 91             753
              53         1173      PNA Op 20-1                                753
              54         1174      PNA Op 20-2                                753
              55         1175      PNA Op 20-3                                753
              56         1176      PNA Op 30-1                                753        29         0.85        881
              57         1177      PNA Op 30-2                                753
              58         1178      PNA Op 30-3                                753
              59         1181      PNA Op 60                                  753
              60         1179      PNA Op 40                                  753
              61         1180      PNA Op 50                                    0
              63         1093      PNA Washer                                   0
              64         2153      PNA Op 60 FEC                                0
              65         1182      PNA Op 70A                                 753



                                                           Min      Ref    Prod                            Planned
                    Mach                                    Per    Cycle    Per    Cycle        OEE          Qty
            Mach ID  No            Mach Desc               Shift   Time    Shift   Time        Target       100p
              68    1183           PNA Op 70B                              753
              73    1763           OP10                                    413
              74    2477           PNA DOWEL PIN PRESS                     753
              75    2371           PNA FACE HEIGHT                         753
              76    1692                                           753
              77    2494           KIRA ELESYS                             1022
              78    2186           ELESYS HEAT SINK OP10                   1022
              79    2506           OP-10                                   344
              80    2507           Assembly                                344
              81    2508           Leaktest                                344
              82    2742           RV2 CAP AL ASY                          577
              83    2741           RJF CAP AL ASY                          577
              84    1761                                           577
              86     650           OP10-1                                  710       82
              87     656           OP10-2                                  710       82
              88    1687           OP20/30-1                               710       140
              89    1688           OP20/30-2                               710       140
              90    2340                                           710     22
              91    1689                                           710     10
              92    1690           LOST MOTION FLATNESS                    710        5
              96    1851           OP10-1                                  241
              97    1852           RNA MAKINO OP10-2                       241
              98    1959           R70 ASY & L/T V6                        645
              99    1660           RNO OP30                                645
             100    2003           OP20-1                                  241
             102    2002           OP20-2                                  241
             103    1663           RNA/R1B ASY L/T                         241
             104    1658           OP30-2                                  241
             105    1659           OP30-1                                  241
             109    2001           OP20-3                                  241
             111    2482           RXO/R5A OIL PAN ASY                     472
             112    1757           OP10                                    472
             113    2530           OP30-1                                  472
             114    2531           OP20-1                                  472
             115    2532           OP30-2                                  472
             116    2533           OP20-2                                  472
             117    2190           OP10-20 B                               515
             118    2191           OP10-20 A                               515
             119    2564           OP-30                                   515



                                                      Min      Ref    Prod                            Planned
                    Mach                               Per    Cycle    Per    Cycle        OEE          Qty
            Mach ID  No            Mach Desc          Shift   Time    Shift   Time        Target       100p
             121    2449           OP20/30                            553
             122    2606           OP10-2C                              0       29         0.85        881
             123    2607           OP10-1C                              0       29         0.85        881
             124    2608           OP10                                 0      26.3        0.85        972
             125    2628           OP60C                                0
             126    2609           OP10-1A                              0     33.75        0.85        757
             127    2610           OP10-2A                              0     33.75        0.85        757
             128    2611           OP20-1A                              0      33          0.85        775
             129    2612           OP30-1A                              0      32          0.85        799
             130    2613           OP30-2A                              0      32          0.85        799
             131    2631           OP50                                 0      31          0.85        825
             132    2629           OP60A                                0
             133    2630           OP60B                                0
             134    2614           OP10-1B                              0      34          0.85        752
             135    2615           OP10-2B                              0      34          0.85        752
             136    2616           OP10.5-2B                            0      34          0.85        752
             137    2617           OP20-1B                              0      33          0.85        775
             138    2618           OP30-1B                              0      32          0.85        799
             139    2619           OP30-2B                              0      32          0.85        799
             140    2620           OP10-1D                              0     36.25        0.85        705
             141    2621           OP20-1D                              0     36.25        0.85        705
             142    2635           OP40                                 0      31          0.85        825
             143    2622           OP20-2E                              0      38          0.85        673
             144    2623           OP10-2E                              0     36.25        0.85        705
             145    2624           OP10-2D                              0     36.25        0.85        705
             146    2625           OP20-2D                              0     36.75        0.85        696
             147    2626           OP20-1E                              0      38          0.85        673
             148    2627           OP10-1E                              0     36.25        0.85        705
             149    1643           WATER OUTLET ASY                   706      36
             152    2720           OP30                                 0      36          0.85        710
             154    2722           OP0                                  0     32.75        0.85        780
             155    2723           OP10.5-1B                            0      34          0.85        752
             156    2636           OP70A                                0      23          0.85        1111
             157    2637           OP70-C2A                             0     26.5         0.85        965
             158    2707           OP70-B1                              0     23.6         0.85        1083
             159    2708           OP70-C1                              0     26.5         0.85        965
             160    2724           OP70-C2B                             0     26.5         0.85        965
             161    2725           OP70-B2                              0     23.6         0.85        1083
             162    2721           OP30                                 0     34.5         0.85        741



                                                             Min      Ref    Prod                            Planned
                    Mach                                      Per    Cycle    Per    Cycle        OEE          Qty
            Mach ID  No            Mach Desc                 Shift   Time    Shift   Time        Target       100p
             163      0            N/A                                         0
             164    1486           COS OKUMA                                   0       190
             166    1135           COS MAZAK                                   0       215
             167     663           COS ROBO DRILL (OP-20)                      0       36
             169    1957                                               0
             170    1958                                               0
             171    1955           COS SEAL PRESS                              0
             172    2423           COS WASHER                                  0       402
             173     662                                               0
             174     585                                               0
             175     659                                               0      54
             176     657                                               0
             177    1667           HEATER OUTLET WASHER                        0
             178    1666                                               0
             179    2341           Parts Washer                                0       60
             180    1164           Bolt Torque Machine                         0       22
             218    1771           CAP A L OP10                                0
             219    1668           CAP A L OP10                                0
             220     641           CAP COOLER ROBODRILL                        0
             221    2654           CAP COOLER ROBODRILL                        0
             222    2655                                               0
             223     648           GUIDE PRESSURE OP20                         0
             224     649                                               0
             225    1611                                               0
             226    2562           RJ2 OIL PAN L/T                            0
             227    1797           CIVIC MAKINO                               0
             228    2719           CH EX1-2 OP20                             826      26.3
             230    1755           Side Case OP20-1                          280      77.5




### 2.1.5 ASSEMBLY


           The assembly area produces finished goods that may be fully assembled, partially assembled, or staged
           kits/trays of parts. Operators identify incoming LOTs or Sub-LOTs of component parts that are being fed
           into the line to produce finished goods. The Finished good has a BOM that drives which parts must be
           available to the line.
           Some assembly lines generate serial numbers for finished goods.



           Assembly lines are located in the machine shop. Some machining operations directly feed parts to the
           final assembly stations. Parts exiting the assembly area are moved to the delivery stations to be packed
           into specific dunnage and placed into containers for shipping.




### 2.1.6 DELIVERY


           The Delivery station is where finished goods are placed into Honda required containers. Parts and
           assemblies are placed onto trays with specific orientations and the part position and orientation is
           verified by cameras. If the arrangement of parts is not correct, the Line will stop, and the operator can
           look at the camera picture and determine what problem is being flagged. The line typically moves the
           part to a reject position where the operator can make corrections (add the missing part or reorient a
           part, etc.). the Operator then takes the tray back to the input side of the delivery line to be reimaged
           and moved to the shipping container.
           Once the shipping container is full, MES requests a new Shipping ID from the AIM system, and then MES
           prints a shipping label for each completed shipping container.




### 2.1.7 PART SERIALIZATION


           Currently, only two process lines serialize individual parts as they are produced. MES generates the
           serial number for each part produced on these lines and presents that serial number to a laser etching
           device that marks the part with the desired serial number.
           MES maintains the traceability of the constituent parts parent LOT number for each serialized part
           produced on an assembly line. This relationship is of utmost importance and must be maintained by
           MES as part of the permanent production records.




### 2.1.8 INSPECTION (DELIVERY STATION)


           Final part/tray inspection is part of the delivery station behavior. Typically, Inspection is performed by
           cameras that give a pass/fail (go/no-go) indication to MES for each final assembly. The pass/fail
           information is presented as OPCUA tags from the local PLC controlling the process.
           MES indicates the part being processed to the final assembly/inspection stations, and the camera uses
           local inspection programming for the specified part to determine if the final assembly is good or No-
           Good. If the part is “No-Good” it is prevented from leaving the assembly area and is removed or
           corrected and reprocessed. If the part fails, and there is a chance that other finished goods in the target
           container may be bad, then the container may be put on Quality Hold. This may also necessitate putting
           a component part sub-LOT and Parent LOT into a Quality Hold state. Note that the finished Goods
           container may need to go the Sort Cage for revalidation.
           Leak Tests are performed on some products (Fuel pumps, Oil Pans, etc.) Leak Test results are currently
           not recorded in MES.
           Torque checks are performed by automated tools and is used to interlock the automation (i.e., a torque
           error will stop the line until it is fixed). This data is currently not recorded in MES.




### 2.1.9 QC SAMPLING AND NO-GOOD PARTS


           Quality test samples can be taken from the various manufacturing areas. Test Samples taken from the
           Die cast area are processed through the expected steps (trim, machining, etc.) and then verified as good
           or bad parts using a “Fit and Function gauge” that stands in for the actual assembly process to allow
           final verification. If test parts fail the verification, their sampled LOT will be put on Quality Hold and
           may be cleared, reworked, or scrapped. These sample parts are tracked by hand by quality personnel.



           Each Sample Part is painted/marked so that they stand out from the normal part flow. Sample parts can
           be introduced into the manufacturing process mid-stream (i.e., while the line is processing other LOTs).
           This practice has caused tracking / LOT count issues resulting from extra machine cycles and over
           production.
           MPP uses a separate non-conformance tracking package (Intelex) to manage quality issues (no-good
           parts) and track the handling of quality issues. When a sample part fails testing, the quality person may
           put the sampled (source) LOT on Hold in the Intelex system and the manufacturing process may
           continue to use parts from the LOT that is on Hold. Note that this has caused LOT tracking issues since
           MES is not in synch with the state of a LOT in the Intelex system and sometimes LOT piece counts
           become unreliable as operators work around quality Hold related issues.
           MPP would like MES to capture data from the sample/test part process where possible and manage the
           Quality Hold Status within the MES if possible.



           See Figure 4 Paper based Sample Part Quality Record below which is an example of the paper record of
           quality checking a sample part.



           Figure 4 Paper based Sample Part Quality Record



           A Machine tool change will necessitate a new quality sample be taken and verified. Machine samples
           after tool changes are saved for 24 hours for reference purposes and then scrapped.
           Die cast area samples are taken at the beginning of each shift and whenever a Die is changed. Samples
           are taken for each cavity in use and treated as unique LOT samples. When a Die is changed, the samples
           are marshalled into “Ship ahead baskets” that are prioritized to expedited quality checks and not allow
           too much production to be produced while waiting for quality verification.
           No-Good parts are not currently tracked in the Legacy MES solution. Most No-Good parts are simply
           scrapped and remelted for reuse.




### 2.1.10 SORT CAGE


           The Sort Cage is a special MES Delivery Station primarily used to re-verify production for shipment.
           Whereas standard Delivery Stations are typically dedicated to a specific line/product, the Sort Cage can
           process any product. The Sort cage is used any time that a shipping container needs to be re-inspected
           and re-packed (e.g., Non-conformance issue, label failure, needing repacked, etc.)
           A shipping container must be placed on hold within the AIM system before it can be processed at the
           Sort Cage. A container that needs to be placed on hold is moved to the Sort Cage where the LOT is
           scanned into MES, then MES identified the bad lot to the AIM system, then AIM provides a HOLD



           number which is printed by MES as a HOLD Ticket. That Hold ticket is placed over (affixed to) the
           original LOT Tag identifying it as a held container. The hold process invalidates the original shipping
           container label in the AIM system, and a new shipping label must be printed for the shipping container if
           the products are validated at the Sort Cage.
           The Sort Cage is capable of visual confirmation of the container/trays just like to original assembly
           station. The Operator scans in the Hold ticket, and then processes the container, re-verifying it for
           shipment. If the container is verified, MES requests a new Container Label from the AIM system and
           prints the ticket which is then applied to the container and the container is moved to shipping.
           Currently, when the shipping container contains serialized parts, the operators must manually re-enter
           those serial numbers into the system for the associated container so they can be included on the new
           shipping label.
           Unlike the other dedicated delivery stations, the Sort Cage does not draw down (consume) inventory or
           produce new products. When the container includes serialized parts, those parts maintain their serial
           number when repackaged. The current MES does not assist the migration of serial numbers from the
           old container to the new container and requires the operator to manually records and re-enter the serial
           numbers.
           The current MES does not support identifying a part removal and replacement at the Sort Cage. The
           new MES must provide a means for entering a replacement part (and the associated LOT information)
           into a finished good at the Sort Cage. The final shipped finished good must be traceable to the
           originating LOTs for all parts included in the shipping container.




### 2.1.11 BARCODE LABEL PRINTING (LOT/SUB-LOT IDS AND CUSTOMER SHIPPING LABELS)


           The MES solution prints barcode labels to identify LOTs, Sub-LOTs, Finished goods and shipping
           containers. MPP uses Zebra barcode printers. MES creates the Zebra Printing Language (ZPL) code
           needed for the barcode labels desired for MPP Parts, and the finished good shipping identifiers needed
           for the final customer.
           MPP uses the AIM system to obtain shipping container label information for outgoing shipping
           containers. MES communicates with the AIM system to obtain a shipping number (shipper) and then
           prints the customer shipping labels as a shipping container is completed.



           (See Figure 5 Example LOT/Container Barcode Label 2 ↓)



           Figure 5 Example LOT/Container Barcode Label




### 2.1.12 PASS THROUGH PARTS


           Pass Through Parts are parts machined elsewhere that-
                1) are simply repackaged into customer-specific dunnage, relabeled, and then shipped to the
                   customer, or
                2) are introduced to the assembly process (by passing the machining).
           Currently pass through parts are either received at the Madison manufacturing site or received at an
           offsite warehouse and then moved to the Madison facility. These parts arrive on pallets which contain
           packages bearing vendor LOT information (LOT number, and possibly a range of serial numbers
           associated with each LOT).
           MPP uses the AIM system to print new customer shipping labels for these materials when they are not
           consumed in the manufacturing process.
           Legacy MES is not managing pass through parts, but MPP would like this to be supported by the future
           MES.




### 2.1.13 OFF SITE (MES APP)


           The Legacy MES Off-site app is a limited feature application that is based upon the existing “Delivery”
           station behavior. This off-site app is configured to support only LOT creation/identification, weigh scale
           interface, and Label printing for shipment.
           An Operator can use the Off-Site application to create a LOT number, capture the weight of material,
           and print a label such that the MES system can track the LOT and eventually consume the parts from
           the LOT. In some ways, this is much like the LOT creation at the Die Cast area with the addition of
           printing a barcoded label and possibly a scale weight.
           MES should not report consumption of component parts used in the LOT in the Off-site app.
                         Non-conformance from off-site – uses paper tags – KD (Kiln Dried) skids .. might
                         be just putting components – o-rings, screws, etc. and then they come into MPP
                         for assembly into the finished good.




### 2.1.14 OPERATOR STATIONS


           MPP operator stations are used for scanning in the lot tags when the lots come to that specific
           manufacturing process location and printing labels where necessary. LOTs are identified/created in MES
           in the Die Cast area using the Die Cast operator station or when received at as pass through parts. MES
           LOTs may be created by a special “off-site” application that is used to allow off site producers to print
           container labels for the identified LOTs.
           An operator station in the Trim shop is used to update LOT information upon completion of a Trim Shop
           operation. The Trim Shop operator scans the LOT ID from the tag created in the Die Cast area and
           updates the piece count for that LOT.
           There are many stations in the machining/assembly area. In the Machine Shop LOTs are entered into
           and out of the Machining or Assembly/Delivery stations. Stations in the machining and Assembly
           delivery area are limited to processing only certain production items. The current MES will warn and
           prevent an operator for entering a LOT of materials on a machine/line that does not support the parts
           associated with the LOT.
           As mentioned above, there is an addition Operator Station at the Sort Cage that supports all products.
           There is currently one “Off-Site” site with approximately 15 stations.
           Some Stations have local barcode label printers that print labels for sub-LOTs and shipping containers.
           These may also print HOLD ticket/Labels for WIP LOTS that have some type of non-conformance.



           Currently one station/Line provides serial numbers to machines that etch the serial number onto parts.
           These serial numbers must maintain their genealogy to the Sub-Lot and Parent LOT that they were
           derived from.



           2.1.14.1            O PERATOR S TATIONS C ONFIGURATION ( DASHBOARDS ) F EATURES
           Legacy MES Operator stations User Interface is presented through dashboards that can be configured to
           enable a variety of features. The following section identifies what can be configured for each
           station/Dashboard.
            Dashboard/Feature                                Description
            CreateAllocationDashboardConfiguration           used at locations to create LOTs
            FullLotScanningIsEnabled                         Allow scanning in a complete LOT



            FinalAssemblyDashboardConfiguration
            RefreshInterval                                  Specify UI count data update interval
            LotHistoryDisplayCount                           Number of historical LOTs that can appear in the
                                                             display list
            ContainerCreationIsSupported                     Allow the Creation of new Containers
            CameraImageDisplayMode                           Allow multiple images on display
            CameraIPAddresses                                Specify IP addresses of Cameras for this line
            IsVisionModeEnabled                              Enable Camera Good/No Good Part verification
            IsScaleModeEnabled                               Enable Scale weight verification
            EMLineName                                       Has event Message Support configuration
            EMTaskName                                       Has event Message Support configuration
            EMTargetWeightChangeEvent                        Has event Message Support configuration
            MessageType                                      Has event Message Support configuration
            VisionInterface
            CameraImageRotations                             Unused
            BeforeContainerCreateScriptID                    .net script segment to be executed before
            PLCPort                                          PLC COM Port it applicable



            LotCreateDashboardConfiguration
            RefreshInterval                                  Specify UI count data update interval
            LotHistoryDisplayCount                           Number of historical LOTs that can appear in the
                                                             display list
            SaveButtonUserInterfaceScriptID                  .net script segment to be executed before



            LotTrackingDashboardConfiguration
            RefreshInterval                                  Specify UI count data update interval
            LotHistoryDisplayCount                           Number of historical LOTs that can appear in the
                                                             display list
            LotHistoryAtSourceLocationDisplayCount           How many historical Source Lots are visible
            LotHistoryAtSourceLocationAreaID                 How many historical Source Lots are visible (Area)
            LotHistoryAtSourceLocationProductionLineID       How many historical Source Lots are visible (Line)



            LotHistoryAtSourceLocationWorkCellID             How many historical Source Lots are visible
                                                             (Workcell)
            MoveButtonUserInterfaceScriptID                  What script to run when the move button is pressed
            LotHistoryAtSourceLocationIsActive               LOT History is active
            LotTrackingType                                  LOT
            PopulateFixedQuantityOnItemSelection             Enabled/Disabled setting
            FixedQuantityToPopulate                          Count to populate
            PopulateInProcessQuantityOnItemSelection         Enabled/Disabled setting
            AssemblyLotScanningIsEnabled                     Enabled/Disabled setting
            PopulateMaterialDefaultBasketQuantityOn          Enabled/Disabled setting
            ItemSelection



            MaterialLabelPrintDashboardConfiguration
            PrinterNames                                     Which Printers can be used



            SortDashboardConfiguration



            WorkOrderDashboardConfiguration
            RefreshInterval                                  Specify UI count data update interval
            WorkOrderDisplayCount                            Number of work orders are visible



            WorkstationDashboardConfiguration
            WorkstationID                                    Which work station
            DisplayOrder                                     position of this work station on display list
            LotCreateDashboardConfigurationID                Which LOT creation screen is used at this work
                                                             station
            LotTrackingDashboardConfigurationID              Which LOT tracking screen is used at this work station
            WorkOrderDashboardConfigurationID                Which work order screen is used at this work station
            FinalAssemblyDashboardConfigurationID            Which delivery screen is used at this work station
            CreateAllocationDashboardConfigurationID         Which Allocation screen is used at this work station
            SortDashboardConfigurationID                     Which Sort screen is available to this work station
            MaterialLabelPrintDashboardConfigurationID       Which Label Print screen is used at this work station




## CONTAINER/LOT/PIECE TRACKING


           The existing MES tracks materials in containers that represent a collection of parts, which are tracked as
           a LOT and may also represent a collection of individually identified serialized parts. Thus, the existing
           MES identifies each container as either serialized or LOT tracked (parts not serialized). The part
           associated with the container will have a BOM that consists of one or more component parts.
           Ultimately, containers are tracked through the required processes and may be 'consumed' into



           assemblies (or trays of parts) and produced into containers that are shipped to customers. Containers
           eventually receive customer-supplied shipping labels (e.g., pallet/container labels from the AIM system)
           prior to leaving MPP.



           A LOT number (e.g., 10548746) is a unique identifier for a collection of the same parts being tracked
           together as a unit/collection. Material is manufactured/processed in most cases at MPP in batches,
           which are assigned LOT numbers. In some cases, each part within the LOT is assigned a serial number
           that uniquely identifies individual parts.



           LOT and serial number traceability is of paramount importance to MPP, and each part shipped must be
           traceable to either a received LOT ID (in the case of purchased or pass-through parts) or a produced LOT
           ID for manufactured parts. An assembled part that integrates a variety of parts from unique LOTs must
           be able to trace each component part back to the LOT it was taken from.



           In some cases, LOTs (Parent LOT) can be broken into sub-LOTs (Child LOT) containing a subset of the LOT
           contents which can be tracked separately from the parent LOT. The parent/child relationship must be
           maintained throughout the manufacturing process.



           MPP currently tracks material by applying LOT Tracking Tags (LTT) to a container/bin of parts, and that
           LTT has the assigned LOT number printed on the tag in human-readable and barcoded formats. LOT tags
           are printed in bulk with each successive tag bearing the successive LOT number in sequence. Each tag is
           applied to a batch of parts in the die-cast area, and when the die-cast production data is entered into
           MES, the operator scans the barcoded LOT number, identifies the part number being tracked, and the
           quantity of parts produced, and MES records the LOT information for LOT tracking and genealogy
           records.



           LOTs originate in the die-cast area where they are assigned an LTT with their part identity and count.
           Next, LOTs are typically processed in the trim shop where they are deburred, etc., and weighed in order
           to estimate/confirm the quantity of parts in the LOT. Lots are then moved into the machining area
           where they are machined and used in the assembly of finished goods. Some diecast LOTs are cleaned at
           the die-cast machine and move directly to the machining area. MES supported LOT creation,
           movement, and consumption actions are summarized for each area in the following sections.




### 2.2.1 MPP LOT TRACKING TICKET (LTT)


           MPP Uses a LOT Tracking Ticket (LTT) to identify LOTS within the facility. MPP Pre-prints the LTTs, and an
           operator simply affixes a tag to a part bulk container for identification and tracking purposes. The LTT
           provides a human readable identifier or a part bin as it is moved within the facility.



                                                  Metal baskets are placed at the end of the casting area to
                                                  collect parts. Operators affix LTTs to the baskets providing
                                                  a unique LOT (serial) number that will stay with the LOT
                                                  until parts are consumed.
                                                  The LTT shown ← here has the part number, the machine
                                                  that casted the part, the die cast, the shift, the number of
                                                  parts per shift and the operator’s initials. The number of
                                                  good parts that have been collected are taken from the
                                                  trim press counter adjacent to the Casting machine.
                                                  Once the operator determines that the basket is full, they
                                                  take the tag over to the MES screen. They scan the tag to
                                                  put the LOT number into the system and manually type in
                                                  the associated data including the total number of parts in
                                                  that basket. This now become the trackable lot inside the
                                                  MES system.
                                                  A sticker is then placed on the label to show that it has
                                                  now been put into the system.
                                                  The tag follows the basket into the Trim and Machine
                                                  shop. When the basket enters the Trim shop, it is then
                                                  scanned into the Trim shop station.
                                                  This process also continues into the Machine Shop.



             Figure 6 LOT Tracking Ticket (LTT)




### 2.2.2 DIE CAST AREA LOT PROCESSING


           MPP pre-prints the LTTs that are attached to each material bin to identify the parts in the bin. The LTT is
           used to hand record shift production data, the Die #/and Cavity used to produce the parts, and the
           number of parts produced by each shift. When the bin is full or the requested amount is produced, an
           operator takes the LTT to an MES Kiosk and enters the LOT number, Part Number, and production data
           into the system. This creates the LOT in MES and allows MES to track the Lot through the other process
           Areas. These parts represent work in progress (WIP).
                     Note that Bad / rejected parts are not tracked on the LTT so MES does not have the ability to
                     augment production performance data to reflect quality performance. The LTT records the
                     number of parts produced each shift which may support a crude performance report based upon
                     theoretical verses actual part production rates.
           Parts come off the die cast machines into the adjacent trim machine that trims the excess aluminum
           from the parts and put the good parts into a basket, bad parts and trim is put in another container to be
           remelted. One basket will have one specific part from one specific cavity of one specific die. When these
           baskets are placed next to the trim machine, they will have an LTT attached bearing a pre-printed LOT
           ID. Operators manually record the part number, Cavity, cast date, Machine #, Cast, Shift, number of
           good parts, and initials of the operator on the LTT and manually key that data into the MES.
           Baskets of specific parts coming off the casting machines are kept next to the machines until the baskets
           are deemed full. This is not kept to a specific number, but the operators decide when the baskets are
           full. Consequently, there is no target LOT piece count for any given part.
           LOTs either are moved to the TRIM Shop for further cleanup or in the case of larger parts, they are
           manually cleaned at the Die Cast machine, and the LOT is moved to the Machine Shop for processing.




### 2.2.3 TRIM AREA LOT PROCESSING


           Hi volume Die Cast Part LOTs are cleaned and trimmed in the TRIM Shop. Trim Shop Operators process
           parts in mass one LOT at a time. The TRIM Shop processing lines are not managed by MES. TRIM shop
           activities are reported to MES when a LOT completes whatever processing is required in the Trim Shop.
           Upon completion of a Trim Shop process, the operator weighs the bin of trimmed parts and calculates a
           theoretical quantity of parts based upon the measured weight (the scale information is read by the
           operator and is not connected to the MES system.)
           The operator records the estimated number of parts on the LTT under the appropriate shift. The
           operator does not enter any data about parts rejected at this process (which is rare), but the count of
           parts in the LOT may go down as a result of the estimate based on weight.
           The operator then updates the LOT’s record in the MES system by scanning the LOT number on the LTT
           and manually entering the count of parts derived from the weight. MES takes no specific action if the
           LOT quantity has changed, and simply updates the count to reflect the revised quantity. MES does
           maintain an internal log that reflects that the quantity changed at this location.




### 2.2.4 LOT QUEUES IN MACHINING AND ASSEMBLY


           The flow of material LOTs into the machining and assembly area it arranged in queues that the machine
           operators maintain. This queue is assumed to be first in first out (FIFO), but the operator can manually
           choose the next LOT to processes. Operators enter LOT numbers into a queue of LOTs to be processed
           at a given machine, and the operator identifies which LOT is currently being used at the machine by
           selecting one from the queue. MES tracks the LOT part count as the machine cycles through each LOT of
           materials, and If the current LOT count falls to zero, MES automatically starts drawing parts from the
           next LOT in the queue.
           The operator can also stop drawing from a LOT and switch to a different LOT from the queue without
           regard to the LOT’s position in the queue.
           One issue in the current MES stems from the fact that MES is not in synch with the nonconformance
           part management (NCM) process. In this case A LOT may be placed on hold after it was placed in the
           queue, and MES may be unaware of this HOLD status, and proceeds to consume parts from the HELD
           LOT when in fact the operators did not automatically proceed to using that LOT. This results in tracking
           and counting issues that must be manually addressed by administrators.




### 2.2.5 LOT/ SUB-LOT IN MACHINING AND ASSEMBLY


           LOTs of WIP material must be identified prior to processing in the Machine Shop for both machining and
           assembly.
           The current MES logically tracks materials in the area as operators identify LOTs entering or leaving
           Machining, and LOTS entering or leaving Assembly. WIP inventory can be physically staged ahead of any
           machining line, between machining and assembly lines, or after assembly. The MES system is not
           tracking the precise location of a WIP LOT except when it is being processed on a specific line.
           LOTs may be divided into sub-LOTs as part of staging for the assembly processes. This is mainly done to
           keep the parts separated in trays after machining so the parts don’t rub against each other. Also,
           individual part instances are tracked as they are integrated/consumed into final goods in the assembly
           process (by their LOT ID and Serial number when available). It is critical for each finished good to
           maintain a record of the full genealogy (LOT history) and manufacturing history of the parts used to
           produce the finished good.
           Some machining areas are coupled directly to assembly areas and in such cases, MES tracks the parts
           from the machining LOT to the Assembly station as the manufacturing line processes the materials. MES
           passes part data to automated assembly stations and receives quality information (good/no-good) from
           the inspection systems. MES also provides serial numbers for and interlocks some assembly machine
           automation steps when bad parts are detected. (5GO is only machine that is interlocked at this time)
           The current MES uses the “Machining IN/OUT”, “Assembly IN/Out” as well as “Allocate Material”
           operator screens to logically group WIP LOTs/Sub-Lots which are at each stage of production.



           Operators identify LOTs entering the Machining lines using a MES Screen called “Machining IN”. When
           the material is not automatically continuing to the Assembly line, an Operator can use the MES screen
           “Machining OUT” to identify the WIP LOT that is being moved to local inventory. Machining OUT is also
           used to support breaking a LOT into sub-LOTs and requesting a label for a sub-LOT. After being identified
           by “Machining OUT” process, sub-LOTs receive new barcode labels and are logically placed into local
           storage waiting for final assembly or placed close to the final assembly intake.
           (Label is seen in Figure 7)



           Figure 7 Sub-Lot Label



           Note that a default Sub-LOT piece count is assigned to each part that use sub-lots. This Sub-LOT count is
           typically a physical constraint based on material handling dunnage that sets the maximum Sub-LOT
           count for a given part. Note that an operator can overwrite the Sub-LOT number with a lesser count if
           the Sub-LOT runs short of pieces.
           The Sub-LOT is identified as available to the Assembly line in order to process the LOT on the Line
           through a process called “Assembly IN” or “Allocate Material” Note that this is also used to identify LOTs
           of purchased components at the line.
           A LOT exiting at an Assembly line must be processed by the “Assembly OUT” process which logically
           places the LOT into a local shipping container and makes it available to be shipped. The Assembly



           process includes a final Inspection (usually camera based) which must verify the part/tray in order to
           have a good product.




### 2.2.6 LOT QUALITY HOLDS


           A LOT can be placed on hold due to some kind of non-conformance. MES must be able to identify all
           WIP items, finished goods, Shipping Containers etc. that reference material associated with the LOT on
           Hold. MES must keep records of LOTs changing to and from the HOLD state which may occur multiple
           times for different reasons, etc.
           A shipping container may also be placed on HOLD. This requires MES to place the LOT on hold in the
           AIM system. Shipping Containers must be on hold in order to be checked into the Sort Cage to be
           requalified. Once requalified, the LOT receives a new LOT number and Shipping label from the AIM
           system. See section 2.1.10.
           NOTE that MES prints HOLD labels when a LOT is placed on hold and the operators apply the Hold label
           over the top of the normal LOT label.




### 2.2.7 SORT CAGE


           Containers processed on the Sort Cage receive new LOT numbers when processed. The LOT number
           entering the Sort Cage must first be placed on a HOLD state due to some non-conformance issue. A new
           LOT number is created when the SORT process reconfirms the container, and MES requests a new
           Container Label from the AIM system when the container receives a GOOD status after inspection
           (basically reproducing the delivery station behavior).
           If the container LOT contains serialized parts, those serial numbers are maintained and must be copied
           into the new container’s manifest.




## EXTERNAL SYSTEM INTEGRATIONS



### 2.3.1 AIM SYSTEM


           The AIM software is used to provide shipping label data required by Honda. MES communicates with the
           AIM system to request the next shipping label number (Shipper) to be assigned to a Container that is
           ready for shipment.
           The AIM solution presents a standard WEB Service API that is used by MES to request a container
           shipping number (shipper), update the status of a Shipper, place a Shipper on hold, or release a Shipper
           from the hold state.




### 2.3.2 PLC AND PLANT AUTOMATION EQUIPMENT


           The existing MES uses OPC technology to communicate with a variety of devices including PLCs,
           Cameras, and weigh scales. The current MES uses Software Toolbox’s “Top Server” and “Omni Server”
           OPC server to access data from the process. These servers will be kept and used for the new MES unless
           it is decided that they are better suited for the Ignition I/O drivers.



            Currently the following PLCs/Line controls provide the following OPC Tag data – a “1” in the column
           indicates the Tag is configured for the line. The actual OPC tags used to trigger event/actions can be
           found in Appendix C.



                                                                                                                                                                     LINE



                                        5A2_L1_CamHolderAssy



                                                                                     5A2_L2_CamHolderAssy
                                                               5A2_L1_FuelPumpAssy



                                                                                                            5A2_L2_FuelPumpAssy



                                                                                                                                                                                                                                                    6MA_CamHolderAssy



                                                                                                                                                                                                                                                                        RPY_CamHolderAssy
                                                                                                                                                                                           6B2_CamHolderAssy
                                                                                                                                                                      5K8_64A_OilPanAssy



                                                                                                                                                                                                                                6FB_CamHolderAssy
                                                                                                                                                                                                               6C2_6MA_OilPan
                                                                                                                                                    5J6_OilPanAssy



                                                                                                                                                                                                                                                                                            Sort_OilPan



                                                                                                                                                                                                                                                                                                          Sort_Totes
                                                                                                                                  5G0_A1



                                                                                                                                           5G0_A2
                  OPC Tag
        InspectionComplete                                                                                                                                  1                   1                    1                 1                  1                   1                   1               1             1
        ContainerName                                                                                                                                                                                1                                    1                                       1
        ContainerCount                             1                      1                     1                      1             1        1
        ContainerCountRequest                      1                      1                     1                      1             1        1
        ContainerSize                              1                      1                     1                      1             1        1
        DataReady                                  1                      1                     1                      1             1        1
        HardwareInterlockEnforced                  1                      1                     1                      1             1        1
        MESAlarmText                               1                      1                     1                      1             1        1
        MESAlarmType                               1                      1                     1                      1             1        1
        MESInterlockEnforced                       1                      1                     1                      1             1        1
        PartComplete                               1                      1                     1                      1             1        1
        PartMultiplier                             1                      1                     1                      1             1        1
        PartSN                                     1                      1                     1                      1             1        1
        PartType                                   1                      1                     1                      1             1        1
        PartValid                                  1                      1                     1                      1             1        1
        ScaleLatch                                                        1                                            1             1        1
        TransInProc                                1                      1                     1                      1             1        1
        PartNumber                                                                                                                                          1                   1                    1                 1                  1                                       1               1             1
        TrayLocked                                                                                                                                          1                   1                    1                 1                  1                   1                   1               1             1
        VisionPartNumber                                                                                                                                    1                   1                                      1                                                                          1             1
        PartDisposition01                                                                                                                                                                            1                                                                            1
        PartDisposition02                                                                                                                                                                            1                                                                            1
        PartDisposition03                                                                                                                                                                            1                                                                            1
        PartDisposition04                                                                                                                                                                            1                                                                            1
        PartDisposition05                                                                                                                                                                            1                                                                            1
        PartDisposition06                                                                                                                                                                            1                                                                            1
        PartDisposition07                                                                                                                                                                            1                                                                            1
        PartDisposition08                                                                                                                                                                            1                                                                            1



        PartDisposition09                        1                        1
        PartDisposition10                        1                        1
        PartDisposition11                        1                        1
        PartDisposition12                        1                        1
        PartDisposition13                        1                        1
        PartDisposition14                        1                        1
        PartDisposition15                        1                        1
        PartDisposition16                        1                        1
        PartDisposition17                        1                        1
        PartDisposition18                        1                        1


