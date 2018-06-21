USE Kustom
GO
IF OBJECT_ID('dbo.RepoDealsNotify') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.RepoDealsNotify
    IF OBJECT_ID('dbo.RepoDealsNotify') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.RepoDealsNotify >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.RepoDealsNotify >>>'
END

/*################################# IMPORTANT DEVELOPMNET NOTES ###############################################################

PDA. 21.06.2018
In the latest version of the procedure used in BCS as of today some of the standard or legacy Reuters SQL functions have been replaced by Systematica functions delivered as part of Radius package. Here is the list of functions concerned:

1) PYearFractionSimple() replaced by Radius_Lib_YearFraction_Get()
2) round() replaced by Radius_Lib_Round
3) RTR_BondsDealsAccrued replaced by Radius_Lib_BondAccrued

*/################################# IMPORTANT DEVELOPMNET NOTES ################################################################

GO
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
   @CapturedDiscount                      char(1),
   @Cur int
)
AS
BEGIN
  DECLARE
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
  @MC_Ccy_Id                   int,
  @MC_Asset                    char(3),
  @MC_Rate                     float,
  @MC_Comments                 varchar(64), 
  @DownloadKey                 varchar(30),
  @PrincipalCashFlow           float,
  @Rate                        float,
  @Mult                        float  ,
  @Currencies_Id               int,
  @Currencies_ShortName        varchar(3),
  @Message                     varchar(200),
  @Help                        float

  /* BY PDA. Currency Conversion handling, to be reviewed.
     -- Проверяем валютную пару: если пара валюта цены к валюте сделки Indirect, то переворачиваем ConversionRate
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

  SELECT @Mult = CASE @CapturedDiscount
                WHEN 'D' THEN (1 - @Discount / 100)
                WHEN 'H' THEN (100 / @Haircut)
                ELSE 1 END

-- END OF Discount vs Haircut handing


-- Dates AND values coherency check

  IF @ValueDate IS NULL OR @MaturityDate IS NULL
    RETURN

  -- Repo with a Bond should mature at least 1 day prior the Bond's maturity
  IF @MaturityDate > (SELECT MaturityDate FROM kplus..Bonds WHERE Bonds_Id = @Bonds_Id) - 1
  BEGIN
    SELECT _MESSAGE_ = MaturityDate, "MaturityDate must be at least 1 day less than Bond's maturity!"
    RETURN

  SELECT @SettlementDate2 = isnull(@SettlementDate2, @MaturityDate)
  SELECT SettlementDate2 = isnull(@SettlementDate2, @MaturityDate)
  SELECT @SettlementDate = isnull(@SettlementDate, @ValueDate)
  SELECT SettlementDate = isnull(@SettlementDate, @ValueDate)

  IF (datediff(DAY, @ValueDate, @MaturityDate) <= 0)
    RETURN

  IF (datediff(DAY, @SettlementDate, @SettlementDate2) <= 0)
    RETURN

  IF ISNULL (@Bonds_Id, 0) = 0
    RETURN

  IF ISNULL(@Price, 0) = 0
    RETURN

  IF ISNULL(@Quantity, 0) = 0
    RETURN

  IF ISNULL(@ConversionRate, 0.0) = 0.0
    RETURN

  IF ISNULL(@Cur, 0) = 0
    RETURN

-- END OF Dates AND values coherency check

  SELECT @Currencies_Id = Currencies_Id
  FROM kplus..Bonds
  WHERE Bonds_Id = @Bonds_Id

  SELECT @Currencies_ShortName = Currencies_ShortName
  FROM kplus..Currencies
  WHERE Currencies_Id = @Cur


  SELECT Currencies_Id = @Currencies_Id
  SELECT CurAccr1 = @Currencies_ShortName
  SELECT CurAccr2 = @Currencies_ShortName
  SELECT CurGA1 = @Currencies_ShortName
  SELECT CurGA2 = @Currencies_ShortName
  SELECT CurWA = @Currencies_ShortName
  SELECT CurFA = @Currencies_ShortName

  DECLARE cBondsCF CURSOR FOR
  SELECT PaymentDate, sum(CashFlow)
  FROM  kplus..BondsSchedule
  WHERE   Bonds_Id = @Bonds_Id
  AND EndDate > @SettlementDate
  AND EndDate <= @SettlementDate2
  AND CashFlowType IN ("I", "N")
  GROUP BY PaymentDate
  ORDER BY 1

-- Deafault Forward Price Method is "D"
  SELECT @FwdPriceMethod = ISNULL(@FwdPriceMethod, 'D')


  SELECT @Principal1 = FaceValue,
         @Principal2 = FaceValue
  FROM   kplus..Bonds
  WHERE  Bonds_Id = @Bonds_Id

-- Custom Accrued Interest calculation for the near and far Repo legs
-- Near leg Accrued
  IF @Bonds_Id > 0 AND @SettlementDate IS NOT NULL AND @Quantity > 0
  BEGIN
      --BY PDA. Legacy Reuters Method: exec RTR_BondsDealsAccrued @Bonds_Id, @Quantity, @SettlementDate,  @AC_Method, @outAccruedAmount output, @outAccrued output
      EXEC Radius_Lib_BondAccrued @Bonds_Id, @Quantity, @SettlementDate, @outAccruedAmount OUTPUT, @outAccrued OUTPUT

      -- BY PDA. IGNORING @AdjFactor, needed for CPI Bonds only
      /* if @AdjFactor is null
      begin
         -- рассчитаем @AdjFactor на дату SettlementDate сделки
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

    
    SELECT @Principal1 = @Principal1 - ISNULL(sum(CashFlow),0)
    FROM   kplus..BondsSchedule
    WHERE  Bonds_Id = @Bonds_Id
    AND    EndDate <= @SettlementDate
    AND    CashFlowType = 'N'

    --BY PDA. Legacy Sysatematica method:
    --SELECT @outGrossAmount = (@Principal1 * @Quantity * @Price / 100 + @outAccruedAmount)
    SELECT @outGrossAmount = dbo.Radius_Lib_Round(@Principal1 * @Quantity * @Price / 100 + @outAccruedAmount, 2, 'R')

    --BY BCS: 20171001 start m1
    IF ISNULL(@FwdPriceMethod,'D') = 'Z'
    SELECT @outGrossAmount = @Principal1 * @Quantity * (@Price+@outAccrued) / 100
    --20171001 end m1
  END
   --END OF near leg accrued


  --Far leg Accrued
  IF @Bonds_Id > 0 AND @SettlementDate2 IS NOT NULL AND @Quantity > 0
  BEGIN
      --BY PDA. Legacy Reuters Method: exec RTR_BondsDealsAccrued @Bonds_Id, @Quantity, @SettlementDate2, @AC_Method,  @outAccruedAmount2 output, @outAccrued2 output
      EXEC Radius_Lib_BondAccrued @Bonds_Id, @Quantity, @SettlementDate2, @outAccruedAmount2 OUTPUT, @outAccrued2 OUTPUT

    -- BY PDA. IGNORING @AdjFactor, needed for CPI Bonds only
    /*
    -- если @FwdAdjFactor не передан
    if @FwdAdjFactor is null
    begin
       -- рассчитаем @FwdAdjFactor на дату SettlementDate2 сделки
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

    SELECT @Principal2 = @Principal2 - ISNULL(sum(CashFlow),0)
    FROM   kplus..BondsSchedule
    WHERE  Bonds_Id = @Bonds_Id
    AND    EndDate <= @SettlementDate2
    AND    CashFlowType = 'N'
  END
  -- END OF far leg accrued

  -- Calculating Year fraction between Value date and Maturity date
  IF @MaturityDate IS NOT NULL AND @ValueDate IS NOT NULL
  --BY PDA. Legacy Reuters Method: exec PYearFractionSimple @ValueDate, @MaturityDate, @Basis, 'A',  @YF output
    BEGIN
      EXEC Radius_Lib_YearFraction_Get
         @StartDate     = @ValueDate,
         @EndDate       = @MaturityDate,
         @Basis         = @Basis,
         @YearFraction  = @YF OUTPUT
   END
  -- END OF Calculating Year fraction between Value date and Maturity date

-- Temporary table for storing custom Repo cash flows
  CREATE TABLE #RepoCashFlows
  (
    Record_Id         numeric(3)   IDENTITY,
    StartDate         datetime     NOT NULL,
    EndDate           datetime     NOT NULL,
    PaymentDate       datetime     NOT NULL,
    CashFlowType      char(1)      NOT NULL,
    Principal         float        NOT NULL,
    CashFlow          float        NULL,
    Rate              float        NULL,
    Comments          varchar(64)  NULL
   )


  IF @FwdPriceMethod = 'B'
  BEGIN
    SELECT
      @FwdPriceMethod   = 'D',
      @BalancedDiscount = 'Y'
  END
  ELSE
  BEGIN
    SELECT @BalancedDiscount = 'N'
  END

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
--16  V ВТБ (Start Price)
--17  P ВТБ (MarketPrice)

/* ##############################    MOEX Repo with Bonds   ###################################   */

  IF @FwdPriceMethod = 'M' AND @Bonds_Id > 0 AND @outAccruedAmount IS NOT NULL AND @outAccruedAmount2 IS NOT NULL
  BEGIN
      -- On Value Date CashFlow should be equal to Weighted Amount      
    SELECT @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @ConversionRate, 2, 'R')      

    INSERT INTO #RepoCashFlows
       (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
    VALUES
       (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)

    SELECT @outForwardAmount = @outGrossAmount * (1 + @YF*@FixedRate/100)
   
   /*
    If there were coupon pay offs during Repo life then Repo Forward Amont should be decreased by the total
    amount of the payments considering coupon growth rate
    */

    IF @IgnoreCouponPayments = 'B'
    BEGIN
      SELECT @AC_Method = isnull(min(substring(Method,1,1)),'G') from RTR_CW_BondsCouponParam
      WHERE DealId = @Bonds_Id and DealType = 'Bonds'

      OPEN cBondsCF
      FETCH cBondsCF INTO @CashFlowDate, @CashFlow
      WHILE (@@sqlstatus = 0)
      BEGIN
        IF @AC_Method = 'C'
        BEGIN
          -- BY PDA. Legacy Systematica Method: SELECT @CashFlow = round(@CashFlow,2) --Rounding coupon by 2 digits
          SELECT @CashFlow = dbo.Radius_Lib_Round(@CashFlow, 2, 'R')
        END        
        EXEC Radius_Lib_YearFraction_Get
             @StartDate     = @CashFlowDate,
             @EndDate       = @MaturityDate,
             @Basis         = @Basis,
             @YearFraction  = @YF_cf output

        SELECT @outForwardAmount = @outForwardAmount - @Quantity*@CashFlow*(1+@YF_cf*@ReinvCouponRate/100)

        -- Inserting the intermediate Cash Flow into the temporary CF Table
        SELECT @CashFlow = (CASE WHEN @DealType IN ('B', 'V') THEN 1 ELSE -1 END) * round(@Quantity*@CashFlow*@ConversionRate, 2)
        
        SELECT @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
        INSERT INTO #RepoCashFlows
           (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
        VALUES
           (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0)

      FETCH cBondsCF INTO @CashFlowDate, @CashFlow
      END
      CLOSE cBondsCF
      DEALLOCATE CURSOR cBondsCF

    END

    /*
    If there were margin calls during the Repo life they need to be handled and the deal's CF updated accordingly
    */

    DECLARE cMarginCallCF CURSOR  FOR
            SELECT e.ValueDate, e.Quantity, mc.FixedRate, e.Assets_Id, e.AssetType, 
            'МС' + convert(varchar,mc.RadiusMarginCalls_Id) + ' ' + mc.Comments + ' ' + e.Comments
            FROM   RadiusMarginCallsExecs e, RadiusMarginCalls mc
            WHERE  e.ContextType = 'RepoDeals'
            AND    e.Context_Id = @Deals_Id
            AND    e.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id
            ORDER BY 1

    OPEN cMarginCallCF
    FETCH cMarginCallCF INTO @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments
    WHILE (@@sqlstatus = 0)
    BEGIN
      IF @MC_Asset = 'CCY' AND  @MC_Ccy_Id <> @Currencies_Id_Price
      BEGIN
      EXEC Radius_GetCurrency_Rate
          @Currencies_Id_1 = @Currencies_Id_Price,
          @Currencies_Id_2 = @MC_Ccy_Id,
          @RateDate = @CashFlowDate,
          @Rate = @MC_Rate OUT,
          @QuoteType = 'F',
          @GoodOrder = 'Y'
      END
      ELSE
      BEGIN
         SELECT  @MC_Rate = @ConversionRate
      END

      EXEC Radius_Lib_YearFraction_Get
           @StartDate     = @CashFlowDate,
           @EndDate       = @MaturityDate,
           @Basis         = @Basis,
           @YearFraction  = @YF_cf output

      -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги
      SELECT @outForwardAmount = @outForwardAmount - @CashFlow/@MC_Rate*(1+@YF_cf*@FixedRate/100) * (CASE WHEN @DealType IN ('S', 'R') THEN -1 ELSE 1 END)

      -- **alex**
      SELECT @CashFlow = @CashFlow/@MC_Rate
      -- Inserting the Margin Call Cash Flow into the temporary CF Table      
      SELECT @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
      
      INSERT INTO #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comments)
      VALUES
         (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)

      FETCH cMarginCallCF INTO @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

    END -- while (@@sqlstatus = 0)

    CLOSE cMarginCallCF
    DEALLOCATE CURSOR cMarginCallCF

    /*
    END OF Margin Calls handing
    */
                                                           
    SELECT @outForwardAmount = dbo.Radius_Lib_Round(@outForwardAmount, 2, 'R')
    SELECT @outGrossAmount2 = dbo.Radius_Lib_Round(@outForwardAmount, 2, 'R')
    SELECT @outDirtyPrice2 = @outGrossAmount2 / @Quantity / @Principal2 * 100
    
    /* ###############################  */
    SELECT @Help = @outDirtyPrice2
    /* #################################  */

    SELECT @outForwardPrice = dbo.Radius_Lib_Round(@outDirtyPrice2 - @outAccrued2, 4, 'R')
    SELECT @outDirtyPrice2 = @outForwardPrice + @outAccrued2
    SELECT @outForwardAmount = dbo.Radius_Lib_Round(@outDirtyPrice2*@Quantity*@Principal2/100, 2, 'R')
    SELECT @outGrossAmount2 = dbo.Radius_Lib_Round(@outForwardAmount, 2, 'R')

      -- On Maturity Date Principal CashFlow equals to WeightedAmount minus all intermediate payments
      INSERT INTO #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      VALUES
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)

      -- On Maturity Date Interest CashFlow equals to ForwardAmount minus the Principal CashFlow above
      SELECT @CashFlow = (CASE WHEN @DealType IN ('B', 'V') THEN 1 ELSE -1 END) * dbo.Radius_Lib_Round(@outForwardAmount*@ConversionRate, 2, 'R') + @PrincipalCashFlow,
             @outWeightedAmount = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R')

      INSERT INTO #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      VALUES
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)


      SELECT
      Accrued           = @outAccrued,
      MarginCallKnockOut     = @Help,
      DirtyPrice        = @outAccrued + @Price,
      GrossAmount1      = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R'),2),
      AccruedCash     = dbo.Radius_Lib_Round(@outAccruedAmount*@ConversionRate, 2, 'R'),
      WeightedAmount    = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R'),
      ForwardPrice2      = @outForwardPrice,
      Accrued2          = @outAccrued2,
      DirtyPrice2       = @outDirtyPrice2,
      GrossAmount2      = dbo.Radius_Lib_Round(@outGrossAmount2*@ConversionRate, 2, 'R'),
      Accrued2Cash    = dbo.Radius_Lib_Round(@outAccruedAmount2*@ConversionRate, 2, 'R'),
      ForwardAmount2     = dbo.Radius_Lib_Round(@outForwardAmount*@ConversionRate, 2, 'R'),
      Prepayment        = dbo.Radius_Lib_Round((CASE @NeedPrepayment WHEN 'Y' THEN @outGrossAmount*@Discount/100 ELSE 0 END)*@ConversionRate, 2, 'R')
      FixedRate2 = @FixedRate
  END


/*

/* Adaptive Server has expanded all '*' elements in the following statement */ SELECT #RepoCashFlows.Record_Id, #RepoCashFlows.StartDate, #RepoCashFlows.EndDate, #RepoCashFlows.PaymentDate, #RepoCashFlows.CashFlowType, #RepoCashFlows.Principal, #RepoCashFlows.CashFlow, #RepoCashFlows.Rate FROM #RepoCashFlows

*/


DECLARE @Max int,
  @RepoDeals_Id int
SELECT @Max= max(RepoDeals_Id) FROM kplus..RepoDeals
SELECT @RepoDeals_Id = @Max + 1

DELETE FROM RussianReposCashFlows
WHERE RepoDeals_Id = @RepoDeals_Id

INSERT RussianReposCashFlows
SELECT @RepoDeals_Id,
  StartDate,
  EndDate,
  PaymentDate,
  CashFlowType,
  Principal,
  CashFlow,
  Rate
FROM  #RepoCashFlows


SELECT @Message = convert(varchar(20), @Bonds_Id) + "#" + @DealType + "#" + convert(varchar(20), @Quantity) + "#" + convert(varchar(20), @ConversionRate) + "#" +  @FwdPriceMethod

 -- exec kplus..SendMail "KPLUS", "KPLUS", @Basis
GO
EXEC sp_procxmode 'dbo.RepoDealsNotify', 'unchained'
GO
IF OBJECT_ID('dbo.RepoDealsNotify') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.RepoDealsNotify >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.RepoDealsNotify >>>'
GO
REVOKE EXECUTE ON dbo.RepoDealsNotify FROM PUBLIC
GO
GRANT EXECUTE ON dbo.RepoDealsNotify TO PUBLIC
GO
