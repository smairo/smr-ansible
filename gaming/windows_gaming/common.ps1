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

function ConvertFrom-WindowsGamingRemainingArguments {
    [CmdletBinding()]
    param(
        [string[]]$Arguments
    )

    $result = @{}
    if (-not $Arguments -or $Arguments.Count -eq 0) {
        return $result
    }

    $optionNames = @{
        '--smb-url' = 'SmbUrl'
        '-smb-url' = 'SmbUrl'
        '--smb-base' = 'SmbBasePath'
        '-smb-base' = 'SmbBasePath'
        '--smb-base-path' = 'SmbBasePath'
        '-smb-base-path' = 'SmbBasePath'
        '--smb-folders' = 'SmbFolders'
        '-smb-folders' = 'SmbFolders'
        '--smb-user' = 'SmbUser'
        '-smb-user' = 'SmbUser'
        '--smb-password' = 'SmbPassword'
        '-smb-password' = 'SmbPassword'
        '--smb-drive-letters' = 'SmbDriveLetters'
        '-smb-drive-letters' = 'SmbDriveLetters'
        '--smb-only' = 'SmbOnly'
        '-smb-only' = 'SmbOnly'
    }
    $arrayOptionNames = @('SmbFolders', 'SmbDriveLetters')
    $switchOptionNames = @('SmbOnly')
    $arrayValues = @{
        SmbFolders = [System.Collections.Generic.List[string]]::new()
        SmbDriveLetters = [System.Collections.Generic.List[string]]::new()
    }
    $unboundArguments = [System.Collections.Generic.List[string]]::new()

    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $token = [string]$Arguments[$index]
        $optionToken = $token
        $valueFromEquals = $null

        if ($token -match '^(--?[^=]+)=(.*)$') {
            $optionToken = $Matches[1]
            $valueFromEquals = $Matches[2]
        }

        $optionKey = $optionToken.ToLowerInvariant()
        if (-not $optionNames.ContainsKey($optionKey)) {
            if ($optionToken.StartsWith('-', [System.StringComparison]::Ordinal)) {
                throw "Unknown argument: $optionToken"
            }

            $unboundArguments.Add($token)
            continue
        }

        $name = $optionNames[$optionKey]
        if ($switchOptionNames -contains $name) {
            if ($null -eq $valueFromEquals) {
                $result[$name] = $true
                continue
            }

            if ($valueFromEquals -notmatch '^(?i:true|false|1|0)$') {
                throw "Invalid boolean value for $optionToken`: $valueFromEquals"
            }

            $result[$name] = ($valueFromEquals -match '^(?i:true|1)$')
            continue
        }

        if ($arrayOptionNames -contains $name) {
            $values = [System.Collections.Generic.List[string]]::new()

            if ($null -ne $valueFromEquals) {
                foreach ($value in ($valueFromEquals -split ',')) {
                    if ($value) {
                        $values.Add($value)
                    }
                }
            }
            else {
                while (($index + 1) -lt $Arguments.Count) {
                    $nextToken = [string]$Arguments[$index + 1]
                    $nextOptionToken = $nextToken
                    if ($nextToken -match '^(--?[^=]+)=(.*)$') {
                        $nextOptionToken = $Matches[1]
                    }

                    if ($optionNames.ContainsKey($nextOptionToken.ToLowerInvariant()) -or $nextOptionToken.StartsWith('-', [System.StringComparison]::Ordinal)) {
                        break
                    }

                    $values.Add($nextToken)
                    $index++
                }
            }

            if ($values.Count -eq 0) {
                throw "Missing value for $optionToken."
            }

            foreach ($value in $values) {
                $arrayValues[$name].Add($value)
            }

            continue
        }

        if ($null -eq $valueFromEquals) {
            if (($index + 1) -ge $Arguments.Count) {
                throw "Missing value for $optionToken."
            }

            $valueFromEquals = [string]$Arguments[$index + 1]
            if ($valueFromEquals.StartsWith('-', [System.StringComparison]::Ordinal)) {
                throw "Missing value for $optionToken."
            }

            $index++
        }

        $result[$name] = $valueFromEquals
    }

    foreach ($name in $arrayOptionNames) {
        if ($arrayValues[$name].Count -gt 0) {
            $result[$name] = [string[]]$arrayValues[$name]
        }
    }

    if ($unboundArguments.Count -gt 0) {
        $result.UnboundArguments = [string[]]$unboundArguments
    }

    return $result
}
