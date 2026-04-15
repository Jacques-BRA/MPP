-- =============================================
-- Procedure:   Location.AppUser_GetByClockNumber
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Looks up an AppUser by clock number for shop-floor PIN authentication.
--   Returns zero or one row.
--   Read-only proc — empty result means not found.
--
-- Parameters:
--   @ClockNumber NVARCHAR(20) - Clock number to look up. Required.
--
-- Result set:
--   Zero or one row from Location.AppUser matching the ClockNumber.
--
-- Dependencies:
--   Tables: Location.AppUser
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.AppUser_GetByClockNumber
    @ClockNumber NVARCHAR(20)
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
    WHERE ClockNumber = @ClockNumber
      AND DeprecatedAt IS NULL;
END;
GO
