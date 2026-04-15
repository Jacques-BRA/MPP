-- ============================================================
-- Migration:   0007_bom_and_route_publish.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-14
-- Description: Phase 6 (BOM Management) + Phase 5 retrofit
--              (Draft/Published state for RouteTemplate).
--
--              1. ALTER Parts.RouteTemplate ADD PublishedAt DATETIME2(3)
--                 NULL. Three-state semantics: NULL = Draft (mutable,
--                 invisible to production), non-NULL = Published
--                 (immutable, visible to GetActiveForItem),
--                 DeprecatedAt NOT NULL = Retired. A new
--                 Parts.RouteTemplate_Publish proc flips a draft to
--                 published. GetActiveForItem filters PublishedAt
--                 IS NOT NULL. RouteStep mutations reject on
--                 Published parents (in addition to Deprecated).
--
--              2. Create Parts.Bom with the same Draft/Published/
--                 Deprecated model via PublishedAt. UNIQUE
--                 (ParentItemId, VersionNumber) mirrors RouteTemplate.
--
--              3. Create Parts.BomLine. No DeprecatedAt — lines are
--                 immutable within a published BOM. Hard DELETE on
--                 _Remove with sibling SortOrder compaction.
--                 UNIQUE (BomId, ChildItemId) prevents duplicate
--                 child references within one BOM (a single line
--                 with total QtyPer is the correct model).
--
--              4. Seed Audit.LogEntityType row 27 for BomLine so
--                 line-level events have a dedicated audit entity
--                 type (Bom was already seeded at Id=6).
-- ============================================================

BEGIN TRANSACTION;

-- Guard: skip if already applied
IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0007_bom_and_route_publish')
BEGIN
    PRINT 'Migration 0007 already applied — skipping.';
    COMMIT;
    RETURN;
END

-- ============================================================
-- == Phase 5 retrofit: RouteTemplate.PublishedAt =============
-- ============================================================

ALTER TABLE Parts.RouteTemplate
    ADD PublishedAt DATETIME2(3) NULL;


-- ============================================================
-- == Parts.Bom (versioned, Draft/Published/Deprecated) ========
-- ============================================================

CREATE TABLE Parts.Bom (
    Id              BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ParentItemId    BIGINT         NOT NULL REFERENCES Parts.Item(Id),
    VersionNumber   INT            NOT NULL DEFAULT 1,
    EffectiveFrom   DATETIME2(3)   NOT NULL,
    PublishedAt     DATETIME2(3)   NULL,   -- NULL = Draft; set = Published
    DeprecatedAt    DATETIME2(3)   NULL,
    CreatedByUserId BIGINT         NOT NULL REFERENCES Location.AppUser(Id),
    CreatedAt       DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Bom_Parent_Version UNIQUE (ParentItemId, VersionNumber)
);

CREATE INDEX IX_Bom_ParentItemId_EffectiveFrom
    ON Parts.Bom (ParentItemId, EffectiveFrom);


-- ============================================================
-- == Parts.BomLine (no soft-delete — hard DELETE pattern) ====
-- ============================================================

CREATE TABLE Parts.BomLine (
    Id          BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    BomId       BIGINT         NOT NULL REFERENCES Parts.Bom(Id),
    ChildItemId BIGINT         NOT NULL REFERENCES Parts.Item(Id),
    QtyPer      DECIMAL(10,4)  NOT NULL,
    UomId       BIGINT         NOT NULL REFERENCES Parts.Uom(Id),
    SortOrder   INT            NOT NULL DEFAULT 0,
    CONSTRAINT UQ_BomLine_Bom_ChildItem UNIQUE (BomId, ChildItemId)
);

CREATE INDEX IX_BomLine_BomId       ON Parts.BomLine (BomId);
CREATE INDEX IX_BomLine_ChildItemId ON Parts.BomLine (ChildItemId);


-- ============================================================
-- == Audit.LogEntityType — add BomLine =======================
-- ============================================================

INSERT INTO Audit.LogEntityType (Id, Code, Name, Description) VALUES
    (27, N'BomLine', N'BOM Line', N'Individual component line within a BOM');


-- == VERSION TRACKING ========================================

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0007_bom_and_route_publish',
    'Phase 6: Parts.Bom + Parts.BomLine with Draft/Published state. Phase 5 retrofit: RouteTemplate.PublishedAt column for same 3-state model.'
);

COMMIT;
