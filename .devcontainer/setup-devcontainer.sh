#!/bin/bash
set -euo pipefail

# Implement custom devcontainer setup here. This is run after the devcontainer has been created.

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
