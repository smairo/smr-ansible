#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$AllowManualReviewPackages,
    [switch]$SkipDefenderExclusion,
    [switch]$FailOnWinGetPackageError,
    [string]$DolphinInstallDir,
    [string]$NucleusInstallDir
)

$ErrorActionPreference = 'Stop'

$moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath 'windows_gaming'

. (Join-Path -Path $moduleRoot -ChildPath 'common.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'config.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'winget.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'chocolatey.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'dolphin.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'vivaldi.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'nucleus-coop.ps1')
. (Join-Path -Path $moduleRoot -ChildPath 'manual-review.ps1')

Assert-Windows
Assert-Administrator

$config = Get-WindowsGamingConfig

if ($PSBoundParameters.ContainsKey('NucleusInstallDir')) {
    $config.NucleusCoop.InstallDir = $NucleusInstallDir
}

if ($PSBoundParameters.ContainsKey('DolphinInstallDir')) {
    $config.Dolphin.InstallDir = $DolphinInstallDir
}

if ($SkipDefenderExclusion) {
    $config.NucleusCoop.AddDefenderExclusion = $false
}

Write-Section 'Installing WinGet packages'
Install-WinGetPackages `
    -Packages $config.WinGetPackages `
    -FailOnError:$FailOnWinGetPackageError.IsPresent

Write-Section 'Installing Chocolatey packages'
Install-ChocolateyPackages -Packages $config.ChocolateyPackages

Write-Section 'Installing Dolphin'
$dolphinParams = @{}
foreach ($key in $config.Dolphin.Keys) {
    $dolphinParams[$key] = $config.Dolphin[$key]
}
Install-Dolphin @dolphinParams

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

Write-Section 'Manual review packages'
Assert-ManualReviewPackages `
    -Packages $config.ManualReviewPackages `
    -Fail:(-not $AllowManualReviewPackages.IsPresent)

Write-Host 'Windows gaming setup finished.'
