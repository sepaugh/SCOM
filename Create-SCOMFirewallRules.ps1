<############# 


    The below commands are based on the Microsoft Docs for configuring the Firewall for Operations Manager 2019.

    https://docs.microsoft.com/en-us/system-center/scom/plan-security-config-firewall?view=sc-om-2019

    These commands are to set up the Windows Firewall on the respective machines to use SCOM 2019.

    These commands are provided without warranty and should be tested and vetted by your organization before 
    production deployments. 

    If using a custom SQL Port, make sure to change 1433 to the custom port number.

#############>


<####

Management Servers

####>
#region ManagementServers

## Management Server >> OpsMgr Database
New-NetFirewallRule `
    -DisplayName "SCOM MS to DB" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 1433,135,137,445,49152-65535 `
    -Action Allow 

## Management Server Interconnection <<>>
New-NetFirewallRule `
    -DisplayName "SCOM MS to MS" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 5723,5724 `
    -Action Allow

## Management Server << Network Device
New-NetFirewallRule `
    -DisplayName "SCOM Network Device to MS" `
    -Group "SCOM" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 161,162 `
    -Action Allow

## Management Server >> Reporting Datawarehouse
New-NetFirewallRule `
    -DisplayName "SCOM MS to ReportDW TCP" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 1433,135,445,49152-65535 `
    -Action Allow 

New-NetFirewallRule `
    -DisplayName "SCOM MS to ReportDW UDP" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol UDP `
    -LocalPort 1434,137 `
    -Action Allow

## Management Server ACS << Agent ACS
New-NetFirewallRule `
    -DisplayName "SCOM Audit Collection Services TCP" `
    -Group "SCOM" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 1433 `
    -Action Allow 

New-NetFirewallRule `
    -DisplayName "SCOM Audit Collection Services UDP" `
    -Group "SCOM" `
    -Direction Inbound `
    -Protocol UDP `
    -LocalPort 1434 `
    -Action Allow 
    
## Management Server >> Unix/Linux Agent Discovery and Monitoring
New-NetFirewallRule `
    -DisplayName "SCOM Console Connection" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -Local 1270 `
    -Action Allow 

## Management Server >> Unix/Linux Agent Install/Upgrade/Remove
New-NetFirewallRule `
    -DisplayName "SCOM Console Connection" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 22 `
    -Action Allow 

## Management Server << Operations Console
New-NetFirewallRule `
    -DisplayName "SCOM Console Connection" `
    -Group "SCOM" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 5724 `
    -Action Allow 

## Connected Management Server (Local) >> Connected Management SErver (Connected)
New-NetFirewallRule `
    -DisplayName "SCOM Connected Management Servers" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 5724 `
    -Action Allow

#endregion


<####

Reporting Server

####>
#region reporting
    
## Reporting Server >> Management Server
New-NetFirewallRule `
    -DisplayName "SCOM Reporting to MS" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 5723,5724 `
    -Action Allow

## Reporting Server >> Reporting Server Datawarehouse
New-NetFirewallRule `
    -DisplayName "SCOM Reporting Server TCP" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 1433 `
    -Action Allow

New-NetFirewallRule `
    -DisplayName "SCOM Reporting Server UDP" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol UDP `
    -LocalPort 1434 `
    -Action Allow

#endregion


<####

Gateway Servers

####>
#region gateway

## Gateway >> Management Server
New-NetFirewallRule `
    -DisplayName "SCOM Gateway to MS" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 5723 `
    -Action Allow

#endregion


<####

Windows Clients

####>
#region WindowsAgents

## Windows Agent MANUAL Install/Repair/Update
New-NetFirewallRule `
    -DisplayName "SCOM Microsoft Monitoring Agnet" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 5723 `
    -Action Allow
    
## Windows Agent PUSH Install/Repair/Update <<>>
New-NetFirewallRule `
    -DisplayName "SCOM Microsoft Monitoring Agent" `
    -Group "SCOM" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 5723,135,137,138,139,445,49152-65535 `
    -Action Allow 

New-NetFirewallRule `
    -DisplayName "SCOM Microsoft Monitoring Agent" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 5723,135,137,138,139,445,49152-65535 `
    -Action Allow

## Agent Audit Collection Services Forwarder >> Managment Server ACS Collector
New-NetFirewallRule `
    -DisplayName "SCOM Agent Audit Collection" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 51909 `
    -Action Allow

## Agentless Exception Monitoring Data >> Client to MS Agentless Exception Monitoring File Share
New-NetFirewallRule `
    -DisplayName "SCOM Agentless Exception Monitoring" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 51906 `
    -Action Allow

## Customer Experience Improvement Program >> Management Server Forwarder
New-NetFirewallRule `
    -DisplayName "SCOM Customer Experience Program" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 51907 `
    -Action Allow


#endregion


<####

Operations Console Servers

####>
#region console

## Operations Console >> Management Group
New-NetFirewallRule `
    -DisplayName "SCOM Console Connection" `
    -Group "SCOM" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 5724 `
    -Action Allow 

## Operations Console (Reports) >> SQL Reporting Services
New-NetFirewallRule `
    -DisplayName "SCOM Operations Console Reports" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 80 `
    -Action Allow


## Operations Console >> Catalog Web Service
New-NetFirewallRule `
    -DisplayName "SCOM Console to Web Catalog" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 443 `
    -Action Allow 

#endregion


<### 

Web Console Server

###>
#region WebConsole

## Web Console Server >> Management Server
New-NetFirewallRule `
    -DisplayName "SCOM Web Console to MS" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 5724 `
    -Action Allow
    
## Web Console Browser >> Web Console Server
## This is also for user machines that want to get to the Web Console Server
New-NetFirewallRule `
    -DisplayName "SCOM Browser to Web Console Server" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 80,443 `
    -Action Allow
    
## Web Console for Application Diagnostics >> OpsMgr DB
New-NetFirewallRule `
    -DisplayName "SCOM Web Console App Diag to OpsMgr DB" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 1433,1434 `
    -Action Allow
    
## Web Console for App Advisor >> Reporting DB
New-NetFirewallRule `
    -DisplayName "SCOM Web Console App Advisor to Report DB" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 1433,1434 `
    -Action Allow
    
#endregion


<### 

Third-Party Connector Server

###>
#region 3PConnectors
    
## Connector Framework >> Management Server
New-NetFirewallRule `
    -DisplayName "SCOM Connector Framework to MS" `
    -Group "SCOM" `
    -Direction Outbound `
    -Protocol TCP `
    -LocalPort 51905 `
    -Action Allow

#endregion



### Verify rules were created 
Get-NetFirewallRule -DisplayGroup "SCOM"
