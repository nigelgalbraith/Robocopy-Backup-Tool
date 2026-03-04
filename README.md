# Robocopy Backup Tool

A simple, configurable PowerShell backup tool built on top of Windows **Robocopy**.

The tool reads a JSON configuration file that defines backup jobs and executes them automatically.

It supports:

* Multiple backup jobs
* Environment variable expansion (e.g. `%USERNAME%`)
* Automatic log generation
* Safe **Dry Run mode**
* Optional **Windows Task Scheduler automation**
* A simple **menu interface**

The tool works with **PowerShell 7 or Windows PowerShell 5.1**.

---

# Folder Structure

Example installation folder:

```
C:\BackupTools\RobocopyBackup\
```

Recommended layout:

```
RobocopyBackup
│
├── run_backup.bat
├── README.md
│
├── config
│   └── robocopy_backup_config.json
│
├── logs
│
└── scripts
    ├── robocopy_backup.ps1
    ├── run_menu.ps1
    ├── install_task.ps1
    ├── remove_task.ps1
    └── open_latest_log.ps1
```

### Folder descriptions

| Folder    | Purpose                             |
| --------- | ----------------------------------- |
| `config`  | Backup job configuration            |
| `scripts` | PowerShell scripts                  |
| `logs`    | Backup logs generated automatically |

---

# Starting the Tool

Launch the tool using:

```
run_backup.bat
```

The launcher will:

* Use **PowerShell 7 (pwsh)** if installed
* Otherwise fall back to **Windows PowerShell**

You will see the interactive menu:

```
Robocopy Backup Tool

1) Dry run (no copy)
2) Run backup now
3) Install/Update scheduled task
4) Remove scheduled task
5) Open latest log
6) Exit
```

---

# Configuration

Backup jobs are defined in:

```
config\robocopy_backup_config.json
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

---

# Configuration Fields

### Meta section

| Field           | Description                                |
| --------------- | ------------------------------------------ |
| `log_root`      | Folder where logs are stored               |
| `default_flags` | Default Robocopy flags applied to all jobs |

---

### Backup job fields

| Field     | Description                          |
| --------- | ------------------------------------ |
| `enabled` | Enables or disables the job          |
| `source`  | Source folder                        |
| `dest`    | Destination folder                   |
| `flags`   | Optional job-specific Robocopy flags |

Environment variables such as `%USERNAME%` are expanded automatically.

---

# Dry Run Mode (Recommended)

Before performing a real backup, run a **Dry Run**.

This simulates the backup without copying files.

From the menu choose:

```
1) Dry run (no copy)
```

or run directly:

```
pwsh scripts\robocopy_backup.ps1 -DryRun
```

This allows you to confirm:

* Source paths
* Destination paths
* Robocopy flags
* Job configuration

---

# Running the Backup

To run the backup manually:

Menu option:

```
2) Run backup now
```

or directly:

```
pwsh scripts\robocopy_backup.ps1
```

---

# Logs

Logs are automatically written to the configured log folder.

Example:

```
logs\
```

Each job creates a timestamped log file:

```
DocumentsBackup_2026-03-04_20-31-12.log
```

You can open the newest log from the menu:

```
5) Open latest log
```

---

# Automating the Backup

The tool can install a scheduled task to run backups automatically.

Menu option:

```
3) Install/Update scheduled task
```

This creates a Windows Task Scheduler job using the schedule defined in the configuration file.

---

# Removing Automation

To remove the scheduled task:

Menu option:

```
4) Remove scheduled task
```

or run:

```
pwsh scripts\remove_task.ps1
```

---

# Requirements

* Windows 10 / Windows 11
* Robocopy (included with Windows)
* PowerShell 5.1 or PowerShell 7

---

# Notes

* Always test configuration changes using **Dry Run mode**.
* Robocopy exit codes are interpreted automatically by the script.
* Each backup job runs independently.

---

# License

Provided as-is for personal and educational use.
