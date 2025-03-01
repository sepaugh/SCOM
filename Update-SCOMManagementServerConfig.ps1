<###### 
Management Server Config Update Script.
To be run on each Management Server in the SCOM environment. Replace the topmost variables
with the updated Database Name, and the new SQL Server or Listener FQDN (same as you'll update 
in the database).
This script is provided without warranty or guarantee, use with caution as we do modify server 
configurations
######>

## Replace these values with the appropriate ones for your environment
$OpsDBName = "OperationsManager"
$OpsDBServer = "SCOM-SQL.momonitoring.com"
$DWDBName = "OperationsManagerDW"
$DWDBServer = "SCOM-SQL.momonitoring.com"

## Check if the script is running as an administrator, if not, restart as an administrator
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{   
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit 000
} 
## Stop Services
try {
    Stop-Service OMSDK,CSHOST,HealthService -Force -Verbose
} catch {
    Write-Error "Failed to stop one or more services."
    exit 001
}
## Get the current date and time in a format that can be used in a file name
$timestamp = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }

## Backup the registry 
reg export "HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager" "$($ENV:TEMP)\SCOM\OperationsManager_.reg.$timestamp" > $null
reg export "HKLM\SYSTEM\CurrentControlSet\Services\HealthService" "$($ENV:TEMP)\SCOM\Healthservice_.reg.$timestamp" > $null
## Get the management server installation directory
try {
    $InstallDir = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup" -Name InstallDirectory
} catch {
    Write-Error "Failed to retrieve the installation directory from the registry."
    exit 002
}
<# 
::: ----------------------
::  Updating Config File
::: ----------------------
#>
## Backup Config File
try {
    Copy-Item -Path "$InstallDir\ConfigService.config" -Destination "$($ENV:TEMP)\SCOM\ConfigService.config.$timestamp"    
}
catch {
    Write-Error "Failed to backup the ConfigService.config file."
    exit 003
}
##Get Configuration File
[xml]$ConfigFile = Get-Content "$InstallDir\ConfigService.config"
## Updating the CMDB Category 
$ConfigNode = $ConfigFile.SelectNodes("//Category[3]")
$ConfigFile | ForEach-Object { 
    $ConfigNode.Setting[0].Value = $OpsDBServer #ServerName
    $ConfigNode.Setting[1].Value = $OpsDBName #DatabaseName
    $ConfigNode.Setting[12].OperationTimeout.DefaultTimeoutSeconds = "300" #OperationsTimeout > DefaultTimeoutSeconds
}
## Updating the ConfigStore Category
$ConfigNode = $ConfigFile.SelectSingleNode("//Category[4]")
$ConfigFile | ForEach-Object { 
    $ConfigNode.Setting[0].Value = $OpsDBServer #ServerName
    $ConfigNode.Setting[1].Value = $OpsDBName #DatabaseName
    $ConfigNode.Setting[10].OperationTimeout.DefaultTimeoutSeconds = "300" #OperationsTimeout > DefaultTimeoutSeconds
}
## Updating the ConfigurationDataProvider Category - if anything, these numbers may go down to decrease the amount of data we push at a time
$ConfigNode = $ConfigFile.SelectSingleNode("//Category[5]")
$ConfigFile | ForEach-Object { 
    $ConfigNode.Setting[0].Value = "50000" #SnapshotSyncManagedEntityBatchSize
    $ConfigNode.Setting[1].Value = "50000" #SnapshotSyncRelationshipBatchSize
    $ConfigNode.Setting[2].Value = "100000" #SnapshotSyncTypedManagedEntityBatchSize
    $ConfigNode.Setting[3].Value = "15" #SafeRangeForLastModifiedDateSeconds
    $ConfigNode.Setting[4].Value = "10000" #DeltaSyncEntityChangeLogBatchSize
}
## Save Config file back to disk
try {
    $ConfigFile.Save("$InstallDir\ConfigService.config")
}
catch {
    Write-Error "Failed to save the updated ConfigService.config file."
    exit 004
}
<# 
::: ----------------------
::  Updating Registry
:: 
::  Some recommendations based on: https://kevinholman.com/2017/03/08/recommended-registry-tweaks-for-scom-2016-management-servers/
::  Values may be modified to suit your environment
::: ----------------------
#>
## Remove unneeded entries in most scenarios, adjust as needed
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\HealthService\Parameters\PoolManager" /f
## Updating database server/DB name entries
reg add "HKLM\SOFTWARE\Microsoft\System Center\2010\Common\Database" /v "DatabaseName" /t REG_SZ /d $OpsDBName /f
reg add "HKLM\SOFTWARE\Microsoft\System Center\2010\Common\Database" /v "DatabaseServerName" /t REG_SZ /d $OpsDBServer /f
reg add "HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup" /v "DataWarehouseDBServerName" /t REG_SZ /d $DWDBServer /f
reg add "HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Setup" /v "DataWarehouseDBName" /t REG_SZ /d $DWDBName /f
## Ensure the SDK service is pointing to itself and not some other machine
reg add "HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Machine Settings" /v "DefaultSDKServiceMachine" /t REG_SZ /d $ENV:COMPUTERNAME /f
## Recommended tweaks
reg add "HKLM\SOFTWARE\Microsoft\System Center\2010\Common" /v "GroupCalcPollingIntervalMilliseconds" /t REG_DWORD /d 1800000 /f
reg add "HKLM\SOFTWARE\Microsoft\System Center\2010\Common\DAL" /v "DALInitiateClearPoolSeconds" /t REG_DWORD /d 60 /f
reg add "HKLM\SOFTWARE\Microsoft\System Center\2010\Common\DAL" /v "DALInitiateClearPool" /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\HealthService\Parameters" /v "State Queue Items" /t REG_DWORD /d 20480 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\HealthService\Parameters" /v "Persistence Checkpoint Depth Maximum" /t REG_DWORD /d 104857600 /f
reg add "HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Data Warehouse" /v "Command Timeout Seconds" /t REG_DWORD /d 1800 /f
reg add "HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Data Warehouse" /v "Deployment Command Timeout Seconds" /t REG_DWORD /d 86400 /f
## Increase the number of command channels that can be run simultaneously , adjust according to environment (Default 5)
reg add "HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Modules\Global\Command Executer" /v "AsyncProcessLimit" /t REG_DWORD /d 50 /f
## Used to adjust DeltaSync timeout, especially when seeing 29181 events on the MS (default 30)
reg add "HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Config Service" /v "CommandTimeoutSeconds" /t REG_DWORD /d 1800 /f
<#
::: ----------------------
:: Optional entries only needed under certain circumstances, use at own risk
reg add "HKLM\SOFTWARE\Microsoft\System Center\2010\Common\DAL" /v "DALCommandTimeoutSeconds" /t REG_DWORD /d 14400 /f :: Updates SDK timeout
reg add "HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Modules\Global\Command Executer" /v "ProcessQueueMinutes" /t REG_DWORD /d 30 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\HealthService\Parameters" /v "Maximum Global Pending Data Count" /t REG_DWORD /d 40480 /f
reg add "HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Modules\Global\PowerShell" /v "QueueMinutes" /t REG_DWORD /d 30 /f
reg add "HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Modules\Global\PowerShell" /v "ScriptLimit" /t REG_DWORD /d 30 /f

## Used when having 2115 events en masse over an extended period of time
reg add “HKLM\SYSTEM\CurrentControlSet\services\HealthService\Parameters” /v “Thread Pool CLR Max Thread Count Min” /t REG_DWORD /d 512 /f
reg add “HKLM\SYSTEM\CurrentControlSet\services\HealthService\Parameters” /v “Thread Pool CLR Min Thread Count” /t REG_DWORD /d 50 /f
::: ----------------------
#>
## Clear the Health Service Cache
if (Test-Path -Path "$($InstallDir)\Health Service State") {
    Remove-Item -Path "$($InstallDir)\Health Service State" -Recurse -Force
}
## Restart Services
try {
    Start-Service OMSDK,CSHOST,HealthService -Verbose
} catch {
    Write-Error "Failed to start one or more SCOM services, please start them manually."
    exit 100
}
