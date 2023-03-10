$domains = Get-Content -Path "C:\path\to\domain\list.txt"

$results = foreach ($domain in $domains) {
    $mx = Resolve-DnsName -Type MX -Server 8.8.8.8 -Name $domain -ErrorAction SilentlyContinue
    if ($mx) {
        $mx.HostExchange, $mx.NameHost
    }
}

$results | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File "C:\path\to\output.csv"