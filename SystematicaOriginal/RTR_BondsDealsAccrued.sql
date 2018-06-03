Use Kustom
GO

create procedure dbo.RTR_BondsDealsAccrued						
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
@CalcDate                   datetime,						
@AccruedInterestAmount      float output,						
@AccruedInterestPercent     float output						
)						
as						
declare						
   @AC_Method           varchar(20),						
   @Principal           float,						
   @Basis               char(1),						
   @CouponRoundingConv  integer,						
   @CouponRoundingType  char(1),						
   @CouponStartDate     datetime,						
   @CouponEndDate       datetime,						
   @CouponRate          float,						
   @CouponCashFlow      float,						
   @YF                  float,						
   @CouponFrequency     char(1),						
   @MaturityDate        datetime						
begin						
						
   if @Quantity is null or @Quantity = 0						
   begin						
      select @AccruedInterestAmount = null,						
             @AccruedInterestPercent = null						
      return						
   end						
						
   -- Р В РІР‚СњР В РЎвЂўР РЋР С“Р РЋРІР‚С™Р В Р’В°Р В Р’ВµР В РЎВ Р РЋР С“Р В РЎвЂ”Р В РЎвЂўР РЋР С“Р В РЎвЂўР В Р’В± Р РЋР вЂљР В Р’В°Р РЋР С“Р РЋРІР‚РЋР В Р’ВµР РЋРІР‚С™Р В Р’В° Р В РЎСљР В РЎв„ўР В РІР‚Сњ Р В РЎвЂ”Р В РЎвЂў Р В РЎвЂўР В Р’В±Р В Р’В»Р В РЎ'Р В РЎвЂ“Р В Р’В°Р РЋРІР‚В Р В РЎ'Р РЋР РЏР В РЎВ						
   select @AC_Method = substring(Method,1,1) from RTR_CW_BondsCouponParam						
   where  DealId = @Bonds_Id and DealType = 'Bonds'						
						
   -- Р В Р’В§Р В РЎ'Р РЋРІР‚С™Р В Р’В°Р В Р’ВµР В РЎВ Р В РЎвЂ”Р В Р’В°Р РЋР вЂљР В Р’В°Р В РЎВР В Р’ВµР РЋРІР‚С™Р РЋР вЂљР РЋРІР‚в„– Р В Р’В±Р РЋРЎ"Р В РЎВР В Р’В°Р В РЎвЂ“Р В РЎ'						
   select @CouponRoundingConv = CouponRoundingConv,						
          @CouponRoundingType = CouponRoundingType,						
          @CouponFrequency = CouponFrequency,						
          @MaturityDate = MaturityDate						
     from kplus.dbo.Bonds						
    where Bonds_Id = @Bonds_Id 						
   						
   if @MaturityDate <= @CalcDate						
   begin						
   	select @AccruedInterestAmount = 0,					
             @AccruedInterestPercent = 0						
      return        						
   end						
   						
   select @Principal = Principal, -- Р В РЎСљР В РЎвЂўР В РЎВР В РЎ'Р В Р вЂ¦Р В Р’В°Р В Р’В»						
          @Basis = AccruedBasis,  -- Р В РІР‚ВР В Р’В°Р В Р’В·Р В РЎ'Р РЋР С“ Р В Р вЂ¦Р В Р’В°Р РЋРІР‚РЋР В РЎ'Р РЋР С“Р В Р’В»Р В Р’ВµР В Р вЂ¦Р В РЎ'						
          @CouponCashFlow = CashFlow, -- Р В Р Р‹Р РЋРЎ"Р В РЎВР В РЎВР В Р’В° Р В РЎ"Р РЋРЎ"Р В РЎвЂ”Р В РЎвЂўР В Р вЂ¦Р В Р’В°						
          @CouponStartDate = StartDate,						
          @CouponEndDate = EndDate,						
          @CouponRate = Rate						
     from kplus.dbo.BondsSchedule						
    where Bonds_Id = @Bonds_Id						
      and StartDate <= @CalcDate						
      and EndDate > @CalcDate						
      						
    						
						
   -- Р В Р’ВµР РЋР С“Р В Р’В»Р В РЎ' Р В Р вЂ¦Р В РЎвЂўР В РЎВР В РЎ'Р В Р вЂ¦Р В Р’В°Р В Р’В» Р В Р вЂ¦Р В Р’Вµ Р В Р’В·Р В Р’В°Р В Рў'Р В Р’В°Р В Р вЂ¦, Р РЋРІР‚С™Р В РЎвЂў Р В Р вЂ¦Р В РЎ'Р РЋРІР‚РЋР В Р’ВµР В РЎвЂ“Р В РЎвЂў Р В Р вЂ¦Р В Р’Вµ Р РЋР С“Р РЋРІР‚РЋР В РЎ'Р РЋРІР‚С™Р В Р’В°Р В Р’ВµР В РЎВ						
   if isnull(@Principal,0) = 0						
   begin						
      select @AccruedInterestAmount = null						
      select @AccruedInterestPercent = null						
      return						
   end						
						
   						
						
   exec PYearFractionSimple @CouponStartDate, @CalcDate, @Basis, @CouponFrequency,  @YF output						
						
   -- GlobalNominal						
   if (@AC_Method = 'G' or @AC_Method is null) and @CouponRoundingType = 'R'						
   begin						
      select @AccruedInterestPercent = round(@CouponRate*@YF, @CouponRoundingConv)						
      select @AccruedInterestAmount = @Quantity * @Principal * @AccruedInterestPercent/100						
   end						
						
   else if (@AC_Method = 'G' or @AC_Method is null) and @CouponRoundingType = 'T'						
   begin						
      select @AccruedInterestPercent = floor(@CouponRate*@YF*power(10,@CouponRoundingConv))/power(10,@CouponRoundingConv)						
      select @AccruedInterestAmount = @Quantity * @Principal * @AccruedInterestPercent/100						
   end						
						
   -- Unit coupon						
   else if @AC_Method = 'C' and @CouponRoundingType = 'R'						
   begin						
      select @AccruedInterestAmount = @Quantity * round(@Principal * @CouponRate/100 * @YF, 2)						
      select @AccruedInterestPercent = round(100*@AccruedInterestAmount/@Quantity/@Principal, @CouponRoundingConv)						
   end						
						
   else if @AC_Method = 'C' and @CouponRoundingType = 'T'						
   begin						
      select @AccruedInterestAmount = @Quantity * round(@Principal * @CouponRate/100 * @YF, 2)						
      select @AccruedInterestPercent = floor(100*@AccruedInterestAmount/@Quantity/@Principal*power(10,@CouponRoundingConv))/power(10,@CouponRoundingConv)						
   end						
						
   -- Unit percentage						
   else if @AC_Method = 'P' and @CouponRoundingType = 'R'						
   begin						
      select @AccruedInterestPercent = round(@CouponCashFlow/@Principal*datediff(dd,@CouponStartDate,@CalcDate)/						
                                             datediff(dd,@CouponStartDate,@CouponEndDate)*100, @CouponRoundingConv)						
      select @AccruedInterestAmount = @Quantity * @AccruedInterestPercent/100 * @Principal						
   end						
						
   else if @AC_Method = 'P' and @CouponRoundingType = 'T'						
   begin						
      select @AccruedInterestPercent = floor(@CouponCashFlow/@Principal*datediff(dd,@CouponStartDate,@CalcDate)/						
                                             datediff(dd,@CouponStartDate,@CouponEndDate)*power(10,@CouponRoundingConv)*100)						
                                             /power(10,@CouponRoundingConv)						
      select @AccruedInterestAmount = @Quantity * @AccruedInterestPercent/100 * @Principal						
   end						
						
   -- Russian goverment bonds						
   else if @AC_Method = 'M' and @CouponRoundingType = 'R'						
   begin						
      select @AccruedInterestAmount = round(@CouponCashFlow*datediff(dd,@CouponStartDate,@CalcDate)/						
                                             datediff(dd,@CouponStartDate,@CouponEndDate), 2) * @Quantity						
      select @AccruedInterestPercent = round(@AccruedInterestAmount / @Quantity / @Principal * 100, @CouponRoundingConv)						
   end						
						
						
end						
						
GO						
