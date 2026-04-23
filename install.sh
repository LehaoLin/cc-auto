#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"

echo "[cca] Installing dependencies..."
cd "$PROJECT_DIR"

if [ ! -d ".venv" ]; then
    uv venv
fi

uv pip install -e .

echo "[cca] Creating cca command in $BIN_DIR..."
mkdir -p "$BIN_DIR"

cat > "$BIN_DIR/cca" << EOF
#!/bin/bash
exec uv run --project "$PROJECT_DIR" cca "\$@"
EOF
chmod +x "$BIN_DIR/cca"

case ":$PATH:" in
    *":$BIN_DIR:"*)
        echo "[cca] $BIN_DIR already in PATH"
        ;;
    *)
        SHELL_RC="$HOME/.zshrc"
        if [ "$(basename "$SHELL")" = "bash" ]; then
            SHELL_RC="$HOME/.bashrc"
        fi
        if grep -q "# cca tool" "$SHELL_RC" 2>/dev/null; then
            echo "[cca] PATH entry already exists in $SHELL_RC"
        else
            echo "" >> "$SHELL_RC"
            echo "# cca tool" >> "$SHELL_RC"
            echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
            echo "[cca] Added $BIN_DIR to PATH in $SHELL_RC"
            echo "[cca] Run 'source $SHELL_RC' or restart your terminal"
        fi
        ;;
esac

echo "[cca] Done! You can now run 'cca claude' in any directory"
