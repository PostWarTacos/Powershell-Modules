function Measure-CommandClean {
    <#
    .SYNOPSIS
        Measures the execution time of a script block in a clean, isolated temporary environment.

    .DESCRIPTION
        The Measure-CommandClean function executes a script block within a temporary directory, 
        measures its execution time, and automatically cleans up the temporary workspace afterwards. 
        This is useful for testing scripts that may create files or modify the current directory 
        without affecting your working environment.

        The function creates a unique temporary directory, changes to that location, executes 
        the provided script block, measures the execution time, restores the original location, 
        and removes the temporary directory.

    .PARAMETER ScriptToTest
        A script block containing the code to be measured. This parameter is mandatory.
        The script block will be executed in an isolated temporary directory.

    .INPUTS
        System.Management.Automation.ScriptBlock
            You can pipe a script block to Measure-CommandClean.

    .OUTPUTS
        System.TimeSpan
            Returns a TimeSpan object containing the measured execution time.

    .EXAMPLE
        PS> Measure-CommandClean { Start-Sleep 2; Write-Host "Test completed" }
        
        Test completed
        Elapsed time: 2.0156432 seconds

        This example measures how long it takes to sleep for 2 seconds and write a message.

    .EXAMPLE
        PS> $result = Measure-CommandClean { 
            New-Item -ItemType File -Name "test.txt" -Force
            "Hello World" | Out-File "test.txt"
            Get-Content "test.txt"
        }
        PS> $result.TotalMilliseconds
        
        Hello World
        Elapsed time: 0.0234567 seconds
        23.4567

        This example creates a file, writes to it, reads from it, and captures the timing result.

    .EXAMPLE
        PS> Measure-CommandClean { 1..1000 | ForEach-Object { $_ * $_ } }
        
        Elapsed time: 0.1234567 seconds

        This example measures the time to calculate squares of numbers 1 through 1000.

    .NOTES
        File Name      : Measure-CommandClean.psm1
        Author         : 
        Prerequisite   : PowerShell 3.0 or later
        Copyright      : 
        
        The temporary directory is created in the system's temp folder using a GUID for uniqueness.
        The function ensures cleanup even if the script block throws an error.

    .LINK
        Measure-Command

    .LINK
        about_Script_Blocks
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

    # Set up a temporary working directory (auto-cleaned later)
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

Export-ModuleMember Measure-CommandClean