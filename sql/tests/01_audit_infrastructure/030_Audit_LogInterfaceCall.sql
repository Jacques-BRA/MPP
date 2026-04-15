-- Tests for Audit.Audit_LogInterfaceCall
EXEC test.BeginTestFile @FileName = N'01_audit_infrastructure/030_Audit_LogInterfaceCall.sql';
GO

DECLARE @MaxIdBefore1 BIGINT = ISNULL((SELECT MAX(Id) FROM Audit.InterfaceLog), 0);
DECLARE @Req1 NVARCHAR(MAX) = N'{"ShipId":"SHP-001","Parts":["A100","A101"]}';
DECLARE @Res1 NVARCHAR(MAX) = N'{"AckCode":"200","Message":"Accepted"}';

EXEC Audit.Audit_LogInterfaceCall @SystemName = N'AIM', @Direction = N'Out', @LogEventTypeCode = N'InterfaceCall',
    @Description = N'Test: high fidelity', @RequestPayload = @Req1, @ResponsePayload = @Res1, @IsHighFidelity = 1;

DECLARE @ResultId1 BIGINT = (SELECT MAX(Id) FROM Audit.InterfaceLog WHERE Id > @MaxIdBefore1);
DECLARE @Sys1 NVARCHAR(50), @Dir1 NVARCHAR(10), @StoredReq1 NVARCHAR(MAX), @StoredRes1 NVARCHAR(MAX), @Fid1 BIT;
SELECT @Sys1 = SystemName, @Dir1 = Direction, @StoredReq1 = RequestPayload, @StoredRes1 = ResponsePayload, @Fid1 = IsHighFidelity
FROM Audit.InterfaceLog WHERE Id = @ResultId1;

DECLARE @ResultId1Str NVARCHAR(20) = CAST(@ResultId1 AS NVARCHAR(20));
EXEC test.Assert_IsNotNull @TestName = N'[High Fidelity] Row inserted', @Value = @ResultId1Str;
EXEC test.Assert_IsEqual @TestName = N'[High Fidelity] SystemName stored as AIM', @Expected = N'AIM', @Actual = @Sys1;
EXEC test.Assert_IsEqual @TestName = N'[High Fidelity] Direction stored as Out', @Expected = N'Out', @Actual = @Dir1;
EXEC test.Assert_IsEqual @TestName = N'[High Fidelity] RequestPayload stored verbatim', @Expected = @Req1, @Actual = @StoredReq1;
EXEC test.Assert_IsEqual @TestName = N'[High Fidelity] ResponsePayload stored verbatim', @Expected = @Res1, @Actual = @StoredRes1;
DECLARE @Fid1Str NVARCHAR(5) = CAST(@Fid1 AS NVARCHAR(5));
EXEC test.Assert_IsEqual @TestName = N'[High Fidelity] IsHighFidelity flag stored as 1', @Expected = N'1', @Actual = @Fid1Str;
GO

DECLARE @MaxIdBefore2 BIGINT = ISNULL((SELECT MAX(Id) FROM Audit.InterfaceLog), 0);
EXEC Audit.Audit_LogInterfaceCall @SystemName = N'Zebra', @Direction = N'Out', @LogEventTypeCode = N'InterfaceCall',
    @Description = N'Test: low fidelity', @RequestPayload = N'^XA^FDTest^FS^XZ', @ResponsePayload = N'OK', @IsHighFidelity = 0;

DECLARE @ResultId2 BIGINT = (SELECT MAX(Id) FROM Audit.InterfaceLog WHERE Id > @MaxIdBefore2);
DECLARE @StoredReq2 NVARCHAR(MAX), @StoredRes2 NVARCHAR(MAX), @Fid2 BIT;
SELECT @StoredReq2 = RequestPayload, @StoredRes2 = ResponsePayload, @Fid2 = IsHighFidelity FROM Audit.InterfaceLog WHERE Id = @ResultId2;

DECLARE @ResultId2Str NVARCHAR(20) = CAST(@ResultId2 AS NVARCHAR(20));
EXEC test.Assert_IsNotNull @TestName = N'[Low Fidelity] Row inserted', @Value = @ResultId2Str;
EXEC test.Assert_IsNull @TestName = N'[Low Fidelity] RequestPayload suppressed to NULL', @Value = @StoredReq2;
EXEC test.Assert_IsNull @TestName = N'[Low Fidelity] ResponsePayload suppressed to NULL', @Value = @StoredRes2;
DECLARE @Fid2Str NVARCHAR(5) = CAST(@Fid2 AS NVARCHAR(5));
EXEC test.Assert_IsEqual @TestName = N'[Low Fidelity] IsHighFidelity flag stored as 0', @Expected = N'0', @Actual = @Fid2Str;
GO

DECLARE @MaxIdBefore3 BIGINT = ISNULL((SELECT MAX(Id) FROM Audit.InterfaceLog), 0);
EXEC Audit.Audit_LogInterfaceCall @SystemName = N'AIM', @Direction = N'In', @LogEventTypeCode = N'InterfaceResponse',
    @Description = N'Test: error fields', @ErrorCondition = N'PARSE_ERROR', @ErrorDescription = N'Unexpected XML element', @IsHighFidelity = 0;

DECLARE @ResultId3 BIGINT = (SELECT MAX(Id) FROM Audit.InterfaceLog WHERE Id > @MaxIdBefore3);
DECLARE @ErrCond3 NVARCHAR(200), @ErrDesc3 NVARCHAR(1000);
SELECT @ErrCond3 = ErrorCondition, @ErrDesc3 = ErrorDescription FROM Audit.InterfaceLog WHERE Id = @ResultId3;

EXEC test.Assert_IsEqual @TestName = N'[Error Fields] ErrorCondition stored correctly', @Expected = N'PARSE_ERROR', @Actual = @ErrCond3;
EXEC test.Assert_IsEqual @TestName = N'[Error Fields] ErrorDescription stored correctly', @Expected = N'Unexpected XML element', @Actual = @ErrDesc3;
GO

EXEC test.PrintSummary;
GO
