# LinuxAliases Module
# Unix/Linux command equivalents for PowerShell

function grep {
    <#
    .SYNOPSIS
        Searches for text patterns in files (Unix grep equivalent).
    
    .DESCRIPTION
        Searches files or pipeline input for lines matching a regular expression pattern.
        Mimics Unix/Linux grep behavior in PowerShell using Select-String.
    
    .PARAMETER regex
        The regular expression pattern to search for.
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
        
        Syntax (BNF):
        <grep-command> ::= "grep" <regex-pattern> [<directory>]
        <regex-pattern> ::= <pcre-expression>
    
    .PARAMETER dir
        Optional directory path to search. If specified, searches all files in the directory.
        If omitted, searches pipeline input.
        
        Type: String
        Required: False
        Position: 1
        Accept pipeline input: False
    
    .EXAMPLE
        Get-Content file.txt | grep "error"
        Searches for "error" in pipeline input.
    
    .EXAMPLE
        grep "TODO" C:\Scripts
        Searches all files in C:\Scripts for "TODO".
    #>
    param($regex, $dir)
    
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

function touch {
    <#
    .SYNOPSIS
        Creates an empty file or updates the timestamp (Unix touch equivalent).
    
    .DESCRIPTION
        Creates a new empty file if it doesn't exist. In Unix, this also updates modification time,
        but this implementation focuses on file creation.
    
    .PARAMETER file
        The path of the file to create.
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
        
        Syntax (BNF):
        <touch-command> ::= "touch" <file-path>
        <file-path> ::= <absolute-path> | <relative-path>
    
    .EXAMPLE
        touch newfile.txt
        Creates an empty file named newfile.txt.
    #>
    param($file)
    
    "" | Out-File $file -Encoding ASCII
}

function df {
    <#
    .SYNOPSIS
        Displays disk space usage (Unix df equivalent).
    
    .DESCRIPTION
        Shows information about all mounted volumes including drive letters, file system types,
        capacity, and free space. Windows equivalent of Unix df command.
    
    .EXAMPLE
        df
        Displays all volume information.
        
    .NOTES
        Syntax (BNF):
        <df-command> ::= "df"
    #>
    get-volume
}

function sed {
    <#
    .SYNOPSIS
        Performs find and replace in files (Unix sed equivalent).
    
    .DESCRIPTION
        Searches for text in a file and replaces all occurrences with new text.
        Simple implementation of Unix sed for basic text replacement operations.
    
    .PARAMETER file
        The path to the file to modify.
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
    
    .PARAMETER find
        The text string to search for.
        
        Type: String
        Required: True
        Position: 1
        Accept pipeline input: False
    
    .PARAMETER replace
        The text string to replace matches with.
        
        Type: String
        Required: True
        Position: 2
        Accept pipeline input: False
        
        Syntax (BNF):
        <sed-command> ::= "sed" <file-path> <find-string> <replace-string>
    
    .EXAMPLE
        sed config.txt "old_value" "new_value"
        Replaces all occurrences of "old_value" with "new_value" in config.txt.
    #>
    param($file, $find, $replace)
    
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which {
    <#
    .SYNOPSIS
        Locates a command and shows its path (Unix which equivalent).
    
    .DESCRIPTION
        Finds the full path of an executable, cmdlet, function, or alias.
        Equivalent to Unix/Linux 'which' command.
    
    .PARAMETER name
        The name of the command to locate.
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
        
        Syntax (BNF):
        <which-command> ::= "which" <command-name>
        <command-name> ::= <string-literal>
    
    .EXAMPLE
        which powershell
        Returns the full path to the PowerShell executable.
    
    .EXAMPLE
        which Get-Process
        Shows the definition location of the Get-Process cmdlet.
    #>
    param($name)
    
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export {
    <#
    .SYNOPSIS
        Sets environment variables (Unix export equivalent).
    
    .DESCRIPTION
        Creates or updates an environment variable in the current session.
        Equivalent to Unix/Linux 'export' command.
    
    .PARAMETER name
        The name of the environment variable to set.
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
    
    .PARAMETER value
        The value to assign to the environment variable.
        
        Type: String
        Required: True
        Position: 1
        Accept pipeline input: False
        
        Syntax (BNF):
        <export-command> ::= "export" <var-name> <var-value>
        <var-name> ::= <identifier>
        <var-value> ::= <string-literal>
    
    .EXAMPLE
        export "PATH" "C:\NewPath;$env:PATH"
        Prepends C:\NewPath to the PATH environment variable.
    
    .EXAMPLE
        export "MY_VAR" "SomeValue"
        Creates MY_VAR environment variable with value "SomeValue".
    #>
    param($name, $value)
    
    set-item -force -path "env:$name" -value $value;
}

function pkill {
    <#
    .SYNOPSIS
        Terminates processes by name (Unix pkill equivalent).
    
    .DESCRIPTION
        Stops all processes matching the specified name. Equivalent to Unix/Linux pkill command.
        Suppresses errors if the process is not found.
    
    .PARAMETER name
        The name of the process(es) to terminate (without .exe extension).
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
        
        Syntax (BNF):
        <pkill-command> ::= "pkill" <process-name>
        <process-name> ::= <identifier>
    
    .EXAMPLE
        pkill notepad
        Terminates all running notepad processes.
    
    .EXAMPLE
        pkill chrome
        Stops all Chrome browser processes.
    #>
    param($name)
    
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep {
    <#
    .SYNOPSIS
        Lists processes by name (Unix pgrep equivalent).
    
    .DESCRIPTION
        Finds and displays information about running processes matching the specified name.
        Equivalent to Unix/Linux pgrep command.
    
    .PARAMETER name
        The name of the process(es) to find (without .exe extension).
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
        
        Syntax (BNF):
        <pgrep-command> ::= "pgrep" <process-name>
        <process-name> ::= <identifier>
    
    .EXAMPLE
        pgrep explorer
        Displays information about the Windows Explorer process.
    
    .EXAMPLE
        pgrep powershell
        Lists all PowerShell processes currently running.
    #>
    param($name)
    
    Get-Process $name
}

function head {
    <#
    .SYNOPSIS
        Displays the first N lines of a file (Unix head equivalent).
    
    .DESCRIPTION
        Reads and displays the beginning of a file. By default shows the first 10 lines.
        Equivalent to Unix/Linux head command.
    
    .PARAMETER Path
        The path to the file to read.
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
    
    .PARAMETER n
        The number of lines to display from the beginning of the file.
        
        Type: Int32
        Required: False
        Position: 1
        Default value: 10
        Accept pipeline input: False
        
        Syntax (BNF):
        <head-command> ::= "head" <file-path> [<line-count>]
        <line-count> ::= "-n" <positive-integer>
    
    .EXAMPLE
        head log.txt
        Displays the first 10 lines of log.txt.
    
    .EXAMPLE
        head config.ini -n 20
        Shows the first 20 lines of config.ini.
    #>
    param($Path, $n = 10)
    
    Get-Content $Path -Head $n
}

function tail {
    <#
    .SYNOPSIS
        Displays the last N lines of a file (Unix tail equivalent).
    
    .DESCRIPTION
        Reads and displays the end of a file. By default shows the last 10 lines.
        Supports following/watching the file for new content with the -f switch.
        Equivalent to Unix/Linux tail command.
    
    .PARAMETER Path
        The path to the file to read.
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
    
    .PARAMETER n
        The number of lines to display from the end of the file.
        
        Type: Int32
        Required: False
        Position: 1
        Default value: 10
        Accept pipeline input: False
    
    .PARAMETER f
        Follow mode - continues to monitor the file and display new lines as they are added.
        
        Type: Switch
        Required: False
        Default value: False
        Accept pipeline input: False
        
        Syntax (BNF):
        <tail-command> ::= "tail" <file-path> [<line-count>] [<follow-switch>]
        <line-count> ::= "-n" <positive-integer>
        <follow-switch> ::= "-f"
    
    .EXAMPLE
        tail log.txt
        Displays the last 10 lines of log.txt.
    
    .EXAMPLE
        tail error.log -n 50
        Shows the last 50 lines of error.log.
    
    .EXAMPLE
        tail -f application.log
        Continuously monitors and displays new lines added to application.log.
    #>
    param($Path, $n = 10, [switch]$f = $false)
    
    Get-Content $Path -Tail $n -Wait:$f
}

function unzip {
    <#
    .SYNOPSIS
        Extracts a ZIP archive (Unix unzip equivalent).
    
    .DESCRIPTION
        Extracts all contents of a ZIP archive to the current directory.
        Equivalent to Unix/Linux unzip command.
    
    .PARAMETER file
        The name of the ZIP file to extract (must be in current directory).
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
        
        Syntax (BNF):
        <unzip-command> ::= "unzip" <zip-filename>
        <zip-filename> ::= <filename> ".zip"
    
    .EXAMPLE
        unzip archive.zip
        Extracts all contents of archive.zip to the current directory.
    
    .EXAMPLE
        unzip package.zip
        Extracts package.zip in the current working directory.
    #>
    param($file)
    
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

function mkcd {
    <#
    .SYNOPSIS
        Creates a directory and changes to it (combined mkdir + cd).
    
    .DESCRIPTION
        Creates a new directory (including parent directories if needed) and immediately
        changes the current location to that directory. Combines Unix mkdir and cd commands.
    
    .PARAMETER dir
        The path of the directory to create and navigate to.
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
        
        Syntax (BNF):
        <mkcd-command> ::= "mkcd" <directory-path>
        <directory-path> ::= <absolute-path> | <relative-path>
    
    .EXAMPLE
        mkcd C:\Projects\NewProject
        Creates the directory C:\Projects\NewProject and navigates to it.
    
    .EXAMPLE
        mkcd ./test/subfolder
        Creates subfolder within test directory and changes to it.
    #>
    param($dir)
    
    mkdir $dir -Force
    Set-Location $dir
}

function ll {
    <#
    .SYNOPSIS
        Lists directory contents including hidden files (Unix ls -la equivalent).
    
    .DESCRIPTION
        Displays all files and folders in the current directory including hidden items,
        formatted as a table. Equivalent to Unix/Linux 'ls -la' command.
    
    .EXAMPLE
        ll
        Lists all items in the current directory including hidden files.
        
    .NOTES
        Syntax (BNF):
        <ll-command> ::= "ll"
    #>
    Get-ChildItem -Force | Format-Table -AutoSize
}

function find-file {
    <#
    .SYNOPSIS
        Recursively searches for files by name (Unix find equivalent).
    
    .DESCRIPTION
        Searches the current directory and all subdirectories for files matching the specified
        name pattern. Supports wildcard matching. Equivalent to Unix/Linux find command.
    
    .PARAMETER name
        The name or pattern to search for (supports wildcards).
        
        Type: String
        Required: True
        Position: 0
        Accept pipeline input: False
        Accept wildcard characters: True
        
        Syntax (BNF):
        <find-file-command> ::= "find-file" <search-pattern>
        <search-pattern> ::= <literal-string> | <wildcard-pattern>
        <wildcard-pattern> ::= [<chars>]* "*" [<chars>]*
    
    .EXAMPLE
        find-file "*.txt"
        Finds all text files in the current directory and subdirectories.
    
    .EXAMPLE
        find-file "config"
        Searches for files containing "config" in their name.
    #>
    param($name)
    
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        $place_path = $_.directory
        Write-Output "${place_path}\${_}"
    }
}

function cpy {
    <#
    .SYNOPSIS
        Copies text to the clipboard (Unix-style clipboard copy).
    
    .DESCRIPTION
        Copies the specified text or object to the Windows clipboard.
        Provides a Unix-style interface to clipboard operations.
    
    .PARAMETER args
        The content to copy to the clipboard.
        
        Type: Object
        Required: True
        Position: 0
        Accept pipeline input: False
        
        Syntax (BNF):
        <cpy-command> ::= "cpy" <content>
        <content> ::= <string> | <object>
    
    .EXAMPLE
        cpy "Hello World"
        Copies "Hello World" to the clipboard.
    
    .EXAMPLE
        cpy (Get-Content file.txt)
        Copies the contents of file.txt to the clipboard.
    #>
    Set-Clipboard $args[0]
}

function pst {
    <#
    .SYNOPSIS
        Pastes text from the clipboard (Unix-style clipboard paste).
    
    .DESCRIPTION
        Retrieves and displays the current contents of the Windows clipboard.
        Provides a Unix-style interface to clipboard operations.
    
    .EXAMPLE
        pst
        Displays the current clipboard contents.
    
    .EXAMPLE
        pst | Out-File output.txt
        Saves clipboard contents to a file.
        
    .NOTES
        Syntax (BNF):
        <pst-command> ::= "pst"
    #>
    Get-Clipboard
}

function sysinfo {
    <#
    .SYNOPSIS
        Displays detailed system information (Unix uname/systeminfo equivalent).
    
    .DESCRIPTION
        Retrieves and displays comprehensive computer information including OS version,
        hardware details, BIOS info, and network configuration. Equivalent to Unix uname -a
        or systeminfo commands.
    
    .EXAMPLE
        sysinfo
        Displays complete system information.
    
    .EXAMPLE
        sysinfo | Select-Object CsName, WindowsVersion, OsArchitecture
        Displays specific system properties.
        
    .NOTES
        Syntax (BNF):
        <sysinfo-command> ::= "sysinfo"
    #>
    Get-ComputerInfo
}

# Export all public functions
Export-ModuleMember -Function grep, touch, df, sed, which, export, pkill, pgrep, head, tail, unzip, mkcd, ll, find-file, cpy, pst, sysinfo
