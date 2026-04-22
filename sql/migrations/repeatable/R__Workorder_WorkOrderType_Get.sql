-- =============================================
-- Procedure:   Workorder.WorkOrderType_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Returns a single WorkOrderType row by Id. Empty result = not found.
--
-- Parameters:
--   @Id BIGINT - PK. Required.
--
-- Result set:
--   Zero or one WorkOrderType row.
--
-- Dependencies:
--   Tables: Workorder.WorkOrderType
-- =============================================
CREATE OR ALTER PROCEDURE Workorder.WorkOrderType_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name, Description
    FROM Workorder.WorkOrderType
    WHERE Id = @Id;
END;
GO
