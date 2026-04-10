# Appendix A — Current MES-Initial Architecture

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.


---


           Appendix A.                           C URREN T MES-I N IT IAL A RC HITE CTURE



           Casting (A)



                            Task                                         Operation
                              1        Cognex In-Sight sensor acquires image of barcode.
                                       Logic in In-Sight sensor (job file) verifies condition of barcode and assigns a
                              2
                                       part state. Decode Error = a state of 0, Successful Decode = a state of 1
                                       Data Ready bit is turned on in In-Sight sensor to let MES know there is a new
                              3
                                       part.
                              4        MD creates and completes part at the casting operation.
                                       Vorne Display Boards: displays updated production data based on discrete
                              5
                                       signals from the Casting control panel.



           Machining (B)



                            Task                                         Operation
                                       Cognex DataMan ID Reader decodes serial number from the 2D Data Matrix
                              1
                                       bar code and sends to the Mitsubishi PLC.
                              2        Mitsubishi PLC stores part serial number data.
                                       Data Ready is set in the Mitsubishi PLC upon receiving the part serial
                              3
                                       number.



                                                 Data Ready triggers MD:
                                                    MD checks if the part exists, if not then the part is created and it
                                            is recorded that the part was started and completed at the operation.
                                            If the part exists then MD checks the Part Interlock logic set for this
                                            part:
                                                     o Part must have a valid SN format
                                                     o Overall Disposition of the part must Good and must not be
                                                         Scrap or Suspect



                              4             Note: The part could have a Casting Part Status of Invalid but this would
                                            not produce a part Invalid at this operation if the overall part disposition is
                                                  Good.
                                                  If the interlock logic determines the part status is Invalid the HMI
                                            displays “Bad Part”. This part is not to be run through the process but
                                                  placed in a tote for supervision to review.
                                                  If the interlock logic determines the part status is Valid the HMI will
                                            display “Good Part” and the part is to be placed on the in-feed conveyor.
                                                MD will also record that the part was started and completed at the
                                            machining operation upon a part status of Valid.
                                        Vorne Display Boards: displays updated production data based on discrete
                              5
                                        signals from the OP40 machines at each line.



           Assembly In – Line 2 Cir-Clip Assembly (C)



                           Task                                             Operation
                                       Cognex DataMan ID Reader decodes serial number from the 2D Data Matrix
                              1
                                       bar code and sends to the Mitsubishi PLC.
                              2        Mitsubishi PLC stores part serial number data.
                                        Data Ready is set in the Mitsubishi PLC upon receiving the part serial
                              3
                                        number.



                                       Data Ready triggers MD:
                                               MD checks if the part exists, if not then the part is created and it is
                                               recorded that the part was started and completed at the operation. If
                                               the part exists then MD checks the Part Interlock logic set for this
                                               part:
                                                 o Part must have a valid SN format
                                                 o Overall Disposition of the part must Good and must not be
                                                       Scrap or Suspect
                                                       Note: The part could have a Part Status of Invalid relating to a
                                                       previous operation (Casting or Machining) but this would not
                              4
                                                       produce a part Invalid if the overall disposition of the part is
                                                       Good.
                                               If the interlock logic determines the part status is Invalid the HMI
                                               displays “MES ERROR”. This part is not to be run through the
                                               process but placed in a tote for supervision to review.
                                               If the interlock logic determines the part status is Valid the HMI will
                                               display “PART VALID” and the part will be allowed to run into the
                                               process.
                                               MD will also record that the part was started and completed at the
                                               machining operation upon a part status of Valid.



           Assembly In – Line 1 Cir-Clip Assembly (C)



                            Task                                          Operation
                                       Cognex DataMan ID Reader decodes serial number from the 2D Data Matrix
                              1
                                       bar code and sends to the Mitsubishi PLC.
                              2        Mitsubishi PLC stores part serial number data.
                                       Data Ready is set in the Mitsubishi PLC upon receiving the part serial
                              3
                                       number.



                                       Data Ready triggers MD:
                                               MD checks if the part exists, if not then the part is created and it is
                                               recorded that the part was started and completed at the operation. If
                                               the part exists, then MD checks the Part Interlock logic set for this
                                               part:
                                                   o Part must have a valid SN format
                                                   o Overall Disposition of the part must be “Good” and must not
                                                        be “Scrap” or “Suspect”



                              4                        Note: The part could have a Part Status of Invalid relating to a
                                                       previous operation (Casting or Machining) but this would not
                                                       produce a part Invalid if the overall disposition of the part is
                                                       Good.
                                               If Cir-Clip machine process produces a clip insert error then the part
                                               status of the Cir-Clip operation is set to Invalid.
                                               If the interlock logic determines that the part status is Invalid the part
                                               is to be placed in a tote for supervision to review.
                                               If the interlock logic determines the part status is Valid the part is to
                                               be queued for the next operation.



                                        MD will also record that the part was started and completed at the
                                         machining operation upon a part status of Valid.



           Assembly In – Line 1 Lost Motion (C)



                            Task                                          Operation
                                       Cognex DataMan ID Reader decodes serial number from the 2D Data Matrix
                              1
                                       bar code and sends to the Mitsubishi PLC.
                              2        Mitsubishi PLC stores part serial number data.
                                       Data Ready is set in the Mitsubishi PLC upon receiving the part serial
                              3
                                       number.



                                       Data Ready triggers MD:
                                        • The following MD interlock logic is checked at this station:
                                                  o The part must have been successfully processed at Cir-Clip,
                                                      Cir-Clip part status must be Valid.
                                                  o Overall Disposition of the part must be “Good” and must not
                                                      be “Scrap” or “Suspect”
                                           Note: The part could have a Part Status of Invalid relating to a previous
                              4            operation (Casting or Machining) but this would not produce a part
                                           Invalid if the overall disposition of the part is Good.
                                                If the interlock logic determines that the part status is Invalid the
                                                part is to be placed in a tote for supervision to review.
                                               If the interlock logic determines the part status is Valid the part will
                                          be accepted into the assembly line for processing.
                                         • MD will also record that the part was started and completed at this
                                            operation upon a part status of Valid.



           Assembly Out (Line 1/2) (D)



                            Task                                          Operation
                                       Cognex In-Sight Sensor decodes serial number from the 2D Data Matrix bar
                              1
                                       code and sends to the Mitsubishi PLC.
                              2        Mitsubishi PLC stores part serial number data.
                              3        Part Start is set in the Mitsubishi PLC upon receiving the part serial number.
                                                Part Start triggers MD:
                                                MD checks if the part exists, if not then the part is created and it is
                                                recorded that the part was started this operation.
                                                   The following MD interlock logic is checked at this station:
                                                   o Part must have a valid SN format
                              4                    o Overall Disposition of the part must be “Good” and must not
                                                      be “Scrap” or “Suspect”
                                           Note: The part could have a Part Status of Invalid relating to a previous
                                           operation (Casting or Machining) but this would not produce a part
                                           Invalid if the overall disposition of the part is Good.
                                                If the interlock logic determines that the part status is Invalid the
                                           machine will not process the part and the operator is to remove the part
                                                from the system and placed in a tote for supervision to review. If
                                                the interlock logic determines the part status is Valid the part will be
                                           accepted into machine for processing.



                                                Data Ready triggers MD:
                                                MD checks the status of this Part Status bit in the PLC to
                                                determineif the part is a good part.
                                                 If the Part Status bit is off this means it is a bad part and the Part
                               5           Status is Invalid and the machine is interlocked and the operator is to
                                                 remove the part and place it in a tote for supervision review. If the
                                                 Part Status bit is on this means it is a good part and the Part Status
                                           is Valid. MD will record the completion of the part processing and the
                                           machine will place the part on the out-feed conveyor by the machine.
                               5       Vorne Display displays updated production data.



           Cognex In-Sight OPC Server (E)



                            Task                                          Operation
                              1        Data is received from In-Sight Sensors in Casting Lines 1 and 2.
                              2        Data is sent to MD.
                              3        Transaction status data is received by MD.
                              4        Transaction status data is sent to Casting Lines 1 and 2.



           Mitsubishi OPC Server (F)



                            Task                                          Operation
                              1        Data is received from PLCs in Machining Lines and Assembly Lines
                              2        Data is sent to MD.
                              3        Transaction status data is received by MD.
                                       Transaction status data is sent to PLCs in Machining Lines and Assembly
                              4
                                       Lines



           Manufacturing Director Terminals (G)



                            Task                                          Operation
                              1        MES data is retrieved from the MD database.
                              2        MES data is displayed to the Operator.



                              3        Operators can track and modify parts and containers.



           Assembly Printers (H)



                           Step #                                           Task
                                       MD populates the label with MES data and sends label to the printer in ZPL
                              1
                                       format.
                                       Zebra Label Printer prints the container labels for completed containers in
                               2
                                       Assembly Out lines 1 and 2.



           Assembly Raw Material Scanner (I)



                           Step #                                           Task
                              1        Data is scanned from container labels.
                              2        Data is sent to MD.
                              3        MES data is received from MD.



           Original Network Interconnect Diagram


