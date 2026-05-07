<#
.SYNOPSIS
    Active Directory utilities using ADSI without requiring the ActiveDirectory module.
#>

function Find-ADSIObject {
    <#
    .SYNOPSIS
        Finds Active Directory objects (Computer, User, Group, OU) using ADSI.

    .DESCRIPTION
        Searches Active Directory for objects using ADSI (Active Directory Service Interfaces) without requiring 
        the ActiveDirectory PowerShell module. Supports searching for Computers, Users, Groups, and Organizational Units.
        Uses LDAP filters for efficient querying of the AD directory.

        Returns all matches found for the requested name and type.
        - No matches: returns $null and writes a warning
        - One match: returns a single ADSI object
        - Multiple matches: returns a collection of ADSI objects

    .PARAMETER Type
        Specifies the type of Active Directory object to search for.
        
        Type: String
        Required: True
        Position: Named
        Default value: None
        Accept pipeline input: False
        Accept wildcard characters: False
        Validation: Must be one of: "Computer", "User", "Group", "OU"
        
        - Computer: Searches for computer objects (automatically appends $ to sAMAccountName)
        - User: Searches for user objects by sAMAccountName
        - Group: Searches for group objects by sAMAccountName
        - OU: Searches for organizational unit objects by OU name

    .PARAMETER Name
        Specifies the name of the Active Directory object to find.
        
        Type: String
        Required: True
        Position: Named
        Default value: None
        Accept pipeline input: False
        Accept wildcard characters: False
        
        Notes:
        - For Computer objects: Do NOT include the trailing $ (it will be added automatically)
        - For User/Group objects: Use the sAMAccountName (login name)
        - For OU objects: Use the OU common name
        - Case-insensitive matching
        
        Syntax (BNF):
        <find-command> ::= "Find-ADSIObject" "-Type" <object-type> "-Name" <object-name>
        <object-type> ::= "Computer" | "User" | "Group" | "OU"
        <object-name> ::= <string-literal>
        <string-literal> ::= <alphanumeric-chars> [<special-chars>]*

    .EXAMPLE
        Find-ADSIObject -Type User -Name "jdoe"
        
        Searches for users with sAMAccountName "jdoe" and returns one or more ADSI objects.

    .EXAMPLE
        Find-ADSIObject -Type Computer -Name "WORKSTATION01"
        
        Searches for a computer named "WORKSTATION01" (automatically searches for "WORKSTATION01$").

    .EXAMPLE
        $results = Find-ADSIObject -Type Group -Name "IT-Admins"
        $results | Select-Object Name, distinguishedName
        
        Searches for groups named "IT-Admins" and lists key properties for all matches.
        
    .EXAMPLE
        $results = Find-ADSIObject -Type OU -Name "Sales"
        if ( $results -is [System.Array] ) {
            "Found $($results.Count) matching OUs"
        } elseif ( $results ) {
            "Found 1 matching OU"
        }
        
        Searches for Organizational Units named "Sales" and handles one-or-many results.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, HelpMessage = "Specify the type of AD object to search for")]
        [ValidateSet("Computer", "User", "Group", "OU")]
        [string]$Type,

        [Parameter(Mandatory, HelpMessage = "Enter the name of the AD object to find")]
        [string]$Name
    )

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
    $results = $searcher.FindAll()

    try {
        $matches = foreach ( $result in $results ) {
            if ( $result.Properties["adspath"] -and $result.Properties["adspath"].Count -gt 0 ) {
                [ADSI]$result.Properties["adspath"][0]
            }
        }
    } finally {
        if ( $results ) {
            $results.Dispose()
        }
    }

    if ( $matches ) {
        return $matches
    }

    Write-Warning "$Type '$Name' not found in AD."
    return $null
}

Export-ModuleMember Find-ADSIObject