-- Tests for Location.AppUser_SetPin
EXEC test.BeginTestFile @FileName = N'03_appuser/070_AppUser_SetPin.sql';
GO

-- Test 1: Happy path
DECLARE @UserId BIGINT;
CREATE TABLE #R1 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #R1 EXEC Location.AppUser_Create @AdAccount = N'setpin070.happy@test.com', @DisplayName = N'SetPin Happy', @AppUserId = 1;
SELECT @UserId = NewId FROM #R1;
DROP TABLE #R1;

DECLARE @S BIT, @M NVARCHAR(500);
CREATE TABLE #R1b (Status BIT, Message NVARCHAR(500));
INSERT INTO #R1b EXEC Location.AppUser_SetPin @Id = @UserId, @PinHash = N'$2b$10$setpin070hash', @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #R1b;
DROP TABLE #R1b;

DECLARE @SStr NVARCHAR(1) = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual @TestName = N'[HappyPath] Status is 1', @Expected = N'1', @Actual = @SStr;

DECLARE @StoredPin NVARCHAR(255);
SELECT @StoredPin = PinHash FROM Location.AppUser WHERE Id = @UserId;
EXEC test.Assert_IsEqual @TestName = N'[HappyPath] PinHash stored correctly', @Expected = N'$2b$10$setpin070hash', @Actual = @StoredPin;

DECLARE @LogCount INT;
SELECT @LogCount = COUNT(*) FROM Audit.ConfigLog cl INNER JOIN Audit.LogEntityType let ON let.Id = cl.LogEntityTypeId
WHERE let.Code = N'AppUser' AND cl.EntityId = @UserId AND cl.Description = N'AppUser PIN updated.';
EXEC test.Assert_RowCount @TestName = N'[HappyPath] ConfigLog row written for SetPin', @ExpectedCount = 1, @ActualCount = @LogCount;

DECLARE @OldVal NVARCHAR(MAX), @NewVal NVARCHAR(MAX);
SELECT TOP 1 @OldVal = cl.OldValue, @NewVal = cl.NewValue FROM Audit.ConfigLog cl INNER JOIN Audit.LogEntityType let ON let.Id = cl.LogEntityTypeId
WHERE let.Code = N'AppUser' AND cl.EntityId = @UserId AND cl.Description = N'AppUser PIN updated.' ORDER BY cl.LoggedAt DESC;
EXEC test.Assert_IsEqual @TestName = N'[HappyPath] ConfigLog OldValue is [REDACTED]', @Expected = N'[REDACTED]', @Actual = @OldVal;
EXEC test.Assert_IsEqual @TestName = N'[HappyPath] ConfigLog NewValue is [REDACTED]', @Expected = N'[REDACTED]', @Actual = @NewVal;
GO

-- Test 2: NULL PinHash rejected
DECLARE @UserId BIGINT;
CREATE TABLE #R2 (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #R2 EXEC Location.AppUser_Create @AdAccount = N'setpin070.nullpin@test.com', @DisplayName = N'SetPin Null', @PinHash = N'$2b$10$original', @AppUserId = 1;
SELECT @UserId = NewId FROM #R2;
DROP TABLE #R2;

DECLARE @S BIT, @M NVARCHAR(500);
CREATE TABLE #R2b (Status BIT, Message NVARCHAR(500));
INSERT INTO #R2b EXEC Location.AppUser_SetPin @Id = @UserId, @PinHash = NULL, @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #R2b;
DROP TABLE #R2b;
DECLARE @SStr NVARCHAR(1) = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual @TestName = N'[NullPinHash] Status is 0', @Expected = N'0', @Actual = @SStr;

DECLARE @StoredPin NVARCHAR(255);
SELECT @StoredPin = PinHash FROM Location.AppUser WHERE Id = @UserId;
EXEC test.Assert_IsEqual @TestName = N'[NullPinHash] PinHash unchanged', @Expected = N'$2b$10$original', @Actual = @StoredPin;
GO

-- Test 3: Deprecated user rejected
DECLARE @UserId BIGINT, @HelperId BIGINT;
CREATE TABLE #R3a (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #R3a EXEC Location.AppUser_Create @AdAccount = N'setpin070.dep@test.com', @DisplayName = N'SetPin Dep', @PinHash = N'$2b$10$beforedep', @AppUserId = 1;
SELECT @UserId = NewId FROM #R3a;
DROP TABLE #R3a;

CREATE TABLE #R3b (Status BIT, Message NVARCHAR(500), NewId BIGINT);
INSERT INTO #R3b EXEC Location.AppUser_Create @AdAccount = N'setpin070.helper@test.com', @DisplayName = N'Helper', @AppUserId = 1;
SELECT @HelperId = NewId FROM #R3b;
DROP TABLE #R3b;

DECLARE @S BIT, @M NVARCHAR(500);
CREATE TABLE #R3c (Status BIT, Message NVARCHAR(500));
INSERT INTO #R3c EXEC Location.AppUser_Deprecate @Id = @UserId, @AppUserId = @HelperId;
DROP TABLE #R3c;

CREATE TABLE #R3d (Status BIT, Message NVARCHAR(500));
INSERT INTO #R3d EXEC Location.AppUser_SetPin @Id = @UserId, @PinHash = N'$2b$10$shouldfail', @AppUserId = 1;
SELECT @S = Status, @M = Message FROM #R3d;
DROP TABLE #R3d;
DECLARE @SStr NVARCHAR(1) = CAST(@S AS NVARCHAR(1));
EXEC test.Assert_IsEqual @TestName = N'[DeprecatedUser] SetPin rejected: Status is 0', @Expected = N'0', @Actual = @SStr;

DECLARE @StoredPin NVARCHAR(255);
SELECT @StoredPin = PinHash FROM Location.AppUser WHERE Id = @UserId;
EXEC test.Assert_IsEqual @TestName = N'[DeprecatedUser] PinHash not altered', @Expected = N'$2b$10$beforedep', @Actual = @StoredPin;
GO

EXEC test.PrintSummary;
GO
