#!/bin/bash
set -e

# Example start script for Go application
# This script will be executed by systemd

# Get the port from environment variable or use default
PORT=${APP_PORT:-9000}

echo "Starting example application on port $PORT..."

# Build the Go application if not already built
if [ ! -f "./example-app" ]; then
    echo "Building Go application..."
    go build -o example-app main.go
fi

# Start the application
exec ./example-app -port "$PORT"
