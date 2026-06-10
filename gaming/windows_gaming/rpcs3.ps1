function Get-RPCS3Marker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallDir
    )

    $markerPath = Join-Path -Path $InstallDir -ChildPath '.smr-windows-gaming-rpcs3-release.json'

    if (Test-Path -LiteralPath $markerPath) {
        return [pscustomobject]@{
            Path = $markerPath
            Data = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
        }
    }

    return $null
}

function Install-RPCS3 {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReleaseApiUrl,

        [Parameter(Mandatory = $true)]
        [string]$InstallDir
    )

    $sevenZip = Find-7Zip
    if (-not $sevenZip) {
        throw '7z.exe was not found. The WinGet package 7zip.7zip must install successfully before RPCS3 can be extracted.'
    }

    $normalizedInstallDir = Get-NormalizedPath -Path $InstallDir
    if ($normalizedInstallDir -eq (Get-NormalizedPath -Path ([System.IO.Path]::GetPathRoot($InstallDir)))) {
        throw 'Refusing to install RPCS3 directly into a drive root.'
    }

    $headers = @{
        'User-Agent' = 'smr-powershell'
        'Accept' = 'application/vnd.github+json'
    }

    $release = Invoke-RestMethodCompat -Uri $ReleaseApiUrl -Headers $headers
    $asset = $release.assets |
        Where-Object { $_.name -like '*_win64_msvc.7z' -and $_.name -notlike '*.sha256' } |
        Select-Object -First 1

    if (-not $asset) {
        throw "RPCS3 Windows archive was not found in the latest GitHub release: $($release.html_url)"
    }

    $assetDigest = [string]$asset.digest
    if (-not $assetDigest -or -not $assetDigest.StartsWith('sha256:', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "RPCS3 release asset does not include a SHA-256 digest: $($asset.name)"
    }

    $expectedHash = $assetDigest.Substring('sha256:'.Length).ToLowerInvariant()
    $marker = Get-RPCS3Marker -InstallDir $InstallDir
    $markerPath = Join-Path -Path $InstallDir -ChildPath '.smr-windows-gaming-rpcs3-release.json'
    $rpcs3ExePath = Join-Path -Path $InstallDir -ChildPath 'rpcs3.exe'

    if ($marker) {
        $installedReleaseMatches = (
            ($marker.Data.tag_name -eq $release.tag_name) -and
            ($marker.Data.asset_name -eq $asset.name) -and
            ($marker.Data.asset_sha256 -eq $expectedHash) -and
            (Test-Path -LiteralPath $rpcs3ExePath)
        )

        if ($installedReleaseMatches) {
            Write-Host "RPCS3 already present: $($release.name)"
            return
        }
    }

    if (-not $PSCmdlet.ShouldProcess($InstallDir, "Install RPCS3 $($release.name)")) {
        return
    }

    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null

    $tempRoot = Join-Path -Path $env:TEMP -ChildPath ('rpcs3-' + [guid]::NewGuid().ToString('N'))
    $archivePath = Join-Path -Path $tempRoot -ChildPath $asset.name
    $extractPath = Join-Path -Path $tempRoot -ChildPath 'extract'
    $backupPath = $null

    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null
    New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

    try {
        Write-Host "Downloading RPCS3 $($release.name)."
        Invoke-WebRequestCompat -Uri $asset.browser_download_url -OutFile $archivePath -Headers $headers | Out-Null
        Unblock-File -LiteralPath $archivePath -ErrorAction SilentlyContinue

        $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            throw "RPCS3 archive SHA-256 mismatch. Expected $expectedHash, got $actualHash."
        }

        $extractArgs = @(
            'x'
            $archivePath
            "-o$extractPath"
            '-y'
        )

        Write-Host 'Extracting RPCS3 with 7-Zip.'
        $extractOutput = & $sevenZip @extractArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "7-Zip failed extracting RPCS3: $($extractOutput | Out-String)"
        }

        $stagedRpcs3ExePath = Join-Path -Path $extractPath -ChildPath 'rpcs3.exe'
        if (-not (Test-Path -LiteralPath $stagedRpcs3ExePath)) {
            throw "rpcs3.exe was not found after extracting $($asset.name)."
        }

        $existingInstallItems = @(Get-ChildItem -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue)
        if ($existingInstallItems.Count -gt 0) {
            $backupPath = '{0}.backup-{1}' -f $InstallDir.TrimEnd('\'), (Get-Date -Format 'yyyyMMddHHmmss')
            while (Test-Path -LiteralPath $backupPath) {
                $backupPath = '{0}.backup-{1}' -f $InstallDir.TrimEnd('\'), [guid]::NewGuid().ToString('N')
            }

            Write-Host "Backing up existing RPCS3 folder to $backupPath."
            Move-Item -LiteralPath $InstallDir -Destination $backupPath
            New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path (Join-Path -Path $extractPath -ChildPath '*') -Destination $InstallDir -Recurse -Force

        if (-not (Test-Path -LiteralPath $rpcs3ExePath)) {
            throw "rpcs3.exe was not found after extracting $($asset.name)."
        }

        @{
            tag_name = $release.tag_name
            release_name = $release.name
            asset_name = $asset.name
            asset_sha256 = $expectedHash
            release = $release.html_url
            installed_at = (Get-Date).ToUniversalTime().ToString('o')
            backup_path = $backupPath
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding UTF8

        Write-Host "RPCS3 installed: $InstallDir"
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
