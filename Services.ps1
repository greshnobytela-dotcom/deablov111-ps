#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Сводка для скриншара: SERVICE STATUS (компактный список),
  загрузка/аптайм, диски, реестр, история событий.
  by DEABLOV111
#>

$ErrorActionPreference = 'Continue'

function Write-Header([string]$Text) {
    Write-Host ''
    Write-Host $Text -ForegroundColor Cyan
}

function Write-KV([string]$Key, [string]$Value, [ConsoleColor]$Color = 'White') {
    Write-Host ("  {0,-28}" -f $Key) -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor $Color
}

function Get-FriendlyUptime([TimeSpan]$Span) {
    '{0}д {1:D2}ч {2:D2}м {3:D2}с' -f $Span.Days, $Span.Hours, $Span.Minutes, $Span.Seconds
}

function Get-TruncatedText([string]$Text, [int]$Max) {
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    if ($Text.Length -le $Max) { return $Text }
    if ($Max -le 3) { return $Text.Substring(0, $Max) }
    return $Text.Substring(0, $Max - 3) + '...'
}

$script:procStartCache = @{}

function Get-ServiceStartTime([string]$ServiceName) {
    try {
        $wmi = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f ($ServiceName -replace "'", "\'")) -ErrorAction Stop
        if (-not $wmi -or $wmi.State -ne 'Running' -or [int]$wmi.ProcessId -le 0) { return $null }

        $procId = [int]$wmi.ProcessId
        if (-not $script:procStartCache.ContainsKey($procId)) {
            $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
            if ($proc -and $proc.StartTime) {
                $script:procStartCache[$procId] = $proc.StartTime
            } else {
                return $null
            }
        }
        return $script:procStartCache[$procId]
    }
    catch { return $null }
}

function Resolve-Service([string]$Name) {
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like "$Name*" -or $_.Name -like "$Name_*"
        } | Select-Object -First 1
    }
    return $svc
}

function Get-BamStatus {
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\bam'
    if (-not (Test-Path $path)) {
        return @{ Ok = $false; Text = 'Missing'; Display = 'Background Activity Moderator Driver' }
    }
    try {
        $bp = Get-ItemProperty $path
        $start = [int]$bp.Start
        # 0 Boot / 1 System / 2 Auto = enabled; 4 = disabled
        $ok = $start -ne 4
        return @{
            Ok      = $ok
            Text    = $(if ($ok) { 'Enabled' } else { 'Disabled' })
            Display = 'Background Activity Moderator Driver'
        }
    }
    catch {
        return @{ Ok = $false; Text = 'Error'; Display = 'Background Activity Moderator Driver' }
    }
}

# Компактный список как на скрине — только нужное для скриншара
$WatchServices = [ordered]@{
    'SysMain'    = 'SysMain'
    'PcaSvc'     = 'Служба помощника по совместимости программ'
    'DPS'        = 'Служба политики диагностики'
    'EventLog'   = 'Журнал событий Windows'
    'Schedule'   = 'Планировщик задач'
    'Bam'        = 'Background Activity Moderator Driver'
    'DusmSvc'    = 'Использование данных'
    'AppInfo'    = 'Сведения о приложении'
    'CDPSvc'     = 'Служба платформы подключенных устройств'
    'DcomLaunch' = 'Модуль запуска процессов DCOM-сервера'
    'PlugPlay'   = 'Plug and Play'
    'WSearch'    = 'Windows Search'
    'DiagTrack'  = 'Функциональные возможности для подключенных пользователей и телеметрия'
    'Power'      = 'Питание'
}

function Write-ServiceStatusLine {
    param(
        [string]$Name,
        [string]$Display,
        [bool]$Ok,
        [string]$Right
    )

    $color = if ($Ok) { 'Green' } else { 'Red' }
    $left  = '{0,-14}' -f $Name
    $mid   = '{0,-48}' -f (Get-TruncatedText $Display 48)
    Write-Host ("{0} {1} | {2}" -f $left, $mid, $Right) -ForegroundColor $color
}

Write-Host ''
Write-Host ('by DEABLOV111') -ForegroundColor DarkGray
Write-KV 'Компьютер' $env:COMPUTERNAME
Write-KV 'Пользователь' $env:USERNAME
Write-KV 'Сейчас' (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Write-Header 'SERVICE STATUS'

foreach ($name in $WatchServices.Keys) {
    $fallbackDisplay = $WatchServices[$name]

    if ($name -eq 'Bam') {
        $bam = Get-BamStatus
        Write-ServiceStatusLine -Name 'Bam' -Display $bam.Display -Ok $bam.Ok -Right $bam.Text
        continue
    }

    $svc = Resolve-Service $name
    if (-not $svc) {
        Write-ServiceStatusLine -Name $name -Display $fallbackDisplay -Ok $false -Right 'Missing'
        continue
    }

    $display = if ($svc.DisplayName) { $svc.DisplayName } else { $fallbackDisplay }
    $running = ($svc.Status -eq 'Running')
    $disabled = ($svc.StartType -eq 'Disabled')

    if ($running) {
        $started = Get-ServiceStartTime -ServiceName $svc.Name
        $right = if ($started) { $started.ToString('HH:mm:ss') } else { (Get-Date).ToString('HH:mm:ss') }
        Write-ServiceStatusLine -Name $svc.Name -Display $display -Ok $true -Right $right
    }
    elseif ($disabled) {
        Write-ServiceStatusLine -Name $svc.Name -Display $display -Ok $false -Right 'Disabled'
    }
    else {
        Write-ServiceStatusLine -Name $svc.Name -Display $display -Ok $false -Right 'Stopped'
    }
}

Write-Header 'BOOT / UPTIME'

$boot = $null
try { $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime }
catch {
    try { $boot = [Management.ManagementDateTimeConverter]::ToDateTime((Get-WmiObject Win32_OperatingSystem).LastBootUpTime) } catch {}
}

if ($boot) {
    Write-KV 'Последняя загрузка' ($boot.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-KV 'Аптайм' (Get-FriendlyUptime ((Get-Date) - $boot)) Cyan
} else {
    Write-KV 'Последняя загрузка' 'Недоступно' Yellow
}

try {
    $csr = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -ErrorAction SilentlyContinue
    if ($null -ne $csr.HiberbootEnabled) {
        $hb = if ($csr.HiberbootEnabled -eq 1) { 'ON (быстрый запуск)' } else { 'OFF' }
        $color = if ($csr.HiberbootEnabled -eq 1) { 'Yellow' } else { 'Green' }
        Write-KV 'Hiberboot' $hb $color
    }
}
catch {}

Write-Header 'DISKS'

Get-CimInstance Win32_LogicalDisk | Sort-Object DeviceID | ForEach-Object {
    $sizeGB = if ($_.Size) { '{0:N1} ГБ' -f ($_.Size / 1GB) } else { '—' }
    $freeGB = if ($_.FreeSpace) { '{0:N1} ГБ' -f ($_.FreeSpace / 1GB) } else { '—' }
    $label  = if ($_.VolumeName) { $_.VolumeName } else { '(без метки)' }
    $fs     = if ($_.FileSystem) { $_.FileSystem } else { '?' }
    Write-Host ("  {0}  {1,-18}  {2,-6}  {3,-10} free {4}" -f $_.DeviceID, $label, $fs, $sizeGB, $freeGB)
}

Write-Header 'BAM / PREFETCH'

$bamSvcPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\bam'
$bamUserPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings'
$bamUserPathAlt = 'HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings'
$startMap = @{ 0 = 'Boot'; 1 = 'System'; 2 = 'Automatic'; 3 = 'Manual'; 4 = 'Disabled' }

if (Test-Path $bamSvcPath) {
    try {
        $bp = Get-ItemProperty $bamSvcPath
        $st = if ($null -ne $bp.Start -and $startMap.ContainsKey([int]$bp.Start)) { $startMap[[int]$bp.Start] } else { "$($bp.Start)" }
        $color = if ("$st" -eq 'Disabled') { 'Red' } else { 'Green' }
        Write-KV 'bam Start' $st $color
    }
    catch { Write-KV 'bam' 'не прочитан' Yellow }
} else {
    Write-KV 'bam' 'ключ отсутствует' Red
}

$userRoot = $null
if (Test-Path $bamUserPath) { $userRoot = $bamUserPath }
elseif (Test-Path $bamUserPathAlt) { $userRoot = $bamUserPathAlt }

if ($userRoot) {
    $sids = @(Get-ChildItem $userRoot -ErrorAction SilentlyContinue)
    $entryCount = 0
    foreach ($sidKey in $sids) {
        $props = Get-ItemProperty $sidKey.PSPath -ErrorAction SilentlyContinue
        if ($props) {
            $entryCount += @($props.PSObject.Properties | Where-Object {
                $_.Name -notmatch '^PS' -and $_.Name -ne '(default)'
            }).Count
        }
    }
    Write-KV 'UserSettings' ("{0} SID, {1} записей" -f $sids.Count, $entryCount) $(if ($entryCount -eq 0) { 'Yellow' } else { 'Green' })
} else {
    Write-KV 'UserSettings' 'нет / очищен' Red
}

function Show-RegDword([string]$Path, [string]$Name, [string]$Label) {
    try {
        if (-not (Test-Path $Path)) {
            Write-KV $Label 'путь отсутствует' Yellow
            return
        }
        $val = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
        $color = 'White'
        if ($Name -match 'EnablePrefetcher|EnableSuperfetch' -and $val -eq 0) { $color = 'Red' }
        elseif ($Name -match 'EnablePrefetcher|EnableSuperfetch' -and $val -ge 1) { $color = 'Green' }
        Write-KV $Label ("$Name = $val") $color
    }
    catch {
        Write-KV $Label 'не задано' Yellow
    }
}

Show-RegDword 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher' 'Prefetcher'
Show-RegDword 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnableSuperfetch' 'Superfetch'

$pf = Join-Path $env:SystemRoot 'Prefetch'
if (Test-Path $pf) {
    $pfItem = Get-Item $pf -Force
    $count = @(Get-ChildItem $pf -Filter *.pf -ErrorAction SilentlyContinue).Count
    $ro = [bool]($pfItem.Attributes -band [IO.FileAttributes]::ReadOnly)
    Write-KV 'Prefetch folder' ("$count .pf | ReadOnly=$ro") $(if ($ro) { 'Red' } else { 'Green' })
} else {
    Write-KV 'Prefetch folder' 'ОТСУТСТВУЕТ' Red
}

Write-Header 'EVENT HISTORY'

function Get-WinEventsSafe {
    param([string]$LogName, [string]$FilterXPath, [int]$MaxEvents = 15)
    try { Get-WinEvent -LogName $LogName -FilterXPath $FilterXPath -MaxEvents $MaxEvents -ErrorAction Stop }
    catch { @() }
}

Write-Host '  Очистки (Security 1102 / System 104):' -ForegroundColor DarkGray
$clears = @()
$clears += Get-WinEventsSafe -LogName 'Security' -FilterXPath '*[System[(EventID=1102)]]' -MaxEvents 8
$clears += Get-WinEventsSafe -LogName 'System'   -FilterXPath '*[System[(EventID=104)]]'  -MaxEvents 8

if ($clears.Count -eq 0) {
    Write-Host '    (не найдено)' -ForegroundColor DarkGray
} else {
    $clears | Sort-Object TimeCreated -Descending | Select-Object -First 10 | ForEach-Object {
        Write-Host ("    {0:yyyy-MM-dd HH:mm:ss}  {1}  ID={2}" -f $_.TimeCreated, $_.LogName, $_.Id) -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host '  Выключения / BSOD (41, 6008, 1074, 6006, 6005):' -ForegroundColor DarkGray
$shutdownFilter = '*[System[(EventID=41 or EventID=6008 or EventID=1074 or EventID=6006 or EventID=6005)]]'
$shutdowns = Get-WinEventsSafe -LogName 'System' -FilterXPath $shutdownFilter -MaxEvents 12
if ($shutdowns.Count -eq 0) {
    Write-Host '    (не найдено)' -ForegroundColor DarkGray
} else {
    foreach ($e in $shutdowns) {
        $color = if ($e.Id -in 41, 6008) { 'Red' } else { 'Gray' }
        $msg = ($e.Message -split "`n")[0]
        if ($msg.Length -gt 80) { $msg = $msg.Substring(0, 80) + '...' }
        Write-Host ("    {0:yyyy-MM-dd HH:mm:ss}  ID={1,-5}  {2}" -f $e.TimeCreated, $e.Id, $msg) -ForegroundColor $color
    }
}

Write-Host ''
Write-Host '  Смена времени (System 1 / Security 4616):' -ForegroundColor DarkGray
$timeEv = @()
$timeEv += Get-WinEventsSafe -LogName 'System'   -FilterXPath '*[System[(EventID=1)] and System[Provider[@Name="Microsoft-Windows-Kernel-General"]]]' -MaxEvents 8
$timeEv += Get-WinEventsSafe -LogName 'Security' -FilterXPath '*[System[(EventID=4616)]]' -MaxEvents 8

if ($timeEv.Count -eq 0) {
    Write-Host '    (не найдено)' -ForegroundColor DarkGray
} else {
    $timeEv | Sort-Object TimeCreated -Descending | Select-Object -First 10 | ForEach-Object {
        Write-Host ("    {0:yyyy-MM-dd HH:mm:ss}  {1}  ID={2}" -f $_.TimeCreated, $_.LogName, $_.Id) -ForegroundColor Magenta
    }
}

Write-Host ''
Write-Host 'by DEABLOV111' -ForegroundColor DarkGray
Write-Host 'Если службы отключены — сначала Service-Enabler.ps1 от админа.' -ForegroundColor DarkGray
Write-Host ''
