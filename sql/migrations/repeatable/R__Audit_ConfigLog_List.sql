-- =============================================
-- Procedure:   Audit.ConfigLog_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns ConfigLog rows within a date range, joined to lookup tables
--   and AppUser. Supports optional filtering by entity type and user.
--   Limited to 1000 rows to prevent unbounded result sets.
--   Read-only proc — empty result means no matching rows.
--
-- Parameters:
--   @StartDate DATETIME2(3)               - Start of date range (inclusive). Required.
--   @EndDate DATETIME2(3)                 - End of date range (inclusive). Required.
--   @LogEntityTypeCode NVARCHAR(50) = NULL - Optional entity type filter.
--   @FilterAppUserId BIGINT = NULL         - Optional user filter.
--
-- Result set:
--   Top 1000 ConfigLog rows with joined lookup names, ordered by LoggedAt DESC.
--
-- Dependencies:
--   Tables: Audit.ConfigLog, Audit.LogEntityType, Audit.LogEventType,
--           Audit.LogSeverity, Location.AppUser
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Audit.ConfigLog_List
    @StartDate          DATETIME2(3),
    @EndDate            DATETIME2(3),
    @LogEntityTypeCode  NVARCHAR(50)    = NULL,
    @FilterAppUserId    BIGINT          = NULL
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
        cl.Id,
        cl.LoggedAt,
        cl.UserId,
        au.DisplayName          AS UserDisplayName,
        cl.LogSeverityId,
        ls.Code                 AS LogSeverityCode,
        cl.LogEventTypeId,
        let.Name                AS LogEventTypeName,
        cl.LogEntityTypeId,
        lent.Name               AS LogEntityTypeName,
        cl.EntityId,
        cl.Description,
        cl.OldValue,
        cl.NewValue
    FROM Audit.ConfigLog            cl
    LEFT JOIN Location.AppUser      au   ON au.Id   = cl.UserId
    INNER JOIN Audit.LogSeverity    ls   ON ls.Id   = cl.LogSeverityId
    INNER JOIN Audit.LogEventType   let  ON let.Id  = cl.LogEventTypeId
    INNER JOIN Audit.LogEntityType  lent ON lent.Id = cl.LogEntityTypeId
    WHERE cl.LoggedAt BETWEEN @StartDate AND @EndDate
      AND (@LogEntityTypeId IS NULL OR cl.LogEntityTypeId = @LogEntityTypeId)
      AND (@FilterAppUserId IS NULL OR cl.UserId = @FilterAppUserId)
    ORDER BY cl.LoggedAt DESC;
END;
GO
