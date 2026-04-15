-- =============================================
-- Procedure:   Parts.ContainerConfig_GetByItem
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns the active ContainerConfig for a given Item. Empty result =
--   no active config. There is at most one active config per Item
--   (enforced by filtered unique index UQ_ContainerConfig_ActiveItemId).
--
--   Includes ClosureMethod and TargetWeight — nullable columns added per
--   OI-02 for anticipated scale-driven container closure on non-serialized
--   lines (pending MPP customer validation). Callers should expect NULL
--   until OI-02 is resolved.
--
-- Parameters:
--   @ItemId BIGINT - FK → Parts.Item. Required.
--
-- Result set:
--   Zero or one ContainerConfig row.
--
-- Dependencies:
--   Tables: Parts.ContainerConfig
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.ContainerConfig_GetByItem
    @ItemId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id, ItemId, TraysPerContainer, PartsPerTray, IsSerialized,
        DunnageCode, CustomerCode,
        ClosureMethod, TargetWeight,
        CreatedAt, UpdatedAt, DeprecatedAt
    FROM Parts.ContainerConfig
    WHERE ItemId = @ItemId
      AND DeprecatedAt IS NULL;
END;
GO
