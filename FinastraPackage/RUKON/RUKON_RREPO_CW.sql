/*-------------------------------------------------*/
/*--- Initialization Part -------------------------*/
/*-------------------------------------------------*/

USE kplus
go

/*-------------------------------------------------*/
/*--- Boxes export --------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		RREPO.RepoDeals
---------------------------------------------------*/

DECLARE @Codifiers_Id     int, 
  @ModuleId_ETOD         int, 
	@ETOD_Id  int, 
	@KdbTables_Id_ETOD     int 

IF NOT EXISTS 
(
	SELECT Codifiers_Id 
	FROM kplus..Codifiers
	WHERE  Codifiers_ShortName = 'RREPO' 
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
		'RREPO',
		'RUSSIAN REPO'
	)

END 


SELECT @Codifiers_Id = Codifiers_Id 
FROM kplus..Codifiers 
WHERE  Codifiers_ShortName = 'RREPO' 


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


INSERT kplus..CustomWindow VALUES ( @Codifiers_Id, @ETOD_Id, 'N', 'N', 'KustomRUKON_RepoDeals', 
'NEXT_Client:0
Name:RREPO
Action:@KdbTables_Id_ETOD
TOD_origin:N
Label:RUKON_RepoDeals
Scrollbars:0
Width:800
Height:400
ViewableWidth:815
ViewableHeight:478
Store:1
SendMsg:1
Seconds:0
Prolong:1
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
Procedure3:StoreDealData
START_Inquiry:1
X:763
Y:12
Name:Calculate
Label:C
Action:0
Procedure:CleanAll
SendMsg:0
Color1:0
Color2:1
Color3:0
CaretNumber:35
Panel:0
Size:8
Square:0
START_Input:43
X:100
Y:10
Action:S
Width:7
Name:RepoType
Label:Repo Type
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:1
Foreign:1
Length:2
Default:Classic
Default:Normal
ChoiceDisp:0
ChoiceReplace:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:600
Y:10
Action:F
Width:14
Name:DirtyPrice
Label:Dirty Price
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:3
Default:-999.999999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:100
Y:35
Action:F
Width:15
Name:AccruedCash
Label:Accrued Cash
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:4
Default:-999 999 999.99
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:350
Y:35
Action:F
Width:16
Name:Accrued2
Label:Accrued2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:5
Default:-999.99999999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:600
Y:35
Action:F
Width:15
Name:Accrued2Cash
Label:Accrued2 Cash
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:6
Default:-999 999 999.99
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:100
Y:60
Action:F
Width:14
Name:DirtyPrice2
Label:Dirty Price2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:7
Default:-999.999999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:350
Y:60
Action:F
Width:19
Name:Prepayment
Label:Prepayment
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:8
Default:-999 999 999 999.99
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:700
Y:60
Action:Y
Width:1
Name:NeedPrepayment
Label:Need Prepayment
Procedure:CalculateValues
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:9
Foreign:1
ChoiceDisp:0
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:100
Y:85
Action:F
Width:14
Name:Discount
Label:Discount
Procedure:CalculateValues
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:10
Default:-999.999999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:350
Y:85
Action:F
Width:14
Name:FixedRate2
Label:Fixed Rate2
Procedure:SetRate
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:11
Default:-999.999999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:600
Y:85
Action:F
Width:14
Name:ForwardPrice2
Label:Forward Price 2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:12
Default:-999.999999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:107
Y:116
Action:S
Width:14
Name:FwdPriceMethod
Label:FwdPriceMethod
Procedure:CalculateValues
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:13
Foreign:1
Length:5
Default:MOEX 4 digits
Default:Default
Default:ZCalypso
Default:6MOEX 6 digits
Default:7Bloomberg
ChoiceDisp:0
ChoiceReplace:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:354
Y:114
Action:F
Width:19
Name:GrossAmount2
Label:Gross Amount2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:14
Default:-999 999 999 999.99
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:602
Y:112
Action:F
Width:19
Name:ForwardAmount2
Label:Fwd Amount2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:15
Default:-999 999 999 999.99
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:350
Y:135
Action:S
Width:9
Name:DeliveryCondition1
Label:DelCondition1
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:17
Foreign:1
Length:2
Default:DVP
Default:ValueDate
ChoiceDisp:0
ChoiceReplace:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:600
Y:135
Action:S
Width:9
Name:DeliveryCondition2
Label:DelCondition2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:18
Foreign:1
Length:2
Default:DVP
Default:ValueDate
ChoiceDisp:0
ChoiceReplace:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:100
Y:160
Action:T
Width:1
Name:AgreementPrepare
Label:AgrmntPrepare
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:19
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:350
Y:160
Action:T
Width:1
Name:DeliveryActive
Label:DeliveryActive
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:20
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:700
Y:160
Action:T
Width:1
Name:DeliveryExpensePayer
Label:DeliveryExpensePayer
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:21
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:100
Y:185
Action:D
Width:10
Name:SettlementDate
Label:SettlementDate
Procedure:CalculateValues
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:22
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:350
Y:185
Action:D
Width:10
Name:SettlementDate2
Label:SettlementDate2
Procedure:CalculateValues
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:23
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:600
Y:185
Action:S
Width:4
Name:TradingPlace
Label:TradingPlace
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:24
Foreign:1
Length:2
Default:MOEX
Default:OTC
ChoiceDisp:0
ChoiceReplace:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:100
Y:210
Action:F
Width:11
Name:MarginCallTrigger
Label:MargCallTrigger
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:25
Default:-999.999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:350
Y:210
Action:F
Width:14
Name:Haircut2
Label:Haircut2
Procedure:CalculateValues
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:26
Default:-999.999999999
Seconds:100
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:600
Y:210
Action:S
Width:1
Name:CapturedDiscount
Label:Captured Discount
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:27
Foreign:1
Length:2
Default:D
Default:H
ChoiceDisp:0
ChoiceReplace:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:100
Y:235
Action:S
Width:1
Name:MarginCallMethod
Label:MargCallMethod
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:28
Foreign:1
Length:2
Default:N
Default:M
ChoiceDisp:0
ChoiceReplace:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:350
Y:235
Action:F
Width:11
Name:MarginCallLower
Label:MargCallLower
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:29
Default:-999.999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:600
Y:235
Action:F
Width:11
Name:MarginCallUpper
Label:MargCallUpper
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:30
Default:-999.999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:100
Y:260
Action:F
Width:16
Name:MarginCallKnockOut
Label:MargCallKO
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:31
Default:-999.99999999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:350
Y:260
Action:Y
Width:1
Name:ToBeProcessed
Label:ToBeProcessed
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:32
Foreign:1
ChoiceDisp:0
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:600
Y:260
Action:F
Width:19
Name:WeightedAmount
Label:Weighted Amount
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:33
Default:-999 999 999 999.99
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:102
Y:287
Action:F
Width:19
Name:GrossAmount1
Label:GrossAmount1
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:34
Default:-999 999 999 999.99
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:360
Y:286
Action:F
Width:16
Name:Accrued
Label:Accrued
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:36
Default:-999.99999999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:100
Y:310
Action:T
Width:3
Name:CurAccr1
Label:A1
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:37
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:200
Y:310
Action:T
Width:3
Name:CurAccr2
Label:A2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:38
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:300
Y:310
Action:T
Width:3
Name:CurGA1
Label:G1
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:39
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:400
Y:310
Action:T
Width:3
Name:CurGA2
Label:G2
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:40
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:500
Y:310
Action:T
Width:3
Name:CurWA
Label:W
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:41
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:569
Y:311
Action:T
Width:3
Name:CurFA
Label:F
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:42
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:663
Y:338
Action:I
Width:15
Name:BOReference
Label:BO Reference
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
UpperCase:0
Color2:0
CaretNumber:43
Default:-999 999 999.99
Foreign:0
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:665
Y:370
Action:I
Width:10
Name:RRPid
Label:RRPid
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:44
Default:-999999999
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:703
Y:294
Action:C
Width:1
Name:RRDFUpd
Label:RRDFUpd
SendMsg:0
Display:0
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:45
Foreign:1
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
NEXT_Input:0
X:549
Y:370
Action:F
Width:9
Name:PriceCw
Label:Price
SendMsg:0
Display:1
Sent:0
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
UpperCase:0
Color2:0
CaretNumber:46
Default:-999.9999
Foreign:0
Panel:0
Size:8
Square:0
Selector:0
PanelHeight:0
START_Square:0
START_Help:3
X:354
Y:14
Procedure4:PriceCur
Name:kplus..Currencies
Label:Price Currency
SendMsg:0
Selector:0
Length:2
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
CaretNumber:2
PersList:1
Procedure5:Currencies_Id
Default:Currencies_Id
Action:I
Width:10
Display:0
Store:1
Sent:0
Foreign:1
UpperCase:0
Seconds:9999999999
Procedure5:Currencies_ShortName
Default:Currencies_ShortName
Action:T
Width:10
Display:1
Store:0
Sent:0
Foreign:0
UpperCase:1
Panel:0
Size:8
Square:0
RiskSource:1
IndexType:I
NEXT_Help:0
X:100
Y:135
Procedure4:ClearingCpty
Name:kplus..Cpty
Label:Clearing Cpty
SendMsg:0
Selector:0
Length:2
ReadOnly:0
Mandatory:0
AlignOnBox:1
Hidden:0
CaretNumber:16
PersList:1
Procedure5:Cpty_Id
Default:Cpty_Id
Action:I
Width:10
Display:0
Store:1
Sent:0
Foreign:1
UpperCase:0
Seconds:9999999999
Procedure5:Cpty_ShortName
Default:Cpty_ShortName
Action:T
Width:10
Display:1
Store:0
Sent:0
Foreign:0
UpperCase:1
Panel:0
Size:8
Square:0
RiskSource:1
IndexType:I
NEXT_Help:0
X:16
Y:370
Procedure4:CurCw
Name:kplus..Currencies
Label:Cur
Procedure:RepoDealsProcess
SendMsg:0
Selector:0
Procedure2:CurHelp
Length:2
ReadOnly:0
Mandatory:0
AlignOnBox:0
Hidden:0
CaretNumber:47
PersList:0
Procedure5:Currencies_Id
Default:Currencies_Id
Action:I
Width:8
Display:0
Store:0
Sent:0
Foreign:0
UpperCase:0
Seconds:99999999
Procedure5:Cur
Default:Currencies_ShortName
Action:T
Width:3
Display:1
Store:0
Sent:0
Foreign:0
UpperCase:1
Panel:0
Size:8
Square:0
RiskSource:1
IndexType:I
START_List:0
START_Foreign:43
Name:RepoType
NEXT_Foreign:0
Name:DirtyPrice
NEXT_Foreign:0
Name:AccruedCash
NEXT_Foreign:0
Name:Accrued2
NEXT_Foreign:0
Name:Accrued2Cash
NEXT_Foreign:0
Name:DirtyPrice2
NEXT_Foreign:0
Name:Prepayment
NEXT_Foreign:0
Name:NeedPrepayment
NEXT_Foreign:0
Name:Discount
NEXT_Foreign:0
Name:FixedRate2
NEXT_Foreign:0
Name:ForwardPrice2
NEXT_Foreign:0
Name:FwdPriceMethod
NEXT_Foreign:0
Name:GrossAmount2
NEXT_Foreign:0
Name:ForwardAmount2
NEXT_Foreign:0
Name:DeliveryCondition1
NEXT_Foreign:0
Name:DeliveryCondition2
NEXT_Foreign:0
Name:AgreementPrepare
NEXT_Foreign:0
Name:DeliveryActive
NEXT_Foreign:0
Name:DeliveryExpensePayer
NEXT_Foreign:0
Name:SettlementDate
NEXT_Foreign:0
Name:SettlementDate2
NEXT_Foreign:0
Name:TradingPlace
NEXT_Foreign:0
Name:MarginCallTrigger
NEXT_Foreign:0
Name:Haircut2
NEXT_Foreign:0
Name:CapturedDiscount
NEXT_Foreign:0
Name:MarginCallMethod
NEXT_Foreign:0
Name:MarginCallLower
NEXT_Foreign:0
Name:MarginCallUpper
NEXT_Foreign:0
Name:MarginCallKnockOut
NEXT_Foreign:0
Name:ToBeProcessed
NEXT_Foreign:0
Name:WeightedAmount
NEXT_Foreign:0
Name:GrossAmount1
NEXT_Foreign:0
Name:Accrued
NEXT_Foreign:0
Name:CurAccr1
NEXT_Foreign:0
Name:CurAccr2
NEXT_Foreign:0
Name:CurGA1
NEXT_Foreign:0
Name:CurGA2
NEXT_Foreign:0
Name:CurWA
NEXT_Foreign:0
Name:CurFA
NEXT_Foreign:0
Name:Currencies_Id
NEXT_Foreign:0
Name:Cpty_Id
NEXT_Foreign:0
Name:RRPid
NEXT_Foreign:0
Name:RRDFUpd
START_Notify:9
Name:ValueDate
Procedure:RepoDealsProcess
NEXT_Notify:0
Name:MaturityDate
Procedure:RepoDealsProcess
NEXT_Notify:0
Name:Bonds
Procedure:RepoDealsProcess
NEXT_Notify:0
Name:FaceAmount
Procedure:RepoDealsProcess
NEXT_Notify:0
Name:Quantity
Procedure:RepoDealsProcess
NEXT_Notify:0
Name:Price
Procedure:RepoDealsProcess
NEXT_Notify:0
Name:FixedRate
Procedure:RepoDealsProcess
NEXT_Notify:0
Name:Currencies
Procedure:RepoDealsProcess
NEXT_Notify:0
Name:ConversionRate
Procedure:RepoDealsProcess
START_Proc:11
Name:Repo_SetSettlementDates
Label:SetSettlementDates
Action:D
Length:2
Default:RepoDeals-ValueDate
Default:RepoDeals-MaturityDate
NEXT_Proc:0
Name:Repo_SetHaircut
Label:SetHaircut
Action:D
Length:1
Default:Discount
NEXT_Proc:0
Name:Repo_SetDiscount
Label:SetDiscount
Action:D
Length:1
Default:Haircut2
NEXT_Proc:0
Name:RepoDealsNotify
Label:CalculateValues
Action:D
Length:23
Default:Pid
Default:Trigger
Default:RowId
Default:RepoDeals-DealType
Default:RepoSecuSched-Bonds_Id
Default:RepoSecuSched-Equities_Id
Default:RepoDeals-ValueDate
Default:SettlementDate
Default:RepoDeals-MaturityDate
Default:SettlementDate2
Default:RepoSecuSched-Price
Default:RepoSecuSched-Quantity
Default:Discount
Default:RepoDeals-FixedRate
Default:RepoDeals-Basis
Default:RepoSecuSched-IgnoreCouponPayments
Default:RepoSecuSched-ReinvCouponRate
Default:RepoSecuSched-ConversionRate
Default:NeedPrepayment
Default:FwdPriceMethod
Default:Haircut2
Default:CapturedDiscount
Default:RepoDeals-Currencies_Id
NEXT_Proc:0
Name:Repo_CleanAll
Label:CleanAll
Action:D
NEXT_Proc:0
Name:Repo_LoadDea
Label:LoadDeal
Action:D
Length:1
Default:DealNr
NEXT_Proc:0
Name:Repo_StoreDealData
Label:StoreDealData
Action:D
Length:44
Default:Pid
Default:Trigger
Default:RowId
Default:RepoDeals-TradeDate
Default:RepoDeals-ValueDate
Default:SettlementDate
Default:RepoDeals-MaturityDate
Default:SettlementDate2
Default:RepoDeals-Folders_Id
Default:RepoDeals-Cpty_Id
Default:RepoDeals-Currencies_Id
Default:Currencies_Id
Default:RepoDeals-DealType
Default:RepoType
Default:RepoDeals-TypeOfInstr_Id
Default:RepoSecuSched-Bonds_Id
Default:RepoSecuSched-ClearingModes_Id
Default:TradingPlace
Default:FwdPriceMethod
Default:RepoSecuSched-FaceAmount
Default:RepoSecuSched-Quantity
Default:RepoSecuSched-IgnoreCouponPayments
Default:Discount
Default:Haircut2
Default:RepoDeals-FixedRate
Default:RepoDeals-ClientMargin
Default:RepoDeals-Basis
Default:RepoSecuSched-Price
Default:Accrued
Default:DirtyPrice
Default:AccruedCash
Default:GrossAmount1
Default:WeightedAmount
Default:ForwardPrice2
Default:Accrued2
Default:DirtyPrice2
Default:Accrued2Cash
Default:GrossAmount2
Default:ForwardAmount2
Default:DeliveryCondition1
Default:DeliveryCondition2
Default:RepoSecuSched-ConversionRate
Default:NeedPrepayment
Default:Prepayment
NEXT_Proc:0
Name:RepoSetFixedRate
Label:SetRate
Action:D
Length:1
Default:FixedRate2
NEXT_Proc:0
Name:RUKON_GetSecDetails
Label:GetSecurityDetails
Action:H
Length:1
Default:RepoDeals-KdbTables_Id_Underlying
NEXT_Proc:0
Name:RUKON_RepoDealsProcess
Label:RepoDealsProcess
Action:D
Length:23
Default:Pid
Default:Trigger
Default:RowId
Default:RepoDeals-DealType
Default:RepoSecuSched-Bonds_Id
Default:RepoSecuSched-Equities_Id
Default:RepoDeals-ValueDate
Default:SettlementDate
Default:RepoDeals-MaturityDate
Default:SettlementDate2
Default:RepoSecuSched-Price
Default:RepoSecuSched-Quantity
Default:Discount
Default:RepoDeals-FixedRate
Default:RepoDeals-Basis
Default:RepoSecuSched-IgnoreCouponPayments
Default:RepoSecuSched-ReinvCouponRate
Default:RepoSecuSched-ConversionRate
Default:NeedPrepayment
Default:FwdPriceMethod
Default:Haircut2
Default:CapturedDiscount
Default:RepoDeals-Currencies_Id
NEXT_Proc:0
Name:RUKON_CurHelp
Label:CurHelp
Action:H
Length:1
Default:RowId
', DEFAULT)


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
WHERE  T.KdbTables_Name    = 'RUKON_RepoDeals' 
AND    T.KdbDatabases_Id   = @KdbDatabases_Id_Kustom 


IF @@rowcount = 0
BEGIN
	SELECT @KdbTables_Id_Kustom = ISNULL(MAX(T.KdbTables_Id) + 1, 10000) 
	FROM kplus..KdbTables T
	WHERE T.KdbTables_Id >= 10000
	AND T.KdbTables_Id < 20000
	IF @KdbTables_Id_Kustom >= 20000
	BEGIN
		RAISERROR 30000 'You have too many kustom local databases (limited to 10000). Cannot proceed...'
	END
END

DELETE kplus..KdbLocalFieldsT  
WHERE KdbLocalTables_Id = @KdbTables_Id_Kustom 

DELETE kplus..KdbLocalTablesT  
WHERE KdbLocalTables_Id = @KdbTables_Id_Kustom 

INSERT kplus..KdbLocalTablesT Values (
@KdbTables_Id_Kustom, 'RUKON_RepoDeals', 'RUKON_RepoDeals',  @KdbDatabases_Id_Kustom,  0,  45, 'Q', 'D', 'FOREIGN',  0,  39,  0,  0, 'R', 'N', 'N', 'N', 'R', 'FOREIGN', 'N', 'N', 'N', 'Y',  0,   0,  'N',  2  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 0, 'DealType',  'DealType',  0,  4,  0,  0, 32,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 1, 'DealId',  'DealId',  0,  1,  0,  0,  5,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N', '999 999 999',  NULL  )
DECLARE @KdbTables_Id_Version int 

SELECT @KdbTables_Id_Version = T.KdbTables_Id 
FROM   kplus..KdbTables T 
WHERE  T.KdbTables_Name    = 'KustomRUKON_RepoDealsVer' 
AND    T.KdbDatabases_Id   = @KdbDatabases_Id_Version 


IF @@rowcount = 0
BEGIN
	SELECT @KdbTables_Id_Version = ISNULL(MAX(T.KdbTables_Id) + 1, 10000) 
	FROM kplus..KdbTables T
	WHERE T.KdbTables_Id >= 10000
	AND T.KdbTables_Id < 20000
	IF @KdbTables_Id_Version >= 20000
	BEGIN
		RAISERROR 30000 'You have too many kustom local databases (limited to 10000). Cannot proceed...'
	END
END

DELETE kplus..KdbLocalFieldsT  
WHERE KdbLocalTables_Id = @KdbTables_Id_Version 

DELETE kplus..KdbLocalTablesT  
WHERE KdbLocalTables_Id = @KdbTables_Id_Version 

INSERT kplus..KdbLocalTablesT Values (
@KdbTables_Id_Version, 'KustomRUKON_RepoDealsVer', 'RUKON_RepoDealsVer Kustom',  @KdbDatabases_Id_Version,  0,  48, 'O', 'D', 'FOREIGN',  0,  39,  0,  0, 'R', 'N', 'N', 'N', 'R', 'FOREIGN', 'N', 'N', 'N', 'Y',  0,   0,  'N',  2  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 0, 'TransactionId',  'Transaction Id',  0,  1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 1, 'DealType',  'DealType',  0,  4,  0,  0,  32,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 2, 'DealId',  'DealId',  0,  1,  0,  0,  5,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N', '999 999 999',  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 46, 'VersionStartDate',  'Version Start Date',  0,  8,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 47, 'VersionEndDate',  'Version End Date',  0,  8,  0,  0,  32,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  NULL  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 2, 'RepoType',  'RepoType',  0,  4,  0,  0,  7,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field RepoType'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 3, 'RepoType',  'RepoType',  0,  4,  0,  0,  7,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field RepoType'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 3, 'DirtyPrice',  'DirtyPrice',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field DirtyPrice'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 4, 'DirtyPrice',  'DirtyPrice',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field DirtyPrice'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 4, 'AccruedCash',  'AccruedCash',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999.99',  'TradeKast field AccruedCash'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 5, 'AccruedCash',  'AccruedCash',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999.99',  'TradeKast field AccruedCash'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 5, 'Accrued2',  'Accrued2',  0,  9,  0,  0,  16,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.99999999999',  'TradeKast field Accrued2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 6, 'Accrued2',  'Accrued2',  0,  9,  0,  0,  16,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.99999999999',  'TradeKast field Accrued2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 6, 'Accrued2Cash',  'Accrued2Cash',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999.99',  'TradeKast field Accrued2Cash'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 7, 'Accrued2Cash',  'Accrued2Cash',  0,  9,  0,  0,  15,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999.99',  'TradeKast field Accrued2Cash'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 7, 'DirtyPrice2',  'DirtyPrice2',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field DirtyPrice2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 8, 'DirtyPrice2',  'DirtyPrice2',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field DirtyPrice2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 8, 'Prepayment',  'Prepayment',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field Prepayment'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 9, 'Prepayment',  'Prepayment',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field Prepayment'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 9, 'NeedPrepayment',  'NeedPrepayment',  0,  6,  0,  1,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field NeedPrepayment'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 10, 'NeedPrepayment',  'NeedPrepayment',  0,  6,  0,  1,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field NeedPrepayment'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 10, 'Discount',  'Discount',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field Discount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 11, 'Discount',  'Discount',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field Discount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 11, 'FixedRate2',  'FixedRate2',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field FixedRate2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 12, 'FixedRate2',  'FixedRate2',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field FixedRate2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 12, 'ForwardPrice2',  'ForwardPrice2',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field ForwardPrice2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 13, 'ForwardPrice2',  'ForwardPrice2',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field ForwardPrice2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 13, 'FwdPriceMethod',  'FwdPriceMethod',  0,  4,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field FwdPriceMethod'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 14, 'FwdPriceMethod',  'FwdPriceMethod',  0,  4,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field FwdPriceMethod'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 14, 'GrossAmount2',  'GrossAmount2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field GrossAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 15, 'GrossAmount2',  'GrossAmount2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field GrossAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 15, 'ForwardAmount2',  'ForwardAmount2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field ForwardAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 16, 'ForwardAmount2',  'ForwardAmount2',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field ForwardAmount2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 16, 'DeliveryCondition1',  'DeliveryCondition1',  0,  4,  0,  0,  9,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryCondition1'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 17, 'DeliveryCondition1',  'DeliveryCondition1',  0,  4,  0,  0,  9,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryCondition1'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 17, 'DeliveryCondition2',  'DeliveryCondition2',  0,  4,  0,  0,  9,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryCondition2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 18, 'DeliveryCondition2',  'DeliveryCondition2',  0,  4,  0,  0,  9,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryCondition2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 18, 'AgreementPrepare',  'AgreementPrepare',  0,  4,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field AgreementPrepare'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 19, 'AgreementPrepare',  'AgreementPrepare',  0,  4,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field AgreementPrepare'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 19, 'DeliveryActive',  'DeliveryActive',  0,  4,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryActive'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 20, 'DeliveryActive',  'DeliveryActive',  0,  4,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryActive'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 20, 'DeliveryExpensePayer',  'DeliveryExpensePayer',  0,  4,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryExpensePayer'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 21, 'DeliveryExpensePayer',  'DeliveryExpensePayer',  0,  4,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field DeliveryExpensePayer'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 21, 'SettlementDate',  'SettlementDate',  0,  7,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field SettlementDate'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 22, 'SettlementDate',  'SettlementDate',  0,  7,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field SettlementDate'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 22, 'SettlementDate2',  'SettlementDate2',  0,  7,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field SettlementDate2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 23, 'SettlementDate2',  'SettlementDate2',  0,  7,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field SettlementDate2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 23, 'TradingPlace',  'TradingPlace',  0,  4,  0,  0,  4,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field TradingPlace'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 24, 'TradingPlace',  'TradingPlace',  0,  4,  0,  0,  4,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field TradingPlace'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 24, 'MarginCallTrigger',  'MarginCallTrigger',  0,  9,  0,  0,  11,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999',  'TradeKast field MarginCallTrigger'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 25, 'MarginCallTrigger',  'MarginCallTrigger',  0,  9,  0,  0,  11,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999',  'TradeKast field MarginCallTrigger'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 25, 'Haircut2',  'Haircut2',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field Haircut2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 26, 'Haircut2',  'Haircut2',  0,  9,  0,  0,  14,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999999',  'TradeKast field Haircut2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 26, 'CapturedDiscount',  'CapturedDiscount',  0,  4,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CapturedDiscount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 27, 'CapturedDiscount',  'CapturedDiscount',  0,  4,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CapturedDiscount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 27, 'MarginCallMethod',  'MarginCallMethod',  0,  4,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field MarginCallMethod'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 28, 'MarginCallMethod',  'MarginCallMethod',  0,  4,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field MarginCallMethod'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 28, 'MarginCallLower',  'MarginCallLower',  0,  9,  0,  0,  11,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999',  'TradeKast field MarginCallLower'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 29, 'MarginCallLower',  'MarginCallLower',  0,  9,  0,  0,  11,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999',  'TradeKast field MarginCallLower'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 29, 'MarginCallUpper',  'MarginCallUpper',  0,  9,  0,  0,  11,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999',  'TradeKast field MarginCallUpper'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 30, 'MarginCallUpper',  'MarginCallUpper',  0,  9,  0,  0,  11,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.999999',  'TradeKast field MarginCallUpper'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 30, 'MarginCallKnockOut',  'MarginCallKnockOut',  0,  9,  0,  0,  16,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.99999999999',  'TradeKast field MarginCallKnockOut'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 31, 'MarginCallKnockOut',  'MarginCallKnockOut',  0,  9,  0,  0,  16,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.99999999999',  'TradeKast field MarginCallKnockOut'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 31, 'ToBeProcessed',  'ToBeProcessed',  0,  6,  0,  1,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field ToBeProcessed'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 32, 'ToBeProcessed',  'ToBeProcessed',  0,  6,  0,  1,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field ToBeProcessed'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 32, 'WeightedAmount',  'WeightedAmount',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field WeightedAmount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 33, 'WeightedAmount',  'WeightedAmount',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field WeightedAmount'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 33, 'GrossAmount1',  'GrossAmount1',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field GrossAmount1'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 34, 'GrossAmount1',  'GrossAmount1',  0,  9,  0,  0,  19,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999 999 999 999.99',  'TradeKast field GrossAmount1'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 34, 'Accrued',  'Accrued',  0,  9,  0,  0,  16,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.99999999999',  'TradeKast field Accrued'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 35, 'Accrued',  'Accrued',  0,  9,  0,  0,  16,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999.99999999999',  'TradeKast field Accrued'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 35, 'CurAccr1',  'CurAccr1',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurAccr1'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 36, 'CurAccr1',  'CurAccr1',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurAccr1'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 36, 'CurAccr2',  'CurAccr2',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurAccr2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 37, 'CurAccr2',  'CurAccr2',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurAccr2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 37, 'CurGA1',  'CurGA1',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurGA1'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 38, 'CurGA1',  'CurGA1',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurGA1'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 38, 'CurGA2',  'CurGA2',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurGA2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 39, 'CurGA2',  'CurGA2',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurGA2'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 39, 'CurWA',  'CurWA',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurWA'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 40, 'CurWA',  'CurWA',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurWA'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 40, 'CurFA',  'CurFA',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurFA'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 41, 'CurFA',  'CurFA',  0,  4,  0,  0,  3,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field CurFA'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 41, 'Currencies_Id',  'Currencies_Id',  0,  10,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '9999999999',  'TradeKast field Currencies_Id'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 42, 'Currencies_Id',  'Currencies_Id',  0,  10,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '9999999999',  'TradeKast field Currencies_Id'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 42, 'Cpty_Id',  'Cpty_Id',  0,  10,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '9999999999',  'TradeKast field Cpty_Id'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 43, 'Cpty_Id',  'Cpty_Id',  0,  10,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '9999999999',  'TradeKast field Cpty_Id'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 43, 'RRPid',  'RRPid',  0,  10,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999999999',  'TradeKast field RRPid'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 44, 'RRPid',  'RRPid',  0,  10,  0,  0,  10,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  '-999999999',  'TradeKast field RRPid'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Kustom, 44, 'RRDFUpd',  'RRDFUpd',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field RRDFUpd'  )
INSERT kplus..KdbLocalFieldsT VALUES (
 @KdbTables_Id_Version, 45, 'RRDFUpd',  'RRDFUpd',  0,  5,  0,  0,  1,  0,  0,  0,  0,  0,  0,  1,  1,  0,  2,  1, 'N',  NULL,  'TradeKast field RRDFUpd'  )

COMMIT TRAN
go

