-- ============================================================
-- Migration:   0006_routes_operations_eligibility.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-14
-- Description: Phase 5 — Process Definition: Routes, Operations,
--              and Eligibility.
--
--              Creates 5 tables:
--                - Parts.OperationTemplate (versioned, clone-to-modify)
--                - Parts.OperationTemplateField (junction to DataCollectionField)
--                - Parts.RouteTemplate (versioned per Item)
--                - Parts.RouteStep (ordered steps via SequenceNumber)
--                - Parts.ItemLocation (eligibility junction)
--
--              OperationTemplate uses the same versioning pattern as
--              RouteTemplate: multiple rows share a Code grouping key,
--              differentiated by VersionNumber. UNIQUE (Code, VersionNumber)
--              enforces this. When engineering wants to modify an existing
--              template, _CreateNewVersion clones the row and its
--              OperationTemplateField junction rows, then engineering
--              edits the clone in place. Historical RouteSteps continue
--              pointing at the original row's Id, preserving traceability.
--
--              RouteStep rows are NOT individually soft-deletable —
--              they are children of a versioned RouteTemplate. If a
--              route needs to change, create a new RouteTemplate version.
--              _Remove performs a hard DELETE within an unpublished
--              route; production history is preserved via the
--              RouteTemplate that was active at run time.
--
--              ItemLocation carries CreatedAt + DeprecatedAt for soft
--              toggling — the Add proc re-activates a deprecated
--              pairing rather than inserting a duplicate.
-- ============================================================

BEGIN TRANSACTION;

-- Guard: skip if already applied
IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0006_routes_operations_eligibility')
BEGIN
    PRINT 'Migration 0006 already applied — skipping.';
    COMMIT;
    RETURN;
END

-- ============================================================
-- == Parts.OperationTemplate (versioned) =====================
-- ============================================================

CREATE TABLE Parts.OperationTemplate (
    Id             BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code           NVARCHAR(20)   NOT NULL,
    VersionNumber  INT            NOT NULL DEFAULT 1,
    Name           NVARCHAR(100)  NOT NULL,
    AreaLocationId BIGINT         NOT NULL REFERENCES Location.Location(Id),
    Description    NVARCHAR(500)  NULL,
    CreatedAt      DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt   DATETIME2(3)   NULL,
    CONSTRAINT UQ_OperationTemplate_Code_Version UNIQUE (Code, VersionNumber)
);

CREATE INDEX IX_OperationTemplate_AreaLocationId ON Parts.OperationTemplate (AreaLocationId);
CREATE INDEX IX_OperationTemplate_Code           ON Parts.OperationTemplate (Code);


-- ============================================================
-- == Parts.OperationTemplateField (junction) =================
-- ============================================================

CREATE TABLE Parts.OperationTemplateField (
    Id                    BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    OperationTemplateId   BIGINT         NOT NULL REFERENCES Parts.OperationTemplate(Id),
    DataCollectionFieldId BIGINT         NOT NULL REFERENCES Parts.DataCollectionField(Id),
    IsRequired            BIT            NOT NULL DEFAULT 1,
    CreatedAt             DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt          DATETIME2(3)   NULL
);

-- No active duplicate pairings per template
CREATE UNIQUE INDEX UQ_OperationTemplateField_ActiveTemplateField
    ON Parts.OperationTemplateField (OperationTemplateId, DataCollectionFieldId)
    WHERE DeprecatedAt IS NULL;

CREATE INDEX IX_OperationTemplateField_OperationTemplateId
    ON Parts.OperationTemplateField (OperationTemplateId);


-- ============================================================
-- == Parts.RouteTemplate (versioned per Item) ================
-- ============================================================

CREATE TABLE Parts.RouteTemplate (
    Id              BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ItemId          BIGINT         NOT NULL REFERENCES Parts.Item(Id),
    VersionNumber   INT            NOT NULL DEFAULT 1,
    Name            NVARCHAR(200)  NOT NULL,
    EffectiveFrom   DATETIME2(3)   NOT NULL,
    DeprecatedAt    DATETIME2(3)   NULL,
    CreatedByUserId BIGINT         NOT NULL REFERENCES Location.AppUser(Id),
    CreatedAt       DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_RouteTemplate_Item_Version UNIQUE (ItemId, VersionNumber)
);

CREATE INDEX IX_RouteTemplate_ItemId_EffectiveFrom
    ON Parts.RouteTemplate (ItemId, EffectiveFrom);


-- ============================================================
-- == Parts.RouteStep (children of RouteTemplate) =============
-- ============================================================

CREATE TABLE Parts.RouteStep (
    Id                  BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    RouteTemplateId     BIGINT         NOT NULL REFERENCES Parts.RouteTemplate(Id),
    OperationTemplateId BIGINT         NOT NULL REFERENCES Parts.OperationTemplate(Id),
    SequenceNumber      INT            NOT NULL,
    IsRequired          BIT            NOT NULL DEFAULT 1,
    Description         NVARCHAR(500)  NULL
);

CREATE INDEX IX_RouteStep_RouteTemplateId     ON Parts.RouteStep (RouteTemplateId);
CREATE INDEX IX_RouteStep_OperationTemplateId ON Parts.RouteStep (OperationTemplateId);


-- ============================================================
-- == Parts.ItemLocation (eligibility junction) ===============
-- ============================================================

CREATE TABLE Parts.ItemLocation (
    Id           BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ItemId       BIGINT         NOT NULL REFERENCES Parts.Item(Id),
    LocationId   BIGINT         NOT NULL REFERENCES Location.Location(Id),
    CreatedAt    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt DATETIME2(3)   NULL
);

-- One active pairing per (Item, Location). The Add proc reactivates a
-- deprecated row if one exists rather than inserting a duplicate.
CREATE UNIQUE INDEX UQ_ItemLocation_ActiveItemLocation
    ON Parts.ItemLocation (ItemId, LocationId)
    WHERE DeprecatedAt IS NULL;

CREATE INDEX IX_ItemLocation_ItemId     ON Parts.ItemLocation (ItemId);
CREATE INDEX IX_ItemLocation_LocationId ON Parts.ItemLocation (LocationId);


-- == VERSION TRACKING ========================================

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0006_routes_operations_eligibility',
    'Phase 5: OperationTemplate (versioned via Code+VersionNumber), OperationTemplateField, RouteTemplate (versioned via ItemId+VersionNumber), RouteStep, ItemLocation'
);

COMMIT;
