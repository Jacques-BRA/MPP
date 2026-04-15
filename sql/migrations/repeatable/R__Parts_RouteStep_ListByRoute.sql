-- =============================================
-- Procedure:   Parts.RouteStep_ListByRoute
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Returns the ordered list of RouteStep rows for a given RouteTemplate,
--   joined to Parts.OperationTemplate for Code/Name. Ordered by
--   SequenceNumber ascending.
--
-- Parameters:
--   @RouteTemplateId BIGINT - Required.
--
-- Result set:
--   Zero or more RouteStep rows ordered by SequenceNumber.
--
-- Dependencies:
--   Tables: Parts.RouteStep, Parts.OperationTemplate
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Parts.RouteStep_ListByRoute
    @RouteTemplateId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        rs.Id,
        rs.RouteTemplateId,
        rs.SequenceNumber,
        rs.OperationTemplateId,
        ot.Code AS OperationCode,
        ot.Name AS OperationName,
        rs.IsRequired,
        rs.Description
    FROM Parts.RouteStep rs
    INNER JOIN Parts.OperationTemplate ot ON ot.Id = rs.OperationTemplateId
    WHERE rs.RouteTemplateId = @RouteTemplateId
    ORDER BY rs.SequenceNumber;
END;
GO
