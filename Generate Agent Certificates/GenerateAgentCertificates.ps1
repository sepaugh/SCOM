<#
    .SYNOPSIS
        This script was designed to help with setting up WORKGROUP machines with certificates for SCOM Monitoring

    .DESCRIPTION
        Please run this scrupt from a SCOM Management Server. We will be requesting a new Certificate for a list of servers stored in the script's directory in a "Computers.txt" file, we'll then try to copy it to the server and try to use the MOMCertImport.exe tool to tell the SCOM Agent to use this new certificate.

    .NOTES
        This script assumes:
            - You are running this script as an Administrator
            - Your target servers have a common Local Admin credential
            - The Microsoft Monitoring Agent is already installed on the target machine
            - Network connectivity can be established
            - PSRemoting is allowed to the target
            - That we can access '\\targetServer\C$\'
                - This is so that we can copy the certificate over and try to install

#>

param (
    
    $CertImportTool = "\\ms16\c$\SC 2016 RTM SCOM\SupportTools\AMD64\MOMCertImport.exe",
    $Template = "SCOMCert",
    [switch]$Install

)

[string]$ScriptPath = $PSScriptRoot
$currentPath = $myinvocation.mycommand.definition
[System.Collections.ArrayList]$failedComputers = @()

## Set path to the MOMCertImport.exe
#$certImportTool = "\\ms16\c$\SC 2016 RTM SCOM\SupportTools\AMD64\MOMCertImport.exe"

## Set password for the certificate security while at rest
$certPass = Read-Host "Enter a Password to secure the certficates at rest" -AsSecureString
$credential = New-Object System.Management.Automation.PSCredential('null',$certPass)
$certPassPlain = $credential.GetNetworkCredential().Password #Unfortunately we have to pass the credential to MOMCertImport.exe as plaintext
"`n"

## Set the correct template name
## This will be the actual name of the template to be used to create the SCOM Certificates
#$template = "SCOMCert"

## Make a temporary SCOM directory for the new certificates
$outDir = "$ScriptPath\SCOMCertificates"

If (Test-Path (!($outDir))){
    Mkdir $outDir
} #else { "Path $outDir already exists, moving on"}

## Make a Computers.txt list of all the machines to make certs for
$computerList = Get-Content $ScriptPath\Computers.txt 

$i = 0
ForEach ($computer in $computerList) {
   # update counter and write progress
   $i++
   Write-Progress -activity "Working on: $computer" -status "Machine $i of $($computerList.Count)" -percentComplete (($i / $computerList.Count)  * 100)

    Write-Host "Working on: $computer`n"

    ## Create the certificate for the computer
    Write-Host "    Creating Certificate..." -NoNewline
    Write-Progress -Id 1 -Activity "Creating Certificate" -PercentComplete 20
    try { 
        $null = Get-Certificate -Template $template -SubjectName "CN=$computer" -CertStoreLocation cert:\LocalMachine\My;
        Write-Host "Success" -ForegroundColor Green
    }
    catch {
        Write-Host "Fail" -ForegroundColor Red 
        "`n"
        Write-Error "Exception thrown : $($error[0].exception.message)" 
    }
    
    ## Export the certificate
    Write-Host "    Exporting Certificate..." -NoNewline
    Write-Progress -Id 1 -Activity "Exporting Certificate" -PercentComplete 40
    try { 
        $newCert = Get-ChildItem cert:\LocalMachine\My | Where-Object Subject -eq "CN=$computer" 
        $newCert | Export-PfxCertificate -FilePath $outdir\$computer.pfx -Password $certPass -ChainOption EndEntityCertOnly > $null;
        
        ## Cleanup
        Get-ChildItem cert:\LocalMachine\My | Where-Object Subject -eq "CN=$computer" | Remove-Item

        Write-Host "Success" -ForegroundColor Green
    } 
    catch { 
        Write-Host "Fail" -ForegroundColor Red
        "`n"
        Write-Warning "Exception thrown : $($error[0].exception.message)"         
    }

    ## Try to install new certificate to the target machine
    try {
        if ($Install) {
            ## Test connectivity
            Write-Progress -Id 1 -Activity "Testing Connectivity" -PercentComplete 60
            Write-Host "    Testing connectivity to server..." -NoNewline
            Test-Connection -ComputerName $computer -Count 1 -ErrorAction Stop > $null
            Write-Host "Success" -ForegroundColor Green
        
            ## Copy certificate to remote machine
            Write-Host "    Copy Certificate to server..." -NoNewline
            Test-Path -Path \\$computer\C$\ > $null
            Write-Progress -Id 1 -Activity "Copying certificate to server" -PercentComplete 66
            if (!(Test-Path \\$computer\C$\Temp\SCOMCert)) { mkdir \\$computer\C$\Temp\SCOMCert }
            Copy-Item $outDir\$computer.pfx -Destination \\$computer\C$\Temp\SCOMCert -Force; Write-Host "Success" -ForegroundColor Green
        
            ## Copy MOMCertImport.exe to localmachine
            Write-Progress -Id 1 -Activity "Copying MOMCertImport.exe to server" -PercentComplete 72
            Write-Host "    Copy MOMCertImport.exe to server..." -NoNewline
            Copy-Item $certImportTool -Destination \\$computer\C$\Temp\SCOMCert; Write-Host "Success" -ForegroundColor Green


            ## Try to install the certificate using MOMCertImport
            Write-Host "    Attempting to install Cert..." -NoNewline
            Write-Progress -Id 1 -Activity "Attempting to install the certificate" -PercentComplete 80
        
            $results = Invoke-Command -ComputerName $computer -ScriptBlock {
                Set-Location C:\Temp\SCOMCert;
                & .\MOMCertImport.exe "$Using:computer.pfx" /Password "$Using:certPassPlain"
                #$certConfirmEvent = Get-EventLog -LogName "Operations Manager" -After ((Get-Date).AddMinutes(-2)) | Where-Object {$_.EventID -eq 20053}
            }

            if ($results -match "S.u.c.c.e.s.s") { 
                Write-Host "Success" -ForegroundColor Green
                Write-Host "    Certificate successfully installed!" -ForegroundColor Green 
            }
            else { Write-Host "Certificate installation failed, please try again manually." -ForegroundColor Red }
        
        }
    }
    catch { 
        Write-Host "Fail" -ForegroundColor Red; "`n"
        Write-Warning "$($error[0].exception.message)"
        $failedComputers += @([pscustomobject]@{Computer=$computer; Error=$($error[0].exception.message)})
    } 

    $results = $null
    "`n"
}

## Cleanup

Write-Host "############`n`nAlright! We're all done. Please check this directory for your certificates: $outdir"
Write-Host "`nSome computers failed to deploy, please do these manually:" -ForegroundColor Yellow
$failedComputers | Format-Table

Start $outDir
