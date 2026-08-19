# PowerShell Modules

A collection of custom PowerShell modules for enhanced productivity and system administration.

> **Note:** This repository contains PowerShell modules only. For the PowerShell profile configuration that uses these modules, see [PowerShellProfile](https://github.com/PostWarTacos/PowerShellProfile).

## Modules

### AdminTools
Provides sudo-like elevation commands for PowerShell.

**Functions:**
- `admin` - Elevate commands or open elevated PowerShell window
  - Supports `-net` switch for domain admin credentials
  - Default domain: current `$env:USERDOMAIN` (customizable when prompted)
  - Default username: current `$env:USERNAME` (customizable when prompted)

**Aliases:**
- `su` → `admin`
- `sudo` → `admin`

**Usage:**
```powershell
# Open elevated PowerShell
admin

# Run command elevated
admin Get-Service

# Use domain admin credentials (prompts for domain, username, and password)
# Press Enter to accept defaults or type custom values
admin -net
```

**Customization:**
To change the defaults, edit the values in [AdminTools.psm1](AdminTools/AdminTools.psm1):
```powershell
$domain = if ([string]::IsNullOrWhiteSpace($domainInput)) { $env:USERDOMAIN } else { $domainInput }
$username = if ([string]::IsNullOrWhiteSpace($usernameInput)) { $env:USERNAME } else { $usernameInput }
```

---


### ADSITools
Active Directory utilities using ADSI without requiring the ActiveDirectory module.

**Functions:**
- `Find-ADSIObject` - Find AD Computers, Users, Groups, or OUs using ADSI (no AD module required)
   - Supports types: Computer, User, Group, OU
   - Example: `Find-ADSIObject -Type User -Name "jdoe"`

**Usage:**
```powershell
# Find a user
Find-ADSIObject -Type User -Name "jdoe"
# Find a computer
Find-ADSIObject -Type Computer -Name "WORKSTATION01"
```

---


### GUIDTools
Tools for finding GUIDs in registry and MSI files.

**Functions:**
- `Find-GUID` - Search registry for installed applications by name or publisher, return GUID and uninstall info
- `Find-GUIDinMSI` - Extract ProductCode, UpgradeCode, and ProductVersion from an MSI file

**Usage:**
```powershell
# Find GUID for installed app
Find-GUID -AppName "Chrome"
# Extract GUIDs from MSI
Find-GUIDinMSI -MSIPath "C:\Temp\app.msi"
```

---


### LinuxAliases
Unix/Linux command equivalents for PowerShell.

**Functions:**
- `grep`, `touch`, `df`, `sed`, `which`, `export`, `pkill`, `pgrep`, `head`, `tail`, `unzip`, `mkcd`, `ll`, `find-file`, `cpy`, `pst`, `sysinfo`

**Highlights:**
- `grep` - Search for text patterns in files or pipeline
- `touch` - Create empty file or update timestamp
- `df` - Show disk usage
- `sed` - Find and replace in files
- `which` - Locate command paths
- `export` - Set environment variables
- `pkill`/`pgrep` - Kill or find processes by name
- `head`/`tail` - Show first/last lines of file
- `unzip` - Extract ZIP archives
- `mkcd` - Create directory and navigate to it
- `ll` - Detailed directory listing
- `find-file` - Find files by name
- `cpy`/`pst` - Copy/paste clipboard
- `sysinfo` - Display system information

**Usage:**
```powershell
grep "error" C:\Logs
touch newfile.txt
df
mkcd NewProject
ll
find-file "*.ps1"
sysinfo
```

---


### RemoteExecution
Executes scripts on remote computers with transcript logging.

**Functions:**
- `Invoke-Script` - Run a script on a remote computer, log output to C:\temp\logs

**Usage:**
```powershell
Invoke-Script -ComputerName "SERVER01" -FilePath "C:\Scripts\HealthCheck.ps1"
```

---


### Utilities
General-purpose utility functions for logging, file dialogs, system maintenance, and performance testing.

**Functions:**
- `Get-PubIP` - Get your public IP address
- `winutil` - Launch Chris Titus Tech's Windows Utility
- `Update-PowerShell` - Check for and install PowerShell updates
- Many more: file dialogs, logging, system info, and more

**Usage:**
```powershell
Get-PubIP
winutil
Update-PowerShell
```

---

## Installation

These modules are automatically installed when you use the [PowerShellProfile](https://github.com/PostWarTacos/PowerShellProfile) installation script.

### Automatic Installation (Recommended)

Use the one-line installer from PowerShellProfile repository:
```powershell
irm https://raw.githubusercontent.com/PostWarTacos/PowerShellProfile/main/Install-PowerShellSetup.ps1 | iex
```

This will:
1. Clone this repository to `~\Documents\Coding\WorkspaceMeta\Powershell-Modules\`
2. Add the modules directory to your `PSModulePath`
3. Make all modules available for import

### Manual Installation

If you prefer to install manually:

1. Clone this repository:
   ```powershell
   cd ~\Documents\Coding
   git clone https://github.com/PostWarTacos/Powershell-Modules.git
   ```

2. Add modules to PowerShell module path:
   ```powershell
   $modulePath = Join-Path $HOME 'Documents\Coding\WorkspaceMeta\Powershell-Modules'
   $currentPath = [Environment]::GetEnvironmentVariable("PSModulePath", "User")
   [Environment]::SetEnvironmentVariable("PSModulePath", "$modulePath;$currentPath", "User")
   ```

3. Restart PowerShell or refresh the session:
   ```powershell
   $env:PSModulePath += ";$HOME\Documents\Coding\WorkspaceMeta\Powershell-Modules"
   ```

4. Import modules as needed:
   ```powershell
   Import-Module AdminTools
   Import-Module LinuxAliases
   Import-Module Utilities
   ```

## Usage

Once installed, modules can be imported manually or set to auto-import in your PowerShell profile:

```powershell
# Import individual module
Import-Module AdminTools

# Import all modules
Get-ChildItem "$HOME\Documents\Coding\WorkspaceMeta\Powershell-Modules" -Directory | 
    ForEach-Object { Import-Module $_.FullName -ErrorAction SilentlyContinue }
```

For automatic loading, add the import commands to your PowerShell profile (`$PROFILE`).

## Requirements

- **PowerShell 5.1** or **PowerShell 7+**
- **Windows 10/11** or **Windows Server 2016+**

## Module Structure

Each module follows the standard PowerShell module structure:
```
ModuleName/
├── ModuleName.psd1    # Module manifest
└── ModuleName.psm1    # Module script file
```

## Contributing

Feel free to submit issues or pull requests to improve these modules.

## Author

Created by **PostWarTacos**

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Repositories

- **[PowerShellProfile](https://github.com/PostWarTacos/PowerShellProfile)** - PowerShell profile configuration with Oh My Posh themes and terminal setup
