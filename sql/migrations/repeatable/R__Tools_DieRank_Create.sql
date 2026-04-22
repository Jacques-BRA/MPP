-- =============================================
-- Procedure:   Tools.DieRank_Create
-- Author:      Blue Ridge Automation
-- Created:     2026-04-22
-- Version:     1.0
--
-- Description:
--   Creates a new DieRank row. Enforces Code uniqueness. Auto-assigns
--   SortOrder as MAX(active siblings)+1 so new ranks append to the
--   end of the ordered list; Admin can reorder via MoveUp/MoveDown.
--
-- Parameters (input):
--   @Code NVARCHAR(20)          - Required. Unique among non-deprecated.
--   @Name NVARCHAR(100)         - Required.
--   @Description NVARCHAR(500)  - Optional.
--   @AppUserId BIGINT           - Required.
--
-- Result set:
--   Single row: Status, Message, NewId.
--
-- Dependencies:
--   Tables: Tools.DieRank
--   Procs:  Audit.Audit_LogConfigChange, Audit.Audit_LogFailure
-- =============================================
CREATE OR ALTER PROCEDURE Tools.DieRank_Create
    @Code        NVARCHAR(20),
    @Name        NVARCHAR(100),
    @Description NVARCHAR(500) = NULL,
    @AppUserId   BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status  BIT           = 0;
    DECLARE @Message NVARCHAR(500) = N'Unknown error';
    DECLARE @NewId   BIGINT        = NULL;

    DECLARE @ProcName NVARCHAR(200) = N'Tools.DieRank_Create';
    DECLARE @Params   NVARCHAR(MAX) =
        (SELECT @Code AS Code, @Name AS Name, @Description AS Description
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    BEGIN TRY
        IF @Code IS NULL OR @Name IS NULL OR @AppUserId IS NULL
        BEGIN
            SET @Message = N'Required parameter missing.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DieRank',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tools.DieRank WHERE Code = @Code)
        BEGIN
            SET @Message = N'A DieRank with this Code already exists.';
            EXEC Audit.Audit_LogFailure
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DieRank',
                @EntityId = NULL, @LogEventTypeCode = N'Created',
                @FailureReason = @Message, @ProcedureName = @ProcName,
                @AttemptedParameters = @Params;
            SELECT @Status AS Status, @Message AS Message, @NewId AS NewId;
            RETURN;
        END

        DECLARE @NextSort INT;
        SELECT @NextSort = ISNULL(MAX(SortOrder), 0) + 1
        FROM Tools.DieRank
        WHERE DeprecatedAt IS NULL;

        BEGIN TRANSACTION;

        INSERT INTO Tools.DieRank (Code, Name, Description, SortOrder, CreatedAt)
        VALUES (@Code, @Name, @Description, @NextSort, SYSUTCDATETIME());

        SET @NewId = CAST(SCOPE_IDENTITY() AS BIGINT);

        EXEC Audit.Audit_LogConfigChange
            @AppUserId         = @AppUserId,
            @LogEntityTypeCode = N'DieRank',
            @EntityId          = @NewId,
            @LogEventTypeCode  = N'Created',
            @LogSeverityCode   = N'Info',
            @Description       = N'DieRank created.',
            @OldValue          = NULL,
            @NewValue          = @Params;

        COMMIT TRANSACTION;

        SET @Status  = 1;
        SET @Message = N'DieRank created successfully.';
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
                @AppUserId = @AppUserId, @LogEntityTypeCode = N'DieRank',
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
