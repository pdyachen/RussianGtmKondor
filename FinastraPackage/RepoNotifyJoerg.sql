USE Kustom
go
IF OBJECT_ID('dbo.RepoDealsNotify') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.RepoDealsNotify
    IF OBJECT_ID('dbo.RepoDealsNotify') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.RepoDealsNotify >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.RepoDealsNotify >>>'
END
go
CREATE PROC RepoDealsNotify

													
(													
  --  @Deals_Id                              int,													
   @DealType                              char(1),													
  -- @RepoType                              char(1),													
   @Bonds_Id                              int,													
--   @Equities_Id                           int,													
--   @Cpty_Id                               int,													
 --  @TradeDate                             datetime,													
   @ValueDate                             datetime,													
   @SettlementDate                        datetime,													
   @MaturityDate                          datetime,													
   @SettlementDate2                       datetime,													
   @Price                                 float,													
--   @Accrued                               float,													
--   @Accrued2                              float,													
   @Quantity                              float,													
   @Discount                              float,													
   @FixedRate                             float,													
   @Basis                                 char(1),													
   @IgnoreCouponPayments                  char(1),													
   @ReinvCouponRate                       float,													
--   @Currencies_Id                         int,													
--   @Currencies_Id_Price                   int,													
   @ConversionRate                        float,													
--   @ClearingModes_Id                      int,													
  -- @ClearingModes_Id_Cpty                 int,													
  @NeedPrepayment                        char(1),													
   @FwdPriceMethod                        char(1),													
 --  @TriggeredField                        varchar(32),													
   @Haircut                               float,													
   @CapturedDiscount                      char(1)  ,
   @Cur int 												
)													
as													
declare													
   @Principal1                  float,													
   @Principal2                  float,													
   @outAccrued                  float,													
   @outGrossAmount              float,													
   @outDirtyPrice               float,													
   @outAccruedAmount            float,													
   @outAccrued2                 float,													
   @outAccruedAmount2           float,													
   @outDirtyPrice2              float,													
   @outGrossAmount2             float,													
   @YF                          float,													
   @YF_cf                       float,	
   @YF_Help float,												
   @outForwardAmount            float,													
   @outWeightedAmount           float,													
   @outForwardPrice             float,													
   @CashFlow                    float,													
   @AC_Method                   char(1),													
   @CashFlowType                char(1),													
   @CashFlowDate                datetime,													
   @DownloadKey                 varchar(30),													
   @PrincipalCashFlow           float,													
   @Rate                        float,													
   @Mult                        float	,
   @Currencies_Id int,
  @Currencies_ShortName varchar(3)	



-- RETURN

        select @AC_Method = "G"
-- SElect @ConversionRate = 1.00

IF (@CapturedDiscount = "H")
BEGIN

SELECT Discount = 0.00
IF (@Haircut != 0.00)
SELECT Discount = 100.00 - (10000.00 / @Haircut )

END

IF (@CapturedDiscount = "D")
BEGIN

SELECT Haircut2 = 100.00
IF (@Discount != 100)
SELECT Haircut2 = 10000.00 / (100.00 - @Discount)


END




Declare @Message varchar(200)
SELECT @Message = convert(varchar(20), @FixedRate) 

/* + "#" + @DealType + "#" + convert(varchar(20), @Quantity) + "#" + convert(varchar(20), @ConversionRate) + "#" +  @FwdPriceMethod
*/

 -- exec kplus..SendMail "KPLUS", "KPLUS", @Message



--  RETURN

IF (@ValueDate = NULL)
RETURN


IF (@SettlementDate = NULL)
BEGIN
SELECT @SettlementDate = @ValueDate
SELECT SettlementDate = @ValueDate
END

IF (@MaturityDate = NULL)
RETURN


IF (@SettlementDate2 = NULL)
BEGIN
SELECT @SettlementDate2 = @MaturityDate
SELECT SettlementDate2 = @MaturityDate
END

IF (datediff(day, @ValueDate, @MaturityDate) <= 0)
RETURN

IF (datediff(day, @SettlementDate, @SettlementDate2) <= 0)
RETURN


IF (@Bonds_Id = 0)
RETURN

IF (@Price in (0, NULL))
RETURN

IF (@Quantity in (0, NULL))
Return

IF (@ConversionRate = 0.00)
RETURN

IF (@Cur in (0, NULL))
Return


SELECT @Currencies_Id = Currencies_Id
FROM kplus..Bonds
WHERE Bonds_Id = @Bonds_Id

SELECT @Currencies_ShortName = Currencies_ShortName
FROM kplus..Currencies
WHERE Currencies_Id = @Cur


Select Currencies_Id = @Currencies_Id
SELECT CurAccr1 = @Currencies_ShortName
SELECT CurAccr2 = @Currencies_ShortName
SELECT CurGA1 = @Currencies_ShortName
SELECT CurGA2 = @Currencies_ShortName
SELECT CurWA = @Currencies_ShortName
SELECT CurFA = @Currencies_ShortName

DEclare cBondsCF cursor for
SELECT PaymentDate, sum(CashFlow)
FROM 	kplus..BondsSchedule
WHERE 	Bonds_Id = @Bonds_Id
and EndDate > @SettlementDate
and EndDate <= @SettlementDate2
and CashFlowType in ("I", "N")
Group By PaymentDate
Order By 1

  select @FwdPriceMethod = isnull(@FwdPriceMethod, 'D')													
--   select @FwdPriceMethod as FwdPriceMethod													
													
   select @Mult = case @CapturedDiscount when 'D' then (1 - @Discount/100) when 'H' then (100/@Haircut) else 1 end													
	


 												
   select @Principal1 = FaceValue, @Principal2 = FaceValue
   from   kplus..Bonds where Bonds_Id = @Bonds_Id													
													
  	

											
   if @Bonds_Id > 0 and @SettlementDate is not null and @Quantity > 0													
   begin													
  												
      exec RTR_BondsDealsAccrued @Bonds_Id, @Quantity, @SettlementDate,  @AC_Method, @outAccruedAmount output, @outAccrued output													
							


						
      select @Principal1 = @Principal1 - isnull(sum(CashFlow),0)													
      from   kplus..BondsSchedule													
      where  Bonds_Id = @Bonds_Id													
      and    EndDate <= @SettlementDate													
      and    CashFlowType = 'N'													
													
  --	select @outAccruedAmount, @outAccrued, @Principal1								
													
      select @outGrossAmount = (@Principal1 * @Quantity * @Price / 100 + @outAccruedAmount)													
													
   end													
													
   if @Bonds_Id > 0 and @SettlementDate2 is not null and @Quantity > 0													
   begin													
      												
      exec RTR_BondsDealsAccrued @Bonds_Id, @Quantity, @SettlementDate2, @AC_Method,  @outAccruedAmount2 output, @outAccrued2 output													
													
      select @Principal2 = @Principal2 - isnull(sum(CashFlow),0)													
      from   kplus..BondsSchedule													
      where  Bonds_Id = @Bonds_Id													
      and    EndDate <= @SettlementDate2													
      and    CashFlowType = 'N'													
																				
													
   end													
													
   if @MaturityDate is null or @ValueDate is null													
      return													
													
  												
   if @MaturityDate is not null and @ValueDate is not null													
      exec PYearFractionSimple @ValueDate, @MaturityDate, @Basis, 'A',  @YF output													
													

									
   create table #RepoCashFlows													
      (													
      Record_Id         numeric(3)   identity,													
      StartDate         datetime     not null,													
      EndDate           datetime     not null,													
      PaymentDate       datetime     not null,													
      CashFlowType      char(1)      not null,													
      Principal         float        not null,													
      CashFlow          float        null,													
      Rate              float        null													
      )													
													
  	DEclare 	@Help float										


/* ##############################    M   ###################################   */




if @FwdPriceMethod = 'M' and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null													
   begin													
													
      													
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * round(@outGrossAmount * @ConversionRate,2)													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)													
													
      select @outForwardAmount = @outGrossAmount * (1 + @YF*@FixedRate/100)	
										
      												
      if @IgnoreCouponPayments = 'B'													
      begin													

 

						
         open cBondsCF													
         fetch cBondsCF into @CashFlowDate, @CashFlow													
         while (@@sqlstatus = 0)													
         begin													
            if @AC_Method = 'C'													
               select @CashFlow = round(@CashFlow,2) 												
													
            exec PYearFractionSimple @CashFlowDate, @MaturityDate, @Basis, 'A',  @YF_cf output	

	
											
            select @outForwardAmount = @outForwardAmount - @Quantity*@CashFlow*(1+@YF_cf*@ReinvCouponRate/100)													
													
   												
            select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * round(@Quantity*@CashFlow*@ConversionRate, 2)													
													
       												
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow													
													
    												
            insert into #RepoCashFlows													
               (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
            values													
               (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0)													
													
            fetch cBondsCF into @CashFlowDate, @CashFlow													
         end													
         close cBondsCF													
         deallocate cursor cBondsCF													
      end													
												
 									
													
      select @outForwardAmount = round(@outForwardAmount,2)		

											
      select @outGrossAmount2 = round(@outForwardAmount,2)													
      select @outDirtyPrice2 = @outGrossAmount2 / @Quantity / @Principal2 * 100													

/* ###############################  */
SELECT @Help = @outDirtyPrice2
/* #################################  */														
      select @outForwardPrice = round(@outDirtyPrice2 - @outAccrued2,4)													
      select @outDirtyPrice2 = @outForwardPrice + @outAccrued2													
      select @outForwardAmount = round(@outDirtyPrice2*@Quantity*@Principal2/100,2)													
      select @outGrossAmount2 = round(@outForwardAmount,2)													
													
  													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)													
													
   													
      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * round(@outForwardAmount*@ConversionRate,2) + @PrincipalCashFlow,													
             @outWeightedAmount = round(@outGrossAmount*@ConversionRate,2)													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)													
													
      select													
      Accrued           = @outAccrued,	
        MarginCallKnockOut     = @Help	,											
         DirtyPrice        = @outAccrued + @Price,													
        GrossAmount1      = round(@outGrossAmount*@ConversionRate,2),	
--        GrossAmount1 = @Help,	
												
         AccruedCash     = round(@outAccruedAmount*@ConversionRate,2),													
         WeightedAmount    = round(@outGrossAmount*@ConversionRate,2),													
         ForwardPrice2      = @outForwardPrice,													
         Accrued2          = @outAccrued2,													
         DirtyPrice2       = @outDirtyPrice2,													
         GrossAmount2      = round(@outGrossAmount2*@ConversionRate,2),													
         Accrued2Cash    = round(@outAccruedAmount2*@ConversionRate,2),													
         ForwardAmount2     = round(@outForwardAmount*@ConversionRate,2),													
         Prepayment        = round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate,2)	,
         FixedRate2 = @FixedRate	





    								
   end			

/* ##############################    D   ###################################   */


 if isnull(@FwdPriceMethod,'D') = 'D' and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null													
   begin													
													
											
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * round(@outGrossAmount * @Mult * @ConversionRate,2)													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)													
													
      select @outForwardAmount = round(@outGrossAmount * @Mult * (1 + @YF*@FixedRate/100), 2)													
													
  												
      if @IgnoreCouponPayments = 'B'													
      begin													
        													
         open cBondsCF													
         fetch cBondsCF into @CashFlowDate, @CashFlow													
         while (@@sqlstatus = 0)													
         begin													
            if @AC_Method = 'C'													
               select @CashFlow = round(@CashFlow,2) 													
													
            exec PYearFractionSimple @CashFlowDate, @MaturityDate, @Basis, 'A',  @YF_cf output	



												
            select @outForwardAmount = @outForwardAmount - @Quantity*@CashFlow*(1+@YF_cf*@ReinvCouponRate/100)													
													
   										
            select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * round(@Quantity*@CashFlow*@ConversionRate, 2)													
 											
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow													
   												
            insert into #RepoCashFlows													
               (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
            values													
               (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'N', 0, @CashFlow, 0)													
													
            fetch cBondsCF into @CashFlowDate, @CashFlow													
         end													
         close cBondsCF													
         deallocate cursor cBondsCF													
      end													
													
 												
													
      select @outForwardAmount = round(@outForwardAmount,2)													
      select @outGrossAmount2 = round(@outForwardAmount / @Mult,2)													
      select @outDirtyPrice2 = @outGrossAmount2 / @Quantity / @Principal2 * 100													
													
 										
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)													
													
   										
      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * round(@outForwardAmount*@ConversionRate,2) + @PrincipalCashFlow,													
             @outWeightedAmount = round(@outGrossAmount*@Mult*@ConversionRate,2)													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
--         (@MaturityDate, @MaturityDate, @MaturityDate, 'F', 0, @CashFlow, 0)													
												
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)													
													
 												
      select													
         Accrued         = @outAccrued,												
         DirtyPrice        = @outAccrued + @Price,													
         GrossAmount1       = round(@outGrossAmount*@ConversionRate,2),													
         AccruedCash     = round(@outAccruedAmount*@ConversionRate,2),													
         WeightedAmount    = round(@outGrossAmount*@Mult*@ConversionRate,2),													
         ForwardPrice2      = @outDirtyPrice2 - @outAccrued2,													
         Accrued2          = @outAccrued2,													
         DirtyPrice2       = @outDirtyPrice2,													
         GrossAmount2      = round(@outGrossAmount2*@ConversionRate,2),													
         Accrued2Cash    = round(@outAccruedAmount2*@ConversionRate,2),													
         ForwardAmount2     = round(@outForwardAmount*@ConversionRate,2),													
         Prepayment        = round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate,2),
	FixedRate2 = @FixedRate													
   end													
	


/* ##############################     A   ###################################   */

if @FwdPriceMethod = 'A' and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null													
   begin													
      select @outForwardAmount = @outGrossAmount													
      											
      if @IgnoreCouponPayments = 'B'													
      begin													
         													
         open cBondsCF													
         fetch cBondsCF into @CashFlowDate, @CashFlow													
         while (@@sqlstatus = 0)													
         begin													
            if @AC_Method = 'C'													
               select @CashFlow = round(@CashFlow,2) -- ????????? ????? ??????													
													
            exec PYearFractionSimple @ValueDate, @CashFlowDate, @Basis, 'A',  @YF_cf output													
            select @outForwardAmount = @outForwardAmount - @Quantity*@CashFlow/(1+@YF_cf*@ReinvCouponRate/100)													
            fetch cBondsCF into @CashFlowDate, @CashFlow													
         end													
         close cBondsCF													
         deallocate cursor cBondsCF													
      end													
													
      select @outForwardAmount = round(@outForwardAmount * (1 + @YF*@FixedRate/100), 2)													
      select @outForwardPrice = round((@outForwardAmount - @outAccruedAmount2)/(@Quantity*@Principal2)*100, 6)													
      select @outForwardAmount = round(@outForwardPrice * @Quantity * @Principal2/100 + @outAccruedAmount2,2)													
													
      select													
         Accrued           = @outAccrued,													
         DirtyPrice        = @outAccrued + @Price,													
         GrossAmount1       = round(@outGrossAmount*@ConversionRate,2),													
         AccruedCash     = round(@outAccruedAmount*@ConversionRate,2),													
         WeightedAmount    = round(@outGrossAmount*@ConversionRate,2),													
         ForwardPrice2      = @outForwardPrice,													
         Accrued2          = @outAccrued2,													
         DirtyPrice2       = @outForwardPrice+@outAccrued2,													
         GrossAmount2      = round(@outForwardAmount*@ConversionRate,2),													
         Accrued2Cash    = round(@outAccruedAmount2*@ConversionRate,2),													
         ForwardAmount2     = round(@outForwardAmount*@ConversionRate,2),													
         Prepayment        = 0													
   end													
			
 											
      						
													
   /* ##############################     A   ###################################   */												





/*

/* Adaptive Server has expanded all '*' elements in the following statement */ select #RepoCashFlows.Record_Id, #RepoCashFlows.StartDate, #RepoCashFlows.EndDate, #RepoCashFlows.PaymentDate, #RepoCashFlows.CashFlowType, #RepoCashFlows.Principal, #RepoCashFlows.CashFlow, #RepoCashFlows.Rate from #RepoCashFlows

*/


DECLARE @Max int,
	@RepoDeals_Id int
SELECT @Max= max(RepoDeals_Id) FROM kplus..RepoDeals
SELECT @RepoDeals_Id = @Max + 1

DELETE FROM RussianReposCashFlows
WHERE	RepoDeals_Id = @RepoDeals_Id

INSERT RussianReposCashFlows
SELECT @RepoDeals_Id,
	StartDate,
	EndDate,
	PaymentDate,
	CashFlowType,
	Principal,
	CashFlow,
	Rate
FROM	#RepoCashFlows


SELECT @Message = convert(varchar(20), @Bonds_Id) + "#" + @DealType + "#" + convert(varchar(20), @Quantity) + "#" + convert(varchar(20), @ConversionRate) + "#" +  @FwdPriceMethod

 -- exec kplus..SendMail "KPLUS", "KPLUS", @Basis
go
EXEC sp_procxmode 'dbo.RepoDealsNotify', 'unchained'
go
IF OBJECT_ID('dbo.RepoDealsNotify') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.RepoDealsNotify >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.RepoDealsNotify >>>'
go
REVOKE EXECUTE ON dbo.RepoDealsNotify FROM public
go
GRANT EXECUTE ON dbo.RepoDealsNotify TO public
go
