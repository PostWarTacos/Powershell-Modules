<#
.SYNOPSIS
    Executes a script on a remote computer with transcript logging to C:\temp\logs.

.DESCRIPTION
    Establishes a PowerShell remoting session to a remote computer, executes a specified script file,
    and logs all output to a transcript file. The transcript is saved locally with a timestamp in the filename.
    Requires PSRemoting to be enabled on the target computer.

.PARAMETER ComputerName
    Specifies the name or IP address of the remote computer where the script will be executed.
    
    Type: String
    Required: True
    Position: Named
    Default value: None
    Accept pipeline input: False
    Accept wildcard characters: False
    
    Requirements:
    - PSRemoting must be enabled on the target computer
    - Current user must have administrative privileges on the remote computer
    - Network connectivity to the remote computer must be available
    - Windows Remote Management (WinRM) service must be running

.PARAMETER FilePath
    Specifies the local path to the PowerShell script file (.ps1) to execute on the remote computer.
    
    Type: String
    Required: True
    Position: Named
    Default value: None
    Accept pipeline input: False
    Accept wildcard characters: False
    
    The script file must exist on the local machine and will be sent to the remote session for execution.
    The file path can be absolute or relative.
    
    Syntax (BNF):
    <invoke-script-command> ::= "Invoke-Script" "-ComputerName" <computer-identifier> "-FilePath" <script-path>
    <computer-identifier> ::= <hostname> | <fqdn> | <ip-address>
    <hostname> ::= <dns-name>
    <fqdn> ::= <hostname> "." <domain-name>
    <ip-address> ::= <ipv4-address> | <ipv6-address>
    <script-path> ::= <absolute-path> | <relative-path>

.EXAMPLE
    Invoke-Script -ComputerName "SERVER01" -FilePath "C:\Scripts\HealthCheck.ps1"
    
    Connects to SERVER01 and executes the HealthCheck.ps1 script, logging all output
    to C:\temp\logs\HealthCheck_<timestamp>.txt.

.EXAMPLE
    Invoke-Script -ComputerName "192.168.1.100" -FilePath ".\Maintenance.ps1"
    
    Connects to the remote computer at IP 192.168.1.100 and executes Maintenance.ps1
    from the current directory.

.NOTES
    The transcript log directory (C:\temp\logs) will be created automatically if it doesn't exist.
    The transcript filename format is: <ScriptName>_<UnixTimestamp>.txt
    
    Common troubleshooting:
    - Ensure Enable-PSRemoting has been run on the remote computer
    - Verify firewall rules allow WinRM traffic
    - Confirm the current user has appropriate permissions
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
    Invoke-Command -Session $session -FilePath $FilePath
    Remove-PSSession $session

    Stop-Transcript

}

Export-ModuleMember Invoke-Script