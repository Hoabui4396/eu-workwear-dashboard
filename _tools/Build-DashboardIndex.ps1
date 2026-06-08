# Build-DashboardIndex.ps1
# Lives in _tools\. Scans ..\dashboards\ for HTML files and writes
# ..\_Dashboard_Index.html with relative links into dashboards\.

try {

if ($PSScriptRoot) { $tools = $PSScriptRoot }
elseif ($MyInvocation.MyCommand.Path) { $tools = Split-Path -Parent $MyInvocation.MyCommand.Path }
else { $tools = (Get-Location).Path }

$root       = Split-Path -Parent $tools
$dashboards = Join-Path $root 'dashboards'
$indexPath  = Join-Path $root '_Dashboard_Index.html'

if (-not (Test-Path -LiteralPath $dashboards)) {
    Write-Host "Dashboards folder not found at: $dashboards" -ForegroundColor Yellow
    Read-Host "Press Enter to continue"
    return
}

$files = @(Get-ChildItem -Path $dashboards -Filter *.html -File)
if ($files.Count -eq 0) {
    Write-Host "No HTML dashboards found in: $dashboards" -ForegroundColor Yellow
    Read-Host "Press Enter to continue"
    return
}

function Get-IsoWeek([datetime]$d) {
    $cal  = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
    $rule = [System.Globalization.CalendarWeekRule]::FirstFourDayWeek
    $cal.GetWeekOfYear($d, $rule, [DayOfWeek]::Monday)
}

$rows = foreach ($f in $files) {
    if ($f.BaseName -match '^\d{13}$') {
        $dt = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$f.BaseName).LocalDateTime
    } else {
        $dt = $f.LastWriteTime
    }
    [PSCustomObject]@{
        File     = $f.Name
        DateTime = $dt
        SizeKB   = [math]::Round($f.Length / 1KB, 0)
    }
}
$rows = @($rows | Sort-Object DateTime -Descending)

$rowsHtml = New-Object System.Text.StringBuilder
$i = 0
foreach ($r in $rows) {
    $i++
    if ($i -eq 1) { $latestBadge = '<span class="badge">LATEST</span>' } else { $latestBadge = '' }
    $dateStr  = $r.DateTime.ToString('dddd, d MMM yyyy')
    $timeStr  = $r.DateTime.ToString('HH:mm')
    $week     = Get-IsoWeek $r.DateTime
    $hrefSafe = 'dashboards/' + [uri]::EscapeDataString($r.File)
    $null = $rowsHtml.AppendLine('    <tr onclick="window.location=''' + $hrefSafe + '''">')
    $null = $rowsHtml.AppendLine('      <td class="week">W' + $week + '</td>')
    $null = $rowsHtml.AppendLine('      <td class="date">' + $dateStr + ' ' + $latestBadge + '<br><span class="time">' + $timeStr + '</span></td>')
    $null = $rowsHtml.AppendLine('      <td class="size">' + $r.SizeKB + ' KB</td>')
    $null = $rowsHtml.AppendLine('      <td class="open"><a href="' + $hrefSafe + '">Open &rsaquo;</a></td>')
    $null = $rowsHtml.AppendLine('    </tr>')
}

$generated = (Get-Date).ToString('dddd, d MMMM yyyy HH:mm')

$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>EU Workwear Dashboards - Weekly Index</title>
<style>
  :root { --ink:#1a1a1a; --muted:#6b7280; --line:#e5e7eb; --accent:#0b4d8c; --hover:#f3f6fb; }
  * { box-sizing:border-box; }
  body { font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; color:var(--ink); margin:0; padding:32px 40px; background:#fafafa; }
  header { display:flex; justify-content:space-between; align-items:baseline; border-bottom:2px solid var(--accent); padding-bottom:12px; margin-bottom:24px; }
  h1 { font-size:22px; margin:0; letter-spacing:-0.01em; }
  .brand { color:var(--accent); font-weight:600; }
  .meta { color:var(--muted); font-size:12px; }
  table { width:100%; border-collapse:collapse; background:white; box-shadow:0 1px 3px rgba(0,0,0,.06); border-radius:6px; overflow:hidden; }
  thead th { text-align:left; font-size:11px; text-transform:uppercase; letter-spacing:.05em; color:var(--muted); padding:12px 16px; border-bottom:1px solid var(--line); background:#fbfbfb; }
  tbody tr { cursor:pointer; transition:background .12s; border-bottom:1px solid var(--line); }
  tbody tr:hover { background:var(--hover); }
  tbody tr:last-child { border-bottom:none; }
  td { padding:14px 16px; font-size:14px; vertical-align:middle; }
  td.week { font-weight:700; color:var(--accent); width:70px; }
  td.date { width:280px; }
  td.file { font-family: ui-monospace, Consolas, monospace; font-size:12px; color:var(--muted); }
  td.size { width:70px; color:var(--muted); font-size:12px; }
  td.open { width:90px; text-align:right; }
  td.open a { color:var(--accent); text-decoration:none; font-weight:600; }
  .time { color:var(--muted); font-size:12px; }
  .badge { background:var(--accent); color:white; font-size:10px; font-weight:700; padding:2px 8px; border-radius:3px; margin-left:8px; letter-spacing:.05em; vertical-align:middle; }
  footer { margin-top:20px; color:var(--muted); font-size:11px; text-align:right; }
</style>
</head>
<body>
  <header>
    <h1><span class="brand">Buikaelements</span> &middot; EU Workwear Dashboards</h1>
    <span class="meta">$($rows.Count) week(s) &middot; click any row to open</span>
  </header>
  <table>
    <thead>
      <tr><th>Week</th><th>Date</th><th>Size</th><th></th></tr>
    </thead>
    <tbody>
$($rowsHtml.ToString())
    </tbody>
  </table>
  <footer>Index generated $generated</footer>
</body>
</html>
"@

$html | Set-Content -Path $indexPath -Encoding UTF8
Write-Host "Index written: $indexPath" -ForegroundColor Green
Start-Process $indexPath

}
catch {
    Write-Host ""
    Write-Host "=== ERROR ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host ($_ | Out-String)
    Read-Host "Press Enter to continue"
}
