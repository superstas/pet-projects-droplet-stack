#!/bin/bash

# Metadata Helper Functions for GitHub Actions Variables
# This script provides functions to interact with the DEPLOYMENT_METADATA
# GitHub Actions variable through the GitHub REST API.

set -euo pipefail

# get_metadata - Reads metadata from GitHub Actions Variable
#
# Returns:
#   JSON string with metadata, or empty object {} if variable doesn't exist
#
# Environment variables required:
#   GITHUB_TOKEN - GitHub token for API authentication
#   GITHUB_REPOSITORY - Repository in format owner/repo
#
# Example:
#   METADATA=$(get_metadata)
get_metadata() {
  # Validate required environment variables
  if ! validate_environment; then
    return 1
  fi
  
  local response
  local http_code
  
  # Make API request to get the variable
  response=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/variables/DEPLOYMENT_METADATA" 2>&1)
  
  # Extract HTTP code from last line
  http_code=$(echo "$response" | tail -n 1)
  response=$(echo "$response" | sed '$d')
  
  # Check if variable exists (404 = Not Found)
  if [ "$http_code" = "404" ]; then
    echo "{}"
    return 0
  fi
  
  # Check for other HTTP errors
  if [ "$http_code" -ge 400 ]; then
    echo "Warning: Unable to access deployment configuration" >&2
    # Don't expose detailed error messages that might contain sensitive information
    echo "{}"
    return 1
  fi
  
  # Extract value from response
  local value
  value=$(echo "$response" | jq -r '.value // "{}"' 2>/dev/null)
  
  # Validate that the value is valid JSON
  if ! echo "$value" | jq empty 2>/dev/null; then
    echo "Warning: Metadata contains invalid JSON, returning empty object" >&2
    echo "{}"
    return 0
  fi
  
  echo "$value"
}

# update_metadata - Updates or creates the DEPLOYMENT_METADATA variable
#
# Parameters:
#   $1 - json_data: JSON string with new metadata
#
# Returns:
#   0 on success, 1 on error
#
# Environment variables required:
#   GITHUB_TOKEN - GitHub token for API authentication
#   GITHUB_REPOSITORY - Repository in format owner/repo
#
# Example:
#   update_metadata '{"droplet":{"ip":"1.2.3.4"}}'
update_metadata() {
  local json_data="${1:-}"
  
  # Validate required environment variables
  if ! validate_environment; then
    return 1
  fi
  
  # Validate JSON input
  if ! echo "$json_data" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON data provided" >&2
    echo "Please ensure the metadata is valid JSON" >&2
    return 1
  fi
  
  # Check if variable exists
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/variables/DEPLOYMENT_METADATA")
  
  local api_response
  local api_http_code
  
  if [ "$http_code" = "200" ]; then
    # Update existing variable
    api_response=$(curl -s -w "\n%{http_code}" -X PATCH \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Content-Type: application/json" \
      "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/variables/DEPLOYMENT_METADATA" \
      -d "$(jq -n --arg name "DEPLOYMENT_METADATA" --arg value "$json_data" '{name: $name, value: $value}')")
    
    api_http_code=$(echo "$api_response" | tail -n 1)
    api_response=$(echo "$api_response" | sed '$d')
  else
    # Create new variable
    api_response=$(curl -s -w "\n%{http_code}" -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Content-Type: application/json" \
      "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/variables" \
      -d "$(jq -n --arg name "DEPLOYMENT_METADATA" --arg value "$json_data" '{name: $name, value: $value}')")
    
    api_http_code=$(echo "$api_response" | tail -n 1)
    api_response=$(echo "$api_response" | sed '$d')
  fi
  
  # Check for API errors
  if [ "$api_http_code" -ge 400 ]; then
    echo "Warning: Unable to update deployment configuration" >&2
    # Don't expose detailed error messages that might contain sensitive information
    echo "Please verify authentication and permissions" >&2
    return 1
  fi
  
  return 0
}

# get_droplet_ip - Extracts droplet IP address from metadata
#
# Returns:
#   IP address string, or empty string if not found
#   Output is suppressed by default for security
#
# Environment variables required:
#   GITHUB_TOKEN - GitHub token for API authentication
#   GITHUB_REPOSITORY - Repository in format owner/repo
#
# Example:
#   DROPLET_IP=$(get_droplet_ip) > /dev/null 2>&1
get_droplet_ip() {
  local metadata
  local ip_address
  
  # Secure error handling - don't expose sensitive information
  if ! metadata=$(get_metadata 2>/dev/null); then
    # Generic error message without revealing sensitive details
    echo "Warning: Unable to retrieve deployment configuration" >&2
    echo ""
    return 1
  fi
  
  if [ "$metadata" = "{}" ]; then
    # No metadata available - return empty string as secure fallback
    echo ""
    return 0
  fi
  
  # Extract IP with secure error handling
  if ! ip_address=$(echo "$metadata" | jq -r '.droplet.ip // empty' 2>/dev/null); then
    # Generic error message without exposing metadata structure
    echo "Warning: Configuration data format issue detected" >&2
    echo ""
    return 1
  fi
  
  # Validate IP address format without exposing the actual value
  if [ -n "$ip_address" ] && ! echo "$ip_address" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    echo "Warning: Invalid network configuration detected" >&2
    echo ""
    return 1
  fi
  
  echo "$ip_address"
}

# get_ssh_port - Extracts SSH port from metadata
#
# Returns:
#   SSH port number, or secure default if not found
#   Output is suppressed by default for security
#
# Environment variables required:
#   GITHUB_TOKEN - GitHub token for API authentication
#   GITHUB_REPOSITORY - Repository in format owner/repo
#
# Example:
#   SSH_PORT=$(get_ssh_port) > /dev/null 2>&1
get_ssh_port() {
  local metadata
  local ssh_port
  local default_port="22"
  
  # Secure error handling - don't expose sensitive information
  if ! metadata=$(get_metadata 2>/dev/null); then
    # Generic error message without revealing sensitive details
    echo "Warning: Unable to retrieve deployment configuration" >&2
    echo "$default_port"
    return 1
  fi
  
  if [ "$metadata" = "{}" ]; then
    # No metadata available - return secure default
    echo "$default_port"
    return 0
  fi
  
  # Extract port with secure error handling
  if ! ssh_port=$(echo "$metadata" | jq -r ".droplet.ssh_port // $default_port" 2>/dev/null); then
    # Generic error message without exposing metadata structure
    echo "Warning: Configuration data format issue detected" >&2
    echo "$default_port"
    return 1
  fi
  
  # Validate port number without exposing the actual value
  if ! echo "$ssh_port" | grep -qE '^[0-9]+$' || [ "$ssh_port" -lt 1 ] || [ "$ssh_port" -gt 65535 ]; then
    echo "Warning: Invalid port configuration detected" >&2
    echo "$default_port"
    return 1
  fi
  
  echo "$ssh_port"
}

# get_ssh_user - Extracts SSH username from metadata
#
# Returns:
#   SSH username, or secure default if not found
#   Output is suppressed by default for security
#
# Environment variables required:
#   GITHUB_TOKEN - GitHub token for API authentication
#   GITHUB_REPOSITORY - Repository in format owner/repo
#
# Example:
#   SSH_USER=$(get_ssh_user) > /dev/null 2>&1
get_ssh_user() {
  local metadata
  local ssh_user
  local default_user="root"
  
  # Secure error handling - don't expose sensitive information
  if ! metadata=$(get_metadata 2>/dev/null); then
    # Generic error message without revealing sensitive details
    echo "Warning: Unable to retrieve deployment configuration" >&2
    echo "$default_user"
    return 1
  fi
  
  if [ "$metadata" = "{}" ]; then
    # No metadata available - return secure default
    echo "$default_user"
    return 0
  fi
  
  # Extract username with secure error handling
  if ! ssh_user=$(echo "$metadata" | jq -r ".droplet.ssh_user // \"$default_user\"" 2>/dev/null); then
    # Generic error message without exposing metadata structure
    echo "Warning: Configuration data format issue detected" >&2
    echo "$default_user"
    return 1
  fi
  
  # Validate username format without exposing the actual value
  if [ -n "$ssh_user" ] && ! echo "$ssh_user" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    echo "Warning: Invalid user configuration detected" >&2
    echo "$default_user"
    return 1
  fi
  
  echo "$ssh_user"
}

# log_secure_status - Provides generic status messages for debugging without revealing sensitive values
#
# Parameters:
#   $1 - operation: The operation being performed (e.g., "connection", "deployment", "configuration")
#   $2 - status: The status (e.g., "starting", "success", "failed", "retrying")
#   $3 - context: Optional context (e.g., "ssh", "api", "validation")
#
# Returns:
#   Logs generic status message to stderr
#
# Example:
#   log_secure_status "connection" "starting" "ssh"
#   log_secure_status "deployment" "success"
log_secure_status() {
  local operation="${1:-operation}"
  local status="${2:-unknown}"
  local context="${3:-}"
  
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  if [ -n "$context" ]; then
    echo "[$timestamp] $operation ($context): $status" >&2
  else
    echo "[$timestamp] $operation: $status" >&2
  fi
}

# validate_environment - Validates required environment variables without exposing their values
#
# Returns:
#   0 if all required variables are set, 1 otherwise
#   Logs generic error messages without revealing variable contents
#
# Example:
#   if ! validate_environment; then
#     log_secure_status "configuration" "failed" "environment"
#     exit 1
#   fi
validate_environment() {
  local missing_vars=0
  
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "Warning: Authentication token not configured" >&2
    missing_vars=1
  fi
  
  if [ -z "${GITHUB_REPOSITORY:-}" ]; then
    echo "Warning: Repository identifier not configured" >&2
    missing_vars=1
  fi
  
  if [ "$missing_vars" -eq 1 ]; then
    echo "Error: Required environment configuration missing" >&2
    return 1
  fi
  
  return 0
}
