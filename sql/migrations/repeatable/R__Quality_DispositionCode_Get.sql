-- =============================================
-- Procedure:   Quality.DispositionCode_Get
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Returns a single DispositionCode row by Id. Empty result = not found.
--
-- Parameters:
--   @Id BIGINT - PK of the DispositionCode to retrieve. Required.
--
-- Result set:
--   Zero or one row from Quality.DispositionCode.
--
-- Dependencies:
--   Tables: Quality.DispositionCode
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version (OUTPUT params)
--   2026-04-14 - 2.0 - Removed OUTPUT params for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Quality.DispositionCode_Get
    @Id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Code, Name
    FROM Quality.DispositionCode
    WHERE Id = @Id;
END;
GO
