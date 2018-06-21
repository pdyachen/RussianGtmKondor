IF OBJECT_ID ('dbo.Radius_Lib_Round') IS NOT NULL
	DROP FUNCTION dbo.Radius_Lib_Round
GO

create function dbo.Radius_Lib_Round
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/*   Rounds Amount by RoundMethod                                                                       */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @Amount           float,
   @Precision        int      = 0,
   @RoundMethod      char(1)  = 'R'    -- R - Round, T - Truncate, N - None
)
returns float
as
begin
    -- если входящая сумма равна 0, то сразу возвращаем 0, не выполняя никаких вычислений
   if @Amount = 0
   begin
      return 0
   end

   -- если выбрано "не округлять", то возвращаем входящую сумму, не выполняя никаких вычислений
   if @RoundMethod = 'N'
   begin
      return @Amount
   end

   declare
      @Power         float,
      @AbsAmount     float,
      @SignAmount    float,
      @Exp           int,
      @Epsilon       float,
      @RoundAmount   float

   -- инициализируем значениями по умолчанию, если передали null
   select
      @Precision     = isnull(@Precision, 0),
      @RoundMethod   = isnull(@RoundMethod, 'R')

   -- для минимизации вычислений вычисляем один раз
   select
      @Power      = power(10e, @Precision),
      @AbsAmount  = abs(@Amount),
      @SignAmount = sign(@Amount)

   -- находим @Epsilon, которое соответствует числу 6 в 17-ом разряде округляемой суммы
   set @Exp       = -17 + log10(@AbsAmount)

   set @Epsilon   = 6 * power(10e, @Exp)

   -- корректируем сумму на величину @Epsilon
   set @AbsAmount = @AbsAmount + @Epsilon

   -- округляем сумму соответствующим методом (используем floor, а не round, для совместимости с C++)
   select
      @RoundAmount =
         case when @RoundMethod = 'T'
            then @SignAmount * floor(@AbsAmount * @Power) / @Power
            else @SignAmount * floor(@AbsAmount * @Power + 0.5) / @Power
         end

   return @RoundAmount
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_Num2Str') IS NOT NULL
	DROP FUNCTION dbo.Radius_Lib_Num2Str
GO

create function dbo.Radius_Lib_Num2Str
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/*   Функция преобразует число в строку с указанными десятичными и разрядными разделителями.            */
/*   Возвращает не более 15 значимых цифр.                                                              */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @Number              float,
   @DecimalSeparator    varchar(1)  = null,
   @ThousandSeparator   varchar(1)  = null,
   @FormatMask          varchar(17) = null   -- задается в формате '0.0..0#..#'; 0 - цифра выводится всегда, # - цифра выводится, если значима
)
returns varchar(400)
as
begin
   
   declare @Result varchar(400)

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
      return @Result
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

   return @Result

end

GO

IF OBJECT_ID ('dbo.Radius_Lib_MaturityToDate') IS NOT NULL
	DROP FUNCTION dbo.Radius_Lib_MaturityToDate
GO

create function dbo.Radius_Lib_MaturityToDate
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/* . Author: Alexander Alexandrov (2015-08-19)                                                          */
/*                                                                                                      */
/*   Функция преобразует строку Maturity в дату.                                                        */
/*   Пример: MAR10 -> 2010-03-01                                                                        */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @Maturity  varchar(5)
)
returns date
as
begin
   return convert
         (
            date,
            right(@Maturity, 2) +
            case left(@Maturity, 3)
               when 'JAN' then '01'
               when 'FEB' then '02'
               when 'MAR' then '03'
               when 'APR' then '04'
               when 'MAY' then '05'
               when 'JUN' then '06'
               when 'JUL' then '07'
               when 'AUG' then '08'
               when 'SEP' then '09'
               when 'OCT' then '10'
               when 'NOV' then '11'
               when 'DEC' then '12'
            end +
            '01',
            12
         )
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_InterpolationCpi') IS NOT NULL
	DROP FUNCTION dbo.Radius_Lib_InterpolationCpi
GO

create function dbo.Radius_Lib_InterpolationCpi
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/*   Находит промежуточное значение CPI с использованием интерполяции                                   */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @CpiValue1           float,   -- значение на дату @CpiDate1
   @CpiValue2           float,   -- значение на дату @CpiDate2
   @CpiDate             date,    -- дата, на которую необходимо получить значение CPI
   @CpiDate1            date,    -- max(CpiDate) <= @CpiDate, для которой есть значение CPI
   @CpiDate2            date,    -- min(CpiDate) > @CpiDate, для которой есть значение CPI
   @InterpolationMethod char(1)  -- метод интерполяции (N - None, L - Linear, O - Logarithmic)
)
returns float
as
begin
   return
      (
         case @InterpolationMethod
            when 'N' then -- None
               @CpiValue1
            when 'L' then -- Linear
               @CpiValue1 + (@CpiValue2 - @CpiValue1) * datediff(dd, @CpiDate1, @CpiDate) / datediff(dd, @CpiDate1, @CpiDate2)
            when 'O' then -- Logarithmic
               exp(log(@CpiValue1) + (log(@CpiValue2) - log(@CpiValue1)) * datediff(dd, @CpiDate1, @CpiDate) / datediff(dd, @CpiDate1, @CpiDate2))
         end
      )
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_DateToMaturity') IS NOT NULL
	DROP FUNCTION dbo.Radius_Lib_DateToMaturity
GO

create function dbo.Radius_Lib_DateToMaturity
/*------------------------------------------------------------------------------------------------------*/
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/*                                                                                                      */
/* . Author: Alexander Alexandrov (2015-08-19)                                                          */
/*                                                                                                      */
/*   Функция преобразует строку дату в Maturity.                                                        */
/*   Пример: 2010-03-XX -> MAR10                                                                        */
/*                                                                                                      */
/*------------------------------------------------------------------------------------------------------*/
(
   @InputDate  date
)
returns varchar(5)
as
begin
   return
      (
         case datepart(mm, @InputDate)
            when 1 then 'JAN'
            when 2 then 'FEB'
            when 3 then 'MAR'
            when 4 then 'APR'
            when 5 then 'MAY'
            when 6 then 'JUN'
            when 7 then 'JUL'
            when 8 then 'AUG'
            when 9 then 'SEP'
            when 10 then 'OCT'
            when 11 then 'NOV'
            when 12 then 'DEC'
         end
      ) + right(convert(varchar, datepart(yy, @InputDate)), 2)
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_DateDiff') IS NOT NULL
	DROP FUNCTION dbo.Radius_Lib_DateDiff
GO

create function dbo.Radius_Lib_DateDiff
/*------------------------------------------------------------------------------------------------------*/
/* Функция вычисляет количество бизнес-дней между двумя датами                                          */
/*                                                                                                      */
/* . Copyright SYSTEMATICA                                                                              */
/* . Author: Evgeny Bugaev                                                                              */
/*------------------------------------------------------------------------------------------------------*/
(
   @DateBeg    datetime,
   @DateEnd    datetime,
   @Cur_Id_1   integer,
   @Cur_Id_2   integer
)
returns integer
as
begin
   declare
      @Days    integer,
      @City_1  integer,
      @City_2  integer,
      @IsWork  char(1)

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

   return @Days
end

GO

IF OBJECT_ID ('dbo.Radius_Lib_Currency_Code_ById') IS NOT NULL
	DROP FUNCTION dbo.Radius_Lib_Currency_Code_ById
GO

create function dbo.Radius_Lib_Currency_Code_ById
/*
   Возвращает либо код валюты, либо строку 'NaN' в случае отсутствия объекта
*/
(
   @Currencies_Id       int = null
)
returns char(3)
as
begin
   declare @Currencies_ShortName char(3)

   select @Currencies_ShortName = Currencies_ShortName
   from kplus.dbo.Currencies
   where Currencies_Id = @Currencies_Id

   return isnull(@Currencies_ShortName,'NaN')
end

GO

