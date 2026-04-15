-- =============================================
-- File:         02_audit_readers/040_ConfigLog_GetByEntity.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Tests for Audit.ConfigLog_GetByEntity.
--   Covers: returns matching rows for valid entity type + ID,
--   and 0 rows for invalid entity type code.
--
--   Pre-conditions:
--     - Migration 0001 applied (audit lookup seeds present)
--     - Location.AppUser Id=1 (system.bootstrap) present
--     - Audit.Audit_LogConfigChange deployed
--     - Audit.ConfigLog_GetByEntity deployed
-- =============================================

EXEC test.BeginTestFile @FileName = N'02_audit_readers/040_ConfigLog_GetByEntity.sql';
GO

-- =============================================
-- Setup: Insert 2 ConfigLog rows for AppUser entity 99,
--        and 1 ConfigLog row for Location entity 99.
--   All three rows share a unique description prefix so
--   tests can isolate what this file inserted.
-- =============================================
EXEC Audit.Audit_LogConfigChange
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @EntityId          = 99,
    @LogEventTypeCode  = N'Created',
    @LogSeverityCode   = N'Info',
    @Description       = N'Test 040: AppUser 99 row 1',
    @OldValue          = NULL,
    @NewValue          = N'{"DisplayName":"Test User"}';

EXEC Audit.Audit_LogConfigChange
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @EntityId          = 99,
    @LogEventTypeCode  = N'Updated',
    @LogSeverityCode   = N'Info',
    @Description       = N'Test 040: AppUser 99 row 2',
    @OldValue          = N'{"DisplayName":"Test User"}',
    @NewValue          = N'{"DisplayName":"Test User Updated"}';

EXEC Audit.Audit_LogConfigChange
    @AppUserId         = 1,
    @LogEntityTypeCode = N'Location',
    @EntityId          = 99,
    @LogEventTypeCode  = N'Created',
    @LogSeverityCode   = N'Info',
    @Description       = N'Test 040: Location 99 row 1',
    @OldValue          = NULL,
    @NewValue          = NULL;
GO

-- =============================================
-- Test 1: Valid entity type + entity ID returns matching rows.
--   Expect exactly 2 rows for AppUser entity 99
--   that were inserted during setup above.
-- =============================================
CREATE TABLE #GetByEntity1 (
    Id              BIGINT,
    LoggedAt        DATETIME2(3),
    UserId          BIGINT,
    UserDisplayName NVARCHAR(200),
    LogSeverityId   BIGINT,
    LogSeverityCode NVARCHAR(50),
    LogEventTypeId  BIGINT,
    LogEventTypeName NVARCHAR(100),
    LogEntityTypeId  BIGINT,
    LogEntityTypeName NVARCHAR(100),
    EntityId        BIGINT,
    Description     NVARCHAR(500),
    OldValue        NVARCHAR(MAX),
    NewValue        NVARCHAR(MAX)
);

INSERT INTO #GetByEntity1
EXEC Audit.ConfigLog_GetByEntity
    @LogEntityTypeCode = N'AppUser',
    @EntityId          = 99;

-- Assert 1a: exactly 2 rows returned for AppUser entity 99
--   (count those matching our setup descriptions to remain stable
--   even if other tests have inserted AppUser 99 rows)
DECLARE @MatchCount INT = (
    SELECT COUNT(*)
    FROM #GetByEntity1
    WHERE Description IN (N'Test 040: AppUser 99 row 1', N'Test 040: AppUser 99 row 2')
);
EXEC test.Assert_RowCount
    @TestName      = N'GetByEntity valid: 2 AppUser 99 setup rows returned',
    @ExpectedCount = 2,
    @ActualCount   = @MatchCount;

-- Assert 1b: no Location rows leaked into result
DECLARE @LocationLeakCount INT = (
    SELECT COUNT(*)
    FROM #GetByEntity1
    WHERE Description = N'Test 040: Location 99 row 1'
);
DECLARE @NoLeakStr NVARCHAR(5) = CAST(@LocationLeakCount AS NVARCHAR(5));
EXEC test.Assert_IsEqual
    @TestName = N'GetByEntity valid: Location entity rows not returned for AppUser filter',
    @Expected = N'0',
    @Actual   = @NoLeakStr;

DROP TABLE #GetByEntity1;
GO

-- =============================================
-- Test 2: Invalid entity type code returns 0 rows.
--   Read procs no longer return Status — invalid filters
--   simply produce empty result sets.
-- =============================================
CREATE TABLE #GetByEntity2 (
    Id              BIGINT,
    LoggedAt        DATETIME2(3),
    UserId          BIGINT,
    UserDisplayName NVARCHAR(200),
    LogSeverityId   BIGINT,
    LogSeverityCode NVARCHAR(50),
    LogEventTypeId  BIGINT,
    LogEventTypeName NVARCHAR(100),
    LogEntityTypeId  BIGINT,
    LogEntityTypeName NVARCHAR(100),
    EntityId        BIGINT,
    Description     NVARCHAR(500),
    OldValue        NVARCHAR(MAX),
    NewValue        NVARCHAR(MAX)
);

INSERT INTO #GetByEntity2
EXEC Audit.ConfigLog_GetByEntity
    @LogEntityTypeCode = N'BOGUS_ENTITY_TYPE',
    @EntityId          = 99;

-- Assert 2a: 0 rows returned for invalid entity type code
DECLARE @RowCount2 INT = (SELECT COUNT(*) FROM #GetByEntity2);
EXEC test.Assert_RowCount
    @TestName      = N'GetByEntity invalid code: 0 rows returned',
    @ExpectedCount = 0,
    @ActualCount   = @RowCount2;

DROP TABLE #GetByEntity2;
GO

-- =============================================
-- Final summary
-- =============================================
EXEC test.PrintSummary;
GO
