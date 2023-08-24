## Use the below to help export a list of objects in each group in SCOM. This will output individual files for each group in the outputPath of your choice. Run the below in PowerShell or the Operations Manager Shell

$groupList = Get-SCOMGroup -DisplayName "*Windows*" # Write in here what name(s) of groups that you want to, or remove "-DisplayName *Windows*" to get all groups
$outputPath = "C:\Temp\" # Change this to location where we can output the results of the query

ForEach ($group in $groupList){
	$groupName = $group.DisplayName
	Write-Host "Getting data for $groupName"
	(Get-SCOMGroup $group).GetRelatedMonitoringObjects() | Convertto-CSV -NoTypeInformation | Out-File -FilePath "$($outputPath)\$($groupName -replace '\\|\/','_').csv" -Force
}
