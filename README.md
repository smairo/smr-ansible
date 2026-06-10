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

To mount SMB folders from `\\192.168.1.64` as persistent network drives, pass the share names and credentials:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\gaming\windows_gaming.ps1 --smb-folders misc game movie pro --smb-user smair --smb-password 1234
```

If you ran the main setup elevated and the mapped drives do not appear in normal File Explorer, run the SMB step again from a non-admin PowerShell session:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\gaming\windows_gaming.ps1 --smb-only --smb-folders misc game movie pro --smb-user smair --smb-password 1234
```

The SMB step maps each folder to the next free drive letter from `Z:` downward. To choose letters explicitly, pass the same number of letters as folders:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\gaming\windows_gaming.ps1 --smb-folders misc game movie pro --smb-drive-letters M G O P --smb-user smair --smb-password 1234
```

The script installs package-manager-backed gaming apps with WinGet and Chocolatey. WinGet and Chocolatey package failures are reported and the setup continues by default; use `-FailOnWinGetPackageError` or `-FailOnChocolateyPackageError` to restore strict failure behavior. Dolphin is installed from the official Windows x64 release archive into `C:\Dolphin`; use `-DolphinInstallDir` to override that path. RPCS3 is installed from the latest official Windows GitHub release archive into `C:\RPCS3`. Vivaldi is installed from the official Windows x64 installer discovered from `vivaldi.com/download/`. Nucleus Co-op is installed from the latest GitHub release ZIP into `C:\NucleusCo-op`; the script adds that folder to Microsoft Defender exclusions before extraction, unblocks the downloaded ZIP, extracts with 7-Zip using the `nucleus` password, and backs up an existing install folder before placing a clean copy.
