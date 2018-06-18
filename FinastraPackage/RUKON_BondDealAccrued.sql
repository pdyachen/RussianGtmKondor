USE Kustom
GO
IF OBJECT_ID('dbo.RUKON_BondDealAccrued') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.RUKON_BondDealAccrued
    IF OBJECT_ID('dbo.RUKON_BondDealAccrued') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.RUKON_BondDealAccrued >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.RUKON_BondDealAccrued >>>'
END
GO
CREATE PROC RUKON_BondDealAccrued
(
@Bonds_Id                   integer,
@Quantity                   float,
@CalcDate                   datetime,
@AC_Method           varchar(20),
@AccruedInterestAmount      float OUTPUT,
@AccruedInterestPercent     float OUTPUT
)
AS
BEGIN

DECLARE
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

-- Return 0 for accrued values if securities quantity = 0
IF isnull(@Quantity, 0) = 0
BEGIN
  SELECT @AccruedInterestAmount = 0,
         @AccruedInterestPercent = 0
  RETURN
END

SELECT @CouponRoundingConv = CouponRoundingConv,
       @CouponRoundingType = CouponRoundingType,
       @CouponFrequency = CouponFrequency,
       @MaturityDate = MaturityDate
FROM kplus.dbo.Bonds
WHERE Bonds_Id = @Bonds_Id

-- Return 0 for accrued values if the bond is matured
IF @MaturityDate <= @CalcDate
BEGIN
  SELECT @AccruedInterestAmount = 0,
         @AccruedInterestPercent = 0
  RETURN
END

SELECT @Principal = Principal,
      @Basis = AccruedBasis,
      @CouponCashFlow = CashFlow,
      @CouponStartDate = StartDate,
      @CouponEndDate = EndDate,
      @CouponRate = Rate
FROM kplus.dbo.BondsSchedule
WHERE Bonds_Id = @Bonds_Id
AND StartDate <= @CalcDate
AND EndDate > @CalcDate

-- Return 0 for accrued values if calculation date equals to coupon date
IF datediff(DAY, @CouponStartDate, @CalcDate) = 0
BEGIN
  SELECT @AccruedInterestAmount = 0,
         @AccruedInterestPercent = 0
  RETURN
END

-- Return 0 for accrued values if Principal is zero
IF isnull(@Principal,0) = 0
BEGIN
  SELECT @AccruedInterestAmount = 0,
         @AccruedInterestPercent = 0
  RETURN
END

EXEC PYearFractionSimple @CouponStartDate, @CalcDate, @Basis, @YF OUTPUT

-- GlobalNominal
IF (@AC_Method = 'G' OR @AC_Method IS NULL) AND @CouponRoundingType = 'R'
BEGIN
  SELECT @AccruedInterestPercent = round(@CouponRate*@YF, @CouponRoundingConv)
  SELECT @AccruedInterestAmount = @Quantity * @Principal * @AccruedInterestPercent/100
END

ELSE IF (@AC_Method = 'G' OR @AC_Method IS NULL) AND @CouponRoundingType = 'T'
BEGIN
  SELECT @AccruedInterestPercent = floor(@CouponRate*@YF*power(10,@CouponRoundingConv))/power(10,@CouponRoundingConv)
  SELECT @AccruedInterestAmount = @Quantity * @Principal * @AccruedInterestPercent/100
END

-- Unit coupon
ELSE IF @AC_Method = 'C' AND @CouponRoundingType = 'R'
BEGIN
  SELECT @AccruedInterestAmount = @Quantity * round(@Principal * @CouponRate/100 * @YF, 2)
  SELECT @AccruedInterestPercent = round(100*@AccruedInterestAmount/@Quantity/@Principal, @CouponRoundingConv)
END

ELSE IF @AC_Method = 'C' AND @CouponRoundingType = 'T'
BEGIN
  SELECT @AccruedInterestAmount = @Quantity * round(@Principal * @CouponRate/100 * @YF, 2)
  SELECT @AccruedInterestPercent = floor(100*@AccruedInterestAmount/@Quantity/@Principal*power(10,@CouponRoundingConv))/power(10,@CouponRoundingConv)
END

-- Unit percentage
ELSE IF @AC_Method = 'P' AND @CouponRoundingType = 'R'
BEGIN
  SELECT @AccruedInterestPercent = round(@CouponCashFlow/@Principal*datediff(dd,@CouponStartDate,@CalcDate)/
                                         datediff(dd,@CouponStartDate,@CouponEndDate)*100, @CouponRoundingConv)
  SELECT @AccruedInterestAmount = @Quantity * @AccruedInterestPercent/100 * @Principal
END

ELSE IF @AC_Method = 'P' AND @CouponRoundingType = 'T'
BEGIN
  SELECT @AccruedInterestPercent = floor(@CouponCashFlow/@Principal*datediff(dd,@CouponStartDate,@CalcDate)/
                                         datediff(dd,@CouponStartDate,@CouponEndDate)*power(10,@CouponRoundingConv)*100)
                                         /power(10,@CouponRoundingConv)
  SELECT @AccruedInterestAmount = @Quantity * @AccruedInterestPercent/100 * @Principal
END

-- Russian goverment bonds
ELSE IF @AC_Method = 'M' AND @CouponRoundingType = 'R'
BEGIN
  SELECT @AccruedInterestAmount = round(@CouponCashFlow*datediff(dd,@CouponStartDate,@CalcDate)/
                                         datediff(dd,@CouponStartDate,@CouponEndDate), 2) * @Quantity
  SELECT @AccruedInterestPercent = round(@AccruedInterestAmount / @Quantity / @Principal * 100, @CouponRoundingConv)
END


END

DECLARE @Message varchar(100)
SELECT @Message = convert(varchar(20), @AccruedInterestPercent) + "-" + convert(varchar(20), @AccruedInterestAmount) + "-" + convert(varchar(20), @YF) + "-" + @AC_Method
-- EXEC kplus..SendMail "KPLUS", "KPLUS", @Message

-- SELECT @AccruedInterestAmount
-- SELECT @AccruedInterestPercent
GO
EXEC sp_procxmode 'dbo.RUKON_BondDealAccrued', 'unchained'
GO
IF OBJECT_ID('dbo.RUKON_BondDealAccrued') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.RUKON_BondDealAccrued >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.RUKON_BondDealAccrued >>>'
GO
REVOKE EXECUTE ON dbo.RUKON_BondDealAccrued FROM PUBLIC
GO
GRANT EXECUTE ON dbo.RUKON_BondDealAccrued TO PUBLIC
GO
