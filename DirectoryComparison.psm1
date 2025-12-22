#region Main Public Function

function Compare-Directories {
    <#
    .SYNOPSIS
        Compares two directories using file-by-file or archive-then-hash method.
    
    .PARAMETER PathA
        First directory path
    
    .PARAMETER PathB
        Second directory path
    
    .PARAMETER Method
        Direct (file-by-file, detailed) or Archive (fast, hash-based)
    
    .PARAMETER Algorithm
        Hash algorithm (MD5, SHA1, SHA256, SHA384, SHA512). Default: SHA256
    
    .PARAMETER Detailed
        Returns detailed results instead of boolean
    
    .EXAMPLE
        Compare-Directories -PathA "C:\Folder1" -PathB "C:\Folder2" -Method Direct
    
    .EXAMPLE
        $result = Compare-Directories -PathA "C:\Source" -PathB "C:\Backup" -Method Direct -Detailed
        $result.Differences | Where-Object { $_.Status -eq "Missing in PathB" }
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$PathA,

        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$PathB,
        
        [Parameter(Mandatory)]
        [ValidateSet("Direct", "Archive")]
        [string]$Method,
        
        [ValidateSet("MD5", "SHA1", "SHA256", "SHA384", "SHA512")]
        [string]$Algorithm = "SHA256",
        
        [switch]$Detailed
    )

    $PathA = Resolve-Path $PathA
    $PathB = Resolve-Path $PathB
    
    switch ($Method) {
        "Direct" {
            return Compare-DirectoriesDirect -PathA $PathA -PathB $PathB -Algorithm $Algorithm -Detailed:$Detailed
        }
        "Archive" {
            return Compare-DirectoriesArchive -PathA $PathA -PathB $PathB -Algorithm $Algorithm -Detailed:$Detailed
        }
    }
}

#endregion

#region Helper Functions

function Compare-DirectoriesDirect {
    param (
        [string]$PathA,
        [string]$PathB,
        [string]$Algorithm,
        [bool]$Detailed
    )
    
    Write-Verbose "Starting direct file-by-file comparison between '$PathA' and '$PathB'"
    
    $filesA = Get-ChildItem -Path $PathA -Recurse -File | ForEach-Object {
        [PSCustomObject]@{
            RelativePath = $_.FullName.Substring($PathA.Length + 1)
            FullPath = $_.FullName
            Size = $_.Length
            LastWriteTime = $_.LastWriteTime
        }
    }
    
    $filesB = Get-ChildItem -Path $PathB -Recurse -File | ForEach-Object {
        [PSCustomObject]@{
            RelativePath = $_.FullName.Substring($PathB.Length + 1)
            FullPath = $_.FullName
            Size = $_.Length
            LastWriteTime = $_.LastWriteTime
        }
    }
    
    $differences = @()
    $matches = 0
    $totalFiles = ($filesA.Count + $filesB.Count)
    
    foreach ($fileA in $filesA) {
        $fileB = $filesB | Where-Object { $_.RelativePath -eq $fileA.RelativePath }
        
        if (-not $fileB) {
            $differences += [PSCustomObject]@{
                RelativePath = $fileA.RelativePath
                Status = "Missing in PathB"
                PathA_Size = $fileA.Size
                PathB_Size = $null
                PathA_Hash = $null
                PathB_Hash = $null
            }
        }
        elseif ($fileA.Size -ne $fileB.Size) {
            $differences += [PSCustomObject]@{
                RelativePath = $fileA.RelativePath
                Status = "Size differs"
                PathA_Size = $fileA.Size
                PathB_Size = $fileB.Size
                PathA_Hash = $null
                PathB_Hash = $null
            }
        }
        else {
            try {
                $hashA = (Get-FileHash -Path $fileA.FullPath -Algorithm $Algorithm).Hash
                $hashB = (Get-FileHash -Path $fileB.FullPath -Algorithm $Algorithm).Hash
                
                if ($hashA -ne $hashB) {
                    $differences += [PSCustomObject]@{
                        RelativePath = $fileA.RelativePath
                        Status = "Content differs"
                        PathA_Size = $fileA.Size
                        PathB_Size = $fileB.Size
                        PathA_Hash = $hashA
                        PathB_Hash = $hashB
                    }
                }
                else {
                    $matches++
                }
            }
            catch {
                $differences += [PSCustomObject]@{
                    RelativePath = $fileA.RelativePath
                    Status = "Hash calculation failed: $($_.Exception.Message)"
                    PathA_Size = $fileA.Size
                    PathB_Size = $fileB.Size
                    PathA_Hash = $null
                    PathB_Hash = $null
                }
            }
        }
    }
    
    foreach ($fileB in $filesB) {
        $fileA = $filesA | Where-Object { $_.RelativePath -eq $fileB.RelativePath }
        
        if (-not $fileA) {
            $differences += [PSCustomObject]@{
                RelativePath = $fileB.RelativePath
                Status = "Missing in PathA"
                PathA_Size = $null
                PathB_Size = $fileB.Size
                PathA_Hash = $null
                PathB_Hash = $null
            }
        }
    }
    
    if ($Detailed) {
        return [PSCustomObject]@{
            Method = "Direct"
            AreIdentical = ($differences.Count -eq 0)
            TotalFiles = [Math]::Max($filesA.Count, $filesB.Count)
            MatchingFiles = $matches
            Differences = $differences
            Summary = "Found $($differences.Count) differences out of $([Math]::Max($filesA.Count, $filesB.Count)) files"
        }
    }
    else {
        return ($differences.Count -eq 0)
    }
}

function Compare-DirectoriesArchive {
    param (
        [string]$PathA,
        [string]$PathB,
        [string]$Algorithm,
        [bool]$Detailed
    )
    
    Write-Verbose "Starting archive-then-hash comparison between '$PathA' and '$PathB'"
    
    $zipA = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, ".zip")
    $zipB = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, ".zip")

    try {
        Write-Verbose "Creating archive for PathA: $PathA -> $zipA"
        Compress-Archive -Path "$PathA\*" -DestinationPath $zipA -Force
        
        Write-Verbose "Creating archive for PathB: $PathB -> $zipB"
        Compress-Archive -Path "$PathB\*" -DestinationPath $zipB -Force

        $hashA = Get-FileHash -Path $zipA -Algorithm $Algorithm
        $hashB = Get-FileHash -Path $zipB -Algorithm $Algorithm
        
        $areIdentical = ($hashA.Hash -eq $hashB.Hash)
        
        if ($Detailed) {
            $zipASize = (Get-Item $zipA).Length
            $zipBSize = (Get-Item $zipB).Length
            
            return [PSCustomObject]@{
                Method = "Archive"
                AreIdentical = $areIdentical
                Algorithm = $Algorithm
                PathA_Hash = $hashA.Hash
                PathB_Hash = $hashB.Hash
                PathA_ArchiveSize = $zipASize
                PathB_ArchiveSize = $zipBSize
                Summary = if ($areIdentical) { "Directories are identical" } else { "Directories differ" }
            }
        }
        else {
            return $areIdentical
        }
    }
    catch {
        Write-Error "Failed to compare directories using archive method: $($_.Exception.Message)"
        
        if ($Detailed) {
            return [PSCustomObject]@{
                Method = "Archive"
                AreIdentical = $false
                Error = $_.Exception.Message
                Summary = "Comparison failed"
            }
        }
        else {
            return $false
        }
    }
    finally {
        Remove-Item $zipA, $zipB -Force -ErrorAction SilentlyContinue
    }
}

#endregion

Export-ModuleMember Compare-Directories