-- ============================================================
-- Migration:   0012_appuser_initials_and_nullable_ad.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-23
-- Description: Completes the Phase C (2026-04-21) security-model
--              realignment that G.4 only partially landed. Adds
--              `Initials` as the primary accountability stamp,
--              makes `AdAccount` optional (for operators with no
--              AD login), and enforces the business rule that
--              IgnitionRole presence requires AdAccount presence.
--
--              Shape delta on Location.AppUser:
--                + Initials NVARCHAR(10) NOT NULL UNIQUE   (new)
--                ~ AdAccount NVARCHAR(100) NULL            (was NOT NULL)
--                - UQ_AppUser_AdAccount (table-level UNIQUE)
--                + UQ_AppUser_AdAccount_Active (filtered UNIQUE
--                  WHERE AdAccount IS NOT NULL)
--                + CK_AppUser_IgnitionRole_Requires_AdAccount
--                  (IgnitionRole IS NULL OR AdAccount IS NOT NULL)
--
--              Bootstrap user (Id=1): Initials = 'SYS'.
--
--              Why: operators are identified by initials stamped
--              onto events (no login); interactive users
--              (Quality / Supervisor / Engineering / Admin) log in
--              via AD. An interactive user MUST have both an AD
--              account and a role, so the CHECK constraint blocks
--              the invalid "IgnitionRole without AdAccount" state.
--
--              Implementation note: statements that reference the
--              newly-added Initials column use EXEC() so each runs
--              in its own batch — the outer batch parser doesn't
--              see Initials until commit, so a direct reference
--              fails with Msg 207.
-- ============================================================

BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0012_appuser_initials_and_nullable_ad')
BEGIN
    PRINT 'Migration 0012 already applied — skipping.';
    COMMIT;
    RETURN;
END


-- ============================================================
-- == Step 1 — Add Initials as nullable to allow backfill =====
-- ============================================================

IF COL_LENGTH('Location.AppUser', 'Initials') IS NULL
    EXEC('ALTER TABLE Location.AppUser ADD Initials NVARCHAR(10) NULL');


-- ============================================================
-- == Step 2 — Backfill Initials for existing rows ============
-- ============================================================
-- Bootstrap row (Id=1) is the only seeded row in production. Test
-- databases may have additional AppUser rows from prior seeds; for
-- those we synthesise unique initials from the Id to satisfy
-- NOT NULL + UNIQUE.

EXEC('UPDATE Location.AppUser SET Initials = N''SYS'' WHERE Id = 1 AND Initials IS NULL');
EXEC('UPDATE Location.AppUser SET Initials = N''U'' + CAST(Id AS NVARCHAR(8)) WHERE Initials IS NULL');


-- ============================================================
-- == Step 3 — Enforce NOT NULL + UNIQUE on Initials ==========
-- ============================================================

EXEC('ALTER TABLE Location.AppUser ALTER COLUMN Initials NVARCHAR(10) NOT NULL');

IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_AppUser_Initials')
    EXEC('ALTER TABLE Location.AppUser ADD CONSTRAINT UQ_AppUser_Initials UNIQUE (Initials)');


-- ============================================================
-- == Step 4 — Relax AdAccount to nullable + filtered UNIQUE ==
-- ============================================================
-- The table-level UNIQUE constraint doesn't tolerate multiple
-- NULLs in SQL Server, so we swap it for a filtered UNIQUE index
-- that only enforces uniqueness among rows where AdAccount is
-- actually set.

IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = 'UQ_AppUser_AdAccount')
    ALTER TABLE Location.AppUser DROP CONSTRAINT UQ_AppUser_AdAccount;

ALTER TABLE Location.AppUser ALTER COLUMN AdAccount NVARCHAR(100) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_AppUser_AdAccount_Active')
    CREATE UNIQUE INDEX UQ_AppUser_AdAccount_Active
        ON Location.AppUser (AdAccount)
        WHERE AdAccount IS NOT NULL;


-- ============================================================
-- == Step 5 — CHECK: IgnitionRole requires AdAccount =========
-- ============================================================
-- Interactive roles (Quality / Supervisor / Engineering / Admin)
-- are only meaningful when the user can log in via AD. A shop-
-- floor operator (no AD, no role) leaves both columns NULL.

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_AppUser_IgnitionRole_Requires_AdAccount')
    ALTER TABLE Location.AppUser
        ADD CONSTRAINT CK_AppUser_IgnitionRole_Requires_AdAccount
            CHECK (IgnitionRole IS NULL OR AdAccount IS NOT NULL);


-- ============================================================
-- == Record migration ========================================
-- ============================================================
INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0012_appuser_initials_and_nullable_ad',
    'Phase C follow-up: Location.AppUser gains Initials NOT NULL UNIQUE; AdAccount becomes nullable with filtered UNIQUE; CK_AppUser_IgnitionRole_Requires_AdAccount added. Bootstrap user Initials = SYS.'
);

COMMIT TRANSACTION;
PRINT 'Migration 0012 completed: Location.AppUser.Initials added (NOT NULL UNIQUE); AdAccount relaxed to nullable with filtered UNIQUE; IgnitionRole/AdAccount pairing enforced by CHECK.';
