# Build sqlite3.dll + sqlite3.exe (shell) + vec0.dll (Windows, MSVC).
# Requires fetch.ps1 first and a Visual Studio developer environment
# (cl on PATH). Output: dist/
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Test-Path vendor/src-sqlite/sqlite3.c)) { throw "run .\fetch.ps1 first" }
$defs = Get-Content flags.txt | Where-Object { $_ -notmatch '^#' -and $_.Trim() -ne '' } |
    ForEach-Object { "/D" + $_.Trim() }
Write-Host "flags: $($defs -join ' ')"
New-Item -ItemType Directory -Force dist | Out-Null

# DLL (SQLITE_API predefined to dllexport before sqlite3.h is read)
cl /nologo /O2 /MD /LD vendor/src-sqlite/sqlite3.c /I vendor/src-sqlite `
   /D "SQLITE_API=__declspec(dllexport)" @defs `
   /Fe:dist\sqlite3.dll /link /IMPLIB:dist\sqlite3.lib
if ($LASTEXITCODE -ne 0) { throw "DLL build failed" }

# Shell (statically linked, same feature set)
cl /nologo /O2 /MD vendor/src-sqlite/shell.c vendor/src-sqlite/sqlite3.c /I vendor/src-sqlite `
   @defs /Fe:dist\sqlite3.exe
if ($LASTEXITCODE -ne 0) { throw "shell build failed" }

# vec0 loadable extension (init entry point: sqlite3_vec_init)
cl /nologo /O2 /MD /LD vendor/src-vec/sqlite-vec.c /I vendor/src-sqlite `
   /Fe:dist\vec0.dll dist\sqlite3.lib
if ($LASTEXITCODE -ne 0) { throw "vec0 build failed" }

Get-ChildItem dist | Format-Table Name, Length
