Function Get-SCOMSupportLogs {
## Get Event Logs
#Requires -RunAsAdministrator

# Config
$logs = @( "Application", "System", "Operations Manager" ) # Add Name of the Logfile (System, Application, etc)
$date = $(Get-Date -Format yyyyMMdd)

# We're going to create a temp directory in the user folder for this
$tempDir = "$($env:TEMP)\SCOMSupport-$($date)"
If (Test-Path ($tempDir)) { Remove-Item  $tempDir -Force -Recurse | Out-Null; }
New-Item -ItemType Directory -Path $tempDir -ErrorAction SilentlyContinue | Out-Null;

## Get System Information
Write-Host "`nGetting System Info"
Get-ComputerInfo | ConvertTo-JSON | Out-File -FilePath "$($TempDir)\ComputerInfo.json";

Write-Host "`nGetting TCP,IP,Schannel,CipherSuite settings"

## Get Schannel Registry Settings
Get-ChildItem -Recurse "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" | Out-File -FilePath "$($TempDir)\Config\SCHANNEL.txt" | Out-Null;

## Get SSL Config
Get-ChildItem -Recurse "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Control\Cryptography\Configuration\Local\SSL" | Out-File -FilePath "$($TempDir)\Config\SSL.txt" | Out-Null;
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL" | Out-File -FilePath "$($TempDir)\Config\SSL.txt" -Append | Out-Null;

## Get FIPS Config
Get-ChildItem -Recurse "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Control\LSA\FIPSAlgorithmPolicy" | Out-File -FilePath "$($TempDir)\Config\FIPS.txt" | Out-Null;

## Output DNS Cache
Get-DnsClientCache | Select * | Out-File -FilePath "$($TempDir)\Config\DNSCache.txt" | Out-Null;

## Get .NET Config
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727" | Out-File -FilePath "$($TempDir)\Config\NETFramework_v2.0.50727.txt" | Out-Null;
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319" | Out-File -FilePath "$($TempDir)\Config\NETFramework_v4.0.30319.txt" | Out-Null;
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\Microsoft\.NETFramework\v2.0.50727" | Out-File -FilePath "$($TempDir)\Config\NETFramework_v2.0.50727.txt" -Append | Out-Null;
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" | Out-File -FilePath "$($TempDir)\Config\NETFramework_v4.0.30319.txt" -Append | Out-Null;

## Get Cipher Suites
Get-TlsCipherSuite | ConvertTo-JSON | Out-File "$($TempDir)\Config\CipherSuites.json" | Out-Null;

## Get TCP Settings
Get-NetTCPSetting | Out-File -FilePath "$($TempDir)\Config\TCPSetting.txt" | Out-Null;

## Get NetIP Config
Get-NetIPConfiguration -Detailed | Out-File -FilePath "$($TempDir)\Config\NetIPConfig.txt" | Out-Null;

# Grab the event log files and export
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
Compress-Archive -Path $TempDir\* -DestinationPath "$($TempDir)\SCOMSupport-EventLogs-$($Env:Computername)-$($date).zip" -CompressionLevel Optimal | Out-Null;

## Cleanup
Get-ChildItem -Path $tempDir -Exclude *.zip | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "`nDone - output logs are located here: $($TempDir)\SCOMSupport-EventLogs-$($Env:Computername)-$($date).zip" -ForegroundColor Green;

## Show user the output file
Start $TempDir
}
Get-SCOMSupportLogs
