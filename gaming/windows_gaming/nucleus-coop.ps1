function Find-7Zip {
    [CmdletBinding()]
    param()

    $command = Get-Command 7z.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $paths = [System.Collections.Generic.List[string]]::new()

    if ($env:ProgramFiles) {
        $paths.Add((Join-Path -Path $env:ProgramFiles -ChildPath '7-Zip\7z.exe'))
    }

    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($programFilesX86) {
        $paths.Add((Join-Path -Path $programFilesX86 -ChildPath '7-Zip\7z.exe'))
    }

    foreach ($path in $paths) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }

    return $null
}

function Test-DefenderPathExclusion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $getMpPreference = Get-Command Get-MpPreference -ErrorAction SilentlyContinue
    $addMpPreference = Get-Command Add-MpPreference -ErrorAction SilentlyContinue

    if (-not $getMpPreference -or -not $addMpPreference) {
        throw 'Microsoft Defender PowerShell cmdlets were not found; cannot manage the Nucleus Co-op folder exclusion.'
    }

    $targetPath = Get-NormalizedPath -Path $Path
    $existingPaths = @((Get-MpPreference).ExclusionPath) | ForEach-Object {
        if ($_) {
            Get-NormalizedPath -Path $_
        }
    }

    return ($existingPaths -contains $targetPath)
}

function Ensure-DefenderPathExclusion {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-DefenderPathExclusion -Path $Path) {
        Write-Host "Microsoft Defender exclusion already present: $Path"
        return
    }

    if (-not $PSCmdlet.ShouldProcess($Path, 'Add Microsoft Defender path exclusion')) {
        return
    }

    Add-MpPreference -ExclusionPath $Path
    Write-Host "Added Microsoft Defender exclusion: $Path"
}

function Invoke-WebRequestCompat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [hashtable]$Headers,

        [string]$OutFile
    )

    $requestParams = @{
        Uri = $Uri
    }

    if ($Headers) {
        $requestParams.Headers = $Headers
    }

    if ($OutFile) {
        $requestParams.OutFile = $OutFile
    }

    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        $requestParams.UseBasicParsing = $true
    }

    Invoke-WebRequest @requestParams
}

function Invoke-RestMethodCompat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [hashtable]$Headers
    )

    $requestParams = @{
        Uri = $Uri
    }

    if ($Headers) {
        $requestParams.Headers = $Headers
    }

    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        $requestParams.UseBasicParsing = $true
    }

    Invoke-RestMethod @requestParams
}

function Get-NucleusMarker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallDir
    )

    $markerPaths = @(
        (Join-Path -Path $InstallDir -ChildPath '.smr-windows-gaming-nucleus-release.json')
        (Join-Path -Path $InstallDir -ChildPath '.smr-ansible-nucleus-release.json')
    )

    foreach ($markerPath in $markerPaths) {
        if (Test-Path -LiteralPath $markerPath) {
            return [pscustomobject]@{
                Path = $markerPath
                Data = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
            }
        }
    }

    return $null
}

function Install-NucleusCoop {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReleaseApiUrl,

        [Parameter(Mandatory = $true)]
        [string]$InstallDir,

        [Parameter(Mandatory = $true)]
        [string]$ArchivePassword,

        [bool]$AddDefenderExclusion = $true
    )

    $sevenZip = Find-7Zip
    if (-not $sevenZip) {
        throw '7z.exe was not found. The WinGet package 7zip.7zip must install successfully before Nucleus Co-op can be extracted.'
    }

    $normalizedInstallDir = Get-NormalizedPath -Path $InstallDir
    $programFiles = Get-NormalizedPath -Path $env:ProgramFiles
    $programFilesX86Value = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $programFilesX86 = $null
    if ($programFilesX86Value) {
        $programFilesX86 = Get-NormalizedPath -Path $programFilesX86Value
    }

    if ($normalizedInstallDir -eq (Get-NormalizedPath -Path ([System.IO.Path]::GetPathRoot($InstallDir)))) {
        throw 'Refusing to install Nucleus Co-op directly into a drive root.'
    }

    if (
        $normalizedInstallDir -eq $programFiles -or
        $normalizedInstallDir.StartsWith("$programFiles\") -or
        ($programFilesX86 -and ($normalizedInstallDir -eq $programFilesX86 -or $normalizedInstallDir.StartsWith("$programFilesX86\")))
    ) {
        throw 'Refusing to install Nucleus Co-op into Program Files.'
    }

    $headers = @{
        'User-Agent' = 'smr-powershell'
        'Accept' = 'application/vnd.github+json'
    }

    $release = Invoke-RestMethodCompat -Uri $ReleaseApiUrl -Headers $headers
    $asset = $release.assets | Where-Object { $_.name -eq 'NucleusApp.zip' } | Select-Object -First 1

    if (-not $asset) {
        throw "NucleusApp.zip was not found in the latest Nucleus Co-op GitHub release: $($release.html_url)"
    }

    $marker = Get-NucleusMarker -InstallDir $InstallDir
    $markerPath = Join-Path -Path $InstallDir -ChildPath '.smr-windows-gaming-nucleus-release.json'
    $nucleusExePath = Join-Path -Path $InstallDir -ChildPath 'NucleusCoop.exe'

    if ($marker) {
        $installedReleaseMatches = (
            ($marker.Data.tag_name -eq $release.tag_name) -and
            ($marker.Data.asset_name -eq $asset.name) -and
            (Test-Path -LiteralPath $nucleusExePath)
        )

        if ($installedReleaseMatches) {
            Write-Host "Nucleus Co-op already present: $($release.tag_name)"

            if ($AddDefenderExclusion) {
                New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
                Ensure-DefenderPathExclusion -Path $InstallDir
            }

            if ($marker.Path -ne $markerPath -and $PSCmdlet.ShouldProcess($markerPath, 'Write native setup marker')) {
                $marker.Data | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding UTF8
            }

            return
        }
    }

    if (-not $PSCmdlet.ShouldProcess($InstallDir, "Install Nucleus Co-op $($release.tag_name)")) {
        return
    }

    New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null

    if ($AddDefenderExclusion) {
        Ensure-DefenderPathExclusion -Path $InstallDir
    }

    $tempRoot = Join-Path -Path $env:TEMP -ChildPath ('nucleus-coop-' + [guid]::NewGuid().ToString('N'))
    $archivePath = Join-Path -Path $tempRoot -ChildPath $asset.name
    $extractPath = Join-Path -Path $tempRoot -ChildPath 'extract'
    $backupPath = $null

    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null
    New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

    try {
        Write-Host "Downloading Nucleus Co-op $($release.tag_name)."
        Invoke-WebRequestCompat -Uri $asset.browser_download_url -OutFile $archivePath -Headers $headers | Out-Null
        Unblock-File -LiteralPath $archivePath -ErrorAction SilentlyContinue

        $assetDigest = [string]$asset.digest
        if ($assetDigest -and $assetDigest.StartsWith('sha256:', [System.StringComparison]::OrdinalIgnoreCase)) {
            $expectedHash = $assetDigest.Substring('sha256:'.Length)
            $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()

            if ($actualHash -ne $expectedHash.ToLowerInvariant()) {
                throw "Nucleus Co-op archive SHA-256 mismatch. Expected $expectedHash, got $actualHash."
            }
        }

        $extractArgs = @(
            'x'
            $archivePath
            "-o$extractPath"
            "-p$ArchivePassword"
            '-y'
        )

        Write-Host 'Extracting Nucleus Co-op with 7-Zip.'
        $extractOutput = & $sevenZip @extractArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "7-Zip failed extracting Nucleus Co-op: $($extractOutput | Out-String)"
        }

        $stagedNucleusExePath = Join-Path -Path $extractPath -ChildPath 'NucleusCoop.exe'
        if (-not (Test-Path -LiteralPath $stagedNucleusExePath)) {
            throw "NucleusCoop.exe was not found after extracting $($asset.name)."
        }

        $existingInstallItems = @(Get-ChildItem -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue)
        if ($existingInstallItems.Count -gt 0) {
            $backupPath = '{0}.backup-{1}' -f $InstallDir.TrimEnd('\'), (Get-Date -Format 'yyyyMMddHHmmss')
            while (Test-Path -LiteralPath $backupPath) {
                $backupPath = '{0}.backup-{1}' -f $InstallDir.TrimEnd('\'), [guid]::NewGuid().ToString('N')
            }

            Write-Host "Backing up existing Nucleus Co-op folder to $backupPath."
            Move-Item -LiteralPath $InstallDir -Destination $backupPath
            New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path (Join-Path -Path $extractPath -ChildPath '*') -Destination $InstallDir -Recurse -Force

        if (-not (Test-Path -LiteralPath $nucleusExePath)) {
            throw "NucleusCoop.exe was not found after extracting $($asset.name)."
        }

        @{
            tag_name = $release.tag_name
            asset_name = $asset.name
            asset_digest = $asset.digest
            release = $release.html_url
            installed_at = (Get-Date).ToUniversalTime().ToString('o')
            defender_exclusion = $AddDefenderExclusion
            backup_path = $backupPath
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding UTF8

        Write-Host "Nucleus Co-op installed: $InstallDir"
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
