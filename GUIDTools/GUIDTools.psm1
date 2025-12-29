<#
.SYNOPSIS
    Searches registry for installed applications and returns GUID and uninstall information.

.DESCRIPTION
    Searches the Windows Registry uninstall keys (both 64-bit and 32-bit locations) for installed applications
    matching the specified name or publisher. Returns detailed information including display name, publisher,
    version, GUID (PSChildName), uninstall string, and registry path.

.PARAMETER AppName
    Specifies the application name or publisher to search for. Supports partial matching and regular expressions.
    
    Type: String
    Required: True
    Position: 0
    Default value: None
    Accept pipeline input: True (ByValue)
    Accept wildcard characters: True (via regex)
    
    The search matches against both the DisplayName and Publisher registry properties.
    Uses PowerShell's -match operator, so regex patterns are supported.
    
    Syntax (BNF):
    <find-guid-command> ::= "Find-GUID" ["-AppName"] <app-pattern>
    <app-pattern> ::= <string-literal> | <regex-pattern>
    <regex-pattern> ::= <pcre-compliant-expression>

.EXAMPLE
    Find-GUID -AppName "Chrome"
    
    Searches for applications containing "Chrome" in the display name or publisher.

.EXAMPLE
    "Adobe" | Find-GUID
    
    Uses pipeline input to search for applications containing "Adobe".
    
.EXAMPLE
    Find-GUID "Visual Studio.*2022"
    
    Uses regex pattern to find Visual Studio 2022 applications.
#>
function Find-GUID{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$AppName
    )

    $appDirs = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ( $dir in $appDirs ){
        Get-ItemProperty $dir |
            Where-Object { $_.DisplayName -match $AppName -or $_.Publisher -match $AppName } |
            Select-Object DisplayName, Publisher, DisplayVersion, PSChildName, UninstallString, @{ Name='Path'; Expression={ $_.PSPath -replace '^Microsoft\.PowerShell\.Core\\Registry::', '' }} |
            Format-List
    }
}


<#
.SYNOPSIS
    Extracts ProductCode, UpgradeCode, and ProductVersion from an MSI file.

.DESCRIPTION
    Opens a Windows Installer MSI database file and extracts key properties including:
    - ProductCode: The unique GUID that identifies this product installation
    - UpgradeCode: The GUID used to identify related product versions for upgrade logic
    - ProductVersion: The version number of the product
    
    Uses the WindowsInstaller.Installer COM object to read the MSI Property table without installation.

.PARAMETER MSIPath
    Specifies the full file system path to the MSI (Microsoft Installer) package file.
    
    Type: String
    Required: True
    Position: 0
    Default value: None
    Accept pipeline input: True (ByValue)
    Accept wildcard characters: False
    
    Must be a valid path to an existing .msi file. The path can be absolute or relative.
    The file must be a valid Windows Installer package that can be opened in read-only mode.
    
    Syntax (BNF):
    <find-guid-msi-command> ::= "Find-GUIDinMSI" ["-MSIPath"] <msi-file-path>
    <msi-file-path> ::= <absolute-path> | <relative-path>
    <absolute-path> ::= <drive-letter> ":" <path-separator> <path-components> <msi-filename>
    <relative-path> ::= ["."] <path-separator> <path-components> <msi-filename>
    <msi-filename> ::= <filename-without-extension> ".msi"

.EXAMPLE
    Find-GUIDinMSI -MSIPath "C:\Temp\application.msi"
    
    Extracts and displays ProductCode, UpgradeCode, and ProductVersion from the specified MSI file.

.EXAMPLE
    Get-ChildItem "*.msi" | ForEach-Object { Find-GUIDinMSI $_.FullName }
    
    Processes all MSI files in the current directory and displays their GUIDs and version information.
    
.EXAMPLE
    Find-GUIDinMSI "C:\Downloads\installer.msi" | Out-File "msi-info.txt"
    
    Exports the MSI property information to a text file.
#>
function Find-GUIDinMSI {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$MSIPath
    )

    $installer = New-Object -ComObject WindowsInstaller.Installer
    $msi = $installer.OpenDatabase("$MSIPath", 0)
    $view = $msi.OpenView("SELECT * FROM Property")
    $view.Execute()
    while ($record = $view.Fetch()) {
        $name = $record.StringData(1)
        $value = $record.StringData(2)
        if ($name -in "ProductCode", "UpgradeCode", "ProductVersion") {
            Write-Host "$name = $value"
        }
    }
}

Export-ModuleMember Find-GUID, Find-GUIDinMSI