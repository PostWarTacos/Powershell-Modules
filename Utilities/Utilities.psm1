<#
.SYNOPSIS
    General-purpose utility functions for logging, file dialogs, system maintenance, and performance testing.
#>

#region Network Utilities

function Get-PubIP {
    <#
    .SYNOPSIS
        Gets your public IP address.
    
    .DESCRIPTION
        Retrieves your public-facing IP address by querying the ifconfig.me service.
        This is the IP address visible to external websites and services on the internet.
    
    .EXAMPLE
        Get-PubIP
        Returns your public IP address (e.g., "203.0.113.42").
    
    .EXAMPLE
        $publicIP = Get-PubIP
        Write-Host "My public IP is: $publicIP"
        
    .NOTES
        Requires internet connectivity to reach ifconfig.me.
        
        Syntax (BNF):
        <get-pubip-command> ::= "Get-PubIP"
    #>
    (Invoke-WebRequest http://ifconfig.me/ip).Content
}

function winutil {
    <#
    .SYNOPSIS
        Opens Chris Titus Tech's Windows Utility tool.
    
    .DESCRIPTION
        Downloads and executes Chris Titus Tech's Windows Utility, a comprehensive tool for
        Windows system optimization, debloating, tweaks, and fixes. The utility provides a
        GUI interface for various Windows maintenance and configuration tasks.
    
    .EXAMPLE
        winutil
        Downloads and launches the Windows Utility tool.
    
    .NOTES
        Requires internet connectivity to download the script from christitus.com.
        May require administrative privileges for certain operations within the utility.
        
        Syntax (BNF):
        <winutil-command> ::= "winutil"
    #>
    irm https://christitus.com/win | iex
}

function Update-PowerShell {
    <#
    .SYNOPSIS
        Checks for and installs PowerShell updates via winget.
    
    .DESCRIPTION
        Checks the current PowerShell version against the latest release available on GitHub.
        If a newer version is available, automatically updates PowerShell using Windows Package Manager (winget).
        Displays status messages indicating whether an update is needed and the version numbers involved.
    
    .EXAMPLE
        Update-PowerShell
        Checks for updates and installs the latest version if available.
    
    .NOTES
        Requirements:
        - Windows Package Manager (winget) must be installed
        - Internet connectivity to reach GitHub API and download packages
        - May require administrative privileges
        
        After updating, you must restart your PowerShell session for changes to take effect.
        
        Syntax (BNF):
        <update-powershell-command> ::= "Update-PowerShell"
    #>
    try {
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
        $updateNeeded = $false
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
        $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
        
        if ($currentVersion -lt $latestVersion) {
            $updateNeeded = $true
        }

        if ($updateNeeded) {
            Write-Host "Updating PowerShell from $currentVersion to $latestVersion..." -ForegroundColor Yellow
            winget upgrade Microsoft.PowerShell --accept-source-agreements --accept-package-agreements
            Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        } else {
            Write-Host "Your PowerShell is up to date (v$currentVersion)." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}

#endregion

#region Write-LogMessage

Function Write-LogMessage {
    <#
    .SYNOPSIS
        Writes timestamped, color-coded log messages to console and optionally to file.

    .DESCRIPTION
        Outputs formatted log messages with timestamps, severity indicators, and color-coding.
        Supports multiple log levels with distinct visual formatting. Can write to console only
        or simultaneously to both console and a log file for persistent logging.

    .PARAMETER Message
        The log message text to display and/or write to file.
        
        Type: String
        Required: True
        Position: 0
        Default value: None
        Accept pipeline input: False
        Accept wildcard characters: False
        
        If an empty string or whitespace is provided, a blank line is output.

    .PARAMETER Level
        Specifies the severity/type of the log message, which determines the prefix and color.
        
        Type: String
        Required: False
        Position: 1
        Default value: "Default" (if not specified)
        Accept pipeline input: False
        Accept wildcard characters: False
        Validation: Must be one of: "Info", "Warning", "Error", "Success", "Default"
        
        Level meanings:
        - Info: Informational messages (White text, [*] prefix)
        - Warning: Warning messages (Yellow text, [!] prefix)
        - Error: Error messages (Red text, [!!!] prefix)
        - Success: Success messages (Green text, [+] prefix)
        - Default: Standard messages (DarkGray text, [*] prefix)

    .PARAMETER LogFile
        Optional file path for persistent logging. If provided, messages are appended to this file.
        
        Type: String
        Required: False
        Position: Named
        Default value: None (console only)
        Accept pipeline input: False
        Accept wildcard characters: False
        
        The log file is created if it doesn't exist. Parent directories must already exist.
        If the path is invalid or write fails, a warning is displayed but execution continues.
        
        Syntax (BNF):
        <log-command> ::= "Write-LogMessage" <message> [<level>] ["-LogFile" <file-path>]
        <message> ::= <string-literal>
        <level> ::= "-Level" ("Info" | "Warning" | "Error" | "Success" | "Default")
        <file-path> ::= <absolute-path> | <relative-path>

    .EXAMPLE
        Write-LogMessage "Starting process" -Level Info
        
        Outputs: [2025-12-29 14:30:15] [*] Starting process (in white)

    .EXAMPLE
        Write-LogMessage "Error occurred" -Level Error -LogFile "C:\logs\app.log"
        
        Displays error message in red and appends to app.log file.
        
    .EXAMPLE
        Write-LogMessage "Operation completed successfully" -Level Success
        
        Outputs: [2025-12-29 14:30:16] [+] Operation completed successfully (in green)
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

#region Get-FileName

Function Get-FileName() {
    <#
    .SYNOPSIS
        Opens a file dialog and returns the selected file path.

    .DESCRIPTION
        Displays a Windows Forms OpenFileDialog to allow the user to browse and select a file.
        Returns the full path of the selected file or an empty string if the dialog is cancelled.
        Useful for creating interactive scripts that need file input from users.

    .PARAMETER InitialDirectory
        Specifies the directory path that the file dialog will open to initially.
        
        Type: String
        Required: True
        Position: 0
        Default value: None
        Accept pipeline input: True (ByValue, ByPropertyName)
        Accept wildcard characters: False
        Validation: Must not be null or empty
        
        The directory must be accessible, though the function will handle invalid paths gracefully.
        If the path doesn't exist, the dialog may open to a default location (e.g., Documents).
        
        Syntax (BNF):
        <get-filename-command> ::= "Get-FileName" ["-InitialDirectory"] <directory-path>
        <directory-path> ::= <absolute-path>
        <absolute-path> ::= <drive-letter> ":" <path-separator> <path-components>

    .EXAMPLE
        Get-FileName -InitialDirectory "C:\Users\Documents"
        
        Opens a file dialog starting in the Documents folder and returns the selected file path.

    .EXAMPLE
        $file = Get-FileName -InitialDirectory $env:USERPROFILE
        if ($file) { Write-Host "Selected: $file" }
        
        Opens dialog in user's home directory and checks if a file was selected.
        
    .EXAMPLE
        $scriptPath = Get-FileName -InitialDirectory "C:\Scripts"
        if ($scriptPath) { & $scriptPath }
        
        Prompts user to select a script file and executes it if selected.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Enter the initial directory path for the file dialog"
        )]
        [ValidateNotNullOrEmpty()]
        [string]$InitialDirectory
    )
    
    begin {
        try {
            [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
        }
        catch {
            throw "Failed to load Windows Forms assembly. This function requires Windows Forms support."
        }
    }
    
    process {
        try {
            $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $OpenFileDialog.InitialDirectory = $InitialDirectory
            $OpenFileDialog.Filter = "All files (*.*)|*.*"
            $OpenFileDialog.Title = "Select a File"
            $OpenFileDialog.Multiselect = $false
            
            $dialogResult = $OpenFileDialog.ShowDialog()
            
            if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
                return $OpenFileDialog.FileName
            } else {
                return ""
            }
        }
        catch {
            Write-Error "An error occurred while displaying the file dialog: $($_.Exception.Message)"
            return ""
        }
        finally {
            if ($OpenFileDialog) {
                $OpenFileDialog.Dispose()
            }
        }
    }
}

#endregion

#region Start-KeepAwake

function Start-KeepAwake {
    <#
    .SYNOPSIS
        Prevents computer from going idle by simulating F15 key presses every 4 minutes.
    
    .DESCRIPTION
        Continuously simulates F15 key presses at 4-minute intervals to prevent the computer
        from entering sleep mode or activating screensavers. Useful during long-running operations,
        presentations, or when you need to prevent automatic screen locking.
        
        The F15 key is used because it typically has no effect in most applications but is
        recognized by Windows as user activity.
        
        Press Ctrl+C to stop the function and allow normal power management to resume.
    
    .EXAMPLE
        Start-KeepAwake
        
        Starts the keep-awake loop. The console will display a message and the script will
        run until you press Ctrl+C.
        
    .NOTES
        The function runs in an infinite loop until manually interrupted.
        Does not prevent manual sleep/lock actions.
        
        Syntax (BNF):
        <keep-awake-command> ::= "Start-KeepAwake"
    #>
    
    Write-Host "Start-KeepAwake script is running. Press Ctrl+C to stop."

    Add-Type -AssemblyName System.Windows.Forms

    while ($true) {
        [System.Windows.Forms.SendKeys]::SendWait("{F15}")
        Start-Sleep -Seconds 240
    }
}

#endregion

#region Measure-CommandClean

function Measure-CommandClean {
    <#
    .SYNOPSIS
        Measures script block execution time in an isolated temporary directory.

    .DESCRIPTION
        Executes a script block in a clean, temporary directory and measures its execution time.
        The temporary directory is automatically created before execution and cleaned up afterward,
        ensuring no artifacts are left behind. Useful for benchmarking code in a consistent environment.

    .PARAMETER ScriptToTest
        The script block to execute and measure.
        
        Type: ScriptBlock
        Required: True
        Position: 0
        Default value: None
        Accept pipeline input: True (ByValue)
        Accept wildcard characters: False
        
        The script block executes with the temporary directory as the current working directory.
        Any files or folders created by the script will be automatically cleaned up afterward.
        
        Syntax (BNF):
        <measure-clean-command> ::= "Measure-CommandClean" <script-block>
        <script-block> ::= "{" <powershell-statements> "}"
        <powershell-statements> ::= <statement> [";" <statement>]*

    .EXAMPLE
        Measure-CommandClean { Start-Sleep 2 }
        
        Measures the execution time of a 2-second sleep operation.
        Output: "Elapsed time: 2.XXX seconds"

    .EXAMPLE
        $result = Measure-CommandClean { Get-ChildItem -Recurse }
        $result.TotalMilliseconds
        
        Measures directory listing time and accesses the result in milliseconds.
        
    .EXAMPLE
        Measure-CommandClean {
            1..100 | ForEach-Object { New-Item "file$_.txt" }
        }
        
        Measures the time to create 100 files. All files are automatically cleaned up.
    #>

    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0,
            HelpMessage = "Enter a script block to measure"
        )]
        [scriptblock]$ScriptToTest
    )

    $tempRoot = Join-Path $env:TEMP "TestRun_$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    try {
        Push-Location $tempRoot

        $result = Measure-Command {
            & $ScriptToTest
        }

        Pop-Location

        Write-Host "Elapsed time: $($result.TotalSeconds) seconds"
        return $result
    }
    finally {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#endregion

#region ConvertTo-Base64

Function ConvertTo-Base64 {
    <#
    .SYNOPSIS
        Encodes a PowerShell script file to Base64 format.

    .DESCRIPTION
        Encodes a script file to Base64 using Unicode encoding and copies the result to the clipboard.
        The encoded string can be used with PowerShell's -EncodedCommand parameter to execute scripts
        without saving them to disk.
        
        If no file path is specified via the -File parameter, opens a file dialog for selection.
        This is useful for passing scripts through command-line interfaces or storing them
        in configuration files where special characters might cause issues.

    .PARAMETER File
        Specifies the path to the file to encode.
        
        Type: String
        Required: False
        Position: 0
        Default value: None (opens file dialog)
        Accept pipeline input: False
        Accept wildcard characters: False
        
        If not specified, a file dialog will be displayed for selection.

    .PARAMETER InitialDirectory
        Specifies the directory to open the file selection dialog in (only used when -File is not specified).
        
        Type: String
        Required: False
        Position: Named
        Default value: "C:\Users\$env:USERNAME\Documents\Coding"
        Accept pipeline input: False
        Accept wildcard characters: False
        
        If not specified, defaults to the user's Documents\Coding folder.
        
        Syntax (BNF):
        <convert-base64-command> ::= "ConvertTo-Base64" ["-File" <file-path>] ["-InitialDirectory" <directory-path>]
        <file-path> ::= <absolute-path> | <relative-path>
        <directory-path> ::= <absolute-path>

    .EXAMPLE
        ConvertTo-Base64 -File myscript.ps1
        
        Encodes the specified script file and copies to clipboard.

    .EXAMPLE
        ConvertTo-Base64
        
        Opens file dialog in default location, encodes selected script, and copies to clipboard.

    .EXAMPLE
        ConvertTo-Base64 -InitialDirectory "C:\Scripts"
        
        Opens file dialog in C:\Scripts folder for script selection.
        
    .EXAMPLE
        $encoded = ConvertTo-Base64 -File "C:\Scripts\deploy.ps1"
        powershell.exe -EncodedCommand $encoded
        
        Encodes a script and executes it using the encoded command parameter.

    .NOTES
        To decode: [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encodedScript))
        The encoded result is automatically copied to the clipboard for convenience.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [string]$File,
        
        [Parameter(Mandatory=$false)]
        [string]$InitialDirectory = "C:\Users\$env:USERNAME\Documents\Coding"
    )
    
    # If -File parameter is provided, use it; otherwise open file dialog
    if ($File) {
        if (-not (Test-Path -Path $File)) {
            Write-Error "File not found: $File"
            return
        }
        $scriptPath = $File
    }
    else {
        $scriptPath = Get-FileName -InitialDirectory $InitialDirectory
        
        if ([string]::IsNullOrWhiteSpace($scriptPath)) {
            Write-Warning "No file selected. Operation cancelled."
            return
        }
    }
    
    try {
        $bytes = [System.Text.Encoding]::Unicode.GetBytes((Get-Content $scriptPath -Raw))
        $encodedCommand = [Convert]::ToBase64String($bytes)

        $encodedCommand | Set-Clipboard
        Write-Host "File Base64 encoded and copied to clipboard" -ForegroundColor Yellow
    }
    catch {
        Write-Error "Failed to encode file: $($_.Exception.Message)"
    }
}

#endregion

#region Get-SMSCode

function Get-SMSCode {
    <#
    .SYNOPSIS
        Gets the SMS site code of the current domain.

    .DESCRIPTION
        Retrieves the SMS (Systems Management Server) / SCCM (System Center Configuration Manager)
        site code from Active Directory when the Configuration Manager client is not installed.
        Queries the System Management container in AD for mSSMSSite objects and returns the site code.
        
        This is useful for scripting Configuration Manager operations or determining the correct
        site code for client installations without having the CCM client already installed.

    .EXAMPLE
        Get-SMSCode
        
        Returns the SMS site code for the current domain (e.g., "PS1").

    .EXAMPLE
        $siteCode = Get-SMSCode
        Write-Host "Site code: $siteCode"
        
        Retrieves and displays the site code.
        
    .EXAMPLE
        if ($siteCode = Get-SMSCode) {
            Write-Host "Installing CCM client for site: $siteCode"
        }
        
        Uses the site code to determine installation parameters.

    .NOTES
        Intent: Get the SMS site code of the current domain when the current company doesn't have CCM installed.
        Date: 6-Apr-25
        Author: Matthew Wurtz
        
        Requirements:
        - Must be run on a domain-joined computer
        - Requires access to query Active Directory
        - System Management container must exist in AD (created during SCCM setup)
        
        Syntax (BNF):
        <get-smscode-command> ::= "Get-SMSCode"
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Get domain DN
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        $domainDN = "LDAP://CN=System Management,CN=System,DC=" + ($domain.Name -replace '\.', ',DC=')

        # Set up searcher
        $searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]$domainDN)
        $searcher.Filter = "(objectClass=mSSMSSite)"
        $searcher.SearchScope = "OneLevel"
        $searcher.PropertiesToLoad.Add("mSSMSSiteCode") | Out-Null

        # Search and return
        $results = $searcher.FindAll()
        foreach ($result in $results) {
            $code = $result.Properties["mSSMSSiteCode"]
        } 

        return $code
    }
    catch {
        Write-Error "Failed to retrieve SMS site code: $($_.Exception.Message)"
    }
    finally {
        if ($searcher) {
            $searcher.Dispose()
        }
    }
}

#endregion

#region Module Exports

# Export all public functions
Export-ModuleMember -Function Write-LogMessage, Get-FileName, Start-KeepAwake, Measure-CommandClean, ConvertTo-Base64, Get-SMSCode

#endregion
