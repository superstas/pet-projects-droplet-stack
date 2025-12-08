#!/bin/bash
# Setup script for Bats testing framework

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_DIR="$SCRIPT_DIR/bats"

echo "Setting up Bats testing framework..."

# Create bats directory if it doesn't exist
mkdir -p "$BATS_DIR"

# Clone bats-core if not already present
if [ ! -d "$BATS_DIR/bats-core" ]; then
    echo "Cloning bats-core..."
    git clone https://github.com/bats-core/bats-core.git "$BATS_DIR/bats-core"
else
    echo "bats-core already exists, updating..."
    cd "$BATS_DIR/bats-core" && git pull && cd -
fi

# Clone bats-support if not already present
if [ ! -d "$BATS_DIR/bats-support" ]; then
    echo "Cloning bats-support..."
    git clone https://github.com/bats-core/bats-support.git "$BATS_DIR/bats-support"
else
    echo "bats-support already exists, updating..."
    cd "$BATS_DIR/bats-support" && git pull && cd -
fi

# Clone bats-assert if not already present
if [ ! -d "$BATS_DIR/bats-assert" ]; then
    echo "Cloning bats-assert..."
    git clone https://github.com/bats-core/bats-assert.git "$BATS_DIR/bats-assert"
else
    echo "bats-assert already exists, updating..."
    cd "$BATS_DIR/bats-assert" && git pull && cd -
fi

echo ""
echo "✓ Bats testing framework setup complete!"
echo ""
echo "To run tests:"
echo "  $BATS_DIR/bats-core/bin/bats infra/tests/bats/*.bats"
echo ""
