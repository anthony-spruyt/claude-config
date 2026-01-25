#!/bin/bash
set -euo pipefail

# Make all shell scripts executable (runs from repo root via postCreateCommand)
sudo find . -type f -name '*.sh' -exec chmod u+x {} +

# Change to script directory for package.json access
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Install and setup safe-chain FIRST before any other npm installs
echo "Installing safe-chain..."
npm install -g "@aikidosec/safe-chain@$(node -p "require('./package.json').dependencies['@aikidosec/safe-chain']")"

echo "Setting up safe-chain..."
safe-chain setup        # Shell aliases for interactive terminals
safe-chain setup-ci     # Executable shims for scripts/CI

# Add safe-chain shims to PATH for all subsequent commands
# This ensures pre-commit and other tools use protected pip/npm
export PATH="$HOME/.safe-chain/shims:$PATH"

echo "Installing pre-commit hooks..."
pre-commit install --install-hooks

echo "Installing Claude Code CLI..."
curl -fsSL https://claude.ai/install.sh | bash

echo ""
echo "Installing bats-core and test helpers..."
git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core
sudo /tmp/bats-core/install.sh /usr/local

sudo mkdir -p /usr/local/lib/bats
sudo git clone --depth 1 https://github.com/bats-core/bats-support.git /usr/local/lib/bats/bats-support
sudo git clone --depth 1 https://github.com/bats-core/bats-assert.git /usr/local/lib/bats/bats-assert
sudo git clone --depth 1 https://github.com/bats-core/bats-file.git /usr/local/lib/bats/bats-file

echo "✅ bats-core installed"

echo ""
echo "Installing Python test dependencies..."
pip3 install --quiet pathspec pyyaml
echo "✅ Python dependencies installed"

echo ""
echo "Running setup verification..."
"$SCRIPT_DIR/verify-setup.sh"
