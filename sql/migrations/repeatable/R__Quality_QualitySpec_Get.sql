-- =============================================
-- Procedure:   Quality.QualitySpec_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Returns a single QualitySpec record by Id, including
--   derived counts for versions.
--
-- Parameters (input):
--   @Id BIGINT - Required.
--
-- Returns (result set):
--   Single row with spec header fields plus VersionCount.
--
-- Dependencies:
--   Tables: Quality.QualitySpec, Quality.QualitySpecVersion
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Quality.QualitySpec_Get
    @Id BIGINT
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
    WHERE qs.Id = @Id;
END
GO
