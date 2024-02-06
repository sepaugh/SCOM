<####

This script will rebuild the Windows Performance Counters 
on the current machine. 

Make sure to run as a user with administrative privileges.

Run at your own risk.

####> 

# Stop services
Stop-Service pla -Force -Verbose

#Delete old perf files
Write-Host "`nRemoving old perf*009.dat files`n"  -ForegroundColor Yellow

If (Test-Path C:\Windows\System32\perf*009.dat.*) {
    Remove-Item C:\Windows\System32\perf*009.dat.* -Verbose
}

Get-Item C:\Windows\System32\perf*009.dat -Force | Rename-Item -NewName { $_.Name -replace '.dat','.dat.old' } -Verbose -Force
#Get-Item C:\Windows\System32\perf*009.dat.old -Force | Rename-Item -NewName { $_.Name -replace '.dat.old','.dat' } -Verbose -Force ## Use this to restore the old files

# Rebuild Perf Counters
Write-Host "`nRebuilding Performance Counters...`n"  -ForegroundColor Yellow

cd c:\Windows\System32
    lodctr /R 
    lodctr /R # Do it again just in case

cd c:\Windows\SysWOW64
    lodctr /R

# Resync Performance Counters
Write-Host "`nResyncing Performance Counters...`n" -ForegroundColor Yellow

cd c:\Windows\System32\wbem
winmgmt.exe /RESYNCPERF

cd c:\Windows\SysWOW64\wbem
winmgmt.exe /RESYNCPERF

# Wait for it
Start-Sleep -Seconds 5

# Restart Services
Write-Host "`nRestarting Services...`n"  -ForegroundColor Yellow

Start-Service pla -Verbose
Stop-Service Winmgmt -Force -Verbose
Start-Service winmgmt,UALSVC,iphlpsvc,ccmexec -Verbose

"`n"
Write-Warning "We will now reboot the machine. If you do not want to, exit the script!`n"

Pause #Waits for user input on newer PS versions, skips for old

# Restart 
Restart-Computer -Force 

