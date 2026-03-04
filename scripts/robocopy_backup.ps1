param(
  # Path to the JSON configuration file.
  # Defaults to ../config/robocopy_backup_config.json relative to this script.
  [string]$ConfigPath = (Join-Path (Join-Path $PSScriptRoot "..\config") "robocopy_backup_config.json"),

  # Optional switch to run Robocopy in "dry run" mode.
  # When enabled, Robocopy lists actions without actually copying files.
  [switch]$DryRun
)

# Writes a timestamped message to both the console and a log file.
function Write-Log {
  param([string]$Message, [string]$LogFile)

  # Generate timestamp for the log entry.
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

  # Construct the log line.
  $line = "$ts : $Message"

  # Display the message in the console.
  Write-Host $line

  # Append the message to the log file.
  Add-Content -Path $LogFile -Value $line
}

# Expands environment variables in a path (e.g. %USERPROFILE%).
function Expand-EnvPath {
  param([string]$Path)

  # Use .NET method to resolve environment variables.
  return [Environment]::ExpandEnvironmentVariables($Path)
}

# Generates a timestamped log file path for a backup job.
function Get-LogFile {
  param([string]$LogRoot, [string]$JobKey)

  # Ensure the root log directory exists.
  if (!(Test-Path $LogRoot)) { New-Item -ItemType Directory -Path $LogRoot | Out-Null }

  # Create a timestamp used in the log file name.
  $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

  # Return the full log file path.
  return Join-Path $LogRoot "$JobKey`_$stamp.log"
}

# Executes a single Robocopy backup job.
function Invoke-RobocopyJob {
  param(
    # Unique key identifying the job (used for logging).
    [string]$JobKey,

    # Meta configuration section from the JSON config.
    [object]$Meta,

    # Job-specific configuration object.
    [object]$Job,

    # Optional switch for dry run mode.
    [switch]$DryRun
  )

  # Determine log folder location from config.
  $logRoot = Expand-EnvPath $Meta.log_root

  # Generate a new log file for this job.
  $logFile = Get-LogFile -LogRoot $logRoot -JobKey $JobKey

  # Skip the job if it is disabled.
  if ($Job.enabled -ne $true) {
    Write-Log "[SKIP] $JobKey disabled" $logFile
    return 0
  }

  # Expand environment variables in source and destination paths.
  $src = Expand-EnvPath $Job.source
  $dst = Expand-EnvPath $Job.dest

  # Ensure the source directory exists.
  if (!(Test-Path $src)) {
    Write-Log "[ERROR] Source not found: $src" $logFile
    return 2
  }

  # Create the destination directory if it does not exist.
  if (!(Test-Path $dst)) {
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
  }

  # Load default flags from the meta configuration.
  $defaultFlags = @()
  if ($Meta.default_flags) { $defaultFlags = @($Meta.default_flags) }

  # Load job-specific flags from the job configuration.
  $jobFlags = @()
  if ($Job.flags) { $jobFlags = @($Job.flags) }

  # Combine default and job-specific flags.
  $flags = @()
  $flags += $defaultFlags
  $flags += $jobFlags

  # Add dry-run flags if requested.
  if ($DryRun) {
      $flags += "/L"     # List only (no actual file operations)
      $flags += "/TEE"   # Display output in console as well as log
  }

  # Log job execution details.
  Write-Log "Mode: $($(if ($DryRun) { 'DRY RUN' } else { 'LIVE' }))" $logFile
  Write-Log "Job: $JobKey" $logFile
  Write-Log "Source: $src" $logFile
  Write-Log "Dest:   $dst" $logFile
  Write-Log "Flags:  $($flags -join ' ')" $logFile

  # Construct Robocopy argument list.
  $args = @($src, $dst) + $flags + @("/LOG+:$logFile")

  try {
    # Execute Robocopy and capture output.
    $out = & robocopy @args 2>&1

    # Capture Robocopy exit code.
    $rc = $LASTEXITCODE

    # If in dry run mode, print Robocopy output to the console.
    if ($DryRun) { $out | ForEach-Object { Write-Host $_ } }

  } catch {
    # Log unexpected execution errors.
    Write-Log "[FAIL] Robocopy execution failed: $($_.Exception.Message)" $logFile
    return 99
  }

  # Robocopy exit codes >= 8 indicate a failure.
  if ($rc -ge 8) {
    Write-Log "[FAIL] Robocopy exit code: $rc" $logFile
    return $rc
  }

  # Successful completion.
  Write-Log "[OK] Robocopy exit code: $rc" $logFile
  return 0
}

# Ensure the configuration file exists before proceeding.
if (!(Test-Path $ConfigPath)) { throw "Config not found: $ConfigPath" }

# Load configuration data from the JSON file.
$cfg = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

# Extract metadata section.
$meta = $cfg.meta

# Extract backup jobs collection.
$jobs = $cfg.backup_jobs

# Track whether any job fails.
$anyFail = $false

# Iterate through each backup job defined in the config.
foreach ($prop in $jobs.PSObject.Properties) {
  $key = $prop.Name
  $job = $prop.Value

  # Execute the job.
  $rc = Invoke-RobocopyJob -JobKey $key -Meta $meta -Job $job -DryRun:$DryRun

  # Record failure if any job returns a non-zero code.
  if ($rc -ne 0) { $anyFail = $true }
}

# Exit with a failure code if any job failed.
if ($anyFail) { exit 2 }

# Otherwise exit successfully.
exit 0