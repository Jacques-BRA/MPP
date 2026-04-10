# Automation Touch Point Agreement
**Document:** 2011230 5GO_AP4 Automation Touchpoint Agreement  
**Project:** VCM Traceability System  
**Author/Firm:** Flexware Innovation, Inc. — 9128 Technology Ln., Indianapolis, IN 46038  
**Last Saved:** 4/13/2012 3:43:00 PM  
**Classification:** Confidential — Property of Flexware Innovation, Inc.

---

## 1.0 Touch Point Design

The automation touch point definition details the automation transaction points at each operation where data will be collected relating to part production.

---

## 1.1 Standard MES Production Station Automation Touch Points

The following table defines the standard Manufacturing Director™ Automation Touch Points.

| Touch Point Name | MES Read/Write | Data Type | Description |
|---|---|---|---|
| **DataReady** | Read/Write | Bool | **Data Ready Trigger** — Set by automation when process data is ready; typically when a part is complete at an operation. Reset by MES on start of transaction. |
| **TransInProc** | Read/Write | Bool | **Transaction In Process** — Set by MES on start of transaction. Reset by MES on completion of transaction. |
| **PartSN** | Read | String | Serial Number is set in automation and is to be collected by MES upon DataRdy. |
| **PartStatus01** | Read | Bool | Part Status is set in automation and is to be collected by MES upon DataRdy. Determines if the part/feature is a Pass (True) or Fail (False). Failed parts are not added to a container and are to be scrapped or reworked. **Not a required field — applicable by station.** |
| **HardwareInterlockEnable** | Read | Bool | **Hardware Interlock Enable** — Set in the MES Interface or in the MIP (Machine Interface Panel). Enables or disables the MES checks executed at the automation level (e.g., quality checks, serial number processing). MES may still be able to process parts if the Hardware Interlock is disabled. |
| **MESInterlockEnable** | Read/Write | Bool | **MES Interlock Enable** — Set in the MES Interface. Enables or disables the MES checks (e.g., duplicate serial number, serial number format validation) executed at the MES software level. MES will not record any information if the MES Interlock is Disabled. |
| **PartValid** | Write | Bool | **MES Station Validation** — Indicates that all rules and logic defined for the station have passed and the part is valid to continue through the process. MES sets this True when validation is passed. Required for the part to continue the process. |
| **WatchDog** | Read/Write | Bool | Provides indication between automation and MES that device connections are present and ready for machine integration. |
| **AudibleAlertEnable** | Read/Write | Bool | **MES Audible Alert Enable** — Set at the MIP HMI or in the MES Interface. Enables or disables the Audible Alert on the MIP in the event a part fails validation (MESStnInvalid) or a quality check. |
| **ContainerCount** | Write | Integer | Part Count in the current Container. |
| **ReqContainerCount** | Read | Bool | Request container count at MIP to MES. |
| **PartDisp** | Write | String | Status of the part. |
| **PartType** | Write | String | Part Type being run at station. |
| **AlarmMsg** | Write | String | Alarm from MES Transaction. |

---

## 1.2 MES Production Station — Automation Touch Point Map

The following table identifies which touch points apply to each production station.

| Touch Point Name | 5GO - Assembly Fronts | 5GO - Assembly Rears | PNA - Assembly Out CH IN/EX 5,6 FP | PNA - Assembly Out 1 RH 1-4 CH IN/EX 1-4 |
|---|---|---|---|---|
| DataReady | Yes | Yes | Yes | Yes |
| TransInProc | Yes | Yes | Yes | Yes |
| PartSN | Yes | Yes | No | No |
| PartStatus01 | No | No | No | No |
| HardwareInterlockEnable | Yes | Yes | Yes | Yes |
| MESInterlockEnable | Yes | Yes | Yes | Yes |
| PartValid | Yes | Yes | Yes | Yes |
| WatchDog | Yes | Yes | Yes | Yes |
| AudibleAlertEnable | Yes | Yes | Yes | Yes |
| ContainerCount | Yes | Yes | Yes | Yes |
| ReqContainerCount | Yes | Yes | Yes | Yes |
| PartDisp | No | No | No | No |
| PartType | Yes | Yes | Yes | Yes |
| AlarmMsg | Yes | Yes | Yes | Yes |

---

## 1.3 Machine Integration to MES

Machine integration to the MES is accomplished with an intermediate **Machine Integration Panel (MIP)** between the machine automation and the MES. The MIP allows for minimal changes to be made to the machine automation hardware and logic for the MES interaction required.

### Architecture Overview (Text Representation)

```
┌─────────────────────────────────────────────────────────┐
│                          MES                            │
│                   Execution Management                  │
│   5GO Production Server ──── TopServer / ModBus TCP     │
└───────────────────────┬─────────────────────────────────┘
                        │  Machine Integration Touch Points
                        │  via ModBus TCP (OPC)
                        │
          ┌─────────────┴──────────────┐
          │   Machine Integration Panel │
          │  (MIP HMI + Serial Comms)  │
          └─────────────┬──────────────┘
                        │
          ┌─────────────┴──────────────┐
          │      Assembly Machine       │
          │  (PLC Input/Output + CR)   │
          └─────────────┬──────────────┘
                        │
                   Laser Marker
```

**Touch points communicated via ModBus TCP (OPC):**
- MESInterlockEnable
- HardwareInterlockEnable (Status To MES)
- PartSN
- DataReady (= New SN and Part Complete)
- TransInProc
- PartValid
- WatchDog
- AudibleAlertEnable
- ContainerCount
- ReqContainerCount
- AlarmMsg
- PartType

**PLC → MIP signals:**
- Part Complete (CR output)
- MES Reset (CR input)

**MIP → Laser Marker:**
- Serial Number (serial comms)

---

## 1.4 5GO — Part Complete Automation > MES Flow Diagram

Transaction type: **Serial Number (Serialized Data Tracking)**  
Swim lanes: Field Automation (PLC) | Machine Integration Panel | Execution Management™ / MES

### Flow Description

```
[PLC] Part Complete at Assembly Station
  └─► [MIP] PartComplete signal set
        └─► Check: MESInterlockEnable?
              ├─ No ──► [PLC] Not PartCompleteReset → PartComplete Set Output
              └─ Yes ──► Check: HardwareInterlockEnable?
                            ├─ No ──► Set PartSN with "NoRead"
                            └─ Yes ──► Read PartSN from Laser Marker (Serial Comms)
                                          └─► PartSN New and Valid Format?
                                                ├─ No ──► Set PartSN with "NoRead"
                                                └─ Yes ──► [MIP] Set DataReady

[MES] DataReady received
  └─► - Reset DataReady
      - Set TransInProc
      - Read PartSN
      - Read HardwareInterlockEnable
        └─► PartSN Validation
              ├─ Fail ──► MES Alarms:
              │             - Low Inventory Level
              │             - Invalid PartSN
              │             - Duplicate PartSN
              │             - (others TBD)
              └─ Pass ──► Inventory > 0?
                            ├─ No ──► - Reset TransInProc
                            │         - Set AlarmMsg
                            └─ Yes ──► Open Container Exists?
                                          ├─ No ──► - Create New Container
                                          │          - Get ID from Base2
                                          │          - Associate PartSN to New Container
                                          └─ Yes ──► Add Part Count to Container
                                                        └─► Last Part In Container?
                                                              └─ Yes ──► Close Container
                                                                          Transaction with Base2
                                                                            └─► Print Label
                                                        └─► - Reset TransInProc
                                                            - Set PartValid
                                                            - Write ContainerCount
                                                            - Write PartType

[MIP] NOT TransInProc & PartValid?
  └─ Yes ──► [PLC] Reset PartComplete
              └─► Set PartCompleteReset
                    └─► [MIP] NOT TransInProc & NOT PartValid?
                          └─ Yes ──► Display AlarmMsg on MIP screen
                                      └─► AudibleAlertEnable?
                                            └─ Yes ──► Sound Alarm Horn
                                                        Display MES Alarm on MIP screen
                                                          └─► Operator Ack Alarm
                                                                └─► Set PartCompleteReset for 5 sec
                                                                    then Reset PartCompleteReset
                                                                    & PartValid
```

---

## 1.5 PNA — Part Complete Automation > MES Flow Diagram

Transaction type: **Lot Tracking (no serial number)**  
Swim lanes: Field Automation (PLC) | Machine Integration Panel | Execution Management™ / MES

> Note: This flow is simplified compared to 5GO — no PartSN, no Laser Marker serial comms, no HardwareInterlockEnable branch. DataReady is set directly by MIP on PartComplete.

### Flow Description

```
[PLC] Part Complete at Assembly Station
  └─► [MIP] PartComplete signal set
        └─► Check: MESInterlockEnable?
              ├─ No ──► [PLC] Not PartCompleteReset → PartComplete Set Output
              └─ Yes ──► [MIP] Set DataReady

[MES] DataReady received
  └─► - Reset DataReady
      - Set TransInProc
        └─► Inventory > 0?
              ├─ No ──► - Reset TransInProc
              │          - Set AlarmMsg
              └─ Yes ──► Open Container Exists?
                            ├─ No ──► - Create New Container
                            │          - Get ID from Base2
                            └─ Yes ──► Add Part Count to Container
                                          └─► Last Part In Container?
                                                └─ Yes ──► Close Container
                                                            Transaction with Base2
                                                              └─► Print Label
                                                    └─► - Reset TransInProc
                                                        - Set PartValid
                                                        - Write ContainerCount
                                                        - Write PartType

[MIP] NOT TransInProc & PartValid?
  └─ Yes ──► [PLC] Reset PartComplete
              └─► Set PartCompleteReset (5 sec) then Reset & PartValid

[MIP] NOT TransInProc & NOT PartValid?
  └─ Yes ──► Display MES Alarm on MIP screen
              └─► MESAudibleAlertEnable?
                    └─ Yes ──► Sound Alarm Horn
                                Display MES Alarm on MIP screen
                                  └─► Operator Ack Alarm
                                        └─► Set PartCompleteReset for 5 sec
                                            then Reset PartCompleteReset & PartValid

MES Alarms (PNA):
  - Low Inventory Level
  - (others TBD)
```

---

## 1.6 WatchDog Timer — Device Error Checking

Defines the interaction between the Machine Integration Panel and MES for WatchDog handshaking.

```
[MIP] WatchDog Timer Done
  └─► Set WatchDog Tag True

[MES] Read WatchDog Tag
  └─► WatchDog True?
        ├─ True ──► Reset WatchDog Tag
        └─ (WatchDog Logic Fail) ──► Log, Notification
```

**Purpose:** Confirms that device connections between MIP and MES are present and active. Failure triggers a logged notification.

---

## 1.7 Container Count Request

Defines the interaction between the Machine Integration Panel and MES for requesting the current container count.

```
[MIP] Request Container Count Pushbutton pressed
  └─► Set ReqContainerCount

[MES] Read ReqContainerCount Tag
  └─► ReqContainerCount = Yes?
        └─ Yes ──► Get Container Count — Return to Execution Management
                    └─► Send ContainerCount to MIP

[MIP] Display ContainerCount
```

**Purpose:** Allows operators at the MIP to request and display the current container part count on demand without initiating a full MES transaction.

---

## Appendix: Key Terms & Acronyms

| Term | Definition |
|---|---|
| MES | Manufacturing Execution System |
| MIP | Machine Integration Panel — intermediate hardware panel between machine PLC and MES |
| EM / Execution Management™ | Flexware's MES execution layer (Manufacturing Director™) |
| TopServer | OPC server product used for ModBus TCP communication |
| ModBus TCP | Industrial communication protocol used for touch point data exchange |
| OPC | OLE for Process Control — standard for industrial data exchange |
| DataReady | Handshake bit set by automation to signal process data is available |
| TransInProc | Handshake bit set by MES to indicate a transaction is in progress |
| PartSN | Part Serial Number string read from automation/laser marker |
| PartValid | MES output bit confirming part passed all station validation rules |
| WatchDog | Heartbeat mechanism to confirm live MES-to-device connectivity |
| CR | Control Relay — used for PLC discrete signal handshake |
| Base2 | External system used for container ID management and label printing |
| PNA | Production station designation (lot-tracked, no serial number) |
| 5GO | Production station designation (serialized, uses laser marker) |
| VCM | Vehicle Component Manufacturing (project context) |
