@echo off
rem Nocna Zmiana - wersja robocza (menu glowne). Dwuklik, zeby zagrac.
rem Wszystko, co gra zapisuje, zostaje na tym dysku: zapis, opcje i log
rem w tools\godot\editor_data\nz_save, pamiec podreczna silnika i sterownika
rem karty graficznej w tools\godot\editor_data\appdata i localappdata
rem (nic w %APPDATA% ani %LOCALAPPDATA% na C:).
set "GODOT=%~dp0tools\godot\Godot_v4.7.2-stable_win64"
if not exist "%GODOT%.exe" goto missing
if not exist "%GODOT%_console.exe" goto missing
set "APPDATA=%~dp0tools\godot\editor_data\appdata"
set "LOCALAPPDATA=%~dp0tools\godot\editor_data\localappdata"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
rem okno od razu w trybie z opcji (bez migniecia pelnym ekranem)
set "SETTINGS=%~dp0tools\godot\editor_data\nz_save\settings.cfg"
set "WINDOW="
if exist "%SETTINGS%" (
	findstr /b /c:"window_mode=0" "%SETTINGS%" >nul && set "WINDOW=--windowed --resolution 1600x900"
	findstr /b /c:"window_mode=1" "%SETTINGS%" >nul && set "WINDOW=--maximized"
)
echo Przygotowuje gre, chwileczke...
"%GODOT%_console.exe" --headless --path "%~dp0." --import >nul 2>&1
start "" "%GODOT%.exe" --path "%~dp0." %WINDOW%
exit /b 0

:missing
echo Nie znaleziono silnika Godot 4.7.2 w folderze:
echo %~dp0tools\godot
echo Potrzebne pliki: Godot_v4.7.2-stable_win64.exe i Godot_v4.7.2-stable_win64_console.exe
pause
exit /b 1
