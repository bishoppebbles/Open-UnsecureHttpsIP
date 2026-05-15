Import-Module activedirectory
. .\Get-SmartCardCred.ps1
$memsDN = (Get-ADGroup 'Group' -Server state.sbu -Properties Members).Members

$mems = switch -Regex ($memsDN) {
    'CN=([A-Za-z0-9]+).+' {
        $matches[1].Trim() + '.domain.com'
    }
}

New-PSSession -ComputerName $mems -SessionOption (New-PSSessionOption -NoMachineProfile) -Credential (Get-SmartCardCred)

$out = Invoke-Command -Session (Get-PSSession) -ScriptBlock {
    
$Manufacturer = (Get-CimInstance -Namespace root\cimv2 -ClassName Win32_BIOS).Manufacturer

if ($Manufacturer -like "*Dell*") { 
    # Get-WmiObject -Namespace root\dcim\sysman -Class "__NAMESPACE" -Recurse
    # Get-CimClass -Namespace root\dcim\sysman\biosattributes | Select-Object -ExpandProperty CimClassName

$filterDell = @"
AttributeName = 'SecureBoot'
OR AttributeName = 'Microphone'
OR AttributeName = 'InternalSpeaker'
OR AttributeName = 'WirelessLan'
OR AttributeName = 'BluetoothDevice'
OR AttributeName = 'TpmSecurity'
OR AttributeName = 'StrongPassword'
OR AttributeName = 'PwdUpperCaseRqd'
OR AttributeName = 'PwdDigitRqd'
OR AttributeName = 'PwdSpecialCharRqd'
OR AttributeName = 'Virtualization'
OR AttributeName = 'PreBootDma'
"@

    # Admin and system password configuration
    $dell = [ordered]@{}
    $dell['Manufacturer'] = 'Dell'
    $dell['PSComputerName'] = $env:COMPUTERNAME
    Get-CimInstance -Namespace root\dcim\sysman\wmisecurity `
                    -ClassName PasswordObject `
                    -Filter "NameId = 'Admin' OR NameId = 'System'" |
        ForEach-Object {
            if($_.NameId -eq 'Admin') {
                $dell['AdminPw'] = if($_.IsPasswordSet -eq 1){'True'} else {'False'}
                $dell['AdminMinPwLen'] = $_.MinimumPasswordLength
                $dell['AdminMaxPwLen'] = $_.MaximumPasswordLength
            } elseif($_.NameId -eq 'System') {
                $dell['SystemPw'] = if($_.IsPasswordSet -eq 1){'True'} else {'False'}
                $dell['SystemMinPwLen'] = $_.MinimumPasswordLength
                $dell['SystemMaxPwLen'] = $_.MaximumPasswordLength
            }
        }
 
    # AttributeName|DisplayName (PasswordBypass,PasswordLock), CurrentValue
    Get-CimInstance -Namespace root\dcim\sysman\biosattributes `
                    -ClassName EnumerationAttribute `
                    -Filter $filterDell | 
        ForEach-Object{ 
            if($_.AttributeName -eq 'SecureBoot'        -or
		        $_.AttributeName -eq 'Microphone'        -or
		        $_.AttributeName -eq 'InternalSpeaker'   -or
		        $_.AttributeName -eq 'WirelessLan'       -or
		        $_.AttributeName -eq 'BluetoothDevice'   -or
		        $_.AttributeName -eq 'TpmSecurity'       -or
		        $_.AttributeName -eq 'StrongPassword'    -or
		        $_.AttributeName -eq 'PwdUpperCaseRqd'   -or
		        $_.AttributeName -eq 'PwdDigitRqd'       -or
		        $_.AttributeName -eq 'PwdSpecialCharRqd' -or
		        $_.AttributeName -eq 'Virtualization'    -or
		        $_.AttributeName -eq 'PreBootDma' ) {
                    $dell[$($_.AttributeName)] = $_.CurrentValue
            }
        }

    # Boot order configuration
    Get-CimInstance -Namespace root\dcim\sysman\biosattributes `
                    -ClassName BootOrder `
                    -Filter "BootListType = 'Legacy' OR BootListType = 'UEFI'" |
        ForEach-Object {
            if($_.BootListType -eq 'Legacy') {
                $dell['LegacyBootOrder'] = $_.BootOrder -join ','
            } elseif($_.BootListType -eq 'UEFI') {
                $dell['UefiBootOrder'] = $_.BootOrder -join ','
            }
        }

    $dell

} elseif ($Manufacturer -like "*HP*") {

$filterHp = @"
Name = 'Setup Password'
OR Name = 'Power-On Password'
OR Name = 'Secure Boot'
OR Name = 'TPM Specification Version'
OR Name = 'TPM State'
OR Name = 'USB Storage Boot'
OR Name = 'CD-ROM Boot'
OR Name = 'Network (PXE) Boot'
OR Name = 'IPv6 during UEFI Boot'
OR Name = 'UEFI Boot Order'
OR Name = 'Legacy Boot Order'
OR Name = 'Configure Legacy Support and Secure Boot'
OR Name = 'Virtualization Technology (VTx)'
OR Name = 'Virtualization Technology for Directed I/O (VTd)'
OR Name = 'Restrict USB Devices'
OR Name = 'DMA Protection'
OR Name = 'Pre-boot DMA protection'
OR Name = 'Password Minimum Length'
OR Name = 'At least one lower case character is required in Administrator and User passwords'
OR Name = 'At least one upper case character is required in Administrator and User passwords'
OR Name = 'At least one number is required in Administrator and User passwords'
OR Name = 'At least one symbol is required in Administrator and User passwords'
"@

    $hp = [ordered]@{}
    $hp['Manufacturer'] = 'HP'
    $hp['PSComputerName'] = $env:COMPUTERNAME
    Get-CimInstance -Namespace root\hp\InstrumentedBIOS `
                    -ClassName HP_BIOSSetting `
                    -Filter $filterHp |
        ForEach-Object{ 
            if($_.Name -eq 'Setup Password') {
                $hp['AdminPw'] = if($_.IsSet -eq 1){'True'} elseif($_.IsSet -eq 0) {'False'}
                $hp['AdminMinPwLen'] = $_.MinLength
                $hp['AdminMaxPwLen'] = $_.MaxLength
            } elseif($_.Name -eq 'Power-On Password') {
                $hp['SystemPw'] = if($_.IsSet -eq 1){'True'} elseif($_.IsSet -eq 0) {'False'}
                $hp['SystemMinPwLen'] = $_.MinLength
                $hp['SystemMaxPwLen'] = $_.MaxLength
            } elseif($_.Name -eq 'Legacy Boot Order'         -or
                        $_.Name -eq 'Password Minimum Length'   -or
                        $_.Name -eq 'TPM Specification Version' -or
                        $_.Name -eq 'UEFI Boot Order') {
                $hp[$($_.Name)] = $_.Value
            }elseif($_.Name -eq 'At least one lower case character is required in Administrator and User passwords' -or
                    $_.Name -eq 'At least one number is required in Administrator and User passwords'               -or
                    $_.Name -eq 'At least one symbol is required in Administrator and User passwords'               -or
                    $_.Name -eq 'At least one upper case character is required in Administrator and User passwords' -or
                    $_.Name -eq 'Configure Legacy Support and Secure Boot' -or
                    $_.Name -eq 'CD-ROM Boot'                              -or
                    $_.Name -eq 'DMA Protection'                           -or
                    $_.Name -eq 'Pre-boot DMA Protection'                  -or
                    $_.Name -eq 'IPv6 during UEFI Boot'                    -or
                    $_.Name -eq 'Network (PXE) Boot'                       -or
                    $_.Name -eq 'Restrict USB Devices'                     -or
                    $_.Name -eq 'Secure Boot'                              -or
                    $_.Name -eq 'TPM State'                                -or
                    $_.Name -eq 'USB Storage Boot'                         -or
                    $_.Name -eq 'Virtualization Technology (VTx)'          -or
                    $_.Name -eq 'Virtualization Technology for Directed I/O (VTd)') {
                $hp[$($_.Name)] = $_.CurrentValue
            }
        }

    $hp
    }
}

$out | ForEach-Object {
    if($_['Manufacturer'] -eq 'HP') {
        [pscustomobject]$_ | Export-Csv hp.csv -Append -NoTypeInformation
    } elseif($_['Manufacturer'] -eq 'Dell') {
        [pscustomobject]$_ | Export-Csv dell.csv -Append -NoTypeInformation
    }
}