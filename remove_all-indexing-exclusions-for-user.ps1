<#
.SYNOPSIS
    Удаление пользовательских исключений и возврат к системным настройкам индексации.
.DESCRIPTION
    Скрипт полностью удаляет созданные блокировки, возвращая контроль домену или антивирусу.
.NOTES
    Права администратора не требуются.
    Перед запуском: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ExcludeRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\DefaultExcludeRoots"

if (Test-Path $ExcludeRegPath) {
    $SubKeys = Get-ChildItem -Path $ExcludeRegPath -ErrorAction SilentlyContinue
    
    if ($SubKeys.Count -gt 0) {
        Write-Host "`n[~] Обнаружены пользовательские блокировки. Начинаю их удаление..." -ForegroundColor Yellow
        
        foreach ($Key in $SubKeys) {
            $CleanPath = $Key.Name -replace "HKEY_CURRENT_USER", "HKCU:"
            Remove-Item -Path $CleanPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host " • Блокировка для диска $($Key.PSChildName) удалена." -ForegroundColor Green
        }
        
        Write-Host "[~] Применяю настройки. Перезапускаю Проводник..." -ForegroundColor Cyan
        Stop-Process -Name "explorer" -Force
        Write-Host "[+] Готово! Все блокировки сняты, индексация снова управляется системой.`n" -ForegroundColor Green
    } else {
        Write-Host "`n[+] Список исключений пуст. Индексация уже работает по умолчанию.`n" -ForegroundColor Green
    }
} else {
    Write-Host "`n[+] Настройки не менялись, блокировок не обнаружено.`n" -ForegroundColor Gray
}
