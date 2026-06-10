# smr-ansible

## Windows gaming workstation

To pull and run the feature branch on a fresh machine:

```powershell
git clone -b feature/windows https://github.com/smairo/smr-ansible.git
cd smr-ansible
powershell.exe -ExecutionPolicy Bypass -File .\gaming\windows_gaming.ps1
```

To mount SMB folders as persistent network drives, pass the SMB server URL, share names, and credentials:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\gaming\windows_gaming.ps1 --smb-url \\192.168.1.111 --smb-folders A B C D --smb-user myuser --smb-password 1234
```
