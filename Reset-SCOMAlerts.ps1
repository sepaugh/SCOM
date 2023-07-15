<# 
- Use of this script is done at your own risk, always ensure to review the code before running it to ensure you are comfortable with doing so.
- This script is provided with no warranty or guarantee of success. 
- This script assumes you have rights to the SCOM environment enough to reset health states and close alerts
- Set the alertName parameter to the name of the alert that you want to close, works best with high numbers of the same alert
- If you want to try to reset ALL alerts, comment out this section where we set the alertList variable: "-Criteria $alertCriteria"
#>

Import-Module OperationsManager

$alertName = "Failed to Connect to Computer" ## Change this to the name of the alert that you want to reset, one at a time only
$alertCriteria = "ResolutionState=0 AND Name='$($alertName)'" ## This sets the Resolution state to "New" (0) and to the alert name specified earlier
$closureComment = "Alert closed via script" ## Set a comment here as to why or how this alert was closed

$alertList = Get-SCOMAlert -Criteria $alertCriteria ## Gets list of alerts meeting above criteria
Write-Host $alertList.Count " Monitors to be reset"

$i = 0 ## Used to indicate progress, leave at zero

ForEach ($alert in $alertList)
{
    $i++
    Write-Progress -activity "Closing alert/resetting health state for '$($alert.Name)' on target '$($alert.MonitoringObjectPath)'" -status "Please wait..." -percentComplete (($i / $alertList.Count)  * 100)
    If ($alert.IsMonitorAlert -eq $false) {
        
        $alert | Resolve-SCOMAlert -Comment $closureComment -Verbose
        
    }
    Else {
        $monitor = Get-SCOMMonitor -id $alert.MonitoringRuleID

        $monitoringObject = Get-SCOMClassInstance -id $alert.MonitoringObjectId

        If (($monitoringObject.HealthState -eq "error") -or ($monitoringObject.HealthState -eq "Warning"))
        {
            $alert.Name
            Write-Information "Performing 'ResetMonitoringState' on target '$($monitoringObject)'"
            $monitoringObject.ResetMonitoringState($monitor)
        }
    }
    Write-Progress -activity "Closing alert '$($alert.Name)' on target '$($alert.MonitoringObjectPath)'" -status "Closed alert #$i of $($alertList.Count)" -percentComplete (($i / $alertList.Count)  * 100)
    
}
Write-Host "Completed - $($alertList.Count) Alerts Closed" -ForegroundColor Green
