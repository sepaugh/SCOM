Function Get-SCOMSupportLogs {
## Get Event Logs
#Requires -RunAsAdministrator

# Config
$logs = @( "Application", "System", "Operations Manager" ) # Add Name of the Logfile (System, Application, etc)
$date = $(Get-Date -Format yyyyMMdd)

# We're going to create a temp directory in the user folder for this
$tempDir = "$($env:TEMP)\SCOMSupportLogs-$($date)"
If (Test-Path ($tempDir)) { Remove-Item  $tempDir -Force -Recurse | Out-Null; }
New-Item -ItemType Directory -Path $tempDir -ErrorAction SilentlyContinue | Out-Null;
New-Item -ItemType Directory -Path "$($tempDir)\Config" -ErrorAction SilentlyContinue | Out-Null;

## Get System Information
Write-Host "`nGetting System Info"
Get-ComputerInfo | ConvertTo-JSON | Out-File -FilePath "$($TempDir)\ComputerInfo.json";

## Get SCOM Info
Write-Host "Getting SCOM registry info"
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\Microsoft\Microsoft Operations Manager" | Out-File -FilePath "$($TempDir)\Config\Microsoft Operations Manager Reg.txt" | Out-Null;
Get-ChildItem -Recurse "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Services\HealthService" | Out-File -FilePath "$($TempDir)\Config\HealthService Reg.txt" | Out-Null;
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\Microsoft\System Center" | Out-File -FilePath "$($TempDir)\Config\System Center Reg.txt" | Out-Null;
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\Microsoft\System Center Operations Manager" | Out-File -FilePath "$($TempDir)\Config\System Center Operations Manager Reg.txt" | Out-Null;

Write-Host "Getting .NET and Networking settings"

## Get Schannel Registry Settings
Write-Host "    SCHANNEL"
Get-ChildItem -Recurse "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" | Out-File -FilePath "$($TempDir)\Config\SCHANNEL.txt" | Out-Null;

## Get SSL Config
Write-Host "    SSL"
Get-ChildItem -Recurse "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Control\Cryptography\Configuration\Local\SSL" | Out-File -FilePath "$($TempDir)\Config\SSL.txt" | Out-Null;
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL" | Out-File -FilePath "$($TempDir)\Config\SSL.txt" -Append | Out-Null;

## Get FIPS Config
Write-Host "    FIPS"
Get-ChildItem -Recurse "REGISTRY::HKLM\SYSTEM\CurrentControlSet\Control\LSA\FIPSAlgorithmPolicy" | Out-File -FilePath "$($TempDir)\Config\FIPS.txt" | Out-Null;

## Output DNS Cache
Write-Host "    DNS Cache"
Get-DnsClientCache | Select * | Out-File -FilePath "$($TempDir)\Config\DNSCache.txt" | Out-Null;

## Get .NET Config
Write-Host "    .NET Framework"
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.*" | Out-File -FilePath "$($TempDir)\Config\NETFramework_v2.txt" | Out-Null;
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.*" | Out-File -FilePath "$($TempDir)\Config\NETFramework_v4.txt" | Out-Null;
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\Microsoft\.NETFramework\v2.*" | Out-File -FilePath "$($TempDir)\Config\NETFramework_v2.txt" -Append | Out-Null;
Get-ChildItem -Recurse "REGISTRY::HKLM\SOFTWARE\Microsoft\.NETFramework\v4.*" | Out-File -FilePath "$($TempDir)\Config\NETFramework_v4.txt" -Append | Out-Null;

## Get Cipher Suites
Write-Host "    Cipher Suites"
Get-TlsCipherSuite | ConvertTo-JSON | Out-File "$($TempDir)\Config\CipherSuites.json" | Out-Null;

## Get TCP Settings
Write-Host "    TCP"
Get-NetTCPSetting | Out-File -FilePath "$($TempDir)\Config\TCPSetting.txt" | Out-Null;

## Get NetIP Config
Write-Host "    Net IP"
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
Compress-Archive -Path $TempDir\* -DestinationPath "$($TempDir)\SCOMSupportLogs-$($Env:Computername)-$($date).zip" -CompressionLevel Optimal | Out-Null;

## Cleanup
Get-ChildItem -Path $tempDir -Exclude *.zip | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "`nDone - output logs are located here: $($TempDir)\SCOMSupportLogs-$($Env:Computername)-$($date).zip" -ForegroundColor Green;

## Show user the output file
Start $TempDir
}
Get-SCOMSupportLogs
