USE Kustom
go
IF OBJECT_ID('dbo.Radius_Bonds_CalcAccrued') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.Radius_Bonds_CalcAccrued
    IF OBJECT_ID('dbo.Radius_Bonds_CalcAccrued') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.Radius_Bonds_CalcAccrued >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.Radius_Bonds_CalcAccrued >>>'
END
go
create procedure Radius_Bonds_CalcAccrued
/*
   Radius_Bonds_CalcAccrued - calculates accrued for bond either by TradeDate or by ValueDate & SettlementDate
*/
(
   @Bonds_Id integer,
   @TradeDate datetime,    -- if TradeDate defined - then ValueDate=SettlDate=NULL, accrued is calculated by TradeDate
   @ValueDate datetime,    -- if ValueDate defined - then TradeDate=NULL, accrued is calculated by ValueDate and SettlDate
   @SettlDate datetime,    -- if SettlDate defined - then TradeDate=NULL, accrued is calculated by ValueDate and SettlDate
   @OutValue float output  -- resulting accrued
)
as
begin
   declare @ProcName varchar(256), @InternalKey varchar(64), @KFS_Version int, @KFS_LicenseMode varchar(1)
   exec Radius_Settings_GetValueText 'KFS_LicenseMode', @KFS_LicenseMode output, 'R'

   select @InternalKey = convert(varchar, @@spid)
   exec Radius_Settings_GetValueText 'KFS_Name', @ProcName output, 'OpenKFS'
   -- in 3.0 KFS procedures FI_Bonds_Accrued and FI_Bonds_Accrued_by_Date have additional argument - @AccruedPeriod - CS_INT_TYPE - Period of accrued interest.
   exec Radius_Settings_GetValueInt 'KFS_Version', @KFS_Version output, 26
   if @TradeDate is not null begin
      select @ProcName = @ProcName + '...FI_Bonds_Accrued'
      if @KFS_Version >= 30
      begin
         if @KFS_LicenseMode = 'R'
            exec @ProcName @Bonds_Id, @TradeDate, 0, @OutValue output, @InternalKey
         else
            exec @ProcName @Bonds_Id, @TradeDate, 0, @OutValue output
      end
      else
      begin
         if @KFS_LicenseMode = 'R'
            exec @ProcName @Bonds_Id, @TradeDate,    @OutValue output, @InternalKey
         else
            exec @ProcName @Bonds_Id, @TradeDate,    @OutValue output
      end
   end
   /*
ADDING SOME STAFF
   */
   else begin
      select @ProcName = @ProcName + '...FI_Bonds_Accrued_by_Date'
      if @KFS_Version >= 30
      begin
         if @KFS_LicenseMode = 'R'
            exec @ProcName @Bonds_Id, @ValueDate, @SettlDate, 0, @OutValue output, @InternalKey
         else
            exec @ProcName @Bonds_Id, @ValueDate, @SettlDate, 0, @OutValue output
      end
      else
      begin
         if @KFS_LicenseMode = 'R'
            exec @ProcName @Bonds_Id, @ValueDate, @SettlDate,    @OutValue output, @InternalKey
         else
            exec @ProcName @Bonds_Id, @ValueDate, @SettlDate,    @OutValue output
      end
   end
end
go
EXEC sp_procxmode 'dbo.Radius_Bonds_CalcAccrued', 'unchained'
go
IF OBJECT_ID('dbo.Radius_Bonds_CalcAccrued') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.Radius_Bonds_CalcAccrued >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.Radius_Bonds_CalcAccrued >>>'
go
REVOKE EXECUTE ON dbo.Radius_Bonds_CalcAccrued FROM public
go
GRANT EXECUTE ON dbo.Radius_Bonds_CalcAccrued TO public
go
