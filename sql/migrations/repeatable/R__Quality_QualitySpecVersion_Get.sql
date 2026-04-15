-- =============================================
-- Procedure:   Quality.QualitySpecVersion_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Returns a single QualitySpecVersion by Id with state indicators
--   and attribute count.
--
-- Parameters (input):
--   @Id BIGINT - Required.
--
-- Returns (result set):
--   Single row with version fields and derived state.
--
-- Dependencies:
--   Tables: Quality.QualitySpecVersion, Quality.QualitySpec,
--           Quality.QualitySpecAttribute, Location.AppUser
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Quality.QualitySpecVersion_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        qsv.Id,
        qsv.QualitySpecId,
        qs.Name               AS QualitySpecName,
        qsv.VersionNumber,
        qsv.EffectiveFrom,
        qsv.PublishedAt,
        qsv.DeprecatedAt,
        CASE
            WHEN qsv.DeprecatedAt IS NOT NULL THEN N'Deprecated'
            WHEN qsv.PublishedAt IS NOT NULL THEN N'Published'
            ELSE N'Draft'
        END                   AS State,
        qsv.CreatedByUserId,
        au.DisplayName        AS CreatedByDisplayName,
        qsv.CreatedAt,
        (SELECT COUNT(*) FROM Quality.QualitySpecAttribute WHERE QualitySpecVersionId = qsv.Id) AS AttributeCount
    FROM Quality.QualitySpecVersion qsv
    INNER JOIN Quality.QualitySpec qs ON qsv.QualitySpecId = qs.Id
    LEFT JOIN Location.AppUser au ON qsv.CreatedByUserId = au.Id
    WHERE qsv.Id = @Id;
END
GO
