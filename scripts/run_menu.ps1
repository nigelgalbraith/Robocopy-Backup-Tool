# IMPORTS
param(
  [string]$ConfigPath = (Join-Path (Join-Path $PSScriptRoot "..\config") "robocopy_backup_config.json")
)

# MENU
# Purpose: Pause execution until the user confirms with Enter
function Wait-ForKey {
  Write-Host ''
  Write-Host 'Press Enter to continue...'
  [void](Read-Host)
}


# HELPERS
# Purpose: Resolve a required script path and fail if the script is missing
function Get-ExistingScriptPath {
  param([string]$FileName)
  $path = Join-Path $PSScriptRoot $FileName
  if (!(Test-Path -LiteralPath $path)) { throw "Required script not found: $path" }
  return (Resolve-Path -LiteralPath $path).Path
}


# MENU
# Purpose: Display the interactive menu and dispatch user selections
function Main {
  param([string]$ConfigPath)
  # --- Validate inputs ---
  $resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
  $backupScript = Get-ExistingScriptPath -FileName 'robocopy_backup.ps1'
  $installScript = Get-ExistingScriptPath -FileName 'install_task.ps1'
  $removeScript = Get-ExistingScriptPath -FileName 'remove_task.ps1'
  $openLogScript = Get-ExistingScriptPath -FileName 'open_latest_log.ps1'
  while ($true) {
    Clear-Host
    Write-Host 'Robocopy Backup Tool'
    Write-Host "Config: $resolvedConfigPath"
    Write-Host ''
    Write-Host '1) Dry run (no copy)'
    Write-Host '2) Run backup now'
    Write-Host '3) Install/Update scheduled task'
    Write-Host '4) Remove scheduled task'
    Write-Host '5) Open latest log'
    Write-Host '6) Exit'
    Write-Host ''
    $choice = Read-Host 'Select (1-6)'
    if ($choice -eq '1') { & $backupScript -ConfigPath $resolvedConfigPath -DryRun; Wait-ForKey; continue }
    if ($choice -eq '2') { & $backupScript -ConfigPath $resolvedConfigPath; Wait-ForKey; continue }
    if ($choice -eq '3') { & $installScript -ConfigPath $resolvedConfigPath; Wait-ForKey; continue }
    if ($choice -eq '4') { & $removeScript -ConfigPath $resolvedConfigPath; Wait-ForKey; continue }
    if ($choice -eq '5') { & $openLogScript -ConfigPath $resolvedConfigPath; Wait-ForKey; continue }
    if ($choice -eq '6') { break }
  }
}


# MAIN
try {
  Main -ConfigPath $ConfigPath
} catch {
  Write-Host "[ERROR] $($_.Exception.Message)"
  Wait-ForKey
  exit 1
}
