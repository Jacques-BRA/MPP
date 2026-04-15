-- =============================================
-- Procedure:   Location.AppUser_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns all AppUser rows, optionally including deprecated records.
--   Orders results by DisplayName ascending.
--   Read-only proc — empty result means no matching rows.
--
-- Parameters:
--   @IncludeDeprecated BIT = 0  - When 1, includes deprecated users in results.
--
-- Result set:
--   All columns from Location.AppUser matching the filter criteria.
--
-- Dependencies:
--   Tables: Location.AppUser
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.AppUser_List
    @IncludeDeprecated BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        AdAccount,
        DisplayName,
        ClockNumber,
        PinHash,
        IgnitionRole,
        CreatedAt,
        DeprecatedAt
    FROM Location.AppUser
    WHERE @IncludeDeprecated = 1
       OR DeprecatedAt IS NULL
    ORDER BY DisplayName;
END;
GO
