param(
  # Path to the JSON configuration file.
  # Defaults to ../config/robocopy_backup_config.json relative to this script.
  [string]$ConfigPath = (Join-Path (Join-Path $PSScriptRoot "..\config") "robocopy_backup_config.json")
)

# Reads and parses the JSON configuration file.
function Get-Config {
  param([string]$Path)

  # Verify the configuration file exists before attempting to read it.
  if (!(Test-Path $Path)) { throw "Config not found: $Path" }

  # Load the file as raw text and convert it into a PowerShell object.
  return (Get-Content -Raw -Path $Path | ConvertFrom-Json)
}

# Expands any environment variables in a path (e.g. %USERPROFILE%, %APPDATA%).
function Expand-EnvPath {
  param([string]$Path)

  # Uses .NET environment variable expansion to resolve variables in the path.
  return [Environment]::ExpandEnvironmentVariables($Path)
}

# Load the configuration data.
$cfg = Get-Config -Path $ConfigPath

# Ensure the config contains a meta section and a log_root path.
if (-not $cfg.meta -or [string]::IsNullOrWhiteSpace($cfg.meta.log_root)) { throw "Missing meta.log_root in config." }

# Expand environment variables in the configured log folder path.
$logRoot = Expand-EnvPath $cfg.meta.log_root

# Verify the log directory exists.
if (!(Test-Path $logRoot)) { throw "Log folder not found: $logRoot" }

# Locate the newest log file in the log directory.
# - Filter for *.log files
# - Sort by LastWriteTime (newest first)
# - Select the first result.
$latest = Get-ChildItem -Path $logRoot -Filter "*.log" -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

# If no log files exist, inform the user and exit.
if (-not $latest) {
  Write-Host "[INFO] No log files found in: $logRoot"
  exit 0
}

# Display which log file is being opened.
Write-Host "Opening latest log:"
Write-Host $latest.FullName

# Launch Notepad and open the most recent log file.
Start-Process -FilePath "notepad.exe" -ArgumentList "`"$($latest.FullName)`""