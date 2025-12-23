<#
.SYNOPSIS
    General-purpose utility functions for logging, file dialogs, system maintenance, and performance testing.
#>

#region Write-LogMessage

Function Write-LogMessage {
    <#
    .SYNOPSIS
        Writes timestamped, color-coded log messages to console and optionally to file.

    .PARAMETER Message
        Log message text

    .PARAMETER Level
        Log level: Info, Warning, Error, Success, or Default

    .PARAMETER LogFile
        Optional log file path for persistent logging

    .EXAMPLE
        Write-LogMessage "Starting process" -Level Info

    .EXAMPLE
        Write-LogMessage "Error occurred" -Level Error -LogFile "C:\logs\app.log"
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

    .PARAMETER InitialDirectory
        The directory to open the file dialog in.

    .EXAMPLE
        Get-FileName -InitialDirectory "C:\Users\Documents"

    .EXAMPLE
        $file = Get-FileName -InitialDirectory $env:USERPROFILE
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
    
    .EXAMPLE
        Start-KeepAwake
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

    .PARAMETER ScriptToTest
        Script block to measure. Executes in a temporary directory that is automatically cleaned up.

    .EXAMPLE
        Measure-CommandClean { Start-Sleep 2 }

    .EXAMPLE
        $result = Measure-CommandClean { Get-ChildItem -Recurse }
        $result.TotalMilliseconds
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

#region Module Exports

# Export all public functions
Export-ModuleMember -Function Write-LogMessage, Get-FileName, Start-KeepAwake, Measure-CommandClean

#endregion
