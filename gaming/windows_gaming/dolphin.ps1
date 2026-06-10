function Get-DolphinMarker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallDir
    )

    $markerPath = Join-Path -Path $InstallDir -ChildPath '.smr-windows-gaming-dolphin-release.json'

    if (Test-Path -LiteralPath $markerPath) {
        return [pscustomobject]@{
            Path = $markerPath
            Data = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
        }
    }

    return $null
}

function Install-Dolphin {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$DownloadUrl,

        [Parameter(Mandatory = $true)]
        [string]$ArchiveSha256,

        [Parameter(Mandatory = $true)]
        [string]$InstallDir,

        [string]$ArchiveRoot = 'Dolphin-x64'
    )

    $sevenZip = Find-7Zip
    if (-not $sevenZip) {
        throw '7z.exe was not found. The WinGet package 7zip.7zip must install successfully before Dolphin can be extracted.'
    }

    $normalizedInstallDir = Get-NormalizedPath -Path $InstallDir
    if ($normalizedInstallDir -eq (Get-NormalizedPath -Path ([System.IO.Path]::GetPathRoot($InstallDir)))) {
        throw 'Refusing to install Dolphin directly into a drive root.'
    }

    $marker = Get-DolphinMarker -InstallDir $InstallDir
    $markerPath = Join-Path -Path $InstallDir -ChildPath '.smr-windows-gaming-dolphin-release.json'
    $dolphinExePath = Join-Path -Path $InstallDir -ChildPath 'Dolphin.exe'

    if ($marker) {
        $installedReleaseMatches = (
            ($marker.Data.version -eq $Version) -and
            ($marker.Data.download_url -eq $DownloadUrl) -and
            ($marker.Data.archive_sha256 -eq $ArchiveSha256.ToLowerInvariant()) -and
            (Test-Path -LiteralPath $dolphinExePath)
        )

        if ($installedReleaseMatches) {
            Write-Host "Dolphin already present: $Version"
            return
        }
    }

    if (-not $PSCmdlet.ShouldProcess($InstallDir, "Install Dolphin $Version")) {
        return
    }

    $headers = @{
        'User-Agent' = 'smr-powershell'
    }

    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null

    $tempRoot = Join-Path -Path $env:TEMP -ChildPath ('dolphin-' + [guid]::NewGuid().ToString('N'))
    $archiveName = [System.IO.Path]::GetFileName(([Uri]$DownloadUrl).AbsolutePath)
    $archivePath = Join-Path -Path $tempRoot -ChildPath $archiveName
    $extractPath = Join-Path -Path $tempRoot -ChildPath 'extract'
    $backupPath = $null

    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null
    New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

    try {
        Write-Host "Downloading Dolphin $Version."
        Invoke-WebRequestCompat -Uri $DownloadUrl -OutFile $archivePath -Headers $headers | Out-Null
        Unblock-File -LiteralPath $archivePath -ErrorAction SilentlyContinue

        $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $ArchiveSha256.ToLowerInvariant()) {
            throw "Dolphin archive SHA-256 mismatch. Expected $ArchiveSha256, got $actualHash."
        }

        $extractArgs = @(
            'x'
            $archivePath
            "-o$extractPath"
            '-y'
        )

        Write-Host 'Extracting Dolphin with 7-Zip.'
        $extractOutput = & $sevenZip @extractArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "7-Zip failed extracting Dolphin: $($extractOutput | Out-String)"
        }

        $stagedRoot = Join-Path -Path $extractPath -ChildPath $ArchiveRoot
        $stagedDolphinExePath = Join-Path -Path $stagedRoot -ChildPath 'Dolphin.exe'
        if (-not (Test-Path -LiteralPath $stagedDolphinExePath)) {
            throw "Dolphin.exe was not found after extracting $archiveName."
        }

        $existingInstallItems = @(Get-ChildItem -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue)
        if ($existingInstallItems.Count -gt 0) {
            $backupPath = '{0}.backup-{1}' -f $InstallDir.TrimEnd('\'), (Get-Date -Format 'yyyyMMddHHmmss')
            while (Test-Path -LiteralPath $backupPath) {
                $backupPath = '{0}.backup-{1}' -f $InstallDir.TrimEnd('\'), [guid]::NewGuid().ToString('N')
            }

            Write-Host "Backing up existing Dolphin folder to $backupPath."
            Move-Item -LiteralPath $InstallDir -Destination $backupPath
            New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path (Join-Path -Path $stagedRoot -ChildPath '*') -Destination $InstallDir -Recurse -Force

        if (-not (Test-Path -LiteralPath $dolphinExePath)) {
            throw "Dolphin.exe was not found after extracting $archiveName."
        }

        @{
            version = $Version
            download_url = $DownloadUrl
            archive_sha256 = $ArchiveSha256.ToLowerInvariant()
            installed_at = (Get-Date).ToUniversalTime().ToString('o')
            backup_path = $backupPath
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding UTF8

        Write-Host "Dolphin installed: $InstallDir"
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
