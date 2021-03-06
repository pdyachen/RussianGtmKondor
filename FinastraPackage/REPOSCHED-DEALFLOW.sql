/*----------------------------------------------*/
/*--- DealFlow REPOSCHED  ----------------------*/
/*----------------------------------------------*/

DECLARE @DealFlow_Id int
SELECT @DealFlow_Id = DealFlow_Id FROM kplus..DealFlow
WHERE DealFlow_ShortName = 'REPOSCHED' OR DealFlow_Name = 'REPO SCHED UPDATE'
IF @DealFlow_Id != 0 AND @DealFlow_Id != NULL
BEGIN
	DELETE kplus..DealFlowGenProcArg WHERE DealFlow_Id = @DealFlow_Id
	DELETE kplus..DealFlowGenRule WHERE DealFlow_Id = @DealFlow_Id
	DELETE kplus..DealFlowGenerate WHERE DealFlow_Id = @DealFlow_Id
	DELETE kplus..DealFlowCriteria WHERE DealFlow_Id = @DealFlow_Id
	UPDATE kplus..DealFlow SET DealFlow_ShortName = 'REPOSCHED', DealFlow_Name = 'REPO SCHED UPDATE', CriProc = NULL, LinkMode = 'N', KdbTables_Id = 395, StrategiesType_Id = 0, LinkTriggerDeal = 'Y', Disable = 'N', InputMode = 'C', Comment = NULL, ActOnUpd = 'C', ActOnDel = 'C' WHERE DealFlow_Id = @DealFlow_Id
END
ELSE
BEGIN
	UPDATE KplusGlobal..DealFlowId SET DealFlowId = DealFlowId + 1, @DealFlow_Id = DealFlowId + 1
	INSERT kplus..DealFlow VALUES (@DealFlow_Id, 'REPOSCHED', 'REPO SCHED UPDATE', NULL, 'N', 395, 0, 'Y', 'N', 'C', NULL, 'C', 'C')
END

INSERT kplus..DealFlowCriteria VALUES (1, @DealFlow_Id, 'Y', 'RepoDeals', 'Action', 'N', 'D', 'Y', 'Y')

INSERT kplus..DealFlowGenerate VALUES (1, @DealFlow_Id, 395, 'DFRepoSchedUpdate', 'N', 'U', 1, 'N')
INSERT kplus..DealFlowGenRule VALUES (1, 'TradeKast_RREPO', 'RRDFUpd', @DealFlow_Id, NULL, NULL, 'Y')
INSERT kplus..DealFlowGenProcArg VALUES (1, 1, @DealFlow_Id, 'RepoDeals', 'RepoDeals_Id')
go

/*--- END --------------------------------------*/
