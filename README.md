# Управление индексированием папок для Windows 11

Права администратора не требуются. Какие либо изменения применяются только для вашего профиля.
В конце принудительно перезапускается explorer.exe.
Перед запуском: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

1. [show-indexing.ps1](./show-indexing.ps1) — Показывает, какие папки сейчас принудительно индексируются системой в HKLM.

2. [disable-all-disks-indexing-for-user.ps1](./disable-all-disks-indexing-for-user.ps1) — Перекрывает системные настройки и отключает индексацию **на уровне дисков** для вашего пользователя.

3. [remove_all-indexing-exclusions-for-user.ps1](./remove_all-indexing-exclusions-for-user.ps1) — Удаляет **ВСЕ!** ваши пользовательские исключения.
