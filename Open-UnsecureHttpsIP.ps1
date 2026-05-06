<#
.SYNOPSIS

.DESCRIPTION
    
.PARAMETER IpList
    The specific OU name of interest.  Can be used to limit the collection scope in a domain environment.
.EXAMPLE
    .\Open-UnsecureHttpsIp.ps1
    Uses Chrome to open all IP addresses in a saved list in the current directory called ips.txt
.EXAMPLE
    .\Open-UnsecureHttpsIp.ps1 -IpList '.\http_ips.txt'
    Uses Chrome to open all IP addresses in a saved list in the current directory called http_ips.txt
.NOTES
    Version 0.02
    Author: Dan Fults
    Last modified: 05 May 2025
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$False, HelpMessage='List of HTTP based IPs')]
    [string]$IpList = '.\ips.txt'
)

# Read IP addresses from MFD.txt
$ipAddresses = Get-Content -Path $IpList | Sort-Object -Unique

# Path to Chrome executable
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"

# Alternative path if Chrome is installed in Program Files (x86)
if (-not (Test-Path $chromePath)) {
    $chromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}

# Check if Chrome exists
if (-not (Test-Path $chromePath)) {
    Write-Host "Chrome not found. Please verify the installation path." -ForegroundColor Red
    exit
}

# Launch Chrome with certificate error bypass flags
# Multiple flags to ensure certificate warnings are bypassed
$chromeArgs = @(
    "--ignore-certificate-errors",
    "--ignore-ssl-errors",
    "--allow-insecure-localhost",
    "--disable-web-security",
    "--user-data-dir=$env:TEMP\ChromeTemp"
)

# Add each IP address as a URL to open
foreach ($ip in $ipAddresses) {
    # Skip empty lines
    #if ([string]::IsNullOrWhiteSpace($ip)) {
    #    continue
    #}
    
    # Add https:// prefix if not present
    if ($ip -notmatch "^https?://") {
        $url = "https://$ip"
    } else {
        $url = $ip
    }
    
    $chromeArgs += $url
    Write-Host "Adding: $url"
}

# Launch Chrome with all URLs
Write-Host "`nLaunching Chrome with $($ipAddresses.Count) printer IP addresses..." -ForegroundColor Green
Start-Process -FilePath $chromePath -ArgumentList $chromeArgs

Write-Host "Done!" -ForegroundColor Green