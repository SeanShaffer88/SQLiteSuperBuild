# Generate a Windows .def export list from a built DLL.
#
# Usage:
#   pwsh tools/gen_def.ps1 <dll> <output.def> [symbol-prefix]
#
# Examples:
#   pwsh tools/gen_def.ps1 dist/sqlite3.dll dist/sqlite3.def
#   pwsh tools/gen_def.ps1 dist/vec0.dll vec0.def sqlite3_vec
#
# The export table is read directly from the PE file, so this works from a
# plain PowerShell prompt (no dumpbin / Visual Studio developer prompt
# required). The checked-in defs are generated from the release build; CI
# regenerates and compares them.
$ErrorActionPreference = 'Stop'

$lib = $args[0]
$out = $args[1]
$prefix = if ($args.Count -gt 2) { $args[2] } else { 'sqlite3' }
if (-not $lib -or -not $out) {
    throw "usage: gen_def.ps1 <dll> <output.def> [symbol-prefix]"
}
if (-not (Test-Path $lib)) { throw "no such DLL: $lib" }

$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $lib).Path)
function Get-U16([int]$offset) { [BitConverter]::ToUInt16($bytes, $offset) }
function Get-U32([int]$offset) { [BitConverter]::ToUInt32($bytes, $offset) }

$peOff = Get-U32 0x3c
if ([System.Text.Encoding]::ASCII.GetString($bytes, $peOff, 4) -ne "PE`0`0") {
    throw "$lib is not a PE file"
}
$coff = $peOff + 4
$nsec = Get-U16 ($coff + 2)
$sizeopt = Get-U16 ($coff + 16)
$opt = $coff + 20
$magic = Get-U16 $opt
$ddOff = $opt + $(if ($magic -eq 0x10b) { 96 } else { 112 })
$expRva = Get-U32 $ddOff
$expSize = Get-U32 ($ddOff + 4)
if ($expRva -eq 0) { throw "$lib has no export table" }

$secOff = $opt + $sizeopt
$sections = @()
for ($i = 0; $i -lt $nsec; $i++) {
    $o = $secOff + $i * 40
    $sections += [pscustomobject]@{
        VSize = Get-U32 ($o + 8)
        VAddr = Get-U32 ($o + 12)
        RSize = Get-U32 ($o + 16)
        RPtr  = Get-U32 ($o + 20)
    }
}

function RvaToOff([uint32]$rva) {
    foreach ($s in $sections) {
        $span = [Math]::Max($s.VSize, $s.RSize)
        if ($rva -ge $s.VAddr -and $rva -lt ($s.VAddr + $span)) {
            return [int]($s.RPtr + ($rva - $s.VAddr))
        }
    }
    throw "RVA 0x$($rva.ToString('X')) is not in any section"
}

$eo = RvaToOff $expRva
$nnames = Get-U32 ($eo + 24)
$anames = Get-U32 ($eo + 32)
$ao = RvaToOff $anames

$names = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $nnames; $i++) {
    $nrva = Get-U32 ($ao + $i * 4)
    $no = RvaToOff $nrva
    $end = $no
    while ($bytes[$end] -ne 0) { $end++ }
    $names.Add([System.Text.Encoding]::ASCII.GetString($bytes, $no, $end - $no))
}
$names = @($names | Where-Object { $_ -like "$prefix*" } | Sort-Object -Unique)
if ($names.Count -eq 0) { throw "no symbols matching '$prefix*' found in $lib" }

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
[System.IO.File]::WriteAllText((Resolve-Path $out).Path, $text, [System.Text.Encoding]::ASCII)
Write-Host "wrote $out ($($names.Count) symbols)"
