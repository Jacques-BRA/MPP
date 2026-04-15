-- ============================================================
-- Repeatable:  R__Audit_Audit_LogInterfaceCall.sql
-- Author:      Blue Ridge Automation
-- Modified:    2026-04-13
-- Description: Writes one row to Audit.InterfaceLog for an external
--              system communication (AIM, Zebra, Macola, Intelex).
--              Per FRS 3.17.4, @IsHighFidelity controls whether the
--              full request/response payloads are stored or just the
--              metadata.
-- ============================================================

CREATE OR ALTER PROCEDURE Audit.Audit_LogInterfaceCall
    @SystemName         NVARCHAR(50),
    @Direction          NVARCHAR(10),
    @LogEventTypeCode   NVARCHAR(50),
    @Description        NVARCHAR(1000),
    @RequestPayload     NVARCHAR(MAX)   = NULL,
    @ResponsePayload    NVARCHAR(MAX)   = NULL,
    @ErrorCondition     NVARCHAR(200)   = NULL,
    @ErrorDescription   NVARCHAR(1000)  = NULL,
    @IsHighFidelity     BIT             = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogEventTypeId BIGINT;
    DECLARE @NewLogId       BIGINT;

    -- Resolve code string to ID
    SELECT @LogEventTypeId = Id FROM Audit.LogEventType WHERE Code = @LogEventTypeCode;

    INSERT INTO Audit.InterfaceLog (
        LoggedAt,
        SystemName,
        Direction,
        LogEventTypeId,
        Description,
        RequestPayload,
        ResponsePayload,
        ErrorCondition,
        ErrorDescription,
        IsHighFidelity
    )
    VALUES (
        SYSUTCDATETIME(),
        @SystemName,
        @Direction,
        ISNULL(@LogEventTypeId, 19),     -- default to InterfaceCall
        @Description,
        CASE WHEN @IsHighFidelity = 1 THEN @RequestPayload  ELSE NULL END,
        CASE WHEN @IsHighFidelity = 1 THEN @ResponsePayload ELSE NULL END,
        @ErrorCondition,
        @ErrorDescription,
        @IsHighFidelity
    );

    SET @NewLogId = SCOPE_IDENTITY();

END;
GO
