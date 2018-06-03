USE Kustom
go
IF OBJECT_ID('dbo.PYearFractionSimple') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.PYearFractionSimple
    IF OBJECT_ID('dbo.PYearFractionSimple') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.PYearFractionSimple >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.PYearFractionSimple >>>'
END
go
create procedure dbo.PYearFractionSimple
/*
   Процедура УСТАРЕЛА, вместо нее необходимо использовать процедуру Radius_Lib_YearFraction_Get,
   обращая внимание на то, что порядок входных параметров в новой процедуре отличен от порядка в текущей
*/
(
   @StartDate     datetime,
   @EndDate       datetime,
   @Basis         char,
   @Frequency     char = 'A', -- Pour la base ACT/nACT
   @YearFraction  float output,
   @Period        char(1) = 'F',
   @Currencies_Id int = 0,
   @Cities_Id     int = 0
)
as
begin
   select -- в старом коде при вызове часто явным образом передавали null для некоторых параметров, а новая процедура требует not null для данного параметра:
      @Frequency = isnull(@Frequency, 'A'),
      @Period = isnull(@Period, 'F')

   exec Radius_Lib_YearFraction_Get
      @StartDate,
      @EndDate,
      @Basis,
      @Frequency,
      @Period,
      @Currencies_Id,
      @Cities_Id,
      @YearFraction output
end
go
EXEC sp_procxmode 'dbo.PYearFractionSimple', 'unchained'
go
IF OBJECT_ID('dbo.PYearFractionSimple') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.PYearFractionSimple >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.PYearFractionSimple >>>'
go
REVOKE EXECUTE ON dbo.PYearFractionSimple FROM public
go
GRANT EXECUTE ON dbo.PYearFractionSimple TO public
go
