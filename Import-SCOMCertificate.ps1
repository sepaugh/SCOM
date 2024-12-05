<#
.SYNOPSIS
This script imports a selected certificate into the SCOM (System Center Operations Manager) configuration.

.DESCRIPTION
The script allows the user to select a certificate from the local machine's certificate store, validates the selected certificate against specific criteria, and then imports the certificate into the SCOM configuration by updating the registry and restarting the HealthService.

.PARAMETER None
This script does not take any parameters.

.EXAMPLE
.\Import-SCOMCertificate.ps1
This command runs the script and opens a GUI for selecting and importing a certificate.

.NOTES
Author: Lorne Sepaugh
Date: 2023-10-05
Version: 1.0

#>

$ErrorActionPreference = 'SilentlyContinue'

# Get the script start time
$scriptStartTime = Get-Date

# Certificate Store to pull from
$certificates = Get-ChildItem -Path Cert:\LocalMachine\My

# Load the Windows Forms assembly
Add-Type -AssemblyName System.Windows.Forms

# Create a new form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Select Certificate'
$form.Size = New-Object System.Drawing.Size(600, 300)

# Create a list view to display certificates
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(10, 10)
$listView.Size = New-Object System.Drawing.Size(570, 200)
$listView.View = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true

# Add columns to the list view
$listView.Columns.Add("Friendly Name", 150)
$listView.Columns.Add("Subject", 150)
$listView.Columns.Add("Issuer", 150)
$listView.Columns.Add("Valid From", 100)
$listView.Columns.Add("Valid To", 100)

# Map for storing certificate objects
$certMap = @{}

# Add certificate details to the list view
$certificates | ForEach-Object {
    $item = New-Object System.Windows.Forms.ListViewItem($_.FriendlyName)
    $item.SubItems.Add($_.Subject)
    $item.SubItems.Add($_.Issuer)
    $item.SubItems.Add($_.NotBefore.ToString())
    $item.SubItems.Add($_.NotAfter.ToString())

    # Add the ListView item to the list view
    $listView.Items.Add($item)

    # Map the item to the certificate
    $certMap[$item] = $_
}

# Add the list view to the form
$form.Controls.Add($listView)

# Initialize selectedCert variable
$selectedCert = $null

# Create a button to close the form
$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point(250, 215)
$button.Size = New-Object System.Drawing.Size(75, 23)
$button.Text = 'OK'
$button.Add_Click({
    if ($listView.SelectedItems.Count -gt 0) {
        $selectedItem = $listView.SelectedItems[0]
        $global:SelectedCert = $certMap[$selectedItem]
        #Write-Host "Debug: Selected Item is $selectedItem"
        #Write-Host "Debug: Certificate is $global:SelectedCert"
    }
    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Close()
})
$form.Controls.Add($button)

# Show the form as a modal dialog
$form.ShowDialog()
# Ensure the form is disposed properly
$form.Dispose()

# Capture the selected certificate and display its properties
if ($global:SelectedCert) {

    # Validate the selected certificate
    $errors = @()

    # Check Subject
    $computerName = [System.Net.Dns]::GetHostName()
    if ($global:SelectedCert.Subject -notmatch "CN=$computerName") {
        $errors += "Subject must be 'CN=$computerName'."
    }

    # Check Key Usage
    if (-not $global:SelectedCert.HasPrivateKey) {
        $errors += "Private key is required."
    }
    if ($global:SelectedCert.SignatureAlgorithm.FriendlyName -ne "sha256RSA") {
        $errors += "Hash algorithm must be SHA256."
    }
    if ($global:SelectedCert.PublicKey.Key.KeySize -lt 2048) {
        $errors += "Key length must be at least 2048."
    }
    if (-not ($global:SelectedCert.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Key Usage" } | ForEach-Object { $_.Format(0) } | Where-Object { $_ -match "Digital Signature, Key Encipherment" })) {
        $errors += "Key usage must include Digital Signature and Key Encipherment."
    }
    
    # Check Enhanced Key Usage
    $ekuOids = ($global:SelectedCert.Extensions | Where-Object { $_.Oid.FriendlyName -eq "Enhanced Key Usage"}).EnhancedKeyUsages.Value
    if ($ekuOids -notcontains "1.3.6.1.5.5.7.3.1" -or $ekuOids -notcontains "1.3.6.1.5.5.7.3.2") {
        $errors += "Enhanced Key Usage must include both`n    Server Authentication (1.3.6.1.5.5.7.3.1)`n    Client Authentication (1.3.6.1.5.5.7.3.2)."
    }

    # Check Compatibility Settings
    if ($global:SelectedCert.Version -lt 3) {
        $errors += "Certificate must be compatible with Windows Server 2003 or newer."
    }

    # Check Cryptography Settings
    if ($global:SelectedCert.PublicKey.Oid.FriendlyName -ne "RSA") {
        $errors += "Algorithm name must be RSA."
    }

    # Display errors if any
    if ($errors.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "The selected certificate does not meet the following requirements, the script will exit:`n`n" + ($errors -join "`n"),
            "Certificate Validation Failed",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit
    } else {
        $confirmation = [System.Windows.Forms.MessageBox]::Show(
            "The selected certificate appears to meet all requirements. Continue with selected cert?`n
Friendly Name: $($global:SelectedCert.FriendlyName)
Subject: $($global:SelectedCert.Subject)
Issuer: $($global:SelectedCert.Issuer)
Valid From: $($global:SelectedCert.NotBefore)
Valid To: $($global:SelectedCert.NotAfter)",
            "Certificate Validation Passed",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
    }

    # If the user confirms, proceed with the certificate import
    if ($confirmation -eq [System.Windows.Forms.DialogResult]::Yes) {

        # Split the string into 2-character chunks
        $chunks = $($global:SelectedCert.SerialNumber) -split '(.{2})' -ne ''

        # Reverse the chunks
        $reversedChunks = [System.Collections.ArrayList]::new()
        foreach ($chunk in $chunks) {
            [void]$reversedChunks.Add($chunk)
        }
        $reversedChunks.Reverse()

        # Join the reversed chunks with a space
        $reversedString = ($reversedChunks -join ' ')

        # Convert to binary bytes
        $byteArray = @()
        foreach ($chunk in $reversedChunks) {
            $byteArray += [Convert]::ToByte($chunk, 16)
        }

        # Display the selected certificate properties to the user
        Write-Host @"
Selected Certificate:
Friendly Name: $($global:SelectedCert.FriendlyName)
Subject: $($global:SelectedCert.Subject)
Issuer: $($global:SelectedCert.Issuer)
Valid From: $($global:SelectedCert.NotBefore)
Valid To: $($global:SelectedCert.NotAfter)
Thumbprint (ChannelCertificateHash): $($global:SelectedCert.Thumbprint)
Serial Number: $($global:SelectedCert.SerialNumber)
Serial Number (Mirrored): $reversedSerialNumber
"@

        # Set the registry path
        $registryPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Operations Manager\3.0\Machine Settings"

        # Set the registry values
        New-ItemProperty -Path $registryPath -Name "ChannelCertificateSerialNumber" -Value ([Byte[]]$byteArray) -Type Binary -Force -Verbose
        New-ItemProperty -Path $registryPath -Name "ChannelCertificateHash" -Value $global:SelectedCert.Thumbprint -Force -Verbose

        # Restart the HealthService
        $serviceName = "HealthService"

        # Start the restart service command as a background job
        $job = Start-Job -ScriptBlock {
            Restart-Service -Name $using:serviceName -Force
        }

        # Function to show progress bar
        function Show-ProgressBar {
            param (
                [int]$duration = 30,
                [string]$text = 'Waiting for the "' + $($serviceName) + '" service to restart...'
            )

            $startTime = Get-Date
            $endTime = $startTime.AddSeconds($duration)

            # Monitor job and update progress bar
            while ($true) {
                $elapsedTime = (Get-Date) - $startTime
                $percentComplete = [int]($elapsedTime.TotalSeconds / $duration * 100)

                Write-Progress -Activity $text -Status "Restarting Service..." -PercentComplete $percentComplete

                if ($job.State -in 'Completed', 'Failed', 'Stopped') {
                    Start-Sleep -Seconds 5
                    Write-Progress -Activity $text -Status "Restarting Service..." -Completed
                    break
                }

                if ($elapsedTime.TotalSeconds -ge $duration) {
                    Write-Progress -Activity $text -Status "Restarting Service..." -Completed
                    break
                }

                Start-Sleep -Seconds 1
            }
        }

        # Show the progress bar while waiting for the job
        Show-ProgressBar -duration 30 -text 'Waiting for HealthService to restart...'

        # Clean up the job if it is still running
        if ($job.State -ne 'Completed') {
            Stop-Job -Job $job
            Remove-Job -Job $job
        }

        If ((Get-Service HealthService).Status -ne 'Running') {
            Write-Error "Failed to restart the HealthService. Please check the Operations Manager event log for more information."
            exit
        } else {
            Write-Host "HealthService has been restarted. Checking the Operations Manager event log for certificate import status..."
        }

        # Check the Operations Manager event log for specific event IDs related to certificate import
        $logName = "Operations Manager"
        $EventIds = @(20049, 20050, 20052, 20053, 20066, 20069, 20077)

        # Function to get the latest event log entry
        function Get-LatestEventLogEntry {
            param (
                [string]$logName,
                [int[]]$eventIds
            )
            
            $filter = @{
                LogName = $logName
                Id = $eventIds
                StartTime = $scriptStartTime
            }
            
            Get-WinEvent -FilterHashtable $filter -MaxEvents 1 | Sort-Object TimeCreated -Descending
        }

        # Check for the latest success event
        $latestEvent = Get-LatestEventLogEntry -logName $logName -eventIds $EventIds

        # Switch on the event ID to display the appropriate message to the user
        Switch ($latestEvent.ID) {
            '' {
                Write-Host "No events related to certificates found recently in the Operations Manager log, there may've been an issue during import. Please try again."
            }
            20053 {
                Write-Host "Certificate import was successful.`n Event ID: $($latestEvent.ID)`n Message: $($latestEvent.Message)" -ForegroundColor Green
            }
            default {
                Write-Error "There were issues with the certificate import:`n Event ID: $($latestEvent.ID)`n Message: $($latestEvent.Message)"
            }
        }

    } ## End of if ($confirmation -eq [System.Windows.Forms.DialogResult]::Yes)
    else {
        Write-Warning "Certificate selection cancelled. Exiting..."
    }

} ## End of if ($global:SelectedCert) from the cert picker popup
else {
    Write-Warning "No certificate selected. Exiting..."
}