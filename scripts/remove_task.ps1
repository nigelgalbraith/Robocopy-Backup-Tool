# IMPORTS
param(
  [string]$ConfigPath = (Join-Path (Join-Path $PSScriptRoot "..\config") "robocopy_backup_config.json")
)

Import-Module (Join-Path $PSScriptRoot "modules\config_helpers.psm1") -Force -Function Read-Config, Get-TaskName

# TASK MANAGEMENT
# Purpose: Remove the configured scheduled backup task if it exists
function Main {
  param([string]$ConfigPath)
  # --- Validate inputs ---
  $resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
  $cfg = Read-Config -Path $resolvedConfigPath
  $taskName = Get-TaskName -Config $cfg
  if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Scheduled task removed: $taskName"
    return
  }
  Write-Host "Scheduled task not found: $taskName"
}


# MAIN
try {
  Main -ConfigPath $ConfigPath
} catch {
  Write-Host "[ERROR] $($_.Exception.Message)"
  exit 1
}
