-- ============================================================
-- Repeatable:  R__Audit_Audit_LogOperation.sql
-- Author:      Blue Ridge Automation
-- Modified:    2026-04-13
-- Description: Writes one row to Audit.OperationLog for a successful
--              plant-floor mutation (LOT creation, movement, production
--              recording, holds, etc.). Defined in Phase 1, used by
--              the Plant Floor build (Arc 2).
--
--              Called inside the transaction, atomic with the data —
--              same pattern as Audit_LogConfigChange.
-- ============================================================

CREATE OR ALTER PROCEDURE Audit.Audit_LogOperation
    @AppUserId          BIGINT,
    @TerminalLocationId BIGINT          = NULL,
    @LocationId         BIGINT          = NULL,
    @LogEntityTypeCode  NVARCHAR(50),
    @EntityId           BIGINT          = NULL,
    @LogEventTypeCode   NVARCHAR(50),
    @LogSeverityCode    NVARCHAR(20)    = N'Info',
    @Description        NVARCHAR(1000),
    @OldValue           NVARCHAR(MAX)   = NULL,
    @NewValue           NVARCHAR(MAX)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogSeverityId   BIGINT;
    DECLARE @LogEventTypeId  BIGINT;
    DECLARE @LogEntityTypeId BIGINT;
    DECLARE @NewLogId        BIGINT;

    -- Resolve code strings to IDs
    SELECT @LogSeverityId   = Id FROM Audit.LogSeverity   WHERE Code = @LogSeverityCode;
    SELECT @LogEventTypeId  = Id FROM Audit.LogEventType  WHERE Code = @LogEventTypeCode;
    SELECT @LogEntityTypeId = Id FROM Audit.LogEntityType WHERE Code = @LogEntityTypeCode;

    INSERT INTO Audit.OperationLog (
        LoggedAt,
        UserId,
        TerminalLocationId,
        LocationId,
        LogSeverityId,
        LogEventTypeId,
        LogEntityTypeId,
        EntityId,
        Description,
        OldValue,
        NewValue
    )
    VALUES (
        SYSUTCDATETIME(),
        @AppUserId,
        @TerminalLocationId,
        @LocationId,
        ISNULL(@LogSeverityId, 1),
        ISNULL(@LogEventTypeId, 1),
        ISNULL(@LogEntityTypeId, 1),
        @EntityId,
        @Description,
        @OldValue,
        @NewValue
    );

END;
GO
