/*-------------------------------------------------*/
/*--- Initialization Part -------------------------*/
/*-------------------------------------------------*/

USE kplus
go

/*------------------------------------------------- 
		RUKON_Round
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RUKON_Round' AND type = 'P' 
)
	DROP FUNCTION RUKON_Round 
go


create function dbo.RUKON_Round
(
   @Rate      float,
   @Digits    int
)
returns float
as
begin
   if @Rate = 0
   begin
      return 0
   end

   declare
      @Power       float,
      @AbsRate     float,
      @SignRate    float,
      @Exp         int,
      @Prec        float,
      @RoundRate   float

   select
      @Digits     = isnull(@Digits, 0)

   select
      @Power      = power(10e, @Digits),
      @AbsRate  = abs(@Rate),
      @SignRate = sign(@Rate)

   set @Exp       = -17 + log10(@AbsRate)

   set @Prec   = 6 * power(10e, @Exp)

   set @AbsRate = @AbsRate + @Prec

   select @RoundRate = @SignRate * floor(@AbsRate * @Power + 0.5) / @Power

   return @RoundRate
end


go



GRANT EXEC ON RUKON_Round TO PUBLIC 
go

