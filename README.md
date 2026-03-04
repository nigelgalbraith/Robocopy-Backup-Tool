# Robocopy Backup Tool

A simple, configurable PowerShell backup tool built on top of Windows **Robocopy**.

The script reads a JSON configuration file describing backup jobs and executes them automatically.

It supports:

* Multiple backup jobs
* Environment variable expansion (e.g. `%USERNAME%`)
* Logging per job
* Safe **Dry Run** mode
* Optional Windows **Task Scheduler automation**

---

# Folder Structure

Place the files together in a folder, for example:

```
C:\BackupTools\RobocopyBackup\
```

Example layout:

```
RobocopyBackup
│
├── robocopy_backup.ps1
├── robocopy_backup_config.json
├── create_backup_task.ps1
├── remove_backup_task.ps1
└── README.md
```

---

# Configuration

The backup jobs are defined in:

```
robocopy_backup_config.json
```

Example configuration:

```json
{
  "meta": {
    "log_root": "C:\\BackupTools\\RobocopyBackup\\logs",
    "default_flags": ["/COPY:DAT", "/DCOPY:DAT", "/R:2", "/W:2", "/FFT", "/NP"]
  },
  "backup_jobs": {
    "DocumentsBackup": {
      "enabled": true,
      "source": "C:\\Users\\%USERNAME%\\Documents",
      "dest": "C:\\Users\\%USERNAME%\\Downloads\\DocumentsBackup",
      "flags": ["/XD", "node_modules", ".git", "/XF", "*.tmp", "*.log"]
    }
  }
}
```

### Configuration fields

| Field     | Description                        |
| --------- | ---------------------------------- |
| `enabled` | Enables or disables the backup job |
| `source`  | Source folder to back up           |
| `dest`    | Destination folder                 |
| `flags`   | Additional Robocopy flags          |

Environment variables like `%USERNAME%` are expanded automatically.

---

# First Test (Safe Mode)

Before running the backup for real, run a **dry run**.

This simulates the backup without copying any files.

```
pwsh robocopy_backup.ps1 -DryRun
```

The script will print the planned jobs and Robocopy commands.

---

# Run the Backup

To run the backup normally:

```
pwsh robocopy_backup.ps1
```

Logs will be written to:

```
C:\BackupTools\RobocopyBackup\logs
```

Each job produces a timestamped log file.

---

# Automating the Backup

You can automatically run the backup using Windows Task Scheduler.

### Create the scheduled task

```
pwsh create_backup_task.ps1
```

This creates a task named:

```
RobocopyBackup
```

By default it runs **daily at 2:00 AM**.

---

# Remove the Scheduled Task

If you want to remove the automation:

```
pwsh remove_backup_task.ps1
```

This removes the scheduled task safely.

---

# First Test (Recommended)

Before running the backup for real, run a Dry Run.

This simulates the backup without copying any files.

pwsh robocopy_backup.ps1 -DryRun

Verify the output and confirm the source and destination paths are correct.

---

# Notes

* Robocopy is included with Windows.
* This script is designed to be simple and easily customizable.
* Always test changes with **Dry Run mode** before running real backups.

---

# License

This project is provided as-is for personal and educational use.
