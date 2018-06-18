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


INSERT kplus..CustomWindow VALUES ( @Codifiers_Id, @ETOD_Id, 'N', 'N', 'KustomRUKON_BondCouponParams', 
'NEXT_Client:0
Name:COUPON
Action:@KdbTables_Id_ETOD
TOD_origin:N
Label:RUKON_BondCouponParams
Scrollbars:0
Width:550
Height:55
ViewableWidth:800
ViewableHeight:291
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
Size:1
Pricing:0
Hidden:0
ShareData:0
START_Inquiry:0
START_Input:0
START_Square:0
START_Help:1
X:17
Y:25
Procedure4:Method
Name:Kustom..RUKON_CusAccrMethods
Label:Coupon Accrued Method
SendMsg:0
Selector:0
Procedure2:AccMethods
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
RiskSource:1
IndexType:I
START_List:0
START_Foreign:1
Name:Method
START_Notify:0
START_Proc:1
Name:RUKON_GetAccrMethod
Label:AccMethods
Action:H
', DEFAULT)


go

/*-------------------------------------------------*/
/*--- Tables export -------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		RUKON_BondCouponParams
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RUKON_BondCouponParams' AND type = 'U' 
)
	DROP table RUKON_BondCouponParams 
go


CREATE table RUKON_BondCouponParams
(
DealType                        varchar(32)     null,
DealId                          int             null,
Method                          char(1)         null 
)
LOCK DATAROWS



/*--- INDEXES -------------------------------------*/

CREATE  INDEX RUKON_BondCouponParamsIdx1 ON RUKON_BondCouponParams 
(
	DealType,
	DealId 
)


go

GRANT ALL ON RUKON_BondCouponParams TO PUBLIC 
go



USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRUKON_BondCoup_V00' AND type = 'U'
)
	DROP table KustomRUKON_BondCoup_V00 
go


CREATE table KustomRUKON_BondCoup_V00
(
TransactionId                   int             not null,
DealType                        varchar(32)     null,
DealId                          int             null,
Method                          char(1)         null,
VersionStartDate                datetime        not null,
VersionEndDate                  datetime        not null,
)
LOCK DATAROWS



/*--- INDEXES -------------------------------------*/

CREATE UNIQUE INDEX KustomRUKON_BondCoup_V00Idx1 ON KustomRUKON_BondCoup_V00 
(
	TransactionId,
	DealType,
	DealId
)

CREATE INDEX KustomRUKON_BondCoup_V00Idx2 ON KustomRUKON_BondCoup_V00 
(
	VersionStartDate
)

CREATE INDEX KustomRUKON_BondCoup_V00Idx3 ON KustomRUKON_BondCoup_V00 
(
	VersionEndDate
)


GRANT ALL ON KustomRUKON_BondCoup_V00 TO PUBLIC 
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
  EXECUTE('CREATE TABLE KustomVersionTablesT 
  (
   TableName          varchar(64) not null,
   VersionTableName   varchar(64) not null
  )

  CREATE UNIQUE INDEX KustomVersionTablesTIdx1 ON KustomVersionTablesT ( TableName )
  CREATE UNIQUE INDEX KustomVersionTablesTIdx2 ON KustomVersionTablesT ( VersionTableName )
  GRANT ALL ON KustomVersionTablesT TO PUBLIC
')
END
go

DELETE FROM  KustomVersionTablesT WHERE TableName = 'Kustom..RUKON_BondCouponParams'
go

INSERT INTO  KustomVersionTablesT
 (TableName, VersionTableName) VALUES ('Kustom..RUKON_BondCouponParams', 'KustomRUKON_BondCoup_V00')

go



USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRUKON_BondCoup_M00' AND type = 'U'
)
	DROP table KustomRUKON_BondCoup_M00 
go


CREATE table KustomRUKON_BondCoup_M00
(
TransactionId                   int             not null,
Action                          char(1)         not null,
MvtId                           numeric(20)     not null,
DealType                        varchar(32)     null,
DealId                          int             null,
Method_                         char(1)         null,
)
LOCK DATAROWS


GRANT ALL ON KustomRUKON_BondCoup_M00 TO PUBLIC 
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
  EXECUTE('CREATE TABLE KustomMovementTablesT 
  (
   TableName          varchar(64) not null,
   VersionTableName   varchar(64) not null
  )

  CREATE UNIQUE INDEX KustomMovementTablesTIdx1 ON KustomMovementTablesT ( TableName )
  CREATE UNIQUE INDEX KustomMovementTablesTIdx2 ON KustomMovementTablesT ( VersionTableName )
  GRANT ALL ON KustomMovementTablesT TO PUBLIC
')
END
go

DELETE FROM KustomMovementTablesT WHERE TableName = 'Kustom..RUKON_BondCouponParams'
go

INSERT INTO KustomMovementTablesT
 (TableName, VersionTableName) VALUES ('Kustom..RUKON_BondCouponParams', 'KustomRUKON_BondCoup_M00')

go

/*------------------------------------------------- 
		KustomRUKON_BondCouponParamsMvts_insert
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRUKON_BondCouponParamsMvts_insert' AND type = 'P' 
)
	DROP PROC KustomRUKON_BondCouponParamsMvts_insert 
go


CREATE PROCEDURE KustomRUKON_BondCouponParamsMvts_insert (@TableId int, @RowId int, @DealType varchar(32), @Action char(1) ) as
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
INSERT Kustom.dbo.KustomRUKON_BondCoup_M00 SELECT @TransId, @Action, @MvtId, F.DealType, F.DealId, F.Method
FROM Kustom.dbo.RUKON_BondCouponParams F
WHERE F.DealId = @RowId AND F.DealType = @DealType 
END 
RETURN 0
END 
go



GRANT EXEC ON KustomRUKON_BondCouponParamsMvts_insert TO PUBLIC 
go

/*-------------------------------------------------*/
/*--- Procs export --------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		RUKON_GetAccrMethod
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RUKON_GetAccrMethod' AND type = 'P' 
)
	DROP PROC RUKON_GetAccrMethod 
go


create procedure dbo.RUKON_GetAccrMethod
as
select Method as 'Method', Method_ShortName as 'Method_ShortName' from RUKON_CusAccrMethods order by 1

go



GRANT EXEC ON RUKON_GetAccrMethod TO PUBLIC 
go

