-- ============================================================
-- Migration:   0008_quality_spec_defect_code.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-14
-- Description: Phase 7 — Quality Schema Configuration Tables
--
--              1. Create Quality.DefectCode — ~153 reject/defect
--                 reason codes (seeded from FRS Appendix E).
--                 Mutable with soft-delete (DeprecatedAt).
--
--              2. Create Quality.QualitySpec — header/parent for
--                 versioned inspection specifications. Links to
--                 Item and/or OperationTemplate to define scope.
--
--              3. Create Quality.QualitySpecVersion with Draft/
--                 Published/Deprecated three-state model via
--                 PublishedAt DATETIME2(3) NULL + DeprecatedAt.
--                 Same pattern as Parts.Bom. UNIQUE
--                 (QualitySpecId, VersionNumber).
--
--              4. Create Quality.QualitySpecAttribute — individual
--                 inspection points within a version. Carries
--                 data type, UOM, target/limits, sort order.
--                 No soft-delete — hard DELETE scoped to
--                 un-published parent versions.
--
--              5. Seed Audit.LogEntityType rows for DefectCode,
--                 QualitySpec, QualitySpecVersion, QualitySpecAttribute.
-- ============================================================

BEGIN TRANSACTION;

-- Guard: skip if already applied
IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0008_quality_spec_defect_code')
BEGIN
    PRINT 'Migration 0008 already applied — skipping.';
    COMMIT;
    RETURN;
END

-- ============================================================
-- == Quality.DefectCode (mutable, soft-delete) ===============
-- ============================================================

CREATE TABLE Quality.DefectCode (
    Id              BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code            NVARCHAR(20)   NOT NULL,
    Description     NVARCHAR(500)  NOT NULL,
    AreaLocationId  BIGINT         NOT NULL REFERENCES Location.Location(Id),
    IsExcused       BIT            NOT NULL DEFAULT 0,
    CreatedAt       DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt    DATETIME2(3)   NULL,
    CONSTRAINT UQ_DefectCode_Code UNIQUE (Code)
);

CREATE INDEX IX_DefectCode_AreaLocationId ON Quality.DefectCode (AreaLocationId);
CREATE INDEX IX_DefectCode_DeprecatedAt   ON Quality.DefectCode (DeprecatedAt);


-- ============================================================
-- == Quality.QualitySpec (header/parent) =====================
-- ============================================================

CREATE TABLE Quality.QualitySpec (
    Id                    BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Name                  NVARCHAR(200)  NOT NULL,
    ItemId                BIGINT         NULL REFERENCES Parts.Item(Id),
    OperationTemplateId   BIGINT         NULL REFERENCES Parts.OperationTemplate(Id),
    Description           NVARCHAR(500)  NULL,
    CreatedAt             DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE INDEX IX_QualitySpec_ItemId              ON Quality.QualitySpec (ItemId);
CREATE INDEX IX_QualitySpec_OperationTemplateId ON Quality.QualitySpec (OperationTemplateId);


-- ============================================================
-- == Quality.QualitySpecVersion (Draft/Published/Deprecated) =
-- ============================================================

CREATE TABLE Quality.QualitySpecVersion (
    Id              BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    QualitySpecId   BIGINT         NOT NULL REFERENCES Quality.QualitySpec(Id),
    VersionNumber   INT            NOT NULL DEFAULT 1,
    EffectiveFrom   DATETIME2(3)   NOT NULL,
    PublishedAt     DATETIME2(3)   NULL,   -- NULL = Draft; set = Published
    DeprecatedAt    DATETIME2(3)   NULL,
    CreatedByUserId BIGINT         NOT NULL REFERENCES Location.AppUser(Id),
    CreatedAt       DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_QualitySpecVersion_Spec_Version UNIQUE (QualitySpecId, VersionNumber)
);

CREATE INDEX IX_QualitySpecVersion_QualitySpecId_EffectiveFrom
    ON Quality.QualitySpecVersion (QualitySpecId, EffectiveFrom);


-- ============================================================
-- == Quality.QualitySpecAttribute (no soft-delete) ===========
-- ============================================================

CREATE TABLE Quality.QualitySpecAttribute (
    Id                     BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    QualitySpecVersionId   BIGINT          NOT NULL REFERENCES Quality.QualitySpecVersion(Id),
    AttributeName          NVARCHAR(100)   NOT NULL,
    DataType               NVARCHAR(50)    NOT NULL,
    Uom                    NVARCHAR(20)    NULL,
    TargetValue            DECIMAL(18,6)   NULL,
    LowerLimit             DECIMAL(18,6)   NULL,
    UpperLimit             DECIMAL(18,6)   NULL,
    IsRequired             BIT             NOT NULL DEFAULT 1,
    SortOrder              INT             NOT NULL DEFAULT 0,
    CONSTRAINT UQ_QualitySpecAttribute_Version_Name UNIQUE (QualitySpecVersionId, AttributeName)
);

CREATE INDEX IX_QualitySpecAttribute_QualitySpecVersionId
    ON Quality.QualitySpecAttribute (QualitySpecVersionId);


-- ============================================================
-- == Audit.LogEntityType — add QualitySpecVersion/Attribute ==
-- ============================================================
-- Note: DefectCode (14) and QualitySpec (12) were seeded in migration 0001.
-- We only add the NEW entity types here.

INSERT INTO Audit.LogEntityType (Id, Code, Name, Description) VALUES
    (28, N'QualitySpecVersion',    N'Quality Spec Version',       N'Versioned quality specification with Draft/Published/Deprecated states'),
    (29, N'QualitySpecAttribute',  N'Quality Spec Attribute',     N'Individual inspection attribute within a quality spec version');


-- == VERSION TRACKING ========================================

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0008_quality_spec_defect_code',
    'Phase 7: Quality.DefectCode (mutable), Quality.QualitySpec (header), Quality.QualitySpecVersion (three-state versioned), Quality.QualitySpecAttribute (no soft-delete). +2 LogEntityType rows (QualitySpecVersion, QualitySpecAttribute).'
);

COMMIT TRANSACTION;

PRINT 'Migration 0008 completed: 4 Quality tables created, 2 LogEntityType rows added.';
