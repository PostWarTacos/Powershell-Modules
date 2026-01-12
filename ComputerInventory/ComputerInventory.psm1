# Note: Most functions in this module require administrator privileges to query remote computers.
# Individual functions will fail gracefully if run without proper permissions.


#region Computer Identity Helper
function Resolve-ComputerIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Computer
    )
    $resolvedHost = $null
    $resolvedIP = $null

    # Regex for IPv4 and IPv6
    $ipRegex = '^(?:\d{1,3}\.){3}\d{1,3}$|^([a-fA-F0-9:]+:+)+[a-fA-F0-9]+$'

    # Check for local machine
    if ($Computer -eq $env:COMPUTERNAME -or $Computer -eq 'localhost' -or $Computer -eq '.') {
        $resolvedHost = $env:COMPUTERNAME
        # Get first non-loopback IPv4 address from any 'Up' adapter
        $upAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        $upIfIndexes = $upAdapters | Select-Object -ExpandProperty IfIndex
        $resolvedIP = $null
        if ($upIfIndexes) {
            $resolvedIP = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.InterfaceIndex -in $upIfIndexes -and $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' } |
                Select-Object -ExpandProperty IPAddress -First 1)
        }
        if (-not $resolvedIP) {
            # Fallback: any IPv4
            $resolvedIP = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -ne '127.0.0.1' } |
                Select-Object -ExpandProperty IPAddress -First 1)
        }
        if (-not $resolvedIP) { $resolvedIP = '127.0.0.1' }
    } elseif ($Computer -match $ipRegex) {
        # Input is an IP address, resolve hostname
        $resolvedIP = $Computer
        try {
            $ptr = [System.Net.Dns]::GetHostEntry($Computer)
            if ($ptr.HostName) {
                $resolvedHost = $ptr.HostName
            } elseif ($ptr.Aliases -and $ptr.Aliases.Count -gt 0) {
                $resolvedHost = $ptr.Aliases[0]
            } else {
                $resolvedHost = $Computer
            }
        } catch {
            $resolvedHost = $Computer
        }
    } else {
        # Input is a hostname, resolve IP
        $resolvedHost = $Computer
        try {
            $dns = Resolve-DnsName -Name $Computer -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress }
            if ($dns) {
                $resolvedIP = $dns[0].IPAddress
            } else {
                $resolvedIP = $Computer
            }
        } catch {
            $resolvedIP = $Computer
        }
    }
    [PSCustomObject]@{
        Hostname = if ($resolvedHost) { $resolvedHost } else { 'null' }
        IP = if ($resolvedIP) { $resolvedIP } else { 'null' }
    }
}
#endregion
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

#region Dependency Checks

# Try to import Utilities module if available, but don't block module load if not found
if (-not (Get-Command Write-LogMessage -ErrorAction SilentlyContinue)) {
    try {
        $utilitiesPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'Utilities\Utilities.psm1'
        if (Test-Path $utilitiesPath) {
            Import-Module $utilitiesPath -ErrorAction Stop
        } else {
            # Download from GitHub if not found locally
            $url = "https://raw.githubusercontent.com/PostWarTacos/Powershell-Modules/main/Utilities/Utilities.psm1"
            $localPath = Join-Path $env:TEMP 'Utilities.psm1'
            Invoke-WebRequest -Uri $url -OutFile $localPath
            Import-Module $localPath -ErrorAction Stop
        }
    } catch {
        Write-Warning "Write-LogMessage not found. Please ensure Utilities module is available or check download/import permissions."
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        $ComputerName = @($env:COMPUTERNAME)
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            if (Get-Command Get-SmbShare -ErrorAction SilentlyContinue) {
                $shares = Get-SmbShare -CimSession $identity.Hostname -ErrorAction Stop
                $results += [PSCustomObject]@{ Hostname = $identity.Hostname; IP = $identity.IP; Shares = ($shares | ForEach-Object { "$($_.Name) ($($_.Path))" }) }
            } else {
                $shares = Get-CimInstance -ClassName Win32_Share -ComputerName $identity.Hostname -ErrorAction Stop
                $results += [PSCustomObject]@{ Computer = $identity.Computer; Hostname = $identity.Hostname; IP = $identity.IP; Shares = ($shares | ForEach-Object { "$($_.Name) ($($_.Path))" }) }
            }
        } catch {
            $results += [PSCustomObject]@{ Hostname = $identity.Hostname; IP = $identity.IP; Shares = "ERROR: $($_.Exception.Message)" }
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        $ComputerName = @($env:COMPUTERNAME)
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            if ($identity.Hostname -eq $env:COMPUTERNAME -or $identity.Hostname -eq 'localhost' -or $name -eq $env:COMPUTERNAME -or $name -eq 'localhost') {
                # Local logic (unchanged)
                $adapters = Get-NetAdapter
                $ipObjs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceIndex -in $adapters.IfIndex }
                $primaryIP = [string]$identity.IP
                $primaryAdapter = $null
                foreach ($adapter in $adapters) {
                    $ips = $ipObjs | Where-Object { $_.InterfaceIndex -eq $adapter.IfIndex } | Select-Object -ExpandProperty IPAddress
                    if ($ips -and ($ips -contains $primaryIP)) {
                        $primaryAdapter = $adapter
                        break
                    }
                }
                if ($primaryAdapter) {
                    $ipconfig = Get-NetIPConfiguration -InterfaceIndex $primaryAdapter.IfIndex
                    $dnsServers = if ($ipconfig.DnsServer.ServerAddresses) { $ipconfig.DnsServer.ServerAddresses -join ", " } else { "N/A" }
                    $gateway = if ($ipconfig.IPv4DefaultGateway) { $ipconfig.IPv4DefaultGateway.NextHop } else { "N/A" }
                } else {
                    $dnsServers = "N/A"
                    $gateway = "N/A"
                }
                $row = [ordered]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    DNS = $dnsServers
                    Gateway = $gateway
                }
                $i = 1
                foreach ($adapter in $adapters) {
                    $mac = $adapter.MacAddress
                    $status = $adapter.Status
                    $ips = @($ipObjs | Where-Object { $_.InterfaceIndex -eq $adapter.IfIndex } | Select-Object -ExpandProperty IPAddress)
                    $row["Int$($i) MAC"] = $mac
                    $row["Int$($i) Status"] = $status
                    if ($ips.Count -gt 0 -and [string]::IsNullOrWhiteSpace($ips[0]) -eq $false) {
                        $row["Int$($i) IP"] = $ips[0]
                    } else {
                        $row["Int$($i) IP"] = $null
                    }
                    $i++
                }
                $results += [PSCustomObject]$row
            } else {
                # Remote logic
                $remoteResult = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
                    param($primaryIP)
                    $adapters = Get-NetAdapter
                    $ipObjs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceIndex -in $adapters.IfIndex }
                    $primaryAdapter = $null
                    foreach ($adapter in $adapters) {
                        $ips = $ipObjs | Where-Object { $_.InterfaceIndex -eq $adapter.IfIndex } | Select-Object -ExpandProperty IPAddress
                        if ($ips -and ($ips -contains $primaryIP)) {
                            $primaryAdapter = $adapter
                            break
                        }
                    }
                    if ($primaryAdapter) {
                        $ipconfig = Get-NetIPConfiguration -InterfaceIndex $primaryAdapter.IfIndex
                        $dnsServers = if ($ipconfig.DnsServer.ServerAddresses) { $ipconfig.DnsServer.ServerAddresses -join ", " } else { "N/A" }
                        $gateway = if ($ipconfig.IPv4DefaultGateway) { $ipconfig.IPv4DefaultGateway.NextHop } else { "N/A" }
                    } else {
                        $dnsServers = "N/A"
                        $gateway = "N/A"
                    }
                    $row = [ordered]@{
                        Hostname = $env:COMPUTERNAME
                        IP = $primaryIP
                        DNS = $dnsServers
                        Gateway = $gateway
                    }
                    $i = 1
                    foreach ($adapter in $adapters) {
                        $mac = $adapter.MacAddress
                        $status = $adapter.Status
                        $ips = @($ipObjs | Where-Object { $_.InterfaceIndex -eq $adapter.IfIndex } | Select-Object -ExpandProperty IPAddress)
                        $row["Int$($i) MAC"] = $mac
                        $row["Int$($i) Status"] = $status
                        if ($ips.Count -gt 0 -and [string]::IsNullOrWhiteSpace($ips[0]) -eq $false) {
                            $row["Int$($i) IP"] = $ips[0]
                        } else {
                            $row["Int$($i) IP"] = $null
                        }
                        $i++
                    }
                    # Ensure the object is returned as a single object, not an array or flattened
                    ,([PSCustomObject]$row)
                } -ArgumentList $identity.IP
                $results += $remoteResult
            }
        } catch {
            $results += [PSCustomObject]@{ Hostname = $identity.Hostname; IP = $identity.IP; DNS = "ERROR"; Gateway = "ERROR" }
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        Write-LogMessage "No computer name provided." -Level Error
        return
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            $lastLogon = $null
            if (Get-Module -ListAvailable -Name ActiveDirectory) {
                Import-Module ActiveDirectory -ErrorAction SilentlyContinue
                $computer = Get-ADComputer -Identity $identity.Hostname -Properties LastLogonTimeStamp -ErrorAction Stop
                if ($computer.LastLogonTimeStamp) {
                    $lastLogon = [DateTime]::FromFileTime($computer.LastLogonTimeStamp)
                } else {
                    $lastLogon = "Never"
                }
            } else {
                $searcher = New-Object System.DirectoryServices.DirectorySearcher
                $searcher.Filter = "(&(objectCategory=computer)(name=$($identity.Hostname)))"
                $searcher.PropertiesToLoad.Add("lastLogonTimeStamp") | Out-Null
                $adSearchResult = $searcher.FindOne()
                if ($adSearchResult -and $adSearchResult.Properties["lastLogonTimeStamp"][0]) {
                    $lastLogon = [DateTime]::FromFileTime($adSearchResult.Properties["lastLogonTimeStamp"][0])
                } else {
                    $lastLogon = "Never"
                }
            }
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                LastLogon = $lastLogon
            }
        } catch {
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                LastLogon = "ERROR: $($_.Exception.Message)"
            }
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        Write-LogMessage "No computer name provided." -Level Error
        return
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            $dc = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
                try {
                    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
                    if (-not $cs.PartOfDomain) {
                        return "Not Domain Joined"
                    }
                    $logonServer = $env:LOGONSERVER
                    if ($logonServer) {
                        return $logonServer -replace '\\', ''
                    }
                    $nltest = nltest /dsgetdc: 2>&1
                    if ($nltest -match 'DC:\s*\\\\(.+)') {
                        return $matches[1]
                    }
                    return "Unknown"
                } catch {
                    return "ERROR"
                }
            } -ErrorAction Stop
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                DomainController = $dc
            }
        } catch {
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                DomainController = "ERROR: $($_.Exception.Message)"
            }
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        Write-LogMessage "No computer name provided." -Level Error
        return
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            $loggedOnUser = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $identity.Hostname -ErrorAction Stop
            $currentUser = $null
            if ($loggedOnUser.UserName) {
                $username = $loggedOnUser.UserName.Split('\\')[-1]
                try {
                    if (Get-Module -ListAvailable -Name ActiveDirectory) {
                        Import-Module ActiveDirectory -ErrorAction SilentlyContinue
                        $adUser = Get-ADUser $username -ErrorAction SilentlyContinue
                        if ($adUser) {
                            $currentUser = "$($adUser.Name) ($username)"
                        }
                    }
                } catch {}
                if (-not $currentUser) { $currentUser = $username }
            } else {
                $currentUser = "None"
            }
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                CurrentUser = $currentUser
            }
        } catch {
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                CurrentUser = "ERROR: $($_.Exception.Message)"
            }
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        Write-LogMessage "No computer name provided." -Level Error
        return
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            $userDir = Get-ChildItem "\\$($identity.Hostname)\c$\Users" -ErrorAction Stop |
                Where-Object {
                    $_.PSIsContainer -and 
                    $_.Name -notmatch '^(Public|Default|Default User|All Users|Admin|Administrator)$'
                } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            $lastUser = $null
            if ($userDir) {
                try {
                    if (Get-Module -ListAvailable -Name ActiveDirectory) {
                        Import-Module ActiveDirectory -ErrorAction SilentlyContinue
                        $adUser = Get-ADUser $userDir.Name -ErrorAction SilentlyContinue
                        if ($adUser) {
                            $lastUser = "$($adUser.Name) ($($userDir.Name))"
                        }
                    }
                } catch {}
                if (-not $lastUser) { $lastUser = $userDir.Name }
            } else {
                $lastUser = "Unknown"
            }
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                LastLoggedOnUser = $lastUser
            }
        } catch {
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                LastLoggedOnUser = "ERROR: $($_.Exception.Message)"
            }
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        Write-LogMessage "No computer name provided." -Level Error
        return
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            $userDirs = Get-ChildItem "\\$($identity.Hostname)\c$\Users" -ErrorAction Stop |
                Where-Object {
                    $_.PSIsContainer -and 
                    $_.Name -notmatch '^(Public|Default|Default User|All Users|Admin|Administrator)$'
                }
            $primaryUser = $null
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
                $primaryUserObj = $userStats | Sort-Object ProfileSize -Descending | Select-Object -First 1
                if ($primaryUserObj) {
                    try {
                        if (Get-Module -ListAvailable -Name ActiveDirectory) {
                            Import-Module ActiveDirectory -ErrorAction SilentlyContinue
                            $adUser = Get-ADUser $primaryUserObj.UserName -ErrorAction SilentlyContinue
                            if ($adUser) {
                                $primaryUser = "$($adUser.Name) ($($primaryUserObj.UserName))"
                            }
                        }
                    } catch {}
                    if (-not $primaryUser) { $primaryUser = $primaryUserObj.UserName }
                } else {
                    $primaryUser = "Unknown"
                }
            } else {
                $primaryUser = "No Users"
            }
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                PrimaryUser = $primaryUser
            }
        } catch {
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                PrimaryUser = "ERROR: $($_.Exception.Message)"
            }
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        Write-LogMessage "No computer name provided." -Level Error
        return
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            $admins = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
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
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                LocalAdmins = $admins
            }
        } catch {
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                LocalAdmins = "ERROR: $($_.Exception.Message)"
            }
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        Write-LogMessage "No computer name provided." -Level Error
        return
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            $drive = Get-CimInstance -ClassName Win32_Volume -ComputerName $identity.Hostname -Filter "drivetype = 3" -ErrorAction Stop |
                Where-Object { $_.DriveLetter -eq 'C:' } |
                Select-Object -First 1
            $driveSpace = $null
            if ($drive) {
                $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
                $totalGB = [math]::Round($drive.Capacity / 1GB, 2)
                $percentFree = [math]::Round(($drive.FreeSpace / $drive.Capacity) * 100, 1)
                $driveSpace = "$freeGB GB free of $totalGB GB ($percentFree%)"
            } else {
                $driveSpace = "N/A"
            }
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                DriveSpace = $driveSpace
            }
        } catch {
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                DriveSpace = "ERROR"
            }
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        Write-LogMessage "No computer name provided." -Level Error
        return
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $identity.Hostname -ErrorAction Stop
            $bios = Get-CimInstance -ClassName Win32_BIOS -ComputerName $identity.Hostname -ErrorAction Stop
            $enclosure = Get-CimInstance -ClassName Win32_SystemEnclosure -ComputerName $identity.Hostname -ErrorAction Stop
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
                $battery = Get-CimInstance -ClassName Win32_Battery -ComputerName $identity.Hostname -ErrorAction SilentlyContinue
                if ($battery) {
                    $chassisName = "Laptop (Battery Detected)"
                }
            }
            $chassisResult = @{ ChassisType = $chassisName }
            if ($isVM) {
                $chassisResult.VMType = $vmType
            }
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                ChassisType = $chassisResult.ChassisType
                VMType = if ($chassisResult.ContainsKey('VMType')) { $chassisResult.VMType } else { 'N/A' }
            }
        } catch {
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                ChassisType = "ERROR"
                VMType = "ERROR"
            }
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        $ComputerName = @(Get-FileName -InitialDirectory $PWD)
        if (-not $ComputerName -or $ComputerName.Count -eq 0) {
            Write-LogMessage "No computer name provided or selected." -Level Error
            return
        }
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            $monitors = Get-CimInstance -ClassName WmiMonitorID -Namespace root\wmi -ComputerName $identity.Hostname -ErrorAction Stop
            $monitorCount = $null
            if ($monitors) {
                $count = ($monitors | Measure-Object).Count
                $monitorCount = "$count monitor(s)"
            } else {
                $monitorCount = "0 (or N/A)"
            }
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                MonitorCount = $monitorCount
            }
        } catch {
            try {
                $displays = Get-CimInstance -ClassName Win32_DesktopMonitor -ComputerName $identity.Hostname -ErrorAction Stop
                if ($displays) {
                    $count = ($displays | Measure-Object).Count
                    $monitorCount = "$count monitor(s)"
                } else {
                    $monitorCount = "N/A"
                }
            } catch {
                $monitorCount = "N/A"
            }
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                MonitorCount = $monitorCount
            }
        }
    }
    return $results
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
            [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
            [string[]]$ComputerName
        )

        if (-not $ComputerName) {
            $ComputerName = @(Get-FileName -InitialDirectory $PWD)
            if (-not $ComputerName -or $ComputerName.Count -eq 0) {
                Write-LogMessage "No computer name provided or selected." -Level Error
                return
            }
        }

        $results = @()
        foreach ($name in $ComputerName) {
            $identity = Resolve-ComputerIdentity $name
            try {
                $batteryInfo = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
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
                            $healthStatus = if ($healthPercent -ge 80) { "Good" } elseif ($healthPercent -ge 60) { "Fair" } else { "Poor" }
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
                                        $healthStatus = if ($healthPercent -ge 80) { "Good" } elseif ($healthPercent -ge 60) { "Fair" } else { "Poor" }
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
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    BatteryStatus = $batteryInfo.Status
                    BatteryHealth = $batteryInfo.Health
                }
            } catch {
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    BatteryStatus = "ERROR"
                    BatteryHealth = "ERROR: $($_.Exception.Message)"
                }
            }
        }
        return $results
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
            [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
            [string[]]$ComputerName
        )

        if (-not $ComputerName) {
            $ComputerName = @(Get-FileName -InitialDirectory $PWD)
            if (-not $ComputerName -or $ComputerName.Count -eq 0) {
                Write-LogMessage "No computer name provided or selected." -Level Error
                return
            }
        }

        $results = @()
        foreach ($name in $ComputerName) {
            $identity = Resolve-ComputerIdentity $name
            try {
                $tpm = Get-CimInstance -Namespace "root\CIMv2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ComputerName $identity.Hostname -ErrorAction Stop
                $status = "Not Present"
                if ($tpm) {
                    $enabled = $tpm.IsEnabled_InitialValue
                    $activated = $tpm.IsActivated_InitialValue
                    if ($enabled -and $activated) {
                        $status = "Enabled & Activated"
                    } elseif ($enabled) {
                        $status = "Enabled Only"
                    } else {
                        $status = "Disabled"
                    }
                }
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    TPMStatus = $status
                }
            } catch {
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    TPMStatus = "Not Available"
                }
            }
        }
        return $results
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
            [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
            [string[]]$ComputerName
        )

        if (-not $ComputerName) {
            $ComputerName = @(Get-FileName -InitialDirectory $PWD)
            if (-not $ComputerName -or $ComputerName.Count -eq 0) {
                Write-LogMessage "No computer name provided or selected." -Level Error
                return
            }
        }

        $results = @()
        foreach ($name in $ComputerName) {
            $identity = Resolve-ComputerIdentity $name
            try {
                $blv = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
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
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    BitLockerStatus = $blv
                }
            } catch {
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    BitLockerStatus = "N/A"
                }
            }
        }
        return $results
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
            [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
            [string[]]$ComputerName
        )

        if (-not $ComputerName) {
            $ComputerName = @(Get-FileName -InitialDirectory $PWD)
            if (-not $ComputerName -or $ComputerName.Count -eq 0) {
                Write-LogMessage "No computer name provided or selected." -Level Error
                return
            }
        }

        $results = @()
        foreach ($name in $ComputerName) {
            $identity = Resolve-ComputerIdentity $name
            try {
                $defenderInfo = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
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
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    Version = $defenderInfo.Version
                    SignatureVersion = $defenderInfo.SignatureVersion
                    SignatureLastUpdated = $defenderInfo.SignatureLastUpdated
                    LastScanType = $defenderInfo.LastScanType
                    LastScanTime = $defenderInfo.LastScanTime
                    Status = $defenderInfo.Status
                }
            } catch {
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    Version = "ERROR"
                    SignatureVersion = "ERROR"
                    SignatureLastUpdated = $null
                    LastScanType = "ERROR"
                    LastScanTime = $null
                    Status = "ERROR: $($_.Exception.Message)"
                }
            }
        }
        return $results
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
            [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
            [string[]]$ComputerName
        )

        if (-not $ComputerName) {
            $ComputerName = @(Get-FileName -InitialDirectory $PWD)
            if (-not $ComputerName -or $ComputerName.Count -eq 0) {
                Write-LogMessage "No computer name provided or selected." -Level Error
                return
            }
        }

        $results = @()
        foreach ($name in $ComputerName) {
            $identity = Resolve-ComputerIdentity $name
            try {
                $lastUpdate = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
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
                            $cbsLog = "C:\\Windows\\Logs\\CBS\\CBS.log"
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
                $dateStr = if ($lastUpdate) { $lastUpdate.ToString("yyyy-MM-dd") } else { "Unknown" }
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    LastWindowsUpdate = $dateStr
                }
            } catch {
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    LastWindowsUpdate = "ERROR"
                }
            }
        }
        return $results
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
            [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
            [string[]]$ComputerName
        )

        if (-not $ComputerName) {
            $ComputerName = @(Get-FileName -InitialDirectory $PWD)
            if (-not $ComputerName -or $ComputerName.Count -eq 0) {
                Write-LogMessage "No computer name provided or selected." -Level Error
                return
            }
        }

        $results = @()
        foreach ($name in $ComputerName) {
            $identity = Resolve-ComputerIdentity $name
            try {
                $updateCount = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
                    try {
                        $session = New-Object -ComObject Microsoft.Update.Session
                        $searcher = $session.CreateUpdateSearcher()
                        $searchResult = $searcher.Search("IsInstalled=0 and Type='Software'")
                        return $searchResult.Updates.Count
                    } catch {
                        return "ERROR"
                    }
                } -ErrorAction Stop
                $pendingStr = if ($updateCount -eq "ERROR") {
                    "ERROR"
                } elseif ($updateCount -eq 0) {
                    "0 (Up to date)"
                } else {
                    "$updateCount pending"
                }
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    PendingUpdates = $pendingStr
                }
            } catch {
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    PendingUpdates = "ERROR: $($_.Exception.Message)"
                }
            }
        }
        return $results
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
            [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
            [string[]]$ComputerName
        )

        if (-not $ComputerName) {
            $ComputerName = @(Get-FileName -InitialDirectory $PWD)
            if (-not $ComputerName -or $ComputerName.Count -eq 0) {
                Write-LogMessage "No computer name provided or selected." -Level Error
                return
            }
        }

        $results = @()
        foreach ($name in $ComputerName) {
            $identity = Resolve-ComputerIdentity $name
            try {
                $pendingReboot = $false
                $reasons = @()
                $cbs = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
                    Test-Path "HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Component Based Servicing\\RebootPending"
                } -ErrorAction SilentlyContinue
                if ($cbs) {
                    $pendingReboot = $true
                    $reasons += "CBS"
                }
                $wu = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
                    Test-Path "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired"
                } -ErrorAction SilentlyContinue
                if ($wu) {
                    $pendingReboot = $true
                    $reasons += "WindowsUpdate"
                }
                $pfro = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
                    $prop = Get-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
                    return ($null -ne $prop -and $prop.PendingFileRenameOperations)
                } -ErrorAction SilentlyContinue
                if ($pfro) {
                    $pendingReboot = $true
                    $reasons += "FileRename"
                }
                $sccm = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
                    try {
                        $ccmClientSDK = Invoke-CimMethod -Namespace "root\\ccm\\ClientSDK" -ClassName CCM_ClientUtilities -MethodName DetermineIfRebootPending -ErrorAction Stop
                        return ($ccmClientSDK.RebootPending -or $ccmClientSDK.IsHardRebootPending)
                    } catch {
                        return $false
                    }
                } -ErrorAction SilentlyContinue
                if ($sccm) {
                    $pendingReboot = $true
                    $reasons += "SCCM"
                }
                $status = if ($pendingReboot) { "Yes ($($reasons -join ', '))" } else { "No" }
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    PendingReboot = $status
                }
            } catch {
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    PendingReboot = "ERROR: $($_.Exception.Message)"
                }
            }
        }
        return $results
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
            [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
            [string[]]$ComputerName
        )

        if (-not $ComputerName) {
            $ComputerName = @(Get-FileName -InitialDirectory $PWD)
            if (-not $ComputerName -or $ComputerName.Count -eq 0) {
                Write-LogMessage "No computer name provided or selected." -Level Error
                return
            }
        }

        $results = @()
        foreach ($name in $ComputerName) {
            $identity = Resolve-ComputerIdentity $name
            try {
                $gpUpdate = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
                    try {
                        $userGP = Get-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Group Policy\\State\\Machine\\Extension-List\\{00000000-0000-0000-0000-000000000000}" -Name EndTimeHi,EndTimeLo -ErrorAction SilentlyContinue
                        if ($userGP -and $userGP.EndTimeHi -and $userGP.EndTimeLo) {
                            $fileTime = ([Int64]$userGP.EndTimeHi -shl 32) -bor $userGP.EndTimeLo
                            $lastUpdate = [DateTime]::FromFileTime($fileTime)
                            return $lastUpdate
                        }
                        $gpResult = gpresult /R /SCOPE:COMPUTER | Select-String "Last time Group Policy was applied"
                        if ($gpResult) {
                            $dateString = $gpResult.ToString() -replace ".*:\\s*", ""
                            return [DateTime]::Parse($dateString)
                        }
                        return $null
                    } catch {
                        return $null
                    }
                } -ErrorAction Stop
                $dateStr = if ($gpUpdate) { $gpUpdate.ToString("yyyy-MM-dd HH:mm") } else { "Unknown" }
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    GPLastUpdate = $dateStr
                }
            } catch {
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    GPLastUpdate = "ERROR: $($_.Exception.Message)"
                }
            }
        }
        return $results
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
            [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
            [string[]]$ComputerName
        )

        if (-not $ComputerName) {
            $ComputerName = @(Get-FileName -InitialDirectory $PWD)
            if (-not $ComputerName -or $ComputerName.Count -eq 0) {
                Write-LogMessage "No computer name provided or selected." -Level Error
                return
            }
        }

        $results = @()
        foreach ($name in $ComputerName) {
            $identity = Resolve-ComputerIdentity $name
            try {
                $prefetchPath = "\\$($identity.Hostname)\c$\Windows\Prefetch"
                if (Test-Path $prefetchPath) {
                    $files = Get-ChildItem -Path $prefetchPath -File -ErrorAction Stop
                    $totalSize = ($files | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum
                    $fileCount = $files.Count
                    $sizeInMB = [math]::Round($totalSize / 1MB, 2)
                    $sizeStr = "$sizeInMB MB ($fileCount files)"
                } else {
                    $sizeStr = "N/A (Prefetch disabled)"
                }
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    PrefetchSize = $sizeStr
                }
            } catch {
                $results += [PSCustomObject]@{
                    Hostname = $identity.Hostname
                    IP = $identity.IP
                    PrefetchSize = "ERROR: $($_.Exception.Message)"
                }
            }
        }
        return $results
}

function Get-SCCMHealth {
    <#
    .SYNOPSIS
        Checks SCCM client health on a remote computer.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        $ComputerName = @(Get-FileName -InitialDirectory $PWD)
        if (-not $ComputerName -or $ComputerName.Count -eq 0) {
            Write-LogMessage "No computer name provided or selected." -Level Error
            return
        }
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $identity = Resolve-ComputerIdentity $name
        try {
            $healthResult = Invoke-Command -ComputerName $identity.Hostname -ScriptBlock {
                $healthMessages = @()
                $clientPath = "C:\\Windows\\CCM\\CcmExec.exe"
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
                    $smsClient = Get-CimInstance -Namespace "root\\ccm" -ClassName SMS_Client -ErrorAction Stop
                    if (-not $smsClient -or -not $smsClient.ClientVersion) {
                        $healthMessages += [PSCustomObject]@{Severity='Warning'; Message='Client version not available.'; Priority=50}
                    }
                } catch {
                    $healthMessages += [PSCustomObject]@{Severity='Warning'; Message='SMS_Client class inaccessible.'; Priority=51}
                }
                try {
                    $mp = Get-CimInstance -Namespace "root\\ccm" -ClassName SMS_Authority -ErrorAction Stop
                    if (-not $mp -or -not $mp.Name) {
                        $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='Site Code not available.'; Priority=4}
                    }
                } catch {
                    $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='SMS_Authority class inaccessible.'; Priority=5}
                }
                try {
                    $ccmClient = Get-CimInstance -Namespace "root\\ccm" -ClassName CCM_Client -ErrorAction Stop
                    if (-not $ccmClient -or -not $ccmClient.ClientId) {
                        $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='Client ID not available.'; Priority=6}
                    }
                } catch {
                    $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='CCM_Client class inaccessible.'; Priority=7}
                }
                try {
                    $clientSDKTest = Get-CimInstance -Namespace "root\\ccm\\ClientSDK" -ClassName CCM_Application -ErrorAction Stop | Select-Object -First 1
                    if (-not $clientSDKTest) {
                        $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='ClientSDK namespace empty.'; Priority=8}
                    }
                } catch {
                    $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='ClientSDK namespace corrupt.'; Priority=9}
                }
                try {
                    $policyResult = Get-CimInstance -Namespace "root\\ccm\\Policy\\Machine\\ActualConfig" -ClassName CCM_TaskSequence -ErrorAction Stop
                    if (-not $policyResult -or $policyResult.Count -eq 0) {
                        $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='Policy namespace empty.'; Priority=10}
                    }
                } catch {
                    $healthMessages += [PSCustomObject]@{Severity='Critical'; Message='Policy namespace corrupt.'; Priority=11}
                }
                try {
                    $mp = Get-CimInstance -Namespace "root\\ccm" -ClassName SMS_Authority -ErrorAction Stop
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
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                SCCMHealth = $healthResult
            }
        } catch {
            $results += [PSCustomObject]@{
                Hostname = $identity.Hostname
                IP = $identity.IP
                SCCMHealth = "ERROR: $($_.Exception.Message)"
            }
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        $ComputerName = @(Get-FileName -InitialDirectory $PWD)
        if (-not $ComputerName -or $ComputerName.Count -eq 0) {
            Write-LogMessage "No computer name provided or selected." -Level Error
            return
        }
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $networkDetails = Get-NetworkDetails -ComputerName $name
        $shares = Get-SharesInfo -ComputerName $name
        $results += [PSCustomObject]@{
            Computer = $networkDetails.Computer
            Hostname = $networkDetails.Hostname
            IP = $networkDetails.IP
            DNSServers = $networkDetails.DNS
            DefaultGateway = $networkDetails.Gateway
            NetworkShares = $shares.Shares
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        $ComputerName = @(Get-FileName -InitialDirectory $PWD)
        if (-not $ComputerName -or $ComputerName.Count -eq 0) {
            Write-LogMessage "No computer name provided or selected." -Level Error
            return
        }
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $adLastLogon = Get-ADLastLogon -ComputerName $name
        $domainController = Get-DomainController -ComputerName $name
        $results += [PSCustomObject]@{
            Computer = $adLastLogon.Computer
            Hostname = $adLastLogon.Hostname
            IP = $adLastLogon.IP
            ADLastLogon = $adLastLogon.LastLogon
            DomainController = $domainController.DomainController
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        $ComputerName = @(Get-FileName -InitialDirectory $PWD)
        if (-not $ComputerName -or $ComputerName.Count -eq 0) {
            Write-LogMessage "No computer name provided or selected." -Level Error
            return
        }
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $currentUser = Get-CurrentUser -ComputerName $name
        $lastLoggedOnUser = Get-LastLoggedOnUser -ComputerName $name
        $primaryUser = Get-PrimaryUser -ComputerName $name
        $localAdmins = Get-LocalAdmins -ComputerName $name
        $results += [PSCustomObject]@{
            Computer = $currentUser.Computer
            Hostname = $currentUser.Hostname
            IP = $currentUser.IP
            CurrentUser = $currentUser.CurrentUser
            LastLoggedOnUser = $lastLoggedOnUser.LastLoggedOnUser
            PrimaryUser = $primaryUser.PrimaryUser
            LocalAdministrators = $localAdmins.LocalAdmins
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        $ComputerName = @(Get-FileName -InitialDirectory $PWD)
        if (-not $ComputerName -or $ComputerName.Count -eq 0) {
            Write-LogMessage "No computer name provided or selected." -Level Error
            return
        }
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $chassisInfo = Get-ChassisType -ComputerName $name
        $driveSpace = Get-DriveSpace -ComputerName $name
        $monitorCount = Get-MonitorCount -ComputerName $name
        $batteryHealth = Get-BatteryHealth -ComputerName $name
        $results += [PSCustomObject]@{
            Computer = $chassisInfo.Computer
            Hostname = $chassisInfo.Hostname
            IP = $chassisInfo.IP
            ChassisType = $chassisInfo.ChassisType
            VMType = $chassisInfo.VMType
            DiskSpace = $driveSpace.DriveSpace
            MonitorCount = $monitorCount.MonitorCount
            BatteryHealth = $batteryHealth.BatteryHealth
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        $ComputerName = @(Get-FileName -InitialDirectory $PWD)
        if (-not $ComputerName -or $ComputerName.Count -eq 0) {
            Write-LogMessage "No computer name provided or selected." -Level Error
            return
        }
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $defenderInfo = Get-WindowsDefenderInfo -ComputerName $name
        $tpmStatus = Get-TPMStatus -ComputerName $name
        $bitLockerStatus = Get-BitLockerStatus -ComputerName $name
        $results += [PSCustomObject]@{
            Computer = $defenderInfo.Computer
            Hostname = $defenderInfo.Hostname
            IP = $defenderInfo.IP
            TPMStatus = $tpmStatus.TPMStatus
            BitLockerStatus = $bitLockerStatus.BitLockerStatus
            DefenderVersion = $defenderInfo.Version
            DefenderSignatureVersion = $defenderInfo.SignatureVersion
            DefenderSignatureLastUpdated = $defenderInfo.SignatureLastUpdated
            DefenderLastScanType = $defenderInfo.LastScanType
            DefenderLastScanTime = $defenderInfo.LastScanTime
            DefenderStatus = $defenderInfo.Status
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        $ComputerName = @(Get-FileName -InitialDirectory $PWD)
        if (-not $ComputerName -or $ComputerName.Count -eq 0) {
            Write-LogMessage "No computer name provided or selected." -Level Error
            return
        }
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $lastUpdate = Get-LastWindowsUpdate -ComputerName $name
        $pendingUpdates = Get-PendingUpdatesCount -ComputerName $name
        $gpLastApplied = Get-GPLastUpdate -ComputerName $name
        $pendingReboot = Get-PendingReboot -ComputerName $name
        $results += [PSCustomObject]@{
            Computer = $lastUpdate.Computer
            Hostname = $lastUpdate.Hostname
            IP = $lastUpdate.IP
            LastWindowsUpdate = $lastUpdate.LastWindowsUpdate
            PendingUpdatesCount = $pendingUpdates.PendingUpdatesCount
            GroupPolicyLastApplied = $gpLastApplied.GPLastUpdate
            PendingReboot = $pendingReboot.PendingReboot
        }
    }
    return $results
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
        [Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )

    if (-not $ComputerName) {
        $ComputerName = @(Get-FileName -InitialDirectory $PWD)
        if (-not $ComputerName -or $ComputerName.Count -eq 0) {
            Write-LogMessage "No computer name provided or selected." -Level Error
            return
        }
    }

    $results = @()
    foreach ($name in $ComputerName) {
        $prefetch = Get-PrefetchSize -ComputerName $name
        $sccm = Get-SCCMHealth -ComputerName $name
        $results += [PSCustomObject]@{
            Computer = $prefetch.Computer
            Hostname = $prefetch.Hostname
            IP = $prefetch.IP
            PrefetchSize = $prefetch.PrefetchSize
            SCCMHealth = $sccm.SCCMHealth
        }
    }
    return $results
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
# Export all public functions
Export-ModuleMember -Function @(
    'Resolve-ComputerIdentity',
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