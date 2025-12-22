# PowerShell Profile Optimization Recommendations

**Current Performance:** Consistent 9 seconds load time after adding .psd1 manifests

## Optimization Opportunities

### 1. Lazy Load Cosmetic Modules
Oh-My-Posh and Terminal-Icons add overhead. Consider lazy loading them or only loading when terminal is interactive:

```powershell
# Only in interactive sessions
if ([Environment]::UserInteractive) {
    Import-Module -Name Terminal-Icons
    # oh-my-posh code...
}
```

**Expected Impact:** Could save 1-2 seconds

---

### 2. Optimize Git Operations
The `git fetch` and hash comparison happens every time. Consider:

**Option A: Time-based caching**
```powershell
$lastSyncFile = "$clonePath\.lastsync"
$syncInterval = 3600 # seconds (1 hour)

if (Test-Path $lastSyncFile) {
    $lastSync = Get-Content $lastSyncFile
    $timeSinceSync = (Get-Date).Ticks - [long]$lastSync
    if ($timeSinceSync -lt ($syncInterval * 10000000)) {
        return # Skip sync
    }
}
# Run sync...
(Get-Date).Ticks | Out-File $lastSyncFile
```

**Option B: Async background sync**
```powershell
Start-Job -ScriptBlock { 
    param($path, $url)
    # Git sync logic here
} -ArgumentList $clonePath, $repoURL | Out-Null
```

**Expected Impact:** Could save 1-3 seconds depending on network latency

---

### 3. Reduce WMI Calls
Cache the product type check result rather than calling WMI each profile load:

```powershell
# At the start of profile
$script:isWorkstation = $null

function Test-IsWorkstation {
    if ($null -eq $script:isWorkstation) {
        $script:isWorkstation = ((Get-WmiObject -class win32_OperatingSystem).ProductType -eq 1)
    }
    return $script:isWorkstation
}

# Later in code
if (Test-IsWorkstation) {
    # Cosmetics code...
}
```

**Expected Impact:** Negligible (< 0.1 seconds), but cleaner code

---

### 4. Conditional WinFetch
WinFetch runs on every console start. Consider only running on first terminal or with a flag:

```powershell
if ($env:WT_SESSION -and -not $env:WINFETCH_SHOWN) {
    winfetch -configpath $winfetchConfigPath
    $env:WINFETCH_SHOWN = $true
}
```

**Alternative:** Only show on specific days or first launch of the day
```powershell
$lastWinFetch = "$env:TEMP\.lastwinfetch"
$showWinFetch = $true

if (Test-Path $lastWinFetch) {
    $lastDate = Get-Content $lastWinFetch
    if ($lastDate -eq (Get-Date -Format "yyyyMMdd")) {
        $showWinFetch = $false
    }
}

if ($showWinFetch) {
    winfetch -configpath $winfetchConfigPath
    (Get-Date -Format "yyyyMMdd") | Out-File $lastWinFetch
}
```

**Expected Impact:** Could save 0.5-1 second on subsequent terminal launches

---

### 5. Parallel Module Imports
Import multiple modules simultaneously instead of sequentially:

```powershell
$modules = Get-ChildItem $clonePath -Filter *.psd1
$modules | ForEach-Object -Parallel {
    Import-Module $_.fullname
} -ThrottleLimit 5
```

**Note:** Only available in PowerShell 7+. May not provide significant benefit with only 5 modules.

**Expected Impact:** 0.2-0.5 seconds (PowerShell 7+ only)

---

### 6. Skip Internet Check if Not Needed
The internet connectivity check runs every time but may only be needed for specific operations:

```powershell
function Test-InternetConnectivity {
    try {
        $connectionProfile = Get-NetConnectionProfile -ErrorAction SilentlyContinue | 
            Where-Object { $_.IPv4Connectivity -eq 'Internet' -or $_.IPv6Connectivity -eq 'Internet' }
        return [bool]$connectionProfile
    } catch {
        return $false
    }
}

# Only call when needed
if ((Test-InternetConnectivity) -and -not (Test-Path $ompConfigPath)) {
    Invoke-WebRequest ...
}
```

**Expected Impact:** Minimal, but cleaner code structure

---

## Recommended Priority Order

1. **Async Git Sync** (Highest impact: 1-3 seconds)
2. **Conditional WinFetch** (Medium impact: 0.5-1 second)
3. **Lazy Load Cosmetics** (Medium impact: 1-2 seconds)
4. **Time-based Git Caching** (Alternative to async, easier to implement)
5. **Cached WMI Calls** (Low impact, code quality improvement)

## Target Performance
With optimizations 1-3 implemented, profile load time could be reduced to **6-7 seconds** or less.

## Testing Recommendations
- Use `Measure-Command { . $PROFILE }` to test each optimization
- Test with and without internet connectivity
- Test first launch vs. subsequent launches
- Consider creating a "fast mode" profile variant for testing

---

*Generated: December 22, 2025*
