USE Kustom
go
IF OBJECT_ID('dbo.Radius_RepoDealsNotify') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.Radius_RepoDealsNotify
    IF OBJECT_ID('dbo.Radius_RepoDealsNotify') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.Radius_RepoDealsNotify >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.Radius_RepoDealsNotify >>>'
END
go
-- version: __VERSION
-- date: '__DATE_VSS'
create procedure dbo.Radius_RepoDealsNotify
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
   @CapturedDiscount                      char(1), -- H/D
   @AdjFactor                             float = null,
   @FwdAdjFactor                          float = null
)
/**************************************************************************************************************
   Updated:
 
 

   2017-10-01 start m1 добавил выключение округления купона для метода Calypso(Z) смотри --20171001 start m1  
   2017-08-01 Krutin вставлен в метод D - default добавлен Метод Z for BCSBackOffice(Calypso) отдельно для РЕПО с облигацией и РЕПО с акцией.  (Изменения подписаны в тексте как --20170801 )
    Общий принцип решения задачи - за основу берем метод Default (купоны, маржин колл и др.).
    Основные измененные шаги по отношению к алгоритму метода Default:
    1) на начальном этапе получаем и округляем WeightedAmount в большую сторону в близи к граничному условию
    2) корректируем значение GrossAmount (GrossAmount1) от зафиксированного WeightedAmount
    3) вводим новую переменную Interest, ее расчитываем и округляем в большую сторону на граничном условии, как при положительной, так и при отрицательной ставке РЕПО
    4) корректируем значение GrossAmount2 и ForwardAmount (ForwardAmount2) от зафиксированного Interest
   итого 4 вставки --20170801 start/end (откат - это закоментировать 4 вставки)
   
   2017-06-01 Semenov
   1. добавлен Метод 7 for Bloomberg 
  
   2017-05-15 Zhegachev
   1. Методы StartPrice и MarketPrice, только для облигаций, для ВТБ доработаны согласно замечаниям банка по Task 12943
   2017-03-10 Zhegachev
   1. Методы StartPrice и MarketPrice, только для акций, для ВТБ доработаны согласно замечаниям банка по Task 12943
   2016-10-18 Pasko
   1. Создал метод для модуля RCMM (исключаются из CashFlow сделки МС, у которых выставлен флаг "Do not affect 2 Leg"), для BSPB пока
   Так же добавил для метода 'D' и 'R' условие отбора - учитывается только исполнение в валюте, исполнение в бумагах игнорируем.
   2015-03-03 Zhegachev
   1. Создал два метода Prepayment для VTB, для акций, с дисконтированной ценой и без дисконта.
   2014-04-01 Zhegachev
   1. Убрал округления в методе Default (D) с вычисляемых параметров: @outGrossAmount, @outAccruedAmount, @outForwardAmount, @PrincipalCashFlow, @outForwardAmount, @outGrossAmount2
   2014-01-24 Zhegachev
   1. Добавил в курсор cMarginCallCF поле Comments, чтобы комментарии переносились в CashFlow
   2012-05-21
   1. @FwdPriceMethod = 'C'
   Изменен выбор WeightedAmount не из RepoDeals, а WeightedAmount2 из  RepoDealsEx
   2. для метода по дефолту для облигаций и выплатами по бумаге:
      isnull(@FwdPriceMethod,'D') in ('D','0') and @Bonds_Id > 0
      and @outAccruedAmount is not null and @outAccruedAmount2 is not null
   Поправлено определение @outForwardAmount_D (ForwardAmount в валюте сделки),
   из-за ошибки в случае, если есть выплата по бондам в период между первой и второй ногой
**************************************************************************************************************/
as
declare
   @Principal1                   float,
   @Principal2                   float,
   @outAccrued                   float,
   @outGrossAmount               float,
   @outDirtyPrice                float,
   @outAccruedAmount             float,
   @outAccrued2                  float,
   @outAccruedAmount2            float,
   @outDirtyPrice2               float,
   @outGrossAmount2              float,
   @YF                           float,
   @YF_cf                        float,
   @outForwardAmount             float,
   @outWeightedAmount            float,
   @outForwardPrice              float,
   @CashFlow                     float,
   @AC_Method                    char(1),
   @CashFlowType                 char(1),
   @MC_Ccy_Id                    int,
   @MC_Asset                     char(3),
   @MC_Rate                      float,
   @MC_Comments                  varchar(64),
   @CashFlowDate                 datetime,
   @DownloadKey                  varchar(30),
   @PrincipalCashFlow            float,
   @Rate                         float,
   @Mult                         float,
   @BalancedDiscount             char(1),
   @PrePay_VTB                   float,
   @PrePay_Rate                  float,
   @DirtyPrice                   float,
   @Sum_Coup                     float  --- сумма выплат по бумаге в период жизни сделки, с учетом прироста этих выплат по ставке реинвестирования купона
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

   -- Проверяем валютную пару: если пара валюта цены к валюте сделки Indirect, то переворачиваем ConversionRate
   if @ConversionRate<=0
   begin
      select _MESSAGE_='WARNING. ConversionRate not defined.'
      return
   end
   else if exists (select * from kplus.dbo.Pairs
                   where Currencies_Id_1 = @Currencies_Id_Price
                  and Currencies_Id_2 = @Currencies_Id
                  and QuotationMode='I')
   begin
         select @ConversionRate = 1.0 / @ConversionRate
   end

   -- Инициализируем предоплату по методу ВТБ
   select @PrePay_VTB = 0, @PrePay_Rate = 0

   -- Следим, чтобы РЕПО с бондами заканчивалось хотя бы за день до погашения бонда, - для этого передвигаем MaturityDate
   select
      @MaturityDate  =
         case when dateadd(dd,-1,MaturityDate)<@MaturityDate
            then dateadd(dd,-1,MaturityDate)
            else @MaturityDate
         end
   from kplus.dbo.Bonds
   where Bonds_Id=@Bonds_Id

   select @SettlementDate2 = isnull(@SettlementDate2, @MaturityDate)
   select @SettlementDate = isnull(@SettlementDate, @ValueDate)

   select @FwdPriceMethod = isnull(@FwdPriceMethod, 'D')
   select @FwdPriceMethod as FwdPriceMethod

   select @Mult = case @CapturedDiscount when 'D' then (1 - @Discount / 100) when 'H' then (100 / @Haircut) else 1 end

   -- находим начальный номинал облигации
   select
      @Principal1 = FaceValue,
      @Principal2 = FaceValue
   from kplus.dbo.Bonds
   where Bonds_Id = @Bonds_Id

   if @AdjFactor = 0
   begin
      -- преобразуем @AdjFactor в 1, ели передан 0
      select @AdjFactor = 1
   end

   if @FwdAdjFactor = 0
   begin
      -- преобразуем @FwdAdjFactor в 1, ели передан 0
      select @FwdAdjFactor = 1
   end

   -- Всегда в начале пересчитываем для облигаций купон в соответствии с дополнительными настройками
   if @Bonds_Id > 0 and @SettlementDate is not null and @Quantity > 0
   begin
      -- вычисляем новую сумму купона для первой ноги
      exec Radius_Lib_BondAccrued @Bonds_Id, @Quantity, @SettlementDate, @outAccruedAmount output, @outAccrued output

      -- если @AdjFactor не передан
      if @AdjFactor is null
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

      select @outGrossAmount = dbo.Radius_Lib_Round(@Principal1 * @Quantity * @Price / 100 + @outAccruedAmount, 2, 'R')
--20171001 start m1     
      if isnull(@FwdPriceMethod,'D') = 'Z'
      select @outGrossAmount =                      @Principal1 * @Quantity * (@Price+@outAccrued) / 100 
--20171001 end m1        
   end

   if @Bonds_Id > 0 and @SettlementDate2 is not null and @Quantity > 0
   begin
      -- вычисляем новую сумму купона для второй ноги
      exec Radius_Lib_BondAccrued @Bonds_Id, @Quantity, @SettlementDate2, @outAccruedAmount2 output, @outAccrued2 output

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
   end

   if @MaturityDate is null or @ValueDate is null
   begin
      return
   end

   -- вычисляем Year Fraction
   if @MaturityDate is not null and @ValueDate is not null
   begin
      exec Radius_Lib_YearFraction_Get
         @StartDate     = @ValueDate,
         @EndDate       = @MaturityDate,
         @Basis         = @Basis,
         @YearFraction  = @YF output
   end

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
      Rate              float        null,
      Comments          varchar(30)  null
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

-- 1	D	Default
-- 2	Z	Calypso Default (ZERO)		20160709
-- 3	7	Bloomberg					20160101
-- 4	F	BCS							20160101
-- 5	M	MICEX 4 digits
-- 6	6	MICEX 6 digits
-- 7	L	Security Loan
-- 8	1	Calypso Empty Cash Flow		20160709
-- 9	0	Empty Cash Flow
--10	B	BalancedDiscount			20150101
--11	C	Cash Flow Only
--12	A	Alfa
--13	N	Nomos
--14	T	Trust
--15	J	JPMorgan
--16	V	ВТБ (Start Price)
--17	P	ВТБ (MarketPrice)

--20170601 start
if @FwdPriceMethod = '7' and @TriggeredField not in ('WeightedAmount','Quantity','FaceAmount')
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
    and (SettlementDate2 is null or @TriggeredField in ('Basis','FixedRate','MaturityDate','SettlementDate2'))
    --and (SettlementDate2 is null or @TriggeredField in ('Basis','FixedRate'))
   
   --for closed Repo
   select ForwardAmount=ForwardAmount2
    ,WeightedAmount=WeightedAmount2
    ,AccruedAmount=AccruedAmount
   from RepoDealsEx
   where DealId=@Deals_Id
    and SettlementDate2 is not null
    and @TriggeredField not in ('Basis','FixedRate','MaturityDate','SettlementDate2')
    --and @TriggeredField not in ('Basis','FixedRate')
   
    
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
        ,(case when @DealType in ('B', 'V') then 1 else -1 end)*round(round(ed.WeightedAmount2/@ConversionRate*@FixedRate/100*datediff(day,@SettlementDate,@SD)/@BasisValue+@corr005,2)*@ConversionRate+@corr005,2)
        ,@FixedRate
    from RepoDealsEx ed
    where ed.DealId=@Deals_Id
        and (ed.SettlementDate2 is null or @TriggeredField in ('Basis','FixedRate','MaturityDate','SettlementDate2'))
        
    insert  #RepoCashFlows (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)  
    select @SettlementDate, @SD, @SD,'I'
        ,(case when @DealType in ('B', 'V') then -1 else 1 end) * ed.WeightedAmount2
        ,ed.ForwardAmount2-ed.WeightedAmount2
        ,@FixedRate
    from RepoDealsEx ed
    where ed.DealId=@Deals_Id
        and ed.SettlementDate2 is not null 
        and @TriggeredField not in ('Basis','FixedRate','MaturityDate','SettlementDate2')
               
   
end         
--20170601 end

   -- Метод для коррекции CashFlow по сделкам загруженным с биржи
   if @FwdPriceMethod = 'C' and isnull(@Deals_Id, 0) <> 0
   begin

      -- 0) читаем параметры сделки из базы данных
      select @DownloadKey = DownloadKey,
             @DealType = DealType
      from   RepoDealsAll
      where  RepoDeals_Id = @Deals_Id

      select @outWeightedAmount = (case when @DealType in ('B', 'V') then -1 else 1 end) * WeightedAmount2,
             @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * WeightedAmount2,
             @outForwardAmount  = (case when @DealType in ('B', 'V') then 1 else -1 end) * ForwardAmount2,
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



         declare cDownPayments cursor  for
            select PaymentDate, CashFlow, 'N'
            from   kplus.dbo.CashFlowSchedule cf, kplus.dbo.CashFlowDeals d
            where  cf.CashFlowDeals_Id = d.CashFlowDeals_Id
               and    d.DealStatus = 'V'
               and    d.PaymentComments = @DownloadKey -- ссылку на сделку репо храним в поле PaymentComments
               and    d.TypeOfInstr_Id = (select TypeOfInstr_Id from kplus.dbo.TypeOfInstr where TypeOfInstr_ShortName = 'REPO_CF')

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

         end -- while (@@sqlstatus = 0)


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

   declare @outForwardAmount_D float -- в валюте сделки

   -- Проводим стандартные вычисления для облигаций если сумма купона была пересчитали
   -- Метод '0' - это стандартный метод с пустым расписанием
   if isnull(@FwdPriceMethod,'D') in ('D','0','R','Z') and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null
   begin
      -- 1) В ValueDate сумма CashFlow равна WeightedAmount
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @Mult * @ConversionRate, 2, 'R')

--20170801 start b1     
      if isnull(@FwdPriceMethod,'D') = 'Z'
      begin                        
      select @PrincipalCashFlow = dbo.Radius_Lib_Round(@outGrossAmount * @Mult * @ConversionRate, 2, 'R')
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

      select @outForwardAmount = dbo.Radius_Lib_Round(@outGrossAmount * @Mult * (1 + @YF * @FixedRate / 100), 2, 'R')
      
--20170801 b2 start    
      if isnull(@FwdPriceMethod,'D') = 'Z'
      begin
      declare @InterestB float
      select  @InterestB = dbo.Radius_Lib_Round(@outGrossAmount*@Mult*@YF*@FixedRate/100*@ConversionRate, 2,'R')/@ConversionRate
      select  @outForwardAmount   = dbo.Radius_Lib_Round(@outGrossAmount * @Mult + @InterestB, 2, 'R')
          -- ,@outForwardAmount_D = dbo.Radius_Lib_Round(@outGrossAmount * @Mult + @InterestB, 2, 'R') * @ConversionRate 
      end
--20170801 b2 end 
      
      -- если были выплаты и они достались покупателю, то сумму @ForwardAmount надо уменьшить на сумму выплат
      -- с учетом прироста этих выплат по ставке реинвестирования купона.
      if @IgnoreCouponPayments = 'B'
      begin
         select @AC_Method = isnull(min(substring(Method,1,1)),'G')
         from   RTR_CW_BondsCouponParam
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
                  select @CashFlow = dbo.Radius_Lib_Round(@CashFlow, 2, 'R') -- округляем сумму купона
               end

               exec Radius_Lib_YearFraction_Get
                  @StartDate     = @CashFlowDate,
                  @EndDate       = @MaturityDate,
                  @Basis         = @Basis,
                  @YearFraction  = @YF_cf output

               select @outForwardAmount = @outForwardAmount - @Quantity * @CashFlow * (1+@YF_cf * @ReinvCouponRate/100)

               -- вставляем запись CashFlow по сделке
               -- а) считаем сумму платежа
               select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * dbo.Radius_Lib_Round(@Quantity*@CashFlow*@ConversionRate, 2, 'R')
               -- б) уменьшаем остаток
               select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
               -- в) вставляем запись
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

      -- Теперь, если были Margin Calls по сделке, то учитываем и их


         declare cMarginCallCF cursor  for
            select e.ValueDate, e.Quantity, mc.FixedRate, e.Assets_Id, e.AssetType, 'МС' + convert(varchar,mc.RadiusMarginCalls_Id) + ' ' + mc.Comments + ' ' + e.Comments
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

            -- если MC в деньгах и валюта сделки не равна валюте МС, то переводим сумму МС в валюту сделки
            if @MC_Asset = 'CCY' and  @MC_Ccy_Id <> @Currencies_Id
            begin
               exec Radius_GetCurrency_Rate
                  @Currencies_Id_1 = @MC_Ccy_Id,
                  @Currencies_Id_2 = @Currencies_Id,
                  @RateDate = @CashFlowDate,
                  @Rate = @MC_Rate OUT,
                  @QuoteType = 'F',
                  @GoodOrder = 'Y'
            end
            else
            begin
               select  @MC_Rate = 1
            end

            exec Radius_Lib_YearFraction_Get
               @StartDate     = @CashFlowDate,
               @EndDate       = @MaturityDate,
               @Basis         = @Basis,
               @YearFraction  = @YF_cf output

            select @outForwardAmount_D = @outForwardAmount_D - @CashFlow*@MC_Rate*(1+@YF_cf*isnull(@Rate,@FixedRate)/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)
                                                           -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги
            -- convert CashFlow currency

            select @CashFlow = @CashFlow*@MC_Rate

            -- вставляем запись CashFlow по сделке
            -- б) уменьшаем остаток
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow

            -- в) вставляем запись
            if @FwdPriceMethod not in ('0')
            begin
               insert into #RepoCashFlows
                  (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comments)
               values
                  (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)
            end


            fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         end -- while (@@sqlstatus = 0)


         close cMarginCallCF

         deallocate cursor cMarginCallCF


      select @outForwardAmount   = dbo.Radius_Lib_Round(@outForwardAmount_D, 2, 'R')
      select @outGrossAmount2    = dbo.Radius_Lib_Round((@outForwardAmount / @ConversionRate) / @Mult, 2, 'R')              -- /@ConversionRate = Пронин 13.09.2012
      select @outDirtyPrice2     = @outGrossAmount2 / @Quantity / @Principal2 * 100

      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.
      if @FwdPriceMethod not in ('0')
      begin
         insert into #RepoCashFlows
            (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
         values
            (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)
      end

      -- 4) На MaturityDate записывается Interest CashFlow равный разнице ForwardAmount и Principal CashFlow из пункта 3
      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * @outForwardAmount + @PrincipalCashFlow,
             @outWeightedAmount = dbo.Radius_Lib_Round(@outGrossAmount*@Mult*@ConversionRate, 2, 'R')

      if @FwdPriceMethod not in ('0')
      begin
         insert into #RepoCashFlows
            (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
         values
   --         (@MaturityDate, @MaturityDate, @MaturityDate, 'F', 0, @CashFlow, 0)
   -- KIS иногда пересчитывает сумму CashFlow c типом I, поэтому приходится ее класть таким кривым образом вместо правильного:
            (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)
      end

      -- возвращаем посчитанные данные
      select
         Accrued           = @outAccrued,
         DirtyPrice        = @outAccrued + @Price,
         GrossAmount       = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R'),
         AccruedAmount     = dbo.Radius_Lib_Round(@outAccruedAmount*@ConversionRate, 2, 'R'),
         WeightedAmount    = dbo.Radius_Lib_Round(@outGrossAmount*@Mult*@ConversionRate, 2, 'R'),
         ForwardPrice      = @outDirtyPrice2 - @outAccrued2,                         -- Убрано @outDirtyPrice2/@ConversionRate - @outAccrued2 = Пронин 13.09.2012
         Accrued2          = @outAccrued2,
         DirtyPrice2       = @outDirtyPrice2,
         GrossAmount2      = case @BalancedDiscount
                                 when 'N' then dbo.Radius_Lib_Round(@outGrossAmount2*@ConversionRate, 2, 'R')
                                 when 'Y' then dbo.Radius_Lib_Round(@outForwardAmount + dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R') - dbo.Radius_Lib_Round(@outGrossAmount*@Mult*@ConversionRate, 2, 'R'), 2, 'R')
                             end,
         AccruedAmount2    = dbo.Radius_Lib_Round(@outAccruedAmount2*@ConversionRate, 2, 'R'),
         ForwardAmount     = @outForwardAmount,
         Prepayment        = dbo.Radius_Lib_Round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate, 2, 'R')
   end

   -- Проводим стандартные вычисления для акций
   -- Метод '0' - это стандартный метод с пустым расписанием
   if isnull(@FwdPriceMethod,'D') in ('D','0','R','Z') and @Equities_Id > 0
   begin

      select @outGrossAmount = @Quantity * @Price

      -- 1) В ValueDate сумма CashFlow равна WeightedAmount
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @Mult * @ConversionRate, 2, 'R')

--20170801 start1     
      if isnull(@FwdPriceMethod,'D') = 'Z' 
      begin                        
      select @PrincipalCashFlow = dbo.Radius_Lib_Round(@outGrossAmount * @Mult * @ConversionRate, 2, 'R') 
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

      select @outForwardAmount   = dbo.Radius_Lib_Round(@outGrossAmount * @Mult * (1 + @YF*@FixedRate/100), 2, 'R'),
             @outForwardAmount_D = dbo.Radius_Lib_Round(@outGrossAmount * @Mult * (1 + @YF*@FixedRate/100), 2, 'R') * @ConversionRate
--20170801  start2    
      if isnull(@FwdPriceMethod,'D') = 'Z'   --20170801
      begin                       
      declare @Interest float       
    --select  @Interest = dbo.Radius_Lib_Round(@outGrossAmount*@Mult*@YF*@FixedRate/100*@ConversionRate, 2,'R') 
      select  @Interest = dbo.Radius_Lib_Round(dbo.Radius_Lib_Round(@outGrossAmount*@Mult*@ConversionRate ,2,'R')*@YF*@FixedRate/100,2, 'R')
      select  @outForwardAmount   = dbo.Radius_Lib_Round(@outGrossAmount * @Mult + @Interest/@ConversionRate , 2, 'R'),
              @outForwardAmount_D = dbo.Radius_Lib_Round(@outGrossAmount * @Mult * @ConversionRate + @Interest, 2, 'R') 
      end                           
--20170801  end2

      -- Теперь, если были Margin Calls по сделке, то учитываем и их

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

            -- если MC в деньгах и валюта сделки не равна валюте МС, то переводим сумму МС в валюту сделки
            if @MC_Asset = 'CCY' and  @MC_Ccy_Id <> @Currencies_Id
            begin
               exec Radius_GetCurrency_Rate
                  @Currencies_Id_1 = @MC_Ccy_Id,
                  @Currencies_Id_2 = @Currencies_Id,
                  @RateDate = @CashFlowDate,
                  @Rate = @MC_Rate OUT,
                  @QuoteType = 'F',
                  @GoodOrder = 'Y'
            end
            else
            begin
               select  @MC_Rate = 1
            end

            exec Radius_Lib_YearFraction_Get
               @StartDate     = @CashFlowDate,
               @EndDate       = @MaturityDate,
               @Basis         = @Basis,
               @YearFraction  = @YF_cf output

            select @outForwardAmount_D = @outForwardAmount_D - @CashFlow*@MC_Rate*(1+@YF_cf*isnull(@Rate,@FixedRate)/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)
            -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги ???

            select @CashFlow = @CashFlow*@MC_Rate
            -- вставляем запись CashFlow по сделке
            -- б) уменьшаем остаток
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
            -- в) вставляем запись
            if @FwdPriceMethod not in ('0')
               insert into #RepoCashFlows
                  (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comments)
               values
                  (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)


            fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         end -- while (@@sqlstatus = 0)


         close cMarginCallCF

         deallocate cursor cMarginCallCF


      select @outForwardAmount = dbo.Radius_Lib_Round(@outForwardAmount_D, 2, 'R')
      select @outGrossAmount2 = dbo.Radius_Lib_Round(@outForwardAmount / @Mult, 2, 'R')
      if @Quantity <> 0
      begin
         select @outDirtyPrice2 = @outGrossAmount2 / @Quantity
      end

      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.
      if @FwdPriceMethod not in ('0')
      begin
         insert into #RepoCashFlows
            (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
         values
            (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)
      end

      -- 4) На MaturityDate записывается Interest CashFlow равный разнице ForwardAmount и Principal CashFlow из пункта 3
      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * @outForwardAmount_D + @PrincipalCashFlow,
             @outWeightedAmount = dbo.Radius_Lib_Round(@outGrossAmount*@Mult*@ConversionRate, 2, 'R')

      if @FwdPriceMethod not in ('0')
      begin
         insert into #RepoCashFlows
            (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
         values
   --         (@MaturityDate, @MaturityDate, @MaturityDate, 'F', 0, @CashFlow, null)
   -- KIS иногда пересчитывает сумму CashFlow c типом I, поэтому приходится ее класть таким кривым образом вместо правильного:
            (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate) -- @CashFlow
      end

      -- возвращаем посчитанные данные
      select
         Accrued           = 0,
         DirtyPrice        = @Price,
         GrossAmount       = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R'),
         AccruedAmount     = 0,
         WeightedAmount    = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate*@Mult, 2, 'R'),
         ForwardPrice      = @outDirtyPrice2/@ConversionRate, -- переводим в валюту цены
         Accrued2          = 0,
         DirtyPrice2       = @outDirtyPrice2,
         GrossAmount2      = case @BalancedDiscount
                                 when 'N' then dbo.Radius_Lib_Round(@outGrossAmount2, 2, 'R')
                                 when 'Y' then dbo.Radius_Lib_Round(@outForwardAmount + dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R') - dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate*@Mult, 2, 'R'), 2, 'R')
                             end,
         AccruedAmount2    = 0,
         ForwardAmount     = @outForwardAmount,
         Prepayment        = dbo.Radius_Lib_Round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate, 2, 'R')
   end

   -- Проводим вычисления от дисконтированной цены (StartPrice) для акций Prepayment для VTB.
   if @FwdPriceMethod = 'V' and @Equities_Id > 0
   begin
      select @outGrossAmount = @Quantity * @Price
      select @DirtyPrice     = @Price

      -- 1) В ValueDate сумма CashFlow равна WeightedAmount
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)


      select @outForwardAmount   = dbo.Radius_Lib_Round(@outGrossAmount * (100 - @Discount) / 100 * (1 + @FixedRate * @YF/100), 2, 'R'),
             @outForwardAmount_D = dbo.Radius_Lib_Round(@outGrossAmount * (100 - @Discount) / 100 * (1 + @FixedRate * @YF/100), 2, 'R') * @ConversionRate

      -- Теперь, если были Margin Calls Prepayment или обычные по сделке (только денежные!), то учитываем и их


         declare cMarginCallCF cursor  for
            select
               mc.ValueDate, mc.Quantity, mc.FixedRate, mc.Assets_Id, mc.AssetType, mc.Comments
            from Kustom..RadiusMarginCalls mc
               inner join RadiusMarginCallsExecs mce
                  on mce.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id
                  and mce.ContextType = 'RepoDeals'
                  and mce.AssetType = 'CCY'
            where mc.Context_Id = @Deals_Id
            order by 1


         open cMarginCallCF


         fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         while (@@sqlstatus = 0)

         begin

            -- если MC в деньгах и валюта сделки не равна валюте МС, то переводим сумму МС в валюту сделки
            if @MC_Asset = 'CCY' and  @MC_Ccy_Id <> @Currencies_Id
            begin
               exec Radius_GetCurrency_Rate
                  @Currencies_Id_1 = @MC_Ccy_Id,
                  @Currencies_Id_2 = @Currencies_Id,
                  @RateDate = @CashFlowDate,
                  @Rate = @MC_Rate OUT,
                  @QuoteType = 'F',
                  @GoodOrder = 'Y'
            end
            else
            begin
               select  @MC_Rate = 1
            end

            exec Radius_Lib_YearFraction_Get
               @StartDate     = @CashFlowDate,
               @EndDate       = @MaturityDate,
               @Basis         = @Basis,
               @YearFraction  = @YF_cf output

            select @outForwardAmount_D = @outForwardAmount_D - @CashFlow*@MC_Rate*(1+@YF_cf*isnull(@Discount,@FixedRate)/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)
            -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги ???

            select @CashFlow = @CashFlow*@MC_Rate
            -- записываем сумму Prepayment из MC
            if @MC_Comments = 'Prepayment for RepoDeals ' + convert(varchar, @Deals_Id)
            begin
               select @PrePay_VTB = IsNull(@CashFlow,0)
               -- записываем процент предоплаты
               select @PrePay_Rate = IsNull(@Rate,0)
            end

            -- вставляем запись CashFlow по сделке
            -- б) уменьшаем остаток
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
            -- в) вставляем запись
            insert into #RepoCashFlows
               (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comments)
            values
               (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)


            fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         end -- while (@@sqlstatus = 0)


         close cMarginCallCF

         deallocate cursor cMarginCallCF


      if @PrePay_VTB = 0
      begin
         select @PrePay_VTB = @outGrossAmount - (@Quantity * @ConversionRate * @DirtyPrice * ((100 - @Discount) / 100))
         select @outForwardAmount_D = @outForwardAmount_D + @PrePay_VTB
      end

      --для ВТБ расчет по предоплате по ставке HCa, согласно методам описанным в TASK 12943
      if @PrePay_Rate >= @Discount and @PrePay_Rate < 100
      begin
			select @outGrossAmount2 = @Quantity * @ConversionRate * @DirtyPrice * ((100 - @PrePay_Rate) / 100) * (1 + @FixedRate * @YF/100) + @PrePay_VTB
			select @outDirtyPrice2  = @DirtyPrice * (1 + @FixedRate * @YF/100)
      end
      else
      begin
      	select @outGrossAmount2 = round(round(@Quantity * @ConversionRate * @DirtyPrice,2) * (1 + @FixedRate * @YF/100), 2)
			select @outDirtyPrice2  = @DirtyPrice * (1 + @FixedRate * @YF/100)
		end

      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.
      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@outGrossAmount2, 0)

      -- 4) На MaturityDate записывается Interest CashFlow равный разнице ForwardAmount и Principal CashFlow из пункта 3
      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * @outForwardAmount_D + @PrincipalCashFlow,
             @outWeightedAmount = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
   --       (@MaturityDate, @MaturityDate, @MaturityDate, 'F', 0, @CashFlow, null)
   -- KIS иногда пересчитывает сумму CashFlow c типом I, поэтому приходится ее класть таким кривым образом вместо правильного:
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', 0, @CashFlow, @FixedRate) -- @CashFlow

      -- возвращаем посчитанные данные
      select
         Accrued           = 0,
         DirtyPrice        = @DirtyPrice,
         GrossAmount       = @outGrossAmount*@ConversionRate,
         AccruedAmount     = 0,
         --WeightedAmount    = @outGrossAmount*@ConversionRate*@Mult,
         WeightedAmount    = @outWeightedAmount,
         ForwardPrice      = @outGrossAmount2/(@Quantity*@ConversionRate),
         Accrued2          = 0,
         DirtyPrice2       = @outDirtyPrice2,
         GrossAmount2      = @outGrossAmount2,
         AccruedAmount2    = 0,
         ForwardAmount     = @outGrossAmount2,
         Prepayment        = @PrePay_VTB
   end

   -- Проводим вычисления от дисконтированной цены (MarketPrice) для акций Prepayment для VTB.
   if @FwdPriceMethod = 'P' and @Equities_Id > 0
   begin
      select @DirtyPrice     = @Price * (100 - @Discount) / 100
      select @outGrossAmount = @Quantity * @DirtyPrice * @ConversionRate

      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)

      select @outForwardAmount   = dbo.Radius_Lib_Round(@outGrossAmount * (100 - @Discount) / 100 * (1 + @FixedRate * @YF/100), 2, 'R'),
             @outForwardAmount_D = dbo.Radius_Lib_Round(@outGrossAmount * (100 - @Discount) / 100 * (1 + @FixedRate * @YF/100), 2, 'R') * @ConversionRate

      -- Теперь, если были Margin Calls Prepayment или обычные по сделке (только денежные!), то учитываем и их


         declare cMarginCallCF cursor  for
            select
               mc.ValueDate, mc.Quantity, mc.FixedRate, mc.Assets_Id, mc.AssetType, mc.Comments
            from Kustom..RadiusMarginCalls mc
               inner join RadiusMarginCallsExecs mce
                  on mce.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id
                  and mce.ContextType = 'RepoDeals'
                  and mce.AssetType = 'CCY'
            where mc.Context_Id = @Deals_Id
            order by 1


         open cMarginCallCF


         fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         while (@@sqlstatus = 0)

         begin

            -- если MC в деньгах и валюта сделки не равна валюте МС, то переводим сумму МС в валюту сделки
            if @MC_Asset = 'CCY' and  @MC_Ccy_Id <> @Currencies_Id
            begin
               exec Radius_GetCurrency_Rate
                  @Currencies_Id_1 = @MC_Ccy_Id,
                  @Currencies_Id_2 = @Currencies_Id,
                  @RateDate = @CashFlowDate,
                  @Rate = @MC_Rate OUT,
                  @QuoteType = 'F',
                  @GoodOrder = 'Y'
            end
            else
            begin
               select  @MC_Rate = 1
            end

            exec Radius_Lib_YearFraction_Get
               @StartDate     = @CashFlowDate,
               @EndDate       = @MaturityDate,
               @Basis         = @Basis,
               @YearFraction  = @YF_cf output

            select @outForwardAmount_D = @outForwardAmount_D - @CashFlow*@MC_Rate*(1+@YF_cf*isnull(@Discount,@FixedRate)/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)
            -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги ???

            select @CashFlow = @CashFlow*@MC_Rate

            -- записываем сумму Prepayment из MC
            if @MC_Comments = 'Prepayment for RepoDeals ' + convert(varchar, @Deals_Id)
            begin
               select @PrePay_VTB = IsNull(@CashFlow,0)
               -- записываем процент предоплаты
               select @PrePay_Rate = IsNull(@Rate,0)
            end

            -- вставляем запись CashFlow по сделке
            -- б) уменьшаем остаток
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
            -- в) вставляем запись
            insert into #RepoCashFlows
               (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comments)
            values
               (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)


            fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         end -- while (@@sqlstatus = 0)


         close cMarginCallCF

         deallocate cursor cMarginCallCF


      if @PrePay_VTB = 0
      begin
         select @PrePay_VTB = dbo.Radius_Lib_Round(@outGrossAmount - (@Quantity * @ConversionRate * @DirtyPrice * ((100 - @Discount) / 100)), 2, 'R')
         select @outForwardAmount_D = @outForwardAmount_D + @PrePay_VTB
      end

      --для ВТБ расчет по предоплате по ставке HCa, согласно методам описанным в TASK 12943
      if @PrePay_Rate >= @Discount and @PrePay_Rate < 100
      begin
			select @outGrossAmount2 = @Quantity * @ConversionRate * @DirtyPrice * ((100 - @PrePay_Rate) / 100) * (1 + @FixedRate * @YF/100) + @PrePay_VTB
			select @outDirtyPrice2  = @DirtyPrice * (1 + @FixedRate * @YF/100)
      end
      else
      begin
      	select @outGrossAmount2 = round(round(@Quantity * @ConversionRate * @DirtyPrice,2) * (1 + @FixedRate * @YF/100), 2)
			select @outDirtyPrice2  = @DirtyPrice * (1 + @FixedRate * @YF/100)
		end

      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.
      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@outGrossAmount2, 0)

      -- 4) На MaturityDate записывается Interest CashFlow равный разнице ForwardAmount и Principal CashFlow из пункта 3
      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * @outForwardAmount_D + @PrincipalCashFlow,
             @outWeightedAmount = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
   --       (@MaturityDate, @MaturityDate, @MaturityDate, 'F', 0, @CashFlow, null)
   -- KIS иногда пересчитывает сумму CashFlow c типом I, поэтому приходится ее класть таким кривым образом вместо правильного:
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', 0, @CashFlow, @FixedRate) -- @CashFlow

      -- возвращаем посчитанные данные
      select
         Accrued           = 0,
         DirtyPrice        = @DirtyPrice,
         GrossAmount       = @outGrossAmount*@ConversionRate,
         AccruedAmount     = 0,
         --WeightedAmount    = @outGrossAmount*@ConversionRate*@Mult,
         WeightedAmount    = @outWeightedAmount,
         ForwardPrice      = @outGrossAmount2/(@Quantity*@ConversionRate),
         Accrued2          = 0,
         DirtyPrice2       = @outDirtyPrice2,
         GrossAmount2      = @outGrossAmount2,
         AccruedAmount2    = 0,
         ForwardAmount     = @outGrossAmount2,
         Prepayment        = @PrePay_VTB
   end

   -- Проводим вычисления от дисконтированной цены (StartPrice) для облигаций Prepayment для VTB.
   if @FwdPriceMethod = 'V' and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null
   begin
      if @Discount <> 100
      begin
         select @DirtyPrice     = dbo.Radius_Lib_Round(@Price, 16, 'R') * 100 / (100 - @Discount)
      end
      select @outGrossAmount = @Quantity * @DirtyPrice

      select @outWeightedAmount = dbo.Radius_Lib_Round((dbo.Radius_Lib_Round(@Principal1 * @Price / 100, 2, 'R')+dbo.Radius_Lib_Round(@Quantity * @outAccruedAmount, 2, 'R')) * @ConversionRate, 2, 'R')

      -- 1) В ValueDate сумма CashFlow равна WeightedAmount
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)

      select @outForwardAmount = dbo.Radius_Lib_Round(@outGrossAmount * @Mult * (1 + @YF * @FixedRate / 100), 2, 'R')

      -- заполним в валюте сделки
      select @outForwardAmount_D = @outForwardAmount * @ConversionRate

      -- если были выплаты и они достались покупателю, то сумму @ForwardAmount надо уменьшить на сумму выплат
      -- с учетом прироста этих выплат по ставке реинвестирования купона.
      if @IgnoreCouponPayments = 'B'
      begin
         select @AC_Method = isnull(min(substring(Method,1,1)),'G')
         from   Kustom..RTR_CW_BondsCouponParam
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
                  select @Sum_Coup = IsNull(@Sum_Coup,0) + @CashFlow
                  select @CashFlow = dbo.Radius_Lib_Round(@CashFlow, 2, 'R') -- округляем сумму купона
               end

               exec Kustom..Radius_Lib_YearFraction_Get
                  @StartDate     = @CashFlowDate,
                  @EndDate       = @MaturityDate,
                  @Basis         = @Basis,
                  @YearFraction  = @YF_cf output

               select @outForwardAmount = @outForwardAmount - @Quantity * @CashFlow * (1+@YF_cf * @ReinvCouponRate/100)

               -- вставляем запись CashFlow по сделке
               -- а) считаем сумму платежа
               select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * dbo.Radius_Lib_Round(@Quantity*@CashFlow*@ConversionRate, 2, 'R')
               -- б) уменьшаем остаток
               select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
               -- в) вставляем запись
               insert into #RepoCashFlows
                  (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
               values
                  (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'N', 0, @CashFlow, 0)


               fetch cBondsCF into @CashFlowDate, @CashFlow

            end -- while (@@sqlstatus = 0)


            close cBondsCF

            deallocate cursor cBondsCF

      end


      -- Теперь, если были Margin Calls Prepayment или обычные по сделке (только денежные!), то учитываем и их


         declare cMarginCallCF cursor  for
            select
               mc.ValueDate, mc.Quantity, mc.FixedRate, mc.Assets_Id, mc.AssetType, mc.Comments
            from Kustom..RadiusMarginCalls mc
               inner join RadiusMarginCallsExecs mce
                  on mce.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id
                  and mce.ContextType = 'RepoDeals'
                  and mce.AssetType = 'CCY'
            where mc.Context_Id = @Deals_Id
            order by 1


         open cMarginCallCF


         fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         while (@@sqlstatus = 0)

         begin

            -- если MC в деньгах и валюта сделки не равна валюте МС, то переводим сумму МС в валюту сделки
            if @MC_Asset = 'CCY' and  @MC_Ccy_Id <> @Currencies_Id
            begin
               exec Radius_GetCurrency_Rate
                  @Currencies_Id_1 = @MC_Ccy_Id,
                  @Currencies_Id_2 = @Currencies_Id,
                  @RateDate = @CashFlowDate,
                  @Rate = @MC_Rate OUT,
                  @QuoteType = 'F',
                  @GoodOrder = 'Y'
            end
            else
            begin
               select  @MC_Rate = 1
            end

            exec Radius_Lib_YearFraction_Get
               @StartDate     = @CashFlowDate,
               @EndDate       = @MaturityDate,
               @Basis         = @Basis,
               @YearFraction  = @YF_cf output

            select @outForwardAmount_D = @outForwardAmount_D - @CashFlow*@MC_Rate*(1+@YF_cf*isnull(@Discount,@FixedRate)/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)
            -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги ???

            select @CashFlow = @CashFlow*@MC_Rate
            -- записываем сумму Prepayment из MC
            if @MC_Comments = 'Prepayment for RepoDeals ' + convert(varchar, @Deals_Id)
            begin
               select @PrePay_VTB = IsNull(@CashFlow,0)
               -- записываем процент предоплаты
               select @PrePay_Rate = IsNull(@Rate,0)
            end

            -- вставляем запись CashFlow по сделке
            -- б) уменьшаем остаток
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
            -- в) вставляем запись
            insert into #RepoCashFlows
               (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comments)
            values
               (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)


            fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         end -- while (@@sqlstatus = 0)


         close cMarginCallCF

         deallocate cursor cMarginCallCF


      if @PrePay_VTB = 0
      begin
         select @PrePay_VTB = @outGrossAmount - (@Quantity * @ConversionRate * @DirtyPrice * ((100 - @Discount) / 100))
         select @outForwardAmount_D = @outForwardAmount_D + @PrePay_VTB
      end

      if @outAccruedAmount2 <> 0 and @ConversionRate <> 0
      begin
         select @outDirtyPrice2  = dbo.Radius_Lib_Round((dbo.Radius_Lib_Round((dbo.Radius_Lib_Round((@outWeightedAmount - @PrePay_VTB) * (1 + @FixedRate * @YF / 100), 2, 'R') + @PrePay_VTB) / @ConversionRate, 2, 'R') - dbo.Radius_Lib_Round(@Quantity * @outAccruedAmount2, 2, 'R') - dbo.Radius_Lib_Round(@Quantity * @Sum_Coup, 2, 'R')) * 100 / @Principal2, 16, 'R')
         select @outForwardPrice = ((@Principal1 * @DirtyPrice / 100 + @Quantity * @outAccruedAmount)* (1 + @FixedRate * @YF / 100) - @Quantity * @outAccruedAmount2 - @Quantity *  @Sum_Coup) * 100 / @outAccruedAmount2

      end

      select @outGrossAmount2 = dbo.Radius_Lib_Round((dbo.Radius_Lib_Round(@Principal2 * @outDirtyPrice2 / 100, 2, 'R') + dbo.Radius_Lib_Round(@Quantity * @outAccruedAmount2, 2, 'R')) * @ConversionRate, 2, 'R')

      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.
      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@outGrossAmount2, 0)


      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
   --       (@MaturityDate, @MaturityDate, @MaturityDate, 'F', 0, @CashFlow, null)
   -- KIS иногда пересчитывает сумму CashFlow c типом I, поэтому приходится ее класть таким кривым образом вместо правильного:
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', 0, @CashFlow, @FixedRate) -- @CashFlow

      -- возвращаем посчитанные данные
      select
         Accrued           = 0,
         DirtyPrice        = @DirtyPrice,
         GrossAmount       = @outGrossAmount*@ConversionRate,
         AccruedAmount     = 0,
         --WeightedAmount    = @outGrossAmount*@ConversionRate*@Mult,
         WeightedAmount    = @outWeightedAmount,
         --ForwardPrice      = @outGrossAmount2/(@Quantity*@ConversionRate),
         Accrued2          = 0,
         DirtyPrice2       = @outDirtyPrice2,
         ForwardPrice      = @outForwardPrice,
         GrossAmount2      = @outGrossAmount2,
         AccruedAmount2    = 0,
         ForwardAmount     = @outGrossAmount2,
         Prepayment        = @PrePay_VTB
   end

   -- Проводим вычисления от дисконтированной цены (MarketPrice) для облигаций Prepayment для VTB.
   if @FwdPriceMethod = 'P' and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null
   begin
      select @DirtyPrice = @Price

      select @outGrossAmount = dbo.Radius_Lib_Round((dbo.Radius_Lib_Round(@Principal1 * @DirtyPrice / 100, 2, 'R')+dbo.Radius_Lib_Round(@Quantity * @outAccruedAmount, 2, 'R')) * @ConversionRate, 2, 'R')

      select @outWeightedAmount = @Quantity * @Price


      If @outWeightedAmount = -1
      begin
         select @outWeightedAmount = dbo.Radius_Lib_Round(@outGrossAmount * (100 - @Discount) / 100, 2, 'R')
      end

      If @Principal1 <> 0 AND @ConversionRate <> 0
      begin
         select @DirtyPrice = dbo.Radius_Lib_Round((@outWeightedAmount/@ConversionRate - dbo.Radius_Lib_Round(@Quantity * @outAccrued, 2, 'R')) * 100 / @Principal1, 9, 'R')
      end

      select @outWeightedAmount = dbo.Radius_Lib_Round((dbo.Radius_Lib_Round(@Principal1 * @DirtyPrice / 100, 2, 'R') + dbo.Radius_Lib_Round(@Quantity * @outAccrued, 2, 'R')) * @ConversionRate, 2, 'R')

      -- 1) В ValueDate сумма CashFlow равна WeightedAmount
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)

      select @outForwardAmount = dbo.Radius_Lib_Round(@outGrossAmount * @Mult * (1 + @YF * @FixedRate / 100), 2, 'R')

      -- заполним в валюте сделки
      select @outForwardAmount_D = @outForwardAmount * @ConversionRate

      -- если были выплаты и они достались покупателю, то сумму @ForwardAmount надо уменьшить на сумму выплат
      -- с учетом прироста этих выплат по ставке реинвестирования купона.
      if @IgnoreCouponPayments = 'B'
      begin
         select @AC_Method = isnull(min(substring(Method,1,1)),'G')
         from   Kustom..RTR_CW_BondsCouponParam
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
                  select @Sum_Coup = IsNull(@Sum_Coup,0) + @CashFlow
                  select @CashFlow = dbo.Radius_Lib_Round(@CashFlow, 2, 'R') -- округляем сумму купона
               end

               exec Kustom..Radius_Lib_YearFraction_Get
                  @StartDate     = @CashFlowDate,
                  @EndDate       = @MaturityDate,
                  @Basis         = @Basis,
                  @YearFraction  = @YF_cf output

               select @outForwardAmount = @outForwardAmount - @Quantity * @CashFlow * (1+@YF_cf * @ReinvCouponRate/100)

               -- вставляем запись CashFlow по сделке
               -- а) считаем сумму платежа
               select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * dbo.Radius_Lib_Round(@Quantity*@CashFlow*@ConversionRate, 2, 'R')
               -- б) уменьшаем остаток
               select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
               -- в) вставляем запись
               insert into #RepoCashFlows
                  (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
               values
                  (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'N', 0, @CashFlow, 0)


               fetch cBondsCF into @CashFlowDate, @CashFlow

            end -- while (@@sqlstatus = 0)


            close cBondsCF

            deallocate cursor cBondsCF

      end


      -- Теперь, если были Margin Calls Prepayment или обычные по сделке (только денежные!), то учитываем и их


         declare cMarginCallCF cursor  for
            select
               mc.ValueDate, mc.Quantity, mc.FixedRate, mc.Assets_Id, mc.AssetType, mc.Comments
            from Kustom..RadiusMarginCalls mc
               inner join RadiusMarginCallsExecs mce
                  on mce.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id
                  and mce.ContextType = 'RepoDeals'
                  and mce.AssetType = 'CCY'
            where mc.Context_Id = @Deals_Id
            order by 1


         open cMarginCallCF


         fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         while (@@sqlstatus = 0)

         begin

            -- если MC в деньгах и валюта сделки не равна валюте МС, то переводим сумму МС в валюту сделки
            if @MC_Asset = 'CCY' and  @MC_Ccy_Id <> @Currencies_Id
            begin
               exec Radius_GetCurrency_Rate
                  @Currencies_Id_1 = @MC_Ccy_Id,
                  @Currencies_Id_2 = @Currencies_Id,
                  @RateDate = @CashFlowDate,
                  @Rate = @MC_Rate OUT,
                  @QuoteType = 'F',
                  @GoodOrder = 'Y'
            end
            else
            begin
               select  @MC_Rate = 1
            end

            exec Radius_Lib_YearFraction_Get
               @StartDate     = @CashFlowDate,
               @EndDate       = @MaturityDate,
               @Basis         = @Basis,
               @YearFraction  = @YF_cf output

            select @outForwardAmount_D = @outForwardAmount_D - @CashFlow*@MC_Rate*(1+@YF_cf*isnull(@Discount,@FixedRate)/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)
            -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги ???

            select @CashFlow = @CashFlow*@MC_Rate
            -- записываем сумму Prepayment из MC
            if @MC_Comments = 'Prepayment for RepoDeals ' + convert(varchar, @Deals_Id)
            begin
               select @PrePay_VTB = IsNull(@CashFlow,0)
               -- записываем процент предоплаты
               select @PrePay_Rate = IsNull(@Rate,0)
            end

            -- вставляем запись CashFlow по сделке
            -- б) уменьшаем остаток
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
            -- в) вставляем запись
            insert into #RepoCashFlows
               (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comments)
            values
               (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)


            fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         end -- while (@@sqlstatus = 0)


         close cMarginCallCF

         deallocate cursor cMarginCallCF


      if @PrePay_VTB = 0
      begin
         select @PrePay_VTB = @outGrossAmount - (@Quantity * @ConversionRate * @DirtyPrice * ((100 - @Discount) / 100))
         select @outForwardAmount_D = @outForwardAmount_D + @PrePay_VTB
      end

      If @PrePay_Rate > @Discount and @PrePay_Rate < 100
      begin
         select @outGrossAmount2 = dbo.Radius_Lib_Round((dbo.Radius_Lib_Round(dbo.Radius_Lib_Round(@outGrossAmount * (100 - @PrePay_Rate) / 100, 2, 'R') - dbo.Radius_Lib_Round(@Quantity * @outAccruedAmount * @ConversionRate, 2, 'R'), 2, 'R') + dbo.Radius_Lib_Round(dbo.Radius_Lib_Round(@Quantity * @outAccruedAmount, 2, 'R') * @ConversionRate, 2, 'R')) * (1 + @FixedRate * @YF / 100), 2, 'R') - dbo.Radius_Lib_Round(@Quantity * @Sum_Coup * @ConversionRate, 2, 'R')  + @PrePay_VTB
      end
      Else
      begin
         select @outGrossAmount2 = dbo.Radius_Lib_Round(@outGrossAmount * (1 +  @FixedRate * @YF / 100), 2, 'R') - dbo.Radius_Lib_Round(@Quantity * @Sum_Coup * @ConversionRate, 2, 'R')
      end

      IF @Principal1 <> 0 AND @ConversionRate <> 0
         select @outForwardPrice = dbo.Radius_Lib_Round((dbo.Radius_Lib_Round(@outGrossAmount2 / @ConversionRate, 2, 'R') - dbo.Radius_Lib_Round(@Quantity * @outAccruedAmount2, 2, 'R')) * 100 / @Principal1, 9, 'R')

      select @outGrossAmount2 = dbo.Radius_Lib_Round((dbo.Radius_Lib_Round(@Principal2 * @outForwardPrice / 100, 2, 'R') + dbo.Radius_Lib_Round(@Quantity * @outAccruedAmount2, 2, 'R')) * @ConversionRate, 2, 'R')

      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.
      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@outGrossAmount2, 0)


      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
   --       (@MaturityDate, @MaturityDate, @MaturityDate, 'F', 0, @CashFlow, null)
   -- KIS иногда пересчитывает сумму CashFlow c типом I, поэтому приходится ее класть таким кривым образом вместо правильного:
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', 0, @CashFlow, @FixedRate) -- @CashFlow

      -- возвращаем посчитанные данные
      select
         Accrued           = 0,
         DirtyPrice        = @DirtyPrice,
         GrossAmount       = @outGrossAmount*@ConversionRate,
         AccruedAmount     = 0,
         --WeightedAmount    = @outGrossAmount*@ConversionRate*@Mult,
         WeightedAmount    = @outWeightedAmount,
         --ForwardPrice      = @outGrossAmount2/(@Quantity*@ConversionRate),
         Accrued2          = 0,
         DirtyPrice2       = @outDirtyPrice2,
         ForwardPrice      = @outForwardPrice,
         GrossAmount2      = @outGrossAmount2,
         AccruedAmount2    = 0,
         ForwardAmount     = @outGrossAmount2,
         Prepayment        = @PrePay_VTB
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
                  select @CashFlow = dbo.Radius_Lib_Round(@CashFlow, 2, 'R') -- округляем сумму купона

               exec Radius_Lib_YearFraction_Get
                  @StartDate     = @ValueDate,
                  @EndDate       = @CashFlowDate,
                  @Basis         = @Basis,
                  @YearFraction  = @YF_cf output

               select @outForwardAmount = @outForwardAmount - @Quantity*@CashFlow/(1+@YF_cf*@ReinvCouponRate/100)


               fetch cBondsCF into @CashFlowDate, @CashFlow

            end -- while (@@sqlstatus = 0)


            close cBondsCF

            deallocate cursor cBondsCF

      end

      select @outForwardAmount = dbo.Radius_Lib_Round(@outForwardAmount * (1 + @YF*@FixedRate/100), 2, 'R')
      select @outForwardPrice = dbo.Radius_Lib_Round((@outForwardAmount - @outAccruedAmount2)/(@Quantity*@Principal2)*100, 6, 'R')
      select @outForwardAmount = dbo.Radius_Lib_Round(@outForwardPrice * @Quantity * @Principal2/100 + @outAccruedAmount2, 2, 'R')

      select
         Accrued           = @outAccrued,
         DirtyPrice        = @outAccrued + @Price,
         GrossAmount       = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R'),
         AccruedAmount     = dbo.Radius_Lib_Round(@outAccruedAmount*@ConversionRate, 2, 'R'),
         WeightedAmount    = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R'),
         ForwardPrice      = @outForwardPrice,
         Accrued2          = @outAccrued2,
         DirtyPrice2       = @outForwardPrice+@outAccrued2,
         GrossAmount2      = dbo.Radius_Lib_Round(@outForwardAmount*@ConversionRate, 2, 'R'),
         AccruedAmount2    = dbo.Radius_Lib_Round(@outAccruedAmount2*@ConversionRate, 2, 'R'),
         ForwardAmount     = dbo.Radius_Lib_Round(@outForwardAmount*@ConversionRate, 2, 'R'),
         Prepayment        = 0
   end

   -- Облигации по ММВБ
   if @FwdPriceMethod = 'M' and @Bonds_Id > 0 and @outAccruedAmount is not null and @outAccruedAmount2 is not null
   begin

      -- 1) В ValueDate сумма CashFlow равна WeightedAmount
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @ConversionRate, 2, 'R')

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
                  select @CashFlow = dbo.Radius_Lib_Round(@CashFlow, 2, 'R') -- округляем сумму купона
               end

               exec Radius_Lib_YearFraction_Get
                  @StartDate     = @CashFlowDate,
                  @EndDate       = @MaturityDate,
                  @Basis         = @Basis,
                  @YearFraction  = @YF_cf output

               select @outForwardAmount = @outForwardAmount - @Quantity*@CashFlow*(1+@YF_cf*@ReinvCouponRate/100)

               -- вставляем запись CashFlow по сделке
               -- а) считаем сумму платежа
               select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * dbo.Radius_Lib_Round(@Quantity*@CashFlow*@ConversionRate, 2, 'R')

               -- б) уменьшаем остаток
               select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow

               -- в) вставляем запись
               insert into #RepoCashFlows
                  (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
               values
                  (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0)


               fetch cBondsCF into @CashFlowDate, @CashFlow

            end -- while (@@sqlstatus = 0)


            close cBondsCF

            deallocate cursor cBondsCF

      end

      -- Теперь, если были Margin Calls по сделке, то учитываем и их


         declare cMarginCallCF cursor  for
            select e.ValueDate, e.Quantity, mc.FixedRate, e.Assets_Id, e.AssetType, 'МС' + convert(varchar,mc.RadiusMarginCalls_Id) + ' ' + mc.Comments + ' ' + e.Comments
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
               exec Radius_GetCurrency_Rate
                  @Currencies_Id_1 = @Currencies_Id_Price,
                  @Currencies_Id_2 = @MC_Ccy_Id,
                  @RateDate = @CashFlowDate,
                  @Rate = @MC_Rate OUT,
                  @QuoteType = 'F',
                  @GoodOrder = 'Y'
            end
            else
            begin
               select  @MC_Rate = @ConversionRate
            end

            exec Radius_Lib_YearFraction_Get
               @StartDate     = @CashFlowDate,
               @EndDate       = @MaturityDate,
               @Basis         = @Basis,
               @YearFraction  = @YF_cf output

            select @outForwardAmount = @outForwardAmount - @CashFlow/@MC_Rate*(1+@YF_cf*@FixedRate/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)
                                                           -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги

            -- **alex**
            select @CashFlow = @CashFlow/@MC_Rate
            -- вставляем запись CashFlow по сделке
            -- б) уменьшаем остаток
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
            -- в) вставляем запись
            insert into #RepoCashFlows
               (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comments)
            values
               (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)


            fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         end -- while (@@sqlstatus = 0)


         close cMarginCallCF

         deallocate cursor cMarginCallCF


      select @outForwardAmount = dbo.Radius_Lib_Round(@outForwardAmount, 2, 'R')
      select @outGrossAmount2 = dbo.Radius_Lib_Round(@outForwardAmount, 2, 'R')
      select @outDirtyPrice2 = @outGrossAmount2 / @Quantity / @Principal2 * 100

      select @outForwardPrice = dbo.Radius_Lib_Round(@outDirtyPrice2 - @outAccrued2, 4, 'R')
      select @outDirtyPrice2 = @outForwardPrice + @outAccrued2
      select @outForwardAmount = dbo.Radius_Lib_Round(@outDirtyPrice2*@Quantity*@Principal2/100, 2, 'R')
      select @outGrossAmount2 = dbo.Radius_Lib_Round(@outForwardAmount, 2, 'R')

      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.
      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)

      -- 4) На MaturityDate записывается Interest CashFlow равный разнице ForwardAmount и Principal CashFlow из пункта 3
      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * dbo.Radius_Lib_Round(@outForwardAmount*@ConversionRate, 2, 'R') + @PrincipalCashFlow,
             @outWeightedAmount = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@ValueDate, @MaturityDate, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)

      select
         Accrued           = @outAccrued,
         DirtyPrice        = @outAccrued + @Price,
         GrossAmount       = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R'),
         AccruedAmount     = dbo.Radius_Lib_Round(@outAccruedAmount*@ConversionRate, 2, 'R'),
         WeightedAmount    = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R'),
         ForwardPrice      = @outForwardPrice,
         Accrued2          = @outAccrued2,
         DirtyPrice2       = @outDirtyPrice2,
         GrossAmount2      = dbo.Radius_Lib_Round(@outGrossAmount2*@ConversionRate, 2, 'R'),
         AccruedAmount2    = dbo.Radius_Lib_Round(@outAccruedAmount2*@ConversionRate, 2, 'R'),
         ForwardAmount     = dbo.Radius_Lib_Round(@outForwardAmount*@ConversionRate, 2, 'R'),
         Prepayment        = dbo.Radius_Lib_Round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate, 2, 'R')
   end

   -- Расчет для акций по методике Номос-банка
   if @FwdPriceMethod = 'N' and @Equities_Id > 0
   begin
      select ForwardPrice   = dbo.Radius_Lib_Round(@Price*(1+@FixedRate/100*@YF), 4, 'R'),
             ForwardAmount  = dbo.Radius_Lib_Round(dbo.Radius_Lib_Round(@Price*(1+@FixedRate/100*@YF), 4, 'R')*@Quantity, 0, 'R'),
             WeightedAmount = dbo.Radius_Lib_Round(@Price*@Quantity, 0, 'R'),
             GrossAmount    = dbo.Radius_Lib_Round(@Price*@Quantity, 0, 'R'),
             GrossAmount2   = dbo.Radius_Lib_Round(dbo.Radius_Lib_Round(@Price*(1+@FixedRate/100*@YF), 4, 'R')*@Quantity, 0, 'R')
   end

   -- Расчет для акций по методике Trust
   if @FwdPriceMethod = 'T' and @Equities_Id > 0
   begin
      select @outGrossAmount2 = dbo.Radius_Lib_Round(@Discount/100*@Quantity*@Price, 2, 'R') +
                                dbo.Radius_Lib_Round((1+@FixedRate/100*@YF)*@Quantity*@Price*@Mult, 2, 'R')
      select
         ForwardPrice      = @outGrossAmount2/@Quantity,
         DirtyPrice2       = @outGrossAmount2/@Quantity,
         GrossAmount2      = @outGrossAmount2,
         ForwardAmount     = @outGrossAmount2 - dbo.Radius_Lib_Round(@Discount/100*@Quantity*@Price, 2, 'R')

   end

   -- Расчет для акций по методике ММВБ
   if @FwdPriceMethod = 'M' and @Equities_Id > 0
   begin
      select @outGrossAmount = @Quantity*@Price
      select @outForwardAmount = (1+@FixedRate/100*@YF)*@Quantity*@Price
      select @outForwardPrice = dbo.Radius_Lib_Round(@outForwardAmount/@Quantity, 4, 'R')
      select @outForwardAmount = dbo.Radius_Lib_Round(@outForwardPrice*@Quantity, 2, 'R')

      select
         WeightedAmount    = @Price*@Quantity,
         ForwardPrice      = @outForwardPrice,
         DirtyPrice2       = @outForwardPrice,
         GrossAmount2      = @outForwardAmount,
         ForwardAmount     = @outForwardAmount

      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)

      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * dbo.Radius_Lib_Round(@outForwardAmount*@ConversionRate, 2, 'R') + @PrincipalCashFlow,
             @outWeightedAmount = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R')

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
      select @outForwardPrice = dbo.Radius_Lib_Round(@outForwardAmount/@Quantity, 6, 'R')
      select @outForwardAmount = dbo.Radius_Lib_Round(@outForwardPrice*@Quantity, 2, 'R')

      select
         WeightedAmount    = @Price*@Quantity,
         ForwardPrice      = @outForwardPrice,
         DirtyPrice2       = @outForwardPrice,
         GrossAmount2      = @outForwardAmount,
         ForwardAmount     = @outForwardAmount

      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)

      select @CashFlow = (case when @DealType in ('B', 'V') then 1 else -1 end) * dbo.Radius_Lib_Round(@outForwardAmount*@ConversionRate, 2, 'R') + @PrincipalCashFlow,
             @outWeightedAmount = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R')

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
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @Mult * @ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)

      select @outForwardAmount  = dbo.Radius_Lib_Round(@outGrossAmount*@Mult*@ConversionRate, 2, 'R')

      declare @Type char(1),
              @PrevDate   datetime,
              @PrevDate_P datetime,
              @CashFlow_I float,
              @PrevCashFlow_I float

      select @PrevDate = @ValueDate,
             @PrevDate_P = @ValueDate,
             @CashFlow_I = 0,
             @PrevCashFlow_I = 0



         declare cCashFlows cursor  for
            select e.ValueDate, e.Quantity, e.Assets_Id, e.AssetType
            from   RadiusMarginCallsExecs e, RadiusMarginCalls mc
            where  e.ContextType = 'RepoDeals'
               and e.Context_Id = @Deals_Id
               and e.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id
            order by 1


         open cCashFlows


         fetch cCashFlows into @CashFlowDate, @CashFlow, @MC_Ccy_Id, @MC_Asset

         while (@@sqlstatus = 0)

         begin

            select @outForwardAmount = @outForwardAmount - @CashFlow*(case when @DealType in ('S', 'R') then -1 else 1 end)

            -- вставляем запись CashFlow по сделке
            insert into #RepoCashFlows
               (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
            values
               (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0)


            fetch cCashFlows into @CashFlowDate, @CashFlow, @MC_Ccy_Id, @MC_Asset

         end -- while (@@sqlstatus = 0)


         close cCashFlows

         deallocate cursor cCashFlows


      select @outForwardAmount = dbo.Radius_Lib_Round(@outForwardAmount, 2, 'R')
      select @outGrossAmount2 = dbo.Radius_Lib_Round(@outForwardAmount / @Mult, 2, 'R')
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
         GrossAmount       = dbo.Radius_Lib_Round(@outGrossAmount*@ConversionRate, 2, 'R'),
         AccruedAmount     = 0,
         WeightedAmount    = dbo.Radius_Lib_Round(@outGrossAmount*@Mult*@ConversionRate, 2, 'R'),
         ForwardPrice      = @outDirtyPrice2,
         Accrued2          = 0,
         DirtyPrice2       = @outDirtyPrice2,
         GrossAmount2      = dbo.Radius_Lib_Round(@outGrossAmount2*@ConversionRate, 2, 'R'),
         AccruedAmount2    = 0,
         ForwardAmount     = dbo.Radius_Lib_Round(@outForwardAmount*@ConversionRate, 2, 'R'),
         Prepayment        = dbo.Radius_Lib_Round((case @NeedPrepayment when 'Y' then @outGrossAmount*@Discount/100 else 0 end)*@ConversionRate, 2, 'R')

   end

   if @FwdPriceMethod = 'L' and @Equities_Id > 0
   begin
      /*
         Изменения по задаче [R:7052]
         Для учета займов ЦБ в системе Kondor+\Radius,  предлагается использовать форму сделок Репо (RepoDeals).

         Ключевое отличие займов от сделок РЕПО, заключается в следующем:
         Длительность займа определяется как Settl.Date2 - Settl.Date1. Начиление процентов происходит именно на этот отрезок времени.
         Расчет PL по данным сделкам, расчет 2 ноги должен происходить аналогично тому как сейчас реализован метод "Default" с учетом начисления % на срок расчитанный по SettlDate.

         Для того, чтобы корректно учитывать подобные сделки в K+\Radius предлагается реализовать новый метод расчета РЕПО (FwdPriceMethod) - «Loan Repo».
      */

      -- вычисляем Year Fraction
      if @MaturityDate is not null and @ValueDate is not null
      begin
         exec Radius_Lib_YearFraction_Get
            @StartDate     = @SettlementDate,
            @EndDate       = @SettlementDate2,
            @Basis         = @Basis,
            @YearFraction  = @YF output
      end

      select @outGrossAmount = @Quantity * @Price

      -- 1) В ValueDate сумма CashFlow равна WeightedAmount
      select @PrincipalCashFlow = (case when @DealType in ('B', 'V') then -1 else 1 end) * dbo.Radius_Lib_Round(@outGrossAmount * @Mult * @ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@ValueDate, @ValueDate, @ValueDate, 'N', 0, @PrincipalCashFlow, 0)

      select @outForwardAmount  = dbo.Radius_Lib_Round(@outGrossAmount * @Mult * (1 + @YF*@FixedRate/100), 2, 'R'),
         @outForwardAmount_D = dbo.Radius_Lib_Round(@outGrossAmount * @Mult * @ConversionRate * (1 + @YF*@FixedRate/100), 2, 'R')

      -- Теперь, если были Margin Calls по сделке, то учитываем и их


         declare cMarginCallCF cursor  for
            select e.ValueDate, e.Quantity, mc.FixedRate, e.Assets_Id, e.AssetType, 'MC' + convert(varchar,mc.RadiusMarginCalls_Id) + ' ' + mc.Comments + ' ' + e.Comments
            from   RadiusMarginCallsExecs e, RadiusMarginCalls mc
            where  e.ContextType = 'RepoDeals'
               and    e.Context_Id = @Deals_Id
               and    e.RadiusMarginCalls_Id = mc.RadiusMarginCalls_Id
            order by 1


         open cMarginCallCF


         fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         while (@@sqlstatus = 0)

         begin

            -- если MC в деньгах и валюта сделки не равна валюте МС, то переводим сумму МС в валюту сделки
            if @MC_Asset = 'CCY' and  @MC_Ccy_Id <> @Currencies_Id
                  exec Radius_GetCurrency_Rate
                                 @Currencies_Id_1  = @MC_Ccy_Id,
                                 @Currencies_Id_2  = @Currencies_Id,
                                 @RateDate         = @CashFlowDate,
                                 @Rate             = @MC_Rate OUT,
                                 @QuoteType        = 'F',
                                 @GoodOrder        = 'Y'

            else
               select @MC_Rate = 1

            exec Radius_Lib_YearFraction_Get
               @StartDate     = @CashFlowDate,
               @EndDate       = @SettlementDate,
               @Basis         = @Basis,
               @YearFraction  = @YF_cf output

            select @outForwardAmount_D = @outForwardAmount_D - @CashFlow * @MC_Rate * (1+@YF_cf * isnull(@Rate,@FixedRate)/100) * (case when @DealType in ('S', 'R') then -1 else 1 end)
            -- выплаты по MC в валюте сделки, а расчет ведется валюте бумаги ???

            select @CashFlow = @CashFlow*@MC_Rate
            -- вставляем запись CashFlow по сделке
            -- б) уменьшаем остаток
            select @PrincipalCashFlow = @PrincipalCashFlow + @CashFlow
            -- в) вставляем запись
            insert into #RepoCashFlows
               (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate, Comments)
            values
               (@CashFlowDate, @CashFlowDate, @CashFlowDate, 'F', 0, @CashFlow, 0, @MC_Comments)


            fetch cMarginCallCF into @CashFlowDate, @CashFlow, @Rate, @MC_Ccy_Id, @MC_Asset, @MC_Comments

         end -- while (@@sqlstatus = 0)


         close cMarginCallCF

         deallocate cursor cMarginCallCF


      select @outForwardAmount = dbo.Radius_Lib_Round(@outForwardAmount_D, 2, 'R')
      select @outGrossAmount2 = dbo.Radius_Lib_Round(@outForwardAmount / @Mult, 2, 'R')
      select @outDirtyPrice2 = @outGrossAmount2 / @Quantity

      -- 3) На MaturityDate записывается Principal CashFlow равный разнице WeightedAmount и всех промежуточных выплат.
      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@MaturityDate, @MaturityDate, @MaturityDate, 'N', 0, -@PrincipalCashFlow, 0)

      select
         @CashFlow = (case
                        when @DealType in ('B', 'V') then 1
                        else -1
                      end) * @outForwardAmount_D + @PrincipalCashFlow,
         @outWeightedAmount = dbo.Radius_Lib_Round(@outGrossAmount*@Mult*@ConversionRate, 2, 'R')

      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@SettlementDate, @SettlementDate2, @MaturityDate, 'I', @outWeightedAmount, @CashFlow, @FixedRate)
   end

   -- Формируем условно пустое расписание для метода без платежей
   if @FwdPriceMethod in ('0')
   begin
      insert into #RepoCashFlows
         (StartDate, EndDate, PaymentDate, CashFlowType, Principal, CashFlow, Rate)
      values
         (@ValueDate, @ValueDate, @ValueDate, 'I', 0, 0, 0)
   end

   -- выводим данные по платежам по сделке
   select 'S' AS '__DATA_MODEL_MODE', '0' as '__INDEX_AUTO_OFF'
   select
      '/CashFlow/' + CashFlowType + '#' + convert(varchar, PaymentDate,112) AS '__DATA_PATH',
      PaymentDate,                  -- null by default
      StartDate,                    -- null by default
      EndDate,                      -- null by default
      null as FixingDate,           -- null by default
      avg(Rate) as Rate,            -- 0 by default
      avg(Principal) as Principal,  -- 0 by default
      0 as AddMargin,               -- 0 by default
      0 as MulMargin,               -- 0 by default
      sum(CashFlow) as CashFlow,    -- 0 by default
      CashFlowType,                 -- '' by default
      'P' as PeriodType,            -- 'P' by default
      'F' as Indexation,            -- 'F' by default
      0 as PrincipalFXRate,         -- 0 by default
      0 as CouponFXRate,            -- 0 by default
      0 as Price,                   -- 0 by default
      'Y' as UserModified,          -- 'Y' by default
      'U' as Used,                  -- 'U' by default
      Comments                      -- null by default
   from #RepoCashFlows
   group by PaymentDate, StartDate, EndDate, CashFlowType, Comments
   order by PaymentDate asc

   drop table #RepoCashFlows

end
go
EXEC sp_procxmode 'dbo.Radius_RepoDealsNotify', 'unchained'
go
IF OBJECT_ID('dbo.Radius_RepoDealsNotify') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.Radius_RepoDealsNotify >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.Radius_RepoDealsNotify >>>'
go
REVOKE EXECUTE ON dbo.Radius_RepoDealsNotify FROM public
go
GRANT EXECUTE ON dbo.Radius_RepoDealsNotify TO public
go
