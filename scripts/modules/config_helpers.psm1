Import-Module (Join-Path $PSScriptRoot "schedule_helpers.psm1") -Force -Function Test-TimeString

# Purpose: Read and parse the JSON config file
function Read-Config {
  param([string]$Path)
  if (!(Test-Path -LiteralPath $Path)) { throw "Config not found: $Path" }
  try {
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json)
  } catch {
    throw "Failed to read config '$Path': $($_.Exception.Message)"
  }
}

# Purpose: Resolve the scheduled task name with a default fallback
function Get-TaskName {
  param([object]$Config)
  $taskName = Get-ConfigValue -InputObject $Config -Path 'meta.task_name'
  if ([string]::IsNullOrWhiteSpace([string]$taskName)) { return 'RobocopyBackup' }
  return [string]$taskName
}


# Purpose: Read a nested value from an object using a dot path
function Get-ConfigValue {
  param(
    [object]$InputObject,
    [string]$Path
  )
  $current = $InputObject
  foreach ($part in ($Path -split '\.')) {
    if ($null -eq $current) { return $null }
    if ($current -is [System.Collections.IDictionary]) {
      if (!$current.Contains($part)) { return $null }
      $current = $current[$part]
      continue
    }
    $property = $current.PSObject.Properties[$part]
    if ($null -eq $property) { return $null }
    $current = $property.Value
  }
  return $current
}

# Purpose: Resolve and normalize the configured log root path
function Get-LogRoot {
  param([object]$Config)
  return (Get-NormalizedPath -Path (Get-ConfigValue -InputObject $Config -Path 'meta.log_root'))
}

# Purpose: Validate config values against required path and type checks
function Test-ConfigValues {
  param(
    [object]$Config,
    [array]$Checks,
    [switch]$VerboseOutput
  )
  foreach ($check in $Checks) {
    $path = $check.Path
    $required = $check.Required
    $type = $check.Type
    if ($VerboseOutput) { Write-Host "[CHECK] Path='$path' Required=$required Type=$type" }
    $value = Get-ConfigValue -InputObject $Config -Path $path
    if ($required -and $null -eq $value) { throw "Missing required config value: $path" }
    if ($null -eq $value) {
      if ($VerboseOutput) { Write-Host "[SKIP] Optional value not present: $path" }
      continue
    }
    switch ($type) {
      'string' {
        if ([string]::IsNullOrWhiteSpace([string]$value)) { throw "Config value must not be blank: $path" }
      }
      'array' {
        if ($value -isnot [System.Array]) { throw "Config value must be an array: $path" }
      }
      'int' {
        $tmp = 0
        if (-not [int]::TryParse([string]$value, [ref]$tmp)) { throw "Config value must be an integer: $path" }
      }
      'bool' {
        if ($value -isnot [bool]) { throw "Config value must be a boolean: $path" }
      }
      'object' {
        if ($value -isnot [psobject] -and $value -isnot [hashtable]) { throw "Config value must be an object: $path" }
      }
      default {
        throw "Unsupported validation type '$type' for path '$path'"
      }
    }
    if ($VerboseOutput) { Write-Host "[OK] $path" }
  }
}

# Purpose: Validate the full backup configuration structure and values
function Test-BackupConfig {
  param([object]$Config)
  # --- Validate inputs ---
  Test-ConfigValues -Config $Config -Checks @(
    @{ Path = 'meta'; Required = $true; Type = 'object' },
    @{ Path = 'meta.log_root'; Required = $true; Type = 'string' },
    @{ Path = 'meta.default_flags'; Required = $false; Type = 'array' },
    @{ Path = 'meta.delaySeconds'; Required = $false; Type = 'int' },
    @{ Path = 'meta.schedule'; Required = $true; Type = 'object' },
    @{ Path = 'meta.schedule.type'; Required = $true; Type = 'string' },
    @{ Path = 'meta.schedule.time'; Required = $true; Type = 'string' },
    @{ Path = 'backup_jobs'; Required = $true; Type = 'object' }
  )
  $taskName = Get-ConfigValue -InputObject $Config -Path 'meta.task_name'
  if ($null -ne $taskName -and [string]::IsNullOrWhiteSpace([string]$taskName)) {
    throw 'Config value must not be blank: meta.task_name'
  }
  Test-StringArray -Value (Get-ConfigValue -InputObject $Config -Path 'meta.default_flags') -Path 'meta.default_flags'
  $delaySeconds = [int](Get-ConfigValue -InputObject $Config -Path 'meta.delaySeconds')
  if ($delaySeconds -lt 0) { throw 'Config value meta.delaySeconds must be zero or greater.' }
  # Enforce supported schedule type to prevent unsupported trigger handling
  $scheduleType = [string](Get-ConfigValue -InputObject $Config -Path 'meta.schedule.type')
  if ($scheduleType -ne 'daily') { throw "Unsupported schedule.type '$scheduleType'. Use 'daily'." }
  $scheduleTime = [string](Get-ConfigValue -InputObject $Config -Path 'meta.schedule.time')
  if (-not (Test-TimeString -TimeStr $scheduleTime)) {
    throw "Invalid schedule time '$scheduleTime' (expected HH:MM, 24-hour)."
  }
  $jobs = Get-ConfigValue -InputObject $Config -Path 'backup_jobs'
  if ($jobs.PSObject.Properties.Count -eq 0) { throw 'Config must contain at least one backup job.' }
  # --- Validate per-job settings ---
  foreach ($prop in $jobs.PSObject.Properties) {
    $jobPath = "backup_jobs.$($prop.Name)"
    Test-ConfigValues -Config $prop.Value -Checks @(
      @{ Path = 'enabled'; Required = $true; Type = 'bool' },
      @{ Path = 'source'; Required = $true; Type = 'string' },
      @{ Path = 'dest'; Required = $true; Type = 'string' },
      @{ Path = 'flags'; Required = $false; Type = 'array' }
    )
    Test-StringArray -Value (Get-ConfigValue -InputObject $prop.Value -Path 'flags') -Path "$jobPath.flags"
  }
}

# Purpose: Validate only schedule-related config values
function Test-ScheduleConfig {
  param([object]$Config)
  Test-ConfigValues -Config $Config -Checks @(
    @{ Path = 'meta.schedule'; Required = $true; Type = 'object' },
    @{ Path = 'meta.schedule.type'; Required = $true; Type = 'string' },
    @{ Path = 'meta.schedule.time'; Required = $true; Type = 'string' }
  )
  $type = Get-ConfigValue -InputObject $Config -Path 'meta.schedule.type'
  if ($type -ne 'daily') { throw "Unsupported schedule.type '$type'" }
  $time = Get-ConfigValue -InputObject $Config -Path 'meta.schedule.time'
  if (-not (Test-TimeString -TimeStr $time)) {
    throw "Invalid schedule time '$time'"
  }
}


# Purpose: Validate only log-related config values
function Test-LogConfig {
  param([object]$Config)
  Test-ConfigValues -Config $Config -Checks @(
    @{ Path = 'meta.log_root'; Required = $true; Type = 'string' }
  )
}


# Purpose: Validate that a value is an array of non-blank strings
function Test-StringArray {
  param(
    [object]$Value,
    [string]$Path
  )
  if ($null -eq $Value) { return }
  if ($Value -isnot [System.Array]) { throw "Config value must be an array: $Path" }
  foreach ($item in $Value) {
    if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) {
      throw "Config array '$Path' must contain only non-blank strings."
    }
  }
}

Export-ModuleMember -Function Read-Config, Get-ConfigValue, Test-ConfigValues, Test-StringArray, Test-BackupConfig, Test-ScheduleConfig, Test-LogConfig, Get-TaskName, Get-LogRoot, ConvertTo-ScheduleTime