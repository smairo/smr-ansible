function Get-WinGetCommand {
    [CmdletBinding()]
    param()

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw 'winget.exe was not found. Install or update Microsoft App Installer before running this setup.'
    }

    return $winget.Source
}

function Get-WinGetPackageSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Package
    )

    $source = [string]$Package.Source
    if ([string]::IsNullOrWhiteSpace($source)) {
        return 'winget'
    }

    return $source
}

function Test-WinGetPackageInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WingetPath,

        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $output = & $WingetPath list --id $Id --exact --source $Source --disable-interactivity 2>&1
    $text = $output | Out-String

    return ($LASTEXITCODE -eq 0) -and ($text -match [regex]::Escape($Id))
}

function Install-WinGetPackages {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [object[]]$Packages,

        [switch]$FailOnError
    )

    if (-not $Packages -or $Packages.Count -eq 0) {
        Write-Host 'No WinGet packages configured.'
        return
    }

    $winget = Get-WinGetCommand
    $failed = [System.Collections.Generic.List[object]]::new()

    foreach ($package in $Packages) {
        $name = [string]$package.Name
        $id = [string]$package.Id
        $source = Get-WinGetPackageSource -Package $package

        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = $id
        }

        if ([string]::IsNullOrWhiteSpace($id)) {
            throw "WinGet package '$name' is missing an Id."
        }

        if (Test-WinGetPackageInstalled -WingetPath $winget -Id $id -Source $source) {
            Write-Host "Present: $name ($id from $source)"
            continue
        }

        if (-not $PSCmdlet.ShouldProcess("$name ($id from $source)", 'Install WinGet package')) {
            continue
        }

        $installArgs = @(
            'install'
            '--id', $id
            '--exact'
            '--source', $source
            '--silent'
            '--accept-package-agreements'
            '--accept-source-agreements'
            '--disable-interactivity'
        )

        Write-Host "Installing: $name ($id from $source)"
        $output = & $winget @installArgs 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            $failed.Add([pscustomobject]@{
                Name = $name
                Id = $id
                Source = $source
                ExitCode = $exitCode
                Output = ($output | Out-String).Trim()
            })
            Write-Warning "Failed: $name ($id from $source)"
            continue
        }

        Write-Host "Installed: $name ($id from $source)"
    }

    if ($failed.Count -gt 0) {
        $details = $failed | Format-List | Out-String
        if ($FailOnError) {
            throw "One or more WinGet packages failed to install:`n$details"
        }

        Write-Warning "One or more WinGet packages failed to install. Continuing with the rest of the setup.`n$details"
    }
}
