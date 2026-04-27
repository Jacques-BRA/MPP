-- ============================================================
-- Migration:   0009_phase8_oee_reference.sql
-- Author:      Blue Ridge Automation
-- Date:        2026-04-15
-- Description: Phase 8 — Operations Reference Data. Creates 4 Oee tables:
--                1. Oee.DowntimeReasonType   (seed-only, 6 fixed rows)
--                2. Oee.DowntimeReasonCode   (mutable, ~353 rows from CSV)
--                3. Oee.ShiftSchedule        (mutable, named shift patterns)
--                4. Oee.Shift                (runtime instances; Arc 2 writes)
--              Also adds 2 new Audit.LogEntityType rows
--              (DowntimeReasonCode, ShiftSchedule).
-- ============================================================

BEGIN TRANSACTION;

IF EXISTS (SELECT 1 FROM dbo.SchemaVersion WHERE MigrationId = '0009_phase8_oee_reference')
BEGIN
    PRINT 'Migration 0009 already applied — skipping.';
    COMMIT;
    RETURN;
END

-- ============================================================
-- == Oee.DowntimeReasonType — seed-only, read-only ===========
-- ============================================================
-- Same pattern as Lots.LotStatusCode and Location.LocationType:
-- seeded in this migration with deterministic Ids; no CRUD procs.

CREATE TABLE Oee.DowntimeReasonType (
    Id   BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(30)   NOT NULL,
    Name NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_DowntimeReasonType_Code UNIQUE (Code)
);

SET IDENTITY_INSERT Oee.DowntimeReasonType ON;
INSERT INTO Oee.DowntimeReasonType (Id, Code, Name) VALUES
    (1, N'Equipment',     N'Equipment'),
    (2, N'Miscellaneous', N'Miscellaneous'),
    (3, N'Mold',          N'Mold'),
    (4, N'Quality',       N'Quality'),
    (5, N'Setup',         N'Setup'),
    (6, N'Unscheduled',   N'Unscheduled');
SET IDENTITY_INSERT Oee.DowntimeReasonType OFF;


-- ============================================================
-- == Oee.DowntimeReasonCode — mutable, full CRUD ============
-- ============================================================
-- AreaLocationId:        NOT NULL — every code belongs to an Area.
-- DowntimeReasonTypeId:  NULL OK — CSV has some rows with missing TypeDesc;
--                        bulk-load inserts them NULL and the UI flags for
--                        engineering backfill (Phase 8 Q-B decision).
-- DowntimeSourceCodeId:  NULL OK — CSV has no source column; populated
--                        later via _Update (Phase 8 Q-3 decision).

CREATE TABLE Oee.DowntimeReasonCode (
    Id                     BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Code                   NVARCHAR(20)   NOT NULL,
    Description            NVARCHAR(500)  NOT NULL,
    AreaLocationId         BIGINT         NOT NULL,
    DowntimeReasonTypeId   BIGINT         NULL,
    DowntimeSourceCodeId   BIGINT         NULL,
    IsExcused              BIT            NOT NULL DEFAULT 0,
    CreatedAt              DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId        BIGINT         NOT NULL,
    UpdatedAt              DATETIME2(3)   NULL,
    UpdatedByUserId        BIGINT         NULL,
    DeprecatedAt           DATETIME2(3)   NULL,
    CONSTRAINT UQ_DowntimeReasonCode_Code UNIQUE (Code),
    CONSTRAINT FK_DowntimeReasonCode_Area
        FOREIGN KEY (AreaLocationId)       REFERENCES Location.Location(Id),
    CONSTRAINT FK_DowntimeReasonCode_Type
        FOREIGN KEY (DowntimeReasonTypeId) REFERENCES Oee.DowntimeReasonType(Id),
    CONSTRAINT FK_DowntimeReasonCode_Source
        FOREIGN KEY (DowntimeSourceCodeId) REFERENCES Oee.DowntimeSourceCode(Id),
    CONSTRAINT FK_DowntimeReasonCode_CreatedBy
        FOREIGN KEY (CreatedByUserId)      REFERENCES Location.AppUser(Id),
    CONSTRAINT FK_DowntimeReasonCode_UpdatedBy
        FOREIGN KEY (UpdatedByUserId)      REFERENCES Location.AppUser(Id)
);

CREATE INDEX IX_DowntimeReasonCode_Area
    ON Oee.DowntimeReasonCode (AreaLocationId) WHERE DeprecatedAt IS NULL;
CREATE INDEX IX_DowntimeReasonCode_Type
    ON Oee.DowntimeReasonCode (DowntimeReasonTypeId) WHERE DeprecatedAt IS NULL;


-- ============================================================
-- == Oee.ShiftSchedule — mutable, full CRUD =================
-- ============================================================
-- DaysOfWeekBitmask: Mon=1, Tue=2, Wed=4, Thu=8, Fri=16, Sat=32, Sun=64.
--                    e.g. Mon-Fri = 31, Sat+Sun = 96.
-- StartTime / EndTime: TIME(0) — seconds precision adequate.
-- Shift spans midnight when EndTime < StartTime (proc handles this).

CREATE TABLE Oee.ShiftSchedule (
    Id                  BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Name                NVARCHAR(100)  NOT NULL,
    Description         NVARCHAR(500)  NULL,
    StartTime           TIME(0)        NOT NULL,
    EndTime             TIME(0)        NOT NULL,
    DaysOfWeekBitmask   INT            NOT NULL,
    EffectiveFrom       DATE           NOT NULL,
    CreatedAt           DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedByUserId     BIGINT         NOT NULL,
    UpdatedAt           DATETIME2(3)   NULL,
    UpdatedByUserId     BIGINT         NULL,
    DeprecatedAt        DATETIME2(3)   NULL,
    CONSTRAINT UQ_ShiftSchedule_Name UNIQUE (Name),
    CONSTRAINT CK_ShiftSchedule_BitmaskRange
        CHECK (DaysOfWeekBitmask BETWEEN 1 AND 127),
    CONSTRAINT FK_ShiftSchedule_CreatedBy
        FOREIGN KEY (CreatedByUserId) REFERENCES Location.AppUser(Id),
    CONSTRAINT FK_ShiftSchedule_UpdatedBy
        FOREIGN KEY (UpdatedByUserId) REFERENCES Location.AppUser(Id)
);


-- ============================================================
-- == Oee.Shift — runtime instances (Arc 2 writes) ============
-- ============================================================
-- Created at runtime by the plant-floor shift controller when a
-- scheduled shift starts. Config Tool only reads (_List) for admin
-- visibility. ActualEnd NULL while the shift is active.

CREATE TABLE Oee.Shift (
    Id                BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ShiftScheduleId   BIGINT         NOT NULL,
    ActualStart       DATETIME2(3)   NOT NULL,
    ActualEnd         DATETIME2(3)   NULL,
    Remarks           NVARCHAR(500)  NULL,
    CreatedAt         DATETIME2(3)   NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Shift_Schedule
        FOREIGN KEY (ShiftScheduleId) REFERENCES Oee.ShiftSchedule(Id)
);

CREATE INDEX IX_Shift_ActualStart ON Oee.Shift (ActualStart DESC);
CREATE INDEX IX_Shift_Schedule_Start
    ON Oee.Shift (ShiftScheduleId, ActualStart DESC);


-- ============================================================
-- == Audit.LogEntityType — add Phase 8 entry ================
-- ============================================================
-- DowntimeReasonCode was already seeded at Id=15 in the bootstrap
-- migration (0001). Only ShiftSchedule is new for Phase 8.
-- Existing max Id after Phase 7 is 29 (QualitySpecAttribute).

INSERT INTO Audit.LogEntityType (Id, Code, Name, Description) VALUES
    (30, N'ShiftSchedule', N'Shift Schedule', N'Named shift pattern (start/end time, days of week, effective date)');


-- ============================================================
-- == Record migration =======================================
-- ============================================================
INSERT INTO dbo.SchemaVersion (MigrationId, Description)
VALUES (
    '0009_phase8_oee_reference',
    'Phase 8: Oee.DowntimeReasonType (seed 6), Oee.DowntimeReasonCode (mutable), Oee.ShiftSchedule (mutable), Oee.Shift (runtime). +1 LogEntityType row (ShiftSchedule); DowntimeReasonCode already seeded in bootstrap at Id=15.'
);

COMMIT TRANSACTION;
PRINT 'Migration 0009 completed: 4 Oee tables created, 6 DowntimeReasonType seed rows inserted, 1 LogEntityType row added (ShiftSchedule).';
