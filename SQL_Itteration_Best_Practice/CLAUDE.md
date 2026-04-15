# AI CONTEXT — SQL Version Control Workflow

> This file provides context for AI assistants (Claude Code, GitHub Copilot) working in this repository.
> Place this file at the repo root as `CLAUDE.md` or `.github/copilot-instructions.md` depending on the tool.

---

## Project Stack

- **Database:** Microsoft SQL Server
- **Version control:** Git
- **Migration approach:** Manual, no third-party migration tooling
- **Environments:** Dev (local) → Staging → Production

---

## Repository Layout

```
/sql
  /schema/tables/           ← Canonical DDL for all tables (source of truth)
  /schema/views/            ← Canonical view definitions
  /schema/stored-procs/     ← Canonical stored procedure definitions
  /schema/indexes/          ← Index definitions
  /migrations/versioned/    ← Numbered, run-once migration scripts
  /migrations/repeatable/   ← R__prefixed, re-runnable scripts (procs, views)
  /seeds/                   ← Reference and test data
  /scripts/reset_dev.sql    ← Dev rebuild script
```

---

## Migration Conventions

### Versioned migrations
- Filename: `NNNN_short_description.sql` (e.g. `0014_add_cip_phase_log.sql`)
- Run exactly once per environment, never modified after application
- Always wrapped in `BEGIN TRANSACTION / COMMIT`
- Always insert into `dbo.SchemaVersion` inside the same transaction
- Applied in ascending numeric order

### Repeatable scripts
- Filename: `R__ObjectName.sql` (e.g. `R__usp_GetCipPhaseReport.sql`)
- Use `CREATE OR ALTER` — never plain `CREATE`
- Re-run whenever the file changes
- Cover stored procedures, views, scalar functions

---

## SchemaVersion Table

Every database has this table. It is the authoritative record of applied migrations.

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

---

## Templates to Use When Generating SQL

### Versioned migration

```sql
-- ============================================================
-- Migration:   NNNN_description.sql
-- Author:      [name]
-- Date:        YYYY-MM-DD
-- Description: [what and why]
-- ============================================================

BEGIN TRANSACTION;

-- ── CHANGE BEGINS ─────────────────────────────────────────


-- ── CHANGE ENDS ───────────────────────────────────────────

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES ('NNNN_description', '[description]');

COMMIT;
```

### Repeatable script (stored procedure)

```sql
-- ============================================================
-- Repeatable:  R__ProcedureName.sql
-- Author:      [name]
-- Modified:    YYYY-MM-DD
-- Description: [what this does]
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.ProcedureName
    @Param1 DATATYPE
AS
BEGIN
    SET NOCOUNT ON;

    -- body

END;
GO
```

### Repeatable script (view)

```sql
-- ============================================================
-- Repeatable:  R__ViewName.sql
-- Author:      [name]
-- Modified:    YYYY-MM-DD
-- Description: [what this does]
-- ============================================================

CREATE OR ALTER VIEW dbo.ViewName
AS
    -- body
;
GO
```

---

## Rules the AI Must Follow

1. **Never modify an existing versioned migration file.** If a fix is needed, generate a new migration with the next available number.

2. **Always wrap versioned migrations in a transaction** that includes the `SchemaVersion` insert.

3. **Use `CREATE OR ALTER`** for all stored procedures and views — never plain `CREATE`.

4. **Assign the next sequential migration number** by checking existing files in `/migrations/versioned/` and incrementing from the highest number found.

5. **Generate schema files alongside migrations.** When creating a new migration that adds or alters a table, also produce or update the corresponding file in `/schema/tables/`.

6. **Never produce `DROP TABLE` or `DROP COLUMN` without explicit user instruction.** Destructive operations require confirmation.

7. **Always use `DATETIME2` not `DATETIME`.** Always use `NVARCHAR` not `VARCHAR` unless the user specifies otherwise.

8. **Update `reset_dev.sql`** when adding a new versioned migration — add the new `:r` line at the bottom of the migration block.

9. **Stored procedure naming convention:** `dbo.usp_VerbNoun` (e.g. `usp_GetBatchEvents`, `usp_InsertPhaseLog`)

10. **View naming convention:** `dbo.vw_Description` (e.g. `vw_ActiveBatches`, `vw_CipPhaseSummary`)

---

## Commit Message Format

```
db: NNNN short description of change

- Bullet detail of what was added/changed
- Refs ticket or context if applicable
```

For repeatable changes:
```
db: update usp_ProcName — describe what changed
```

---

## When Asked to Generate SQL in This Repo

- Identify whether the change is a **versioned migration** (schema/data change) or **repeatable** (proc/view update)
- Use the correct template above
- Place output in the correct directory
- Increment migration number correctly
- Flag any destructive operations and ask for confirmation before generating
- Note any dependent objects that may need corresponding updates
