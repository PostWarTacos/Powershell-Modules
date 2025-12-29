# AdminTools Module - Provides sudo-like elevation for PowerShell

function admin {
    <#
    .SYNOPSIS
    Elevates a command or opens an elevated PowerShell window.
    
    .DESCRIPTION
    Works like sudo in Linux - runs commands in an elevated PowerShell window or opens a new elevated window.
    Use -net for admin credentials on both local and domain resources.
    
    .PARAMETER net
    Prompt for admin credentials that work on both local machine and domain resources.
    
    .PARAMETER args
    The command to run elevated. If omitted, opens an elevated PowerShell window.
    
    .EXAMPLE
    admin Get-Service
    Opens elevated window and runs Get-Service
    
    .EXAMPLE
    admin
    Opens a new elevated PowerShell window
    
    .EXAMPLE
    admin -net
    Opens PowerShell with admin credentials for both local and domain access
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$net,
        
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Command
    )
    
    # Check if current process is running elevated
    $isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }
    
    if ($net) {
        # Prompt for domain admin credentials (works for both local and domain)
        $domainInput = Read-Host "Enter domain [DDS]"
        $domain = if ([string]::IsNullOrWhiteSpace($domainInput)) { "DDS" } else { $domainInput }
        
        $usernameInput = Read-Host "Enter admin username [wurtzmt-a]"
        $username = if ([string]::IsNullOrWhiteSpace($usernameInput)) { "wurtzmt-a" } else { $usernameInput }
        
        $password = Read-Host "Enter password" -AsSecureString
        $fullUser = "$domain\$username"
        $cred = New-Object System.Management.Automation.PSCredential($fullUser, $password)
        
        if ($Command.Count -gt 0) {
            $commandText = $Command -join ' '
            if ($processCmd -eq "wt.exe") {
                Start-Process "wt.exe" -ArgumentList "$powershellCmd -NoExit -Command `"$commandText`"" -Credential $cred
            } else {
                Start-Process $powershellCmd -ArgumentList "-NoExit -Command `"$commandText`"" -Credential $cred
            }
        } else {
            if ($processCmd -eq "wt.exe") {
                Start-Process "wt.exe" -ArgumentList $powershellCmd -Credential $cred
            } else {
                Start-Process $powershellCmd -Credential $cred
            }
        }
    } elseif ($Command.Count -gt 0) {
        # Run command in elevated window (local admin only)
        $commandText = $Command -join ' '
        
        if ($processCmd -eq "wt.exe") {
            Start-Process $processCmd -ArgumentList "$powershellCmd -NoExit -Command `"$commandText`"" -Verb RunAs
        } else {
            Start-Process $processCmd -ArgumentList "-NoExit -Command `"$commandText`"" -Verb RunAs
        }
    } else {
        # Just open elevated window (local admin only)
        if (-not $isElevated) {
            if ($processCmd -eq "wt.exe") {
                Start-Process $processCmd -ArgumentList $powershellCmd -Verb RunAs
            } else {
                Start-Process $processCmd -Verb RunAs
            }
        } else {
            Write-Output "Already running as Administrator"
        }
    }
}

# Set UNIX-like aliases for the admin command
Set-Alias -Name su -Value admin
Set-Alias -Name sudo -Value admin

# Export module members
Export-ModuleMember -Function admin -Alias su, sudo
