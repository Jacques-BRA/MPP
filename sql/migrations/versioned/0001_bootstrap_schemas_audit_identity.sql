-- ============================================================
-- Migration:   0001_bootstrap_schemas_audit_identity.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-13
-- Description: Bootstrap migration — creates all application schemas,
--              the SchemaVersion tracking table, audit lookup tables
--              (seeded), the four audit log tables, and the AppUser
--              table with the system bootstrap row.
--
--              This is Phase 1 bedrock. Every CRUD proc in every later
--              phase depends on the audit infrastructure created here.
-- ============================================================

BEGIN TRANSACTION;

-- ── IDEMPOTENCY GUARD ────────────────────────────────────────
IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0001_bootstrap_schemas_audit_identity')
BEGIN
    PRINT 'Migration 0001 already applied — skipping.';
    COMMIT;
    RETURN;
END

-- ── SCHEMAS ──────────────────────────────────────────────────

-- Note: CREATE SCHEMA must be the only statement in a batch when
-- not using EXEC. Using EXEC here so we can stay inside one transaction.

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Location')
    EXEC('CREATE SCHEMA [Location]');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Parts')
    EXEC('CREATE SCHEMA [Parts]');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Lots')
    EXEC('CREATE SCHEMA [Lots]');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Workorder')
    EXEC('CREATE SCHEMA [Workorder]');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Quality')
    EXEC('CREATE SCHEMA [Quality]');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Oee')
    EXEC('CREATE SCHEMA [Oee]');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Audit')
    EXEC('CREATE SCHEMA [Audit]');


-- ── AUDIT LOOKUP TABLES ──────────────────────────────────────

CREATE TABLE Audit.LogSeverity (
    Id      BIGINT          NOT NULL PRIMARY KEY,
    Code    NVARCHAR(20)    NOT NULL,
    Name    NVARCHAR(100)   NOT NULL,
    CONSTRAINT UQ_LogSeverity_Code UNIQUE (Code)
);

CREATE TABLE Audit.LogEventType (
    Id          BIGINT          NOT NULL PRIMARY KEY,
    Code        NVARCHAR(50)    NOT NULL,
    Name        NVARCHAR(200)   NOT NULL,
    Description NVARCHAR(500)   NULL,
    CONSTRAINT UQ_LogEventType_Code UNIQUE (Code)
);

CREATE TABLE Audit.LogEntityType (
    Id          BIGINT          NOT NULL PRIMARY KEY,
    Code        NVARCHAR(50)    NOT NULL,
    Name        NVARCHAR(200)   NOT NULL,
    Description NVARCHAR(500)   NULL,
    CONSTRAINT UQ_LogEntityType_Code UNIQUE (Code)
);


-- ── SEED AUDIT LOOKUPS ───────────────────────────────────────

-- LogSeverity
INSERT INTO Audit.LogSeverity (Id, Code, Name) VALUES
    (1, N'Info',     N'Information'),
    (2, N'Warning',  N'Warning'),
    (3, N'Error',    N'Error'),
    (4, N'Critical', N'Critical');

-- LogEventType — initial set, extensible via future migrations
INSERT INTO Audit.LogEventType (Id, Code, Name, Description) VALUES
    ( 1, N'Created',             N'Created',              N'Entity was created'),
    ( 2, N'Updated',             N'Updated',              N'Entity was modified'),
    ( 3, N'Deprecated',          N'Deprecated',           N'Entity was soft-deleted'),
    ( 4, N'Restored',            N'Restored',             N'Entity was reactivated from deprecated'),
    ( 5, N'LotCreated',          N'LOT Created',          N'A new LOT was created'),
    ( 6, N'LotMoved',            N'LOT Moved',            N'A LOT was moved to a new location'),
    ( 7, N'LotSplit',            N'LOT Split',            N'A LOT was split into sublots'),
    ( 8, N'LotMerged',           N'LOT Merged',           N'LOTs were merged'),
    ( 9, N'LotConsumed',         N'LOT Consumed',         N'A LOT was consumed as material input'),
    (10, N'ProductionRecorded',  N'Production Recorded',  N'Production output was recorded'),
    (11, N'HoldPlaced',          N'Hold Placed',          N'A hold was placed on an entity'),
    (12, N'HoldReleased',        N'Hold Released',        N'A hold was released'),
    (13, N'InspectionRecorded',  N'Inspection Recorded',  N'An inspection result was recorded'),
    (14, N'DowntimeStarted',     N'Downtime Started',     N'A downtime event began'),
    (15, N'DowntimeEnded',       N'Downtime Ended',       N'A downtime event ended'),
    (16, N'ShipmentCreated',     N'Shipment Created',     N'A shipment was created'),
    (17, N'LabelPrinted',        N'Label Printed',        N'A label was printed'),
    (18, N'PinChanged',          N'PIN Changed',          N'User PIN was changed'),
    (19, N'InterfaceCall',       N'Interface Call',        N'External system call made'),
    (20, N'InterfaceResponse',   N'Interface Response',    N'External system response received');

-- LogEntityType — initial set, extensible via future migrations
INSERT INTO Audit.LogEntityType (Id, Code, Name, Description) VALUES
    ( 1, N'Location',           N'Location',              N'Plant hierarchy location'),
    ( 2, N'LocationType',       N'Location Type',         N'ISA-95 location type'),
    ( 3, N'LocationTypeDef',    N'Location Type Def',     N'Polymorphic location kind'),
    ( 4, N'LocationAttrDef',    N'Location Attribute Def',N'Attribute schema for a location kind'),
    ( 5, N'Item',               N'Item',                  N'Part/material master record'),
    ( 6, N'Bom',                N'BOM',                   N'Bill of materials'),
    ( 7, N'Route',              N'Route',                 N'Manufacturing route'),
    ( 8, N'OperationTemplate',  N'Operation Template',    N'Route step template'),
    ( 9, N'Lot',                N'LOT',                   N'LOT tracking entity'),
    (10, N'Container',          N'Container',             N'Physical container'),
    (11, N'WorkOrder',          N'Work Order',            N'Work order'),
    (12, N'QualitySpec',        N'Quality Spec',          N'Quality specification'),
    (13, N'HoldEvent',          N'Hold Event',            N'Quality hold (place/release lifecycle)'),
    (14, N'DefectCode',         N'Defect Code',           N'Defect code reference'),
    (15, N'DowntimeReasonCode', N'Downtime Reason Code',  N'Downtime reason code reference'),
    (16, N'AppUser',            N'Application User',      N'MES user account'),
    (17, N'Shipment',           N'Shipment',              N'Shipping record'),
    (18, N'ContainerConfig',    N'Container Config',      N'Container configuration'),
    (19, N'ItemLocation',       N'Item-Location',         N'Item eligibility at a location'),
    (20, N'DataCollectionField',N'Data Collection Field',  N'Configurable operation data field'),
    (21, N'OpTemplateField',    N'Op Template Field',      N'Operation-to-field junction'),
    (22, N'NonConformance',     N'Non-Conformance',        N'Non-conformance record'),
    (23, N'RouteStep',          N'Route Step',             N'Manufacturing route step'),
    (24, N'SerializedPart',     N'Serialized Part',        N'Individual serial number');


-- ── APPUSER TABLE ────────────────────────────────────────────

CREATE TABLE Location.AppUser (
    Id              BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    AdAccount       NVARCHAR(100)   NOT NULL,
    DisplayName     NVARCHAR(200)   NOT NULL,
    ClockNumber     NVARCHAR(20)    NULL,
    PinHash         NVARCHAR(255)   NULL,
    IgnitionRole    NVARCHAR(100)   NULL,
    CreatedAt       DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    DeprecatedAt    DATETIME2(3)    NULL,
    CONSTRAINT UQ_AppUser_AdAccount UNIQUE (AdAccount)
);

-- Bootstrap row — breaks the chicken-and-egg dependency on @AppUserId
SET IDENTITY_INSERT Location.AppUser ON;

INSERT INTO Location.AppUser (Id, AdAccount, DisplayName, IgnitionRole, CreatedAt)
VALUES (1, N'system.bootstrap', N'System Bootstrap', N'Admin', SYSUTCDATETIME());

SET IDENTITY_INSERT Location.AppUser OFF;


-- ── AUDIT LOG TABLES ─────────────────────────────────────────

-- ConfigLog — successful configuration mutations
CREATE TABLE Audit.ConfigLog (
    Id              BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LoggedAt        DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    UserId          BIGINT          NULL     REFERENCES Location.AppUser(Id),
    LogSeverityId   BIGINT          NOT NULL REFERENCES Audit.LogSeverity(Id),
    LogEventTypeId  BIGINT          NOT NULL REFERENCES Audit.LogEventType(Id),
    LogEntityTypeId BIGINT          NOT NULL REFERENCES Audit.LogEntityType(Id),
    EntityId        BIGINT          NULL,
    Description     NVARCHAR(1000)  NOT NULL,
    OldValue        NVARCHAR(MAX)   NULL,
    NewValue        NVARCHAR(MAX)   NULL
);

CREATE INDEX IX_ConfigLog_LoggedAt        ON Audit.ConfigLog (LoggedAt DESC);
CREATE INDEX IX_ConfigLog_EntityType      ON Audit.ConfigLog (LogEntityTypeId, EntityId, LoggedAt DESC);
CREATE INDEX IX_ConfigLog_User            ON Audit.ConfigLog (UserId, LoggedAt DESC);

-- OperationLog — successful plant-floor actions
CREATE TABLE Audit.OperationLog (
    Id                  BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LoggedAt            DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    UserId              BIGINT          NULL     REFERENCES Location.AppUser(Id),
    TerminalLocationId  BIGINT          NULL,    -- FK added after Location table exists (Phase 2)
    LocationId          BIGINT          NULL,    -- FK added after Location table exists (Phase 2)
    LogSeverityId       BIGINT          NOT NULL REFERENCES Audit.LogSeverity(Id),
    LogEventTypeId      BIGINT          NOT NULL REFERENCES Audit.LogEventType(Id),
    LogEntityTypeId     BIGINT          NOT NULL REFERENCES Audit.LogEntityType(Id),
    EntityId            BIGINT          NULL,
    Description         NVARCHAR(1000)  NOT NULL,
    OldValue            NVARCHAR(MAX)   NULL,
    NewValue            NVARCHAR(MAX)   NULL
);

CREATE INDEX IX_OperationLog_LoggedAt     ON Audit.OperationLog (LoggedAt DESC);
CREATE INDEX IX_OperationLog_EntityType   ON Audit.OperationLog (LogEntityTypeId, EntityId, LoggedAt DESC);
CREATE INDEX IX_OperationLog_User         ON Audit.OperationLog (UserId, LoggedAt DESC);

-- InterfaceLog — external system communications
CREATE TABLE Audit.InterfaceLog (
    Id                  BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LoggedAt            DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    SystemName          NVARCHAR(50)    NOT NULL,
    Direction           NVARCHAR(10)    NOT NULL,
    LogEventTypeId      BIGINT          NOT NULL REFERENCES Audit.LogEventType(Id),
    Description         NVARCHAR(1000)  NOT NULL,
    RequestPayload      NVARCHAR(MAX)   NULL,
    ResponsePayload     NVARCHAR(MAX)   NULL,
    ErrorCondition      NVARCHAR(200)   NULL,
    ErrorDescription    NVARCHAR(1000)  NULL,
    IsHighFidelity      BIT             NOT NULL DEFAULT 0
);

CREATE INDEX IX_InterfaceLog_LoggedAt     ON Audit.InterfaceLog (LoggedAt DESC);
CREATE INDEX IX_InterfaceLog_System       ON Audit.InterfaceLog (SystemName, LoggedAt DESC);

-- FailureLog — attempted but rejected operations
CREATE TABLE Audit.FailureLog (
    Id                  BIGINT          NOT NULL IDENTITY(1,1) PRIMARY KEY,
    AttemptedAt         DATETIME2(3)    NOT NULL DEFAULT SYSUTCDATETIME(),
    AppUserId           BIGINT          NOT NULL REFERENCES Location.AppUser(Id),
    LogEntityTypeId     BIGINT          NOT NULL REFERENCES Audit.LogEntityType(Id),
    EntityId            BIGINT          NULL,
    LogEventTypeId      BIGINT          NOT NULL REFERENCES Audit.LogEventType(Id),
    FailureReason       NVARCHAR(500)   NOT NULL,
    ProcedureName       NVARCHAR(200)   NOT NULL,
    AttemptedParameters NVARCHAR(MAX)   NULL
);

CREATE INDEX IX_FailureLog_AttemptedAt    ON Audit.FailureLog (AttemptedAt DESC);
CREATE INDEX IX_FailureLog_AppUser        ON Audit.FailureLog (AppUserId, AttemptedAt DESC);
CREATE INDEX IX_FailureLog_EntityEvent    ON Audit.FailureLog (LogEntityTypeId, LogEventTypeId, AttemptedAt DESC);
CREATE INDEX IX_FailureLog_ProcedureName  ON Audit.FailureLog (ProcedureName, AttemptedAt DESC);


-- ── SCHEMA VERSION ───────────────────────────────────────────

INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0001_bootstrap_schemas_audit_identity',
    'Bootstrap: 7 application schemas, audit lookups (seeded), AppUser (with bootstrap row), 4 audit log tables with indexes'
);

COMMIT;
