Function Get-FileName() {
    <#
    .SYNOPSIS
        Opens a file dialog to allow the user to select a file and returns the full path.

    .DESCRIPTION
        The Get-FileName function displays a Windows file browser dialog that allows users to 
        navigate and select a file. It returns the full path of the selected file as a string.
        If the user cancels the dialog, an empty string is returned.

        This function uses the Windows.Forms.OpenFileDialog class to provide a familiar 
        file selection interface.

    .PARAMETER InitialDirectory
        Specifies the initial directory that the file dialog will open to. This parameter 
        is mandatory and must be a valid directory path. The directory should exist, 
        though the function will still work if it doesn't (defaulting to a system directory).

    .INPUTS
        System.String
        You can pipe a directory path string to this function.

    .OUTPUTS
        System.String
        Returns the full path of the selected file, or an empty string if cancelled.

    .EXAMPLE
        Get-FileName -InitialDirectory "C:\Users\Documents"
        
        Opens a file dialog starting in the C:\Users\Documents directory and returns 
        the path of the selected file.

    .EXAMPLE
        $selectedFile = Get-FileName -InitialDirectory $env:USERPROFILE
        if ($selectedFile) {
            Write-Host "You selected: $selectedFile"
        } else {
            Write-Host "No file was selected."
        }
        
        Demonstrates capturing the return value and handling the case where no file is selected.

    .EXAMPLE
        "C:\Temp" | Get-FileName
        
        Shows how to pipe a directory path to the function.

    .NOTES
        File Name      : Get-FileName.psm1
        Author         : [Author Name]
        Prerequisite   : PowerShell V2.0+, Windows Forms
        
        This function requires the System.Windows.Forms assembly, which is automatically 
        loaded when the function runs. The function is designed for Windows systems only.

    .LINK
        https://docs.microsoft.com/en-us/dotnet/api/system.windows.forms.openfiledialog

    .LINK
        Get-Help

    #>
    
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Enter the initial directory path for the file dialog"
        )]
        [ValidateNotNullOrEmpty()]
        [string]$InitialDirectory
    )
    
    begin {
        # Load the Windows Forms assembly
        try {
            [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
        }
        catch {
            throw "Failed to load Windows Forms assembly. This function requires Windows Forms support."
        }
    }
    
    process {
        try {
            # Create and configure the OpenFileDialog
            $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $OpenFileDialog.InitialDirectory = $InitialDirectory
            $OpenFileDialog.Filter = "All files (*.*)|*.*"
            $OpenFileDialog.Title = "Select a File"
            $OpenFileDialog.Multiselect = $false
            
            # Show the dialog and capture the result
            $dialogResult = $OpenFileDialog.ShowDialog()
            
            # Return the selected filename if OK was clicked, otherwise return empty string
            if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
                return $OpenFileDialog.FileName
            } else {
                return ""
            }
        }
        catch {
            Write-Error "An error occurred while displaying the file dialog: $($_.Exception.Message)"
            return ""
        }
        finally {
            # Clean up the dialog object
            if ($OpenFileDialog) {
                $OpenFileDialog.Dispose()
            }
        }
    }
}

Export-ModuleMember Get-FileName