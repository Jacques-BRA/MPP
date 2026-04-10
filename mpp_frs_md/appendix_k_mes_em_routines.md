# Appendix K — MES EM Core Routines

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.



> ⚠️ **SPARK SECTION — HIGH DEPENDENCY**  

> This entire section describes Flexware's SparkMES framework. Blue Ridge does not have access to this framework.  

> Use this section to understand the **intended architecture and capability** only.  

> Every subsection will require a Blue Ridge-native design decision.


---


           Appendix K.                   MES EM C ORE R OUTIN ES



           Container
                    GetContainerQuantity(string containerName)
                    GetContainerMaterial(string containerName)
                    GetInProcessContainer(string siteName, string areaName, string productionLineName, string workCellName)



           LOT
                    ProcessContainerAtEndOfLine(string siteName, string areaName, string productionLineName, string workCellName)
                    ProcessTrayLocked(string siteName, string areaName, string productionLineName, string workCellName)
                    ProcessTrayLockedForMaterial(string siteName, string areaName, string productionLineName, string workCellName, string
                     materialName)
                    ProcessTrayInspectionComplete(string siteName, string areaName, string productionLineName, string workCellName, int
                     disposition)
                    ProcessTrayInspectionCompleteForMaterial(string siteName, string areaName, string productionLineName, string
                     workCellName, string materialName, int disposition)
                    ProcessLotAtEndOfLine(string siteName, string areaName, string productionLineName, string workCellName)



           Serialized Item
                    CompleteSerializedContainer(string siteName, string areaName, string productionLineName, string workCellName)
                    ProcessSerializedItemAtEndOfLine(string siteName, string areaName, string productionLineName, string workCellName,
                     string serializedItemName, bool autoCompleteContainer = true)



           Sort
                    GetInProcessContainerSortRecipe(string siteName, string areaName, string productionLineName, string workCellName)
                    ProcessSortSetAdd(string siteName, string areaName, string productionLineName, string workCellName)



           Work Order
                    GetActiveWorkOrderMaterialName(string siteName, string areaName, string productionLineName, string workCellName)
                    GetActiveWorkOrderMaterialName(string siteName, string areaName, string productionLineName, string workCellName, int
                     materialID)


