-- =============================================
-- Procedure:   Parts.Item_Deprecate
-- Author:      Blue Ridge Automation
-- Created:     2026-04-14
-- Version:     1.0
--
-- Description:
--   Soft-deletes an active Item by setting DeprecatedAt. Rejects if
--   the Item is referenced by any active dependent:
--     - Parts.Bom              (either as ParentItem or BomLine child)
--     - Parts.RouteTemplate    (ItemId)
--     - Parts.ItemLocation     (ItemId)
--     - Parts.ContainerConfig  (ItemId)
--
--   Each dependent check is guarded by sys.tables so the proc compiles
--   cleanly in earlier phases where those tables may not yet exist.
--
-- Parameters (input):
--   @Id BIGINT        - Required.
--   @AppUserId BIGINT - Required for audit.
--
-- Parameters (output):
--   @Status BIT            - 1 on success, 0 on failure.
--   @Message NVARCHAR(500) - Human-readable status message.
--
-- Dependencies:
--   Tables: Parts.Item; optionally Parts.Bom, Parts.BomLine,
--           Parts.RouteTemplate, Parts.ItemLocation, Parts.ContainerConfig
--           (existence-guarded)
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Change Log:
--   2026-04-14 - 1.0 - Initial version
-- =============================================
CREATE OR ALTER PROCEDURE Parts.Item_Deprecate
    @Id        BIGINT,
    @AppUserId BIGINT,
    @Status    BIT            OUTPUT,
    @Message   NVARCHAR(500)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Status  = 0;
    SET @Message = N'Unknown error';

    DECLARE @ProcName NVARCHAR(200) = N'Parts.Item_Deprecate';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- Parameter validation
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Business rule: must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Parts.Item WHERE Id = @Id AND DeprecatedAt IS NULL)
        BEGIN
            SET @Message = N'Item not found or already deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            RETURN;
        END

        -- Dependency checks (each guarded — tables may not exist yet)
        DECLARE @DepCount INT = 0;

        -- Parts.Bom — parent role
        IF EXISTS (SELECT 1 FROM sys.tables t INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
                   WHERE s.name = N'Parts' AND t.name = N'Bom')
        BEGIN
            EXEC sp_executesql
                N'SELECT @cnt = COUNT(*) FROM Parts.Bom WHERE ParentItemId = @id AND DeprecatedAt IS NULL;',
                N'@id BIGINT, @cnt INT OUTPUT',
                @id = @Id, @cnt = @DepCount OUTPUT;
            IF @DepCount > 0
            BEGIN
                SET @Message = N'Cannot deprecate: active BOMs reference this Item as parent.';
                EXEC Audit.Audit_LogFailure
                    @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                    @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                    @FailureReason = @Message, @ProcedureName = @ProcName,
                    @AttemptedParameters = @Params;
                RETURN;
            END
        END

        -- Parts.BomLine — child role
        IF EXISTS (SELECT 1 FROM sys.tables t INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
                   WHERE s.name = N'Parts' AND t.name = N'BomLine')
        BEGIN
            EXEC sp_executesql
                N'SELECT @cnt = COUNT(*) FROM Parts.BomLine WHERE ChildItemId = @id;',
                N'@id BIGINT, @cnt INT OUTPUT',
                @id = @Id, @cnt = @DepCount OUTPUT;
            IF @DepCount > 0
            BEGIN
                SET @Message = N'Cannot deprecate: BOM lines reference this Item as a child component.';
                EXEC Audit.Audit_LogFailure
                    @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                    @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                    @FailureReason = @Message, @ProcedureName = @ProcName,
                    @AttemptedParameters = @Params;
                RETURN;
            END
        END

        -- Parts.RouteTemplate
        IF EXISTS (SELECT 1 FROM sys.tables t INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
                   WHERE s.name = N'Parts' AND t.name = N'RouteTemplate')
        BEGIN
            EXEC sp_executesql
                N'SELECT @cnt = COUNT(*) FROM Parts.RouteTemplate WHERE ItemId = @id AND DeprecatedAt IS NULL;',
                N'@id BIGINT, @cnt INT OUTPUT',
                @id = @Id, @cnt = @DepCount OUTPUT;
            IF @DepCount > 0
            BEGIN
                SET @Message = N'Cannot deprecate: active RouteTemplates reference this Item.';
                EXEC Audit.Audit_LogFailure
                    @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                    @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                    @FailureReason = @Message, @ProcedureName = @ProcName,
                    @AttemptedParameters = @Params;
                RETURN;
            END
        END

        -- Parts.ItemLocation
        IF EXISTS (SELECT 1 FROM sys.tables t INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
                   WHERE s.name = N'Parts' AND t.name = N'ItemLocation')
        BEGIN
            EXEC sp_executesql
                N'SELECT @cnt = COUNT(*) FROM Parts.ItemLocation WHERE ItemId = @id AND DeprecatedAt IS NULL;',
                N'@id BIGINT, @cnt INT OUTPUT',
                @id = @Id, @cnt = @DepCount OUTPUT;
            IF @DepCount > 0
            BEGIN
                SET @Message = N'Cannot deprecate: active ItemLocation eligibility entries reference this Item.';
                EXEC Audit.Audit_LogFailure
                    @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                    @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                    @FailureReason = @Message, @ProcedureName = @ProcName,
                    @AttemptedParameters = @Params;
                RETURN;
            END
        END

        -- Parts.ContainerConfig
        IF EXISTS (SELECT 1 FROM sys.tables t INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
                   WHERE s.name = N'Parts' AND t.name = N'ContainerConfig')
        BEGIN
            EXEC sp_executesql
                N'SELECT @cnt = COUNT(*) FROM Parts.ContainerConfig WHERE ItemId = @id AND DeprecatedAt IS NULL;',
                N'@id BIGINT, @cnt INT OUTPUT',
                @id = @Id, @cnt = @DepCount OUTPUT;
            IF @DepCount > 0
            BEGIN
                SET @Message = N'Cannot deprecate: an active ContainerConfig references this Item.';
                EXEC Audit.Audit_LogFailure
                    @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                    @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                    @FailureReason = @Message, @ProcedureName = @ProcName,
                    @AttemptedParameters = @Params;
                RETURN;
            END
        END

        BEGIN TRANSACTION;

        UPDATE Parts.Item
        SET DeprecatedAt    = SYSUTCDATETIME(),
            UpdatedAt       = SYSUTCDATETIME(),
            UpdatedByUserId = @AppUserId
        WHERE Id = @Id;

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'Item',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Deprecated',
            @LogSeverityCode   = N'Info',
            @Description       = N'Item deprecated.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'Item deprecated successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'Item',
                @EntityId = @Id, @LogEventTypeCode = N'Deprecated',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
        END CATCH

        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
