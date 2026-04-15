-- =============================================
-- File:         01_audit_infrastructure/010_Audit_LogConfigChange.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Audit.Audit_LogConfigChange.
--   Covers: happy path, NULL EntityId, invalid code fallbacks,
--   and OldValue/NewValue JSON round-trip.
--
--   Pre-conditions:
--     - Migration 0001 applied (audit lookup seeds present)
--     - Location.AppUser Id=1 (system.bootstrap) present
--     - Audit.Audit_LogConfigChange deployed
-- =============================================

EXEC test.BeginTestFile @FileName = N'01_audit_infrastructure/010_Audit_LogConfigChange.sql';
GO

-- =============================================
-- Test 1: Happy path - valid codes, full parameters.
--   Verify row inserted; severity, event type, and entity type
--   IDs are resolved correctly against lookup tables.
-- =============================================
DECLARE @BaselineCount INT;
DECLARE @NewCount      INT;
DECLARE @InsertedId    BIGINT;

-- Capture row count before call
SELECT @BaselineCount = COUNT(*) FROM Audit.ConfigLog;

-- Execute the procedure - AppUser=1 (bootstrap), known valid codes
EXEC Audit.Audit_LogConfigChange
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @EntityId          = 42,
    @LogEventTypeCode  = N'Created',
    @LogSeverityCode   = N'Info',
    @Description       = N'Test: happy path - user created',
    @OldValue          = NULL,
    @NewValue          = NULL;

SELECT @NewCount = COUNT(*) FROM Audit.ConfigLog;

-- Assert 1a: exactly one row was added
DECLARE @Diff1a INT = @NewCount - @BaselineCount;
EXEC test.Assert_RowCount
    @TestName      = N'Happy path: one row inserted into ConfigLog',
    @ExpectedCount = 1,
    @ActualCount   = @Diff1a;

-- Grab the row we just inserted (newest Id for UserId=1 / Description match)
DECLARE @SeverityId   BIGINT;
DECLARE @EventTypeId  BIGINT;
DECLARE @EntityTypeId BIGINT;
DECLARE @StoredEntityId BIGINT;

SELECT TOP 1
    @InsertedId    = cl.Id,
    @SeverityId    = cl.LogSeverityId,
    @EventTypeId   = cl.LogEventTypeId,
    @EntityTypeId  = cl.LogEntityTypeId,
    @StoredEntityId = cl.EntityId
FROM Audit.ConfigLog cl
WHERE cl.UserId = 1
ORDER BY cl.Id DESC;

-- Expected IDs from seed data (migration 0001)
DECLARE @ExpectedSeverityId   BIGINT = (SELECT Id FROM Audit.LogSeverity  WHERE Code = N'Info');
DECLARE @ExpectedEventTypeId  BIGINT = (SELECT Id FROM Audit.LogEventType WHERE Code = N'Created');
DECLARE @ExpectedEntityTypeId BIGINT = (SELECT Id FROM Audit.LogEntityType WHERE Code = N'AppUser');

-- Assert 1b: LogSeverityId resolves correctly
DECLARE @ExpectedSeverityIdStr  NVARCHAR(20) = CAST(@ExpectedSeverityId   AS NVARCHAR(20));
DECLARE @ActualSeverityIdStr    NVARCHAR(20) = CAST(@SeverityId           AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName  = N'Happy path: LogSeverityId resolves to Info',
    @Expected  = @ExpectedSeverityIdStr,
    @Actual    = @ActualSeverityIdStr;

-- Assert 1c: LogEventTypeId resolves correctly
DECLARE @ExpectedEventTypeIdStr NVARCHAR(20) = CAST(@ExpectedEventTypeId  AS NVARCHAR(20));
DECLARE @ActualEventTypeIdStr   NVARCHAR(20) = CAST(@EventTypeId          AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName  = N'Happy path: LogEventTypeId resolves to Created',
    @Expected  = @ExpectedEventTypeIdStr,
    @Actual    = @ActualEventTypeIdStr;

-- Assert 1d: LogEntityTypeId resolves correctly
DECLARE @ExpectedEntityTypeIdStr NVARCHAR(20) = CAST(@ExpectedEntityTypeId AS NVARCHAR(20));
DECLARE @ActualEntityTypeIdStr   NVARCHAR(20) = CAST(@EntityTypeId         AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName  = N'Happy path: LogEntityTypeId resolves to AppUser',
    @Expected  = @ExpectedEntityTypeIdStr,
    @Actual    = @ActualEntityTypeIdStr;

-- Assert 1e: EntityId stored correctly
DECLARE @StoredEntityIdStr NVARCHAR(20) = CAST(@StoredEntityId AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName  = N'Happy path: EntityId stored as 42',
    @Expected  = N'42',
    @Actual    = @StoredEntityIdStr;
GO

-- =============================================
-- Test 2: NULL EntityId - verify row inserted with EntityId = NULL.
-- =============================================
DECLARE @LogId      BIGINT;
DECLARE @EntityId   BIGINT;

EXEC Audit.Audit_LogConfigChange
    @AppUserId         = 1,
    @LogEntityTypeCode = N'Location',
    @EntityId          = NULL,
    @LogEventTypeCode  = N'Updated',
    @LogSeverityCode   = N'Info',
    @Description       = N'Test: NULL EntityId';

-- Retrieve most recent row for this description
SELECT TOP 1
    @LogId    = Id,
    @EntityId = EntityId
FROM Audit.ConfigLog
WHERE Description = N'Test: NULL EntityId'
ORDER BY Id DESC;

-- Assert 2a: row was inserted (Id is not null)
DECLARE @LogIdStr2a NVARCHAR(20) = CAST(@LogId AS NVARCHAR(20));
EXEC test.Assert_IsNotNull
    @TestName = N'NULL EntityId: row inserted',
    @Value    = @LogIdStr2a;

-- Assert 2b: EntityId stored as NULL
DECLARE @EntityIdStr2b NVARCHAR(20) = CAST(@EntityId AS NVARCHAR(20));
EXEC test.Assert_IsNull
    @TestName = N'NULL EntityId: EntityId column is NULL',
    @Value    = @EntityIdStr2b;
GO

-- =============================================
-- Test 3: Invalid code strings - all three lookups receive bogus codes.
--   Procedure must NOT throw. Row must be inserted using fallback
--   defaults: Info (Id=1) / Created (Id=1) / Location (Id=1).
-- =============================================
DECLARE @LogId         BIGINT;
DECLARE @SeverityId    BIGINT;
DECLARE @EventTypeId   BIGINT;
DECLARE @EntityTypeId  BIGINT;
DECLARE @ThrewException BIT = 0;

BEGIN TRY
    EXEC Audit.Audit_LogConfigChange
        @AppUserId         = 1,
        @LogEntityTypeCode = N'BOGUS_ENTITY',
        @EntityId          = NULL,
        @LogEventTypeCode  = N'BOGUS_EVENT',
        @LogSeverityCode   = N'BOGUS_SEVERITY',
        @Description       = N'Test: invalid code fallback';
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
FROM Audit.ConfigLog
WHERE Description = N'Test: invalid code fallback'
ORDER BY Id DESC;

-- Assert 3b: row was inserted
DECLARE @LogIdStr3b       NVARCHAR(20) = CAST(@LogId        AS NVARCHAR(20));
EXEC test.Assert_IsNotNull
    @TestName = N'Invalid codes: row still inserted',
    @Value    = @LogIdStr3b;

-- Assert 3c: LogSeverityId falls back to 1 (Info)
DECLARE @SeverityIdStr3c  NVARCHAR(20) = CAST(@SeverityId   AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName  = N'Invalid codes: LogSeverityId falls back to 1 (Info)',
    @Expected  = N'1',
    @Actual    = @SeverityIdStr3c;

-- Assert 3d: LogEventTypeId falls back to 1 (Created)
DECLARE @EventTypeIdStr3d NVARCHAR(20) = CAST(@EventTypeId  AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName  = N'Invalid codes: LogEventTypeId falls back to 1 (Created)',
    @Expected  = N'1',
    @Actual    = @EventTypeIdStr3d;

-- Assert 3e: LogEntityTypeId falls back to 1 (Location)
DECLARE @EntityTypeIdStr3e NVARCHAR(20) = CAST(@EntityTypeId AS NVARCHAR(20));
EXEC test.Assert_IsEqual
    @TestName  = N'Invalid codes: LogEntityTypeId falls back to 1 (Location)',
    @Expected  = N'1',
    @Actual    = @EntityTypeIdStr3e;
GO

-- =============================================
-- Test 4: OldValue/NewValue JSON round-trip.
--   Verify JSON strings are stored and retrieved verbatim.
-- =============================================
DECLARE @OldJson    NVARCHAR(MAX) = N'{"DisplayName":"Alice","IgnitionRole":"Operator"}';
DECLARE @NewJson    NVARCHAR(MAX) = N'{"DisplayName":"Alice Smith","IgnitionRole":"Supervisor"}';
DECLARE @LogId      BIGINT;
DECLARE @StoredOld  NVARCHAR(MAX);
DECLARE @StoredNew  NVARCHAR(MAX);

EXEC Audit.Audit_LogConfigChange
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @EntityId          = 99,
    @LogEventTypeCode  = N'Updated',
    @LogSeverityCode   = N'Info',
    @Description       = N'Test: JSON round-trip',
    @OldValue          = @OldJson,
    @NewValue          = @NewJson;

SELECT TOP 1
    @LogId     = Id,
    @StoredOld = OldValue,
    @StoredNew = NewValue
FROM Audit.ConfigLog
WHERE Description = N'Test: JSON round-trip'
ORDER BY Id DESC;

-- Assert 4a: OldValue stored verbatim
EXEC test.Assert_IsEqual
    @TestName  = N'JSON round-trip: OldValue stored correctly',
    @Expected  = @OldJson,
    @Actual    = @StoredOld;

-- Assert 4b: NewValue stored verbatim
EXEC test.Assert_IsEqual
    @TestName  = N'JSON round-trip: NewValue stored correctly',
    @Expected  = @NewJson,
    @Actual    = @StoredNew;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
