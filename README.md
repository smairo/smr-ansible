# smr-ansible

## Windows gaming workstation

To run the Windows gaming setup on a fresh machine without cloning the repo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/smairo/smr-ansible/main/gaming/windows_gaming.ps1 | iex"
```

To mount SMB folders as persistent network drives, pass the SMB server URL, share names, and credentials:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/smairo/smr-ansible/main/gaming/windows_gaming.ps1))) --smb-url '\\192.168.1.111' --smb-folders A B C D --smb-user myuser --smb-password 1234"
```
