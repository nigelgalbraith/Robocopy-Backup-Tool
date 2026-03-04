param(
  # Path to the JSON configuration file.
  # Defaults to ../config/robocopy_backup_config.json relative to the script location.
  [string]$ConfigPath = (Join-Path (Join-Path $PSScriptRoot "..\config") "robocopy_backup_config.json")
)

# Reads and parses the JSON configuration file.
function Read-Config {
  param([string]$Path)

  # Ensure the configuration file exists before attempting to read it.
  if (!(Test-Path $Path)) { throw "Config not found: $Path" }

  # Load the entire file as raw text and convert JSON into a PowerShell object.
  return (Get-Content -Raw -Path $Path | ConvertFrom-Json)
}

# Converts a time string (HH:MM) into a DateTime object used by the scheduler.
function Parse-Time {
  param([string]$TimeStr)

  # Validate that the time is in HH:MM format.
  if ($TimeStr -notmatch '^\d{2}:\d{2}$') { throw "Invalid schedule time '$TimeStr' (expected HH:MM)" }

  # Split hours and minutes.
  $parts = $TimeStr.Split(":")

  # Create a DateTime object using today's date with the provided time.
  return (Get-Date -Hour ([int]$parts[0]) -Minute ([int]$parts[1]) -Second 0)
}

# Load configuration data from JSON.
$cfg = Read-Config -Path $ConfigPath

# Access the metadata section of the configuration.
$meta = $cfg.meta

# Ensure the configuration contains a meta section.
if (-not $meta) { throw "Missing meta section in config." }

# Get the scheduled task name from the config.
$taskName = $meta.task_name

# Use a default name if none was provided in the config.
if ([string]::IsNullOrWhiteSpace($taskName)) { $taskName = "RobocopyBackup" }

# Read scheduling settings from the config.
$sched = $meta.schedule

# Ensure scheduling settings exist.
if (-not $sched) { throw "Missing meta.schedule in config." }

# Only "daily" scheduling is supported by this script.
if ($sched.type -ne "daily") { throw "Unsupported schedule.type '$($sched.type)'. Use 'daily'." }

# Convert configured schedule time into a DateTime value.
$at = Parse-Time -TimeStr $sched.time

# Determine the path to the backup script that the scheduled task will run.
$scriptPath = Join-Path $PSScriptRoot "robocopy_backup.ps1"

# Detect the PowerShell executable currently running this script.
# This allows the scheduled task to run with either PowerShell 7 (pwsh) or Windows PowerShell.
$psExe = (Get-Process -Id $PID).Path

# Define the scheduled task action.
# This tells Windows which executable to run and what arguments to pass.
$action = New-ScheduledTaskAction `
  -Execute $psExe `
  -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""

# Create a daily trigger at the configured time.
$trigger = New-ScheduledTaskTrigger -Daily -At $at

# Register or update the scheduled task in Windows Task Scheduler.
Register-ScheduledTask `
  -TaskName $taskName `
  -Action $action `
  -Trigger $trigger `
  -Description "Robocopy Backup Tool (JSON-configured)" `
  -Force | Out-Null

# Display confirmation to the user.
Write-Host "Scheduled task created/updated: $taskName (daily at $($sched.time))"