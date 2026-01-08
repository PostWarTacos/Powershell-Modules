<#
.SYNOPSIS
    Computer Inventory PowerShell Module

.DESCRIPTION
    Provides comprehensive computer inventory and health check functions for remote Windows systems.
    Functions can be called individually or grouped by category (Hardware, Network, Security, etc.)

.NOTES
    Author: PostWarTacos
    Date: January 8, 2026
    Version: 3.0 (Converted to module format)
#>

#region Helper Functions

Function Write-LogMessage {
    <#
    .SYNOPSIS
        Writes timestamped, color-coded log messages to console and optionally to file.

    .DESCRIPTION
        Outputs formatted log messages with timestamps, severity indicators, and color-coding.
        Supports multiple log levels with distinct visual formatting.

    .PARAMETER Message
        The log message text to display and/or write to file.

    .PARAMETER Level
        Specifies the severity/type of the log message.
        Valid values: "Info", "Warning", "Error", "Success", "Default"

    .PARAMETER LogFile
        Optional file path for persistent logging.

    .EXAMPLE
        Write-LogMessage "Starting process" -Level Info
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        [string]$Message,
        [Parameter(Position=1)]
        [ValidateSet("Info", "Warning", "Error", "Success", "Default")]
        [string]$Level,
        [Parameter(Mandatory=$false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$LogFile
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        Write-Host ""
        if ($LogFile) {
            try {
                "" | Out-File -FilePath $LogFile -Append -ErrorAction Stop
            } catch {
                Write-Warning "Failed to write to log file: $($_.Exception.Message)"
            }
        }
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if ($Level) {
        $prefix = switch ($Level) {
            "Info"    { "[*]" }
            "Warning" { "[!]" }
            "Error"   { "[!!!]" }
            "Success" { "[+]" }
        }
    }
    else {
        $prefix = "[*]"
        $Level = "Default"
    }

    $logEntry = "[$timestamp] $prefix $Message"

    switch ($Level) {
        "Default" { Write-Host $logEntry -ForegroundColor DarkGray }
        "Info"    { Write-Host $logEntry -ForegroundColor White }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Error"   { Write-Host $logEntry -ForegroundColor Red }
        "Success" { Write-Host $logEntry -ForegroundColor Green }
    }

    if ($LogFile) {
        try {
            $logEntry | Out-File -FilePath $LogFile -Append -ErrorAction Stop
        } catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

#endregion

#region Network Functions

function Get-SharesInfo {
    <#
    .SYNOPSIS
        Gets network share information from a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-SharesInfo -ComputerName "SERVER01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        if (Get-Command Get-SmbShare -ErrorAction SilentlyContinue) {
            $shares = Get-SmbShare -CimSession $ComputerName -ErrorAction Stop | 
                Where-Object { $_.Name -notmatch '^(IPC\$|ADMIN\$|[A-Z]\$)$' }
            return ($shares | ForEach-Object { "$($_.Name) ($($_.Path))" }) -join "; "
        } else {
            $shares = Get-CimInstance -ClassName Win32_Share -ComputerName $ComputerName -ErrorAction Stop |
                Where-Object { $_.Name -notmatch '^(IPC\$|ADMIN\$|[A-Z]\$)$' }
            return ($shares | ForEach-Object { "$($_.Name) ($($_.Path))" }) -join "; "
        }
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

function Get-NetworkDetails {
    <#
    .SYNOPSIS
        Gets network configuration details (DNS servers and default gateway) from a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-NetworkDetails -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $networks = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ComputerName $ComputerName -ErrorAction Stop |
            Where-Object { $_.IPEnabled -and $_.IPAddress }
        
        if ($networks) {
            $network = $networks | Select-Object -First 1
            
            $dns = if ($network.DNSServerSearchOrder) {
                $network.DNSServerSearchOrder -join ", "
            } else {
                "N/A"
            }
            
            $gateway = if ($network.DefaultIPGateway) {
                $network.DefaultIPGateway -join ", "
            } else {
                "N/A"
            }
            
            return @{
                DNS = $dns
                Gateway = $gateway
            }
        }
        
        return @{
            DNS = "N/A"
            Gateway = "N/A"
        }
    } catch {
        return @{
            DNS = "ERROR"
            Gateway = "ERROR"
        }
    }
}

#endregion

#region Active Directory Functions

function Get-ADLastLogon {
    <#
    .SYNOPSIS
        Gets the last logon timestamp for a computer from Active Directory.
    
    .PARAMETER ComputerName
        The name of the computer to query.
    
    .EXAMPLE
        Get-ADLastLogon -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            Import-Module ActiveDirectory -ErrorAction SilentlyContinue
            $computer = Get-ADComputer -Identity $ComputerName -Properties LastLogonTimeStamp -ErrorAction Stop
            if ($computer.LastLogonTimeStamp) {
                return [DateTime]::FromFileTime($computer.LastLogonTimeStamp)
            } else {
                return "Never"
            }
        } else {
            # Fallback to ADSI
            $searcher = New-Object System.DirectoryServices.DirectorySearcher
            $searcher.Filter = "(&(objectCategory=computer)(name=$ComputerName))"
            $searcher.PropertiesToLoad.Add("lastLogonTimeStamp") | Out-Null
            
            $adSearchResult = $searcher.FindOne()
            if ($adSearchResult -and $adSearchResult.Properties["lastLogonTimeStamp"][0]) {
                return [DateTime]::FromFileTime($adSearchResult.Properties["lastLogonTimeStamp"][0])
            } else {
                return "Never"
            }
        }
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

function Get-DomainController {
    <#
    .SYNOPSIS
        Gets the domain controller that the remote computer authenticated with.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-DomainController -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $dc = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                # Check if domain-joined
                $cs = Get-CimInstance -ClassName Win32_ComputerSystem
                if (-not $cs.PartOfDomain) {
                    return "Not Domain Joined"
                }
                
                # Get logon server from environment
                $logonServer = $env:LOGONSERVER
                if ($logonServer) {
                    return $logonServer -replace '\\\\', ''
                }
                
                # Fallback: Use nltest
                $nltest = nltest /dsgetdc: 2>&1
                if ($nltest -match 'DC:\s*\\\\(.+)') {
                    return $matches[1]
                }
                
                return "Unknown"
            } catch {
                return "ERROR"
            }
        } -ErrorAction Stop
        
        return $dc
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

#endregion

#region User Functions

function Get-CurrentUser {
    <#
    .SYNOPSIS
        Gets the currently logged-on user from a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-CurrentUser -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $loggedOnUser = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop
        
        if ($loggedOnUser.UserName) {
            $username = $loggedOnUser.UserName.Split('\\')[-1]
            
            try {
                if (Get-Module -ListAvailable -Name ActiveDirectory) {
                    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
                    $adUser = Get-ADUser $username -ErrorAction SilentlyContinue
                    if ($adUser) {
                        return "$($adUser.Name) ($username)"
                    }
                }
            } catch {}
            
            return $username
        } else {
            return "None"
        }
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

function Get-LastLoggedOnUser {
    <#
    .SYNOPSIS
        Gets the last logged-on user from a remote computer based on profile timestamps.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-LastLoggedOnUser -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $userDir = Get-ChildItem "\\$ComputerName\c$\Users" -ErrorAction Stop |
            Where-Object {
                $_.PSIsContainer -and 
                $_.Name -notmatch '^(Public|Default|Default User|All Users|Admin|Administrator)$'
            } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        
        if ($userDir) {
            try {
                if (Get-Module -ListAvailable -Name ActiveDirectory) {
                    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
                    $adUser = Get-ADUser $userDir.Name -ErrorAction SilentlyContinue
                    if ($adUser) {
                        return "$($adUser.Name) ($($userDir.Name))"
                    }
                }
            } catch {}
            
            return $userDir.Name
        } else {
            return "Unknown"
        }
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

function Get-PrimaryUser {
    <#
    .SYNOPSIS
        Gets the primary user of a remote computer based on profile size (most used).
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-PrimaryUser -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $userDirs = Get-ChildItem "\\$ComputerName\c$\Users" -ErrorAction Stop |
            Where-Object {
                $_.PSIsContainer -and 
                $_.Name -notmatch '^(Public|Default|Default User|All Users|Admin|Administrator)$'
            }
        
        if ($userDirs) {
            $userStats = foreach ($userDir in $userDirs) {
                try {
                    $size = (Get-ChildItem $userDir.FullName -Recurse -ErrorAction SilentlyContinue | 
                        Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    
                    [PSCustomObject]@{
                        UserName = $userDir.Name
                        ProfileSize = $size
                        LastAccess = $userDir.LastWriteTime
                    }
                } catch {}
            }
            
            $primaryUser = $userStats | Sort-Object ProfileSize -Descending | Select-Object -First 1
            
            if ($primaryUser) {
                try {
                    if (Get-Module -ListAvailable -Name ActiveDirectory) {
                        Import-Module ActiveDirectory -ErrorAction SilentlyContinue
                        $adUser = Get-ADUser $primaryUser.UserName -ErrorAction SilentlyContinue
                        if ($adUser) {
                            return "$($adUser.Name) ($($primaryUser.UserName))"
                        }
                    }
                } catch {}
                
                return $primaryUser.UserName
            } else {
                return "Unknown"
            }
        } else {
            return "No Users"
        }
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

function Get-LocalAdmins {
    <#
    .SYNOPSIS
        Gets the members of the local Administrators group from a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-LocalAdmins -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $admins = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                $group = Get-LocalGroup -Name "Administrators" -ErrorAction Stop
                $members = Get-LocalGroupMember -Group $group -ErrorAction Stop
                return ($members | ForEach-Object { $_.Name.Split('\\')[-1] }) -join "; "
            } catch {
                $output = net localgroup administrators
                $members = $output | Where-Object { $_ -match '^[^-]' -and $_ -notmatch '^(Alias name|Comment|Members|The command completed)' -and $_.Trim() -ne '' }
                return ($members | ForEach-Object { $_.Trim() }) -join "; "
            }
        } -ErrorAction Stop
        
        return $admins
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

#endregion

#region Hardware Functions

function Get-DriveSpace {
    <#
    .SYNOPSIS
        Gets disk space information for the C: drive on a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-DriveSpace -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $drive = Get-CimInstance -ClassName Win32_Volume -ComputerName $ComputerName -Filter "drivetype = 3" -ErrorAction Stop |
            Where-Object { $_.DriveLetter -eq 'C:' } |
            Select-Object -First 1
        
        if ($drive) {
            $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
            $totalGB = [math]::Round($drive.Capacity / 1GB, 2)
            $percentFree = [math]::Round(($drive.FreeSpace / $drive.Capacity) * 100, 1)
            return "$freeGB GB free of $totalGB GB ($percentFree%)"
        }
        return "N/A"
    } catch {
        return "ERROR"
    }
}

function Get-ChassisType {
    <#
    .SYNOPSIS
        Determines the chassis type (Desktop, Laptop, Server, VM) of a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-ChassisType -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop
        $bios = Get-CimInstance -ClassName Win32_BIOS -ComputerName $ComputerName -ErrorAction Stop
        $enclosure = Get-CimInstance -ClassName Win32_SystemEnclosure -ComputerName $ComputerName -ErrorAction Stop
        
        $isVM = $false
        $vmType = ""
        
        $model = $computer.Model.ToLower()
        $manufacturer = $computer.Manufacturer.ToLower()
        $biosManufacturer = $bios.Manufacturer.ToLower()
        
        if ($model -match 'virtual|vmware|vbox|kvm|xen|qemu') {
            $isVM = $true
            if ($model -match 'vmware') { $vmType = "VMware" }
            elseif ($model -match 'virtual machine') { $vmType = "Hyper-V" }
            elseif ($model -match 'vbox|virtualbox') { $vmType = "VirtualBox" }
            elseif ($model -match 'kvm') { $vmType = "KVM" }
            elseif ($model -match 'xen') { $vmType = "Xen" }
            elseif ($model -match 'qemu') { $vmType = "QEMU" }
            else { $vmType = "VM" }
        } elseif ($manufacturer -match 'vmware|microsoft corporation' -or $biosManufacturer -match 'vmware|hyper-v|xen|qemu|innotek|parallels') {
            $isVM = $true
            if ($manufacturer -match 'vmware' -or $biosManufacturer -match 'vmware') { $vmType = "VMware" }
            elseif ($biosManufacturer -match 'hyper-v' -or ($manufacturer -match 'microsoft' -and $model -match 'virtual')) { $vmType = "Hyper-V" }
            elseif ($biosManufacturer -match 'innotek') { $vmType = "VirtualBox" }
            elseif ($biosManufacturer -match 'xen') { $vmType = "Xen" }
            elseif ($biosManufacturer -match 'qemu') { $vmType = "QEMU" }
            elseif ($biosManufacturer -match 'parallels') { $vmType = "Parallels" }
            else { $vmType = "VM" }
        }
        
        $chassisName = "Unknown"
        if ($enclosure -and $enclosure.ChassisTypes) {
            $chassisType = $enclosure.ChassisTypes[0]
            
            $chassisName = switch ($chassisType) {
                {$_ -in 3, 4, 5, 6, 7, 15, 16} { "Desktop" }
                {$_ -in 8, 9, 10, 11, 12, 14, 18, 21} { "Laptop" }
                13 { "All-in-One" }
                17 { "Server (Tower)" }
                23 { "Server (Rack)" }
                24 { "Server (Sealed)" }
                28 { "Server (Blade Enclosure)" }
                29 { "Server (Blade)" }
                30 { "Tablet" }
                31 { "Convertible" }
                32 { "Detachable" }
                default { "Unknown ($chassisType)" }
            }
        }
        
        if ($chassisName -eq "Unknown" -or $chassisName -match "Unknown \(\d+\)") {
            $battery = Get-CimInstance -ClassName Win32_Battery -ComputerName $ComputerName -ErrorAction SilentlyContinue
            if ($battery) {
                $chassisName = "Laptop (Battery Detected)"
            }
        }
        
        $chassisResult = @{ ChassisType = $chassisName }
        if ($isVM) {
            $chassisResult.VMType = $vmType
        }
        return $chassisResult
        
    } catch {
        return @{ ChassisType = "ERROR" }
    }
}

function Get-MonitorCount {
    <#
    .SYNOPSIS
        Gets the number of monitors connected to a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-MonitorCount -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $monitors = Get-CimInstance -ClassName WmiMonitorID -Namespace root\wmi -ComputerName $ComputerName -ErrorAction Stop
        
        if ($monitors) {
            $count = ($monitors | Measure-Object).Count
            return "$count monitor(s)"
        } else {
            return "0 (or N/A)"
        }
    } catch {
        try {
            $displays = Get-CimInstance -ClassName Win32_DesktopMonitor -ComputerName $ComputerName -ErrorAction Stop
            if ($displays) {
                $count = ($displays | Measure-Object).Count
                return "$count monitor(s)"
            }
        } catch {}
        
        return "N/A"
    }
}

function Get-BatteryHealth {
    <#
    .SYNOPSIS
        Gets battery health information from a remote computer (laptops only).
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-BatteryHealth -ComputerName "LAPTOP01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $batteryInfo = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop
                
                if (-not $battery) {
                    return [PSCustomObject]@{
                        Status = "No Battery"
                        Health = $null
                    }
                }
                
                $designCapacity = $battery.DesignCapacity
                $fullChargeCapacity = $battery.FullChargeCapacity
                
                if ($designCapacity -and $fullChargeCapacity -and $designCapacity -gt 0) {
                    $healthPercent = [math]::Round(($fullChargeCapacity / $designCapacity) * 100, 1)
                    
                    $healthStatus = if ($healthPercent -ge 80) { "Good" }
                                   elseif ($healthPercent -ge 60) { "Fair" }
                                   else { "Poor" }
                    
                    return [PSCustomObject]@{
                        Status = "Present"
                        Health = "$healthPercent% ($healthStatus)"
                    }
                } else {
                    try {
                        $batteryStatic = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1
                        $batteryStatus = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1
                        
                        if ($batteryStatic -and $batteryStatus) {
                            $design = $batteryStatic.DesignedCapacity
                            $current = $batteryStatus.FullChargedCapacity
                            
                            if ($design -gt 0) {
                                $healthPercent = [math]::Round(($current / $design) * 100, 1)
                                
                                $healthStatus = if ($healthPercent -ge 80) { "Good" }
                                               elseif ($healthPercent -ge 60) { "Fair" }
                                               else { "Poor" }
                                
                                return [PSCustomObject]@{
                                    Status = "Present"
                                    Health = "$healthPercent% ($healthStatus)"
                                }
                            }
                        }
                    } catch {}
                    
                    return [PSCustomObject]@{
                        Status = "Present"
                        Health = "Unknown (capacity data unavailable)"
                    }
                }
            } catch {
                return [PSCustomObject]@{
                    Status = "No Battery"
                    Health = $null
                }
            }
        } -ErrorAction Stop
        
        if ($batteryInfo.Health -ne $null) {
            return $batteryInfo.Health
        } else {
            return $batteryInfo.Status
        }
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

#endregion

#region Security Functions

function Get-TPMStatus {
    <#
    .SYNOPSIS
        Gets TPM (Trusted Platform Module) status from a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-TPMStatus -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $tpm = Get-CimInstance -Namespace "root\CIMv2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ComputerName $ComputerName -ErrorAction Stop
        
        if ($tpm) {
            $enabled = $tpm.IsEnabled_InitialValue
            $activated = $tpm.IsActivated_InitialValue
            
            if ($enabled -and $activated) {
                return "Enabled & Activated"
            } elseif ($enabled) {
                return "Enabled Only"
            } else {
                return "Disabled"
            }
        } else {
            return "Not Present"
        }
    } catch {
        return "Not Available"
    }
}

function Get-BitLockerStatus {
    <#
    .SYNOPSIS
        Gets BitLocker encryption status for the C: drive on a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-BitLockerStatus -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $blv = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                $vol = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
                $status = $vol.ProtectionStatus
                $method = ($vol.KeyProtector | Where-Object { $_.KeyProtectorType -ne 'RecoveryPassword' } | Select-Object -First 1).KeyProtectorType
                
                if ($status -eq 'On') {
                    if ($method) {
                        return "Encrypted ($method)"
                    } else {
                        return "Encrypted"
                    }
                } elseif ($status -eq 'Off') {
                    return "Not Encrypted"
                } else {
                    return "Unknown"
                }
            } catch {
                return "N/A"
            }
        } -ErrorAction Stop
        
        return $blv
    } catch {
        return "N/A"
    }
}

function Get-WindowsDefenderInfo {
    <#
    .SYNOPSIS
        Gets Windows Defender status, version, and scan information from a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-WindowsDefenderInfo -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $defenderInfo = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                $mpPreference = Get-MpComputerStatus -ErrorAction Stop
                
                $version = $mpPreference.AMProductVersion
                $signatureVersion = $mpPreference.AntivirusSignatureVersion
                $signatureLastUpdated = $mpPreference.AntivirusSignatureLastUpdated
                
                $quickScanTime = $mpPreference.QuickScanEndTime
                $fullScanTime = $mpPreference.FullScanEndTime
                
                $lastScanType = "Never"
                $lastScanTime = $null
                
                if ($quickScanTime -and $fullScanTime) {
                    if ($quickScanTime -gt $fullScanTime) {
                        $lastScanType = "Quick"
                        $lastScanTime = $quickScanTime
                    } else {
                        $lastScanType = "Full"
                        $lastScanTime = $fullScanTime
                    }
                } elseif ($quickScanTime) {
                    $lastScanType = "Quick"
                    $lastScanTime = $quickScanTime
                } elseif ($fullScanTime) {
                    $lastScanType = "Full"
                    $lastScanTime = $fullScanTime
                }
                
                $realtimeProtection = $mpPreference.RealTimeProtectionEnabled
                $status = if ($realtimeProtection) { "Enabled" } else { "Disabled" }
                
                return [PSCustomObject]@{
                    Version = $version
                    SignatureVersion = $signatureVersion
                    SignatureLastUpdated = $signatureLastUpdated
                    LastScanType = $lastScanType
                    LastScanTime = $lastScanTime
                    Status = $status
                }
            } catch {
                try {
                    $service = Get-Service -Name WinDefend -ErrorAction Stop
                    if ($service.Status -eq 'Running') {
                        return [PSCustomObject]@{
                            Version = "Unknown"
                            SignatureVersion = "Unknown"
                            SignatureLastUpdated = $null
                            LastScanType = "Unknown"
                            LastScanTime = $null
                            Status = "Service Running (Limited Info)"
                        }
                    } else {
                        return [PSCustomObject]@{
                            Version = "N/A"
                            SignatureVersion = "N/A"
                            SignatureLastUpdated = $null
                            LastScanType = "N/A"
                            LastScanTime = $null
                            Status = "Service Stopped"
                        }
                    }
                } catch {
                    return [PSCustomObject]@{
                        Version = "N/A"
                        SignatureVersion = "N/A"
                        SignatureLastUpdated = $null
                        LastScanType = "N/A"
                        LastScanTime = $null
                        Status = "Not Installed"
                    }
                }
            }
        } -ErrorAction Stop
        
        return $defenderInfo
    } catch {
        return [PSCustomObject]@{
            Version = "ERROR"
            SignatureVersion = "ERROR"
            SignatureLastUpdated = $null
            LastScanType = "ERROR"
            LastScanTime = $null
            Status = "ERROR: $($_.Exception.Message)"
        }
    }
}

#endregion

#region Update Functions

function Get-LastWindowsUpdate {
    <#
    .SYNOPSIS
        Gets the date of the last Windows Update installation on a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-LastWindowsUpdate -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $lastUpdate = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                $session = New-Object -ComObject Microsoft.Update.Session
                $searcher = $session.CreateUpdateSearcher()
                $historyCount = $searcher.GetTotalHistoryCount()
                
                if ($historyCount -gt 0) {
                    $history = $searcher.QueryHistory(0, 1) | Select-Object -First 1
                    return $history.Date
                } else {
                    return $null
                }
            } catch {
                try {
                    $cbsLog = "C:\Windows\Logs\CBS\CBS.log"
                    if (Test-Path $cbsLog) {
                        $lastLine = Get-Content $cbsLog -Tail 100 | Where-Object { $_ -match 'Installed|Updated' } | Select-Object -Last 1
                        if ($lastLine -match '(\d{4}-\d{2}-\d{2})') {
                            return [DateTime]::Parse($matches[1])
                        }
                    }
                } catch {}
                
                return $null
            }
        } -ErrorAction Stop
        
        if ($lastUpdate) {
            return $lastUpdate.ToString("yyyy-MM-dd")
        } else {
            return "Unknown"
        }
    } catch {
        return "ERROR"
    }
}

function Get-PendingUpdatesCount {
    <#
    .SYNOPSIS
        Gets the count of pending Windows Updates on a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-PendingUpdatesCount -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $updateCount = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                $session = New-Object -ComObject Microsoft.Update.Session
                $searcher = $session.CreateUpdateSearcher()
                $searchResult = $searcher.Search("IsInstalled=0 and Type='Software'")
                return $searchResult.Updates.Count
            } catch {
                return "ERROR"
            }
        } -ErrorAction Stop
        
        if ($updateCount -eq "ERROR") {
            return "ERROR"
        } elseif ($updateCount -eq 0) {
            return "0 (Up to date)"
        } else {
            return "$updateCount pending"
        }
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

function Get-PendingReboot {
    <#
    .SYNOPSIS
        Checks if a remote computer has a pending reboot.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-PendingReboot -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $pendingReboot = $false
        $reasons = @()
        
        $cbs = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
        } -ErrorAction SilentlyContinue
        
        if ($cbs) {
            $pendingReboot = $true
            $reasons += "CBS"
        }
        
        $wu = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
        } -ErrorAction SilentlyContinue
        
        if ($wu) {
            $pendingReboot = $true
            $reasons += "WindowsUpdate"
        }
        
        $pfro = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $prop = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
            return ($null -ne $prop -and $prop.PendingFileRenameOperations)
        } -ErrorAction SilentlyContinue
        
        if ($pfro) {
            $pendingReboot = $true
            $reasons += "FileRename"
        }
        
        $sccm = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                $ccmClientSDK = Invoke-CimMethod -Namespace "root\ccm\ClientSDK" -ClassName CCM_ClientUtilities -MethodName DetermineIfRebootPending -ErrorAction Stop
                return ($ccmClientSDK.RebootPending -or $ccmClientSDK.IsHardRebootPending)
            } catch {
                return $false
            }
        } -ErrorAction SilentlyContinue
        
        if ($sccm) {
            $pendingReboot = $true
            $reasons += "SCCM"
        }
        
        if ($pendingReboot) {
            return "Yes ($($reasons -join ', '))"
        } else {
            return "No"
        }
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

function Get-GPLastUpdate {
    <#
    .SYNOPSIS
        Gets the timestamp when Group Policy was last applied on a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-GPLastUpdate -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $gpUpdate = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                $userGP = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Extension-List\{00000000-0000-0000-0000-000000000000}" -Name EndTimeHi,EndTimeLo -ErrorAction SilentlyContinue
                
                if ($userGP -and $userGP.EndTimeHi -and $userGP.EndTimeLo) {
                    $fileTime = ([Int64]$userGP.EndTimeHi -shl 32) -bor $userGP.EndTimeLo
                    $lastUpdate = [DateTime]::FromFileTime($fileTime)
                    return $lastUpdate
                }
                
                $gpResult = gpresult /R /SCOPE:COMPUTER | Select-String "Last time Group Policy was applied"
                if ($gpResult) {
                    $dateString = $gpResult.ToString() -replace ".*:\s*", ""
                    return [DateTime]::Parse($dateString)
                }
                
                return $null
            } catch {
                return $null
            }
        } -ErrorAction Stop
        
        if ($gpUpdate) {
            return $gpUpdate.ToString("yyyy-MM-dd HH:mm")
        } else {
            return "Unknown"
        }
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

#endregion

#region System Health Functions

function Get-PrefetchSize {
    <#
    .SYNOPSIS
        Gets the size of the Prefetch folder on a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-PrefetchSize -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $prefetchPath = "\\$ComputerName\c$\Windows\Prefetch"
        
        if (Test-Path $prefetchPath) {
            $files = Get-ChildItem -Path $prefetchPath -File -ErrorAction Stop
            $totalSize = ($files | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum
            $fileCount = $files.Count
            
            $sizeInMB = [math]::Round($totalSize / 1MB, 2)
            return "$sizeInMB MB ($fileCount files)"
        } else {
            return "N/A (Prefetch disabled)"
        }
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

function Get-SCCMHealth {
    <#
    .SYNOPSIS
        Checks SCCM client health on a remote computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-SCCMHealth -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $healthResult = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $healthMessages = @()
            
            $clientPath = "C:\Windows\CCM\CcmExec.exe"
            if (-not (Test-Path $clientPath)) {
                $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='CcmExec.exe missing.'; Priority=1}
            }
            
            try {
                $service = Get-Service -Name CcmExec -ErrorAction Stop
                if ($service.Status -ne 'Running') {
                    $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='CcmExec service stopped.'; Priority=2}
                }
            } catch {
                $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='CcmExec service missing.'; Priority=3}
            }
            
            try {
                $smsClient = Get-CimInstance -Namespace "root\ccm" -ClassName SMS_Client -ErrorAction Stop
                if (-not $smsClient -or -not $smsClient.ClientVersion) {
                    $healthMessages += [PSCustomObject]@{Severity='Warning'; Message='Client version not available.'; Priority=50}
                }
            } catch {
                $healthMessages += [PSCustomObject]@{Severity='Warning'; Message='SMS_Client class inaccessible.'; Priority=51}
            }
            
            try {
                $mp = Get-CimInstance -Namespace "root\ccm" -ClassName SMS_Authority -ErrorAction Stop
                if (-not $mp -or -not $mp.Name) {
                    $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='Site Code not available.'; Priority=4}
                }
            } catch {
                $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='SMS_Authority class inaccessible.'; Priority=5}
            }
            
            try {
                $ccmClient = Get-CimInstance -Namespace "root\ccm" -ClassName CCM_Client -ErrorAction Stop
                if (-not $ccmClient -or -not $ccmClient.ClientId) {
                    $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='Client ID not available.'; Priority=6}
                }
            } catch {
                $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='CCM_Client class inaccessible.'; Priority=7}
            }
            
            try {
                $clientSDKTest = Get-CimInstance -Namespace "root\ccm\ClientSDK" -ClassName CCM_Application -ErrorAction Stop | Select-Object -First 1
                if (-not $clientSDKTest) {
                    $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='ClientSDK namespace empty.'; Priority=8}
                }
            } catch {
                $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='ClientSDK namespace corrupt.'; Priority=9}
            }
            
            try {
                $policyResult = Get-CimInstance -Namespace "root\ccm\Policy\Machine\ActualConfig" -ClassName CCM_TaskSequence -ErrorAction Stop
                if (-not $policyResult -or $policyResult.Count -eq 0) {
                    $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='Policy namespace empty.'; Priority=10}
                }
            } catch {
                $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='Policy namespace corrupt.'; Priority=11}
            }
            
            try {
                $mp = Get-CimInstance -Namespace "root\ccm" -ClassName SMS_Authority -ErrorAction Stop
                if (-not $mp -or -not $mp.CurrentManagementPoint) {
                    $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='Management Point not available.'; Priority=14}
                }
            } catch {
                $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='Management Point inaccessible.'; Priority=15}
            }
            
            if ($healthMessages.Count -eq 0) {
                return "Healthy"
            } elseif ($healthMessages.Count -eq 1) {
                return "Corrupt Client: [$($healthMessages[0].Severity)] $($healthMessages[0].Message)"
            } else {
                $sortedMessages = $healthMessages | Sort-Object Priority, Severity, Message
                $topError = $sortedMessages[0]
                $additionalCount = $healthMessages.Count - 1
                return "Corrupt Client: [$($topError.Severity)] $($topError.Message) (+ $additionalCount more issues)"
            }
        } -ErrorAction Stop
        
        return $healthResult
    } catch {
        return "ERROR: $($_.Exception.Message)"
    }
}

#endregion

#region Wrapper Functions

function Get-AllNetworkInfo {
    <#
    .SYNOPSIS
        Gets all network-related information from a remote computer.
    
    .DESCRIPTION
        Collects DNS servers, default gateway, and network shares from the target computer.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-AllNetworkInfo -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    $networkDetails = Get-NetworkDetails -ComputerName $ComputerName
    
    return [PSCustomObject]@{
        ComputerName = $ComputerName.ToUpper()
        DNSServers = $networkDetails.DNS
        DefaultGateway = $networkDetails.Gateway
        NetworkShares = Get-SharesInfo -ComputerName $ComputerName
    }
}

function Get-AllADInfo {
    <#
    .SYNOPSIS
        Gets all Active Directory related information from a remote computer.
    
    .DESCRIPTION
        Collects AD last logon timestamp and domain controller information.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-AllADInfo -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    return [PSCustomObject]@{
        ComputerName = $ComputerName.ToUpper()
        ADLastLogon = Get-ADLastLogon -ComputerName $ComputerName
        DomainController = Get-DomainController -ComputerName $ComputerName
    }
}

function Get-AllUserInfo {
    <#
    .SYNOPSIS
        Gets all user-related information from a remote computer.
    
    .DESCRIPTION
        Collects current user, last logged on user, primary user, and local administrators.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-AllUserInfo -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    return [PSCustomObject]@{
        ComputerName = $ComputerName.ToUpper()
        CurrentUser = Get-CurrentUser -ComputerName $ComputerName
        LastLoggedOnUser = Get-LastLoggedOnUser -ComputerName $ComputerName
        PrimaryUser = Get-PrimaryUser -ComputerName $ComputerName
        LocalAdministrators = Get-LocalAdmins -ComputerName $ComputerName
    }
}

function Get-AllHardwareInfo {
    <#
    .SYNOPSIS
        Gets all hardware-related information from a remote computer.
    
    .DESCRIPTION
        Collects chassis type, disk space, monitor count, and battery health information.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-AllHardwareInfo -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    $chassisInfo = Get-ChassisType -ComputerName $ComputerName
    
    $result = [PSCustomObject]@{
        ComputerName = $ComputerName.ToUpper()
        ChassisType = $chassisInfo.ChassisType
        VMType = if ($chassisInfo.ContainsKey('VMType')) { $chassisInfo.VMType } else { "N/A" }
        DiskSpace = Get-DriveSpace -ComputerName $ComputerName
        MonitorCount = Get-MonitorCount -ComputerName $ComputerName
        BatteryHealth = Get-BatteryHealth -ComputerName $ComputerName
    }
    
    return $result
}

function Get-AllSecurityInfo {
    <#
    .SYNOPSIS
        Gets all security-related information from a remote computer.
    
    .DESCRIPTION
        Collects TPM status, BitLocker status, and Windows Defender information.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-AllSecurityInfo -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    $defenderInfo = Get-WindowsDefenderInfo -ComputerName $ComputerName
    
    return [PSCustomObject]@{
        ComputerName = $ComputerName.ToUpper()
        TPMStatus = Get-TPMStatus -ComputerName $ComputerName
        BitLockerStatus = Get-BitLockerStatus -ComputerName $ComputerName
        DefenderVersion = $defenderInfo.Version
        DefenderSignatureVersion = $defenderInfo.SignatureVersion
        DefenderSignatureLastUpdated = $defenderInfo.SignatureLastUpdated
        DefenderLastScanType = $defenderInfo.LastScanType
        DefenderLastScanTime = $defenderInfo.LastScanTime
        DefenderStatus = $defenderInfo.Status
    }
}

function Get-AllUpdateInfo {
    <#
    .SYNOPSIS
        Gets all Windows Update and maintenance information from a remote computer.
    
    .DESCRIPTION
        Collects last Windows Update date, pending updates count, Group Policy last applied, and pending reboot status.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-AllUpdateInfo -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    return [PSCustomObject]@{
        ComputerName = $ComputerName.ToUpper()
        LastWindowsUpdate = Get-LastWindowsUpdate -ComputerName $ComputerName
        PendingUpdatesCount = Get-PendingUpdatesCount -ComputerName $ComputerName
        GroupPolicyLastApplied = Get-GPLastUpdate -ComputerName $ComputerName
        PendingReboot = Get-PendingReboot -ComputerName $ComputerName
    }
}

function Get-AllSystemHealthInfo {
    <#
    .SYNOPSIS
        Gets all system health information from a remote computer.
    
    .DESCRIPTION
        Collects prefetch folder size and SCCM client health status.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .EXAMPLE
        Get-AllSystemHealthInfo -ComputerName "PC01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    return [PSCustomObject]@{
        ComputerName = $ComputerName.ToUpper()
        PrefetchSize = Get-PrefetchSize -ComputerName $ComputerName
        SCCMHealth = Get-SCCMHealth -ComputerName $ComputerName
    }
}

function Get-CompleteInventory {
    <#
    .SYNOPSIS
        Gets a complete inventory of all information from a remote computer.
    
    .DESCRIPTION
        Runs all inventory functions and returns a comprehensive report of the remote computer.
        This includes hardware, network, security, users, updates, and system health information.
    
    .PARAMETER ComputerName
        The name of the remote computer to query.
    
    .PARAMETER IncludeSCCM
        Include SCCM health check. Default is $true.
    
    .EXAMPLE
        Get-CompleteInventory -ComputerName "PC01"
    
    .EXAMPLE
        Get-CompleteInventory -ComputerName "PC01" -IncludeSCCM $false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory=$false)]
        [bool]$IncludeSCCM = $true
    )
    
    Write-Verbose "Collecting complete inventory for $ComputerName"
    
    # Test connectivity first
    try {
        $pingResult = Test-Connection -ComputerName $ComputerName -Count 2 -Quiet -ErrorAction Stop
        if (-not $pingResult) {
            return [PSCustomObject]@{
                ComputerName = $ComputerName.ToUpper()
                Status = "Offline"
                ErrorMessage = "No ping response"
            }
        }
    } catch {
        return [PSCustomObject]@{
            ComputerName = $ComputerName.ToUpper()
            Status = "Offline"
            ErrorMessage = $_.Exception.Message
        }
    }
    
    # Get basic system information
    try {
        $bios = Get-CimInstance -ClassName Win32_BIOS -ComputerName $ComputerName -ErrorAction Stop
        $hardware = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $ComputerName -ErrorAction Stop
        $cpu = Get-CimInstance -ClassName Win32_Processor -ComputerName $ComputerName -ErrorAction Stop | Select-Object -First 1
        $networks = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ComputerName $ComputerName -ErrorAction Stop |
            Where-Object { $_.IPEnabled }
    } catch {
        return [PSCustomObject]@{
            ComputerName = $ComputerName.ToUpper()
            Status = "Error"
            ErrorMessage = "Failed to retrieve basic system information: $($_.Exception.Message)"
        }
    }
    
    # Calculate uptime
    $lastBoot = $os.ConvertToDateTime($os.LastBootUpTime)
    $uptime = (Get-Date) - $lastBoot
    
    # Get all category information
    Write-Verbose "  Getting hardware information..."
    $hwInfo = Get-AllHardwareInfo -ComputerName $ComputerName
    
    Write-Verbose "  Getting network information..."
    $netInfo = Get-AllNetworkInfo -ComputerName $ComputerName
    
    Write-Verbose "  Getting user information..."
    $userInfo = Get-AllUserInfo -ComputerName $ComputerName
    
    Write-Verbose "  Getting security information..."
    $secInfo = Get-AllSecurityInfo -ComputerName $ComputerName
    
    Write-Verbose "  Getting update information..."
    $updateInfo = Get-AllUpdateInfo -ComputerName $ComputerName
    
    Write-Verbose "  Getting system health information..."
    $healthInfo = Get-AllSystemHealthInfo -ComputerName $ComputerName
    
    # Get AD info if applicable
    $adInfo = $null
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop
        if ($cs.PartOfDomain) {
            Write-Verbose "  Getting Active Directory information..."
            $adInfo = Get-AllADInfo -ComputerName $ComputerName
        }
    } catch {}
    
    # Build comprehensive result
    $result = [PSCustomObject]@{
        ComputerName = $ComputerName.ToUpper()
        Status = "Online"
        
        # Basic Info
        Manufacturer = $hardware.Manufacturer
        Model = $hardware.Model
        SerialNumber = $bios.SerialNumber
        BIOSVersion = $bios.SMBIOSBIOSVersion
        Architecture = $hardware.SystemType
        
        # OS Info
        OperatingSystem = $os.Caption
        OSVersion = $os.Version
        OSBuildNumber = $os.BuildNumber
        InstallDate = $os.InstallDate
        
        # Hardware Info
        ChassisType = $hwInfo.ChassisType
        VMType = $hwInfo.VMType
        RAM_GB = [math]::Round($hardware.TotalPhysicalMemory / 1GB, 2)
        CPUName = $cpu.Name
        CPUCores = $cpu.NumberOfCores
        CPULogicalProcessors = $cpu.NumberOfLogicalProcessors
        DiskSpace = $hwInfo.DiskSpace
        MonitorCount = $hwInfo.MonitorCount
        BatteryHealth = $hwInfo.BatteryHealth
        
        # Network Info
        IPAddress = if ($networks) { $networks[0].IPAddress[0] } else { "N/A" }
        MACAddress = if ($networks) { $networks[0].MACAddress } else { "N/A" }
        DNSServers = $netInfo.DNSServers
        DefaultGateway = $netInfo.DefaultGateway
        NetworkShares = $netInfo.NetworkShares
        
        # User Info
        CurrentUser = $userInfo.CurrentUser
        LastLoggedOnUser = $userInfo.LastLoggedOnUser
        PrimaryUser = $userInfo.PrimaryUser
        LocalAdministrators = $userInfo.LocalAdministrators
        
        # Security Info
        TPMStatus = $secInfo.TPMStatus
        BitLockerStatus = $secInfo.BitLockerStatus
        DefenderVersion = $secInfo.DefenderVersion
        DefenderSignatureVersion = $secInfo.DefenderSignatureVersion
        DefenderSignatureUpdated = if ($secInfo.DefenderSignatureLastUpdated) { 
            $secInfo.DefenderSignatureLastUpdated.ToString("yyyy-MM-dd HH:mm") 
        } else { "N/A" }
        DefenderLastScan = if ($secInfo.DefenderLastScanTime) {
            "$($secInfo.DefenderLastScanType) - $($secInfo.DefenderLastScanTime.ToString('yyyy-MM-dd HH:mm'))"
        } else { $secInfo.DefenderLastScanType }
        DefenderStatus = $secInfo.DefenderStatus
        
        # Update Info
        Uptime = "$([math]::Floor($uptime.TotalDays)) days"
        LastWindowsUpdate = $updateInfo.LastWindowsUpdate
        PendingUpdates = $updateInfo.PendingUpdatesCount
        GroupPolicyLastApplied = $updateInfo.GroupPolicyLastApplied
        PendingReboot = $updateInfo.PendingReboot
        
        # System Health Info
        PrefetchSize = $healthInfo.PrefetchSize
        SCCMHealth = if ($IncludeSCCM) { $healthInfo.SCCMHealth } else { "Skipped" }
        
        # AD Info
        ADLastLogon = if ($adInfo) { $adInfo.ADLastLogon } else { "N/A" }
        DomainController = if ($adInfo) { $adInfo.DomainController } else { "N/A" }
    }
    
    return $result
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Write-LogMessage',
    'Get-SharesInfo',
    'Get-NetworkDetails',
    'Get-ADLastLogon',
    'Get-DomainController',
    'Get-CurrentUser',
    'Get-LastLoggedOnUser',
    'Get-PrimaryUser',
    'Get-LocalAdmins',
    'Get-DriveSpace',
    'Get-ChassisType',
    'Get-MonitorCount',
    'Get-BatteryHealth',
    'Get-TPMStatus',
    'Get-BitLockerStatus',
    'Get-WindowsDefenderInfo',
    'Get-LastWindowsUpdate',
    'Get-PendingUpdatesCount',
    'Get-PendingReboot',
    'Get-GPLastUpdate',
    'Get-PrefetchSize',
    'Get-SCCMHealth',
    'Get-AllNetworkInfo',
    'Get-AllADInfo',
    'Get-AllUserInfo',
    'Get-AllHardwareInfo',
    'Get-AllSecurityInfo',
    'Get-AllUpdateInfo',
    'Get-AllSystemHealthInfo',
    'Get-CompleteInventory'
)
