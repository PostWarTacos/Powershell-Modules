<#
.SYNOPSIS
    Active Directory utilities using ADSI without requiring the ActiveDirectory module.
#>

function Find-ADSIObject {
    <#
    .SYNOPSIS
        Finds Active Directory objects (Computer, User, Group, OU) using ADSI.

    .PARAMETER Type
        Type of AD object: Computer, User, Group, or OU

    .PARAMETER Name
        Name of the AD object (do not include $ for computers)

    .EXAMPLE
        Find-ADSIObject -Type User -Name "jdoe"

    .EXAMPLE
        Find-ADSIObject -Type Computer -Name "WORKSTATION01"
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
    $result = $searcher.FindOne()

    if ( $result -and $result.Properties["adspath"] ) {
        return [ADSI]$result.Properties["adspath"][0]
    } else {
        Write-Warning "$Type '$Name' not found in AD."
        return $null
    }
}

Export-ModuleMember Find-ADSIObject