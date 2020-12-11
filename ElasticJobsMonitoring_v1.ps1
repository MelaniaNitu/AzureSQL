##  =========================================================================
##    Insert Credentials, SQL Server Details & SMTP server Details
##  =========================================================================

$server = '.database.windows.net' # Set the name of the server
$jobDB = ''   # Set the name of the job database you wish to test
$user = '' # Set the login username you wish to use
$passw = '' # Set the login password you wish to use
$FromEmail = 'xxxxxxxxxxxx@yahoo.com' # "from" field's account must match the smtp server domain 
$FromEmailPassw = '' # use app/server access token - it works with account passw
$ToEmail = 'xxxxxxxxxxxx@yyyyy.com'
$SMTPServer = "smtp.mail.yahoo.com" #insert SMTP server
$SMTPPort = "587" # or port 465
$StorageAccountName = ''
$StorageContainerName = ''

##  =========================================================================
##       Section to mask credentials during remote sessions 
##  =========================================================================
## To mask user credentials during remote sessions, uncomment below code section 
## and password will be asked during execution. This approach is not recomended for automation tasks.

<#
$credentials = Get-Credential -Message "Credentials to test connections to the database (optional)"  
$user = $credentials.GetNetworkCredential().username
$passw = $credentials.GetNetworkCredential().password
#>

$todaydate = Get-Date -Format yyyyMMddTHHmmssffff 
$output_file = "failed_jobs_$todaydate.log"
$FormatEnumerationLimit = -1


if (Test-Path $output_file) {
  Remove-Item $output_file
}

$params = @{
  'serverInstance' =  $server
  'database' = $jobDB
  'username' = $user
  'password' = $passw
  'outputSqlErrors' = $true
}


Invoke-SqlCmd @params
$params.query = "SELECT * FROM jobs.job_executions WHERE lifecycle = 'Failed' ORDER BY start_time DESC" 
Invoke-SqlCmd @params | Format-Table -Wrap -Autosize | out-File -filepath $output_file 


if((Get-Content $output_file).Length -ne 0)
{
  
   'Failed Jobs Found. Sending email...'

    function Send-ToEmail([string]$email){

        $message = new-object Net.Mail.MailMessage;
        $message.From = $FromEmail;
        $message.To.Add($email);
        $message.Subject = "Alert Notification - ElasticJob Failed";
        $time = Get-Date
        $message.Body = @" 

##############################################
                  ALERT NOTIFICATION                                                                               
##############################################

Note: You are receiving this email because Failed Elastic Jobs were identified for your database.

Issue: Elastic Job Failed

Description: The attached file contains a list with Failed Jobs for below resource:

Subscription ID: $((Get-AzContext).Subscription.id) 
Impacted Database: $($params.database)
On Server: $($params.serverInstance)

File generated at $($time.ToUniversalTime()) UTC time.
"@
        
       
        $att = new-object Net.Mail.Attachment($output_file)
        $message.Attachments.Add($output_file)
	    $smtp = new-object Net.Mail.SmtpClient($SMTPServer, $SMTPPort); 
        $smtp.EnableSSL = $true;
        $smtp.Credentials = New-Object System.Net.NetworkCredential($FromEmail, $FromEmailPassw);
        $smtp.send($message);
        $att.Dispose()
        write-host "=====================" ; 
        write-host "     Mail Sent" ; 
        write-host "=====================" ; 
    }
 
    Send-ToEmail  -email $ToEmail;

}else{

   'No failed jobs.'
}


##  =========================================================================
##             Login when running from a Runbook
##  =========================================================================
## Enable this code section when running from Azure Runbook
## Get the connection "AzureRunAsConnection" when run from automation account


<#
$connection = Get-AutomationConnection -Name AzureRunAsConnection
Connect-AzAccount `
    -ServicePrincipal `
    -Tenant $connection.TenantID `
    -ApplicationId $connection.ApplicationID `
    -CertificateThumbprint $connection.CertificateThumbprint

"Login successful.."
#>


# Get key to storage account
$acctKey = (Get-AzStorageAccountKey -Name generals -ResourceGroupName general).Value[0]

# Map to the reports BLOB context
$storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $acctKey

# Copy the file to the storage account
Set-AzStorageBlobContent -File $output_file -Container StorageContainerName -BlobType "Block" -Context $storageContext -Verbose




