# Appendix D — Downtime Reason Codes

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.


---


           Appendix D.                    D OWN TIME R EA SON C ODES
            Reason                                                 Dept         Dept      Type
            ID          Reason Desc                     Dept ID    Desc         Code      ID         Type Desc       Excused
                 1      Scheduled Downtime              10         Die Cast     DC        6          Unscheduled     0
                 2      Mold Change                     10         Die Cast     DC        5          Setup           0
                 3      Machine Repair                  10         Die Cast     DC        1          Equipment       1
                 4      Mold Repair                     10         Die Cast     DC        3          Mold            1
                 5      Bad Repair                      10         Die Cast     DC        3          Mold            1
                 6      Cam Repair                      10         Die Cast     DC        3          Mold            1
                 7      Sprayer Adjustment              10         Die Cast     DC        1          Equipment       0
                 8      Sprayer Repair                  10         Die Cast     DC        1          Equipment       0
                 9      Trim Press Adjustment           10         Die Cast     DC        1          Equipment       1
                10      Trim Press Repair/Adjustment    10         Die Cast     DC        1          Equipment       0
                11      Trim Die Repair                 10         Die Cast     DC        3          Mold            0
                12      Furnace Trouble                 10         Die Cast     DC        1          Equipment       0
                13      AK Porter                       10         Die Cast     DC        1          Equipment       0
                14      Sleeve and Tip                  10         Die Cast     DC        1          Equipment       1
                15      Die Lube System                 10         Die Cast     DC        1          Equipment       0
                16      Machine Start-Up/Preheat        10         Die Cast     DC        2          Miscellaneous   0
                17      Sample Test Work                10         Die Cast     DC        2          Miscellaneous   1
                18      Insert Machine Trouble          10         Die Cast     DC        1          Equipment       1
                19      Flash Removal (@ Machine)       10         Die Cast     DC        3          Mold            0
                20      Machine Adjustment              10         Die Cast     DC        1          Equipment       1
                21      Extractor Repair/Adjustment     10         Die Cast     DC        1          Equipment       0
                22      Extractor Adjustment            10         Die Cast     DC        1          Equipment       1
                23      Auto Ladle Repair               10         Die Cast     DC        1          Equipment       0
                24      No Rocker Arm Inserts           10         Die Cast     DC        2          Miscellaneous   1
                25      Broken Crane                    10         Die Cast     DC        1          Equipment       0
                26      No Operator                     10         Die Cast     DC        2          Miscellaneous   1
                27      Computer Problems               10         Die Cast     DC        1          Equipment       1
                28      Conveyor Problems               10         Die Cast     DC        1          Equipment       0
                29      Thermo Cast Problems            10         Die Cast     DC        1          Equipment       1
                30      N/G Production Time             10         Die Cast     DC        2          Miscellaneous   1
                31      No Baskets                      10         Die Cast     DC        2          Miscellaneous   1
                32      Waiting on Q.C. Approval        10         Die Cast     DC        4          Quality         1
                33      Sorting or Repairing Parts      10         Die Cast     DC        4          Quality         1
                34      Cooling Tower/Water Pressure    10         Die Cast     DC        2          Miscellaneous   1
                35      Power Outage                    10         Die Cast     DC        2          Miscellaneous   1
                36      Emergency Evacuation/Shutdown   10         Die Cast     DC        2          Miscellaneous   1
                37      Solder Removal (@ Machine)      10         Die Cast     DC        3          Mold            0
                38      Hydraulic Core Trouble          10         Die Cast     DC        3          Mold            1



                  39    Low Air Pressure                       10    Die Cast     DC        1          Equipment       0
                  40    Gripper Trouble                        10    Die Cast     DC        1          Equipment       1
                  41    Tool Measure                           10    Die Cast     DC        1          Equipment       1
                  42    Robot/Gripper                          10    Die Cast     DC        1          Equipment       0
                  43    Tool Change                            10    Die Cast     DC        1          Equipment       1
                  44    Part Detect Sensors                    10    Die Cast     DC        1          Equipment       0
                  45    Tool Sensor's Not Reading              10    Die Cast     DC        1          Equipment       1
                  46    Die Table Changeover                   10    Die Cast     DC        1          Equipment       1
                  47    Waiting on Maintenance                 10    Die Cast     DC        2          Miscellaneous   1
                  48    Tool Life Count Up                     10    Die Cast     DC        1          Equipment       1
                  49    Stuck Part                             10    Die Cast     DC        1          Equipment       0
                  50    Waiting for Parts                      10    Die Cast     DC        2          Miscellaneous   1
                  51    Thermal Pictures                       10    Die Cast     DC        1          Equipment       1
                  52    Waiting for Tech/Team Leader           10    Die Cast     DC                                   1
                  53    Broken Drill                           10    Die Cast     DC                                   1
                  54    Engraver                               10    Die Cast     DC                                   0
                  55    No Parts                               10    Die Cast     DC                                   1
                  56    COP                                    10    Die Cast     DC                                   1
                  57    Preventive Maintenance                 10    Die Cast     DC                                   1
                  58    Training New Associate                 10    Die Cast     DC                                   1
                  59    Waiting for Crane                      10    Die Cast     DC                                   0
                  64    Preventive Maintenance                 10    Die Cast     DC                                   0
                  66    Quench Tank                            10    Die Cast     DC                                   0
                  67    Quench Tank Fixtures                   10    Die Cast     DC                                   1
                  68    Machine Overheating                    10    Die Cast     DC                                   1
                  69    D/C Machine Hyd.                       10    Die Cast     DC                                   0
                  70    D/C Machine Elec.                      10    Die Cast     DC                                   0
                  71    D/C Machine Mech.                      10    Die Cast     DC                                   0
                  72    Mold Repair - Broken/Bent Pin          10    Die Cast     DC                                   0
                  73    Mold Repair-Bent Pin                   10    Die Cast     DC                                   1
                  74    Mold Repair-Broken Die                 10    Die Cast     DC                                   1
                  75    Mold Repair-Water Leak                 10    Die Cast     DC                                   0
                  76    Mold Repair - Dimensional/Broken Die   10    Die Cast     DC                                   0
                  77    Mold Repair-Flashing                   10    Die Cast     DC                                   0
                  78    Tip/Coupling                           10    Die Cast     DC                                   0
                  79    Sleeve Change                          10    Die Cast     DC                                   0
                  80    Tip Lube Line Repair                   10    Die Cast     DC                                   0
                  81    Change Tip Coupling                    10    Die Cast     DC                                   1
                  82    Sleeve Adjustments                     10    Die Cast     DC                                   0
                  83    Shot Bead Unit                         10    Die Cast     DC                                   0
                  84    Change Date Pin                        10    Die Cast     DC                                   0
                  85    Quality Check                          10    Die Cast     DC                                   0



                                                           Machine
                  87 OP0-1 Down                      12    Shop         MS                                 0
                                                           Machine
                  88 OP0-2 Down                      12    Shop         MS                                 0
                  89 No Operator                     10    Die Cast     DC                                 0
                  90 Ladel Sensor                    10    Die Cast     DC                                 0
                  91 ELB Cam Cords                   10    Die Cast     DC                                 0
                  92 COP                             10    Die Cast     DC                                 0
                  93 Waiting on MRO                  10    Die Cast     DC                                 0
                  94 Vacuum System                   10    Die Cast     DC        1          Equipment     0
                     Scheduled Down                        Trim
                 201 /////////////////////////////   11    Shop         TS                                 0
                                                           Trim
                 202 Power Outage                    11    Shop         TS                                 0
                                                           Trim
                 203 Emergency Evacuation            11    Shop         TS                                 0
                                                           Trim
                 204 Low Air Pressure                11    Shop         TS                                 0
                                                           Trim
                 205 No Operator                     11    Shop         TS                                 0
                                                           Trim
                 206 Gripper Trouble                 11    Shop         TS                                 0
                                                           Trim
                 207 Tool Measure                    11    Shop         TS                                 0
                                                           Trim
                 208 Robot Position Trouble          11    Shop         TS                                 0
                                                           Trim
                 209 Tool Change                     11    Shop         TS                                 0
                                                           Trim
                 210 Part Detect Sensors             11    Shop         TS                                 0
                                                           Trim
                 211 Tool Sensors not Reading        11    Shop         TS                                 0
                                                           Trim
                 212 Conveyor Trouble                11    Shop         TS                                 0
                                                           Trim
                 213 Die Table Change-Over           11    Shop         TS                                 0
                                                           Trim
                 214 No Parts                        11    Shop         TS                                 0
                                                           Trim
                 215 Running Test Parts              11    Shop         TS                                 0
                                                           Trim
                 216 Waiting on Q.C. Approval        11    Shop         TS                                 0
                                                           Trim
                 217 Waiting on Maintenance          11    Shop         TS                                 0



                                                                    Trim
                 218 Tool Life Count Up                      11     Shop         TS                               0
                                                                    Trim
                 219 Stuck Part                              11     Shop         TS                               0
                                                                    Trim
                 220 Table Sensor Not Reading                11     Shop         TS                               0
                                                                    Trim
                 221 Safety Meeting                          11     Shop         TS                               0
                                                                    Trim
                 222 Grinder Trouble                         11     Shop         TS                               0
                                                                    Trim
                 226 Sort Parts                              11     Shop         TS                               0
                                                                    Trim
                 229 C.O.P.                                  11     Shop         TS                               1
                                                                    Trim
                 230 No Dunnage/Baskets                       11    Shop         TS                               1
                     Air Leak on                                    Machine
                 401 Machine///////////////////////////////// 12    Shop         MS                               1
                                                                    Machine
                 402 Assembly Machine Problems               12     Shop         MS                               0
                                                                    Machine
                 403 Awaiting Leader to Reset Red Light      12     Shop         MS                               1
                                                                    Machine
                 404 Broken Tool Change                      12     Shop         MS                               0
                                                                    Machine
                 405 C.O.P.                                  12     Shop         MS                               1
                                                                    Machine
                 406 Cavity Change/Check                     12     Shop         MS                               1
                                                                    Machine
                 407 Change RA Wheels                        12     Shop         MS                               1
                                                                    Machine
                 408 CMM Confirmation of Changeover          12     Shop         MS                               1
                                                                    Machine
                 409 CMM Confirmation of Change Point        12     Shop         MS                               1
                                                                    Machine
                 410 Conveyor Problems                       12     Shop         MS                               1
                                                                    Machine
                 411 Coolant Problems                        12     Shop         MS                               1
                                                                    Machine
                 412 Crash                                   12     Shop         MS                               1
                                                                    Machine
                 413 Cycle Stop                              12     Shop         MS                               0
                                                                    Machine
                 414 Dimension Problems                      12     Shop         MS                               1
                                                                    Machine
                 415 Door Problems                           12     Shop         MS                               0



                                                                 Machine
                 416 Dotting Parts                         12    Shop         MS                               1
                                                                 Machine
                 417 Dowel Pin Problems                    12    Shop         MS                               1
                                                                 Machine
                 418 Drills (Fire, Tornado, etc.)          12    Shop         MS                               0
                                                                 Machine
                 419 Emergency Evacuation/Shutdown         12    Shop         MS                               0
                                                                 Machine
                 420 Excessive Flash Removal               12    Shop         MS                               1
                                                                 Machine
                 421 Engineer Working on Machine           12    Shop         MS                               0
                                                                 Machine
                 422 Hole Size No Good Problem             12    Shop         MS                               1
                                                                 Machine
                 423 How Long MSM to Repair Machine        12    Shop         MS                               0
                                                                 Machine
                 424 How Long MSM to Respond               12    Shop         MS                               1
                                                                 Machine
                 425 Hydraulic Problems                    12    Shop         MS                               1
                                                                 Machine
                 426 Interviews                            12    Shop         MS                               1
                                                                 Machine
                 427 Jig Problems                          12    Shop         MS                               1
                                                                 Machine
                 428 Leak Tester Problems                  12    Shop         MS                               0
                                                                 Machine
                 429 Light Curtain Problems                12    Shop         MS                               1
                                                                 Machine
                 430 Machine Adjustments                   12    Shop         MS                               0
                                                                 Machine
                 431 Machine Leaking (mopping)             12    Shop         MS                               1
                     MSM Prevenative Maintenance on              Machine
                 432 Machine                               12    Shop         MS                               1
                     Machine Trials (New Die Parts, Test         Machine
                 433 Tools, etc)                           12    Shop         MS                               1
                                                                 Machine
                 434 Meetings                              12    Shop         MS                               1
                                                                 Machine
                 435 Pre-shift meetings                    12    Shop         MS                               1
                                                                 Machine
                 436 Misset Problems                       12    Shop         MS                               1
                                                                 Machine
                 437 Changeover                            12    Shop         MS                               1
                                                                 Machine
                 438 Motor Overload/Overheating            12    Shop         MS                               1



                                                                 Machine
                 439 No Diecast Parts                      12    Shop         MS                               1
                                                                 Machine
                 440 No Operator due to Absence            12    Shop         MS                               1
                                                                 Machine
                 441 No Operator due to Repacking          12    Shop         MS                               1
                                                                 Machine
                 442 No Operator due to Repairing Parts    12    Shop         MS                               1
                     No Operator due to Running Other            Machine
                 443 Process                               12    Shop         MS                               1
                                                                 Machine
                 444 No Operator due to Sorting In-House   12    Shop         MS                               1
                     No Operator due to Sorting at               Machine
                 445 Customer                              12    Shop         MS                               1
                     No Operator due to Relieving for            Machine
                 446 Breaks/Lunch                          12    Shop         MS                               1
                                                                 Machine
                 447 Low or No Air Pressure                12    Shop         MS                               1
                                                                 Machine
                 448 No Parts to Assemble                  12    Shop         MS                               1
                                                                 Machine
                 449 No Parts to Inspect                   12    Shop         MS                               1
                                                                 Machine
                 450 No Parts to Lap                       12    Shop         MS                               1
                                                                 Machine
                 451 No Supply Parts                       12    Shop         MS                               0
                                                                 Machine
                 452 No Trim Shop Parts                    12    Shop         MS                               1
                                                                 Machine
                 453 Other                                 12    Shop         MS                               1
                                                                 Machine
                 454 Overfilling Machine (mopping)         12    Shop         MS                               1
                                                                 Machine
                 455 Performing Machine Condition Checks   12    Shop         MS                               1
                                                                 Machine
                 456 Pin Pressure Problem                  12    Shop         MS                               1
                                                                 Machine
                 457 Power Outage/Surges                   12    Shop         MS                               0
                                                                 Machine
                 458 Probe Problems                        12    Shop         MS                               1
                                                                 Machine
                 459 Quality Problems (misc.)              12    Shop         MS                               0
                                                                 Machine
                 460 Red Lights for Machining (misc.)      12    Shop         MS                               0
                                                                 Machine
                 461 Red Lights for Assembly (misc.)       12    Shop         MS                               0



                                                               Machine
                 462 Red Lights for Inspection (misc.)   12    Shop         MS                               0
                                                               Machine
                 463 Restocking Area of Supplies         12    Shop         MS                               1
                                                               Machine
                 464 Safety Problems                     12    Shop         MS                               1
                                                               Machine
                 465 Schedule Zero Production            12    Shop         MS                               1
                                                               Machine
                 466 Seal Problems                       12    Shop         MS                               1
                                                               Machine
                 467 Sensor Problems                     12    Shop         MS                               1
                                                               Machine
                 468 Servo Motor/Cable Problems          12    Shop         MS                               1
                                                               Machine
                 469 Table Full (Stop Production)        12    Shop         MS                               1
                                                               Machine
                 470 Tool Limit (count up)               12    Shop         MS                               0
                                                               Machine
                 471 Training                            12    Shop         MS                               1
                                                               Machine
                 472 Training (Safety)                   12    Shop         MS                               1
                                                               Machine
                 473 Unknown                             12    Shop         MS                               1
                                                               Machine
                 474 Waiting on Q.C. Approval            12    Shop         MS                               1
                                                               Machine
                 475 Warm Up Machines                    12    Shop         MS                               1
                                                               Machine
                 476 Washer Failure on Leak Tester       12    Shop         MS                               1
                                                               Machine
                 477 Washer (Machine) Problems (down)    12    Shop         MS                               0
                                                               Machine
                 478 Worn Tool Change                    12    Shop         MS                               0
                     Measuring Parts (C/D, Surfometer,         Machine
                 479 gaging, etc.)                       12    Shop         MS                               1
                                                               Machine
                 480 ATC Problems                        12    Shop         MS                               1
                                                               Machine
                 481 Clamp Problems                      12    Shop         MS                               1
                                                               Machine
                 482 No Dunnage/Baskets                  12    Shop         MS                               1
                                                               Machine
                 483 Loader Error                        12    Shop         MS                               1
                                                               Machine
                 484 No PLC Thermo Covers                12    Shop         MS                               1



                                                                Machine
                 485 Belt/Timing Problems                 12    Shop         MS                               1
                                                                Machine
                 486 Spindle Problems                     12    Shop         MS                               1
                                                                Machine
                 487 Oil Level Low                        12    Shop         MS                               1
                                                                Machine
                 488 Machine Would Not Start              12    Shop         MS                               1
                                                                Machine
                 489 Empty Chip Bins                      12    Shop         MS                               1
                                                                Machine
                 490 No Water Pressure                    12    Shop         MS                               1
                                                                Machine
                 491 Plant-Wide Meeting                   12    Shop         MS                               1
                                                                Machine
                 492 Shutdown High Inventory Level        12    Shop         MS                               1
                     No Operator due to Emptying Recyle         Machine
                 493 Bins                                 12    Shop         MS                               1
                                                                Machine
                 494 Inventory Schedule Down              12    Shop         MS                               1
                     No Operator due to Training New            Machine
                 495 Operator                             12    Shop         MS                               1
                     No Operator due to Performing              Machine
                 496 Preventive Maintenan                 12    Shop         MS                               1
                                                                Machine
                 497 Hearing Test                         12    Shop         MS                               1
                                                                Machine
                 498 Tool Fell Out                        12    Shop         MS                               1
                                                                Machine
                 499 CMM Parts                            12    Shop         MS                               1
                                                                Machine
                 500 Packing Parts                        12    Shop         MS                               1
                                                                Machine
                 501 No Parts to Machine                  12    Shop         MS                               1
                                                                Machine
                 502 Check Machine                        12    Shop         MS                               1
                                                                Machine
                 503 Inspecting                           12    Shop         MS                               1
                                                                Machine
                 504 Problems with Memory                 12    Shop         MS                               1
                                                                Machine
                 508 Process Change                       12    Shop         MS                               1
                                                                Machine
                 511 Inventory                            12    Shop         MS                               1
                                                                Machine
                 513 Torque Tool Change                   12    Shop         MS                               1



                                                               Machine
                 514 Sort DC/TS Defects                  12    Shop         MS                                1
                                                               Machine
                 515 Dowel Pin Feeder                    12    Shop         MS                                1
                                                               Machine
                 516 OP40 Down                           12    Shop         MS                                1
                                                               Machine
                 517 Purging Line                        12    Shop         MS                                1
                                                               Machine
                 518 No parts from previous process      12    Shop         MS                                0
                                                               Machine
                 519 Dowel pin feeder down               12    Shop         MS                                1
                                                               Machine
                 520 Precautionary Shutdown              12    Shop         MS                                1
                                                               Machine
                 521 No User due to Re-Inspection        12    Shop         MS                                1
                                                               Machine
                 522 Bolt stuck in chute                 12    Shop         MS                                1
                                                               Machine
                 523 Waiting on torque gun               12    Shop         MS                                1
                                                               Machine
                 524 Spring change                       12    Shop         MS                                1
                                                               Machine
                 525 No Oper. For running overflow       12    Shop         MS                                1
                                                               Machine
                 527 Cleaning/Filling Washer             12    Shop         MS                                1
                                                               Machine
                 528 (M02)Face Height Ajustment          12    Shop         MS                                1
                                                               Machine
                 529 (M03)Part Height Ajustment          12    Shop         MS                                1
                                                               Machine
                 530 (M04)Dow Pin Pitch Ajustment        12    Shop         MS                                1
                                                               Machine
                 531 (M11)Scheduled Repair Downtime      12    Shop         MS                                1
                                                               Machine
                 532 (M13)Machine Testing Downtime       12    Shop         MS                                1
                                                               Machine
                 533 (M15)Repair Downtime by Leader      12    Shop         MS                                1
                                                               Machine
                 534 Washing Parts                       12    Shop         MS                                1
                                                               Machine
                 535 (M01)Cycle Stop                     12    Shop         MS                                1
                                                               Machine
                 536 (M05)Tool Change & Quality          12    Shop         MS                                1
                     (M06)Broken Tool change & Quality         Machine
                 537 Confirmation                        12    Shop         MS                                1



                                                                  Machine
                 538 (M07)Oper. Moved to other Process      12    Shop         MS                                1
                                                                  Machine
                 539 (M08)Out of Parts from D/C             12    Shop         MS                                1
                                                                  Machine
                 540 (M09)Changing Line Over/Purging Line   12    Shop         MS                                1
                     (M10)Unscheduled Machine Repair By           Machine
                 541 Maint.                                 12    Shop         MS                                1
                                                                  Machine
                 542 (M12)Machine Down For PM               12    Shop         MS                                1
                                                                  Machine
                 543 (M14)Machine Alarm                     12    Shop         MS                                1
                                                                  Machine
                 544 (M16)No Oper Due To Absence            12    Shop         MS                                1
                                                                  Machine
                 545 (M17)Meeting                           12    Shop         MS                                1
                                                                  Machine
                 546 (M18)Maching Shut Down Due To WIP      12    Shop         MS                                1
                                                                  Machine
                 547 (M19)Other                             12    Shop         MS                                1
                                                                  Machine
                 562 Line Full                              12    Shop         MS                                1
                                                                  Machine
                 563 Gauging Parts                          12    Shop         MS                                1
                                                                  Machine
                 564 Transfer                               12    Shop         MS                                1
                                                                  Machine
                 565 OP10 Down                              12    Shop         MS                                0
                                                                  Machine
                 567 OP10-1 Down                            12    Shop         MS                                0
                                                                  Machine
                 568 OP10-2 Down                            12    Shop         MS                                0
                                                                  Machine
                 569 OP10-3 Down                            12    Shop         MS                                0
                                                                  Machine
                 570 OP10-4 Down                            12    Shop         MS                                0
                                                                  Machine
                 571 OP10-5 Down                            12    Shop         MS                                0
                                                                  Machine
                 572 OP10-6 Down                            12    Shop         MS                                0
                                                                  Machine
                 573 OP10-7 Down                            12    Shop         MS                                0
                                                                  Machine
                 574 OP20 Down                              12    Shop         MS                                0
                                                                  Machine
                 575 OP20-1 Down                            12    Shop         MS                                0



                                                      Machine
                 576 OP20-2 Down                12    Shop         MS                                0
                                                      Machine
                 577 OP20-3 Down                12    Shop         MS                                0
                                                      Machine
                 578 OP20/30 Down               12    Shop         MS                                0
                                                      Machine
                 579 OP20/30-1 Down             12    Shop         MS                                0
                                                      Machine
                 580 OP20/30-2 Down             12    Shop         MS                                0
                                                      Machine
                 581 OP30 Down                  12    Shop         MS                                0
                                                      Machine
                 582 OP30-1 Down                12    Shop         MS                                0
                                                      Machine
                 583 OP30-2 Down                12    Shop         MS                                0
                                                      Machine
                 584 OP30-3 Down                12    Shop         MS                                0
                                                      Machine
                 585 Deburr Down                12    Shop         MS                                0
                                                      Machine
                 586 FEC Down                   12    Shop         MS                                0
                                                      Machine
                 587 Face Height Down           12    Shop         MS                                0
                                                      Machine
                 588 OP60 Down                  12    Shop         MS                                0
                                                      Machine
                 589 OP70-1 Down                12    Shop         MS                                0
                                                      Machine
                 590 OP70-2 Down                12    Shop         MS                                0
                                                      Machine
                 591 OP70-A Down                12    Shop         MS                                0
                                                      Machine
                 592 OP70-B Down                12    Shop         MS                                0
                                                      Machine
                 593 Shut down due to weather   12    Shop         MS                                1
                                                      Machine
                 594 Rework                     12    Shop         MS                                0
                                                      Machine
                 595 C-Clip Insert              12    Shop         MS                                0
                                                      Machine
                 596 Lost Motion                12    Shop         MS                                0
                                                      Machine
                 597 Dowel Pin Feed Machine     12    Shop         MS                                0
                                                      Machine
                 598 VCM Ex "A"                 12    Shop         MS                                0



                                                        Machine
                 599 VCM Ex "B"                   12    Shop         MS                                0
                                                        Machine
                 600 VCM "IN"                     12    Shop         MS                                0
                                                        Machine
                 601 VCM "IN" R/A                 12    Shop         MS                                0
                                                        Machine
                 602 Non VCM "IN"                 12    Shop         MS                                0
                                                        Machine
                 603 Non VCM "A" R/A              12    Shop         MS                                0
                                                        Machine
                 604 Non VCM "B" R/A              12    Shop         MS                                0
                                                        Machine
                 605 Non VCM Ex "A"               12    Shop         MS                                0
                                                        Machine
                 606 Non VCM Ex "B"               12    Shop         MS                                0
                                                        Machine
                 607 IN R/S Front                 12    Shop         MS                                0
                                                        Machine
                 608 IN R/S Rear                  12    Shop         MS                                0
                                                        Machine
                 609 IN R/S RKG                   12    Shop         MS                                0
                                                        Machine
                 610 IN Shafts                    12    Shop         MS                                0
                                                        Machine
                 611 Ex Shafts                    12    Shop         MS                                0
                                                        Machine
                 612 EX R/S Front                 12    Shop         MS                                0
                                                        Machine
                 613 EX R/S Rear                  12    Shop         MS                                0
                                                        Machine
                 614 EX R/S RKG                   12    Shop         MS                                0
                                                        Machine
                 615 Mounting Bolt Feed Machine   12    Shop         MS                                0
                                                        Machine
                 616 Bolt Torque Machine          12    Shop         MS                                0
                                                        Machine
                 617 Inspection Unit              12    Shop         MS                                0
                                                        Machine
                 618 #1/#3 OP10/20-1              12    Shop         MS                                0
                                                        Machine
                 619 #1/#3 OP10/20-2              12    Shop         MS                                0
                                                        Machine
                 620 #2 OP10/20-1                 12    Shop         MS                                0
                                                        Machine
                 621 #2 OP10/20-2                 12    Shop         MS                                0



> ⚠️ **SPARK DEPENDENCY** — References SparkMES or Flexware-specific functionality. Blue Ridge must implement an equivalent natively.


                                                                 Machine
                 622 OP21                                  12    Shop         MS                                0
                                                                 Machine
                 623 OP22                                  12    Shop         MS                                0
                                                                 Machine
                 624 OP40-1                                12    Shop         MS                                0
                                                                 Machine
                 625 OP40-2                                12    Shop         MS                                0
                                                                 Machine
                 626 OP40-3                                12    Shop         MS                                0
                                                                 Machine
                 627 OP40-4                                12    Shop         MS                                0
                                                                 Machine
                 628 QA Machine                            12    Shop         MS                                0
                                                                 Machine
                 629 Label Maker                           12    Shop         MS                                0
                                                                 Machine
                 630 Robot                                 12    Shop         MS                                0
                                                                 Machine
                 631 Warm Up Machines                      12    Shop         MS                                1
                                                                 Machine
                 632 No Operator due to Absence            12    Shop         MS                                1
                                                                 Machine
                 633 No Operator due to Sorting In-House   12    Shop         MS                                1
                                                                 Machine
                 634 No Parts to Inspect                   12    Shop         MS                                0
                                                                 Machine
                 635 Misset Problems                       12    Shop         MS                                0
                                                                 Machine
                 636 CMM Confirmation of Change Point      12    Shop         MS                                0
                                                                 Machine
                 637 CMM Confirmation of Changeover        12    Shop         MS                                0
                                                                 Machine
                 638 Transfer (VCM)                        12    Shop         MS                                0
                                                                 Machine
                 639 RKR Arm Load                          12    Shop         MS                                0
                                                                 Machine
                 640 RKR Holder Load                       12    Shop         MS                                0
                                                                 Machine
                 641 Shaft Install                         12    Shop         MS                                0
                                                                 Machine
                 642 Laser Engraver                        12    Shop         MS                                0
                                                                 Machine
                 643 Flexware                              12    Shop         MS                                0
                                                                 Machine
                 644 Waiting on Maintenance                12    Shop         MS                                0


> 📝 **BLUE RIDGE NOTE** — Identify the equivalent capability in your stack before implementing.



                                                         Machine
                 645 OP 10/20-1 #1/#3              12    Shop         MS                                0
                                                         Machine
                 646 OP 10/20-1 #2                 12    Shop         MS                                0
                                                         Machine
                 647 OP 10/20-2 #1/#3              12    Shop         MS                                0
                                                         Machine
                 648 OP 10/20-2 #2                 12    Shop         MS                                0
                                                         Machine
                 649 OP10/20-3 #1/#3               12    Shop         MS                                0
                                                         Machine
                 650 OP10/20-3 #2                  12    Shop         MS                                0
                                                         Machine
                 651 Scheduled Downtime            12    Shop         MS                                0
                                                         Machine
                 652 Washer Awareness              12    Shop         MS                                0
                                                         Machine
                 653 Washer Cutout                 12    Shop         MS                                0
                                                         Machine
                 654 Robot Line #1 (Walle)         12    Shop         MS                                0
                                                         Machine
                 655 Robot Line #2 (Geisha)        12    Shop         MS                                0
                                                         Machine
                 656 Robot Line #3 (Gizmo)         12    Shop         MS                                0
                                                         Machine
                 657 No Die Cast Parts             12    Shop         MS                                0
                                                         Machine
                 658 MS Quality Issues             12    Shop         MS                                0
                                                         Machine
                 659 DC Quality Issues             12    Shop         MS                                0
                                                         Machine
                 660 Waiting on Part for Machine   12    Shop         MS                                0
                                                         Machine
                 661 No Dunnage                    12    Shop         MS                                0
                                                         Machine
                 662 OP50 Down                     12    Shop         MS                                0


