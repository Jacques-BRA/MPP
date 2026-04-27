-- ============================================================
-- Migration:   0011_drop_appuser_legacy_auth.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-23
-- Description: Phase G.4 of the 2026-04-20 OI review refactor —
--              drop the legacy clock-number / PIN auth columns from
--              Location.AppUser.
--
--              Phase C (2026-04-21) rewrote §4 of the FDS to the
--              initials-only security model: operators are identified
--              by initials stamped onto events; interactive users log
--              in via AD; elevated actions are per-action AD
--              re-prompts. Clock numbers and PIN hashes are no longer
--              part of the auth flow, so these two columns are
--              physically removed here.
--
--              This migration drops ONLY the two columns. The broader
--              AppUser realignment flagged in Data Model v1.6 —
--              adding `Initials NOT NULL UNIQUE`, making `AdAccount`
--              nullable with a filtered UNIQUE, and adding the CHECK
--              constraint binding `IgnitionRole` presence to
--              `AdAccount` presence — is a separate scope and will
--              land in its own migration once MPP confirms the
--              initials source.
--
--              COORDINATED WITH PROC CHANGES:
--                - R__Location_AppUser_SetPin.sql            — DELETED
--                - R__Location_AppUser_GetByClockNumber.sql  — DELETED
--                - R__Location_AppUser_Create.sql            — params + INSERT updated
--                - R__Location_AppUser_Update.sql            — params + UPDATE updated
--                - R__Location_AppUser_Get.sql               — SELECT trimmed
--                - R__Location_AppUser_GetByAdAccount.sql    — SELECT trimmed
--                - R__Location_AppUser_List.sql              — SELECT trimmed
--                - R__Location_AppUser_Deprecate.sql         — JSON snapshots trimmed
--
--              Test suites in sql/tests/03_appuser were updated in
--              the same commit — 040_AppUser_GetByClockNumber.sql and
--              070_AppUser_SetPin.sql are deleted; 010/020/030/050/060
--              are stripped of ClockNumber/PinHash references.
-- ============================================================

BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0011_drop_appuser_legacy_auth')
BEGIN
    PRINT 'Migration 0011 already applied — skipping.';
    COMMIT;
    RETURN;
END


-- ============================================================
-- == Location.AppUser — DROP legacy auth columns ==============
-- ============================================================
-- No FKs or indexes reference these columns (grep of the codebase
-- confirms), so a straight DROP COLUMN is safe.

IF COL_LENGTH('Location.AppUser', 'ClockNumber') IS NOT NULL
    ALTER TABLE Location.AppUser DROP COLUMN ClockNumber;

IF COL_LENGTH('Location.AppUser', 'PinHash') IS NOT NULL
    ALTER TABLE Location.AppUser DROP COLUMN PinHash;


-- ============================================================
-- == Record migration =========================================
-- ============================================================
INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0011_drop_appuser_legacy_auth',
    'Phase G.4: drop Location.AppUser.ClockNumber and Location.AppUser.PinHash. Initials/AdAccount-nullable realignment deferred to a separate migration.'
);

COMMIT TRANSACTION;
PRINT 'Migration 0011 completed: Location.AppUser.ClockNumber and Location.AppUser.PinHash dropped.';
