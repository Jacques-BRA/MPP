# Appendix B — Machines and Processes

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.


---


           Appendix B.                            M A CHINE S AND P RO CE SSES



                                                              Min     Ref     Prod                     Planned
            Mach   Mach                                       Per     Cycle   Per     Cycle   OEE      Qty       Dept   Dept       Proc                 Orig
            ID     No      Mach Desc    Tonnage   Dept desc   Shift   Time    Shift   Time    Target   100p      Code   Desc       id     Proc Desc     Proc



            1      1       DieCast#1    125       Die Cast    450     31      0                                  DC     Die Cast   1      Diecast       1



            2      2       DieCast#2    125       Die Cast    450     31      0                                  DC     Die Cast   1      Diecast       1



            3      3       DieCast#3    125       Die Cast    450     31      0                                  DC     Die Cast   1      Diecast       1



            4      4       DieCast#4    350       Die Cast    450     43      0                                  DC     Die Cast   1      Diecast       1



            5      5       Diecast#5    350       Die Cast    450     43      0                                  DC     Die Cast   1      Diecast       1



            6      6       Diecast#6    350       Die Cast    450     43      0                                  DC     Die Cast   1      Diecast       1



            7      7       DieCast#7    250       Die Cast    450     40      0                                  DC     Die Cast   1      Diecast       1



            8      8       DieCast#8    350       Die Cast    450     43      0                                  DC     Die Cast   1      Diecast       1



            9      9       DieCast#9    350       Die Cast    450     43      0                                  DC     Die Cast   1      Diecast       1



            10     10      DieCast#10   350       Die Cast    450     43      0                                  DC     Die Cast   1      Diecast       1



            11     11      DieCast#11   250       Die Cast    450     40      0                                  DC     Die Cast   1      Diecast       1



            12     12      DieCast#12   250       Die Cast    450     40      0                                  DC     Die Cast   1      Diecast       1



            13     61      DieCast#61   350       Die Cast    450     32      0                                  DC     Die Cast   1      Diecast       1



            14     62      DieCast#62   350       Die Cast    450     43      0                                  DC     Die Cast   1      Diecast       1



            15     63      DieCast#63   350       Die Cast    450     43      0                                  DC     Die Cast   1      Diecast       1



            16     64      DieCast#64   350       Die Cast    450     43      0                                  DC     Die Cast   1      Diecast       1



            17     65      DieCast#65   350       Die Cast    450     43      0                                  DC     Die Cast   1      Diecast       1



            18     66      DieCast#66   500       Die Cast    450     50      0                                  DC     Die Cast   1      Diecast       1



            19     67      DieCast#67   500       Die Cast    450     50      0                                  DC     Die Cast   1      Diecast       1



            20     70      DieCast#70   350       Die Cast    450     32      0                                  DC     Die Cast   1      Diecast       1



            21     73      DieCast#73   1250      Die Cast    460     86      0                                  DC     Die Cast   1      Diecast       1



            22     74      DieCast#74   800       Die Cast    460     72      0                                  DC     Die Cast   1      Diecast       1



            23     75      DieCast#75   1650      Die Cast    460     120     0                                  DC     Die Cast   1      Diecast       1



            24     76      DieCast#76   1250      Die Cast    460     86      0                                  DC     Die Cast   1      Diecast       1
                                                                                                                                          Debur-
            25     113     Debur#113              Die Cast    450             0                                  DC     Die Cast   6      Mach 27       0
                                                                                                                                          Debur-
            26     114     Debur#114              Die Cast    450             0                                  DC     Die Cast   6      Mach 27       0
                                                                                                                        Trim              Debur-
            27     22      22 - Debur             Trim Shop   450             0                                  TS     Shop       6      Mach 27       0
                                                                                                                        Trim              Debur-
            28     28      TS Assoc               Trim Shop   480             0                                  TS     Shop       7      Hand 27       0
                                                  Machine                                                               Machine
            30     30      MS Assoc               Shop        480             0                                  MS     Shop       8      Machine       0
                                                  Prod.                                                                 Prod.
            31     31      PC Assoc               Control     480             0                                  PC     Control



            32     32      DC Assoc               Die Cast    480             0                                  DC     Die Cast
                                                  Machine                                                               Machine
            33     535     Leak Test              Shop        450             0                                  MS     Shop       13     Leak Test     0
                                                  Machine                                                               Machine
            34     1165    Leak Test              Shop        450             0                                  MS     Shop       13     Leak Test     0
                                                  Machine                                                               Machine
            35     798     First Cut              Shop        450             0                                  MS     Shop       8      Machine       0
                                                  Machine                                                               Machine
            36     880     First Cut              Shop        450             0                                  MS     Shop       8      Machine       0



                                                 Machine                                                Machine
            37     908     First Cut             Shop       450        0                          MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            38     909     First Cut             Shop       450        0                          MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            39     910     Leak Test             Shop       450        0                          MS    Shop       13   Leak Test     0
                                                 New                                                    New
            40     40      Administer            Model      480        0                          NM    Model      21   Administer    0



            41     77      Diecast#77      700   Die Cast   480        0                          DC    Die Cast   1    Diecast       1



            42     50      Hoffman DC            Die Cast   450        0                          DC    Die Cast   1    Diecast       1



            43     51      ACP                   Die Cast   450        0                          DC    Die Cast   1    Diecast       1



            44     69      Diecast#69      350   Die Cast   450        0                          DC    Die Cast   1    Diecast       1
                                                                                                                        Debur-
            45     1665    KensCorp              Die Cast   450        0                          DC    Die Cast   6    Mach 27       0
                                                 Machine                                                Machine
            46     1166    PNA Op 10-1           Shop       91         753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            47     1167    PNA Op 10-2           Shop       91         753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            48     1168    PNA Op 10-3           Shop       91         753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            49     1169    PNA Op 10-4           Shop       91         753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            50     1170    PNA Op 10-5           Shop       91         753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            51     1171    PNA Op 10-6           Shop       91         753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            52     1172    PNA Op 10-7           Shop       91         753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            53     1173    PNA Op 20-1           Shop                  753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            54     1174    PNA Op 20-2           Shop                  753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            55     1175    PNA Op 20-3           Shop                  753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            56     1176    PNA Op 30-1           Shop                  753    29   0.85   881     MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            57     1177    PNA Op 30-2           Shop                  753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            58     1178    PNA Op 30-3           Shop                  753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            59     1181    PNA Op 60             Shop                  753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            60     1179    PNA Op 40             Shop                  753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            61     1180    PNA Op 50             Shop                  0                          MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            63     1093    PNA Washer            Shop                  0                          MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            64     2153    PNA Op 60 FEC         Shop                  0                          MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            65     1182    PNA Op 70A            Shop                  753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            68     1183    PNA Op 70B            Shop                  753                        MS    Shop       8    Machine       0



            69     501     VCM #501              Die Cast              0                          DC    Die Cast   1    Diecast       1



            70     502     VCM #502              Die Cast              0                          DC    Die Cast   1    Diecast       1



            71     68      DieCast#68      500   Die Cast   450   50   0                          DC    Die Cast   1    Diecast       1
                                                 Machine                                                Machine
            73     1763    OP10                  Shop                  413                        MS    Shop       8    Machine       0
                           PNA DOWEL PIN         Machine                                                Machine
            74     2477    PRESS                 Shop                  753                        MS    Shop       8    Machine       0
                           PNA FACE              Machine                                                Machine
            75     2371    HEIGHT                Shop                  753                        MS    Shop       8    Machine       0




## PNA TC CAP


                           OP30 L/T              Machine                                                Machine
            76     1692    (1692A)               Shop                  753                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            77     2494    KIRA ELESYS           Shop                  1022                       MS    Shop       8    Machine       0
                           ELESYS HEAT           Machine                                                Machine
            78     2186    SINK OP10             Shop                  1022                       MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            79     2506    OP-10                 Shop                  344                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            80     2507    Assembly              Shop                  344                        MS    Shop       8    Machine       0
                                                 Machine                                                Machine
            81     2508    Leaktest              Shop                  344                        MS    Shop       8    Machine       0



                                            Machine                                      Machine
            82     2742    RV2 CAP AL ASY   Shop      577                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            83     2741    RJF CAP AL ASY   Shop      577                          MS    Shop      8    Machine      0
                           CAP AL RV2/RJF   Machine                                      Machine
            84     1761    OP10-A (1761A)   Shop      577                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            86     650     OP10-1           Shop      710   82                     MS    Shop      8    Machine      0
                                            Machine                                      Machine
            87     656     OP10-2           Shop      710   82                     MS    Shop      8    Machine      0
                                            Machine                                      Machine
            88     1687    OP20/30-1        Shop      710   140                    MS    Shop      8    Machine      0
                                            Machine                                      Machine
            89     1688    OP20/30-2        Shop      710   140                    MS    Shop      8    Machine      0
                           LOST MOTION      Machine                                      Machine
            90     2340    OP40 DEBURR      Shop      710   22                     MS    Shop      8    Machine      0




## LOST MOTION


                           DOWEL PIN ASY    Machine                                      Machine
            91     1689    (1689A)          Shop      710   10                     MS    Shop      8    Machine      0
                           LOST MOTION      Machine                                      Machine
            92     1690    FLATNESS         Shop      710   5                      MS    Shop      8    Machine      0
                                            Machine                                      Machine
            96     1851    OP10-1           Shop      241                          MS    Shop      8    Machine      0
                           RNA MAKINO       Machine                                      Machine
            97     1852    OP10-2           Shop      241                          MS    Shop      8    Machine      0
                           R70 ASY & L/T    Machine                                      Machine
            98     1959    V6               Shop      645                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            99     1660    RNO OP30         Shop      645                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            100    2003    OP20-1           Shop      241                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            102    2002    OP20-2           Shop      241                          MS    Shop      8    Machine      0
                           RNA/R1B ASY      Machine                                      Machine
            103    1663    L/T              Shop      241                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            104    1658    OP30-2           Shop      241                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            105    1659    OP30-1           Shop      241                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            109    2001    OP20-3           Shop      241                          MS    Shop      8    Machine      0
                           RXO/R5A OIL      Machine                                      Machine
            111    2482    PAN ASY          Shop      472                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            112    1757    OP10             Shop      472                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            113    2530    OP30-1           Shop      472                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            114    2531    OP20-1           Shop      472                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            115    2532    OP30-2           Shop      472                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            116    2533    OP20-2           Shop      472                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            117    2190    OP10-20 B        Shop      515                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            118    2191    OP10-20 A        Shop      515                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            119    2564    OP-30            Shop      515                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            121    2449    OP20/30          Shop      553                          MS    Shop      8    Machine      0
                                            Machine                                      Machine
            122    2606    OP10-2C          Shop      0     29      0.85   881     MS    Shop      8    Machine      0
                                            Machine                                      Machine
            123    2607    OP10-1C          Shop      0     29      0.85   881     MS    Shop      8    Machine      0
                                            Machine                                      Machine
            124    2608    OP10             Shop      0     26.3    0.85   972     MS    Shop      8    Machine      0
                                            Machine                                      Machine
            125    2628    OP60C            Shop      0                            MS    Shop      8    Machine      0
                                            Machine                                      Machine
            126    2609    OP10-1A          Shop      0     33.75   0.85   757     MS    Shop      8    Machine      0
                                            Machine                                      Machine
            127    2610    OP10-2A          Shop      0     33.75   0.85   757     MS    Shop      8    Machine      0
                                            Machine                                      Machine
            128    2611    OP20-1A          Shop      0     33      0.85   775     MS    Shop      8    Machine      0
                                            Machine                                      Machine
            129    2612    OP30-1A          Shop      0     32      0.85   799     MS    Shop      8    Machine      0
                                            Machine                                      Machine
            130    2613    OP30-2A          Shop      0     32      0.85   799     MS    Shop      8    Machine      0
                                            Machine                                      Machine
            131    2631    OP50             Shop      0     31      0.85   825     MS    Shop      8    Machine      0
                                            Machine                                      Machine
            132    2629    OP60A            Shop      0                            MS    Shop      8    Machine      0



                                            Machine                                       Machine
            133    2630    OP60B            Shop       0                            MS    Shop       8   Machine       0
                                            Machine                                       Machine
            134    2614    OP10-1B          Shop       0     34      0.85   752     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            135    2615    OP10-2B          Shop       0     34      0.85   752     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            136    2616    OP10.5-2B        Shop       0     34      0.85   752     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            137    2617    OP20-1B          Shop       0     33      0.85   775     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            138    2618    OP30-1B          Shop       0     32      0.85   799     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            139    2619    OP30-2B          Shop       0     32      0.85   799     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            140    2620    OP10-1D          Shop       0     36.25   0.85   705     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            141    2621    OP20-1D          Shop       0     36.25   0.85   705     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            142    2635    OP40             Shop       0     31      0.85   825     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            143    2622    OP20-2E          Shop       0     38      0.85   673     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            144    2623    OP10-2E          Shop       0     36.25   0.85   705     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            145    2624    OP10-2D          Shop       0     36.25   0.85   705     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            146    2625    OP20-2D          Shop       0     36.75   0.85   696     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            147    2626    OP20-1E          Shop       0     38      0.85   673     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            148    2627    OP10-1E          Shop       0     36.25   0.85   705     MS    Shop       8   Machine       0
                           WATER OUTLET     Machine                                       Machine
            149    1643    ASY              Shop       706   36                     MS    Shop       8   Machine       0



            150    503     VCM #503         Die Cast   0                            DC    Die Cast   1   Diecast       1



            151    504     VCM #504         Die Cast   0                            DC    Die Cast   1   Diecast       1
                                            Machine                                       Machine
            152    2720    OP30             Shop       0     36      0.85   710     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            154    2722    OP0              Shop       0     32.75   0.85   780     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            155    2723    OP10.5-1B        Shop       0     34      0.85   752     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            156    2636    OP70A            Shop       0     23      0.85   1111    MS    Shop       8   Machine       0
                                            Machine                                       Machine
            157    2637    OP70-C2A         Shop       0     26.5    0.85   965     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            158    2707    OP70-B1          Shop       0     23.6    0.85   1083    MS    Shop       8   Machine       0
                                            Machine                                       Machine
            159    2708    OP70-C1          Shop       0     26.5    0.85   965     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            160    2724    OP70-C2B         Shop       0     26.5    0.85   965     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            161    2725    OP70-B2          Shop       0     23.6    0.85   1083    MS    Shop       8   Machine       0
                                            Machine                                       Machine
            162    2721    OP30             Shop       0     34.5    0.85   741     MS    Shop       8   Machine       0
                                            Machine                                       Machine
            163    0       N/A              Shop       0                            MS    Shop       8   Machine       0
                                            Machine                                       Machine
            164    1486    COS OKUMA        Shop       0     190                    MS    Shop       8   Machine       0
                                            Machine                                       Machine
            166    1135    COS MAZAK        Shop       0     215                    MS    Shop       8   Machine       0
                           COS ROBO         Machine                                       Machine
            167    663     DRILL (OP-20)    Shop       0     36                     MS    Shop       8   Machine       0




## COS DOWEL


                           PRESS LEAK       Machine                                       Machine
            169    1957    TESTER           Shop       0                            MS    Shop       8   Machine       0




## COS DOWELL


                           PRESS LEAK       Machine                                       Machine
            170    1958    TESTER           Shop       0                            MS    Shop       8   Machine       0
                                            Machine                                       Machine
            171    1955    COS SEAL PRESS   Shop       0                            MS    Shop       8   Machine       0
                                            Machine                                       Machine
            172    2423    COS WASHER       Shop       0     402                    MS    Shop       8   Machine       0
                           THERMO COVER     Machine                                       Machine
            173    662     ROBO DRILL       Shop       0                            MS    Shop       8   Machine       0
                           THERMO COVER     Machine                                       Machine
            174    585     LEAK TESTER      Shop       0                            MS    Shop       8   Machine       0




## HEATER OUTLET


                           ROBO DRILL OP-   Machine                                       Machine
            175    659     10               Shop       0     54                     MS    Shop       8   Machine       0




## HEATER OUTLET


                           ROBO DRILL OP-    Machine                                     Machine
            176    657     20                Shop      0                           MS    Shop      8    Machine      0
                           HEATER OUTLET     Machine                                     Machine
            177    1667    WASHER            Shop      0                           MS    Shop      8    Machine      0




## HEATER OUTLET


                           ASSEMBLY/LEAK     Machine                                     Machine
            178    1666    TEST              Shop      0                           MS    Shop      8    Machine      0
                                             Machine                                     Machine
            179    2341    Parts Washer      Shop      0      60                   MS    Shop      8    Machine      0
                           Bolt Torque       Machine                                     Machine
            180    1164    Machine           Shop      0      22                   MS    Shop      8    Machine      0



            182    1641    Thermo Case                 0      36
                           Side Case OP20-
            183    1755    1                           280    77.5
                           Side Case OP20-
            184    1756    2                           280    77.5
                           Side Case Leak
            185    1758    Tester                      280    77.5
                           Side Case OP40
            186    1759    Washer                      280    77.5



            187    1784    Side Case OP10              280    77.5
                           Side Case OP30-
            188    1785    2                           280    77.5



            189    1965    OP10-1                      400    40



            190    1966    OP10-2                      400    40
                           Assembly
            191    1978    Bridge Line 1               480    47.5



            192    1989    OP40-2                      400    40



            193    1995    OP50-1 Washer               548    20



            194    1998    OP0-1                       400    40



            195    1999    OP0-2                       400    40
                           Assembly
            196    2166    Bridge Line 2               540    46



            197    2182    OP40-3                      400    40
                           OP10/20-3
            198    2187    #1/#3                       548    20



            199    2188    OP50-2 Washer               400    40



            200    2189    OP10/20-3 #2                1096   40
                           OP20/30
            201    2363    Transfer                    400    40
                           Housing B Leak
            202    2424    Tester                      630    35.5
                           Motor Holder
            203    2425    Leak Tester                 630    35.5



            204    2426    Housing B OP10              630    35.5
                           Motor Holder
            206    2428    OP20                        630    35.5



            207    2555    Showa Washer                630    35.5



            208    2555    Showa Washer                630    35.5
                           OP10/20-1
            209    2638    #1/#3                       548    20
                           OP10/20-2
            210    2639    #1/#3                       548    20



            211    2640    OP10/20-1 #2                1096   40



            212    2641    OP10/20-2 #2                1096   40
                           Assembly 5G0
            213    2642    Rear                        593    37
                           Assembly 5G0
            214    2653    Front                       593    37
                           Housing B
            215    652     OP20-1                      630    35.5
                           Motor Holder
            216    654     OP30                        630    35.5
                           Housing B
            217    661     OP20-2                      630    35.5
                                             Machine                                     Machine
            218    1771    CAP A L OP10      Shop      0                           MS    Shop      8    Machine      0



                                             Machine                                    Machine
            219    1668    CAP A L OP10      Shop      0                          MS    Shop      8    Machine       0
                           CAP COOLER        Machine                                    Machine
            220    641     ROBODRILL         Shop      0                          MS    Shop      8    Machine       0
                           CAP COOLER        Machine                                    Machine
            221    2654    ROBODRILL         Shop      0                          MS    Shop      8    Machine       0




## HEAT SINK


                           ROBODRILL OP      Machine                                    Machine
            222    2655    10-4              Shop      0                          MS    Shop      8    Machine       0
                           GUIDE             Machine                                    Machine
            223    648     PRESSURE OP20     Shop      0                          MS    Shop      8    Machine       0




## TK8 HOUSING


                           ROBO DRILL OP-    Machine                                    Machine
            224    649     10                Shop      0                          MS    Shop      8    Machine       0




## CIVIC WATER


                           PUMP L/T &        Machine                                    Machine
            225    1611    ASY               Shop      0                          MS    Shop      8    Machine       0
                                             Machine                                    Machine
            226    2562    RJ2 OIL PAN L/T   Shop      0                          MS    Shop      8    Machine       0
                                             Machine                                    Machine
            227    1797    CIVIC MAKINO      Shop      0                          MS    Shop      8    Machine       0
                                             Machine                                    Machine
            228    2719    CH EX1-2 OP20     Shop      826   26.3                 MS    Shop      1    Diecast       1
                           Side Case OP20-   Machine                                    Machine
            230    1755    1                 Shop      280   77.5                 MS    Shop      8    Machine       0


