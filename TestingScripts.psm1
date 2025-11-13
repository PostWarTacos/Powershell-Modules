<#
.SYNOPSIS
Writes structured log messages to console and optionally to a file with color-coded output.

.DESCRIPTION
The Write-LogMessage function provides a standardized way to write log messages with different severity levels.
Messages are displayed in the console with color coding based on the log level and can optionally be written
to a log file. Each message includes a timestamp and a level-specific prefix for easy identification.

Log Level Prefixes:
- Info: [*] (displayed in Cyan)
- Warning: [!] (displayed in Yellow) 
- Error: [!!!] (displayed in Red)
- Success: [+] (displayed in Green)

.PARAMETER Level
Specifies the severity level of the log message. Valid values are:
- Info: For informational messages
- Warning: For warning messages that indicate potential issues
- Error: For error messages that indicate failures
- Success: For success messages that indicate successful operations

.PARAMETER Message
The log message text to be written. This parameter is mandatory.

.PARAMETER LogFile
The path to the log file where messages should be written. If not specified, defaults to $Config.LogFilePath.
If no log file is specified or available, messages will only be written to the console.

.EXAMPLE
Write-LogMessage -Level "Info" -Message "Starting application initialization"

Writes an informational message to the console in cyan color with format:
[2025-11-13 14:30:15] [*] Starting application initialization

.EXAMPLE
Write-LogMessage -Level "Warning" -Message "Configuration file not found, using defaults" -LogFile "C:\Logs\app.log"

Writes a warning message to both console (in yellow) and to the specified log file.

.EXAMPLE
Write-LogMessage -Level "Error" -Message "Database connection failed"

Writes an error message to the console in red color with format:
[2025-11-13 14:30:15] [!!!] Database connection failed

.EXAMPLE
Write-LogMessage -Level "Success" -Message "User authentication completed successfully"

Writes a success message to the console in green color with format:
[2025-11-13 14:30:15] [+] User authentication completed successfully

.OUTPUTS
None. This function does not return any objects to the pipeline. It writes to the console and optionally to a log file.

.NOTES
Author: postwartacos
Version: 2.0
Requires: PowerShell 5.0 or later

The function automatically creates timestamps in "yyyy-MM-dd HH:mm:ss" format.
If writing to a log file fails, a warning message will be displayed but execution will continue.
The log file will be created if it doesn't exist, and messages will be appended if it does exist.

.LINK
https://github.com/postwartacos/powershell-modules

.LINK
Write-Host

.LINK
Out-File
#>
Function Write-LogMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$LogFile = $Config.LogFilePath 
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Add level-specific prefixes
    $prefix = switch ($Level) {
        "Info"    { "[*]" }
        "Warning" { "[!]" }
        "Error"   { "[!!!]" }
        "Success" { "[+]" }
    }
    
    # Build the log entry
    if (-not $prefix) {
        $logEntry = "[$timestamp] $Message"
    }
    else {
        $logEntry = "[$timestamp] $prefix $Message"
    }

    # Console output with colors
    switch ($Level) {
        "Info"    { Write-Host $logEntry -ForegroundColor Cyan }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Error"   { Write-Host $logEntry -ForegroundColor Red }
        "Success" { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # File output
    if ($LogFile) {
        try {
            $logEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8 -ErrorAction Stop
        } catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

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

Export-ModuleMember Write-LogMessage, Invoke-Script