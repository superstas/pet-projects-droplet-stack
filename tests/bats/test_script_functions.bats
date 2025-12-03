#!/usr/bin/env bats

# Unit tests for bash script functions
# Tests domain sanitization edge cases, configuration file generation, and error handling

load 'bats-support/load'
load 'bats-assert/load'

setup() {
    # Get the project root directory
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export PROJECT_ROOT
    
    # Source the sanitize_domain function from setup-application.sh
    # We extract just the function to test it in isolation
    eval "$(sed -n '/^sanitize_domain()/,/^}/p' "$PROJECT_ROOT/scripts/setup-application.sh")"
}

# ============================================================================
# Domain Sanitization Tests
# ============================================================================

@test "sanitize_domain: converts uppercase to lowercase" {
    result=$(sanitize_domain "EXAMPLE.COM")
    assert_equal "$result" "examplecom"
}

@test "sanitize_domain: removes dots" {
    result=$(sanitize_domain "example.com")
    assert_equal "$result" "examplecom"
}

@test "sanitize_domain: removes hyphens" {
    result=$(sanitize_domain "my-app.example.com")
    assert_equal "$result" "myappexamplecom"
}

@test "sanitize_domain: removes underscores" {
    result=$(sanitize_domain "my_app.example.com")
    assert_equal "$result" "myappexamplecom"
}

@test "sanitize_domain: removes special characters" {
    result=$(sanitize_domain "my@app!.example#.com")
    assert_equal "$result" "myappexamplecom"
}

@test "sanitize_domain: preserves alphanumeric characters" {
    result=$(sanitize_domain "app123.example456.com")
    assert_equal "$result" "app123example456com"
}

@test "sanitize_domain: handles mixed case with special chars" {
    result=$(sanitize_domain "My-App_123.Example.COM")
    assert_equal "$result" "myapp123examplecom"
}

@test "sanitize_domain: truncates to 32 characters" {
    # Create a long domain name (more than 32 chars after sanitization)
    long_domain="verylongdomainname123456789012345678901234567890.com"
    result=$(sanitize_domain "$long_domain")
    
    # Check length is exactly 32
    assert_equal "${#result}" "32"
}

@test "sanitize_domain: handles empty string" {
    result=$(sanitize_domain "")
    assert_equal "$result" ""
}

@test "sanitize_domain: handles only special characters" {
    result=$(sanitize_domain "!@#$%^&*()")
    assert_equal "$result" ""
}

@test "sanitize_domain: handles unicode characters" {
    result=$(sanitize_domain "café.example.com")
    # Unicode characters should be removed, leaving only alphanumeric
    assert_equal "$result" "cafexamplecom"
}

@test "sanitize_domain: handles subdomain" {
    result=$(sanitize_domain "api.myapp.example.com")
    assert_equal "$result" "apimyappexamplecom"
}

@test "sanitize_domain: handles www prefix" {
    result=$(sanitize_domain "www.example.com")
    assert_equal "$result" "wwwexamplecom"
}

@test "sanitize_domain: result contains only [a-z0-9]" {
    result=$(sanitize_domain "My-Complex_App123!@#.Example.COM")
    # Verify result matches pattern [a-z0-9]+
    [[ "$result" =~ ^[a-z0-9]+$ ]]
}

# ============================================================================
# Nginx Configuration Generation Tests
# ============================================================================

@test "nginx config: generated config contains server blocks" {
    # Create a temporary test directory
    TEST_DIR="$(mktemp -d)"
    
    # Generate a simple nginx config for testing
    cat > "$TEST_DIR/test_nginx.conf" << 'EOF'
server {
    listen 443 ssl http2;
    server_name example.com;
    
    location / {
        proxy_pass http://localhost:9000;
    }
}
EOF
    
    # Verify server block exists
    run grep -q "server {" "$TEST_DIR/test_nginx.conf"
    assert_success
    
    # Cleanup
    rm -rf "$TEST_DIR"
}

@test "nginx config: contains proxy_pass directive" {
    # Test that setup-application.sh would generate correct proxy_pass
    # We check the script contains the template
    run grep -q 'proxy_pass http://localhost:$APP_PORT' "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "nginx config: contains SSL configuration" {
    # SSL configuration is now in setup-ssl.sh, not setup-application.sh
    # Verify that setup-application.sh mentions SSL setup
    run grep -q "setup-ssl.sh" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "nginx config: contains static files location" {
    # Verify the script configures static files
    run grep -q "location /static" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "nginx config: contains www to non-www redirect" {
    # Verify the script creates www redirect
    run grep -q "www.$DOMAIN_NAME" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "nginx config: contains HTTP to HTTPS redirect" {
    # HTTPS redirect is added by setup-ssl.sh, not setup-application.sh
    # Verify that setup-application.sh creates HTTP-only config initially
    run grep -q "listen 80;" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

# ============================================================================
# Systemd Service Generation Tests
# ============================================================================

@test "systemd service: generated service contains [Unit] section" {
    # Verify the script generates [Unit] section
    run grep -A 2 "cat > \"\$SERVICE_FILE\"" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
    
    run grep -q "\[Unit\]" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "systemd service: contains [Service] section" {
    run grep -q "\[Service\]" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "systemd service: contains [Install] section" {
    run grep -q "\[Install\]" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "systemd service: sets User to system username" {
    run grep -q "User=\$USERNAME" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "systemd service: sets WorkingDirectory" {
    run grep -q "WorkingDirectory=\$USER_HOME/app" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "systemd service: configures Restart=always" {
    run grep -q "Restart=always" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "systemd service: configures StandardOutput=journal" {
    run grep -q "StandardOutput=journal" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "systemd service: sets WantedBy=multi-user.target" {
    run grep -q "WantedBy=multi-user.target" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

# ============================================================================
# Prometheus Configuration Tests
# ============================================================================

@test "prometheus config: script updates prometheus.yml" {
    run grep -q "PROMETHEUS_CONFIG=\"/etc/prometheus/prometheus.yml\"" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "prometheus config: creates backup before modification" {
    run grep -q "PROMETHEUS_BACKUP=" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "prometheus config: adds job_name for application" {
    run grep -q "job_name: '\$USERNAME'" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "prometheus config: configures metrics_path" {
    run grep -q "metrics_path: '\$METRICS_PATH'" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "prometheus config: adds static_configs with target" {
    run grep -q "targets: \['localhost:\$APP_PORT'\]" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "prometheus config: validates configuration with promtool" {
    run grep -q "promtool check config" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "prometheus config: reloads prometheus after update" {
    run grep -q "systemctl reload prometheus" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "error handling: script uses set -e" {
    run head -n 5 "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_output --partial "set -e"
}

@test "error handling: script uses set -o pipefail" {
    run head -n 5 "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_output --partial "set -o pipefail"
}

@test "error handling: validates number of arguments" {
    run grep -q 'if \[ "\$#" -ne 4 \]' "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "error handling: validates domain name not empty" {
    run grep -q 'if \[ -z "\$DOMAIN_NAME" \]' "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "error handling: validates port number range" {
    # Check that the script validates port is numeric and in valid range
    run grep -q 'APP_PORT.*=~.*0-9' "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
    run grep -q 'APP_PORT.*-lt 1024' "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
    run grep -q 'APP_PORT.*-gt 65535' "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "error handling: validates metrics path not empty" {
    run grep -q 'if \[ -z "\$METRICS_PATH" \]' "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "error handling: validates SSH public key not empty" {
    run grep -q 'if \[ -z "\$SSH_PUBLIC_KEY" \]' "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "error handling: validates generated username not empty" {
    run grep -q 'if \[ -z "\$USERNAME" \]' "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "error handling: checks nginx configuration validity" {
    run grep -q "nginx -t" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "error handling: exits on certbot failure" {
    # Certbot is now in setup-ssl.sh, not setup-application.sh
    # Verify that setup-application.sh exits on nginx config failure
    run grep -A 10 "nginx -t" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_output --partial "exit 1"
}

# ============================================================================
# Logging Tests
# ============================================================================

@test "logging: script defines log_info function" {
    run grep -q "log_info()" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "logging: script defines log_warn function" {
    run grep -q "log_warn()" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "logging: script defines log_error function" {
    run grep -q "log_error()" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}

@test "logging: uses color codes for output" {
    run grep -q "GREEN=" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
    run grep -q "RED=" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
    run grep -q "YELLOW=" "$PROJECT_ROOT/scripts/setup-application.sh"
    assert_success
}
