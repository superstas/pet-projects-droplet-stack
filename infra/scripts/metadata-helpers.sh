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
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "Error: GITHUB_TOKEN environment variable is required" >&2
    return 1
  fi
  
  if [ -z "${GITHUB_REPOSITORY:-}" ]; then
    echo "Error: GITHUB_REPOSITORY environment variable is required" >&2
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
    echo "Error: GitHub API request failed with HTTP $http_code" >&2
    if echo "$response" | jq -e '.message' > /dev/null 2>&1; then
      echo "Error message: $(echo "$response" | jq -r '.message')" >&2
    fi
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
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "Error: GITHUB_TOKEN environment variable is required" >&2
    return 1
  fi
  
  if [ -z "${GITHUB_REPOSITORY:-}" ]; then
    echo "Error: GITHUB_REPOSITORY environment variable is required" >&2
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
    echo "Error: GitHub API request failed with HTTP $api_http_code" >&2
    if echo "$api_response" | jq -e '.message' > /dev/null 2>&1; then
      local error_msg=$(echo "$api_response" | jq -r '.message')
      echo "Error: GitHub API request failed: $error_msg" >&2
    fi
    echo "Please check GITHUB_TOKEN permissions and try again" >&2
    return 1
  fi
  
  return 0
}

# get_droplet_ip - Extracts droplet IP address from metadata
#
# Returns:
#   IP address string, or empty string if not found
#
# Environment variables required:
#   GITHUB_TOKEN - GitHub token for API authentication
#   GITHUB_REPOSITORY - Repository in format owner/repo
#
# Example:
#   DROPLET_IP=$(get_droplet_ip)
get_droplet_ip() {
  local metadata
  metadata=$(get_metadata) || return 1
  
  if [ "$metadata" = "{}" ]; then
    echo ""
    return 0
  fi
  
  echo "$metadata" | jq -r '.droplet.ip // empty'
}

# get_ssh_port - Extracts SSH port from metadata
#
# Returns:
#   SSH port number, or 53222 (default) if not found
#
# Environment variables required:
#   GITHUB_TOKEN - GitHub token for API authentication
#   GITHUB_REPOSITORY - Repository in format owner/repo
#
# Example:
#   SSH_PORT=$(get_ssh_port)
get_ssh_port() {
  local metadata
  metadata=$(get_metadata) || return 1
  
  if [ "$metadata" = "{}" ]; then
    echo "53222"
    return 0
  fi
  
  echo "$metadata" | jq -r '.droplet.ssh_port // 53222'
}

# get_ssh_user - Extracts SSH username from metadata
#
# Returns:
#   SSH username, or "admin" (default) if not found
#
# Environment variables required:
#   GITHUB_TOKEN - GitHub token for API authentication
#   GITHUB_REPOSITORY - Repository in format owner/repo
#
# Example:
#   SSH_USER=$(get_ssh_user)
get_ssh_user() {
  local metadata
  metadata=$(get_metadata) || return 1
  
  if [ "$metadata" = "{}" ]; then
    echo "admin"
    return 0
  fi
  
  echo "$metadata" | jq -r '.droplet.ssh_user // "admin"'
}
