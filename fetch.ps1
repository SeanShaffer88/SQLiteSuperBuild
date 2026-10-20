# Download the pinned upstream sources into vendor/ and verify SHA-256.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$pins = @{}
Get-Content pins.txt | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $k, $v = $_ -split '=', 2; $pins[$k.Trim()] = $v.Trim()
}
New-Item -ItemType Directory -Force vendor | Out-Null

function Fetch([string]$Url, [string]$File, [string]$Want) {
    $path = Join-Path vendor $File
    if (-not (Test-Path $path)) {
        Write-Host "downloading $Url"
        Invoke-WebRequest -Uri $Url -OutFile $path
    }
    $got = (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
    if ($got -ne $Want) {
        throw "SHA-256 MISMATCH for $File`n  pinned: $Want`n  actual: $got"
    }
    Write-Host "verified $File ($got)"
}

Fetch $pins['SQLITE_URL'] "$($pins['SQLITE_AMALGAMATION']).zip" $pins['SQLITE_SHA256']
Fetch $pins['SQLITE_VEC_URL'] "sqlite-vec-$($pins['SQLITE_VEC_VERSION'])-amalgamation.zip" $pins['SQLITE_VEC_SHA256']

Remove-Item -Recurse -Force vendor/src-sqlite, vendor/src-vec -ErrorAction SilentlyContinue
Expand-Archive "vendor/$($pins['SQLITE_AMALGAMATION']).zip" -DestinationPath vendor/tmp-sqlite -Force
New-Item -ItemType Directory -Force vendor/src-sqlite | Out-Null
Move-Item "vendor/tmp-sqlite/$($pins['SQLITE_AMALGAMATION'])/*" vendor/src-sqlite/
Remove-Item -Recurse -Force vendor/tmp-sqlite
Expand-Archive "vendor/sqlite-vec-$($pins['SQLITE_VEC_VERSION'])-amalgamation.zip" -DestinationPath vendor/src-vec -Force
Write-Host "sources ready in vendor/src-sqlite and vendor/src-vec"
