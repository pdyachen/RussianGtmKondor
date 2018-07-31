/*-------------------------------------------------*/
/*--- Initialization Part -------------------------*/
/*-------------------------------------------------*/

USE kplus
go

/*-------------------------------------------------*/
/*--- Tables export -------------------------------*/
/*-------------------------------------------------*/

/*------------------------------------------------- 
		RUKON_RepoDeals
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RUKON_RepoDeals' AND type = 'U' 
)
	DROP table RUKON_RepoDeals 
go


CREATE table RUKON_RepoDeals
(
DealType                        varchar(32)     not null,
DealId                          int             not null,
RepoType                        varchar(7)      null,
DirtyPrice                      float           null,
AccruedCash                     float           null,
Accrued2                        float           null,
Accrued2Cash                    float           null,
DirtyPrice2                     float           null,
Prepayment                      float           null,
NeedPrepayment                  char(1)         null,
Discount                        float           null,
FixedRate2                      float           null,
ForwardPrice2                   float           null,
FwdPriceMethod                  varchar(14)     null,
GrossAmount2                    float           null,
ForwardAmount2                  float           null,
DeliveryCondition1              varchar(9)      null,
DeliveryCondition2              varchar(9)      null,
AgreementPrepare                varchar(1)      null,
DeliveryActive                  varchar(1)      null,
DeliveryExpensePayer            varchar(1)      null,
SettlementDate                  datetime        null,
SettlementDate2                 datetime        null,
TradingPlace                    varchar(4)      null,
MarginCallTrigger               float           null,
Haircut2                        float           null,
CapturedDiscount                varchar(1)      null,
MarginCallMethod                varchar(1)      null,
MarginCallLower                 float           null,
MarginCallUpper                 float           null,
MarginCallKnockOut              float           null,
ToBeProcessed                   char(1)         null,
WeightedAmount                  float           null,
GrossAmount1                    float           null,
Accrued                         float           null,
CurAccr1                        varchar(3)      null,
CurAccr2                        varchar(3)      null,
CurGA1                          varchar(3)      null,
CurGA2                          varchar(3)      null,
CurWA                           varchar(3)      null,
CurFA                           varchar(3)      null,
Currencies_Id                   int             null,
Cpty_Id                         int             null,
RRPid                           int             null,
RRDFUpd                         varchar(1)      null,
PriceCw                         int             null 
)
LOCK DATAROWS



/*--- INDEXES -------------------------------------*/

CREATE  INDEX RUKON_RepoDealsIdx1 ON RUKON_RepoDeals 
(
	DealType,
	DealId 
)


go

GRANT ALL ON RUKON_RepoDeals TO PUBLIC 
go



USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRUKON_RepoDealsVer' AND type = 'U'
)
	DROP table KustomRUKON_RepoDealsVer 
go


CREATE table KustomRUKON_RepoDealsVer
(
TransactionId                   int             not null,
DealType                        varchar(32)     not null,
DealId                          int             not null,
RepoType                        varchar(7)      null,
DirtyPrice                      float           null,
AccruedCash                     float           null,
Accrued2                        float           null,
Accrued2Cash                    float           null,
DirtyPrice2                     float           null,
Prepayment                      float           null,
NeedPrepayment                  char(1)         null,
Discount                        float           null,
FixedRate2                      float           null,
ForwardPrice2                   float           null,
FwdPriceMethod                  varchar(14)     null,
GrossAmount2                    float           null,
ForwardAmount2                  float           null,
DeliveryCondition1              varchar(9)      null,
DeliveryCondition2              varchar(9)      null,
AgreementPrepare                varchar(1)      null,
DeliveryActive                  varchar(1)      null,
DeliveryExpensePayer            varchar(1)      null,
SettlementDate                  datetime        null,
SettlementDate2                 datetime        null,
TradingPlace                    varchar(4)      null,
MarginCallTrigger               float           null,
Haircut2                        float           null,
CapturedDiscount                varchar(1)      null,
MarginCallMethod                varchar(1)      null,
MarginCallLower                 float           null,
MarginCallUpper                 float           null,
MarginCallKnockOut              float           null,
ToBeProcessed                   char(1)         null,
WeightedAmount                  float           null,
GrossAmount1                    float           null,
Accrued                         float           null,
CurAccr1                        varchar(3)      null,
CurAccr2                        varchar(3)      null,
CurGA1                          varchar(3)      null,
CurGA2                          varchar(3)      null,
CurWA                           varchar(3)      null,
CurFA                           varchar(3)      null,
Currencies_Id                   int             null,
Cpty_Id                         int             null,
RRPid                           int             null,
RRDFUpd                         varchar(1)      null,
PriceCw                         int             null,
VersionStartDate                datetime        not null,
VersionEndDate                  datetime        not null,
)
LOCK DATAROWS



/*--- INDEXES -------------------------------------*/

CREATE UNIQUE INDEX KustomRUKON_RepoDealsVerIdx1 ON KustomRUKON_RepoDealsVer 
(
	TransactionId,
	DealType,
	DealId
)

CREATE INDEX KustomRUKON_RepoDealsVerIdx2 ON KustomRUKON_RepoDealsVer 
(
	VersionStartDate
)

CREATE INDEX KustomRUKON_RepoDealsVerIdx3 ON KustomRUKON_RepoDealsVer 
(
	VersionEndDate
)


GRANT ALL ON KustomRUKON_RepoDealsVer TO PUBLIC 
go



USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRUKON_RepoDealsMvts' AND type = 'U'
)
	DROP table KustomRUKON_RepoDealsMvts 
go


CREATE table KustomRUKON_RepoDealsMvts
(
TransactionId                   int             not null,
Action                          char(1)         not null,
MvtId                           numeric(20)     not null,
DealType                        varchar(32)     not null,
DealId                          int             not null,
RepoType_                       varchar(7)      null,
DirtyPrice_                     float           null,
AccruedCash_                    float           null,
Accrued2_                       float           null,
Accrued2Cash_                   float           null,
DirtyPrice2_                    float           null,
Prepayment_                     float           null,
NeedPrepayment_                 char(1)         null,
Discount_                       float           null,
FixedRate2_                     float           null,
ForwardPrice2_                  float           null,
FwdPriceMethod_                 varchar(14)     null,
GrossAmount2_                   float           null,
ForwardAmount2_                 float           null,
DeliveryCondition1_             varchar(9)      null,
DeliveryCondition2_             varchar(9)      null,
AgreementPrepare_               varchar(1)      null,
DeliveryActive_                 varchar(1)      null,
DeliveryExpensePayer_           varchar(1)      null,
SettlementDate_                 datetime        null,
SettlementDate2_                datetime        null,
TradingPlace_                   varchar(4)      null,
MarginCallTrigger_              float           null,
Haircut2_                       float           null,
CapturedDiscount_               varchar(1)      null,
MarginCallMethod_               varchar(1)      null,
MarginCallLower_                float           null,
MarginCallUpper_                float           null,
MarginCallKnockOut_             float           null,
ToBeProcessed_                  char(1)         null,
WeightedAmount_                 float           null,
GrossAmount1_                   float           null,
Accrued_                        float           null,
CurAccr1_                       varchar(3)      null,
CurAccr2_                       varchar(3)      null,
CurGA1_                         varchar(3)      null,
CurGA2_                         varchar(3)      null,
CurWA_                          varchar(3)      null,
CurFA_                          varchar(3)      null,
Currencies_Id_                  int             null,
Cpty_Id_                        int             null,
RRPid_                          int             null,
RRDFUpd_                        varchar(1)      null,
PriceCw                         int             null
)
LOCK DATAROWS


GRANT ALL ON KustomRUKON_RepoDealsMvts TO PUBLIC 
go

/*------------------------------------------------- 
		KustomRUKON_RepoDealsMvts_insert
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'KustomRUKON_RepoDealsMvts_insert' AND type = 'P' 
)
	DROP PROC KustomRUKON_RepoDealsMvts_insert 
go






CREATE PROCEDURE KustomRUKON_RepoDealsMvts_insert (@TableId int, @RowId int, @DealType varchar(32), @Action char(1) ) as
BEGIN
DECLARE @MvtId numeric(20), @TransId int, @ret_value int
SELECT @MvtId = 0, @TransId = 0, @ret_value = 0
EXECUTE kplus.dbo.KLSDealsInfo_BatchFlag_test @TableId, @RowId, @Action, @ret_value output
IF (@ret_value > 0) 
BEGIN
IF EXISTS (SELECT 1 from kplus.dbo.DBVariables where KeyId=51) /* OPTION DBVAR_UNSERIAL_DEALS_ID */ 
BEGIN
EXECUTE kplus.dbo.KLSDealsInfo_getMvtId @TableId, @RowId, @Action, @MvtId output 
IF @MvtId = -1 
RETURN -1
END 
ELSE 
BEGIN
EXECUTE kplus.dbo.KLSDealsInfo_getTransId @TableId, @RowId, @Action, @TransId output 
IF (@TransId = 0 OR @TransId = NULL) 
RETURN -1
END 
INSERT Kustom.dbo.KustomRUKON_RepoDealsMvts SELECT @TransId, @Action, @MvtId, F.DealType, F.DealId, F.RepoType, F.DirtyPrice, F.AccruedCash, F.Accrued2, F.Accrued2Cash, F.DirtyPrice2, F.Prepayment, F.NeedPrepayment, F.Discount, F.FixedRate2, F.ForwardPrice2, F.FwdPriceMethod, F.GrossAmount2, F.ForwardAmount2, F.DeliveryCondition1, F.DeliveryCondition2, F.AgreementPrepare, F.DeliveryActive, F.DeliveryExpensePayer, F.SettlementDate, F.SettlementDate2, F.TradingPlace, F.MarginCallTrigger, F.Haircut2, F.CapturedDiscount, F.MarginCallMethod, F.MarginCallLower, F.MarginCallUpper, F.MarginCallKnockOut, F.ToBeProcessed, F.WeightedAmount, F.GrossAmount1, F.Accrued, F.CurAccr1, F.CurAccr2, F.CurGA1, F.CurGA2, F.CurWA, F.CurFA, F.Currencies_Id, F.Cpty_Id, F.RRPid, F.RRDFUpd, F.PriceCw
FROM Kustom.dbo.RUKON_RepoDeals F
WHERE F.DealId = @RowId AND F.DealType = @DealType 
END 
RETURN 0
END 


go



GRANT EXEC ON KustomRUKON_RepoDealsMvts_insert TO PUBLIC 
go

