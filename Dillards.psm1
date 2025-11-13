<#
.SYNOPSIS
    Retrieves store information from the Dillards DDS API based on hostname, store number, or site code.

.DESCRIPTION
    The Get-SiteInfoFromDDSAPI function queries the Dillards Device Data Service (DDS) API to retrieve store information.
    It supports three different ways to lookup store data:
    - By hostname (extracts site code from hostname)
    - By store number (partial matching supported)
    - By site code (exact matching)
    
    The function returns store details including store number, site code, division, store type, and timezone.

.PARAMETER Hostname
    The hostname of the device/system to lookup. The function extracts the site code from positions 2-5 of the hostname.
    This parameter is part of the 'ByHostname' parameter set.

.PARAMETER StoreNumber
    The store number to search for. Supports partial matching using wildcard patterns.
    This parameter is part of the 'ByStore' parameter set.

.PARAMETER SiteCode
    The exact site code to search for. This is typically a 4-character identifier.
    This parameter is part of the 'BySite' parameter set.

.EXAMPLE
    Get-SiteInfoFromDDSAPI -Hostname "S1234WKS001"
    
    Retrieves store information for site code 1234 (extracted from hostname).

.EXAMPLE
    Get-SiteInfoFromDDSAPI -StoreNumber "0123"
    
    Retrieves store information for stores matching store number 0123.

.EXAMPLE
    Get-SiteInfoFromDDSAPI -SiteCode "1234"
    
    Retrieves store information for the exact site code 1234.

.INPUTS
    System.String
    You can pipe hostnames, store numbers, or site codes to this function.

.OUTPUTS
    PSCustomObject
    Returns objects with the following properties:
    - StoreNumber: The store's number identifier
    - SiteCode: The 4-character site code
    - Division: The division the store belongs to
    - StoreType: The type of store (e.g., regular, outlet, etc.)
    - Timezone: The timezone the store operates in

.NOTES
    Author: Your Name
    Version: 1.0
    Last Modified: November 13, 2025
    
    Requirements:
    - Network access to https://ssdcorpappsrvt1.dpos.loc
    - Proper authentication/network permissions to access the DDS API

.LINK
    https://ssdcorpappsrvt1.dpos.loc/esper/Device/AllStores

.COMPONENT
    Dillards PowerShell Module

.ROLE
    Information Retrieval

.FUNCTIONALITY
    Store Data Lookup
#>
Function Get-SiteInfoFromDDSAPI() {
    [CmdletBinding(DefaultParameterSetName = 'ByHostname')]
    param (
        # The hostname to extract site code from (positions 2-5)
        [Parameter(ParameterSetName = 'ByHostname', Mandatory = $true, 
                   ValueFromPipeline = $true,
                   HelpMessage = "Enter the hostname (e.g., S1234WKS001)")]
        [string]$Hostname,
        
        # The store number to search for (supports partial matching)
        [Parameter(ParameterSetName = 'ByStore', Mandatory = $true,
                   ValueFromPipeline = $true,
                   HelpMessage = "Enter the store number (e.g., 0123)")]
        [string]$StoreNumber,

        # The exact site code to search for
        [Parameter(ParameterSetName = 'BySite', Mandatory = $true,
                   ValueFromPipeline = $true,
                   HelpMessage = "Enter the 4-character site code (e.g., 1234)")]
        [string]$SiteCode
    )

    # Define the DDS API endpoint and headers
    $uri = "https://ssdcorpappsrvt1.dpos.loc/esper/Device/AllStores"
    $header = @{"accept" = "text/plain"}
    
    try {
        # Query the DDS API and convert JSON response to PowerShell objects
        $web = Invoke-WebRequest -Uri $uri -Headers $header -ErrorAction Stop
        $db = $web.content | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to connect to DDS API: $($_.Exception.Message)"
        return
    }

    # Process the request based on the parameter set used
    switch ($PSCmdlet.ParameterSetName) {
        'ByHostname' {
            # Extract site code from hostname (characters 2-5, positions 1-4 in substring)
            $localCode = $($Hostname).substring(1,4)
            $result = $db | Where-Object SiteCode -eq $localCode
        }
        'ByStore' {
            # Search for stores with matching store number (supports partial matching)
            $result = $db | Where-Object StoreNumber -like "*$StoreNumber"
        }
        'BySite' {
            # Search for exact site code match
            $result = $db | Where-Object SiteCode -eq $SiteCode
        }
    }

    # Return filtered results with selected properties
    $result | Select-Object StoreNumber, SiteCode, Division, StoreType, Timezone
}

Export-ModuleMember Get-SiteInfoFromDDSAPI