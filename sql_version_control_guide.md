# SQL Version Control & Dev Workflow — Engineer Guide

> **Applies to:** SQL Server projects using Git for version control
> **Tooling required:** None beyond Git and a SQL client (SSMS, Azure Data Studio, or similar)
> **Last updated:** 2026-04-12

## Revision History

| Version | Date | Author | Change Summary |
|---|---|---|---|
| 0.1 | 2026-04-12 | Blue Ridge Automation | Initial version — reconciled from general-purpose guide with MPP MES project conventions |

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
  /schema               <- Source of truth: DDL files showing current desired state
    tables/
    views/
    stored-procs/
    indexes/
    constraints/
  /migrations
    /versioned          <- Run-once scripts: schema changes, data migrations
    /repeatable         <- Re-run on change: views, stored procs, functions
  /seeds                <- Reference data and test data inserts
  /scripts              <- Utility scripts (resets, audits, diagnostics)
  README.md             <- DB overview, setup instructions
```

**Note on repeatables:** Repeatable scripts live in `/migrations/repeatable/`. The `/schema/stored-procs/` and `/schema/views/` folders hold the canonical DDL for documentation and grep-ability, but `/migrations/repeatable/` is the operational copy. On Windows environments (where symlinks are painful), maintain one canonical location — if you update the repeatable, update the schema copy at commit time.

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
0014_add_location_attributes.sql
0027_alter_lot_add_split_flag.sql
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
R__Location_Location_Create.sql
```

The `R__` prefix signals: *this file replaces itself on change, it is not a one-time event.*

---

## Migration File Template

Every versioned migration file must follow this structure:

```sql
-- ============================================================
-- Migration:   0014_add_location_attributes.sql
-- Author:      [Your Name]
-- Date:        YYYY-MM-DD
-- Description: Short description of what this migration does
--              and why it is needed.
-- ============================================================

BEGIN TRANSACTION;

-- -- CHANGE BEGINS ------------------------------------------------

-- Guard: skip if already applied (idempotency for manual re-runs)
IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0014_add_location_attributes')
BEGIN
    PRINT 'Migration 0014 already applied — skipping.';
    COMMIT;
    RETURN;
END

-- Your DDL or DML here


-- -- CHANGE ENDS --------------------------------------------------

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0014_add_location_attributes',
    'Adds LocationAttributeDefinition table for polymorphic config'
);

COMMIT;
```

**Rules:**
- Always wrap in a transaction
- Insert into `SchemaVersion` inside the same transaction
- Include the idempotency guard — the `SchemaVersion` unique constraint catches accidental re-runs at the INSERT, but the guard prevents the DDL portion from executing twice (e.g., adding a column that already exists)
- Never modify this file after it has been applied to any shared environment

---

## Repeatable Script Template

Stored procedures and views use `CREATE OR ALTER` so they are safe to re-run:

```sql
-- ============================================================
-- Repeatable:  R__Location_Location_Create.sql
-- Author:      [Your Name]
-- Modified:    YYYY-MM-DD
-- Description: Creates a new Location row under the specified parent
-- ============================================================

CREATE OR ALTER PROCEDURE Location.Location_Create
    @LocationTypeDefinitionId INT,
    @ParentLocationId         INT            = NULL,
    @Name                     NVARCHAR(200),
    @Code                     NVARCHAR(50),
    @AppUserId                INT,
    @Status                   BIT            OUTPUT,
    @Message                  NVARCHAR(500)  OUTPUT,
    @NewId                    INT            = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- procedure body per project SP conventions

END;
GO
```

**Rules:**
- Use `CREATE OR ALTER` — never plain `CREATE`
- Changes to these files get committed with a meaningful commit message describing what changed and why

---

## Dev Environment Workflow

Dev is where you move fast. The rules here are looser — the discipline comes at commit time.

### The Iteration Loop

```
1. SKETCH   -> Make changes directly in your dev DB. Experiment freely.
2. VALIDATE -> Confirm the change works and is what you want.
3. CAPTURE  -> Write the migration script that produces this result on a clean DB.
4. VERIFY   -> Reset your dev DB and re-run all migrations. Does it build clean?
5. COMMIT   -> Push migration + any updated schema files together.
```

**Never write the migration first and then fight the dev DB to match it.** Build the thing, then document the delta as a migration.

### The Reset Script

Every project must have a reset script for dev. Being able to rebuild from zero in under a minute removes the fear of experimenting.

Location: `/sql/scripts/Reset-DevDatabase.ps1`

```powershell
# Usage:
.\Reset-DevDatabase.ps1                              # localhost, Windows auth
.\Reset-DevDatabase.ps1 -ServerInstance ".\SQL2022"   # named instance
.\Reset-DevDatabase.ps1 -DatabaseName "MPP_MES_QA"   # different DB name
```

The PowerShell script auto-discovers files in the `/migrations/versioned/`, `/migrations/repeatable/`, and `/seeds/` directories — no manual file list to maintain. When you add a new migration or repeatable, the reset script picks it up automatically.

**Prerequisite:** `SqlServer` PowerShell module — `Install-Module SqlServer` (one-time).

**Execution order:** The script runs in this fixed sequence:
1. Drop and recreate the database
2. Create/map the dev `ignition` SQL login (see prod notice below)
3. Create the `SchemaVersion` tracking table
4. Versioned migrations — sorted by filename (numeric order)
5. Repeatable scripts — all `R__*.sql` files (any order, `CREATE OR ALTER` makes them idempotent)
6. Seed scripts — all `.sql` files in `/seeds/`

Seeds depend on tables existing and procs being available, which is why they run last.

> **⚠ PROD NOTICE — Ignition DB login provisioning**
>
> Step 2 of `Reset-DevDatabase.ps1` creates a SQL login named `ignition` with the password `ignition` and grants it `db_owner`. **That is dev-only** and is required because `DROP DATABASE` destroys all database-level users on each reset.
>
> For staging/prod:
> - **Do not run this reset script.** Prod databases are provisioned once and migrated forward, not dropped.
> - Create the Ignition SQL login manually with a strong managed password (stored only in the Ignition Gateway datasource config, never in a repo file).
> - Grant only the minimum required permissions: `EXECUTE` on the application schemas (`Location`, `Parts`, `Lots`, `Workorder`, `Quality`, `Oee`, `Audit`) plus `SELECT/INSERT/UPDATE` on the tables the Named Queries touch directly. No `db_owner`.
> - SQL Server must be in **Mixed Mode** auth for SQL logins to work (enabled via SSMS: *Server Properties → Security*).

---

## Seed Data

Seed scripts populate reference data — code tables, machine lists, defect codes, downtime reasons. They are **not** migrations (they don't change schema) and they are **not** repeatables (they insert data, not replace objects).

Location: `/sql/seeds/`

Seed scripts should be **idempotent** — safe to re-run without creating duplicates. Use `MERGE` or `IF NOT EXISTS` guards:

```sql
-- seed_downtime_reason_codes.sql
-- Idempotent: safe to re-run

IF NOT EXISTS (SELECT 1 FROM Oee.DowntimeReasonCode WHERE Code = N'Tooling')
    INSERT INTO Oee.DowntimeReasonCode (Code, Description, CategoryId)
    VALUES (N'Tooling', N'Tooling change or repair', 3);

-- Or use MERGE for bulk seed data
```

**Seeds in the reset script:** Seeds are loaded last, after all versioned migrations and repeatables. This ensures the target tables and any validation procs exist.

---

## Reversing a Migration

Migrations are immutable once applied. If migration 0027 needs to be undone:

1. **Write a new corrective migration** (0028) that reverses the change
2. Do NOT edit or delete migration 0027
3. The `SchemaVersion` table will show both — the original and the correction

```sql
-- 0028_revert_lot_split_flag.sql
-- Reverses: 0027_alter_lot_add_split_flag.sql
-- Reason:  Split tracking moved to LotGenealogyEvent instead

BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0028_revert_lot_split_flag')
BEGIN
    PRINT 'Migration 0028 already applied — skipping.';
    COMMIT;
    RETURN;
END

ALTER TABLE Lots.Lot DROP COLUMN SplitFlag;

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES ('0028_revert_lot_split_flag', 'Revert: removes SplitFlag from Lots.Lot (moved to event model)');

COMMIT;
```

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

6. In manufacturing environments, **coordinate with production schedules** — a migration that locks a table mid-shift is a downtime event.

---

## Commit Message Convention

```
db: 0014 add LocationAttributeDefinition table

- New table: Location.LocationAttributeDefinition
- Indexes on LocationTypeDefinitionId
- Refs OI-10
```

Format: `db: NNNN short description`

For repeatable changes: `db: update Location_Create — add Code uniqueness check`

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
| To undo a migration, write a new one | Never delete or edit history |

---

## Quick Reference

| Situation | Action |
|---|---|
| Adding a new table | New versioned migration |
| Altering a column | New versioned migration |
| Updating a stored proc | Edit the `R__` file, commit with description of change |
| Adding a new stored proc | New `R__` file in `/migrations/repeatable/` |
| Loading reference data | Add or update a seed script in `/seeds/` |
| Something went wrong in dev | Reset and rebuild using `reset_dev.sql` |
| Checking DB state | `SELECT * FROM dbo.SchemaVersion ORDER BY AppliedAt DESC` |
| Onboarding a new dev environment | Run all migrations in order from `0001` |
| Reversing a deployed change | New versioned migration that undoes the prior one |

---

---

# MPP MES Project Conventions

> The sections above describe the general-purpose workflow. Everything below is **specific to the MPP MES project** and overrides general conventions where they conflict. A new engineer on this project follows the general workflow but uses the naming, templates, and structure defined here.

## Database Layout

**SQL Server 2022 Standard Edition** with 7 application schemas plus `dbo` for infrastructure:

| Schema | Purpose | Scope |
|---|---|---|
| `dbo` | Infrastructure only (`SchemaVersion`) | Always |
| `Location` | ISA-95 plant hierarchy, polymorphic location model | MVP |
| `Parts` | Items, BOMs, routes, operation templates | MVP |
| `Lots` | LOT lifecycle, genealogy, container tracking | MVP |
| `Workorder` | Work orders (auto-generated, hidden in MVP) | CONDITIONAL |
| `Quality` | Inspections, specs, holds, defect events | MVP |
| `Oee` | Downtime events, production events, OEE snapshots | MVP (events) / FUTURE (snapshots) |
| `Audit` | OperationLog, ConfigLog, InterfaceLog, FailureLog | MVP |

Every table, proc, and view lives in its application schema — not `dbo`. The only `dbo` object is `SchemaVersion`.

## Naming Conventions

**All database identifiers use UpperCamelCase.** This overrides any general convention.

| Element | Convention | Example |
|---|---|---|
| Tables | `Schema.EntityName` (singular) | `Location.Location`, `Parts.Item`, `Audit.ConfigLog` |
| Columns | UpperCamelCase | `PieceCount`, `CreatedAt`, `DeprecatedAt` |
| Foreign keys | `ReferencedEntityId` | `ParentLocationId`, `LocationTypeDefinitionId` |
| Stored procs | `Schema.Entity_Verb` | `Location.Location_Create`, `Parts.Item_Update` |
| Views | `Schema.Entity_ViewName` | `Location.Location_ActiveHierarchy` |
| Code values | UpperCamelCase | `Site`, `Area`, `WorkCenter`, `Good`, `Hold`, `InProgress` |
| Primary keys | Always `Id` (surrogate `INT IDENTITY`) | `Location.Location.Id` |
| Soft deletes | `DeprecatedAt DATETIME2(3) NULL` | Non-null = inactive |

**Proc naming:** The pattern is `Entity_Verb`, not `usp_VerbNoun`. The schema prefix replaces the `dbo.usp_` prefix:
- General pattern: `dbo.usp_GetBatchEvents`
- MPP pattern: `Lots.Lot_GetActive`

**Migration filenames** still use `snake_case` with underscores — this is a file-naming convention, not a DB-naming convention. Migration content uses UpperCamelCase for all SQL identifiers.

## Stored Procedure Template

Every stored procedure on this project follows the template defined in `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md` (Stored Procedure Template and Conventions section). That document is the authoritative reference. Key points summarized here for quick reference:

### Output Contract

Every proc — read or write — returns:

| Output Parameter | Type | Purpose |
|---|---|---|
| `@Status` | `BIT OUTPUT` | `1` on success, `0` on failure. Always set before returning. |
| `@Message` | `NVARCHAR(500) OUTPUT` | Human-readable status. Surfaced directly in Perspective UI on error. |
| *(proc-specific)* | various `OUTPUT` | E.g., `@NewId INT OUTPUT` for Create procs. |

### Error Hierarchy (Three Tiers)

| Tier | Example | Handling |
|---|---|---|
| **Parameter validation** | NULL required param, bad FK | `@Status = 0`, friendly `@Message`, call `Audit.Audit_LogFailure`, `RETURN`. No transaction. |
| **Business rule violation** | Duplicate code, stale data | Same: `@Status = 0`, `@Message`, `Audit.Audit_LogFailure`, `RETURN`. |
| **Unexpected exception** | Deadlock, constraint violation | CATCH: rollback, `@Status = 0`, `ERROR_MESSAGE()` in `@Message`, `Audit.Audit_LogFailure` outside txn, then `THROW`. |

### Transaction & Audit Boilerplate

```sql
SET NOCOUNT ON;
SET XACT_ABORT ON;
```

- Success audit (`Audit.Audit_LogConfigChange`) goes **inside** the transaction — rolls back atomically with the data
- Failure audit (`Audit.Audit_LogFailure`) goes **outside** the rolled-back transaction, wrapped in nested TRY/CATCH to avoid masking
- `@AppUserId INT` is required on every mutating proc for audit attribution

### Shared Audit Procs (Code-String Pattern)

The four audit procs take code strings, not integer IDs:

```sql
EXEC Audit.Audit_LogConfigChange
    @AppUserId         = @AppUserId,
    @LogEntityTypeCode = N'Location',    -- not an integer FK
    @EntityId          = @NewId,
    @LogEventTypeCode  = N'Created',     -- not an integer FK
    @LogSeverityCode   = N'Info',        -- not an integer FK
    @Description       = N'Location created',
    @OldValue          = NULL,
    @NewValue          = @Params;
```

Self-documenting, no hardcoded IDs, no inline subquery clutter.

### Read Procs

Read procs still get `@Status` / `@Message` but skip transactions and success audit. Parameter-validation failures on reads generally should **not** write to `Audit.FailureLog` (too much noise) — override at author's discretion if the read has valuable failure signal.

> **Full template with complete example:** See `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md`, section "Stored Procedure Template and Conventions." Copy the `Location.Location_Create` example as your starting point for any new proc.

## Repeatable File Naming (MPP Override)

Because procs are schema-qualified with `Schema.Entity_Verb`, the repeatable filename convention is:

```
R__Schema_Entity_Verb.sql
```

Examples:
```
R__Location_Location_Create.sql
R__Location_Location_Update.sql
R__Location_Location_Deprecate.sql
R__Parts_Item_Create.sql
R__Audit_Audit_LogConfigChange.sql
```

The double appearance of "Location" or "Audit" is intentional — it mirrors the `Schema.Entity` qualification in the proc name.

## Seed Data (MPP)

876 rows of seed data have been extracted from the FRS appendices into CSVs at `reference/seed_data/`:

| File | Rows | Source |
|---|---|---|
| `machines.csv` | 209 | FRS Appendix B |
| `opc_tags.csv` | 161 | FRS Appendix C |
| `downtime_reason_codes.csv` | 353 | FRS Appendix D |
| `defect_codes.csv` | 153 | FRS Appendix E |

These CSVs are the canonical source. SQL seed scripts in `/sql/seeds/` should load from these CSVs (or inline the data with idempotent inserts). The Excel workbook at `reference/seed_data.xlsx` is a derivative for human review — never treat it as the source.

**35 partial machine rows** on FRS page 85 have empty right-side columns (in-development entries). These need MPP classification before loading.

## Bootstrap Pattern

The first `Audit.AppUser` row (`Id = 1`, `AdAccount = 'system.bootstrap'`) is inserted directly by the initial migration script — not by a stored proc. This breaks the chicken-and-egg dependency on `@AppUserId` for audit attribution. All subsequent admin accounts are created through procs by this bootstrap user.

## Data Types (MPP Specifics)

These rules from `sql_best_practices_mes.md` are non-negotiable on this project:

- `DATETIME2(3)` — never `DATETIME`
- `DECIMAL` — never `FLOAT` for any measurement or count
- `NVARCHAR` — never `VARCHAR` (Unicode support for Honda EDI data)
- `NOT NULL` by default — NULLs only when absence is semantically distinct
- Status fields are code-table backed — FK to a code table, not magic integers or free-text

---

## AI Assistant Rules (MPP Context)

> These rules govern AI-assisted SQL generation within this project. They extend the general non-negotiable rules above.

1. **Never modify an existing versioned migration file.** Generate a new migration with the next available number.

2. **Always wrap versioned migrations in a transaction** that includes both the `SchemaVersion` insert and the idempotency guard.

3. **Use `CREATE OR ALTER`** for all stored procedures, views, and functions — never plain `CREATE`.

4. **Assign the next sequential migration number** by checking existing files in `/sql/migrations/versioned/` and incrementing from the highest.

5. **Generate schema files alongside migrations.** When a migration adds or alters a table, produce or update the corresponding file in `/sql/schema/tables/`.

6. **Never produce `DROP TABLE` or `DROP COLUMN` without explicit user instruction.** Destructive operations require confirmation.

7. **Follow MPP naming conventions.** UpperCamelCase for all SQL identifiers. `Schema.Entity_Verb` for procs. No `dbo.usp_` prefix.

8. **Follow the MPP stored procedure template.** Every proc gets `@Status BIT OUTPUT`, `@Message NVARCHAR(500) OUTPUT`, the three-tier error hierarchy, and audit calls. Copy the `Location.Location_Create` example from the Phased Plan as the starting point.

9. **Schema-qualify every reference.** `Location.Location`, not just `Location`. `Audit.Audit_LogFailure`, not just `Audit_LogFailure`.

10. **Update `reset_dev.sql`** when adding any migration, repeatable, or seed script.

11. **Use `DATETIME2(3)`, `NVARCHAR`, and `DECIMAL`** — never `DATETIME`, `VARCHAR`, or `FLOAT`.

12. **Seed data is idempotent.** Use `IF NOT EXISTS` or `MERGE`. Never blindly `INSERT` reference data.

13. **Note dependent objects.** When generating SQL that affects a table, flag any stored procs, views, or seeds that may need corresponding updates.
