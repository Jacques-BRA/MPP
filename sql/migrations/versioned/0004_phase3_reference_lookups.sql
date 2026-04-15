-- ============================================================
-- Migration:   0004_phase3_reference_lookups.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-13
-- Description: Phase 3 — Reference Lookups. Creates 16 code tables
--              across 5 schemas (Lots, Parts, Quality, Oee, Workorder).
--              13 are read-only {Id, Code, Name} (+BlocksProduction on
--              LotStatusCode); 3 are mutable with Description +
--              CreatedAt + DeprecatedAt.
--
--              All tables seeded with deterministic Ids via
--              SET IDENTITY_INSERT. Values sourced from MPP_MES_DATA_MODEL.md
--              except LabelTypeCode (proposed from Honda shipping conventions)
--              and WorkOrderStatus (PascalCased from the stale UPPER_SNAKE
--              values in v0.4.1).
--
--              Also adds 2 new Audit.LogEntityType rows for Uom and
--              ItemType (DataCollectionField already seeded at Id=20).
-- ============================================================

BEGIN TRANSACTION;

-- Guard: skip if already applied
IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0004_phase3_reference_lookups')
BEGIN
    PRINT 'Migration 0004 already applied — skipping.';
    COMMIT;
    RETURN;
END

-- ============================================================
-- == LOTS SCHEMA =============================================
-- ============================================================

-- LotOriginType — read-only
CREATE TABLE Lots.LotOriginType (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(30)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_LotOriginType_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Lots.LotOriginType ON;
INSERT INTO Lots.LotOriginType (Id, Code, Name) VALUES
    (1, N'Manufactured',    N'Manufactured'),
    (2, N'Received',        N'Received'),
    (3, N'ReceivedOffsite', N'Received Offsite');
SET IDENTITY_INSERT Lots.LotOriginType OFF;


-- LotStatusCode — read-only, plus BlocksProduction flag
CREATE TABLE Lots.LotStatusCode (
    Id               BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code             NVARCHAR(20)   NOT NULL,
    Name             NVARCHAR(100)  NOT NULL,
    BlocksProduction BIT            NOT NULL DEFAULT 0,
    CONSTRAINT UQ_LotStatusCode_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Lots.LotStatusCode ON;
INSERT INTO Lots.LotStatusCode (Id, Code, Name, BlocksProduction) VALUES
    (1, N'Good',   N'Good',   0),
    (2, N'Hold',   N'Hold',   1),
    (3, N'Scrap',  N'Scrap',  1),
    (4, N'Closed', N'Closed', 0);
SET IDENTITY_INSERT Lots.LotStatusCode OFF;


-- ContainerStatusCode — read-only
CREATE TABLE Lots.ContainerStatusCode (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(20)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_ContainerStatusCode_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Lots.ContainerStatusCode ON;
INSERT INTO Lots.ContainerStatusCode (Id, Code, Name) VALUES
    (1, N'Open',     N'Open'),
    (2, N'Complete', N'Complete'),
    (3, N'Shipped',  N'Shipped'),
    (4, N'Hold',     N'Hold'),
    (5, N'Void',     N'Void');
SET IDENTITY_INSERT Lots.ContainerStatusCode OFF;


-- GenealogyRelationshipType — read-only
CREATE TABLE Lots.GenealogyRelationshipType (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(20)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_GenealogyRelationshipType_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Lots.GenealogyRelationshipType ON;
INSERT INTO Lots.GenealogyRelationshipType (Id, Code, Name) VALUES
    (1, N'Split',       N'Split'),
    (2, N'Merge',       N'Merge'),
    (3, N'Consumption', N'Consumption');
SET IDENTITY_INSERT Lots.GenealogyRelationshipType OFF;


-- PrintReasonCode — read-only
CREATE TABLE Lots.PrintReasonCode (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(50)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_PrintReasonCode_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Lots.PrintReasonCode ON;
INSERT INTO Lots.PrintReasonCode (Id, Code, Name) VALUES
    (1, N'Initial',             N'Initial'),
    (2, N'ReprintDamaged',      N'Reprint — Damaged'),
    (3, N'Split',               N'Split'),
    (4, N'Merge',               N'Merge'),
    (5, N'SortCageReIdentify',  N'Sort Cage Re-identify');
SET IDENTITY_INSERT Lots.PrintReasonCode OFF;


-- LabelTypeCode — read-only (values proposed — Honda shipping conventions)
CREATE TABLE Lots.LabelTypeCode (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(50)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_LabelTypeCode_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Lots.LabelTypeCode ON;
INSERT INTO Lots.LabelTypeCode (Id, Code, Name) VALUES
    (1, N'Primary',   N'Primary Shipping Label'),
    (2, N'Container', N'Container Label'),
    (3, N'Master',    N'Master Shipping Label'),
    (4, N'Void',      N'Void Replacement Label');
SET IDENTITY_INSERT Lots.LabelTypeCode OFF;


-- ============================================================
-- == QUALITY SCHEMA ==========================================
-- ============================================================

-- InspectionResultCode — read-only
CREATE TABLE Quality.InspectionResultCode (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(20)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_InspectionResultCode_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Quality.InspectionResultCode ON;
INSERT INTO Quality.InspectionResultCode (Id, Code, Name) VALUES
    (1, N'Pass',        N'Pass'),
    (2, N'Fail',        N'Fail'),
    (3, N'Conditional', N'Conditional');
SET IDENTITY_INSERT Quality.InspectionResultCode OFF;


-- SampleTriggerCode — read-only
CREATE TABLE Quality.SampleTriggerCode (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(30)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_SampleTriggerCode_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Quality.SampleTriggerCode ON;
INSERT INTO Quality.SampleTriggerCode (Id, Code, Name) VALUES
    (1, N'FirstPiece', N'First Piece'),
    (2, N'LastPiece',  N'Last Piece'),
    (3, N'Hourly',     N'Hourly'),
    (4, N'Random',     N'Random');
SET IDENTITY_INSERT Quality.SampleTriggerCode OFF;


-- HoldTypeCode — read-only
CREATE TABLE Quality.HoldTypeCode (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(30)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_HoldTypeCode_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Quality.HoldTypeCode ON;
INSERT INTO Quality.HoldTypeCode (Id, Code, Name) VALUES
    (1, N'QualityHold',     N'Quality Hold'),
    (2, N'EngineeringHold', N'Engineering Hold'),
    (3, N'CustomerHold',    N'Customer Hold');
SET IDENTITY_INSERT Quality.HoldTypeCode OFF;


-- DispositionCode — read-only
CREATE TABLE Quality.DispositionCode (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(30)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_DispositionCode_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Quality.DispositionCode ON;
INSERT INTO Quality.DispositionCode (Id, Code, Name) VALUES
    (1, N'UseAsIs',          N'Use As-Is'),
    (2, N'Rework',           N'Rework'),
    (3, N'Scrap',            N'Scrap'),
    (4, N'ReturnToSupplier', N'Return to Supplier');
SET IDENTITY_INSERT Quality.DispositionCode OFF;


-- ============================================================
-- == OEE SCHEMA ==============================================
-- ============================================================

-- DowntimeSourceCode — read-only
CREATE TABLE Oee.DowntimeSourceCode (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(20)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_DowntimeSourceCode_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Oee.DowntimeSourceCode ON;
INSERT INTO Oee.DowntimeSourceCode (Id, Code, Name) VALUES
    (1, N'Operator', N'Operator'),
    (2, N'PLC',      N'PLC'),
    (3, N'System',   N'System');
SET IDENTITY_INSERT Oee.DowntimeSourceCode OFF;


-- ============================================================
-- == WORKORDER SCHEMA ========================================
-- ============================================================

-- OperationStatus — read-only
CREATE TABLE Workorder.OperationStatus (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(20)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_OperationStatus_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Workorder.OperationStatus ON;
INSERT INTO Workorder.OperationStatus (Id, Code, Name) VALUES
    (1, N'Pending',    N'Pending'),
    (2, N'InProgress', N'In Progress'),
    (3, N'Completed',  N'Completed'),
    (4, N'Skipped',    N'Skipped');
SET IDENTITY_INSERT Workorder.OperationStatus OFF;


-- WorkOrderStatus — read-only (PascalCased from stale UPPER_SNAKE values)
CREATE TABLE Workorder.WorkOrderStatus (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(20)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_WorkOrderStatus_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Workorder.WorkOrderStatus ON;
INSERT INTO Workorder.WorkOrderStatus (Id, Code, Name) VALUES
    (1, N'Created',    N'Created'),
    (2, N'InProgress', N'In Progress'),
    (3, N'Completed',  N'Completed'),
    (4, N'Cancelled',  N'Cancelled');
SET IDENTITY_INSERT Workorder.WorkOrderStatus OFF;


-- ============================================================
-- == PARTS SCHEMA ============================================
-- ============================================================

-- Uom — mutable (engineering can add)
CREATE TABLE Parts.Uom (
    Id           BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code         NVARCHAR(20)   NOT NULL,
    Name         NVARCHAR(100)  NOT NULL,
    Description  NVARCHAR(500)  NULL,
    CreatedAt    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt DATETIME2(3)   NULL,
    CONSTRAINT UQ_Uom_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Parts.Uom ON;
INSERT INTO Parts.Uom (Id, Code, Name, Description) VALUES
    (1, N'EA',  N'Each',       N'Discrete unit count'),
    (2, N'LB',  N'Pound',      N'Pound mass (imperial)'),
    (3, N'KG',  N'Kilogram',   N'Kilogram (metric)'),
    (4, N'IN',  N'Inch',       N'Inch (imperial length)'),
    (5, N'MM',  N'Millimeter', N'Millimeter (metric length)'),
    (6, N'PCS', N'Pieces',     N'Piece count');
SET IDENTITY_INSERT Parts.Uom OFF;


-- ItemType — mutable (rarely extended)
CREATE TABLE Parts.ItemType (
    Id           BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code         NVARCHAR(30)   NOT NULL,
    Name         NVARCHAR(100)  NOT NULL,
    Description  NVARCHAR(500)  NULL,
    CreatedAt    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt DATETIME2(3)   NULL,
    CONSTRAINT UQ_ItemType_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Parts.ItemType ON;
INSERT INTO Parts.ItemType (Id, Code, Name, Description) VALUES
    (1, N'RawMaterial',  N'Raw Material',  N'Incoming raw material (e.g., aluminum ingot)'),
    (2, N'Component',    N'Component',     N'Manufactured or purchased component'),
    (3, N'SubAssembly',  N'Sub-Assembly',  N'Intermediate assembly'),
    (4, N'FinishedGood', N'Finished Good', N'Final shippable product to Honda'),
    (5, N'PassThrough',  N'Pass-Through',  N'Item that passes through MPP without processing');
SET IDENTITY_INSERT Parts.ItemType OFF;


-- DataCollectionField — mutable (engineering can add new fields)
CREATE TABLE Parts.DataCollectionField (
    Id           BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code         NVARCHAR(50)   NOT NULL,
    Name         NVARCHAR(100)  NOT NULL,
    Description  NVARCHAR(500)  NULL,
    CreatedAt    DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt DATETIME2(3)   NULL,
    CONSTRAINT UQ_DataCollectionField_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Parts.DataCollectionField ON;
INSERT INTO Parts.DataCollectionField (Id, Code, Name, Description) VALUES
    (1, N'MaterialVerification', N'Material Verification', N'Operator must verify the material lot at this step'),
    (2, N'SerialNumber',         N'Serial Number',         N'A serial number is captured/assigned at this step'),
    (3, N'DieInfo',              N'Die Info',              N'Die identifier and status are captured'),
    (4, N'CavityInfo',           N'Cavity Info',           N'Cavity count and/or identifiers are captured'),
    (5, N'Weight',               N'Weight',               N'Weight reading is captured (typically via scale)'),
    (6, N'GoodCount',            N'Good Count',            N'Good part count is captured'),
    (7, N'BadCount',             N'Bad Count',             N'Reject/bad part count is captured');
SET IDENTITY_INSERT Parts.DataCollectionField OFF;


-- ============================================================
-- == AUDIT.LogEntityType — add Uom and ItemType ==============
-- ============================================================
-- (DataCollectionField already seeded at Id=20 in migration 0001)

INSERT INTO Audit.LogEntityType (Id, Code, Name, Description) VALUES
    (25, N'Uom',      N'Unit of Measure', N'Parts.Uom reference data'),
    (26, N'ItemType', N'Item Type',       N'Parts.ItemType reference data');


-- == VERSION TRACKING ========================================

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0004_phase3_reference_lookups',
    'Phase 3: 16 code tables across 5 schemas (13 read-only, 3 mutable) with seed data; +2 Audit.LogEntityType rows'
);

COMMIT;
