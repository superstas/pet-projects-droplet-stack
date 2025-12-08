#!/bin/bash
set -e

# Example start script for Go application
# This script will be executed by systemd

# Get the port from environment variable or use default
PORT=${APP_PORT:-9000}
echo "Starting example application on port $PORT..."

# Start the application
exec ./example-app -port "$PORT"
