USE Kustom
go
IF OBJECT_ID('dbo.RTR_Bonds_Micex_YTM_or_Offer') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.RTR_Bonds_Micex_YTM_or_Offer
    IF OBJECT_ID('dbo.RTR_Bonds_Micex_YTM_or_Offer') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.RTR_Bonds_Micex_YTM_or_Offer >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.RTR_Bonds_Micex_YTM_or_Offer >>>'
END
go
-- version: __VERSION
-- date: '__DATE_VSS' 
create procedure dbo.RTR_Bonds_Micex_YTM_or_Offer
   (
   @Bonds_Id         int,
   @Price            float,
   @Date             datetime,
   @AccruedAmount    float,
   @ApproximateYield float output
   )
as
declare
   @CurrentBondsPrice   float,
   @CurrentNominal      float,
   @OfferDate           datetime,
   @CalcDate            datetime,
   @RedemptionValue     float,
   @A                   float,
   @Y1                  float,
   @Y2                  float,
   @Y                   float
begin


   select @CalcDate = isnull(@Date, getdate())

   /*                         */
   /*  The checking section   */
   /*                         */

   if (select count(*) from kplus..Bonds where Bonds_Id = @Bonds_Id) = 0
      return

--   if (select count(*) from kplus..BondsSchedule where Bonds_Id = @Bonds_Id AND EndDate > @CalcDate AND CashFlowType="I") = 0
--   begin
--      select @ApproximateYield = 0
--      return
--   end

--   if (select MarketPrice from kplus..BondsRTT where Bonds_Id = @Bonds_Id) = 0
--   begin
--      select @ApproximateYield = 0
--      return
--   end

--   if (select max(substring(Method,1,1)) from Kustom..RTR_CW_BondsCouponParam where DealId = @Bonds_Id) != 'C'
--      return

   /*                          */
   /*   Main body of script    */
   /*                          */
   select @CurrentNominal = (select b.FaceValue from kplus..Bonds b where b.Bonds_Id = @Bonds_Id)
                            -
                            (select isnull(sum(s.CashFlow),0) from kplus..BondsSchedule s
                              where s.Bonds_Id = @Bonds_Id and s.CashFlowType = 'N' and s.PaymentDate <= @CalcDate)

   if (select IsCallPutable from kplus..Bonds where Bonds_Id = @Bonds_Id) != 'N'
      select @OfferDate = EndDate, @RedemptionValue = RedemptionValue
        from kplus..BondsCallPut
       where Bonds_Id = @Bonds_Id
         and EndDate = (select min(EndDate) from kplus..BondsCallPut where Bonds_Id = @Bonds_Id and EndDate > @CalcDate)

   if @OfferDate is null
      select @OfferDate = max(EndDate), @RedemptionValue = 0
        from kplus..BondsSchedule
       where Bonds_Id = @Bonds_Id
         and EndDate > @CalcDate
         and CashFlowType = 'N'

   select @CurrentBondsPrice = isnull(@Price, b.MarketPrice) / 100 * @CurrentNominal
                             + isnull(@AccruedAmount, round(b.Accrued,3) / 100 * @CurrentNominal)
     from kplus..BondsRTT b
    where b.Bonds_Id = @Bonds_Id

   select @Y1 = -99.99, @Y2 = 100000, @A = 0

   while abs(@A - @CurrentBondsPrice) > 0.00000001 and abs(@Y1 - @Y2) > 0.0000001
   begin
      select @Y = (@Y1 + @Y2) / 2

      select @A = sum(CashFlow/power((1 + @Y/100), datediff(day,@CalcDate,EndDate)/365.0))
        from kplus..BondsSchedule
       where Bonds_Id = @Bonds_Id and CashFlowType in ('I', 'N')
         and EndDate > @CalcDate and EndDate <= @OfferDate

      select @A = isnull(@A,0) + @RedemptionValue/power((1 + @Y/100), datediff(day,@CalcDate, @OfferDate)/365.0)

      if @A > @CurrentBondsPrice
         select @Y1 = @Y
      else
         select @Y2 = @Y
   end

   select @ApproximateYield = @Y
end
go
EXEC sp_procxmode 'dbo.RTR_Bonds_Micex_YTM_or_Offer', 'unchained'
go
IF OBJECT_ID('dbo.RTR_Bonds_Micex_YTM_or_Offer') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.RTR_Bonds_Micex_YTM_or_Offer >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.RTR_Bonds_Micex_YTM_or_Offer >>>'
go
REVOKE EXECUTE ON dbo.RTR_Bonds_Micex_YTM_or_Offer FROM public
go
GRANT EXECUTE ON dbo.RTR_Bonds_Micex_YTM_or_Offer TO public
go
