/*-------------------------------------------------*/
/*--- Initialization Part -------------------------*/
/*-------------------------------------------------*/

USE kplus
go

/*-------------------------------------------------*/
/*--- Boxes export --------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		COUPON.Bonds
---------------------------------------------------*/

DECLARE @Codifiers_Id     int, 
  @ModuleId_ETOD         int, 
	@ETOD_Id  int, 
	@KdbTables_Id_ETOD     int 

IF NOT EXISTS 
(
	SELECT Codifiers_Id 
	FROM kplus..Codifiers
	WHERE  Codifiers_ShortName = 'COUPON' 
)
BEGIN 

	/* Search Next Id */ 
	BEGIN  TRAN 
		UPDATE KplusGlobal..GlobalDataId SET GlobalDataId = GlobalDataId + 1
		SELECT @Codifiers_Id = GlobalDataId FROM KplusGlobal..GlobalDataId 
	COMMIT TRAN 

	/* Insert new Codifiers in this DataBase */ 
	INSERT kplus..Codifiers VALUES ( 
		@Codifiers_Id,
		'COUPON',
		'BOND COUPONS CALCULATION PARAMS'
	)

END 


SELECT @Codifiers_Id = Codifiers_Id 
FROM kplus..Codifiers 
WHERE  Codifiers_ShortName = 'COUPON' 


SELECT @KdbTables_Id_ETOD = 23 
SELECT @ETOD_Id = @KdbTables_Id_ETOD 
IF EXISTS 
(
	SELECT Codifiers_Id 
	FROM  kplus..KLSParams  
	WHERE  Codifiers_Id = @Codifiers_Id 
	AND    KdbTables_Id = @ETOD_Id 
	AND    TypeOfDealsOrigin = 'N' 
)
	DELETE kplus..KLSParams 
	WHERE  Codifiers_Id = @Codifiers_Id 
	AND    KdbTables_Id = @ETOD_Id 
	AND    TypeOfDealsOrigin = 'N'


/* Insert new KLSParams in this DataBase */ 
INSERT kplus..KLSParams VALUES ( 
	@Codifiers_Id,
	@ETOD_Id,
	'N',
	0,
	0.000000,
	0,
	0.000000,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0.000000,
	0,
	0,
	0,
	0,
	0,
	' ',
	0,
	0,
	0,
	0 
)


IF EXISTS 
(
	SELECT Codifiers_Id 
	FROM kplus..CustomWindow 
	WHERE  Codifiers_Id = @Codifiers_Id AND KdbTables_Id = @ETOD_Id AND TypeOfDealsOrigin = 'N' 
)
	DELETE kplus..CustomWindow 
	WHERE  Codifiers_Id = @Codifiers_Id AND KdbTables_Id = @ETOD_Id AND TypeOfDealsOrigin = 'N'


INSERT kplus..CustomWindow VALUES ( @Codifiers_Id, @ETOD_Id, 'N', 'N', 'KustomRTR_CW_BondsCouponParam', 
'NEXT_Client:0
Name:COUPON
Action:@KdbTables_Id_ETOD
TOD_origin:N
Label:RTR_CW_BondsCouponParam
Scrollbars:0
Width:600
Height:55
ViewableWidth:610
ViewableHeight:133
Store:1
SendMsg:1
Seconds:0
Prolong:0
ReadOnly:1
Mandatory:0
Color1:0
Color2:1
Color3:0
Display:0
NewHelpNaming:0
Size:0
ShareData:0
START_Inquiry:0
START_Input:0
START_Square:0
START_Help:1
X:35
Y:25
Procedure4:Method
Name:Kustom..AccruedMethods
Label:Coupon Accrued Method
SendMsg:0
Selector:0
Length:2
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
CaretNumber:1
PersList:0
Procedure5:Method
Default:Method
Action:C
Width:1
Display:1
Store:1
Sent:0
Foreign:1
UpperCase:1
Procedure5:Method_ShortName
Default:Method_ShortName
Action:T
Width:40
Display:1
Store:0
Sent:0
Foreign:0
UpperCase:0
Panel:0
Size:8
Square:0
START_List:0
START_Foreign:1
Name:Method
START_Notify:0
START_Proc:1
Name:GetAccruedMethods
Label:AccMethods
Action:H
')


go

/*-------------------------------------------------*/
/*--- Tables export -------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		RTR_CW_BondsCouponParam
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RTR_CW_BondsCouponParam' AND type = 'U' 
)
	DROP table RTR_CW_BondsCouponParam 
go


CREATE table RTR_CW_BondsCouponParam
(
DealType                        varchar(32)     not null,
DealId                          int             not null,
Method                          char(1)         null 
)
LOCK DATAROWS



/*--- INDEXES -------------------------------------*/

CREATE  INDEX ix_DealId ON RTR_CW_BondsCouponParam 
(
	DealId,
	DealType 
)


go

GRANT ALL ON RTR_CW_BondsCouponParam TO PUBLIC 
go



USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRTR_CW_BondsCo_V00' AND type = 'U'
)
	DROP table KustomRTR_CW_BondsCo_V00 
go


CREATE table KustomRTR_CW_BondsCo_V00
(
TransactionId                   int             not null,
DealType                        varchar(32)     not null,
DealId                          int             not null,
Method                          char(1)         null,
VersionStartDate                datetime        not null,
VersionEndDate                  datetime        not null,
)



/*--- INDEXES -------------------------------------*/

CREATE UNIQUE INDEX KustomRTR_CW_BondsCo_V00Idx1 ON KustomRTR_CW_BondsCo_V00 
(
	TransactionId,
	DealType,
	DealId
)

CREATE INDEX KustomRTR_CW_BondsCo_V00Idx2 ON KustomRTR_CW_BondsCo_V00 
(
	VersionStartDate
)

CREATE INDEX KustomRTR_CW_BondsCo_V00Idx3 ON KustomRTR_CW_BondsCo_V00 
(
	VersionEndDate
)

CREATE  INDEX ix_DealId ON Kustom..RTR_CW_BondsCouponParamVer 
(
	DealId,
	DealType 
)


GRANT ALL ON KustomRTR_CW_BondsCo_V00 TO PUBLIC 
go



USE Kustom
go

IF NOT EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomVersionTablesT' AND type = 'U'
)
BEGIN
  EXECUTE("CREATE TABLE KustomVersionTablesT 
  (
   TableName          varchar(64) not null,
   VersionTableName   varchar(64) not null
  ) ")

  CREATE UNIQUE INDEX KustomVersionTablesTIdx1 ON KustomVersionTablesT ( TableName ) 
  CREATE UNIQUE INDEX KustomVersionTablesTIdx2 ON KustomVersionTablesT ( VersionTableName ) 

 GRANT ALL ON KustomVersionTablesT TO PUBLIC 
END
go

DELETE FROM  KustomVersionTablesT WHERE TableName = "Kustom..RTR_CW_BondsCouponParam"
go

INSERT INTO  KustomVersionTablesT
 (TableName, VersionTableName) VALUES ("Kustom..RTR_CW_BondsCouponParam", "KustomRTR_CW_BondsCo_V00")

go



USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRTR_CW_BondsCo_M00' AND type = 'U'
)
	DROP table KustomRTR_CW_BondsCo_M00 
go


CREATE table KustomRTR_CW_BondsCo_M00
(
TransactionId                   int             not null,
Action                          char(1)         not null,
MvtId                           numeric(20)     not null,
DealType                        varchar(32)     not null,
DealId                          int             not null,
Method_                         char(1)         null,
)
LOCK DATAROWS


GRANT ALL ON KustomRTR_CW_BondsCo_M00 TO PUBLIC 
go



USE Kustom
go

IF NOT EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomMovementTablesT' AND type = 'U'
)
BEGIN
  EXECUTE("CREATE TABLE KustomMovementTablesT 
  (
   TableName          varchar(64) not null,
   VersionTableName   varchar(64) not null
  ) ")

  CREATE UNIQUE INDEX KustomMovementTablesTIdx1 ON KustomMovementTablesT ( TableName ) 
  CREATE UNIQUE INDEX KustomMovementTablesTIdx2 ON KustomMovementTablesT ( VersionTableName ) 

 GRANT ALL ON KustomMovementTablesT TO PUBLIC 
END
go

DELETE FROM KustomMovementTablesT WHERE TableName = "Kustom..RTR_CW_BondsCouponParam"
go

INSERT INTO KustomMovementTablesT
 (TableName, VersionTableName) VALUES ("Kustom..RTR_CW_BondsCouponParam", "KustomRTR_CW_BondsCo_M00")

go

/*------------------------------------------------- 
		KustomRTR_CW_BondsCouponParamMvts_insert
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRTR_CW_BondsCouponParamMvts_insert' AND type = 'P' 
)
	DROP PROC KustomRTR_CW_BondsCouponParamMvts_insert 
go


CREATE PROCEDURE KustomRTR_CW_BondsCouponParamMvts_insert (@TableId int, @RowId int, @DealType varchar(32), @Action char(1) ) as
BEGIN
DECLARE @MvtId numeric(20), @TransId int, @ret_value int
SELECT @MvtId = 0, @TransId = 0, @ret_value = 0
EXECUTE kplus.dbo.KLSDealsInfo_BatchFlag_test @TableId, @RowId, @Action, @ret_value output
IF (@ret_value > 0) 
BEGIN
IF EXISTS (SELECT 1 from kplus.dbo.DBVariables where KeyId=51) /* OPTION DBVAR_UNSERIAL_DEALS_ID */ 
BEGIN
EXECUTE kplus.dbo.KLSDealsInfo_getMvtId @TableId, @RowId, @Action, @MvtId output 
IF @MvtId = -1 
RETURN -1
END 
ELSE 
BEGIN
EXECUTE kplus.dbo.KLSDealsInfo_getTransId @TableId, @RowId, @Action, @TransId output 
IF (@TransId = 0 OR @TransId = NULL) 
RETURN -1
END 
INSERT Kustom.dbo.KustomRTR_CW_BondsCo_M00 SELECT @TransId, @Action, @MvtId, F.DealType, F.DealId, F.Method
FROM Kustom.dbo.RTR_CW_BondsCouponParam F
WHERE F.DealId = @RowId AND F.DealType = @DealType 
END 
RETURN 0
END 
go



GRANT EXEC ON KustomRTR_CW_BondsCouponParamMvts_insert TO PUBLIC 
go

/*-------------------------------------------------*/
/*--- Procs export --------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		GetAccruedMethods
---------------------------------------------------*/

USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'AccruedMethods' AND type = 'U' 
)
	DROP table AccruedMethods 
go


CREATE table AccruedMethods
(
Method                          char(1)         null,
Method_ShortName				varchar(32)
)
LOCK DATAROWS

USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'GetAccruedMethods' AND type = 'P' 
)
	DROP PROC GetAccruedMethods 
go



create procedure dbo.GetAccruedMethods
as
select Method as 'Method', Method_ShortName as 'Method_ShortName' from AccruedMethods order by 1

go



GRANT EXEC ON GetAccruedMethods TO PUBLIC 
go

