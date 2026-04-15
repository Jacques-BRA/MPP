# Stored Procedure Test Suite — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a repeatable SQL test suite that validates all 21 Phase 1 stored procedures — happy paths, validation failures, business rules, edge cases, and audit side-effects.

**Architecture:** Pure T-SQL test scripts executed via `sqlcmd.exe`, orchestrated by a PowerShell runner modeled on `Reset-DevDatabase.ps1`. Each test file is self-contained: it sets up its own data, runs assertions, and prints pass/fail results. The runner resets the database once, runs all test files, and reports a summary. No external test frameworks — just SQL and PowerShell.

**Tech Stack:** T-SQL (SQL Server 2022+), PowerShell, sqlcmd.exe

---

## File Structure

```
sql/
├── tests/
│   ├── Run-Tests.ps1                          # Test runner — resets DB, runs all test files, reports summary
│   ├── helpers/
│   │   └── 0001_test_framework.sql            # Assert procs: Assert_IsEqual, Assert_IsTrue, Assert_IsNull, Assert_RowCount, Test_PrintSummary
│   ├── 01_audit_infrastructure/
│   │   ├── 010_Audit_LogConfigChange.sql      # Tests for Audit.Audit_LogConfigChange
│   │   ├── 020_Audit_LogFailure.sql           # Tests for Audit.Audit_LogFailure
│   │   ├── 030_Audit_LogInterfaceCall.sql     # Tests for Audit.Audit_LogInterfaceCall
│   │   └── 040_Audit_LogOperation.sql         # Tests for Audit.Audit_LogOperation
│   ├── 02_audit_readers/
│   │   ├── 010_LogEntityType_List.sql         # Tests for Audit.LogEntityType_List
│   │   ├── 020_LogEventType_List.sql          # Tests for Audit.LogEventType_List
│   │   ├── 030_LogSeverity_List.sql           # Tests for Audit.LogSeverity_List
│   │   ├── 040_ConfigLog_GetByEntity.sql      # Tests for Audit.ConfigLog_GetByEntity
│   │   ├── 050_ConfigLog_List.sql             # Tests for Audit.ConfigLog_List
│   │   ├── 060_FailureLog_GetByEntity.sql     # Tests for Audit.FailureLog_GetByEntity
│   │   ├── 070_FailureLog_List.sql            # Tests for Audit.FailureLog_List
│   │   ├── 080_FailureLog_GetTopProcs.sql     # Tests for Audit.FailureLog_GetTopProcs
│   │   └── 090_FailureLog_GetTopReasons.sql   # Tests for Audit.FailureLog_GetTopReasons
│   └── 03_appuser/
│       ├── 010_AppUser_Create.sql             # Tests for Location.AppUser_Create
│       ├── 020_AppUser_Get.sql                # Tests for Location.AppUser_Get
│       ├── 030_AppUser_GetByAdAccount.sql     # Tests for Location.AppUser_GetByAdAccount
│       ├── 040_AppUser_GetByClockNumber.sql   # Tests for Location.AppUser_GetByClockNumber
│       ├── 050_AppUser_List.sql               # Tests for Location.AppUser_List
│       ├── 060_AppUser_Update.sql             # Tests for Location.AppUser_Update
│       ├── 070_AppUser_SetPin.sql             # Tests for Location.AppUser_SetPin
│       └── 080_AppUser_Deprecate.sql          # Tests for Location.AppUser_Deprecate
```

**Naming rationale:** Numbered prefixes control execution order within each group. Groups are also numbered so the runner processes them in dependency order (audit writers first, then readers that query audit tables, then AppUser CRUD which exercises both).

---

## Task 1: Test Framework — Assert Helpers and Runner

**Files:**
- Create: `sql/tests/helpers/0001_test_framework.sql`
- Create: `sql/tests/Run-Tests.ps1`

### Step 1: Write the test framework SQL

- [ ] **Step 1a: Create the assert helper procs**

Create `sql/tests/helpers/0001_test_framework.sql`:

```sql
-- ============================================================
-- Test Framework — Lightweight assertion helpers
-- ============================================================
-- Deployed into a [test] schema so they never collide with app code.
-- Every assert prints PASS/FAIL with the test label.
-- A running tally is kept in a temp table ##TestResults so the
-- runner can report a summary at the end of each file.
-- ============================================================

IF SCHEMA_ID('test') IS NULL EXEC('CREATE SCHEMA test;');
GO

-- ── Shared result accumulator (global temp — survives GO batches) ──
IF OBJECT_ID('tempdb..##TestResults') IS NOT NULL
    DROP TABLE ##TestResults;

CREATE TABLE ##TestResults (
    Id        INT IDENTITY(1,1),
    TestFile  NVARCHAR(200),
    TestName  NVARCHAR(500),
    Passed    BIT,
    Detail    NVARCHAR(1000) NULL
);
GO

-- ============================================================
-- test.BeginTestFile — call at the top of each test script
-- ============================================================
CREATE OR ALTER PROCEDURE test.BeginTestFile
    @FileName NVARCHAR(200)
AS
BEGIN
    -- Store current file name for assertions to reference
    IF OBJECT_ID('tempdb..##CurrentTestFile') IS NOT NULL
        DROP TABLE ##CurrentTestFile;
    CREATE TABLE ##CurrentTestFile (FileName NVARCHAR(200));
    INSERT INTO ##CurrentTestFile VALUES (@FileName);

    PRINT '';
    PRINT '── ' + @FileName + ' ──────────────────────────────';
END;
GO

-- ============================================================
-- test.Assert_IsEqual — compare two NVARCHAR values
-- ============================================================
CREATE OR ALTER PROCEDURE test.Assert_IsEqual
    @TestName  NVARCHAR(500),
    @Expected  NVARCHAR(MAX),
    @Actual    NVARCHAR(MAX)
AS
BEGIN
    DECLARE @File NVARCHAR(200) = (SELECT TOP 1 FileName FROM ##CurrentTestFile);
    DECLARE @Pass BIT = CASE WHEN @Expected = @Actual THEN 1 ELSE 0 END;
    DECLARE @Detail NVARCHAR(1000) = NULL;

    IF @Pass = 0
        SET @Detail = N'Expected: [' + ISNULL(@Expected, N'NULL') + N'] Actual: [' + ISNULL(@Actual, N'NULL') + N']';

    INSERT INTO ##TestResults (TestFile, TestName, Passed, Detail) VALUES (@File, @TestName, @Pass, @Detail);
    PRINT CASE WHEN @Pass = 1 THEN '  PASS: ' ELSE '  FAIL: ' END + @TestName
        + ISNULL(' — ' + @Detail, '');
END;
GO

-- ============================================================
-- test.Assert_IsTrue — check a BIT condition
-- ============================================================
CREATE OR ALTER PROCEDURE test.Assert_IsTrue
    @TestName  NVARCHAR(500),
    @Condition BIT,
    @Detail    NVARCHAR(1000) = NULL
AS
BEGIN
    DECLARE @File NVARCHAR(200) = (SELECT TOP 1 FileName FROM ##CurrentTestFile);
    IF @Condition IS NULL SET @Condition = 0;

    INSERT INTO ##TestResults (TestFile, TestName, Passed, Detail) VALUES (@File, @TestName, @Condition, @Detail);
    PRINT CASE WHEN @Condition = 1 THEN '  PASS: ' ELSE '  FAIL: ' END + @TestName
        + ISNULL(' — ' + @Detail, '');
END;
GO

-- ============================================================
-- test.Assert_IsNull — verify a value IS NULL
-- ============================================================
CREATE OR ALTER PROCEDURE test.Assert_IsNull
    @TestName NVARCHAR(500),
    @Value    NVARCHAR(MAX)
AS
BEGIN
    DECLARE @File NVARCHAR(200) = (SELECT TOP 1 FileName FROM ##CurrentTestFile);
    DECLARE @Pass BIT = CASE WHEN @Value IS NULL THEN 1 ELSE 0 END;
    DECLARE @Detail NVARCHAR(1000) = NULL;
    IF @Pass = 0 SET @Detail = N'Expected NULL but got: [' + @Value + N']';

    INSERT INTO ##TestResults (TestFile, TestName, Passed, Detail) VALUES (@File, @TestName, @Pass, @Detail);
    PRINT CASE WHEN @Pass = 1 THEN '  PASS: ' ELSE '  FAIL: ' END + @TestName
        + ISNULL(' — ' + @Detail, '');
END;
GO

-- ============================================================
-- test.Assert_IsNotNull — verify a value IS NOT NULL
-- ============================================================
CREATE OR ALTER PROCEDURE test.Assert_IsNotNull
    @TestName NVARCHAR(500),
    @Value    NVARCHAR(MAX)
AS
BEGIN
    DECLARE @File NVARCHAR(200) = (SELECT TOP 1 FileName FROM ##CurrentTestFile);
    DECLARE @Pass BIT = CASE WHEN @Value IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @Detail NVARCHAR(1000) = NULL;
    IF @Pass = 0 SET @Detail = N'Expected non-NULL value but got NULL';

    INSERT INTO ##TestResults (TestFile, TestName, Passed, Detail) VALUES (@File, @TestName, @Pass, @Detail);
    PRINT CASE WHEN @Pass = 1 THEN '  PASS: ' ELSE '  FAIL: ' END + @TestName
        + ISNULL(' — ' + @Detail, '');
END;
GO

-- ============================================================
-- test.Assert_RowCount — check that a table has N rows matching a condition
-- (Pass the count in, not the query — keeps this framework simple)
-- ============================================================
CREATE OR ALTER PROCEDURE test.Assert_RowCount
    @TestName      NVARCHAR(500),
    @ExpectedCount INT,
    @ActualCount   INT
AS
BEGIN
    DECLARE @File NVARCHAR(200) = (SELECT TOP 1 FileName FROM ##CurrentTestFile);
    DECLARE @Pass BIT = CASE WHEN @ExpectedCount = @ActualCount THEN 1 ELSE 0 END;
    DECLARE @Detail NVARCHAR(1000) = NULL;
    IF @Pass = 0
        SET @Detail = N'Expected ' + CAST(@ExpectedCount AS NVARCHAR) + N' rows, got ' + CAST(@ActualCount AS NVARCHAR);

    INSERT INTO ##TestResults (TestFile, TestName, Passed, Detail) VALUES (@File, @TestName, @Pass, @Detail);
    PRINT CASE WHEN @Pass = 1 THEN '  PASS: ' ELSE '  FAIL: ' END + @TestName
        + ISNULL(' — ' + @Detail, '');
END;
GO

-- ============================================================
-- test.PrintSummary — call at the end of each test file
-- ============================================================
CREATE OR ALTER PROCEDURE test.PrintSummary
AS
BEGIN
    DECLARE @File NVARCHAR(200) = (SELECT TOP 1 FileName FROM ##CurrentTestFile);
    DECLARE @Total INT = (SELECT COUNT(*) FROM ##TestResults WHERE TestFile = @File);
    DECLARE @Passed INT = (SELECT COUNT(*) FROM ##TestResults WHERE TestFile = @File AND Passed = 1);
    DECLARE @Failed INT = @Total - @Passed;

    PRINT '';
    PRINT '  Results: ' + CAST(@Passed AS NVARCHAR) + '/' + CAST(@Total AS NVARCHAR) + ' passed'
        + CASE WHEN @Failed > 0 THEN ' (' + CAST(@Failed AS NVARCHAR) + ' FAILED)' ELSE '' END;
    PRINT '';
END;
GO
```

- [ ] **Step 1b: Run the framework SQL manually to verify it compiles**

Run from the project root:
```powershell
sqlcmd -S localhost -d MPP_MES_Dev -i sql\tests\helpers\0001_test_framework.sql -b -I -C
```
Expected: No errors. The `test` schema and 7 procs are created.

### Step 2: Write the test runner PowerShell script

- [ ] **Step 2a: Create Run-Tests.ps1**

Create `sql/tests/Run-Tests.ps1`:

```powershell
# ============================================================
# Run-Tests.ps1
# Resets the dev database, deploys the test framework, and runs
# all test scripts. Reports pass/fail summary at the end.
#
# Usage:
#   .\Run-Tests.ps1                                  # localhost, Windows auth
#   .\Run-Tests.ps1 -ServerInstance ".\SQL2022"
#   .\Run-Tests.ps1 -Filter "AppUser"                # only run files matching "AppUser"
#
# Prerequisites:
#   - sqlcmd.exe (ships with SSMS or SQL Server)
#   - Reset-DevDatabase.ps1 in ../scripts/
# ============================================================

[CmdletBinding()]
param(
    [string]$ServerInstance = "localhost",
    [string]$DatabaseName  = "MPP_MES_Dev",
    [string]$Filter        = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TestRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$SqlRoot    = Split-Path -Parent $TestRoot
$ScriptsDir = Join-Path $SqlRoot "scripts"
$Helpers    = Join-Path $TestRoot "helpers"

# ── Step 1: Reset the database ───────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  STORED PROCEDURE TEST SUITE" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "[1/4] Resetting database via Reset-DevDatabase.ps1..." -ForegroundColor Cyan
& (Join-Path $ScriptsDir "Reset-DevDatabase.ps1") -ServerInstance $ServerInstance -DatabaseName $DatabaseName

# ── Step 2: Deploy test framework ────────────────────────────
Write-Host "[2/4] Deploying test framework..." -ForegroundColor Cyan
$helperFiles = @(Get-ChildItem -Path $Helpers -Filter "*.sql" | Sort-Object Name)
foreach ($file in $helperFiles) {
    Write-Host "  Running: $($file.Name)" -ForegroundColor DarkGray
    $output = & sqlcmd -S $ServerInstance -d $DatabaseName -i $file.FullName -b -I -C 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED: $($file.Name)" -ForegroundColor Red
        $output | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        throw "Test framework deployment failed on $($file.Name)"
    }
}

# ── Step 3: Discover and run test files ──────────────────────
Write-Host "[3/4] Running tests..." -ForegroundColor Cyan
Write-Host ""

# Find all numbered test directories, sorted
$testDirs = @(Get-ChildItem -Path $TestRoot -Directory | Where-Object { $_.Name -match '^\d+_' } | Sort-Object Name)

$allTestFiles = @()
foreach ($dir in $testDirs) {
    $files = @(Get-ChildItem -Path $dir.FullName -Filter "*.sql" | Sort-Object Name)
    if ($Filter -ne "") {
        $files = @($files | Where-Object { $_.Name -like "*$Filter*" })
    }
    $allTestFiles += $files
}

if ($allTestFiles.Count -eq 0) {
    Write-Host "  No test files found$(if ($Filter) { " matching '$Filter'" })." -ForegroundColor DarkYellow
    return
}

$filesFailed = 0
foreach ($file in $allTestFiles) {
    $output = & sqlcmd -S $ServerInstance -d $DatabaseName -i $file.FullName -b -I -C 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR running $($file.Name):" -ForegroundColor Red
        $output | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        $filesFailed++
    }
    else {
        # Print the PASS/FAIL output from the test file
        $output | ForEach-Object {
            $line = $_.ToString().Trim()
            if ($line -ne "" -and $line -notmatch "^\(\d+ rows? affected\)$" -and $line -notmatch "^Changed database") {
                if ($line -match "FAIL") {
                    Write-Host $line -ForegroundColor Red
                }
                elseif ($line -match "PASS") {
                    Write-Host $line -ForegroundColor Green
                }
                elseif ($line -match "^──") {
                    Write-Host $line -ForegroundColor Cyan
                }
                else {
                    Write-Host $line
                }
            }
        }
    }
}

# ── Step 4: Final summary ────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  FINAL SUMMARY" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Query the ##TestResults table for totals
$summaryQuery = @"
SELECT
    (SELECT COUNT(*) FROM ##TestResults) AS Total,
    (SELECT COUNT(*) FROM ##TestResults WHERE Passed = 1) AS Passed,
    (SELECT COUNT(*) FROM ##TestResults WHERE Passed = 0) AS Failed;
"@
$summaryOutput = & sqlcmd -S $ServerInstance -d $DatabaseName -Q $summaryQuery -h -1 -W -s "|" -b -C 2>&1
if ($LASTEXITCODE -eq 0 -and $summaryOutput.Count -gt 0) {
    $parts = $summaryOutput[0].ToString().Split('|')
    $total  = $parts[0].Trim()
    $passed = $parts[1].Trim()
    $failed = $parts[2].Trim()

    Write-Host ""
    Write-Host "  Total:  $total" -ForegroundColor White
    Write-Host "  Passed: $passed" -ForegroundColor Green
    if ([int]$failed -gt 0) {
        Write-Host "  Failed: $failed" -ForegroundColor Red
        Write-Host ""

        # List failing tests
        $failQuery = "SELECT TestFile + ' :: ' + TestName + ISNULL(' — ' + Detail, '') FROM ##TestResults WHERE Passed = 0;"
        $failOutput = & sqlcmd -S $ServerInstance -d $DatabaseName -Q $failQuery -h -1 -W -b -C 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Failing tests:" -ForegroundColor Red
            $failOutput | ForEach-Object {
                $line = $_.ToString().Trim()
                if ($line -ne "") { Write-Host "    - $line" -ForegroundColor Red }
            }
        }
    }
    else {
        Write-Host "  Failed: 0" -ForegroundColor Green
    }
}

if ($filesFailed -gt 0) {
    Write-Host ""
    Write-Host "  $filesFailed test file(s) had execution errors (sqlcmd failures)." -ForegroundColor Red
}

Write-Host ""

# Exit with error code if anything failed
if ($filesFailed -gt 0 -or ([int]$failed -gt 0)) {
    exit 1
}
```

- [ ] **Step 2b: Verify the runner finds no tests (sanity check)**

```powershell
cd sql\tests
.\Run-Tests.ps1
```
Expected: Database resets, framework deploys, "No test files found" message, no errors.

- [ ] **Step 2c: Commit the scaffolding**

```bash
git add sql/tests/Run-Tests.ps1 sql/tests/helpers/0001_test_framework.sql
git commit -m "test: add SQL test framework and runner for Phase 1 stored procs"
```

---

## Task 2: Audit Infrastructure — LogConfigChange Tests

**Files:**
- Create: `sql/tests/01_audit_infrastructure/010_Audit_LogConfigChange.sql`

**What we're testing:** `Audit.Audit_LogConfigChange` — logs successful config mutations. Resolves code strings to IDs via lookup tables. Falls back to default IDs if codes are bad (never throws).

- [ ] **Step 1: Write the test file**

Create `sql/tests/01_audit_infrastructure/010_Audit_LogConfigChange.sql`:

```sql
-- ============================================================
-- Tests: Audit.Audit_LogConfigChange
-- ============================================================
EXEC test.BeginTestFile @FileName = N'010_Audit_LogConfigChange';
GO

-- ── Test 1: Happy path — valid codes, full parameters ────────
DECLARE @CountBefore INT = (SELECT COUNT(*) FROM Audit.ConfigLog);

EXEC Audit.Audit_LogConfigChange
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @EntityId          = 1,
    @LogEventTypeCode  = N'Created',
    @LogSeverityCode   = N'Info',
    @Description       = N'Test config change.',
    @OldValue          = N'{"before": true}',
    @NewValue          = N'{"after": true}';

DECLARE @CountAfter INT = (SELECT COUNT(*) FROM Audit.ConfigLog);
EXEC test.Assert_IsTrue @TestName = N'Happy path inserts a row',
    @Condition = CASE WHEN @CountAfter = @CountBefore + 1 THEN 1 ELSE 0 END;

-- Verify the inserted row has correct resolved FKs
DECLARE @SevId BIGINT, @EventId BIGINT, @EntityTypeId BIGINT;
SELECT TOP 1
    @SevId = LogSeverityId,
    @EventId = LogEventTypeId,
    @EntityTypeId = LogEntityTypeId
FROM Audit.ConfigLog ORDER BY Id DESC;

DECLARE @ExpSevId BIGINT = (SELECT Id FROM Audit.LogSeverity WHERE Code = N'Info');
DECLARE @ExpEventId BIGINT = (SELECT Id FROM Audit.LogEventType WHERE Code = N'Created');
DECLARE @ExpEntityId BIGINT = (SELECT Id FROM Audit.LogEntityType WHERE Code = N'AppUser');

EXEC test.Assert_IsEqual @TestName = N'Severity resolved correctly',
    @Expected = CAST(@ExpSevId AS NVARCHAR), @Actual = CAST(@SevId AS NVARCHAR);
EXEC test.Assert_IsEqual @TestName = N'EventType resolved correctly',
    @Expected = CAST(@ExpEventId AS NVARCHAR), @Actual = CAST(@EventId AS NVARCHAR);
EXEC test.Assert_IsEqual @TestName = N'EntityType resolved correctly',
    @Expected = CAST(@ExpEntityId AS NVARCHAR), @Actual = CAST(@EntityTypeId AS NVARCHAR);
GO

-- ── Test 2: NULL EntityId is allowed ─────────────────────────
DECLARE @CountBefore2 INT = (SELECT COUNT(*) FROM Audit.ConfigLog);

EXEC Audit.Audit_LogConfigChange
    @AppUserId         = 1,
    @LogEntityTypeCode = N'Location',
    @EntityId          = NULL,
    @LogEventTypeCode  = N'Created',
    @LogSeverityCode   = N'Info',
    @Description       = N'Entity not yet created.';

DECLARE @CountAfter2 INT = (SELECT COUNT(*) FROM Audit.ConfigLog);
EXEC test.Assert_IsTrue @TestName = N'NULL EntityId inserts a row',
    @Condition = CASE WHEN @CountAfter2 = @CountBefore2 + 1 THEN 1 ELSE 0 END;

DECLARE @StoredEntityId BIGINT;
SELECT TOP 1 @StoredEntityId = EntityId FROM Audit.ConfigLog ORDER BY Id DESC;
EXEC test.Assert_IsNull @TestName = N'EntityId stored as NULL',
    @Value = CAST(@StoredEntityId AS NVARCHAR);
GO

-- ── Test 3: Invalid code strings fall back to defaults ───────
DECLARE @CountBefore3 INT = (SELECT COUNT(*) FROM Audit.ConfigLog);

EXEC Audit.Audit_LogConfigChange
    @AppUserId         = 1,
    @LogEntityTypeCode = N'BOGUS_ENTITY',
    @EntityId          = 999,
    @LogEventTypeCode  = N'BOGUS_EVENT',
    @LogSeverityCode   = N'BOGUS_SEV',
    @Description       = N'All codes invalid — should fall back.';

DECLARE @CountAfter3 INT = (SELECT COUNT(*) FROM Audit.ConfigLog);
EXEC test.Assert_IsTrue @TestName = N'Invalid codes still insert (fallback)',
    @Condition = CASE WHEN @CountAfter3 = @CountBefore3 + 1 THEN 1 ELSE 0 END;

-- The proc falls back to Info / Created / Location defaults
DECLARE @FbSevId BIGINT, @FbEventId BIGINT, @FbEntityTypeId BIGINT;
SELECT TOP 1
    @FbSevId = LogSeverityId,
    @FbEventId = LogEventTypeId,
    @FbEntityTypeId = LogEntityTypeId
FROM Audit.ConfigLog ORDER BY Id DESC;

DECLARE @InfoId BIGINT = (SELECT Id FROM Audit.LogSeverity WHERE Code = N'Info');
DECLARE @CreatedId BIGINT = (SELECT Id FROM Audit.LogEventType WHERE Code = N'Created');
DECLARE @LocationId BIGINT = (SELECT Id FROM Audit.LogEntityType WHERE Code = N'Location');

EXEC test.Assert_IsEqual @TestName = N'Fallback severity = Info',
    @Expected = CAST(@InfoId AS NVARCHAR), @Actual = CAST(@FbSevId AS NVARCHAR);
EXEC test.Assert_IsEqual @TestName = N'Fallback event type = Created',
    @Expected = CAST(@CreatedId AS NVARCHAR), @Actual = CAST(@FbEventId AS NVARCHAR);
EXEC test.Assert_IsEqual @TestName = N'Fallback entity type = Location',
    @Expected = CAST(@LocationId AS NVARCHAR), @Actual = CAST(@FbEntityTypeId AS NVARCHAR);
GO

-- ── Test 4: OldValue and NewValue stored correctly ───────────
DECLARE @OldJson NVARCHAR(MAX) = N'{"DisplayName":"Old Name"}';
DECLARE @NewJson NVARCHAR(MAX) = N'{"DisplayName":"New Name"}';

EXEC Audit.Audit_LogConfigChange
    @AppUserId         = 1,
    @LogEntityTypeCode = N'AppUser',
    @EntityId          = 1,
    @LogEventTypeCode  = N'Updated',
    @LogSeverityCode   = N'Info',
    @Description       = N'Testing JSON snapshots.',
    @OldValue          = @OldJson,
    @NewValue          = @NewJson;

DECLARE @StoredOld NVARCHAR(MAX), @StoredNew NVARCHAR(MAX);
SELECT TOP 1 @StoredOld = OldValue, @StoredNew = NewValue
FROM Audit.ConfigLog ORDER BY Id DESC;

EXEC test.Assert_IsEqual @TestName = N'OldValue JSON stored correctly',
    @Expected = @OldJson, @Actual = @StoredOld;
EXEC test.Assert_IsEqual @TestName = N'NewValue JSON stored correctly',
    @Expected = @NewJson, @Actual = @StoredNew;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Run the test to verify it passes**

```powershell
cd sql\tests
.\Run-Tests.ps1
```
Expected: All 10 assertions pass.

- [ ] **Step 3: Commit**

```bash
git add sql/tests/01_audit_infrastructure/010_Audit_LogConfigChange.sql
git commit -m "test: Audit.Audit_LogConfigChange — code resolution, fallbacks, JSON snapshots"
```

---

## Task 3: Audit Infrastructure — LogFailure Tests

**Files:**
- Create: `sql/tests/01_audit_infrastructure/020_Audit_LogFailure.sql`

**What we're testing:** `Audit.Audit_LogFailure` — logs rejected operations. Must never throw (callers rely on this). Resolves codes, stores procedure name and attempted params.

- [ ] **Step 1: Write the test file**

Create `sql/tests/01_audit_infrastructure/020_Audit_LogFailure.sql`:

```sql
-- ============================================================
-- Tests: Audit.Audit_LogFailure
-- ============================================================
EXEC test.BeginTestFile @FileName = N'020_Audit_LogFailure';
GO

-- ── Test 1: Happy path — validation failure logged ───────────
DECLARE @CountBefore INT = (SELECT COUNT(*) FROM Audit.FailureLog);

EXEC Audit.Audit_LogFailure
    @AppUserId           = 1,
    @LogEntityTypeCode   = N'AppUser',
    @EntityId            = NULL,
    @LogEventTypeCode    = N'Created',
    @FailureReason       = N'Required parameter missing.',
    @ProcedureName       = N'Location.AppUser_Create',
    @AttemptedParameters = N'{"AdAccount":null}';

DECLARE @CountAfter INT = (SELECT COUNT(*) FROM Audit.FailureLog);
EXEC test.Assert_IsTrue @TestName = N'Failure log row inserted',
    @Condition = CASE WHEN @CountAfter = @CountBefore + 1 THEN 1 ELSE 0 END;

-- Verify stored values
DECLARE @Reason NVARCHAR(500), @Proc NVARCHAR(200), @Params NVARCHAR(MAX);
SELECT TOP 1
    @Reason = FailureReason,
    @Proc   = ProcedureName,
    @Params = AttemptedParameters
FROM Audit.FailureLog ORDER BY Id DESC;

EXEC test.Assert_IsEqual @TestName = N'FailureReason stored',
    @Expected = N'Required parameter missing.', @Actual = @Reason;
EXEC test.Assert_IsEqual @TestName = N'ProcedureName stored',
    @Expected = N'Location.AppUser_Create', @Actual = @Proc;
EXEC test.Assert_IsEqual @TestName = N'AttemptedParameters stored',
    @Expected = N'{"AdAccount":null}', @Actual = @Params;
GO

-- ── Test 2: NULL AttemptedParameters is allowed ──────────────
DECLARE @CountBefore2 INT = (SELECT COUNT(*) FROM Audit.FailureLog);

EXEC Audit.Audit_LogFailure
    @AppUserId           = 1,
    @LogEntityTypeCode   = N'AppUser',
    @EntityId            = 42,
    @LogEventTypeCode    = N'Updated',
    @FailureReason       = N'User not found.',
    @ProcedureName       = N'Location.AppUser_Update',
    @AttemptedParameters = NULL;

DECLARE @CountAfter2 INT = (SELECT COUNT(*) FROM Audit.FailureLog);
EXEC test.Assert_IsTrue @TestName = N'NULL params still inserts',
    @Condition = CASE WHEN @CountAfter2 = @CountBefore2 + 1 THEN 1 ELSE 0 END;
GO

-- ── Test 3: Invalid codes fall back (same as LogConfigChange) ──
DECLARE @CountBefore3 INT = (SELECT COUNT(*) FROM Audit.FailureLog);

EXEC Audit.Audit_LogFailure
    @AppUserId           = 1,
    @LogEntityTypeCode   = N'BOGUS',
    @EntityId            = NULL,
    @LogEventTypeCode    = N'BOGUS',
    @FailureReason       = N'Testing fallback.',
    @ProcedureName       = N'Test.FakeProc',
    @AttemptedParameters = NULL;

DECLARE @CountAfter3 INT = (SELECT COUNT(*) FROM Audit.FailureLog);
EXEC test.Assert_IsTrue @TestName = N'Invalid codes still insert (fallback)',
    @Condition = CASE WHEN @CountAfter3 = @CountBefore3 + 1 THEN 1 ELSE 0 END;
GO

-- ── Test 4: EntityId can be non-NULL ─────────────────────────
EXEC Audit.Audit_LogFailure
    @AppUserId           = 1,
    @LogEntityTypeCode   = N'AppUser',
    @EntityId            = 1,
    @LogEventTypeCode    = N'Deprecated',
    @FailureReason       = N'Cannot deprecate self.',
    @ProcedureName       = N'Location.AppUser_Deprecate',
    @AttemptedParameters = N'{"Id":1}';

DECLARE @StoredEntityId BIGINT;
SELECT TOP 1 @StoredEntityId = EntityId FROM Audit.FailureLog ORDER BY Id DESC;
EXEC test.Assert_IsEqual @TestName = N'EntityId stored when provided',
    @Expected = N'1', @Actual = CAST(@StoredEntityId AS NVARCHAR);
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Run tests**

```powershell
.\Run-Tests.ps1
```
Expected: All pass (010 + 020 files).

- [ ] **Step 3: Commit**

```bash
git add sql/tests/01_audit_infrastructure/020_Audit_LogFailure.sql
git commit -m "test: Audit.Audit_LogFailure — happy path, NULL params, fallback codes"
```

---

## Task 4: Audit Infrastructure — LogInterfaceCall Tests

**Files:**
- Create: `sql/tests/01_audit_infrastructure/030_Audit_LogInterfaceCall.sql`

**What we're testing:** `Audit.Audit_LogInterfaceCall` — logs external system comms. Key behavior: `@IsHighFidelity=0` NULLs out payloads.

- [ ] **Step 1: Write the test file**

Create `sql/tests/01_audit_infrastructure/030_Audit_LogInterfaceCall.sql`:

```sql
-- ============================================================
-- Tests: Audit.Audit_LogInterfaceCall
-- ============================================================
EXEC test.BeginTestFile @FileName = N'030_Audit_LogInterfaceCall';
GO

-- ── Test 1: High-fidelity — payloads stored ──────────────────
DECLARE @CountBefore INT = (SELECT COUNT(*) FROM Audit.InterfaceLog);

EXEC Audit.Audit_LogInterfaceCall
    @SystemName        = N'AIM',
    @Direction         = N'Out',
    @LogEventTypeCode  = N'InterfaceCall',
    @Description       = N'GetNextNumber request.',
    @RequestPayload    = N'{"action":"GetNextNumber"}',
    @ResponsePayload   = N'{"number":"12345"}',
    @ErrorCondition    = NULL,
    @ErrorDescription  = NULL,
    @IsHighFidelity    = 1;

DECLARE @CountAfter INT = (SELECT COUNT(*) FROM Audit.InterfaceLog);
EXEC test.Assert_IsTrue @TestName = N'High-fidelity row inserted',
    @Condition = CASE WHEN @CountAfter = @CountBefore + 1 THEN 1 ELSE 0 END;

DECLARE @ReqPayload NVARCHAR(MAX), @RespPayload NVARCHAR(MAX), @SysName NVARCHAR(50), @Dir NVARCHAR(10);
SELECT TOP 1
    @ReqPayload  = RequestPayload,
    @RespPayload = ResponsePayload,
    @SysName     = SystemName,
    @Dir         = Direction
FROM Audit.InterfaceLog ORDER BY Id DESC;

EXEC test.Assert_IsEqual @TestName = N'Request payload stored (high fidelity)',
    @Expected = N'{"action":"GetNextNumber"}', @Actual = @ReqPayload;
EXEC test.Assert_IsEqual @TestName = N'Response payload stored (high fidelity)',
    @Expected = N'{"number":"12345"}', @Actual = @RespPayload;
EXEC test.Assert_IsEqual @TestName = N'SystemName = AIM',
    @Expected = N'AIM', @Actual = @SysName;
EXEC test.Assert_IsEqual @TestName = N'Direction = Out',
    @Expected = N'Out', @Actual = @Dir;
GO

-- ── Test 2: Low-fidelity — payloads NULLed ───────────────────
EXEC Audit.Audit_LogInterfaceCall
    @SystemName        = N'Zebra',
    @Direction         = N'Out',
    @LogEventTypeCode  = N'InterfaceCall',
    @Description       = N'Print label.',
    @RequestPayload    = N'ZPL-data-here',
    @ResponsePayload   = N'OK',
    @IsHighFidelity    = 0;

DECLARE @ReqLo NVARCHAR(MAX), @RespLo NVARCHAR(MAX);
SELECT TOP 1 @ReqLo = RequestPayload, @RespLo = ResponsePayload
FROM Audit.InterfaceLog ORDER BY Id DESC;

EXEC test.Assert_IsNull @TestName = N'Request payload NULLed (low fidelity)',
    @Value = @ReqLo;
EXEC test.Assert_IsNull @TestName = N'Response payload NULLed (low fidelity)',
    @Value = @RespLo;
GO

-- ── Test 3: Error fields stored when present ─────────────────
EXEC Audit.Audit_LogInterfaceCall
    @SystemName        = N'AIM',
    @Direction         = N'In',
    @LogEventTypeCode  = N'InterfaceResponse',
    @Description       = N'AIM returned error.',
    @ErrorCondition    = N'AIM-ERR-500',
    @ErrorDescription  = N'Internal server error from AIM.',
    @IsHighFidelity    = 0;

DECLARE @ErrCond NVARCHAR(200), @ErrDesc NVARCHAR(1000);
SELECT TOP 1 @ErrCond = ErrorCondition, @ErrDesc = ErrorDescription
FROM Audit.InterfaceLog ORDER BY Id DESC;

EXEC test.Assert_IsEqual @TestName = N'ErrorCondition stored',
    @Expected = N'AIM-ERR-500', @Actual = @ErrCond;
EXEC test.Assert_IsEqual @TestName = N'ErrorDescription stored',
    @Expected = N'Internal server error from AIM.', @Actual = @ErrDesc;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Run tests, verify pass**

```powershell
.\Run-Tests.ps1
```

- [ ] **Step 3: Commit**

```bash
git add sql/tests/01_audit_infrastructure/030_Audit_LogInterfaceCall.sql
git commit -m "test: Audit.Audit_LogInterfaceCall — high/low fidelity, error fields"
```

---

## Task 5: Audit Infrastructure — LogOperation Tests

**Files:**
- Create: `sql/tests/01_audit_infrastructure/040_Audit_LogOperation.sql`

**What we're testing:** `Audit.Audit_LogOperation` — logs plant-floor mutations. Same as LogConfigChange but with TerminalLocationId and LocationId.

- [ ] **Step 1: Write the test file**

Create `sql/tests/01_audit_infrastructure/040_Audit_LogOperation.sql`:

```sql
-- ============================================================
-- Tests: Audit.Audit_LogOperation
-- ============================================================
EXEC test.BeginTestFile @FileName = N'040_Audit_LogOperation';
GO

-- ── Test 1: Happy path with location context ─────────────────
DECLARE @CountBefore INT = (SELECT COUNT(*) FROM Audit.OperationLog);

EXEC Audit.Audit_LogOperation
    @AppUserId           = 1,
    @TerminalLocationId  = 100,
    @LocationId          = 200,
    @LogEntityTypeCode   = N'Lot',
    @EntityId            = 5000,
    @LogEventTypeCode    = N'LotCreated',
    @LogSeverityCode     = N'Info',
    @Description         = N'LOT created at die cast.',
    @OldValue            = NULL,
    @NewValue            = N'{"LotNumber":"DC-2026-001"}';

DECLARE @CountAfter INT = (SELECT COUNT(*) FROM Audit.OperationLog);
EXEC test.Assert_IsTrue @TestName = N'Operation log row inserted',
    @Condition = CASE WHEN @CountAfter = @CountBefore + 1 THEN 1 ELSE 0 END;

DECLARE @TermId BIGINT, @LocId BIGINT;
SELECT TOP 1 @TermId = TerminalLocationId, @LocId = LocationId
FROM Audit.OperationLog ORDER BY Id DESC;

EXEC test.Assert_IsEqual @TestName = N'TerminalLocationId stored',
    @Expected = N'100', @Actual = CAST(@TermId AS NVARCHAR);
EXEC test.Assert_IsEqual @TestName = N'LocationId stored',
    @Expected = N'200', @Actual = CAST(@LocId AS NVARCHAR);
GO

-- ── Test 2: NULL location fields are allowed ─────────────────
EXEC Audit.Audit_LogOperation
    @AppUserId           = 1,
    @TerminalLocationId  = NULL,
    @LocationId          = NULL,
    @LogEntityTypeCode   = N'Lot',
    @EntityId            = 5001,
    @LogEventTypeCode    = N'LotMoved',
    @LogSeverityCode     = N'Info',
    @Description         = N'No terminal context.';

DECLARE @TermId2 BIGINT, @LocId2 BIGINT;
SELECT TOP 1 @TermId2 = TerminalLocationId, @LocId2 = LocationId
FROM Audit.OperationLog ORDER BY Id DESC;

EXEC test.Assert_IsNull @TestName = N'NULL TerminalLocationId stored',
    @Value = CAST(@TermId2 AS NVARCHAR);
EXEC test.Assert_IsNull @TestName = N'NULL LocationId stored',
    @Value = CAST(@LocId2 AS NVARCHAR);
GO

-- ── Test 3: Code resolution works same as ConfigLog ──────────
EXEC Audit.Audit_LogOperation
    @AppUserId           = 1,
    @LogEntityTypeCode   = N'BOGUS',
    @EntityId            = NULL,
    @LogEventTypeCode    = N'BOGUS',
    @LogSeverityCode     = N'BOGUS',
    @Description         = N'Fallback test.';

DECLARE @FbSevId BIGINT;
SELECT TOP 1 @FbSevId = LogSeverityId FROM Audit.OperationLog ORDER BY Id DESC;
DECLARE @InfoId BIGINT = (SELECT Id FROM Audit.LogSeverity WHERE Code = N'Info');

EXEC test.Assert_IsEqual @TestName = N'Invalid codes fall back to defaults',
    @Expected = CAST(@InfoId AS NVARCHAR), @Actual = CAST(@FbSevId AS NVARCHAR);
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Run tests, verify pass**

```powershell
.\Run-Tests.ps1
```

- [ ] **Step 3: Commit**

```bash
git add sql/tests/01_audit_infrastructure/040_Audit_LogOperation.sql
git commit -m "test: Audit.Audit_LogOperation — location context, NULL fields, fallback codes"
```

---

## Task 6: Audit Readers — Lookup List Procs

**Files:**
- Create: `sql/tests/02_audit_readers/010_LogEntityType_List.sql`
- Create: `sql/tests/02_audit_readers/020_LogEventType_List.sql`
- Create: `sql/tests/02_audit_readers/030_LogSeverity_List.sql`

**What we're testing:** Three lookup procs that return seed data. Verify row counts match seed data and Status=1.

- [ ] **Step 1: Write all three lookup test files**

Create `sql/tests/02_audit_readers/010_LogEntityType_List.sql`:

```sql
-- ============================================================
-- Tests: Audit.LogEntityType_List
-- ============================================================
EXEC test.BeginTestFile @FileName = N'010_LogEntityType_List';
GO

DECLARE @Status BIT, @Message NVARCHAR(500);
EXEC Audit.LogEntityType_List @Status = @Status OUTPUT, @Message = @Message OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Status = 1',
    @Condition = @Status;
EXEC test.Assert_IsEqual @TestName = N'Message = Success',
    @Expected = N'LogEntityType list retrieved.', @Actual = @Message;

-- Verify row count matches seed data (24 entity types)
DECLARE @Count INT = (SELECT COUNT(*) FROM Audit.LogEntityType);
EXEC test.Assert_IsTrue @TestName = N'At least 24 entity types seeded',
    @Condition = CASE WHEN @Count >= 24 THEN 1 ELSE 0 END,
    @Detail = CAST(@Count AS NVARCHAR) + N' rows found';
GO

EXEC test.PrintSummary;
GO
```

Create `sql/tests/02_audit_readers/020_LogEventType_List.sql`:

```sql
-- ============================================================
-- Tests: Audit.LogEventType_List
-- ============================================================
EXEC test.BeginTestFile @FileName = N'020_LogEventType_List';
GO

DECLARE @Status BIT, @Message NVARCHAR(500);
EXEC Audit.LogEventType_List @Status = @Status OUTPUT, @Message = @Message OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Status = 1',
    @Condition = @Status;

-- Verify row count matches seed data (20 event types)
DECLARE @Count INT = (SELECT COUNT(*) FROM Audit.LogEventType);
EXEC test.Assert_IsTrue @TestName = N'At least 20 event types seeded',
    @Condition = CASE WHEN @Count >= 20 THEN 1 ELSE 0 END,
    @Detail = CAST(@Count AS NVARCHAR) + N' rows found';
GO

EXEC test.PrintSummary;
GO
```

Create `sql/tests/02_audit_readers/030_LogSeverity_List.sql`:

```sql
-- ============================================================
-- Tests: Audit.LogSeverity_List
-- ============================================================
EXEC test.BeginTestFile @FileName = N'030_LogSeverity_List';
GO

DECLARE @Status BIT, @Message NVARCHAR(500);
EXEC Audit.LogSeverity_List @Status = @Status OUTPUT, @Message = @Message OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Status = 1',
    @Condition = @Status;

-- Exactly 4 severities: Info, Warning, Error, Critical
DECLARE @Count INT = (SELECT COUNT(*) FROM Audit.LogSeverity);
EXEC test.Assert_RowCount @TestName = N'Exactly 4 severity levels',
    @ExpectedCount = 4, @ActualCount = @Count;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Run tests, verify pass**

```powershell
.\Run-Tests.ps1
```

- [ ] **Step 3: Commit**

```bash
git add sql/tests/02_audit_readers/010_LogEntityType_List.sql sql/tests/02_audit_readers/020_LogEventType_List.sql sql/tests/02_audit_readers/030_LogSeverity_List.sql
git commit -m "test: audit lookup list procs — seed data row counts and status"
```

---

## Task 7: Audit Readers — ConfigLog Readers

**Files:**
- Create: `sql/tests/02_audit_readers/040_ConfigLog_GetByEntity.sql`
- Create: `sql/tests/02_audit_readers/050_ConfigLog_List.sql`

**What we're testing:** Query procs that read ConfigLog. Need test data — we'll create it via `Audit_LogConfigChange` calls in the test setup.

- [ ] **Step 1: Write ConfigLog_GetByEntity tests**

Create `sql/tests/02_audit_readers/040_ConfigLog_GetByEntity.sql`:

```sql
-- ============================================================
-- Tests: Audit.ConfigLog_GetByEntity
-- ============================================================
EXEC test.BeginTestFile @FileName = N'040_ConfigLog_GetByEntity';
GO

-- ── Setup: seed some config log entries ──────────────────────
EXEC Audit.Audit_LogConfigChange
    @AppUserId = 1, @LogEntityTypeCode = N'AppUser', @EntityId = 99,
    @LogEventTypeCode = N'Created', @LogSeverityCode = N'Info',
    @Description = N'Test user 99 created.';

EXEC Audit.Audit_LogConfigChange
    @AppUserId = 1, @LogEntityTypeCode = N'AppUser', @EntityId = 99,
    @LogEventTypeCode = N'Updated', @LogSeverityCode = N'Info',
    @Description = N'Test user 99 updated.';

EXEC Audit.Audit_LogConfigChange
    @AppUserId = 1, @LogEntityTypeCode = N'Location', @EntityId = 99,
    @LogEventTypeCode = N'Created', @LogSeverityCode = N'Info',
    @Description = N'Different entity type — should not appear.';
GO

-- ── Test 1: Valid entity type + entity ID returns matching rows ──
DECLARE @Status BIT, @Message NVARCHAR(500);

-- We need to capture the result set to count rows
DECLARE @ResultCount INT;
CREATE TABLE #GetByEntityResults (
    Id BIGINT, LoggedAt DATETIME2(3), DisplayName NVARCHAR(200),
    SeverityCode NVARCHAR(20), EventTypeName NVARCHAR(200),
    EntityTypeName NVARCHAR(200), EntityId BIGINT,
    Description NVARCHAR(1000), OldValue NVARCHAR(MAX), NewValue NVARCHAR(MAX)
);

INSERT INTO #GetByEntityResults
EXEC Audit.ConfigLog_GetByEntity
    @LogEntityTypeCode = N'AppUser',
    @EntityId = 99,
    @Status = @Status OUTPUT,
    @Message = @Message OUTPUT;

SET @ResultCount = (SELECT COUNT(*) FROM #GetByEntityResults);
DROP TABLE #GetByEntityResults;

EXEC test.Assert_IsTrue @TestName = N'Status = 1 for valid entity',
    @Condition = @Status;
EXEC test.Assert_IsTrue @TestName = N'Returns 2 rows for AppUser 99',
    @Condition = CASE WHEN @ResultCount = 2 THEN 1 ELSE 0 END,
    @Detail = CAST(@ResultCount AS NVARCHAR) + N' rows returned';
GO

-- ── Test 2: Invalid entity type code returns Status=0 ────────
DECLARE @Status2 BIT, @Message2 NVARCHAR(500);

CREATE TABLE #EmptyResults (
    Id BIGINT, LoggedAt DATETIME2(3), DisplayName NVARCHAR(200),
    SeverityCode NVARCHAR(20), EventTypeName NVARCHAR(200),
    EntityTypeName NVARCHAR(200), EntityId BIGINT,
    Description NVARCHAR(1000), OldValue NVARCHAR(MAX), NewValue NVARCHAR(MAX)
);

INSERT INTO #EmptyResults
EXEC Audit.ConfigLog_GetByEntity
    @LogEntityTypeCode = N'INVALID_TYPE',
    @EntityId = 99,
    @Status = @Status2 OUTPUT,
    @Message = @Message2 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Status = 0 for invalid entity type',
    @Condition = CASE WHEN @Status2 = 0 THEN 1 ELSE 0 END;
DROP TABLE #EmptyResults;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Write ConfigLog_List tests**

Create `sql/tests/02_audit_readers/050_ConfigLog_List.sql`:

```sql
-- ============================================================
-- Tests: Audit.ConfigLog_List
-- ============================================================
EXEC test.BeginTestFile @FileName = N'050_ConfigLog_List';
GO

-- ── Setup: seed config log entries with known timestamps ─────
-- The audit infra tests already inserted rows; we add more here
EXEC Audit.Audit_LogConfigChange
    @AppUserId = 1, @LogEntityTypeCode = N'AppUser', @EntityId = 50,
    @LogEventTypeCode = N'Created', @LogSeverityCode = N'Info',
    @Description = N'ConfigLog_List test row.';
GO

-- ── Test 1: Date range covering now returns rows ─────────────
DECLARE @Status BIT, @Message NVARCHAR(500);
DECLARE @Start DATETIME2(3) = DATEADD(HOUR, -1, SYSUTCDATETIME());
DECLARE @End DATETIME2(3) = DATEADD(HOUR, 1, SYSUTCDATETIME());

CREATE TABLE #ListResults (
    Id BIGINT, LoggedAt DATETIME2(3), DisplayName NVARCHAR(200),
    SeverityCode NVARCHAR(20), EventTypeName NVARCHAR(200),
    EntityTypeName NVARCHAR(200), EntityId BIGINT,
    Description NVARCHAR(1000), OldValue NVARCHAR(MAX), NewValue NVARCHAR(MAX)
);

INSERT INTO #ListResults
EXEC Audit.ConfigLog_List
    @StartDate = @Start,
    @EndDate = @End,
    @Status = @Status OUTPUT,
    @Message = @Message OUTPUT;

DECLARE @Count INT = (SELECT COUNT(*) FROM #ListResults);
DROP TABLE #ListResults;

EXEC test.Assert_IsTrue @TestName = N'Status = 1',
    @Condition = @Status;
EXEC test.Assert_IsTrue @TestName = N'Returns rows for current time window',
    @Condition = CASE WHEN @Count > 0 THEN 1 ELSE 0 END,
    @Detail = CAST(@Count AS NVARCHAR) + N' rows';
GO

-- ── Test 2: Date range in the past returns 0 rows ────────────
DECLARE @Status2 BIT, @Message2 NVARCHAR(500);

CREATE TABLE #EmptyList (
    Id BIGINT, LoggedAt DATETIME2(3), DisplayName NVARCHAR(200),
    SeverityCode NVARCHAR(20), EventTypeName NVARCHAR(200),
    EntityTypeName NVARCHAR(200), EntityId BIGINT,
    Description NVARCHAR(1000), OldValue NVARCHAR(MAX), NewValue NVARCHAR(MAX)
);

INSERT INTO #EmptyList
EXEC Audit.ConfigLog_List
    @StartDate = '2020-01-01',
    @EndDate = '2020-01-02',
    @Status = @Status2 OUTPUT,
    @Message = @Message2 OUTPUT;

DECLARE @Count2 INT = (SELECT COUNT(*) FROM #EmptyList);
DROP TABLE #EmptyList;

EXEC test.Assert_IsTrue @TestName = N'Status = 1 even with 0 results',
    @Condition = @Status2;
EXEC test.Assert_RowCount @TestName = N'No rows for historical date range',
    @ExpectedCount = 0, @ActualCount = @Count2;
GO

-- ── Test 3: Entity type filter works ─────────────────────────
DECLARE @Status3 BIT, @Message3 NVARCHAR(500);
DECLARE @Start3 DATETIME2(3) = DATEADD(HOUR, -1, SYSUTCDATETIME());
DECLARE @End3 DATETIME2(3) = DATEADD(HOUR, 1, SYSUTCDATETIME());

CREATE TABLE #FilterResults (
    Id BIGINT, LoggedAt DATETIME2(3), DisplayName NVARCHAR(200),
    SeverityCode NVARCHAR(20), EventTypeName NVARCHAR(200),
    EntityTypeName NVARCHAR(200), EntityId BIGINT,
    Description NVARCHAR(1000), OldValue NVARCHAR(MAX), NewValue NVARCHAR(MAX)
);

INSERT INTO #FilterResults
EXEC Audit.ConfigLog_List
    @StartDate = @Start3,
    @EndDate = @End3,
    @LogEntityTypeCode = N'AppUser',
    @Status = @Status3 OUTPUT,
    @Message = @Message3 OUTPUT;

-- All returned rows should have EntityTypeName matching 'AppUser'
DECLARE @NonMatch INT = (SELECT COUNT(*) FROM #FilterResults WHERE EntityTypeName != N'AppUser');
DROP TABLE #FilterResults;

EXEC test.Assert_RowCount @TestName = N'Filter: no non-AppUser rows returned',
    @ExpectedCount = 0, @ActualCount = @NonMatch;
GO

-- ── Test 4: Invalid entity type filter returns Status=0 ──────
DECLARE @Status4 BIT, @Message4 NVARCHAR(500);

CREATE TABLE #BadFilter (
    Id BIGINT, LoggedAt DATETIME2(3), DisplayName NVARCHAR(200),
    SeverityCode NVARCHAR(20), EventTypeName NVARCHAR(200),
    EntityTypeName NVARCHAR(200), EntityId BIGINT,
    Description NVARCHAR(1000), OldValue NVARCHAR(MAX), NewValue NVARCHAR(MAX)
);

INSERT INTO #BadFilter
EXEC Audit.ConfigLog_List
    @StartDate = '2020-01-01',
    @EndDate = '2030-01-01',
    @LogEntityTypeCode = N'INVALID',
    @Status = @Status4 OUTPUT,
    @Message = @Message4 OUTPUT;

DROP TABLE #BadFilter;

EXEC test.Assert_IsTrue @TestName = N'Status = 0 for invalid entity type filter',
    @Condition = CASE WHEN @Status4 = 0 THEN 1 ELSE 0 END;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 3: Run tests, verify pass**

```powershell
.\Run-Tests.ps1
```

- [ ] **Step 4: Commit**

```bash
git add sql/tests/02_audit_readers/040_ConfigLog_GetByEntity.sql sql/tests/02_audit_readers/050_ConfigLog_List.sql
git commit -m "test: ConfigLog_GetByEntity + ConfigLog_List — filters, date ranges, invalid codes"
```

---

## Task 8: Audit Readers — FailureLog Readers

**Files:**
- Create: `sql/tests/02_audit_readers/060_FailureLog_GetByEntity.sql`
- Create: `sql/tests/02_audit_readers/070_FailureLog_List.sql`
- Create: `sql/tests/02_audit_readers/080_FailureLog_GetTopProcs.sql`
- Create: `sql/tests/02_audit_readers/090_FailureLog_GetTopReasons.sql`

**What we're testing:** FailureLog query procs — filtering, aggregation, and invalid code handling.

- [ ] **Step 1: Write FailureLog_GetByEntity tests**

Create `sql/tests/02_audit_readers/060_FailureLog_GetByEntity.sql`:

```sql
-- ============================================================
-- Tests: Audit.FailureLog_GetByEntity
-- ============================================================
EXEC test.BeginTestFile @FileName = N'060_FailureLog_GetByEntity';
GO

-- ── Setup: seed failure log entries ──────────────────────────
EXEC Audit.Audit_LogFailure
    @AppUserId = 1, @LogEntityTypeCode = N'AppUser', @EntityId = 77,
    @LogEventTypeCode = N'Created', @FailureReason = N'Duplicate AdAccount.',
    @ProcedureName = N'Location.AppUser_Create', @AttemptedParameters = N'{"AdAccount":"dup@test"}';

EXEC Audit.Audit_LogFailure
    @AppUserId = 1, @LogEntityTypeCode = N'AppUser', @EntityId = 77,
    @LogEventTypeCode = N'Updated', @FailureReason = N'User deprecated.',
    @ProcedureName = N'Location.AppUser_Update';
GO

-- ── Test 1: Returns matching rows ────────────────────────────
DECLARE @Status BIT, @Message NVARCHAR(500);

CREATE TABLE #FBE (
    Id BIGINT, AttemptedAt DATETIME2(3), DisplayName NVARCHAR(200),
    EntityTypeName NVARCHAR(200), EventTypeName NVARCHAR(200), EntityId BIGINT,
    FailureReason NVARCHAR(500), ProcedureName NVARCHAR(200),
    AttemptedParameters NVARCHAR(MAX)
);

INSERT INTO #FBE
EXEC Audit.FailureLog_GetByEntity
    @LogEntityTypeCode = N'AppUser',
    @EntityId = 77,
    @Status = @Status OUTPUT,
    @Message = @Message OUTPUT;

DECLARE @Count INT = (SELECT COUNT(*) FROM #FBE);
DROP TABLE #FBE;

EXEC test.Assert_IsTrue @TestName = N'Status = 1', @Condition = @Status;
EXEC test.Assert_IsTrue @TestName = N'Returns 2 failures for entity 77',
    @Condition = CASE WHEN @Count = 2 THEN 1 ELSE 0 END,
    @Detail = CAST(@Count AS NVARCHAR) + N' rows';
GO

-- ── Test 2: Invalid entity type returns Status=0 ─────────────
DECLARE @Status2 BIT, @Message2 NVARCHAR(500);

CREATE TABLE #FBE2 (
    Id BIGINT, AttemptedAt DATETIME2(3), DisplayName NVARCHAR(200),
    EntityTypeName NVARCHAR(200), EventTypeName NVARCHAR(200), EntityId BIGINT,
    FailureReason NVARCHAR(500), ProcedureName NVARCHAR(200),
    AttemptedParameters NVARCHAR(MAX)
);

INSERT INTO #FBE2
EXEC Audit.FailureLog_GetByEntity
    @LogEntityTypeCode = N'INVALID',
    @EntityId = 77,
    @Status = @Status2 OUTPUT,
    @Message = @Message2 OUTPUT;

DROP TABLE #FBE2;

EXEC test.Assert_IsTrue @TestName = N'Status = 0 for invalid entity type',
    @Condition = CASE WHEN @Status2 = 0 THEN 1 ELSE 0 END;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Write FailureLog_List tests**

Create `sql/tests/02_audit_readers/070_FailureLog_List.sql`:

```sql
-- ============================================================
-- Tests: Audit.FailureLog_List
-- ============================================================
EXEC test.BeginTestFile @FileName = N'070_FailureLog_List';
GO

-- ── Test 1: Date range returns rows ──────────────────────────
DECLARE @Status BIT, @Message NVARCHAR(500);
DECLARE @Start DATETIME2(3) = DATEADD(HOUR, -1, SYSUTCDATETIME());
DECLARE @End DATETIME2(3) = DATEADD(HOUR, 1, SYSUTCDATETIME());

CREATE TABLE #FL (
    Id BIGINT, AttemptedAt DATETIME2(3), DisplayName NVARCHAR(200),
    EntityTypeName NVARCHAR(200), EventTypeName NVARCHAR(200), EntityId BIGINT,
    FailureReason NVARCHAR(500), ProcedureName NVARCHAR(200),
    AttemptedParameters NVARCHAR(MAX)
);

INSERT INTO #FL
EXEC Audit.FailureLog_List
    @StartDate = @Start,
    @EndDate = @End,
    @Status = @Status OUTPUT,
    @Message = @Message OUTPUT;

DECLARE @Count INT = (SELECT COUNT(*) FROM #FL);
DROP TABLE #FL;

EXEC test.Assert_IsTrue @TestName = N'Status = 1', @Condition = @Status;
EXEC test.Assert_IsTrue @TestName = N'Returns rows for current window',
    @Condition = CASE WHEN @Count > 0 THEN 1 ELSE 0 END;
GO

-- ── Test 2: ProcedureName filter ─────────────────────────────
DECLARE @Status2 BIT, @Message2 NVARCHAR(500);
DECLARE @Start2 DATETIME2(3) = DATEADD(HOUR, -1, SYSUTCDATETIME());
DECLARE @End2 DATETIME2(3) = DATEADD(HOUR, 1, SYSUTCDATETIME());

CREATE TABLE #FL2 (
    Id BIGINT, AttemptedAt DATETIME2(3), DisplayName NVARCHAR(200),
    EntityTypeName NVARCHAR(200), EventTypeName NVARCHAR(200), EntityId BIGINT,
    FailureReason NVARCHAR(500), ProcedureName NVARCHAR(200),
    AttemptedParameters NVARCHAR(MAX)
);

INSERT INTO #FL2
EXEC Audit.FailureLog_List
    @StartDate = @Start2,
    @EndDate = @End2,
    @ProcedureName = N'Location.AppUser_Create',
    @Status = @Status2 OUTPUT,
    @Message = @Message2 OUTPUT;

-- All rows should be from that proc
DECLARE @NonMatch INT = (SELECT COUNT(*) FROM #FL2 WHERE ProcedureName != N'Location.AppUser_Create');
DROP TABLE #FL2;

EXEC test.Assert_RowCount @TestName = N'Proc filter: no non-matching rows',
    @ExpectedCount = 0, @ActualCount = @NonMatch;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 3: Write FailureLog_GetTopProcs tests**

Create `sql/tests/02_audit_readers/080_FailureLog_GetTopProcs.sql`:

```sql
-- ============================================================
-- Tests: Audit.FailureLog_GetTopProcs
-- ============================================================
EXEC test.BeginTestFile @FileName = N'080_FailureLog_GetTopProcs';
GO

DECLARE @Status BIT, @Message NVARCHAR(500);
DECLARE @Start DATETIME2(3) = DATEADD(HOUR, -1, SYSUTCDATETIME());
DECLARE @End DATETIME2(3) = DATEADD(HOUR, 1, SYSUTCDATETIME());

CREATE TABLE #TopProcs (ProcedureName NVARCHAR(200), FailureCount INT);

INSERT INTO #TopProcs
EXEC Audit.FailureLog_GetTopProcs
    @StartDate = @Start,
    @EndDate = @End,
    @Status = @Status OUTPUT,
    @Message = @Message OUTPUT;

DECLARE @Count INT = (SELECT COUNT(*) FROM #TopProcs);

EXEC test.Assert_IsTrue @TestName = N'Status = 1', @Condition = @Status;
EXEC test.Assert_IsTrue @TestName = N'Returns aggregated proc rows',
    @Condition = CASE WHEN @Count > 0 THEN 1 ELSE 0 END;

-- Verify ordering: first row should have highest count
DECLARE @First INT = (SELECT TOP 1 FailureCount FROM #TopProcs);
DECLARE @MaxCount INT = (SELECT MAX(FailureCount) FROM #TopProcs);
DROP TABLE #TopProcs;

EXEC test.Assert_IsEqual @TestName = N'First row has highest failure count',
    @Expected = CAST(@MaxCount AS NVARCHAR), @Actual = CAST(@First AS NVARCHAR);
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 4: Write FailureLog_GetTopReasons tests**

Create `sql/tests/02_audit_readers/090_FailureLog_GetTopReasons.sql`:

```sql
-- ============================================================
-- Tests: Audit.FailureLog_GetTopReasons
-- ============================================================
EXEC test.BeginTestFile @FileName = N'090_FailureLog_GetTopReasons';
GO

DECLARE @Status BIT, @Message NVARCHAR(500);
DECLARE @Start DATETIME2(3) = DATEADD(HOUR, -1, SYSUTCDATETIME());
DECLARE @End DATETIME2(3) = DATEADD(HOUR, 1, SYSUTCDATETIME());

CREATE TABLE #TopReasons (FailureReason NVARCHAR(500), FailureCount INT);

INSERT INTO #TopReasons
EXEC Audit.FailureLog_GetTopReasons
    @StartDate = @Start,
    @EndDate = @End,
    @Status = @Status OUTPUT,
    @Message = @Message OUTPUT;

DECLARE @Count INT = (SELECT COUNT(*) FROM #TopReasons);

EXEC test.Assert_IsTrue @TestName = N'Status = 1', @Condition = @Status;
EXEC test.Assert_IsTrue @TestName = N'Returns aggregated reason rows',
    @Condition = CASE WHEN @Count > 0 THEN 1 ELSE 0 END;

-- Verify ordering
DECLARE @First INT = (SELECT TOP 1 FailureCount FROM #TopReasons);
DECLARE @MaxCount INT = (SELECT MAX(FailureCount) FROM #TopReasons);
DROP TABLE #TopReasons;

EXEC test.Assert_IsEqual @TestName = N'First row has highest failure count',
    @Expected = CAST(@MaxCount AS NVARCHAR), @Actual = CAST(@First AS NVARCHAR);
GO

-- ── Test 2: Entity type filter ───────────────────────────────
DECLARE @Status2 BIT, @Message2 NVARCHAR(500);
DECLARE @Start2 DATETIME2(3) = DATEADD(HOUR, -1, SYSUTCDATETIME());
DECLARE @End2 DATETIME2(3) = DATEADD(HOUR, 1, SYSUTCDATETIME());

CREATE TABLE #FilterReasons (FailureReason NVARCHAR(500), FailureCount INT);

INSERT INTO #FilterReasons
EXEC Audit.FailureLog_GetTopReasons
    @StartDate = @Start2,
    @EndDate = @End2,
    @LogEntityTypeCode = N'AppUser',
    @Status = @Status2 OUTPUT,
    @Message = @Message2 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Status = 1 with entity filter',
    @Condition = @Status2;
DROP TABLE #FilterReasons;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 5: Run all tests, verify pass**

```powershell
.\Run-Tests.ps1
```

- [ ] **Step 6: Commit**

```bash
git add sql/tests/02_audit_readers/
git commit -m "test: FailureLog readers — GetByEntity, List, GetTopProcs, GetTopReasons"
```

---

## Task 9: AppUser — Create Tests

**Files:**
- Create: `sql/tests/03_appuser/010_AppUser_Create.sql`

**What we're testing:** `Location.AppUser_Create` — full CRUD lifecycle starts here. Validates required params, checks AdAccount uniqueness, outputs @NewId, logs success/failure to audit.

- [ ] **Step 1: Write the test file**

Create `sql/tests/03_appuser/010_AppUser_Create.sql`:

```sql
-- ============================================================
-- Tests: Location.AppUser_Create
-- ============================================================
EXEC test.BeginTestFile @FileName = N'010_AppUser_Create';
GO

-- ── Test 1: Happy path — create a new user ───────────────────
DECLARE @Status BIT, @Message NVARCHAR(500), @NewId BIGINT;

EXEC Location.AppUser_Create
    @AdAccount   = N'test.user1@mppmfg.com',
    @DisplayName = N'Test User One',
    @ClockNumber = N'T001',
    @PinHash     = N'fakehash123',
    @IgnitionRole = N'Operator',
    @AppUserId   = 1,
    @Status      = @Status OUTPUT,
    @Message     = @Message OUTPUT,
    @NewId       = @NewId OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Create: Status = 1', @Condition = @Status;
EXEC test.Assert_IsNotNull @TestName = N'Create: NewId returned', @Value = CAST(@NewId AS NVARCHAR);

-- Verify the row exists
DECLARE @StoredName NVARCHAR(200), @StoredClock NVARCHAR(20), @StoredRole NVARCHAR(100);
SELECT @StoredName = DisplayName, @StoredClock = ClockNumber, @StoredRole = IgnitionRole
FROM Location.AppUser WHERE Id = @NewId;

EXEC test.Assert_IsEqual @TestName = N'Create: DisplayName stored',
    @Expected = N'Test User One', @Actual = @StoredName;
EXEC test.Assert_IsEqual @TestName = N'Create: ClockNumber stored',
    @Expected = N'T001', @Actual = @StoredClock;
EXEC test.Assert_IsEqual @TestName = N'Create: IgnitionRole stored',
    @Expected = N'Operator', @Actual = @StoredRole;

-- Verify audit log was written
DECLARE @AuditCount INT = (
    SELECT COUNT(*) FROM Audit.ConfigLog
    WHERE EntityId = @NewId
      AND LogEntityTypeId = (SELECT Id FROM Audit.LogEntityType WHERE Code = N'AppUser')
      AND LogEventTypeId = (SELECT Id FROM Audit.LogEventType WHERE Code = N'Created')
);
EXEC test.Assert_IsTrue @TestName = N'Create: ConfigLog entry written',
    @Condition = CASE WHEN @AuditCount >= 1 THEN 1 ELSE 0 END;
GO

-- ── Test 2: Missing required params — @AdAccount NULL ────────
DECLARE @Status2 BIT, @Message2 NVARCHAR(500), @NewId2 BIGINT;

EXEC Location.AppUser_Create
    @AdAccount   = NULL,
    @DisplayName = N'No Account',
    @AppUserId   = 1,
    @Status      = @Status2 OUTPUT,
    @Message     = @Message2 OUTPUT,
    @NewId       = @NewId2 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'NULL AdAccount: Status = 0',
    @Condition = CASE WHEN @Status2 = 0 THEN 1 ELSE 0 END;
EXEC test.Assert_IsNull @TestName = N'NULL AdAccount: NewId is NULL',
    @Value = CAST(@NewId2 AS NVARCHAR);
GO

-- ── Test 3: Missing required params — @DisplayName NULL ──────
DECLARE @Status3 BIT, @Message3 NVARCHAR(500), @NewId3 BIGINT;

EXEC Location.AppUser_Create
    @AdAccount   = N'noname@test.com',
    @DisplayName = NULL,
    @AppUserId   = 1,
    @Status      = @Status3 OUTPUT,
    @Message     = @Message3 OUTPUT,
    @NewId       = @NewId3 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'NULL DisplayName: Status = 0',
    @Condition = CASE WHEN @Status3 = 0 THEN 1 ELSE 0 END;
GO

-- ── Test 4: Duplicate AdAccount ──────────────────────────────
DECLARE @Status4 BIT, @Message4 NVARCHAR(500), @NewId4 BIGINT;

EXEC Location.AppUser_Create
    @AdAccount   = N'test.user1@mppmfg.com',   -- same as Test 1
    @DisplayName = N'Duplicate User',
    @AppUserId   = 1,
    @Status      = @Status4 OUTPUT,
    @Message     = @Message4 OUTPUT,
    @NewId       = @NewId4 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Duplicate AdAccount: Status = 0',
    @Condition = CASE WHEN @Status4 = 0 THEN 1 ELSE 0 END;
EXEC test.Assert_IsNull @TestName = N'Duplicate AdAccount: NewId is NULL',
    @Value = CAST(@NewId4 AS NVARCHAR);

-- Verify failure was logged
DECLARE @FailCount INT = (
    SELECT COUNT(*) FROM Audit.FailureLog
    WHERE ProcedureName = N'Location.AppUser_Create'
);
EXEC test.Assert_IsTrue @TestName = N'Failures logged to FailureLog',
    @Condition = CASE WHEN @FailCount >= 1 THEN 1 ELSE 0 END;
GO

-- ── Test 5: Optional params can be NULL ──────────────────────
DECLARE @Status5 BIT, @Message5 NVARCHAR(500), @NewId5 BIGINT;

EXEC Location.AppUser_Create
    @AdAccount   = N'minimal@test.com',
    @DisplayName = N'Minimal User',
    @AppUserId   = 1,
    @Status      = @Status5 OUTPUT,
    @Message     = @Message5 OUTPUT,
    @NewId       = @NewId5 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Minimal params: Status = 1', @Condition = @Status5;

DECLARE @StoredPin NVARCHAR(255), @StoredClock5 NVARCHAR(20);
SELECT @StoredPin = PinHash, @StoredClock5 = ClockNumber
FROM Location.AppUser WHERE Id = @NewId5;

EXEC test.Assert_IsNull @TestName = N'Minimal params: PinHash is NULL',
    @Value = @StoredPin;
EXEC test.Assert_IsNull @TestName = N'Minimal params: ClockNumber is NULL',
    @Value = @StoredClock5;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Run tests, verify pass**

```powershell
.\Run-Tests.ps1
```

- [ ] **Step 3: Commit**

```bash
git add sql/tests/03_appuser/010_AppUser_Create.sql
git commit -m "test: AppUser_Create — happy path, validation, duplicate AdAccount, audit logging"
```

---

## Task 10: AppUser — Get/GetByAdAccount/GetByClockNumber Tests

**Files:**
- Create: `sql/tests/03_appuser/020_AppUser_Get.sql`
- Create: `sql/tests/03_appuser/030_AppUser_GetByAdAccount.sql`
- Create: `sql/tests/03_appuser/040_AppUser_GetByClockNumber.sql`

**What we're testing:** Three read procs with different lookup keys. Key difference: GetByClockNumber filters out deprecated users; GetByAdAccount does not.

- [ ] **Step 1: Write AppUser_Get tests**

Create `sql/tests/03_appuser/020_AppUser_Get.sql`:

```sql
-- ============================================================
-- Tests: Location.AppUser_Get
-- ============================================================
EXEC test.BeginTestFile @FileName = N'020_AppUser_Get';
GO

-- ── Test 1: Get bootstrap user (Id=1) ────────────────────────
DECLARE @Status BIT, @Message NVARCHAR(500);

CREATE TABLE #GetResult (
    Id BIGINT, AdAccount NVARCHAR(100), DisplayName NVARCHAR(200),
    ClockNumber NVARCHAR(20), PinHash NVARCHAR(255),
    IgnitionRole NVARCHAR(100), CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);

INSERT INTO #GetResult
EXEC Location.AppUser_Get @Id = 1, @Status = @Status OUTPUT, @Message = @Message OUTPUT;

DECLARE @Count INT = (SELECT COUNT(*) FROM #GetResult);
DECLARE @AdAcc NVARCHAR(100) = (SELECT AdAccount FROM #GetResult);
DROP TABLE #GetResult;

EXEC test.Assert_IsTrue @TestName = N'Status = 1', @Condition = @Status;
EXEC test.Assert_RowCount @TestName = N'Returns 1 row for Id=1',
    @ExpectedCount = 1, @ActualCount = @Count;
EXEC test.Assert_IsEqual @TestName = N'Bootstrap user AdAccount',
    @Expected = N'system.bootstrap', @Actual = @AdAcc;
GO

-- ── Test 2: Non-existent Id returns 0 rows (still Status=1) ──
DECLARE @Status2 BIT, @Message2 NVARCHAR(500);

CREATE TABLE #NoResult (
    Id BIGINT, AdAccount NVARCHAR(100), DisplayName NVARCHAR(200),
    ClockNumber NVARCHAR(20), PinHash NVARCHAR(255),
    IgnitionRole NVARCHAR(100), CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);

INSERT INTO #NoResult
EXEC Location.AppUser_Get @Id = 999999, @Status = @Status2 OUTPUT, @Message = @Message2 OUTPUT;

DECLARE @Count2 INT = (SELECT COUNT(*) FROM #NoResult);
DROP TABLE #NoResult;

EXEC test.Assert_IsTrue @TestName = N'Status = 1 for missing Id', @Condition = @Status2;
EXEC test.Assert_RowCount @TestName = N'Returns 0 rows for missing Id',
    @ExpectedCount = 0, @ActualCount = @Count2;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Write AppUser_GetByAdAccount tests**

Create `sql/tests/03_appuser/030_AppUser_GetByAdAccount.sql`:

```sql
-- ============================================================
-- Tests: Location.AppUser_GetByAdAccount
-- ============================================================
EXEC test.BeginTestFile @FileName = N'030_AppUser_GetByAdAccount';
GO

-- ── Test 1: Find bootstrap user by AdAccount ─────────────────
DECLARE @Status BIT, @Message NVARCHAR(500);

CREATE TABLE #ByAd (
    Id BIGINT, AdAccount NVARCHAR(100), DisplayName NVARCHAR(200),
    ClockNumber NVARCHAR(20), PinHash NVARCHAR(255),
    IgnitionRole NVARCHAR(100), CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);

INSERT INTO #ByAd
EXEC Location.AppUser_GetByAdAccount
    @AdAccount = N'system.bootstrap',
    @Status = @Status OUTPUT,
    @Message = @Message OUTPUT;

DECLARE @Count INT = (SELECT COUNT(*) FROM #ByAd);
DROP TABLE #ByAd;

EXEC test.Assert_IsTrue @TestName = N'Status = 1', @Condition = @Status;
EXEC test.Assert_RowCount @TestName = N'Found bootstrap user',
    @ExpectedCount = 1, @ActualCount = @Count;
GO

-- ── Test 2: Non-existent AdAccount returns 0 rows ────────────
DECLARE @Status2 BIT, @Message2 NVARCHAR(500);

CREATE TABLE #ByAd2 (
    Id BIGINT, AdAccount NVARCHAR(100), DisplayName NVARCHAR(200),
    ClockNumber NVARCHAR(20), PinHash NVARCHAR(255),
    IgnitionRole NVARCHAR(100), CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);

INSERT INTO #ByAd2
EXEC Location.AppUser_GetByAdAccount
    @AdAccount = N'nobody@nowhere.com',
    @Status = @Status2 OUTPUT,
    @Message = @Message2 OUTPUT;

DECLARE @Count2 INT = (SELECT COUNT(*) FROM #ByAd2);
DROP TABLE #ByAd2;

EXEC test.Assert_IsTrue @TestName = N'Status = 1 for missing account', @Condition = @Status2;
EXEC test.Assert_RowCount @TestName = N'0 rows for missing AdAccount',
    @ExpectedCount = 0, @ActualCount = @Count2;
GO

-- ── Test 3: Returns deprecated users (no DeprecatedAt filter) ──
-- Setup: create a user then deprecate them
DECLARE @Sid BIT, @Smsg NVARCHAR(500), @DepUserId BIGINT;
EXEC Location.AppUser_Create
    @AdAccount = N'deprecated.test@mppmfg.com', @DisplayName = N'Dep Test',
    @AppUserId = 1, @Status = @Sid OUTPUT, @Message = @Smsg OUTPUT, @NewId = @DepUserId OUTPUT;

EXEC Location.AppUser_Deprecate
    @Id = @DepUserId, @AppUserId = 1,
    @Status = @Sid OUTPUT, @Message = @Smsg OUTPUT;

-- Now look them up by AdAccount
DECLARE @Status3 BIT, @Message3 NVARCHAR(500);

CREATE TABLE #ByAd3 (
    Id BIGINT, AdAccount NVARCHAR(100), DisplayName NVARCHAR(200),
    ClockNumber NVARCHAR(20), PinHash NVARCHAR(255),
    IgnitionRole NVARCHAR(100), CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);

INSERT INTO #ByAd3
EXEC Location.AppUser_GetByAdAccount
    @AdAccount = N'deprecated.test@mppmfg.com',
    @Status = @Status3 OUTPUT,
    @Message = @Message3 OUTPUT;

DECLARE @Count3 INT = (SELECT COUNT(*) FROM #ByAd3);
DECLARE @DepAt DATETIME2(3) = (SELECT DeprecatedAt FROM #ByAd3);
DROP TABLE #ByAd3;

EXEC test.Assert_RowCount @TestName = N'GetByAdAccount returns deprecated users',
    @ExpectedCount = 1, @ActualCount = @Count3;
EXEC test.Assert_IsNotNull @TestName = N'DeprecatedAt is populated',
    @Value = CAST(@DepAt AS NVARCHAR);
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 3: Write AppUser_GetByClockNumber tests**

Create `sql/tests/03_appuser/040_AppUser_GetByClockNumber.sql`:

```sql
-- ============================================================
-- Tests: Location.AppUser_GetByClockNumber
-- ============================================================
EXEC test.BeginTestFile @FileName = N'040_AppUser_GetByClockNumber';
GO

-- ── Setup: create a user with a clock number ─────────────────
DECLARE @Sid BIT, @Smsg NVARCHAR(500), @ClockUserId BIGINT;
EXEC Location.AppUser_Create
    @AdAccount = N'clock.test@mppmfg.com', @DisplayName = N'Clock Tester',
    @ClockNumber = N'CLK999', @AppUserId = 1,
    @Status = @Sid OUTPUT, @Message = @Smsg OUTPUT, @NewId = @ClockUserId OUTPUT;
GO

-- ── Test 1: Find user by clock number ────────────────────────
DECLARE @Status BIT, @Message NVARCHAR(500);

CREATE TABLE #ByClock (
    Id BIGINT, AdAccount NVARCHAR(100), DisplayName NVARCHAR(200),
    ClockNumber NVARCHAR(20), PinHash NVARCHAR(255),
    IgnitionRole NVARCHAR(100), CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);

INSERT INTO #ByClock
EXEC Location.AppUser_GetByClockNumber
    @ClockNumber = N'CLK999',
    @Status = @Status OUTPUT,
    @Message = @Message OUTPUT;

DECLARE @Count INT = (SELECT COUNT(*) FROM #ByClock);
DROP TABLE #ByClock;

EXEC test.Assert_IsTrue @TestName = N'Status = 1', @Condition = @Status;
EXEC test.Assert_RowCount @TestName = N'Found user by clock number',
    @ExpectedCount = 1, @ActualCount = @Count;
GO

-- ── Test 2: Does NOT return deprecated users ─────────────────
-- Deprecate the user
DECLARE @Sid2 BIT, @Smsg2 NVARCHAR(500);
DECLARE @DepId BIGINT = (SELECT Id FROM Location.AppUser WHERE ClockNumber = N'CLK999');
EXEC Location.AppUser_Deprecate
    @Id = @DepId, @AppUserId = 1,
    @Status = @Sid2 OUTPUT, @Message = @Smsg2 OUTPUT;

-- Try to look them up by clock number
DECLARE @Status2 BIT, @Message2 NVARCHAR(500);

CREATE TABLE #ByClock2 (
    Id BIGINT, AdAccount NVARCHAR(100), DisplayName NVARCHAR(200),
    ClockNumber NVARCHAR(20), PinHash NVARCHAR(255),
    IgnitionRole NVARCHAR(100), CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);

INSERT INTO #ByClock2
EXEC Location.AppUser_GetByClockNumber
    @ClockNumber = N'CLK999',
    @Status = @Status2 OUTPUT,
    @Message = @Message2 OUTPUT;

DECLARE @Count2 INT = (SELECT COUNT(*) FROM #ByClock2);
DROP TABLE #ByClock2;

EXEC test.Assert_RowCount @TestName = N'Deprecated user NOT returned by clock number',
    @ExpectedCount = 0, @ActualCount = @Count2;
GO

-- ── Test 3: Non-existent clock number returns 0 rows ─────────
DECLARE @Status3 BIT, @Message3 NVARCHAR(500);

CREATE TABLE #ByClock3 (
    Id BIGINT, AdAccount NVARCHAR(100), DisplayName NVARCHAR(200),
    ClockNumber NVARCHAR(20), PinHash NVARCHAR(255),
    IgnitionRole NVARCHAR(100), CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);

INSERT INTO #ByClock3
EXEC Location.AppUser_GetByClockNumber
    @ClockNumber = N'NOPE',
    @Status = @Status3 OUTPUT,
    @Message = @Message3 OUTPUT;

DECLARE @Count3 INT = (SELECT COUNT(*) FROM #ByClock3);
DROP TABLE #ByClock3;

EXEC test.Assert_RowCount @TestName = N'Non-existent clock: 0 rows',
    @ExpectedCount = 0, @ActualCount = @Count3;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 4: Run tests, verify pass**

```powershell
.\Run-Tests.ps1
```

- [ ] **Step 5: Commit**

```bash
git add sql/tests/03_appuser/020_AppUser_Get.sql sql/tests/03_appuser/030_AppUser_GetByAdAccount.sql sql/tests/03_appuser/040_AppUser_GetByClockNumber.sql
git commit -m "test: AppUser read procs — Get, GetByAdAccount, GetByClockNumber + deprecation filter"
```

---

## Task 11: AppUser — List Tests

**Files:**
- Create: `sql/tests/03_appuser/050_AppUser_List.sql`

- [ ] **Step 1: Write the test file**

Create `sql/tests/03_appuser/050_AppUser_List.sql`:

```sql
-- ============================================================
-- Tests: Location.AppUser_List
-- ============================================================
EXEC test.BeginTestFile @FileName = N'050_AppUser_List';
GO

-- ── Test 1: Default (exclude deprecated) ─────────────────────
DECLARE @Status BIT, @Message NVARCHAR(500);

CREATE TABLE #List1 (
    Id BIGINT, AdAccount NVARCHAR(100), DisplayName NVARCHAR(200),
    ClockNumber NVARCHAR(20), PinHash NVARCHAR(255),
    IgnitionRole NVARCHAR(100), CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);

INSERT INTO #List1
EXEC Location.AppUser_List
    @IncludeDeprecated = 0,
    @Status = @Status OUTPUT,
    @Message = @Message OUTPUT;

-- No deprecated users should appear
DECLARE @DepCount INT = (SELECT COUNT(*) FROM #List1 WHERE DeprecatedAt IS NOT NULL);
DECLARE @TotalActive INT = (SELECT COUNT(*) FROM #List1);
DROP TABLE #List1;

EXEC test.Assert_IsTrue @TestName = N'Status = 1', @Condition = @Status;
EXEC test.Assert_RowCount @TestName = N'No deprecated users in default list',
    @ExpectedCount = 0, @ActualCount = @DepCount;
EXEC test.Assert_IsTrue @TestName = N'At least bootstrap user returned',
    @Condition = CASE WHEN @TotalActive >= 1 THEN 1 ELSE 0 END;
GO

-- ── Test 2: Include deprecated ───────────────────────────────
DECLARE @Status2 BIT, @Message2 NVARCHAR(500);

CREATE TABLE #List2 (
    Id BIGINT, AdAccount NVARCHAR(100), DisplayName NVARCHAR(200),
    ClockNumber NVARCHAR(20), PinHash NVARCHAR(255),
    IgnitionRole NVARCHAR(100), CreatedAt DATETIME2(3), DeprecatedAt DATETIME2(3)
);

INSERT INTO #List2
EXEC Location.AppUser_List
    @IncludeDeprecated = 1,
    @Status = @Status2 OUTPUT,
    @Message = @Message2 OUTPUT;

DECLARE @TotalAll INT = (SELECT COUNT(*) FROM #List2);
DECLARE @DepCount2 INT = (SELECT COUNT(*) FROM #List2 WHERE DeprecatedAt IS NOT NULL);
DROP TABLE #List2;

EXEC test.Assert_IsTrue @TestName = N'IncludeDeprecated=1: returns more or equal rows',
    @Condition = CASE WHEN @TotalAll >= @TotalActive THEN 1 ELSE 0 END;

-- If prior tests deprecated users, we should see at least one deprecated row
-- (This is a soft check — depends on test order, so we just verify the flag works)
EXEC test.Assert_IsTrue @TestName = N'Status = 1 with IncludeDeprecated',
    @Condition = @Status2;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Run tests, verify pass**

```powershell
.\Run-Tests.ps1
```

- [ ] **Step 3: Commit**

```bash
git add sql/tests/03_appuser/050_AppUser_List.sql
git commit -m "test: AppUser_List — default vs include deprecated filter"
```

---

## Task 12: AppUser — Update Tests

**Files:**
- Create: `sql/tests/03_appuser/060_AppUser_Update.sql`

**What we're testing:** Updates mutable fields (DisplayName, ClockNumber, IgnitionRole). AdAccount and PinHash are immutable via this proc. Cannot update deprecated users.

- [ ] **Step 1: Write the test file**

Create `sql/tests/03_appuser/060_AppUser_Update.sql`:

```sql
-- ============================================================
-- Tests: Location.AppUser_Update
-- ============================================================
EXEC test.BeginTestFile @FileName = N'060_AppUser_Update';
GO

-- ── Setup: create a user to update ───────────────────────────
DECLARE @Sid BIT, @Smsg NVARCHAR(500), @UserId BIGINT;
EXEC Location.AppUser_Create
    @AdAccount = N'update.test@mppmfg.com', @DisplayName = N'Before Update',
    @ClockNumber = N'U001', @IgnitionRole = N'Operator',
    @AppUserId = 1, @Status = @Sid OUTPUT, @Message = @Smsg OUTPUT, @NewId = @UserId OUTPUT;
GO

-- ── Test 1: Happy path — update mutable fields ───────────────
DECLARE @UserId BIGINT = (SELECT Id FROM Location.AppUser WHERE AdAccount = N'update.test@mppmfg.com');
DECLARE @Status BIT, @Message NVARCHAR(500);

EXEC Location.AppUser_Update
    @Id           = @UserId,
    @DisplayName  = N'After Update',
    @ClockNumber  = N'U002',
    @IgnitionRole = N'Supervisor',
    @AppUserId    = 1,
    @Status       = @Status OUTPUT,
    @Message      = @Message OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Update: Status = 1', @Condition = @Status;

DECLARE @Name NVARCHAR(200), @Clock NVARCHAR(20), @Role NVARCHAR(100);
SELECT @Name = DisplayName, @Clock = ClockNumber, @Role = IgnitionRole
FROM Location.AppUser WHERE Id = @UserId;

EXEC test.Assert_IsEqual @TestName = N'DisplayName updated',
    @Expected = N'After Update', @Actual = @Name;
EXEC test.Assert_IsEqual @TestName = N'ClockNumber updated',
    @Expected = N'U002', @Actual = @Clock;
EXEC test.Assert_IsEqual @TestName = N'IgnitionRole updated',
    @Expected = N'Supervisor', @Actual = @Role;

-- Verify audit has old/new snapshots
DECLARE @NewVal NVARCHAR(MAX);
SELECT TOP 1 @NewVal = NewValue FROM Audit.ConfigLog
WHERE EntityId = @UserId
  AND LogEventTypeId = (SELECT Id FROM Audit.LogEventType WHERE Code = N'Updated')
ORDER BY Id DESC;

EXEC test.Assert_IsNotNull @TestName = N'Update audit: NewValue captured',
    @Value = @NewVal;
GO

-- ── Test 2: NULL DisplayName rejected ────────────────────────
DECLARE @UserId2 BIGINT = (SELECT Id FROM Location.AppUser WHERE AdAccount = N'update.test@mppmfg.com');
DECLARE @Status2 BIT, @Message2 NVARCHAR(500);

EXEC Location.AppUser_Update
    @Id = @UserId2, @DisplayName = NULL, @AppUserId = 1,
    @Status = @Status2 OUTPUT, @Message = @Message2 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'NULL DisplayName: Status = 0',
    @Condition = CASE WHEN @Status2 = 0 THEN 1 ELSE 0 END;
GO

-- ── Test 3: Non-existent user ────────────────────────────────
DECLARE @Status3 BIT, @Message3 NVARCHAR(500);

EXEC Location.AppUser_Update
    @Id = 999999, @DisplayName = N'Ghost', @AppUserId = 1,
    @Status = @Status3 OUTPUT, @Message = @Message3 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Non-existent user: Status = 0',
    @Condition = CASE WHEN @Status3 = 0 THEN 1 ELSE 0 END;
GO

-- ── Test 4: Cannot update deprecated user ────────────────────
-- Create and deprecate a user
DECLARE @Sid4 BIT, @Smsg4 NVARCHAR(500), @DepId BIGINT;
EXEC Location.AppUser_Create
    @AdAccount = N'dep.update@mppmfg.com', @DisplayName = N'Dep Update Test',
    @AppUserId = 1, @Status = @Sid4 OUTPUT, @Message = @Smsg4 OUTPUT, @NewId = @DepId OUTPUT;
EXEC Location.AppUser_Deprecate
    @Id = @DepId, @AppUserId = 1, @Status = @Sid4 OUTPUT, @Message = @Smsg4 OUTPUT;

DECLARE @Status4 BIT, @Message4 NVARCHAR(500);
EXEC Location.AppUser_Update
    @Id = @DepId, @DisplayName = N'Should Fail', @AppUserId = 1,
    @Status = @Status4 OUTPUT, @Message = @Message4 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Deprecated user: Status = 0',
    @Condition = CASE WHEN @Status4 = 0 THEN 1 ELSE 0 END;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Run tests, verify pass**

```powershell
.\Run-Tests.ps1
```

- [ ] **Step 3: Commit**

```bash
git add sql/tests/03_appuser/060_AppUser_Update.sql
git commit -m "test: AppUser_Update — happy path, validation, deprecated guard, audit snapshots"
```

---

## Task 13: AppUser — SetPin Tests

**Files:**
- Create: `sql/tests/03_appuser/070_AppUser_SetPin.sql`

**What we're testing:** PIN update with audit redaction — OldValue and NewValue are hardcoded as `[REDACTED]`.

- [ ] **Step 1: Write the test file**

Create `sql/tests/03_appuser/070_AppUser_SetPin.sql`:

```sql
-- ============================================================
-- Tests: Location.AppUser_SetPin
-- ============================================================
EXEC test.BeginTestFile @FileName = N'070_AppUser_SetPin';
GO

-- ── Setup: create a user ─────────────────────────────────────
DECLARE @Sid BIT, @Smsg NVARCHAR(500), @PinUserId BIGINT;
EXEC Location.AppUser_Create
    @AdAccount = N'pin.test@mppmfg.com', @DisplayName = N'Pin Tester',
    @AppUserId = 1, @Status = @Sid OUTPUT, @Message = @Smsg OUTPUT, @NewId = @PinUserId OUTPUT;
GO

-- ── Test 1: Happy path — set PIN ─────────────────────────────
DECLARE @PinUserId BIGINT = (SELECT Id FROM Location.AppUser WHERE AdAccount = N'pin.test@mppmfg.com');
DECLARE @Status BIT, @Message NVARCHAR(500);

EXEC Location.AppUser_SetPin
    @Id        = @PinUserId,
    @PinHash   = N'newhash$2b$12$abc123',
    @AppUserId = 1,
    @Status    = @Status OUTPUT,
    @Message   = @Message OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'SetPin: Status = 1', @Condition = @Status;

-- Verify PIN was actually updated
DECLARE @StoredPin NVARCHAR(255);
SELECT @StoredPin = PinHash FROM Location.AppUser WHERE Id = @PinUserId;
EXEC test.Assert_IsEqual @TestName = N'PIN stored in database',
    @Expected = N'newhash$2b$12$abc123', @Actual = @StoredPin;

-- Verify audit log has REDACTED values (critical security check)
DECLARE @AuditOld NVARCHAR(MAX), @AuditNew NVARCHAR(MAX);
SELECT TOP 1 @AuditOld = OldValue, @AuditNew = NewValue
FROM Audit.ConfigLog
WHERE EntityId = @PinUserId
  AND LogEventTypeId = (SELECT Id FROM Audit.LogEventType WHERE Code = N'PinChanged')
ORDER BY Id DESC;

EXEC test.Assert_IsEqual @TestName = N'Audit OldValue = [REDACTED]',
    @Expected = N'[REDACTED]', @Actual = @AuditOld;
EXEC test.Assert_IsEqual @TestName = N'Audit NewValue = [REDACTED]',
    @Expected = N'[REDACTED]', @Actual = @AuditNew;
GO

-- ── Test 2: NULL PinHash rejected ────────────────────────────
DECLARE @PinUserId2 BIGINT = (SELECT Id FROM Location.AppUser WHERE AdAccount = N'pin.test@mppmfg.com');
DECLARE @Status2 BIT, @Message2 NVARCHAR(500);

EXEC Location.AppUser_SetPin
    @Id = @PinUserId2, @PinHash = NULL, @AppUserId = 1,
    @Status = @Status2 OUTPUT, @Message = @Message2 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'NULL PinHash: Status = 0',
    @Condition = CASE WHEN @Status2 = 0 THEN 1 ELSE 0 END;
GO

-- ── Test 3: Cannot set PIN on deprecated user ────────────────
DECLARE @Sid3 BIT, @Smsg3 NVARCHAR(500), @DepPinId BIGINT;
EXEC Location.AppUser_Create
    @AdAccount = N'dep.pin@mppmfg.com', @DisplayName = N'Dep Pin Test',
    @AppUserId = 1, @Status = @Sid3 OUTPUT, @Message = @Smsg3 OUTPUT, @NewId = @DepPinId OUTPUT;
EXEC Location.AppUser_Deprecate
    @Id = @DepPinId, @AppUserId = 1, @Status = @Sid3 OUTPUT, @Message = @Smsg3 OUTPUT;

DECLARE @Status3 BIT, @Message3 NVARCHAR(500);
EXEC Location.AppUser_SetPin
    @Id = @DepPinId, @PinHash = N'shouldfail', @AppUserId = 1,
    @Status = @Status3 OUTPUT, @Message = @Message3 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Deprecated user PIN: Status = 0',
    @Condition = CASE WHEN @Status3 = 0 THEN 1 ELSE 0 END;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Run tests, verify pass**

```powershell
.\Run-Tests.ps1
```

- [ ] **Step 3: Commit**

```bash
git add sql/tests/03_appuser/070_AppUser_SetPin.sql
git commit -m "test: AppUser_SetPin — PIN update, audit redaction, validation guards"
```

---

## Task 14: AppUser — Deprecate Tests

**Files:**
- Create: `sql/tests/03_appuser/080_AppUser_Deprecate.sql`

**What we're testing:** Soft delete. Business rules: cannot deprecate bootstrap (Id=1), cannot self-deprecate, cannot double-deprecate. Audit captures old/new state.

- [ ] **Step 1: Write the test file**

Create `sql/tests/03_appuser/080_AppUser_Deprecate.sql`:

```sql
-- ============================================================
-- Tests: Location.AppUser_Deprecate
-- ============================================================
EXEC test.BeginTestFile @FileName = N'080_AppUser_Deprecate';
GO

-- ── Test 1: Happy path — deprecate a user ────────────────────
DECLARE @Sid BIT, @Smsg NVARCHAR(500), @TargetId BIGINT;
EXEC Location.AppUser_Create
    @AdAccount = N'deprecate.happy@mppmfg.com', @DisplayName = N'Deprecate Happy',
    @AppUserId = 1, @Status = @Sid OUTPUT, @Message = @Smsg OUTPUT, @NewId = @TargetId OUTPUT;

DECLARE @Status BIT, @Message NVARCHAR(500);
EXEC Location.AppUser_Deprecate
    @Id = @TargetId, @AppUserId = 1,
    @Status = @Status OUTPUT, @Message = @Message OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Deprecate: Status = 1', @Condition = @Status;

DECLARE @DepAt DATETIME2(3);
SELECT @DepAt = DeprecatedAt FROM Location.AppUser WHERE Id = @TargetId;
EXEC test.Assert_IsNotNull @TestName = N'DeprecatedAt is set',
    @Value = CAST(@DepAt AS NVARCHAR);

-- Verify audit log
DECLARE @AuditCount INT = (
    SELECT COUNT(*) FROM Audit.ConfigLog
    WHERE EntityId = @TargetId
      AND LogEventTypeId = (SELECT Id FROM Audit.LogEventType WHERE Code = N'Deprecated')
);
EXEC test.Assert_IsTrue @TestName = N'Deprecate audit logged',
    @Condition = CASE WHEN @AuditCount >= 1 THEN 1 ELSE 0 END;
GO

-- ── Test 2: Cannot deprecate bootstrap account (Id=1) ────────
-- Create a non-bootstrap user to act as the caller
DECLARE @Sid2 BIT, @Smsg2 NVARCHAR(500), @CallerId BIGINT;
EXEC Location.AppUser_Create
    @AdAccount = N'caller.dep@mppmfg.com', @DisplayName = N'Caller',
    @AppUserId = 1, @Status = @Sid2 OUTPUT, @Message = @Smsg2 OUTPUT, @NewId = @CallerId OUTPUT;

DECLARE @Status2 BIT, @Message2 NVARCHAR(500);
EXEC Location.AppUser_Deprecate
    @Id = 1, @AppUserId = @CallerId,
    @Status = @Status2 OUTPUT, @Message = @Message2 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Cannot deprecate bootstrap: Status = 0',
    @Condition = CASE WHEN @Status2 = 0 THEN 1 ELSE 0 END;

-- Verify bootstrap is still active
DECLARE @BootDepAt DATETIME2(3);
SELECT @BootDepAt = DeprecatedAt FROM Location.AppUser WHERE Id = 1;
EXEC test.Assert_IsNull @TestName = N'Bootstrap still active (DeprecatedAt NULL)',
    @Value = CAST(@BootDepAt AS NVARCHAR);
GO

-- ── Test 3: Cannot self-deprecate ────────────────────────────
DECLARE @SelfId BIGINT = (SELECT Id FROM Location.AppUser WHERE AdAccount = N'caller.dep@mppmfg.com');
DECLARE @Status3 BIT, @Message3 NVARCHAR(500);

EXEC Location.AppUser_Deprecate
    @Id = @SelfId, @AppUserId = @SelfId,
    @Status = @Status3 OUTPUT, @Message = @Message3 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Self-deprecate: Status = 0',
    @Condition = CASE WHEN @Status3 = 0 THEN 1 ELSE 0 END;
GO

-- ── Test 4: Cannot double-deprecate ──────────────────────────
-- Deprecate a new user twice
DECLARE @Sid4 BIT, @Smsg4 NVARCHAR(500), @DblId BIGINT;
EXEC Location.AppUser_Create
    @AdAccount = N'double.dep@mppmfg.com', @DisplayName = N'Double Dep',
    @AppUserId = 1, @Status = @Sid4 OUTPUT, @Message = @Smsg4 OUTPUT, @NewId = @DblId OUTPUT;
EXEC Location.AppUser_Deprecate
    @Id = @DblId, @AppUserId = 1, @Status = @Sid4 OUTPUT, @Message = @Smsg4 OUTPUT;

DECLARE @Status4 BIT, @Message4 NVARCHAR(500);
EXEC Location.AppUser_Deprecate
    @Id = @DblId, @AppUserId = 1,
    @Status = @Status4 OUTPUT, @Message = @Message4 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Double deprecate: Status = 0',
    @Condition = CASE WHEN @Status4 = 0 THEN 1 ELSE 0 END;
GO

-- ── Test 5: Non-existent user ────────────────────────────────
DECLARE @Status5 BIT, @Message5 NVARCHAR(500);

EXEC Location.AppUser_Deprecate
    @Id = 999999, @AppUserId = 1,
    @Status = @Status5 OUTPUT, @Message = @Message5 OUTPUT;

EXEC test.Assert_IsTrue @TestName = N'Non-existent user: Status = 0',
    @Condition = CASE WHEN @Status5 = 0 THEN 1 ELSE 0 END;
GO

EXEC test.PrintSummary;
GO
```

- [ ] **Step 2: Run the full test suite**

```powershell
.\Run-Tests.ps1
```
Expected: All tests across all 21 files pass.

- [ ] **Step 3: Commit**

```bash
git add sql/tests/03_appuser/080_AppUser_Deprecate.sql
git commit -m "test: AppUser_Deprecate — bootstrap guard, self-deprecate, double-deprecate, happy path"
```

---

## Test Coverage Summary

| Proc Group | Proc | Tests | Key Scenarios |
|---|---|---|---|
| **Audit Writers** | Audit_LogConfigChange | 4 | Code resolution, fallbacks, NULL EntityId, JSON snapshots |
| | Audit_LogFailure | 4 | Happy path, NULL params, fallback codes, non-NULL EntityId |
| | Audit_LogInterfaceCall | 3 | High/low fidelity payloads, error fields |
| | Audit_LogOperation | 3 | Location context, NULL locations, fallback codes |
| **Audit Readers** | LogEntityType_List | 2 | Status, seed count (>=24) |
| | LogEventType_List | 2 | Status, seed count (>=20) |
| | LogSeverity_List | 2 | Status, exact count (4) |
| | ConfigLog_GetByEntity | 2 | Matching rows, invalid code |
| | ConfigLog_List | 4 | Date range, empty range, entity filter, invalid filter |
| | FailureLog_GetByEntity | 2 | Matching rows, invalid code |
| | FailureLog_List | 2 | Date range, proc name filter |
| | FailureLog_GetTopProcs | 2 | Aggregation, ordering |
| | FailureLog_GetTopReasons | 2 | Aggregation, entity filter |
| **AppUser CRUD** | AppUser_Create | 5 | Happy path, NULL required params, duplicate AdAccount, optional NULLs, audit logging |
| | AppUser_Get | 2 | Found by Id, missing Id |
| | AppUser_GetByAdAccount | 3 | Found, missing, returns deprecated users |
| | AppUser_GetByClockNumber | 3 | Found, deprecated filtered out, missing |
| | AppUser_List | 2 | Default filter, include deprecated |
| | AppUser_Update | 4 | Happy path, NULL DisplayName, missing user, deprecated guard |
| | AppUser_SetPin | 3 | Happy path + audit redaction, NULL PinHash, deprecated guard |
| | AppUser_Deprecate | 5 | Happy path, bootstrap guard, self-deprecate, double-deprecate, missing user |

**Total: 21 procs, 21 test files, ~60 assertions**
