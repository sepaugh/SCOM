<###### 
SQL Database/Server update script

To be run on each Management Server in the SCOM environment. Replace the topmost variables
with the updated Database Name, and the new SQL Server or Listener FQDN (same as you'll update 
in the database).

This script is provided without waranty or guarantee, use with caution as we do modify server 
configurations

######>

## Replace these values with the appropriate ones for your environment
$OpsDBName = "OperationsManager"
$OpsDBServer = "SQL.contoso.com"

$DWDBName = "OperationsManagerDW"
$DWDBServer = "SQL.contoso.com"

## Stop Services
Stop-Service OMSDK,CSHOST,HealthService -Force -Verbose

## Backup the Registry to LocalAppData
New-Item -Path "$Env:LocalAppData\SCOM\Backup" -Type Directory
Write-Host "`tBacking up registry hive: HKEY_LOCAL_MACHINE"
    if ((Start-Process -Wait -PassThru reg "export HKLM `"$Env:LocalAppData\SCOM\Backup\HKLM.reg.$timestamp`" /y").ExitCode -notlike "0") { 
        Write-Output "`t`tFailed to backup HKLM registry hive. Error Code $($LastExitCode)"
    } else {
        Write-Output "`t`tSuccessfully backed up HKLM registry hive"
    }

## Update OperationsManager Registry Instances
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup" -Name DatabaseName -Value $OpsDBName -Force -Verbose
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup" -Name DatabaseServerName -Value $OpsDBServer -Force -Verbose
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center\2010\Common\Database" -Name DatabaseName -Value $OpsDBName -Force -Verbose
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center\2010\Common\Database" -Name DatabaseServerName -Value $OpsDBServer -Force -Verbose

## Update Datawarehouse Registry Instances
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup" -Name DataWarehouseDBName -Value $DWDBName -Force -Verbose
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup" -Name DataWarehouseDBServerName -Value $DWDBServer -Force -Verbose


## Get the management server installation directory
$InstallDir = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup" -Name InstallDirectory

## Backup Config File
$timestamp = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
Copy-Item -Path "$InstallDir\ConfigService.config" -Destination "$InstallDir\ConfigService.config.$timestamp"


##Get Configuration File
[xml]$ConfigFile = Get-Content "$InstallDir\ConfigService.config"

## Updating the CMDB Category 
$ConfigNode = $ConfigFile.SelectNodes("//Category[3]")
$ConfigFile | ForEach-Object { 
    $ConfigNode.Setting[0].Value = $OpsDBServer
    $ConfigNode.Setting[1].Value = $OpsDBName
}

## Updating the ConfigStore Category
$ConfigNode = $ConfigFile.SelectSingleNode("//Category[4]")
$ConfigFile | ForEach-Object { 
    $ConfigNode.Setting[0].Value = $OpsDBServer
    $ConfigNode.Setting[1].Value = $OpsDBName
}

## Save Config file back to disk
$ConfigFile.Save("$InstallDir\ConfigService.config")

## Restart Services
Start-Service OMSDK,CSHOST,HealthService -Verbose
