# IMPORTS
param(
  [string]$ConfigPath = (Join-Path (Join-Path $PSScriptRoot "..\config") "robocopy_backup_config.json")
)

Import-Module (Join-Path $PSScriptRoot "modules\config_helpers.psm1") -Force -Function Read-Config, Test-ScheduleConfig, Get-TaskName
Import-Module (Join-Path $PSScriptRoot "modules\schedule_helpers.psm1") -Force -Function ConvertTo-ScheduleTime


# TASK MANAGEMENT
# Purpose: Create or update the scheduled backup task from configuration
function Main {
  param([string]$ConfigPath)
  # --- Validate inputs ---
  $resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
  $cfg = Read-Config -Path $resolvedConfigPath
  Test-ScheduleConfig -Config $cfg
  $taskName = Get-TaskName -Config $cfg
  $sched = $cfg.meta.schedule
  $at = ConvertTo-ScheduleTime -TimeStr $sched.time
  $scriptPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'robocopy_backup.ps1')).Path
  if (!(Test-Path -LiteralPath $scriptPath)) { throw "Backup script not found: $scriptPath" }
  $psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
  # Quote script and config paths to avoid malformed scheduled task arguments
  $action = New-ScheduledTaskAction -Execute $psExe -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$scriptPath`" -ConfigPath `"$resolvedConfigPath`""
  $trigger = New-ScheduledTaskTrigger -Daily -At $at
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description 'Robocopy Backup Tool (JSON-configured)' -Force | Out-Null
  Write-Host "Scheduled task created/updated: $taskName (daily at $($sched.time))"
}


# MAIN
try {
  Main -ConfigPath $ConfigPath
} catch {
  Write-Host "[ERROR] $($_.Exception.Message)"
  exit 1
}
