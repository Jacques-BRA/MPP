-- ============================================================
-- Migration:   0002_plant_model_location_schema.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-13
-- Description: Creates the 5 Location schema tables (LocationType,
--              LocationTypeDefinition, LocationAttributeDefinition,
--              Location, LocationAttribute), seeds the ISA-95 type
--              hierarchy and attribute definitions, and backfills
--              deferred FKs on Audit.OperationLog.
-- ============================================================

BEGIN TRANSACTION;

-- == IDEMPOTENCY GUARD ========================================
IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0002_plant_model_location_schema')
BEGIN
    PRINT 'Migration 0002 already applied -- skipping.';
    COMMIT;
    RETURN;
END

-- == TABLES ===================================================

-- LocationType -- ISA-95 tiers (explicit IDs, NOT IDENTITY)
CREATE TABLE Location.LocationType (
    Id              BIGINT          NOT NULL PRIMARY KEY,
    Code            NVARCHAR(20)    NOT NULL,
    Name            NVARCHAR(100)   NOT NULL,
    HierarchyLevel  INT             NOT NULL,
    Description     NVARCHAR(500)   NULL,
    CONSTRAINT UQ_LocationType_Code UNIQUE (Code)
);

-- LocationTypeDefinition -- polymorphic kinds within each tier
CREATE TABLE Location.LocationTypeDefinition (
    Id                  BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LocationTypeId      BIGINT          NOT NULL REFERENCES Location.LocationType(Id),
    Code                NVARCHAR(50)    NOT NULL,
    Name                NVARCHAR(100)   NOT NULL,
    Description         NVARCHAR(500)   NULL,
    CreatedAt           DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt        DATETIME2(3)    NULL,
    CONSTRAINT UQ_LocationTypeDefinition_Code UNIQUE (Code)
);

CREATE INDEX IX_LocationTypeDefinition_LocationTypeId
    ON Location.LocationTypeDefinition (LocationTypeId);

-- LocationAttributeDefinition -- attribute schema per definition
CREATE TABLE Location.LocationAttributeDefinition (
    Id                          BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LocationTypeDefinitionId    BIGINT          NOT NULL REFERENCES Location.LocationTypeDefinition(Id),
    AttributeName               NVARCHAR(100)   NOT NULL,
    DataType                    NVARCHAR(50)    NOT NULL,
    IsRequired                  BIT             NOT NULL DEFAULT 0,
    DefaultValue                NVARCHAR(255)   NULL,
    Uom                         NVARCHAR(20)    NULL,
    SortOrder                   INT             NOT NULL DEFAULT 0,
    Description                 NVARCHAR(500)   NULL,
    CreatedAt                   DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt                DATETIME2(3)    NULL
);

CREATE INDEX IX_LocationAttributeDefinition_LocationTypeDefinitionId
    ON Location.LocationAttributeDefinition (LocationTypeDefinitionId);

-- Location -- plant hierarchy nodes, self-referential
CREATE TABLE Location.Location (
    Id                          BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LocationTypeDefinitionId    BIGINT          NOT NULL REFERENCES Location.LocationTypeDefinition(Id),
    ParentLocationId            BIGINT          NULL     REFERENCES Location.Location(Id),
    Name                        NVARCHAR(200)   NOT NULL,
    Code                        NVARCHAR(50)    NOT NULL,
    Description                 NVARCHAR(500)   NULL,
    SortOrder                   INT             NOT NULL DEFAULT 0,
    CreatedAt                   DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt                DATETIME2(3)    NULL,
    CONSTRAINT UQ_Location_Code UNIQUE (Code)
);

CREATE INDEX IX_Location_ParentLocationId
    ON Location.Location (ParentLocationId);

CREATE INDEX IX_Location_LocationTypeDefinitionId
    ON Location.Location (LocationTypeDefinitionId);

-- LocationAttribute -- attribute values per location
CREATE TABLE Location.LocationAttribute (
    Id                              BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LocationId                      BIGINT          NOT NULL REFERENCES Location.Location(Id),
    LocationAttributeDefinitionId   BIGINT          NOT NULL REFERENCES Location.LocationAttributeDefinition(Id),
    AttributeValue                  NVARCHAR(255)   NOT NULL,
    CreatedAt                       DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt                       DATETIME2(3)    NULL,
    UpdatedByUserId                 BIGINT          NULL     REFERENCES Location.AppUser(Id)
);

CREATE INDEX IX_LocationAttribute_LocationId
    ON Location.LocationAttribute (LocationId);

CREATE UNIQUE INDEX UX_LocationAttribute_Location_Definition
    ON Location.LocationAttribute (LocationId, LocationAttributeDefinitionId);


-- == SEED: LocationType (5 ISA-95 tiers) ======================

INSERT INTO Location.LocationType (Id, Code, Name, HierarchyLevel, Description) VALUES
    (1, N'Enterprise',  N'Enterprise',   0, N'Top-level organization (MPP Inc.)'),
    (2, N'Site',        N'Site',         1, N'Physical plant/facility'),
    (3, N'Area',        N'Area',         2, N'Subdivision within a site'),
    (4, N'WorkCenter',  N'Work Center',  3, N'Production line or grouping of equipment'),
    (5, N'Cell',        N'Cell',         4, N'Individual station/unit');


-- == SEED: LocationTypeDefinition (15 kinds) ==================

SET IDENTITY_INSERT Location.LocationTypeDefinition ON;

INSERT INTO Location.LocationTypeDefinition (Id, LocationTypeId, Code, Name) VALUES
    ( 1, 1, N'Organization',           N'Organization'),
    ( 2, 2, N'Facility',               N'Facility'),
    ( 3, 3, N'ProductionArea',         N'Production Area'),
    ( 4, 3, N'SupportArea',            N'Support Area'),
    ( 5, 4, N'ProductionLine',         N'Production Line'),
    ( 6, 4, N'InspectionLine',         N'Inspection Line'),
    ( 7, 5, N'Terminal',               N'Terminal'),
    ( 8, 5, N'DieCastMachine',         N'Die Cast Machine'),
    ( 9, 5, N'CNCMachine',             N'CNC Machine'),
    (10, 5, N'TrimPress',              N'Trim Press'),
    (11, 5, N'AssemblyStation',        N'Assembly Station'),
    (12, 5, N'SerializedAssemblyLine', N'Serialized Assembly Line'),
    (13, 5, N'InspectionStation',      N'Inspection Station'),
    (14, 5, N'InventoryLocation',      N'Inventory Location'),
    (15, 5, N'Scale',                  N'Scale');

SET IDENTITY_INSERT Location.LocationTypeDefinition OFF;


-- == SEED: LocationAttributeDefinition (~18 rows) =============

-- Terminal (DefId 7)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description)
VALUES
    (7, N'IpAddress',          N'NVARCHAR', 0, NULL, NULL, 1, N'IP address of the terminal'),
    (7, N'DefaultPrinter',     N'NVARCHAR', 0, NULL, NULL, 2, N'Default Zebra printer name'),
    (7, N'HasBarcodeScanner',  N'BIT',      1, N'1', NULL, 3, N'Whether terminal has a barcode scanner');

-- DieCastMachine (DefId 8)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description)
VALUES
    (8, N'Tonnage',            N'DECIMAL',  0, NULL,  N'tons',    1, N'Machine tonnage rating'),
    (8, N'NumberOfCavities',   N'INT',      0, NULL,  NULL,       2, N'Number of die cavities'),
    (8, N'RefCycleTimeSec',    N'DECIMAL',  0, NULL,  N'seconds', 3, N'Reference cycle time in seconds'),
    (8, N'OeeTarget',          N'DECIMAL',  0, NULL,  NULL,       4, N'OEE target percentage');

-- CNCMachine (DefId 9)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description)
VALUES
    (9, N'RefCycleTimeSec',    N'DECIMAL',  0, NULL,  N'seconds', 1, N'Reference cycle time in seconds'),
    (9, N'OeeTarget',          N'DECIMAL',  0, NULL,  NULL,       2, N'OEE target percentage');

-- TrimPress (DefId 10)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description)
VALUES
    (10, N'RefCycleTimeSec',   N'DECIMAL',  0, NULL,  N'seconds', 1, N'Reference cycle time in seconds'),
    (10, N'OeeTarget',         N'DECIMAL',  0, NULL,  NULL,       2, N'OEE target percentage');

-- InventoryLocation (DefId 14)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description)
VALUES
    (14, N'IsPhysical',        N'BIT',      1, N'1', NULL, 1, N'Whether this is a physical location'),
    (14, N'IsLineside',        N'BIT',      0, N'0', NULL, 2, N'Whether this is a lineside location'),
    (14, N'MaxLotCapacity',    N'INT',      0, NULL, NULL, 3, N'Maximum number of lots this location can hold');

-- Scale (DefId 15)
INSERT INTO Location.LocationAttributeDefinition
    (LocationTypeDefinitionId, AttributeName, DataType, IsRequired, DefaultValue, Uom, SortOrder, Description)
VALUES
    (15, N'OpcTagPath',        N'NVARCHAR', 0, NULL,  NULL, 1, N'OPC tag path for the scale reading'),
    (15, N'WeightUom',         N'NVARCHAR', 0, N'LB', NULL, 2, N'Unit of measure for weight');


-- == DEFERRED FK BACKFILL: Audit.OperationLog =================

ALTER TABLE Audit.OperationLog
    ADD CONSTRAINT FK_OperationLog_TerminalLocationId
    FOREIGN KEY (TerminalLocationId) REFERENCES Location.Location(Id);

ALTER TABLE Audit.OperationLog
    ADD CONSTRAINT FK_OperationLog_LocationId
    FOREIGN KEY (LocationId) REFERENCES Location.Location(Id);


-- == SCHEMA VERSION ===========================================

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0002_plant_model_location_schema',
    'Location schema: 5 tables (LocationType, LocationTypeDefinition, LocationAttributeDefinition, Location, LocationAttribute), seed types/definitions/attributes, deferred FK backfill on Audit.OperationLog'
);

COMMIT;
