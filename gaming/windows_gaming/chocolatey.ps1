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
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

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
        [string[]]$Packages
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

    foreach ($package in $Packages) {
        if (-not $PSCmdlet.ShouldProcess($package, 'Install Chocolatey package')) {
            continue
        }

        Write-Host "Installing Chocolatey package: $package"
        $output = & $choco install $package -y --no-progress 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            throw "Chocolatey package '$package' failed with exit code $exitCode.`n$($output | Out-String)"
        }

        Write-Host "Chocolatey package present: $package"
    }
}
