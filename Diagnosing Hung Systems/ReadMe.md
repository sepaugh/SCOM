# Trying to diagnose "hung" client systems

This may be a bit of a stretch, and will take some setup, but it may help in figuring out what's going on right before a client system hangs. And by the system hanging, I mean it's responsive to Ping, sometimes the hosted application still works, but you can't RDP to it and we're not getting any alerts. Anything beyond what's outlined here will need to be manually observed on your end. This here is simply something I put together a while back to help diagnose this scenario on domain controllers, but should be able to be used on any Windows client, and is to be used without warranty and at your own peril.

Know that the actual diagnostic tasks will incur additional resource load on the targeted servers when running, this is the process and performance monitor captures specifically.

NOTE - I have not had a chance to fully test this process out, good luck :smile:

## Parts of the process:

  - SCOM Alert Canary
    - A SCOM alert needs to be triggered based on an event in the event log to alert us to incoming issues with system resources -- this may not be the most reliable Canary, but we can set it up anyway. 
    - This alert will be triggered based on Event ID 2004 in the System event log, where Windows diagnoses a low virtual memory condition
    - This alert is disabled by default and will need to be enabled for the affected machines to monitor
    - This alert will need to be configured 

  - Windows Performance Monitor
    - This will be setup on all affected clients using Logman
    - This will run when the alert is triggered up to a specified file size
    - This will need to be manually stopped, if the server does not get restarted

  - Process Monitor (ProcMon)
    - [Process Monitor - Sysinternals | Microsoft Learn](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon)
    - This application will need to be downloaded and stored in the exact same location on all clients that we're testing this on
    - We will also need to have a Procmon configuration file present in the same location on all systems so that we can load it
    - When the alert is triggered, we'll try to start Procmon so it can capture, rather than have it run constantly - although we can set it to do so


# How to set it up

In your SCOM console:
1. Import a Management Pack
    1. I've created a new SCOM Management Pack that contains the alert and diagnostic tasks that need to run
    2. You can simply import this file into your environment and that part will be setup
    3. Download a copy of the "HungSystemDiagnostics.xml" from the repo
      i. Do note that to see any files to download, you'll first need to sign in using the button in the upper right corner of the page
    4. Copy the XML file to one of your SCOM management servers, or wherever you access SCOM through the console
    5. Go to Administration > Management Packs
    6. Right click on 'Management Packs' and select "Import Management Packs…"
    7. Click Add > From Disk
    8. And say No on the popup
    9. Navigate to where the XML file was saved, click OK
    10. Then click Install/Import
    11. When done, you should see a management pack named "HungSystemDiagnostics" in the Installed Management Packs list
		
	
2. Setup Alert Notifications
    1. You'll need to manually setup a new notification for the "Resource Exhausted" alert to go where you want it to go
    2. In the SCOM Console go to Administration > Notifications > Subscriptions
    3. Create a new subscription and provide a recognizable name
    4. Under "Criteria", insert an Expression
        1. Under Criteria, select "Monitors"
        2. Under Operator, select "Equals"
        3. Under Value, click the […] button, search for "Resource Exhaustion" and click OK
      
          ![image](https://github.com/sepaugh/SCOM/assets/9103519/a8daaca9-293c-4ff2-a93c-319d9d5a7a40)
      
        4. Continue to select the subscribers (recipients), and the channel (mode of notification)
        5. When satisfied, create the subscription
    
3. Enable alert for desired servers
    1. The monitor that was created for this test is disabled by default, we will have to turn it on only for those servers we want to try to run this diagnostic on
    2. In the SCOM Console go to Authoring > Management Pack Objects > Monitors
    3. Change the Scope to only "Windows Servers"
    4. Look for: "Resource Exhaustion"
    
    ![image](https://github.com/sepaugh/SCOM/assets/9103519/3b8ad814-7b75-44a0-a48a-8c97df2c967c)

    
    5. Open the properties for this monitor by double-clicking, or by right-clicking and selecting properties
    6. Navigate to the Overrides tab
    7. Click the "Override…" button > For a Specific Object of class…
    
    ![image](https://github.com/sepaugh/SCOM/assets/9103519/aaca49c8-e333-4024-acf4-f6a894f77fee)
    
    7. Find and select the server to enable this rule on (one at a time), click OK
    8. In the Override Properties window, change Enabled to True:
    
    ![image](https://github.com/sepaugh/SCOM/assets/9103519/fae4a833-6399-4ca5-91d7-4c69c1413363)
    
    9. Click OK - repeat for all desired servers
    10. When done, click OK on the Resource Exhaustion Properties window
    11. In a few minutes, your servers should get this new monitor


## On the Client Machine
All actions taken below will need to be performed on all servers that we're trying to diagnose.

1. Create this folder path: `C:\Temp\HungSystemDiagnostics`

> [!IMPORTANT]
> It must be this path as it's hardcoded into the MP - change the MP if you want to change the path

2. Download a copy of "Procmon.exe" from Sysinternals - Process Monitor - Sysinternals | Microsoft Learn
  a. This will be in a .zip folder, extract the contents
3. Download a copy of "ProcmonConfiguration.pmc"
4. Add the .exe and .pmc files to the folder created earlier
5. We now need to create our Windows Performance Monitor counter so that we can capture our data
    - Run the below as an administrator in CMD or PowerShell, this will create out counter template to run later

      ```CMD
      logman.exe create counter HungSystemDiagnostics -f bincirc -v mmddhhmm -max 350 -c "\LogicalDisk(*)\*" "\Memory\*" "\Network Interface(*)\*" "\Netlogon\*" "\Paging File(*)\*" "\PhysicalDisk(*)\*" "\Process(*)\*" "\Processor(*)\*" "\Processor Information(*)\*" "\Redirector\*" "\Server\*" "\System\*" "\Thread(*)\*"   -si 00:00:10
      ```

    - You can confirm the creation of this counter by opening Performance Monitor (PerfMon) on the system, and looking under Data Collector Sets > User Defined, for "HungSystemDiagnostics"
    - Open the properties of this data collector set and check the "Directory" tab, this Root Directory should be where the output will be stored when the job is run
	
	
# How to use it

- If all works like it's supposed to, then when we get a 2004 event in the System event log with the "Microsoft-Windows-Resource-Exhaustion-Detector" source, an alert should be triggered in SCOM automatically, and a notification sent out to interested parties.
- If/Once the alert is triggered, there are two Diagnostic tasks that should be started:
    - Procmon should be started, and will write it's log to the temp directory created earlier: `D:\Temp\HungSystemDiagnostics`
    - Perfmon should be started, and will write to the directory shown earlier in the PerfMon gui (which should be something like `%systemdrive%\PerfLogs\<UserName>`)
- Both of those diagnostic tasks will run for a while, however will cutoff before they get too large 
    - Procmon = 1 GB
    - Perfmon = 350 MB
- By this point, we'll likely have either a system hung scenario, or it will recover enough to extract these logs
- These logs can then be looked at to try and figure out why the system stopped responding

