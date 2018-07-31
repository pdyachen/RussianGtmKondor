/*-------------------------------------------------*/
/*--- Initialization Part -------------------------*/
/*-------------------------------------------------*/

USE kplus
go

/*-------------------------------------------------*/
/*--- Procs export --------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		RUKON_YearFraction
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RUKON_YearFraction' AND type = 'P' 
)
	DROP PROC RUKON_YearFraction 
go


create procedure dbo.RUKON_YearFraction
(
   @StartDate      datetime = null,
   @EndDate        datetime = null,
   @Basis          char(1)  = null,
   @Frequency      char(1)  = 'A', 
   @Period         char(1)  = 'F', 
   @Currencies_Id  int      = null,
   @Cities_Id      int      = null,
   @YearFraction   float    = null output
)
as
begin

   if @Basis is not null
   begin
      -- зачищаем входную таблицу
      delete from Radius_Lib_YearFraction where SPID = @@spid
      -- кладЄм в нее параметры процедуры
      insert into Radius_Lib_YearFraction
         (SPID, StartDate, EndDate, Frequency, Basis, Period, Currencies_Id, Cities_Id)
      values
         (@@spid, @StartDate, @EndDate, @Frequency, @Basis, @Period, @Currencies_Id, @Cities_Id)

      -- и вызываем процедуру еще раз - теперь уже без параметров
      exec RUKON_YearFraction

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
   -- —читаем дл€ базисов M,5,D,F,B,N,C,I,A,R,E,Y,4,Z
   -- дл€ базисов 6,J,2 считаем ниже
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
   -- дл€ базисов 6 (ACT/365 (366)), J (ACT/365 (JPY))
   -- дл€ базиса 2 считаем ниже
   
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
   -- дл€ базиса 2 (BUS/252)
   /*
      BUS/252 Kondor+ uses the BUS/252 day count basis to calculate the year fraction for certain South American
      markets, in particular the Brazilian bond market. This convention uses 252 business days per year as a
      base. Kondor+ calculates the year fraction as follows: YearFraction = Bus_D1_D2/252
      where Bus_D1_D2 is the number of business days between D1 and D2 determined from the holiday calendar

      Ѕазис рассчитываетс€ как YearFraction = Bus_D1_D2 / 252
         Bus_D1_D2 - это количество рабочих дней в периоде (@StartDate; @EndDate - 1) (проценты начисл€ютс€ в конце рабочего дн€)
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

   -- дл€ базиса BUS/252, если переданного города не существует, то YearFraction возвращаем 0
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

go



GRANT EXEC ON RUKON_YearFraction TO PUBLIC 
go

