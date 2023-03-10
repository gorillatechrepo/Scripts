# Check if the required version of ExchangeOnlineManagement module is installed
$installedModule = Get-InstalledModule -Name ExchangeOnlineManagement -ErrorAction SilentlyContinue
if (!$installedModule -or $installedModule.Version -lt '3.1.0') {
    # Install the required version of ExchangeOnlineManagement module
    Install-Module -Name ExchangeOnlineManagement -RequiredVersion 3.1.0 -Force
}

#Connect to Exchange Online and Grab Domains
Connect-ExchangeOnline -ShowBanner:$false
$TenantName = (Get-OrganizationConfig).Name
Write-Output "Tenant name: $TenantName"
#Grab all accepted domains
$Domains = $Domains = Get-AcceptedDomain | Select-Object -ExpandProperty  DomainName
$Domains
Write-Output "Accepted domains: $Domains"


# Initialize variables for missing DNS records
$missingRecords = @()

# Check DKIM & DMARC
Write-Output "-------- DKIM and DMARC DNS Records Report --------`n"
$Result = "Protection`tDomain`tTyp`tHost name`tValue`tTTL`n"
foreach ($Domain in $Domains) {
    # Check DKIM Selector 1 CNAME Record
    $dkimselector1 = nslookup -q=cname selector1._domainkey.$Domain 2> $null | Select-String "canonical name"
    if (!$dkimselector1) {
        $missingRecords += "DKIM Selector 1 for $Domain"
        $Result += "DKIM`t$Domain`tCNAME`tselector1._domainkey`tselector1-$($Domain -replace "\.", "-")._domainkey.$TenantName`t3600`n"
    }

    # Check DKIM Selector 2 CNAME Record
    $dkimselector2 = nslookup -q=cname selector2._domainkey.$Domain 2> $null | Select-String "canonical name"
    if (!$dkimselector2) {
        $missingRecords += "DKIM Selector 2 for $Domain"
        $Result += "DKIM`t$Domain`tCNAME`tselector2._domainkey`tselector2-$($Domain -replace "\.", "-")._domainkey.$TenantName`t3600`n"
    }

    # Check DMARC TXT Record
    $dmarc = (nslookup -q=txt _dmarc.$Domain 2> $null | Select-String "DMARC1") -replace "`t", ""
    if (!$dmarc) {
        $missingRecords += "DMARC for $Domain"
        $Result += "DMARC`t$Domain`tTXT`t_dmarc`tv=DMARC1; p=none; pct=100; rua=mailto:$ReportMailbox; ruf=mailto:$ReportMailbox; fo=1`t3600`n"
    }

    # Check SPF TXT Record
    $spf = (nslookup -q=txt $Domain 2> $null | Select-String "v=spf1") -replace "`t", ""
    if (!$spf) {
        $missingRecords += "SPF for $Domain"
        $Result += "SPF`t$Domain`tTXT`t@`tv=spf1 include:spf.protection.outlook.com -all`t3600`n"
    }

   # Output results for current domain
   Write-Output "---------------------- $Domain ----------------------"
   Write-Output "DKIM Selector 1 CNAME Record:"
   Write-Output "$dkimselector1"
   Write-Output ""
   Write-Output "DKIM Selector 2 CNAME Record:"
   Write-Output "$dkimselector2"
   Write-Output ""
   Write-Output "DMARC TXT Record:"
   Write-Output "$dmarc"
   Write-Output ""
   Write-Output "SPF TXT Record:"
   Write-Output "$spf"
   Write-Output "-----------------------------------------------------`n`n"

# Check DKIM signing configuration and prompt user if it's disabled
Write-Output "---------------------- Checking DKIM Signing Config ----------------------"
$dkimConfig = Get-DKIMSigningConfig -Identity $Domain
if ($dkimConfig.Enabled -eq $false) {
   Write-Output "DKIM signing is disabled for domain $Domain"
   $EnableDKIM= Read-Host "Do you want to enable DKIM signing for this domain? (yes or no)"
   if ($EnableDKIM.ToLower() -eq 'yes') {
       Write-Output "Enabling DKIM for domain $Domain"
       Set-DkimSigningConfig -Identity $Domain -Enabled $true
   } else {
       Write-Output "DKIM signing will remain disabled for domain $Domain."
   }
} else {
   Write-Output "DKIM signing is already enabled for domain $Domain."
}
Write-Output "-----------------------------------------------------`n`n"

}
    
# Output results for current domain
    Write-Output "---------------------- $Domain ----------------------"
    Write-Output "DKIM Selector 1 CNAME Record:"
    Write-Output "$dkimselector1"
    Write-Output ""
    Write-Output "DKIM Selector 2 CNAME Record:"
    Write-Output "$dkimselector2"
    Write-Output ""
    Write-Output "DMARC TXT Record:"
    Write-Output "$dmarc"
    Write-Output ""
    Write-Output "SPF TXT Record:"
    Write-Output "$spf"
    Write-Output "-----------------------------------------------------`n`n"
 # Check DKIM signing configuration and prompt user if it's disabled
 Write-Output "---------------------- Checking DKIM Signing Config ----------------------"
 $dkimConfig = Get-DKIMSigningConfig -Identity $Domain
 if ($dkimConfig.Enabled -eq $false) {
    Write-Output "DKIM signing is disabled for domain $Domain"
    $EnableDKIM= Read-Host "Do you want to enable DKIM signing for this domain? (yes or no)"
    if ($EnableDKIM.ToLower() -eq 'yes') {
        Write-Output "Enabling DKI M for domain $Domain"
        Set-DkimSigningConfig -Identity $Domain -Enabled $true
    } else {
        Write-Output "DKIM signing will remain disabled for domain $Domain."
    }
} else {
    Write-Output "DKIM signing is already enabled for domain $Domain."
}
Write-Output "-----------------------------------------------------`n`n"

# Check if any records are missing and prompt user to generate CSV if necessary
if ($missingRecords.Count -gt 0) {
    $missingString = $missingRecords -join ", "
    $generateCSV = Read-Host "The following DNS records are missing: $missingString. Would you like to generate a CSV file? (Y/N)"
    if ($generateCSV -eq "Y") {
        # Create order text for DKIM and DMARC records.
    $ReportMailbox = Read-Host = "What is the reporting mailbox address for DMARC? (Ex:report@domain.com)"
    #$TenantName = "example.onmicrosoft.com"
    Write-Output "CSV file generated and loaded to your clipboar. Open Excel and hit Ctrl+V"
    } else {c
        Write-Output "No CSV file generated."
    }
} else {
    Write-Output "All necessary DNS records exist."
}


# Prompt the user to select a location to save the CSV file
$saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
$saveFileDialog.Title = "Save CSV file"
$saveFileDialog.Filter = "CSV files (*.csv)|*.csv"

if ($saveFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "No file selected"
    return
}

# Save the Missing DNS Records to the selected CSV file
$Result | ConvertFrom-Csv -Delimiter "`t" | Export-Csv $saveFileDialog.FileName -NoTypeInformation
Write-Host "DNS records saved to '$($saveFileDialog.FileName)'"
Write-Host "Done."