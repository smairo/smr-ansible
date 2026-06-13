#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param()

$ErrorActionPreference = 'Stop'

function Invoke-WindowsDevBootstrapDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$OutFile
    )

    $requestParams = @{
        Uri = $Uri
        OutFile = $OutFile
    }

    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        $requestParams.UseBasicParsing = $true
    }

    Invoke-WebRequest @requestParams
}

function Resolve-WindowsDevWinGetScript {
    [CmdletBinding()]
    param(
        [string]$ScriptRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($ScriptRoot)) {
        $localSharedPath = Join-Path -Path $ScriptRoot -ChildPath 'windows\winget.ps1'
        if (Test-Path -LiteralPath $localSharedPath -PathType Leaf) {
            return $localSharedPath
        }
    }

    $sourceBaseUrl = $env:SMR_WINDOWS_SHARED_SOURCE_BASE_URL
    if ([string]::IsNullOrWhiteSpace($sourceBaseUrl)) {
        $sourceBaseUrl = 'https://raw.githubusercontent.com/smairo/smr-ansible/main/workstations/windows'
    }

    $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('smr-windows-dev-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

    $sharedPath = Join-Path -Path $tempRoot -ChildPath 'winget.ps1'
    Invoke-WindowsDevBootstrapDownload -Uri ($sourceBaseUrl.TrimEnd('/') + '/winget.ps1') -OutFile $sharedPath

    return $sharedPath
}

function Assert-Windows {
    [CmdletBinding()]
    param()

    if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
        throw 'This setup must be run on Windows.'
    }
}

function Assert-Administrator {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this script from an elevated PowerShell session.'
    }
}

function Write-Section {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ''
    Write-Host "== $Message =="
}

function Enable-WindowsDevOptionalFeature {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName
    if ($feature.State -eq 'Enabled') {
        Write-Host "Present: $DisplayName ($FeatureName)"
        return $false
    }

    if (-not $PSCmdlet.ShouldProcess("$DisplayName ($FeatureName)", 'Enable Windows optional feature')) {
        return $false
    }

    Write-Host "Enabling: $DisplayName ($FeatureName)"
    Enable-WindowsOptionalFeature `
        -Online `
        -FeatureName $FeatureName `
        -All `
        -NoRestart | Out-Null

    Write-Host "Enabled: $DisplayName ($FeatureName)"
    return $true
}

function Get-WindowsDevWslDistributions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WslPath
    )

    $output = & $WslPath --list --quiet 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Warning "Could not list installed WSL distributions. Exit code $exitCode`: $($output | Out-String)"
        return @()
    }

    return @(
        $output |
            ForEach-Object { [string]$_ } |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Enable-WindowsDevWsl {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $enabledAnyFeature = $false
    $features = @(
        [pscustomobject]@{
            Name = 'Microsoft-Windows-Subsystem-Linux'
            DisplayName = 'Windows Subsystem for Linux'
        }
        [pscustomobject]@{
            Name = 'VirtualMachinePlatform'
            DisplayName = 'Virtual Machine Platform'
        }
    )

    foreach ($feature in $features) {
        $enabled = Enable-WindowsDevOptionalFeature `
            -FeatureName $feature.Name `
            -DisplayName $feature.DisplayName

        $enabledAnyFeature = $enabledAnyFeature -or $enabled
    }

    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wsl) {
        Write-Warning 'wsl.exe was not found after enabling WSL features. Reboot Windows and run this setup again if WSL is unavailable.'
        return
    }

    if ($enabledAnyFeature) {
        Write-Warning 'WSL Windows features were enabled. Reboot Windows, then run this setup again to finish the WSL distro installation.'
        return
    }

    if ($PSCmdlet.ShouldProcess('WSL', 'Set default version to 2')) {
        Write-Host 'Setting WSL default version to 2.'
        $output = & $wsl.Source --set-default-version 2 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            Write-Warning "Could not set WSL default version to 2. Exit code $exitCode`: $($output | Out-String)"
        }
    }

    $distributions = Get-WindowsDevWslDistributions -WslPath $wsl.Source
    if ($distributions.Count -gt 0) {
        Write-Host "Present: WSL distribution(s): $($distributions -join ', ')"
        return
    }

    if ($PSCmdlet.ShouldProcess('Ubuntu', 'Install default WSL distribution')) {
        Write-Host 'Installing Ubuntu for WSL.'
        $output = & $wsl.Source --install --distribution Ubuntu --no-launch 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            Write-Warning "Could not install the Ubuntu WSL distribution. Exit code $exitCode`: $($output | Out-String)"
            return
        }

        Write-Host 'Installed Ubuntu for WSL.'
        Write-Warning 'Launch Ubuntu once to complete the first-run Linux user setup.'
    }
}

function Get-WindowsDevWinGetPackages {
    [CmdletBinding()]
    param()

    return @(
        [pscustomobject]@{ Name = 'JetBrains Toolbox'; Id = 'JetBrains.Toolbox' }
        [pscustomobject]@{ Name = 'Visual Studio Code'; Id = 'Microsoft.VisualStudioCode' }
        [pscustomobject]@{ Name = 'Visual Studio Professional 2026'; Id = 'Microsoft.VisualStudio.Professional' }
        [pscustomobject]@{ Name = 'SQL Server Management Studio 21'; Id = 'Microsoft.SQLServerManagementStudio.21' }
        [pscustomobject]@{ Name = 'Kate'; Id = 'KDE.Kate' }
        [pscustomobject]@{ Name = 'Power BI Desktop'; Id = 'Microsoft.PowerBI' }
        [pscustomobject]@{ Name = '.NET SDK 8'; Id = 'Microsoft.DotNet.SDK.8' }
        [pscustomobject]@{ Name = '.NET SDK 9'; Id = 'Microsoft.DotNet.SDK.9' }
        [pscustomobject]@{ Name = '.NET SDK 10'; Id = 'Microsoft.DotNet.SDK.10' }
        [pscustomobject]@{ Name = 'Microsoft OpenJDK 21'; Id = 'Microsoft.OpenJDK.21' }
        [pscustomobject]@{ Name = 'Azure CLI'; Id = 'Microsoft.AzureCLI' }
        [pscustomobject]@{ Name = 'Azure VPN Client'; Id = '9NP355QT2SQB'; Source = 'msstore' }
        [pscustomobject]@{ Name = 'Kubernetes kubectl'; Id = 'Kubernetes.kubectl' }
        [pscustomobject]@{ Name = 'Helm'; Id = 'Helm.Helm' }
        [pscustomobject]@{ Name = 'Podman'; Id = 'RedHat.Podman' }
        [pscustomobject]@{ Name = 'Podman Desktop'; Id = 'RedHat.Podman-Desktop' }
        [pscustomobject]@{ Name = 'Slack'; Id = 'SlackTechnologies.Slack' }
        [pscustomobject]@{ Name = 'Spotify'; Id = 'Spotify.Spotify' }
        [pscustomobject]@{ Name = 'Vivaldi'; Id = 'Vivaldi.Vivaldi' }
        [pscustomobject]@{ Name = 'Microsoft Edge'; Id = 'Microsoft.Edge' }
        [pscustomobject]@{ Name = 'Google Chrome'; Id = 'Google.Chrome' }
        [pscustomobject]@{ Name = 'Mozilla Firefox'; Id = 'Mozilla.Firefox' }
        [pscustomobject]@{ Name = 'Node.js'; Id = 'OpenJS.NodeJS' }
        [pscustomobject]@{ Name = 'Bun'; Id = 'Oven-sh.Bun' }
        [pscustomobject]@{ Name = 'Git'; Id = 'Git.Git' }
    )
}

Assert-Windows
Assert-Administrator

$wingetScript = Resolve-WindowsDevWinGetScript -ScriptRoot $PSScriptRoot
. $wingetScript

Write-Section 'Enabling WSL'
Enable-WindowsDevWsl

Write-Section 'Installing Windows development WinGet packages'
Install-WinGetPackages `
    -Packages (Get-WindowsDevWinGetPackages)

Write-Host 'Windows development setup finished.'
