#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Включает компактный набор служб для скриншара
  (EventLog, SysMain, BAM, DPS и др.) + Prefetch в реестре.
  by DEABLOV111
#>

$ErrorActionPreference = 'Continue'
$esc = [char]27

function Enable-AnsiConsole {
    try {
        Add-Type -ErrorAction Stop -Namespace Native -Name ConsoleVT -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError=true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
        $h = [Native.ConsoleVT]::GetStdHandle(-11)
        $mode = [uint32]0
        if ([Native.ConsoleVT]::GetConsoleMode($h, [ref]$mode)) {
            [void][Native.ConsoleVT]::SetConsoleMode($h, ($mode -bor 0x0004))
        }
    }
    catch {}
}

function Write-Ansi([string]$Text) { [Console]::Write($Text) }

function Write-BloodBanner {
    Enable-AnsiConsole
    $sh  = "$esc[38;2;60;0;0m"
    $mid = "$esc[38;2;120;0;0m"
    $bld = "$esc[38;2;190;8;8m"
    $hot = "$esc[38;2;255;40;40m"
    $drip= "$esc[38;2;140;0;0m"
    $rst = "$esc[0m"
    $dim = "$esc[38;2;70;70;70m"

    $art = @(
        '██████╗ ███████╗ █████╗ ██████╗ ██╗      ██████╗ ██╗   ██╗ ██╗ ██╗ ██╗',
        '██╔══██╗██╔════╝██╔══██╗██╔══██╗██║     ██╔═══██╗██║   ██║███║███║███║',
        '██║  ██║█████╗  ███████║██████╔╝██║     ██║   ██║██║   ██║╚██║╚██║╚██║',
        '██║  ██║██╔══╝  ██╔══██║██╔══██╗██║     ██║   ██║╚██╗ ██╔╝ ██║ ██║ ██║',
        '██████╔╝███████╗██║  ██║██████╔╝███████╗╚██████╔╝ ╚████╔╝  ██║ ██║ ██║',
        '╚═════╝ ╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝ ╚═════╝   ╚═══╝   ╚═╝ ╚═╝ ╚═╝'
    )

    Write-Host ''
    foreach ($line in $art) { Write-Ansi ("  $sh$line$rst`n") }
    Write-Ansi ("$esc[$($art.Count)A")
    $i = 0
    foreach ($line in $art) {
        $color = if ($i -lt 2) { $hot } elseif ($i -lt 4) { $bld } else { $mid }
        Write-Ansi ("$color$line$rst`n")
        $i++
    }
    Write-Ansi ("$drip  ║     ║          ║    ║║          ║       ║║         ║  ║  ║$rst`n")
    Write-Ansi ("$drip  ┘     ┘          ░    ░░     ▄    ▕       ░░         ▕  ▕  ▕$rst`n")
    Write-Ansi ("$sh  by DEABLOV111$rst`n")
    Write-Ansi ("$esc[1A$hot" + 'by DEABLOV111' + "$rst  $dim service enabler$rst`n")
    Write-Host ''
}

function Write-Header([string]$Text) {
    $c = "$esc[38;2;220;40;40m"
    $g = "$esc[38;2;90;90;90m"
    $w = "$esc[38;2;220;220;220m"
    $rst = "$esc[0m"
    $line = '─' * [Math]::Max(8, (62 - $Text.Length))
    Write-Host ''
    Write-Ansi ("$g┌─$c▓$rst $w$Text$rst $g$line$rst`n")
}

function Write-OK([string]$Text)   { Write-Host "[+] $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "[!] $Text" -ForegroundColor Yellow }
function Write-Fail([string]$Text) { Write-Host "[-] $Text" -ForegroundColor Red }
function Write-Info([string]$Text) { Write-Host "[*] $Text" -ForegroundColor Gray }

function Get-StartTypeRu($StartType) {
    switch ("$StartType") {
        'Automatic' { 'Авто' }
        'Manual'    { 'Вручную' }
        'Disabled'  { 'Отключена' }
        'Boot'      { 'Загрузка' }
        'System'    { 'Система' }
        default     { "$StartType" }
    }
}

function Get-StatusRu($Status) {
    switch ("$Status") {
        'Running'  { 'Работает' }
        'Stopped'  { 'Остановлена' }
        default    { "$Status" }
    }
}

# Тот же набор, что в SERVICE STATUS (Services.ps1)
$CriticalServices = [ordered]@{
    'EventLog'   = @{ Startup = 'Automatic'; Start = $true;  Note = 'Журнал событий Windows' }
    'SysMain'    = @{ Startup = 'Automatic'; Start = $true;  Note = 'SysMain' }
    'Schedule'   = @{ Startup = 'Automatic'; Start = $true;  Note = 'Планировщик задач' }
    'DPS'        = @{ Startup = 'Automatic'; Start = $true;  Note = 'Служба политики диагностики' }
    'DiagTrack'  = @{ Startup = 'Automatic'; Start = $true;  Note = 'Телеметрия' }
    'PcaSvc'     = @{ Startup = 'Automatic'; Start = $true;  Note = 'Помощник по совместимости программ' }
    'AppInfo'    = @{ Startup = 'Manual';    Start = $true;  Note = 'Сведения о приложении' }
    'PlugPlay'   = @{ Startup = 'Manual';    Start = $true;  Note = 'Plug and Play' }
    'DcomLaunch' = @{ Startup = 'Automatic'; Start = $true;  Note = 'Запуск процессов DCOM-сервера' }
    'CDPSvc'     = @{ Startup = 'Automatic'; Start = $true;  Note = 'Платформа подключенных устройств' }
    'DusmSvc'    = @{ Startup = 'Automatic'; Start = $true;  Note = 'Использование данных' }
    'WSearch'    = @{ Startup = 'Automatic'; Start = $true;  Note = 'Windows Search' }
    'Power'      = @{ Startup = 'Automatic'; Start = $true;  Note = 'Питание' }
}

Write-BloodBanner
Write-Info ("ПК: {0} | Юзер: {1} | {2}" -f $env:COMPUTERNAME, $env:USERNAME, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

Write-Header 'ENABLE SERVICES'

$results = @()

foreach ($name in $CriticalServices.Keys) {
    $cfg = $CriticalServices[$name]
    $row = [pscustomobject]@{
        Service = $name
        Note    = $cfg.Note
        Before  = 'н/д'
        After   = 'н/д'
        Status  = 'Нет'
        Action  = ''
    }

    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if (-not $svc) {
        $svc = Get-Service -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like "$name*" -or $_.Name -like "$name_*"
        } | Select-Object -First 1
    }

    if (-not $svc) {
        Write-Warn ("{0} — нет на этой системе" -f $name)
        $results += $row
        continue
    }

    $actualName = $svc.Name
    $row.Service = $actualName
    $row.Before  = '{0} / {1}' -f (Get-StartTypeRu $svc.StartType), (Get-StatusRu $svc.Status)

    try {
        Set-Service -Name $actualName -StartupType $cfg.Startup -ErrorAction Stop
        $row.Action = "Запуск -> $(Get-StartTypeRu $cfg.Startup)"

        if ($cfg.Start) {
            if ($svc.Status -ne 'Running') {
                Start-Service -Name $actualName -ErrorAction Stop
                $row.Action += '; запущена'
            } else {
                $row.Action += '; уже работает'
            }
        }

        $svc = Get-Service -Name $actualName
        $row.After  = '{0} / {1}' -f (Get-StartTypeRu $svc.StartType), (Get-StatusRu $svc.Status)
        $row.Status = 'OK'
        Write-OK ("{0} ({1}) => {2}" -f $actualName, $cfg.Note, $row.After)
    }
    catch {
        $row.Status = 'FAIL'
        $row.Action = $_.Exception.Message
        Write-Fail ("{0}: {1}" -f $actualName, $_.Exception.Message)
    }

    $results += $row
}

Write-Header 'BAM'

$bamPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\bam'
$startMapRu = @{ 0 = 'Загрузка'; 1 = 'Система'; 2 = 'Авто'; 3 = 'Вручную'; 4 = 'Отключена' }

if (Test-Path $bamPath) {
    try {
        $bp = Get-ItemProperty $bamPath
        $oldStart = [int]$bp.Start
        $oldRu = if ($startMapRu.ContainsKey($oldStart)) { $startMapRu[$oldStart] } else { "$oldStart" }

        $desired = 1
        Set-ItemProperty -Path $bamPath -Name 'Start' -Value $desired -Type DWord -Force

        $statePath = Join-Path $bamPath 'State'
        $userPath  = Join-Path $bamPath 'State\UserSettings'
        if (-not (Test-Path $statePath)) { New-Item -Path $statePath -Force | Out-Null }
        if (-not (Test-Path $userPath))  { New-Item -Path $userPath  -Force | Out-Null }

        $newRu = $startMapRu[$desired]
        Write-OK ("bam Start: {0} -> {1} (System)" -f $oldRu, $newRu)
        Write-OK 'Ключи State\UserSettings проверены/созданы'

        $sc = & sc.exe start bam 2>&1
        if ($LASTEXITCODE -eq 0 -or ("$sc" -match 'RUNNING|уже запущ|already')) {
            Write-OK 'sc start bam — ок / уже запущен'
        } else {
            Write-Info ("sc start bam: {0}" -f (($sc | Out-String).Trim()))
            Write-Info 'Kernel driver: полный старт может потребовать перезагрузки'
        }
    }
    catch {
        Write-Fail ("BAM: {0}" -f $_.Exception.Message)
    }
} else {
    Write-Fail 'Ключ HKLM\SYSTEM\CurrentControlSet\Services\bam отсутствует'
}

Write-Header 'PREFETCH / SYSMAIN'

$prefetchPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'
$prefetchKeys = @{
    EnablePrefetcher  = 3
    EnableSuperfetch  = 3
}

if (Test-Path $prefetchPath) {
    foreach ($key in $prefetchKeys.Keys) {
        try {
            $old = (Get-ItemProperty -Path $prefetchPath -Name $key -ErrorAction SilentlyContinue).$key
            Set-ItemProperty -Path $prefetchPath -Name $key -Value $prefetchKeys[$key] -Type DWord -Force
            Write-OK ("{0}: {1} -> {2}" -f $key, $old, $prefetchKeys[$key])
        }
        catch {
            Write-Fail ("{0}: {1}" -f $key, $_.Exception.Message)
        }
    }
} else {
    Write-Warn 'Ключ PrefetchParameters не найден'
}

$prefetchDir = Join-Path $env:SystemRoot 'Prefetch'
if (Test-Path $prefetchDir) {
    try {
        $item = Get-Item $prefetchDir -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReadOnly) {
            $item.Attributes = $item.Attributes -bxor [IO.FileAttributes]::ReadOnly
            Write-OK 'Снят ReadOnly с Prefetch'
        } else {
            Write-Info 'Атрибуты Prefetch в норме'
        }
    }
    catch {
        Write-Fail ("Папка Prefetch: {0}" -f $_.Exception.Message)
    }
}

Write-Header 'SUMMARY'
$results | Format-Table Service, Status, Before, After, Note -AutoSize

$failed = @($results | Where-Object { $_.Status -eq 'FAIL' })
$ok     = @($results | Where-Object { $_.Status -eq 'OK' }).Count
Write-Host ''
Write-OK ("Включено/проверено: {0}" -f $ok)
if ($failed.Count -gt 0) {
    Write-Warn ("Ошибки: {0} (нужен запуск от администратора)" -f $failed.Count)
}

Write-Host ''
Write-Ansi ("  $esc[38;2;60;0;0m  by DEABLOV111$esc[0m`n")
Write-Ansi ("$esc[1A  $esc[38;2;255;40;40mby DEABLOV111$esc[0m`n")
Write-Info 'Готово. Проверь через Services.ps1'
Write-Host ''
