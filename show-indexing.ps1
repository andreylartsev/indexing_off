<#
.SYNOPSIS
    Просмотр путей индексации Windows 11 с разделением на включения и исключения.
.DESCRIPTION
    Скрипт читает системную ветку реестра, анализирует флаг 'Suppress' для каждой записи
    и корректно определяет, индиксируется папка или она находится в глобальных исключениях.
.NOTES
    Имя файла: show-indexing.ps1
    Права администратора не требуются.
    Перед запуском: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$SysPath = "HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex\Sites"
$ExcludePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\DefaultExcludeRoots"

Write-Host "`n--- ПРОВЕРКА СТАТУСА ИНДЕКСАЦИИ (ОБНОВЛЕННАЯ) ---" -ForegroundColor Cyan

# 1. Проверяем, включены ли пользовательские блокировки всего диска
$ActiveExclusions = @()
if (Test-Path $ExcludePath) {
    $ActiveExclusions = Get-ChildItem -Path $ExcludePath -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName }
}

if ($ActiveExclusions) {
    Write-Host "[!] ВАШИ КОРНЕВЫЕ БЛОКИРОВКИ АКТИВНЫ ДЛЯ: $($ActiveExclusions -join ', ')" -ForegroundColor Yellow
    Write-Host "(Индексация данных дисков полностью остановлена в вашем профиле)" -ForegroundColor DarkGray
} else {
    Write-Host "[+] Ваши личные блокировки отсутствуют. Система работает по умолчанию." -ForegroundColor Gray
}

# 2. Сканируем системную ветку
if (Test-Path $SysPath) {
    Write-Host "`n--- Системные правила (из реестра HKLM) ---" -ForegroundColor Cyan
    
    # Ищем все подразделы, которые содержат пути
    $SubKeys = Get-ChildItem -Path $SysPath -Recurse -ErrorAction SilentlyContinue
    
    foreach ($Key in $SubKeys) {
        $Properties = Get-ItemProperty -Path $Key.PSPath -ErrorAction SilentlyContinue
        
        # Нас интересуют только объекты, у которых есть параметр Url или Path
        if ($Properties.Url -or $Properties.Path) {
            $RawPath = if ($Properties.Url) { $Properties.Url } else { $Properties.Path }
            
            # Делаем путь читаемым
            $CleanedPath = $RawPath -replace "file:///","" -replace "file:",""
            
            # Извлекаем значения флагов (если их нет, пишем "Нет")
            $SuppressVal = if ($null -ne $Properties.Suppress) { $Properties.Suppress } else { "Нет" }
            $PolicyVal = if ($null -ne $Properties.Policy) { $Properties.Policy } else { "Нет" }
            
            # Логика определения исключения:
            # 1. Если Suppress равен 1
            # 2. Если это системный мусор (Корзина, Temp, AppData), и Suppress не равен 0 принудительно
            # 3. Если активна групповая политика (Policy = 1)
            $IsExcluded = ($SuppressVal -eq 1) -or 
                          ($PolicyVal -eq 1) -or 
                          (($SuppressVal -eq "Нет") -and ($CleanedPath -match "Temp|Recycle|\.BIN|AppData|Information"))

            # Проверяем, перекрывается ли диск нашей пользовательской блокировкой
            $Disk = if ($CleanedPath.Length -ge 2) { $CleanedPath.Substring(0,2) } else { "" }
            
            # Вывод информации
            Write-Host "Путь: $CleanedPath" -ForegroundColor White
            Write-Host "└─ Флаги в реестре -> Suppress: $SuppressVal | Policy: $PolicyVal" -ForegroundColor DarkGray
            
            if ($ActiveExclusions -contains $Disk) {
                Write-Host "   СТАТУС: [ПЕРЕКРЫТО ПОЛЬЗОВАТЕЛЕМ]" -ForegroundColor DarkGray
            } elseif ($IsExcluded) {
                Write-Host "   СТАТУС: [ГЛОБАЛЬНОЕ ИСКЛЮЧЕНИЕ] (Поиск тут отключен)" -ForegroundColor Green
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
