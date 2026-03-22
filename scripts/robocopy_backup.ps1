# IMPORTS
param(
  [string]$ConfigPath = (Join-Path (Join-Path $PSScriptRoot "..\config") "robocopy_backup_config.json"),
  [switch]$DryRun
)

Import-Module (Join-Path $PSScriptRoot "modules\config_helpers.psm1") -Force -Function Read-Config, Test-BackupConfig, Get-LogRoot
Import-Module (Join-Path $PSScriptRoot "modules\path_helpers.psm1") -Force -Function Expand-EnvPath, Get-NormalizedPath, Test-PathConflict

# LOGGING
# Purpose: Write a timestamped line to the run log and optionally the console
function Write-Log {
  param(
    [string]$Message,
    [string]$LogFile,
    [switch]$NoConsole
  )
  $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $line = "$ts : $Message"
  if (-not $NoConsole) { Write-Host $line }
  Add-Content -LiteralPath $LogFile -Value $line
}


# Purpose: Create a timestamped run log file path and ensure log root exists
function New-RunLogFile {
  param([string]$LogRoot)
  if (!(Test-Path -LiteralPath $LogRoot)) { New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null }
  $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
  return (Join-Path $LogRoot "backup_run_$stamp.log")
}


# BACKUP OPERATIONS
# Purpose: Map robocopy exit codes to normalized outcome values
function Get-RobocopyOutcome {
  param([int]$ExitCode)
  # Robocopy uses non-zero success and warning codes; 8+ indicates failure
  if ($ExitCode -ge 8) { return 'FAIL' }
  if ($ExitCode -eq 0) { return 'OK' }
  return 'WARN'
}


# LOGGING
# Purpose: Write a visual section boundary in the run log
function Start-LogSection {
  param(
    [string]$Title,
    [string]$LogFile
  )
  Write-Log ('=' * 78) -LogFile $LogFile
  Write-Log $Title -LogFile $LogFile
  Write-Log ('=' * 78) -LogFile $LogFile
}


# BACKUP OPERATIONS
# Purpose: Execute one backup job and write its result section to the run log
# BACKUP OPERATIONS
# Purpose: Validate job state and return skip result if disabled
function Test-JobEnabled {
  param([string]$JobKey, [object]$Job, [string]$LogFile)
  if ($Job.enabled -ne $true) {
    Write-Log '[SKIP] Job disabled.' -LogFile $LogFile
    return [pscustomobject]@{ JobKey = $JobKey; Outcome = 'SKIP'; ExitCode = 0; Message = 'Job disabled.' }
  }
  return $null
}


# Purpose: Resolve and normalize job paths
function Resolve-JobPaths {
  param([object]$Job, [string]$LogFile)
  try {
    $src = Get-NormalizedPath -Path $Job.source
    $dst = Get-NormalizedPath -Path $Job.dest
    return @{ Source = $src; Dest = $dst }
  } catch {
    Write-Log "[FAIL] Invalid source or destination path: $($_.Exception.Message)" -LogFile $LogFile
    return $null
  }
}


# Purpose: Validate source and destination paths
function Test-JobPaths {
  param([string]$JobKey, [string]$Src, [string]$Dst, [string]$LogFile)
  if (Test-PathConflict -SourcePath $Src -DestPath $Dst) {
    Write-Log '[FAIL] Unsafe source/destination relationship detected.' -LogFile $LogFile
    return [pscustomobject]@{ JobKey = $JobKey; Outcome = 'FAIL'; ExitCode = 2; Message = 'Unsafe source/destination relationship.' }
  }
  if (!(Test-Path -LiteralPath $Src)) {
    Write-Log "[FAIL] Source not found: $Src" -LogFile $LogFile
    return [pscustomobject]@{ JobKey = $JobKey; Outcome = 'FAIL'; ExitCode = 2; Message = 'Source not found.' }
  }
  if (!(Test-Path -LiteralPath $Dst)) {
    New-Item -ItemType Directory -Path $Dst -Force | Out-Null
    Write-Log '[INFO] Destination folder created.' -LogFile $LogFile
  }
  return $null
}


# Purpose: Build robocopy argument list
function Get-RobocopyArguments {
  param([object]$Meta, [object]$Job, [string]$Src, [string]$Dst, [string]$LogFile, [switch]$DryRun)
  $defaultFlags = @()
  if ($Meta.default_flags) { $defaultFlags = @($Meta.default_flags) }
  $jobFlags = @()
  if ($Job.flags) { $jobFlags = @($Job.flags) }
  $flags = @($defaultFlags + $jobFlags)
  if ($DryRun) { $flags += '/L' }
  Write-Log "Flags:  $($flags -join ' ')" -LogFile $LogFile
  return @($Src, $Dst) + $flags + @("/LOG+:$LogFile")
}


# Purpose: Execute robocopy and return outcome
function Invoke-Robocopy {
  param([string]$JobKey, [array]$Arguments, [string]$LogFile)
  try {
    & robocopy @Arguments | Out-Null
    $rc = $LASTEXITCODE
  } catch {
    Write-Log "[FAIL] Robocopy execution failed: $($_.Exception.Message)" -LogFile $LogFile
    return [pscustomobject]@{ JobKey = $JobKey; Outcome = 'FAIL'; ExitCode = 99; Message = 'Robocopy execution failed.' }
  }
  $outcome = Get-RobocopyOutcome -ExitCode $rc
  Write-Log "[${outcome}] Robocopy exit code: $rc" -LogFile $LogFile
  return [pscustomobject]@{ JobKey = $JobKey; Outcome = $outcome; ExitCode = $rc; Message = 'Completed.' }
}


# Purpose: Execute one backup job and write its result section to the run log
function Invoke-RobocopyJob {
  param(
    [string]$JobKey,
    [object]$Meta,
    [object]$Job,
    [string]$LogFile,
    [switch]$DryRun
  )
  Start-LogSection -Title "JOB: $JobKey" -LogFile $LogFile
  # --- Validate inputs ---
  $skip = Test-JobEnabled -JobKey $JobKey -Job $Job -LogFile $LogFile
  if ($skip) { return $skip }
  # --- Resolve paths ---
  $paths = Resolve-JobPaths -Job $Job -LogFile $LogFile
  if (-not $paths) {
    return [pscustomobject]@{ JobKey = $JobKey; Outcome = 'FAIL'; ExitCode = 99; Message = 'Invalid source or destination path.' }
  }
  $src = $paths.Source
  $dst = $paths.Dest
  Write-Log "Mode:   $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })" -LogFile $LogFile
  Write-Log "Source: $src" -LogFile $LogFile
  Write-Log "Dest:   $dst" -LogFile $LogFile
  # --- Validate paths ---
  $pathCheck = Test-JobPaths -JobKey $JobKey -Src $src -Dst $dst -LogFile $LogFile
  if ($pathCheck) { return $pathCheck }
  # --- Build arguments ---
  $arguments = Get-RobocopyArguments -Meta $Meta -Job $Job -Src $src -Dst $dst -LogFile $LogFile -DryRun:$DryRun
  # --- Execute ---
  return Invoke-Robocopy -JobKey $JobKey -Arguments $arguments -LogFile $LogFile
}


# Purpose: Write per-job outcomes and aggregate totals to the run log
function Write-RunSummary {
  param(
    [array]$Results,
    [string]$LogFile
  )
  # --- Build run summary ---
  Start-LogSection -Title 'RUN SUMMARY' -LogFile $LogFile
  foreach ($result in $Results) {
    Write-Log ("{0,-24} Outcome={1,-5} ExitCode={2,-3} Message={3}" -f $result.JobKey, $result.Outcome, $result.ExitCode, $result.Message) -LogFile $LogFile
  }
  $failed = @($Results | Where-Object { $_.Outcome -eq 'FAIL' }).Count
  $warnings = @($Results | Where-Object { $_.Outcome -eq 'WARN' }).Count
  $skipped = @($Results | Where-Object { $_.Outcome -eq 'SKIP' }).Count
  $ok = @($Results | Where-Object { $_.Outcome -eq 'OK' }).Count
  Write-Log "Totals: OK=$ok WARN=$warnings SKIP=$skipped FAIL=$failed" -LogFile $LogFile
}


# MAIN
# Purpose: Run all configured backup jobs and return process exit status
function Main {
  param(
    [string]$ConfigPath,
    [switch]$DryRun
  )
  # --- Validate inputs ---
  $resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
  $cfg = Read-Config -Path $resolvedConfigPath
  Test-BackupConfig -Config $cfg
  $meta = $cfg.meta
  $delaySeconds = [int]$meta.delaySeconds
  $logRoot = Get-LogRoot -Config $cfg
  if (!(Test-Path -LiteralPath $logRoot)) {
    New-Item -ItemType Directory -Path $logRoot | Out-Null
  }
  $runLog = New-RunLogFile -LogRoot $logRoot
  Start-LogSection -Title 'RUN START' -LogFile $runLog
  Write-Log "Config:  $resolvedConfigPath" -LogFile $runLog
  Write-Log "Mode:    $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })" -LogFile $runLog
  Write-Log "LogFile: $runLog" -LogFile $runLog
  # Honor configured delay to stagger backup start time when needed
  if ($delaySeconds -gt 0) {
    Write-Log "Delay:   $delaySeconds seconds" -LogFile $runLog
    Start-Sleep -Seconds $delaySeconds
  } else {
    Write-Log 'Delay:   0 seconds' -LogFile $runLog
  }
  # --- Write job section to run log ---
  $results = @()
  $jobs = $cfg.backup_jobs.PSObject.Properties
  foreach ($job in $jobs) {
    $results += Invoke-RobocopyJob -JobKey $job.Name -Meta $meta -Job $job.Value -LogFile $runLog -DryRun:$DryRun
  }
  Write-RunSummary -Results $results -LogFile $runLog
  $failed = @($results | Where-Object { $_.Outcome -eq 'FAIL' }).Count
  if ($failed -gt 0) {
    Write-Log 'Final result: FAIL' -LogFile $runLog
    return 2
  }
  Write-Log 'Final result: OK' -LogFile $runLog
  return 0
}


try {
  $code = Main -ConfigPath $ConfigPath -DryRun:$DryRun
  exit $code
} catch {
  Write-Host "[ERROR] $($_.Exception.Message)"
  exit 1
}
