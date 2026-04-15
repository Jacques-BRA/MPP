# SQL Version Control & Dev Workflow — Engineer Guide

> **Applies to:** SQL Server projects using Git for version control
> **Tooling required:** None beyond Git and a SQL client
> **Last updated:** 2026-04-12

---

## Why This Exists

A database has *state*. Unlike application code, you can't just overwrite a file and redeploy — the database already has data, structure, and history in it. This guide gives every engineer a shared, predictable way to make database changes, track them, and hand them off without surprises.

The goal is:
- Any engineer can rebuild any database from scratch at any time
- Every change is traceable to a person, date, and reason
- Dev iteration stays fast without creating drift from production

---

## Repository Structure

Every project repo containing database work should follow this layout:

```
/sql
  /schema               ← Source of truth: DDL files showing current desired state
    tables/
    views/
    stored-procs/
    indexes/
    constraints/
  /migrations
    /versioned          ← Run-once scripts: schema changes, data migrations
    /repeatable         ← Re-run on change: views, stored procs, functions
  /seeds                ← Reference data and test data inserts
  /scripts              ← Utility scripts (resets, audits, diagnostics)
  README.md             ← DB overview, setup instructions
```

---

## The SchemaVersion Table

Every project database gets this table. It is the single source of truth for what has been applied.

Create it once, manually, as the very first thing on any new database:

```sql
CREATE TABLE dbo.SchemaVersion (
    Id          INT IDENTITY(1,1)   NOT NULL PRIMARY KEY,
    MigrationId NVARCHAR(200)       NOT NULL,
    AppliedBy   NVARCHAR(100)       NOT NULL DEFAULT SYSTEM_USER,
    AppliedAt   DATETIME2(3)        NOT NULL DEFAULT GETUTCDATE(),
    Description NVARCHAR(500)       NULL,
    CONSTRAINT UQ_SchemaVersion_MigrationId UNIQUE (MigrationId)
);
```

To check where a database currently is:

```sql
SELECT * FROM dbo.SchemaVersion ORDER BY AppliedAt DESC;
```

---

## Migration File Naming Convention

### Versioned Migrations (run once)
These cover table creation, schema alterations, index changes, data migrations.

```
NNNN_short_description.sql
```

Examples:
```
0001_initial_schema.sql
0014_add_cip_phase_log.sql
0027_alter_batchevent_add_duration_col.sql
```

- `NNNN` is a zero-padded sequential number
- Description uses underscores, lowercase, no spaces
- Numbers are **global** — never reuse one, never insert between existing ones

### Repeatable Scripts (re-run on change)
These cover views, stored procedures, and scalar functions — objects that can be dropped and recreated safely.

```
R__ObjectName.sql
```

Examples:
```
R__vw_ActiveBatches.sql
R__usp_GetCipPhaseReport.sql
```

The `R__` prefix signals: *this file replaces itself on change, it is not a one-time event.*

---

## Migration File Template

Every versioned migration file must follow this structure:

```sql
-- ============================================================
-- Migration:   0014_add_cip_phase_log.sql
-- Author:      [Your Name]
-- Date:        YYYY-MM-DD
-- Description: Short description of what this migration does
--              and why it is needed.
-- ============================================================

BEGIN TRANSACTION;

-- ── CHANGE BEGINS ─────────────────────────────────────────

-- Your DDL or DML here


-- ── CHANGE ENDS ───────────────────────────────────────────

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0014_add_cip_phase_log',
    'Adds CipPhaseLog table for S88 phase event capture'
);

COMMIT;
```

**Rules:**
- Always wrap in a transaction
- Insert into `SchemaVersion` inside the same transaction
- Never modify this file after it has been applied to any shared environment

---

## Repeatable Script Template

Stored procedures and views use `CREATE OR ALTER` so they are safe to re-run:

```sql
-- ============================================================
-- Repeatable:  R__usp_GetCipPhaseReport.sql
-- Author:      [Your Name]
-- Modified:    YYYY-MM-DD
-- Description: Returns CIP phase summary for a given batch
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.usp_GetCipPhaseReport
    @BatchId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- procedure body here

END;
GO
```

**Rules:**
- Use `CREATE OR ALTER` — never plain `CREATE`
- These files live in `/migrations/repeatable/` and also in `/schema/stored-procs/` (they are the same file — symlink or copy policy decided per project)
- Changes to these files get committed with a meaningful commit message describing what changed and why

---

## Dev Environment Workflow

Dev is where you move fast. The rules here are looser — the discipline comes at commit time.

### The Iteration Loop

```
1. SKETCH   → Make changes directly in your dev DB. Experiment freely.
2. VALIDATE → Confirm the change works and is what you want.
3. CAPTURE  → Write the migration script that produces this result on a clean DB.
4. VERIFY   → Reset your dev DB and re-run all migrations. Does it build clean?
5. COMMIT   → Push migration + any updated schema files together.
```

**Never write the migration first and then fight the dev DB to match it.** Build the thing, then document the delta as a migration.

### The Reset Script

Every project must have a reset script for dev. Being able to rebuild from zero in under a minute removes the fear of experimenting.

Location: `/sql/scripts/reset_dev.sql`

```sql
-- ============================================================
-- reset_dev.sql
-- WARNING: Destroys and rebuilds the dev database from scratch.
-- FOR DEV USE ONLY. Never run against staging or production.
-- ============================================================

USE master;

IF DB_ID(N'YourDevDB') IS NOT NULL
BEGIN
    ALTER DATABASE [YourDevDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [YourDevDB];
END

CREATE DATABASE [YourDevDB];
GO

USE [YourDevDB];
GO

-- Bootstrap
:r ../migrations/versioned/0001_initial_schema.sql
:r ../migrations/versioned/0002_add_audit_log.sql
-- Add each migration in order as they are added to the project
```

Update this script every time a new migration is added to the project.

---

## Applying Migrations to Shared Environments

For staging, UAT, or production:

1. Check where the DB currently is:
   ```sql
   SELECT TOP 1 MigrationId, AppliedAt FROM dbo.SchemaVersion ORDER BY AppliedAt DESC;
   ```

2. Identify which migrations have not yet been applied (anything with a number higher than the last applied)

3. Run each unapplied migration **in order**, one at a time

4. Confirm each migration inserted its row into `SchemaVersion` before running the next

5. Never skip migrations. Never apply them out of order.

---

## Commit Message Convention

```
db: 0014 add CipPhaseLog table for S88 phase capture

- New table: dbo.CipPhaseLog
- Indexes on BatchId and PhaseStartTime
- Refs ticket CIP-042
```

Format: `db: NNNN short description`

For repeatable changes: `db: update usp_GetCipPhaseReport — add duration calc`

---

## The Rules (Non-Negotiable)

| Rule | Why |
|---|---|
| Never modify an applied versioned migration | It breaks reproducibility and trust in the history |
| Always wrap migrations in a transaction | A failed migration should leave the DB unchanged |
| Always insert into SchemaVersion in the same transaction | The record only exists if the migration succeeded |
| Reset and rebuild your dev DB before committing | Catches missing dependencies and order problems |
| One migration per logical change | Easier to review, revert, and understand |
| Never hand-edit a shared DB without a migration | If it's not in git, it doesn't exist |

---

## Quick Reference

| Situation | Action |
|---|---|
| Adding a new table | New versioned migration |
| Altering a column | New versioned migration |
| Updating a stored proc | Edit the `R__` file, commit with description of change |
| Adding a new stored proc | New `R__` file in `/migrations/repeatable/` |
| Something went wrong in dev | Reset and rebuild using `reset_dev.sql` |
| Checking DB state | `SELECT * FROM dbo.SchemaVersion ORDER BY AppliedAt DESC` |
| Onboarding a new dev environment | Run all migrations in order from `0001` |
