# smr-ansible

## Windows gaming workstation

Run from an elevated PowerShell session on the Windows machine:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\gaming\windows_gaming.ps1
```

To pull and run the feature branch on a fresh machine:

```powershell
git clone -b feature/windows https://github.com/smairo/smr-ansible.git
cd smr-ansible
powershell.exe -ExecutionPolicy Bypass -File .\gaming\windows_gaming.ps1
```

The script installs package-manager-backed gaming apps with WinGet and Chocolatey. WinGet and Chocolatey package failures are reported and the setup continues by default; use `-FailOnWinGetPackageError` or `-FailOnChocolateyPackageError` to restore strict failure behavior. Dolphin is installed from the official Windows x64 release archive into `C:\Dolphin`; use `-DolphinInstallDir` to override that path. Vivaldi is installed from the official Windows x64 installer discovered from `vivaldi.com/download/`. Nucleus Co-op is installed from the latest GitHub release ZIP into `C:\NucleusCo-op`; the script adds that folder to Microsoft Defender exclusions before extraction, unblocks the downloaded ZIP, extracts with 7-Zip using the `nucleus` password, and backs up an existing install folder before placing a clean copy. Citron is kept in manual review because no current WinGet or Chocolatey package was found for it; the script fails at the end by default so it is not silently skipped. Use `-AllowManualReviewPackages` to allow the setup to finish with that warning.
