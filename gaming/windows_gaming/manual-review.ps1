function Assert-ManualReviewPackages {
    [CmdletBinding()]
    param(
        [object[]]$Packages,
        [switch]$Fail
    )

    if (-not $Packages -or $Packages.Count -eq 0) {
        Write-Host 'No manual-review packages.'
        return
    }

    Write-Warning 'Some requested packages still need manual install automation.'

    foreach ($package in $Packages) {
        Write-Warning ("{0}: {1}" -f $package.Name, $package.Reason)
    }

    if ($Fail) {
        $names = ($Packages | ForEach-Object { $_.Name }) -join ', '
        throw "Requested Windows gaming packages still need manual install automation: $names. Run with -AllowManualReviewPackages to allow the rest of the setup to pass."
    }
}
