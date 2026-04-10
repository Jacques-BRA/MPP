# Appendix G — FWI Event Manager (EM)

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.



> ⚠️ **SPARK SECTION — HIGH DEPENDENCY**  

> This entire section describes Flexware's SparkMES framework. Blue Ridge does not have access to this framework.  

> Use this section to understand the **intended architecture and capability** only.  

> Every subsection will require a Blue Ridge-native design decision.


---


           Appendix G.                          FWI E VEN T M A NAGE R (EM)
           The original MES was built on the Flexware Innovation Event Manager (EM). EM is a configurable event
           management platform that support recognizing process events and executing actions and steps in
           response. The actions include capturing and writing to OPC process data tag, and executing scripts that
           implement business logic and database back end activities. Much of the MPP MES functionality is
           effected by processing events from scales, PLCs and Cameras, and providing responses that including
           part numbers, serial numbers, and process setpoint information, as well as update database artifacts
           that support the production tracking needs of the business.



           Current Lines and Tasks configured in the system



            Line                                Task
            59B Line 1 - Fuel Pump 1 Assembly   Fuel Pump Assembly
            5A2 Line 1 - Cam Holder Assembly    Cam Holder Assembly
            5A2 Line 1 - Fuel Pump Assembly     Fuel Pump Assembly
            5A2 Line 2 - Cam Holder Assembly    Cam Holder Assembly
            5A2 Line 2 - Fuel Pump Assembly     Fuel Pump Assembly
            5G0 - Line 1                        Assembly 1
            5G0 - Line 2                        Assembly 2
            5G0 - Line 2 Backup                 Assembly 2
            5J6 - Oil Pan Assembly              Oil Pump Assembly
            5K8 64A - Oil Pan Assembly          Oil Pump Assembly
            5PA Line 1 - Fuel Pump 1 Assembly   Fuel Pump Assembly
            6B2 - Cam Holder Assembly           Cam Holder Assembly
            6B2 Line 1 - Fuel Pump 1 Assembly   Fuel Pump Assembly
            6C2 6MA - Oil Pan Assembly          Oil Pump Assembly
            6FB - CH and OP Assembly            CH and OP Assembly
            6MA - Cam Holder Assembly           Cam Holder Assembly
            6MA - Cam Holder Assembly - 2       Cam Holder Assembly
            RPY - Cam Holder Assembly           Cam Holder Assembly
            RPY - Compressor Bracket Assembly   Compressor Bracket Assembly
            RPY Line 1 - Fuel Pump 1 Assembly   Fuel Pump Assembly
            Sort Line - Oil Pan                 Oil Pan Sort
            Sort Line - Totes                   Totes Sort



           Current Event configured in the system
           Events are signals from the process that MES monitors and responds to. This table identifies the events
           monitored for each line and task. Each event (unique EventID in table) is configured to respond to a
           specific OPC event served by one of two OPC servers; Omniserver, or TOP Server. Omniserver is used
           primarily to communicate with TCP/Ethernet devices (e.g., weigh scales). TOP Server is used to
           communicate with PLCs.



           Events with blank OPC data are triggered by the Operator Interface.



           The Trigger Name column values imply the following:



                    “EQ” trigger when set to True
                    “all” Trigger on any data change



                                                      Event id
                                                                                                        OPC



                                                                                                                                                                                                   trigger
                                                                                                        Server
            Line                task                             event                                  Name          Access Path                            OPC Item ID
            59B Line 1 - Fuel
            Pump 1 Assembly     Fuel Pump Assembly    17         100 - Net Weight Update                OmniServer                                           59B_1_FP_1.NET_DataReady              EQ
            5A2 Line 1 - Cam
            Holder Assembly     Cam Holder Assembly    2         200 - Data Ready                       TOP Server     5A2_L1_CamHolderAssy.ProfaceLT_3300   DataReady                             EQ
            5A2 Line 1 - Fuel
            Pump Assembly       Fuel Pump Assembly     8         200 - Data Ready                       TOP Server     5A2_L1_FuelPumpAssy.ProfaceLT_3300    DataReady                             EQ
            5A2 Line 2 - Cam
            Holder Assembly     Cam Holder Assembly    9         200 - Data Ready                       TOP Server     5A2_L2_CamHolderAssy.ProfaceLT_3300   DataReady                             EQ
            5A2 Line 2 - Fuel
            Pump Assembly       Fuel Pump Assembly    10         200 - Data Ready                       TOP Server     5A2_L2_FuelPumpAssy.ProfaceLT_3300    DataReady                             EQ
            5G0 - Line 1        Assembly 1            64         003 - Container Count Request          TOP Server                                           5G0_A1.5G0_A1.ContainerCountRequest   EQ
            5G0 - Line 1        Assembly 1            65         200 - Data Ready                       TOP Server                                           5G0_A1.5G0_A1.DataReady               EQ
            5G0 - Line 1        Assembly 1            66         300 - Net Weight Update                OmniServer                                           5G0_Front_Scale.NET_DataReady         EQ
            5G0 - Line 1        Assembly 1            67         400 - Process Part                     TOP Server                                           5G0_A1.5G0_A1.PartComplete            EQ
            5G0 - Line 2        Assembly 2            72         003 - Container Count Request          TOP Server                                           5G0_A2.5G0_A2.ContainerCountRequest   EQ
            5G0 - Line 2        Assembly 2            73         200 - Data Ready                       TOP Server                                           5G0_A2.5G0_A2.DataReady               EQ
            5G0 - Line 2        Assembly 2            75         300 - Scale Data Ready                 OmniServer                                           5G0_Rear_Scale.NET_DataReady          EQ
            5G0 - Line 2        Assembly 2            76         400 - Process Part                     TOP Server                                           5G0_A2.5G0_A2.PartComplete            EQ
            5G0 - Line 2
            Backup              Assembly 2             5         003 - Container Count Request          TOP Server                                           5G0_A2.5G0_A2.ContainerCountRequest   EQ
            5G0 - Line 2
            Backup              Assembly 2             6         200 - Data Ready                       TOP Server                                           5G0_A2.5G0_A2.DataReady               EQ
            5J6 - Oil Pan
            Assembly            Oil Pump Assembly     82         100 - Tray Locked                      TOP Server     5J6_OilPanAssy.MicroLogix1400         TrayLocked                            ALL
            5J6 - Oil Pan
            Assembly            Oil Pump Assembly     83         200 - Inspection Complete              TOP Server     5J6_OilPanAssy.MicroLogix1400         InspectionComplete                    ALL
            5K8 64A - Oil Pan
            Assembly            Oil Pump Assembly     42         100 - Tray Locked                      TOP Server     5K8_64A_OilPanAssy.MicroLogix1400     TrayLocked                            ALL
            5K8 64A - Oil Pan
            Assembly            Oil Pump Assembly     43         200 - Inspection Complete              TOP Server     5K8_64A_OilPanAssy.MicroLogix1400     InspectionComplete                    ALL
            5PA Line 1 - Fuel
            Pump 1 Assembly     Fuel Pump Assembly    27         050 - Target Weight Change                                                                                                        EQ
            5PA Line 1 - Fuel
            Pump 1 Assembly     Fuel Pump Assembly    28         100 - Net Weight Update                OmniServer                                           5PA_1_FP_1.NET_DataReady              EQ
            6B2 - Cam Holder
            Assembly            Cam Holder Assembly   19         100 - Tray Locked                      TOP Server     6B2_CH.MicroLogix1400                 TrayLocked                            ALL
            6B2 - Cam Holder
            Assembly            Cam Holder Assembly   20         150 - Set In-Process Container                                                                                                    ALL



            6B2 - Cam Holder
            Assembly              Cam Holder Assembly   22   200 - Inspection Complete              TOP Server     6B2_CH.MicroLogix1400               InspectionComplete         ALL
            6B2 Line 1 - Fuel
            Pump 1 Assembly       Fuel Pump Assembly    23   100 - Net Weight Update                OmniServer                                         6B2_1_FP_1.NET_DataReady   EQ
            6B2 Line 1 - Fuel
            Pump 1 Assembly       Fuel Pump Assembly    24   050 - Target Weight Change                                                                                           EQ
            6C2 6MA - Oil Pan
            Assembly              Oil Pump Assembly     29   200 - Inspection Complete              TOP Server     6C2_6MA_OilPanAssy.MicroLogix1400   InspectionComplete         ALL
            6C2 6MA - Oil Pan
            Assembly              Oil Pump Assembly     30   100 - Tray Locked                      TOP Server     6C2_6MA_OilPanAssy.MicroLogix1400   TrayLocked                 ALL
            6FB - CH and OP
            Assembly              CH and OP Assembly    87   100 - Tray Locked                      TOP Server     6FB_CH.MicroLogix1400               TrayLocked                 ALL
            6FB - CH and OP
            Assembly              CH and OP Assembly    89   200 - Inspection Complete              TOP Server     6FB_CH.MicroLogix1400               InspectionComplete         ALL
            6MA - Cam Holder
            Assembly              Cam Holder Assembly   84   100 - Tray Locked                      TOP Server     6MA_CH.MicroLogix1400               TrayLocked                 ALL
            6MA - Cam Holder
            Assembly              Cam Holder Assembly   85   150 - Set In-Process Container                                                                                       ALL
            6MA - Cam Holder
            Assembly              Cam Holder Assembly   86   200 - Inspection Complete              TOP Server     6MA_CH.MicroLogix1400               InspectionComplete         ALL
            6MA - Cam Holder
            Assembly - 2          Cam Holder Assembly   44   100 - Tray Locked                      TOP Server     6MA_CH.MicroLogix1400               TrayLocked                 ALL
            6MA - Cam Holder
            Assembly - 2          Cam Holder Assembly   45   200 - Inspection Complete              TOP Server     6MA_CH.MicroLogix1400               InspectionComplete         ALL
            RPY - Cam Holder
            Assembly              Cam Holder Assembly   79   200 - Inspection Complete              TOP Server     RPY_CH.MicroLogix1400               InspectionComplete         ALL
            RPY - Cam Holder
            Assembly              Cam Holder Assembly   80   100 - Tray Locked                      TOP Server     RPY_CH.MicroLogix1400               TrayLocked                 ALL
            RPY - Compressor      Compressor Bracket
            Bracket Assembly      Assembly              40   100 - Net Weight Update                OmniServer                                         RPY_1_CB_1.NET_DataReady   EQ
            RPY - Compressor      Compressor Bracket
            Bracket Assembly      Assembly              41   050 - Target Weight Change                                                                                           EQ
            RPY Line 1 - Fuel
            Pump 1 Assembly       Fuel Pump Assembly    15   100 - Net Weight Update                OmniServer                                         RPY_1_FP_1.NET_DataReady   EQ
            RPY Line 1 - Fuel
            Pump 1 Assembly       Fuel Pump Assembly    16   050 - Target Weight Change                                                                                           EQ
            Sort Line - Oil Pan   Oil Pan Sort          32   100 - Tray Locked                      TOP Server     Sort_OilPan.MicroLogix1400          TrayLocked                 ALL
            Sort Line - Oil Pan   Oil Pan Sort          33   200 - Inspection Complete              TOP Server     Sort_OilPan.MicroLogix1400          InspectionComplete         ALL
            Sort Line - Totes     Totes Sort            38   100 - Tray Locked                      TOP Server     Sort_Totes.MicroLogix1400           TrayLocked                 ALL
            Sort Line - Totes     Totes Sort            39   200 - Inspection Complete              TOP Server     Sort_Totes.MicroLogix1400           InspectionComplete         ALL



           Each event has an associates set of actions/steps that are performed in response to the triggering of the event. These actions are listed in a
           subsequent table below. This table lists the actions/operations performed for each event ID and any associated Read/Write OPC tag. As each
           event is processed, the steps are activated/executed in ascending order of step number. Steps that do not include an OPC configuration are
           performing tags that do not require PLC/Process I/O



            event                                       Step
            id       name                               Number   Direction   OPC Server                Access Path                           ItemID
            2        Set Transaction In Process         0020        W        SWToolbox.TOPServer.V5    5A2_L1_CamHolderAssy.ProfaceLT_3300   TransInProc
            2        Process Part                       0200
            2        Set Part Valid                     1000        W        SWToolbox.TOPServer.V5    5A2_L1_CamHolderAssy.ProfaceLT_3300   PartValid
            2        Skip To Write Part Type            1010
            2        Set Alarm Type                     1020        W        SWToolbox.TOPServer.V5    5A2_L1_CamHolderAssy.ProfaceLT_3300   MESAlarmType
            2        Set Alarm Message                  1030        W        SWToolbox.TOPServer.V5    5A2_L1_CamHolderAssy.ProfaceLT_3300   MESAlarmText
            2        Write Part Type                    1050        W        SWToolbox.TOPServer.V5    5A2_L1_CamHolderAssy.ProfaceLT_3300   PartType
            2        Reset Transaction In Process       1100        W        SWToolbox.TOPServer.V5    5A2_L1_CamHolderAssy.ProfaceLT_3300   TransInProc
            2        Reset Data Ready                   2000        W        SWToolbox.TOPServer.V5    5A2_L1_CamHolderAssy.ProfaceLT_3300   DataReady
            5        Get Container Count                0200
            5        Set Container Count                1005        W        SWToolbox.TOPServer.V5                                          5G0_A2.5G0_A2.ContainerCount
            5        Reset Container Count Request      1010        W        SWToolbox.TOPServer.V5                                          5G0_A2.5G0_A2.ContainerCountRequest
            6        Reset Data Ready                   0010        W        SWToolbox.TOPServer.V5                                          5G0_A2.5G0_A2.DataReady
            6        Set Transaction In Process         0020        W        SWToolbox.TOPServer.V5                                          5G0_A2.5G0_A2.TransInProc
            6        Read Serial Number                 0100        R        SWToolbox.TOPServer.V5                                          5G0_A2.5G0_A2.PartSN
            6        Read Hardware Interlock Enforced   0130        R        SWToolbox.TOPServer.V5                                          5G0_A2.5G0_A2.HardwareInterlockEnforced
            6        Process Part                       0200
            6        Set Part Valid                     1000        W        SWToolbox.TOPServer.V5                                          5G0_A2.5G0_A2.PartValid
            6        Skip To Write Container Quantity   1010
            6        Set Alarm Type                     1020        W        SWToolbox.TOPServer.V5                                          5G0_A2.5G0_A2.MESAlarmType
            6        Set Alarm Message                  1030        W        SWToolbox.TOPServer.V5                                          5G0_A2.5G0_A2.MESAlarmText



            6        Write Container Quantity       1040   W   SWToolbox.TOPServer.V5                                         5G0_A2.5G0_A2.ContainerCount
            6        Write Part Type                1050   W   SWToolbox.TOPServer.V5                                         5G0_A2.5G0_A2.PartType
            6        Reset Transaction In Process   1100   W   SWToolbox.TOPServer.V5                                         5G0_A2.5G0_A2.TransInProc
            8        Set Transaction In Process     0020   W   SWToolbox.TOPServer.V5   5A2_L1_FuelPumpAssy.ProfaceLT_3300    TransInProc
            8        Process Part                   0200
            8        Set Part Valid                 1000   W   SWToolbox.TOPServer.V5   5A2_L1_FuelPumpAssy.ProfaceLT_3300    PartValid
            8        Skip To Write Part Type        1010
            8        Set Alarm Type                 1020   W   SWToolbox.TOPServer.V5   5A2_L1_FuelPumpAssy.ProfaceLT_3300    MESAlarmType
            8        Set Alarm Message              1030   W   SWToolbox.TOPServer.V5   5A2_L1_FuelPumpAssy.ProfaceLT_3300    MESAlarmText
            8        Write Part Type                1050   W   SWToolbox.TOPServer.V5   5A2_L1_FuelPumpAssy.ProfaceLT_3300    PartType
            8        Reset Transaction In Process   1100   W   SWToolbox.TOPServer.V5   5A2_L1_FuelPumpAssy.ProfaceLT_3300    TransInProc
            8        Reset Data Ready               2000   W   SWToolbox.TOPServer.V5   5A2_L1_FuelPumpAssy.ProfaceLT_3300    DataReady
            9        Set Transaction In Process     0020   W   SWToolbox.TOPServer.V5   5A2_L2_CamHolderAssy.ProfaceLT_3300   TransInProc
            9        Process Part                   0200
            9        Set Part Valid                 1000   W   SWToolbox.TOPServer.V5   5A2_L2_CamHolderAssy.ProfaceLT_3300   PartValid
            9        Skip To Write Part Type        1010
            9        Set Alarm Type                 1020   W   SWToolbox.TOPServer.V5   5A2_L2_CamHolderAssy.ProfaceLT_3300   MESAlarmType
            9        Set Alarm Message              1030   W   SWToolbox.TOPServer.V5   5A2_L2_CamHolderAssy.ProfaceLT_3300   MESAlarmText
            9        Write Part Type                1050   W   SWToolbox.TOPServer.V5   5A2_L2_CamHolderAssy.ProfaceLT_3300   PartType
            9        Reset Transaction In Process   1100   W   SWToolbox.TOPServer.V5   5A2_L2_CamHolderAssy.ProfaceLT_3300   TransInProc
            9        Reset Data Ready               2000   W   SWToolbox.TOPServer.V5   5A2_L2_CamHolderAssy.ProfaceLT_3300   DataReady
            10       Set Transaction In Process     0020   W   SWToolbox.TOPServer.V5   5A2_L2_FuelPumpAssy.ProfaceLT_3300    TransInProc
            10       Process Part                   0200
            10       Set Part Valid                 1000   W   SWToolbox.TOPServer.V5   5A2_L2_FuelPumpAssy.ProfaceLT_3300    PartValid
            10       Skip To Write Part Type        1010
            10       Set Alarm Type                 1020   W   SWToolbox.TOPServer.V5   5A2_L2_FuelPumpAssy.ProfaceLT_3300    MESAlarmType
            10       Set Alarm Message              1030   W   SWToolbox.TOPServer.V5   5A2_L2_FuelPumpAssy.ProfaceLT_3300    MESAlarmText
            10       Write Part Type                1050   W   SWToolbox.TOPServer.V5   5A2_L2_FuelPumpAssy.ProfaceLT_3300    PartType
            10       Reset Transaction In Process   1100   W   SWToolbox.TOPServer.V5   5A2_L2_FuelPumpAssy.ProfaceLT_3300    TransInProc
            10       Reset Data Ready               2000   W   SWToolbox.TOPServer.V5   5A2_L2_FuelPumpAssy.ProfaceLT_3300    DataReady



            15       Initialize Local Variables     0010
            15       Get Net Weight Value           0100   R   SWToolbox.OmniServer                                      RPY_1_FP_1.NET_NetWeightValue
            15       Get Net Weight UOM             0110   R   SWToolbox.OmniServer                                      RPY_1_FP_1.NET_NetWeightUOM
            15       Get Target Weight Met Flag     0120   R   SWToolbox.OmniServer                                      RPY_1_FP_1.NET_TargetWeightMetFlag
            15       Clear Net Weight Data Ready    0130   W   SWToolbox.OmniServer                                      RPY_1_FP_1.NET_DataReady
            15       [BEGIN] Net Weight Msg         0200
            15       Send Weight to MES             0210
            15       [END] Net Weight Msg           0299
            15       [BEGIN] Process Tote           0300
            15       Process Tote                   0310
            15       [END] Process Tote             0399
            16       Message Handler Initialize     0001
            16       Initialize Local Variables     0010
            16       Write Target Weight Value      0100   W   SWToolbox.OmniServer                                      RPY_1_FP_1.TRG_TargetWeightValue
            16       Write Target Weight UOM        0110   W   SWToolbox.OmniServer                                      RPY_1_FP_1.TRG_TargetWeightUOM
            16       Write Tolerance Weight Value   0120   W   SWToolbox.OmniServer                                      RPY_1_FP_1.TRG_ToleranceWeightValue
                     Send Target Weight Change To
            16       Scale                          0190   W   SWToolbox.OmniServer                                      RPY_1_FP_1.TRG_SendMessage
            17       Initialize Local Variables     0010
            17       Get Net Weight Value           0100   R   SWToolbox.OmniServer                                      59B_1_FP_1.NET_NetWeightValue
            17       Get Net Weight UOM             0110   R   SWToolbox.OmniServer                                      59B_1_FP_1.NET_NetWeightUOM
            17       Get Target Weight Met Flag     0120   R   SWToolbox.OmniServer                                      59B_1_FP_1.NET_TargetWeightMetFlag
            17       Get Part Number                0125   R   SWToolbox.OmniServer                                      59B_1_FP_1.NET_PartNumber
            17       Clear Net Weight Data Ready    0130   W   SWToolbox.OmniServer                                      59B_1_FP_1.NET_DataReady
            17       Verify Part                    0171
            17       [BEGIN] Net Weight Msg         0200
            17       Send Weight to MES             0210
            17       [END] Net Weight Msg           0299
            17       [BEGIN] Process Tote           0300
            17       Process Tote                   0310
            17       [END] Process Tote             0399



            18       Message Handler Initialize     0001
            18       Initialize Local Variables     0010
            18       Write Target Weight Value      0100   W   SWToolbox.OmniServer                                          59B_1_FP_1.TRG_TargetWeightValue
            18       Write Target Weight UOM        0110   W   SWToolbox.OmniServer                                          59B_1_FP_1.TRG_TargetWeightUOM
            18       Write Tolerance Weight Value   0120   W   SWToolbox.OmniServer                                          59B_1_FP_1.TRG_ToleranceWeightValue
                     Send Target Weight Change To
            18       Scale                          0190   W   SWToolbox.OmniServer                                          59B_1_FP_1.TRG_SendMessage
            19       Initialize Local Variables     0010
            19       Send Message to MES            0020
            20       Message Handler Initialize     0001
            20       Set Part Type                  0100   W   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartNumber
            20       Set Container Name             0200   W   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                ContainerName
            20       Set Ok To Continue             0300   W   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                OkToContinue
            22       Bail on reset                  0005
            22       Initialize Local Variables     0010
            22       Read Part 01 Disposition       0101   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition01
            22       Read Part 02 Disposition       0102   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition02
            22       Read Part 03 Disposition       0103   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition03
            22       Read Part 04 Disposition       0104   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition04
            22       Read Part 05 Disposition       0105   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition05
            22       Read Part 06 Disposition       0106   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition06
            22       Read Part 07 Disposition       0107   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition07
            22       Read Part 08 Disposition       0108   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition08
            22       Read Part 09 Disposition       0109   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition09
            22       Read Part 10 Disposition       0110   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition10
            22       Read Part 11 Disposition       0111   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition11
            22       Read Part 12 Disposition       0112   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition12
            22       Read Part 13 Disposition       0113   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition13
            22       Read Part 14 Disposition       0114   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition14
            22       Read Part 15 Disposition       0115   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition15
            22       Read Part 16 Disposition       0116   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition16



            22       Read Part 17 Disposition       0117   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition17
            22       Read Part 18 Disposition       0118   R   SWToolbox.TOPServer.V5   6B2_CH.MicroLogix1400                PartDisposition18
            22       Send Message to MES            0200
            23       Initialize Local Variables     0010
            23       Get Net Weight Value           0100   R   SWToolbox.OmniServer                                          6B2_1_FP_1.NET_NetWeightValue
            23       Get Net Weight UOM             0110   R   SWToolbox.OmniServer                                          6B2_1_FP_1.NET_NetWeightUOM
            23       Get Target Weight Met Flag     0120   R   SWToolbox.OmniServer                                          6B2_1_FP_1.NET_TargetWeightMetFlag
            23       Clear Net Weight Data Ready    0130   W   SWToolbox.OmniServer                                          6B2_1_FP_1.NET_DataReady
            23       [BEGIN] Net Weight Msg         0200
            23       Send Weight to MES             0210
            23       [END] Net Weight Msg           0299
            23       [BEGIN] Process Tote           0300
            23       Process Tote                   0310
            23       [END] Process Tote             0399
            24       Message Handler Initialize     0001
            24       Initialize Local Variables     0010
            24       Write Target Weight Value      0100   W   SWToolbox.OmniServer                                          6B2_1_FP_1.TRG_TargetWeightValue
            24       Write Target Weight UOM        0110   W   SWToolbox.OmniServer                                          6B2_1_FP_1.TRG_TargetWeightUOM
            24       Write Tolerance Weight Value   0120   W   SWToolbox.OmniServer                                          6B2_1_FP_1.TRG_ToleranceWeightValue
                     Send Target Weight Change To
            24       Scale                          0190   W   SWToolbox.OmniServer                                          6B2_1_FP_1.TRG_SendMessage
            27       Message Handler Initialize     0001
            27       Initialize Local Variables     0010
            27       Write Target Weight Value      0100   W   SWToolbox.OmniServer                                          5PA_1_FP_1.TRG_TargetWeightValue
            27       Write Target Weight UOM        0110   W   SWToolbox.OmniServer                                          5PA_1_FP_1.TRG_TargetWeightUOM
            27       Write Tolerance Weight Value   0120   W   SWToolbox.OmniServer                                          5PA_1_FP_1.TRG_ToleranceWeightValue
                     Send Target Weight Change To
            27       Scale                          0190   W   SWToolbox.OmniServer                                          5PA_1_FP_1.TRG_SendMessage
            28       Initialize Local Variables     0010
            28       Get Net Weight Value           0100   R   SWToolbox.OmniServer                                          5PA_1_FP_1.NET_NetWeightValue
            28       Get Net Weight UOM             0110   R   SWToolbox.OmniServer                                          5PA_1_FP_1.NET_NetWeightUOM



            28       Get Target Weight Met Flag    0120   R   SWToolbox.OmniServer                                              5PA_1_FP_1.NET_TargetWeightMetFlag
            28       Clear Net Weight Data Ready   0130   W   SWToolbox.OmniServer                                              5PA_1_FP_1.NET_DataReady
            28       [BEGIN] Net Weight Msg        0200
            28       Send Weight to MES            0210
            28       [END] Net Weight Msg          0299
            28       [BEGIN] Process Tote          0300
            28       Process Tote                  0310
            28       [END] Process Tote            0399
            29       Bail on reset                 0005
            29       Initialize Local Variables    0010
            29       Get Vision Part Number        0100   R   SWToolbox.TOPServer.V5   6C2_6MA_OilPanAssy.MicroLogix1400        VisionPartNumber
            29       Process Tote                  0310
            30       Bail on reset                 0005
            30       Initialize Local Variables    0010
            30       Get Part Type                 0100
            30       Set Part Type                 0200   W   SWToolbox.TOPServer.V5   6C2_6MA_OilPanAssy.MicroLogix1400        PartNumber
            32       Bail on reset                 0005
            32       Initialize Local Variables    0010
            32       Get Sort Recipe               0100
            32       Set Sort Recipe               0200   W   SWToolbox.TOPServer.V5   Sort_OilPan.MicroLogix1400               PartNumber
            33       Bail on reset                 0005
            33       Initialize Local Variables    0010
            33       Process Tote                  0310
            38       Bail on reset                 0005
            38       Initialize Local Variables    0010
            38       Get Sort Recipe               0100
            38       Set Sort Recipe               0200   W   SWToolbox.TOPServer.V5   Sort_Totes.MicroLogix1400                PartNumber
            39       Bail on reset                 0005
            39       Initialize Local Variables    0010
            39       Process Tote                  0310



            40       Initialize Local Variables     0010
            40       Get Net Weight Value           0100   R   SWToolbox.OmniServer                                         RPY_1_CB_1.NET_NetWeightValue
            40       Get Net Weight UOM             0110   R   SWToolbox.OmniServer                                         RPY_1_CB_1.NET_NetWeightUOM
            40       Get Target Weight Met Flag     0120   R   SWToolbox.OmniServer                                         RPY_1_CB_1.NET_TargetWeightMetFlag
            40       Clear Net Weight Data Ready    0130   W   SWToolbox.OmniServer                                         RPY_1_CB_1.NET_DataReady
            40       [BEGIN] Net Weight Msg         0200
            40       Send Weight to MES             0210
            40       [END] Net Weight Msg           0299
            40       [BEGIN] Process Tote           0300
            40       Process Tote                   0310
            40       [END] Process Tote             0399
            41       Message Handler Initialize     0001
            41       Initialize Local Variables     0010
            41       Write Target Weight Value      0100   W   SWToolbox.OmniServer                                         RPY_1_CB_1.TRG_TargetWeightValue
            41       Write Target Weight UOM        0110   W   SWToolbox.OmniServer                                         RPY_1_CB_1.TRG_TargetWeightUOM
            41       Write Tolerance Weight Value   0120   W   SWToolbox.OmniServer                                         RPY_1_CB_1.TRG_ToleranceWeightValue
                     Send Target Weight Change To
            41       Scale                          0190   W   SWToolbox.OmniServer                                         RPY_1_CB_1.TRG_SendMessage
            42       Bail on reset                  0005
            42       Initialize Local Variables     0010
            42       Get Part Type                  0100
            42       Set Part Type                  0200   W   SWToolbox.TOPServer.V5   5K8_64A_OilPanAssy.MicroLogix1400   PartNumber
            43       Bail on reset                  0005
            43       Initialize Local Variables     0010
            43       Get Vision Part Number         0100   R   SWToolbox.TOPServer.V5   5K8_64A_OilPanAssy.MicroLogix1400   VisionPartNumber
            43       Process Tote                   0310
            44       Initialize Local Variables     0010
            44       Send Message to MES            0020
            45       Bail on reset                  0005
            45       Initialize Local Variables     0010
            45       Send Message to MES            0200



            64       Get Container Count                0200
            64       Set Container Count                1005   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.ContainerCount
            64       Reset Container Count Request      1010   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.ContainerCountRequest
            65       Reset Data Ready                   0010   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.DataReady
            65       Read Container Count               0015   R   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.ContainerCount
            65       Set Transaction In Process         0020   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.TransInProc
            65       Check Container Count              0030
            65       Set Part Complete                  0040   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.PartComplete
            66       Initialize Local Variables         0010
            66       Read Container Count               0015   R   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.ContainerCount
            66       Validate Part Count                0016
            66       Get Net Weight Value               0100   R   SWToolbox.OmniServer                                      5G0_Front_Scale.NET_NetWeightValue
            66       Get Net Weight UOM                 0110   R   SWToolbox.OmniServer                                      5G0_Front_Scale.NET_NetWeightUOM
            66       Get Target Weight Met Flag         0120   R   SWToolbox.OmniServer                                      5G0_Front_Scale.NET_TargetWeightMetFlag
            66       Clear Net Weight Data Ready        0130   W   SWToolbox.OmniServer                                      5G0_Front_Scale.NET_DataReady
            66       [BEGIN] Complete Container         0300
            66       Complete Container                 0320
            66       Set Part Valid                     0325   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.PartValid
            66       Write Container Quantity           0330   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.ContainerCount
            66       Write Part Type                    0335   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.PartType
            66       [END] Complete Container           0399
            66       [BEGIN] Process Next Part          0500
            66       Read TransInProc                   0510   R   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.TransInProc
            66       Read Part Complete                 0520   R   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.PartComplete
            66       Check Next Part Pending            0540
            66       Set Part Complete                  0550   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.PartComplete
            66       [END] Process Next Part            0599
            67       Read Serial Number                 0100   R   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.PartSN
            67       Read Hardware Interlock Enforced   0130   R   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.HardwareInterlockEnforced
            67       Process Part                       0200



            67       Set Part Valid                     1000   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.PartValid
            67       Skip To Write Container Quantity   1010
            67       Set Alarm Type                     1020   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.MESAlarmType
            67       Set Alarm Message                  1030   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.MESAlarmText
            67       Write Container Quantity           1040   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.ContainerCount
            67       Write Part Type                    1050   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.PartType
            67       Reset Transaction In Process       1100   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.TransInProc
            67       Reset Part Complete                1200   W   SWToolbox.TOPServer.V5                                    5G0_A1.5G0_A1.PartComplete
            72       Get Container Count                0200
            72       Set Container Count                1005   W   SWToolbox.TOPServer.V5                                    5G0_A2.5G0_A2.ContainerCount
            72       Reset Container Count Request      1010   W   SWToolbox.TOPServer.V5                                    5G0_A2.5G0_A2.ContainerCountRequest
            73       Reset Data Ready                   0010   W   SWToolbox.TOPServer.V5                                    5G0_A2.5G0_A2.DataReady
            73       Read Container Count               0015   R   SWToolbox.TOPServer.V5                                    5G0_A2.5G0_A2.ContainerCount
            73       Set Transaction In Process         0020   W   SWToolbox.TOPServer.V5                                    5G0_A2.5G0_A2.TransInProc
            73       Check Container Count              0030
            73       Set Part Complete                  0040   W   SWToolbox.TOPServer.V5                                    5G0_A2.5G0_A2.PartComplete
            75       Initialize Local Variables         0010
            75       Get Net Weight Value               0100   R   SWToolbox.OmniServer                                      5G0_Rear_Scale.NET_NetWeightValue
            75       Get Net Weight UOM                 0110   R   SWToolbox.OmniServer                                      5G0_Rear_Scale.NET_NetWeightUOM
            75       Get Target Weight Met Flag         0120   R   SWToolbox.OmniServer                                      5G0_Rear_Scale.NET_TargetWeightMetFlag
            75       Clear Net Weight Data Ready        0130   W   SWToolbox.OmniServer                                      5G0_Rear_Scale.NET_DataReady
            75       [BEGIN] Complete Container         0300
            75       Complete Container                 0320
            75       Set Part Valid                     0325   W   SWToolbox.TOPServer.V5                                    5G0_A2.5G0_A2.PartValid
            75       Reset Container Quantity           0330   W   SWToolbox.TOPServer.V5                                    5G0_A2.5G0_A2.ContainerCount
            75       Write Part Type                    0335   W   SWToolbox.TOPServer.V5                                    5G0_A2.5G0_A2.PartType
            75       [END] Complete Container           0399
            75       [BEGIN] Process Next Part          0500
            75       Read TransInProc                   0510   R   SWToolbox.TOPServer.V5                                    5G0_A2.5G0_A2.TransInProc
            75       Read Part Complete                 0520   R   SWToolbox.TOPServer.V5                                    5G0_A2.5G0_A2.PartComplete



            75       Check Next Part Pending            0540
            75       Set Part Complete                  0550   W   SWToolbox.TOPServer.V5                                        5G0_A2.5G0_A2.PartComplete
            75       [END] Process Next Part            0599
            76       Read Serial Number                 0100   R   SWToolbox.TOPServer.V5                                        5G0_A2.5G0_A2.PartSN
            76       Read Hardware Interlock Enforced   0130   R   SWToolbox.TOPServer.V5                                        5G0_A2.5G0_A2.HardwareInterlockEnforced
            76       Process Part                       0200
            76       Set Part Valid                     1000   W   SWToolbox.TOPServer.V5                                        5G0_A2.5G0_A2.PartValid
            76       Skip To Write Container Quantity   1010
            76       Set Alarm Type                     1020   W   SWToolbox.TOPServer.V5                                        5G0_A2.5G0_A2.MESAlarmType
            76       Set Alarm Message                  1030   W   SWToolbox.TOPServer.V5                                        5G0_A2.5G0_A2.MESAlarmText
            76       Write Container Quantity           1040   W   SWToolbox.TOPServer.V5                                        5G0_A2.5G0_A2.ContainerCount
            76       Write Part Type                    1050   W   SWToolbox.TOPServer.V5                                        5G0_A2.5G0_A2.PartType
            76       Reset Transaction In Process       1100   W   SWToolbox.TOPServer.V5                                        5G0_A2.5G0_A2.TransInProc
            76       Reset Part Complete                1200   W   SWToolbox.TOPServer.V5                                        5G0_A2.5G0_A2.PartComplete
            79       Bail on reset                      0005
            79       Initialize Local Variables         0010
            79       Get Vision Part Number             0100   R   SWToolbox.TOPServer.V5   RPY_CH.MicroLogix1400                PartNumber
            79       Process Tray                       0310
            79       Send Message to MES                0320
            80       Initialize Local Variables         0010
            80       Get Part Type                      0050
            80       Set Part Type                      0100   W   SWToolbox.TOPServer.V5   RPY_CH.MicroLogix1400                PartNumber
            80       Process Tray Locked                0200
            80       Send Message to MES                0210
            80       Set Ok To Continue                 0300   W   SWToolbox.TOPServer.V5   RPY_CH.MicroLogix1400                OkToContinue
            82       Bail on reset                      0005
            82       Initialize Local Variables         0010
            82       Get Part Type                      0100
            82       Set Part Type                      0200   W   SWToolbox.TOPServer.V5   5J6_OilPanAssy.MicroLogix1400        PartNumber
            83       Bail on reset                      0005



            83       Initialize Local Variables   0010
            83       Get Vision Part Number       0100   R   SWToolbox.TOPServer.V5   5J6_OilPanAssy.MicroLogix1400        VisionPartNumber
            83       Process Tote                 0310
            84       Initialize Local Variables   0010
            84       Send Message to MES          0020
            85       Message Handler Initialize   0001
            85       Set Part Type                0100   W   SWToolbox.TOPServer.V5   6MA_CH.MicroLogix1400                PartNumber
            85       Set Container Name           0200   W   SWToolbox.TOPServer.V5   6MA_CH.MicroLogix1400                ContainerName
            85       Set Ok To Continue           0300   W   SWToolbox.TOPServer.V5   6MA_CH.MicroLogix1400                OkToContinue
            86       Bail on reset                0005
            86       Initialize Local Variables   0010
            86       Send Message to MES          0200
            87       Bail on Reset                0005
            87       Initialize Local Variables   0010
            87       Send Message to MES          0300
            87       Set Ok to Continue           0400   W   SWToolbox.TOPServer.V5   6FB_CH.Micrologix1400                OkToContinue
            89       Bail on reset                0005
            89       Initialize Local Variables   0010
            89       Get Vision Part Number       0100   R   SWToolbox.TOPServer.V5   6FB_CH.MicroLogix1400                PartNumber
            89       Process Tray Complete        0325
            89       Send Message to MES          0420



                                                                   Step                                                                                                                       script
   event ID   Event             action                             Number   Name   OPC Server Name            Access Path                           OPC Item ID                                 id
              200 - Data
      2       Ready             TRIGGER                            0         EQ    TOP Server                 5A2_L1_CamHolderAssy.ProfaceLT_3300   DataReady                                   0
      2                         Set Transaction In Process         20        W     SWToolbox.TOPServer.V5     5A2_L1_CamHolderAssy.ProfaceLT_3300   TransInProc                                 0
      2                         Process Part                       200                                                                                                                          2
      2                         Set Part Valid                     1000      W     SWToolbox.TOPServer.V5     5A2_L1_CamHolderAssy.ProfaceLT_3300   PartValid                                   0
      2                         Skip To Write Part Type            1010                                                                                                                         3
      2                         Set Alarm Type                     1020      W     SWToolbox.TOPServer.V5     5A2_L1_CamHolderAssy.ProfaceLT_3300   MESAlarmType                                0
      2                         Set Alarm Message                  1030      W     SWToolbox.TOPServer.V5     5A2_L1_CamHolderAssy.ProfaceLT_3300   MESAlarmText                                0
      2                         Write Part Type                    1050      W     SWToolbox.TOPServer.V5     5A2_L1_CamHolderAssy.ProfaceLT_3300   PartType                                    0
      2                         Reset Transaction In Process       1100      W     SWToolbox.TOPServer.V5     5A2_L1_CamHolderAssy.ProfaceLT_3300   TransInProc                                 0
      2                         Reset Data Ready                   2000      W     SWToolbox.TOPServer.V5     5A2_L1_CamHolderAssy.ProfaceLT_3300   DataReady                                   0
              003 - Container
      5       Count Request     TRIGGER                            0         EQ    TOP Server                                                       5G0_A2.5G0_A2.ContainerCountRequest         0
      5                         Get Container Count                200                                                                                                                          9
      5                         Set Container Count                1005      W     SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.ContainerCount                0
      5                         Reset Container Count Request      1010      W     SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.ContainerCountRequest         0
              200 - Data
      6       Ready             TRIGGER                            0         EQ    TOP Server                                                       5G0_A2.5G0_A2.DataReady                     0
      6                         Reset Data Ready                   10        W     SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.DataReady                     0
      6                         Set Transaction In Process         20        W     SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.TransInProc                   0
      6                         Read Serial Number                 100       R     SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.PartSN                        0
      6                         Read Hardware Interlock Enforced   130       R     SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.HardwareInterlockEnforced     0
      6                         Process Part                       200                                                                                                                         10
      6                         Set Part Valid                     1000      W     SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.PartValid                     0
      6                         Skip To Write Container Quantity   1010                                                                                                                        11
      6                         Set Alarm Type                     1020      W     SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.MESAlarmType                  0
      6                         Set Alarm Message                  1030      W     SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.MESAlarmText                  0



      6                         Write Container Quantity       1040   W    SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.ContainerCount   0
      6                         Write Part Type                1050   W    SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.PartType         0
      6                         Reset Transaction In Process   1100   W    SWToolbox.TOPServer.V5                                           5G0_A2.5G0_A2.TransInProc      0
              200 - Data
      8       Ready             TRIGGER                        0      EQ   TOP Server                 5A2_L1_FuelPumpAssy.ProfaceLT_3300    DataReady                      0
      8                         Set Transaction In Process     20     W    SWToolbox.TOPServer.V5     5A2_L1_FuelPumpAssy.ProfaceLT_3300    TransInProc                    0
      8                         Process Part                   200                                                                                                         13
      8                         Set Part Valid                 1000   W    SWToolbox.TOPServer.V5     5A2_L1_FuelPumpAssy.ProfaceLT_3300    PartValid                      0
      8                         Skip To Write Part Type        1010                                                                                                        14
      8                         Set Alarm Type                 1020   W    SWToolbox.TOPServer.V5     5A2_L1_FuelPumpAssy.ProfaceLT_3300    MESAlarmType                   0
      8                         Set Alarm Message              1030   W    SWToolbox.TOPServer.V5     5A2_L1_FuelPumpAssy.ProfaceLT_3300    MESAlarmText                   0
      8                         Write Part Type                1050   W    SWToolbox.TOPServer.V5     5A2_L1_FuelPumpAssy.ProfaceLT_3300    PartType                       0
      8                         Reset Transaction In Process   1100   W    SWToolbox.TOPServer.V5     5A2_L1_FuelPumpAssy.ProfaceLT_3300    TransInProc                    0
      8                         Reset Data Ready               2000   W    SWToolbox.TOPServer.V5     5A2_L1_FuelPumpAssy.ProfaceLT_3300    DataReady                      0
              200 - Data
      9       Ready             TRIGGER                        0      EQ   TOP Server                 5A2_L2_CamHolderAssy.ProfaceLT_3300   DataReady                      0
      9                         Set Transaction In Process     20     W    SWToolbox.TOPServer.V5     5A2_L2_CamHolderAssy.ProfaceLT_3300   TransInProc                    0
      9                         Process Part                   200                                                                                                         15
      9                         Set Part Valid                 1000   W    SWToolbox.TOPServer.V5     5A2_L2_CamHolderAssy.ProfaceLT_3300   PartValid                      0
      9                         Skip To Write Part Type        1010                                                                                                        16
      9                         Set Alarm Type                 1020   W    SWToolbox.TOPServer.V5     5A2_L2_CamHolderAssy.ProfaceLT_3300   MESAlarmType                   0
      9                         Set Alarm Message              1030   W    SWToolbox.TOPServer.V5     5A2_L2_CamHolderAssy.ProfaceLT_3300   MESAlarmText                   0
      9                         Write Part Type                1050   W    SWToolbox.TOPServer.V5     5A2_L2_CamHolderAssy.ProfaceLT_3300   PartType                       0
      9                         Reset Transaction In Process   1100   W    SWToolbox.TOPServer.V5     5A2_L2_CamHolderAssy.ProfaceLT_3300   TransInProc                    0
      9                         Reset Data Ready               2000   W    SWToolbox.TOPServer.V5     5A2_L2_CamHolderAssy.ProfaceLT_3300   DataReady                      0
              200 - Data
     10       Ready             TRIGGER                        0      EQ   TOP Server                 5A2_L2_FuelPumpAssy.ProfaceLT_3300    DataReady                      0
     10                         Set Transaction In Process     20     W    SWToolbox.TOPServer.V5     5A2_L2_FuelPumpAssy.ProfaceLT_3300    TransInProc                    0
     10                         Process Part                   200                                                                                                         17
     10                         Set Part Valid                 1000   W    SWToolbox.TOPServer.V5     5A2_L2_FuelPumpAssy.ProfaceLT_3300    PartValid                      0
     10                         Skip To Write Part Type        1010                                                                                                        18
     10                         Set Alarm Type                 1020   W    SWToolbox.TOPServer.V5     5A2_L2_FuelPumpAssy.ProfaceLT_3300    MESAlarmType                   0



     10                         Set Alarm Message              1030   W    SWToolbox.TOPServer.V5     5A2_L2_FuelPumpAssy.ProfaceLT_3300   MESAlarmText                          0
     10                         Write Part Type                1050   W    SWToolbox.TOPServer.V5     5A2_L2_FuelPumpAssy.ProfaceLT_3300   PartType                              0
     10                         Reset Transaction In Process   1100   W    SWToolbox.TOPServer.V5     5A2_L2_FuelPumpAssy.ProfaceLT_3300   TransInProc                           0
     10                         Reset Data Ready               2000   W    SWToolbox.TOPServer.V5     5A2_L2_FuelPumpAssy.ProfaceLT_3300   DataReady                             0
              100 - Net
     15       Weight Update     TRIGGER                        0      EQ   OmniServer                                                      RPY_1_FP_1.NET_DataReady              0
     15                         Initialize Local Variables     10                                                                                                                19
     15                         Get Net Weight Value           100    R    SWToolbox.OmniServer                                            RPY_1_FP_1.NET_NetWeightValue         0
     15                         Get Net Weight UOM             110    R    SWToolbox.OmniServer                                            RPY_1_FP_1.NET_NetWeightUOM           0
     15                         Get Target Weight Met Flag     120    R    SWToolbox.OmniServer                                            RPY_1_FP_1.NET_TargetWeightMetFlag    0
     15                         Clear Net Weight Data Ready    130    W    SWToolbox.OmniServer                                            RPY_1_FP_1.NET_DataReady              0
     15                         [BEGIN] Net Weight Msg         200                                                                                                               20
     15                         Send Weight to MES             210                                                                                                               21
     15                         [END] Net Weight Msg           299                                                                                                               22
     15                         [BEGIN] Process Tote           300                                                                                                               23
     15                         Process Tote                   310                                                                                                               24
     15                         [END] Process Tote             399                                                                                                               25
              050 - Target
     16       Weight Change     TRIGGER                        0      EQ   NULL                       NULL                                 NULL                                  0
     16                         Message Handler Initialize     1                                                                                                                 26
     16                         Initialize Local Variables     10                                                                                                                27
     16                         Write Target Weight Value      100    W    SWToolbox.OmniServer                                            RPY_1_FP_1.TRG_TargetWeightValue      0
     16                         Write Target Weight UOM        110    W    SWToolbox.OmniServer                                            RPY_1_FP_1.TRG_TargetWeightUOM        0
     16                         Write Tolerance Weight Value   120    W    SWToolbox.OmniServer                                            RPY_1_FP_1.TRG_ToleranceWeightValue   0
                                Send Target Weight Change To
     16                         Scale                          190    W    SWToolbox.OmniServer                                            RPY_1_FP_1.TRG_SendMessage            0
              100 - Net
     17       Weight Update     TRIGGER                        0      EQ   OmniServer                                                      59B_1_FP_1.NET_DataReady              0
     17                         Initialize Local Variables     10                                                                                                                28
     17                         Get Net Weight Value           100    R    SWToolbox.OmniServer                                            59B_1_FP_1.NET_NetWeightValue         0
     17                         Get Net Weight UOM             110    R    SWToolbox.OmniServer                                            59B_1_FP_1.NET_NetWeightUOM           0
     17                         Get Target Weight Met Flag     120    R    SWToolbox.OmniServer                                            59B_1_FP_1.NET_TargetWeightMetFlag    0



     17                          Get Part Number                125   R     SWToolbox.OmniServer                               59B_1_FP_1.NET_PartNumber             0
     17                          Clear Net Weight Data Ready    130   W     SWToolbox.OmniServer                               59B_1_FP_1.NET_DataReady              0
     17                          Verify Part                    171                                                                                                  82
     17                          [BEGIN] Net Weight Msg         200                                                                                                  29
     17                          Send Weight to MES             210                                                                                                  30
     17                          [END] Net Weight Msg           299                                                                                                  31
     17                          [BEGIN] Process Tote           300                                                                                                  32
     17                          Process Tote                   310                                                                                                  33
     17                          [END] Process Tote             399                                                                                                  34
              050 - Target
     18       Weight Change      TRIGGER                        0     EQ    NULL                       NULL                    NULL                                  0
     18                          Message Handler Initialize     1                                                                                                    35
     18                          Initialize Local Variables     10                                                                                                   36
     18                          Write Target Weight Value      100   W     SWToolbox.OmniServer                               59B_1_FP_1.TRG_TargetWeightValue      0
     18                          Write Target Weight UOM        110   W     SWToolbox.OmniServer                               59B_1_FP_1.TRG_TargetWeightUOM        0
     18                          Write Tolerance Weight Value   120   W     SWToolbox.OmniServer                               59B_1_FP_1.TRG_ToleranceWeightValue   0
                                 Send Target Weight Change To
     18                          Scale                          190   W     SWToolbox.OmniServer                               59B_1_FP_1.TRG_SendMessage            0
              100 - Tray
     19       Locked             TRIGGER                        0     ALL   TOP Server                 6B2_CH.MicroLogix1400   TrayLocked                            0
     19                          Initialize Local Variables     10                                                                                                   37
     19                          Send Message to MES            20                                                                                                   38
              150 - Set In-
              Process
     20       Container          TRIGGER                        0     ALL   NULL                       NULL                    NULL                                  0
     20                          Message Handler Initialize     1                                                                                                    39
     20                          Set Part Type                  100   W     SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartNumber                            0
     20                          Set Container Name             200   W     SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   ContainerName                         0
     20                          Set Ok To Continue             300   W     SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   OkToContinue                          0
              200 - Inspection
     22       Complete           TRIGGER                        0     ALL   TOP Server                 6B2_CH.MicroLogix1400   InspectionComplete                    0
     22                          Bail on reset                  5                                                                                                    55
     22                          Initialize Local Variables     10                                                                                                   43



     22                         Read Part 01 Disposition      101   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition01                    0
     22                         Read Part 02 Disposition      102   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition02                    0
     22                         Read Part 03 Disposition      103   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition03                    0
     22                         Read Part 04 Disposition      104   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition04                    0
     22                         Read Part 05 Disposition      105   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition05                    0
     22                         Read Part 06 Disposition      106   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition06                    0
     22                         Read Part 07 Disposition      107   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition07                    0
     22                         Read Part 08 Disposition      108   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition08                    0
     22                         Read Part 09 Disposition      109   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition09                    0
     22                         Read Part 10 Disposition      110   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition10                    0
     22                         Read Part 11 Disposition      111   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition11                    0
     22                         Read Part 12 Disposition      112   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition12                    0
     22                         Read Part 13 Disposition      113   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition13                    0
     22                         Read Part 14 Disposition      114   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition14                    0
     22                         Read Part 15 Disposition      115   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition15                    0
     22                         Read Part 16 Disposition      116   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition16                    0
     22                         Read Part 17 Disposition      117   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition17                    0
     22                         Read Part 18 Disposition      118   R    SWToolbox.TOPServer.V5     6B2_CH.MicroLogix1400   PartDisposition18                    0
     22                         Send Message to MES           200                                                                                                45
              100 - Net
     23       Weight Update     TRIGGER                       0     EQ   OmniServer                                         6B2_1_FP_1.NET_DataReady             0
     23                         Initialize Local Variables    10                                                                                                 46
     23                         Get Net Weight Value          100   R    SWToolbox.OmniServer                               6B2_1_FP_1.NET_NetWeightValue        0
     23                         Get Net Weight UOM            110   R    SWToolbox.OmniServer                               6B2_1_FP_1.NET_NetWeightUOM          0
     23                         Get Target Weight Met Flag    120   R    SWToolbox.OmniServer                               6B2_1_FP_1.NET_TargetWeightMetFlag   0
     23                         Clear Net Weight Data Ready   130   W    SWToolbox.OmniServer                               6B2_1_FP_1.NET_DataReady             0
     23                         [BEGIN] Net Weight Msg        200                                                                                                47
     23                         Send Weight to MES            210                                                                                                48
     23                         [END] Net Weight Msg          299                                                                                                49
     23                         [BEGIN] Process Tote          300                                                                                                50
     23                         Process Tote                  310                                                                                                51



     23                          [END] Process Tote             399                                                                                                              52
              050 - Target
     24       Weight Change      TRIGGER                        0     EQ    NULL                       NULL                                NULL                                  0
     24                          Message Handler Initialize     1                                                                                                                53
     24                          Initialize Local Variables     10                                                                                                               54
     24                          Write Target Weight Value      100   W     SWToolbox.OmniServer                                           6B2_1_FP_1.TRG_TargetWeightValue      0
     24                          Write Target Weight UOM        110   W     SWToolbox.OmniServer                                           6B2_1_FP_1.TRG_TargetWeightUOM        0
     24                          Write Tolerance Weight Value   120   W     SWToolbox.OmniServer                                           6B2_1_FP_1.TRG_ToleranceWeightValue   0
                                 Send Target Weight Change To
     24                          Scale                          190   W     SWToolbox.OmniServer                                           6B2_1_FP_1.TRG_SendMessage            0
              050 - Target
     27       Weight Change      TRIGGER                        0     EQ    NULL                       NULL                                NULL                                  0
     27                          Message Handler Initialize     1                                                                                                                65
     27                          Initialize Local Variables     10                                                                                                               66
     27                          Write Target Weight Value      100   W     SWToolbox.OmniServer                                           5PA_1_FP_1.TRG_TargetWeightValue      0
     27                          Write Target Weight UOM        110   W     SWToolbox.OmniServer                                           5PA_1_FP_1.TRG_TargetWeightUOM        0
     27                          Write Tolerance Weight Value   120   W     SWToolbox.OmniServer                                           5PA_1_FP_1.TRG_ToleranceWeightValue   0
                                 Send Target Weight Change To
     27                          Scale                          190   W     SWToolbox.OmniServer                                           5PA_1_FP_1.TRG_SendMessage            0
              100 - Net
     28       Weight Update      TRIGGER                        0     EQ    OmniServer                                                     5PA_1_FP_1.NET_DataReady              0
     28                          Initialize Local Variables     10                                                                                                               67
     28                          Get Net Weight Value           100   R     SWToolbox.OmniServer                                           5PA_1_FP_1.NET_NetWeightValue         0
     28                          Get Net Weight UOM             110   R     SWToolbox.OmniServer                                           5PA_1_FP_1.NET_NetWeightUOM           0
     28                          Get Target Weight Met Flag     120   R     SWToolbox.OmniServer                                           5PA_1_FP_1.NET_TargetWeightMetFlag    0
     28                          Clear Net Weight Data Ready    130   W     SWToolbox.OmniServer                                           5PA_1_FP_1.NET_DataReady              0
     28                          [BEGIN] Net Weight Msg         200                                                                                                              68
     28                          Send Weight to MES             210                                                                                                              69
     28                          [END] Net Weight Msg           299                                                                                                              70
     28                          [BEGIN] Process Tote           300                                                                                                              71
     28                          Process Tote                   310                                                                                                              72
     28                          [END] Process Tote             399                                                                                                              73
              200 - Inspection
     29       Complete           TRIGGER                        0     ALL   TOP Server                 6C2_6MA_OilPanAssy.MicroLogix1400   InspectionComplete                    0



     29                          Bail on reset                5                                                                                                     80
     29                          Initialize Local Variables   10                                                                                                    74
     29                          Get Vision Part Number       100   R     SWToolbox.TOPServer.V5     6C2_6MA_OilPanAssy.MicroLogix1400   VisionPartNumber            0
     29                          Process Tote                 310                                                                                                   77
              100 - Tray
     30       Locked             TRIGGER                      0     ALL   TOP Server                 6C2_6MA_OilPanAssy.MicroLogix1400   TrayLocked                  0
     30                          Bail on reset                5                                                                                                     79
     30                          Initialize Local Variables   10                                                                                                    76
     30                          Get Part Type                100                                                                                                   75
     30                          Set Part Type                200   W     SWToolbox.TOPServer.V5     6C2_6MA_OilPanAssy.MicroLogix1400   PartNumber                  0
              100 - Tray
     32       Locked             TRIGGER                      0     ALL   TOP Server                 Sort_OilPan.MicroLogix1400          TrayLocked                  0
     32                          Bail on reset                5                                                                                                     86
     32                          Initialize Local Variables   10                                                                                                    87
     32                          Get Sort Recipe              100                                                                                                   88
     32                          Set Sort Recipe              200   W     SWToolbox.TOPServer.V5     Sort_OilPan.MicroLogix1400          PartNumber                  0
              200 - Inspection
     33       Complete           TRIGGER                      0     ALL   TOP Server                 Sort_OilPan.MicroLogix1400          InspectionComplete          0
     33                          Bail on reset                5                                                                                                     89
     33                          Initialize Local Variables   10                                                                                                    90
     33                          Process Tote                 310                                                                                                   91
              100 - Tray
     38       Locked             TRIGGER                      0     ALL   TOP Server                 Sort_Totes.MicroLogix1400           TrayLocked                  0
     38                          Bail on reset                5                                                                                                     108
     38                          Initialize Local Variables   10                                                                                                    109
     38                          Get Sort Recipe              100                                                                                                   110
     38                          Set Sort Recipe              200   W     SWToolbox.TOPServer.V5     Sort_Totes.MicroLogix1400           PartNumber                  0
              200 - Inspection
     39       Complete           TRIGGER                      0     ALL   TOP Server                 Sort_Totes.MicroLogix1400           InspectionComplete          0
     39                          Bail on reset                5                                                                                                     111
     39                          Initialize Local Variables   10                                                                                                    112
     39                          Process Tote                 310                                                                                                   113
              100 - Net
     40       Weight Update      TRIGGER                      0     EQ    OmniServer                                                     RPY_1_CB_1.NET_DataReady    0



     40                          Initialize Local Variables     10                                                                                                               114
     40                          Get Net Weight Value           100   R     SWToolbox.OmniServer                                           RPY_1_CB_1.NET_NetWeightValue          0
     40                          Get Net Weight UOM             110   R     SWToolbox.OmniServer                                           RPY_1_CB_1.NET_NetWeightUOM            0
     40                          Get Target Weight Met Flag     120   R     SWToolbox.OmniServer                                           RPY_1_CB_1.NET_TargetWeightMetFlag     0
     40                          Clear Net Weight Data Ready    130   W     SWToolbox.OmniServer                                           RPY_1_CB_1.NET_DataReady               0
     40                          [BEGIN] Net Weight Msg         200                                                                                                              115
     40                          Send Weight to MES             210                                                                                                              116
     40                          [END] Net Weight Msg           299                                                                                                              117
     40                          [BEGIN] Process Tote           300                                                                                                              118
     40                          Process Tote                   310                                                                                                              119
     40                          [END] Process Tote             399                                                                                                              120
              050 - Target
     41       Weight Change      TRIGGER                        0     EQ    NULL                       NULL                                NULL                                   0
     41                          Message Handler Initialize     1                                                                                                                121
     41                          Initialize Local Variables     10                                                                                                               122
     41                          Write Target Weight Value      100   W     SWToolbox.OmniServer                                           RPY_1_CB_1.TRG_TargetWeightValue       0
     41                          Write Target Weight UOM        110   W     SWToolbox.OmniServer                                           RPY_1_CB_1.TRG_TargetWeightUOM         0
     41                          Write Tolerance Weight Value   120   W     SWToolbox.OmniServer                                           RPY_1_CB_1.TRG_ToleranceWeightValue    0
                                 Send Target Weight Change To
     41                          Scale                          190   W     SWToolbox.OmniServer                                           RPY_1_CB_1.TRG_SendMessage             0
              100 - Tray
     42       Locked             TRIGGER                        0     ALL   TOP Server                 5K8_64A_OilPanAssy.MicroLogix1400   TrayLocked                             0
     42                          Bail on reset                  5                                                                                                                123
     42                          Initialize Local Variables     10                                                                                                               124
     42                          Get Part Type                  100                                                                                                              125
     42                          Set Part Type                  200   W     SWToolbox.TOPServer.V5     5K8_64A_OilPanAssy.MicroLogix1400   PartNumber                             0
              200 - Inspection
     43       Complete           TRIGGER                        0     ALL   TOP Server                 5K8_64A_OilPanAssy.MicroLogix1400   InspectionComplete                     0
     43                          Bail on reset                  5                                                                                                                126
     43                          Initialize Local Variables     10                                                                                                               127
     43                          Get Vision Part Number         100   R     SWToolbox.TOPServer.V5     5K8_64A_OilPanAssy.MicroLogix1400   VisionPartNumber                       0
     43                          Process Tote                   310                                                                                                              128



              100 - Tray
     44       Locked             TRIGGER                         0      ALL   TOP Server                 6MA_CH.MicroLogix1400   TrayLocked                                 0
     44                          Initialize Local Variables      10                                                                                                        129
     44                          Send Message to MES             20                                                                                                        130
              200 - Inspection
     45       Complete           TRIGGER                         0      ALL   TOP Server                 6MA_CH.MicroLogix1400   InspectionComplete                         0
     45                          Bail on reset                   5                                                                                                         131
     45                          Initialize Local Variables      10                                                                                                        132
     45                          Send Message to MES             200                                                                                                       133
              003 - Container
     64       Count Request      TRIGGER                         0      EQ    TOP Server                                         5G0_A1.5G0_A1.ContainerCountRequest        0
     64                          Get Container Count             200                                                                                                       202
     64                          Set Container Count             1005   W     SWToolbox.TOPServer.V5                             5G0_A1.5G0_A1.ContainerCount               0
     64                          Reset Container Count Request   1010   W     SWToolbox.TOPServer.V5                             5G0_A1.5G0_A1.ContainerCountRequest        0
              200 - Data
     65       Ready              TRIGGER                         0      EQ    TOP Server                                         5G0_A1.5G0_A1.DataReady                    0
     65                          Reset Data Ready                10     W     SWToolbox.TOPServer.V5                             5G0_A1.5G0_A1.DataReady                    0
     65                          Read Container Count            15     R     SWToolbox.TOPServer.V5                             5G0_A1.5G0_A1.ContainerCount               0
     65                          Set Transaction In Process      20     W     SWToolbox.TOPServer.V5                             5G0_A1.5G0_A1.TransInProc                  0
     65                          Check Container Count           30                                                                                                        204
     65                          Set Part Complete               40     W     SWToolbox.TOPServer.V5                             5G0_A1.5G0_A1.PartComplete                 0
              300 - Net
     66       Weight Update      TRIGGER                         0      EQ    OmniServer                                         5G0_Front_Scale.NET_DataReady              0
     66                          Initialize Local Variables      10                                                                                                        207
     66                          Read Container Count            15     R     SWToolbox.TOPServer.V5                             5G0_A1.5G0_A1.ContainerCount               0
     66                          Validate Part Count             16                                                                                                        208
     66                          Get Net Weight Value            100    R     SWToolbox.OmniServer                               5G0_Front_Scale.NET_NetWeightValue         0
     66                          Get Net Weight UOM              110    R     SWToolbox.OmniServer                               5G0_Front_Scale.NET_NetWeightUOM           0
     66                          Get Target Weight Met Flag      120    R     SWToolbox.OmniServer                               5G0_Front_Scale.NET_TargetWeightMetFlag    0
     66                          Clear Net Weight Data Ready     130    W     SWToolbox.OmniServer                               5G0_Front_Scale.NET_DataReady              0
     66                          [BEGIN] Complete Container      300                                                                                                       209
     66                          Complete Container              320                                                                                                       210
     66                          Set Part Valid                  325    W     SWToolbox.TOPServer.V5                             5G0_A1.5G0_A1.PartValid                    0



     66                         Write Container Quantity           330    W    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.ContainerCount               0
     66                         Write Part Type                    335    W    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.PartType                     0
     66                         [END] Complete Container           399                                                                                                     211
     66                         [BEGIN] Process Next Part          500                                                                                                     212
     66                         Read TransInProc                   510    R    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.TransInProc                  0
     66                         Read Part Complete                 520    R    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.PartComplete                 0
     66                         Check Next Part Pending            540                                                                                                     213
     66                         Set Part Complete                  550    W    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.PartComplete                 0
     66                         [END] Process Next Part            599                                                                                                     214
              400 - Process
     67       Part              TRIGGER                            0      EQ   TOP Server                                        5G0_A1.5G0_A1.PartComplete                 0
     67                         Read Serial Number                 100    R    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.PartSN                       0
     67                         Read Hardware Interlock Enforced   130    R    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.HardwareInterlockEnforced    0
     67                         Process Part                       200                                                                                                     215
     67                         Set Part Valid                     1000   W    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.PartValid                    0
     67                         Skip To Write Container Quantity   1010                                                                                                    216
     67                         Set Alarm Type                     1020   W    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.MESAlarmType                 0
     67                         Set Alarm Message                  1030   W    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.MESAlarmText                 0
     67                         Write Container Quantity           1040   W    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.ContainerCount               0
     67                         Write Part Type                    1050   W    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.PartType                     0
     67                         Reset Transaction In Process       1100   W    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.TransInProc                  0
     67                         Reset Part Complete                1200   W    SWToolbox.TOPServer.V5                            5G0_A1.5G0_A1.PartComplete                 0
              003 - Container
     72       Count Request     TRIGGER                            0      EQ   TOP Server                                        5G0_A2.5G0_A2.ContainerCountRequest        0
     72                         Get Container Count                200                                                                                                     229
     72                         Set Container Count                1005   W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.ContainerCount               0
     72                         Reset Container Count Request      1010   W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.ContainerCountRequest        0
              200 - Data
     73       Ready             TRIGGER                            0      EQ   TOP Server                                        5G0_A2.5G0_A2.DataReady                    0
     73                         Reset Data Ready                   10     W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.DataReady                    0
     73                         Read Container Count               15     R    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.ContainerCount               0
     73                         Set Transaction In Process         20     W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.TransInProc                  0



     73                          Check Container Count              30                                                                                                      232
     73                          Set Part Complete                  40     W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.PartComplete                 0
              300 - Scale Data
     75       Ready              TRIGGER                            0      EQ   OmniServer                                        5G0_Rear_Scale.NET_DataReady               0
     75                          Initialize Local Variables         10                                                                                                      233
     75                          Get Net Weight Value               100    R    SWToolbox.OmniServer                              5G0_Rear_Scale.NET_NetWeightValue          0
     75                          Get Net Weight UOM                 110    R    SWToolbox.OmniServer                              5G0_Rear_Scale.NET_NetWeightUOM            0
     75                          Get Target Weight Met Flag         120    R    SWToolbox.OmniServer                              5G0_Rear_Scale.NET_TargetWeightMetFlag     0
     75                          Clear Net Weight Data Ready        130    W    SWToolbox.OmniServer                              5G0_Rear_Scale.NET_DataReady               0
     75                          [BEGIN] Complete Container         300                                                                                                     240
     75                          Complete Container                 320                                                                                                     241
     75                          Set Part Valid                     325    W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.PartValid                    0
     75                          Reset Container Quantity           330    W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.ContainerCount               0
     75                          Write Part Type                    335    W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.PartType                     0
     75                          [END] Complete Container           399                                                                                                     242
     75                          [BEGIN] Process Next Part          500                                                                                                     243
     75                          Read TransInProc                   510    R    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.TransInProc                  0
     75                          Read Part Complete                 520    R    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.PartComplete                 0
     75                          Check Next Part Pending            540                                                                                                     244
     75                          Set Part Complete                  550    W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.PartComplete                 0
     75                          [END] Process Next Part            599                                                                                                     245
              400 - Process
     76       Part               TRIGGER                            0      EQ   TOP Server                                        5G0_A2.5G0_A2.PartComplete                 0
     76                          Read Serial Number                 100    R    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.PartSN                       0
     76                          Read Hardware Interlock Enforced   130    R    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.HardwareInterlockEnforced    0
     76                          Process Part                       200                                                                                                     246
     76                          Set Part Valid                     1000   W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.PartValid                    0
     76                          Skip To Write Container Quantity   1010                                                                                                    247
     76                          Set Alarm Type                     1020   W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.MESAlarmType                 0
     76                          Set Alarm Message                  1030   W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.MESAlarmText                 0
     76                          Write Container Quantity           1040   W    SWToolbox.TOPServer.V5                            5G0_A2.5G0_A2.ContainerCount               0



     76                          Write Part Type                1050   W     SWToolbox.TOPServer.V5                                     5G0_A2.5G0_A2.PartType        0
     76                          Reset Transaction In Process   1100   W     SWToolbox.TOPServer.V5                                     5G0_A2.5G0_A2.TransInProc     0
     76                          Reset Part Complete            1200   W     SWToolbox.TOPServer.V5                                     5G0_A2.5G0_A2.PartComplete    0
              200 - Inspection
     79       Complete           TRIGGER                        0      ALL   TOP Server                 RPY_CH.MicroLogix1400           InspectionComplete            0
     79                          Bail on reset                  5                                                                                                    251
     79                          Initialize Local Variables     10                                                                                                   252
     79                          Get Vision Part Number         100    R     SWToolbox.TOPServer.V5     RPY_CH.MicroLogix1400           PartNumber                    0
     79                          Process Tray                   310                                                                                                  254
     79                          Send Message to MES            320                                                                                                  262
              100 - Tray
     80       Locked             TRIGGER                        0      ALL   TOP Server                 RPY_CH.MicroLogix1400           TrayLocked                    0
     80                          Initialize Local Variables     10                                                                                                   255
     80                          Get Part Type                  50                                                                                                   259
     80                          Set Part Type                  100    W     SWToolbox.TOPServer.V5     RPY_CH.MicroLogix1400           PartNumber                    0
     80                          Process Tray Locked            200                                                                                                  260
     80                          Send Message to MES            210                                                                                                  261
     80                          Set Ok To Continue             300    W     SWToolbox.TOPServer.V5     RPY_CH.MicroLogix1400           OkToContinue                  0
              100 - Tray
     82       Locked             TRIGGER                        0      ALL   TOP Server                 5J6_OilPanAssy.MicroLogix1400   TrayLocked                    0
     82                          Bail on reset                  5                                                                                                    263
     82                          Initialize Local Variables     10                                                                                                   264
     82                          Get Part Type                  100                                                                                                  265
     82                          Set Part Type                  200    W     SWToolbox.TOPServer.V5     5J6_OilPanAssy.MicroLogix1400   PartNumber                    0
              200 - Inspection
     83       Complete           TRIGGER                        0      ALL   TOP Server                 5J6_OilPanAssy.MicroLogix1400   InspectionComplete            0
     83                          Bail on reset                  5                                                                                                    266
     83                          Initialize Local Variables     10                                                                                                   267
     83                          Get Vision Part Number         100    R     SWToolbox.TOPServer.V5     5J6_OilPanAssy.MicroLogix1400   VisionPartNumber              0
     83                          Process Tote                   310                                                                                                  268
              100 - Tray
     84       Locked             TRIGGER                        0      ALL   TOP Server                 6MA_CH.MicroLogix1400           TrayLocked                    0
     84                          Initialize Local Variables     10                                                                                                   274



     84                          Send Message to MES          20                                                                                  275
              150 - Set In-
              Process
     85       Container          TRIGGER                      0     ALL   NULL                       NULL                    NULL                  0
     85                          Message Handler Initialize   1                                                                                   276
     85                          Set Part Type                100   W     SWToolbox.TOPServer.V5     6MA_CH.MicroLogix1400   PartNumber            0
     85                          Set Container Name           200   W     SWToolbox.TOPServer.V5     6MA_CH.MicroLogix1400   ContainerName         0
     85                          Set Ok To Continue           300   W     SWToolbox.TOPServer.V5     6MA_CH.MicroLogix1400   OkToContinue          0
              200 - Inspection
     86       Complete           TRIGGER                      0     ALL   TOP Server                 6MA_CH.MicroLogix1400   InspectionComplete    0
     86                          Bail on reset                5                                                                                   277
     86                          Initialize Local Variables   10                                                                                  278
     86                          Send Message to MES          200                                                                                 279
              100 - Tray
     87       Locked             TRIGGER                      0     ALL   TOP Server                 6FB_CH.MicroLogix1400   TrayLocked            0
     87                          Bail on Reset                5                                                                                   291
     87                          Initialize Local Variables   10                                                                                  280
     87                          Send Message to MES          300                                                                                 290
     87                          Set Ok to Continue           400   W     SWToolbox.TOPServer.V5     6FB_CH.Micrologix1400   OkToContinue          0
              200 - Inspection
     89       Complete           TRIGGER                      0     ALL   TOP Server                 6FB_CH.MicroLogix1400   InspectionComplete    0
     89                          Bail on reset                5                                                                                   283
     89                          Initialize Local Variables   10                                                                                  284
     89                          Get Vision Part Number       100   R     SWToolbox.TOPServer.V5     6FB_CH.MicroLogix1400   PartNumber            0
     89                          Process Tray Complete        325                                                                                 292
     89                          Send Message to MES          420                                                                                 287


