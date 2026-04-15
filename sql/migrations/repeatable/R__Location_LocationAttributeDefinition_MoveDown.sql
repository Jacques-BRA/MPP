-- =============================================
-- Procedure:   Location.LocationAttributeDefinition_MoveDown
-- Author:      Blue Ridge Automation
-- Created:     2026-04-13
-- Version:     2.0
--
-- Description:
--   Moves a LocationAttributeDefinition down in the sort order by swapping
--   SortOrder with the nearest active sibling below (higher SortOrder).
--   No-op (Status=1) if already at the bottom position.
--
-- Parameters (input):
--   @Id BIGINT        - PK of the row to move. Required.
--   @AppUserId BIGINT - User performing the action. Required for audit.
--
-- Result set:
--   Single row with Status (BIT), Message (NVARCHAR).
--   Status=1 on success, 0 on failure.
--
-- Dependencies:
--   Tables: Location.LocationAttributeDefinition
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
--
-- Error Handling:
--   - Validation/business-rule failures: @Status=0, @Message set, Audit_LogFailure, RETURN.
--   - CATCH handler: rollback, @Status=0, @Message captured, Audit_LogFailure, RAISERROR.
--
-- Change Log:
--   2026-04-13 - 1.0 - Initial version
--   2026-04-15 - 2.0 - SELECT result for Named Query compatibility
-- =============================================
CREATE OR ALTER PROCEDURE Location.LocationAttributeDefinition_MoveDown
    @Id        BIGINT,
    @AppUserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Result variables (returned via SELECT instead of OUTPUT)
    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';

    -- Capture input for failure-log snapshots
    DECLARE @ProcName NVARCHAR(200) = N'Location.LocationAttributeDefinition_MoveDown';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Id AS Id
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        -- ====================
        -- Parameter validation
        -- ====================
        IF @Id IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Get current row's SortOrder and parent definition
        DECLARE @CurrentSort INT, @ParentDefId BIGINT;
        SELECT @CurrentSort = SortOrder,
               @ParentDefId = LocationTypeDefinitionId
        FROM Location.LocationAttributeDefinition
        WHERE Id = @Id AND DeprecatedAt IS NULL;

        IF @CurrentSort IS NULL
        BEGIN
            SET @Message = N'LocationAttributeDefinition not found or is deprecated.';
            EXEC Audit.Audit_LogFailure
                @AppUserId           = @AppUserId,
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- Find nearest active sibling BELOW (higher SortOrder)
        DECLARE @SwapId BIGINT, @SwapSort INT;
        SELECT TOP 1 @SwapId = Id, @SwapSort = SortOrder
        FROM Location.LocationAttributeDefinition
        WHERE LocationTypeDefinitionId = @ParentDefId
          AND DeprecatedAt IS NULL
          AND SortOrder > @CurrentSort
        ORDER BY SortOrder ASC;

        -- Already last — no-op, success
        IF @SwapId IS NULL
        BEGIN
            SET @Status  = 1;
            SET @Message = N'Already at the bottom position.';
            SELECT @Status AS Status, @Message AS Message;
            RETURN;
        END

        -- ====================
        -- Mutation (atomic)
        -- ====================
        DECLARE @OldValue NVARCHAR(MAX) =
            (SELECT @Id AS Id, @CurrentSort AS OldSortOrder,
                    @SwapId AS SwapId, @SwapSort AS SwapOldSortOrder
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        DECLARE @NewValue NVARCHAR(MAX) =
            (SELECT @Id AS Id, @SwapSort AS NewSortOrder,
                    @SwapId AS SwapId, @CurrentSort AS SwapNewSortOrder
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRANSACTION;

        UPDATE Location.LocationAttributeDefinition SET SortOrder = @SwapSort WHERE Id = @Id;
        UPDATE Location.LocationAttributeDefinition SET SortOrder = @CurrentSort WHERE Id = @SwapId;

        -- Success audit INSIDE the transaction
        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'LocationAttrDef',
            @EntityId          = @Id,
            @LogEventTypeCode  = N'Updated',
            @LogSeverityCode   = N'Info',
            @Description       = N'LocationAttributeDefinition moved down.',
            @OldValue          = @OldValue,
            @NewValue          = @NewValue;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'LocationAttributeDefinition moved down successfully.';
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
                @LogEntityTypeCode   = N'LocationAttrDef',
                @EntityId            = @Id,
                @LogEventTypeCode    = N'Updated',
                @FailureReason       = @Message,
                @ProcedureName       = @ProcName,
                @AttemptedParameters = @Params;
        END TRY
        BEGIN CATCH
            -- Swallow; don't mask the original exception
        END CATCH

        SELECT @Status AS Status, @Message AS Message;
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END;
GO
