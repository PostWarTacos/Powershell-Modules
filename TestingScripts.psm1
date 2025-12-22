<#
.SYNOPSIS
Executes a PowerShell script on a remote computer with transcript logging.

.DESCRIPTION
The Invoke-Script function executes a PowerShell script file on a remote computer using PowerShell remoting.
It automatically creates a transcript log of the execution with a timestamped filename and manages the 
remote session lifecycle. The transcript is saved locally in C:\temp\logs.

.PARAMETER ComputerName
The name or IP address of the remote computer where the script will be executed. This parameter is mandatory.
The target computer must have PowerShell remoting enabled and the current user must have appropriate permissions.

.PARAMETER FilePath
The full path to the PowerShell script file that will be executed on the remote computer. This parameter is mandatory.
The script file must be accessible from the local machine.

.EXAMPLE
Invoke-Script -ComputerName "SERVER01" -FilePath "C:\Scripts\HealthCheck.ps1"
Executes the HealthCheck.ps1 script on SERVER01 and logs the output with a timestamp.

.EXAMPLE
Invoke-Script -ComputerName "192.168.1.100" -FilePath "C:\Admin\Maintenance.ps1"
Executes the Maintenance.ps1 script on the remote computer at IP address 192.168.1.100.

.OUTPUTS
None. The function creates a transcript log file but does not return objects to the pipeline.
The transcript file is saved as: C:\temp\logs\[ScriptName]_[UnixTimestamp].txt

.NOTES
Author: [Your Name]
Version: 1.0
Requires: PowerShell 5.0 or later, PowerShell Remoting enabled on target computer

Prerequisites:
- PowerShell remoting must be enabled on the target computer
- Current user must have permission to create remote sessions
- Network connectivity to the target computer
- The C:\temp\logs directory will be created if it doesn't exist

.LINK
https://github.com/postwartacos/powershell-modules

.LINK
about_Remote

.LINK
Enter-PSSession
#>
function Invoke-Script(){
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$ComputerName,
        
        [Parameter(Mandatory)]
        [String]$FilePath
    )

    $transcriptLogPath = "C:\temp\logs"
    $udate = [int](get-date -UFormat %s)
    $fileName = [System.io.path]::GetFileNameWithoutExtension($FilePath)
    $fullPath = "$transcriptLogPath\$($fileName)_$($udate).txt"

    if ( -not ( Test-Path $transcriptLogPath )) {
        mkdir $transcriptLogPath | Out-Null
    }

    Start-Transcript -Path $fullPath

    $session = New-PSSession -ComputerName $ComputerName

    # Execute it remotely
    Invoke-Command -Session $session -FilePath $FilePath

    # Clean up session
    Remove-PSSession $session

    Stop-Transcript

}

Export-ModuleMember Invoke-Script