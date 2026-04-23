#!/bin/bash
set -e

cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
    uv venv
fi

uv pip install -e .

uv run cca claude
