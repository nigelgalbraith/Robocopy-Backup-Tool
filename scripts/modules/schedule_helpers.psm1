# Purpose: Parse validated HH:MM time string into DateTime for scheduling
function ConvertTo-ScheduleTime {
  param([string]$TimeStr)
  $parts = $TimeStr.Split(':')
  return (Get-Date -Hour ([int]$parts[0]) -Minute ([int]$parts[1]) -Second 0)
}

Export-ModuleMember -Function ConvertTo-ScheduleTime
