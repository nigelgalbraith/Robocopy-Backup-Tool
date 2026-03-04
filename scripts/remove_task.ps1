param(
  # Path to the JSON configuration file.
  # Defaults to ../config/robocopy_backup_config.json relative to this script.
  [string]$ConfigPath = (Join-Path (Join-Path $PSScriptRoot "..\config") "robocopy_backup_config.json")
)

# Reads and parses the JSON configuration file.
function Read-Config {
  param([string]$Path)

  # Verify that the configuration file exists before attempting to read it.
  if (!(Test-Path $Path)) { throw "Config not found: $Path" }

  # Load the file as raw text and convert the JSON into a PowerShell object.
  return (Get-Content -Raw -Path $Path | ConvertFrom-Json)
}

# Load configuration data from the JSON file.
$cfg = Read-Config -Path $ConfigPath

# Retrieve the scheduled task name from the config metadata.
$taskName = $cfg.meta.task_name

# If no task name is defined in the config, use a default name.
if ([string]::IsNullOrWhiteSpace($taskName)) { $taskName = "RobocopyBackup" }

# Check whether the scheduled task exists in Windows Task Scheduler.
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {

  # If the task exists, remove it without prompting the user for confirmation.
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false

  # Inform the user that the scheduled task has been removed.
  Write-Host "Scheduled task removed: $taskName"

} else {

  # If the task was not found, notify the user.
  Write-Host "Scheduled task not found: $taskName"

}