-- =============================================
-- File:         helpers/0001_test_framework.sql
-- Author:       Blue Ridge Automation
-- Created:      2026-04-13
-- Description:
--   Lightweight T-SQL test framework for MPP MES stored procedure tests.
--   Deploys into the [test] schema. Creates permanent tables for result
--   tracking and a set of assert procedures.
--
--   Permanent tables (created once, truncated at the start of each run):
--     test.TestResults      - accumulated pass/fail rows across all test files
--     test.CurrentTestFile  - single-row tracker for the active test file name
-- =============================================

-- Create [test] schema
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'test')
    EXEC(N'CREATE SCHEMA [test]');
GO

-- Create test.TestResults if it does not yet exist
IF OBJECT_ID('test.TestResults') IS NULL
BEGIN
    CREATE TABLE test.TestResults (
        Id          INT             IDENTITY(1,1)   NOT NULL,
        TestFile    NVARCHAR(200)   NOT NULL,
        TestName    NVARCHAR(500)   NOT NULL,
        Passed      BIT             NOT NULL,
        Detail      NVARCHAR(1000)  NULL
    );
END
GO

IF OBJECT_ID('test.CurrentTestFile') IS NULL
BEGIN
    CREATE TABLE test.CurrentTestFile (
        FileName NVARCHAR(200) NOT NULL
    );
END
GO

-- =============================================
-- Procedure:  test.BeginTestFile
-- Purpose:    Sets the current test file name and prints a header banner.
-- =============================================
CREATE OR ALTER PROCEDURE test.BeginTestFile
    @FileName NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM test.CurrentTestFile;
    INSERT INTO test.CurrentTestFile (FileName) VALUES (@FileName);

    PRINT N'';
    PRINT N'====================================================';
    PRINT N'  TEST FILE: ' + @FileName;
    PRINT N'====================================================';
END;
GO

-- =============================================
-- Procedure:  test.Assert_IsEqual
-- Purpose:    Asserts @Expected equals @Actual (both as NVARCHAR).
--             NULL == NULL is treated as PASS.
-- =============================================
CREATE OR ALTER PROCEDURE test.Assert_IsEqual
    @TestName NVARCHAR(500),
    @Expected NVARCHAR(MAX),
    @Actual   NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Passed BIT;
    DECLARE @Detail NVARCHAR(1000) = NULL;
    DECLARE @File   NVARCHAR(200)  = ISNULL((SELECT TOP 1 FileName FROM test.CurrentTestFile), N'(unknown)');

    IF (@Expected IS NULL AND @Actual IS NULL)
        SET @Passed = 1;
    ELSE IF (@Expected IS NULL OR @Actual IS NULL)
    BEGIN
        SET @Passed = 0;
        SET @Detail = N'Expected: ' + ISNULL(@Expected, N'NULL') + N' | Actual: ' + ISNULL(@Actual, N'NULL');
    END
    ELSE IF (@Expected = @Actual)
        SET @Passed = 1;
    ELSE
    BEGIN
        SET @Passed = 0;
        SET @Detail = N'Expected: ' + LEFT(@Expected, 400) + N' | Actual: ' + LEFT(@Actual, 400);
    END

    INSERT INTO test.TestResults (TestFile, TestName, Passed, Detail)
    VALUES (@File, @TestName, @Passed, @Detail);

    IF @Passed = 1
        PRINT N'  PASS: ' + @TestName;
    ELSE
        PRINT N'  FAIL: ' + @TestName + N' -- ' + ISNULL(@Detail, N'(no detail)');
END;
GO

-- =============================================
-- Procedure:  test.Assert_IsTrue
-- Purpose:    Asserts @Condition = 1.
-- =============================================
CREATE OR ALTER PROCEDURE test.Assert_IsTrue
    @TestName  NVARCHAR(500),
    @Condition BIT,
    @Detail    NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Passed BIT = CASE WHEN @Condition = 1 THEN 1 ELSE 0 END;
    DECLARE @File   NVARCHAR(200) = ISNULL((SELECT TOP 1 FileName FROM test.CurrentTestFile), N'(unknown)');
    DECLARE @EffectiveDetail NVARCHAR(1000) = CASE
        WHEN @Passed = 0 THEN ISNULL(@Detail, N'Condition was false or NULL')
        ELSE NULL
    END;

    INSERT INTO test.TestResults (TestFile, TestName, Passed, Detail)
    VALUES (@File, @TestName, @Passed, @EffectiveDetail);

    IF @Passed = 1
        PRINT N'  PASS: ' + @TestName;
    ELSE
        PRINT N'  FAIL: ' + @TestName + N' -- ' + ISNULL(@EffectiveDetail, N'(no detail)');
END;
GO

-- =============================================
-- Procedure:  test.Assert_IsNull
-- Purpose:    Asserts @Value IS NULL.
-- =============================================
CREATE OR ALTER PROCEDURE test.Assert_IsNull
    @TestName NVARCHAR(500),
    @Value    NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Passed BIT = CASE WHEN @Value IS NULL THEN 1 ELSE 0 END;
    DECLARE @File   NVARCHAR(200) = ISNULL((SELECT TOP 1 FileName FROM test.CurrentTestFile), N'(unknown)');
    DECLARE @Detail NVARCHAR(1000) = CASE
        WHEN @Passed = 0 THEN N'Expected NULL but got: ' + LEFT(@Value, 400)
        ELSE NULL
    END;

    INSERT INTO test.TestResults (TestFile, TestName, Passed, Detail)
    VALUES (@File, @TestName, @Passed, @Detail);

    IF @Passed = 1
        PRINT N'  PASS: ' + @TestName;
    ELSE
        PRINT N'  FAIL: ' + @TestName + N' -- ' + ISNULL(@Detail, N'(no detail)');
END;
GO

-- =============================================
-- Procedure:  test.Assert_IsNotNull
-- Purpose:    Asserts @Value IS NOT NULL.
-- =============================================
CREATE OR ALTER PROCEDURE test.Assert_IsNotNull
    @TestName NVARCHAR(500),
    @Value    NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Passed BIT = CASE WHEN @Value IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @File   NVARCHAR(200) = ISNULL((SELECT TOP 1 FileName FROM test.CurrentTestFile), N'(unknown)');
    DECLARE @Detail NVARCHAR(1000) = CASE
        WHEN @Passed = 0 THEN N'Expected a non-NULL value but got NULL'
        ELSE NULL
    END;

    INSERT INTO test.TestResults (TestFile, TestName, Passed, Detail)
    VALUES (@File, @TestName, @Passed, @Detail);

    IF @Passed = 1
        PRINT N'  PASS: ' + @TestName;
    ELSE
        PRINT N'  FAIL: ' + @TestName + N' -- ' + ISNULL(@Detail, N'(no detail)');
END;
GO

-- =============================================
-- Procedure:  test.Assert_RowCount
-- Purpose:    Asserts @ExpectedCount equals @ActualCount.
-- =============================================
CREATE OR ALTER PROCEDURE test.Assert_RowCount
    @TestName      NVARCHAR(500),
    @ExpectedCount INT,
    @ActualCount   INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Passed BIT = CASE
        WHEN @ExpectedCount IS NULL OR @ActualCount IS NULL THEN 0
        WHEN @ExpectedCount = @ActualCount THEN 1
        ELSE 0
    END;
    DECLARE @File   NVARCHAR(200) = ISNULL((SELECT TOP 1 FileName FROM test.CurrentTestFile), N'(unknown)');
    DECLARE @Detail NVARCHAR(1000);

    IF @ExpectedCount IS NULL OR @ActualCount IS NULL
        SET @Detail = N'Expected or actual count was NULL';
    ELSE IF @Passed = 0
        SET @Detail = N'Expected row count: ' + CAST(@ExpectedCount AS NVARCHAR(20))
                    + N' | Actual: ' + CAST(@ActualCount AS NVARCHAR(20));

    INSERT INTO test.TestResults (TestFile, TestName, Passed, Detail)
    VALUES (@File, @TestName, @Passed, @Detail);

    IF @Passed = 1
        PRINT N'  PASS: ' + @TestName;
    ELSE
        PRINT N'  FAIL: ' + @TestName + N' -- ' + ISNULL(@Detail, N'(no detail)');
END;
GO

-- =============================================
-- Procedure:  test.PrintSummary
-- Purpose:    Prints pass/fail counts for the current test file.
--             Call at the end of each test file.
-- =============================================
CREATE OR ALTER PROCEDURE test.PrintSummary
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @File    NVARCHAR(200) = ISNULL((SELECT TOP 1 FileName FROM test.CurrentTestFile), N'(unknown)');
    DECLARE @Total   INT;
    DECLARE @Passed  INT;
    DECLARE @Failed  INT;

    SELECT
        @Total  = COUNT(*),
        @Passed = SUM(CASE WHEN Passed = 1 THEN 1 ELSE 0 END),
        @Failed = SUM(CASE WHEN Passed = 0 THEN 1 ELSE 0 END)
    FROM test.TestResults
    WHERE TestFile = @File;

    PRINT N'';
    PRINT N'  -- Summary: ' + @File;
    PRINT N'     Total:  ' + CAST(ISNULL(@Total,  0) AS NVARCHAR(10));
    PRINT N'     Passed: ' + CAST(ISNULL(@Passed, 0) AS NVARCHAR(10));
    PRINT N'     Failed: ' + CAST(ISNULL(@Failed, 0) AS NVARCHAR(10));
    PRINT N'';
END;
GO
