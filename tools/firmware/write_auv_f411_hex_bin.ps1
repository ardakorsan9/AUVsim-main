#Requires -Version 5.1
param(
  [Parameter(Mandatory = $true)]
  [string]$CMakeBuildDir
)

$ErrorActionPreference = 'Stop'

function Write-ExportFailure {
  param([string]$Message)
  Write-Error $Message
  exit 1
}

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$BuildDir = $CMakeBuildDir
if (-not [System.IO.Path]::IsPathRooted($BuildDir)) {
  $BuildDir = Join-Path $ProjectRoot $BuildDir
}
$BuildDir = [System.IO.Path]::GetFullPath($BuildDir)

$ElfPath = Join-Path $BuildDir 'auv_f411.elf'
$ArtifactDir = Join-Path $ProjectRoot 'artifacts\firmware'
$HexPath = Join-Path $ArtifactDir 'auv_f411.hex'
$BinPath = Join-Path $ArtifactDir 'auv_f411.bin'

$CMakeCmd = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $CMakeCmd) {
  Write-ExportFailure 'Required tool not found on PATH: cmake'
}

$ObjcopyCmd = Get-Command arm-none-eabi-objcopy -ErrorAction SilentlyContinue
if (-not $ObjcopyCmd) {
  Write-ExportFailure 'Required tool not found on PATH: arm-none-eabi-objcopy'
}

& $CMakeCmd.Source --build $BuildDir --target auv_f411
if ($LASTEXITCODE -ne 0) {
  Write-ExportFailure ("cmake --build failed for {0}" -f $BuildDir)
}

if (-not (Test-Path -LiteralPath $ElfPath -PathType Leaf)) {
  Write-ExportFailure ("Missing isolated ELF: {0}" -f $ElfPath)
}

New-Item -ItemType Directory -Path $ArtifactDir -Force | Out-Null

& $ObjcopyCmd.Source -O ihex $ElfPath $HexPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $HexPath -PathType Leaf)) {
  Write-ExportFailure ("HEX export failed: {0}" -f $HexPath)
}

& $ObjcopyCmd.Source -O binary $ElfPath $BinPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $BinPath -PathType Leaf)) {
  Write-ExportFailure ("BIN export failed: {0}" -f $BinPath)
}

Write-Host "Export complete:"
Write-Host ("  ELF: {0}" -f $ElfPath)
Write-Host ("  HEX: {0}" -f $HexPath)
Write-Host ("  BIN: {0}" -f $BinPath)
exit 0
