@echo off

set "BASE_DIR=%~dp0"
set "PATH=%BASE_DIR%\iup;%PATH%"
set "LUA_PATH=%BASE_DIR%\lua_modules\share\lua\5.1\?.lua;%BASE_DIR%\app\?.lua"
set "LUA_CPATH=%BASE_DIR%\iup\?.dll;%BASE_DIR%\iup\?.dll"

"%BASE_DIR%\iup\lua5.1.exe" "%BASE_DIR%\app\main.lua"
