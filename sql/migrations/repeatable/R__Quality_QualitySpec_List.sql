-- =============================================
-- Procedure:   Quality.QualitySpec_List
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Returns all QualitySpec records with optional filters
--   for Item and/or OperationTemplate. Includes version counts.
--
-- Parameters (input):
--   @ItemId BIGINT NULL - Filter to specs linked to this Item.
--   @OperationTemplateId BIGINT NULL - Filter to specs linked to this OperationTemplate.
--
-- Returns (result set):
--   All matching specs with header fields and VersionCount.
--
-- Dependencies:
--   Tables: Quality.QualitySpec, Quality.QualitySpecVersion
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Quality.QualitySpec_List
    @ItemId              BIGINT = NULL,
    @OperationTemplateId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        qs.Id,
        qs.Name,
        qs.ItemId,
        i.PartNumber      AS ItemCode,
        i.Description     AS ItemName,
        qs.OperationTemplateId,
        ot.Code           AS OperationTemplateCode,
        ot.Name           AS OperationTemplateName,
        qs.Description,
        qs.CreatedAt,
        (SELECT COUNT(*) FROM Quality.QualitySpecVersion WHERE QualitySpecId = qs.Id) AS VersionCount,
        (SELECT COUNT(*) FROM Quality.QualitySpecVersion
         WHERE QualitySpecId = qs.Id AND PublishedAt IS NOT NULL AND DeprecatedAt IS NULL) AS ActiveVersionCount
    FROM Quality.QualitySpec qs
    LEFT JOIN Parts.Item i ON qs.ItemId = i.Id
    LEFT JOIN Parts.OperationTemplate ot ON qs.OperationTemplateId = ot.Id
    WHERE (@ItemId IS NULL OR qs.ItemId = @ItemId)
      AND (@OperationTemplateId IS NULL OR qs.OperationTemplateId = @OperationTemplateId)
    ORDER BY qs.Name;
END
GO
