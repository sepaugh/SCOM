	Function Get-MSSupportEventLogs {
	## Get Event Logs
	#Requires -RunAsAdministrator
	
	# Config
	$logs = @( "Application", "System", "Operations Manager" ) # Add Name of the Logfile (System, Application, etc)
	$date = $(Get-Date -Format yyyyMMdd)
	
	# We're going to create a temp directory in the user folder for this
	$tempDir = "$($env:TEMP)\MSSupport-$($date)"
	If (Test-Path ($tempDir)) { Remove-Item  $tempDir -Force -Recurse | Out-Null; }
	New-Item -ItemType Directory -Path $tempDir -ErrorAction SilentlyContinue | Out-Null;
	
	# Grab the log files and export
	ForEach ($logFileName in $logs) {
	    If(Get-WinEvent -LogName $logFileName -ErrorAction SilentlyContinue | Select -First 1) {
	    
	    Write-Host "Exporting Event Log '$($logFileName)'"
	
	    #Create CSV
	    Get-WinEvent -LogName "$($logFileName)" |
	        Select-Object -Property @{n = 'Level'; e = { $_.LevelDisplayName }}, @{n = 'EventID'; e = { $_.ID }}, @{n = 'Source'; e = { $_.ProviderName }}, @{n = 'Date and Time'; e = { $_.TimeCreated }}, @{n = 'Message'; e = { $_.Message }} -First 10000 |
	        Export-Csv -Path "$($tempDir)\$(($logFileName.Replace("/","_"))).csv" -NoClobber -NoTypeInformation
	
	    # Create EVTx file with metadata
	    wevtutil export-log "$($logFileName)" "$($tempDir)\$(($logFileName.Replace("/","_"))).evtx" # Export log
	    wevtutil archive-log "$($tempDir)\$(($logFileName.Replace("/","_"))).evtx" /locale:en-US # Generate metadata
	    
	    } 
	    else{
	        Write-Warning "The '$($logFileName)' log was not found on this machine"
	    }
	}
	
	## Compress and Archive results
	Write-Host "`nArchiving output"
	Compress-Archive -Path $TempDir\* -DestinationPath "$TempDir\MSSupport-EventLogs-$($Env:Computername)-$($date).zip" -CompressionLevel Optimal | Out-Null;
	
	## Cleanup
	Get-ChildItem -Path $tempDir -Exclude *.zip | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
	Write-Host "`nDone - output logs are located here: $TempDir\MSSupport-EventLogs-$($Env:Computername)-$($date).zip" -ForegroundColor Green;
	
	## Show user the output file
	Start $TempDir
	}
	Get-MSSupportEventLogs
