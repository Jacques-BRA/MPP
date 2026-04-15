-- ============================================================
-- Repeatable:  R__Audit_Audit_LogFailure.sql
-- Author:      Blue Ridge Automation
-- Modified:    2026-04-13
-- Description: Writes one row to Audit.FailureLog for an attempted
--              but rejected operation — parameter validation failures,
--              business rule violations, and caught exceptions.
--
--              Called from every validation-failure path (before RETURN)
--              and every CATCH handler (after ROLLBACK, wrapped in
--              nested TRY/CATCH to avoid masking the original error).
--
--              This proc must be safe to call outside of any transaction
--              context — it commits its own insert standalone.
-- ============================================================

CREATE OR ALTER PROCEDURE Audit.Audit_LogFailure
    @AppUserId           BIGINT,
    @LogEntityTypeCode   NVARCHAR(50),
    @EntityId            BIGINT          = NULL,
    @LogEventTypeCode    NVARCHAR(50),
    @FailureReason       NVARCHAR(500),
    @ProcedureName       NVARCHAR(200),
    @AttemptedParameters NVARCHAR(MAX)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogEventTypeId  BIGINT;
    DECLARE @LogEntityTypeId BIGINT;
    DECLARE @NewLogId        BIGINT;

    -- Resolve code strings to IDs
    SELECT @LogEventTypeId  = Id FROM Audit.LogEventType  WHERE Code = @LogEventTypeCode;
    SELECT @LogEntityTypeId = Id FROM Audit.LogEntityType WHERE Code = @LogEntityTypeCode;

    INSERT INTO Audit.FailureLog (
        AttemptedAt,
        AppUserId,
        LogEntityTypeId,
        EntityId,
        LogEventTypeId,
        FailureReason,
        ProcedureName,
        AttemptedParameters
    )
    VALUES (
        SYSUTCDATETIME(),
        @AppUserId,
        ISNULL(@LogEntityTypeId, 1),     -- default if code not found
        @EntityId,
        ISNULL(@LogEventTypeId, 1),      -- default if code not found
        @FailureReason,
        @ProcedureName,
        @AttemptedParameters
    );

END;
GO
