-- =============================================
-- Procedure:   Quality.QualitySpecAttribute_ListByVersion
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Returns all attributes for a given QualitySpecVersion,
--   ordered by SortOrder ascending.
--
-- Parameters (input):
--   @QualitySpecVersionId BIGINT - Required.
--
-- Returns (result set):
--   All attributes with their configuration.
--
-- Dependencies:
--   Tables: Quality.QualitySpecAttribute
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Quality.QualitySpecAttribute_ListByVersion
    @QualitySpecVersionId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Id,
        QualitySpecVersionId,
        AttributeName,
        DataType,
        Uom,
        TargetValue,
        LowerLimit,
        UpperLimit,
        IsRequired,
        SortOrder
    FROM Quality.QualitySpecAttribute
    WHERE QualitySpecVersionId = @QualitySpecVersionId
    ORDER BY SortOrder ASC;
END
GO
