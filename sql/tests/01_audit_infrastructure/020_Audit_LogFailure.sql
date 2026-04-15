-- =============================================
-- File:         01_audit_infrastructure/020_Audit_LogFailure.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Modified:     2026-04-14 - Uses MAX(Id) before/after pattern
-- Description:
--   Tests for Audit.Audit_LogFailure.
-- =============================================

EXEC test.BeginTestFile @FileName = N'01_audit_infrastructure/020_Audit_LogFailure.sql';
GO

DECLARE @MaxIdBefore BIGINT = ISNULL((SELECT MAX(Id) FROM Audit.FailureLog), 0);

EXEC Audit.Audit_LogFailure
    @AppUserId           = 1,
    @LogEntityTypeCode   = N'AppUser',
    @EntityId            = NULL,
    @LogEventTypeCode    = N'Created',
    @FailureReason       = N'Duplicate AdAccount detected during create',
    @ProcedureName       = N'Location.AppUser_Create',
    @AttemptedParameters = N'{"AdAccount":"jdoe","DisplayName":"John Doe"}';

DECLARE @ResultId1 BIGINT = (SELECT MAX(Id) FROM Audit.FailureLog WHERE Id > @MaxIdBefore);
DECLARE @Reason1   NVARCHAR(500);
DECLARE @ProcName1 NVARCHAR(200);
DECLARE @Params1   NVARCHAR(MAX);

SELECT @Reason1 = FailureReason, @ProcName1 = ProcedureName, @Params1 = AttemptedParameters
FROM Audit.FailureLog WHERE Id = @ResultId1;

DECLARE @ResultId1Str NVARCHAR(20) = CAST(@ResultId1 AS NVARCHAR(20));
EXEC test.Assert_IsNotNull @TestName = N'[Happy Path] Row inserted', @Value = @ResultId1Str;
EXEC test.Assert_IsEqual @TestName = N'[Happy Path] FailureReason stored correctly', @Expected = N'Duplicate AdAccount detected during create', @Actual = @Reason1;
EXEC test.Assert_IsEqual @TestName = N'[Happy Path] ProcedureName stored correctly', @Expected = N'Location.AppUser_Create', @Actual = @ProcName1;
EXEC test.Assert_IsEqual @TestName = N'[Happy Path] AttemptedParameters stored correctly', @Expected = N'{"AdAccount":"jdoe","DisplayName":"John Doe"}', @Actual = @Params1;
GO

DECLARE @MaxIdBefore2 BIGINT = ISNULL((SELECT MAX(Id) FROM Audit.FailureLog), 0);
EXEC Audit.Audit_LogFailure @AppUserId = 1, @LogEntityTypeCode = N'AppUser', @LogEventTypeCode = N'Updated', @FailureReason = N'User not found', @ProcedureName = N'Location.AppUser_Update';
DECLARE @ResultId2 BIGINT = (SELECT MAX(Id) FROM Audit.FailureLog WHERE Id > @MaxIdBefore2);
DECLARE @Params2 NVARCHAR(MAX) = (SELECT AttemptedParameters FROM Audit.FailureLog WHERE Id = @ResultId2);
DECLARE @ResultId2Str NVARCHAR(20) = CAST(@ResultId2 AS NVARCHAR(20));
EXEC test.Assert_IsNotNull @TestName = N'[NULL Params] Row inserted', @Value = @ResultId2Str;
EXEC test.Assert_IsNull @TestName = N'[NULL Params] AttemptedParameters is NULL', @Value = @Params2;
GO

DECLARE @MaxIdBefore3 BIGINT = ISNULL((SELECT MAX(Id) FROM Audit.FailureLog), 0);
EXEC Audit.Audit_LogFailure @AppUserId = 1, @LogEntityTypeCode = N'BOGUS', @LogEventTypeCode = N'BOGUS', @FailureReason = N'Test', @ProcedureName = N'TestProc';
DECLARE @ResultId3 BIGINT = (SELECT MAX(Id) FROM Audit.FailureLog WHERE Id > @MaxIdBefore3);
DECLARE @EntityTypeId3 BIGINT, @EventTypeId3 BIGINT;
SELECT @EntityTypeId3 = LogEntityTypeId, @EventTypeId3 = LogEventTypeId FROM Audit.FailureLog WHERE Id = @ResultId3;
DECLARE @ResultId3Str NVARCHAR(20) = CAST(@ResultId3 AS NVARCHAR(20));
DECLARE @EntityTypeId3Str NVARCHAR(20) = CAST(@EntityTypeId3 AS NVARCHAR(20));
DECLARE @EventTypeId3Str NVARCHAR(20) = CAST(@EventTypeId3 AS NVARCHAR(20));
EXEC test.Assert_IsNotNull @TestName = N'[Invalid Codes] Row inserted', @Value = @ResultId3Str;
EXEC test.Assert_IsEqual @TestName = N'[Invalid Codes] LogEntityTypeId falls back to 1', @Expected = N'1', @Actual = @EntityTypeId3Str;
EXEC test.Assert_IsEqual @TestName = N'[Invalid Codes] LogEventTypeId falls back to 1', @Expected = N'1', @Actual = @EventTypeId3Str;
GO

DECLARE @MaxIdBefore4 BIGINT = ISNULL((SELECT MAX(Id) FROM Audit.FailureLog), 0);
EXEC Audit.Audit_LogFailure @AppUserId = 1, @LogEntityTypeCode = N'AppUser', @EntityId = 42, @LogEventTypeCode = N'Deprecated', @FailureReason = N'Test', @ProcedureName = N'Test', @AttemptedParameters = N'{"Id":42}';
DECLARE @ResultId4 BIGINT = (SELECT MAX(Id) FROM Audit.FailureLog WHERE Id > @MaxIdBefore4);
DECLARE @StoredId4 BIGINT = (SELECT EntityId FROM Audit.FailureLog WHERE Id = @ResultId4);
DECLARE @StoredId4Str NVARCHAR(20) = CAST(@StoredId4 AS NVARCHAR(20));
EXEC test.Assert_IsEqual @TestName = N'[EntityId] EntityId stored correctly', @Expected = N'42', @Actual = @StoredId4Str;
GO

EXEC test.PrintSummary;
GO
