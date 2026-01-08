#
# Module manifest for module 'ComputerInventory'
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ComputerInventory.psm1'
    
    # Version number of this module.
    ModuleVersion = '3.1.0'
    
    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')
    
    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'
    
    # Author of this module
    Author = 'PostWarTacos'
    
    # Company or vendor of this module
    CompanyName = 'Unknown'
    
    # Copyright statement for this module
    Copyright = '(c) 2026 PostWarTacos. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Comprehensive computer inventory and health check module for remote Windows systems. Provides functions to query hardware, software, security status, network configuration, and system health.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Write-LogMessage',
        'Get-SharesInfo',
        'Get-NetworkDetails',
        'Get-ADLastLogon',
        'Get-DomainController',
        'Get-CurrentUser',
        'Get-LastLoggedOnUser',
        'Get-PrimaryUser',
        'Get-LocalAdmins',
        'Get-DriveSpace',
        'Get-ChassisType',
        'Get-MonitorCount',
        'Get-BatteryHealth',
        'Get-TPMStatus',
        'Get-BitLockerStatus',
        'Get-WindowsDefenderInfo',
        'Get-LastWindowsUpdate',
        'Get-PendingUpdatesCount',
        'Get-PendingReboot',
        'Get-GPLastUpdate',
        'Get-PrefetchSize',
        'Get-SCCMHealth',
        'Get-AllNetworkInfo',
        'Get-AllADInfo',
        'Get-AllUserInfo',
        'Get-AllHardwareInfo',
        'Get-AllSecurityInfo',
        'Get-AllUpdateInfo',
        'Get-AllSystemHealthInfo',
        'Get-CompleteInventory'
    )
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Inventory', 'ComputerManagement', 'SystemAdministration', 'RemoteManagement', 'WindowsManagement', 'Security', 'Hardware', 'Monitoring')
            
            # A URL to the license for this module.
            # LicenseUri = ''
            
            # A URL to the main website for this project.
            # ProjectUri = ''
            
            # A URL to an icon representing this module.
            # IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = @'
Version 3.1.0 (January 8, 2026)
- Added 8 wrapper functions for grouped data collection:
  * Get-AllNetworkInfo - Collects all network-related data
  * Get-AllADInfo - Collects Active Directory information
  * Get-AllUserInfo - Collects user and administrator information
  * Get-AllHardwareInfo - Collects hardware specifications
  * Get-AllSecurityInfo - Collects security status (TPM, BitLocker, Defender)
  * Get-AllUpdateInfo - Collects Windows Update and Group Policy info
  * Get-AllSystemHealthInfo - Collects system health metrics
  * Get-CompleteInventory - Runs all checks and returns comprehensive report
- Organized functions into logical regions in module
- Improved performance by allowing category-specific queries

Version 3.0.0 (January 8, 2026)
- Converted script to PowerShell module format
- Added 22 individual functions for targeted queries
- Functions organized by category: Network, Active Directory, User, Hardware, Security, Updates, System Health
- All functions can be called independently for specific data collection
- Modular design allows for efficient, selective information gathering
- Added comprehensive help documentation for all functions

Previous Features (Version 2.2):
- Battery health monitoring for laptops
- Monitor count detection
- Pending Windows updates count
- Group Policy last applied timestamp
- DNS server and default gateway information
- Domain controller detection
- Windows Defender comprehensive status
- Prefetch folder size analysis
'@
        }
    }
    
    # HelpInfo URI of this module
    # HelpInfoURI = ''
    
    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
