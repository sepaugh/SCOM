
#Get the SCOM Cmdlets (if not in Operations Manager Shell)
Import-Module OperationsManager

## Get All Windows Computers
Get-SCOMAgent | Select ComputerName,Domain,IPAddress,Version | Format-Table

## Get All Windows Services
Get-SCOMClass -Name "Microsoft.SystemCenter.NTService" | Get-SCOMClassInstance `
    | Select `
        @{L=’Server’;E={$_.Path}}, `
        @{L=’Service Name’;E={$_.Name}}, `
        @{L=’Display Name’;E={$_.DisplayName}}, `
        @{L=’Health Status’;E={$_.HealthState}}, `
        @{L=’Availability Checked’;E={$_.AvailabilityLastModified}} `
    | Sort 'Server' | Format-Table


## Get Windows Process Monitors
Get-SCOMClass -Name "Microsoft.SystemCenter.Process.BaseMonitoredProcess" | Get-SCOMMonitoringObject `
    | Select `
        @{L=’Server’;E={$_.Path}}, `
        @{L=’Process Name’;E={"$($_."[Microsoft.SystemCenter.Process.BaseMonitoredProcess].ProcessName").$($_."[Microsoft.SystemCenter.Process.BaseMonitoredProcess].ProcessNameExtension")"}}, `
        @{L=’Health Status’;E={$_.HealthState}}, `
        @{L=’Availability Checked’;E={$_.AvailabilityLastModified}}, `
        @{L=’Monitor Name’;E={$_.DisplayName}} `
    | Format-Table


## Get All Unix Machines
Get-SCXAgent | Select Name,IPAddress,SSHPort,AgentVersion,UnixComputerType | Format-Table 

Export-CSV -Path C:\Path\FileName.csv
