-- ============================================================
-- Migration:   0013_oi07_oi12_corrections.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-27
-- Description: Two correction migrations bundled. Both fix Phase G
--              (migration 0010) additives that were authored against
--              an out-of-date understanding of the 2026-04-20 MPP
--              meeting decisions.
--
--   OI-07 — Workorder.WorkOrderType
--     The 2026-04-20 meeting note was mis-recorded as a three-type
--     model (Demand / Maintenance / Recipe). Jacques's 2026-04-24
--     OIR review (v2.10, commit 6865d8d) corrected this: there is
--     ONE active type today — `Production`. Maintenance and Recipe
--     are FUTURE hooks; the WorkOrder table itself does not exist
--     yet (Arc 2 Phase 1 will create it). Recipe was deleted
--     entirely. Until then, the seed table is just visibility for
--     the discriminator that Production WO rows will eventually
--     carry.
--
--     Shape delta on Workorder.WorkOrderType:
--       ~ Row Id=1 renamed Demand → Production
--       - Row Id=2 (Maintenance) deleted
--       - Row Id=3 (Recipe) deleted
--
--     Audit.LogEntityType row Id=38 description refreshed to reflect
--     single-Production seed.
--
--   OI-12 — MaxParts moves from ContainerConfig to Item
--     The 2026-04-20 meeting note placed MaxParts on ContainerConfig
--     (the per-Item container packaging spec). Jacques's review
--     (OIR v2.10) clarified that MaxParts is a Part attribute —
--     a hard cap on pieces that flow through ANY container of that
--     part — not a property of the packaging shape itself.
--
--     Shape delta:
--       - Parts.ContainerConfig.MaxParts (INT NULL)         dropped
--       + Parts.Item.MaxParts (INT NULL)                    added
--
--     Companion repeatable proc updates land alongside this migration:
--       Parts.ContainerConfig_Create / _Update — strip @MaxParts param.
--       Parts.ContainerConfig_GetByItem — strip MaxParts from SELECT.
--       Parts.Item_Create / _Update — add @MaxParts param + > 0
--         validation when supplied.
--       Parts.Item_Get / _GetByPartNumber / _List — surface MaxParts
--         in SELECT.
--
-- Why bundled: both corrections are tiny, both touch Phase G additive
-- shape, and both have to land before any test rerun can stay green.
-- Splitting them into two versioned migrations would just be ceremony.
-- ============================================================

BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0013_oi07_oi12_corrections')
BEGIN
    PRINT 'Migration 0013 already applied — skipping.';
    COMMIT;
    RETURN;
END


-- ============================================================
-- == OI-07: Workorder.WorkOrderType single-Production seed ===
-- ============================================================
-- DELETE order matters only insofar as no FK currently references
-- WorkOrderType.Id (Workorder.WorkOrder doesn't exist yet, per
-- migration 0010 §11). Safe to remove rows 2 + 3 directly.

DELETE FROM Workorder.WorkOrderType WHERE Id IN (2, 3);

UPDATE Workorder.WorkOrderType
SET Code        = N'Production',
    Name        = N'Production Work Order',
    Description = N'The single active WorkOrderType today. Auto-generated on LOT start, invisible to operators. Maintenance and Recipe are FUTURE hooks — the discriminator is retained as a code table so Arc 2 Phase 1''s Workorder.WorkOrder can carry a WorkOrderTypeId FK without re-shaping later.'
WHERE Id = 1;


-- ============================================================
-- == OI-07: Audit.LogEntityType row 38 description refresh ===
-- ============================================================

UPDATE Audit.LogEntityType
SET Description = N'Workorder.WorkOrderType — Production-only discriminator (single active seed). Maintenance + Recipe deferred to FUTURE. Read-only seed.'
WHERE Code = N'WorkOrderType';


-- ============================================================
-- == OI-12: DROP Parts.ContainerConfig.MaxParts ==============
-- ============================================================
-- No constraints, indexes, or default values on this column —
-- it was added by 0010 as a plain INT NULL — so DROP COLUMN is
-- straightforward.

IF COL_LENGTH('Parts.ContainerConfig', 'MaxParts') IS NOT NULL
    ALTER TABLE Parts.ContainerConfig DROP COLUMN MaxParts;


-- ============================================================
-- == OI-12: ADD Parts.Item.MaxParts ==========================
-- ============================================================
-- Hard cap on pieces per container of this Part. NULL means no
-- cap (consumer math falls back to TraysPerContainer × PartsPerTray
-- alone). Validated > 0 when supplied — see Item_Create / _Update.

IF COL_LENGTH('Parts.Item', 'MaxParts') IS NULL
    ALTER TABLE Parts.Item ADD MaxParts INT NULL;


-- ============================================================
-- == Record migration ========================================
-- ============================================================
INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0013_oi07_oi12_corrections',
    'OI-07: Workorder.WorkOrderType reduced to single Production seed (Demand renamed, Maintenance + Recipe deleted, LogEntityType row 38 description refreshed). OI-12: Parts.ContainerConfig.MaxParts dropped, Parts.Item.MaxParts added (INT NULL, > 0 validation in repeatable procs).'
);

COMMIT TRANSACTION;
PRINT 'Migration 0013 completed: WorkOrderType collapsed to Production-only; MaxParts moved from Parts.ContainerConfig to Parts.Item.';
