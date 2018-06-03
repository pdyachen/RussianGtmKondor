IF OBJECT_ID ('dbo.Radius_RepoDealsNotify') IS NOT NULL													
	DROP PROCEDURE dbo.Radius_RepoDealsNotify												
GO													
													
create procedure Radius_RepoDealsNotify													
(													
   @Deals_Id                              int,													
   @DealType                              char(1),													
   @RepoType                              char(1),													
   @Bonds_Id                              int,													
   @Equities_Id                           int,													
   @Cpty_Id                               int,													
   @TradeDate                             datetime,													
   @ValueDate                             datetime,													
   @SettlementDate                        datetime,													
   @MaturityDate                          datetime,													
   @SettlementDate2                       datetime,													
   @Price                                 float,													
   @Accrued                               float,													
   @Accrued2                              float,													
   @Quantity                              float,													
   @Discount                              float,													
   @FixedRate                             float,													
   @Basis                                 char(1),													
   @IgnoreCouponPayments                  char(1),													
   @ReinvCouponRate                       float,													
   @Currencies_Id                         int,													
   @Currencies_Id_Price                   int,													
   @ConversionRate                        float,													
   @ClearingModes_Id                      int,													
   @ClearingModes_Id_Cpty                 int,													
   @NeedPrepayment                        char(1),													
   @FwdPriceMethod                        char(1),													
   @TriggeredField                        varchar(32),													
   @Haircut                               float,													
   @CapturedDiscount                      char(1)  -- H/D													
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
   @Mult                        float													
													
													
   declare cBondsCF cursor for													
      select PaymentDate, sum(CashFlow)													
      from   kplus..BondsSchedule													
      where  Bonds_Id = @Bonds_Id													
      and    EndDate > @SettlementDate													
      and    EndDate <= @SettlementDate2													
      and    CashFlowType in ('I', 'N')													
      group by PaymentDate													
      order by 1													
													
   declare cMarginCallCF cursor for													
      select e.ValueDate, e.Quantity, mc.FixedRate													
      from   RadiusMarginCallsExecs e, RadiusMarginCalls mc													
      where  e.ContextType = 'RepoDeals'													
      and    e.Context_Id = @Deals_Id													
      and    e.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id													
      order by 1													
													
begin													
--   insert into OutputInfo values(@TriggeredField)													
/*													
   if @TriggeredField = 'Cpty' or @FwdPriceMethod is null -- если метод расчета не определен, читаем его из параметров контрагента													
      select @FwdPriceMethod = RepoFwdPriceMethod													
        from RTR_CW_Cpty where DealId = @Cpty_Id													
													
   if @TriggeredField = 'Cpty'													
      select @FwdPriceMethod as FwdPriceMethod													
													
   -- Если метод расчета не задан, то ничего не делаем													
   if @FwdPriceMethod is null													
      return													
*/													
   select @FwdPriceMethod = isnull(@FwdPriceMethod, 'D')													
   select @FwdPriceMethod as FwdPriceMethod													
													
   select @Mult = case @CapturedDiscount when 'D' then (1 - @Discount/100) when 'H' then (100/@Haircut) else 1 end													
													
     -- находим начальный номинал облигации													
   select @Principal1 = FaceValue, @Principal2 = FaceValue													
   from   kplus..Bonds where Bonds_Id = @Bonds_Id													
													
   -- Всегда в начале пересчитываем для облигаций купон в соответствии с дополнительными настройками													
   if @Bonds_Id > 0 and @SettlementDate is not null and @Quantity > 0													
   begin													
      -- вычисляем новую сумму купона для первой ноги													
      exec RTR_BondsDealsAccrued @Bonds_Id, @Quantity, @SettlementDate, @outAccruedAmount output, @outAccrued output													
													
      select @Principal1 = @Principal1 - isnull(sum(CashFlow),0)													
      from   kplus..BondsSchedule													
      where  Bonds_Id = @Bonds_Id													
      and    EndDate <= @SettlementDate													
      and    CashFlowType = 'N'													
													
      if @outAccrued is null													
      begin													
         exec Radius_Bonds_CalcAccrued @Bonds_Id, null, @ValueDate, @SettlementDate, @outAccrued output													
         select @outAccruedAmount = round(@Principal1 * @outAccrued / 100, 2)													
      end													
													
      select @outGrossAmount = (@Principal1 * @Quantity * @Price / 100 + @outAccruedAmount)													
													
   end													
													
   if @Bonds_Id > 0 and @SettlementDate2 is not null and @Quantity > 0													
   begin													
      -- вычисляем новую сумму купона для второй ноги													
      exec RTR_BondsDealsAccrued @Bonds_Id, @Quantity, @SettlementDate2, @outAccruedAmount2 output, @outAccrued2 output													
													
      select @Principal2 = @Principal2 - isnull(sum(CashFlow),0)													
      from   kplus..BondsSchedule													
      where  Bonds_Id = @Bonds_Id													
      and    EndDate <= @SettlementDate2													
      and    CashFlowType = 'N'													
													
      if @outAccrued2 is null													
      begin													
         exec Radius_Bonds_CalcAccrued @Bonds_Id, null, @MaturityDate, @SettlementDate2, @outAccrued2 output													
         select @outAccruedAmount2 = round(@Principal2 * @outAccrued2 / 100, 2)													
      end													
													
   end													
													
   if @MaturityDate is null or @ValueDate is null													
      return													
													
   -- вычисляем Year Fraction													
   if @MaturityDate is not null and @ValueDate is not null													
      exec PYearFractionSimple @ValueDate, @MaturityDate, @Basis, 'A',  @YF output													
													
   -- таблица CashFlows по сделке репо													
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
													
   -- Метод для коррекции CashFlow по сделкам загруженным с биржи													
   if @FwdPriceMethod = 'C' and @Deals_Id is not null													
   begin													
													
      -- 0) читаем параметры сделки из базы данных													
      select @outWeightedAmount = (case DealType when 'B' then -1 else 1 end) * WeightedAmount,													
             @PrincipalCashFlow = (case DealType when 'B' then -1 else 1 end) * WeightedAmount,													
             @DownloadKey = DownloadKey,													
             @DealType = DealType													
      from   RepoDealsAll													
      where  RepoDeals_Id = @Deals_Id													
													
      select @outForwardAmount = (case when @DealType in ('B', 'V') then 1 else -1 end) * ForwardAmount2,													
             @Rate = FixedRate2													
      from   RepoDealsEx													
      where  DealType = 'RepoDeals'													
      and    DealId = @Deals_Id													
													
      -- 1) В ValueDate сумма CashFlow равна WeightedAmount													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @outWeightedAmount, 0)													
													
      -- 2) Все промежуточные выплаты ложатся в CashFlow, как выплаты Principal в даты, когда эти выплаты происходили													
      -- Эти промежуточные выплаты мы читаем из двух источников:													
      --   а) CashFlowDeals с типом инструмента 'REPO_CF (REPO DOWNPAYMENT)'													
      --   б) Исполнение Margin Calls													
													
      declare cDownPayments cursor for													
         select PaymentDate, CashFlow, 'N'													
         from   kplus..CashFlowSchedule cf, kplus..CashFlowDeals d													
         where  cf.CashFlowDeals_Id = d.CashFlowDeals_Id													
         and    d.DealStatus = 'V'													
         and    d.PaymentComments = @DownloadKey -- ссылку на сделку репо храним в поле PaymentComments													
         and    d.TypeOfInstr_Id = (select TypeOfInstr_Id from kplus..TypeOfInstr where TypeOfInstr_ShortName = 'REPO_CF')													
         union													
         select ValueDate, Quantity, 'F'													
         from   RadiusMarginCallsExecs													
         where  ContextType = 'RepoDeals'													
         and    Context_Id = @Deals_Id													
         order by 1													
													
      open cDownPayments													
      fetch cDownPayments into @CashFlowDate, @CashFlow, @CashFlowType													
													
      while (@@sqlstatus = 0)													
      begin													
         insert into #RepoCashFlows													
            (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
         values													
            (@CashFlowDate, @CashFlowDate, @CashFlowDate, @CashFlowType, 0, @CashFlow, 0)													
													
         select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow													
													
         fetch cDownPayments into @CashFlowDate, @CashFlow, @CashFlowType													
      end													
													
      close cDownPayments													
      deallocate cursor cDownPayments													
													
      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)													
													
      -- 4) На MaturityDate записывается Interest CashFlow равный разнице ForwardAmount и Principal CashFlow из пункта 3													
      select @CashFlow = @outForwardAmount + @PrincipalCashFlow													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
--         (@MaturityDate, @MaturityDate, @MaturityDate, 'F', 0, @CashFlow, 0)													
-- KIS иногда пересчитывает сумму CashFlow c типом I, поэтому приходится ее класть таким кривым образом вместо правильного:													
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', abs(@outWeightedAmount), @CashFlow, @Rate)													
													
   end													
													
   -- Проводим стандартные вычисления для облигаций если сумма купона была пересчитали													
   if isnull(@FwdPriceMethod,'D') = 'D' and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null													
   begin													
													
      -- 1) В ValueDate сумма CashFlow равна WeightedAmount													
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * round(@outGrossAmount * @Mult * @ConversionRate,2)													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)													
													
      select @outForwardAmount = round(@outGrossAmount * @Mult * (1 + @YF*@FixedRate/100), 2)													
													
      -- если были выплаты и они достались покупателю, то сумму @ForwardAmount надо уменьшить на сумму выплат													
      -- с учетом прироста этих выплат по ставке реинвестирования купона.													
      if @IgnoreCouponPayments = 'B'													
      begin													
         select @AC_Method = isnull(min(substring(Method,1,1)),'G')													
         from   RTR_CW_BondsCouponParam													
         where  DealId = @Bonds_Id and DealType = 'Bonds'													
         open cBondsCF													
         fetch cBondsCF into @CashFlowDate, @CashFlow													
         while (@@sqlstatus = 0)													
         begin													
            if @AC_Method = 'C'													
               select @CashFlow = round(@CashFlow,2) -- округляем сумму купона													
													
            exec PYearFractionSimple @CashFlowDate, @MaturityDate, @Basis, 'A',  @YF_cf output													
            select @outForwardAmount = @outForwardAmount - @Quantity*@CashFlow*(1+@YF_cf*@ReinvCouponRate/100)													
													
            -- вставляем запись CashFlow по сделке													
            -- а) считаем сумму платежа													
            select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * round(@Quantity*@CashFlow*@ConversionRate, 2)													
            -- б) уменьшаем остаток													
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow													
            -- в) вставляем запись													
            insert into #RepoCashFlows													
               (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
            values													
               (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'N', 0, @CashFlow, 0)													
													
            fetch cBondsCF into @CashFlowDate, @CashFlow													
         end													
         close cBondsCF													
         deallocate cursor cBondsCF													
      end													
													
      -- Теперь, если были Margin Calls по сделке, то учитываем и их													
      open cMarginCallCF													
      fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate													
      while (@@sqlstatus = 0)													
      begin													
													
         exec PYearFractionSimple @CashFlowDate, @MaturityDate, @Basis, 'A',  @YF_cf output													
         select @outForwardAmount = @outForwardAmount - @CashFlow/@ConversionRate*(1+@YF_cf*isnull(@Rate,@FixedRate)/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)													
                                                        -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги													
													
         -- вставляем запись CashFlow по сделке													
         -- б) уменьшаем остаток													
         select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow													
         -- в) вставляем запись													
         insert into #RepoCashFlows													
            (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
         values													
            (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0)													
													
         fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate													
      end													
      close cMarginCallCF													
      deallocate cursor cMarginCallCF													
													
      select @outForwardAmount = round(@outForwardAmount,2)													
      select @outGrossAmount2 = round(@outForwardAmount / @Mult,2)													
      select @outDirtyPrice2 = @outGrossAmount2 / @Quantity / @Principal2 * 100													
													
      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)													
													
      -- 4) На MaturityDate записывается Interest CashFlow равный разнице ForwardAmount и Principal CashFlow из пункта 3													
      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * round(@outForwardAmount*@ConversionRate,2) + @PrincipalCashFlow,													
             @outWeightedAmount = round(@outGrossAmount*@Mult*@ConversionRate,2)													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
--         (@MaturityDate, @MaturityDate, @MaturityDate, 'F', 0, @CashFlow, 0)													
-- KIS иногда пересчитывает сумму CashFlow c типом I, поэтому приходится ее класть таким кривым образом вместо правильного:													
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)													
													
      -- возвращаем посчитанные данные													
      select													
         Accrued           = @outAccrued,													
         DirtyPrice        = @outAccrued + @Price,													
         GrossAmount       = round(@outGrossAmount*@ConversionRate,2),													
         AccruedAmount     = round(@outAccruedAmount*@ConversionRate,2),													
         WeightedAmount    = round(@outGrossAmount*@Mult*@ConversionRate,2),													
         ForwardPrice      = @outDirtyPrice2 - @outAccrued2,													
         Accrued2          = @outAccrued2,													
         DirtyPrice2       = @outDirtyPrice2,													
         GrossAmount2      = round(@outGrossAmount2*@ConversionRate,2),													
         AccruedAmount2    = round(@outAccruedAmount2*@ConversionRate,2),													
         ForwardAmount     = round(@outForwardAmount*@ConversionRate,2),													
         Prepayment        = round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate,2)													
   end													
													
   -- Проводим стандартные вычисления для акций													
   if isnull(@FwdPriceMethod,'D') = 'D' and @Equities_Id > 0													
   begin													
													
      select @outGrossAmount = @Quantity * @Price													
													
      -- 1) В ValueDate сумма CashFlow равна WeightedAmount													
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * round(@outGrossAmount * @Mult * @ConversionRate,2)													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)													
													
      select @outForwardAmount  = round(@outGrossAmount * @Mult * (1 + @YF*@FixedRate/100), 2)													
													
      -- Теперь, если были Margin Calls по сделке, то учитываем и их													
      open cMarginCallCF													
      fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate													
      while (@@sqlstatus = 0)													
      begin													
													
         exec PYearFractionSimple @CashFlowDate, @MaturityDate, @Basis, 'A',  @YF_cf output													
         select @outForwardAmount = @outForwardAmount - @CashFlow/@ConversionRate*(1+@YF_cf*isnull(@Rate,@FixedRate)/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)													
                                                        -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги													
													
         -- вставляем запись CashFlow по сделке													
         -- б) уменьшаем остаток													
         select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow													
													
         -- в) вставляем запись													
         insert into #RepoCashFlows													
            (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
         values													
            (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0)													
													
         fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate													
      end													
      close cMarginCallCF													
      deallocate cursor cMarginCallCF													
													
      select @outForwardAmount = round(@outForwardAmount,2)													
      select @outGrossAmount2 = round(@outForwardAmount / @Mult,2)													
      select @outDirtyPrice2 = @outGrossAmount2 / @Quantity													
													
      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)													
													
      -- 4) На MaturityDate записывается Interest CashFlow равный разнице ForwardAmount и Principal CashFlow из пункта 3													
      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * round(@outForwardAmount*@ConversionRate,2) + @PrincipalCashFlow,													
             @outWeightedAmount = round(@outGrossAmount*@Mult*@ConversionRate,2)													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
--         (@MaturityDate, @MaturityDate, @MaturityDate, 'F', 0, @CashFlow, null)													
-- KIS иногда пересчитывает сумму CashFlow c типом I, поэтому приходится ее класть таким кривым образом вместо правильного:													
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)													
													
      -- возвращаем посчитанные данные													
      select													
         Accrued           = 0,													
         DirtyPrice        = @Price,													
         GrossAmount       = round(@outGrossAmount*@ConversionRate,2),													
         AccruedAmount     = 0,													
         WeightedAmount    = round(@outGrossAmount*@Mult*@ConversionRate,2),													
         ForwardPrice      = @outDirtyPrice2,													
         Accrued2          = 0,													
         DirtyPrice2       = @outDirtyPrice2,													
         GrossAmount2      = round(@outGrossAmount2*@ConversionRate,2),													
         AccruedAmount2    = 0,													
         ForwardAmount     = round(@outForwardAmount*@ConversionRate,2),													
         Prepayment        = round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate,2)													
   end													
													
													
													
   -- Облигации Альфабанк													
   if @FwdPriceMethod = 'A' and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null													
   begin													
      select @outForwardAmount = @outGrossAmount													
      -- если были выплаты и они достались покупателю, то сумму @ForwardAmount надо уменьшить на сумму выплат													
      -- с учетом прироста этих выплат по ставке реинвестирования купона.													
      if @IgnoreCouponPayments = 'B'													
      begin													
         select @AC_Method = isnull(min(substring(Method,1,1)),'G') from RTR_CW_BondsCouponParam													
          where DealId = @Bonds_Id and DealType = 'Bonds'													
         open cBondsCF													
         fetch cBondsCF into @CashFlowDate, @CashFlow													
         while (@@sqlstatus = 0)													
         begin													
            if @AC_Method = 'C'													
               select @CashFlow = round(@CashFlow,2) -- округляем сумму купона													
													
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
         GrossAmount       = round(@outGrossAmount*@ConversionRate,2),													
         AccruedAmount     = round(@outAccruedAmount*@ConversionRate,2),													
         WeightedAmount    = round(@outGrossAmount*@ConversionRate,2),													
         ForwardPrice      = @outForwardPrice,													
         Accrued2          = @outAccrued2,													
         DirtyPrice2       = @outForwardPrice+@outAccrued2,													
         GrossAmount2      = round(@outForwardAmount*@ConversionRate,2),													
         AccruedAmount2    = round(@outAccruedAmount2*@ConversionRate,2),													
         ForwardAmount     = round(@outForwardAmount*@ConversionRate,2),													
         Prepayment        = 0													
   end													
													
   -- Облигации по ММВБ													
   if @FwdPriceMethod = 'M' and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null													
   begin													
													
      -- 1) В ValueDate сумма CashFlow равна WeightedAmount													
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * round(@outGrossAmount * @ConversionRate,2)													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)													
													
      select @outForwardAmount = @outGrossAmount * (1 + @YF*@FixedRate/100)													
      -- если были выплаты и они достались покупателю, то сумму @ForwardAmount надо уменьшить на сумму выплат													
      -- с учетом прироста этих выплат по ставке реинвестирования купона.													
      if @IgnoreCouponPayments = 'B'													
      begin													
         select @AC_Method = isnull(min(substring(Method,1,1)),'G') from RTR_CW_BondsCouponParam													
          where DealId = @Bonds_Id and DealType = 'Bonds'													
         open cBondsCF													
         fetch cBondsCF into @CashFlowDate, @CashFlow													
         while (@@sqlstatus = 0)													
         begin													
            if @AC_Method = 'C'													
               select @CashFlow = round(@CashFlow,2) -- округляем сумму купона													
													
            exec PYearFractionSimple @CashFlowDate, @MaturityDate, @Basis, 'A',  @YF_cf output													
            select @outForwardAmount = @outForwardAmount - @Quantity*@CashFlow*(1+@YF_cf*@ReinvCouponRate/100)													
													
            -- вставляем запись CashFlow по сделке													
            -- а) считаем сумму платежа													
            select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * round(@Quantity*@CashFlow*@ConversionRate, 2)													
													
            -- б) уменьшаем остаток													
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow													
													
            -- в) вставляем запись													
            insert into #RepoCashFlows													
               (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
            values													
               (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0)													
													
            fetch cBondsCF into @CashFlowDate, @CashFlow													
         end													
         close cBondsCF													
         deallocate cursor cBondsCF													
      end													
													
      -- Теперь, если были Margin Calls по сделке, то учитываем и их													
      open cMarginCallCF													
      fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate													
      while (@@sqlstatus = 0)													
      begin													
													
         exec PYearFractionSimple @CashFlowDate, @MaturityDate, @Basis, 'A',  @YF_cf output													
         select @outForwardAmount = @outForwardAmount - @CashFlow/@ConversionRate*(1+@YF_cf*@FixedRate/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)													
                                                        -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги													
													
         -- вставляем запись CashFlow по сделке													
         -- б) уменьшаем остаток													
         select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow													
         -- в) вставляем запись													
         insert into #RepoCashFlows													
            (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
         values													
            (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0)													
													
         fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate													
      end													
      close cMarginCallCF													
      deallocate cursor cMarginCallCF													
													
													
      select @outForwardAmount = round(@outForwardAmount,2)													
      select @outGrossAmount2 = round(@outForwardAmount,2)													
      select @outDirtyPrice2 = @outGrossAmount2 / @Quantity / @Principal2 * 100													
													
      select @outForwardPrice = round(@outDirtyPrice2 - @outAccrued2,4)													
      select @outDirtyPrice2 = @outForwardPrice + @outAccrued2													
      select @outForwardAmount = round(@outDirtyPrice2*@Quantity*@Principal2/100,2)													
      select @outGrossAmount2 = round(@outForwardAmount,2)													
													
      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)													
													
      -- 4) На MaturityDate записывается Interest CashFlow равный разнице ForwardAmount и Principal CashFlow из пункта 3													
      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * round(@outForwardAmount*@ConversionRate,2) + @PrincipalCashFlow,													
             @outWeightedAmount = round(@outGrossAmount*@ConversionRate,2)													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)													
													
      select													
         Accrued           = @outAccrued,													
         DirtyPrice        = @outAccrued + @Price,													
         GrossAmount       = round(@outGrossAmount*@ConversionRate,2),													
         AccruedAmount     = round(@outAccruedAmount*@ConversionRate,2),													
         WeightedAmount    = round(@outGrossAmount*@ConversionRate,2),													
         ForwardPrice      = @outForwardPrice,													
         Accrued2          = @outAccrued2,													
         DirtyPrice2       = @outDirtyPrice2,													
         GrossAmount2      = round(@outGrossAmount2*@ConversionRate,2),													
         AccruedAmount2    = round(@outAccruedAmount2*@ConversionRate,2),													
         ForwardAmount     = round(@outForwardAmount*@ConversionRate,2),													
         Prepayment        = round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate,2)													
   end													
													
   -- Расчет для акций по методике Номос-банка													
   if @FwdPriceMethod = 'N' and @Equities_Id > 0													
   begin													
      select ForwardPrice   = round(@Price*(1+@FixedRate/100*@YF),4),													
             ForwardAmount  = round(round(@Price*(1+@FixedRate/100*@YF),4)*@Quantity,0),													
             WeightedAmount = round(@Price*@Quantity,0),													
             GrossAmount    = round(@Price*@Quantity,0),													
             GrossAmount2   = round(round(@Price*(1+@FixedRate/100*@YF),4)*@Quantity,0)													
   end													
													
   -- Расчет для акций по методике Trust													
   if @FwdPriceMethod = 'T' and @Equities_Id > 0													
   begin													
      select @outGrossAmount2 = round(@Discount/100*@Quantity*@Price, 2) +													
                                round((1+@FixedRate/100*@YF)*@Quantity*@Price*@Mult,2)													
      select													
         ForwardPrice      = @outGrossAmount2/@Quantity,													
         DirtyPrice2       = @outGrossAmount2/@Quantity,													
         GrossAmount2      = @outGrossAmount2,													
         ForwardAmount     = @outGrossAmount2 - round(@Discount/100*@Quantity*@Price, 2)													
													
   end													
													
   -- Расчет для акций по методике ММВБ													
   if @FwdPriceMethod = 'M' and @Equities_Id > 0													
   begin													
      select @outGrossAmount = @Quantity*@Price													
      select @outForwardAmount = (1+@FixedRate/100*@YF)*@Quantity*@Price													
      select @outForwardPrice = round(@outForwardAmount/@Quantity,4)													
      select @outForwardAmount = round(@outForwardPrice*@Quantity,2)													
													
      select													
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
													
   -- Расчет для акций по методике ММВБ c точностью 6 знаков													
   if @FwdPriceMethod = '6' and @Equities_Id > 0													
   begin													
      select @outGrossAmount = @Quantity*@Price													
      select @outForwardAmount = (1+@FixedRate/100*@YF)*@Quantity*@Price													
      select @outForwardPrice = round(@outForwardAmount/@Quantity,6)													
      select @outForwardAmount = round(@outForwardPrice*@Quantity,2)													
													
      select													
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
													
													
   -- Расчет для акций по методике JPMorgan													
   -- % ставка в системе Radius  носит информативный характер, не отражается в Cash Flow и не влияла на PL.													
   -- 2 нога сделки будет также изменяться в соответствие с MC, которые учитываются в Cash Flow.													
   -- Результаты по данным сделкам --> PL всегда равно нулю.													
													
   if @FwdPriceMethod = 'J' and @Equities_Id > 0													
   begin													
													
      select @outGrossAmount = @Quantity * @Price													
													
      -- 1) В ValueDate сумма CashFlow равна WeightedAmount													
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * round(@outGrossAmount * @Mult * @ConversionRate,2)													
													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)													
													
      select @outForwardAmount  = round(@outGrossAmount*@Mult*@ConversionRate,2)													
													
      declare @Type char(1),													
              @PrevDate   datetime,													
              @PrevDate_P datetime,													
              @CashFlow_I float,													
              @PrevCashFlow_I float													
													
      select @PrevDate = @ValueDate,													
             @PrevDate_P = @ValueDate,													
             @CashFlow_I = 0,													
             @PrevCashFlow_I = 0													
													
      declare cCashFlows cursor for													
         select e.ValueDate, e.Quantity													
         from   RadiusMarginCallsExecs e, RadiusMarginCalls mc													
         where  e.ContextType = 'RepoDeals'													
         and    e.Context_Id = @Deals_Id													
         and    e.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id													
         order by 1													
													
      -- Теперь, если были Margin Calls по сделке, то учитываем и их													
      open cCashFlows													
      fetch cCashFlows into @CashFlowDate, @CashFlow													
      while (@@sqlstatus = 0)													
      begin													
													
         select @outForwardAmount = @outForwardAmount - @CashFlow*(case when @DealType in ('S', 'R') then -1 else 1 end)													
													
         -- вставляем запись CashFlow по сделке													
         insert into #RepoCashFlows													
            (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
         values													
            (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0)													
													
         fetch cCashFlows into @CashFlowDate, @CashFlow													
      end													
      close cCashFlows													
      deallocate cursor cCashFlows													
													
      select @outForwardAmount = round(@outForwardAmount,2)													
      select @outGrossAmount2 = round(@outForwardAmount / @Mult,2)													
      select @outDirtyPrice2 = @outGrossAmount2 / @Quantity													
													
      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.													
      insert into #RepoCashFlows													
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)													
      values													
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, @outForwardAmount, 0)													
													
      -- возвращаем посчитанные данные													
      select													
         Accrued           = 0,													
         DirtyPrice        = @Price,													
         GrossAmount       = round(@outGrossAmount*@ConversionRate,2),													
         AccruedAmount     = 0,													
         WeightedAmount    = round(@outGrossAmount*@Mult*@ConversionRate,2),													
         ForwardPrice      = @outDirtyPrice2,													
         Accrued2          = 0,													
         DirtyPrice2       = @outDirtyPrice2,													
         GrossAmount2      = round(@outGrossAmount2*@ConversionRate,2),													
         AccruedAmount2    = 0,													
         ForwardAmount     = round(@outForwardAmount*@ConversionRate,2),													
         Prepayment        = round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate,2)													
													
   end													
													
   -- выводим данные по платежам по сделке													
   select 'S' AS '__DATA_MODEL_MODE', '0' as '__INDEX_AUTO_OFF'													
   select													
      '/CashFlow/' + CashFlowType + '#' + convert(varchar, PaymentDate,112) AS '__DATA_PATH',													
       PaymentDate,           -- null by default													
       StartDate,             -- null by default													
       EndDate,               -- null by default													
       null as FixingDate,    -- null by default													
       avg(Rate) as Rate,     -- 0 by default													
       avg(Principal) as Principal, -- 0 by default													
	    0 as AddMargin,			-- 0 by default									
	    0 as MulMargin,			-- 0 by default									
       sum(CashFlow) as CashFlow, -- 0 by default													
       CashFlowType,          -- '' by default													
       'P' as PeriodType,     -- 'P' by default													
       'F' as Indexation,     -- 'F' by default													
       0 as PrincipalFXRate,  -- 0 by default													
       0 as CouponFXRate,     -- 0 by default													
	    0 as Price,				-- 0 by default								
       'Y' as UserModified,   -- 'Y' by default													
	    'U' as Used				-- 'U' by default								
   from  #RepoCashFlows													
   group by PaymentDate, StartDate, EndDate, CashFlowType													
   order by PaymentDate asc													
   													
   drop table #RepoCashFlows													
													
end													
													
GO													
