/*-------------------------------------------------*/
/*--- Initialization Part -------------------------*/
/*-------------------------------------------------*/

USE kplus
go
/*------------------------------------------------- 
		RUKON_RepoDealsDealFlow
---------------------------------------------------*/


USE Kustom
go

IF EXISTS 
(
	SELECT name 
	FROM   sysobjects 
	WHERE  name = 'RUKON_RepoDealsDealFlow' AND type = 'P' 
)
	DROP PROC RUKON_RepoDealsDealFlow 
go





CREATE PROC RUKON_RepoDealsDealFlow (@DealId int)
AS
BEGIN

DECLARE @RRDFUpd varchar(1)
select @RRDFUpd=RRDFUpd from Kustom..RUKON_RepoDeals where DealId=@DealId
IF @RRDFUpd != 'N'
   RETURN

--IF  EXISTS (SELECT Status FROM RepoGen Where DealId = @DealId ) 
--RETURN

Insert RepoGen
SELECT @DealId, "D"

SELECT 'RepoDeals', 'RepoDeals_Id', @DealId

DECLARE @Row int
SELECT @Row = 0

DECLARE @UserModified char(1), @RowName varchar(128)
DECLARE @CashFlowType char(1), @Principal float, @StartDate datetime, @EndDate datetime, @PaymentDate datetime
DECLARE @FixingDate datetime, @CashFlow float, @Rate float, @FloatingRates_Id int, @AdditiveMargin float
DECLARE @MultiplyMargin float

DECLARE @Pid int
--SELECT @Pid=convert(int, Comments) from kplus..RepoDeals where RepoDeals_Id=@DealId
SELECT @Pid=RRPid from Kustom..RUKON_RepoDeals where DealId=@DealId

DECLARE Row CURSOR FOR 
	SELECT  CashFlowType, Principal, StartDate, EndDate, PaymentDate, CashFlow, Rate
--	FROM RUKON_RepoSchedule WHERE RepoDeals_Id = @DealId
	FROM RUKON_RepoSchedule WHERE Pid = @Pid
	ORDER BY PaymentDate, CashFlowType
	OPEN Row
	FETCH Row INTO @CashFlowType, @Principal, @StartDate, @EndDate, @PaymentDate, @CashFlow,
			@Rate
	WHILE @@FETCH_STATUS = 0
	BEGIN

SELECT @UserModified = "Y"
SELECT @FixingDate = @PaymentDate
SELECT @AdditiveMargin = 0
SELECT @FloatingRates_Id = 0
SELECT @AdditiveMargin = 0
SELECT @MultiplyMargin = 0


SELECT @RowName = 'RepoSchedule_' + convert(varchar, @Row)
SELECT @Row = @Row + 1

SELECT @RowName, 'UserModified', @UserModified
SELECT @RowName, 'Used', 'U'
SELECT @RowName, 'CashFlowType', @CashFlowType
SELECT @RowName, 'StartDate', @StartDate
SELECT @RowName, 'EndDate', @EndDate
SELECT @RowName, 'PaymentDate', @PaymentDate
SELECT @RowName, 'Principal', @Principal
SELECT @RowName, 'CashFlow', @CashFlow
-- SELECT @RowName, 'Rate', @Rate
SELECT @RowName, 'FixingDate', @FixingDate
SELECT @RowName, 'AdditiveMargin', @AdditiveMargin
SELECT @RowName, 'MultiplyMargin', @MultiplyMargin

	FETCH Row INTO @CashFlowType, @Principal, @StartDate, @EndDate, @PaymentDate, @CashFlow,
			@Rate
	END
	CLOSE Row
DEALLOCATE Row

SELECT 'RepoSchedule', 'Number', @Row

SELECT '','TradeKast','Y'
SELECT 'TradeKast_RREPO', 'RRDFUpd','Y'
SELECT 'RepoDeals', 'Comments', 'Dealflow '+convert(varchar(10),@DealId)



/*

DECLARE Row CURSOR FOR 
	SELECT UserModified, CashFlowType, Principal, StartDate, EndDate, PaymentDate, CashFlow, Rate,
		FixingDate, FloatingRates_Id, AdditiveMargin, MultiplyMargin
	FROM kplus..RepoSchedule WHERE RepoDeals_Id = @DealId
	ORDER BY StartDate
	OPEN Row
	FETCH Row INTO @UserModified, @CashFlowType, @Principal, @StartDate, @EndDate, @PaymentDate, @CashFlow,
			@Rate, @FixingDate, @FloatingRates_Id, @AdditiveMargin, @MultiplyMargin
	WHILE @@FETCH_STATUS = 0
	BEGIN

SELECT @RowName = 'RepoSchedule_' + convert(varchar, @Row)
SELECT @Row = @Row + 1

SELECT @RowName, 'UserModified', @UserModified
SELECT @RowName, 'Used', 'U'
SELECT @RowName, 'CashFlowType', @CashFlowType
SELECT @RowName, 'StartDate', @StartDate
SELECT @RowName, 'EndDate', @EndDate
SELECT @RowName, 'PaymentDate', @PaymentDate
SELECT @RowName, 'Principal', @Principal
IF @Row = 2
	SELECT @RowName, 'CashFlow', @CashFlow * 2.0
ELSE
	SELECT @RowName, 'CashFlow', @CashFlow
-- SELECT @RowName, 'Rate', @Rate
SELECT @RowName, 'FixingDate', @FixingDate
SELECT @RowName, 'AdditiveMargin', @AdditiveMargin
SELECT @RowName, 'MultiplyMargin', @MultiplyMargin

	FETCH Row INTO @UserModified, @CashFlowType, @Principal, @StartDate, @EndDate, @PaymentDate, @CashFlow,
			@Rate, @FixingDate, @FloatingRates_Id, @AdditiveMargin, @MultiplyMargin
	END
	CLOSE Row
DEALLOCATE Row

SELECT 'RepoSchedule', 'Number', @Row

*/



END













go



GRANT EXEC ON RUKON_RepoDealsDealFlow TO PUBLIC 
go

