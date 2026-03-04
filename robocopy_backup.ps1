param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot "robocopy_backup_config.json"),
  [switch]$DryRun
)

function Write-Log {
  param([string]$Message, [string]$LogFile)
  $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $line = "$ts : $Message"
  Write-Host $line
  Add-Content -Path $LogFile -Value $line
}

function Expand-EnvPath {
  param([string]$Path)
  return [Environment]::ExpandEnvironmentVariables($Path)
}

function Get-LogFile {
  param([string]$LogRoot, [string]$JobKey)
  if (!(Test-Path $LogRoot)) { New-Item -ItemType Directory -Path $LogRoot | Out-Null }
  $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
  return Join-Path $LogRoot "$JobKey`_$stamp.log"
}

function Invoke-RobocopyJob {
  param(
    [string]$JobKey,
    [hashtable]$Meta,
    [hashtable]$Job,
    [switch]$DryRun
  )

  $logRoot = Expand-EnvPath $Meta.log_root
  $logFile = Get-LogFile -LogRoot $logRoot -JobKey $JobKey

  if ($Job.enabled -ne $true) {
    Write-Log "[SKIP] $JobKey disabled" $logFile
    return 0
  }

  $src = Expand-EnvPath $Job.source
  $dst = Expand-EnvPath $Job.dest

  if (!(Test-Path $src)) {
    Write-Log "[ERROR] Source not found: $src" $logFile
    return 2
  }

  $defaultFlags = @()
  if ($Meta.default_flags) { $defaultFlags = @($Meta.default_flags) }

  $jobFlags = @()
  if ($Job.flags) { $jobFlags = @($Job.flags) }

  $flags = @()
  $flags += $defaultFlags
  $flags += $jobFlags

  if ($DryRun) { $flags += "/L" } # list-only (dry-run)

  Write-Log "Job: $JobKey" $logFile
  Write-Log "Source: $src" $logFile
  Write-Log "Dest:   $dst" $logFile
  Write-Log "Flags:  $($flags -join ' ')" $logFile

  $args = @($src, $dst) + $flags + @("/LOG+:$logFile")

  # Run robocopy
  try {
    & robocopy @args | Out-Null
    $rc = $LASTEXITCODE
  }
  catch {
    Write-Log "[FAIL] Robocopy execution failed: $($_.Exception.Message)" $logFile
    return 99
  }

  # Robocopy exit codes: 0–7 are generally “success with info”; >=8 indicates failure.
  if ($rc -ge 8) {
    Write-Log "[FAIL] Robocopy exit code: $rc" $logFile
    return $rc
  }

  Write-Log "[OK] Robocopy exit code: $rc" $logFile
  return 0
}

# Main
if (!(Test-Path $ConfigPath)) { throw "Config not found: $ConfigPath" }

$cfg = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json -AsHashtable
$meta = $cfg.meta
$jobs = $cfg.backup_jobs

$anyFail = $false
foreach ($key in $jobs.Keys) {
  $rc = Invoke-RobocopyJob -JobKey $key -Meta $meta -Job $jobs[$key] -DryRun:$DryRun
  if ($rc -ne 0) { $anyFail = $true }
}

if ($anyFail) { exit 2 }
exit 0