# IMPORTS
param(
  [string]$ConfigPath = (Join-Path (Join-Path $PSScriptRoot "..\config") "robocopy_backup_config.json")
)

Import-Module (Join-Path $PSScriptRoot "modules\config_helpers.psm1") -Force -Function Read-Config, Test-LogConfig, Get-LogRoot

# LOGGING
# Purpose: Open the most recently updated run log file
function Main {
  param([string]$ConfigPath)
  # --- Validate inputs ---
  $resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
  $cfg = Read-Config -Path $resolvedConfigPath
  Test-LogConfig -Config $cfg
  $logRoot = Get-LogRoot -Config $cfg
  if (!(Test-Path -LiteralPath $logRoot)) {
    Write-Host "[INFO] Log folder does not exist yet: $logRoot"
    return 0
  }
  # Sort by write time to select the newest log from prior runs
  $latest = Get-ChildItem -LiteralPath $logRoot -Filter '*.log' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (-not $latest) {
    Write-Host "[INFO] No log files found in: $logRoot"
    return 0
  }
  Write-Host 'Opening latest log:'
  Write-Host $latest.FullName
  Start-Process -FilePath 'notepad.exe' -ArgumentList "`"$($latest.FullName)`""
}


# MAIN
try {
  $code = Main -ConfigPath $ConfigPath
  exit $code
} catch {
  Write-Host "[ERROR] $($_.Exception.Message)"
  exit 1
}