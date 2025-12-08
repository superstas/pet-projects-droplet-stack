#!/usr/bin/env bats

# Unit tests for configuration file validation
# Tests cloud-init.yml syntax, workflow YAML syntax, and default values

load 'bats-support/load'
load 'bats-assert/load'

setup() {
    # Get the project root directory
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
    export PROJECT_ROOT
}

# ============================================================================
# Cloud-init Configuration Tests
# ============================================================================

@test "cloud-init.yml exists" {
    [ -f "$PROJECT_ROOT/infra/templates/cloud-init.yml" ]
}

@test "cloud-init.yml is valid YAML" {
    run python3 -c "import yaml; yaml.safe_load(open('$PROJECT_ROOT/infra/templates/cloud-init.yml'))"
    assert_success
}

@test "cloud-init.yml contains required packages" {
    required_packages=(
        "nginx"
        "certbot"
        "python3-certbot-nginx"
        "ufw"
        "sqlite3"
        "litecli"
        "prometheus"
        "unattended-upgrades"
        "logrotate"
    )
    
    for package in "${required_packages[@]}"; do
        run grep -q "$package" "$PROJECT_ROOT/infra/templates/cloud-init.yml"
        assert_success
    done
}

@test "cloud-init.yml configures SSH port" {
    run grep -q "Port [0-9]\+" "$PROJECT_ROOT/infra/templates/cloud-init.yml"
    assert_success
}

@test "cloud-init.yml disables password authentication" {
    run grep -q "PasswordAuthentication no" "$PROJECT_ROOT/infra/templates/cloud-init.yml"
    assert_success
}

@test "cloud-init.yml enables pubkey authentication" {
    run grep -q "PubkeyAuthentication yes" "$PROJECT_ROOT/infra/templates/cloud-init.yml"
    assert_success
}

@test "cloud-init.yml configures UFW firewall" {
    run grep -q "ufw limit [0-9]\+/tcp" "$PROJECT_ROOT/infra/templates/cloud-init.yml"
    assert_success
    run grep -q "ufw allow 80/tcp" "$PROJECT_ROOT/infra/templates/cloud-init.yml"
    assert_success
    run grep -q "ufw allow 443/tcp" "$PROJECT_ROOT/infra/templates/cloud-init.yml"
    assert_success
}

@test "cloud-init.yml creates 1GB swap" {
    run grep -q "bs=1M count=1024" "$PROJECT_ROOT/infra/templates/cloud-init.yml"
    assert_success
}

@test "cloud-init.yml sets swappiness to 10" {
    run grep -q "vm.swappiness=10" "$PROJECT_ROOT/infra/templates/cloud-init.yml"
    assert_success
}

@test "cloud-init.yml configures log retention to 90 days" {
    run grep -q "MaxRetentionSec=90d" "$PROJECT_ROOT/infra/templates/cloud-init.yml"
    assert_success
}

@test "cloud-init.yml disables automatic reboot" {
    run grep -q 'Automatic-Reboot "false"' "$PROJECT_ROOT/infra/templates/cloud-init.yml"
    assert_success
}

# ============================================================================
# GitHub Workflow Tests - create-droplet.yml
# ============================================================================

@test "create-droplet.yml exists" {
    [ -f "$PROJECT_ROOT/.github/workflows/create-droplet.yml" ]
}

@test "create-droplet.yml is valid YAML" {
    run python3 -c "import yaml; yaml.safe_load(open('$PROJECT_ROOT/.github/workflows/create-droplet.yml'))"
    assert_success
}

@test "create-droplet.yml has required input: domain_name" {
    run grep -q "domain_name:" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

@test "create-droplet.yml has required input: region" {
    run grep -q "region:" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

@test "create-droplet.yml has default app_port of 9000" {
    run grep -A 2 "app_port:" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_output --partial "default: 9000"
}

@test "create-droplet.yml has default metrics_path of /metrics" {
    run grep -A 4 "metrics_path:" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_output --partial "default: '/metrics'"
}

@test "create-droplet.yml uses correct droplet size" {
    run grep -q "DROPLET_SIZE: s-1vcpu-512mb-10gb" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

@test "create-droplet.yml uses Debian 12 image" {
    run grep -q "DROPLET_IMAGE: debian-12-x64" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

@test "create-droplet.yml references DO_API_TOKEN secret" {
    run grep -q "secrets.DO_API_TOKEN" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

@test "create-droplet.yml references SSH_PUBLIC_KEY secret" {
    run grep -q "secrets.SSH_PUBLIC_KEY" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

@test "create-droplet.yml references SSH_PRIVATE_KEY secret" {
    run grep -q "secrets.SSH_PRIVATE_KEY" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

@test "create-droplet.yml has ssh_port input with default 53222" {
    run grep -A 4 "ssh_port:" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_output --partial "default: 53222"
}

@test "create-droplet.yml validates SSH port range" {
    run grep -q "SSH port must be between 1024 and 65535" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

@test "create-droplet.yml mentions reserved system ports in validation" {
    run grep -q "Ports below 1024 are system ports" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

@test "create-droplet.yml mentions port 22 as reserved" {
    run grep -q "22" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

@test "create-droplet.yml mentions port 80 as reserved" {
    run grep -q "80" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

@test "create-droplet.yml mentions port 443 as reserved" {
    run grep -q "443" "$PROJECT_ROOT/.github/workflows/create-droplet.yml"
    assert_success
}

# ============================================================================
# GitHub Workflow Tests - add-application.yml
# ============================================================================

@test "add-application.yml exists" {
    [ -f "$PROJECT_ROOT/.github/workflows/add-application.yml" ]
}

@test "add-application.yml is valid YAML" {
    run python3 -c "import yaml; yaml.safe_load(open('$PROJECT_ROOT/.github/workflows/add-application.yml'))"
    assert_success
}

@test "add-application.yml has required input: domain_name" {
    run grep -q "domain_name:" "$PROJECT_ROOT/.github/workflows/add-application.yml"
    assert_success
}

@test "add-application.yml has required input: app_port" {
    run grep -q "app_port:" "$PROJECT_ROOT/.github/workflows/add-application.yml"
    assert_success
}

@test "add-application.yml has required input: droplet_ip" {
    run grep -q "droplet_ip:" "$PROJECT_ROOT/.github/workflows/add-application.yml"
    assert_success
}

# ============================================================================
# GitHub Workflow Tests - deploy.yml
# ============================================================================

@test "deploy.yml exists" {
    [ -f "$PROJECT_ROOT/.github/workflows/deploy.yml" ]
}

@test "deploy.yml is valid YAML" {
    run python3 -c "import yaml; yaml.safe_load(open('$PROJECT_ROOT/.github/workflows/deploy.yml'))"
    assert_success
}

@test "deploy.yml triggers on version tags" {
    run grep -A 2 "push:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "tags:"
    assert_output --partial "v*.*.*"
}

@test "deploy.yml has default app_directory of ./app" {
    run grep -A 4 "app_directory:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "default: './app'"
}

# ============================================================================
# Setup Script Tests
# ============================================================================

@test "setup-application.sh exists" {
    [ -f "$PROJECT_ROOT/infra/scripts/setup-application.sh" ]
}

@test "setup-application.sh is executable" {
    [ -x "$PROJECT_ROOT/infra/scripts/setup-application.sh" ]
}

@test "setup-application.sh has shebang" {
    run head -n 1 "$PROJECT_ROOT/infra/scripts/setup-application.sh"
    assert_output --partial "#!/bin/bash"
}

@test "setup-application.sh uses set -e for error handling" {
    run grep -q "set -e" "$PROJECT_ROOT/infra/scripts/setup-application.sh"
    assert_success
}

@test "setup-application.sh defines sanitize_domain function" {
    run grep -q "sanitize_domain()" "$PROJECT_ROOT/infra/scripts/setup-application.sh"
    assert_success
}
