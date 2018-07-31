/*-------------------------------------------------*/
/*--- Initialization Part -------------------------*/
/*-------------------------------------------------*/

USE kplus
go

/*-------------------------------------------------*/
/*--- Procs export --------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		RUKON_RepoDealsProcess
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RUKON_RepoDealsProcess' AND type = 'P' 
)
	DROP PROC RUKON_RepoDealsProcess 
go


create PROC dbo.RUKON_RepoDealsProcess
(
  @Pid                                   int ,
  @Trigger                               varchar(32),
  @Deals_Id                              int,
  @DealType                              char(1),
  -- @RepoType                              char(1),
  @Bonds_Id                              int,
  @Equities_Id                           int,    
  @ValueDate                             datetime,
  @SettlementDate                        datetime,
  @MaturityDate                          datetime,
  @SettlementDate2                       datetime,
  @Price                                 float,
  @Quantity                              float,
  @Discount                              float,
  @FixedRate                             float,
  @Basis                                 char(1),
  @IgnoreCouponPayments                  char(1),
  @ReinvCouponRate                       float,
  -- @Currencies_Id                         int,
  -- @Currencies_Id_Price                   int,
  @ConversionRate                        float,
  -- @ClearingModes_Id                      int,
  -- @ClearingModes_Id_Cpty                 int,
  @NeedPrepayment                        char(1),
  @FwdPriceMethod                        char(1),
  -- @Trigger                               varchar(32),
  @Haircut                               float,
  @CapturedDiscount                      char(1),
  @Cur                                   int
)
as
begin
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
  @YF_Help                     float,
  @outForwardAmount            float,
  @outWeightedAmount           float,
  @outForwardPrice             float,
  @CashFlow                    float,
  @AC_Method                   char(1),
  @CashFlowType                char(1),
  @CashFlowDate                datetime,
  @MC_Ccy_Id                   int,
  @MC_Asset                    char(3),
  @MC_Rate                     float,
  @MC_Comments                 varchar(64),
  @DownloadKey                 varchar(30),
  @PrincipalCashFlow           float,
  @Rate                        float,
  @Mult                        float  ,
  @BalancedDiscount             char(1),
  @Currencies_Id               int,
  --PDA TESTING ONLY
  @Currencies_Id_Price          int,
  @Currencies_ShortName        varchar(3),
  @Message                     varchar(200),
  @Help                        float

  /* BY PDA. Currency Conversion handling, to be reviewed.
     -- ????????? ???????? ????: ???? ???? ?????? ???? ? ?????? ?????? Indirect, ?? ????????Я????? ConversionRate
     IF @ConversionRate<=0
     BEGIN
        SELECT _MESSAGE_='WARNING. ConversionRate not defined.'
        return
     END
     ELSE IF exists (SELECT * FROM kplus.dbo.Pairs
                     WHERE Currencies_Id_1 = @Currencies_Id_Price
                    AND Currencies_Id_2 = @Currencies_Id
                    AND QuotationMode='I')
     BEGIN
           SELECT @ConversionRate = 1.0 / @ConversionRate
     END
  */

  -- Discount vs Haircut handing

  if (@CapturedDiscount = "H")
  begin
    select Discount = 0.00
    if (@Haircut != 0.00)
      select Discount = 100.00 - (10000.00 / @Haircut )
  end

  if (@CapturedDiscount = "D")
  begin
    select Haircut2 = 100.00
    if (@Discount != 100)
      select Haircut2 = 10000.00 / (100.00 - @Discount)
  end

  select @Mult = case @CapturedDiscount
                when 'D' then (1 - @Discount / 100)
                when 'H' then (100 / @Haircut)
                else 1 end

-- END OF Discount vs Haircut handing


-- Dates AND values coherency check

  if @ValueDate is null or @MaturityDate is null
    return
    
    
/*
  -- Repo with a Bond should mature at least 1 day prior the Bond's maturity
  if @MaturityDate > (select dateadd(dd, -1, MaturityDate) from kplus..Bonds where Bonds_Id = @Bonds_Id)
  begin
    select _MESSAGE_ = "MaturityDate", "Maturity Date must be at least 1 day less than Bond's maturity!"
    return
  end
*/

  if @Trigger = "ValueDate"
  begin  
    select @SettlementDate = @ValueDate
    select SettlementDate = @ValueDate
  end

  if @Trigger = "MaturityDate"
  begin  
    select @SettlementDate2 = @MaturityDate
    select SettlementDate2 = @MaturityDate
  end

    

  select @SettlementDate2 = isnull(@SettlementDate2, @MaturityDate)
  select SettlementDate2 = isnull(@SettlementDate2, @MaturityDate)
  select @SettlementDate = isnull(@SettlementDate, @ValueDate)
  select SettlementDate = isnull(@SettlementDate, @ValueDate)

  if (datediff(day, @ValueDate, @MaturityDate) <= 0)
    return

  if (datediff(day, @SettlementDate, @SettlementDate2) <= 0)
    return

  if isnull(@Bonds_Id, 0) = 0 and isnull(@Equities_Id, 0) = 0
    return

  if isnull(@Price, 0) = 0
    return

  if isnull(@Quantity, 0) = 0
    return

  if isnull(@ConversionRate, 0.0) = 0.0
    return

  if isnull(@Cur, 0) = 0
    return

-- END OF Dates AND values coherency check

  select @Currencies_Id = Currencies_Id
  from kplus..Bonds
  where Bonds_Id = @Bonds_Id

  select @Currencies_ShortName = Currencies_ShortName
  from kplus..Currencies
  where Currencies_Id = @Cur

-- BY PDA. Only for Testing:
select @Currencies_Id_Price = @Currencies_Id

  select Currencies_Id = @Currencies_Id
  select CurAccr1 = @Currencies_ShortName
  select CurAccr2 = @Currencies_ShortName
  select CurGA1 = @Currencies_ShortName
  select CurGA2 = @Currencies_ShortName
  select CurWA = @Currencies_ShortName
  select CurFA = @Currencies_ShortName

  declare cBondsCF cursor for
  select PaymentDate, sum(CashFlow)
  from  kplus..BondsSchedule
  where   Bonds_Id = @Bonds_Id
  and EndDate > @SettlementDate
  and EndDate <= @SettlementDate2
  and CashFlowType in ("I", "N")
  group by PaymentDate
  order by 1

-- Deafault Forward Price Method is "D"
  select @FwdPriceMethod = isnull(@FwdPriceMethod, 'D')


  select @Principal1 = FaceValue,
         @Principal2 = FaceValue
  from   kplus..Bonds
  where  Bonds_Id = @Bonds_Id

-- Custom Accrued Interest calculation for the near and far Repo legs
-- Near leg Accrued
  if @Bonds_Id > 0 and @SettlementDate is not null and @Quantity > 0
  begin
      --BY PDA. Legacy Reuters Method: exec RTR_BondsDealsAccrued @Bonds_Id, @Quantity, @SettlementDate,  @AC_Method, @outAccruedAmount output, @outAccrued output
      exec RUKON_BondsAccrued @Bonds_Id, @Quantity, @SettlementDate, @outAccruedAmount output, @outAccrued output

      -- BY PDA. IGNORING @AdjFactor, needed for CPI Bonds only
      /* if @AdjFactor is null
      begin
         -- ????Я????? @AdjFactor ?? ???? SettlementDate ??????
         exec Radius_Lib_BondsAdjFactors_Get @Bonds_Id, @SettlementDate, @AdjFactor output
      end

      select
         @Principal1 =
            @AdjFactor * (@Principal1 - isnull(sum(CashFlow / (case AdjFactor when 0 then 1 else AdjFactor end)), 0))
      from kplus.dbo.BondsSchedule
      where Bonds_Id       = @Bonds_Id
         and EndDate       <= @SettlementDate
         and CashFlowType  = 'N'
      */
       -- END OF BY PDA. IGNORING @AdjFactor, needed for CPI Bonds only


    select @Principal1 = @Principal1 - isnull(sum(CashFlow),0)
    from   kplus..BondsSchedule
    where  Bonds_Id = @Bonds_Id
    and    EndDate <= @SettlementDate
    and    CashFlowType = 'N'

    --BY PDA. Legacy Sysatematica method:
    --SELECT @outGrossAmount = (@Principal1 * @Quantity * @Price / 100 + @outAccruedAmount)
    select @outGrossAmount = dbo.RUKON_Round(@Principal1 * @Quantity * @Price / 100 + @outAccruedAmount, 2)

    --BY BCS: 20171001 start m1
    if isnull(@FwdPriceMethod,'D') = 'Z'
    select @outGrossAmount = @Principal1 * @Quantity * (@Price+@outAccrued) / 100
    --20171001 end m1
  end
   --END OF near leg accrued


  --Far leg Accrued
  if @Bonds_Id > 0 and @SettlementDate2 is not null and @Quantity > 0
  begin
      --BY PDA. Legacy Reuters Method: exec RTR_BondsDealsAccrued @Bonds_Id, @Quantity, @SettlementDate2, @AC_Method,  @outAccruedAmount2 output, @outAccrued2 output
      exec RUKON_BondsAccrued @Bonds_Id, @Quantity, @SettlementDate2, @outAccruedAmount2 output, @outAccrued2 output

    -- BY PDA. IGNORING @AdjFactor, needed for CPI Bonds only
    /*
    -- ???? @FwdAdjFactor ?? ???????
    if @FwdAdjFactor is null
    begin
       -- ????Я????? @FwdAdjFactor ?? ???? SettlementDate2 ??????
       exec Radius_Lib_BondsAdjFactors_Get @Bonds_Id, @SettlementDate2, @FwdAdjFactor output
    end

    select
       @Principal2 =
          @FwdAdjFactor * (@Principal2 - isnull(sum(CashFlow / (case AdjFactor when 0 then 1 else AdjFactor end)), 0))
    from kplus.dbo.BondsSchedule
    where Bonds_Id       = @Bonds_Id
       and EndDate       <= @SettlementDate2
       and CashFlowType  = 'N'
      */
    -- END OF BY PDA. IGNORING @AdjFactor, needed for CPI Bonds only

    select @Principal2 = @Principal2 - isnull(sum(CashFlow),0)
    from   kplus..BondsSchedule
    where  Bonds_Id = @Bonds_Id
    and    EndDate <= @SettlementDate2
    and    CashFlowType = 'N'
  end
  -- END OF far leg accrued

  -- Calculating Year fraction between Value date and Maturity date
  if @MaturityDate is not null and @ValueDate is not null
  --BY PDA. Legacy Reuters Method: exec PYearFractionSimple @ValueDate, @MaturityDate, @Basis, 'A',  @YF output
    begin
      exec RUKON_YearFraction
         @StartDate     = @ValueDate,
         @EndDate       = @MaturityDate,
         @Basis         = @Basis,
         @YearFraction  = @YF output
   end
  -- END OF Calculating Year fraction between Value date and Maturity date

-- Temporary table for storing custom Repo cash flows
  create table #RepoCashFlows
  (
    Record_Id         numeric(3)   identity,
    StartDate         datetime     not null,
    EndDate           datetime     not null,
    PaymentDate       datetime     not null,
    CashFlowType      char(1)      not null,
    Principal         float        not null,
    CashFlow          float        null,
    Rate              float        null,
    Comment          varchar(64)   null
   )

  
  if @FwdPriceMethod = 'B'
  begin
    select
      @FwdPriceMethod   = 'D',
      @BalancedDiscount = 'Y'
  end
  else
  begin
    select @BalancedDiscount = 'N'
  end

-- 1  D Default
-- 2  Z Calypso Default (ZERO)    20160709
-- 3  7 Bloomberg         20160101
-- 4  F BCS             20160101
-- 5  M MICEX 4 digits
-- 6  6 MICEX 6 digits
-- 7  L Security Loan
-- 8  1 Calypso Empty Cash Flow   20160709
-- 9  0 Empty Cash Flow
--10  B BalancedDiscount      20150101
--11  C Cash Flow Only
--12  A Alfa
--13  N Nomos
--14  T Trust
--15  J JPMorgan
--16  V ??? (Start Price)
--17  P ??? (MarketPrice)

/* ##############################    Default and Calypso methods for Bonds   ###################################   */

    declare @outForwardAmount_D float -- в валюте сделки
   -- ѕроводим стандартные вычислени€ дл€ облигаций если сумма купона была пересчитали
   -- ћетод '0' - это стандартный метод с пустым расписанием
  if isnull(@FwdPriceMethod,'D') in ('D','0','Z') and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null
  begin    
    -- 1) ¬ ValueDate сумма CashFlow равна WeightedAmount
    select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.RUKON_Round(@outGrossAmount * @Mult * @ConversionRate, 2) 

  --20170801 start b1
    if isnull(@FwdPriceMethod,'D') = 'Z'
    begin
    select @PrincipalCashFlow = dbo.RUKON_Round(@outGrossAmount * @Mult * @ConversionRate, 2)
    if (@Mult * @ConversionRate) <> 0
    select @outGrossAmount = @PrincipalCashFlow / (@Mult * @ConversionRate)
    select @PrincipalCashFlow = @PrincipalCashFlow *(case when @DealType in ('B', 'V') then -1 else 1 end)
    end
  --20170801 end b1

    if @FwdPriceMethod not in ('0')
    begin
       insert into #RepoCashFlows
          (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
       values
          (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)
    end

    select @outForwardAmount = dbo.RUKON_Round(@outGrossAmount * @Mult * (1 + @YF * @FixedRate / 100), 2)

  --20170801 b2 start
    if isnull(@FwdPriceMethod,'D') = 'Z'
    begin
    declare @InterestB float
    select  @InterestB = dbo.RUKON_Round(@outGrossAmount*@Mult*@YF*@FixedRate/100*@ConversionRate, 2)/@ConversionRate
    select  @outForwardAmount   = dbo.RUKON_Round(@outGrossAmount * @Mult + @InterestB, 2)
        -- ,@outForwardAmount_D = dbo.RUKON_Round(@outGrossAmount * @Mult + @InterestB, 2) * @ConversionRate
    end
  --20170801 b2 end

    -- если были выплаты и они достались покупателю, то сумму @ForwardAmount надо уменьшить на сумму выплат
    -- с учетом прироста этих выплат по ставке реинвестировани€ купона.
    if @IgnoreCouponPayments = 'B'
    begin
      select @AC_Method = isnull(min(substring(Method,1,1)),'G')
      from   RUKON_BondCouponParams
      where  DealId = @Bonds_Id and DealType = 'Bonds'

      declare cBondsCF cursor  for
        select PaymentDate, sum(CashFlow)
        from   kplus.dbo.BondsSchedule
        where  Bonds_Id = @Bonds_Id
        and    EndDate > @SettlementDate
        and    EndDate <= @SettlementDate2
        and    CashFlowType in ('I', 'N')
        group by PaymentDate
        order by 1


      open cBondsCF


          fetch cBondsCF into @CashFlowDate, @CashFlow

          while (@@sqlstatus = 0)

          begin

             if @AC_Method = 'C'
             begin
                select @CashFlow = dbo.RUKON_Round(@CashFlow, 2) -- округл€ем сумму купона
             end

             exec RUKON_YearFraction
                @StartDate     = @CashFlowDate,
                @EndDate       = @MaturityDate,
                @Basis         = @Basis,
                @YearFraction  = @YF_cf output

             select @outForwardAmount = @outForwardAmount - @Quantity * @CashFlow * (1+@YF_cf * @ReinvCouponRate/100)

             -- вставл€ем запись CashFlow по сделке
             -- а) считаем сумму платежа
             select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * dbo.RUKON_Round(@Quantity*@CashFlow*@ConversionRate, 2)
             -- б) уменьшаем остаток
             select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
             -- в) вставл€ем запись
             if @FwdPriceMethod not in ('0')
                insert into #RepoCashFlows
                   (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
                values
                   (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'N', 0, @CashFlow, 0)


             fetch cBondsCF into @CashFlowDate, @CashFlow

          end -- while (@@sqlstatus = 0)


          close cBondsCF

          deallocate cursor cBondsCF

    end
    -- заполним в валюте сделки
    select @outForwardAmount_D = @outForwardAmount * @ConversionRate

    -- “еперь, если были Margin Calls по сделке, то учитываем и их


       declare cMarginCallCF cursor  for
          select e.ValueDate, e.Quantity, mc.FixedRate, e.Assets_Id, e.AssetType, 'ћ—' + convert(varchar,mc.RadiusMarginCalls_Id) + ' ' + mc.Comments + ' ' + e.Comments
          from RadiusMarginCallsExecs e
             inner join RadiusMarginCalls mc
                on e.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id
                and e.ContextType = 'RepoDeals'
                and e.AssetType = 'CCY'
          where e.Context_Id = @Deals_Id

          order by 1


       open cMarginCallCF


       fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

       while (@@sqlstatus = 0)

       begin

          -- если MC в деньгах и валюта сделки не равна валюте ћ—, то переводим сумму ћ— в валюту сделки
          if @MC_Asset = 'CCY' and  @MC_Ccy_Id <> @Currencies_Id
          begin
             exec Radius_Lib_CurrenciesRate_Get
                @Currencies_Id_1 = @MC_Ccy_Id,
                @Currencies_Id_2 = @Currencies_Id,
                @RateDate = @CashFlowDate,
                @Rate = @MC_Rate out,
                @QuoteType = 'F',
                @GoodOrder = 'Y'
          end
          else
          begin
             select  @MC_Rate = 1
          end

          exec RUKON_YearFraction
             @StartDate     = @CashFlowDate,
             @EndDate       = @MaturityDate,
             @Basis         = @Basis,
             @YearFraction  = @YF_cf output

          select @outForwardAmount_D = @outForwardAmount_D - @CashFlow*@MC_Rate*(1+@YF_cf*isnull(@Rate,@FixedRate)/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)
                                                         -- выплаты по MC в валюте сделки, а расчет ведетс€ валюте бумаги
          -- convert CashFlow currency

          select @CashFlow = @CashFlow*@MC_Rate

          -- вставл€ем запись CashFlow по сделке
          -- б) уменьшаем остаток
          select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow

          -- в) вставл€ем запись
          if @FwdPriceMethod not in ('0')
          begin
             insert into #RepoCashFlows
                (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comment)
             values
                (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)
          end


          fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

       end -- while (@@sqlstatus = 0)


       close cMarginCallCF

       deallocate cursor cMarginCallCF


    select @outForwardAmount   = dbo.RUKON_Round(@outForwardAmount_D, 2)
    select @outGrossAmount2    = dbo.RUKON_Round((@outForwardAmount / @ConversionRate) / @Mult, 2)              -- /@ConversionRate = ѕронин 13.09.2012
    select @outDirtyPrice2     = @outGrossAmount2 / @Quantity / @Principal2 * 100

    -- 3) Ќа MaturityDate записываетс€ Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.
    if @FwdPriceMethod not in ('0')
    begin
       insert into #RepoCashFlows
          (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
       values
          (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)
    end

    -- 4) Ќа MaturityDate записываетс€ Interest CashFlow равный разнице ForwardAmount и Principal CashFlow из пункта 3
    select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * @outForwardAmount + @PrincipalCashFlow,
           @outWeightedAmount = dbo.RUKON_Round(@outGrossAmount*@Mult*@ConversionRate, 2)

    if @FwdPriceMethod not in ('0')
    begin
       insert into #RepoCashFlows
          (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
       values
  --         (@MaturityDate, @MaturityDate, @MaturityDate, 'F', 0, @CashFlow, 0)
  -- KIS иногда пересчитывает сумму CashFlow c типом I, поэтому приходитс€ ее класть таким кривым образом вместо правильного:
          (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)
    end

    -- возвращаем посчитанные данные
    select
      Accrued           = @outAccrued,
      DirtyPrice        = @outAccrued + @Price,
      GrossAmount       = dbo.RUKON_Round(@outGrossAmount*@ConversionRate, 2),
      AccruedAmount     = dbo.RUKON_Round(@outAccruedAmount*@ConversionRate, 2),
      WeightedAmount    = dbo.RUKON_Round(@outGrossAmount*@Mult*@ConversionRate, 2),
      ForwardPrice      = @outDirtyPrice2 - @outAccrued2,
      Accrued2          = @outAccrued2,
      DirtyPrice2       = @outDirtyPrice2,
      GrossAmount2      = case @BalancedDiscount
                           when 'N' then dbo.RUKON_Round(@outGrossAmount2*@ConversionRate, 2)
                           when 'Y' then dbo.RUKON_Round(@outForwardAmount + dbo.RUKON_Round(@outGrossAmount*@ConversionRate, 2) - dbo.RUKON_Round(@outGrossAmount*@Mult*@ConversionRate, 2), 2)
                         end,
      AccruedAmount2    = dbo.RUKON_Round(@outAccruedAmount2*@ConversionRate, 2),
      ForwardAmount     = @outForwardAmount,
      Prepayment        = dbo.RUKON_Round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate, 2)
  end


/* ##############################  EOF Default and Calypso methods for Bonds  ###################################   */



/* ############################## Default and Calypso methods for Equities  ###################################   */

  if isnull(@FwdPriceMethod,'D') in ('D','0','Z') and @Equities_Id > 0
  begin

    --select _MESSAGE_ = "FwdPriceMethod", @FwdPriceMethod
    select @outGrossAmount = @Quantity * @Price

    -- 1) ¬ ValueDate сумма CashFlow равна WeightedAmount
    select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.RUKON_Round(@outGrossAmount * @Mult * @ConversionRate, 2)

  --20170801 start1
    if isnull(@FwdPriceMethod,'D') = 'Z'
    begin
    select @PrincipalCashFlow = dbo.RUKON_Round(@outGrossAmount * @Mult * @ConversionRate, 2)
    if (@Mult * @ConversionRate) <> 0
    select @outGrossAmount = @PrincipalCashFlow / (@Mult * @ConversionRate)
    select @PrincipalCashFlow = @PrincipalCashFlow *(case when @DealType in ('B', 'V') then -1 else 1 end)
    end
  --20170801 end1

    if @FwdPriceMethod not in ('0')
    begin
       insert into #RepoCashFlows
          (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
       values
          (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)
    end

    select @outForwardAmount   = dbo.RUKON_Round(@outGrossAmount * @Mult * (1 + @YF*@FixedRate/100), 2),
           @outForwardAmount_D = dbo.RUKON_Round(@outGrossAmount * @Mult * (1 + @YF*@FixedRate/100), 2) * @ConversionRate
  --20170801  start2
    if isnull(@FwdPriceMethod,'D') = 'Z'   --20170801
    begin
    declare @Interest float
  --select  @Interest = dbo.RUKON_Round(@outGrossAmount*@Mult*@YF*@FixedRate/100*@ConversionRate, 2)
    select  @Interest = dbo.RUKON_Round(dbo.RUKON_Round(@outGrossAmount*@Mult*@ConversionRate ,2)*@YF*@FixedRate/100,2)
    select  @outForwardAmount   = dbo.RUKON_Round(@outGrossAmount * @Mult + @Interest/@ConversionRate , 2),
            @outForwardAmount_D = dbo.RUKON_Round(@outGrossAmount * @Mult * @ConversionRate + @Interest, 2)
    end
  --20170801  end2

    -- “еперь, если были Margin Calls по сделке, то учитываем и их

       declare cMarginCallCF cursor  for
          select e.ValueDate, e.Quantity, mc.FixedRate, e.Assets_Id, e.AssetType, 'MC' + convert(varchar,mc.RadiusMarginCalls_Id) + ' ' + mc.Comments + ' ' + e.Comments
          from RadiusMarginCallsExecs e
             inner join RadiusMarginCalls mc
                on e.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id
                and e.ContextType = 'RepoDeals'
                and e.AssetType = 'CCY'
          where e.Context_Id = @Deals_Id

          order by 1


       open cMarginCallCF


       fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

       while (@@sqlstatus = 0)

       begin

          -- если MC в деньгах и валюта сделки не равна валюте ћ—, то переводим сумму ћ— в валюту сделки
          if @MC_Asset = 'CCY' and  @MC_Ccy_Id <> @Currencies_Id
          begin
             exec Radius_Lib_CurrenciesRate_Get
                @Currencies_Id_1 = @MC_Ccy_Id,
                @Currencies_Id_2 = @Currencies_Id,
                @RateDate = @CashFlowDate,
                @Rate = @MC_Rate out,
                @QuoteType = 'F',
                @GoodOrder = 'Y'
          end
          else
          begin
             select  @MC_Rate = 1
          end

          exec RUKON_YearFraction
             @StartDate     = @CashFlowDate,
             @EndDate       = @MaturityDate,
             @Basis         = @Basis,
             @YearFraction  = @YF_cf output

          select @outForwardAmount_D = @outForwardAmount_D - @CashFlow*@MC_Rate*(1+@YF_cf*isnull(@Rate,@FixedRate)/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)
          -- выплаты по MC в валюте сделки, а расчет ведетс€ валюте бумаги ???

          select @CashFlow = @CashFlow*@MC_Rate
          -- вставл€ем запись CashFlow по сделке
          -- б) уменьшаем остаток
          select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
          -- в) вставл€ем запись
          if @FwdPriceMethod not in ('0')
             insert into #RepoCashFlows
                (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comment)
             values
                (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)


          fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

       end -- while (@@sqlstatus = 0)


       close cMarginCallCF

       deallocate cursor cMarginCallCF


    select @outForwardAmount = dbo.RUKON_Round(@outForwardAmount_D, 2)
    select @outGrossAmount2 = dbo.RUKON_Round(@outForwardAmount / @Mult, 2)
    if @Quantity <> 0
    begin
       select @outDirtyPrice2 = @outGrossAmount2 / @Quantity
    end

    -- 3) Ќа MaturityDate записываетс€ Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.
    if @FwdPriceMethod not in ('0')
    begin
       insert into #RepoCashFlows
          (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
       values
          (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)
    end

    -- 4) Ќа MaturityDate записываетс€ Interest CashFlow равный разнице ForwardAmount и Principal CashFlow из пункта 3
    select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * @outForwardAmount_D + @PrincipalCashFlow,
           @outWeightedAmount = dbo.RUKON_Round(@outGrossAmount*@Mult*@ConversionRate, 2)

    if @FwdPriceMethod not in ('0')
    begin
       insert into #RepoCashFlows
          (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
       values
          (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate) -- @CashFlow
    end

    -- возвращаем посчитанные данные
    select _MESSAGE_ = "DirtyPrice", @Price
    select _MESSAGE_ = "DirtyPrice2", @outDirtyPrice2
    
    select
       Accrued           = 0,
       DirtyPrice        = @Price,
       GrossAmount1       = dbo.RUKON_Round(@outGrossAmount*@ConversionRate, 2),
       AccruedAmount     = 0,
       WeightedAmount    = dbo.RUKON_Round(@outGrossAmount*@ConversionRate*@Mult, 2),
       ForwardPrice2      = @outDirtyPrice2/@ConversionRate, -- переводим в валюту цены
       Accrued2          = 0,
       DirtyPrice2       = @outDirtyPrice2,
       GrossAmount2      = case @BalancedDiscount
                               when 'N' then dbo.RUKON_Round(@outGrossAmount2, 2)
                               when 'Y' then dbo.RUKON_Round(@outForwardAmount + dbo.RUKON_Round(@outGrossAmount*@ConversionRate, 2) - dbo.RUKON_Round(@outGrossAmount*@ConversionRate*@Mult, 2), 2)
                           end,
       AccruedAmount2    = 0,
       ForwardAmount2     = @outForwardAmount,
       Prepayment        = dbo.RUKON_Round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate, 2)
  end


/* ##############################  EOF Default and Calypso methods for Equities  ###################################   */




/* ##############################    MOEX Repo with Bonds 4 digits roundinging   ###################################   */

  if @FwdPriceMethod = 'M' and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null
  begin
      -- On Value Date CashFlow should be equal to Weighted Amount
    select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.RUKON_Round(@outGrossAmount * @ConversionRate, 2)

    insert into #RepoCashFlows
       (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
    values
       (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)

    select @outForwardAmount = @outGrossAmount * (1 + @YF*@FixedRate/100)

   /*
    If there were coupon pay offs during Repo life then Repo Forward Amont should be decreased by the total
    amount of the payments considering coupon growth rate
    */

    if @IgnoreCouponPayments = 'B'
    begin
      select @AC_Method = isnull(min(substring(Method,1,1)),'G') from RUKON_BondCouponParams
      where DealId = @Bonds_Id and DealType = 'Bonds'

      open cBondsCF
      fetch cBondsCF into @CashFlowDate, @CashFlow
      while (@@sqlstatus = 0)
      begin
        if @AC_Method = 'C'
        begin
          -- BY PDA. Legacy Systematica Method: SELECT @CashFlow = round(@CashFlow,2) --Rounding coupon by 2 digits
          select @CashFlow = dbo.RUKON_Round(@CashFlow, 2)
        end
        exec RUKON_YearFraction
             @StartDate     = @CashFlowDate,
             @EndDate       = @MaturityDate,
             @Basis         = @Basis,
             @YearFraction  = @YF_cf output

        select @outForwardAmount = @outForwardAmount - @Quantity*@CashFlow*(1+@YF_cf*@ReinvCouponRate/100)

        -- Inserting the intermediate Cash Flow into the temporary CF Table
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

    /*
    If there were margin calls during the Repo life they need to be handled and the deal's CF updated accordingly
    */

    declare cMarginCallCF cursor  for
            select e.ValueDate, e.Quantity, mc.FixedRate, e.Assets_Id, e.AssetType,
            '??' + convert(varchar,mc.RadiusMarginCalls_Id) + ' ' + mc.Comments + ' ' + e.Comments
            from   RadiusMarginCallsExecs e, RadiusMarginCalls mc
            where  e.ContextType = 'RepoDeals'
            and    e.Context_Id = @Deals_Id
            and    e.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id
            order by 1

    open cMarginCallCF
    fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments
    while (@@sqlstatus = 0)
    begin
      if @MC_Asset = 'CCY' and  @MC_Ccy_Id <> @Currencies_Id_Price
      begin
      exec Radius_Lib_CurrenciesRate_Get
          @Currencies_Id_1 = @Currencies_Id_Price,
          @Currencies_Id_2 = @MC_Ccy_Id,
          @RateDate = @CashFlowDate,
          @Rate = @MC_Rate out,
          @QuoteType = 'F',
          @GoodOrder = 'Y'
      end
      else
      begin
         select  @MC_Rate = @ConversionRate
      end

      exec RUKON_YearFraction
           @StartDate     = @CashFlowDate,
           @EndDate       = @MaturityDate,
           @Basis         = @Basis,
           @YearFraction  = @YF_cf output

      -- ??????? ?? MC ? ?????? ??????, ? ???Я?? ??????? ?????? ??????
      select @outForwardAmount = @outForwardAmount - @CashFlow/@MC_Rate*(1+@YF_cf*@FixedRate/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)

      -- **alex**
      select @CashFlow = @CashFlow/@MC_Rate
      -- Inserting the Margin Call Cash Flow into the temporary CF Table
      select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comment)
      values
         (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)

      fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

    end -- while (@@sqlstatus = 0)

    close cMarginCallCF
    deallocate cursor cMarginCallCF

    /*
    END OF Margin Calls handing
    */

    select @outForwardAmount = dbo.RUKON_Round(@outForwardAmount, 2)
    select @outGrossAmount2 = dbo.RUKON_Round(@outForwardAmount, 2)
    select @outDirtyPrice2 = @outGrossAmount2 / @Quantity / @Principal2 * 100

    /* ###############################  */
    select @Help = @outDirtyPrice2
    /* #################################  */

    select @outForwardPrice = dbo.RUKON_Round(@outDirtyPrice2 - @outAccrued2, 4)
    select @outDirtyPrice2 = @outForwardPrice + @outAccrued2
    select @outForwardAmount = dbo.RUKON_Round(@outDirtyPrice2*@Quantity*@Principal2/100, 2)
    select @outGrossAmount2 = dbo.RUKON_Round(@outForwardAmount, 2)

      -- On Maturity Date Principal CashFlow equals to WeightedAmount minus all intermediate payments
      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)

      -- On Maturity Date Interest CashFlow equals to ForwardAmount minus the Principal CashFlow above
      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * dbo.RUKON_Round(@outForwardAmount*@ConversionRate, 2) + @PrincipalCashFlow,
             @outWeightedAmount = dbo.RUKON_Round(@outGrossAmount*@ConversionRate, 2)

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)

      select
      PriceCw             = @Price,
      Accrued           = @outAccrued,
      MarginCallKnockOut     = @Help,
      DirtyPrice        = @outAccrued + @Price,
      GrossAmount1      = dbo.RUKON_Round(@outGrossAmount*@ConversionRate, 2),
      AccruedCash     = dbo.RUKON_Round(@outAccruedAmount*@ConversionRate, 2),
      WeightedAmount    = dbo.RUKON_Round(@outGrossAmount*@ConversionRate, 2),
      ForwardPrice2      = @outForwardPrice,
      Accrued2          = @outAccrued2,
      DirtyPrice2       = @outDirtyPrice2,
      GrossAmount2      = dbo.RUKON_Round(@outGrossAmount2*@ConversionRate, 2),
      Accrued2Cash    = dbo.RUKON_Round(@outAccruedAmount2*@ConversionRate, 2),
      ForwardAmount2     = dbo.RUKON_Round(@outForwardAmount*@ConversionRate, 2),
      Prepayment        = dbo.RUKON_Round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate, 2),
      FixedRate2 = @FixedRate
  end


/* ############################## EOF MOEX Repo with Bonds 4 digits rounding  ###################################   */



/* ##############################  MOEX Repo with Equities 4 digits rounding   ###################################   */

  if @FwdPriceMethod = 'M' and @Equities_Id > 0
  begin
    select @outGrossAmount = @Quantity*@Price
    select @outForwardAmount = (1+@FixedRate/100*@YF)*@Quantity*@Price
    select @outForwardPrice = dbo.RUKON_Round(@outForwardAmount/@Quantity, 4)
    select @outForwardAmount = dbo.RUKON_Round(@outForwardPrice*@Quantity, 2)

    select
       WeightedAmount    = @Price*@Quantity,
       ForwardPrice      = @outForwardPrice,
       DirtyPrice2       = @outForwardPrice,
       GrossAmount2      = @outForwardAmount,
       ForwardAmount     = @outForwardAmount

    select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.RUKON_Round(@outGrossAmount * @ConversionRate, 2)

    insert into #RepoCashFlows
       (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
    values
       (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)

    insert into #RepoCashFlows
       (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
    values
       (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)

    select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * dbo.RUKON_Round(@outForwardAmount*@ConversionRate, 2) + @PrincipalCashFlow,
           @outWeightedAmount = dbo.RUKON_Round(@outGrossAmount*@ConversionRate, 2)

    insert into #RepoCashFlows
       (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
    values
       (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)

  end

/* ##############################  EOF  MOEX Repo with Equities 4 digits rounding   ###################################   */




/* ##############################  MOEX Repo with Equities 6 digits rounding   ###################################   */


  if @FwdPriceMethod = '6' and @Equities_Id > 0
  begin
    select @outGrossAmount = @Quantity*@Price
    select @outForwardAmount = (1+@FixedRate/100*@YF)*@Quantity*@Price
    select @outForwardPrice = round(@outForwardAmount/@Quantity,6)
    select @outForwardAmount = round(@outForwardPrice*@Quantity,2)

    select
    PriceCw           = @Price,
    WeightedAmount    = @Price*@Quantity,
    ForwardPrice      = @outForwardPrice,
    DirtyPrice2       = @outForwardPrice,
    GrossAmount2      = @outForwardAmount,
    ForwardAmount     = @outForwardAmount

    select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * round(@outGrossAmount * @ConversionRate,2)

    insert into #RepoCashFlows
       (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
    values
       (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)

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

  end


/* ##############################  EOF  MOEX Repo with Equities 6 digits rounding   ###################################   */



/* ##############################  OTC Repo from Bloomberg ###################################   */
/*
--20170601 start
if @FwdPriceMethod = '7' and @Trigger not in ('WeightedAmount','Quantity','FaceAmount')
begin
  declare    @BasisValue  int
  declare    @corr005    float
  select @corr005=0.00002
  select @BasisValue =(case  when charindex('360',v.ItemDisplayName)>0 then 360 else 365 end)
  from kplus..KdbChoicesValues v
  join kplus..KdbChoices c on c.KdbChoices_Id=v.KdbChoices_Id
  where c.KdbChoices_Name='Basis'
  and v.InternalValue=@Basis

  declare @SD datetime

  if @SettlementDate2 is null
  begin
    select @SD= dateadd(day,n.NoDays,getdate())
    from kplus..RepoDeals d
    join RepoDealsEx ed on ed.DealId=d.RepoDeals_Id
    join kplus..CallNotices n on n.CallNotices_Id=d.CallNotices_Id
    where d.RepoDeals_Id=@Deals_Id
   end

  else
      begin
      set @SD=@SettlementDate2
      end

  select ForwardAmount=WeightedAmount2+round(round(WeightedAmount2/@ConversionRate*@FixedRate/100*datediff(day,@SettlementDate,@SD)/@BasisValue+@corr005,2)*@ConversionRate+@corr005,2)
  ,WeightedAmount=WeightedAmount2
  ,AccruedAmount=AccruedAmount
  from RepoDealsEx
  where DealId=@Deals_Id
  and (SettlementDate2 is null or @Trigger in ('Basis','FixedRate','MaturityDate','SettlementDate2'))
  --and (SettlementDate2 is null or @Trigger in ('Basis','FixedRate'))

  --for closed Repo
  select ForwardAmount=ForwardAmount2,
         WeightedAmount=WeightedAmount2,
         AccruedAmount=AccruedAmount
  from RepoDealsEx
  where DealId=@Deals_Id
  and SettlementDate2 is not null
  and @Trigger not in ('Basis','FixedRate','MaturityDate','SettlementDate2')
  --and @Trigger not in ('Basis','FixedRate')


  insert  #RepoCashFlows (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
  select @SettlementDate,@SettlementDate,@SettlementDate,'N'
      ,0
      ,(case when @DealType in ('B', 'V') then -1 else 1 end) * ed.WeightedAmount2
      ,0
  from RepoDealsEx ed
  where ed.DealId=@Deals_Id

  insert  #RepoCashFlows (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
  select @SD, @SD, @SD,'N'
      ,0
      ,(case when @DealType in ('B', 'V') then 1 else -1 end) * ed.WeightedAmount2
      ,0
  from RepoDealsEx ed
  where ed.DealId=@Deals_Id


   insert  #RepoCashFlows (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
  select @SettlementDate, @SD, @SD,'I'
      ,(case when @DealType in ('B', 'V') then -1 else 1 end) * ed.WeightedAmount2
      ,(case when @DealType in ('B', 'V') then 1 else -1 end) * round(round(ed.WeightedAmount2/@ConversionRate*@FixedRate/100*datediff(day,@SettlementDate,@SD)/@BasisValue+@corr005,2)*@ConversionRate+@corr005,2)
      ,@FixedRate
  from RepoDealsEx ed
  where ed.DealId=@Deals_Id
      and (ed.SettlementDate2 is null or @Trigger in ('Basis','FixedRate','MaturityDate','SettlementDate2'))

  insert  #RepoCashFlows (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
  select @SettlementDate, @SD, @SD,'I'
      ,(case when @DealType in ('B', 'V') then -1 else 1 end) * ed.WeightedAmount2
      ,ed.ForwardAmount2-ed.WeightedAmount2
      ,@FixedRate
  from RepoDealsEx ed
  where ed.DealId=@Deals_Id
      and ed.SettlementDate2 is not null
      and @Trigger not in ('Basis','FixedRate','MaturityDate','SettlementDate2')
end
--20170601 end
*/
/* ############################## EOF OTC Repo from Bloomberg ###################################   */


delete from RUKON_RepoSchedule
where RepoDeals_Id=@Pid

update RUKON_RepoSchedule
  set Pid=0 where Pid=@Pid

insert RUKON_RepoSchedule
select
  @Deals_Id,
  StartDate,
  EndDate,
  PaymentDate,
  CashFlowType,
  Principal,
  CashFlow,
  Rate,
  @Pid
from  #RepoCashFlows

select "comment"=" notify, deald "+convert(varchar(15),@Deals_Id) + " pid: "+convert(varchar(15),@Pid)
select "RRPid"=@Pid
select "RRDFUpd"="N"

--SELECT @Message = convert(varchar(20), @Bonds_Id) + "#" + @DealType + "#" + convert(varchar(20), @Quantity) + "#" + convert(varchar(20), @ConversionRate) + "#" +  @FwdPriceMethod

 -- exec kplus..SendMail "KPLUS", "KPLUS", @Basis
end

go



GRANT EXEC ON RUKON_RepoDealsProcess TO PUBLIC 
go

