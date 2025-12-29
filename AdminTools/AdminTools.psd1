@{
    RootModule = 'AdminTools.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'f8a3e4d2-9c1b-4a7e-8d6f-2c5b9e1a3f4d'
    Author = 'wurtzmt'
    Description = 'Provides sudo-like elevation commands for PowerShell'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('admin')
    AliasesToExport = @('su', 'sudo')
    PrivateData = @{
        PSData = @{
            Tags = @('admin', 'elevation', 'sudo', 'privilege')
        }
    }
}
