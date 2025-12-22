<#
.SYNOPSIS
    Executes a script on a remote computer with transcript logging to C:\temp\logs.

.PARAMETER ComputerName
    Remote computer name or IP address (requires PSRemoting enabled)

.PARAMETER FilePath
    Path to the script file to execute

.EXAMPLE
    Invoke-Script -ComputerName "SERVER01" -FilePath "C:\Scripts\HealthCheck.ps1"
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