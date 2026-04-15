-- =============================================
-- Procedure:   Quality.QualitySpecAttribute_Update
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     2.0
--
-- Description:
--   Updates an existing attribute on a Draft version. Rejects if
--   the parent version is published or deprecated.
--
-- Parameters (input):
--   @Id BIGINT - Required.
--   @AttributeName NVARCHAR(100) - Required.
--   @DataType NVARCHAR(50) - Required.
--   @Uom NVARCHAR(20) NULL - Unit of measure.
--   @TargetValue DECIMAL(18,6) NULL - Expected/target value.
--   @LowerLimit DECIMAL(18,6) NULL - Lower specification limit.
--   @UpperLimit DECIMAL(18,6) NULL - Upper specification limit.
--   @IsRequired BIT - Required.
--   @AppUserId BIGINT - Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR).
--   Status=1 on success, 0 on failure.
--
-- Dependencies:
--   Tables: Quality.QualitySpecAttribute, Quality.QualitySpecVersion
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
--   2026-04-15 - 2.0 - SELECT result for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Quality.QualitySpecAttribute_Update
    @Id            BIGINT,
    @AttributeName NVARCHAR(100),
    @DataType      NVARCHAR(50),
    @Uom           NVARCHAR(20)  = NULL,
    @TargetValue   DECIMAL(18,6) = NULL,
    @LowerLimit    DECIMAL(18,6) = NULL,
    @UpperLimit    DECIMAL(18,6) = NULL,
    @IsRequired    BIT           = 1,
    @AppUserId     BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Quality.QualitySpecAttribute_Update';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id, @AttributeName AS AttributeName, @DataType AS DataType,
                @Uom AS Uom, @TargetValue AS TargetValue, @LowerLimit AS LowerLimit,
                @UpperLimit AS UpperLimit, @IsRequired AS IsRequired
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @Id IS NULL OR @AttributeName IS NULL OR LTRIM(RTRIM(@AttributeName)) = N''
           OR @DataType IS NULL OR LTRIM(RTRIM(@DataType)) = N'' OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'QualitySpecAttribute',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Get attribute and version
        -- ====================
        DECLARE @QualitySpecVersionId BIGINT;
        DECLARE @OldName              NVARCHAR(100);
        DECLARE @OldDataType          NVARCHAR(50);
        DECLARE @OldUom               NVARCHAR(20);
        DECLARE @OldTarget            DECIMAL(18,6);
        DECLARE @OldLower             DECIMAL(18,6);
        DECLARE @OldUpper             DECIMAL(18,6);
        DECLARE @OldIsRequired        BIT;
        DECLARE @RowExists            BIT = 0;

        SELECT @QualitySpecVersionId = QualitySpecVersionId,
               @OldName              = AttributeName,
               @OldDataType          = DataType,
               @OldUom               = Uom,
               @OldTarget            = TargetValue,
               @OldLower             = LowerLimit,
               @OldUpper             = UpperLimit,
               @OldIsRequired        = IsRequired,
               @RowExists            = 1
        FROM Quality.QualitySpecAttribute WHERE Id = @Id;

        IF @RowExists = 0
        BEGIN
            SET @Message = N'Attribute not found.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'QualitySpecAttribute',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Parent version checks
        -- ====================
        DECLARE @PublishedAt  DATETIME2(3);
        DECLARE @DeprecatedAt DATETIME2(3);

        SELECT @PublishedAt  = PublishedAt,
               @DeprecatedAt = DeprecatedAt
        FROM Quality.QualitySpecVersion WHERE Id = @QualitySpecVersionId;

        IF @PublishedAt IS NOT NULL
        BEGIN
            SET @Message = N'Cannot update attributes on a published version.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'QualitySpecAttribute',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        IF @DeprecatedAt IS NOT NULL
        BEGIN
            SET @Message = N'Cannot update attributes on a deprecated version.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'QualitySpecAttribute',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Business rule: unique name (if changing)
        -- ====================
        IF LTRIM(RTRIM(@AttributeName)) <> @OldName
           AND EXISTS (SELECT 1 FROM Quality.QualitySpecAttribute
                       WHERE QualitySpecVersionId = @QualitySpecVersionId
                         AND AttributeName = LTRIM(RTRIM(@AttributeName))
                         AND Id <> @Id)
        BEGIN
            SET @Message = N'Another attribute with this name already exists in this version.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'QualitySpecAttribute',
                @EntityId = @Id, @LogEventTypeCode = N'Updated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Build old/new JSON
        -- ====================
        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT @OldName AS AttributeName, @OldDataType AS DataType, @OldUom AS Uom,
                    @OldTarget AS TargetValue, @OldLower AS LowerLimit, @OldUpper AS UpperLimit,
                    @OldIsRequired AS IsRequired
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        -- ====================
        -- Mutation (atomic)
        -- ====================
        BEGIN TRANSACTION;

        UPDATE Quality.QualitySpecAttribute SET
            AttributeName = LTRIM(RTRIM(@AttributeName)),
            DataType      = LTRIM(RTRIM(@DataType)),
            Uom           = @Uom,
            TargetValue   = @TargetValue,
            LowerLimit    = @LowerLimit,
            UpperLimit    = @UpperLimit,
            IsRequired    = ISNULL(@IsRequired, 1)
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'QualitySpecAttribute',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'Quality spec attribute updated.',
            @OldValue          = @OldValue,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Attribute updated successfully.';
    SELECT @Status AS Status, @Message AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();

        SET @Status  = 0;
        SET @Message = N'Unexpected error: ' + LEFT(@ErrMsg, 400);

        BEGIN TRY
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'QualitySpecAttribute',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        SELECT @Status AS Status, @Message AS Message;

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END
GO
