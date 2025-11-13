<#
.SYNOPSIS
    ADSITools PowerShell Module

.DESCRIPTION
    This module provides utilities for working with Active Directory Service Interfaces (ADSI).
    It contains functions to search for and interact with Active Directory objects using ADSI
    without requiring the ActiveDirectory PowerShell module.

.AUTHOR
    Your Name

.VERSION
    1.0.0

.NOTES
    This module requires network connectivity to a domain controller and appropriate
    permissions to query Active Directory.
#>

function Find-ADSIObject {
    <#
    .SYNOPSIS
        Finds Active Directory objects using ADSI.

    .DESCRIPTION
        The Find-ADSIObject function searches Active Directory for objects of specified types
        (Computer, User, Group, or OU) using their name. It uses ADSI (Active Directory Service Interfaces)
        to perform the search without requiring the ActiveDirectory PowerShell module.

    .PARAMETER Type
        Specifies the type of Active Directory object to search for.
        Valid values are: Computer, User, Group, OU

    .PARAMETER Name
        The name of the Active Directory object to search for. For computers, do not include the trailing dollar sign ($).

    .INPUTS
        String
        You can pipe strings containing object names to this function.

    .OUTPUTS
        System.DirectoryServices.DirectoryEntry
        Returns an ADSI DirectoryEntry object if found, or $null if not found.

    .EXAMPLE
        Find-ADSIObject -Type User -Name "jdoe"
        
        Searches for a user account with the sAMAccountName "jdoe".

    .EXAMPLE
        Find-ADSIObject -Type Computer -Name "WORKSTATION01"
        
        Searches for a computer account named "WORKSTATION01".

    .EXAMPLE
        Find-ADSIObject -Type Group -Name "Domain Admins"
        
        Searches for a group named "Domain Admins".

    .EXAMPLE
        Find-ADSIObject -Type OU -Name "Computers"
        
        Searches for an Organizational Unit named "Computers".

    .EXAMPLE
        "jdoe", "jsmith" | ForEach-Object { Find-ADSIObject -Type User -Name $_ }
        
        Searches for multiple user accounts by piping names to the function.

    .NOTES
        - This function requires network connectivity to a domain controller
        - The account running this function must have read permissions to Active Directory
        - Computer names should not include the trailing dollar sign ($) as it's added automatically
        - If the object is not found, a warning message is displayed and $null is returned

    .LINK
        https://docs.microsoft.com/en-us/windows/win32/adsi/active-directory-service-interfaces-adsi

    .FUNCTIONALITY
        Active Directory, ADSI, Search
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, HelpMessage = "Specify the type of AD object to search for")]
        [ValidateSet("Computer", "User", "Group", "OU")]
        [string]$Type,

        [Parameter(Mandatory, HelpMessage = "Enter the name of the AD object to find")]
        [string]$Name
    )

    # Map LDAP filters for each type
    switch ( $Type ) {
        "Computer" {
            $filter = "(&(objectClass=computer)(sAMAccountName=$Name`$))"
        }
        "User" {
            $filter = "(&(objectClass=user)(sAMAccountName=$Name))"
        }
        "Group" {
            $filter = "(&(objectClass=group)(sAMAccountName=$Name))"
        }
        "OU" {
            $filter = "(&(objectClass=organizationalUnit)(ou=$Name))"
        }
    }

    $searcher = [ADSISearcher]::new($filter)
    $result = $searcher.FindOne()

    if ( $result -and $result.Properties["adspath"] ) {
        return [ADSI]$result.Properties["adspath"][0]
    } else {
        Write-Warning "$Type '$Name' not found in AD."
        return $null
    }
}

Export-ModuleMember Find-ADSIObject