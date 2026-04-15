-- =============================================
-- Procedure:   Quality.SampleTriggerCode_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns a single SampleTriggerCode row by Id. Empty result = not found.
--
-- Parameters:
--   @Id BIGINT - PK of the SampleTriggerCode to retrieve. Required.
--
-- Result set:
--   Zero or one row from Quality.SampleTriggerCode.
--
-- Dependencies:
--   Tables: Quality.SampleTriggerCode
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Quality.SampleTriggerCode_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name
    FROM Quality.SampleTriggerCode
    WHERE Id = @Id;
END;
GO
