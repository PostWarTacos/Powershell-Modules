#region Main Public Function

function Compare-Directories {
    <#
    .SYNOPSIS
    Compares two directories using either direct file-by-file comparison or archive-then-hash method.
    
    .DESCRIPTION
    This function provides two methods to compare directories:
    1. Direct: Compares files directly by checking existence, size, and hash
    2. Archive: Creates archives of both directories and compares their hashes
    
    The Direct method is more granular and provides detailed information about differences,
    while the Archive method is faster for large directories with many files.
    
    .PARAMETER PathA
    Path to the first directory to compare. Must be a valid directory path.
    
    .PARAMETER PathB
    Path to the second directory to compare. Must be a valid directory path.
    
    .PARAMETER Method
    Comparison method: 'Direct' for file-by-file comparison or 'Archive' for archive-then-hash
    - Direct: Compares each file individually (slower but more detailed)
    - Archive: Creates ZIP archives and compares hashes (faster for large datasets)
    
    .PARAMETER Algorithm
    Hash algorithm to use for file/archive comparison (MD5, SHA1, SHA256, SHA384, SHA512)
    Default is SHA256 for good security and performance balance.
    
    .PARAMETER Detailed
    Returns detailed comparison results instead of just true/false.
    Includes information about differences, file counts, and comparison method used.
    
    .EXAMPLE
    Compare-Directories -PathA "C:\Folder1" -PathB "C:\Folder2" -Method Direct
    Returns $true if directories are identical, $false otherwise using direct comparison.
    
    .EXAMPLE
    Compare-Directories -PathA "C:\Folder1" -PathB "C:\Folder2" -Method Archive -Algorithm SHA256 -Detailed
    Returns detailed comparison object with hash information using archive method.
    
    .EXAMPLE
    $result = Compare-Directories -PathA "C:\Source" -PathB "C:\Backup" -Method Direct -Detailed
    $result.Differences | Where-Object { $_.Status -eq "Missing in PathB" }
    Get detailed information about files missing in the backup directory.
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_ -PathType Container})]  # Ensure path exists and is a directory
        [string]$PathA,

        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_ -PathType Container})]  # Ensure path exists and is a directory
        [string]$PathB,
        
        [Parameter(Mandatory)]
        [ValidateSet("Direct", "Archive")]  # Restrict to supported comparison methods
        [string]$Method,
        
        [ValidateSet("MD5", "SHA1", "SHA256", "SHA384", "SHA512")]  # Supported hash algorithms
        [string]$Algorithm = "SHA256",  # Default to SHA256 for good security/performance balance
        
        [switch]$Detailed  # Optional detailed output instead of simple boolean
    )

    # Convert relative paths to absolute paths for consistent processing
    # This ensures we have full paths regardless of current working directory
    $PathA = Resolve-Path $PathA
    $PathB = Resolve-Path $PathB
    
    # Route to appropriate comparison method based on user selection
    switch ($Method) {
        "Direct" {
            # Use direct file-by-file comparison for granular analysis
            return Compare-DirectoriesDirect -PathA $PathA -PathB $PathB -Algorithm $Algorithm -Detailed:$Detailed
        }
        "Archive" {
            # Use archive-then-hash method for faster bulk comparison
            return Compare-DirectoriesArchive -PathA $PathA -PathB $PathB -Algorithm $Algorithm -Detailed:$Detailed
        }
    }
}

#endregion

#region Helper Functions

function Compare-DirectoriesDirect {
    <#
    .SYNOPSIS
    Internal helper function for direct file-by-file directory comparison.
    
    .DESCRIPTION
    Performs detailed comparison by:
    1. Enumerating all files in both directories recursively
    2. Comparing file existence, sizes, and content hashes
    3. Tracking differences and generating detailed reports
    
    This method is more resource-intensive but provides granular difference information.
    #>
    param (
        [string]$PathA,        # First directory path (fully resolved)
        [string]$PathB,        # Second directory path (fully resolved)
        [string]$Algorithm,    # Hash algorithm to use for content comparison
        [bool]$Detailed        # Whether to return detailed results or simple boolean
    )
    
    Write-Verbose "Starting direct file-by-file comparison between '$PathA' and '$PathB'"
    
    # Get all files from both directories recursively
    # Create normalized file objects with relative paths for comparison
    # Relative paths allow us to compare file structure independent of root directory names
    $filesA = Get-ChildItem -Path $PathA -Recurse -File | ForEach-Object {
        [PSCustomObject]@{
            RelativePath = $_.FullName.Substring($PathA.Length + 1)  # Remove root path to get relative path
            FullPath = $_.FullName                                    # Keep full path for hash calculation
            Size = $_.Length                                          # File size in bytes
            LastWriteTime = $_.LastWriteTime                         # Timestamp (for future use)
        }
    }
    
    # Same structure for second directory
    $filesB = Get-ChildItem -Path $PathB -Recurse -File | ForEach-Object {
        [PSCustomObject]@{
            RelativePath = $_.FullName.Substring($PathB.Length + 1)  # Remove root path to get relative path
            FullPath = $_.FullName                                    # Keep full path for hash calculation
            Size = $_.Length                                          # File size in bytes
            LastWriteTime = $_.LastWriteTime                         # Timestamp (for future use)
        }
    }
    
    # Initialize tracking variables for comparison results
    $differences = @()    # Array to store all differences found
    $matches = 0         # Counter for files that match exactly
    $totalFiles = ($filesA.Count + $filesB.Count)  # Total files (may include duplicates)
    
    # First pass: Check all files in PathA against PathB
    # This finds missing files and content differences
    foreach ($fileA in $filesA) {
        # Look for corresponding file in PathB using relative path matching
        $fileB = $filesB | Where-Object { $_.RelativePath -eq $fileA.RelativePath }
        
        if (-not $fileB) {
            # File exists in PathA but not in PathB - record as missing
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
            # File exists in both but different sizes - definitely different content
            # Skip hash calculation as size difference is sufficient proof
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
            # Files exist in both locations and have same size
            # Need to compare content hashes to determine if content is identical
            try {
                # Calculate hash for both files using specified algorithm
                # This is the definitive test for content equality
                $hashA = (Get-FileHash -Path $fileA.FullPath -Algorithm $Algorithm).Hash
                $hashB = (Get-FileHash -Path $fileB.FullPath -Algorithm $Algorithm).Hash
                
                if ($hashA -ne $hashB) {
                    # Same size but different content - files have been modified
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
                    # Hashes match - files are identical
                    $matches++
                }
            }
            catch {
                # Handle cases where hash calculation fails (permissions, locked files, etc.)
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
    
    # Second pass: Check for files that exist in PathB but not in PathA
    # This catches files that were added to PathB or removed from PathA
    foreach ($fileB in $filesB) {
        # Look for corresponding file in PathA
        $fileA = $filesA | Where-Object { $_.RelativePath -eq $fileB.RelativePath }
        
        if (-not $fileA) {
            # File exists in PathB but not in PathA - record as missing from PathA
            $differences += [PSCustomObject]@{
                RelativePath = $fileB.RelativePath
                Status = "Missing in PathA"
                PathA_Size = $null
                PathB_Size = $fileB.Size
                PathA_Hash = $null
                PathB_Hash = $null
            }
        }
        # Note: If fileA exists, we already compared it in the first pass above
    }
    
    # Format and return results based on requested detail level
    if ($Detailed) {
        # Return comprehensive result object with all comparison details
        return [PSCustomObject]@{
            Method = "Direct"                                           # Comparison method used
            AreIdentical = ($differences.Count -eq 0)                 # Overall result: true if no differences
            TotalFiles = [Math]::Max($filesA.Count, $filesB.Count)    # Total unique files across both directories
            MatchingFiles = $matches                                   # Number of files that matched exactly
            Differences = $differences                                 # Array of all differences found
            Summary = "Found $($differences.Count) differences out of $([Math]::Max($filesA.Count, $filesB.Count)) files"
        }
    }
    else {
        # Return simple boolean result: true if identical, false if any differences
        return ($differences.Count -eq 0)
    }
}

function Compare-DirectoriesArchive {
    <#
    .SYNOPSIS
    Internal helper function for archive-based directory comparison.
    
    .DESCRIPTION
    Performs fast bulk comparison by:
    1. Creating ZIP archives of both directory structures
    2. Comparing archive hashes for overall equality
    3. Cleaning up temporary files
    
    This method is faster for large directories but provides less granular information.
    Archive comparison includes file content, names, paths, and directory structure.
    #>
    param (
        [string]$PathA,        # First directory path (fully resolved)
        [string]$PathB,        # Second directory path (fully resolved)
        [string]$Algorithm,    # Hash algorithm to use for archive comparison
        [bool]$Detailed        # Whether to return detailed results or simple boolean
    )
    
    Write-Verbose "Starting archive-then-hash comparison between '$PathA' and '$PathB'"
    
    # Create temporary file paths for ZIP archives
    # Using system temp directory ensures cleanup and avoids permission issues
    $zipA = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, ".zip")
    $zipB = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, ".zip")

    try {
        # Create ZIP archive of first directory
        # Archive includes all files, subdirectories, and preserves structure
        Write-Verbose "Creating archive for PathA: $PathA -> $zipA"
        Compress-Archive -Path "$PathA\*" -DestinationPath $zipA -Force
        
        # Create ZIP archive of second directory
        Write-Verbose "Creating archive for PathB: $PathB -> $zipB"
        Compress-Archive -Path "$PathB\*" -DestinationPath $zipB -Force

        # Calculate hash of each archive file
        # If archives are identical, the directories contain the same content
        # Archive hashes account for: file content, filenames, directory structure, and metadata
        $hashA = Get-FileHash -Path $zipA -Algorithm $Algorithm
        $hashB = Get-FileHash -Path $zipB -Algorithm $Algorithm
        
        # Compare archive hashes - identical hashes mean identical directory contents
        $areIdentical = ($hashA.Hash -eq $hashB.Hash)
        
        # Format results based on requested detail level
        if ($Detailed) {
            # Get archive sizes for additional information
            $zipASize = (Get-Item $zipA).Length
            $zipBSize = (Get-Item $zipB).Length
            
            # Return comprehensive result object with archive comparison details
            return [PSCustomObject]@{
                Method = "Archive"                    # Comparison method used
                AreIdentical = $areIdentical         # Overall result: true if archives match
                Algorithm = $Algorithm               # Hash algorithm used
                PathA_Hash = $hashA.Hash            # Hash of first directory's archive
                PathB_Hash = $hashB.Hash            # Hash of second directory's archive
                PathA_ArchiveSize = $zipASize       # Size of first archive in bytes
                PathB_ArchiveSize = $zipBSize       # Size of second archive in bytes
                Summary = if ($areIdentical) { "Directories are identical" } else { "Directories differ" }
            }
        }
        else {
            # Return simple boolean result: true if identical, false if different
            return $areIdentical
        }
    }
    catch {
        # Handle any errors during archive creation or hash calculation
        # Common causes: insufficient disk space, permission issues, corrupted files
        Write-Error "Failed to compare directories using archive method: $($_.Exception.Message)"
        
        if ($Detailed) {
            # Return error details in detailed mode
            return [PSCustomObject]@{
                Method = "Archive"
                AreIdentical = $false                # Assume not identical on error
                Error = $_.Exception.Message         # Include error details
                Summary = "Comparison failed"
            }
        }
        else {
            # Return false on any error in simple mode
            return $false
        }
    }
    finally {
        # Always clean up temporary archive files, even if comparison fails
        # Suppress errors if files don't exist or can't be deleted
        Remove-Item $zipA, $zipB -Force -ErrorAction SilentlyContinue
    }
}

#endregion

#region Module Exports

# Export only the main public function
# Helper functions (Compare-DirectoriesDirect, Compare-DirectoriesArchive) remain internal
Export-ModuleMember Compare-Directories

#endregion