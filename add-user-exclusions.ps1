<#
.SYNOPSIS
    Точечное отключение индексации Windows Search для системного мусора и кэша.
.DESCRIPTION
    Скрипт предназначен для работы в окружении без прав администратора. 
    Он добавляет правила исключений в реестр текущего пользователя (HKCU), 
    что позволяет обойти неработающие доменные/системные правила HKLM, 
    которые ссылаются на устаревший или чужой GUID тома (7e25e7d0-...).
    
    Скрипт привязывается к букве диска C: и маскам путей, полностью ограждая
    поиск Windows Search от сканирования временных файлов, Корзины и AppData,
    тем самым снижая нагрузку на процессор, SSD и устраняя скрытые блокировки файлов.
.NOTES
    После внесения изменений скрипт перезапускает процесс explorer.exe 
    для немедленного применения настроек поиска.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ExcludeRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\DefaultExcludeRoots"

# Список папок, которые мы хотим исключить (относительно корня диска C:)
$FolderTemplates = @(
    "Users\*\AppData\Local\Temp",
    "Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files",
    "WINDOWS\Temp",
    "WINDOWS\system32\config\systemprofile\AppData\Local\Licensing",
    "`$RECYCLE.BIN",
    "System Volume Information"
)

# Проверяем и создаем корневую папку в реестре, если её нет
if (-not (Test-Path $ExcludeRegPath)) {
    New-Item -Path $ExcludeRegPath -Force | Out-Null
}

Write-Host "`n[~] Начинаю добавление точечных исключений в ваш профиль..." -ForegroundColor Yellow

foreach ($Template in $FolderTemplates) {
    # Формируем полный URL для индексатора (например, file:///C:/Users/*/AppData/Local/Temp/)
    $ExcludeUrl = "file:///C:/$Template/"
    
    # Заменяем символы, которые реестр не разрешает использовать в именах подразделов
    $SubKeyName = $Template -replace '\\', '_' -replace '\*', 'ANY'
    $CleanPath = Join-Path $ExcludeRegPath $SubKeyName
    
    # Создаем подраздел для конкретного правила
    if (-not (Test-Path $CleanPath)) {
        New-Item -Path $CleanPath -Force | Out-Null
    }
    
    # Записываем URL исключения
    New-ItemProperty -Path $CleanPath -Name "Url" -Value $ExcludeUrl -PropertyType String -Force | Out-Null
    Write-Host " • Успешно исключено: C:\$Template" -ForegroundColor Green
}

# Применяем настройки путем перезапуска Проводника
Write-Host "`n[~] Применяю настройки. Перезапускаю Проводник..." -ForegroundColor Cyan
Stop-Process -Name "explorer" -Force

Write-Host "[+] Готово! Глобальный мусор теперь официально исключен из вашего поиска.`n" -ForegroundColor Green
