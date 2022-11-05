## This script will aid in resetting stuck monitors that cannot be reset through the console. 
## This will check all systems in the environment and reset the monitor listed below 
## Original Source: https://www.catapultsystems.com/blogs/scom-monitor-reset-script/

$ManagementServer = "MS007"
$MonitorName = "Microsoft.SystemCenter.Agent.HealthService.PrivateBytesThreshold"

# Load OpsMgr Module
if(@(get-module | where-object {$_.Name -eq "OperationsManager"}  ).count -eq 0) {
    Import-Module OperationsManager -ErrorVariable err -Force
}

# Execute script
New-SCOMManagementGroupConnection -ComputerName $ManagementServer
$Monitors = Get-SCOMMonitor -ComputerName $ManagementServer | where {$_.Name -eq $MonitorName}

foreach ($Monitor in $Monitors) {
     get-scomclass -name $Monitor.target.identifier.path |
     Get-SCOMClassInstance | where {$_.HealthState.value__ -gt 1} |
     For-Each {$_.ResetMonitoringState($Monitor)}
}
