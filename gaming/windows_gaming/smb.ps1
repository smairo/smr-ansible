function Join-SmbRemotePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$Folder
    )

    if ([string]::IsNullOrWhiteSpace($BasePath)) {
        throw 'SMB base path cannot be empty.'
    }

    if ([string]::IsNullOrWhiteSpace($Folder)) {
        throw 'SMB folder cannot be empty.'
    }

    $cleanBasePath = $BasePath.Trim().TrimEnd('\')
    if (-not $cleanBasePath.StartsWith('\\', [System.StringComparison]::Ordinal)) {
        throw "SMB base path must be a UNC path such as \\192.168.1.64."
    }

    $cleanFolder = $Folder.Trim()
    if ($cleanFolder.StartsWith('\\', [System.StringComparison]::Ordinal)) {
        return $cleanFolder.TrimEnd('\')
    }

    $cleanFolder = $cleanFolder.Trim('\', '/') -replace '/', '\'
    if ([string]::IsNullOrWhiteSpace($cleanFolder)) {
        throw 'SMB folder cannot be empty.'
    }

    return "$cleanBasePath\$cleanFolder"
}

function Get-NormalizedSmbRemotePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RemotePath
    )

    return $RemotePath.Trim().TrimEnd('\').ToLowerInvariant()
}

function Get-NormalizedSmbDriveLetter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter
    )

    $normalizedDriveLetter = $DriveLetter.Trim().TrimEnd(':').ToUpperInvariant()
    if ($normalizedDriveLetter -notmatch '^[A-Z]$') {
        throw "SMB drive letter must be a single letter from A to Z: $DriveLetter"
    }

    return $normalizedDriveLetter
}

function Get-SmbDriveMappingCommands {
    [CmdletBinding()]
    param()

    $getSmbMapping = Get-Command Get-SmbMapping -ErrorAction SilentlyContinue
    $newSmbMapping = Get-Command New-SmbMapping -ErrorAction SilentlyContinue

    if (-not $getSmbMapping -or -not $newSmbMapping) {
        throw 'Get-SmbMapping and New-SmbMapping were not found. Run this setup on Windows with the SMB client PowerShell cmdlets available.'
    }

    return [pscustomobject]@{
        Get = $getSmbMapping.Source
        New = $newSmbMapping.Source
    }
}

function Get-AvailableSmbDriveLetter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$UsedDriveLetters
    )

    for ($letterCode = [int][char]'Z'; $letterCode -ge [int][char]'D'; $letterCode--) {
        $letter = [char]$letterCode
        $letterText = $letter.ToString()
        if (-not $UsedDriveLetters.ContainsKey($letterText)) {
            return $letterText
        }
    }

    throw 'No free drive letters were available for SMB mappings.'
}

function Resolve-SmbDriveMappings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Folders,

        [string[]]$DriveLetters
    )

    if (-not $Folders -or $Folders.Count -eq 0) {
        return @()
    }

    $normalizedDriveLetters = @()
    if ($DriveLetters -and $DriveLetters.Count -gt 0) {
        if ($DriveLetters.Count -ne $Folders.Count) {
            throw 'The number of SMB drive letters must match the number of SMB folders.'
        }

        foreach ($driveLetter in $DriveLetters) {
            $normalizedDriveLetters += Get-NormalizedSmbDriveLetter -DriveLetter $driveLetter
        }
    }

    $existingMappings = @(Get-SmbMapping -ErrorAction SilentlyContinue)
    $usedDriveLetters = @{}

    foreach ($drive in @(Get-PSDrive -PSProvider FileSystem)) {
        if ($drive.Name) {
            $usedDriveLetters[$drive.Name.ToUpperInvariant()] = $true
        }
    }

    foreach ($mapping in $existingMappings) {
        if ($mapping.LocalPath) {
            $usedDriveLetters[(Get-NormalizedSmbDriveLetter -DriveLetter $mapping.LocalPath)] = $true
        }
    }

    $resolvedMappings = [System.Collections.Generic.List[object]]::new()
    $seenRemotePaths = @{}
    $seenDriveLetters = @{}

    for ($index = 0; $index -lt $Folders.Count; $index++) {
        $remotePath = Join-SmbRemotePath -BasePath $BasePath -Folder $Folders[$index]
        $normalizedRemotePath = Get-NormalizedSmbRemotePath -RemotePath $remotePath
        if ($seenRemotePaths.ContainsKey($normalizedRemotePath)) {
            throw "Duplicate SMB remote path configured: $remotePath"
        }
        $seenRemotePaths[$normalizedRemotePath] = $true

        $requestedDriveLetter = $null
        if ($normalizedDriveLetters.Count -gt 0) {
            $requestedDriveLetter = $normalizedDriveLetters[$index]
            if ($seenDriveLetters.ContainsKey($requestedDriveLetter)) {
                throw "Duplicate SMB drive letter configured: $requestedDriveLetter`:"
            }
        }

        $existingRemoteMapping = $existingMappings |
            Where-Object {
                $_.RemotePath -and
                ((Get-NormalizedSmbRemotePath -RemotePath $_.RemotePath) -eq $normalizedRemotePath) -and
                $_.LocalPath
            } |
            Select-Object -First 1

        if ($existingRemoteMapping) {
            $existingDriveLetter = Get-NormalizedSmbDriveLetter -DriveLetter $existingRemoteMapping.LocalPath
            if ($requestedDriveLetter -and $requestedDriveLetter -ne $existingDriveLetter) {
                throw "SMB path $remotePath is already mapped to $existingDriveLetter`: but $requestedDriveLetter`: was requested."
            }

            $seenDriveLetters[$existingDriveLetter] = $true
            $resolvedMappings.Add([pscustomobject]@{
                DriveLetter = $existingDriveLetter
                LocalPath = "${existingDriveLetter}:"
                RemotePath = $remotePath
                Present = $true
            })
            continue
        }

        if (-not $requestedDriveLetter) {
            $requestedDriveLetter = Get-AvailableSmbDriveLetter -UsedDriveLetters $usedDriveLetters
        }

        $requestedLocalPath = "${requestedDriveLetter}:"
        $existingLocalMapping = $existingMappings |
            Where-Object {
                $_.LocalPath -and
                ((Get-NormalizedSmbDriveLetter -DriveLetter $_.LocalPath) -eq $requestedDriveLetter)
            } |
            Select-Object -First 1

        if ($existingLocalMapping) {
            throw "Drive $requestedLocalPath is already mapped to $($existingLocalMapping.RemotePath)."
        }

        if ($usedDriveLetters.ContainsKey($requestedDriveLetter)) {
            throw "Drive $requestedLocalPath is already in use."
        }

        $usedDriveLetters[$requestedDriveLetter] = $true
        $seenDriveLetters[$requestedDriveLetter] = $true
        $resolvedMappings.Add([pscustomobject]@{
            DriveLetter = $requestedDriveLetter
            LocalPath = $requestedLocalPath
            RemotePath = $remotePath
            Present = $false
        })
    }

    return [object[]]$resolvedMappings
}

function Mount-SmbFolders {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [string[]]$Folders,

        [string]$User,

        [string]$Password,

        [string[]]$DriveLetters,

        [bool]$Persistent = $true
    )

    if (-not $Folders -or $Folders.Count -eq 0) {
        Write-Host 'No SMB folders configured.'
        return
    }

    if (($User -and -not $Password) -or ($Password -and -not $User)) {
        throw 'SMB user and password must be supplied together.'
    }

    Get-SmbDriveMappingCommands | Out-Null
    $mappings = Resolve-SmbDriveMappings `
        -BasePath $BasePath `
        -Folders $Folders `
        -DriveLetters $DriveLetters

    foreach ($mapping in $mappings) {
        if ($mapping.Present) {
            Write-Host "Present: $($mapping.LocalPath) -> $($mapping.RemotePath)"
            continue
        }

        $action = 'Create SMB drive mapping'
        if ($Persistent) {
            $action = 'Create persistent SMB drive mapping'
        }

        if (-not $PSCmdlet.ShouldProcess("$($mapping.LocalPath) -> $($mapping.RemotePath)", $action)) {
            continue
        }

        $mappingParams = @{
            LocalPath = $mapping.LocalPath
            RemotePath = $mapping.RemotePath
            Persistent = $Persistent
            ErrorAction = 'Stop'
        }

        if ($User) {
            $mappingParams.UserName = $User
            $mappingParams.Password = $Password
        }

        New-SmbMapping @mappingParams | Out-Null
        Write-Host "Mapped: $($mapping.LocalPath) -> $($mapping.RemotePath)"
    }
}
