# Vaultwarden Automated Backup Pipeline

An automated backup pipeline for Vaultwarden running on Docker. Backups are captured nightly, flushed from SQLite WAL records, packaged into timestamped archives, and synchronized directly to Google Drive.

---

## Architecture Overview

```text
                      +-----------------------------+
                      |   Live Vaultwarden Stack    |
                      |  (/home/.../vaultwarden)    |
                      +--------------+--------------+
                                     |
                         Nightly tar.gz snapshot
                                     v
+-----------------------------------------------------------------------+
|  Host Staging: /var/backups/vaultwarden                               |
|                                                                       |
|  - vaultwarden-backup.sh         -> Flushes WAL, creates tar archive  |
|  - vaultwarden-nightly.tar.gz    -> Local latest backup snapshot      |
+-----------------------------------+-----------------------------------+
                                    |
                         Rclone encrypted sync
                                    v
                       +-------------------------+
                       |   Google Drive Remote   |
                       |  (VaultwardenBackups/)  |
                       +-------------------------+
```

---

## Prerequisites & Dependencies

The host VM requires `rclone` for offsite Google Drive syncing, `git` for configuration tracking, and an SSH Deploy Key:

```bash
# Host dependencies
sudo apt update && sudo apt install -y git rclone
```

### Required Directory Permissions
```bash
sudo chmod o+x /var/backups
sudo chown -R rvaitpros:rvaitpros /var/backups/vaultwarden
chmod -R 755 /var/backups/vaultwarden
```

---

## Configuration

### 1. Rclone (`rclone.conf.example`)
Configure Google Drive remote storage:
```bash
rclone config
```
* Remote Name: `gdrive`
* Storage Type: `drive`
* Root Folder: `VaultwardenBackups`

*Refer to `rclone.conf.example` for non-sensitive structure.*

### 2. GitHub Deploy Key
SSH Deploy Keys provide restricted write access for version tracking without personal account passwords:
```bash
ssh-keygen -t ed25519 -C "vaultwarden-backup-deploy-key" -f ~/.ssh/github_bitwarden_deploy_key -N ""
```
1. Add `~/.ssh/github_bitwarden_deploy_key.pub` to **Repository Settings > Deploy Keys** with **Write Access** enabled.
2. Add the host entry to `~/.ssh/config`:
```text
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_bitwarden_deploy_key
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
```

---

## Backup Script

### Daily Backup: `/usr/local/bin/vaultwarden-backup.sh`
* Flushes Write-Ahead Log (WAL) records to SQLite safely.
* Packages database, RSA keys, attachments, and configs into `vaultwarden-nightly.tar.gz`.
* Uploads the archive to `gdrive:VaultwardenBackups`.

---

## Automation (Cron Schedule)

### Nightly Backup
Runs daily at 03:00 AM:
```cron
0 3 * * * /usr/local/bin/vaultwarden-backup.sh >> /var/log/vaultwarden-backup.log 2>&1
```

---

## Security & Sanitization Policy

* **Live Databases:** Raw `.sqlite3` databases, `.env` files, and `.tar.gz` archives are barred via `.gitignore`.
* **Credentials:** Do not commit `rclone.conf` with OAuth tokens or administrative access tokens.
* **Tracked Assets:** Only operational scripts, sanitized templates, and setup documentation are maintained in this repository.
