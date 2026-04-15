-- =============================================
-- Procedure:   Audit.FailureLog_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns FailureLog rows within a date range, joined to lookup tables
--   and AppUser. Supports optional filtering by entity type, user, and
--   procedure name. Limited to 1000 rows to prevent unbounded result sets.
--   Read-only proc — empty result means no matching rows.
--
-- Parameters:
--   @StartDate DATETIME2(3)                 - Start of date range (inclusive). Required.
--   @EndDate DATETIME2(3)                   - End of date range (inclusive). Required.
--   @LogEntityTypeCode NVARCHAR(50) = NULL  - Optional entity type filter.
--   @FilterAppUserId BIGINT = NULL          - Optional user filter.
--   @ProcedureName NVARCHAR(200) = NULL     - Optional procedure name filter.
--
-- Result set:
--   Top 1000 FailureLog rows with joined lookup names, ordered by AttemptedAt DESC.
--
-- Dependencies:
--   Tables: Audit.FailureLog, Audit.LogEntityType, Audit.LogEventType,
--           Location.AppUser
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Audit.FailureLog_List
    @StartDate          DATETIME2(3),
    @EndDate            DATETIME2(3),
    @LogEntityTypeCode  NVARCHAR(50)    = NULL,
    @FilterAppUserId    BIGINT          = NULL,
    @ProcedureName      NVARCHAR(200)   = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Resolve optional entity type filter
    DECLARE @LogEntityTypeId BIGINT = NULL;

    IF @LogEntityTypeCode IS NOT NULL
    BEGIN
        SELECT @LogEntityTypeId = Id
        FROM Audit.LogEntityType
        WHERE Code = @LogEntityTypeCode;

        -- Filter specified but not found → empty result
        IF @LogEntityTypeId IS NULL
            RETURN;
    END

    SELECT TOP (1000)
        fl.Id,
        fl.AttemptedAt,
        fl.AppUserId,
        au.DisplayName          AS UserDisplayName,
        fl.LogEntityTypeId,
        lent.Name               AS LogEntityTypeName,
        fl.EntityId,
        fl.LogEventTypeId,
        let.Name                AS LogEventTypeName,
        fl.FailureReason,
        fl.ProcedureName,
        fl.AttemptedParameters
    FROM Audit.FailureLog           fl
    INNER JOIN Location.AppUser     au   ON au.Id   = fl.AppUserId
    INNER JOIN Audit.LogEntityType  lent ON lent.Id = fl.LogEntityTypeId
    INNER JOIN Audit.LogEventType   let  ON let.Id  = fl.LogEventTypeId
    WHERE fl.AttemptedAt BETWEEN @StartDate AND @EndDate
      AND (@LogEntityTypeId IS NULL OR fl.LogEntityTypeId = @LogEntityTypeId)
      AND (@FilterAppUserId IS NULL OR fl.AppUserId = @FilterAppUserId)
      AND (@ProcedureName   IS NULL OR fl.ProcedureName = @ProcedureName)
    ORDER BY fl.AttemptedAt DESC;
END;
GO
