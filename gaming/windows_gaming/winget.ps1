function Resolve-SharedWinGetScript {
    [CmdletBinding()]
    param(
        [string]$ScriptRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($ScriptRoot)) {
        $localSharedPath = Join-Path -Path $ScriptRoot -ChildPath '..\..\workstations\windows\winget.ps1'
        $localSharedPath = [System.IO.Path]::GetFullPath($localSharedPath)

        if (Test-Path -LiteralPath $localSharedPath -PathType Leaf) {
            return $localSharedPath
        }
    }

    $sourceBaseUrl = $env:SMR_WINDOWS_SHARED_SOURCE_BASE_URL
    if ([string]::IsNullOrWhiteSpace($sourceBaseUrl)) {
        $sourceBaseUrl = 'https://raw.githubusercontent.com/smairo/smr-ansible/main/workstations/windows'
    }

    $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('smr-windows-shared-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

    $sharedPath = Join-Path -Path $tempRoot -ChildPath 'winget.ps1'
    $requestParams = @{
        Uri = $sourceBaseUrl.TrimEnd('/') + '/winget.ps1'
        OutFile = $sharedPath
    }

    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        $requestParams.UseBasicParsing = $true
    }

    Invoke-WebRequest @requestParams

    return $sharedPath
}

. (Resolve-SharedWinGetScript -ScriptRoot $PSScriptRoot)
