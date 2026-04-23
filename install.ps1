$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BinDir = Join-Path $env:USERPROFILE ".local\bin"

Write-Host "[cca] Installing dependencies..."
Set-Location $ProjectDir

if (-not (Test-Path ".venv")) {
    uv venv
}

uv pip install -e .

Write-Host "[cca] Creating cca command in $BinDir..."
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

$WrapperPath = Join-Path $BinDir "cca.ps1"
@"
param([Parameter(ValueFromRemainingArguments)]`$args)
exec uv run --project "$ProjectDir" cca @args
"@ | Set-Content -Path $WrapperPath -Encoding UTF8

$OldPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($OldPath -like "*$BinDir*") {
    Write-Host "[cca] $BinDir already in PATH"
} else {
    [Environment]::SetEnvironmentVariable("Path", "$BinDir;$OldPath", "User")
    Write-Host "[cca] Added $BinDir to user PATH"
    Write-Host "[cca] Restart your terminal or run: `$env:Path = `"$BinDir;`$env:Path`""
}

Write-Host "[cca] Done! You can now run 'cca claude' in any directory"
