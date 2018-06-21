set char_convert off
go

IF OBJECT_ID ('dbo.Radius_Lib_YearFraction') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_YearFraction
GO

CREATE TABLE dbo.Radius_Lib_YearFraction
	(
	  SPID          INT NOT NULL
	, StartDate     DATETIME NULL
	, EndDate       DATETIME NULL
	, Frequency     CHAR (1) DEFAULT 'A' NOT NULL
	, Basis         CHAR (1) NULL
	, YearFraction  FLOAT NULL
	, Period        CHAR (1) DEFAULT 'F' NOT NULL
	, Currencies_Id INT NULL
	, Cities_Id     INT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX PK_Radius_Lib_YearFraction
	ON dbo.Radius_Lib_YearFraction (SPID, StartDate, EndDate, Basis) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_PositionsAssets') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_PositionsAssets
GO

CREATE TABLE dbo.Radius_Lib_PositionsAssets
	(
	  SPID                     INT NOT NULL
	, "Date"                   DATETIME NOT NULL
	, PrevDate                 DATETIME NOT NULL
	, RadiusPositionsAssets_Id NUMERIC (10) DEFAULT 0 NOT NULL
	, RadiusPositions_Id       NUMERIC (10) DEFAULT 0 NOT NULL
	, TransactionId            INT DEFAULT 0 NULL
	, Updated                  DATETIME NULL
	, AssetsType               CHAR (3) NULL
	, Assets_Id                INT NULL
	, Events_Id                NUMERIC (10) NULL
	, Events_SortCode          VARCHAR (50) NULL
	, Currencies_Id            INT NULL
	, OpenQty                  FLOAT DEFAULT 0 NULL
	, OpenAmount               FLOAT DEFAULT 0 NULL
	, OpenAccrued              FLOAT DEFAULT 0 NULL
	, LastRevalDate            DATETIME NULL
	, LastRevalPrice           FLOAT DEFAULT 0 NULL
	, LastRevalAccrued         FLOAT DEFAULT 0 NULL
	, StartQty                 FLOAT DEFAULT 0 NULL
	, BuyQty                   FLOAT DEFAULT 0 NULL
	, SellQty                  FLOAT DEFAULT 0 NULL
	, BuyAmount                FLOAT DEFAULT 0 NULL
	, SellAmount               FLOAT DEFAULT 0 NULL
	, FeesAmount               FLOAT DEFAULT 0 NULL
	, CouponRcv                FLOAT DEFAULT 0 NULL
	, PrincipalRcv             FLOAT DEFAULT 0 NULL
	, RealizedAccrued          FLOAT DEFAULT 0 NULL
	, RealizedPrice            FLOAT DEFAULT 0 NULL
	, BuyQtyC                  FLOAT DEFAULT 0 NULL
	, SellQtyC                 FLOAT DEFAULT 0 NULL
	, BuyAmountC               FLOAT DEFAULT 0 NULL
	, SellAmountC              FLOAT DEFAULT 0 NULL
	, FeesAmountC              FLOAT DEFAULT 0 NULL
	, CouponRcvC               FLOAT DEFAULT 0 NULL
	, PrincipalRcvC            FLOAT DEFAULT 0 NULL
	, RealizedAccruedC         FLOAT DEFAULT 0 NULL
	, RealizedPriceC           FLOAT DEFAULT 0 NULL
	, CustVal1                 FLOAT NULL
	, CustVal2                 FLOAT NULL
	, CustVal3                 FLOAT NULL
	, CustVal4                 FLOAT NULL
	, CustVal5                 FLOAT NULL
	, CustVal6                 FLOAT NULL
	, CustVal7                 FLOAT NULL
	, CustVal8                 FLOAT NULL
	, CustVal9                 VARCHAR (32) NULL
	, CustVal10                VARCHAR (32) NULL
	, CustVal11                VARCHAR (32) NULL
	, CustVal12                VARCHAR (32) NULL
	, CustVal13                FLOAT NULL
	, CustVal14                FLOAT NULL
	, CustVal15                FLOAT NULL
	, CustVal16                FLOAT NULL
	, CustVal17                FLOAT NULL
	, CustVal18                FLOAT NULL
	, CustVal19                FLOAT NULL
	, CustVal20                FLOAT NULL
	, CustVal21                FLOAT NULL
	, CustVal22                FLOAT NULL
	, CustVal23                FLOAT NULL
	, CustVal24                FLOAT NULL
	, CustVal25                FLOAT NULL
	, CustVal26                FLOAT NULL
	, CustVal27                FLOAT NULL
	, CustVal28                FLOAT NULL
	, CustVal29                FLOAT NULL
	, CustVal30                FLOAT NULL
	, CustVal31                FLOAT NULL
	, CustVal32                FLOAT NULL
	, Currencies_Id_PL         INT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE UNIQUE NONCLUSTERED INDEX ix_Radius_Lib_PositionsAssets
	ON dbo.Radius_Lib_PositionsAssets (SPID, Date, RadiusPositionsAssets_Id) ON 'default'
GO

CREATE UNIQUE NONCLUSTERED INDEX ix_Radius_Lib_PositionsAssets2
	ON dbo.Radius_Lib_PositionsAssets (SPID, PrevDate, RadiusPositionsAssets_Id) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_Objects') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_Objects
GO

CREATE TABLE dbo.Radius_Lib_Objects
	(
	  SPID        INT NOT NULL
	, Objects_Id  NUMERIC (10) NOT NULL
	, ObjectsType CHAR (1) NOT NULL
	)
	LOCK DATAROWS
	WITH EXP_ROW_SIZE = 1
	ON 'default'
GO

CREATE UNIQUE NONCLUSTERED INDEX ix_Radius_Lib_Objects
	ON dbo.Radius_Lib_Objects (SPID, Objects_Id, ObjectsType) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_FwdInterestRate') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_FwdInterestRate
GO

CREATE TABLE dbo.Radius_Lib_FwdInterestRate
	(
	  SPID             INT NOT NULL
	, Curves_Id        INT NOT NULL
	, Basis            CHAR (1) NOT NULL
	, "Date"           DATETIME NOT NULL
	, ForwardStartDate DATETIME NOT NULL
	, ForwardEndDate   DATETIME NOT NULL
	, FwdRate          FLOAT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX ix_Radius_Lib_FwdIntrRate_1
	ON dbo.Radius_Lib_FwdInterestRate (SPID, Curves_Id, Basis, Date, ForwardStartDate, ForwardEndDate) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_ForwardRate') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_ForwardRate
GO

CREATE TABLE dbo.Radius_Lib_ForwardRate
	(
	  SPID               INT NOT NULL
	, Pairs_Id           INT NOT NULL
	, "Date"             DATETIME NOT NULL
	, ValueDate          DATETIME NOT NULL
	, Mode               INT NULL
	, SpotDate           DATETIME NULL
	, DF_CCY1            FLOAT NULL
	, DF_CCY2            FLOAT NULL
	, Points             FLOAT NULL
	, YieldCurve_CCY1_Id INT NULL
	, YieldCurve_CCY2_Id INT NULL
	, ZCBasis_CCY1       CHAR (1) NULL
	, ZCBasis_CCY2       CHAR (1) NULL
	, Points_Id_L        INT NULL
	, TermL              INT NULL
	, PointsL_Date_L     DATETIME NULL
	, PointsL_Date_R     DATETIME NULL
	, PointsL            FLOAT NULL
	, Points_Id_R        INT NULL
	, TermR              INT NULL
	, PointsR_Date_L     DATETIME NULL
	, PointsR_Date_R     DATETIME NULL
	, PointsR            FLOAT NULL
	, SpotRate           FLOAT NULL
	, FwdRate            FLOAT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX ix_Radius_Lib_ForwardRate_1
	ON dbo.Radius_Lib_ForwardRate (SPID) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_FloatingRates') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_FloatingRates
GO

CREATE TABLE dbo.Radius_Lib_FloatingRates
	(
	  SPID                  INT NOT NULL
	, FloatingRates_Id      INT NULL
	, CurRefIndex_ShortName VARCHAR (32) NULL
	, StartDate             DATETIME NOT NULL
	, EndDate               DATETIME NOT NULL
	, FloatingRatesType     CHAR (1) NULL
	, Rate                  FLOAT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX ix_Radius_Lib_FloatingRates_1
	ON dbo.Radius_Lib_FloatingRates (SPID) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_DateDiff_Basis') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_DateDiff_Basis
GO

CREATE TABLE dbo.Radius_Lib_DateDiff_Basis
	(
	  SPID          INT NOT NULL
	, StartDate     DATETIME NULL
	, EndDate       DATETIME NULL
	, Frequency     CHAR (1) DEFAULT 'A' NOT NULL
	, Basis         CHAR (1) NULL
	, Days          INT NULL
	, Period        CHAR (1) DEFAULT 'F' NOT NULL
	, Currencies_Id INT NULL
	, Cities_Id     INT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX PK_Radius_Lib_DateDiff_Basis
	ON dbo.Radius_Lib_DateDiff_Basis (SPID, StartDate, EndDate, Basis) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_CurvesRates') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_CurvesRates
GO

CREATE TABLE dbo.Radius_Lib_CurvesRates
	(
	  SPID           INT NOT NULL
	, Curves_Id      INT NULL
	, StartDate      DATETIME NULL
	, EndDate        DATETIME NULL
	, CurveRate      FLOAT NULL
	, ZeroRate       FLOAT NULL
	, DiscountFactor FLOAT NULL
	, LeftPoint      DATETIME NULL
	, RightPoint     DATETIME NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX PK_Radius_Lib_CurvesRates
	ON dbo.Radius_Lib_CurvesRates (SPID, Curves_Id, StartDate, EndDate) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_CurrenciesRates') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_CurrenciesRates
GO

CREATE TABLE dbo.Radius_Lib_CurrenciesRates
	(
	  SPID             INT NOT NULL
	, Currencies_Id_1  INT NOT NULL
	, Currencies_Id_2  INT NOT NULL
	, Pairs_Id         INT NULL
	, Pairs_Id_Reverse INT NULL
	, "Date"           DATETIME DEFAULT convert(datetime,convert(char(8),getdate(),112),112) NOT NULL
	, QuoteType        CHAR (1) DEFAULT 'H' NOT NULL
	, BidAskMiddle     CHAR (1) DEFAULT 'M' NOT NULL
	, GoodOrder        CHAR (1) DEFAULT 'N' NOT NULL
	, ExactDate        CHAR (1) DEFAULT 'N' NOT NULL
	, StoredRate       FLOAT NULL
	, Rate             FLOAT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX PK_Radius_Lib_CurrenciesRates
	ON dbo.Radius_Lib_CurrenciesRates (SPID, QuoteType, Date, GoodOrder) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_CpiValues') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_CpiValues
GO

CREATE TABLE dbo.Radius_Lib_CpiValues
	(
	  SPID                  INT DEFAULT @@SPID NOT NULL
	, ConsumerPriceIndex_Id INT NULL
	, CalcDate              DATE NOT NULL
	, CpiLag                INT DEFAULT 0 NOT NULL
	, InterpolationMethod   CHAR (1) DEFAULT 'L' NOT NULL
	, AnticipatedInflation  FLOAT DEFAULT 0 NULL
	, CpiValue              FLOAT NULL
	, CpiValue1             FLOAT NULL
	, CpiValue2             FLOAT NULL
	, CpiDate               DATE NULL
	, CpiDate1              DATE NULL
	, CpiDate2              DATE NULL
	, MonthlyInflationCoeff FLOAT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX ix_Radius_Lib_CpiValues
	ON dbo.Radius_Lib_CpiValues (SPID, ConsumerPriceIndex_Id, CalcDate, CpiLag) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_Calendar') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_Calendar
GO

CREATE TABLE dbo.Radius_Lib_Calendar
	(
	  "Date" DATETIME NOT NULL
	)
	LOCK DATAROWS
	WITH EXP_ROW_SIZE = 1
	ON 'default'
GO

CREATE UNIQUE CLUSTERED INDEX ix_Radius_Lib_Calendar
	ON dbo.Radius_Lib_Calendar (Date) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_BondsPrincipal') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_BondsPrincipal
GO

CREATE TABLE dbo.Radius_Lib_BondsPrincipal
	(
	  SPID      INT DEFAULT @@SPID NOT NULL
	, Bonds_Id  INT NOT NULL
	, CalcDate  DATETIME DEFAULT convert(date, getdate()) NOT NULL
	, AdjFactor FLOAT NULL
	, Principal FLOAT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE UNIQUE CLUSTERED INDEX ix_Radius_Lib_BondsPrincipal
	ON dbo.Radius_Lib_BondsPrincipal (SPID, Bonds_Id, CalcDate, AdjFactor) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_BondsAdjFactors') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_BondsAdjFactors
GO

CREATE TABLE dbo.Radius_Lib_BondsAdjFactors
	(
	  SPID                      INT DEFAULT @@SPID NOT NULL
	, Bonds_Id                  INT NOT NULL
	, CalcDate                  DATE DEFAULT getdate() NOT NULL
	, AdjFactor                 FLOAT NULL
	, PrincipalIndexed          CHAR (1) NULL
	, IssueDate                 DATE NULL
	, ConsumerPriceIndex_Id     INT NULL
	, OriginalRefCpi_Cpi        FLOAT NULL
	, AnticipatedInflation_Cpi  FLOAT NULL
	, RefCpiLag_Cpi             INT NULL
	, IsRefCpiRounding_Cpi      CHAR (1) NULL
	, RefCpiRoundingConv_Cpi    INT NULL
	, RefCpiRoundingType_Cpi    CHAR (1) NULL
	, AdjFactorRoundingConv_Cpi INT NULL
	, AdjFactorRoundingType_Cpi CHAR (1) NULL
	, InterpolationMethod_Cpi   CHAR (1) NULL
	, InflationBondConvention   CHAR (1) NULL
	, CpiValue                  FLOAT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX ix_Radius_Lib_BondsAdjFactors
	ON dbo.Radius_Lib_BondsAdjFactors (SPID, Bonds_Id, CalcDate) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_BondsAccrued') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_BondsAccrued
GO

CREATE TABLE dbo.Radius_Lib_BondsAccrued
	(
	  SPID           INT DEFAULT @@SPID NOT NULL
	, Bonds_Id       INT NOT NULL
	, Quantity       NUMERIC (28,10) NULL
	, "Date"         DATETIME NOT NULL
	, AdjFactor      NUMERIC (28,10) NULL
	, Amount         NUMERIC (28,10) NULL
	, Percent        NUMERIC (28,10) NULL
	, CouponPeriod   CHAR (1) DEFAULT 'F' NOT NULL
	, CurrentNominal NUMERIC (28,10) NULL
	, AddAmount      NUMERIC (28,10) DEFAULT 0 NOT NULL
	, AddPercent     NUMERIC (28,10) DEFAULT 0 NOT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX ix_Radius_Lib_BondsAccrued
	ON dbo.Radius_Lib_BondsAccrued (SPID, Bonds_Id) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_AssetsQuotes') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_AssetsQuotes
GO

CREATE TABLE dbo.Radius_Lib_AssetsQuotes
	(
	  SPID         INT NOT NULL
	, Assets_Id    INT NOT NULL
	, AssetsType   CHAR (3) NOT NULL
	, "Date"       DATETIME NULL
	, PriceType    CHAR (1) DEFAULT 'B' NOT NULL
	, UseAltQuotes CHAR (1) DEFAULT 'N' NOT NULL
	, Perimeter    INT NULL
	, QuoteType    CHAR (1) DEFAULT 'F' NOT NULL
	, PriceBid     FLOAT NULL
	, PriceAsk     FLOAT NULL
	, IsAltQuote   CHAR (1) DEFAULT 'N' NOT NULL
	, TheoPrice    FLOAT NULL
	, Delta        FLOAT NULL
	, Gamma        FLOAT NULL
	, Theta        FLOAT NULL
	, Vega         FLOAT NULL
	, Rho          FLOAT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX PK_Radius_Lib_AssetsQuotes
	ON dbo.Radius_Lib_AssetsQuotes (SPID, Assets_Id, AssetsType, Date) ON 'default'
GO

IF OBJECT_ID ('dbo.Radius_Lib_AddDays') IS NOT NULL
	DROP TABLE dbo.Radius_Lib_AddDays
GO

CREATE TABLE dbo.Radius_Lib_AddDays
	(
	  SPID            INT NOT NULL
	, Currencies_Id_1 INT NULL
	, Currencies_Id_2 INT NULL
	, Cities_Id_1     INT NULL
	, Cities_Id_2     INT NULL
	, DateIn          DATETIME NOT NULL
	, DaysToAdd       INT NOT NULL
	, DaysType        CHAR (1) NOT NULL
	, DateOut         DATETIME NULL
	, Remainder       INT NULL
	, Date1           DATETIME NULL
	, Date2           DATETIME NULL
	, Remainder1      INT NULL
	, Remainder2      INT NULL
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE NONCLUSTERED INDEX PK_Radius_Lib_AddDays
	ON dbo.Radius_Lib_AddDays (SPID, Currencies_Id_1, Currencies_Id_2, DateIn, DaysToAdd, DaysType, DateOut) ON 'default'
GO

CREATE NONCLUSTERED INDEX ix_Radius_Lib_AddDays
	ON dbo.Radius_Lib_AddDays (SPID, DaysType) ON 'default'
GO


IF OBJECT_ID ('dbo.RadiusMarginCalls') IS NOT NULL
	DROP TABLE dbo.RadiusMarginCalls
GO

CREATE TABLE dbo.RadiusMarginCalls
	(
	  RadiusMarginCalls_Id NUMERIC (15) NOT NULL
	, TransactionId        INT NOT NULL
	, CaptureDate          DATETIME NOT NULL
	, LastModifDate        DATETIME NOT NULL
	, DealStatus           CHAR (1) NOT NULL
	, InputMode            CHAR (1) NOT NULL
	, DownloadKey          VARCHAR (30) NOT NULL
	, Users_Id             INT NULL
	, Users_Id_Last        INT NULL
	, Folders_Id           INT NOT NULL
	, ContextType          VARCHAR (30) NOT NULL
	, Context_Id           NUMERIC (15) NOT NULL
	, TradeDate            DATETIME NOT NULL
	, ValueDate            DATETIME NOT NULL
	, Cpty_Id              INT NOT NULL
	, AssetType            CHAR (3) NOT NULL
	, Assets_Id            INT NOT NULL
	, Quantity             FLOAT NOT NULL
	, FixedRate            FLOAT NULL
	, Comments             VARCHAR (64) NULL
	, CONSTRAINT PK_RadiusMarginCalls PRIMARY KEY (RadiusMarginCalls_Id) ON 'default'
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE UNIQUE NONCLUSTERED INDEX IX_RadiusMarginCalls_1
	ON dbo.RadiusMarginCalls (DownloadKey) ON 'default'
GO




IF OBJECT_ID ('dbo.RadiusMarginCallsMvts') IS NOT NULL
	DROP TABLE dbo.RadiusMarginCallsMvts
GO

CREATE TABLE dbo.RadiusMarginCallsMvts
	(
	  Mvts_Id              NUMERIC (15) IDENTITY NOT NULL
	, Mvts_Date            DATETIME NOT NULL
	, Action               CHAR (1) NOT NULL
	, RefCount             INT NOT NULL
	, TranId               NUMERIC (15) NULL
	, RadiusMarginCalls_Id NUMERIC (15) NOT NULL
	, TransactionId        INT NOT NULL
	, CaptureDate          DATETIME NOT NULL
	, LastModifDate        DATETIME NOT NULL
	, DealStatus           CHAR (1) NOT NULL
	, InputMode            CHAR (1) NOT NULL
	, DownloadKey          VARCHAR (30) NOT NULL
	, Users_Id             INT NULL
	, Users_Id_Last        INT NULL
	, Folders_Id           INT NOT NULL
	, ContextType          VARCHAR (30) NOT NULL
	, Context_Id           NUMERIC (15) NOT NULL
	, TradeDate            DATETIME NOT NULL
	, ValueDate            DATETIME NOT NULL
	, Cpty_Id              INT NOT NULL
	, AssetType            CHAR (3) NOT NULL
	, Assets_Id            INT NOT NULL
	, Quantity             FLOAT NOT NULL
	, FixedRate            FLOAT NULL
	, Comments             VARCHAR (64) NULL
	, CONSTRAINT PK_RadiusMarginCallsMvts PRIMARY KEY (Mvts_Id) ON 'default'
	)
	LOCK DATAROWS
	WITH IDENTITY_GAP = 10000
	ON 'default'
GO

CREATE NONCLUSTERED INDEX IX_RadiusMarginCallsMvts_1
	ON dbo.RadiusMarginCallsMvts (TranId) ON 'default'
GO

IF OBJECT_ID ('dbo.RadiusMarginCallsExecsMvts') IS NOT NULL
	DROP TABLE dbo.RadiusMarginCallsExecsMvts
GO

CREATE TABLE dbo.RadiusMarginCallsExecsMvts
	(
	  Mvts_Id                   NUMERIC (15) IDENTITY NOT NULL
	, Mvts_Date                 DATETIME NOT NULL
	, Action                    CHAR (1) NOT NULL
	, RefCount                  INT NOT NULL
	, TranId                    NUMERIC (15) NULL
	, RadiusMarginCallsExecs_Id NUMERIC (15) NOT NULL
	, RadiusMarginCalls_Id      NUMERIC (15) NOT NULL
	, TransactionId             INT NOT NULL
	, Exec_Status               CHAR (1) NOT NULL
	, Exec_DealType             VARCHAR (30) NULL
	, Exec_Deals_Id             INT NULL
	, CaptureDate               DATETIME NOT NULL
	, LastModifDate             DATETIME NOT NULL
	, InputMode                 CHAR (1) NOT NULL
	, DownloadKey               VARCHAR (30) NOT NULL
	, Users_Id                  INT NULL
	, Users_Id_Last             INT NULL
	, ContextType               VARCHAR (30) NOT NULL
	, Context_Id                NUMERIC (15) NOT NULL
	, ValueDate                 DATETIME NOT NULL
	, AssetType                 CHAR (3) NOT NULL
	, Assets_Id                 INT NOT NULL
	, Quantity                  FLOAT NOT NULL
	, Comments                  VARCHAR (64) NULL
	, CONSTRAINT PK_RadiusMarginCallsExecsMvts PRIMARY KEY (Mvts_Id) ON 'default'
	)
	LOCK DATAROWS
	WITH IDENTITY_GAP = 10000
	ON 'default'
GO

CREATE NONCLUSTERED INDEX IX_RadiusMarginCallsExecsMvts1
	ON dbo.RadiusMarginCallsExecsMvts (TranId) ON 'default'
GO

IF OBJECT_ID ('dbo.RadiusMarginCallsExecs') IS NOT NULL
	DROP TABLE dbo.RadiusMarginCallsExecs
GO

CREATE TABLE dbo.RadiusMarginCallsExecs
	(
	  RadiusMarginCallsExecs_Id NUMERIC (15) NOT NULL
	, RadiusMarginCalls_Id      NUMERIC (15) NOT NULL
	, TransactionId             INT NOT NULL
	, Exec_Status               CHAR (1) NOT NULL
	, Exec_DealType             VARCHAR (30) NULL
	, Exec_Deals_Id             INT NULL
	, CaptureDate               DATETIME NOT NULL
	, LastModifDate             DATETIME NOT NULL
	, InputMode                 CHAR (1) NOT NULL
	, DownloadKey               VARCHAR (30) NOT NULL
	, Users_Id                  INT NULL
	, Users_Id_Last             INT NULL
	, ContextType               VARCHAR (30) NOT NULL
	, Context_Id                NUMERIC (15) NOT NULL
	, ValueDate                 DATETIME NOT NULL
	, AssetType                 CHAR (3) NOT NULL
	, Assets_Id                 INT NOT NULL
	, Quantity                  FLOAT NOT NULL
	, Comments                  VARCHAR (64) NULL
	, CONSTRAINT PK_RadiusMarginCallsExecs PRIMARY KEY (RadiusMarginCallsExecs_Id) ON 'default'
	, CONSTRAINT FK_RadiusMarginCallsExecs FOREIGN KEY (RadiusMarginCalls_Id) REFERENCES dbo.RadiusMarginCalls (RadiusMarginCalls_Id)
	)
	LOCK DATAROWS
	ON 'default'
GO

CREATE UNIQUE NONCLUSTERED INDEX IX_RadiusMarginCallsExecs_1
	ON dbo.RadiusMarginCallsExecs (DownloadKey) ON 'default'
GO

CREATE NONCLUSTERED INDEX IX_RadiusMarginCallsExecs_2
	ON dbo.RadiusMarginCallsExecs (RadiusMarginCalls_Id) ON 'default'
GO


