# Purpose: Expand environment variables in a path string
function Expand-EnvPath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
  return [Environment]::ExpandEnvironmentVariables($Path)
}


# Purpose: Convert a path to a normalized full path without trailing separators
function Get-NormalizedPath {
  param([string]$Path)
  $expandedPath = Expand-EnvPath -Path $Path
  if ([string]::IsNullOrWhiteSpace($expandedPath)) { return $expandedPath }
  return [System.IO.Path]::GetFullPath($expandedPath).TrimEnd('\', '/')
}

# Purpose: Detect unsafe source and destination path overlap
function Test-PathConflict {
  param(
    [string]$SourcePath,
    [string]$DestPath
  )
  try {
    $srcFull = Get-NormalizedPath -Path $SourcePath
    $dstFull = Get-NormalizedPath -Path $DestPath
    if ([string]::IsNullOrWhiteSpace($srcFull) -or [string]::IsNullOrWhiteSpace($dstFull)) { return $true }
    $srcCompare = $srcFull.ToLowerInvariant()
    $dstCompare = $dstFull.ToLowerInvariant()
    if ($srcCompare -eq $dstCompare) { return $true }
    if ($dstCompare.StartsWith($srcCompare + '\')) { return $true }
    if ($srcCompare.StartsWith($dstCompare + '\')) { return $true }
    return $false
  } catch {
    return $true
  }
}


Export-ModuleMember -Function Test-PathConflict, Expand-EnvPath, Get-NormalizedPath