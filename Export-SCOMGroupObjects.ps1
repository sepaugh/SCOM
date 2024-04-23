## Use the below to help export a list of objects in each group in SCOM. This will output individual files for each group in the outputPath of your choice. Run the below in PowerShell or the Operations Manager Shell
$groupList = Get-SCOMGroup -DisplayName "*Windows*" # Write in here what name(s) of groups that you want to, or remove "-DisplayName *Windows*" to get all groups
$tempDir = "$($env:TEMP)\MSSupport-SCOMGroupExport-$($date)"
If (Test-Path ($tempDir)) { Remove-Item  $tempDir -Force -Recurse | Out-Null; }
New-Item -ItemType Directory -Path $tempDir -ErrorAction SilentlyContinue | Out-Null;

ForEach ($group in $groupList){
	$groupName = $group.DisplayName
	Write-Host "Getting data for $groupName"
	(Get-SCOMGroup $group).GetRelatedMonitoringObjects() | Convertto-CSV -NoTypeInformation | Out-File -FilePath "$($tempDir)\$($groupName -replace '\\|\/','_').csv" -Force
}

## Compress and Archive results
Write-Host "`nArchiving output"
Compress-Archive -Path $TempDir\* -DestinationPath "$TempDir\MSSupport-SCOMGroupExport-$($Env:Computername)-$($date).zip" -CompressionLevel Optimal | Out-Null;

## Open Temp Directory
Start $TempDir
