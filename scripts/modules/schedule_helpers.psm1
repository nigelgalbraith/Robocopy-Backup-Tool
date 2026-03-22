# Purpose: Parse validated HH:MM time string into DateTime for scheduling
function ConvertTo-ScheduleTime {
  param([string]$TimeStr)
  if (-not (Test-TimeString -TimeStr $TimeStr)) {
    throw "Invalid schedule time '$TimeStr'"
  }
  $parts = $TimeStr.Split(':')
  return (Get-Date -Hour ([int]$parts[0]) -Minute ([int]$parts[1]) -Second 0)
}

# Purpose: Validate time text in HH:MM 24-hour format
function Test-TimeString {
  param([string]$TimeStr)
  if ([string]::IsNullOrWhiteSpace($TimeStr)) { return $false }
  return ($TimeStr -match '^([01]\d|2[0-3]):[0-5]\d$')
}

Export-ModuleMember -Function ConvertTo-ScheduleTime, Test-TimeString