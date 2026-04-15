-- ============================================================
-- Repeatable:  R__Audit_Audit_LogConfigChange.sql
-- Author:      Blue Ridge Automation
-- Modified:    2026-04-13
-- Description: Writes one row to Audit.ConfigLog for a successful
--              configuration mutation. Called by every Create/Update/
--              Deprecate proc — inside the transaction, atomic with
--              the data.
--
--              Accepts code strings (@LogEntityTypeCode, etc.) and
--              resolves them to IDs internally via the seeded lookup
--              tables. Callers write N'Location', N'Created', N'Info'
--              — self-documenting, no hardcoded IDs.
-- ============================================================

CREATE OR ALTER PROCEDURE Audit.Audit_LogConfigChange
    @AppUserId          BIGINT,
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

    -- If any code failed to resolve, still write the log with available data.
    -- A missing lookup is a seed-data gap, not a reason to silently skip logging.
    INSERT INTO Audit.ConfigLog (
        LoggedAt,
        UserId,
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
        ISNULL(@LogSeverityId, 1),      -- default to Info if code not found
        ISNULL(@LogEventTypeId, 1),      -- default to Created if code not found
        ISNULL(@LogEntityTypeId, 1),     -- default to Location if code not found
        @EntityId,
        @Description,
        @OldValue,
        @NewValue
    );

END;
GO
