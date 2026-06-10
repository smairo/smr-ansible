# smr-ansible

## Windows gaming workstation

Install the required Ansible collections:

```sh
ansible-galaxy collection install -r requirements.yml
```

Run the Windows gaming workstation playbook against hosts in the `windows_gaming` inventory group:

```sh
ansible-playbook -i inventory.ini workstations/windows_gaming.yml
```

The inventory must define a Windows connection, such as WinRM or PSRP, for the hosts in that group.

The playbook installs package-manager-backed gaming apps with WinGet and Chocolatey. Nucleus Co-op is installed from the latest GitHub release ZIP into `C:\NucleusCo-op`; the task adds that folder to Microsoft Defender exclusions before extraction, unblocks the downloaded ZIP, extracts with 7-Zip using the `nucleus` password, and backs up an existing install folder before placing a clean copy. Citron is kept in `windows_gaming_manual_review_packages` because no current WinGet or Chocolatey package was found for it; the playbook fails at the end by default so it is not silently skipped.
