#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    [switch]$AllowManualReviewPackages,
    [switch]$SkipDefenderExclusion,
    [switch]$FailOnWinGetPackageError,
    [switch]$FailOnChocolateyPackageError,
    [string]$DolphinInstallDir,
    [string]$NucleusInstallDir,
    [string]$SmbBasePath,
    [string[]]$SmbFolders,
    [string]$SmbUser,
    [string]$SmbPassword,
    [string[]]$SmbDriveLetters,
    [switch]$SmbOnly,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'

$moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath 'windows_gaming'

. (Join-Path -Path $moduleRoot -ChildPath 'common.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'config.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'winget.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'chocolatey.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'dolphin.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'rpcs3.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'vivaldi.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'nucleus-coop.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'smb.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'manual-review.ps1')

Assert-Windows

$argumentOverrides = ConvertFrom-WindowsGamingRemainingArguments -Arguments $RemainingArgs

if ($argumentOverrides.ContainsKey('SmbOnly')) {
    $SmbOnly = [bool]$argumentOverrides.SmbOnly
}

if (-not $SmbOnly) {
    Assert-Administrator
}

$config = Get-WindowsGamingConfig

if ($argumentOverrides.ContainsKey('SmbBasePath')) {
    $SmbBasePath = [string]$argumentOverrides.SmbBasePath
}

if ($argumentOverrides.ContainsKey('SmbFolders')) {
    if ($SmbFolders) {
        $SmbFolders = @($SmbFolders) + @($argumentOverrides.SmbFolders)
    }
    else {
        $SmbFolders = @($argumentOverrides.SmbFolders)
    }
}

if ($argumentOverrides.ContainsKey('SmbUser')) {
    $SmbUser = [string]$argumentOverrides.SmbUser
}

if ($argumentOverrides.ContainsKey('SmbPassword')) {
    $SmbPassword = [string]$argumentOverrides.SmbPassword
}

if ($argumentOverrides.ContainsKey('SmbDriveLetters')) {
    if ($SmbDriveLetters) {
        $SmbDriveLetters = @($SmbDriveLetters) + @($argumentOverrides.SmbDriveLetters)
    }
    else {
        $SmbDriveLetters = @($argumentOverrides.SmbDriveLetters)
    }
}

if ($argumentOverrides.ContainsKey('UnboundArguments')) {
    if ($SmbFolders) {
        $SmbFolders = @($SmbFolders) + @($argumentOverrides.UnboundArguments)
    }
    elseif ($SmbDriveLetters) {
        $SmbDriveLetters = @($SmbDriveLetters) + @($argumentOverrides.UnboundArguments)
    }
    else {
        throw "Unexpected argument(s): $($argumentOverrides.UnboundArguments -join ', ')"
    }
}

if ($PSBoundParameters.ContainsKey('NucleusInstallDir')) {
    $config.NucleusCoop.InstallDir = $NucleusInstallDir
}

if ($PSBoundParameters.ContainsKey('DolphinInstallDir')) {
    $config.Dolphin.InstallDir = $DolphinInstallDir
}

if ($SkipDefenderExclusion) {
    $config.NucleusCoop.AddDefenderExclusion = $false
}

if ($PSBoundParameters.ContainsKey('SmbBasePath') -or $argumentOverrides.ContainsKey('SmbBasePath')) {
    $config.SmbMappings.BasePath = $SmbBasePath
}

if ($SmbFolders) {
    $config.SmbMappings.Folders = @($SmbFolders)
}

if ($PSBoundParameters.ContainsKey('SmbUser') -or $argumentOverrides.ContainsKey('SmbUser')) {
    $config.SmbMappings.User = $SmbUser
}

if ($PSBoundParameters.ContainsKey('SmbPassword') -or $argumentOverrides.ContainsKey('SmbPassword')) {
    $config.SmbMappings.Password = $SmbPassword
}

if ($SmbDriveLetters) {
    $config.SmbMappings.DriveLetters = @($SmbDriveLetters)
}

if ($SmbOnly) {
    if (-not $config.SmbMappings.Folders -or $config.SmbMappings.Folders.Count -eq 0) {
        throw 'SmbOnly requires at least one SMB folder. Use -SmbFolders or --smb-folders.'
    }

    Write-Section 'Mounting SMB drives'
    $smbParams = @{}
    foreach ($key in $config.SmbMappings.Keys) {
        $smbParams[$key] = $config.SmbMappings[$key]
    }
    Mount-SmbFolders @smbParams

    Write-Host 'Windows gaming SMB setup finished.'
    return
}

Write-Section 'Installing WinGet packages'
Install-WinGetPackages `
    -Packages $config.WinGetPackages `
    -FailOnError:$FailOnWinGetPackageError.IsPresent

Write-Section 'Installing Chocolatey packages'
Install-ChocolateyPackages `
    -Packages $config.ChocolateyPackages `
    -FailOnError:$FailOnChocolateyPackageError.IsPresent

Write-Section 'Installing Dolphin'
$dolphinParams = @{}
foreach ($key in $config.Dolphin.Keys) {
    $dolphinParams[$key] = $config.Dolphin[$key]
}
Install-Dolphin @dolphinParams

Write-Section 'Installing RPCS3'
$rpcs3Params = @{}
foreach ($key in $config.RPCS3.Keys) {
    $rpcs3Params[$key] = $config.RPCS3[$key]
}
Install-RPCS3 @rpcs3Params

Write-Section 'Installing Vivaldi'
$vivaldiParams = @{}
foreach ($key in $config.Vivaldi.Keys) {
    $vivaldiParams[$key] = $config.Vivaldi[$key]
}
Install-Vivaldi @vivaldiParams

Write-Section 'Installing Nucleus Co-op'
$nucleusParams = @{}
foreach ($key in $config.NucleusCoop.Keys) {
    $nucleusParams[$key] = $config.NucleusCoop[$key]
}
Install-NucleusCoop @nucleusParams

if ($config.SmbMappings.Folders -and $config.SmbMappings.Folders.Count -gt 0) {
    Write-Section 'Mounting SMB drives'
    $smbParams = @{}
    foreach ($key in $config.SmbMappings.Keys) {
        $smbParams[$key] = $config.SmbMappings[$key]
    }
    Mount-SmbFolders @smbParams
}

Write-Section 'Manual review packages'
Assert-ManualReviewPackages `
    -Packages $config.ManualReviewPackages `
    -Fail:(-not $AllowManualReviewPackages.IsPresent)

Write-Host 'Windows gaming setup finished.'
