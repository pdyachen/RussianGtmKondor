/*-------------------------------------------------*/
/*--- Initialization Part -------------------------*/
/*-------------------------------------------------*/

USE kplus
go

/*-------------------------------------------------*/
/*--- Procs export --------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		RUKON_CurHelp
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RUKON_CurHelp' AND type = 'P' 
)
	DROP PROC RUKON_CurHelp 
go


create PROC dbo.RUKON_CurHelp
(
--  @Pid                                   int ,
--  @Trigger                               varchar(32),
  @Deals_Id                              int
--  @DealType                              char(1),
)
as
begin

select
  c.Currencies_ShortName
from kplus..RepoDeals x
  join kplus..Currencies c on c.Currencies_Id=x.Currencies_Id
where x.RepoDeals_Id=@Deals_Id
union
select
  c.Currencies_ShortName
--, x.KdbTables_Id_Underlying
--, rs.Bonds_Id
--, rs.Equities_Id
from kplus..RepoDeals x
  join kplus..RepoSecuSched rs on x.RepoDeals_Id=rs.RepoDeals_Id
  join kplus..KdbTables kdb on kdb.KdbTables_Id=x.KdbTables_Id_Underlying
    and kdb.KdbTables_Name="Bonds"
  join kplus..Bonds u on u.Bonds_Id=rs.Bonds_Id
  join kplus..Currencies c on c.Currencies_Id=u.Currencies_Id
where x.RepoDeals_Id=@Deals_Id
union
select
  c.Currencies_ShortName
--, x.KdbTables_Id_Underlying
--, rs.Bonds_Id
--, rs.Equities_Id
from kplus..RepoDeals x
  join kplus..RepoSecuSched rs on x.RepoDeals_Id=rs.RepoDeals_Id
  join kplus..KdbTables kdb on kdb.KdbTables_Id=x.KdbTables_Id_Underlying
    and kdb.KdbTables_Name="Equities"
  join kplus..Equities u on u.Equities_Id=rs.Equities_Id
  join kplus..Currencies c on c.Currencies_Id=u.Currencies_Id
where x.RepoDeals_Id=@Deals_Id


end

go



GRANT EXEC ON RUKON_CurHelp TO PUBLIC 
go

