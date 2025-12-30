# PowerShell Modules

A collection of custom PowerShell modules for enhanced productivity and system administration.

> **Note:** This repository contains PowerShell modules only. For the PowerShell profile configuration that uses these modules, see [PowerShellProfile](https://github.com/PostWarTacos/PowerShellProfile).

## Modules

### AdminTools
Provides sudo-like elevation commands for PowerShell.

**Functions:**
- `admin` - Elevate commands or open elevated PowerShell window
  - Supports `-net` switch for domain admin credentials
  - Default domain: `DDS` (customizable in script or when prompted)
  - Default username: `wurtzmt-a` (customizable in script or when prompted)

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
To change the default domain and username, edit the values in [AdminTools.psm1](AdminTools/AdminTools.psm1):
```powershell
$domain = if ([string]::IsNullOrWhiteSpace($domainInput)) { "DDS" } else { $domainInput }
$username = if ([string]::IsNullOrWhiteSpace($usernameInput)) { "wurtzmt-a" } else { $usernameInput }
```

---

### ADSITools
Active Directory utilities using ADSI without requiring the ActiveDirectory module.

**Description:**
Lightweight AD tools that work without needing the full AD module installed.

---

### Dillards
Retrieves store information from the Dillards DDS API.

**Description:**
Custom module for querying Dillards store data.

---

### GUIDTools
Tools for finding GUIDs in registry and MSI files.

**Description:**
Utilities for working with GUIDs in the Windows registry and MSI installers.

---

### LinuxAliases
Unix/Linux command equivalents for PowerShell.

**Functions:**
- `grep` - Search for text patterns in files
- `touch` - Create empty file or update timestamp
- `df` - Display disk space usage
- `sed` - Stream editor
- `which` - Locate command paths
- `export` - Set environment variables
- `pkill` - Kill processes by name
- `pgrep` - Find processes by name
- `head` - Display first lines of file
- `tail` - Display last lines of file
- `unzip` - Extract ZIP archives
- `mkcd` - Create directory and navigate to it
- `ll` - Detailed directory listing
- `find-file` - Find files by name
- `cpy` - Copy to clipboard
- `pst` - Paste from clipboard
- `sysinfo` - Display system information

**Usage:**
```powershell
# Search for pattern in files
grep "error" C:\Logs

# Create new file
touch newfile.txt

# Show disk usage
df

# Create directory and cd into it
mkcd NewProject
```

---

### RemoteExecution
Executes scripts on remote computers with transcript logging.

**Description:**
Tools for running scripts remotely with built-in logging capabilities.

---

### Utilities
General-purpose utility functions for logging, file dialogs, system maintenance, and performance testing.

**Functions:**
- `Get-PubIP` - Get your public IP address
- `winutil` - Launch Chris Titus Tech's Windows Utility
- `Update-PowerShell` - Check for and install PowerShell updates
- Additional file dialogs, logging, and system utilities

**Usage:**
```powershell
# Get public IP
Get-PubIP

# Update PowerShell
Update-PowerShell

# Launch Windows Utility
winutil
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
1. Clone this repository to `~\Documents\Coding\Powershell-Modules\`
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
   $modulePath = Join-Path $HOME 'Documents\Coding\Powershell-Modules'
   $currentPath = [Environment]::GetEnvironmentVariable("PSModulePath", "User")
   [Environment]::SetEnvironmentVariable("PSModulePath", "$modulePath;$currentPath", "User")
   ```

3. Restart PowerShell or refresh the session:
   ```powershell
   $env:PSModulePath += ";$HOME\Documents\Coding\Powershell-Modules"
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
Get-ChildItem "$HOME\Documents\Coding\Powershell-Modules" -Directory | 
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
