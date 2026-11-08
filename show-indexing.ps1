<#
.SYNOPSIS
    Комплексный просмотр путей индексации Windows 11 (Системные + Пользовательские).
.DESCRIPTION
    Скрипт читает системную ветку реестра (HKLM) и ветку текущего пользователя (HKCU),
    анализирует флаги 'Suppress', 'Policy' и пользовательские правила 'DefaultExcludeRoots'.
    Определяет реальный статус индексации с учетом перекрытия системных правил пользовательскими.
.NOTES
    Имя файла: show-indexing.ps1
    Права администратора не требуются.
    Перед запуском: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$SysPath = "HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex\Sites"
$ExcludePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\DefaultExcludeRoots"

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "--- ПРОВЕРКА СТАТУСА ИНДЕКСАЦИИ (СИСТЕМНЫЕ + ПОЛЬЗОВАТЕЛЬСКИЕ) ---" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Считываем пользовательские настройки из HKCU
$UserExclusionsPaths = @()
$WholeDiskExclusions = @()

if (Test-Path $ExcludePath) {
    $SubKeys = Get-ChildItem -Path $ExcludePath -ErrorAction SilentlyContinue
    foreach ($Key in $SubKeys) {
        $Properties = Get-ItemProperty -Path $Key.PSPath -ErrorAction SilentlyContinue
        if ($Properties.Url) {
            # Очищаем URL для последующего сопоставления
            $CleanUserUrl = $Properties.Url -replace "file:///","" -replace "file:","" -replace "/","\"
            $UserExclusionsPaths += $CleanUserUrl
        }
        
        # Если имя ключа — просто буква диска (например, "C:"), значит это полная блокировка корня
        if ($Key.PSChildName -match "^[A-Za-z]:$") {
            $WholeDiskExclusions += $Key.PSChildName
        }
    }
}

# Выводим блок пользовательских настроек
Write-Host "`n[1] ПОЛЬЗОВАТЕЛЬСКИЕ НАСТРОЙКИ (Ветка HKCU)" -ForegroundColor Cyan
if ($WholeDiskExclusions) {
    Write-Host "[!] ПОЛНАЯ БЛОКИРОВКА КОРНЯ ДЛЯ ДИСКОВ: $($WholeDiskExclusions -join ', ')" -ForegroundColor Yellow
}

if ($UserExclusionsPaths) {
    Write-Host "[!] Активны следующие точечные исключения пользователя:" -ForegroundColor Yellow
    foreach ($Path in $UserExclusionsPaths) {
        Write-Host " • [БЛОКИРОВКА] $Path" -ForegroundColor Green
    }
}

if (-not $WholeDiskExclusions -and -not $UserExclusionsPaths) {
    Write-Host "[+] Ваши личные блокировки отсутствуют. Система работает по умолчанию." -ForegroundColor Gray
}

Write-Host ("=" * 60) -ForegroundColor DarkGray

# 2. Сканируем системную ветку HKLM и проверяем наложения
if (Test-Path $SysPath) {
    Write-Host "`n[2] СИСТЕМНЫЕ ПРАВИЛА (Ветка HKLM) И ИХ РЕАЛЬНЫЙ СТАТУС" -ForegroundColor Cyan
    
    $SubKeys = Get-ChildItem -Path $SysPath -Recurse -ErrorAction SilentlyContinue
    
    foreach ($Key in $SubKeys) {
        $Properties = Get-ItemProperty -Path $Key.PSPath -ErrorAction SilentlyContinue
        
        if ($Properties.Url -or $Properties.Path) {
            $RawPath = if ($Properties.Url) { $Properties.Url } else { $Properties.Path }
            
            # Делаем системный путь читаемым и переводим в слэши Windows
            $CleanedPath = $RawPath -replace "file:///","" -replace "file:",""
            $WinStylePath = $CleanedPath -replace "/","\"
            
            # Извлекаем значения флагов
            $SuppressVal = if ($null -ne $Properties.Suppress) { $Properties.Suppress } else { "Нет" }
            $PolicyVal = if ($null -ne $Properties.Policy) { $Properties.Policy } else { "Нет" }
            
            # Логика определения системного исключения
            $IsSystemExcluded = ($SuppressVal -eq 1) -or 
                                ($PolicyVal -eq 1) -or 
                                (($SuppressVal -eq "Нет") -and ($CleanedPath -match "Temp|Recycle|\.BIN|AppData|Information"))

            # Проверяем перекрытие диска или конкретного пути пользователем
            $Disk = if ($CleanedPath.Length -ge 2) { $CleanedPath.Substring(0,2) } else { "" }
            
            $IsOverriddenByDisk = $WholeDiskExclusions -contains $Disk
            
            # Проверяем, перекрывается ли путь точечным правилом пользователя (частичное совпадение)
            $IsOverriddenByPath = $false
            foreach ($UserPath in $UserExclusionsPaths) {
                # Убираем диски и проверяем маски (например Users\*\AppData)
                $RegexPattern = [regex]::Escape($UserPath) -replace '\\\\\*', '.*' -replace '\\\\', '\\'
                if ($WinStylePath -match $RegexPattern) {
                    $IsOverriddenByPath = $true
                    break
                }
            }

            # Вывод информации
            Write-Host "Путь: $WinStylePath" -ForegroundColor White
            Write-Host "└─ Флаги в реестре -> Suppress: $SuppressVal | Policy: $PolicyVal" -ForegroundColor DarkGray
            
            if ($IsOverriddenByDisk -or $IsOverriddenByPath) {
                Write-Host "   СТАТУС: [ПЕРЕКРЫТО ПОЛЬЗОВАТЕЛЕМ] (Ваше правило заблокировало поиск)" -ForegroundColor DarkGray
            } elseif ($IsSystemExcluded) {
                Write-Host "   СТАТУС: [ГЛОБАЛЬНОЕ ИСКЛЮЧЕНИЕ] (Поиск отключен системой)" -ForegroundColor Green
            } else {
                Write-Host "   СТАТУС: [ПРИНУДИТЕЛЬНО ИНДЕКС] (Поиск тут работает)" -ForegroundColor Red
            }
            Write-Host ("-" * 60) -ForegroundColor DarkGray
        }
    }
} else {
    Write-Warning "Системная ветка индексации не найдена."
}
Write-Host ""
