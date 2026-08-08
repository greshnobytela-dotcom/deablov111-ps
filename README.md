# by DEABLOV111

PowerShell-скрипты для скриншара: включение служб и компактный `SERVICE STATUS`.

## Скрипты

| Файл | Назначение |
|------|------------|
| `Service-Enabler.ps1` | Включает EventLog, SysMain, BAM, DPS и др. + Prefetch |
| `Services.ps1` | SERVICE STATUS (14 служб), boot/uptime, диски, BAM/Prefetch, event history |

Запускать от **администратора**.

## Запуск без скачивания

**Service-Enabler**

```powershell
powershell Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass && powershell Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/greshnobytela-dotcom/lilith-ps/refs/heads/main/Service-Enabler.ps1)
```

**Services**

```powershell
powershell Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass && powershell Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/greshnobytela-dotcom/lilith-ps/refs/heads/main/Services.ps1)
```

## Локально

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Service-Enabler.ps1
.\Services.ps1
```

by DEABLOV111
