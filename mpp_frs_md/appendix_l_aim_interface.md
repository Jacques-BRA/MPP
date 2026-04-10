# Appendix L — AIM Interface

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.


---


           Appendix L.                             AIM I NT ER FACE
           The following are methods in the AIM interface:



               public static string GetNextNumber(Context context)



               public static void UpdateAim(Context context, string partName, int quantity, string lotName
                                                                       , string serial, string previousSerial = null)



               public static void PlaceOnHold(Context context, string serial)



               public static void ReleaseFromHold(Context context, string serial)



           QA Staff uses a tablet to go to the hold screen to put on and take off hold – a big deal


