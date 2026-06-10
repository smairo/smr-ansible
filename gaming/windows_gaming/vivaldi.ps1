function Get-VivaldiMarker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StateDir
    )

    $markerPath = Join-Path -Path $StateDir -ChildPath 'vivaldi-release.json'

    if (Test-Path -LiteralPath $markerPath) {
        return [pscustomobject]@{
            Path = $markerPath
            Data = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
        }
    }

    return $null
}

function Get-VivaldiDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DownloadPageUrl
    )

    $headers = @{
        'User-Agent' = 'smr-powershell'
    }
    $response = Invoke-WebRequestCompat -Uri $DownloadPageUrl -Headers $headers
    $content = [string]$response.Content
    $matches = [regex]::Matches(
        $content,
        'https://downloads\.vivaldi\.com/stable/Vivaldi\.(?<version>[0-9.]+)\.x64\.exe'
    )

    if ($matches.Count -eq 0) {
        throw "Could not find a Windows x64 Vivaldi installer link on $DownloadPageUrl."
    }

    $url = $matches[0].Value
    $version = $matches[0].Groups['version'].Value

    return [pscustomobject]@{
        Version = $version
        Url = $url
    }
}

function Test-VivaldiInstallerSignature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid') {
        throw "Vivaldi installer signature is not valid: $($signature.Status)"
    }

    $subject = [string]$signature.SignerCertificate.Subject
    if ($subject -notmatch 'Vivaldi Technologies') {
        throw "Vivaldi installer signer is unexpected: $subject"
    }
}

function Get-VivaldiExecutablePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ExecutablePaths
    )

    foreach ($path in $ExecutablePaths) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }

    return $null
}

function Install-Vivaldi {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DownloadPageUrl,

        [Parameter(Mandatory = $true)]
        [string]$StateDir,

        [Parameter(Mandatory = $true)]
        [string[]]$ExecutablePaths
    )

    $download = Get-VivaldiDownload -DownloadPageUrl $DownloadPageUrl
    $marker = Get-VivaldiMarker -StateDir $StateDir
    $markerPath = Join-Path -Path $StateDir -ChildPath 'vivaldi-release.json'
    $existingExecutablePath = Get-VivaldiExecutablePath -ExecutablePaths $ExecutablePaths

    if ($marker) {
        $installedReleaseMatches = (
            ($marker.Data.version -eq $download.Version) -and
            ($marker.Data.download_url -eq $download.Url) -and
            $existingExecutablePath
        )

        if ($installedReleaseMatches) {
            Write-Host "Vivaldi already present: $($download.Version)"
            return
        }
    }

    if (-not $PSCmdlet.ShouldProcess(($ExecutablePaths -join ', '), "Install Vivaldi $($download.Version)")) {
        return
    }

    $headers = @{
        'User-Agent' = 'smr-powershell'
    }

    New-Item -Path $StateDir -ItemType Directory -Force | Out-Null

    $tempRoot = Join-Path -Path $env:TEMP -ChildPath ('vivaldi-' + [guid]::NewGuid().ToString('N'))
    $installerName = [System.IO.Path]::GetFileName(([Uri]$download.Url).AbsolutePath)
    $installerPath = Join-Path -Path $tempRoot -ChildPath $installerName

    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

    try {
        Write-Host "Downloading Vivaldi $($download.Version)."
        Invoke-WebRequestCompat -Uri $download.Url -OutFile $installerPath -Headers $headers | Out-Null
        Unblock-File -LiteralPath $installerPath -ErrorAction SilentlyContinue
        Test-VivaldiInstallerSignature -Path $installerPath

        $installArgs = @(
            '--vivaldi-silent'
            '--do-not-launch-chrome'
            '--system-level'
        )

        Write-Host "Installing Vivaldi $($download.Version)."
        $installOutput = & $installerPath @installArgs 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            throw "Vivaldi installer failed with exit code $exitCode`: $($installOutput | Out-String)"
        }

        $installedExecutablePath = Get-VivaldiExecutablePath -ExecutablePaths $ExecutablePaths
        if (-not $installedExecutablePath) {
            throw "Vivaldi executable was not found after installation. Checked: $($ExecutablePaths -join ', ')"
        }

        @{
            version = $download.Version
            download_url = $download.Url
            installed_at = (Get-Date).ToUniversalTime().ToString('o')
            executable_path = $installedExecutablePath
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding UTF8

        Write-Host "Vivaldi installed: $installedExecutablePath"
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
