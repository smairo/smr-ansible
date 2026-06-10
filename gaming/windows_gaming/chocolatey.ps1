function Get-ChocolateyCommand {
    [CmdletBinding()]
    param()

    $choco = Get-Command choco.exe -ErrorAction SilentlyContinue
    if ($choco) {
        return $choco.Source
    }

    $defaultPath = Join-Path -Path $env:ProgramData -ChildPath 'chocolatey\bin\choco.exe'
    if (Test-Path -LiteralPath $defaultPath) {
        return $defaultPath
    }

    return $null
}

function Install-ChocolateyCli {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $existing = Get-ChocolateyCommand
    if ($existing) {
        return $existing
    }

    if (-not $PSCmdlet.ShouldProcess('Chocolatey', 'Install Chocolatey CLI')) {
        return $null
    }

    Write-Host 'Installing Chocolatey CLI.'
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    $installScript = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
    Invoke-Expression $installScript | ForEach-Object {
        Write-Host $_
    }

    $choco = Get-ChocolateyCommand
    if (-not $choco) {
        throw 'Chocolatey installation finished, but choco.exe was not found.'
    }

    $chocoBin = Split-Path -Path $choco -Parent
    if (($env:Path -split ';') -notcontains $chocoBin) {
        $env:Path = "$env:Path;$chocoBin"
    }

    return $choco
}

function Install-ChocolateyPackages {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string[]]$Packages,

        [switch]$FailOnError
    )

    if (-not $Packages -or $Packages.Count -eq 0) {
        Write-Host 'No Chocolatey packages configured.'
        return
    }

    $choco = Install-ChocolateyCli
    if (-not $choco) {
        Write-Warning 'Chocolatey CLI is not installed. Skipping Chocolatey packages.'
        return
    }

    $failed = [System.Collections.Generic.List[object]]::new()

    foreach ($package in $Packages) {
        if (-not $PSCmdlet.ShouldProcess($package, 'Install Chocolatey package')) {
            continue
        }

        Write-Host "Installing Chocolatey package: $package"
        $output = & $choco install $package -y --no-progress 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            $failed.Add([pscustomobject]@{
                Name = $package
                ExitCode = $exitCode
                Output = ($output | Out-String).Trim()
            })
            Write-Warning "Failed Chocolatey package: $package"
            continue
        }

        Write-Host "Chocolatey package present: $package"
    }

    if ($failed.Count -gt 0) {
        $details = $failed | Format-List | Out-String
        if ($FailOnError) {
            throw "One or more Chocolatey packages failed to install:`n$details"
        }

        Write-Warning "One or more Chocolatey packages failed to install. Continuing with the rest of the setup.`n$details"
    }
}
