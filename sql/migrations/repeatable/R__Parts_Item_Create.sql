-- =============================================
-- Procedure:   Parts.Item_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Creates a new Item row. Validates ItemTypeId, UomId, and
--   WeightUomId FKs; enforces PartNumber uniqueness. Requires
--   WeightUomId when UnitWeight is provided (the two must be
--   paired — weight without UOM is ambiguous).
--
--   Sets CreatedByUserId = @AppUserId.
--
-- Parameters (input):
--   @PartNumber NVARCHAR(50)       - Required. Unique.
--   @ItemTypeId BIGINT             - FK → Parts.ItemType. Required.
--   @Description NVARCHAR(500) NULL
--   @MacolaPartNumber NVARCHAR(50) NULL
--   @DefaultSubLotQty INT NULL
--   @MaxLotSize INT NULL
--   @UomId BIGINT                  - FK → Parts.Uom. Required.
--   @UnitWeight DECIMAL(10,4) NULL
--   @WeightUomId BIGINT NULL       - FK → Parts.Uom. Required if UnitWeight provided.
--   @CountryOfOrigin NVARCHAR(2) NULL - ISO 3166-1 alpha-2. OI-19 (Phase E).
--   @AppUserId BIGINT              - User performing action. Required.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR), NewId (BIGINT).
--   Status=1 on success, 0 on failure. NewId is NULL on failure.
--
-- Dependencies:
--   Tables: Parts.Item, Parts.ItemType, Parts.Uom
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Error Handling:
--   Three-tier: validation, business rule, CATCH with RAISERROR.
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version (OUTPUT params)
--   2026-04-15 - 2.0 - SELECT result for Named Query compatibility
--   2026-04-23 - 2.1 - Phase G.3: @CountryOfOrigin added (OI-19)
-- =============================================
CREATE OR ALTER PROCEDURE Parts.Item_Create
    @PartNumber       NVARCHAR(50),
    @ItemTypeId       BIGINT,
    @Description      NVARCHAR(500)  = NULL,
    @MacolaPartNumber NVARCHAR(50)   = NULL,
    @DefaultSubLotQty INT            = NULL,
    @MaxLotSize       INT            = NULL,
    @UomId            BIGINT,
    @UnitWeight       DECIMAL(10,4)  = NULL,
    @WeightUomId      BIGINT         = NULL,
    @CountryOfOrigin  NVARCHAR(2)    = NULL,
    @AppUserId        BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';
    DECLARE @NewId   BIGINT        = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Parts.Item_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @PartNumber       AS PartNumber,
                @ItemTypeId       AS ItemTypeId,
                @Description      AS Description,
                @MacolaPartNumber AS MacolaPartNumber,
                @DefaultSubLotQty AS DefaultSubLotQty,
                @MaxLotSize       AS MaxLotSize,
                @UomId            AS UomId,
                @UnitWeight       AS UnitWeight,
                @WeightUomId      AS WeightUomId,
                @CountryOfOrigin  AS CountryOfOrigin
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @PartNumber IS NULL OR @ItemTypeId IS NULL OR @UomId IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- Business rule: UnitWeight + WeightUomId must be paired
        IF @UnitWeight IS NOT NULL AND @WeightUomId IS NULL
        BEGIN
            SET @Message = N'WeightUomId is required when UnitWeight is provided.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- Business rule: ItemTypeId must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.ItemType WHERE Id = @ItemTypeId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated ItemTypeId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- Business rule: UomId must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.Uom WHERE Id = @UomId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated UomId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- Business rule: WeightUomId (if provided) must exist and be active
        IF @WeightUomId IS NOT NULL AND NOT EXISTS
            (SELECT 1 FROM Parts.Uom WHERE Id = @WeightUomId AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Invalid or deprecated WeightUomId.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- Business rule: PartNumber unique (table has a UNIQUE constraint across
        -- all rows including deprecated — check both so the message is friendly)
        IF EXISTS (SELECT 1 FROM Parts.Item WHERE PartNumber = @PartNumber)
        BEGIN
            SET @Message = N'An Item with this PartNumber already exists.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        BEGIN TRANSACTION;

        INSERT INTO Parts.Item
            (ItemTypeId, PartNumber, Description, MacolaPartNumber,
             DefaultSubLotQty, MaxLotSize, UomId, UnitWeight, WeightUomId,
             CountryOfOrigin, CreatedAt, CreatedByUserId)
        VALUES
            (@ItemTypeId, @PartNumber, @Description, @MacolaPartNumber,
             @DefaultSubLotQty, @MaxLotSize, @UomId, @UnitWeight, @WeightUomId,
             @CountryOfOrigin, SYSUTCDATETIME(), @AppUserId);

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'Item',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'Item created.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Item created successfully.';
        SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);
        SET @NewId   = NULL;

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
