function Get-WindowsGamingConfig {
    [CmdletBinding()]
    param()

    return @{
        WinGetPackages = @(
            [pscustomobject]@{ Name = '7-Zip'; Id = '7zip.7zip' }
            [pscustomobject]@{ Name = 'Microsoft Visual C++ Redistributable 2015-2022 x64'; Id = 'Microsoft.VCRedist.2015+.x64' }
            [pscustomobject]@{ Name = 'Microsoft Visual C++ Redistributable 2015-2022 x86'; Id = 'Microsoft.VCRedist.2015+.x86' }
            [pscustomobject]@{ Name = 'Microsoft Edge WebView2 Runtime'; Id = 'Microsoft.EdgeWebView2Runtime' }
            [pscustomobject]@{ Name = 'Cemu'; Id = 'Cemu.Cemu' }
            [pscustomobject]@{ Name = 'RetroArch'; Id = 'Libretro.RetroArch' }
            [pscustomobject]@{ Name = 'Xemu'; Id = 'xemu-project.xemu' }
            [pscustomobject]@{ Name = 'Xenia'; Id = 'Xenia.Xenia' }
            [pscustomobject]@{ Name = 'Playnite'; Id = 'Playnite.Playnite' }
            [pscustomobject]@{ Name = 'PCSX2'; Id = 'PCSX2Team.PCSX2' }
            [pscustomobject]@{ Name = 'Epic Games Launcher'; Id = 'EpicGames.EpicGamesLauncher' }
            [pscustomobject]@{ Name = 'Rockstar Games Launcher'; Id = 'RockstarGames.Launcher' }
            [pscustomobject]@{ Name = 'Steam'; Id = 'Valve.Steam' }
            [pscustomobject]@{ Name = 'WinRAR'; Id = 'RARLab.WinRAR' }
            [pscustomobject]@{ Name = 'Proton VPN'; Id = 'Proton.ProtonVPN' }
            [pscustomobject]@{ Name = 'qBittorrent'; Id = 'qBittorrent.qBittorrent' }
            [pscustomobject]@{ Name = 'WizTree'; Id = 'AntibodySoftware.WizTree' }
            [pscustomobject]@{ Name = 'Prism Launcher'; Id = 'PrismLauncher.PrismLauncher' }
            [pscustomobject]@{ Name = 'Vortex'; Id = 'NexusMods.Vortex' }
        )

        Dolphin = @{
            Version = '2603a'
            DownloadUrl = 'https://dl.dolphin-emu.org/releases/2603a/dolphin-2603a-x64.7z'
            ArchiveSha256 = '4cc6d975fe9646ed7326271ec9a2d84b93301de7cdb525c6b20ed97c0a715bf1'
            ArchiveRoot = 'Dolphin-x64'
            InstallDir = 'C:\Dolphin'
        }

        Vivaldi = @{
            DownloadPageUrl = 'https://vivaldi.com/download/'
            StateDir = Join-Path -Path $env:ProgramData -ChildPath 'smr-windows-gaming'
            ExecutablePath = Join-Path -Path $env:ProgramFiles -ChildPath 'Vivaldi\Application\vivaldi.exe'
        }

        ChocolateyPackages = @(
            'rpcs3'
            'ryujinx'
        )

        NucleusCoop = @{
            ReleaseApiUrl = 'https://api.github.com/repos/SplitScreen-Me/splitscreenme-nucleus/releases/latest'
            InstallDir = 'C:\NucleusCo-op'
            ArchivePassword = 'nucleus'
            AddDefenderExclusion = $true
        }

        ManualReviewPackages = @(
            [pscustomobject]@{
                Name = 'Citron'
                Reason = 'No current WinGet or Chocolatey package was found.'
            }
        )
    }
}
