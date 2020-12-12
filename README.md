# Automate and Send Alerts for Elastic Jobs Failures


Alerts can be sent for any particular state of an elastic job. This script addresses the case of 'Failed' jobs, however the solution can be easily extended to other scenarios. The script can be executed on client machines in background on a schedule or in Azure Automation Runbook. If failed jobs are identified, email notifications are sent, with an attachment of a log file containing only the failed jobs. 

This repository contains a PowerShell script that filters job executions based on their status and sends the output to a log file, that is further sent as an attachment in a notification email and in the same time the log file is stored in an Azure Storage Account for further reference. 

The jobs are filtered with the below T-SQL, that can be modified as per the requirements:

```
SELECT * FROM jobs.job_executions WHERE lifecycle = 'Failed' ORDER BY start_time DESC
```

The email functionality can be leveraged through any Simple Mail Transfer Protocol server. The proposed script is using smtp.mail.yahoo.com on port 587. 

# Running automation 

## OPTION#1 
Run the script on schedule in background on client machine

```
##  =========================================================================
##                Schedule Commands for Client Machines 
##  =========================================================================
## To schedule script execution in background, please see below options

#insert parameter values
$script = 'script.ps1' # insert script path
$Time= 'MM/DD/YYYY HH:MM' # insert desired start time for schedule
$jobName = 'Job1'#insert desired job name


# display all scheduled jobs
Get-ScheduledJob

# add new job to run at schedule
Register-ScheduledJob -Name $jobName -FilePath $script -Trigger (New-JobTrigger -Once -At $Time `
    -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration ([TimeSpan]::MaxValue))

# command to remove a scheduled job
Unregister-ScheduledJob $jobName
```

## OPTION#2
Run the script from Azure Runbook

* Create a new Automation Account as described [here](https://docs.microsoft.com/en-us/azure/automation/automation-create-standalone-account#create-a-new-automation-account-in-the-azure-portal) and make sure you choose "YES" for option "Create Azure Run As Account".

* Import the following Azure Modules by browsing the gallery: Az.Accounts (≥ 2.2.2), Az.Storage, Az.Automation
             
* Create a runbook to run the script and make sure you choose Powershell runbook type.

* Add the following login section when connecting from a Runbook        

```
##  =========================================================================
##             Login when running from a Runbook
##  =========================================================================
## Enable this code section when running from Azure Runbook
## Get the connection "AzureRunAsConnection" when run from automation account

$connection = Get-AutomationConnection -Name AzureRunAsConnection
Connect-AzAccount `
    -ServicePrincipal `
    -Tenant $connection.TenantID `
    -ApplicationId $connection.ApplicationID `
    -CertificateThumbprint $connection.CertificateThumbprint

"Login successful..."

```

* Schedule task

For a detailed overview of script functionalities, please check [this blogpost](https://techcommunity.microsoft.com/t5/azure-database-support-blog/automate-and-send-alerts-for-elastic-jobs-failures/ba-p/1981457).

Contributions and suggestions are welcomed. 



