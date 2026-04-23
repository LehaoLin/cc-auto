$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Set-Location $ProjectDir

if (-not (Test-Path ".venv")) {
    uv venv
}

uv pip install -e .

uv run cca claude
