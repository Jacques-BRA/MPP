-- =============================================
-- Procedure:   Quality.QualitySpecVersion_ListBySpec
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Returns all versions for a given QualitySpec, ordered by
--   VersionNumber descending (newest first).
--
-- Parameters (input):
--   @QualitySpecId BIGINT - Required.
--
-- Returns (result set):
--   All versions with state indicators and attribute counts.
--
-- Dependencies:
--   Tables: Quality.QualitySpecVersion, Quality.QualitySpecAttribute
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Quality.QualitySpecVersion_ListBySpec
    @QualitySpecId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        qsv.Id,
        qsv.QualitySpecId,
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
    LEFT JOIN Location.AppUser au ON qsv.CreatedByUserId = au.Id
    WHERE qsv.QualitySpecId = @QualitySpecId
    ORDER BY qsv.VersionNumber DESC;
END
GO
