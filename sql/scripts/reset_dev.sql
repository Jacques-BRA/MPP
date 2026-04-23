-- ============================================================
-- reset_dev.sql
-- WARNING: Destroys and rebuilds the dev database from scratch.
-- FOR DEV USE ONLY. Never run against staging or production.
--
-- Run in SSMS with SQLCMD Mode enabled (Query > SQLCMD Mode)
-- so that :r includes work correctly.
-- ============================================================

USE master;
GO

IF DB_ID(N'MPP_MES_Dev') IS NOT NULL
BEGIN
    ALTER DATABASE [MPP_MES_Dev] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [MPP_MES_Dev];
END
GO

CREATE DATABASE [MPP_MES_Dev];
GO

USE [MPP_MES_Dev];
GO

-- ── SchemaVersion table (must exist before first migration) ──
CREATE TABLE dbo.SchemaVersion (
    Id          INT IDENTITY(1,1)   NOT NULL PRIMARY KEY,
    MigrationId NVARCHAR(200)       NOT NULL,
    AppliedBy   NVARCHAR(100)       NOT NULL DEFAULT SYSTEM_USER,
    AppliedAt   DATETIME2(3)        NOT NULL DEFAULT GETUTCDATE(),
    Description NVARCHAR(500)       NULL,
    CONSTRAINT UQ_SchemaVersion_MigrationId UNIQUE (MigrationId)
);
GO

-- ── Versioned migrations (in order) ──────────────────────────
:r ..\migrations\versioned\0001_bootstrap_schemas_audit_identity.sql
-- Add each new migration here in numeric order

-- ── Repeatable scripts (any order) ───────────────────────────

-- Audit infrastructure procs (must deploy before any CRUD proc)
:r ..\migrations\repeatable\R__Audit_Audit_LogConfigChange.sql
:r ..\migrations\repeatable\R__Audit_Audit_LogFailure.sql
:r ..\migrations\repeatable\R__Audit_Audit_LogOperation.sql
:r ..\migrations\repeatable\R__Audit_Audit_LogInterfaceCall.sql

-- Audit lookup list procs
:r ..\migrations\repeatable\R__Audit_LogSeverity_List.sql
:r ..\migrations\repeatable\R__Audit_LogEventType_List.sql
:r ..\migrations\repeatable\R__Audit_LogEntityType_List.sql

-- Audit log read procs
:r ..\migrations\repeatable\R__Audit_ConfigLog_List.sql
:r ..\migrations\repeatable\R__Audit_ConfigLog_GetByEntity.sql
:r ..\migrations\repeatable\R__Audit_FailureLog_List.sql
:r ..\migrations\repeatable\R__Audit_FailureLog_GetByEntity.sql
:r ..\migrations\repeatable\R__Audit_FailureLog_GetTopReasons.sql
:r ..\migrations\repeatable\R__Audit_FailureLog_GetTopProcs.sql

-- AppUser CRUD
:r ..\migrations\repeatable\R__Location_AppUser_List.sql
:r ..\migrations\repeatable\R__Location_AppUser_Get.sql
:r ..\migrations\repeatable\R__Location_AppUser_GetByAdAccount.sql
:r ..\migrations\repeatable\R__Location_AppUser_GetByInitials.sql
:r ..\migrations\repeatable\R__Location_AppUser_Create.sql
:r ..\migrations\repeatable\R__Location_AppUser_Update.sql
:r ..\migrations\repeatable\R__Location_AppUser_Deprecate.sql

-- Add each new repeatable here

-- ── Seed data (after all migrations and repeatables) ─────────
-- :r ..\seeds\seed_location_types.sql
-- :r ..\seeds\seed_machines.sql
-- :r ..\seeds\seed_downtime_reason_codes.sql
-- :r ..\seeds\seed_defect_codes.sql
-- Uncomment as seed scripts are created

-- ── Verify ───────────────────────────────────────────────────
PRINT '========================================';
PRINT 'MPP_MES_Dev rebuild complete.';
PRINT '========================================';

SELECT MigrationId, AppliedAt, Description
FROM dbo.SchemaVersion
ORDER BY AppliedAt;
GO
