param(
  # Path to the JSON configuration file.
  # Defaults to ../config/robocopy_backup_config.json relative to this script.
  [string]$ConfigPath = (Join-Path (Join-Path $PSScriptRoot "..\config") "robocopy_backup_config.json")
)

# Simple helper function that pauses execution until the user presses Enter.
function Pause-ForKey {
  Write-Host ""
  Write-Host "Press Enter to continue..."
  [void](Read-Host)
}

# Resolve the paths to the other scripts used by this menu.
# All scripts are expected to be in the same directory as this file.
$backupScript = Join-Path $PSScriptRoot "robocopy_backup.ps1"
$installScript = Join-Path $PSScriptRoot "install_task.ps1"
$removeScript = Join-Path $PSScriptRoot "remove_task.ps1"
$openLogScript = Join-Path $PSScriptRoot "open_latest_log.ps1"

# Start an infinite loop so the menu keeps reappearing
# until the user chooses the Exit option.
while ($true) {

  # Clear the console screen before drawing the menu.
  Clear-Host

  # Display the menu header and configuration path being used.
  Write-Host "Robocopy Backup Tool"
  Write-Host "Config: $ConfigPath"
  Write-Host ""

  # Display available menu options.
  Write-Host "1) Dry run (no copy)"
  Write-Host "2) Run backup now"
  Write-Host "3) Install/Update scheduled task"
  Write-Host "4) Remove scheduled task"
  Write-Host "5) Open latest log"
  Write-Host "6) Exit"
  Write-Host ""

  # Prompt the user to select a menu option.
  $choice = Read-Host "Select (1-6)"

  # Option 1: Run the backup script in dry-run mode.
  # This shows what would happen without copying any files.
  if ($choice -eq "1") {
    & $backupScript -ConfigPath $ConfigPath -DryRun
    Pause-ForKey
    continue
  }

  # Option 2: Run the backup script normally.
  if ($choice -eq "2") {
    & $backupScript -ConfigPath $ConfigPath
    Pause-ForKey
    continue
  }

  # Option 3: Install or update the scheduled task
  # that automatically runs the backup.
  if ($choice -eq "3") {
    & $installScript -ConfigPath $ConfigPath
    Pause-ForKey
    continue
  }

  # Option 4: Remove the scheduled task from Windows Task Scheduler.
  if ($choice -eq "4") {
    & $removeScript -ConfigPath $ConfigPath
    Pause-ForKey
    continue
  }

  # Option 5: Open the most recent backup log file.
  if ($choice -eq "5") {
    & $openLogScript -ConfigPath $ConfigPath
    Pause-ForKey
    continue
  }

  # Option 6: Exit the menu loop and end the program.
  if ($choice -eq "6") { break }
}