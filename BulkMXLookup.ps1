# Prompt the user for how they want to get the domains
$option = Read-Host "Do you want to load domains from Office365 (O) or from a file (F)?"

if ($option.ToLower() -eq "o") {
    # Connect to Exchange Online and retrieve a list of all domains
    Connect-ExchangeOnline -ShowBanner:$false
    $domains = Get-AcceptedDomain | Select-Object -ExpandProperty Name
} elseif ($option.ToLower() -eq "f") {
    
    # Load the .NET assembly that contains the SaveFileDialog class
    Add-Type -AssemblyName System.Windows.Forms

    # Prompt the user to select a text file containing a list of domain names
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Title = "Select a file containing a list of domain names"
    $fileDialog.Filter = "Text files (*.txt)|*.txt"
    $domains = Get-Content $fileDialog.FileName

        if ($fileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            Write-Host "No file selected"
            return
        }

} else {
    Write-Host "Invalid option selected"
    Exit
}

# Perform an MX lookup on each domain
$mxRecords = foreach ($domain in $domains) {
    try {
        $mxRecords = Resolve-DnsName -Type MX $domain | Sort-Object -Property Priority
        foreach ($mxRecord in $mxRecords) {
            [PSCustomObject]@{
                Domain = $domain
                MXRecord = $mxRecord.NameExchange
                Priority = $mxRecord.Preference
            }
        }
    }
    catch {
        Write-Warning "Failed to perform MX lookup for '$domain': $_"
    }
}

# Prompt the user to select a location to save the CSV file
$saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
$saveFileDialog.Title = "Save CSV file"
$saveFileDialog.Filter = "CSV files (*.csv)|*.csv"

if ($saveFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "No file selected"
    return
}

# Save the MX records to the selected CSV file
$mxRecords | Export-Csv $saveFileDialog.FileName -NoTypeInformation
Write-Host "MX records saved to '$($saveFileDialog.FileName)'"

# Prompt the user for the location to save the CSV


Write-Host "Done."