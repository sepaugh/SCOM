<#
.SYNOPSIS
    This script rebuilds the Windows Performance Counters on the current machine.

.DESCRIPTION
    This script stops the necessary services, deletes old performance counter files, rebuilds the performance counters, resyncs them, and restarts the services. It also prompts the user to restart the computer to apply the changes.

.NOTES
    Make sure to run this script as a user with administrative privileges.
    Run at your own risk.

#>

# Stop services
Stop-Service pla -Force -Verbose

#Delete old perf files
Write-Host "`nRemoving old perf*009.dat files`n"  -ForegroundColor Yellow

If (Test-Path C:\Windows\System32\perf*009.dat.*) {
    Remove-Item C:\Windows\System32\perf*009.dat.* -Verbose
}

Get-Item C:\Windows\System32\perf*009.dat -Force | Rename-Item -NewName { $_.Name -replace '.dat','.dat.old' } -Verbose -Force
#Get-Item C:\Windows\System32\perf*009.dat.old -Force | Rename-Item -NewName { $_.Name -replace '.dat.old','.dat' } -Verbose -Force ## Use this to restore the old files

# Search for services that have a Performance subkey, locate the registry key, and remove specified values
Write-Host "`nRemoving values from Performance subkeys for services that have it`n" -ForegroundColor Yellow

$services = Get-ChildItem -Path "HKLM:\System\CurrentControlSet\Services"

foreach ($service in $services) {
    $performanceKeyPath = "HKLM:\System\CurrentControlSet\Services\$($service.PSChildName)\Performance"
    if (Test-Path $performanceKeyPath) {
        Remove-ItemProperty -Path $performanceKeyPath -Name "First Counter" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $performanceKeyPath -Name "First Help" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $performanceKeyPath -Name "Last Counter" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $performanceKeyPath -Name "Last Help" -ErrorAction SilentlyContinue
    }
}

# Rebuild Perf Counters
Write-Host "`nRebuilding Performance Counters...`n"  -ForegroundColor Yellow

cd c:\Windows\System32
    lodctr /R 
    lodctr /R # Do it again just in case

cd c:\Windows\SysWOW64
    lodctr /R
    lodctr /R # Do it again just in case
    
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

Restart-Service -Name winmgmt,pla -Force -PassThru -Verbose

"`n"

# Prompt user to restart
Write-Warning "It is recommended to reboot the machine to apply changes.`n"

function Prompt-Restart {
    $choice = Read-Host "Do you want to restart the computer now? (Yes or No/N)"
    
    switch ($choice.ToUpper()) {
        'YES' {
            Write-Host "Restarting the computer..."
            Restart-Computer -Force -Confirm
        }
        'NO' {
            Write-Host "Exiting without restarting."
        }
        'N' {
            Write-Host "Exiting without restarting."
        }
        default {
            Write-Error "Invalid input. Please enter Yes or No/N."
            Prompt-Restart
        }
    }
}

# Call the function
Prompt-Restart


