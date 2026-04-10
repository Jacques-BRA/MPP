# Appendix J — MES Base2 Core Routines

> **Source:** Madison Precision Products MES — Functional Requirement Specification (Flexware, v1.0, 3/15/2024)  

> **Status:** Reference document — Blue Ridge Automation does not have access to the SparkMES framework.



> ⚠️ **SPARK SECTION — HIGH DEPENDENCY**  

> This entire section describes Flexware's SparkMES framework. Blue Ridge does not have access to this framework.  

> Use this section to understand the **intended architecture and capability** only.  

> Every subsection will require a Blue Ridge-native design decision.


---


           Appendix J.                     MES B A SE 2 C OR E R OU TIN ES
           BASE2 CORE Functions
           Note CONTEXT Structure includes:



                            context.MachineName,
                     context.Source,
                     context.User,
                     context.Host,
                     context.HostWithoutPort



           GetDefaultReturnableDunnageCode(Context context, string materialName, string customer)
           SQL =



                     SELECT CAST(LTRIM(RTRIM(SFIELD17)) AS nvarchar) AS SFIELD17
                     FROM LblParts
                     WHERE REPLACE(REPLACE(LTRIM(RTRIM(SPARTNBR)), '-', ''), ' ', '')
                            = REPLACE(REPLACE(LTRIM(RTRIM(@MaterialName)), '-', ''), ' ', '') AND LTRIM(RTRIM(STRADINGPARTNER)) = @Customer";
           Returns



                     returnableDunnageCode = dataSet.Tables[0].Rows[0]["SFIELD17"].ToString();



           CustomerEnumForMaterial(Context context, string materialName)



           SQL =
                     SELECT DISTINCT CAST(LTRIM(RTRIM(STRADINGPARTNER)) AS nvarchar) AS STRADINGPARTNER
                     FROM LblParts WHERE REPLACE(REPLACE(LTRIM(RTRIM(SPARTNBR)), '-', ''), ' ', '')
                                    = REPLACE(REPLACE(LTRIM(RTRIM(@MaterialName)), '-', ''), ' ', '')
                     ORDER BY CAST(LTRIM(RTRIM(STRADINGPARTNER)) AS nvarchar)";



           Returns
                 foreach (DataRow dataRow in dataSet.Tables[0].Rows)
                   customers.Add(dataRow["STRADINGPARTNER"].ToString());



                   return customers;



           GetNextNumber(Context context)
           SQL =
                   UPDATE numberstorage
                   SET inumber = inumber + 1
                   OUTPUT Inserted.inumber
                   WHERE snumberkey = 'LastSerial'";
           Returns



                   containerNumber = string.Format("{0:D8}", dataSet.Tables[0].Rows[0]["inumber"]);



           PerformPartQuantityLotSerialScan(Context context, string partName, int quantity, string lotName, string serial)



           Reads a file that contains serial numbers for Parts (PartName) associated with a LOT (LotName)
            Find Directory for File to upload from configuration data
                   filePathConfigurationValue = new ConfigurationValue(context, "Base2ContainerDetailsFilePath");
                   filePath = filePathConfigurationValue.Value;



                   // If the file already exists, append to it; otherwise, create and fill it



                   try
                   {
                     StreamWriter streamWriter = File.AppendText(filePath);



                       streamWriter.WriteLine(
                         "{0},{1},{2},{3}",
                         string.Format("1S13218001{0}", serial), // Format as Honda supplier serial
                         partName.Replace("-", ""),       // Remove dashes
                         quantity,
                         lotName);



                       streamWriter.Flush();
                       streamWriter.Close();
                   }



           Macola Support Functions
           //This checks if the Account Number/Cost Center exists in the database
           public static bool AcctLookup(Context context, string acctNo, string costCenter)
               {
                 bool foundMatch = false;
                 Database database = context.Database;



                   SqlCommand sqlCommand = new SqlCommand();
                   sqlCommand.CommandType = CommandType.StoredProcedure;
                   sqlCommand.CommandText = "mro.spSYACTFIL_SQL_EnumByMnSb";



                    Database.AddSqlParameter(sqlCommand, "@mn_no", SqlDbType.Char, ParameterDirection.Input, acctNo);
                    Database.AddSqlParameter(sqlCommand, "@sb_no", SqlDbType.Char, ParameterDirection.Input, costCenter);



                    DataSet dataSet = database.ExecuteQuery(sqlCommand);
                    if(dataSet!=null && dataSet.Tables[0].Rows.Count > 0)
                    {
                      foundMatch = true;
                    }
                    return foundMatch;
                }



           // This Routine checks if the Job Number exists in in the database.



                public static bool JobLookup(Context context, string jobNo)
                {
                  bool foundMatch = false;
                  Database database = context.Database;



                    SqlCommand sqlCommand = new SqlCommand();
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.CommandText = "mro.spPOLINHST_SQL_EnumByJobNo";



                    Database.AddSqlParameter(sqlCommand, "@job_no", SqlDbType.Char, ParameterDirection.Input, jobNo);



                    DataSet dataSet = database.ExecuteQuery(sqlCommand);
                    if (dataSet != null && dataSet.Tables[0].Rows.Count > 0)
                    {
                      foundMatch = true;
                    }
                    return foundMatch;



           // This routine returns the next Doc Number from Macola for the current context
           public static string NextDocNoLookup(Context context)
               {
                 string nextDocNo = null;
                 Database database = context.Database;



                    SqlCommand sqlCommand = new SqlCommand();
                    sqlCommand.CommandType = CommandType.StoredProcedure;



                   sqlCommand.CommandText = "mro.spIMCTLFIL_SQL_Enum";



                   DataSet dataSet = database.ExecuteQuery(sqlCommand);
                   if (dataSet != null && dataSet.Tables[0].Rows.Count > 0)
                   {
                     nextDocNo = dataSet.Tables[0].Rows[0]["next_doc_no"].ToString();
                   }
                   return nextDocNo;



           // initialize Macola Order/inventory state interface
           Data row fields are :
                      _macolaNumber = "item_no"
                      _vendorItemNumber = "vend_item_no”
                      _macolaDescription = "search_desc”
                      _location = "loc”
                      _quantity = i.ToString()
                      _stdCost = "std_cost”
                      _pickingSequence = "picking_seq”
                      _offsetMnNo = "mn_no”
                      _offsetSbNo = "sb_no”
                      _note_1 = "note_1”
                      _note_2 = "note_2”
                      _note_3 = "note_3”
                      _note_4 = "note_4”
                      _note_5 = "note_5”
                      _orderUpToLevel = "ord_up_to_lvl”



           Private void Initialize(DataRow dataRow)
               {
                 if (dataRow != null)
                 {
                   _macolaNumber = dataRow["item_no"].ToString();
                   _vendorItemNumber = dataRow["vend_item_no"].ToString();
                   _macolaDescription = dataRow["search_desc"].ToString();
                   _location = dataRow["loc"].ToString();
                   decimal d = 0;



                      int i = 0;
                      try
                      {
                        d = Decimal.Parse(dataRow["qty_on_hand"].ToString());
                        i = Convert.ToInt32(d);
                        _quantity = i.ToString();
                      }
                      catch
                      {
                        _quantity = "0";
                      }
                      _stdCost = dataRow["std_cost"].ToString();
                      _pickingSequence = dataRow["picking_seq"].ToString();
                      _offsetMnNo = dataRow["mn_no"].ToString();
                      _offsetSbNo = dataRow["sb_no"].ToString();
                      _note_1 = dataRow["note_1"].ToString();
                      _note_2 = dataRow["note_2"].ToString();
                      _note_3 = dataRow["note_3"].ToString();
                      _note_4 = dataRow["note_4"].ToString();
                      _note_5 = dataRow["note_5"].ToString();
                      if(!String.IsNullOrEmpty(_location) && _location == "MRO")
                      {
                        _orderUpToLevel = dataRow["ord_up_to_lvl"].ToString();
                        int index = _orderUpToLevel.IndexOf('.');
                        if (index > -1)
                        {
                           _orderUpToLevel = _orderUpToLevel.Substring(0, index);
                        }
                      }
                      else
                      {
                        _orderUpToLevel = String.Empty;
                      }



                   }
                   else
                   {
                     _vendorItemNumber = null;
                     _macolaNumber = null;
                     _macolaDescription = null;



                        _location = null;
                        _quantity = null;
                        _stdCost = null;
                        _pickingSequence = null;
                        _offsetMnNo = null;
                        _offsetSbNo = null;
                        _note_1 = null;
                        _note_2 = null;
                        _note_3 = null;
                        _note_4 = null;
                        _note_5 = null;
                        _orderUpToLevel = null;
                    }
                }



           // this returns Macola Item data based on the supplied Search Text



                public static List<MacolaItem> GetSearchResults(Context context, string searchText)
                {
                  #region Retrieve data from the database



                    Database database = context.Database;



                    SqlCommand sqlCommand = new SqlCommand();
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.CommandText = "mro.spIMITMIDX_SQL_EnumBySearch";



                    Database.AddSqlParameter(sqlCommand, "@SearchString", SqlDbType.Char, ParameterDirection.Input, searchText);



                    DataSet dataSet = database.ExecuteQuery(sqlCommand);



                    #endregion Retrieve data from the database



                    List <MacolaItem> macolaItems = new List<MacolaItem>();



                    foreach (DataRow dataRow in dataSet.Tables[0].Rows)
                    {
                      macolaItems.Add(new MacolaItem(context, dataRow));
                    }



                    return macolaItems;
                }



           // this routine uses mro.spIMTRXDST_SQL_Insert to insert an Issue Transaction to Macola



               public static bool IssueTransaction(Context context, string itemNo, string nextDocNo, string offsetMnNo, string
           offsetSbNo, string stdCost, string quantity, string acct, string costCenter, string user, string jobNo, int issueDate,
           string customer, string type)
               {
                 Database database = context.Database;



                    SqlCommand sqlCommand = new SqlCommand();
                    sqlCommand.CommandType = CommandType.StoredProcedure;



                    sqlCommand.CommandText = "mro.spIMTRXDST_SQL_Insert";



                    Database.AddSqlParameter(sqlCommand, "@item_no", SqlDbType.Char, ParameterDirection.Input, itemNo);
                    Database.AddSqlParameter(sqlCommand, "@doc_no", SqlDbType.Char, ParameterDirection.Input, nextDocNo);
                    Database.AddSqlParameter(sqlCommand, "@item_filler", SqlDbType.Char, ParameterDirection.Input, "");
                    Database.AddSqlParameter(sqlCommand, "@doc_dt", SqlDbType.Int, ParameterDirection.Input, issueDate); //date as a
           number
                 Database.AddSqlParameter(sqlCommand, "@seq_no", SqlDbType.SmallInt, ParameterDirection.Input, 1);
                 Database.AddSqlParameter(sqlCommand, "@mn_no", SqlDbType.Char, ParameterDirection.Input, acct); //acct number entered
           and validated with spSYACTFIL_SQL_EnumByMnSb
                 Database.AddSqlParameter(sqlCommand, "@sb_no", SqlDbType.Char, ParameterDirection.Input, costCenter); //this is the
           cost center they enter, validated with spSYACTFIL_SQL_EnumByMnSb
                 Database.AddSqlParameter(sqlCommand, "@dp_no", SqlDbType.Char, ParameterDirection.Input, "00000000");// not sure yet,
           maybe all zeros?



                 Database.AddSqlParameter(sqlCommand, "@pkg_id", SqlDbType.Char, ParameterDirection.Input, "IM");
                 Database.AddSqlParameter(sqlCommand, "@jnl_src", SqlDbType.Char, ParameterDirection.Input, null);
                 Database.AddSqlParameter(sqlCommand, "@job_no", SqlDbType.Char, ParameterDirection.Input, jobNo);
                 Database.AddSqlParameter(sqlCommand, "@offset_mn_no", SqlDbType.Char, ParameterDirection.Input, offsetMnNo); //on the
           screen, this seems to be the asset acct, which is another call to syactfil with offset_mn_no supplied as the mn_no in that
           table
                 Database.AddSqlParameter(sqlCommand, "@offset_sb_no", SqlDbType.Char, ParameterDirection.Input, offsetSbNo); //goes
           with offset_mn_no, and should be the sb_no cooresponding with it
                 Database.AddSqlParameter(sqlCommand, "@offset_dp_no", SqlDbType.Char, ParameterDirection.Input, "00000000"); //not
           sure yet, maybe all zeros?



                 Database.AddSqlParameter(sqlCommand, "@dist_amt", SqlDbType.Decimal, ParameterDirection.Input,
           Decimal.Parse(stdCost)); //IMINVLOC_SQL.? Where loc='MRO'
                 Database.AddSqlParameter(sqlCommand, "@dist_qty", SqlDbType.Decimal, ParameterDirection.Input,
           Decimal.Parse(quantity)); //inventory.std_cost
                 Database.AddSqlParameter(sqlCommand, "@reference", SqlDbType.Char, ParameterDirection.Input, null);
                 Database.AddSqlParameter(sqlCommand, "@filler_0002", SqlDbType.Char, ParameterDirection.Input, null);
                 Database.AddSqlParameter(sqlCommand, "@customer", SqlDbType.NVarChar, ParameterDirection.Input, customer);
                 Database.AddSqlParameter(sqlCommand, "@type", SqlDbType.Char, ParameterDirection.Input, type);



                    DataSet dataSet = database.ExecuteQuery(sqlCommand);



                    bool success = false;



                    if (dataSet !=null && dataSet.Tables[0].Rows.Count > 0)
                    {
                      // Insert success
                      success = true;
                    }



                    return success;
                }




## OFFLINE TRANSACTIONS


           It appears that transaction can be posted into local storage and then moved to Macola later
           The routine mro.spflx_IMTRXDST_SQL_Insert is used to save the data


