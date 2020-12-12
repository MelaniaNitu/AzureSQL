##  =========================================================================
##                Schedule Commands for Client Machines 
##  =========================================================================
## To schedule script execution in background, please see below options

#insert parameter values
$script = 'script.ps1' # insert script path
$Time= "MM/DD/YYYY HH:MM" # insert desired start time for schedule
$jobName = ''#insert desired job name


# display all scheduled jobs
Get-ScheduledJob

# add new job to run at schedule
Register-ScheduledJob -Name $jobName -FilePath $script -Trigger (New-JobTrigger -Once -At $Time `
    -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration ([TimeSpan]::MaxValue))

# command to remove a scheduled job
Unregister-ScheduledJob $jobName

