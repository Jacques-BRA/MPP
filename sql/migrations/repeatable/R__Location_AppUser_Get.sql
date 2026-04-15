-- =============================================
-- Procedure:   Location.AppUser_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns a single AppUser row by Id, or an empty result set if not found.
--   Read-only proc — empty result means not found (not an error).
--
-- Parameters:
--   @Id BIGINT  - PK of the AppUser to retrieve. Required.
--
-- Result set:
--   Zero or one row from Location.AppUser.
--
-- Dependencies:
--   Tables: Location.AppUser
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.AppUser_Get
    @Id BIGINT
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
    WHERE Id = @Id;
END;
GO
