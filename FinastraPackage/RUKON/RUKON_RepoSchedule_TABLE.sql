/*-------------------------------------------------*/
/*--- Initialization Part -------------------------*/
/*-------------------------------------------------*/

USE kplus
go

/*------------------------------------------------- 
		RUKON_RepoSchedule
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RUKON_RepoSchedule' AND type = 'U' 
)
	DROP table RUKON_RepoSchedule 
go


CREATE table RUKON_RepoSchedule
(
RepoDeals_Id                    int             null,
StartDate                       datetime        null,
EndDate                         datetime        null,
PaymentDate                     datetime        null,
CashFlowType                    char(1)         null,
Principal                       float           null,
CashFlow                        float           null,
Rate                            float           null,
Pid                             int             null 
)
LOCK DATAROWS


go

GRANT ALL ON RUKON_RepoSchedule TO PUBLIC 
go

