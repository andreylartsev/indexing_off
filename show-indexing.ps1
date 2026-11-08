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

Write-Host "`n--- ПРОВЕРКА СТАТУСА ИНДЕКСАЦИИ ---" -ForegroundColor Cyan

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
    Write-Host "`n--- Системные правила (из доменных политик HKLM) ---" -ForegroundColor Cyan
    
    # Ищем все подразделы, которые содержат пути
    $SubKeys = Get-ChildItem -Path $SysPath -Recurse -ErrorAction SilentlyContinue
    
    foreach ($Key in $SubKeys) {
        $Properties = Get-ItemProperty -Path $Key.PSPath -ErrorAction SilentlyContinue
        
        # Нас интересуют только объекты, у которых есть параметр Url или Path
        if ($Properties.Url -or $Properties.Path) {
            $RawPath = if ($Properties.Url) { $Properties.Url } else { $Properties.Path }
            
            # Делаем путь читаемым
            $CleanedPath = $RawPath -replace "file:///","" -replace "file:",""
            
            # Проверяем флаг Suppress: 1 означает, что папка исключена из поиска
            $IsExcluded = $Properties.Suppress -eq 1
            
            # Проверяем, перекрывается ли диск нашей пользовательской блокировкой
            $Disk = if ($CleanedPath.Length -ge 2) { $CleanedPath.Substring(0,2) } else { "" }
            
            if ($ActiveExclusions -contains $Disk) {
                Write-Host " • [ПЕРЕКРЫТО ПОЛЬЗОВАТЕЛЕМ] $CleanedPath" -ForegroundColor DarkGray
            } elseif ($IsExcluded) {
                Write-Host " • [ГЛОБАЛЬНОЕ ИСКЛЮЧЕНИЕ]  $CleanedPath" -ForegroundColor Green
            } else {
                Write-Host " • [ПРИНУДИТЕЛЬНО ИНДЕКС]  $CleanedPath" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Warning "Системная ветка индексации не найдена."
}
Write-Host ""
