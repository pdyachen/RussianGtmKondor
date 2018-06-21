IF OBJECT_ID ('dbo.Radius_Lib_YieldToMaturity') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_YieldToMaturity
GO

create procedure Radius_Lib_YieldToMaturity
(
   @Bonds_Id         int,
   @Price            float,
   @Date             datetime,
   @AccruedAmount    float,
   @ApproximateYield float output,
   @AdjFactor        float = null
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
   @Y                   float,
   @MarketPrice         float,
   @MarketAccrued       float,
   @FaceValue           float,
   @YieldRoundingConv   int,
   @YieldRoundingType   char(1)
begin

   select @CalcDate = isnull(@Date, getdate())

   /*                         */
   /*  The checking section   */
   /*                         */

   if not exists (select 1 from kplus.dbo.Bonds where Bonds_Id = @Bonds_Id)
   begin
      return
   end

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

   -- вычисляем AdjFactor облигации на дату @CalcDate
   if @AdjFactor is null
   begin
      exec Radius_Lib_BondsAdjFactors_Get @Bonds_Id, @CalcDate, @AdjFactor output
   end

   -- начитываем параметры облигации
   select
      @FaceValue           = FaceValue,
      @YieldRoundingConv   = YieldRoundingConv,
      @YieldRoundingType   = YieldRoundingType
   from kplus.dbo.Bonds b
   where b.Bonds_Id = @Bonds_Id

   -- вычисляем номинал облигации на дату @CalcDate
   select @CurrentNominal =   @AdjFactor *
                              (
                                 @FaceValue -
                                 (
                                    select isnull(sum(s.CashFlow / (case s.AdjFactor when 0 then 1 else s.AdjFactor end)), 0)
                                    from kplus.dbo.BondsSchedule s
                                    where s.Bonds_Id        = @Bonds_Id
                                       and s.CashFlowType   = 'N'
                                       and s.PaymentDate    <= @CalcDate
                                 )
                              )

   if (select IsCallPutable from kplus.dbo.Bonds where Bonds_Id = @Bonds_Id) != 'N' -- Collable/Puttable(0) <> 'No'
   begin
      if (select DominantYield from kplus.dbo.Bonds where Bonds_Id = @Bonds_Id) = 'N' -- 'Dominant Risk' = 'Next'
      begin
         select
            @OfferDate        = EndDate,
            @RedemptionValue  = RedemptionValue
         from kplus.dbo.BondsCallPut
         where Bonds_Id = @Bonds_Id
            and EndDate = (
                              select min(EndDate)
                              from kplus.dbo.BondsCallPut
                              where Bonds_Id = @Bonds_Id
                              and EndDate > @CalcDate
                           )
      end
   end

   if @OfferDate is null
   begin
      select
         @OfferDate        = max(EndDate),
         @RedemptionValue  = 0
      from kplus.dbo.BondsSchedule
      where Bonds_Id = @Bonds_Id
         and EndDate       > @CalcDate
         and CashFlowType  = 'N'
   end

   if @Price is null or @AccruedAmount is null
   begin
      select
         @MarketPrice   = b.MarketPrice,
         @MarketAccrued = b.Accrued
      from kplus.dbo.BondsRTT b
      where b.Bonds_Id = @Bonds_Id
   end

   select @CurrentBondsPrice =
      isnull(@Price, @MarketPrice) / 100 * @CurrentNominal +
      isnull(@AccruedAmount, round(@MarketAccrued, 3) / 100 * @CurrentNominal)

   select
      @Y1 = -99.99,
      @Y2 = 100000,
      @A  = 0

   while abs(@A - @CurrentBondsPrice) > 0.00000001 and abs(@Y1 - @Y2) > 0.00000001
   begin

      select @Y = (@Y1 + @Y2) / 2

      select
         @A = sum(CashFlow/power((1 + @Y/100),datediff(day,@CalcDate,EndDate)/365.0))
      from kplus.dbo.BondsSchedule
      where Bonds_Id = @Bonds_Id
         and CashFlowType  in ('I', 'N')
         and EndDate       > @CalcDate
         and EndDate       <= @OfferDate

      select
         @A = isnull(@A,0) + @RedemptionValue/power((1 + @Y/100), datediff(day, @CalcDate, @OfferDate)/365.0)

      if @A > @CurrentBondsPrice
      begin
         select @Y1 = @Y
      end
      else
      begin
         select @Y2 = @Y
      end
   end

   select
      @ApproximateYield = dbo.Radius_Lib_Round(@Y, @YieldRoundingConv, @YieldRoundingType)

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_YearFraction_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_YearFraction_Get
GO

create procedure Radius_Lib_YearFraction_Get
/*
   Расчет доли года в периоде. Если параметры не переданы, то процедура работает по входной таблице
*/
(
   @StartDate      datetime = null,
   @EndDate        datetime = null,
   @Basis          char(1)  = null,
   @Frequency      char(1)  = 'A', -- значение по умолчанию как в таблице, чтобы не вставить Null
   @Period         char(1)  = 'F', -- значение по умолчанию как в таблице, чтобы не вставить Null
   @Currencies_Id  int      = null,
   @Cities_Id      int      = null,
   @YearFraction   float    = null output
)
as
begin

   -- если процедуру вызвали с параметрами, то считаем базис для переданных параметров, а на табличку не смотрим
   if @Basis is not null
   begin
      -- зачищаем входную таблицу
      delete from Radius_Lib_YearFraction where SPID = @@spid
      -- кладём в нее параметры процедуры
      insert into Radius_Lib_YearFraction
         (SPID, StartDate, EndDate, Frequency, Basis, Period, Currencies_Id, Cities_Id)
      values
         (@@spid, @StartDate, @EndDate, @Frequency, @Basis, @Period, @Currencies_Id, @Cities_Id)

      -- и вызываем процедуру еще раз - теперь уже без параметров
      exec Radius_Lib_YearFraction_Get

      -- читаем результат
      select @YearFraction = YearFraction from Radius_Lib_YearFraction where SPID = @@spid
      delete from Radius_Lib_YearFraction where SPID = @@spid

      return
   end

   -- считаем по входной таблице
   declare
      @StartDateC      datetime,
      @EndDateC        datetime,
      @StartYear       int,
      @EndYear         int,
      @BissexNbr       int,
      @Year            int,
      @BasisC          char(1),
      @FrequencyC      char(1)

   ------------------------------------------------
   -- Считаем для базисов M,5,D,F,B,N,C,I,A,R,E,Y,4,Z
   -- для базисов 6,J,2 считаем ниже
   update Radius_Lib_YearFraction set
      YearFraction =
         case Basis
            when 'M' then  -- ACT/360
                        convert(float, datediff(dd,StartDate,EndDate)) / 360
            when '5' then  -- ACT/365
                        convert(float, datediff(dd,StartDate,EndDate)) / 365
            when '4' then  -- ACT/364
                           --For the year fraction calculation, Kondor+ uses this formula for the ACT/364 day count basis: n/364
                        convert(float, datediff(dd,StartDate,EndDate)) / 364
            when 'D' then  -- ACT+1/360
                           -- KONDOR+ REFERENCE: Kondor+ applies the basis to the first cash flow in the schedule. Kondor+
                           --                    calculates the other cash flows by using the ACT/365 and ACT/360 bases
                        convert(float, datediff(dd,StartDate,EndDate) + case Period when 'F' then 1 else 0 end) / 360
            when 'F' then  -- ACT+1/365
                        convert(float, datediff(dd,StartDate,EndDate) + case Period when 'F' then 1 else 0 end) / 365
            when 'B' then  -- ACT/365.25
                        convert(float, datediff(dd,StartDate,EndDate)) / 365.25
            when 'N' then  -- ACT/nACT
                        case Frequency
                           when 'S' then convert(float, datediff(dd,StartDate,EndDate)) / (datediff(day, StartDate, dateadd(month, 6, StartDate)) * 2)
                           when 'H' then convert(float, datediff(dd,StartDate,EndDate)) / (datediff(day, StartDate, dateadd(month, 6, StartDate)) * 2)
                           when 'Q' then convert(float, datediff(dd,StartDate,EndDate)) / (datediff(day, StartDate, dateadd(month, 3, StartDate)) * 4)
                           when 'B' then convert(float, datediff(dd,StartDate,EndDate)) / (datediff(day, StartDate, dateadd(month, 2, StartDate)) * 6)
                           when 'M' then convert(float, datediff(dd,StartDate,EndDate)) / (datediff(day, StartDate, dateadd(month, 1, StartDate)) *12)
                           else          convert(float, datediff(dd,StartDate,EndDate)) / (datediff(day, StartDate, dateadd(year,  1, StartDate)) * 1)
                        end
            when 'C' then  -- 30/360
                        convert(float, (360 * (datepart(year, EndDate) - datepart(year, StartDate)) +
                            30  * (datepart(month, EndDate) - datepart(month, StartDate)) +
                                  (datepart(day, EndDate) - datepart(day, StartDate))
                           )
                           + case when datepart(day, StartDate) = 31 then 1 else 0 end
                           + case when (datepart(day, EndDate) = 31 and datepart(day, StartDate) >= 30) then -1 else 0 end
                        ) / 360
            when 'E' then  -- 30E/360
                        convert(float, (360 * (datepart(year, EndDate) - datepart(year, StartDate)) +
                             30 * (datepart(month, EndDate) - datepart(month, StartDate)) +
                                  (datepart(day, EndDate) - datepart(day, StartDate))
                           )
                           + case when datepart(day, StartDate) = 31 then 1 else 0 end
                           + case when datepart(day, EndDate) = 31 then -1 else 0 end
                        ) / 360
            when 'I' then  -- 30E+1/360 (ITL)
                        convert(float, (360 * (datepart(year, EndDate) - datepart(year, StartDate)) +
                             30 * (datepart(month, EndDate) - datepart(month, StartDate)) +
                                  (datepart(day, EndDate) - datepart(day, StartDate))
                           )
                           + case when datepart(day, StartDate) = 31 then 1 else 0 end
                           + case when datepart(day, EndDate) = 31 then -1 else 0 end
                           + 1
                        ) / 360
            when 'A' then  -- ACT/ACT
                        (
                           (1 - convert(float, datepart(dayofyear, StartDate) - 1)
                                / datediff(day,
                                             convert(datetime, '01/01/' + convert(char, datepart(year, StartDate)), 101),
                                             convert(datetime, '01/01/' + convert(char, datepart(year, StartDate) + 1), 101)
                                          )
                           )
                           +
                           (
                              convert(float, datepart(dayofyear, EndDate) - 1)
                              / datediff(day,
                                          convert(datetime, '01/01/' + convert(char, datepart(year, EndDate)), 101),
                                          convert(datetime, '01/01/' + convert(char, datepart(year, EndDate) + 1), 101)
                                        )
                           )
                           +
                           datepart(year,EndDate) - datepart(year,StartDate) - 1
                        )
            when 'R' then  -- ACT/ACT(RUS)
                        (
                           (1 - convert(float, datepart(dayofyear, StartDate))
                                / datediff(day,
                                             convert(datetime, '01/01/' + convert(char, datepart(year, StartDate)), 101),
                                             convert(datetime, '01/01/' + convert(char, datepart(year, StartDate) + 1), 101)
                                          )
                           )
                           +
                           (
                              convert(float, datepart(dayofyear, EndDate))
                              / datediff(day,
                                          convert(datetime, '01/01/' + convert(char, datepart(year, EndDate)), 101),
                                          convert(datetime, '01/01/' + convert(char, datepart(year, EndDate) + 1), 101)
                                        )
                           )
                           +
                           datepart(year,EndDate) - datepart(year,StartDate) - 1
                        )
            when 'Y' then  -- 30E/360 (FEB)
                           -- Kondor+ modifies the values so that all months have 30 days, except for February that has 28 days.
                           -- This is equivalent to 30E/360 Basis for February - Day Count.
                        convert(float, 360 * (datepart(year, EndDate) - datepart(year, StartDate)) +
                                   30 * (datepart(month, EndDate) - datepart(month, StartDate)) +
                                  case when datepart(day, EndDate) > 30 then 30 else datepart(day, EndDate) end -
                                  case when datepart(day, StartDate) > 30 then 30 else datepart(day, StartDate) end
                        ) / 360

            when 'Z' then  -- ACT+1/365(Thai)
                           -- The Thai basis for day count applies for:
                           -- - the first interest period is equivalent to ACT+1/365
                           -- - the last interest period is ACT-1/365
                           -- - other interest period ACT/365ACT
                        convert(float, datediff(dd,StartDate,EndDate) +
                                  case Period when 'F' then 1 when 'L' then -1 when 'M' then 0 else 0 end
                        ) / 365
         end
   where SPID        = @@SPID
      and Basis      not in ('6','J','2')
      and StartDate  is not null
      and EndDate    is not null
      and EndDate    > StartDate

   ------------------------------------------------
   -- для базисов 6 (ACT/365 (366)), J (ACT/365 (JPY))
   -- для базиса 2 считаем ниже
   
   declare Years cursor  for 
         select
            StartDate, EndDate, Basis, Frequency
         from Radius_Lib_YearFraction
         where SPID        = @@SPID
            and Basis      in ('6','J')
            and StartDate  is not NULL
            and EndDate    is not NULL
            and EndDate    > StartDate
         for update
      
   open Years

   fetch Years into @StartDateC, @EndDateC, @BasisC, @FrequencyC
   while (@@sqlstatus = 0)
   begin
      
         select
            @StartYear  = datepart(year, @StartDateC),
            @EndYear    = datepart(year, @EndDateC)

         select
            @Year       = @StartYear,
            @BissexNbr  = 0

         while (@Year <= @EndYear)
         begin
            if ((@Year % 4 = 0) and (@Year % 100 != 0)) or  (@Year % 400 = 0)
            begin
               if @StartDateC <= convert(varchar, @Year) + '0229' and @EndDateC >= convert(varchar, @Year) + '0229'
               begin
                  select  @BissexNbr = @BissexNbr + 1
               end
            end
            select @Year = @Year + 1
         end

         update Radius_Lib_YearFraction set
            YearFraction =
               case
                  when Basis = 'J' then     convert(float, datediff(day, @StartDateC, @EndDateC) - @BissexNbr) / 365
                  when @BissexNbr = 0 then  convert(float, datediff(day, @StartDateC, @EndDateC)) / 365
                  when @BissexNbr != 0 then convert(float, datediff(day, @StartDateC, @EndDateC)) /366
               end
         where SPID        = @@SPID
            and StartDate  = @StartDateC
            and EndDate    = @EndDateC
            and Basis      = @BasisC
            and Frequency  = @FrequencyC
      
   
      fetch Years into @StartDateC, @EndDateC, @BasisC, @FrequencyC
   end -- while (@@sqlstatus = 0)

   close Years
   deallocate cursor Years


   ------------------------------------------------
   -- для базиса 2 (BUS/252)
   /*
      BUS/252 Kondor+ uses the BUS/252 day count basis to calculate the year fraction for certain South American
      markets, in particular the Brazilian bond market. This convention uses 252 business days per year as a
      base. Kondor+ calculates the year fraction as follows: YearFraction = Bus_D1_D2/252
      where Bus_D1_D2 is the number of business days between D1 and D2 determined from the holiday calendar

      Базис рассчитывается как YearFraction = Bus_D1_D2 / 252
         Bus_D1_D2 - это количество рабочих дней в периоде (@StartDate; @EndDate - 1) (проценты начисляются в конце рабочего дня)
   */
   -- найдем Cities_Id там, где этот параметр не указан
   update  Radius_Lib_YearFraction set
      Cities_Id =  c.Cities_Id
   from kplus..Currencies c
   where Radius_Lib_YearFraction.SPID     = @@SPID
      and Radius_Lib_YearFraction.Basis   = '2'
      and c.Currencies_Id                 = Radius_Lib_YearFraction.Currencies_Id
      and isnull(Radius_Lib_YearFraction.Cities_Id, 0) = 0

   update  Radius_Lib_YearFraction set
      YearFraction =
         (
            select
               convert(float, datediff(dd,y.StartDate, y.EndDate) - count(*)) / 252
            from Kustom..Radius_Lib_Calendar c
            where c.Date between y.StartDate and dateadd(dd, -1, y.EndDate)
            and
            (
               exists
                  (
                     select 1
                     from kplus..WeekHolidays w
                     where w.Cities_Id = y.Cities_Id
                        and DayOfWeek  = datepart(dw, c.Date) - 1
                  )
               or
               exists
                  (
                     select 1
                     from kplus..FixedHolidays f
                     where f.Cities_Id             = y.Cities_Id
                        and day(f.HolidayDate)     = day(c.Date)
                        and month(f.HolidayDate)   = month(c.Date)
                  )
               or
               exists
                  (
                     select 1
                     from kplus..VariableHolidays v
                     where v.Cities_Id                            = y.Cities_Id
                        and datediff(dy, v.HolidayDate, c.Date)   = 0
                  )
            )
         )
   from Radius_Lib_YearFraction y
   where SPID        = @@SPID
      and Basis      in ('2')
      and StartDate  is not null
      and EndDate    is not null
      and EndDate    > StartDate

   -- для базиса BUS/252, если переданного города не существует, то YearFraction возвращаем 0
   update  Radius_Lib_YearFraction set
      YearFraction = 0
   from Radius_Lib_YearFraction y
   where SPID        = @@SPID
      and Basis      in ('2')
      and not exists
         (
            select c.Cities_Id from kplus..Cities c where c.Cities_Id = y.Cities_Id
         )

   update Radius_Lib_YearFraction set
      YearFraction = 0
   where SPID     = @@SPID
      and EndDate <= StartDate
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_ShiftDays_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_ShiftDays_Get
GO

create procedure Radius_Lib_ShiftDays_Get
as
BEGIN
   declare
      @StartDate      datetime,
      @EndDate         datetime,
      @MinDate         datetime,
      @MaxDate         datetime,
      @CCY_Id         int,
      @Cities_Id      int

   select
      @MaxDate = max(dateadd(dd,Shift+50,StartDate)),
      @MinDate   = min(dateadd(dd,Shift-50,StartDate))
   from #ShiftDays_Input

   declare CCY cursor for
   select distinct Currencies_Id from #ShiftDays_Input

   open CCY
   fetch CCY into @CCY_Id

   while @@sqlstatus = 0
   begin
      create table #tmp_ccy_1 (id int identity, Date   datetime)
      create table #tmp_ccy_2 (id int identity, Date   datetime)

      select @Cities_Id = Cities_Id from kplus..Currencies where Currencies_Id = @CCY_Id

      insert #tmp_ccy_1
      select c.Date
      from Radius_Lib_Calendar c
         left outer join kplus.dbo.WeekHolidays w
            on datepart(weekday, c.Date) - 1 = w.DayOfWeek
            and w.Cities_Id = @Cities_Id
         left outer join kplus.dbo.FixedHolidays f
            on datepart(dd,f.HolidayDate) = datepart(dd,c.Date)
            and datepart(mm,f.HolidayDate) = datepart(mm,c.Date)
            and f.Cities_Id = @Cities_Id
         left outer join kplus.dbo.VariableHolidays v
            on datediff(dy, v.HolidayDate, c.Date) = 0
            and v.Cities_Id = @Cities_Id
      where 1=1
         and c.Date between @MinDate and @MaxDate
         and case
                 when datepart(weekday, c.Date) - 1 = w.DayOfWeek  then 1
                 when datepart(dd,f.HolidayDate) = datepart(dd,c.Date)
                      and datepart(mm,f.HolidayDate) = datepart(mm,c.Date) then 2
                 when datediff(dy, v.HolidayDate, c.Date) = 0 then 3
                 else 0
              end = 0
      order by c.Date

      insert #tmp_ccy_2 (Date) values ('19000101')
      insert #tmp_ccy_2
      select Date from #tmp_ccy_1 order by Date


      insert #ShiftDays_Result (Currencies_Id, StartDate, EndDate)
      select @CCY_Id, t2.Date, t1.Date
      from #tmp_ccy_1 t1
         inner join #tmp_ccy_2 t2
            on t2.id = t1.id
      where 1=1

      drop table #tmp_ccy_1
      drop table #tmp_ccy_2

      fetch CCY into @CCY_Id
   end
   close CCY
   deallocate cursor CCY
END

GO

IF OBJECT_ID ('dbo.Radius_Lib_PositionsAssets_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_PositionsAssets_Get
GO

-- version: __VERSION
-- date: '__DATE_VSS' 
create procedure Radius_Lib_PositionsAssets_Get
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/* . Author: Fonarev Oleg                                                                               */
/* Процедура возвращает состояние позиции в разрезе дат от StartDate до EndDate                         */
/* Входные данные:                                                                                      */
/*   @StartDate -- дата начала диапазона                                                                */
/*   @EndDate   -- дата окончания диапазона                                                             */
/*  таблица Radius_Lib_Objects                                                                          */
/*     SPID         -- id текущего пользователя                                                         */
/*     Objects_Id   -- RadiusPositionsAssets_Id                                                         */
/*     ObjectsType  -- A                                                                                */
/* Выходные данные: таблица #pos_lib с состоянием позиции по датам                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @StartDate datetime,
   @EndDate datetime
)
as
begin
   declare @TL_ProcName varchar(50), @TL_ExecProc varchar(50), @TL_Scope varchar(50), @TL_Cmd varchar(100), @TL_TimingIsEnabled char(1), @TL_TimeStamp datetime select @TL_TimingIsEnabled = 'N', @TL_TimeStamp = getdate(), @TL_Scope = object_name(@@procid), @TL_ExecProc = 'RadiusTimingLog_INIT' if object_id('Kustom..RadiusTimingLog_INIT') is not NULL exec @TL_ExecProc 'PositionServer',@TL_Scope,@TimingIsEnabled = @TL_TimingIsEnabled output
/*

create table #pos_lib
(
    Date                     datetime      NOT NULL,
    PrevDate                 datetime      NOT NULL,
    RadiusPositionsAssets_Id numeric(10,0) DEFAULT 0 NOT NULL,
    RadiusPositions_Id       numeric(10,0) DEFAULT 0 NOT NULL,
    TransactionId            int           DEFAULT 0 NULL,
    Updated                  datetime      NULL,
    AssetsType               char(3)       NULL,
    Assets_Id                int           NULL,
    Events_Id                numeric(10,0) NULL,
    Events_SortCode          varchar(50)   NULL,
    Currencies_Id            int           NULL,
    OpenQty                  float         DEFAULT 0 NULL,
    OpenAmount               float         DEFAULT 0 NULL,
    OpenAccrued              float         DEFAULT 0 NULL,
    LastRevalDate            datetime      NULL,
    LastRevalPrice           float         DEFAULT 0 NULL,
    LastRevalAccrued         float         DEFAULT 0 NULL,
    StartQty                 float         DEFAULT 0 NULL,
    BuyQty                   float         DEFAULT 0 NULL,
    SellQty                  float         DEFAULT 0 NULL,
    BuyAmount                float         DEFAULT 0 NULL,
    SellAmount               float         DEFAULT 0 NULL,
    FeesAmount               float         DEFAULT 0 NULL,
    CouponRcv                float         DEFAULT 0 NULL,
    PrincipalRcv             float         DEFAULT 0 NULL,
    RealizedAccrued          float         DEFAULT 0 NULL,
    RealizedPrice            float         DEFAULT 0 NULL,
    BuyQtyC                  float         DEFAULT 0 NULL,
    SellQtyC                 float         DEFAULT 0 NULL,
    BuyAmountC               float         DEFAULT 0 NULL,
    SellAmountC              float         DEFAULT 0 NULL,
    FeesAmountC              float         DEFAULT 0 NULL,
    CouponRcvC               float         DEFAULT 0 NULL,
    PrincipalRcvC            float         DEFAULT 0 NULL,
    RealizedAccruedC         float         DEFAULT 0 NULL,
    RealizedPriceC           float         DEFAULT 0 NULL,
    CustVal1                 float         NULL,
    CustVal2                 float         NULL,
    CustVal3                 float         NULL,
    CustVal4                 float         NULL,
    CustVal5                 float         NULL,
    CustVal6                 float         NULL,
    CustVal7                 float         NULL,
    CustVal8                 float         NULL,
    CustVal9                 varchar(32)   NULL,
    CustVal10                varchar(32)   NULL,
    CustVal11                varchar(32)   NULL,
    CustVal12                varchar(32)   NULL,
    CustVal13                float         NULL,
    CustVal14                float         NULL,
    CustVal15                float         NULL,
    CustVal16                float         NULL,
    CustVal17                float         NULL,
    CustVal18                float         NULL,
    CustVal19                float         NULL,
    CustVal20                float         NULL,
    CustVal21                float         NULL,
    CustVal22                float         NULL,
    CustVal23                float         NULL,
    CustVal24                float         NULL,
    CustVal25                float         NULL,
    CustVal26                float         NULL,
    CustVal27                float         NULL,
    CustVal28                float         NULL,
    CustVal29                float         NULL,
    CustVal30                float         NULL,
    CustVal31                float         NULL,
    CustVal32                float         NULL,
    Currencies_Id_PL         int           NULL
)

*/

   declare
   @RadiusPositionsAssets_Id numeric(10),
   @today   datetime,
   @LastDate datetime -- дата последнего события

   select @today = getdate()

   if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'14416',6)+'//'+'Fill #PositionsAssets', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end

   insert into #pos_lib
   (
      Date, PrevDate, RadiusPositionsAssets_Id, RadiusPositions_Id, TransactionId, Updated, AssetsType, Assets_Id,
      Events_Id, Events_SortCode, Currencies_Id, OpenQty, OpenAmount, OpenAccrued, LastRevalDate,
      LastRevalPrice, LastRevalAccrued, StartQty, BuyQty, SellQty, BuyAmount, SellAmount, FeesAmount,
      CouponRcv, PrincipalRcv, RealizedAccrued, RealizedPrice,
      BuyQtyC, SellQtyC, BuyAmountC, SellAmountC, FeesAmountC,
      CouponRcvC, PrincipalRcvC, RealizedAccruedC, RealizedPriceC,
      CustVal1, CustVal2, CustVal3, CustVal4,
      CustVal5, CustVal6, CustVal7, CustVal8, CustVal9, CustVal10, CustVal11, CustVal12, CustVal13,
      CustVal14, CustVal15, CustVal16, CustVal17, CustVal18, CustVal19, CustVal20, CustVal21, CustVal22,
      CustVal23, CustVal24, CustVal25, CustVal26, CustVal27, CustVal28, CustVal29, CustVal30, CustVal31,
      CustVal32, Currencies_Id_PL
   )
   select
      c.Date, dateadd(dd,-1,c.Date),
      h.RadiusPositionsAssets_Id, h.RadiusPositions_Id, h.TransactionId, h.Updated, h.AssetsType, h.Assets_Id,
      h.Events_Id, h.Events_SortCode, h.Currencies_Id, h.OpenQty, h.OpenAmount, h.OpenAccrued, h.LastRevalDate,
      h.LastRevalPrice, h.LastRevalAccrued, h.StartQty, h.BuyQty, h.SellQty, h.BuyAmount, h.SellAmount, h.FeesAmount,
      h.CouponRcv, h.PrincipalRcv, h.RealizedAccrued, h.RealizedPrice,
      h.BuyQtyC, h.SellQtyC, h.BuyAmountC, h.SellAmountC, h.FeesAmountC,
      h.CouponRcvC, h.PrincipalRcvC, h.RealizedAccruedC, h.RealizedPriceC,
      h.CustVal1, h.CustVal2, h.CustVal3, h.CustVal4,
      h.CustVal5, h.CustVal6, h.CustVal7, h.CustVal8, h.CustVal9, h.CustVal10, h.CustVal11, h.CustVal12, h.CustVal13,
      h.CustVal14, h.CustVal15, h.CustVal16, h.CustVal17, h.CustVal18, h.CustVal19, h.CustVal20, h.CustVal21, h.CustVal22,
      h.CustVal23, h.CustVal24, h.CustVal25, h.CustVal26, h.CustVal27, h.CustVal28, h.CustVal29, h.CustVal30, h.CustVal31,
      h.CustVal32, h.Currencies_Id_PL
   from Radius_Lib_Objects o
      inner join RadiusPositionsAssets a
         on a.RadiusPositionsAssets_Id = o.Objects_Id
      inner join Radius_Lib_Calendar c
         on c.Date between @StartDate and @EndDate
         and c.Date < convert(datetime,substring(a.Events_SortCode,1,8),112)
      inner join RadiusPositionsAssetsHist h
         on h.RadiusPositionsAssets_Id = o.Objects_Id
         and h.RecordType = 'N'
         and c.Date >= h.HistDate
         and c.Date < h.HistDateTo
   where 1=1
      and o.ObjectsType = 'A'
      and o.SPID = @@SPID

   insert into #pos_lib
   (
      Date, PrevDate, RadiusPositionsAssets_Id, RadiusPositions_Id, TransactionId, Updated, AssetsType, Assets_Id,
      Events_Id, Events_SortCode, Currencies_Id, OpenQty, OpenAmount, OpenAccrued, LastRevalDate,
      LastRevalPrice, LastRevalAccrued, StartQty, BuyQty, SellQty, BuyAmount, SellAmount, FeesAmount,
      CouponRcv, PrincipalRcv, RealizedAccrued, RealizedPrice,
      BuyQtyC, SellQtyC, BuyAmountC, SellAmountC, FeesAmountC,
      CouponRcvC, PrincipalRcvC, RealizedAccruedC, RealizedPriceC,
      CustVal1, CustVal2, CustVal3, CustVal4,
      CustVal5, CustVal6, CustVal7, CustVal8, CustVal9, CustVal10, CustVal11, CustVal12, CustVal13,
      CustVal14, CustVal15, CustVal16, CustVal17, CustVal18, CustVal19, CustVal20, CustVal21, CustVal22,
      CustVal23, CustVal24, CustVal25, CustVal26, CustVal27, CustVal28, CustVal29, CustVal30, CustVal31,
      CustVal32, Currencies_Id_PL
   )
   select
      c.Date, dateadd(dd,-1,c.Date), a.RadiusPositionsAssets_Id, a.RadiusPositions_Id, a.TransactionId, a.Updated, a.AssetsType, a.Assets_Id,
      a.Events_Id, a.Events_SortCode, a.Currencies_Id, a.OpenQty, a.OpenAmount, a.OpenAccrued, a.LastRevalDate,
      a.LastRevalPrice, a.LastRevalAccrued, a.StartQty, a.BuyQty, a.SellQty, a.BuyAmount, a.SellAmount, a.FeesAmount,
      a.CouponRcv, a.PrincipalRcv, a.RealizedAccrued, a.RealizedPrice,
      a.BuyQtyC, a.SellQtyC, a.BuyAmountC, a.SellAmountC, a.FeesAmountC,
      a.CouponRcvC, a.PrincipalRcvC, a.RealizedAccruedC, a.RealizedPriceC,
      a.CustVal1, a.CustVal2, a.CustVal3, a.CustVal4,
      a.CustVal5, a.CustVal6, a.CustVal7, a.CustVal8, a.CustVal9, a.CustVal10, a.CustVal11, a.CustVal12, a.CustVal13,
      a.CustVal14, a.CustVal15, a.CustVal16, a.CustVal17, a.CustVal18, a.CustVal19, a.CustVal20, a.CustVal21, a.CustVal22,
      a.CustVal23, a.CustVal24, a.CustVal25, a.CustVal26, a.CustVal27, a.CustVal28, a.CustVal29, a.CustVal30, a.CustVal31,
      a.CustVal32, a.Currencies_Id_PL
   from Radius_Lib_Objects o
      inner join Radius_Lib_Calendar c
         on c.Date between @StartDate and @EndDate
      inner join RadiusPositionsAssets a
         on a.RadiusPositionsAssets_Id = o.Objects_Id
         and c.Date between convert(datetime,substring(a.Events_SortCode,1,8),112) and '20501231'
   where 1=1
      and o.ObjectsType = 'A'
      and o.SPID = @@SPID

   if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'14496',6)+'//'+'Finish', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_NumToStr') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_NumToStr
GO

create procedure Radius_Lib_NumToStr
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/*   Процедура преобразует число в строку с указанными десятичными и разрядными разделителями.          */
/*   Возвращает не более 15 значимых цифр.                                                              */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @Number              float,
   @Result              varchar(50) output,
   @DecimalSeparator    varchar(1)  = null,
   @ThousandSeparator   varchar(1)  = null,  -- для Sybase: для передачи пустого сепаратора нужно передавать Null ('' не годится, превратится в ' ')
   @FormatMask          varchar(17) = null   -- задается в формате '0.0..0#..#'; 0 - цифра выводится всегда, # - цифра выводится, если значима
)
as
begin
   
   

   declare
      @Sign             varchar(1),       -- знак числа
      @Exp              int,              -- 15 - [экспонента числа]
      @Scale            int,              -- максимальная длина дробной части ('0000###')
      @MandatoryScale   int,              -- минимальная длина дробной части ('0000')
      @RoundScale       int,              -- точность округления
      @Rounded          numeric(38, 15),  -- число после округления
      @RoundedStr       varchar(400),     -- число после округления в виде строки
      @WholePart        varchar(50),      -- целая часть
      @Res              int,
      @DecimalPart      varchar(50)       -- дробная часть

   select
      @DecimalSeparator    = isnull(@DecimalSeparator, '.'),
      @ThousandSeparator   = case when @ThousandSeparator is null then ltrim('') else @ThousandSeparator end, -- нельзя использовать isnull(@s,''), т.к. в Sybase '' превращается в ' '
      @FormatMask          =
         case
            when @FormatMask is null   then '0.###############'
            when @FormatMask = ''      then '0'
            else @FormatMask
         end

   -- проверяем формат
   if @FormatMask           <> '0'
      and @FormatMask       is not null
      and
      (
         @FormatMask        not like '0._%'
         or
         @FormatMask        like '0.%[^0#]%'    -- содержит символы отличные от '0' и '#'
         or
         @FormatMask        like '0.%#%0%'      -- символы '#' не могут стоять до символов '0'
      )
   begin
      set @Result = 'Incorrect Format: ' + @FormatMask
      return 
   end

   -- сохраняем знак числа и число без знака
   select
      @Sign    =
         case
            when @Number < 0 then '-'
            else ''
         end,
      @Number  = abs(@Number),
      @Exp     = 14 + (case when abs(@Number) < 1 then 1 else 0 end) -
         case
            when @Number = 0 then 0
            else convert(int, log10(abs(@Number)))
         end

   -- получаем максимальную и минимальную длину дробной части
   select
      @Scale          =
         case
            when char_length(@FormatMask) > 2 then isnull(char_length(ltrim(rtrim(str_replace(@FormatMask,'0.','')))), 0)
            else 0
         end,
      @MandatoryScale =
         case
            when char_length(@FormatMask) > 2 then isnull(char_length(ltrim(rtrim(str_replace(str_replace(@FormatMask,'0.',''),'#','')))), 0)
            else 0
         end

   -- получаем точность округления - она не должна выходить за границы float, иначе появятся "хвосты" при преобразовании к numeric
   set @RoundScale =
      case
         when @Scale > @Exp then @Exp
         else @Scale
      end

   -- округляем число до необходимой точности
   set @Number = dbo.Radius_Lib_Round(@Number, @RoundScale, 'R')

   -- преобразуем к numeric(38, 15) через промежуточное преобразование к numeric(38, @RoundScale)
   set @Rounded =
      case @RoundScale
         when 0 then convert(numeric(38, 15), convert(numeric(38, 0), @Number))
         when 1 then convert(numeric(38, 15), convert(numeric(38, 1), @Number))
         when 2 then convert(numeric(38, 15), convert(numeric(38, 2), @Number))
         when 3 then convert(numeric(38, 15), convert(numeric(38, 3), @Number))
         when 4 then convert(numeric(38, 15), convert(numeric(38, 4), @Number))
         when 5 then convert(numeric(38, 15), convert(numeric(38, 5), @Number))
         when 6 then convert(numeric(38, 15), convert(numeric(38, 6), @Number))
         when 7 then convert(numeric(38, 15), convert(numeric(38, 7), @Number))
         when 8 then convert(numeric(38, 15), convert(numeric(38, 8), @Number))
         when 9 then convert(numeric(38, 15), convert(numeric(38, 9), @Number))
         when 10 then convert(numeric(38, 15), convert(numeric(38, 10), @Number))
         when 11 then convert(numeric(38, 15), convert(numeric(38, 11), @Number))
         when 12 then convert(numeric(38, 15), convert(numeric(38, 12), @Number))
         when 13 then convert(numeric(38, 15), convert(numeric(38, 13), @Number))
         when 14 then convert(numeric(38, 15), convert(numeric(38, 14), @Number))
         else convert(numeric(38, 15), @Number)
      end

   -- преобразуем число в строку
   set @RoundedStr = convert(varchar(400), @Rounded)

   -- получаем целую часть - без символа-разделителя и 15-ти символов дробной части
   set @WholePart = left(@RoundedStr, char_length(@RoundedStr) - 1 - 15)

   -- формируем целую часть с временными разделителями
   set @Res       = char_length(@WholePart) % 3

   set @WholePart =
      substring(@WholePart, 1, @Res) + ' ' +
      substring(@WholePart, 1 + @Res, 3) + ' ' +
      substring(@WholePart, 4 + @Res, 3) + ' ' +
      substring(@WholePart, 7 + @Res, 3) + ' ' +
      substring(@WholePart, 10 + @Res, 3) + ' ' +
      substring(@WholePart, 13 + @Res, 3) + ' ' +
      substring(@WholePart, 16 + @Res, 3) + ' ' +
      substring(@WholePart, 19 + @Res, 3) + ' ' +
      substring(@WholePart, 22 + @Res, 3) + ' ' +
      substring(@WholePart, 25 + @Res, 3)

   -- формируем целую часть с необходимыми разделителями
   set @WholePart = str_replace(ltrim(rtrim(@WholePart)),' ',@ThousandSeparator)

   -- получаем дробную часть - берем 15 символов дробной части, а из них лишь требуемое количество символов
   set @DecimalPart = left(right(@RoundedStr, 15), @Scale)

   -- у дробной части убираем справа нули, если их выводить необязательно
   while @MandatoryScale < char_length(@DecimalPart) and right(@DecimalPart, 1) = '0'
   begin
      set @DecimalPart = left(@DecimalPart, char_length(@DecimalPart) - 1)
   end

   -- формируем результат
   set @Result =
      ltrim(rtrim(
         @Sign + @WholePart +
         (
            case
               when char_length(@DecimalPart) > 0 then @DecimalSeparator + @DecimalPart
               else ''
            end
         )
      ))

   return 

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_IsHoliday_City') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_IsHoliday_City
GO

create procedure Radius_Lib_IsHoliday_City
/*
   Checks if given date is holiday or business day for the city
   returns: 0 for working day, 1 for week holiday, 2 for fixed holiday, 3 for variable holiday
*/
(
   @Cities_Id int,
   @date datetime,
   @result int output
)
as
begin
   if exists( select 1 from kplus..WeekHolidays
            where Cities_Id = @Cities_Id and DayOfWeek = datepart(weekday, @date) - 1 )
      select @result = 1  /* Week holiday founded */
   else if exists( select 1 from kplus..FixedHolidays
            where Cities_Id = @Cities_Id and datepart(dd,HolidayDate) = datepart(dd,@date) and datepart(mm,HolidayDate) = datepart(mm,@date))
      select @result = 2  /* Fixed holiday founded e.g. `Apr 25'  */
   else if exists( select 1 from kplus..VariableHolidays
            where Cities_Id = @Cities_Id and datediff(dy, HolidayDate, @date) = 0 )
      select @result = 3  /* Variable holiday founded */
   else
      select @result = 0  /* Date is not a holiday */
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_IsHoliday_Cities') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_IsHoliday_Cities
GO

create procedure Radius_Lib_IsHoliday_Cities
/*
   Checks if given date is holiday or business day for the BOTH cities (if it is holiday in one of the cities - than it is holiday for both)
   returns: 0 for working day, 1 for week holiday, 2 for fixed holiday, 3 for variable holiday
*/
(
   @Cities_Id1 int,
   @Cities_Id2 int,
   @date datetime,
   @result int output
)
as
begin
   if exists( select 1 from kplus..WeekHolidays
            where Cities_Id in (@Cities_Id1, @Cities_Id2) and DayOfWeek = datepart(weekday, @date) - 1 )
      select @result = 1  /* Week holiday founded */
   else if exists( select 1 from kplus..FixedHolidays
            where Cities_Id in (@Cities_Id1, @Cities_Id2) and datepart(dd,HolidayDate) = datepart(dd,@date) and datepart(mm,HolidayDate) = datepart(mm,@date))
      select @result = 2  /* Fixed holiday founded e.g. `Apr 25'  */
   else if exists( select 1 from kplus..VariableHolidays
            where Cities_Id in (@Cities_Id1, @Cities_Id2) and datediff(dy, HolidayDate, @date) = 0 )
      select @result = 3  /* Variable holiday founded */
   else
      select @result = 0  /* Date is not a holiday */
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_GetWorkingDay') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_GetWorkingDay
GO

create procedure Radius_Lib_GetWorkingDay
/*
   Find the following working day depending on the type of conversion
*/
(
   @Cities_Id1 int,
   @Cities_Id2 int,
   @Cities_Id3 int,         --
   @DateIn datetime,        -- DateIn
   @RollConv char(1),       -- M - Modified Following, F - Following
   @DateOut datetime output -- DateOut
)
as
begin
   exec Radius_Lib_AddDays_Cities3 @Cities_Id1, @Cities_Id2, @Cities_Id3, @DateIn, 0, @DateOut out
   if datepart(mm,@DateIn) <> datepart(mm,@DateOut) and @RollConv = 'M'
   begin
      declare @result int
      select @result = 1
      select @DateOut = @DateIn
      while @result <> 0 begin
         select @result = 0
         select @DateOut = dateadd(dd, -1, @DateOut)
         if @Cities_Id1 <> 0 exec Radius_Lib_IsHoliday_Cities @Cities_Id1, 0, @DateOut, @result out
         if @Cities_Id2 <> 0 and @result <> 0 exec Radius_Lib_IsHoliday_Cities @Cities_Id2, 0, @DateOut, @result out
         if @Cities_Id3 <> 0 and @result <> 0 exec Radius_Lib_IsHoliday_Cities @Cities_Id3, 0, @DateOut, @result out
      end
   end
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_FwdInterestRate_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_FwdInterestRate_Get
GO

create procedure Radius_Lib_FwdInterestRate_Get
/*------------------------------------------------------------------------------------------------------*/
/*  Расчет форвардной процентной ставки на форвардную дату ForwardStartDate на срок ForwardEndDate      */
/*  на основе ставок из кривой.                                                                         */
/*  Расчетные формулы взяты из kplus_30_calculations.pdf, Chapter 25, Future Cash Flows                 */
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*   Автор Мельников М.В., 16.08.2012                                                                   */
/*------------------------------------------------------------------------------------------------------*/
as
begin

   create table #cfcf
   (
      Curves_Id         int null,
      Basis             chaR(1) null,
      Date              datetime null,
      ForwardStartDate  datetime null,
      ForwardEndDate    datetime null,

      DF_Method         char(1) null,
      RateStart         float null,
      RateEnd           float null,
      YF                float null,
      DFStart           float null,
      DFEnd             float null,
      FwdRate           float null,
      DaysStart         float null,
      DaysEnd           float null
   )

   insert into #cfcf (Curves_Id, Basis, Date, ForwardStartDate, ForwardEndDate)
   select DISTINCT Curves_Id, Basis, Date, ForwardStartDate, ForwardEndDate
   from Radius_Lib_FwdInterestRate where SPID = @@spid


   --определяем метод для расчета дисконтных факторов (C-Compounded Interest, E-Exponential)
   --достаем метод сначала из параметров кривой.
   --здесь могут быть значения: C-Compounded Interest, E-Exponential, S-simple
   update #cfcf
   set DF_Method = c.DiscountFactorForm
   from kplus.dbo.Curves c
   where c.Curves_Id = #cfcf.Curves_Id

   --данная процедура может рассчитывать дисконтные факторы только двумя методами, C или E,
   --поэтому, если в кривой задан метод S, то достаем метод из настроек К+ (где возможны только значения C или E)
   update #cfcf
   set DF_Method = (select DiscountFactorForm from kplus.dbo.IdentityCard)
   where isnull(DF_Method, '') not in ('C', 'E')



   --из кривой получаем процентные ставки на даты ForwardStartDate и ForwardEndDate
   delete from Radius_Lib_CurvesRates where SPID = @@spid

   insert into Radius_Lib_CurvesRates (SPID, Curves_Id, StartDate, EndDate)
      select @@spid, Curves_Id, Date, ForwardStartDate from #cfcf
      union
      select @@spid, Curves_Id, Date, ForwardEndDate from #cfcf

   exec Radius_Lib_CurvesRates_Get

   update #cfcf set
      RateStart = isnull(r1.ZeroRate, 0),
      RateEnd   = isnull(r2.ZeroRate, 0)
   from #cfcf cf
         left outer join Radius_Lib_CurvesRates r1
            on r1.SPID = @@spid
            and r1.Curves_Id = cf.Curves_Id
            and r1.StartDate = cf.Date
            and r1.EndDate = cf.ForwardStartDate

         left outer join Radius_Lib_CurvesRates r2
            on r2.SPID = @@spid
            and r2.Curves_Id = cf.Curves_Id
            and r2.StartDate = cf.Date
            and r2.EndDate = cf.ForwardEndDate

   delete from Radius_Lib_CurvesRates where SPID = @@spid


   --рассчитываем YearFraction для периода ForwardStartDate-ForwardEndDate по базису @Basis
   delete from Radius_Lib_YearFraction where SPID = @@spid

   insert into Radius_Lib_YearFraction (SPID, StartDate, EndDate, Frequency, Basis )
   select DISTINCT @@spid, ForwardStartDate, ForwardEndDate, 'A', Basis from #cfcf

   exec Radius_Lib_YearFraction_Get

   update #cfcf
   set YF = y.YearFraction
   from Radius_Lib_YearFraction y
   where y.SPID = @@spid
   and y.StartDate = #cfcf.ForwardStartDate
   and y.EndDate = #cfcf.ForwardEndDate
   and y.Basis = #cfcf.Basis

   delete from Radius_Lib_YearFraction where SPID = @@spid



   update #cfcf set
      DaysStart = datediff(dd, Date, ForwardStartDate),
      DaysEnd   = datediff(dd, Date, ForwardEndDate)


   --рассчитываем дисконтные факторы
   update #cfcf set
      DFStart = 1 / power(1 + RateStart/100, DaysStart/365),      --именно 365, а не YearFraction, зависящий от базиса.   См.kplus_30_calculations.pdf, Chapter 25, Future Cash Flows
      DFEnd   = 1 / power(1 + RateEnd/100, DaysEnd/365)
   where DF_Method = 'C' --Compounded Interest


   update #cfcf set
      DFStart = exp(-RateStart * DaysStart /365/100),
      DFEnd   = exp(-RateEnd * DaysEnd /365/100)
   where DF_Method = 'E' --Exponential


   update #cfcf set
      FwdRate = case when YF <> 0 then (DFStart/DFEnd - 1) / YF * 100 else 0 end


   --записываем результат в 'output'-табличку
   update Radius_Lib_FwdInterestRate
   set FwdRate = #cfcf.FwdRate
   from Radius_Lib_FwdInterestRate t, #cfcf
   where t.SPID = @@spid
   and #cfcf.Curves_Id = t.Curves_Id
   and #cfcf.Basis = t.Basis
   and #cfcf.Date = t.Date
   and #cfcf.ForwardStartDate = t.ForwardStartDate
   and #cfcf.ForwardEndDate = t.ForwardEndDate

   drop table #cfcf

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_ForwardRate_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_ForwardRate_Get
GO

create procedure Radius_Lib_ForwardRate_Get
/*------------------------------------------------------------------------------------------------------*/
/* Процедура начатывает параметры для расчета форвардного курса по паре                                 */
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/* . Author: Fonarev Oleg                                                                               */
/*------------------------------------------------------------------------------------------------------*/
as
begin

   -- расчет по Points

   

   create table #spot
   (
      Pairs_Id          int,
      Currencies_Id_1   int,
      Currencies_Id_2   int,
      SpotLag           int,
      Date              datetime
   )

   -- считаем спотовую дату пары
   insert into #spot (Pairs_Id,Currencies_Id_1,Currencies_Id_2,SpotLag,Date)
   select distinct fr.Pairs_Id, p.Currencies_Id_1, p.Currencies_Id_2, p.SpotLag, fr.Date
   from Radius_Lib_ForwardRate fr, kplus..Pairs p
   where fr.Pairs_Id = p.Pairs_Id
   and fr.SPID = @@spid
   and fr.SpotDate is null

   declare
      @cPairs_Id        int,
      @cCurrencies_Id_1 int,
      @cCurrencies_Id_2 int,
      @cSpotLag         int,
      @cDate            datetime,
      @cSpotDate        datetime

   
   declare spot cursor  for 
      select Pairs_Id, Currencies_Id_1, Currencies_Id_2, SpotLag, Date from #spot
   
   open spot

   fetch spot into @cPairs_Id, @cCurrencies_Id_1, @cCurrencies_Id_2, @cSpotLag, @cDate
   while (@@sqlstatus = 0)
   begin
      
      exec Radius_Lib_AddDays_Currencies @cCurrencies_Id_1, @cCurrencies_Id_2, @cDate, @cSpotLag, 'B', @cSpotDate Output

      update Radius_Lib_ForwardRate
      set SpotDate = @cSpotDate
      where SPID = @@spid
      and Pairs_Id = @cPairs_Id
      and Date = @cDate
   
      fetch spot into @cPairs_Id, @cCurrencies_Id_1, @cCurrencies_Id_2, @cSpotLag, @cDate
   end -- while (@@sqlstatus = 0)

   close spot
   deallocate cursor spot


   drop table #spot

   
   -- ищем Points  с количеством дней ближайшим 'снизу' к сроку
   update Radius_Lib_ForwardRate
   set Points_Id_L = (p.Points_Id),
       TermL = (m.NoDays)
   from Radius_Lib_ForwardRate fr,
        kplus.dbo.PointsDefT p,
        kplus.dbo.MaturityClasses m
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    p.Pairs_Id = fr.Pairs_Id
   and    p.MaturityClasses_Id = m.MaturityClasses_Id
   and    m.RefDate = 'S'
   and    m.NoDays = (select max(m2.NoDays)
                     from kplus.dbo.PointsDefT p2,
                          kplus.dbo.MaturityClasses m2
                     where  p2.Pairs_Id = fr.Pairs_Id
                     and    p2.MaturityClasses_Id = m2.MaturityClasses_Id
                     and    m2.RefDate = 'S'
                     and    m2.NoDays <= datediff(dd, fr.SpotDate, fr.ValueDate))

   

   -- ищем Points  с количеством дней ближайшим 'сверху' к сроку
   update Radius_Lib_ForwardRate
   set Points_Id_R = (p.Points_Id),
       TermR = (m.NoDays)
   from  Radius_Lib_ForwardRate fr,
         kplus.dbo.PointsDefT p,
         kplus.dbo.MaturityClasses m
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    p.Pairs_Id = fr.Pairs_Id
   and    p.MaturityClasses_Id = m.MaturityClasses_Id
   and    m.RefDate = 'S'
   and    m.NoDays = (select min(m2.NoDays)
                     from   kplus.dbo.Points p2, kplus.dbo.MaturityClasses m2
                     where  p2.Pairs_Id = fr.Pairs_Id
                     and    p2.MaturityClasses_Id = m2.MaturityClasses_Id
                     and    m2.RefDate = 'S'
                     and    m2.NoDays > datediff(dd, fr.SpotDate, fr.ValueDate))  -- кол-во дней от SpotDate до MaturityDate

   --------------------------------------------
   -- PointsL для 'левого' MaturityClasses - (т.е количество дней меньше чем в искомом)
   --------------------------------------------

   
   -- читаем значение пунктов из истории
   update Radius_Lib_ForwardRate
      set PointsL = (h.Bid + h.Ask) / 2
   from   Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1),
          kplus..PointsHist h
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    h.Points_Id = fr.Points_Id_L
   and    h.HistDate = fr.Date
   

   
   -- на Today читаем текущее значение поинтов
   update Radius_Lib_ForwardRate
      set PointsL = (p.Bid + p.Ask) / 2
   from   Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1),
          kplus..Points p
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    p.Points_Id = fr.Points_Id_L
   and    datediff(dd,getdate(),fr.Date) = 0 -- если ReportDate='сегодня' и в PointsHist еще нет данных, то берем из Points
   and    fr.PointsL is null

   -----------------------------------------------
   -- если PointsL не нашли - (т.е на нужную дату нет значений в истории)
   -- найдем из истории линейной интерполяцией

   
   -- найдем 'левую' дату для Points_Id_L (т.е дату < Date)
   update Radius_Lib_ForwardRate
      set PointsL_Date_L = (
                            select max(h.HistDate)
                            from kplus..PointsHist h
                            where h.Points_Id = fr.Points_Id_L
                            and   h.HistDate <= fr.Date
                            
                            )
   from   Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1)
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    fr.PointsL is null

   
   -- найдем 'праввую' дату для Points_Id_L (т.е дату < Date)
   update Radius_Lib_ForwardRate
      set PointsL_Date_R = isnull((
                                   select min(h.HistDate)
                                   from kplus..PointsHist h
                                   where h.Points_Id = fr.Points_Id_L
                                   and   h.HistDate >= fr.Date
                                   
                                  ), PointsL_Date_L) -- если в истории не нашли правую точку используем левую

   from   Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1)
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    fr.PointsL is null

   
   -- если даты совпали - ищем @PointsL в этой точке
   update Radius_Lib_ForwardRate
      set PointsL = (h.Bid + h.Ask) / 2
   from   Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1)
      inner join kplus..PointsHist h
      on  h.Points_Id = fr.Points_Id_L
      and h.HistDate = fr.PointsL_Date_R
      
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    fr.PointsL_Date_R = fr.PointsL_Date_L
   and    fr.PointsL is null

   
   --в противном случае используем линейная интерполяцию
   update Radius_Lib_ForwardRate
   set PointsL = (select (Bid + Ask) / 2 from kplus..PointsHist where Points_Id = fr.Points_Id_L and HistDate = fr.PointsL_Date_R) -
            ((select (Bid + Ask) / 2 from kplus..PointsHist where Points_Id = fr.Points_Id_L and HistDate = fr.PointsL_Date_R) -
             (select (Bid + Ask) / 2 from kplus..PointsHist where Points_Id = fr.Points_Id_L and HistDate = fr.PointsL_Date_L))*
             datediff(day,fr.PointsL_Date_R,fr.Date)/datediff(day,fr.PointsL_Date_R,fr.PointsL_Date_L)
   from Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1)
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    fr.PointsL is null

   -- если не нашли MaturityClasses, интерполируем с 0
   update Radius_Lib_ForwardRate
   set PointsL = 0,
       TermL = 0
   from Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1)
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    fr.PointsL is null
   and    fr.TermL is null

   
   --------------------------------------------
   -- PointsR для 'правого' MaturityClasses - (т.е количество дней больше чем в искомом)
   --------------------------------------------

   -- читаем значение пунктов из истории
   update Radius_Lib_ForwardRate
      set PointsR = (h.Bid + h.Ask) / 2
   from   Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1),
          kplus..PointsHist h
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    h.Points_Id = fr.Points_Id_R
   and    h.HistDate = fr.Date
   

   
   -- на Today читаем текущее значение поинтов
   update Radius_Lib_ForwardRate
      set PointsR = (p.Bid + p.Ask) / 2
   from   Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1),
          kplus..Points p
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    p.Points_Id = fr.Points_Id_R
   and    fr.PointsR is null
   and    datediff(dd,getdate(),fr.Date) = 0

   
   -----------------------------------------------
   -- если PointsR не нашли - (т.е на нужную дату нет значений в истории)
   -- найдем из истории линейной интерполяцией

   update Radius_Lib_ForwardRate
      set PointsR_Date_L = (
                            select max(h.HistDate)
                            from kplus..PointsHist h
                            where h.Points_Id = fr.Points_Id_R
                            and   h.HistDate <= fr.Date
                            
                            )
   from Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1)
   where fr.SPID = @@spid
   and   fr.ValueDate > fr.SpotDate
   and   fr.PointsR is null

   
   update Radius_Lib_ForwardRate
      set PointsR_Date_R = isnull((
                                   select min(h.HistDate)
                                   from kplus..PointsHist h
                                   where h.Points_Id = fr.Points_Id_R
                                   and   h.HistDate >= fr.Date
                                   
                                  ),PointsR_Date_L)
   from Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1)
   where fr.SPID = @@spid
   and   fr.ValueDate > fr.SpotDate

   and   fr.PointsR is null

   
   -- если даты совпали - ищем @PointsR в этой точке
   update Radius_Lib_ForwardRate
      set PointsR = (Bid + Ask) / 2
   from   Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1)
      inner join kplus..PointsHist h
      on  h.Points_Id = fr.Points_Id_R
      and h.HistDate = fr.PointsR_Date_R
      
   where  fr.SPID = @@spid
   and    fr.ValueDate > fr.SpotDate
   and    fr.PointsR_Date_R = fr.PointsR_Date_L
   and    fr.PointsR is null

   
   --в противном случае используем линейная интерполяцию
   update Radius_Lib_ForwardRate
      set PointsR =
   (select (Bid + Ask) / 2   from kplus..PointsHist where Points_Id = fr.Points_Id_R and HistDate = fr.PointsR_Date_R) -
   ((select (Bid + Ask) / 2   from kplus..PointsHist where Points_Id = fr.Points_Id_R and HistDate = fr.PointsR_Date_R) -
   (select (Bid + Ask) / 2   from kplus..PointsHist where Points_Id = fr.Points_Id_R and HistDate = fr.PointsR_Date_L))*
   datediff(day,fr.PointsR_Date_R,fr.Date)/datediff(day,fr.PointsR_Date_R,fr.PointsR_Date_L)
   from Radius_Lib_ForwardRate fr (index ix_Radius_Lib_ForwardRate_1)
   where fr.SPID = @@spid
   and fr.PointsR is null

   -- пункты на заданную дату считаем линейной интерполяцией
   update Radius_Lib_ForwardRate
      set Points = isnull(PointsL + (PointsR - PointsL) * (datediff(dd, Date, ValueDate) - TermL) / (TermR - TermL),0)
   where SPID = @@spid



   ----------------------------------------------
   -- начитываем кривые доходностей по валютам CCY1 CCY2
   update Radius_Lib_ForwardRate set
      YieldCurve_CCY1_Id = c.Curves_Id,
      ZCBasis_CCY1 = c.ZCBasis
   from kplus..InstrCurvesAssign ica, kplus..CurrencyCurvesAssign cca,
        kplus..Curves c, kplus..Pairs p, kplus..KdbTables t
   where Radius_Lib_ForwardRate.SPID = @@spid
   and Radius_Lib_ForwardRate.Pairs_Id = p.Pairs_Id
   and ica.TypeOfDealsOrigin = 'N'
   and cca.InstrCurvesAssign_Id = ica.InstrCurvesAssign_Id
   and cca.Currencies_Id = p.Currencies_Id_1
   and c.Curves_Id = cca.Curves_Id
   and ica.TypeOfDealsId = t.KdbTables_Id
   and t.KdbTables_Name = 'SpotDeals'
   and isnull(cca.CurvesSpread_Id,0) = 0
   and isnull(ica.TypeOfInstr_Id,0) = 0
   --and isnull(Radius_Lib_ForwardRate.Points,0) = 0

   update Radius_Lib_ForwardRate set
      YieldCurve_CCY2_Id = c.Curves_Id,
      ZCBasis_CCY2 = c.ZCBasis
   from kplus..InstrCurvesAssign ica, kplus..CurrencyCurvesAssign cca,
        kplus..Curves c, kplus..Pairs p, kplus..KdbTables t
   where Radius_Lib_ForwardRate.SPID = @@spid
   and Radius_Lib_ForwardRate.Pairs_Id = p.Pairs_Id
   and ica.TypeOfDealsOrigin = 'N'
   and cca.InstrCurvesAssign_Id = ica.InstrCurvesAssign_Id
   and cca.Currencies_Id = p.Currencies_Id_2
   and c.Curves_Id = cca.Curves_Id
   and ica.TypeOfDealsId = t.KdbTables_Id
   and t.KdbTables_Name = 'SpotDeals'
   and isnull(cca.CurvesSpread_Id,0) = 0
   and isnull(ica.TypeOfInstr_Id,0) = 0
   --and isnull(Radius_Lib_ForwardRate.Points,0) = 0


   -- расчет процентных ставок по кривым доходностей
   delete from Radius_Lib_CurvesRates where SPID = @@spid

   insert into Radius_Lib_CurvesRates(SPID, Curves_Id, StartDate, EndDate) -- CurveRate
   select @@spid, YieldCurve_CCY1_Id, Date, ValueDate
   from Radius_Lib_ForwardRate
   where SPID = @@spid
   union
   select @@spid, YieldCurve_CCY2_Id, Date, ValueDate
   from Radius_Lib_ForwardRate
   where SPID = @@spid

   exec Radius_Lib_CurvesRates_Get


   --select * from Radius_Lib_CurvesRates where SPID = @@spid
   -- расчет YearFraction
   delete from Radius_Lib_YearFraction where SPID = @@spid

   insert into Radius_Lib_YearFraction(SPID, StartDate, EndDate, Frequency, Basis ) --> YearFraction
   select @@spid, Date, ValueDate, 'A', ZCBasis_CCY1
   from Radius_Lib_ForwardRate
   where SPID = @@spid
   union
   select distinct @@spid, Date, ValueDate, 'A', ZCBasis_CCY2
   from Radius_Lib_ForwardRate
   where SPID = @@spid

   exec Radius_Lib_YearFraction_Get

   -- находим по экспоненциальной формуле Discount Factor
   update Radius_Lib_ForwardRate
   set DF_CCY1 = exp(-isnull(c.CurveRate,0)*isnull(y.YearFraction,0)/100.0)
   from Radius_Lib_CurvesRates c, Radius_Lib_YearFraction y, Radius_Lib_ForwardRate f
   where f.SPID = @@spid
   and f.YieldCurve_CCY1_Id = c.Curves_Id
   and c.SPID = @@spid
   and y.SPID = @@spid
   and y.StartDate = f.Date
   and y.EndDate = f.ValueDate
   and c.StartDate = f.Date
   and c.EndDate = f.ValueDate

   update Radius_Lib_ForwardRate
   set DF_CCY2 = exp(-isnull(c.CurveRate,0)*isnull(y.YearFraction,0)/100.0)
   from Radius_Lib_CurvesRates c, Radius_Lib_YearFraction y, Radius_Lib_ForwardRate f
   where f.SPID = @@spid
   and f.YieldCurve_CCY2_Id = c.Curves_Id
   and c.SPID = @@spid
   and y.SPID = @@spid
   and y.StartDate = f.Date
   and y.EndDate = f.ValueDate
   and c.StartDate = f.Date
   and c.EndDate = f.ValueDate

   delete from Radius_Lib_YearFraction where SPID = @@spid
   delete from Radius_Lib_CurvesRates where SPID = @@spid

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_FloatingRates_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_FloatingRates_Get
GO

create procedure Radius_Lib_FloatingRates_Get
(
   @CurRefIndex_ShortName  varchar(32)    = null,
   @Currencies_Id          int            = null,
   @DateStart              datetime       = null,
   @DateEnd                datetime       = null,
   @Rate                   float          = null output
)
as
begin
   if @CurRefIndex_ShortName is not NULL -- считаем по переданным переменным
   begin
      declare
         @FundingRate1           float,
         @Term1                  integer,
         @FundingRate2           float,
         @Term2                  integer,
         @FundingRate            float,
         @ValueDate              datetime,
         @MaturityDate           datetime,
         @DealTerm               integer,
         @CurRefIndex_Id         integer,
         @FloatingRates_Id_1     integer,
         @FloatingRates_Id_2     integer

      select @DealTerm = datediff(dd,@DateStart,@DateEnd)

      -- ищем набор плавающих ставок
      select @CurRefIndex_Id = min(CurRefIndex_Id)
      from   kplus..CurRefIndex cri, kplus.dbo.Currencies c
      where  c.Currencies_Id = @Currencies_Id
      and    cri.CurRefIndex_ShortName = @CurRefIndex_ShortName

      -- теперь ищем FloatingRate  с количеством дней ближайшим 'снизу' к сроку сделки
      select @FloatingRates_Id_1 = min(f.FloatingRates_Id), @Term1 = min(m.NoDays)
      from   kplus..FloatingRates f, kplus..MaturityClasses m
      where  f.CurRefIndex_Id = @CurRefIndex_Id
      and    f.MaturityClasses_Id = m.MaturityClasses_Id
      and    m.NoDays = (select max(m2.NoDays)
                        from   kplus..FloatingRates f2, kplus..MaturityClasses m2
                        where  f2.CurRefIndex_Id = @CurRefIndex_Id
                        and    f2.MaturityClasses_Id = m2.MaturityClasses_Id
                        and    m2.NoDays <= @DealTerm)

      -- теперь ищем FloatingRate  с количеством дней ближайшим 'сверху' к сроку сделки
      select @FloatingRates_Id_2 = min(f.FloatingRates_Id), @Term2 = min(m.NoDays)
      from   kplus..FloatingRates f, kplus..MaturityClasses m
      where  f.CurRefIndex_Id = @CurRefIndex_Id
      and    f.MaturityClasses_Id = m.MaturityClasses_Id
      and    m.NoDays = (select min(m2.NoDays)
                        from   kplus..FloatingRates f2, kplus..MaturityClasses m2
                        where  f2.CurRefIndex_Id = @CurRefIndex_Id
                        and    f2.MaturityClasses_Id = m2.MaturityClasses_Id
                        and    m2.NoDays > @DealTerm)

      if @FloatingRates_Id_1 is null
      begin
         select null as FundingRate, 'Не найдена плавающая ставка для данной валюты на данный срок (Floating Rate)' as ErrorMessage
         return
      end

      -- теперь собственно достаем значения ставок
      select @FundingRate1 = max(Rate)
      from   kplus..FloatingRatesValues
      where  FloatingRates_Id = @FloatingRates_Id_1
      and    FRDate = (select max(FRDate)
                     from   kplus..FloatingRatesValues
                     where  FloatingRates_Id = @FloatingRates_Id_1
                     and    FRDate <= @DateStart)

      if @FundingRate1 is null
      begin
         select null as FundingRate, 'Не установлено значение ставки фондирования для данной валюты на срок ' + convert(varchar, @Term1) + ' дней (Floating Rate Value)' as ErrorMessage
         return
      end

      if @FloatingRates_Id_2 is not null or @DealTerm = @Term1
      begin
         select @FundingRate2 = max(Rate)
         from   kplus..FloatingRatesValues
         where  FloatingRates_Id = @FloatingRates_Id_2
         and    FRDate = (select max(FRDate)
                        from   kplus..FloatingRatesValues
                        where  FloatingRates_Id = @FloatingRates_Id_2
                        and    FRDate <= @DateStart)

         if @FundingRate2 is null
         begin
            select null as FundingRate, 'Не установлено значение ставки фондирования для данной валюты на срок ' + convert(varchar, @Term2) + ' дней (Floating Rate Value)' as ErrorMessage
            return
         end

         -- между точками линейная интерполяци
         select @Rate = @FundingRate1 + (@FundingRate2 - @FundingRate1) * (@DealTerm - @Term1) / (@Term2 - @Term1)

      end
      else
         select @Rate = @FundingRate1
   end
   else -- считаем по переданному массиву данных
   begin
      if not exists(select 1 from Radius_Lib_FloatingRates where SPID = @@SPID)
      begin
         return
      end
      /*
         2 варианта работы:
            1. в рамках переданной ставки
            2. без ставки по всем имеющимся тенорам с интерполяцией
      */
      -- 1 вариант
      update Radius_Lib_FloatingRates set
         Rate = v.Rate
      from Radius_Lib_FloatingRates r
         inner join kplus.dbo.FloatingRatesValues v
            on v.FloatingRates_Id = r.FloatingRates_Id
            and v.FRDate = r.StartDate
      where r.SPID = @@SPID

      update Radius_Lib_FloatingRates set
         Rate = v.Rate
      from Radius_Lib_FloatingRates r
         inner join kplus.dbo.FloatingRatesValues v
            on v.FloatingRates_Id = r.FloatingRates_Id
            and v.FRDate =
               (
                  select max(vm.FRDate)
                  from kplus.dbo.FloatingRatesValues vm
                  where vm.FloatingRates_Id = v.FloatingRates_Id
                     and vm.FRDate < r.StartDate
               )
      where r.SPID = @@SPID
         and r.Rate is NULL -- предыдущий апдейт не нашел ставку за указанную дату

      -- 2 вариант надо бы реализовать :)

   end
end --end of proc

GO

IF OBJECT_ID ('dbo.Radius_Lib_FirstLastDay') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_FirstLastDay
GO

create procedure Radius_Lib_FirstLastDay
/*
   Возвращает первый/последний рабочий/календарный день месяца/квартала/года
*/
(
   @DateIn              datetime,
   @Currencies_Id_1     int = null,
   @Currencies_Id_2     int = null,
   @Pairs_Id            int = null,
   @DaysType            char(1),             -- 'B' - business day; 'C' calendar day
   @FirstLast           char(1),             -- 'F' - first or 'L' - last day of month/quarter/year
   @MQY                 char(1),             -- 'M' - month; 'Q' - quarter; 'Y' - year;
   @DateOut             datetime output
)
as
begin
   declare
      @TmpDate datetime,
      @IsHoliday int

   set @DateOut = null

   if isnull(@Pairs_Id, 0) > 0
      select @Currencies_Id_1 = Currencies_Id_1, @Currencies_Id_2 = Currencies_Id_2
      from kplus.dbo.Pairs where Pairs_Id = @Pairs_Id


   --первый день месяца
   if @MQY = 'M'
      select @TmpDate = convert(datetime, '01.' + substring(convert(varchar, @DateIn, 104), 4, 7), 104)

   --первый день квартала
   else if @MQY = 'Q'
      select @TmpDate = convert(datetime, case datepart(qq, @DateIn)
                                                when 1 then '01.01.'
                                                when 2 then '01.04.'
                                                when 3 then '01.07.'
                                                when 4 then '01.10.'
                                          end
                                          + substring(convert(varchar, @DateIn, 104), 7, 4), 104)
   --первый день года
   else if @MQY = 'Y'
      select @TmpDate = convert(datetime, '01.01.' + substring(convert(varchar, @DateIn, 104), 7, 4), 104)


   --последний день месяца/квартала/года
   if @FirstLast = 'L'
   begin
           if @MQY = 'M' set @TmpDate = dateadd(mm, +1, @TmpDate)
      else if @MQY = 'Q' set @TmpDate = dateadd(qq, +1, @TmpDate)
      else if @MQY = 'Y' set @TmpDate = dateadd(yy, +1, @TmpDate)

      set @TmpDate = dateadd(dd, -1, @TmpDate)
   end

   if @DaysType = 'C'
      set @DateOut = @TmpDate

   --если нужен первый/последний бизнес-день
   else if @DaysType = 'B'
   begin
         exec IsHoliday_Currency @Currencies_Id_1, @TmpDate, @IsHoliday output
         if @IsHoliday = 0
            exec IsHoliday_Currency @Currencies_Id_2, @TmpDate, @IsHoliday output

         if @IsHoliday = 0
            set @DateOut = @TmpDate
         else
         begin
            if @FirstLast = 'F'
               exec Radius_Lib_AddDays_Currencies @Currencies_Id_1, @Currencies_Id_2, @TmpDate,  1, 'B', @DateOut output
            else if @FirstLast = 'L'
               exec Radius_Lib_AddDays_Currencies @Currencies_Id_1, @Currencies_Id_2, @TmpDate, -1, 'B', @DateOut output
         end
   end
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_DateDiff_Currencies') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_DateDiff_Currencies
GO

create procedure Radius_Lib_DateDiff_Currencies
/*------------------------------------------------------------------------------------------------------*/
/* Процедура вычисляет количество бизнес-дней между двумя датами                                        */
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/* . Author: Evgeny Bugaev                                                                              */
/*------------------------------------------------------------------------------------------------------*/
(
   @DateBeg    datetime,
   @DateEnd    datetime,
   @Cur_Id_1   integer,
   @Cur_Id_2   integer,
   @Days       integer output
)
as
begin
   declare
      @City_1   integer,
      @City_2   integer,
      @IsWork   char(1)

   select @Days = 0

   select @City_1 = Cities_Id from kplus..Currencies where Currencies_Id = @Cur_Id_1
   select @City_2 = Cities_Id from kplus..Currencies where Currencies_Id = @Cur_Id_2

   -- смотрим, если попали на выходной в одной из валют идем по календарю
   while (@DateBeg < @DateEnd)
   begin
      select @IsWork = 'Y'

      select @DateBeg = dateadd(dd,1,@DateBeg)


      if exists (select * from kplus..VariableHolidays
                  where Cities_Id in (@City_1, @City_2) and HolidayDate = @DateBeg)
         select @IsWork = 'N'

      if exists (select * from kplus..FixedHolidays
                  where Cities_Id in (@City_1, @City_2)
                    and datepart(dd,HolidayDate) = datepart(dd,@DateBeg)
                    and datepart(mm,HolidayDate) = datepart(mm,@DateBeg))
         select @IsWork = 'N'

      if exists (select * from kplus..WeekHolidays
                  where Cities_Id in (@City_1, @City_2) and DayOfWeek = datepart(dw,@DateBeg)-1 )
         select @IsWork = 'N'

      if @IsWork = 'Y'
         select @Days = @Days + 1
   end
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_DateDiff_Basis_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_DateDiff_Basis_Get
GO

create procedure Radius_Lib_DateDiff_Basis_Get
/*
   Расчет доли года в периоде. Если параметры не переданы, то процедура работает по входной таблице
*/
(
   @StartDate     datetime = null,
   @EndDate       datetime = null,
   @Basis         char(1)  = null,
   @Frequency     char(1)  = 'A', -- значение по умолчанию как в таблице, чтобы не вставить Null
   @Period        char(1)  = 'F', -- значение по умолчанию как в таблице, чтобы не вставить Null
   @Currencies_Id int      = null,
   @Cities_Id     int      = null,
   @Days          int      = null output
)
as
begin

   -- если процедуру вызвали с параметрами, то считаем базис для переданных параметров, а на табличку не смотрим
   if @Basis is not null
   begin
      -- зачищаем входную таблицу
      delete from Radius_Lib_DateDiff_Basis where SPID = @@spid
      -- кладём в нее параметры процедуры
      insert into Radius_Lib_DateDiff_Basis
         (SPID, StartDate, EndDate, Frequency, Basis, Period, Currencies_Id, Cities_Id)
      values
         (@@spid, @StartDate, @EndDate, @Frequency, @Basis, @Period, @Currencies_Id, @Cities_Id)

      -- и вызываем процедуру еще раз - теперь уже без параметров
      exec Radius_Lib_DateDiff_Basis_Get

      -- читаем результат
      select @Days = Days from Radius_Lib_DateDiff_Basis where SPID = @@spid
      delete from Radius_Lib_DateDiff_Basis where SPID = @@spid

      return
   end

   -- считаем по входной таблице
   declare
      @StartDateC      datetime,
      @EndDateC        datetime,
      @StartYear       int,
      @EndYear         int,
      @BissexNbr       int,
      @Year            int,
      @BasisC          char(1),
      @FrequencyC      char(1)

   ------------------------------------------------
   -- Считаем для базисов M,5,D,F,B,N,C,I,A,R,E,Y,4,Z
   -- для базисов 6,J,2 считаем ниже
   update Radius_Lib_DateDiff_Basis set
      Days =
         case Basis
            when 'M' then  -- ACT/360
                        datediff(dd,StartDate,EndDate)
            when '5' then  -- ACT/365
                        datediff(dd,StartDate,EndDate)
            when '4' then  -- ACT/364
                           --For the year fraction calculation, Kondor+ uses this formula for the ACT/364 day count basis: n/364
                        datediff(dd,StartDate,EndDate)
            when 'D' then  -- ACT+1/360
                           -- KONDOR+ REFERENCE: Kondor+ applies the basis to the first cash flow in the schedule. Kondor+
                           --                    calculates the other cash flows by using the ACT/365 and ACT/360 bases
                        datediff(dd,StartDate,EndDate) + case Period when 'F' then 1 else 0 end
            when 'F' then  -- ACT+1/365
                        datediff(dd,StartDate,EndDate) + case Period when 'F' then 1 else 0 end
            when 'B' then  -- ACT/365.25
                        datediff(dd,StartDate,EndDate)
            when 'N' then  -- ACT/nACT
                        datediff(dd,StartDate,EndDate)
            when 'C' then  -- 30/360
                        (360 * (datepart(year, EndDate) - datepart(year, StartDate)) +
                         30  * (datepart(month, EndDate) - datepart(month, StartDate)) +
                               (datepart(day, EndDate) - datepart(day, StartDate))
                        )
                        + case when datepart(day, StartDate) = 31 then 1 else 0 end
                        + case when (datepart(day, EndDate) = 31 and datepart(day, StartDate) >= 30) then -1 else 0 end
            when 'E' then  -- 30E/360
                        (360 * (datepart(year, EndDate) - datepart(year, StartDate)) +
                          30 * (datepart(month, EndDate) - datepart(month, StartDate)) +
                               (datepart(day, EndDate) - datepart(day, StartDate))
                        )
                        + case when datepart(day, StartDate) = 31 then 1 else 0 end
                        + case when datepart(day, EndDate) = 31 then -1 else 0 end
            when 'I' then  -- 30E+1/360 (ITL)
                        (360 * (datepart(year, EndDate) - datepart(year, StartDate)) +
                          30 * (datepart(month, EndDate) - datepart(month, StartDate)) +
                               (datepart(day, EndDate) - datepart(day, StartDate))
                        )
                        + case when datepart(day, StartDate) = 31 then 1 else 0 end
                        + case when datepart(day, EndDate) = 31 then -1 else 0 end
                        + 1
            when 'A' then  -- ACT/ACT
                        datediff(dd,StartDate,EndDate)
            when 'R' then  -- ACT/ACT(RUS)
                        datediff(dd,StartDate,EndDate)
            when 'Y' then  -- 30E/360 (FEB)
                           -- Kondor+ modifies the values so that all months have 30 days, except for February that has 28 days.
                           -- This is equivalent to 30E/360 Basis for February - Day Count.
                        360 * (datepart(year, EndDate) - datepart(year, StartDate)) +
                        30 * (datepart(month, EndDate) - datepart(month, StartDate)) +
                        case when datepart(day, EndDate) > 30 then 30 else datepart(day, EndDate) end -
                        case when datepart(day, StartDate) > 30 then 30 else datepart(day, StartDate) end
            when 'Z' then  -- ACT+1/365(Thai)
                           -- The Thai basis for day count applies for:
                           -- - the first interest period is equivalent to ACT+1/365
                           -- - the last interest period is ACT-1/365
                           -- - other interest period ACT/365ACT
                        datediff(dd,StartDate,EndDate) +
                        case Period when 'F' then 1 when 'L' then -1 when 'M' then 0 else 0 end
         end
   where SPID        = @@SPID
      and Basis      not in ('6','J','2')
      and StartDate  is not null
      and EndDate    is not null
      and EndDate    > StartDate

   ------------------------------------------------
   -- для базисов 6 (ACT/365 (366)), J (ACT/365 (JPY))
   -- для базиса 2 считаем ниже
   
   declare Years cursor  for 
         select
            StartDate, EndDate, Basis, Frequency
         from Radius_Lib_DateDiff_Basis
         where SPID        = @@SPID
            and Basis      in ('6','J')
            and StartDate  is not NULL
            and EndDate    is not NULL
            and EndDate    > StartDate
         for update
      
   open Years

   fetch Years into @StartDateC, @EndDateC, @BasisC, @FrequencyC
   while (@@sqlstatus = 0)
   begin
      
         select
            @StartYear  = datepart(year, @StartDateC),
            @EndYear    = datepart(year, @EndDateC)

         select
            @Year       = @StartYear,
            @BissexNbr  = 0

         while (@Year <= @EndYear)
         begin
            if ((@Year % 4 = 0) and (@Year % 100 != 0)) or  (@Year % 400 = 0)
            begin
               if @StartDateC <= convert(varchar, @Year) + '0229' and @EndDateC >= convert(varchar, @Year) + '0229'
               begin
                  select  @BissexNbr = @BissexNbr + 1
               end
            end
            select @Year = @Year + 1
         end

         update Radius_Lib_DateDiff_Basis set
            Days =
               case
                  when Basis = 'J' then     datediff(day, @StartDateC, @EndDateC) - @BissexNbr
                  when @BissexNbr = 0 then  datediff(day, @StartDateC, @EndDateC)
                  when @BissexNbr != 0 then datediff(day, @StartDateC, @EndDateC)
               end
         where SPID        = @@SPID
            and StartDate  = @StartDateC
            and EndDate    = @EndDateC
            and Basis      = @BasisC
            and Frequency  = @FrequencyC
      
   
      fetch Years into @StartDateC, @EndDateC, @BasisC, @FrequencyC
   end -- while (@@sqlstatus = 0)

   close Years
   deallocate cursor Years


   ------------------------------------------------
   -- для базиса 2 (BUS/252)
   /*
      BUS/252 Kondor+ uses the BUS/252 day count basis to calculate the year fraction for certain South American
      markets, in particular the Brazilian bond market. This convention uses 252 business days per year as a
      base. Kondor+ calculates the year fraction as follows: YearFraction = Bus_D1_D2/252
      where Bus_D1_D2 is the number of business days between D1 and D2 determined from the holiday calendar

      Базис рассчитывается как YearFraction = Bus_D1_D2 / 252
         Bus_D1_D2 - это количество рабочих дней в периоде (@StartDate; @EndDate - 1) (проценты начисляются в конце рабочего дня)
   */
   -- найдем Cities_Id там, где этот параметр не указан
   update  Radius_Lib_DateDiff_Basis set
      Cities_Id =  c.Cities_Id
   from kplus..Currencies c
   where Radius_Lib_DateDiff_Basis.SPID     = @@SPID
      and Radius_Lib_DateDiff_Basis.Basis   = '2'
      and c.Currencies_Id                 = Radius_Lib_DateDiff_Basis.Currencies_Id
      and isnull(Radius_Lib_DateDiff_Basis.Cities_Id, 0) = 0

   update  Radius_Lib_DateDiff_Basis set
      Days =
         (
            select
               datediff(dd,y.StartDate, y.EndDate) - count(*)
            from Kustom..Radius_Lib_Calendar c
            where c.Date between y.StartDate and dateadd(dd, -1, y.EndDate)
            and
            (
               exists
                  (
                     select 1
                     from kplus..WeekHolidays w
                     where w.Cities_Id = y.Cities_Id
                        and DayOfWeek  = datepart(dw, c.Date) - 1
                  )
               or
               exists
                  (
                     select 1
                     from kplus..FixedHolidays f
                     where f.Cities_Id             = y.Cities_Id
                        and day(f.HolidayDate)     = day(c.Date)
                        and month(f.HolidayDate)   = month(c.Date)
                  )
               or
               exists
                  (
                     select 1
                     from kplus..VariableHolidays v
                     where v.Cities_Id                            = y.Cities_Id
                        and datediff(dy, v.HolidayDate, c.Date)   = 0
                  )
            )
         )
   from Radius_Lib_DateDiff_Basis y
   where SPID        = @@SPID
      and Basis      in ('2')
      and StartDate  is not null
      and EndDate    is not null
      and EndDate    > StartDate

   -- для базиса BUS/252, если переданного города не существует, то Days возвращаем 0
   update  Radius_Lib_DateDiff_Basis set
      Days = 0
   from Radius_Lib_DateDiff_Basis y
   where SPID        = @@SPID
      and Basis      in ('2')
      and not exists
         (
            select c.Cities_Id from kplus..Cities c where c.Cities_Id = y.Cities_Id
         )

   update Radius_Lib_DateDiff_Basis set
      Days = 0
   where SPID     = @@SPID
      and EndDate <= StartDate
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_CurvesRates_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_CurvesRates_Get
GO

create procedure Radius_Lib_CurvesRates_Get
/*
   Первый проход для поиска точек является конечным, если искомое состояние попадет в имеющийся интервал.
   В противном случае необходимо делать экстраполяцию и необходимо найти еще одну точку левее или правее.
*/
(
   @QuoteType  char(1) = 'R'
)
as
begin
   declare
      @CurDate            datetime

   select @CurDate = convert(datetime,convert(varchar,getdate(),103),103)




   /************************************************************************************************
      Достаем данные из [CurvesRates].
      В таблицу существует точка на искомый срок
   ************************************************************************************************/
   update Radius_Lib_CurvesRates set
      CurveRate      = cr.ParRate,
      ZeroRate       = cr.ZeroRate,
      DiscountFactor = cr.DiscountFactor
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id    = b.Curves_Id
         and c.CurvesMethod  <> 'N' -- Whether Methodology is Newton Raphson or not
      inner join kplus..CurvesRates cr
         on cr.Curves_Id  = b.Curves_Id
      
         and cr.MaturityDate = b.EndDate
   where b.SPID = @@SPID
      and b.StartDate = @CurDate -- Whether History or Current

   -- ищем граничные точки для линейной интерполяции
   update Radius_Lib_CurvesRates set
      LeftPoint   =
         (
            select max(cr.MaturityDate)
            from kplus..CurvesRates cr
            where cr.Curves_Id = b.Curves_Id
            
               and cr.MaturityDate < b.EndDate
         ),
      RightPoint  =
         (
            select min(cr.MaturityDate)
            from kplus..CurvesRates cr
            where cr.Curves_Id = b.Curves_Id
            
               and cr.MaturityDate > b.EndDate
         )
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  <> 'N' -- Whether Methodology is Newton Raphson or not
   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate = @CurDate -- Whether History or Current

   -- одна из точек не найдена. Для экстраполяции ищем вторую точку.
   update Radius_Lib_CurvesRates set
      LeftPoint =
         case
            when b.LeftPoint is null then b.RightPoint -- вышли за ЛЕВУЮ границу интервала кривой
            when b.RightPoint is NULL then -- вышли за ПРАВУЮ границу интервала кривой
               (
                  select max(cr.MaturityDate)
                  from kplus..CurvesRates cr
                  where cr.Curves_Id = b.Curves_Id
                  
                     and cr.MaturityDate < b.LeftPoint
               )
               else b.LeftPoint
         end,
      RightPoint =
         case
            when b.RightPoint is null then b.LeftPoint -- вышли за ПРАВУЮ границу интервала кривой
            when b.LeftPoint is NULL then -- вышли за ЛЕВУЮ границу интервала кривой
               (
                  select min(cr.MaturityDate)
                  from kplus..CurvesRates cr
                  where cr.Curves_Id = b.Curves_Id
                  
                     and cr.MaturityDate > b.RightPoint
               )
               else b.RightPoint
         end
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  <> 'N' -- Whether Methodology is Newton Raphson or not
   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate = @CurDate -- Whether History or Current
      and (b.LeftPoint is NULL or b.RightPoint is NULL)

   -- на основе найденных точек достаем необходимые данные
   update Radius_Lib_CurvesRates set
      CurveRate =
         lp.ParRate
         +
         (
            (rp.ParRate - lp.ParRate)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         ),
      ZeroRate =
         lp.ZeroRate
         +
         (
            (rp.ZeroRate - lp.ZeroRate)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         ),
      DiscountFactor =
         lp.DiscountFactor
         +
         (
            (rp.DiscountFactor - lp.DiscountFactor)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         )
   from Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  <> 'N' -- Whether Methodology is Newton Raphson or not
      inner join kplus..CurvesRates lp
         on lp.Curves_Id = b.Curves_Id
            

               and lp.MaturityDate = b.LeftPoint

      inner join kplus..CurvesRates rp
         on rp.Curves_Id = b.Curves_Id
         

               and rp.MaturityDate = b.RightPoint

   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate = @CurDate -- Whether History or Current


   /************************************************************************************************
      Достаем данные из [CurvesRatesHist].
      В таблицу существует точка на искомый срок
   ************************************************************************************************/
   update Radius_Lib_CurvesRates set
      CurveRate      = cr.ParRate,
      ZeroRate       = cr.ZeroRate,
      DiscountFactor = cr.DiscountFactor
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id    = b.Curves_Id
         and c.CurvesMethod  <> 'N' -- Whether Methodology is Newton Raphson or not
      inner join kplus..CurvesRatesHist cr
         on cr.Curves_Id  = b.Curves_Id
      
         and cr.HistDate  = b.StartDate
         and cr.QuoteType = @QuoteType
      
         and MaturityDate = b.EndDate
   where b.SPID = @@SPID
      and b.StartDate < @CurDate -- Whether History or Current

   -- ищем граничные точки для линейной интерполяции
   update Radius_Lib_CurvesRates set
      LeftPoint   =
         (
            select max(MaturityDate)
            from kplus..CurvesRatesHist cr
            where cr.Curves_Id = b.Curves_Id
            
               and cr.HistDate = b.StartDate
               and cr.QuoteType = @QuoteType
            
               and MaturityDate < b.EndDate
         ),
      RightPoint  =
         (
            select min(MaturityDate)
            from kplus..CurvesRatesHist cr
            where cr.Curves_Id = b.Curves_Id
            
               and cr.HistDate    = b.StartDate
               and cr.QuoteType   = @QuoteType
            
               and MaturityDate > b.EndDate
         )
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  <> 'N' -- Whether Methodology is Newton Raphson or not
   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate < @CurDate -- Whether History or Current

   -- одна из точек не найдена. Для экстраполяции ищем вторую точку.
   update Radius_Lib_CurvesRates set
      LeftPoint =
         case
            when b.LeftPoint is null then b.RightPoint -- вышли за ЛЕВУЮ границу интервала кривой
            when b.RightPoint is NULL then -- вышли за ПРАВУЮ границу интервала кривой
               (
                  select max(MaturityDate)
                  from kplus..CurvesRatesHist cr
                  where cr.Curves_Id = b.Curves_Id
                  
                     and cr.HistDate = b.StartDate
                     and cr.QuoteType = @QuoteType
                  
                     and MaturityDate < b.LeftPoint
               )
               else b.LeftPoint
         end,
      RightPoint =
         case
            when b.RightPoint is null then b.LeftPoint -- вышли за ПРАВУЮ границу интервала кривой
            when b.LeftPoint is NULL then -- вышли за ЛЕВУЮ границу интервала кривой
               (
                  select min(MaturityDate)
                  from kplus..CurvesRatesHist cr
                  where cr.Curves_Id = b.Curves_Id
                  
                     and cr.HistDate = b.StartDate
                     and cr.QuoteType = @QuoteType
                  
                     and MaturityDate > b.RightPoint
               )
               else b.RightPoint
         end
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  <> 'N' -- Whether Methodology is Newton Raphson or not
   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate < @CurDate -- Whether History or Current
      and (b.LeftPoint is NULL or b.RightPoint is NULL)

   -- на основе найденных точек достаем необходимые данные
   update Radius_Lib_CurvesRates set
      CurveRate =
         lp.ParRate
         +
         (
            (rp.ParRate - lp.ParRate)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         ),
      ZeroRate =
         lp.ZeroRate
         +
         (
            (rp.ZeroRate - lp.ZeroRate)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         ),
      DiscountFactor =
         lp.DiscountFactor
         +
         (
            (rp.DiscountFactor - lp.DiscountFactor)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         )
   from Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  <> 'N' -- Whether Methodology is Newton Raphson or not
      inner join kplus..CurvesRatesHist lp
         on lp.Curves_Id = b.Curves_Id
            
               and lp.HistDate    = b.StartDate
               and lp.QuoteType   = @QuoteType
            

               and lp.MaturityDate = b.LeftPoint

      inner join kplus..CurvesRatesHist rp
         on rp.Curves_Id = b.Curves_Id
         
               and rp.HistDate    = b.StartDate
               and rp.QuoteType   = @QuoteType
            

               and rp.MaturityDate = b.RightPoint

   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate < @CurDate -- Whether History or Current


   /************************************************************************************************
      Достаем данные из [CurvesRatesNR].
      В таблицу существует точка на искомый срок
   ************************************************************************************************/
   update Radius_Lib_CurvesRates set
      CurveRate      = cr.MarketValue,
      ZeroRate       = cr.ZeroRate,
      DiscountFactor = cr.DiscountFactor
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id    = b.Curves_Id
         and c.CurvesMethod  = 'N' -- Whether Methodology is Newton Raphson or not
      inner join kplus..CurvesRatesNR cr
         on cr.Curves_Id  = b.Curves_Id
      
         and cr.MaturityDate = b.EndDate
   where b.SPID = @@SPID
      and b.StartDate = @CurDate -- Whether History or Current

   -- ищем граничные точки для линейной интерполяции
   update Radius_Lib_CurvesRates set
      LeftPoint   =
         (
            select max(cr.MaturityDate)
            from kplus..CurvesRatesNR cr
            where cr.Curves_Id = b.Curves_Id
            
               and cr.MaturityDate < b.EndDate
         ),
      RightPoint  =
         (
            select min(cr.MaturityDate)
            from kplus..CurvesRatesNR cr
            where cr.Curves_Id = b.Curves_Id
            
               and cr.MaturityDate > b.EndDate
         )
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  = 'N' -- Whether Methodology is Newton Raphson or not
   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate = @CurDate -- Whether History or Current

   -- одна из точек не найдена. Для экстраполяции ищем вторую точку.
   update Radius_Lib_CurvesRates set
      LeftPoint =
         case
            when b.LeftPoint is null then b.RightPoint -- вышли за ЛЕВУЮ границу интервала кривой
            when b.RightPoint is NULL then -- вышли за ПРАВУЮ границу интервала кривой
               (
                  select max(cr.MaturityDate)
                  from kplus..CurvesRatesNR cr
                  where cr.Curves_Id = b.Curves_Id
                  
                     and cr.MaturityDate < b.LeftPoint
               )
               else b.LeftPoint
         end,
      RightPoint =
         case
            when b.RightPoint is null then b.LeftPoint -- вышли за ПРАВУЮ границу интервала кривой
            when b.LeftPoint is NULL then -- вышли за ЛЕВУЮ границу интервала кривой
               (
                  select min(cr.MaturityDate)
                  from kplus..CurvesRatesNR cr
                  where cr.Curves_Id = b.Curves_Id
                  
                     and cr.MaturityDate > b.RightPoint
               )
               else b.RightPoint
         end
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  = 'N' -- Whether Methodology is Newton Raphson or not
   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate = @CurDate -- Whether History or Current
      and (b.LeftPoint is NULL or b.RightPoint is NULL)

   -- на основе найденных точек достаем необходимые данные
   update Radius_Lib_CurvesRates set
      CurveRate =
         lp.MarketValue
         +
         (
            (rp.MarketValue - lp.MarketValue)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         ),
      ZeroRate =
         lp.ZeroRate
         +
         (
            (rp.ZeroRate - lp.ZeroRate)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         ),
      DiscountFactor =
         lp.DiscountFactor
         +
         (
            (rp.DiscountFactor - lp.DiscountFactor)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         )
   from Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  = 'N' -- Whether Methodology is Newton Raphson or not
      inner join kplus..CurvesRatesNR lp
         on lp.Curves_Id = b.Curves_Id
            

               and lp.MaturityDate = b.LeftPoint

      inner join kplus..CurvesRatesNR rp
         on rp.Curves_Id = b.Curves_Id
         

               and rp.MaturityDate = b.RightPoint

   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate = @CurDate -- Whether History or Current


   /************************************************************************************************
      Достаем данные из [CurvesRatesNRHist].
      В таблицу существует точка на искомый срок
   ************************************************************************************************/
   update Radius_Lib_CurvesRates set
      CurveRate      = cr.MarketValue,
      ZeroRate       = cr.ZeroRate,
      DiscountFactor = cr.DiscountFactor
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id    = b.Curves_Id
         and c.CurvesMethod  = 'N' -- Whether Methodology is Newton Raphson or not
      inner join kplus..CurvesRatesNRHist cr
         on cr.Curves_Id  = b.Curves_Id
      
         and cr.HistDate  = b.StartDate
         and cr.QuoteType = @QuoteType
      
         and cr.MaturityDate = b.EndDate
   where b.SPID = @@SPID
      and b.StartDate < @CurDate -- Whether History or Current

   -- ищем граничные точки для линейной интерполяции
   update Radius_Lib_CurvesRates set
      LeftPoint   =
         (
            select max(cr.MaturityDate)
            from kplus..CurvesRatesNRHist cr
            where cr.Curves_Id = b.Curves_Id
            
               and cr.HistDate = b.StartDate
               and cr.QuoteType = @QuoteType
            
               and cr.MaturityDate < b.EndDate
         ),
      RightPoint  =
         (
            select min(cr.MaturityDate)
            from kplus..CurvesRatesNRHist cr
            where cr.Curves_Id = b.Curves_Id
            
               and cr.HistDate    = b.StartDate
               and cr.QuoteType   = @QuoteType
            
               and cr.MaturityDate > b.EndDate
         )
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  = 'N' -- Whether Methodology is Newton Raphson or not
   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate < @CurDate -- Whether History or Current

   -- одна из точек не найдена. Для экстраполяции ищем вторую точку.
   update Radius_Lib_CurvesRates set
      LeftPoint =
         case
            when b.LeftPoint is null then b.RightPoint -- вышли за ЛЕВУЮ границу интервала кривой
            when b.RightPoint is NULL then -- вышли за ПРАВУЮ границу интервала кривой
               (
                  select max(cr.MaturityDate)
                  from kplus..CurvesRatesNRHist cr
                  where cr.Curves_Id = b.Curves_Id
                  
                     and cr.HistDate = b.StartDate
                     and cr.QuoteType = @QuoteType
                  
                     and cr.MaturityDate < b.LeftPoint
               )
               else b.LeftPoint
         end,
      RightPoint =
         case
            when b.RightPoint is null then b.LeftPoint -- вышли за ПРАВУЮ границу интервала кривой
            when b.LeftPoint is NULL then -- вышли за ЛЕВУЮ границу интервала кривой
               (
                  select min(cr.MaturityDate)
                  from kplus..CurvesRatesNRHist cr
                  where cr.Curves_Id = b.Curves_Id
                  
                     and cr.HistDate = b.StartDate
                     and cr.QuoteType = @QuoteType
                  
                     and cr.MaturityDate > b.RightPoint
               )
               else b.RightPoint
         end
   from Kustom..Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  = 'N' -- Whether Methodology is Newton Raphson or not
   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate < @CurDate -- Whether History or Current
      and (b.LeftPoint is NULL or b.RightPoint is NULL)

   -- на основе найденных точек достаем необходимые данные
   update Radius_Lib_CurvesRates set
      CurveRate =
         lp.MarketValue
         +
         (
            (rp.MarketValue - lp.MarketValue)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         ),
      ZeroRate =
         lp.ZeroRate
         +
         (
            (rp.ZeroRate - lp.ZeroRate)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         ),
      DiscountFactor =
         lp.DiscountFactor
         +
         (
            (rp.DiscountFactor - lp.DiscountFactor)
            /
            datediff(dd,b.LeftPoint,b.RightPoint)
         )
         *
         (
            datediff(dd,b.StartDate, b.EndDate)
            -
            datediff(dd,b.StartDate,b.LeftPoint)
         )
   from Radius_Lib_CurvesRates b
      inner join kplus..Curves c
         on c.Curves_Id      = b.Curves_Id
         and c.CurvesMethod  = 'N' -- Whether Methodology is Newton Raphson or not
      inner join kplus..CurvesRatesNRHist lp
         on lp.Curves_Id = b.Curves_Id
            
               and lp.HistDate    = b.StartDate
               and lp.QuoteType   = @QuoteType
            

               and lp.MaturityDate = b.LeftPoint

      inner join kplus..CurvesRatesNRHist rp
         on rp.Curves_Id = b.Curves_Id
         
               and rp.HistDate    = b.StartDate
               and rp.QuoteType   = @QuoteType
            

               and rp.MaturityDate = b.RightPoint

   where b.SPID = @@SPID
      and b.CurveRate is NULL
      and b.StartDate < @CurDate -- Whether History or Current


end -- end of proc

GO

IF OBJECT_ID ('dbo.Radius_Lib_CurvesRate_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_CurvesRate_Get
GO

create procedure Radius_Lib_CurvesRate_Get
/*
   Процедура для поиска значения кривой на дату
*/
(
   @Curves_Id integer,          --id кривой
   @RateDate datetime,          --дата (!БЕЗ ВРЕМЕНИ!), на которую берем кривую (т.е. набор ставок различных срочностей), если NULL - то на сегодня
   @MaturityDate datetime,      --на эту дату определяем ставку из кривой
   @NDays integer = null,       --кол-во дней, определяющий срок ставки (это альтернативный способ задания @MaturityDate: @MaturityDate=@RateDate+@NDays)
   @QuoteType char(1) = 'R',    --тип ставок: R-revaluation
   @ParRate float output        --искомая ставка
)
as
begin
   declare
           @Date_Min datetime,
           @Date_Max datetime,
           @Rate_Min float,
           @Rate_Max float,
           @NoDays_Min integer,
           @NoDays_Max integer

   

   select @ParRate = null
   if @RateDate is null
      select @RateDate = convert(datetime,convert(varchar,getdate(),103),103)

   if @MaturityDate is null
      select @MaturityDate = dateadd(day, @NDays, @RateDate)
   else
      select @NDays = datediff(day, @RateDate, @MaturityDate)

   if exists
      (  -- Methodology <> Newton Raphson
         select 1
         from kplus.dbo.Curves
         where Curves_Id = @Curves_Id
            and CurvesMethod <> 'N'
      )
   begin
      if @RateDate = convert(datetime,convert(varchar,getdate(),103),103)
      begin

         SELECT @ParRate = cr.ParRate
         FROM kplus.dbo.CurvesRates cr
         WHERE  cr.Curves_Id = @Curves_Id
         and cr.MaturityDate = @MaturityDate

         if @@rowcount = 1 -- есть запись на заданную дату
            return
         else
         begin
            -- предыдущаяя дата
            select @Date_Min = max(cr.MaturityDate)
            FROM kplus.dbo.CurvesRates cr
            WHERE  cr.Curves_Id = @Curves_Id
               and cr.MaturityDate < @MaturityDate

            -- следущая дата
            select @Date_Max = min(cr.MaturityDate)
            FROM kplus.dbo.CurvesRates cr
            WHERE  cr.Curves_Id = @Curves_Id
               and cr.MaturityDate > @MaturityDate

            -- выход за границы интервала кривой
            if @Date_Min is null
            begin
               select @Date_Min = @Date_Max

               select @Date_Max = min(cr.MaturityDate)
               FROM kplus.dbo.CurvesRates cr
               WHERE  cr.Curves_Id = @Curves_Id
                  and cr.MaturityDate > @Date_Min
            end

            if @Date_Max is null
            begin
               select @Date_Max = @Date_Min

               select @Date_Min = max(cr.MaturityDate)
               FROM kplus.dbo.CurvesRates cr
               WHERE  cr.Curves_Id = @Curves_Id
                  and cr.MaturityDate < @Date_Max
            end

            -- значение ставки [предыдущая дата]
            SELECT @Rate_Min = cr.ParRate
            FROM kplus.dbo.CurvesRates cr
            WHERE  cr.Curves_Id = @Curves_Id
            and cr.MaturityDate = @Date_Min

            --значение ставки [следущая дата]
            SELECT @Rate_Max = cr.ParRate
            FROM kplus.dbo.CurvesRates cr
            WHERE  cr.Curves_Id = @Curves_Id
            and cr.MaturityDate = @Date_Max

            -- линейная интерполяция
            select @ParRate = @Rate_Min + (@Rate_Max - @Rate_Min)/datediff(dd, @Date_Min, @Date_Max)*datediff(dd, @Date_Min, @MaturityDate)

         end
      end
      -- если дата расчета ставки не на сегодня, то берем занчения из исторической таблицы
      else
      begin
         --ищем ставку строго на заданное кол-во дней @NDays
         SELECT @ParRate = cr.ParRate
         FROM kplus.dbo.CurvesRatesHistT cr (index CurvesRatesHistTIdx1)
         WHERE  cr.Curves_Id = @Curves_Id
            and cr.HistDate = @RateDate
            and datediff(dd,cr.HistDate,cr.MaturityDate) = @NDays
            and cr.QuoteType = @QuoteType


         if @ParRate is null
         begin
            -- предыдущаяя дата
            select @NoDays_Min = max(datediff(dd,cr.HistDate,cr.MaturityDate))
            FROM kplus.dbo.CurvesRatesHistT cr (index CurvesRatesHistTIdx1)
            WHERE  cr.Curves_Id = @Curves_Id
               and datediff(dd,cr.HistDate,cr.MaturityDate) < @NDays
               and cr.HistDate = @RateDate
               and cr.QuoteType = @QuoteType

            -- следущая дата
            select @NoDays_Max = min(datediff(dd,cr.HistDate,cr.MaturityDate))
            FROM kplus.dbo.CurvesRatesHistT cr (index CurvesRatesHistTIdx1)
            WHERE  cr.Curves_Id = @Curves_Id
               and datediff(dd,cr.HistDate,cr.MaturityDate) > @NDays
               and cr.HistDate = @RateDate
               and cr.QuoteType = @QuoteType

            if @NoDays_Min is null
            begin
               select @NoDays_Min = @NoDays_Max

               select @NoDays_Max = min(datediff(dd,cr.HistDate,cr.MaturityDate))
               FROM kplus.dbo.CurvesRatesHistT cr (index CurvesRatesHistTIdx1)
               WHERE  cr.Curves_Id = @Curves_Id
                  and datediff(dd,cr.HistDate,cr.MaturityDate) > @NoDays_Min
                  and cr.HistDate = @RateDate
                  and cr.QuoteType = @QuoteType
            end

            if @NoDays_Max is null
            begin
               select @NoDays_Max = @NoDays_Min

               select @NoDays_Min = max(datediff(dd,cr.HistDate,cr.MaturityDate))
               FROM kplus.dbo.CurvesRatesHistT cr (index CurvesRatesHistTIdx1)
               WHERE  cr.Curves_Id = @Curves_Id
                  and datediff(dd,cr.HistDate,cr.MaturityDate) < @NoDays_Max
                  and cr.HistDate = @RateDate
                  and cr.QuoteType = @QuoteType
            end

            -- значение ставки [предыдущая дата]
            SELECT @Rate_Min = cr.ParRate
            FROM kplus.dbo.CurvesRatesHistT cr (index CurvesRatesHistTIdx1)
            WHERE  cr.Curves_Id = @Curves_Id
               and datediff(dd,cr.HistDate,cr.MaturityDate) = @NoDays_Min
               and cr.HistDate = @RateDate
               and cr.QuoteType = @QuoteType

            -- значение ставки [следущая дата]
            SELECT @Rate_Max = cr.ParRate
            FROM kplus.dbo.CurvesRatesHistT cr (index CurvesRatesHistTIdx1)
            WHERE  cr.Curves_Id = @Curves_Id
               and datediff(dd,cr.HistDate,cr.MaturityDate) = @NoDays_Max
               and cr.HistDate = @RateDate
               and cr.QuoteType = @QuoteType


           -- линейная интерполяция
            select @ParRate =
               @Rate_Min
               +
               (
                  (@Rate_Max - @Rate_Min)
                  /
                  (@NoDays_Max-@NoDays_Min)
               )
               *
               (@NDays-@NoDays_Min)
         end
      end
   end
   --Methodology = Newton Raphson
   else
   begin
      --за сегодня
      if @RateDate = convert(datetime,convert(varchar,getdate(),103),103)
      begin

         SELECT @ParRate = cr.MarketValue
         FROM kplus.dbo.CurvesRatesNR cr
         WHERE  cr.Curves_Id = @Curves_Id
         and cr.MaturityDate = @MaturityDate

         if @@rowcount = 1 -- есть запись на заданную дату
            return
         else
         begin
            -- следущая дата
            select @Date_Max = min(cr.MaturityDate)
            FROM kplus.dbo.CurvesRatesNR cr
            WHERE  cr.Curves_Id = @Curves_Id
            and cr.MaturityDate > @MaturityDate

            -- предыдущаяя дата
            select @Date_Min = max(cr.MaturityDate)
            FROM kplus.dbo.CurvesRatesNR cr
            WHERE  cr.Curves_Id = @Curves_Id
            and cr.MaturityDate < @MaturityDate

            -- выход за границы интервала кривой
            if @Date_Min is null
            begin
               select @Date_Min = @Date_Max

               select @Date_Max = min(cr.MaturityDate)
               FROM kplus.dbo.CurvesRatesNR cr
               WHERE  cr.Curves_Id = @Curves_Id
                  and cr.MaturityDate > @Date_Min
            end

            if @Date_Max is null
            begin
               select @Date_Max = @Date_Min

               select @Date_Min = max(cr.MaturityDate)
               FROM kplus.dbo.CurvesRatesNR cr
               WHERE  cr.Curves_Id = @Curves_Id
                  and cr.MaturityDate < @Date_Max
            end

            -- значение ставки [предыдущая дата]
            SELECT @Rate_Min = cr.MarketValue
            FROM kplus.dbo.CurvesRatesNR cr
            WHERE  cr.Curves_Id = @Curves_Id
            and cr.MaturityDate = @Date_Min

            --значение ставки [следущая дата]
            SELECT @Rate_Max = cr.MarketValue
            FROM kplus.dbo.CurvesRatesNR cr
            WHERE  cr.Curves_Id = @Curves_Id
            and cr.MaturityDate = @Date_Max

            -- линейная интерполяция
            select @ParRate = @Rate_Min + (@Rate_Max - @Rate_Min)/datediff(dd, @Date_Min, @Date_Max)*datediff(dd, @Date_Min, @MaturityDate)

         end
      end
      --если дата расчета ставки не на сегодня, то берем занчения из исторической таблицы
      else
      begin

         select @RateDate = max(HistDate)
         from kplus.dbo.CurvesRatesNRHist cr
         where Curves_Id = @Curves_Id
            and HistDate <= @RateDate
            and QuoteType = @QuoteType


         --ищем ставку строго на заданную дату @MaturityDate
         select @ParRate = cr.MarketValue
         from kplus.dbo.CurvesRatesNRHist cr
         where  cr.Curves_Id = @Curves_Id
            and cr.HistDate = @RateDate
            and cr.MaturityDate = @MaturityDate
            and cr.QuoteType = @QuoteType


         if @ParRate is null
         begin
            -- следущая дата
            select @Date_Max = min(cr.MaturityDate)
            FROM kplus.dbo.CurvesRatesNRHist cr
            WHERE  cr.Curves_Id = @Curves_Id
               and cr.HistDate = @RateDate
               and cr.QuoteType = @QuoteType
               and cr.MaturityDate > @MaturityDate

            -- предыдущаяя дата
            select @Date_Min = max(cr.MaturityDate)
            FROM kplus.dbo.CurvesRatesNRHist cr
            WHERE  cr.Curves_Id = @Curves_Id
               and cr.HistDate = @RateDate
               and cr.QuoteType = @QuoteType
               and cr.MaturityDate < @MaturityDate

            if @Date_Min is null
            begin
               select @Date_Min = @Date_Max

               select @Date_Max = min(cr.MaturityDate)
               FROM kplus.dbo.CurvesRatesNRHist cr
               WHERE  cr.Curves_Id = @Curves_Id
                  and cr.MaturityDate > @Date_Min
                  and cr.HistDate = @RateDate
                  and cr.QuoteType = @QuoteType
            end

            if @Date_Max is null
            begin
               select @Date_Max = @Date_Min

               select @Date_Min = max(cr.MaturityDate)
               FROM kplus.dbo.CurvesRatesNRHist cr
               WHERE  cr.Curves_Id = @Curves_Id
                  and cr.MaturityDate < @Date_Max
                  and cr.HistDate = @RateDate
                  and cr.QuoteType = @QuoteType
            end

           -- значение ставки [предыдущая дата]
            SELECT @Rate_Min = cr.MarketValue
            FROM kplus.dbo.CurvesRatesNRHist cr
            WHERE  cr.Curves_Id = @Curves_Id
               and cr.HistDate = @RateDate
               and cr.QuoteType = @QuoteType
               and cr.MaturityDate = @Date_Min

           -- значение ставки [следущая дата]
            SELECT @Rate_Max = cr.MarketValue
            FROM kplus.dbo.CurvesRatesNRHist cr
            WHERE  cr.Curves_Id = @Curves_Id
               and cr.HistDate = @RateDate
               and cr.QuoteType = @QuoteType
               and cr.MaturityDate = @Date_Max


           -- линейная интерполяция
            select @ParRate = @Rate_Min + (@Rate_Max - @Rate_Min)/datediff(dd, @Date_Min, @Date_Max)*datediff(dd, @Date_Min, @MaturityDate)
         end
      end
   end

   select @ParRate = isnull(@ParRate, 0)
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_CurrenciesRates_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_CurrenciesRates_Get
GO

create procedure Radius_Lib_CurrenciesRates_Get
/***************************************************************************************************

. Copyright SYSTEMATICA

. Author: Denis Ivanov

   Входные данные: таблица Radius_Lib_CurrenciesRates
      SPID
      Currencies_Id_1
      Currencies_Id_2
      Date            -- дата требуемой котировки
      QuoteType       -- тип котировок (R - Revaluation; H - Historical)
      BidAskMiddle
      GoodOrder       -- заменятьили нет курс текущей пары от GoodOrder'ной пары
      ExactDate       -- Y - поиск котировки за конкретную дату
                           и без продления предыдущей действующей котировки
      StoredRate      --выходное значение хранимой котировки, использованной для получения Rate
      Rate            --выходное значение котировки
---------------------------------------------------------------------------------------------------*/
as
begin
   declare
      @LocalCcy_Id   int,
      @CurDate      datetime

   select @LocalCcy_Id = Currencies_Id_Local from kplus.dbo.IdentityCard -- национальная валюта
   select @CurDate = convert(datetime,convert(char(8),getdate(),112),112)

   -- начитываем кастомные настройки поиска курса
   declare
      @UseMarketIfTodayFixingUndef  char(1),
      @UseMarketIfTodayHistUndef    char(1),
      @AllwaysUseMarketForTodayHist char(1),
      @UseRevPairIfDirectRateUndef  char(1)

   exec Radius_Settings_GetValueText 'CurrenciesRates::TodayFixingUndefined->UseMarketRate', @UseMarketIfTodayFixingUndef output, 'N'
   exec Radius_Settings_GetValueText 'CurrenciesRates::TodayHistoricalUndefined->UseMarketRate', @UseMarketIfTodayHistUndef output, 'Y'
   exec Radius_Settings_GetValueText 'CurrenciesRates::TodayHistorical->AllwaysUseMarketRate', @AllwaysUseMarketForTodayHist output, 'Y'
   exec Radius_Settings_GetValueText 'CurrenciesRates::DirectPairRateUndefined->UseReversePair', @UseRevPairIfDirectRateUndef output, 'Y'


   
   


   --select getdate() as _PR_1

   -- проставляем курс, равный 1 там, где валюты равны
   update Radius_Lib_CurrenciesRates set
      StoredRate = 1,
      Rate = 1
   from Radius_Lib_CurrenciesRates (index PK_Radius_Lib_CurrenciesRates)
   where
      SPID = @@SPID
      and Currencies_Id_1 = Currencies_Id_2

   -- начитываем ИД валютной пары
   update Radius_Lib_CurrenciesRates set
      Pairs_Id = r.Pairs_Id
   from Radius_Lib_CurrenciesRates cr (index PK_Radius_Lib_CurrenciesRates)
      inner join kplus..PairsDefT r (index PairsDefTIdx3)
         on  r.Currencies_Id_1 = cr.Currencies_Id_1
         and r.Currencies_Id_2 = cr.Currencies_Id_2
   where 1=1
      and cr.SPID       = @@SPID
      and cr.Pairs_Id   is NULL

   --select getdate() as _PR_2

   -- начитываем ИД обратной валютной пары, относительно Pairs_Id, для случаев когда:
   --    1) необходимо попытаться найти курс по обратной паре, если по прямой не найден
   --    2) необходимо найти курс по GoodOrder-паре
   update Radius_Lib_CurrenciesRates set
      Pairs_Id_Reverse = r.Pairs_Id
   from Radius_Lib_CurrenciesRates pr (index PK_Radius_Lib_CurrenciesRates)
      inner join kplus..PairsDefT p (index PairsDefTIdx1)
         on p.Pairs_Id = pr.Pairs_Id
      inner join kplus..PairsDefT r (index PairsDefTIdx3)
         on r.Currencies_Id_1 = p.Currencies_Id_2
         and r.Currencies_Id_2 = p.Currencies_Id_1
   where 1=1
      and pr.SPID = @@SPID

   --select getdate() as _PR_3

   -- 1. Поиск Revaluation котировок
   if exists(select 1 from Radius_Lib_CurrenciesRates where SPID = @@SPID and QuoteType = 'R')
   begin
      update Radius_Lib_CurrenciesRates set
         StoredRate = s.RevalRateMid,
         Rate  =  case when
                     (
                       (ps.QuotationMode = 'D' and ps.Currencies_Id_1 = c.Currencies_Id_1)
                       OR
                       (ps.QuotationMode = 'I' and ps.Currencies_Id_1 = @LocalCcy_Id)
                     )
                        then s.RevalRateMid / ps.Quotation
                     else  ps.Quotation / s.RevalRateMid
                  end
                  *
                  case when
                        (
                           (ps2.QuotationMode = 'D' and ps2.Currencies_Id_1 = @LocalCcy_Id)
                           OR
                           (ps2.QuotationMode = 'I' and ps2.Currencies_Id_1 = c.Currencies_Id_2)
                        )
                        then s2.RevalRateMid / ps2.Quotation
                     else ps2.Quotation / s2.RevalRateMid
                  end
      from Radius_Lib_CurrenciesRates c (index PK_Radius_Lib_CurrenciesRates),
         kplus..PairsDefT p (index PairsDefTIdx1),
         kplus..PairsDefT ps (index PairsDefTIdx3),
         kplus..PairsDefT ps2 (index PairsDefTIdx3),
         kplus..SpotQuotesT s (index SpotQuotesTIdx1),
         kplus..SpotQuotesT s2 (index SpotQuotesTIdx1)
      where 1=1
         and c.SPID              = @@SPID
         and c.QuoteType         = 'R'
         and c.Currencies_Id_1   != @LocalCcy_Id
         and c.Currencies_Id_2   != @LocalCcy_Id
         --сама пара
         and p.Pairs_Id            = c.Pairs_Id
         --найдем пару между валютой котировки и валютой системы
         and (ps.Currencies_Id_1 = c.Currencies_Id_1 AND ps.Currencies_Id_2 = @LocalCcy_Id
             OR
             ps.Currencies_Id_2 = c.Currencies_Id_1 AND ps.Currencies_Id_1 = @LocalCcy_Id)
         and ps.DisplayOrder     = 'Y'
         --найдем пару между котируемой валютой и валютой системы
         and (ps2.Currencies_Id_1 = c.Currencies_Id_2 AND ps2.Currencies_Id_2 = @LocalCcy_Id
             OR
             ps2.Currencies_Id_2 = c.Currencies_Id_2 AND ps2.Currencies_Id_1 = @LocalCcy_Id)
         and ps2.DisplayOrder     = 'Y'
         -- котируемая валюта
         and s.QuoteType         = 'R'
         and s.Currencies_Id     = c.Currencies_Id_1
         and s.PriceDate         = (select max(s_1.PriceDate)
                                    from kplus..SpotQuotesT s_1 (index SpotQuotesTIdx1)
                                    where 1=1
                                       and s_1.QuoteType       = s.QuoteType
                                       and s_1.Currencies_Id   = s.Currencies_Id
                                       and s_1.PriceDate       <= c.Date)
         -- валюта котировки
         and s2.QuoteType        = 'R'
         and s2.Currencies_Id    = c.Currencies_Id_2
         and s2.PriceDate        = (select max(s_2.PriceDate)
                                    from kplus..SpotQuotesT s_2 (index SpotQuotesTIdx1)
                                    where 1=1
                                       and s_2.QuoteType       = s2.QuoteType
                                       and s_2.Currencies_Id   = s2.Currencies_Id
                                       and s_2.PriceDate       <= c.Date)
         and s2.RevalRateMid <> 0

      --select getdate() as _PR_4

      -- одна из валюты в паре - валюта системы
      update Radius_Lib_CurrenciesRates set
         StoredRate = s.RevalRateMid,
         Rate = case p.QuotationMode
                  when 'D' then s.RevalRateMid / p.Quotation
                  when 'I' then p.Quotation / s.RevalRateMid
               end
      from Radius_Lib_CurrenciesRates c (index PK_Radius_Lib_CurrenciesRates),
         kplus..PairsDefT p (index PairsDefTIdx3),
         kplus..SpotQuotesT s (index SpotQuotesTIdx1)
      where 1=1
         and c.SPID             = @@SPID
         and c.QuoteType         = 'R'
         and (c.Currencies_Id_1  = @LocalCcy_Id
               or
              c.Currencies_Id_2    = @LocalCcy_Id)
         and p.Currencies_Id_1   = c.Currencies_Id_1
         and p.Currencies_Id_2   = c.Currencies_Id_2
         and s.QuoteType         = 'R'
         and s.Currencies_Id     = case c.Currencies_Id_1 when @LocalCcy_Id then c.Currencies_Id_2 else c.Currencies_Id_1 end
         and s.PriceDate         = (select max(s_1.PriceDate)
                                    from kplus..SpotQuotesT s_1 (index SpotQuotesTIdx1)
                                    where 1=1
                                       and s_1.QuoteType       = s.QuoteType
                                       and s_1.Currencies_Id    = s.Currencies_Id
                                       and s_1.PriceDate       <= c.Date)
         and s.RevalRateMid <> 0
   end

   --select getdate() as _PR_5

   -- если требуется GoodOrder = 'Y', а пара без признака GoodOrder, то меняем пару на обратную
   update Radius_Lib_CurrenciesRates set
      Pairs_Id_Reverse    = pr.Pairs_Id,
      Pairs_Id            = pr.Pairs_Id_Reverse,
      GoodOrder         = 'I'
   from Radius_Lib_CurrenciesRates pr (index PK_Radius_Lib_CurrenciesRates)
      inner join kplus..PairsDefT p (index PairsDefTIdx1)
         on p.Pairs_Id = pr.Pairs_Id
      inner join kplus..PairsLocT t   (index PairsLocTIdx1)
         on  t.Pairs_Id    = p.Pairs_Id
         and t.GoodOrder   = 'N'
   where 1=1
      and pr.SPID       = @@SPID
      and pr.QuoteType  in ('H','F')
      and pr.GoodOrder  = 'Y'

   --select getdate() as _PR_6

   -- 2. Поиск в исторических котировках
   -- 2.1. Поиск в исторических котировках для прямой валютной пары (Pairs_Id)
   -- 2.1.1. исторические котировки для Pairs_Id за конкретную дату
   update Radius_Lib_CurrenciesRates set
      StoredRate =
         case c.BidAskMiddle
            when 'M' then (q.SpotBid + q.SpotAsk)/2
            when 'B' then q.SpotBid
            when 'A' then q.SpotAsk
         end,
      Rate  =  case
                  when p.QuotationMode = 'D' then
                     (
                        case c.BidAskMiddle
                           when 'M' then (q.SpotBid + q.SpotAsk)/2
                           when 'B' then q.SpotBid
                           when 'A' then q.SpotAsk
                        end
                     ) / p.Quotation
                  when p.QuotationMode = 'I' and (q.SpotBid + q.SpotAsk)!=0 then
                     (
                        case c.BidAskMiddle
                           when 'M' then 2/(q.SpotBid + q.SpotAsk)
                           when 'A' then 1/q.SpotBid
                           when 'B' then 1/q.SpotAsk
                        end
                     ) * p.Quotation
                  else null
               end
   from
      Radius_Lib_CurrenciesRates c (index PK_Radius_Lib_CurrenciesRates)
      inner join kplus..PairsDefT p (index PairsDefTIdx1)
         on p.Pairs_Id = c.Pairs_Id
      inner join kplus..PairsQuotesT q  (index PairsQuotesTIdx1)
         on q.Pairs_Id     = p.Pairs_Id
         and q.QuoteType   = c.QuoteType 
         and q.PriceDate   = c.Date
   where 1=1
      and c.SPID        = @@SPID
      and c.QuoteType   in ('H','F')

   -- 2.1.2. если за историческую дату нет котировки, ищем последнюю сохраненную для ExactDate = 'N'
   update Radius_Lib_CurrenciesRates set
      StoredRate =
         case c.BidAskMiddle
            when 'M' then (q.SpotBid + q.SpotAsk)/2
            when 'B' then q.SpotBid
            when 'A' then q.SpotAsk
         end,
      Rate  =  case
                  when p.QuotationMode = 'D' then
                     (
                        case c.BidAskMiddle
                           when 'M' then (q.SpotBid + q.SpotAsk)/2
                           when 'B' then q.SpotBid
                           when 'A' then q.SpotAsk
                        end
                     ) / p.Quotation
                  when p.QuotationMode = 'I' and (q.SpotBid + q.SpotAsk)!=0 then
                     (
                        case c.BidAskMiddle
                           when 'M' then 2/(q.SpotBid + q.SpotAsk)
                           when 'A' then 1/q.SpotBid
                           when 'B' then 1/q.SpotAsk
                        end
                     ) * p.Quotation
                  else null
               end
   from
      Radius_Lib_CurrenciesRates c (index PK_Radius_Lib_CurrenciesRates)
      inner join kplus..PairsDefT p (index PairsDefTIdx1)
         on p.Pairs_Id = c.Pairs_Id
      inner join kplus..PairsQuotesT q  (index PairsQuotesTIdx1)
         on q.Pairs_Id = p.Pairs_Id
         and q.QuoteType       = c.QuoteType 
         and q.PriceDate       = (select max(q2.PriceDate)
                                 from kplus..PairsQuotesT q2  (index PairsQuotesTIdx1)
                                 where 1=1
                                    and q2.Pairs_Id   = p.Pairs_Id
                                    and q2.QuoteType  = c.QuoteType 
                                    and q2.PriceDate  <= c.Date)
   where 1=1
      and c.SPID        = @@SPID
      and
      (
         (
            c.Date                        <> @CurDate
            and c.QuoteType               in ('H','F')
         )
         or
         (  -- заполняем историческим значением на сегодня только если не требуется замены на текущие котировки
            @UseMarketIfTodayHistUndef    = 'N'
            and c.Date                    = @CurDate
            and c.QuoteType               = 'H'
         )
         or
         (  -- заполняем историческим значением на сегодня только если не требуется замены на текущие котировки
            @UseMarketIfTodayFixingUndef  = 'N'
            and c.Date                    = @CurDate
            and c.QuoteType               = 'F'
         )
      )
      and c.QuoteType   in ('H','F')
      and c.Rate        is NULL
      and c.ExactDate   = 'N'

   --select getdate() as _PR_9

   if @UseRevPairIfDirectRateUndef = 'Y'
   begin
      -- 2.2. Поиск в исторических котировках для обратной валютной пары (Pairs_Id_Reverse)
      -- 2.2.1. исторические котировки для Pairs_Id_Reverse за конкретную дату
      update Radius_Lib_CurrenciesRates set
         StoredRate =
            case c.BidAskMiddle
               when 'M' then (q.SpotBid + q.SpotAsk)/2
               when 'B' then q.SpotBid
               when 'A' then q.SpotAsk
            end,
         Rate  =  case
                     when p.QuotationMode = 'I' then
                        (
                           case c.BidAskMiddle
                              when 'M' then (q.SpotBid + q.SpotAsk)/2
                              when 'B' then q.SpotBid
                              when 'A' then q.SpotAsk
                           end
                        ) / p.Quotation
                     when p.QuotationMode = 'D' and (q.SpotBid + q.SpotAsk)!=0 then
                        (
                           case c.BidAskMiddle
                              when 'M' then 2/(q.SpotBid + q.SpotAsk)
                              when 'A' then 1/q.SpotBid
                              when 'B' then 1/q.SpotAsk
                           end
                        ) * p.Quotation
                     else null
                  end
      from
         Radius_Lib_CurrenciesRates c (index PK_Radius_Lib_CurrenciesRates)
         inner join kplus..PairsDefT p (index PairsDefTIdx1)
            on p.Pairs_Id = c.Pairs_Id_Reverse
         inner join kplus..PairsQuotesT q  (index PairsQuotesTIdx1)
            on q.Pairs_Id     = p.Pairs_Id
            and q.QuoteType   = c.QuoteType 
            and q.PriceDate   = c.Date
      where 1=1
         and c.SPID           = @@SPID
         and c.QuoteType      in ('H','F')
         and c.Rate           is NULL

      -- 2.2.2. если за историческую дату нет котировки, ищем последнюю сохраненную для ExactDate = 'N'
      update Radius_Lib_CurrenciesRates set
         StoredRate =
            case c.BidAskMiddle
               when 'M' then (q.SpotBid + q.SpotAsk)/2
               when 'B' then q.SpotBid
               when 'A' then q.SpotAsk
            end,
         Rate  =  case
                     when p.QuotationMode = 'I' then
                        (
                           case c.BidAskMiddle
                              when 'M' then (q.SpotBid + q.SpotAsk)/2
                              when 'B' then q.SpotBid
                              when 'A' then q.SpotAsk
                           end
                        ) / p.Quotation
                     when p.QuotationMode = 'D' and (q.SpotBid + q.SpotAsk)!=0 then
                        (
                           case c.BidAskMiddle
                              when 'M' then 2/(q.SpotBid + q.SpotAsk)
                              when 'A' then 1/q.SpotBid
                              when 'B' then 1/q.SpotAsk
                           end
                        ) * p.Quotation
                     else null
                  end
      from
         Radius_Lib_CurrenciesRates c (index PK_Radius_Lib_CurrenciesRates)
         inner join kplus..PairsDefT p (index PairsDefTIdx1)
            on p.Pairs_Id = c.Pairs_Id_Reverse
         inner join kplus..PairsQuotesT q  (index PairsQuotesTIdx1)
            on q.Pairs_Id     = p.Pairs_Id
            and q.QuoteType   = c.QuoteType 
            and q.PriceDate   = (select max(q2.PriceDate)
                                from kplus..PairsQuotesT q2  (index PairsQuotesTIdx1)
                                where 1=1
                                   and q2.Pairs_Id    = p.Pairs_Id
                                   and q2.QuoteType   = c.QuoteType 
                                   and q2.PriceDate   <= c.Date)
      where 1=1
         and c.SPID        = @@SPID
         and
         (
            (
               c.Date                        <> @CurDate
               and c.QuoteType               in ('H','F')
            )
            or
            (  -- заполняем историческим значением на сегодня только если не требуется замены на текущие котировки
               @UseMarketIfTodayHistUndef    = 'N'
               and c.Date                    = @CurDate
               and c.QuoteType               = 'H'
            )
            or
            (  -- заполняем историческим значением на сегодня только если не требуется замены на текущие котировки
               @UseMarketIfTodayFixingUndef  = 'N'
               and c.Date                    = @CurDate
               and c.QuoteType               = 'F'
            )
         )
         and c.Rate        is NULL
         and c.ExactDate   = 'N'
   end

   -- 3. Поиск в Realtime котировках
   -- 3.1. Поиск в Realtime котировках по прямой валютной паре (Pairs_Id)
   update Radius_Lib_CurrenciesRates set
      StoredRate =
         case c.BidAskMiddle
            when 'M' then rt.SpotRate
            when 'B' then rt.SpotRateBid
            when 'A' then rt.SpotRateAsk
         end,
      Rate = (case
               when p.QuotationMode = 'D' then (
                                          case c.BidAskMiddle
                                             when 'M' then rt.SpotRate
                                             when 'B' then rt.SpotRateBid
                                             when 'A' then rt.SpotRateAsk
                                          end
                                       ) / p.Quotation
               when p.QuotationMode = 'I' and rt.SpotRate != 0 then (
                                                         case c.BidAskMiddle
                                                            when 'M' then 1/rt.SpotRate
                                                            when 'A' then 1/rt.SpotRateBid
                                                            when 'B' then 1/rt.SpotRateAsk
                                                         end
                                                      ) * p.Quotation
                       else null
                  end)
   from Radius_Lib_CurrenciesRates c (index PK_Radius_Lib_CurrenciesRates)
      inner join kplus..PairsDefT p (index PairsDefTIdx1)
         on p.Pairs_Id       = c.Pairs_Id

      inner join kplus..PairsRTT rt (index PairsRTTIdx1)
         on rt.Pairs_Id      = c.Pairs_Id

   where 1=1
      and c.SPID        = @@SPID
      and c.Date        = @CurDate
      and
      (
         (  -- использовать текущий Market курс, если искомый Fixing на сегодня НЕ задан
            @UseMarketIfTodayFixingUndef  = 'Y'
            and c.QuoteType               = 'F'
            and c.Rate                    is NULL
         )
         or
         (  -- использовать текущий Market курс, если искомый Historical на сегодня НЕ задан
            @UseMarketIfTodayHistUndef    = 'Y'
            and c.QuoteType               = 'H'
            and c.Rate                    is NULL
         )
         or
         (  -- использовать текущий Market курс, даже если искомый Historical на сегодня задан
            @AllwaysUseMarketForTodayHist = 'Y'
            and c.QuoteType               = 'H'
         )
      )

   --select getdate() as _PR_7

   if @UseRevPairIfDirectRateUndef = 'Y'
   begin
      -- 3.2. Поиск в Realtime котировках по обратной валютной паре (Pairs_Id_Reverse)
      update Radius_Lib_CurrenciesRates set
         StoredRate =
            case c.BidAskMiddle
               when 'M' then rt.SpotRate
               when 'B' then rt.SpotRateBid
               when 'A' then rt.SpotRateAsk
            end,
         Rate = (case
                  when p.QuotationMode = 'I' then (
                                             case c.BidAskMiddle
                                                when 'M' then rt.SpotRate
                                                when 'B' then rt.SpotRateBid
                                                when 'A' then rt.SpotRateAsk
                                             end
                                          ) / p.Quotation
                  when p.QuotationMode = 'D' and rt.SpotRate != 0 then (
                                                            case c.BidAskMiddle
                                                               when 'M' then 1/rt.SpotRate
                                                               when 'A' then 1/rt.SpotRateBid
                                                               when 'B' then 1/rt.SpotRateAsk
                                                            end
                                                         ) * p.Quotation
                          else null
                     end)
      from Radius_Lib_CurrenciesRates c (index PK_Radius_Lib_CurrenciesRates)
         inner join kplus..PairsDefT p (index PairsDefTIdx1)
            on p.Pairs_Id       = c.Pairs_Id_Reverse

         inner join kplus..PairsRTT rt (index PairsRTTIdx1)
            on rt.Pairs_Id      = p.Pairs_Id

      where 1=1
         and c.SPID        = @@SPID
         and c.Date        = @CurDate
         and c.Rate        is NULL     -- если не нашли курс по прямой паре
         and
         (
            (  -- использовать текущий Market курс, если искомый Fixing на сегодня НЕ задан
               @UseMarketIfTodayFixingUndef  = 'Y'
               and c.QuoteType               = 'F'
            )
            or
            (  -- использовать текущий Market курс, если искомый Historical на сегодня НЕ задан
               @UseMarketIfTodayHistUndef    = 'Y'
               and c.QuoteType               = 'H'
            )
            or
            (  -- использовать текущий Market курс, даже если искомый Historical на сегодня задан
               @AllwaysUseMarketForTodayHist = 'Y'
               and c.QuoteType               = 'H'
            )
         )
   end

   --select getdate() as _PR_10

   -- для тех пар, которые принудительно разворачивали (требовался GoodOrder = 'Y'), перевернем курс
   update Radius_Lib_CurrenciesRates set
      Rate              =
         case
            when isnull(Rate, 0) <> 0 then 1 / Rate
            else Rate
         end,
      Pairs_Id          = Pairs_Id_Reverse,
      Pairs_Id_Reverse  = Pairs_Id,
      GoodOrder         = 'Y'
   from Radius_Lib_CurrenciesRates (index PK_Radius_Lib_CurrenciesRates)
   where 1=1
      and SPID       = @@SPID
      and GoodOrder  = 'I'





   --select getdate() as _PR_11

--SET FORCEPLAN OFF
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_CurrenciesRates_CLR') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_CurrenciesRates_CLR
GO

create procedure Radius_Lib_CurrenciesRates_CLR
/***************************************************************************************************
   Процедура для очистки буферной таблицы при поиске котировок по валютным парам
***************************************************************************************************/
as
begin
   delete Radius_Lib_CurrenciesRates
   from Radius_Lib_CurrenciesRates (index PK_Radius_Lib_CurrenciesRates)
   where SPID = @@SPID
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_CurrenciesRate_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_CurrenciesRate_Get
GO

create procedure Radius_Lib_CurrenciesRate_Get
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @Currencies_Id_1     integer,
   @Currencies_Id_2     integer,
   @RateDate            datetime,
   @Rate                float output,
   @QuoteType           char(1) = 'H',
   @BidAskMiddle        char(1) = 'M',
   @GoodOrder           char(1) = 'N',  -- Y/N = брать сначала курс пары с признаком GoodOrder
   @ExactDate           char(1) = 'N'   -- Y/N. Если Y, то сначала курс берем из истории, причем строго за дату @RateDate,
                                        --      если в истории не нашли, и если @RateDate='сегодня', то берем текущий курс из Pairs
                                        --      если в истории не нашли, и если @RateDate<>'сегодня', то ругаемся
)
as
begin
   delete Radius_Lib_CurrenciesRates from Radius_Lib_CurrenciesRates where SPID = @@SPID

   
   insert Radius_Lib_CurrenciesRates
   (
      Currencies_Id_1 ,
      Currencies_Id_2 ,
      Date ,
      ExactDate ,
      GoodOrder ,
      QuoteType ,
      BidAskMiddle ,
      SPID 
   )
   select
      @Currencies_Id_1 ,
      @Currencies_Id_2 ,
      @RateDate ,
      @ExactDate ,
      @GoodOrder ,
      @QuoteType ,
      @BidAskMiddle ,
      @@SPID 


   exec Radius_Lib_CurrenciesRates_Get

   select @Rate = cr.Rate
   from Radius_Lib_CurrenciesRates cr
   where cr.SPID = @@SPID
      and cr.Currencies_Id_1  = @Currencies_Id_1
      and cr.Currencies_Id_2  = @Currencies_Id_2
      and cr.Date             = @RateDate
      and cr.ExactDate        = @ExactDate
      and cr.GoodOrder        = @GoodOrder
      and cr.QuoteType        = @QuoteType
      and cr.BidAskMiddle     = @BidAskMiddle

   delete Radius_Lib_CurrenciesRates from Radius_Lib_CurrenciesRates where SPID = @@SPID
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_CpiValues_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_CpiValues_Get
GO

create procedure Radius_Lib_CpiValues_Get
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/* . Author: Alexander Alexandrov (2015-08-19)                                                          */
/*                                                                                                      */
/*   Процедура возвращает интерполированное значение CPI на требуемую дату                              */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @ConsumerPriceIndex_Id     int      = null,
   @CalcDate                  date     = null,
   @CpiLag                    int      = null,
   @InterpolationMethod       char(1)  = null,
   @AnticipatedInflation      float    = null,
   @CpiValue                  float    = null output
)
as
declare
   @CpiValue1                 float,
   @CpiValue2                 float,
   @CpiDate                   date,
   @CpiDate1                  date,    -- первое число месяца искомой даты
   @CpiDate2                  date,    -- первое число следующего месяца
   @MonthlyInflationCoeff     float,   -- коэффициент месячной инфляции
   @Months                    int
begin
   set nocount on

   -- если передали параметры, то не смотрим в таблицу, а работаем с переданными параметрами
   if @ConsumerPriceIndex_Id is not null
   begin
      -- если не передан минимальный набор параметров, то ничего не считаем
      if @CalcDate            is null
         or
         @CpiLag              is null
         or
         @InterpolationMethod is null
      begin
         return
      end

      delete from Radius_Lib_CpiValues where SPID = @@SPID

      
      insert Radius_Lib_CpiValues
      (
         ConsumerPriceIndex_Id ,
         CalcDate ,
         CpiLag ,
         InterpolationMethod ,
         AnticipatedInflation 
      )
      select
         @ConsumerPriceIndex_Id ,
         @CalcDate ,
         @CpiLag ,
         @InterpolationMethod ,
         @AnticipatedInflation 

   end

   update Radius_Lib_CpiValues set
      CpiDate                 = dateadd(mm, -CpiLag, CalcDate),
      CpiDate1                = dateadd(dd, -datepart(dd, CalcDate) + 1, CalcDate),
      MonthlyInflationCoeff   = power((1 + AnticipatedInflation / 100), 1e / 12)
   where SPID = @@SPID

   update Radius_Lib_CpiValues set
      CpiDate2                = dateadd(mm, 1, CpiDate1)
   where SPID = @@SPID

   -- находим значение CPI на начало месяца
   update Radius_Lib_CpiValues set
      CpiValue1  = cpiv.CpiValue
   from Radius_Lib_CpiValues r
      join kplus..CpiValues cpiv
         on cpiv.ConsumerPriceIndex_Id = r.ConsumerPriceIndex_Id
         and cpiv.Maturity             = dbo.Radius_Lib_DateToMaturity(r.CpiDate)
   where r.SPID      = @@SPID
      and r.CpiValue is null

   -- там, где нашли значение на конкретную дату, используем его
   update Radius_Lib_CpiValues set
      CpiValue = CpiValue1
   where SPID                    = @@SPID
      and datepart(dd, CalcDate) = 1
      and CpiValue1              is not null

   -- если на начало месяца CPI не задан, то вычисляем его на основе последнего значения CPI до искомой даты и значения ожидаемой инфляции
   update Radius_Lib_CpiValues set
      CpiValue1 =
         cpiv.CpiValue * power(r.MonthlyInflationCoeff, datediff(mm, dbo.Radius_Lib_MaturityToDate(cpiv.Maturity), r.CpiDate))
   from Radius_Lib_CpiValues r
      join kplus..CpiValues cpiv
         on cpiv.ConsumerPriceIndex_Id = r.ConsumerPriceIndex_Id
         and cpiv.Maturity             =
            dbo.Radius_Lib_DateToMaturity -- находим последний Maturity, на который есть значение CPI
            (
               (
                  select
                     max(dbo.Radius_Lib_MaturityToDate(cpiv_last.Maturity))
                  from kplus..CpiValues cpiv_last
                  where cpiv_last.ConsumerPriceIndex_Id                    = r.ConsumerPriceIndex_Id
                     and dbo.Radius_Lib_MaturityToDate(cpiv_last.Maturity) < r.CpiDate
               )
            )
   where SPID        = @@SPID
      and CpiValue1  is null

   -- там, где не нужна интерполяция
   update Radius_Lib_CpiValues set
      CpiValue = CpiValue1
   where SPID                 = @@SPID
      and CpiValue            is null
      and InterpolationMethod = 'N' -- None

   -- там, где нужна интерполяция, ищем значение CPI на начало следующего месяца
   update Radius_Lib_CpiValues set
      CpiValue2  = cpiv.CpiValue
   from Radius_Lib_CpiValues r
      join kplus..CpiValues cpiv
         on cpiv.ConsumerPriceIndex_Id = r.ConsumerPriceIndex_Id
         and cpiv.Maturity             = dbo.Radius_Lib_DateToMaturity(dateadd(mm, 1, r.CpiDate))
   where r.SPID                  = @@SPID
      and r.CpiValue             is null
      and r.InterpolationMethod  in ('L', 'O') -- Linear, Logarithmic

    -- если не нашли значение CPI на первое число следующего месяца, то используем для вычислений ожидаемый уровень инфляции
   update Radius_Lib_CpiValues set
      CpiValue2  = CpiValue1 * MonthlyInflationCoeff
   where SPID                 = @@SPID
      and CpiValue            is null
      and CpiValue2           is null
      and InterpolationMethod in ('L', 'O') -- Linear, Logarithmic

   -- находим искомое значение с помощью интерполяции
   update Radius_Lib_CpiValues set
      CpiValue = dbo.Radius_Lib_InterpolationCpi(CpiValue1, CpiValue2, CalcDate, CpiDate1, CpiDate2, InterpolationMethod)
   where SPID        = @@SPID
      and CpiValue   is null

   -- если передали параметры, то возвращаем значение
   if @ConsumerPriceIndex_Id is not null
   begin
      select
         @CpiValue = CpiValue
      from Radius_Lib_CpiValues
      where SPID = @@SPID

      delete from Radius_Lib_CpiValues where SPID = @@SPID
   end

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_Choice_Int2Str') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_Choice_Int2Str
GO

create procedure Radius_Lib_Choice_Int2Str
/*------------------------------------------------------------------------------------------------------
   Процедура Radius_Lib_Choice_Int2Str преобразует битовую маску Choice, сформированную в Радиусе при
   множественном выборе из Choice, в строку, содержащую последовательность символьных значений этого
   Choice, в составе и в порядке соответствующем выбору в Радиусе.
   подробнее см. в рубрике:
   http://support.systematica.ru/Rubrica/Help/Show?book=RADIUS&language=RU&article=Radius_Lib_Choice_Int2Str

   Copyright SYSTEMATICA
   Автор Мажорин Ю.Н., 12.02.2014
------------------------------------------------------------------------------------------------------*/
(
   @Type          varchar(10),   -- Kustom / kplus
   @Choices_Name  varchar(32),
   @ValuesInt     int,
   @ZeroMeansAll  int = 1,
   @ValuesStr     varchar(30) output
)
as
begin

   if object_id('tempdb..#ChoicesValues') is not null
   begin
      drop table #ChoicesValues
   end

   create table #ChoicesValues
      (
      RowNumber   int identity,
      Code        char(1)
      )

   -- наполняем табличку со значениями Choice в !нужном порядке!
   if @Type = 'Kustom'
   begin
      insert into #ChoicesValues
         (
         Code
         )
      select
         cv.InternalValue
      from
         Kustom..KustomChoices c
         inner join Kustom..KustomChoicesValues cv on
            cv.KustomChoices_Id = c.KustomChoices_Id
      where
         c.KustomChoices_Name = @Choices_Name
      order by
         cv.ChoiceOrder
   end
   else
   begin
      insert into #ChoicesValues
         (
         Code
         )
      select
         cv.InternalValue
      from
         kplus..KdbChoices c
         inner join kplus..KdbChoicesValues cv on
            cv.KdbChoices_Id = c.KdbChoices_Id
      where
         c.KdbChoices_Name = @Choices_Name
      order by
         cv.ChoiceOrder
   end

   -- теперь, имея непрерывающийся RowNumber и соответствующий порядку элементов в Радиусе,
   -- можем корректно отсеять невыбранные значения
   -- но только, если не определено параметром "не выбрано значений - значит выбраны все значения"
   if @ValuesInt <> 0 or
      @ZeroMeansAll = 0
   begin
      delete from #ChoicesValues where power(2, RowNumber - 1) & @ValuesInt = 0
   end

   -- остаётся только собрать список кодов в результирующую строку
   -- p.s. MS SQL код для этого был бы проще: select @Result = @Result + Code from #ChoicesValues order by RowNumber

   ------------------------------------------
   declare
      @Code char(1)
   select
      @ValuesStr  = ''

   
   declare ChoicesValues cursor  for 
      select
         Code
      from
         #ChoicesValues
      order by
         RowNumber asc
   
   open ChoicesValues

   fetch ChoicesValues into @Code
   while (@@sqlstatus = 0)
   begin
      
      set @ValuesStr = @ValuesStr + @Code
   
      fetch ChoicesValues into @Code
   end -- while (@@sqlstatus = 0)

   close ChoicesValues
   deallocate cursor ChoicesValues

   -----------------------------------------

   set @ValuesStr = ltrim(@ValuesStr)
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_BondsPrincipal_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_BondsPrincipal_Get
GO

create procedure Radius_Lib_BondsPrincipal_Get
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/* . Author: Alexander Alexandrov (2016-07-28)                                                          */
/*                                                                                                      */
/*   Процедура расчета номинала облигации.                                                              */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @Bonds_Id   int      = null,        -- ИД облигации
   @CalcDate   datetime = null,        -- расчетная дата (если NULL - берется текущая дата)
   @Principal  float    = null output, -- номинал облигации на расчетную дату
   @AdjFactor  float    = null output  -- коэффициент индексации номинала (если NULL - вычисляется)
)
as
begin

   if @Bonds_Id is not null
   begin
      -- если не передали дату, то считаем на текущую
      set @CalcDate = isnull(@CalcDate, convert(date, getdate()))

      delete from Radius_Lib_BondsPrincipal where SPID = @@SPID

      
      insert Radius_Lib_BondsPrincipal
      (
         Bonds_Id ,
         CalcDate ,
         AdjFactor 
      )
      select
         @Bonds_Id ,
         @CalcDate ,
         @AdjFactor 

   end

   -- вычисляем AdjFactor'ы облигаций на даты CalcDate, для тех записей, где он не задан
   delete from Radius_Lib_BondsAdjFactors where SPID = @@SPID

   
   insert Radius_Lib_BondsAdjFactors
   (
      SPID ,
      Bonds_Id ,
      CalcDate 
   )
   select distinct
      @@SPID ,
      Bonds_Id ,
      CalcDate 

   from Radius_Lib_BondsPrincipal
   where SPID        = @@SPID
      and AdjFactor  is null

   exec Radius_Lib_BondsAdjFactors_Get

   update Radius_Lib_BondsPrincipal set
      AdjFactor = af.AdjFactor
   from Radius_Lib_BondsPrincipal p
      left join Radius_Lib_BondsAdjFactors af
         on af.SPID        = @@SPID
         and af.Bonds_Id   = p.Bonds_Id
         and af.CalcDate   = p.CalcDate
   where p.SPID         = @@SPID
      and p.AdjFactor   is null

   delete from Radius_Lib_BondsAdjFactors where SPID = @@SPID

   -- вычисляем номинал
   update Radius_Lib_BondsPrincipal set
      Principal =
         p.AdjFactor *
         (
            b.FaceValue -
            (
               select
                  isnull(sum(s.CashFlow / (case s.AdjFactor when 0 then 1 else s.AdjFactor end)), 0)
               from kplus.dbo.BondsSchedule s   -- все прошедшие амортизационные выплаты
               where s.Bonds_Id        = p.Bonds_Id
                  and s.CashFlowType   = 'N'
                  and s.PaymentDate    <= p.CalcDate
               
            )
         )
   from Radius_Lib_BondsPrincipal p
      inner join kplus.dbo.Bonds b
         on b.Bonds_Id = p.Bonds_Id
   where p.SPID = @@SPID

   -- если передали параметры, то возвращаем значение
   if @Bonds_Id is not null
   begin
      select
         @Principal  = Principal,
         @AdjFactor  = AdjFactor
      from Radius_Lib_BondsPrincipal
      where SPID = @@SPID

      delete from Radius_Lib_BondsPrincipal where SPID = @@SPID
   end

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_BondsAdjFactors_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_BondsAdjFactors_Get
GO

create procedure Radius_Lib_BondsAdjFactors_Get
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/* . Author: Alexander Alexandrov (2015-08-19)                                                          */
/*                                                                                                      */
/*   Процедура расчета AdjFactor облигаций.                                                             */
/*                                                                                                      */
/*   AdjFactor - коэффициент, который определяет текущий номинал индексируемых облигаций:               */
/*      CurrentNominal = (FaceValue - Amortizations) * AdjFactor                                        */
/*   Для неиндексируемых облигаций AdjFactor равен 1.                                                   */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @Bonds_Id   int   = null,
   @CalcDate   date  = null,
   @AdjFactor  float = null output
)
as
begin
   set nocount on

   -- если передали параметры, то не смотрим в таблицу, а работаем с переданными параметрами
   if @Bonds_Id is not null
   begin
      -- если не передан минимальный набор параметров, то ничего не считаем
      if @CalcDate is null
      begin
         return
      end

      delete from Radius_Lib_BondsAdjFactors where SPID = @@SPID

      
      insert Radius_Lib_BondsAdjFactors
      (
         SPID ,
         Bonds_Id ,
         CalcDate 
      )
      select
         @@SPID ,
         @Bonds_Id ,
         @CalcDate 

   end


   -- начитаем параметры облигаций
   update Radius_Lib_BondsAdjFactors set
      PrincipalIndexed           = isnull(a.PrincipalIndexed, b.PrincipalIndexed),
      IssueDate                  = isnull(a.IssueDate, b.IssueDate),
      ConsumerPriceIndex_Id      = isnull(a.ConsumerPriceIndex_Id, bpm.ConsumerPriceIndex_Id_Cpi),
      OriginalRefCpi_Cpi         = isnull(a.OriginalRefCpi_Cpi, bpm.OriginalRefCpi_Cpi),
      AnticipatedInflation_Cpi   = isnull(a.AnticipatedInflation_Cpi, bpm.AnticipatedInflation_Cpi),
      RefCpiLag_Cpi              = isnull(a.RefCpiLag_Cpi, bpm.RefCpiLag_Cpi),
      IsRefCpiRounding_Cpi       = isnull(a.IsRefCpiRounding_Cpi, bpm.IsRefCpiRounding_Cpi),
      RefCpiRoundingConv_Cpi     = isnull(a.RefCpiRoundingConv_Cpi, bpm.RefCpiRoundingConv_Cpi),
      RefCpiRoundingType_Cpi     = isnull(a.RefCpiRoundingType_Cpi, bpm.RefCpiRoundingType_Cpi),
      AdjFactorRoundingConv_Cpi  = isnull(a.AdjFactorRoundingConv_Cpi, bpm.AdjFactorRoundingConv_Cpi),
      AdjFactorRoundingType_Cpi  = isnull(a.AdjFactorRoundingType_Cpi, bpm.AdjFactorRoundingType_Cpi),
      InterpolationMethod_Cpi    = isnull(a.InterpolationMethod_Cpi, bpm.InterpolationMethod_Cpi),
      InflationBondConvention    = isnull(a.InflationBondConvention, bpm.InflationBondConvention)
   from Radius_Lib_BondsAdjFactors a
      left join kplus..Bonds b
         on b.Bonds_Id     = a.Bonds_Id
      left join kplus..BondsPrincipalMethod bpm
         on bpm.Bonds_Id   = b.Bonds_Id
   where SPID = @@SPID

   -- для всех неиндексируемых облигаций AdjFactor выставляем в единицу
   update Radius_Lib_BondsAdjFactors set
      AdjFactor = 1
   where SPID              = @@SPID
      and PrincipalIndexed <> 'C' -- Consumer Price Index

   -- переведем значение RefCpiLag_Cpi в месяцы
   update Radius_Lib_BondsAdjFactors set
      RefCpiLag_Cpi = RefCpiLag_Cpi * 3
   where SPID                       = @@SPID
      and InflationBondConvention   = 'A'
      and AdjFactor                 is null

   -- если не задано опорное значение индекса потребительских цен, то рассчитываем его на дату выпуска облигации

   delete from Radius_Lib_CpiValues where SPID = @@SPID

   
insert Radius_Lib_CpiValues
(
   ConsumerPriceIndex_Id ,
   CalcDate ,
   CpiLag ,
   InterpolationMethod ,
   AnticipatedInflation 
)
select distinct
   ConsumerPriceIndex_Id ,
   IssueDate ,
   RefCpiLag_Cpi ,
   InterpolationMethod_Cpi ,
   AnticipatedInflation_Cpi 

   from Radius_Lib_BondsAdjFactors
   where SPID                             = @@SPID
      and isnull(OriginalRefCpi_Cpi, 0)   = 0
      and AdjFactor                       is null
      and IssueDate                       is not null
      and RefCpiLag_Cpi                   is not null
      and InterpolationMethod_Cpi         is not null

   exec Radius_Lib_CpiValues_Get

   update Radius_Lib_BondsAdjFactors set
       OriginalRefCpi_Cpi =
         case IsRefCpiRounding_Cpi
            when 'Y' then dbo.Radius_Lib_Round(c.CpiValue, RefCpiRoundingConv_Cpi, RefCpiRoundingType_Cpi)
            else c.CpiValue
         end
   from Radius_Lib_BondsAdjFactors a
      join Radius_Lib_CpiValues c
         on c.SPID                     = @@SPID
         and c.ConsumerPriceIndex_Id   = a.ConsumerPriceIndex_Id
         and c.CalcDate                = a.IssueDate
         and c.CpiLag                  = a.RefCpiLag_Cpi
         and c.InterpolationMethod     = a.InterpolationMethod_Cpi
         and c.AnticipatedInflation    = a.AnticipatedInflation_Cpi
   where a.SPID                           = @@SPID
      and isnull(a.OriginalRefCpi_Cpi, 0) = 0
      and a.AdjFactor                     is null

   delete from Radius_Lib_CpiValues where SPID = @@SPID

   -- рассчитаем значение индекса потребительских цен на искомую дату

   delete from Radius_Lib_CpiValues where SPID = @@SPID

   
insert Radius_Lib_CpiValues
(
   ConsumerPriceIndex_Id ,
   CalcDate ,
   CpiLag ,
   InterpolationMethod ,
   AnticipatedInflation 
)
select distinct
   ConsumerPriceIndex_Id ,
   CalcDate ,
   RefCpiLag_Cpi ,
   InterpolationMethod_Cpi ,
   AnticipatedInflation_Cpi 

   from Radius_Lib_BondsAdjFactors
   where SPID                       = @@SPID
      and AdjFactor                 is null
      and CalcDate                  is not null
      and RefCpiLag_Cpi             is not null
      and InterpolationMethod_Cpi   is not null

   exec Radius_Lib_CpiValues_Get

   update Radius_Lib_BondsAdjFactors set
       CpiValue =
         case IsRefCpiRounding_Cpi
            when 'Y' then dbo.Radius_Lib_Round(c.CpiValue, RefCpiRoundingConv_Cpi, RefCpiRoundingType_Cpi)
            else c.CpiValue
         end
   from Radius_Lib_BondsAdjFactors a
      join Radius_Lib_CpiValues c
         on c.SPID                     = @@SPID
         and c.ConsumerPriceIndex_Id   = a.ConsumerPriceIndex_Id
         and c.CalcDate                = a.CalcDate
         and c.CpiLag                  = a.RefCpiLag_Cpi
         and c.InterpolationMethod     = a.InterpolationMethod_Cpi
         and c.AnticipatedInflation    = a.AnticipatedInflation_Cpi
   where a.SPID                     = @@SPID
      and a.AdjFactor               is null

   delete from Radius_Lib_CpiValues where SPID = @@SPID

   -- рассчитываем @AdjFactor
   update Radius_Lib_BondsAdjFactors set
      AdjFactor =
         case
            when OriginalRefCpi_Cpi <> 0 then CpiValue / OriginalRefCpi_Cpi
            else null
         end
   where SPID        = @@SPID
      and AdjFactor  is null

   -- округляем результат
   update Radius_Lib_BondsAdjFactors set
      AdjFactor = dbo.Radius_Lib_Round(AdjFactor, AdjFactorRoundingConv_Cpi, AdjFactorRoundingType_Cpi)
   where SPID        = @@SPID

   -- если передали параметры, то возвращаем значение
   if @Bonds_Id is not null
   begin
      select
         @AdjFactor = AdjFactor
      from Radius_Lib_BondsAdjFactors
      where SPID = @@SPID

      delete from Radius_Lib_BondsAdjFactors where SPID = @@SPID
   end

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_BondsAccrued_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_BondsAccrued_Get
GO

create procedure Radius_Lib_BondsAccrued_Get
as
begin
   -- отключим ошибки округления, так как работаем с числами с фиксированной запятой
   --The precision of a datatype denotes the maximum number of digits allowed in columns of that datatype.
   --For the exact numeric types dec, decimal and numeric, the allowed range of data depends on the column's
   --precision as well as its scale, that is, the maximum number of digits that are allowed to the right of the decimal point.

   -- Error 3624 occurs when an operation inserts data into a target column or variable but the precision
   --or scale of the target are too small for the data. The operation fails and the command is aborted.
   set arithabort numeric_truncation off

   declare @TL_ProcName varchar(50), @TL_ExecProc varchar(50), @TL_Scope varchar(50), @TL_Cmd varchar(100), @TL_TimingIsEnabled char(1), @TL_TimeStamp datetime select @TL_TimingIsEnabled = 'N', @TL_TimeStamp = getdate(), @TL_Scope = object_name(@@procid), @TL_ExecProc = 'RadiusTimingLog_INIT' if object_id('Kustom..RadiusTimingLog_INIT') is not NULL exec @TL_ExecProc 'CORE',@TL_Scope,@TimingIsEnabled = @TL_TimingIsEnabled output

   update Radius_Lib_BondsAccrued set
      Amount      = null,
      [Percent]   = null
   where SPID                 = @@SPID
      and isnull(Quantity, 0) = 0

   /*
      Необходимо делать подмену базиса для непервого платежа облигации для двух базисов:
         1. (ACT+1)/360
         2. (ACT+1)/365

      Из доки кондора:

      Kondor+ uses the (ACT + 1)/360 day count basis to calculate the first row in a bond cash flow schedule
      and the cash flows of interest or pay off type in deal cash flow schedules, and then calculates the other
      rows using the ACT/360 basis. To calculate the first row of the cash flow schedule and interest or pay off
      cash flows, Kondor+ adds one day to the actual number of days between D1 and D2 and then divides it
      by 360.

      Если мы считаем НКД для первого Interest платежа, то подмену делать не нужно.
   */

   -- заполняем порядок купонного периода (First, Last, Middle)
   update Radius_Lib_BondsAccrued set
      CouponPeriod =
         case
            when s.EndDate =
               (
                  select
                     min(si.EndDate)
                  from kplus.dbo.BondsSchedule si
                  where si.Bonds_Id       = a.Bonds_Id
                     and si.CashFlowType  = 'I'
               ) then 'F'
            when s.EndDate =
               (
                  select
                     max(si.EndDate)
                  from kplus.dbo.BondsSchedule si
                  where si.Bonds_Id       = a.Bonds_Id
                     and si.CashFlowType  = 'I'
               ) then 'L'
            else 'M'
         end
   from Radius_Lib_BondsAccrued a
      inner join kplus..BondsSchedule s   -- текущий купонный период
         on s.Bonds_Id        = a.Bonds_Id
         and s.StartDate      <= a.Date
         and s.EndDate        > a.Date
         and s.CashFlowType   = 'I'
         and s.AccruedBasis   in ('D','F','Z')
   where a.SPID = @@SPID

   if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'12073',6)+'//'+'CouponPeriod', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end

   -- вычисляем AdjFactor'ы облигаций на даты Date
   delete from Radius_Lib_BondsAdjFactors where SPID = @@SPID

   
   insert Radius_Lib_BondsAdjFactors
   (
      SPID ,
      Bonds_Id ,
      CalcDate 
   )
   select
      distinct @@SPID ,
      Bonds_Id ,
      Date 

   from Radius_Lib_BondsAccrued
   where SPID        = @@SPID
      and AdjFactor  is null

   if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'12086',6)+'//'+'AdjFac_prep', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end

   exec Radius_Lib_BondsAdjFactors_Get

   if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'12090',6)+'//'+'AdjFac_calc', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end

   update Radius_Lib_BondsAccrued set
      AdjFactor = af.AdjFactor
   from Radius_Lib_BondsAccrued a
      left join Radius_Lib_BondsAdjFactors af
         on af.SPID        = @@SPID
         and af.Bonds_Id   = a.Bonds_Id
         and af.CalcDate   = a.Date
   where a.SPID         = @@SPID
      and a.AdjFactor   is null

   if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'12102',6)+'//'+'AdjFac_put', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end

   delete from Radius_Lib_BondsAdjFactors where SPID = @@SPID

   -- заполняем поле текущий номинал
   update Radius_Lib_BondsAccrued set
      CurrentNominal =
         a.AdjFactor *
         (
            b.FaceValue -
            (
               select
                  isnull(sum(s.CashFlow / (case s.AdjFactor when 0 then 1 else s.AdjFactor end)), 0)
               from kplus..BondsSchedule s   -- все прошедшие амортизационные выплаты
               where s.Bonds_Id        = a.Bonds_Id
                  and s.CashFlowType   = 'N'
                  and s.PaymentDate    <= a.Date
               
            )
         )
   from Radius_Lib_BondsAccrued a
      inner join kplus..Bonds b
         on b.Bonds_Id     = a.Bonds_Id
   where a.SPID = @@SPID

   if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'12139',6)+'//'+'Nominal_put', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end

   -- вычисляем YearFraction'ы
   delete from Radius_Lib_YearFraction where SPID = @@SPID

   
   insert Radius_Lib_YearFraction
   (
      SPID ,
      StartDate ,
      EndDate ,
      Basis ,
      Period 
   )
   select
      distinct @@SPID ,
      s.StartDate ,
      a.Date ,
      s.AccruedBasis ,
      a.CouponPeriod 

   from Radius_Lib_BondsAccrued a
      inner join kplus..BondsSchedule s   -- текущий купонный период
         on s.Bonds_Id     = a.Bonds_Id
         and s.StartDate   <= a.Date
         and s.EndDate     > a.Date
   where a.SPID = @@SPID

   exec Radius_Lib_YearFraction_Get

   if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'12159',6)+'//'+'YF_Calc', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end

   -- вычисляем Days'ы
   delete from Radius_Lib_DateDiff_Basis where SPID = @@SPID

   
   insert Radius_Lib_DateDiff_Basis
   (
      SPID ,
      StartDate ,
      EndDate ,
      Basis ,
      Period 
   )
   select
      distinct @@SPID ,
      s.StartDate ,
      
            case dt.DateType
               when 'Date'    then a.Date
               when 'EndDate' then s.EndDate
            end
          ,
      s.AccruedBasis ,
      a.CouponPeriod 

   from Radius_Lib_BondsAccrued a
      inner join kplus..BondsSchedule s   -- текущий купонный период
         on s.Bonds_Id     = a.Bonds_Id
         and s.StartDate   <= a.Date
         and s.EndDate     > a.Date
      inner join
         (
            select 'Date' DateType
            union
            select 'EndDate'
         ) dt
         on 1=1
   where a.SPID = @@SPID

   exec Radius_Lib_DateDiff_Basis_Get

   if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'12192',6)+'//'+'Days_Calc', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end

   /*
      в случаях, когда в течение купонного периода меняется его ставка или базис,
      купонный период сплитуется на два (или более),
      поэтому ищем завершенные купонные периоды являющиеся частями засплитованного купонного периода,
      частью которого также является текущий купонный период,
      так как платежи по данным купонным периодам также будут влиять на НКД
   */
   update Radius_Lib_BondsAccrued set
      AddAmount  =
         (
            select isnull(sum(s2.CashFlow), 0)
            from kplus..BondsSchedule s2
            where s2.Bonds_Id       = a.Bonds_Id
               and s2.EndDate       <= a.Date
               and s2.PaymentDate   = s.PaymentDate
               and s2.CashFlowType  = 'I'
         ),
      AddPercent =
         100 *
         (
            select isnull(sum(s2.CashFlow), 0)
            from kplus..BondsSchedule s2
            where s2.Bonds_Id       = a.Bonds_Id
               and s2.EndDate       <= a.Date
               and s2.PaymentDate   = s.PaymentDate
               and s2.CashFlowType  = 'I'
         ) / a.CurrentNominal
   from Radius_Lib_BondsAccrued a
      inner join kplus..Bonds b
         on b.Bonds_Id        = a.Bonds_Id
      inner join kplus..BondsSchedule s
         on s.Bonds_Id        = a.Bonds_Id
         and s.StartDate      <= a.Date
         and s.EndDate        > a.Date
         and s.CashFlowType   = 'I'
   where a.SPID            = @@SPID
      and a.CurrentNominal <> 0

   if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'12232',6)+'//'+'AddFields_Calc', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end

   -- вычисляем сумму и процент НКД
   update Radius_Lib_BondsAccrued set

      Amount   = round(a.Quantity *
              case
               when substring(cw.Method,1,1) = 'G' and b.CouponRoundingType = 'R'
                  then a.CurrentNominal * round(a.AddPercent + convert(numeric(28,10), s.Rate) * convert(numeric(28,10), yf.YearFraction),b.CouponRoundingConv)/100

               when isnull(cw.Method,'') = ''      and b.CouponRoundingType = 'R'
                  then a.CurrentNominal * round(a.AddPercent + convert(numeric(28,10), s.Rate) * convert(numeric(28,10), yf.YearFraction),b.CouponRoundingConv)/100

               when substring(cw.Method,1,1) = 'G' and b.CouponRoundingType = 'T'
                  then a.CurrentNominal * convert(numeric(28,0), floor(a.AddPercent + convert(numeric(28,10), s.Rate) * convert(numeric(28,10), yf.YearFraction) * power(10,b.CouponRoundingConv)))/power(10,b.CouponRoundingConv)/100

               when isnull(cw.Method,'') = ''      and b.CouponRoundingType = 'T'
                  then a.CurrentNominal * convert(numeric(28,0), floor(a.AddPercent + convert(numeric(28,10), s.Rate) * convert(numeric(28,10), yf.YearFraction) * power(10,b.CouponRoundingConv)))/power(10,b.CouponRoundingConv)/100

               when substring(cw.Method,1,1) = 'C' and b.CouponRoundingType in ('R','T')
                  then round(a.AddAmount + a.CurrentNominal * convert(numeric(28,10), s.Rate)/100 * convert(numeric(28,10), yf.YearFraction), c.NoDecimal)

               when substring(cw.Method,1,1) = 'P' and b.CouponRoundingType = 'R'
                  then a.CurrentNominal * round(a.AddPercent + convert(numeric(28,10), s.CashFlow)/a.CurrentNominal*d.Days/dc.Days*100, b.CouponRoundingConv) / 100

               when substring(cw.Method,1,1) = 'P' and b.CouponRoundingType = 'T'
                  then a.CurrentNominal * convert(numeric(28,0), floor(a.AddPercent + convert(numeric(28,10), s.CashFlow)/a.CurrentNominal*d.Days/dc.Days*power(10,b.CouponRoundingConv)*100))/power(10,b.CouponRoundingConv) / 100

               when substring(cw.Method,1,1) = 'M' and b.CouponRoundingType = 'R'
                  then round(a.AddAmount + convert(numeric(28,10), s.CashFlow)*d.Days/dc.Days, c.NoDecimal)

               when substring(cw.Method,1,1) = 'M' and b.CouponRoundingType = 'T'
                  then round(a.AddAmount + convert(numeric(28,10), s.CashFlow)*d.Days/dc.Days, c.NoDecimal)
              end, c.NoDecimal),
      [Percent] =
              case
               when substring(cw.Method,1,1) = 'G' and b.CouponRoundingType = 'R'
                  then round(a.AddPercent + convert(numeric(28,10), s.Rate) * convert(numeric(28,10), yf.YearFraction),b.CouponRoundingConv)

               when isnull(cw.Method,'') = ''      and b.CouponRoundingType = 'R'
                  then round(a.AddPercent + convert(numeric(28,10), s.Rate) * convert(numeric(28,10), yf.YearFraction),b.CouponRoundingConv)

               when substring(cw.Method,1,1) = 'G' and b.CouponRoundingType = 'T'
                  then convert(numeric(28,0), floor(a.AddPercent + convert(numeric(28,10), s.Rate) * convert(numeric(28,10), yf.YearFraction) * power(10,b.CouponRoundingConv)))/power(10,b.CouponRoundingConv)

               when isnull(cw.Method,'') = ''      and b.CouponRoundingType = 'T'
                  then convert(numeric(28,0), floor(a.AddPercent + convert(numeric(28,10), s.Rate) * convert(numeric(28,10), yf.YearFraction) * power(10,b.CouponRoundingConv)))/power(10,b.CouponRoundingConv)

               when substring(cw.Method,1,1) = 'C' and b.CouponRoundingType = 'R'
                  then round(100 * convert(numeric(28,10),round(a.AddAmount + a.CurrentNominal * convert(numeric(28,10), s.Rate)/100 *  convert(numeric(28,10), yf.YearFraction), c.NoDecimal))/a.CurrentNominal, b.CouponRoundingConv)

               when substring(cw.Method,1,1) = 'C' and b.CouponRoundingType = 'T'
                  then convert(numeric(28,0), floor(100 * convert(numeric(28,10),round(a.AddAmount + a.CurrentNominal * convert(numeric(28,10), s.Rate)/100 *  convert(numeric(28,10), yf.YearFraction), c.NoDecimal))/a.CurrentNominal*power(10,b.CouponRoundingConv)))/power(10,b.CouponRoundingConv)

               when substring(cw.Method,1,1) = 'P' and b.CouponRoundingType = 'R'
                  then round(a.AddPercent + convert(numeric(28,10), s.CashFlow)/a.CurrentNominal*d.Days/dc.Days*100, b.CouponRoundingConv)

               when substring(cw.Method,1,1) = 'P' and b.CouponRoundingType = 'T'
                  then convert(numeric(28,0), floor(a.AddPercent + convert(numeric(28,10), s.CashFlow)/a.CurrentNominal*d.Days/dc.Days*power(10,b.CouponRoundingConv)*100))/power(10,b.CouponRoundingConv)

               when substring(cw.Method,1,1) = 'M' and b.CouponRoundingType = 'R'
                  then round(round(a.AddAmount + convert(numeric(28,10), s.CashFlow)*d.Days/dc.Days, c.NoDecimal) / a.CurrentNominal * 100, b.CouponRoundingConv)

               when substring(cw.Method,1,1) = 'M' and b.CouponRoundingType = 'T'
                  then convert(numeric(28,0), floor(round(a.AddAmount + convert(numeric(28,10), s.CashFlow)*d.Days/dc.Days, c.NoDecimal) / a.CurrentNominal * 100 * power(10,b.CouponRoundingConv)))/power(10,b.CouponRoundingConv)
              end

   from Radius_Lib_BondsAccrued a
      inner join kplus..Bonds b
         on b.Bonds_Id        = a.Bonds_Id
      inner join kplus..Currencies c
         on c.Currencies_Id   = b.Currencies_Id

      left join RTR_CW_BondsCouponParam cw
         on cw.DealId         = a.Bonds_Id
         and cw.DealType      = 'Bonds'

      inner join kplus..BondsSchedule s
         on s.Bonds_Id        = a.Bonds_Id
         and s.StartDate      <= a.Date
         and s.EndDate        > a.Date
         and s.CashFlowType   = 'I'
      inner join Radius_Lib_YearFraction yf
         on yf.SPID           = @@SPID
         and yf.StartDate     = s.StartDate
         and yf.EndDate       = a.Date
         and yf.Basis         = s.AccruedBasis
         and yf.Period        = a.CouponPeriod
      inner join Radius_Lib_DateDiff_Basis d
         on d.SPID            = @@SPID
         and d.StartDate      = s.StartDate
         and d.EndDate        = a.Date
         and d.Basis          = s.AccruedBasis
         and d.Period         = a.CouponPeriod
      inner join Radius_Lib_DateDiff_Basis dc   -- количество дней в купонном периоде
         on dc.SPID           = @@SPID
         and dc.StartDate     = s.StartDate
         and dc.EndDate       = s.EndDate
         and dc.Basis         = s.AccruedBasis
         and dc.Period        = a.CouponPeriod
   where a.SPID            = @@SPID
      and a.CurrentNominal <> 0

   if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'12346',6)+'//'+'CalcAccrued', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end

   delete from Radius_Lib_DateDiff_Basis where SPID = @@SPID

   delete from Radius_Lib_YearFraction where SPID = @@SPID

   declare
      @Bonds_Id     int,
      @Date         datetime,
      @Accrued      float

   -- если на текущий момент по каким-то из бондов не найден НКД, воспользуемся KFS'ом
   select Bonds_Id, Date
   into #tmp
   from Radius_Lib_BondsAccrued
   where [Percent]   is null
      and SPID       = @@SPID

   
   declare KFS cursor  for 
         select Bonds_Id, Date from #tmp
      
   open KFS

   fetch KFS into @Bonds_Id, @Date
   while (@@sqlstatus = 0)
   begin
      
         exec Radius_Bonds_CalcAccrued @Bonds_Id, null, @Date, @Date, @Accrued output

         update Radius_Lib_BondsAccrued set
            [Percent]   = a.AddPercent + @Accrued,
            Amount      =
               round
               (
                  a.Quantity * a.CurrentNominal * convert(numeric(28,10), a.AddPercent + @Accrued) / 100
                  , c.NoDecimal
               )
         from Radius_Lib_BondsAccrued a
            inner join kplus..Bonds b
               on b.Bonds_Id        = a.Bonds_Id
            inner join kplus..Currencies c
               on c.Currencies_Id   = b.Currencies_Id
         where a.Bonds_Id  = @Bonds_Id
            and a.Date     = @Date
            and a.SPID     = @@SPID

         if @TL_TimingIsEnabled = 'Y' begin select @TL_Cmd = @TL_Scope + '//'+right('00000'+'12364',6)+'//'+'CalcByKFS', @TL_ExecProc = 'RadiusTimingLog_PUT' if object_id('Kustom..RadiusTimingLog_PUT') is not NULL exec @TL_ExecProc @TL_Cmd,@TL_TimeStamp = @TL_TimeStamp select @TL_TimeStamp = getdate() end
      
      fetch KFS into @Bonds_Id, @Date
   end -- while (@@sqlstatus = 0)

   close KFS
   deallocate cursor KFS



   set arithabort numeric_truncation on
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_BondAccrued') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_BondAccrued
GO

create procedure Radius_Lib_BondAccrued
(
   @Bonds_Id                  integer,
   @Quantity                  numeric(28,10),
   @CalcDate                  datetime,
   @AccruedInterestAmount     numeric(28,10) output,
   @AccruedInterestPercent    numeric(28,10) output,
   @AdjFactor                 numeric(28,10) = null
)
as
begin
   -- отключим ошибки округления, так как работаем с числами с фиксированной запятой
   -- The precision of a datatype denotes the maximum number of digits allowed in columns of that datatype.
   -- For the exact numeric types dec, decimal and numeric, the allowed range of data depends on the column's
   -- precision as well as its scale, that is, the maximum number of digits that are allowed to the right of the decimal point.

   -- Error 3624 occurs when an operation inserts data into a target column or variable but the precision
   -- or scale of the target are too small for the data. The operation fails and the command is aborted.
   set arithabort numeric_truncation off

   declare
      @AC_Method           char(1),
      @CurrentNominal      numeric(28,10),
      @Basis               char(1),
      @CouponRoundingConv  integer,
      @CouponRoundingType  char(1),
      @CouponStartDate     datetime,
      @CouponEndDate       datetime,
      @CouponPaymentDate   datetime,
      @CouponRate          numeric(28,10),
      @CouponCashFlow      numeric(28,10),
      @YF                  numeric(28,10),
      @CouponPeriod        char(1), -- 'F' - first, 'M' - middle, 'L' - last
      @Days                int,
      @DaysCoupon          int,
      @CouponFrequency     char(1),
      @ProcName            varchar(256),
      @InternalKey         varchar(64),
      @OutValue            float,
      @FirstCouponEndDate  datetime,
      @LastCouponEndDate   datetime,
      @AddInterestAmount   numeric(28,10),
      @AddInterestPercent  numeric(28,10),
      @Amount_NoDecimal    int


   /*
      Необходимо делать подмену базиса для непервого платежа облигации для двух базисов:
         1. (ACT+1)/360
         2. (ACT+1)/365

      Из доки кондора:

      Kondor+ uses the (ACT + 1)/360 day count basis to calculate the first row in a bond cash flow schedule
      and the cash flows of interest or pay off type in deal cash flow schedules, and then calculates the other
      rows using the ACT/360 basis. To calculate the first row of the cash flow schedule and interest or pay off
      cash flows, Kondor+ adds one day to the actual number of days between D1 and D2 and then divides it
      by 360.

      Если мы считаем НКД для первого Interest платежа, то подмену делать не нужно.
   */

   -- найдем дату EndDate первого и последнего купонного платежа
   select
      @FirstCouponEndDate = min(EndDate)
   from kplus.dbo.BondsSchedule
   where Bonds_Id       = @Bonds_Id
      and CashFlowType  = 'I'

   select
      @LastCouponEndDate = max(EndDate)
   from kplus.dbo.BondsSchedule
   where Bonds_Id       = @Bonds_Id
      and CashFlowType  = 'I'

   -- читаем параметры купонного периода бумаги, в который попадает дата @CalcDate
   select
      @Basis               = AccruedBasis,
      @CouponPeriod        =
         case
            when EndDate = @FirstCouponEndDate then 'F'
            when EndDate = @LastCouponEndDate  then 'L'
            else 'M'
         end,
      @CouponCashFlow      = CashFlow,    -- Сумма купона
      @CouponStartDate     = StartDate,
      @CouponEndDate       = EndDate,
      @CouponPaymentDate   = PaymentDate,
      @CouponRate          = Rate
   from kplus.dbo.BondsSchedule
   where Bonds_Id       = @Bonds_Id
      and StartDate     <= @CalcDate
      and EndDate       > @CalcDate
      and CashFlowType  = 'I'

   -- вычисляем AdjFactor облигации на дату @CalcDate
   if @AdjFactor is null
   begin
      exec Radius_Lib_BondsAdjFactors_Get @Bonds_Id, @CalcDate, @AdjFactor output
   end

   -- вычисляем номинал облигации на дату @CalcDate
   select @CurrentNominal =   @AdjFactor *
                              (
                                 (
                                    select b.FaceValue
                                    from kplus.dbo.Bonds b
                                    where b.Bonds_Id = @Bonds_Id
                                 )
                                 -
                                 (
                                    select isnull(sum(s.CashFlow / (case s.AdjFactor when 0 then 1 else s.AdjFactor end)), 0)
                                    from kplus.dbo.BondsSchedule s
                                    where s.Bonds_Id        = @Bonds_Id
                                       and s.CashFlowType   = 'N'
                                       and s.PaymentDate    <= @CalcDate
                                 )
                              )


   -- если номинал не задан, то ничего не считаем
   if isnull(@CurrentNominal, 0) = 0
   begin
      select
         @AccruedInterestAmount  = null,
         @AccruedInterestPercent = null

      set arithabort numeric_truncation on

      return
   end

   -- в случаях, когда в течение купонного периода меняется его ставка или базис, купонный период сплитуется на два (или более),
   -- поэтому ищем завершенные купонные периоды являющиеся частями засплитованного купонного периода, частью которого также является текущий купонный период,
   -- так как платежи по данным купонным периодам также будут влиять на НКД
   select
      @AddInterestPercent = 100 * sum(CashFlow) / @CurrentNominal,
      @AddInterestAmount  = sum(CashFlow)
   from kplus..BondsSchedule
   where Bonds_Id       = @Bonds_Id
      and EndDate       <= @CalcDate         -- купонный период завершился
      and PaymentDate   = @CouponPaymentDate -- дата выплаты купонного платежа совпадает с датой выплаты текущего купонного периода
      and CashFlowType  = 'I'

   select
      @AddInterestPercent = isnull(@AddInterestPercent, 0),
      @AddInterestAmount  = isnull(@AddInterestAmount, 0)


   -- достаем способ расчета НКД по облигациям (по умолчанию @AC_Method = Null)
   select
      @AC_Method = substring(Method, 1, 1)
   from RTR_CW_BondsCouponParam
   where DealId      = @Bonds_Id
      and DealType   = 'Bonds'


   select
      @CouponRoundingConv  = b.CouponRoundingConv,
      @CouponRoundingType  = b.CouponRoundingType,
      @CouponFrequency     = b.CouponFrequency,
      @Amount_NoDecimal    = c.NoDecimal
   from kplus.dbo.Bonds b
      inner join kplus.dbo.Currencies c
         on c.Currencies_Id   = b.Currencies_Id
   where b.Bonds_Id = @Bonds_Id

   declare @fYF float--процедура вернет float, нам нужно преобразовать в numeric @YF

   exec Radius_Lib_YearFraction_Get
      @StartDate     = @CouponStartDate,
      @EndDate       = @CalcDate,
      @Basis         = @Basis,
      @Frequency     = @CouponFrequency,
      @Period        = @CouponPeriod,
      @YearFraction  = @fYF output

   select @YF = convert(numeric(28,10), @fYF)

   declare @fDays float--процедура вернет float, нам нужно преобразовать в numeric @Days

   exec Radius_Lib_DateDiff_Basis_Get
      @StartDate     = @CouponStartDate,
      @EndDate       = @CalcDate,
      @Basis         = @Basis,
      @Frequency     = @CouponFrequency,
      @Period        = @CouponPeriod,
      @Days          = @fDays output

   select @Days = convert(numeric(28,10), @fDays)

   declare @fDaysCoupon float--процедура вернет float, нам нужно преобразовать в numeric @Days

   exec Radius_Lib_DateDiff_Basis_Get
      @StartDate     = @CouponStartDate,
      @EndDate       = @CouponEndDate,
      @Basis         = @Basis,
      @Frequency     = @CouponFrequency,
      @Period        = @CouponPeriod,
      @Days          = @fDaysCoupon output

   select @DaysCoupon = convert(numeric(28,10), @fDaysCoupon)

   -- GlobalNominal
   if (@AC_Method = 'G' or isnull(@AC_Method,'') = '') and @CouponRoundingType = 'R'
   begin
      select @AccruedInterestPercent   = round(@AddInterestPercent + @CouponRate * @YF, @CouponRoundingConv)
      select @AccruedInterestAmount    = round(@Quantity * @CurrentNominal * @AccruedInterestPercent / 100, @Amount_NoDecimal)
   end

   else if (@AC_Method = 'G' or isnull(@AC_Method,'') = '') and @CouponRoundingType = 'T'
   begin
      select @AccruedInterestPercent   = convert(numeric(28,0), floor(@AddInterestPercent + @CouponRate * @YF * power(10, @CouponRoundingConv))) / power(10, @CouponRoundingConv)
      select @AccruedInterestAmount    = round(@Quantity * @CurrentNominal * @AccruedInterestPercent / 100, @Amount_NoDecimal)
   end

   -- Unit coupon
   else if @AC_Method = 'C' and @CouponRoundingType = 'R'
   begin
      -- сначала расчет на одну бумагу
      select @AccruedInterestAmount    = round(@AddInterestAmount + @CurrentNominal * @CouponRate / 100 * @YF, @Amount_NoDecimal)
      select @AccruedInterestPercent   = round(100 * @AccruedInterestAmount / @CurrentNominal, @CouponRoundingConv)
      -- расчет суммы НКД для @Quantity бумаг
      select @AccruedInterestAmount    = @Quantity * @AccruedInterestAmount
   end

   else if @AC_Method = 'C' and @CouponRoundingType = 'T'
   begin
      -- сначала расчет на одну бумагу
      select @AccruedInterestAmount    = round(@AddInterestAmount + @CurrentNominal * @CouponRate/100 * @YF, @Amount_NoDecimal)
      select @AccruedInterestPercent   = convert(numeric(28,0), floor(100 * @AccruedInterestAmount / @CurrentNominal * power(10, @CouponRoundingConv))) / power(10, @CouponRoundingConv)
      -- расчет суммы НКД для @Quantity бумаг
      select @AccruedInterestAmount    = @Quantity * @AccruedInterestAmount
   end

   -- Unit percentage
   else if @AC_Method = 'P' and @CouponRoundingType = 'R'
   begin
      select @AccruedInterestPercent   = round(@AddInterestPercent + @CouponCashFlow / @CurrentNominal * @Days / @DaysCoupon * 100, @CouponRoundingConv)
      select @AccruedInterestAmount    = round(@Quantity * @AccruedInterestPercent / 100 * @CurrentNominal, @Amount_NoDecimal)
   end

   else if @AC_Method = 'P' and @CouponRoundingType = 'T'
   begin
      select @AccruedInterestPercent   = convert(numeric(28,0), floor(@AddInterestPercent + @CouponCashFlow / @CurrentNominal * @Days / @DaysCoupon * power(10, @CouponRoundingConv) * 100)) / power(10, @CouponRoundingConv)
      select @AccruedInterestAmount    = round(@Quantity * @AccruedInterestPercent / 100 * @CurrentNominal, @Amount_NoDecimal)
   end

   -- Russian goverment bonds
   else if @AC_Method = 'M' and @CouponRoundingType = 'R'
   begin
      -- сначала расчет на одну бумагу
      select @AccruedInterestAmount    = round(@AddInterestAmount + @CouponCashFlow * @Days / @DaysCoupon, @Amount_NoDecimal)
      select @AccruedInterestPercent   = round(@AccruedInterestAmount / @CurrentNominal * 100, @CouponRoundingConv)
      -- расчет суммы НКД для @Quantity бумаг
      select @AccruedInterestAmount    = @Quantity * @AccruedInterestAmount
   end

   else if @AC_Method = 'M' and @CouponRoundingType = 'T'
   begin
      -- сначала расчет на одну бумагу
      select @AccruedInterestAmount    = round(@AddInterestAmount + @CouponCashFlow * @Days / @DaysCoupon, @Amount_NoDecimal)
      select @AccruedInterestPercent   = convert(numeric(28,0), floor(@AccruedInterestAmount / @CurrentNominal * 100 * power(10, @CouponRoundingConv))) / power(10, @CouponRoundingConv)
      -- расчет суммы НКД для @Quantity бумаг
      select @AccruedInterestAmount    = @Quantity * @AccruedInterestAmount
   end

   -- если в кастомном окне указан метод '*'
   else
   begin
      -- вызываем для расчетов KFS
      exec Radius_Bonds_CalcAccrued @Bonds_Id, null, @CalcDate, @CalcDate, @OutValue output

      select @AccruedInterestPercent   = @AddInterestPercent + convert(numeric(28,10), @OutValue)
      select @AccruedInterestAmount    = round(@Quantity * @AccruedInterestPercent / 100 * @CurrentNominal, @Amount_NoDecimal)
   end

   set arithabort numeric_truncation on
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_AssetsQuotes_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_AssetsQuotes_Get
GO

create procedure Radius_Lib_AssetsQuotes_Get
as
begin
   declare
      @CurDate            datetime

   select @CurDate = convert(datetime,convert(char(8),getdate(),112),112)



   -- Equities RT
   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.PriceBid,
      PriceAsk = e.PriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.Equities e
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          = @CurDate
      and a.AssetsType    = 'EQU'
      and e.Equities_Id   = a.Assets_Id
      and not exists(select 1
                  from
                     kplus.dbo.EquitiesQuotesT e2 (index EquitiesQuotesTIdx1)
                  where 1=1
                     and e2.Equities_Id  = e.Equities_Id
                     and e2.QuoteType    = a.QuoteType
                     and e2.PriceDate    = @CurDate
                  )

   -- RT for Fixing
   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.PriceBid,
      PriceAsk = e.PriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.EquitiesQuotesT e (index EquitiesQuotesTIdx1)
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          = @CurDate
      and a.AssetsType    = 'EQU'
      and a.QuoteType     in ('F','R')
      and e.Equities_Id   = a.Assets_Id
      and e.QuoteType     = a.QuoteType
      and e.PriceDate     = @CurDate

   -- Equities Hist Quotes
   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.PriceBid,
      PriceAsk = e.PriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.EquitiesQuotesT e (index EquitiesQuotesTIdx1)
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          < @CurDate
      and a.AssetsType    = 'EQU'
      and e.Equities_Id   = a.Assets_Id
      and e.QuoteType     = a.QuoteType
      and e.PriceDate     = ( select max(e2.PriceDate)
                        from kplus.dbo.EquitiesQuotesT e2 (index EquitiesQuotesTIdx1)
                        where 1=1
                           and e2.Equities_Id  = e.Equities_Id
                           and e2.QuoteType    = e.QuoteType
                           and e2.PriceDate    <= a.Date)
   -- end of Equities

   -- Bonds RealTime
   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.MarketPriceBid,
      PriceAsk = e.MarketPriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.BondsRTT e
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          = @CurDate
      and a.AssetsType    = 'BON'
      and e.Bonds_Id      = a.Assets_Id
      and not exists(select 1
                  from
                     kplus.dbo.BondsQuotesT b (index BondsQuotesTIdx1)
                  where 1=1
                     and b.Bonds_Id      = e.Bonds_Id
                     and b.QuoteType     = a.QuoteType
                     and b.PriceDate     = @CurDate
                  )

   -- RT for Fixing
   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.MarketPriceBid,
      PriceAsk = e.MarketPriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.BondsQuotesT e (index BondsQuotesTIdx1)
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          = @CurDate
      and a.AssetsType    = 'BON'
      and a.QuoteType     in ('F','R')
      and e.Bonds_Id      = a.Assets_Id
      and e.QuoteType     = a.QuoteType
      and e.PriceDate     = @CurDate

   -- Bonds Hist Quotes
   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.MarketPriceBid,
      PriceAsk = e.MarketPriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.BondsQuotesT e (index BondsQuotesTIdx1)
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          < @CurDate
      and a.AssetsType    = 'BON'
      and e.Bonds_Id      = a.Assets_Id
      and e.QuoteType     = a.QuoteType
      and e.PriceDate     = ( select max(e2.PriceDate)
                        from kplus.dbo.BondsQuotesT e2 (index BondsQuotesTIdx1)
                        where 1=1
                           and e2.Bonds_Id     = e.Bonds_Id
                           and e2.QuoteType    = e.QuoteType
                           and e2.PriceDate    <= a.Date)
   -- end of Bonds

   -- Futures
   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.MarketPriceBid,
      PriceAsk = e.MarketPriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.FuturesMaturities e
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          = @CurDate
      and a.AssetsType    = 'FUT'
      and e.FuturesMaturities_Id = a.Assets_Id
      and not exists(select 1
                  from
                     kplus.dbo.FuturesQuotesT f (index FuturesQuotesTIdx1)
                  where 1=1
                     and f.FuturesMaturities_Id  = e.FuturesMaturities_Id
                     and f.QuoteType             = a.QuoteType
                     and f.PriceDate             = @CurDate
                  )
   -- RT for Fixing
   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.PriceBid,
      PriceAsk = e.PriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.FuturesQuotesT e (index FuturesQuotesTIdx1)
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          = @CurDate
      and a.AssetsType    = 'FUT'
      and a.QuoteType     in ('F','R')
      and e.FuturesMaturities_Id = a.Assets_Id
      and e.QuoteType     = a.QuoteType
      and e.PriceDate     = @CurDate

   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.PriceBid,
      PriceAsk = e.PriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.FuturesQuotesT e (index FuturesQuotesTIdx1)
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          < @CurDate
      and a.AssetsType    = 'FUT'
      and e.FuturesMaturities_Id = a.Assets_Id
      and e.QuoteType     = a.QuoteType
      and e.PriceDate     = ( select max(e2.PriceDate)
                        from kplus.dbo.FuturesQuotesT e2 (index FuturesQuotesTIdx1)
                        where 1=1
                           and e2.FuturesMaturities_Id = e.FuturesMaturities_Id
                           and e2.QuoteType    = e.QuoteType
                           and e2.PriceDate    <= a.Date)
   -- end of Futures

   -- Options
   update Radius_Lib_AssetsQuotes
   set
      PriceBid = ov.MarketPriceBid,
      PriceAsk = ov.MarketPriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.OptionsValues ov
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          = @CurDate
      and a.AssetsType    = 'OPT'
      and ov.OptionsValues_Id = a.Assets_Id
      and not exists (select 1
                  from kplus.dbo.OptionsQuotesT q (index OptionsQuotesTIdx1)
                  where 1=1
                     and q.OptionsValues_Id  = ov.OptionsValues_Id
                     and q.QuoteType         = a.QuoteType
                     and q.PriceDate         = @CurDate
                  )

   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.PriceBid,
      PriceAsk = e.PriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.OptionsQuotesT e (index OptionsQuotesTIdx1)
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          = @CurDate
      and a.AssetsType    = 'OPT'
      and a.QuoteType     in ('F','R')
      and e.OptionsValues_Id = a.Assets_Id
      and e.QuoteType     = a.QuoteType
      and e.PriceDate     = @CurDate

   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.PriceBid,
      PriceAsk = e.PriceAsk
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.OptionsQuotesT e (index OptionsQuotesTIdx1)
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          < @CurDate
      and a.AssetsType    = 'OPT'
      and e.OptionsValues_Id = a.Assets_Id
      and e.QuoteType     = a.QuoteType
      and e.PriceDate     = ( select max(e2.PriceDate)
                        from kplus.dbo.OptionsQuotesT e2 (index OptionsQuotesTIdx1)
                        where 1=1
                           and e2.OptionsValues_Id = e.OptionsValues_Id
                           and e2.QuoteType    = e.QuoteType
                           and e2.PriceDate    <= a.Date)
   -- Options end

   -- OTC Options
   update Radius_Lib_AssetsQuotes
   set
      PriceBid    = e.SpotPrice,  --Middle по цене базового актива
      PriceAsk    = e.SpotPrice,
      TheoPrice   = e.TheoPrice,
      Delta       = e.Delta,
      Gamma       = e.Gamma,
      Theta       = e.Theta,
      Vega        = e.Vega,
      Rho         = e.Rho
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      Kustom..RadiusAssetsGreeks e
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          = @CurDate
      and a.AssetsType    = 'AGR'
      and e.Assets_Id     = a.Assets_Id

   update Radius_Lib_AssetsQuotes
   set
      PriceBid    = e.SpotPrice,
      PriceAsk    = e.SpotPrice,
      TheoPrice   = e.TheoPrice,
      Delta       = e.Delta,
      Gamma       = e.Gamma,
      Theta       = e.Theta,
      Vega        = e.Vega,
      Rho         = e.Rho
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      Kustom..RadiusAssetsGreeksHist e
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          < @CurDate
      and a.AssetsType    = 'AGR'
      and e.Assets_Id     = a.Assets_Id
      and e.PriceDate     = ( select max(hh.PriceDate)
                        from RadiusAssetsGreeksHist hh
                        where 1=1
                           and hh.Assets_Id = e.Assets_Id
                           and hh.PriceDate <= a.Date
                       )
   --end of OTC Option

   -- BasketIndexes RT
   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.MarketPrice,
      PriceAsk = e.MarketPrice
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.BasketIndexes e
   where 1=1
      and a.SPID          = @@SPID
      and a.Date          = @CurDate
      and a.AssetsType    = 'IND'
      and e.BasketIndexes_Id   = a.Assets_Id
      and not exists(select 1
                  from
                     kplus.dbo.BasketIndexesQuotesT e2 (index BasketIndexesQuotesTIdx1)
                  where 1=1
                     and e2.BasketIndexes_Id  = e.BasketIndexes_Id
                     and e2.PriceDate    = @CurDate
                  )

   -- RT for Fixing
   update Radius_Lib_AssetsQuotes
   set
      PriceBid = e.Price,
      PriceAsk = e.Price
   from
      Kustom..Radius_Lib_AssetsQuotes a,
      kplus.dbo.BasketIndexesQuotesT e (index BasketIndexesQuotesTIdx1)
   where 1=1
      and a.SPID          = @@SPID
      and a.AssetsType    = 'IND'
      and e.BasketIndexes_Id   = a.Assets_Id
      and e.PriceDate     = ( select max(e2.PriceDate)
                        from kplus.dbo.BasketIndexesQuotesT e2 (index BasketIndexesQuotesTIdx1)
                        where 1=1
                           and e2.BasketIndexes_Id  = e.BasketIndexes_Id
                           and e2.PriceDate    <= a.Date)

END --end of proc

GO

IF OBJECT_ID ('dbo.Radius_Lib_AddDays_Get') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_AddDays_Get
GO

create procedure Radius_Lib_AddDays_Get
(
   -- для работы через параметры необходимо заполнить хотя бы один из следующих 4 параметров
   -- параметр Cities_Id имеет приоритет перед параметром Currencies_Id (Currencies_Id не будет учитываться, если заполнен соответствующий параметр Cities_Id)
   -- если все 4-е параметра не заданы - процедура работает с интерфейсной таблицей Radius_Lib_AddDays
   @Currencies_Id1   int = null,
   @Currencies_Id2   int = null,
   @Cities_Id1       int = null,
   @Cities_Id2       int = null,
   -- для работы через параметры необходимо заполнить два следующих параметра
   @DateIn           datetime = null,        -- DateIn
   @DaysToAdd        int = null,             -- days to add
   -- необязательный параметр
   @DaysType         char(1) = 'B',          -- 'B' - business (by default), 'C' calendar
   -- выходной параметр
   @DateOut          datetime = null output  -- DateOut
)
as
begin

   -- если передан хотя бы один из первых 4 параметров
   if coalesce(@Currencies_Id1, @Currencies_Id2, @Cities_Id1, @Cities_Id2, 0) <> 0
      and @DateIn is not null and @DaysToAdd is not null
   begin

      --ищем город 1,2 если его нет
      select
         @Cities_Id1 = isnull(@Cities_Id1, (select Cities_Id from kplus..CurrenciesDefT с where с.Currencies_Id = @Currencies_Id1)),
         @Cities_Id2 = isnull(@Cities_Id2, (select Cities_Id from kplus..CurrenciesDefT с where с.Currencies_Id = @Currencies_Id2))

      exec Radius_Lib_AddDays_Cities @Cities_Id1, @Cities_Id2, @DateIn, @DaysToAdd, @DaysType, @DateOut out

   end
   else --работаем по таблице
   begin

      --сначала сдвинем все даты, для которых указан сдвиг на календарные дни, а потом все что осталось сдвинем на рабочие дни,
      update Radius_Lib_AddDays set
         DateOut     = dateadd(dd, DaysToAdd, DateIn),
         Remainder   = 0
      where SPID        = @@SPID
         and DaysType   = 'C'

      --подготовимся к сдвигу на рабочие дни, заполнив число дней, которые необходимо добавить, заполним Cities_Id, там где они не заполнены.
      update Radius_Lib_AddDays set
         DateOut     = DateIn,
         Date1       = DateIn,
         Date2       = DateIn,
         Remainder   = DaysToAdd,
         Remainder1  = DaysToAdd,
         Remainder2  = DaysToAdd,
         Cities_Id_1 = isnull(Cities_Id_1, (select Cities_Id from kplus..CurrenciesDefT с where с.Currencies_Id  = Radius_Lib_AddDays.Currencies_Id_1)),
         Cities_Id_2 = isnull(Cities_Id_2, (select Cities_Id from kplus..CurrenciesDefT с where с.Currencies_Id  = Radius_Lib_AddDays.Currencies_Id_2))
      where SPID        = @@SPID
         and DaysType   = 'B'

      -- если задан сдвиг на 0 дней, но переданный день - праздничный, то нужно сдвинуться на следующий рабочий
      -- для этого добавим 1 рабочий день к Remainder
      update Radius_Lib_AddDays set
         Remainder1  =
            case
               when
                  (
                     exists
                        (
                           select 1 from kplus..WeekHolidays w
                           where w.Cities_Id in (d.Cities_Id_1) and DayOfWeek = datepart(dw, d.DateOut) - 1
                        )
                     or
                     exists
                        (
                           select 1 from kplus..FixedHolidays f
                           where f.Cities_Id in (d.Cities_Id_1) and day(f.HolidayDate) = day(d.DateOut)
                              and month(f.HolidayDate) = month(d.DateOut)
                        )
                     or
                     exists
                        (
                           select 1 from kplus..VariableHolidays v
                           where v.Cities_Id in (d.Cities_Id_1) and datediff(dy, v.HolidayDate, d.DateOut) = 0
                        )
                  )
               then 1
               else 0
            end,
         Remainder2  =
            case
               when
                  (
                     exists
                        (
                           select 1 from kplus..WeekHolidays w
                           where w.Cities_Id in (d.Cities_Id_2) and DayOfWeek = datepart(dw, d.DateOut) - 1
                        )
                     or
                     exists
                        (
                           select 1 from kplus..FixedHolidays f
                           where f.Cities_Id in (d.Cities_Id_2) and day(f.HolidayDate) = day(d.DateOut)
                              and month(f.HolidayDate) = month(d.DateOut)
                        )
                     or
                     exists
                        (
                           select 1 from kplus..VariableHolidays v
                           where v.Cities_Id in (d.Cities_Id_2) and datediff(dy, v.HolidayDate, d.DateOut) = 0
                        )
                  )
               then 1
               else 0
            end
      from Radius_Lib_AddDays d
      where SPID        = @@SPID
         and Remainder  = 0
         and DaysType   = 'B'

      -- если есть записи, которые надо сдвинуть на рабочие дни
      while exists
               (
                  select 1 from Radius_Lib_AddDays r
                  where r.SPID      = @@SPID
                     and DaysType   = 'B'
                     and
                     (
                        Remainder1  <> 0
                        or
                        Remainder2  <> 0
                     )
                     and not (isnull(Cities_Id_1, 0) = 0 and isnull(Cities_Id_2, 0) = 0)
               )
      begin
         -- сдвигаем дату на Remainder календарных дней,
         -- считаем количество попавших в этот отрезок праздничных дней и записываем их количество в Remainder
         -- для каждого календаря вычисления производятся раздельно (Date1, Remainder1, Date2, Remainder2)

         -- сначала для положительных значений Remainder (полуинтервал (DateOut, DateOut + Remainder])
         update Radius_Lib_AddDays set
            Date1       = dateadd(dd, Remainder1, Date1),
            Date2       = dateadd(dd, Remainder2, Date2),
            Remainder1  =
               case
                  when Remainder1 > 0 then
                     (
                        select
                           count(*)
                        from Radius_Lib_Calendar c
                        where c.Date   > d.Date1
                           and c.Date  <= dateadd(dd, d.Remainder1, d.Date1)
                           and
                              (
                                 exists
                                    (
                                       select 1 from kplus..WeekHolidays w
                                       where w.Cities_Id in (d.Cities_Id_1) and DayOfWeek = datepart(dw, c.Date) - 1
                                    )
                                 or
                                 exists
                                    (
                                       select 1 from kplus..FixedHolidays f
                                       where f.Cities_Id in (d.Cities_Id_1) and day(f.HolidayDate) = day(c.Date)
                                          and month(f.HolidayDate) = month(c.Date)
                                    )
                                 or
                                 exists
                                    (
                                       select 1 from kplus..VariableHolidays v
                                       where v.Cities_Id in (d.Cities_Id_1) and datediff(dy, v.HolidayDate, c.Date) = 0
                                    )
                              )
                     )
                  else Remainder1
               end,
            Remainder2  =
               case
                  when Remainder2 > 0 then
                     (
                        select
                           count(*)
                        from Radius_Lib_Calendar c
                        where c.Date   > d.Date2
                           and c.Date  <= dateadd(dd, d.Remainder2, d.Date2)
                           and
                              (
                                 exists
                                    (
                                       select 1 from kplus..WeekHolidays w
                                       where w.Cities_Id in (d.Cities_Id_2) and DayOfWeek = datepart(dw, c.Date) - 1
                                    )
                                 or
                                 exists
                                    (
                                       select 1 from kplus..FixedHolidays f
                                       where f.Cities_Id in (d.Cities_Id_2) and day(f.HolidayDate) = day(c.Date)
                                          and month(f.HolidayDate) = month(c.Date)
                                    )
                                 or
                                 exists
                                    (
                                       select 1 from kplus..VariableHolidays v
                                       where v.Cities_Id in (d.Cities_Id_2) and datediff(dy, v.HolidayDate, c.Date) = 0
                                    )
                              )
                     )
                  else Remainder2
               end
         from Radius_Lib_AddDays d
         where SPID        = @@SPID
            and DaysType   = 'B'
            and
            (
               Remainder1  > 0
               or
               Remainder2  > 0
            )

         -- потом для отрицательных значений Remainder (-> )полуинтервал [DateOut + Remainder, DateOut))
         update Radius_Lib_AddDays set
            Date1       = dateadd(dd, Remainder1, Date1),
            Date2       = dateadd(dd, Remainder2, Date2),
            Remainder1  =
               case
                  when Remainder1 < 0 then
                     (
                        select
                           - count(*)
                        from Radius_Lib_Calendar c
                        where c.Date   < d.Date1
                           and c.Date  >= dateadd(dd, d.Remainder1, d.Date1)
                           and
                              (
                                 exists
                                    (
                                       select 1 from kplus..WeekHolidays w
                                       where w.Cities_Id in (d.Cities_Id_1) and DayOfWeek = datepart(dw, c.Date) - 1
                                    )
                                 or
                                 exists
                                    (
                                       select 1 from kplus..FixedHolidays f
                                       where f.Cities_Id in (d.Cities_Id_1) and day(f.HolidayDate) = day(c.Date)
                                          and month(f.HolidayDate) = month(c.Date)
                                    )
                                 or
                                 exists
                                    (
                                       select 1 from kplus..VariableHolidays v
                                       where v.Cities_Id in (d.Cities_Id_1) and datediff(dy, v.HolidayDate, c.Date) = 0
                                    )
                              )
                     )
                  else Remainder1
               end,
            Remainder2  =
               case
                  when Remainder2 < 0 then
                     (
                        select
                           - count(*)
                        from Radius_Lib_Calendar c
                        where c.Date   < d.Date2
                           and c.Date  >= dateadd(dd, d.Remainder2, d.Date2)
                           and
                              (
                                 exists
                                    (
                                       select 1 from kplus..WeekHolidays w
                                       where w.Cities_Id in (d.Cities_Id_2) and DayOfWeek = datepart(dw, c.Date) - 1
                                    )
                                 or
                                 exists
                                    (
                                       select 1 from kplus..FixedHolidays f
                                       where f.Cities_Id in (d.Cities_Id_2) and day(f.HolidayDate) = day(c.Date)
                                          and month(f.HolidayDate) = month(c.Date)
                                    )
                                 or
                                 exists
                                    (
                                       select 1 from kplus..VariableHolidays v
                                       where v.Cities_Id in (d.Cities_Id_2) and datediff(dy, v.HolidayDate, c.Date) = 0
                                    )
                              )
                     )
                  else Remainder2
               end
         from Radius_Lib_AddDays d
         where SPID        = @@SPID
            and DaysType   = 'B'
            and
            (
               Remainder1  < 0
               or
               Remainder2  < 0
            )

      end

      -- заполняем значение DateOut одним из значений Date1 или Date2 в зависимости от направления сдвига
      update Radius_Lib_AddDays set
         DateOut     =
            case
               when DaysToAdd < 0 then
                  case -- присваиваем минимальную
                     when Date1 < Date2 then Date1
                     else Date2
                  end
               else
                  case -- присваиваем максимальную
                     when Date1 > Date2 then Date1
                     else Date2
                  end
            end,
         Remainder   = 0
      where SPID        = @@SPID
         and DaysType   = 'B'

      -- если дата DateOut является выходным для одного из календарей изменяем значение Remainder для продолжения вычислений
      update Radius_Lib_AddDays set
          Remainder = case when DaysToAdd < 0 then -1 else 1 end
      from Radius_Lib_AddDays d
      where SPID        = @@SPID
         and DaysType   = 'B'
         and
         (
            exists
               ( select 1 from kplus..WeekHolidays w
                 where w.Cities_Id in (d.Cities_Id_1, d.Cities_Id_2) and DayOfWeek = datepart(dw, d.DateOut) - 1
               )
            or
            exists
               (
                  select 1 from kplus..FixedHolidays f
                  where f.Cities_Id in (d.Cities_Id_1, d.Cities_Id_2) and day(f.HolidayDate) = day(d.DateOut)
                     and month(f.HolidayDate) = month(d.DateOut)
               )
            or
            exists
               (
                  select 1 from kplus..VariableHolidays v
                  where v.Cities_Id in (d.Cities_Id_1, d.Cities_Id_2) and datediff(dy, v.HolidayDate, d.DateOut) = 0
               )
         )

      -- ищем ближайшую рабочую дату (для обоих календарей) в зависимости от направления сдвига
      while exists
               (
                  select 1 from Radius_Lib_AddDays r
                  where r.SPID      = @@SPID
                     and DaysType   = 'B'
                     and Remainder  <> 0
                     and not (isnull(Cities_Id_1,0) = 0 and isnull(Cities_Id_2,0) = 0)
               )
      begin

         -- изменяем значение DateOut, а в Remainder пишем является ли новое значение DateOut выходным (+1, -1 - является; 0 - не является)
         update Radius_Lib_AddDays set
            DateOut     = dateadd(dd, d.Remainder, d.DateOut),
            Remainder   =
               (case when d.DaysToAdd < 0 then -1 else 1 end)  -- учет направления сдвига
               *
               (
                  select
                     count(*)                                  -- возможные значения: 0, 1
                  from Radius_Lib_Calendar c
                  where c.Date = dateadd(dd, d.Remainder, d.DateOut)
                     and
                     (
                        exists
                           (
                              select 1 from kplus..WeekHolidays w
                              where w.Cities_Id in (d.Cities_Id_1, d.Cities_Id_2) and DayOfWeek = datepart(dw, c.Date) - 1
                           )
                        or
                        exists
                           (
                              select 1 from kplus..FixedHolidays f
                              where f.Cities_Id in (d.Cities_Id_1, d.Cities_Id_2) and day(f.HolidayDate) = day(c.Date)
                                 and month(f.HolidayDate) = month(c.Date)
                           )
                        or
                        exists
                           (
                              select 1 from kplus..VariableHolidays v
                              where v.Cities_Id in (d.Cities_Id_1, d.Cities_Id_2) and datediff(dy, v.HolidayDate, c.Date) = 0
                           )
                      )
               )
         from Radius_Lib_AddDays d
         where SPID        = @@SPID
            and DaysType   = 'B'
            and Remainder  <> 0

      end

   end
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_AddDays_Currencies') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_AddDays_Currencies
GO

create procedure Radius_Lib_AddDays_Currencies
(
   @Currencies_Id1   int,
   @Currencies_Id2   int,
   @DateIn           datetime,         -- DateIn
   @DaysToAdd        int,              -- days to add
   @DaysType         char(1) = 'B',    -- 'B' - business (by default), 'C' calendar
   @DateOut          datetime output   -- DateOut
)
as
declare
   @Cities_Id1       int,
   @Cities_Id2       int
begin

   select
      @Cities_Id1 = isnull(@Cities_Id1, (select Cities_Id from kplus..CurrenciesDefT с where с.Currencies_Id = @Currencies_Id1)),
      @Cities_Id2 = isnull(@Cities_Id2, (select Cities_Id from kplus..CurrenciesDefT с where с.Currencies_Id = @Currencies_Id2))

   exec Radius_Lib_AddDays_Cities @Cities_Id1, @Cities_Id2, @DateIn, @DaysToAdd, @DaysType, @DateOut out

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_AddDays_City') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_AddDays_City
GO

create procedure Radius_Lib_AddDays_City
/*
   Adds business or calendar days to input date
   Always returns business day
*/
(
   @Cities_Id  int,
   @DateIn     datetime,         -- DateIn
   @DaysToAdd  int,              -- days to add
   @DaysType   char(1) = 'B',    -- 'B' - business (by default), 'C' calendar
   @DateOut    datetime output   -- DateOut
)
as
declare
   @Remainder  int               -- остаток дней, на который еще надо сдвинуть дату DateOut
begin

   -- если сдвиг на календарные дни
   if @DaysType = 'C'
   begin
      select @DateOut = dateadd(dd, @DaysToAdd, @DateIn)
      return
   end

   -- надо прибавить рабочие дни (всегда возвращаем рабочий день, даже если необходимо добавить ноль дней)
   select
      @DateOut    = @DateIn,
      @Remainder  = @DaysToAdd

   -- если нужно было добавить ноль дней и @DateIn выходной, будем прибавлять 1 рабочий день
   select
      @Remainder = 1
   where @DaysToAdd = 0
      and
      (
         exists
            (
               select 1 from kplus..WeekHolidays w
               where w.Cities_Id in (@Cities_Id) and DayOfWeek = datepart(dw, @DateIn) - 1
            )
         or
         exists
            (
               select 1 from kplus..FixedHolidays f
               where f.Cities_Id in (@Cities_Id) and day(f.HolidayDate) = day(@DateIn)
                  and month(f.HolidayDate) = month(@DateIn)
            )
         or
         exists
            (
               select 1 from kplus..VariableHolidays v
               where v.Cities_Id in (@Cities_Id) and datediff(dy, v.HolidayDate, @DateIn) = 0
            )
      )

   -- будем прибавлять календарные дни, пока @Remainder > 0
   -- в 1 итерации @Remainder - это кол-во бизнес-дней, которые необходимо добавить
   -- в последующих итерациях это кол-во выходных, попавших в период [@DateOut2 = @DateOut1 + @Remainder1, @DateOut2 + @Remainder2]
   while @Remainder > 0
   begin
      select
         @DateOut   = dateadd(dd, @Remainder, @DateOut),
         @Remainder = count(*)
      from Kustom..Radius_Lib_Calendar c
      where c.Date  > @DateOut
         and c.Date <= dateadd(dd, @Remainder, @DateOut)
         and
         (
            exists
               (
                  select 1 from kplus..WeekHolidays w
                  where w.Cities_Id in (@Cities_Id) and DayOfWeek = datepart(dw, c.Date) - 1
               )
            or
            exists
               (
                  select 1 from kplus..FixedHolidays f
                  where f.Cities_Id in (@Cities_Id) and day(f.HolidayDate) = day(c.Date)
                     and month(f.HolidayDate) = month(c.Date)
               )
            or
            exists
               (
                  select 1 from kplus..VariableHolidays v
                  where v.Cities_Id in (@Cities_Id) and datediff(dy, v.HolidayDate, c.Date) = 0
               )
         )
   end

   -- будем вычитать календарные дни, пока @Remainder < 0
   -- в 1 итерации @Remainder - это кол-во бизнес-дней, которые необходимо вычесть
   -- в последующих итерациях это кол-во выходных, попавших в период [@DateOut2 - @Remainder2, @DateOut2 = @DateOut1 - @Remainder1]
   while @Remainder < 0
   begin
      select
         @DateOut   = dateadd(dd, @Remainder, @DateOut),
         @Remainder = - count(*)
      from Kustom..Radius_Lib_Calendar c
      where c.Date  < @DateOut
         and c.Date >= dateadd(dd, @Remainder, @DateOut)
         and
         (
            exists
               (
                  select 1 from kplus..WeekHolidays w
                  where w.Cities_Id in (@Cities_Id) and DayOfWeek = datepart(dw, c.Date) - 1
               )
            or
            exists
               (
                  select 1 from kplus..FixedHolidays f
                  where f.Cities_Id in (@Cities_Id) and day(f.HolidayDate) = day(c.Date)
                     and month(f.HolidayDate) = month(c.Date)
               )
            or
            exists
               (
                  select 1 from kplus..VariableHolidays v
                  where v.Cities_Id in (@Cities_Id) and datediff(dy, v.HolidayDate, c.Date) = 0
               )
         )
   end

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_AddDays_Cities3') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_AddDays_Cities3
GO

create procedure Radius_Lib_AddDays_Cities3
/*
   Adds business days to input date for a pair of cities
   and check the result date by a third city
   Always returns business day
*/
(
   @Cities_Id1 int,
   @Cities_Id2 int,
   @Cities_Id3 int,              -- получив результат по @Cities_Id1,2 проверим, что он не является праздником по @Cities_Id3
   @DateIn     datetime,         -- DateIn
   @DaysToAdd  int,              -- days to add
   @DateOut    datetime output   -- DateOut
)
as
declare
   @DateMinMax datetime,
   @Direction  int,
   @IsHoliday  int
begin

   -- необходимо, чтобы по 1-му и 2-му городу прошло необходимое количество рабочих дней
   exec Radius_Lib_AddDays_Cities @Cities_Id1, @Cities_Id2, @DateIn, @DaysToAdd, 'B', @DateOut out

   -- получаем дальнейшее направление поиска
   select
      @DaysToAdd =
         case
            when @DaysToAdd >= 0 then 1
            else -1
         end

   -- ищем первый общий рабочий день для всех 3-х городов в зависимости от направления поиска
   -- получаем информацию о том, является ли дата @DateOut рабочим днем для 3-го города
   exec Radius_Lib_IsHoliday_City @Cities_Id3, @DateOut, @IsHoliday out

   -- если для 3-го города дата @DateOut выходной, то ищем дальше
   while @IsHoliday > 0
   begin

      -- к дате @DateOut прибавляем 1/-1 бизнес-дней по 2-м городам
      exec Radius_Lib_AddDays_Cities @Cities_Id1, @Cities_Id2, @DateOut, @DaysToAdd, 'B', @DateOut out

      -- получаем информацию о том, является ли дата @DateOut рабочим днем для 3-го города
      exec Radius_Lib_IsHoliday_City @Cities_Id3, @DateOut, @IsHoliday out

   end

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_AddDays_Cities') IS NOT NULL
   DROP PROCEDURE dbo.Radius_Lib_AddDays_Cities
GO

create procedure Radius_Lib_AddDays_Cities
/*
   Adds business or calendar days to input date for a pair of cities
   Always returns business day
*/
(
   @Cities_Id1 int,
   @Cities_Id2 int,
   @DateIn     datetime,         -- DateIn
   @DaysToAdd  int,              -- days to add
   @DaysType   char(1) = 'B',    -- 'B' - business (by default), 'C' calendar
   @DateOut    datetime output   -- DateOut
)
as
declare
   @Date1      datetime,  -- @DateOut1 для @Cities_Id1
   @Date2      datetime,  -- @DateOut2 для @Cities_Id2
   @Direction  int,       -- направление поиска
   @IsHoliday  int        -- признак выходного дня
begin

   -- если сдвиг на календарные дни
   if @DaysType = 'C'
   begin
      select @DateOut = dateadd(dd, @DaysToAdd, @DateIn)
      return
   end

   -- необходимо, чтобы по каждому из городов прошло необходимое количество рабочих дней
   exec Radius_Lib_AddDays_City @Cities_Id1, @DateIn, @DaysToAdd, @DaysType, @Date1 out
   exec Radius_Lib_AddDays_City @Cities_Id2, @DateIn, @DaysToAdd, @DaysType, @Date2 out

   select
      @Direction = sign(@DaysToAdd)

   -- в зависимости от направления поиска находим общий рабочий день
   while @Date1 <> @Date2
   begin
      -- если Date2 позднее и прибавляем дни или Date2 раньше и вычитаем дни
      if
      (
         @Date1 < @Date2 and @Direction > -1
         or
         @Date1 > @Date2 and @Direction = -1
      )
      begin
         select @Date1 = @Date2

         -- если Date2 для Cities1 выходной, то передвигаем дату на рабочий день в зависимости от направления
         exec Radius_Lib_IsHoliday_City @Cities_Id1, @Date2, @IsHoliday out

         if @IsHoliday > 0
         begin
            exec Radius_Lib_AddDays_City @Cities_Id1, @Date2, @Direction, @DaysType, @Date1 out
         end
      end
      else -- если Date1 позднее и прибавляем дни или Date1 раньше и вычитаем дни
      begin
         select @Date2 = @Date1

         -- если Date1 для Cities2 выходной, то передвигаем дату на рабочий день в зависимости от направления
         exec Radius_Lib_IsHoliday_City @Cities_Id2, @Date1, @IsHoliday out

         if @IsHoliday > 0
         begin
            exec Radius_Lib_AddDays_City @Cities_Id2, @Date1, @Direction, @DaysType, @Date2 out
         end
      end
   end

   select
      @DateOut = @Date1
end

GO

