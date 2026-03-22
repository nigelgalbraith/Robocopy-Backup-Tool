# Robocopy Backup Tool

A simple, configurable PowerShell backup tool built on top of Windows **Robocopy**.

The tool reads a JSON configuration file that defines backup jobs and executes them automatically.

---

## Features

* Multiple backup jobs
* Environment variable expansion (e.g. `%USERNAME%`)
* Automatic log generation
* Safe **Dry Run mode**
* Optional **Windows Task Scheduler automation**
* Simple interactive menu
* Structured internal modules (config, path, schedule)

---

## Compatibility

* Windows PowerShell 5.1
* PowerShell 7+

---

# Folder Structure

Example installation folder:

```
C:\BackupTools\RobocopyBackup\
```

### Recommended layout

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
    ├── open_latest_log.ps1
    │
    └── modules
        ├── config_helpers.psm1
        ├── path_helpers.psm1
        └── schedule_helpers.psm1
```

---

## Folder descriptions

| Folder    | Purpose                  |
| --------- | ------------------------ |
| `config`  | Backup job configuration |
| `scripts` | PowerShell scripts       |
| `modules` | Shared helper functions  |
| `logs`    | Backup logs              |

---

# Starting the Tool

Run:

```
run_backup.bat
```

The launcher will:

* Use **PowerShell 7 (`pwsh`)** if available
* Otherwise fall back to **Windows PowerShell**

---

## Menu

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

Located at:

```
config\robocopy_backup_config.json
```

---

## Example

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

## Configuration Fields

### Meta

| Field           | Description                  |
| --------------- | ---------------------------- |
| `log_root`      | Folder where logs are stored |
| `default_flags` | Default Robocopy flags       |

---

### Backup Jobs

| Field     | Description             |
| --------- | ----------------------- |
| `enabled` | Enable/disable job      |
| `source`  | Source folder           |
| `dest`    | Destination folder      |
| `flags`   | Optional Robocopy flags |

Environment variables (e.g. `%USERNAME%`) are automatically expanded.

---

# Dry Run Mode (Recommended)

Run a safe simulation before copying files.

Menu:

```
1) Dry run (no copy)
```

Or direct:

```
pwsh scripts\robocopy_backup.ps1 -DryRun
```

---

# Running the Backup

Menu:

```
2) Run backup now
```

Or:

```
pwsh scripts\robocopy_backup.ps1
```

---

# Logs

Logs are written to the configured folder.

Example:

```
logs\
```

### Behaviour

* A **single run log** is created per execution:

  ```
  backup_run_YYYY-MM-DD_HH-MM-SS.log
  ```

* Each job writes into the same run log

* Robocopy output is appended using `/LOG+`

---

## Open latest log

Menu:

```
5) Open latest log
```

If the log folder does not exist or no logs are present, the tool exits cleanly.

---

# Scheduled Tasks

Install/update:

```
3) Install/Update scheduled task
```

Remove:

```
4) Remove scheduled task
```

Or direct:

```
pwsh scripts\install_task.ps1
pwsh scripts\remove_task.ps1
```

---

# Requirements

* Windows 10 / Windows 11
* Robocopy (built-in)
* PowerShell 5.1 or PowerShell 7

---

# Notes

* Always use **Dry Run** before real execution
* Jobs are executed independently
* Robocopy exit codes are interpreted automatically
* Safe path validation prevents destructive configurations

---

# License

Provided as-is for personal and educational use.
