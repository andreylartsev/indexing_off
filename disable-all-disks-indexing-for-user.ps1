<#
.SYNOPSIS
    Отключение индексации всех дисков через пользовательские исключения.
.DESCRIPTION
    Скрипт добавляет все обнаруженные в системе локальные диски в список исключений 
    текущего пользователя, принудительно останавливая индексацию.
.NOTES
    Права администратора не требуются. Изменения применяются только для вашего профиля.
    Перед запуском: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ExcludeRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\DefaultExcludeRoots"

if (-not (Test-Path $ExcludeRegPath)) {
    New-Item -Path $ExcludeRegPath -Force | Out-Null
}

$Drives = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }

if ($Drives) {
    Write-Host "`n[~] Начинаю добавление дисков в список исключений поиска..." -ForegroundColor Yellow
    
    foreach ($Drive in $Drives) {
        $DriveLetter = $Drive.DeviceID
        $ExcludeUrl = "file:///$DriveLetter/"
        
        $CleanPath = Join-Path $ExcludeRegPath $DriveLetter
        if (-not (Test-Path $CleanPath)) {
            New-Item -Path $CleanPath -Force | Out-Null
        }
        
        New-ItemProperty -Path $CleanPath -Name "Url" -Value $ExcludeUrl -PropertyType String -Force | Out-Null
        Write-Host " • Диск $DriveLetter успешно добавлен в исключения (индексация выключена)." -ForegroundColor Green
    }
    
    Write-Host "[~] Применяю настройки. Перезапускаю Проводник..." -ForegroundColor Cyan
    Stop-Process -Name "explorer" -Force
    Write-Host "[+] Готово! Индексация дисков полностью отключена для вашего пользователя.`n" -ForegroundColor Green
} else {
    Write-Error "Не удалось обнаружить локальные диски в системе."
}
