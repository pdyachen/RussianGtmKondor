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