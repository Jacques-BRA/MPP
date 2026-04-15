-- =============================================
-- Procedure:   Quality.QualitySpecAttribute_Add
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Adds a new attribute to a QualitySpecVersion. The parent
--   version must be in Draft state (PublishedAt IS NULL).
--   SortOrder is auto-assigned as MAX(siblings) + 1.
--
-- Parameters (input):
--   @QualitySpecVersionId BIGINT - Required. Must be Draft.
--   @AttributeName NVARCHAR(100) - Required. Unique within version.
--   @DataType NVARCHAR(50) - Required (Numeric, Text, Boolean, etc.).
--   @Uom NVARCHAR(20) NULL - Unit of measure.
--   @TargetValue DECIMAL(18,6) NULL - Expected/target value.
--   @LowerLimit DECIMAL(18,6) NULL - Lower specification limit.
--   @UpperLimit DECIMAL(18,6) NULL - Upper specification limit.
--   @IsRequired BIT - Required. Defaults to 1.
--   @AppUserId BIGINT - Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR), NewId (BIGINT).
--   Status=1 on success, 0 on failure. NewId is NULL on failure.
--
-- Dependencies:
--   Tables: Quality.QualitySpecVersion, Quality.QualitySpecAttribute
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
--   2026-04-15 - 2.0 - SELECT result for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Quality.QualitySpecAttribute_Add
    @QualitySpecVersionId BIGINT,
    @AttributeName        NVARCHAR(100),
    @DataType             NVARCHAR(50),
    @Uom                  NVARCHAR(20)    = NULL,
    @TargetValue          DECIMAL(18,6)   = NULL,
    @LowerLimit           DECIMAL(18,6)   = NULL,
    @UpperLimit           DECIMAL(18,6)   = NULL,
    @IsRequired           BIT             = 1,
    @AppUserId            BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';
    DECLARE @NewId   BIGINT        = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Quality.QualitySpecAttribute_Add';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @QualitySpecVersionId AS QualitySpecVersionId, @AttributeName AS AttributeName,
                @DataType AS DataType, @Uom AS Uom, @TargetValue AS TargetValue,
                @LowerLimit AS LowerLimit, @UpperLimit AS UpperLimit, @IsRequired AS IsRequired
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @QualitySpecVersionId IS NULL OR @AttributeName IS NULL OR LTRIM(RTRIM(@AttributeName)) = N''
           OR @DataType IS NULL OR LTRIM(RTRIM(@DataType)) = N'' OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'QualitySpecAttribute',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- ====================
        -- Parent version checks
        -- ====================
        DECLARE @PublishedAt  DATETIME2(3);
        DECLARE @DeprecatedAt DATETIME2(3);
        DECLARE @VersionExists BIT = 0;

        SELECT @PublishedAt  = PublishedAt,
               @DeprecatedAt = DeprecatedAt,
               @VersionExists = 1
        FROM Quality.QualitySpecVersion WHERE Id = @QualitySpecVersionId;

        IF @VersionExists = 0
        BEGIN
            SET @Message = N'Parent version not found.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'QualitySpecAttribute',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        IF @PublishedAt IS NOT NULL
        BEGIN
            SET @Message = N'Cannot add attributes to a published version.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'QualitySpecAttribute',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        IF @DeprecatedAt IS NOT NULL
        BEGIN
            SET @Message = N'Cannot add attributes to a deprecated version.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'QualitySpecAttribute',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- ====================
        -- Business rule: unique name
        -- ====================
        IF EXISTS (SELECT 1 FROM Quality.QualitySpecAttribute
                   WHERE QualitySpecVersionId = @QualitySpecVersionId
                     AND AttributeName = LTRIM(RTRIM(@AttributeName)))
        BEGIN
            SET @Message = N'An attribute with this name already exists in this version.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'QualitySpecAttribute',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        -- ====================
        -- Calculate SortOrder
        -- ====================
        DECLARE @NewSortOrder INT = (
            SELECT ISNULL(MAX(SortOrder), 0) + 1
            FROM Quality.QualitySpecAttribute
            WHERE QualitySpecVersionId = @QualitySpecVersionId
        );

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        INSERT INTO Quality.QualitySpecAttribute
            (QualitySpecVersionId, AttributeName, DataType, Uom, TargetValue, LowerLimit, UpperLimit, IsRequired, SortOrder)
        VALUES
            (@QualitySpecVersionId, LTRIM(RTRIM(@AttributeName)), LTRIM(RTRIM(@DataType)),
             @Uom, @TargetValue, @LowerLimit, @UpperLimit, ISNULL(@IsRequired, 1), @NewSortOrder);

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'QualitySpecAttribute',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'Quality spec attribute added.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Attribute added successfully.';
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
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'QualitySpecAttribute',
                @EntityId            = NULL,
                @LogEventTypeCode    = N'Created',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END
GO
