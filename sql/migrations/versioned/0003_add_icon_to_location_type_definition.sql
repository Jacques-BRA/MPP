-- ============================================================
-- Migration:   0003_add_icon_to_location_type_definition.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-13
-- Description: Adds Icon column (NVARCHAR(100) NULL) to
--              Location.LocationTypeDefinition for Perspective
--              Tree component icon mapping.
--
--              Icon values are NOT seeded — they'll be populated
--              via the Configuration Tool once the LocationType-
--              Definition CRUD frontend is built. The Jython tree
--              builder (shared.locations.buildTree) falls back to
--              a default icon when Icon IS NULL, so the tree still
--              renders correctly with empty icon values.
-- ============================================================

BEGIN TRANSACTION;

-- Guard: skip if already applied
IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0003_add_icon_to_location_type_definition')
BEGIN
    PRINT 'Migration 0003 already applied — skipping.';
    COMMIT;
    RETURN;
END

-- == ADD COLUMN ================================================

ALTER TABLE Location.LocationTypeDefinition
    ADD Icon NVARCHAR(100) NULL;

-- == VERSION TRACKING ==========================================

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0003_add_icon_to_location_type_definition',
    'Adds nullable Icon column to LocationTypeDefinition (values populated later via Config Tool)'
);

COMMIT;
