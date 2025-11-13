<#
.SYNOPSIS
    Searches for installed applications by name and returns their GUID and uninstall information.

.DESCRIPTION
    The Find-GUID function searches the Windows registry for installed applications that match 
    the specified application name. It looks in both the standard and WOW6432Node registry 
    locations to find applications installed on both 32-bit and 64-bit systems. The function 
    returns detailed information including the application's GUID (PSChildName), display name, 
    publisher, version, uninstall string, and registry path.

.PARAMETER AppName
    Specifies the name of the application to search for. This parameter supports partial 
    matching and regular expressions. The search is performed against both the DisplayName 
    and Publisher fields in the registry.

.INPUTS
    System.String
    You can pipe a string containing the application name to Find-GUID.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns objects containing DisplayName, Publisher, DisplayVersion, PSChildName (GUID), 
    UninstallString, and Path properties for each matching application.

.EXAMPLE
    Find-GUID -AppName "Chrome"
    
    Searches for all installed applications with "Chrome" in the display name or publisher.

.EXAMPLE
    Find-GUID -AppName "Microsoft"
    
    Finds all applications published by Microsoft or with "Microsoft" in the application name.

.EXAMPLE
    "Adobe" | Find-GUID
    
    Uses pipeline input to search for Adobe applications.

.NOTES
    Author: [Your Name]
    Version: 1.0
    Requires: PowerShell 3.0 or higher
    
    This function requires read access to the Windows registry uninstall keys.

.LINK
    Find-GUIDinMSI
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
    Extracts GUID information from an MSI (Microsoft Installer) package file.

.DESCRIPTION
    The Find-GUIDinMSI function opens an MSI package file and extracts important GUID 
    information including the ProductCode, UpgradeCode, and ProductVersion. This is useful 
    for software deployment, inventory management, and troubleshooting installation issues. 
    The function uses the Windows Installer COM object to read the MSI database directly.

.PARAMETER MSIPath
    Specifies the full path to the MSI file from which to extract GUID information. 
    The file must be a valid MSI package and accessible to the current user.

.INPUTS
    System.String
    You can pipe a string containing the MSI file path to Find-GUIDinMSI.

.OUTPUTS
    None (Console Output)
    The function displays ProductCode, UpgradeCode, and ProductVersion information 
    directly to the console using Write-Host.

.EXAMPLE
    Find-GUIDinMSI -MSIPath "C:\Temp\application.msi"
    
    Extracts and displays GUID information from the specified MSI file.

.EXAMPLE
    Get-ChildItem "C:\Software\*.msi" | ForEach-Object { Find-GUIDinMSI $_.FullName }
    
    Processes multiple MSI files and displays GUID information for each.

.EXAMPLE
    "C:\Downloads\setup.msi" | Find-GUIDinMSI
    
    Uses pipeline input to process an MSI file.

.NOTES
    Author: [Your Name]
    Version: 1.0
    Requires: PowerShell 3.0 or higher, Windows Installer service
    
    This function requires the Windows Installer COM object (WindowsInstaller.Installer) 
    to be available on the system. The MSI file must be accessible and not corrupted.
    
    The function extracts the following properties:
    - ProductCode: Unique identifier for the product
    - UpgradeCode: Identifier used for product upgrades
    - ProductVersion: Version number of the product

.LINK
    Find-GUID
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