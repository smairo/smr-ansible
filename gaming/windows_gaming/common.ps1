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

function Get-NormalizedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\').ToLowerInvariant()
}

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
