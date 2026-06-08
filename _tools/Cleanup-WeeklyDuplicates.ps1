# Cleanup-WeeklyDuplicates.ps1
# Lives in _tools\. Operates on ..\dashboards\, archives older same-week
# duplicates into ..\_superseded\. Re-runs are safe.

try {

if ($PSScriptRoot) { $tools = $PSScriptRoot }
elseif ($MyInvocation.MyCommand.Path) { $tools = Split-Path -Parent $MyInvocation.MyCommand.Path }
else { $tools = (Get-Location).Path }

$root       = Split-Path -Parent $tools
$dashboards = Join-Path $root 'dashboards'
$archive    = Join-Path $root '_superseded'

Write-Host ""
Write-Host "Scanning: $dashboards" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $dashboards)) {
    Write-Host "Dashboards folder not found at: $dashboards" -ForegroundColor Yellow
    Read-Host "Press Enter to continue"
    return
}

$files = @(Get-ChildItem -Path $dashboards -Filter *.html -File)
Write-Host ("Found {0} HTML dashboard file(s) to consider." -f $files.Count)

if ($files.Count -eq 0) {
    Write-Host "Nothing to do." -ForegroundColor Yellow
    Read-Host "Press Enter to continue"
    return
}

function Get-IsoWeek([datetime]$d) {
    $cal  = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
    $rule = [System.Globalization.CalendarWeekRule]::FirstFourDayWeek
    $cal.GetWeekOfYear($d, $rule, [DayOfWeek]::Monday)
}

$records = foreach ($f in $files) {
    if ($f.BaseName -match '^\d{13}$') {
        $dt = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$f.BaseName).LocalDateTime
    } else {
        $dt = $f.LastWriteTime
    }
    [PSCustomObject]@{
        File     = $f
        DateTime = $dt
        IsoKey   = '{0}-W{1:00}' -f $dt.Year, (Get-IsoWeek $dt)
    }
}

$groups = @($records | Group-Object IsoKey)
$toMove = @()
$kept   = @()
foreach ($g in $groups) {
    $sorted = @($g.Group | Sort-Object DateTime -Descending)
    $kept  += $sorted[0]
    if ($sorted.Count -gt 1) {
        $toMove += $sorted[1..($sorted.Count - 1)]
    }
}

Write-Host ""
Write-Host "=== Plan ===" -ForegroundColor Cyan
Write-Host ("Weeks found:    {0}" -f $groups.Count)
Write-Host ("Will KEEP:      {0} (newest per week)" -f $kept.Count) -ForegroundColor Green
Write-Host ("Will ARCHIVE:   {0} (older duplicates)" -f $toMove.Count) -ForegroundColor Yellow
Write-Host ""

Write-Host "Details:" -ForegroundColor Cyan
foreach ($g in $groups) {
    $sorted = @($g.Group | Sort-Object DateTime -Descending)
    Write-Host ("  {0}" -f $g.Name) -ForegroundColor White
    for ($i = 0; $i -lt $sorted.Count; $i++) {
        if ($i -eq 0) { $tag = 'KEEP    '; $col = 'Green' }
        else          { $tag = 'archive '; $col = 'Yellow' }
        Write-Host ("    [{0}] {1}  ({2:yyyy-MM-dd HH:mm})" -f $tag, $sorted[$i].File.Name, $sorted[$i].DateTime) -ForegroundColor $col
    }
}

if ($toMove.Count -eq 0) {
    Write-Host ""
    Write-Host "Nothing to clean. Every week already has exactly one file." -ForegroundColor Green
    Read-Host "Press Enter to continue"
    return
}

Write-Host ""
$confirm = Read-Host "Proceed with archive? (Y/N)"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "Aborted. Nothing moved." -ForegroundColor Yellow
    Read-Host "Press Enter to continue"
    return
}

if (-not (Test-Path -LiteralPath $archive)) {
    New-Item -ItemType Directory -Path $archive | Out-Null
}

foreach ($r in $toMove) {
    $dest = Join-Path $archive $r.File.Name
    if (Test-Path -LiteralPath $dest) {
        $stamp = Get-Date -Format 'yyyyMMddHHmmss'
        $dest = Join-Path $archive ($r.File.BaseName + '_' + $stamp + $r.File.Extension)
    }
    Move-Item -LiteralPath $r.File.FullName -Destination $dest
    Write-Host ("  moved -> {0}" -f (Split-Path $dest -Leaf))
}

Write-Host ""
Write-Host ("Done. {0} file(s) moved to:" -f $toMove.Count) -ForegroundColor Green
Write-Host ("  {0}" -f $archive)
Read-Host "Press Enter to continue"

}
catch {
    Write-Host ""
    Write-Host "=== ERROR ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ($_ | Out-String)
    Read-Host "Press Enter to continue"
}
