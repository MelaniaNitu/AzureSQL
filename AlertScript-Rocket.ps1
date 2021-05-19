##  ==============================================================================
##  This powershell script is sending email alerts when temperature of the 
##  employees goes over a certain threshold. The email includes an attachment
##  with report of employees at risk details an location to monitor spreadability.
##  Report is sent in email body as HTML as well.
##  ==============================================================================


##  =========================================================================
##    Insert Credentials, SQL Server Details & SMTP server Details
##  =========================================================================

$server = '.database.windows.net' # Set the name of the server
$database = ''
$user = '' # Set the login username you wish to use
$passw = '' # Set the login password you wish to use
$FromEmail = '' # "from" field's account must match the smtp server domain 
$FromEmailPassw = '' # use app/server access token - it works with account passw
$ToEmail = ''
$SMTPServer = "smtp.mail.yahoo.com" #insert SMTP server
$SMTPPort = "587" # or port 465

##  =========================================================================
##       Section to mask credentials during remote sessions 
##  =========================================================================
## To mask user credentials during screen sharing sessions, uncomment below code section 
## and password will be asked during execution. This approach is not recomended for automation tasks.

<#
$credentials = Get-Credential -Message "Credentials to test connections to the database (optional)"  
$user = $credentials.GetNetworkCredential().username
$passw = $credentials.GetNetworkCredential().password
#>


$time = Get-Date
[PSCustomobject]$TxtToArray

$todaydate = Get-Date -Format yyyyMMddTHHmmssffff 
$output_file = "C:\users\menitu\desktop\employees_at_risk_$todaydate.csv"
$FormatEnumerationLimit = -1

$params = @{
  'serverInstance' =  $server
  'database' = $db
  'username' = $user
  'password' = $passw
  'outputSqlErrors' = $true
}

Invoke-SqlCmd @params
$params.query = "SELECT * FROM employees_records WHERE COrTemp > 37"  #modify the T-SQL as per your needs
Invoke-SqlCmd @params | export-csv -path $output_file 

$TxtToArray = Get-Content $output_file

$Results = foreach( $Line in $TxtToArray ){

    IF( $TxtToArray.IndexOf($Line) -gt 1){
        $line = $line -replace '"',''
        
        [array]$item = $Line.Split(",")
       
           New-Object -TypeName psobject -Property @{
           
            Username       = $item[0]
            Country         = $item[1]
            Building = $item[2]
            Age    = $item[3]
            Vaccinated = $item[4]
            Date = $item[5]
            DeviceClient = $item[6]
            UserID = $item[7]
            AmbientTemp = $item[8]
            CorrectedTemp = $item[9]
            }
            }
        }

        $Table_Result = $Results | ConvertTo-Html -As Table -Fragment -Property Username, Building,Age,Vaccinated,Date,DeviceClient,UserID,AmbientTemp,CorrectedTemp
        $time = $time.ToUniversalTime()
        $bodyRaw = @" 
        <style>
            h1 {
                font-family: Arial, Helvetica, sans-serif;
                color: #e68a00;
                font-size: 28px;
            }
        
            h2 {
        
                font-family: Arial, Helvetica, sans-serif;
                color: #000099;
                font-size: 16px;
        
            }
           
            
           table {
                font-size: 12px;
                border: 0px; 
                font-family: Arial, Helvetica, sans-serif;
            } 
            
            td {
                padding: 4px;
                margin: 0px;
                border: 0;
            }
            
            th {
                background: #395870;
                background: linear-gradient(#49708f, #293f50);
                color: #fff;
                font-size: 11px;
                text-transform: uppercase;
                padding: 10px 15px;
                vertical-align: middle;
            }
        
            tbody tr:nth-child(even) {
                background: #f0f0f2;
            }
        
            alert {
                padding: 20px;
                background-color: #f44336; /* Red */
                color: white;
                margin-bottom: 15px;
        }
        
        </style>
        <p style="padding: 20px;background-color: #f44336; /* Red */;color: white;margin-bottom: 15px;"> ALERT NOTIFICATION </p>
        <p></p>
        
        <h2>Note: You are receiving this email because employees at risk were identified in your company.</h2>
        <p></p>
        
        <h2>Description: The attached file contains a list with identified employees at risk.<h2>
        <p></p>
        
        
        $Table_Result
        <p></p>
        
        <p>
        File generated at $time UTC time.
        </p>
"@        


if((Get-Content $output_file).Length -ne 0)
{
  
   'Found employees at risk. Sending alert...'

    function Send-ToEmail([string]$email){

        $message = new-object Net.Mail.MailMessage;
        $message.IsBodyHtml = $true
        $message.From = $FromEmail;
        $message.To.Add($email);
        $message.Subject = "Alert Notification - Employees at risk";
        $time = Get-Date
        $message.Body = $bodyRaw
        
       
        $att = new-object Net.Mail.Attachment($output_file)
        $message.Attachments.Add($output_file)
	    $smtp = new-object Net.Mail.SmtpClient($SMTPServer, $SMTPPort); 
        $smtp.EnableSSL = $true;
        $smtp.Credentials = New-Object System.Net.NetworkCredential($FromEmail, $FromEmailPassw);
        $smtp.send($message);
        $att.Dispose()
        write-host "=====================" ; 
        write-host "     Alert Sent" ; 
        write-host "=====================" ; 
    }
 
    Send-ToEmail  -email $ToEmail;

}else{

   'No employees at risk.'
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

##  =========================================================================
##       Section to store log files to a storage account
##  =========================================================================
## To to store log files to a storage account, uncomment below code section 
## and provdie storage account details


$StorageAccountName = ''  #insert storage account name
$StorageContainerName = '' #insert cotainer name

# Get key to storage account
$acctKey = (Get-AzStorageAccountKey -Name generals -ResourceGroupName general).Value[0]

# Map to the reports BLOB context
$storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $acctKey

# Copy the file to the storage account
Set-AzStorageBlobContent -File $output_file -Container $StorageContainerName -BlobType "Block" -Context $storageContext -Verbose
