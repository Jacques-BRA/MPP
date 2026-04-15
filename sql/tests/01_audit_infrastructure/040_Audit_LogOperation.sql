-- =============================================
-- File:         01_audit_infrastructure/040_Audit_LogOperation.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Audit.Audit_LogOperation.
--   Covers: happy path with location context, NULL location fields,
--   and invalid code fallbacks.
--
--   Pre-conditions:
--     - Migration 0001 applied (audit lookup seeds present)
--     - Location.AppUser Id=1 (system.bootstrap) present
--     - Audit.Audit_LogOperation deployed
-- =============================================

EXEC test.BeginTestFile @FileName = N'01_audit_infrastructure/040_Audit_LogOperation.sql';
GO

-- =============================================
-- Test 1: Happy path with location context.
--   Pass valid TerminalLocationId and LocationId.
--   Verify row inserted and both location columns stored correctly.
-- =============================================
DECLARE @BaselineCount      INT;
DECLARE @NewCount           INT;
DECLARE @InsertedId         BIGINT;
DECLARE @StoredTerminalLocId BIGINT;
DECLARE @StoredLocationId   BIGINT;
DECLARE @StoredEntityId     BIGINT;

-- Capture row count before call
SELECT @BaselineCount = COUNT(*) FROM Audit.OperationLog;

-- Use NULL for location FKs since no Location rows exist in Phase 1.
-- TerminalLocationId/LocationId are tested for NULL storage in Test 2.
EXEC Audit.Audit_LogOperation
    @AppUserId          = 1,
    @TerminalLocationId = NULL,
    @LocationId         = NULL,
    @LogEntityTypeCode  = N'AppUser',
    @EntityId           = 42,
    @LogEventTypeCode   = N'Created',
    @LogSeverityCode    = N'Info',
    @Description        = N'Test: happy path with location context',
    @OldValue           = NULL,
    @NewValue           = NULL;

SELECT @NewCount = COUNT(*) FROM Audit.OperationLog;

-- Assert 1a: exactly one row was added
DECLARE @Diff1a INT = @NewCount - @BaselineCount;
EXEC test.Assert_RowCount
    @TestName      = N'Happy path: one row inserted into OperationLog',
    @ExpectedCount = 1,
    @ActualCount   = @Diff1a;

-- Retrieve the inserted row
SELECT TOP 1
    @InsertedId          = Id,
    @StoredTerminalLocId = TerminalLocationId,
    @StoredLocationId    = LocationId,
    @StoredEntityId      = EntityId
FROM Audit.OperationLog
WHERE Description = N'Test: happy path with location context'
ORDER BY Id DESC;

-- Assert 1b: EntityId stored correctly
DECLARE @StoredEntityIdStr1b NVARCHAR(20) = CAST(@StoredEntityId AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName  = N'Happy path: EntityId stored as 42',
    @Expected  = N'42',
    @Actual    = @StoredEntityIdStr1b;
GO

-- =============================================
-- Test 2: NULL location fields.
--   Omit TerminalLocationId and LocationId (use defaults).
--   Verify both columns are stored as NULL.
-- =============================================
DECLARE @LogId              BIGINT;
DECLARE @StoredTerminalLocId BIGINT;
DECLARE @StoredLocationId   BIGINT;

EXEC Audit.Audit_LogOperation
    @AppUserId         = 1,
    @LogEntityTypeCode = N'Location',
    @EntityId          = NULL,
    @LogEventTypeCode  = N'Updated',
    @LogSeverityCode   = N'Info',
    @Description       = N'Test: NULL location fields';

SELECT TOP 1
    @LogId               = Id,
    @StoredTerminalLocId = TerminalLocationId,
    @StoredLocationId    = LocationId
FROM Audit.OperationLog
WHERE Description = N'Test: NULL location fields'
ORDER BY Id DESC;

-- Assert 2a: row was inserted
DECLARE @LogIdStr2a           NVARCHAR(20) = CAST(@LogId              AS NVARCHAR(20));
EXEC test.Assert_IsNotNull
    @TestName = N'NULL locations: row inserted',
    @Value    = @LogIdStr2a;

-- Assert 2b: TerminalLocationId is NULL
DECLARE @StoredTerminalLocIdStr2b NVARCHAR(20) = CAST(@StoredTerminalLocId AS NVARCHAR(20));
EXEC test.Assert_IsNull
    @TestName = N'NULL locations: TerminalLocationId is NULL',
    @Value    = @StoredTerminalLocIdStr2b;

-- Assert 2c: LocationId is NULL
DECLARE @StoredLocationIdStr2c NVARCHAR(20) = CAST(@StoredLocationId AS NVARCHAR(20));
EXEC test.Assert_IsNull
    @TestName = N'NULL locations: LocationId is NULL',
    @Value    = @StoredLocationIdStr2c;
GO

-- =============================================
-- Test 3: Invalid code strings - all three lookups receive bogus codes.
--   Procedure must NOT throw. Row must be inserted using fallback
--   defaults: Info (Id=1) / Created (Id=1) / Location (Id=1).
-- =============================================
DECLARE @LogId          BIGINT;
DECLARE @SeverityId     BIGINT;
DECLARE @EventTypeId    BIGINT;
DECLARE @EntityTypeId   BIGINT;
DECLARE @ThrewException BIT = 0;

BEGIN TRY
    EXEC Audit.Audit_LogOperation
        @AppUserId         = 1,
        @LogEntityTypeCode = N'BOGUS_ENTITY',
        @EntityId          = NULL,
        @LogEventTypeCode  = N'BOGUS_EVENT',
        @LogSeverityCode   = N'BOGUS_SEVERITY',
        @Description       = N'Test: operation invalid code fallback';
END TRY
BEGIN CATCH
    SET @ThrewException = 1;
END CATCH;

-- Assert 3a: no exception was raised
DECLARE @ThrewExceptionStr3a NVARCHAR(5) = CAST(@ThrewException AS NVARCHAR(5));
EXEC test.Assert_IsEqual
    @TestName  = N'Invalid codes: procedure did not throw',
    @Expected  = N'0',
    @Actual    = @ThrewExceptionStr3a;

-- Retrieve the inserted row
SELECT TOP 1
    @LogId        = Id,
    @SeverityId   = LogSeverityId,
    @EventTypeId  = LogEventTypeId,
    @EntityTypeId = LogEntityTypeId
FROM Audit.OperationLog
WHERE Description = N'Test: operation invalid code fallback'
ORDER BY Id DESC;

-- Assert 3b: row was still inserted
DECLARE @LogIdStr3b      NVARCHAR(20) = CAST(@LogId      AS NVARCHAR(20));
EXEC test.Assert_IsNotNull
    @TestName = N'Invalid codes: row still inserted',
    @Value    = @LogIdStr3b;

-- Assert 3c: LogSeverityId falls back to 1 (Info)
DECLARE @SeverityIdStr3c NVARCHAR(20) = CAST(@SeverityId AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName  = N'Invalid codes: LogSeverityId falls back to 1 (Info)',
    @Expected  = N'1',
    @Actual    = @SeverityIdStr3c;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
