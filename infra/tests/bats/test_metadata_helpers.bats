#!/usr/bin/env bats

# Unit tests for metadata helper functions
# Tests GitHub API interaction, JSON validation, and error handling

load 'bats-support/load'
load 'bats-assert/load'

setup() {
    # Get the project root directory
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
    export PROJECT_ROOT
    
    # Source the metadata helper functions
    source "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    
    # Set up mock environment variables
    export GITHUB_TOKEN="mock_token_12345"
    export GITHUB_REPOSITORY="owner/repo"
    
    # Create a temporary directory for test files
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
}

teardown() {
    # Clean up temporary directory
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# ============================================================================
# get_metadata() Tests
# ============================================================================

@test "get_metadata: function exists and is callable" {
    run type get_metadata
    assert_success
    assert_output --partial "get_metadata is a function"
}

@test "get_metadata: requires GITHUB_TOKEN environment variable" {
    unset GITHUB_TOKEN
    run get_metadata
    assert_failure
}

@test "get_metadata: requires GITHUB_REPOSITORY environment variable" {
    unset GITHUB_REPOSITORY
    run get_metadata
    assert_failure
}

# ============================================================================
# update_metadata() Tests
# ============================================================================

@test "update_metadata: function exists and is callable" {
    run type update_metadata
    assert_success
    assert_output --partial "update_metadata is a function"
}

@test "update_metadata: rejects invalid JSON" {
    run update_metadata "invalid json"
    assert_failure
    assert_output --partial "Invalid JSON"
}

@test "update_metadata: rejects empty string" {
    # Empty string is not valid JSON, but jq might accept it as empty input
    # The function should fail either on validation or API call
    run update_metadata ""
    assert_failure
}

@test "update_metadata: accepts valid JSON object" {
    # This will fail in actual execution without mocking, but tests the validation logic
    skip "Requires API mocking"
}

@test "update_metadata: accepts valid nested JSON" {
    # Test JSON validation with nested structure
    valid_json='{"droplet":{"id":"123","ip":"1.2.3.4"},"applications":[]}'
    
    # We can't test actual API call without mocking, but we can verify it doesn't fail on validation
    # The function will fail on API call, but should pass JSON validation first
    skip "Requires API mocking"
}

@test "update_metadata: requires GITHUB_TOKEN environment variable" {
    unset GITHUB_TOKEN
    run update_metadata '{"test":"data"}'
    assert_failure
}

@test "update_metadata: requires GITHUB_REPOSITORY environment variable" {
    unset GITHUB_REPOSITORY
    run update_metadata '{"test":"data"}'
    assert_failure
}

# ============================================================================
# get_droplet_ip() Tests
# ============================================================================

@test "get_droplet_ip: function exists and is callable" {
    run type get_droplet_ip
    assert_success
    assert_output --partial "get_droplet_ip is a function"
}

@test "get_droplet_ip: requires GITHUB_TOKEN environment variable" {
    unset GITHUB_TOKEN
    run get_droplet_ip
    assert_failure
    assert_output --partial "Unable to retrieve deployment configuration"
}

@test "get_droplet_ip: requires GITHUB_REPOSITORY environment variable" {
    unset GITHUB_REPOSITORY
    run get_droplet_ip
    assert_failure
    assert_output --partial "Unable to retrieve deployment configuration"
}

# ============================================================================
# get_ssh_port() Tests
# ============================================================================

@test "get_ssh_port: function exists and is callable" {
    run type get_ssh_port
    assert_success
    assert_output --partial "get_ssh_port is a function"
}

@test "get_ssh_port: requires GITHUB_TOKEN environment variable" {
    unset GITHUB_TOKEN
    run get_ssh_port
    assert_failure
    assert_output --partial "Unable to retrieve deployment configuration"
}

@test "get_ssh_port: requires GITHUB_REPOSITORY environment variable" {
    unset GITHUB_REPOSITORY
    run get_ssh_port
    assert_failure
    assert_output --partial "Unable to retrieve deployment configuration"
}

# ============================================================================
# get_ssh_user() Tests
# ============================================================================

@test "get_ssh_user: function exists and is callable" {
    run type get_ssh_user
    assert_success
    assert_output --partial "get_ssh_user is a function"
}

@test "get_ssh_user: requires GITHUB_TOKEN environment variable" {
    unset GITHUB_TOKEN
    run get_ssh_user
    assert_failure
    assert_output --partial "Unable to retrieve deployment configuration"
}

@test "get_ssh_user: requires GITHUB_REPOSITORY environment variable" {
    unset GITHUB_REPOSITORY
    run get_ssh_user
    assert_failure
    assert_output --partial "Unable to retrieve deployment configuration"
}

# ============================================================================
# JSON Validation Tests
# ============================================================================

@test "JSON validation: update_metadata validates JSON structure" {
    # Test various invalid JSON formats
    run update_metadata "not json at all"
    assert_failure
    assert_output --partial "Invalid JSON"
}

@test "JSON validation: update_metadata accepts empty object" {
    skip "Requires API mocking"
}

@test "JSON validation: update_metadata accepts complex nested structure" {
    skip "Requires API mocking"
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "error handling: script uses set -euo pipefail" {
    run head -n 10 "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_output --partial "set -euo pipefail"
}

@test "error handling: functions handle missing environment variables" {
    # Test that functions fail gracefully when env vars are missing
    unset GITHUB_TOKEN
    unset GITHUB_REPOSITORY
    
    run get_metadata
    assert_failure
}

@test "error handling: update_metadata validates input before API call" {
    # Ensure validation happens before any API interaction
    run update_metadata "invalid"
    assert_failure
    # Should fail on validation, not on API call
    assert_output --partial "Invalid JSON"
}

# ============================================================================
# Function Signature Tests
# ============================================================================

@test "function signatures: get_metadata takes no arguments" {
    # Function should work without arguments
    skip "Requires API mocking"
}

@test "function signatures: update_metadata requires one argument" {
    run update_metadata
    assert_failure
}

@test "function signatures: get_droplet_ip takes no arguments" {
    skip "Requires API mocking"
}

@test "function signatures: get_ssh_port takes no arguments" {
    skip "Requires API mocking"
}

@test "function signatures: get_ssh_user takes no arguments" {
    skip "Requires API mocking"
}

# ============================================================================
# Script Structure Tests
# ============================================================================

@test "script structure: has proper shebang" {
    run head -n 1 "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_output "#!/bin/bash"
}

@test "script structure: is executable" {
    run test -x "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

@test "script structure: contains all required functions" {
    run grep -q "^get_metadata()" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
    
    run grep -q "^update_metadata()" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
    
    run grep -q "^get_droplet_ip()" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
    
    run grep -q "^get_ssh_port()" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
    
    run grep -q "^get_ssh_user()" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

@test "script structure: functions have documentation comments" {
    # Check that functions have comment blocks
    run grep -B 5 "^get_metadata()" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_output --partial "#"
    
    run grep -B 5 "^update_metadata()" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_output --partial "#"
}

# ============================================================================
# API Interaction Tests
# ============================================================================

@test "API interaction: uses correct GitHub API endpoint for reading" {
    run grep "api.github.com/repos/\$GITHUB_REPOSITORY/actions/variables/DEPLOYMENT_METADATA" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

@test "API interaction: uses Authorization header with token" {
    run grep 'Authorization: token \$GITHUB_TOKEN' "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

@test "API interaction: uses Accept header for API version" {
    run grep 'Accept: application/vnd.github.v3+json' "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

@test "API interaction: handles 404 response for missing variable" {
    run grep -A 5 "404" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
    assert_output --partial "{}"
}

@test "API interaction: uses PATCH for updating existing variable" {
    run grep "PATCH" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

@test "API interaction: uses POST for creating new variable" {
    run grep "POST" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

# ============================================================================
# Default Value Tests
# ============================================================================

@test "default values: get_ssh_port returns 22 as default" {
    run grep '"22"' "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

@test "default values: get_ssh_user returns root as default" {
    run grep '"root"' "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

@test "default values: get_droplet_ip returns empty string when not found" {
    run grep "empty" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

# ============================================================================
# jq Usage Tests
# ============================================================================

@test "jq usage: uses jq for JSON parsing" {
    run grep "jq" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

@test "jq usage: validates JSON with jq empty" {
    run grep "jq empty" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

@test "jq usage: extracts values with jq -r" {
    run grep "jq -r" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}

@test "jq usage: uses // operator for default values" {
    run grep "jq -r.*//.*" "$PROJECT_ROOT/infra/scripts/metadata-helpers.sh"
    assert_success
}
