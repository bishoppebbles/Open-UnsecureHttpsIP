<#
.SYNOPSIS
    Auto-connects using HTTPS from a unique IP list with Chrome.
.DESCRIPTION
    The script takes as input a list of IPs and attempts to connect to each one using HTTPS.  It opens one Chrome tab per address.
.PARAMETER IpList
    The list of target IPs (one per line).
.EXAMPLE
    .\Open-UnsecureHttpsIp.ps1
    Uses Chrome to connect to all unique HTTPS IP addresses listed in ips.txt saved in the current directory.
.EXAMPLE
    .\Open-UnsecureHttpsIp.ps1 -IpList .\http_ips.txt
    Uses Chrome to connect to all unique HTTPS IP addresses listed in http_ips.txt saved in the current directory.
.NOTES
    Version 1.00
    Author: Dan Fults
    Last modified: 06 May 2025
#>

[CmdletBinding()]
param (
    [Parameter(Position=0, Mandatory=$False, HelpMessage='List of IPs to connect using HTTPS')]
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
  
    # Add https:// prefix if not present
    if ($ip -notmatch "^https?://") {
        $addr = "https://$ip"
    } else {
        $addr = $ip
    }
    
    $chromeArgs += $addr
    Write-Verbose "Adding: $addr"
}

# Launch Chrome with all URLs
if($ipAddresses.Count -eq 0) {
    Write-Host "No IP address data present, exiting." -ForegroundColor Red
    exit
} elseif($ipAddresses.Count -eq 1) {
    Write-Host "Launching Chrome opening $($ipAddresses.Count) HTTPS tab." -ForegroundColor Green
} else {
    Write-Host "Launching Chrome opening $($ipAddresses.Count) HTTPS tabs." -ForegroundColor Green
}

Start-Process -FilePath $chromePath -ArgumentList $chromeArgs