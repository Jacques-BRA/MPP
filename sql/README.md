# MPP MES — SQL Database

SQL Server 2022 database scripts for the MPP MES replacement project.

## Quick Start — Rebuild Dev from Scratch

```powershell
cd sql\scripts
.\Reset-DevDatabase.ps1                          # localhost, Windows auth
.\Reset-DevDatabase.ps1 -ServerInstance ".\SQL2022"  # named instance
```

**Prerequisite:** `SqlServer` PowerShell module — `Install-Module SqlServer` (one-time).

The script auto-discovers all migrations, repeatables, and seed scripts — no file list to maintain. It drops and recreates `MPP_MES_Dev`, runs versioned migrations in numeric order, deploys all `R__*.sql` repeatables, loads all seed scripts, and prints a verification summary.

## Folder Layout

```
sql/
  schema/                  <- Source of truth: DDL showing current desired state
    tables/                    (one file per table)
    views/
    stored-procs/              (copy of repeatable for grep-ability)
    indexes/
    constraints/
  migrations/
    versioned/             <- Run-once: schema changes, data migrations (0001_, 0002_, ...)
    repeatable/            <- Re-run on change: stored procs, views (R__*.sql)
  seeds/                   <- Reference data inserts (idempotent)
  scripts/
    Reset-DevDatabase.ps1      Dev database rebuild (PowerShell)
    _TEMPLATE_stored_procedure.sql   SP template with full example + blank skeleton
```

## Conventions

- **Full guide:** `sql_version_control_guide.md` in project root
- **Design patterns:** `sql_best_practices_mes.md` in project root
- **SP template:** `MPP_MES_PHASED_PLAN_CONFIG_TOOL.md` > "Stored Procedure Template and Conventions"
- **Naming:** UpperCamelCase for all SQL identifiers. `Schema.Entity_Verb` for procs.
- **Data types:** `BIGINT` PKs/FKs, `NVARCHAR` strings, `DATETIME2(3)` timestamps, `DECIMAL` measurements — never `INT` PKs, `VARCHAR`, `DATETIME`, `FLOAT`

## Current State

| Component | Status |
|---|---|
| `0001` — Schemas, audit lookups (seeded), AppUser (bootstrap row), 4 audit log tables | Script ready |
| Shared audit procs (4) | Repeatables ready |
| Audit lookup list procs (3) | Repeatables ready |
| Audit log read procs — ConfigLog (2) + FailureLog (4) | Repeatables ready |
| AppUser CRUD (8 procs — List, Get, GetByAdAccount, GetByClockNumber, Create, Update, SetPin, Deprecate) | Repeatables ready |
| SP template | Script ready |
| Dev reset script (PowerShell) | Script ready |
| **Phase 1 total: 1 migration + 21 repeatables** | **Complete** |
| Phase 2+ migrations | Not started |
| Seed data SQL scripts | Not started (CSVs ready in `reference/seed_data/`) |
