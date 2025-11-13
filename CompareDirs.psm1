function Test-DirsMatch {
    param (
        [Parameter(Mandatory)]
        [string]$PathA,

        [Parameter(Mandatory)]
        [string]$PathB,
        
        [ValidateSet("MD5","SHA1","SHA256")][string]$Algorithm = "SHA256"
    )

    $zipA = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, ".zip")
    $zipB = [System.IO.Path]::ChangeExtension((New-TemporaryFile).FullName, ".zip")

    try {
        Compress-Archive -Path "$PathA\*" -DestinationPath $zipA -Force -Verbose
        Compress-Archive -Path "$PathB\*" -DestinationPath $zipB -Force -Verbose

        $hashA = Get-FileHash -Path $zipA -Algorithm $Algorithm
        $hashB = Get-FileHash -Path $zipB -Algorithm $Algorithm

        return ( $hashA.Hash -eq $hashB.Hash )
    }
    finally {
        Remove-Item $zipA, $zipB -Force -ErrorAction SilentlyContinue
    }
}


Function Sync-Dirs() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination
    )   

    # Getting folders and Files
    $srcFolders = Get-ChildItem $source -Recurse -Force -Directory
    $destFolders = Get-ChildItem $destination -Recurse -Force -Directory

    $srcFiles = Get-ChildItem $source -Recurse -Force File
    $destFiles = Get-ChildItem $destination -Recurse -Force -File

    # Checking for Folders that are in Source, but not in Destination
    foreach( $folder in $srcFolders ) {
        $srcFolderPath = $source -replace "\\","\\" -replace "\:","\:"
        $destFolderPath = $folder.Fullname -replace $srcFolderPath,$destination
        if( -not ( test-path $destFolderPath )) {
            Write-Host "Folder $destFolderPath Missing."
        }
    }

    # Checking for Folders that are in Destinatino, but not in Source
    foreach( $folder in $destFolders ) {
        $destFolderPath = $destination -replace "\\","\\" -replace "\:","\:"
        $srcFolderPath = $folder.Fullname -replace $destFolderPath,$source
        if( -not ( test-path $srcFolderPath )) {
            Write-Host "Folder $srcFolderPath Missing."
        }
    }

    # Checking for Files that are in the Source, but not in Destination
    foreach( $entry in $srcFiles ) {
        $srcFullName = $entry.fullname
        $srcFilePath = $source -replace "\\","\\" -replace "\:","\:"
        $destFullName = $srcFullName -replace $srcFilePath,$destination
        if( test-Path $destFullName ) {
            $srcMD5 = Get-FileHash $srcFullName -Algorithm MD5
            $destMD5 = Get-FileHash $destFullName -Algorithm MD5
            If( Compare-Object $srcMD5 $destMD5 ) {
                Write-Host "The Files MD5's are Different... Checking Write
                Dates"
                Write-Host $srcMD5
                Write-Host $destMD5
            }
        }
        else {
            Write-Host "$destFullName Missing."
        }
    }

    # Checking for Files that are in the Destinatino, but not in Source
    foreach($entry in $destFiles)
    {
        $destFullName = $entry.fullname
        $destFilePath = $destination -replace "\\","\\" -replace "\:","\:"
        $srcFullName = $destFullName -replace $destFilePath,$source
        if( -not ( test-Path $srcFullName ))
        {
            Write-Host "$srcFullName Missing."
        }
    }
}

Export-ModuleMember Test-DirsMatch, Sync-Dirs