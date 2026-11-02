# Generate a Windows .def export list from a built DLL.
#
# Usage:
#   pwsh tools/gen_def.ps1 <dll> <output.def> [symbol-prefix]
#
# Examples:
#   pwsh tools/gen_def.ps1 dist/sqlite3.dll dist/sqlite3.def
#   pwsh tools/gen_def.ps1 dist/vec0.dll vec0.def sqlite3_vec
#
# Requires dumpbin on PATH (run from a Visual Studio developer prompt, or
# use ilammy/msvc-dev-cmd in CI). The checked-in defs are generated from
# the release build; CI regenerates and compares them.
$ErrorActionPreference = 'Stop'

$lib = $args[0]
$out = $args[1]
$prefix = if ($args.Count -gt 2) { $args[2] } else { 'sqlite3' }
if (-not $lib -or -not $out) {
    throw "usage: gen_def.ps1 <dll> <output.def> [symbol-prefix]"
}
if (-not (Test-Path $lib)) { throw "no such DLL: $lib" }

$names = New-Object System.Collections.Generic.List[string]
foreach ($line in (& dumpbin /EXPORTS $lib)) {
    # "  ordinal hint RVA name" - the symbol is the last column.
    if ($line -match '^\s+\d+\s+[0-9A-Fa-f]+\s+[0-9A-Fa-f]+\s+(\S+)\s*$') {
        $names.Add($Matches[1])
    }
}
$names = $names | Where-Object { $_ -like "$prefix*" } | Sort-Object -Unique

$header = @(
    '; SQLite SuperBuild export list'
    "; Generated from $lib by tools/gen_def.ps1; do not edit by hand."
    'EXPORTS'
)
$body = foreach ($name in $names) {
    if ($name -eq 'sqlite3_version') { "$name DATA" } else { $name }
}
# LF line endings keep the generated file byte-identical to the checked-in
# def on every platform (Windows tools accept LF in .def files).
$text = (($header + $body) -join "`n") + "`n"
[System.IO.File]::WriteAllText((Resolve-Path $out), $text, [System.Text.Encoding]::ASCII)
Write-Host "wrote $out ($($names.Count) symbols)"
