/*-------------------------------------------------*/
/*--- Initialization Part -------------------------*/
/*-------------------------------------------------*/

USE kplus
go

/*-------------------------------------------------*/
/*--- Boxes export --------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		REPODEALEX.RepoDeals
---------------------------------------------------*/

DECLARE @Codifiers_Id     int, 
  @ModuleId_ETOD         int, 
	@ETOD_Id  int, 
	@KdbTables_Id_ETOD     int 

IF NOT EXISTS 
(
	SELECT Codifiers_Id 
	FROM kplus..Codifiers
	WHERE  Codifiers_ShortName = 'REPODEALEX' 
)
BEGIN 

	/* Search Next Id */ 
	BEGIN  TRAN 
		UPDATE kplus..GlobalDataId SET GlobalDataId = GlobalDataId + 1
		SELECT @Codifiers_Id = GlobalDataId FROM kplus..GlobalDataId 
	COMMIT TRAN 

	/* Insert new Codifiers in this DataBase */ 
	INSERT kplus..Codifiers VALUES ( 
		@Codifiers_Id,
		'REPODEALEX',
		'EXTENDED INFO FOR REPO DEALS'
	)

END 


SELECT @Codifiers_Id = Codifiers_Id 
FROM kplus..Codifiers 
WHERE  Codifiers_ShortName = 'REPODEALEX' 


SELECT @KdbTables_Id_ETOD = 395 
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


INSERT kplus..CustomWindow VALUES ( @Codifiers_Id, @ETOD_Id, 'N', 'N', 'KustomRepoDealsEx', 
'NEXT_Client:0
Name:REPODEALEX
Action:@KdbTables_Id_ETOD
TOD_origin:N
Label:Kustom..RepoDealsEx
Scrollbars:0
Width:725
Height:320
ViewableWidth:740
ViewableHeight:398
Store:1
SendMsg:0
Seconds:0
Prolong:1
ReadOnly:1
Mandatory:1
Color1:0
Color2:1
Color3:0
Display:0
NewHelpNaming:0
Size:1
ShareData:0
Procedure:coherence
START_Inquiry:0
START_Input:32
X:10
Y:10
Action:C
Width:1
Name:RepoType
Label:Repo Type
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:1
Default:C
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:10
Y:35
Action:F
Width:19
Name:AccruedAmount
Label:Accrued Cash
SendMsg:0
Display:0
Sent:0
ReadOnly:1
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:3
Default:-999 999 999 999.99
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:240
Y:35
Action:F
Width:17
Name:Accrued2
Label:Accrued2
SendMsg:0
Display:0
Sent:0
ReadOnly:1
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:4
Default:-9 999.9999999999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:480
Y:35
Action:F
Width:19
Name:AccruedAmount2
Label:Accrued2 Cash
SendMsg:0
Display:0
Sent:0
ReadOnly:1
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:5
Default:-999 999 999 999.99
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:240
Y:60
Action:F
Width:18
Name:Prepayment
Label:Prepayment
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:6
Default:999 999 999 999.99
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:480
Y:60
Action:Y
Width:1
Name:NeedPrepayment
Label:Need Prepayment
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:7
Foreign:1
ChoiceDisp:0
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:10
Y:60
Action:F
Width:19
Name:DirtyPrice2
Label:Dirty Price2
SendMsg:0
Display:0
Sent:0
ReadOnly:1
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:8
Default:9 999 999.999999999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:10
Y:85
Action:F
Width:15
Name:Discount
Label:Discount
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:9
Default:-999 999.999999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:240
Y:85
Action:F
Width:17
Name:FixedRate2
Label:Fixed Rate2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:10
Default:999 999.999999999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:10
Y:185
Action:D
Width:10
Name:SettlementDate
Label:SettlementDate
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:11
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:240
Y:185
Action:D
Width:10
Name:SettlementDate2
Label:SettlementDate2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:12
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:240
Y:135
Action:C
Width:1
Name:DeliveryCondition1
Label:DeliveryCondition1
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:14
Default:N
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:480
Y:135
Action:C
Width:1
Name:DeliveryCondition2
Label:DeliveryCondition2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:15
Default:N
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:10
Y:160
Action:C
Width:1
Name:AgreementPrepare
Label:Agreement Prepare
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:16
Default:C
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:240
Y:160
Action:C
Width:1
Name:DeliveryActive
Label:DeliveryActive
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:17
Default:C
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:480
Y:160
Action:C
Width:1
Name:DeliveryExpensePayer
Label:DeliveryExpensePayer
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:18
Default:C
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:10
Y:110
Action:C
Width:1
Name:FwdPriceMethod
Label:FwdPriceMethod
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:19
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:480
Y:10
Action:F
Width:19
Name:DirtyPrice
Label:DirtyPrice
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:20
Default:9 999 999.999999999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:480
Y:85
Action:F
Width:20
Name:ForwardPrice2
Label:Forward Price2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:21
Default:9 999 999.9999999999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:240
Y:110
Action:F
Width:19
Name:GrossAmount2
Label:Gross Amount2
SendMsg:0
Display:0
Sent:0
ReadOnly:1
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:22
Default:-999 999 999 999.99
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:480
Y:185
Action:C
Width:1
Name:TradingPlace
Label:TradingPlace
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:23
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:480
Y:110
Action:F
Width:19
Name:ForwardAmount2
Label:Forward Amount2
SendMsg:0
Display:0
Sent:0
ReadOnly:1
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:24
Default:-999 999 999 999.99
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:10
Y:210
Action:F
Width:15
Name:MarginCallTrigger
Label:MarginCallTrigger
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:25
Default:-999 999.999999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:480
Y:210
Action:C
Width:1
Name:CapturedDiscount
Label:CapturedDiscount
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:27
Default:D
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:240
Y:210
Action:F
Width:20
Name:Haircut2
Label:Haircut2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:26
Default:-9 999 999.999999999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:10
Y:240
Action:C
Width:1
Name:MarginCallMethod
Label:MarginCallMethod
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:28
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:240
Y:240
Action:F
Width:15
Name:MarginCallLower
Label:MarginCallLower
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:29
Default:-999 999.999999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:480
Y:240
Action:F
Width:15
Name:MarginCallUpper
Label:MarginCallUpper
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:30
Default:-999 999.999999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:279
Y:266
Action:Y
Width:1
Name:ToBeProcessed
Label:ToBeProcessed
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:31
Foreign:1
ChoiceDisp:0
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:10
Y:264
Action:F
Width:15
Name:MarginCallKnockOut
Label:MarginCallKnockOut
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:32
Default:999.99999999999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:479
Y:263
Action:F
Width:18
Name:WeightedAmount2
Label:Weighted Amount
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:33
Default:99999999999999.999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:10
Y:291
Action:F
Width:18
Name:GrossAmount1
Label:GrossAmount1
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:34
Default:99999999999999.999
Foreign:1
Panel:0
Size:0
Square:0
Selector:0
PanelHeight:0
START_Square:0
START_Help:2
X:240
Y:10
Procedure4:Currencies_Id_Price
Name:kplus..Currencies
Label:Price Currency
SendMsg:0
Selector:0
Length:2
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
CaretNumber:2
PersList:0
Procedure5:Currencies_Id_Price
Default:Currencies_Id
Action:I
Width:15
Display:0
Store:1
Sent:0
Foreign:1
UpperCase:0
Seconds:999 999 999 999
Procedure5:Currencies_ShortName
Default:Currencies_ShortName
Action:T
Width:3
Display:1
Store:0
Sent:0
Foreign:0
UpperCase:1
Panel:0
Size:0
Square:0
NEXT_Help:0
X:10
Y:135
Procedure4:ClearingModes_Id_Cpty
Name:kplus..ClearingModes
Label:Clearing Cpty
SendMsg:0
Selector:0
Length:2
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
CaretNumber:13
PersList:0
Procedure5:ClearingModes_Id_Cpty
Default:ClearingModes_Id
Action:I
Width:15
Display:0
Store:1
Sent:0
Foreign:1
UpperCase:0
Seconds:999 999 999 999
Procedure5:ClearingModes_ShortName
Default:ClearingModes_ShortName
Action:T
Width:12
Display:1
Store:0
Sent:0
Foreign:0
UpperCase:1
Panel:0
Size:0
Square:0
START_List:0
START_Foreign:34
Name:RepoType
NEXT_Foreign:0
Name:Currencies_Id_Price
NEXT_Foreign:0
Name:Accrued2
NEXT_Foreign:0
Name:Prepayment
NEXT_Foreign:0
Name:NeedPrepayment
NEXT_Foreign:0
Name:Discount
NEXT_Foreign:0
Name:FixedRate2
NEXT_Foreign:0
Name:SettlementDate
NEXT_Foreign:0
Name:SettlementDate2
NEXT_Foreign:0
Name:DeliveryCondition1
NEXT_Foreign:0
Name:DeliveryCondition2
NEXT_Foreign:0
Name:ClearingModes_Id_Cpty
NEXT_Foreign:0
Name:AgreementPrepare
NEXT_Foreign:0
Name:DeliveryActive
NEXT_Foreign:0
Name:DeliveryExpensePayer
NEXT_Foreign:0
Name:FwdPriceMethod
NEXT_Foreign:0
Name:AccruedAmount
NEXT_Foreign:0
Name:AccruedAmount2
NEXT_Foreign:0
Name:DirtyPrice2
NEXT_Foreign:0
Name:DirtyPrice
NEXT_Foreign:0
Name:ForwardPrice2
NEXT_Foreign:0
Name:GrossAmount2
NEXT_Foreign:0
Name:TradingPlace
NEXT_Foreign:0
Name:ForwardAmount2
NEXT_Foreign:0
Name:CapturedDiscount
NEXT_Foreign:0
Name:Haircut2
NEXT_Foreign:0
Name:MarginCallMethod
NEXT_Foreign:0
Name:MarginCallLower
NEXT_Foreign:0
Name:MarginCallUpper
NEXT_Foreign:0
Name:MarginCallTrigger
NEXT_Foreign:0
Name:MarginCallKnockOut
NEXT_Foreign:0
Name:ToBeProcessed
NEXT_Foreign:0
Name:WeightedAmount2
NEXT_Foreign:0
Name:GrossAmount1
START_Notify:0
START_Proc:1
Name:RSG_RepoDealEx_check
Label:coherence
Action:C
Length:32
Default:Trigger
Default:RepoDeals-Cpty_Id
Default:RepoDeals-TradeDate
Default:RepoSecuSched-ClearingModes_Id
Default:RepoDeals-Folders_Id
Default:RepoDeals-DealStatus
Default:Users_Id
Default:RepoDeals-RepoDeals_Id
Default:TradingPlace
Default:Pid
Default:RepoDeals-DownloadKey
Default:RepoSecuSched-Bonds_Id
Default:RepoSecuSched-Equities_Id
Default:RepoSecuSched-Quantity
Default:Discount
Default:RepoDeals-Basis
Default:RepoDeals-ValueDate
Default:SettlementDate
Default:RepoSecuSched-Price
Default:RepoSecuSched-Accrued
Default:AccruedAmount
Default:WeightedAmount2
Default:RepoDeals-MaturityDate
Default:SettlementDate2
Default:ForwardAmount2
Default:ForwardPrice2
Default:Accrued2
Default:AccruedAmount2
Default:RepoDeals-DealType
Default:RepoDeals-Currencies_Id
Default:RepoDeals-DeliveryMode
Default:RepoDeals-Brokers_Id
')


BEGIN TRAN
DECLARE @KdbDatabases_Id_Kustom int 

SELECT @KdbDatabases_Id_Kustom = D.KdbLocalDatabases_Id 
FROM   kplus..KdbLocalDatabases D
WHERE  D.DatabaseName = 'Kustom' 

IF @@rowcount = 0
BEGIN
	SELECT @KdbDatabases_Id_Kustom = ISNULL(MAX(D.KdbLocalDatabases_Id) + 1, 10000) 
	FROM kplus..KdbLocalDatabases D
	WHERE D.KdbLocalDatabases_Id >= 10000
	AND D.KdbLocalDatabases_Id < 20000
	IF @KdbDatabases_Id_Kustom >= 20000
	BEGIN
		RAISERROR 30000 'You have too many kustom local databases (limited to 10000). Cannot proceed...'
	END
	INSERT kplus..KdbLocalDatabases VALUES (
  @KdbDatabases_Id_Kustom, 	 'Kustom', 	 'P', 	 'Kustom', 	  2    )
END

DECLARE @KdbDatabases_Id_Version int

SELECT @KdbDatabases_Id_Version = D.KdbLocalDatabases_Id 
FROM   kplus..KdbLocalDatabases D
WHERE  D.DatabaseName = 'Kustom' 

IF @@rowcount = 0
BEGIN
	SELECT @KdbDatabases_Id_Version = ISNULL(MAX(D.KdbLocalDatabases_Id) + 1, 10000) 
	FROM kplus..KdbLocalDatabases D
	WHERE D.KdbLocalDatabases_Id >= 10000
	AND D.KdbLocalDatabases_Id < 20000
	IF @KdbDatabases_Id_Version >= 20000
	BEGIN
		RAISERROR 30000 'You have too many kustom local databases (limited to 10000). Cannot proceed...'
	END
	INSERT kplus..KdbLocalDatabases VALUES (
  @KdbDatabases_Id_Version, 	 'Kustom', 	 'P', 	 'Kustom', 	  2    )
END

DECLARE @KdbTables_Id_Kustom int

SELECT @KdbTables_Id_Kustom = T.KdbTables_Id 
FROM   kplus..KdbTables T 
WHERE  T.KdbTables_Name    = 'RepoDealsEx' 
AND    T.KdbDatabases_Id   = @KdbDatabases_Id_Kustom 


IF @@rowcount = 0
BEGIN
	SELECT @KdbTables_Id_Kustom = ISNULL(MAX(T.KdbTables_Id) + 1, 10000) 
	FROM kplus..KdbTables T
	WHERE T.KdbTables_Id >= 10000
	AND T.KdbTables_Id < 20000
	IF @KdbTables_Id_Kustom >= 20000
	BEGIN
		RAISERROR 30000 'You have too many kustom local tables (limited to 10000). Cannot proceed...'
	END
END

DELETE kplus..KdbLocalFieldsT  
WHERE KdbLocalTables_Id = @KdbTables_Id_Kustom 

DELETE kplus..KdbLocalTablesT  
WHERE KdbLocalTables_Id = @KdbTables_Id_Kustom 

INSERT kplus..KdbLocalTablesT Values (
@KdbTables_Id_Kustom, 'RepoDealsEx', 'RepoDealsEx',  @KdbDatabases_Id_Kustom,  0,  36, 'Q', 'D', 'FOREIGN',  0,  39,  0,  0, 'R', 'N', 'N', 'N', 'R', 'FOREIGN', 'N', 'N', 'N', 'Y',  0,   0,  'N',  2  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 0, 'DealType',  'DealType',  0,  4,  0,  0, 32,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 1, 'DealId',  'DealId',  0,  1,  0,  0,  5,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N', '999 999 999',  NULL  )
DECLARE @KdbTables_Id_Version int 

SELECT @KdbTables_Id_Version = T.KdbTables_Id 
FROM   kplus..KdbTables T 
WHERE  T.KdbTables_Name    = 'KustomRepoDealsExVer' 
AND    T.KdbDatabases_Id   = @KdbDatabases_Id_Version 


IF @@rowcount = 0
BEGIN
	SELECT @KdbTables_Id_Version = ISNULL(MAX(T.KdbTables_Id) + 1, 10000) 
	FROM kplus..KdbTables T
	WHERE T.KdbTables_Id >= 10000
	AND T.KdbTables_Id < 20000
	IF @KdbTables_Id_Version >= 20000
	BEGIN
		RAISERROR 30000 'You have too many kustom local tables (limited to 10000). Cannot proceed...'
	END
END

DELETE kplus..KdbLocalFieldsT  
WHERE KdbLocalTables_Id = @KdbTables_Id_Version 

DELETE kplus..KdbLocalTablesT  
WHERE KdbLocalTables_Id = @KdbTables_Id_Version 

INSERT kplus..KdbLocalTablesT Values (
@KdbTables_Id_Version, 'KustomRepoDealsExVer', 'RepoDealsExVer Kustom',  @KdbDatabases_Id_Version,  0,  39, 'O', 'D', 'FOREIGN',  0,  39,  0,  0, 'R', 'N', 'N', 'N', 'R', 'FOREIGN', 'N', 'N', 'N', 'Y',  0,   0,  'N',  2  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 0, 'TransactionId',  'Transaction Id',  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 1, 'DealType',  'DealType',  0,  4,  0,  0,  32,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 2, 'DealId',  'DealId',  0,  1,  0,  0,  5,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N', '999 999 999',  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 37, 'VersionStartDate',  'Version Start Date',  0,  8,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 38, 'VersionEndDate',  'Version End Date',  0,  8,  0,  0,  32,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 2, 'RepoType',  'RepoType',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field RepoType'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 3, 'RepoType',  'RepoType',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field RepoType'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 3, 'Currencies_Id_Price',  'Currencies_Id_Price',  0,  10,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '999 999 999 999',  'TradeKast field Currencies_Id_Price'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 4, 'Currencies_Id_Price',  'Currencies_Id_Price',  0,  10,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '999 999 999 999',  'TradeKast field Currencies_Id_Price'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 4, 'Accrued2',  'Accrued2',  0,  9,  0,  0,  17,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-9 999.9999999999',  'TradeKast field Accrued2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 5, 'Accrued2',  'Accrued2',  0,  9,  0,  0,  17,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-9 999.9999999999',  'TradeKast field Accrued2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 5, 'Prepayment',  'Prepayment',  0,  9,  0,  0,  18,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '999 999 999 999.99',  'TradeKast field Prepayment'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 6, 'Prepayment',  'Prepayment',  0,  9,  0,  0,  18,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '999 999 999 999.99',  'TradeKast field Prepayment'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 6, 'NeedPrepayment',  'NeedPrepayment',  0,  6,  0,  1,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field NeedPrepayment'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 7, 'NeedPrepayment',  'NeedPrepayment',  0,  6,  0,  1,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field NeedPrepayment'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 7, 'Discount',  'Discount',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999.999999',  'TradeKast field Discount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 8, 'Discount',  'Discount',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999.999999',  'TradeKast field Discount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 8, 'FixedRate2',  'FixedRate2',  0,  9,  0,  0,  17,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '999 999.999999999',  'TradeKast field FixedRate2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 9, 'FixedRate2',  'FixedRate2',  0,  9,  0,  0,  17,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '999 999.999999999',  'TradeKast field FixedRate2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 9, 'SettlementDate',  'SettlementDate',  0,  7,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field SettlementDate'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 10, 'SettlementDate',  'SettlementDate',  0,  7,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field SettlementDate'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 10, 'SettlementDate2',  'SettlementDate2',  0,  7,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field SettlementDate2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 11, 'SettlementDate2',  'SettlementDate2',  0,  7,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field SettlementDate2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 11, 'DeliveryCondition1',  'DeliveryCondition1',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryCondition1'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 12, 'DeliveryCondition1',  'DeliveryCondition1',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryCondition1'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 12, 'DeliveryCondition2',  'DeliveryCondition2',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryCondition2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 13, 'DeliveryCondition2',  'DeliveryCondition2',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryCondition2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 13, 'ClearingModes_Id_Cpty',  'ClearingModes_Id_Cpty',  0,  10,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '999 999 999 999',  'TradeKast field ClearingModes_Id_Cpty'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 14, 'ClearingModes_Id_Cpty',  'ClearingModes_Id_Cpty',  0,  10,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '999 999 999 999',  'TradeKast field ClearingModes_Id_Cpty'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 14, 'AgreementPrepare',  'AgreementPrepare',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field AgreementPrepare'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 15, 'AgreementPrepare',  'AgreementPrepare',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field AgreementPrepare'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 15, 'DeliveryActive',  'DeliveryActive',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryActive'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 16, 'DeliveryActive',  'DeliveryActive',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryActive'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 16, 'DeliveryExpensePayer',  'DeliveryExpensePayer',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryExpensePayer'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 17, 'DeliveryExpensePayer',  'DeliveryExpensePayer',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryExpensePayer'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 17, 'FwdPriceMethod',  'FwdPriceMethod',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field FwdPriceMethod'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 18, 'FwdPriceMethod',  'FwdPriceMethod',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field FwdPriceMethod'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 18, 'AccruedAmount',  'AccruedAmount',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field AccruedAmount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 19, 'AccruedAmount',  'AccruedAmount',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field AccruedAmount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 19, 'AccruedAmount2',  'AccruedAmount2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field AccruedAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 20, 'AccruedAmount2',  'AccruedAmount2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field AccruedAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 20, 'DirtyPrice2',  'DirtyPrice2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '9 999 999.999999999',  'TradeKast field DirtyPrice2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 21, 'DirtyPrice2',  'DirtyPrice2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '9 999 999.999999999',  'TradeKast field DirtyPrice2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 21, 'DirtyPrice',  'DirtyPrice',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '9 999 999.999999999',  'TradeKast field DirtyPrice'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 22, 'DirtyPrice',  'DirtyPrice',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '9 999 999.999999999',  'TradeKast field DirtyPrice'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 22, 'ForwardPrice2',  'ForwardPrice2',  0,  9,  0,  0,  20,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '9 999 999.9999999999',  'TradeKast field ForwardPrice2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 23, 'ForwardPrice2',  'ForwardPrice2',  0,  9,  0,  0,  20,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '9 999 999.9999999999',  'TradeKast field ForwardPrice2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 23, 'GrossAmount2',  'GrossAmount2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field GrossAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 24, 'GrossAmount2',  'GrossAmount2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field GrossAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 24, 'TradingPlace',  'TradingPlace',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field TradingPlace'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 25, 'TradingPlace',  'TradingPlace',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field TradingPlace'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 25, 'ForwardAmount2',  'ForwardAmount2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field ForwardAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 26, 'ForwardAmount2',  'ForwardAmount2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field ForwardAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 26, 'CapturedDiscount',  'CapturedDiscount',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CapturedDiscount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 27, 'CapturedDiscount',  'CapturedDiscount',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CapturedDiscount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 27, 'Haircut2',  'Haircut2',  0,  9,  0,  0,  20,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-9 999 999.999999999',  'TradeKast field Haircut2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 28, 'Haircut2',  'Haircut2',  0,  9,  0,  0,  20,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-9 999 999.999999999',  'TradeKast field Haircut2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 28, 'MarginCallMethod',  'MarginCallMethod',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field MarginCallMethod'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 29, 'MarginCallMethod',  'MarginCallMethod',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field MarginCallMethod'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 29, 'MarginCallLower',  'MarginCallLower',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999.999999',  'TradeKast field MarginCallLower'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 30, 'MarginCallLower',  'MarginCallLower',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999.999999',  'TradeKast field MarginCallLower'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 30, 'MarginCallUpper',  'MarginCallUpper',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999.999999',  'TradeKast field MarginCallUpper'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 31, 'MarginCallUpper',  'MarginCallUpper',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999.999999',  'TradeKast field MarginCallUpper'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 31, 'MarginCallTrigger',  'MarginCallTrigger',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999.999999',  'TradeKast field MarginCallTrigger'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 32, 'MarginCallTrigger',  'MarginCallTrigger',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999.999999',  'TradeKast field MarginCallTrigger'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 32, 'MarginCallKnockOut',  'MarginCallKnockOut',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '999.99999999999',  'TradeKast field MarginCallKnockOut'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 33, 'MarginCallKnockOut',  'MarginCallKnockOut',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '999.99999999999',  'TradeKast field MarginCallKnockOut'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 33, 'ToBeProcessed',  'ToBeProcessed',  0,  6,  0,  1,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field ToBeProcessed'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 34, 'ToBeProcessed',  'ToBeProcessed',  0,  6,  0,  1,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field ToBeProcessed'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 34, 'WeightedAmount2',  'WeightedAmount2',  0,  9,  0,  0,  18,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '99999999999999.999',  'TradeKast field WeightedAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 35, 'WeightedAmount2',  'WeightedAmount2',  0,  9,  0,  0,  18,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '99999999999999.999',  'TradeKast field WeightedAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 35, 'GrossAmount1',  'GrossAmount1',  0,  9,  0,  0,  18,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '99999999999999.999',  'TradeKast field GrossAmount1'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 36, 'GrossAmount1',  'GrossAmount1',  0,  9,  0,  0,  18,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '99999999999999.999',  'TradeKast field GrossAmount1'  )

COMMIT TRAN
go

/*-------------------------------------------------*/
/*--- Tables export -------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		RepoDealsEx
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RepoDealsEx' AND type = 'U' 
)
	DROP table RepoDealsEx 
go


CREATE table RepoDealsEx
(
DealType                        varchar(32)     not null,
DealId                          int             not null,
RepoType                        char(1)         null,
Currencies_Id_Price             int             null,
Accrued2                        float           null,
Prepayment                      float           null,
NeedPrepayment                  char(1)         null,
Discount                        float           null,
FixedRate2                      float           null,
SettlementDate                  datetime        null,
SettlementDate2                 datetime        null,
DeliveryCondition1              char(1)         null,
DeliveryCondition2              char(1)         null,
ClearingModes_Id_Cpty           int             null,
AgreementPrepare                char(1)         null,
DeliveryActive                  char(1)         null,
DeliveryExpensePayer            char(1)         null,
FwdPriceMethod                  char(1)         null,
AccruedAmount                   float           null,
AccruedAmount2                  float           null,
DirtyPrice2                     float           null,
DirtyPrice                      float           null,
ForwardPrice2                   float           null,
GrossAmount2                    float           null,
TradingPlace                    char(1)         null,
ForwardAmount2                  float           null,
CapturedDiscount                char(1)         null,
Haircut2                        float           null,
MarginCallMethod                char(1)         null,
MarginCallLower                 float           null,
MarginCallUpper                 float           null,
MarginCallTrigger               float           null,
MarginCallKnockOut              float           null,
ToBeProcessed                   char(1)         null,
WeightedAmount2                 float           null,
GrossAmount1                    float           null 
)
LOCK DATAROWS



/*--- INDEXES -------------------------------------*/

CREATE  INDEX IX_RepoDealsEx ON RepoDealsEx 
(
	DealId,
	DealType 
)


go

GRANT ALL ON RepoDealsEx TO PUBLIC 
go



USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRepoDealsExVer' AND type = 'U'
)
	DROP table KustomRepoDealsExVer 
go


CREATE table KustomRepoDealsExVer
(
TransactionId                   int             not null,
DealType                        varchar(32)     not null,
DealId                          int             not null,
RepoType                        char(1)         null,
Currencies_Id_Price             int             null,
Accrued2                        float           null,
Prepayment                      float           null,
NeedPrepayment                  char(1)         null,
Discount                        float           null,
FixedRate2                      float           null,
SettlementDate                  datetime        null,
SettlementDate2                 datetime        null,
DeliveryCondition1              char(1)         null,
DeliveryCondition2              char(1)         null,
ClearingModes_Id_Cpty           int             null,
AgreementPrepare                char(1)         null,
DeliveryActive                  char(1)         null,
DeliveryExpensePayer            char(1)         null,
FwdPriceMethod                  char(1)         null,
AccruedAmount                   float           null,
AccruedAmount2                  float           null,
DirtyPrice2                     float           null,
DirtyPrice                      float           null,
ForwardPrice2                   float           null,
GrossAmount2                    float           null,
TradingPlace                    char(1)         null,
ForwardAmount2                  float           null,
CapturedDiscount                char(1)         null,
Haircut2                        float           null,
MarginCallMethod                char(1)         null,
MarginCallLower                 float           null,
MarginCallUpper                 float           null,
MarginCallTrigger               float           null,
MarginCallKnockOut              float           null,
ToBeProcessed                   char(1)         null,
WeightedAmount2                 float           null,
GrossAmount1                    float           null,
VersionStartDate                datetime        not null,
VersionEndDate                  datetime        not null,
)



/*--- INDEXES -------------------------------------*/

CREATE UNIQUE INDEX KustomRepoDealsExVerIdx1 ON KustomRepoDealsExVer 
(
	TransactionId,
	DealType,
	DealId
)

CREATE INDEX KustomRepoDealsExVerIdx2 ON KustomRepoDealsExVer 
(
	VersionStartDate
)

CREATE INDEX KustomRepoDealsExVerIdx3 ON KustomRepoDealsExVer 
(
	VersionEndDate
)

CREATE  INDEX IX_RepoDealsEx ON Kustom..RepoDealsExVer 
(
	DealId,
	DealType 
)


GRANT ALL ON KustomRepoDealsExVer TO PUBLIC 
go



USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRepoDealsExMvts' AND type = 'U'
)
	DROP table KustomRepoDealsExMvts 
go


CREATE table KustomRepoDealsExMvts
(
TransactionId                   int             not null,
Action                          char(1)         not null,
MvtId                           numeric(20)     not null,
DealType                        varchar(32)     not null,
DealId                          int             not null,
RepoType_                       char(1)         null,
Currencies_Id_Price_            int             null,
Accrued2_                       float           null,
Prepayment_                     float           null,
NeedPrepayment_                 char(1)         null,
Discount_                       float           null,
FixedRate2_                     float           null,
SettlementDate_                 datetime        null,
SettlementDate2_                datetime        null,
DeliveryCondition1_             char(1)         null,
DeliveryCondition2_             char(1)         null,
ClearingModes_Id_Cpty_          int             null,
AgreementPrepare_               char(1)         null,
DeliveryActive_                 char(1)         null,
DeliveryExpensePayer_           char(1)         null,
FwdPriceMethod_                 char(1)         null,
AccruedAmount_                  float           null,
AccruedAmount2_                 float           null,
DirtyPrice2_                    float           null,
DirtyPrice_                     float           null,
ForwardPrice2_                  float           null,
GrossAmount2_                   float           null,
TradingPlace_                   char(1)         null,
ForwardAmount2_                 float           null,
CapturedDiscount_               char(1)         null,
Haircut2_                       float           null,
MarginCallMethod_               char(1)         null,
MarginCallLower_                float           null,
MarginCallUpper_                float           null,
MarginCallTrigger_              float           null,
MarginCallKnockOut_             float           null,
ToBeProcessed_                  char(1)         null,
WeightedAmount2_                float           null,
GrossAmount1_                   float           null,
)
LOCK DATAROWS


GRANT ALL ON KustomRepoDealsExMvts TO PUBLIC 
go

/*------------------------------------------------- 
		KustomRepoDealsExMvts_insert
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRepoDealsExMvts_insert' AND type = 'P' 
)
	DROP PROC KustomRepoDealsExMvts_insert 
go


CREATE PROCEDURE KustomRepoDealsExMvts_insert (@TableId int, @RowId int, @DealType varchar(32), @Action char(1) ) as
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
INSERT Kustom.dbo.KustomRepoDealsExMvts SELECT @TransId, @Action, @MvtId, F.DealType, F.DealId, F.RepoType, F.Currencies_Id_Price, F.Accrued2, F.Prepayment, F.NeedPrepayment, F.Discount, F.FixedRate2, F.SettlementDate, F.SettlementDate2, F.DeliveryCondition1, F.DeliveryCondition2, F.ClearingModes_Id_Cpty, F.AgreementPrepare, F.DeliveryActive, F.DeliveryExpensePayer, F.FwdPriceMethod, F.AccruedAmount, F.AccruedAmount2, F.DirtyPrice2, F.DirtyPrice, F.ForwardPrice2, F.GrossAmount2, F.TradingPlace, F.ForwardAmount2, F.CapturedDiscount, F.Haircut2, F.MarginCallMethod, F.MarginCallLower, F.MarginCallUpper, F.MarginCallTrigger, F.MarginCallKnockOut, F.ToBeProcessed, F.WeightedAmount2, F.GrossAmount1
FROM Kustom.dbo.RepoDealsEx F
WHERE F.DealId = @RowId AND F.DealType = @DealType 
END 
RETURN 0
END 
go



GRANT EXEC ON KustomRepoDealsExMvts_insert TO PUBLIC 
go

/*-------------------------------------------------*/
/*--- Procs export --------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		RSG_RepoDealEx_check
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RSG_RepoDealEx_check' AND type = 'P' 
)
	DROP PROC RSG_RepoDealEx_check 
go


CREATE PROCEDURE dbo.RSG_RepoDealEx_check(
@Trigger                           varchar(10)
,@Cpty_Id                           integer
,@TradeDate                         datetime
,@ClearingModes_Id                  integer
,@Folders_Id                        int
,@DealStatus                        char(1)
,@Users_Id                          int
,@RepoDeals_Id                      int
,@TradingPlace                      char(1)
,@Pid                               int
,@DownloadKey                       varchar(24)
,@Bonds_Id                          int
,@Equities_Id                       int
,@Quantity                          float
,@Discount                          float
,@Basis                            char(1)
,@ValueDate                        datetime
,@SettlementDate                   datetime
,@Price                            float
,@Accrued                           float
,@AccruedAmount                    float
,@WeightedAmount                   float
,@MaturityDate                     datetime
,@SettlementDate2                   datetime
,@ForwardAmount                    float
,@ForwardPrice                     float
,@Accrued2                         float
,@AccruedAmount2                   float
,@DealType                         char(1)
,@Currencies_Id                    int
,@DeliveryMode                     char(1)
,@Brokers_Id                        int
)
AS
    BEGIN
    
    /*----------------------------------------------------------*/
    /*															*/
    /* CW coherence procedure                  					*/
    /* Prepared during the proekt P14-629 Diasoft implementation*/
    /*															*/
    /* Author: M.Bashkov. Rosbank	    						*/
    /* 2015/2016    											*/
    /*															*/
    /*----------------------------------------------------------*/

declare @IsOK           int
        ,@Message       varchar(255)
        ,@ForControl                        char
        ,@oDealStatus   char(1)
        ,@KdbTables_Id                      int
        ,@Codifiers_Id_Back                 int
        ,@IsModified          char(1)
   ,@ProcessingState     char(1)
   ,@StatusMessage             varchar(512)
   ,@Updatable   	   char(1)    
   ,@BackDeals_Id_1	   varchar(32)
   ,@BackDeals_Id_2	   varchar(32) 
   ,@BackDealStatus 	   varchar(32)
   ,@BackDealStatus_2	   varchar(32) 
   ,@Updatable_2	           char(1)
   ,@oBonds_Id              int
   ,@oEquities_Id           int
   ,@oTradeDate             datetime
   ,@oQuantity              float
   ,@oDiscount              float
   ,@oBasis                 char(1)
   ,@oValueDate             datetime
   ,@oSettlementDate        datetime
   ,@oPrice                 float
   ,@oAccrued               float
   ,@oAccruedAmount         float
   ,@oWeightedAmount        float
   ,@oMaturityDate          datetime
   ,@oSettlementDate2       datetime
   ,@oForwardPrice          float
   ,@oAccrued2              float
   ,@oAccruedAmount2        float
   ,@oForwardAmount         float
   ,@oCpty_Id               int
   ,@oClearingModes_Id      int
   ,@oDealType              char(1)
   ,@oCurrencies_Id         int
   ,@oDeliveryMode          char(1)
   ,@oTradingPlace          char(1)
   ,@MessageUpdate       varchar(255)
   ,@oFolders_Id            int
   ,@oBrokers_Id            int
   ,@Check_Folder_Result                int                
   ,@Check_Folder_Message        varchar(128)
        
        
-- Assing Table Id

select @KdbTables_Id = 395        
        
-- Assign IsOK

select @IsOK = 1, @Message = ""

/*----------Get old deal parameters-----------------------*/

if @Trigger = 'Update'
   select @oDealStatus = d.DealStatus
    from kplus.dbo.RepoDeals d
    where d.RepoDeals_Id = @RepoDeals_Id
else 
   select @oDealStatus = 'N'

/*----------Work on valid operation in GUI-----------------------*/

if @Trigger in ('Insert', 'Update')  
    and @DealStatus = 'V'
    and @oDealStatus != @DealStatus
    --and isnull(@Pid ,0) = 0 
    -- GUI only - not exchange
    and @DownloadKey not like "%B" and @DownloadKey not like "%S"
    -- User is not in FINADMIN group
    and not exists (select 1 from kplus.dbo.Users 
                                where Users_Id = @Users_Id
                                  and UsersGrp_Id = 27128 -- FINADMIN UsersGrp_Id
                                  )
begin

  -- Check Clearing Mode for external deals
  if @ClearingModes_Id = 1068 -- Clearing Mode D - Id
  begin
    if not exists (select 1 from kplus.dbo.Folders where Cpty_Id = @Cpty_Id) 
    begin
       select @IsOK = 0
       select @Message = "Set not Default (D) Clearing Mode for external deals"
    end
  end
  else
  -- Check Trading Place
  begin
     if @TradingPlace != "O"
     begin
        select @IsOK = 0
        select @Message = "Trading Place must be OTC"
     end  
  end
  
end 

/*----------End valid operation in GUI-----------------------*/

/*----------Check if deal in Diasoft-----------------------*/

select @Codifiers_Id_Back = c.Codifiers_Id
   from kplus.dbo.Codifiers c
   where c.Codifiers_ShortName = 'K2DIASOFT'

   -- get Production BackOffice status
   exec Kondor2Back_GetDealStatusExt
      @KdbTables_Id        = @KdbTables_Id,
      @Deals_Id            = @RepoDeals_Id,
      @Codifiers_Id        = @Codifiers_Id_Back,
      @BackDeals_Id        = @BackDeals_Id_1   output,
      @BackDeals_Id_2	   = @BackDeals_Id_2   output,	   
      @BackDealStatus      = @BackDealStatus   output, 
      @BackDealStatus_2    = @BackDealStatus_2 output, 
      @Updatable_2	   = @Updatable_2      output,    
      @Updatable	   = @Updatable        output,    
      @Message             = @StatusMessage          output,
      @ProcessingState     = @ProcessingState  output
      

if @ProcessingState = 'P' -- Processing to Diasoft
   begin
      select @IsOK = 0
      select @Message = "Deal is transferring to Diasoft. Try later."
      select @IsOK, @Message
      return
   end
   
if @Trigger = 'Delete'
      and (isnull(@BackDeals_Id_1,'') not in ('','0') or isnull(@BackDeals_Id_2,'') not in ('','0'))
      -- User is not in FINADMIN group
      and not exists (select 1 from kplus.dbo.Users 
                                where Users_Id = @Users_Id
                                  and UsersGrp_Id = 27128 -- FINADMIN UsersGrp_Id
                                  )
begin
      select @IsOK = 0
      select @Message = "You try to delete deal which is registered in Diasoft. " + @Trigger + " is forbidden!!!"
end

if @Trigger = 'Update'
      and (isnull(@BackDeals_Id_1,'') not in ('','0') or isnull(@BackDeals_Id_2,'') not in ('','0'))
      --and @Updatable = "N"
      and @IsOK = 1
      -- User is not in FINADMIN group
      and not exists (select 1 from kplus.dbo.Users 
                                where Users_Id = @Users_Id
                                  and UsersGrp_Id = 27128 -- FINADMIN UsersGrp_Id
                                  )
begin
   -- Start warning message
   select @MessageUpdate = "You are trying to update:"
   
   -- Read old data from deals table
   select @oBonds_Id = rss.Bonds_Id,
          @oEquities_Id = rss.Equities_Id,
          @oTradeDate = d.TradeDate,
          @oQuantity = rss.Quantity,
          @oDiscount = cw.Discount,
          @oBasis = d.Basis,
          @oValueDate = d.ValueDate,
          @oSettlementDate = cw.SettlementDate,
          @oPrice = rss.Price,
          @oAccrued = rss.Accrued,
          @oAccruedAmount = cw.AccruedAmount,
          @oWeightedAmount = cw.WeightedAmount2,
          @oMaturityDate = d.MaturityDate,
          @oSettlementDate2 = cw.SettlementDate2,
          @oForwardPrice = cw.ForwardPrice2,
          @oAccrued2 = cw.Accrued2,
          @oAccruedAmount2 = cw.AccruedAmount2,
          @oForwardAmount = cw.ForwardAmount2,
          @oCpty_Id = d.Cpty_Id,
          @oClearingModes_Id = rss.ClearingModes_Id,
          @oDealType = d.DealType,
          @oCurrencies_Id = d.Currencies_Id,
          @oDeliveryMode = d.DeliveryMode,
          @oTradingPlace = cw.TradingPlace,
          @oFolders_Id = d.Folders_Id,
          @oBrokers_Id = d.Brokers_Id
   from kplus.dbo.RepoDeals d, kplus.dbo.RepoSecuSched rss, Kustom..RepoDealsEx cw--, kplus.dbo.Brokers b
   where d.RepoDeals_Id = @RepoDeals_Id
     and rss.RepoDeals_Id = @RepoDeals_Id
     and cw.DealId = @RepoDeals_Id
     --and d.Brokers_Id = b.Brokers_Id
   
   -- Check parameters
   if isnull(@Bonds_Id,0) != isnull(@oBonds_Id,0)
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Bond"
   if isnull(@Equities_Id,0) != isnull(@oEquities_Id,0)
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Equity"
   if @TradeDate != @oTradeDate
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Trade Date"
   if @Quantity != @oQuantity
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Quantity"
   if isnull(@Discount,0) != isnull(@oDiscount,0)
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Discount"
   if @Basis != @oBasis
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Basis"
   if @ValueDate != @oValueDate
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Value Date"
   if @SettlementDate != @oSettlementDate
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Settlement Date"
   if @Price != @oPrice
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Price"
   if isnull(@Accrued,0) != isnull(@oAccrued,0)
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Accrued"
   if isnull(@AccruedAmount,0) != isnull(@oAccruedAmount,0)
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Accrued Cash"
   if @WeightedAmount != @oWeightedAmount
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Weighted Amount"
   if isnull(@MaturityDate,"01 Jan 2016") != isnull(@oMaturityDate,"01 Jan 2016")
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Maturity Date"
   if isnull(@SettlementDate2,"01 Jan 2016") != isnull(@oSettlementDate2,"01 Jan 2016")
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Settlement Date 2leg"
   if isnull(@ForwardAmount,0) != isnull(@oForwardAmount,0)
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Forward Amount"
   if isnull(@ForwardPrice,0) != isnull(@oForwardPrice,0)
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Forward Price"
   /*if isnull(@Accrued2,0) != isnull(@oAccrued2,0)
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Forward Accrued"*/ -- Commented due to the letters at 25.11.15
   if isnull(@AccruedAmount2,0) != isnull(@oAccruedAmount2,0)
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Accrued Cash 2leg"
   if @Cpty_Id != @oCpty_Id
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Counterparty"
   if @ClearingModes_Id != @oClearingModes_Id
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Clearing Mode"
   if @DealType != @oDealType
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Deal Type"
   if @Currencies_Id != @oCurrencies_Id
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Deal Currency"
   if @DeliveryMode != @oDeliveryMode
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Delivery Mode"
   if @TradingPlace != @oTradingPlace
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Trading Place"
   -- Check params which can be edited if deal is Updatable
   if @Updatable = "N"
   begin
     if @Folders_Id != @oFolders_Id
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Folder"
     if isnull(@Brokers_Id,0) != isnull(@oBrokers_Id,0)
      select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + "Broker"
   end
   else -- Check Folders condition
   begin
      if @Folders_Id != @oFolders_Id
      begin
         exec Kustom..RSG_K2D_CheckFolder4Updatable @Folders_Id, @oFolders_Id, @Check_Folder_Result output, @Check_Folder_Message output
         if @Check_Folder_Result = 0
            select @IsOK = 0, @MessageUpdate = @MessageUpdate + char(10) + @Check_Folder_Message
      end
   end
   
   -- Finalization
   if @IsOK = 0
      select @Message = @MessageUpdate + char(10) + "in deal which is registered in Diasoft. " + @Trigger + " is forbidden!!!"
      
end


--Final output
select isnull(@IsOK,1), @Message

    END

go



GRANT EXEC ON RSG_RepoDealEx_check TO PUBLIC 
go

