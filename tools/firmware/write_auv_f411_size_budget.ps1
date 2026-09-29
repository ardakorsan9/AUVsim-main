#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function Write-BudgetFailure {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ElfPath = Join-Path $ProjectRoot 'stm32\gomulu\cubemx\build\auv_f411.elf'
$MapPath = Join-Path $ProjectRoot 'stm32\gomulu\cubemx\build\auv_f411.map'
$OutPath = Join-Path $ProjectRoot 'artifacts\firmware\auv_f411_size_budget.json'

$FlashLimit = 524288
$RamLimit = 131072
$McuPart = 'STM32F411CE'

if (-not (Test-Path -LiteralPath $ElfPath)) {
    Write-BudgetFailure "Missing ELF artifact: $ElfPath"
}

if (-not (Test-Path -LiteralPath $MapPath)) {
    Write-BudgetFailure "Missing MAP artifact: $MapPath"
}

$mapText = Get-Content -LiteralPath $MapPath -Raw -ErrorAction Stop
if ([string]::IsNullOrWhiteSpace($mapText)) {
    Write-BudgetFailure "Unparseable MAP artifact: empty file"
}

if ($mapText -notmatch 'Memory Configuration' -or $mapText -notmatch 'Linker script and memory map') {
    Write-BudgetFailure 'Unparseable MAP artifact: missing linker map markers'
}

$sizeCmd = Get-Command arm-none-eabi-size -ErrorAction SilentlyContinue
if (-not $sizeCmd) {
    Write-BudgetFailure 'arm-none-eabi-size not found on PATH'
}

$versionOutput = & $sizeCmd.Source --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-BudgetFailure 'arm-none-eabi-size --version failed'
}

$versionLine = ($versionOutput | Select-Object -First 1).ToString().Trim()
if ([string]::IsNullOrWhiteSpace($versionLine)) {
    Write-BudgetFailure 'arm-none-eabi-size version is empty'
}

$sizeOutput = & $sizeCmd.Source $ElfPath 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-BudgetFailure "arm-none-eabi-size failed for ELF: $ElfPath"
}

$sizeLine = $sizeOutput |
    Where-Object { $_ -match '\.elf\s*$' } |
    Select-Object -Last 1

if (-not $sizeLine) {
    Write-BudgetFailure "Unparseable ELF size output for: $ElfPath"
}

$sizeFields = ($sizeLine -replace '\s+', ' ').Trim() -split ' '
if ($sizeFields.Count -lt 5) {
    Write-BudgetFailure "Unparseable ELF size output: $sizeLine"
}

try {
    $textBytes = [int64]$sizeFields[0]
    $dataBytes = [int64]$sizeFields[1]
    $bssBytes = [int64]$sizeFields[2]
}
catch {
    Write-BudgetFailure "Unparseable ELF size fields: $sizeLine"
}

$flashUsed = $textBytes + $dataBytes
$ramUsed = $dataBytes + $bssBytes

$flashUsedPercent = [math]::Round((100.0 * $flashUsed) / $FlashLimit, 4)
$ramUsedPercent = [math]::Round((100.0 * $ramUsed) / $RamLimit, 4)

if ($flashUsed -gt $FlashLimit) {
    Write-BudgetFailure "Flash usage $flashUsed exceeds limit $FlashLimit"
}

if ($ramUsed -gt $RamLimit) {
    Write-BudgetFailure "RAM usage $ramUsed exceeds limit $RamLimit"
}

$approved = $false
$certified = $false

$report = [ordered]@{
    mcu                  = $McuPart
    flash_used           = $flashUsed
    flash_limit          = $FlashLimit
    flash_used_percent   = $flashUsedPercent
    ram_used             = $ramUsed
    ram_limit            = $RamLimit
    ram_used_percent     = $ramUsedPercent
    text_bytes           = $textBytes
    data_bytes           = $dataBytes
    bss_bytes            = $bssBytes
    elf_path             = 'stm32/gomulu/cubemx/build/auv_f411.elf'
    map_path             = 'stm32/gomulu/cubemx/build/auv_f411.map'
    source_tool          = 'arm-none-eabi-size'
    source_tool_version  = $versionLine
    generated_utc        = (Get-Date).ToUniversalTime().ToString('o')
    approved             = $approved
    certified            = $certified
}

$outDir = Split-Path -Parent $OutPath
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$json = $report | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText($OutPath, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

Write-Output "Wrote $OutPath (flash=$flashUsed/$FlashLimit, ram=$ramUsed/$RamLimit)"
exit 0
