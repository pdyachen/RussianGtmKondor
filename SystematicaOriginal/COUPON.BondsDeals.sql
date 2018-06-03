/*-------------------------------------------------*/
/*--- Initialization Part -------------------------*/
/*-------------------------------------------------*/

USE kplus
go

/*-------------------------------------------------*/
/*--- Boxes export --------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		COUPON.BondsDeals
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


SELECT @KdbTables_Id_ETOD = 97 
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


INSERT kplus..CustomWindow VALUES ( @Codifiers_Id, @ETOD_Id, 'N', 'N', 'Kustom', 
'NEXT_Client:0
Name:COUPON
Action:@KdbTables_Id_ETOD
TOD_origin:N
Scrollbars:0
Width:483
Height:1
ViewableWidth:535
ViewableHeight:126
Store:1
SendMsg:1
Seconds:0
Prolong:0
ReadOnly:1
Mandatory:0
Color1:0
Color2:0
Color3:0
Display:0
NewHelpNaming:0
Size:0
ShareData:0
START_Inquiry:0
START_Input:0
START_Square:0
START_Help:0
START_List:0
START_Foreign:0
START_Notify:13
Name:Bonds
Procedure:Notification
NEXT_Notify:0
Name:SettlementDate
Procedure:Notification
NEXT_Notify:0
Name:FaceAmount
Procedure:Notification
NEXT_Notify:0
Name:Quantity
Procedure:Notification
NEXT_Notify:0
Name:Price
Procedure:Notification
NEXT_Notify:0
Name:Yield
Procedure:Notification
NEXT_Notify:0
Name:GrossBrokerage
Procedure:Notification
NEXT_Notify:0
Name:Vat
Procedure:Notification
NEXT_Notify:0
Name:BrokerageDiscount
Procedure:Notification
NEXT_Notify:0
Name:BrokerageRate
Procedure:Notification
NEXT_Notify:0
Name:DealType
Procedure:Notification
NEXT_Notify:0
Name:ValueDate
Procedure:Notification
NEXT_Notify:0
Name:TradeDate
Procedure:Notification
START_Proc:1
Name:RTR_CW_Notify_BondsDeals
Label:Notification
Action:D
Length:7
Default:BondsDeals-Bonds_Id
Default:BondsDeals-Quantity
Default:BondsDeals-Price
Default:BondsDeals-SettlementDate
Default:BondsDeals-DealType
Default:BondsDeals-NetBrokerage
Default:BondsDeals-Vat
')


go

/*-------------------------------------------------*/
/*--- Procs export --------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		RTR_CW_Notify_BondsDeals
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RTR_CW_Notify_BondsDeals' AND type = 'P' 
)
	DROP PROC RTR_CW_Notify_BondsDeals 
go


create procedure dbo.RTR_CW_Notify_BondsDeals
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyrights REUTERS                                                                                 */
/*                                                                                                      */
/* . Author: Evgeny Bugaev                                                                              */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
@Bonds_Id                   integer,
@Quantity                   float,
@Price                      float,
@SettlementDate             datetime,
@BuySell                    char = 'B',
@NetBrokerage               float = null,
@Vat                        float = null
)
as
declare
   @AccruedInterestAmount      float,
   @AccruedInterestPercent     float,
   @Principal                  float,
   @Yield                      float
begin
   -- Р Р†РЎвЂ№РЎвЂЎР С'РЎРѓР В»РЎРЏР ВµР С Р Р…Р С•Р Р†РЎС"РЎР‹ РЎРѓРЎС"Р СР СРЎС" Р С"РЎС"Р С—Р С•Р Р…Р В°
   exec RTR_BondsDealsAccrued @Bonds_Id, @Quantity, @SettlementDate, @AccruedInterestAmount output, @AccruedInterestPercent output

   if @AccruedInterestAmount is null
      return -- Р ВµРЎРѓР В»Р С' Р Р…Р С'РЎвЂЎР ВµР С–Р С• Р Р…Р Вµ Р С—Р С•РЎРѓРЎвЂЎР С'РЎвЂљР В°Р В»Р С•РЎРѓРЎРЉ, РЎвЂљР С• Р Р…Р С'РЎвЂЎР ВµР С–Р С• Р С' Р Р…Р Вµ Р Т'Р ВµР В»Р В°Р ВµР С

   -- Р С—Р С•Р С"Р В° Р Р…Р Вµ РЎвЂЎР С'РЎвЂљР В°Р ВµР С РЎРѓР С—Р С•РЎРѓР С•Р В± Р В·Р В°Р Т'Р В°Р Р…Р С'РЎРЏ РЎвЂ Р ВµР Р…РЎвЂ№. Р С—Р С•Р Т'Р Т'Р ВµРЎР‚Р В¶Р С'Р Р†Р В°Р ВµР С РЎвЂљР С•Р В»РЎРЉР С"Р С• Р С"Р С•РЎвЂљР С'РЎР‚Р С•Р Р†Р В°Р Р…Р С'Р Вµ Р Р† % Р С" Р Р…Р С•Р СР С'Р Р…Р В°Р В»РЎС"
   -- Р В§Р С'РЎвЂљР В°Р ВµР С Р Р…Р С•Р СР С'Р Р…Р В°Р В» Р В±РЎС"Р СР В°Р С–Р С'
   select @Principal = (select b.FaceValue from kplus.dbo.Bonds b where b.Bonds_Id = @Bonds_Id)
                       -
                       (select isnull(sum(s.CashFlow),0) from kplus.dbo.BondsSchedule s
                         where s.Bonds_Id = @Bonds_Id and s.CashFlowType = 'N' and s.PaymentDate <= @SettlementDate)

   select GrossAmount = @Quantity*@Price/100*@Principal+@AccruedInterestAmount,
          Accrued = @AccruedInterestPercent,
          AccruedAmount = @AccruedInterestAmount

   if @NetBrokerage is not null
   begin
      select NetAmount = @Quantity*@Price/100*@Principal+@AccruedInterestAmount +
                         (case @BuySell when 'B' then +1 else -1 end) * (@NetBrokerage + isnull(@Vat,0))
   end

   select @AccruedInterestAmount = @AccruedInterestAmount / @Quantity

   -- Р СџР ВµРЎР‚Р ВµРЎРѓРЎвЂЎР С'РЎвЂљРЎвЂ№Р Р†Р В°Р ВµР С YieldToMaturity
   exec RTR_Bonds_Micex_YTM_or_Offer @Bonds_Id, @Price, @SettlementDate, @AccruedInterestAmount, @Yield output


   if @Yield is not null
      select Yield = @Yield

end

go



GRANT EXEC ON RTR_CW_Notify_BondsDeals TO PUBLIC 
go

