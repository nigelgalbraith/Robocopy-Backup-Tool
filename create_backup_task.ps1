$taskName = "RobocopyBackup"
$scriptPath = Join-Path $PSScriptRoot "robocopy_backup.ps1"

$action = New-ScheduledTaskAction `    -Execute "pwsh.exe"`
-Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger -Daily -At 2am

Register-ScheduledTask `    -TaskName $taskName`
-Action $action `    -Trigger $trigger`
-Description "Automated Robocopy Backup"

Write-Host "Scheduled task '$taskName' created."
