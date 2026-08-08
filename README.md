# by DEABLOV111

PowerShell-скрипты для скриншара в кровавом стиле.

## Скрипты

| Файл | Назначение |
|------|------------|
| `Service-Enabler.ps1` | Включает EventLog, SysMain, BAM, DPS и др. + Prefetch |
| `Services.ps1` | SERVICE STATUS (14 служб), boot/uptime, диски, BAM/Prefetch, event history |
| `DoomsDayDetector.ps1` | Doomsday Client Scanner (USN / Prefetch) |

Запускать от **администратора**.

## Запуск без скачивания

**Service-Enabler**

```powershell
powershell Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass && powershell Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/greshnobytela-dotcom/deablov111-ps/refs/heads/main/Service-Enabler.ps1)
```

**Services**

```powershell
powershell Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass && powershell Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/greshnobytela-dotcom/deablov111-ps/refs/heads/main/Services.ps1)
```

**DoomsDayDetector**

```powershell
powershell Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass && powershell Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/greshnobytela-dotcom/deablov111-ps/refs/heads/main/DoomsDayDetector.ps1)
```

## Локально

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Service-Enabler.ps1
.\Services.ps1
.\DoomsDayDetector.ps1
```

by DEABLOV111
