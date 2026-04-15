-- =============================================
-- Procedure:   Parts.OperationTemplateField_ListByTemplate
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns the active OperationTemplateField rows for a given
--   OperationTemplate, joined to Parts.DataCollectionField for
--   Code/Name. Ordered by DataCollectionField.Code.
--
-- Parameters:
--   @OperationTemplateId BIGINT - Required.
--
-- Result set:
--   Zero or more OperationTemplateField rows with joined
--   DataCollectionField Code and Name, active only.
--
-- Dependencies:
--   Tables: Parts.OperationTemplateField, Parts.DataCollectionField
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.OperationTemplateField_ListByTemplate
    @OperationTemplateId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        otf.Id,
        otf.OperationTemplateId,
        otf.DataCollectionFieldId,
        dcf.Code              AS DataCollectionFieldCode,
        dcf.Name              AS DataCollectionFieldName,
        otf.IsRequired,
        otf.CreatedAt,
        otf.DeprecatedAt
    FROM Parts.OperationTemplateField otf
    INNER JOIN Parts.DataCollectionField dcf ON dcf.Id = otf.DataCollectionFieldId
    WHERE otf.OperationTemplateId = @OperationTemplateId
      AND otf.DeprecatedAt IS NULL
    ORDER BY dcf.Code;
END;
GO
