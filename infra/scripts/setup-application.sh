#!/bin/bash
set -e
set -o pipefail

# setup-application.sh
# Script to configure a new application on the server
#
# Usage: setup-application.sh <domain_name> <app_port> <metrics_path> <ssh_public_key>
#
# Parameters:
#   $1 - domain_name: Domain name for the application (e.g., example.com)
#   $2 - app_port: Port the application will listen on (e.g., 9000)
#   $3 - metrics_path: Path to metrics endpoint (e.g., /metrics)
#   $4 - ssh_public_key: SSH public key for the system user

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function: sanitize_domain
# Purpose: Convert domain name to valid Linux username
# Rules:
# - Convert to lowercase
# - Remove all non-alphanumeric characters
# - Truncate to 32 characters max
# - Domain name is already unique, no hash suffix needed
sanitize_domain() {
    local domain="$1"
    local sanitized
    
    # Convert to lowercase
    sanitized=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
    
    # Remove all non-alphanumeric characters
    sanitized=$(echo "$sanitized" | sed 's/[^a-z0-9]//g')
    
    # Truncate to 32 characters max (Linux username limit)
    if [ ${#sanitized} -gt 32 ]; then
        sanitized=$(echo "$sanitized" | cut -c1-32)
    fi
    
    echo "$sanitized"
}

# Validate arguments
if [ "$#" -ne 4 ]; then
    log_error "Usage: $0 <domain_name> <app_port> <metrics_path> <ssh_public_key>"
    exit 1
fi

DOMAIN_NAME="$1"
APP_PORT="$2"
METRICS_PATH="$3"
SSH_PUBLIC_KEY="$4"

# Validate inputs
if [ -z "$DOMAIN_NAME" ]; then
    log_error "Domain name cannot be empty"
    exit 1
fi

if ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [ "$APP_PORT" -lt 1024 ] || [ "$APP_PORT" -gt 65535 ]; then
    log_error "Invalid port number: $APP_PORT (must be between 1024 and 65535)"
    exit 1
fi

if [ -z "$METRICS_PATH" ]; then
    log_error "Metrics path cannot be empty"
    exit 1
fi

if [ -z "$SSH_PUBLIC_KEY" ]; then
    log_error "SSH public key cannot be empty"
    exit 1
fi

# Generate username from domain
USERNAME=$(sanitize_domain "$DOMAIN_NAME")

if [ -z "$USERNAME" ]; then
    log_error "Failed to generate valid username from domain: $DOMAIN_NAME"
    exit 1
fi

log_info "Starting application setup for domain: $DOMAIN_NAME"
log_info "Generated username: $USERNAME"
log_info "Application port: $APP_PORT"
log_info "Metrics path: $METRICS_PATH"

# ============================================================================
# USER CREATION
# ============================================================================

log_info "Creating system user: $USERNAME"

# Check if user already exists
if id "$USERNAME" &>/dev/null; then
    log_warn "User $USERNAME already exists, skipping user creation"
else
    # Create system user with home directory
    # -m: create home directory
    # -s: set shell to /bin/bash
    # Note: Not adding to sudo group - will configure limited sudo access below
    useradd -m -s /bin/bash "$USERNAME"
    log_info "User $USERNAME created successfully"
fi

# Configure limited sudo access for this user
# Allow user to manage only their own service without password
SERVICE_NAME="app-$USERNAME"
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"

log_info "Configuring limited sudo access for $USERNAME"

cat > "$SUDOERS_FILE" << EOF
# Limited sudo access for application user: $USERNAME
# User can only manage their own service

# Allow service management
$USERNAME ALL=(ALL) NOPASSWD: /bin/systemctl start $SERVICE_NAME
$USERNAME ALL=(ALL) NOPASSWD: /bin/systemctl stop $SERVICE_NAME
$USERNAME ALL=(ALL) NOPASSWD: /bin/systemctl restart $SERVICE_NAME
$USERNAME ALL=(ALL) NOPASSWD: /bin/systemctl reload $SERVICE_NAME
$USERNAME ALL=(ALL) NOPASSWD: /bin/systemctl status $SERVICE_NAME
$USERNAME ALL=(ALL) NOPASSWD: /bin/systemctl is-active $SERVICE_NAME

# Allow viewing logs for their service
$USERNAME ALL=(ALL) NOPASSWD: /bin/journalctl -u $SERVICE_NAME*
EOF

chmod 0440 "$SUDOERS_FILE"
log_info "Configured limited sudo: user can manage service $SERVICE_NAME"

# Setup SSH authorized_keys
USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

log_info "Setting up SSH access for user: $USERNAME"

# Create .ssh directory if it doesn't exist
if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    log_info "Created .ssh directory"
fi

# Add SSH public key to authorized_keys
if [ ! -f "$AUTHORIZED_KEYS" ]; then
    echo "$SSH_PUBLIC_KEY" > "$AUTHORIZED_KEYS"
    log_info "Created authorized_keys file"
else
    # Check if key already exists
    if ! grep -qF "$SSH_PUBLIC_KEY" "$AUTHORIZED_KEYS"; then
        echo "$SSH_PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
        log_info "Added SSH public key to authorized_keys"
    else
        log_warn "SSH public key already exists in authorized_keys"
    fi
fi

# Set correct permissions
chmod 700 "$SSH_DIR"
chmod 600 "$AUTHORIZED_KEYS"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

log_info "SSH access configured successfully"

# ============================================================================
# DIRECTORY STRUCTURE CREATION
# ============================================================================

log_info "Creating directory structure for application"

RELEASES_DIR="$USER_HOME/releases"
APP_SYMLINK="$USER_HOME/app"

# Create releases directory
if [ ! -d "$RELEASES_DIR" ]; then
    mkdir -p "$RELEASES_DIR"
    log_info "Created releases directory: $RELEASES_DIR"
else
    log_warn "Releases directory already exists: $RELEASES_DIR"
fi

# Create placeholder app symlink (will point to actual release later)
# For now, create a placeholder directory
if [ ! -e "$APP_SYMLINK" ]; then
    mkdir -p "$USER_HOME/app_placeholder"
    ln -s "$USER_HOME/app_placeholder" "$APP_SYMLINK"
    log_info "Created app symlink placeholder: $APP_SYMLINK"
else
    log_warn "App symlink already exists: $APP_SYMLINK"
fi

# Set proper ownership
chown -R "$USERNAME:$USERNAME" "$USER_HOME/releases"
if [ -d "$USER_HOME/app_placeholder" ]; then
    chown -R "$USERNAME:$USERNAME" "$USER_HOME/app_placeholder"
fi

log_info "Directory structure created successfully"

# ============================================================================
# NOTE: SSL CERTIFICATE SETUP
# ============================================================================
# SSL certificates are NOT acquired during application setup.
# After the droplet is provisioned and DNS is configured, run:
#   ./infra/scripts/setup-ssl.sh <domain_name> <droplet_ip>
#
# This separation ensures:
# 1. Application setup works even if certbot is not yet installed
# 2. DNS can be configured before SSL acquisition
# 3. SSL setup can be retried independently if it fails
# ============================================================================

# ============================================================================
# NGINX CONFIGURATION
# ============================================================================

log_info "Generating nginx configuration for $DOMAIN_NAME"

# Ensure nginx directories exist
if [ ! -d "/etc/nginx/sites-available" ]; then
    log_info "Creating /etc/nginx/sites-available directory"
    mkdir -p /etc/nginx/sites-available
fi

if [ ! -d "/etc/nginx/sites-enabled" ]; then
    log_info "Creating /etc/nginx/sites-enabled directory"
    mkdir -p /etc/nginx/sites-enabled
fi

NGINX_CONFIG="/etc/nginx/sites-available/$USERNAME"
NGINX_ENABLED="/etc/nginx/sites-enabled/$USERNAME"

# Determine if this is a subdomain or root domain
DOT_COUNT=$(echo "$DOMAIN_NAME" | tr -cd '.' | wc -c)
IS_SUBDOMAIN=false
if [ "$DOT_COUNT" -gt 1 ]; then
    IS_SUBDOMAIN=true
fi

# Generate nginx configuration file (HTTP-only, SSL will be added by setup-ssl.sh)
if [ "$IS_SUBDOMAIN" = true ]; then
    # Configuration for subdomain (no www redirect)
    cat > "$NGINX_CONFIG" << EOF
# Nginx configuration for $DOMAIN_NAME
# Generated by setup-application.sh
# Note: This is HTTP-only. Run setup-ssl.sh to enable HTTPS.

# Main HTTP server block
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    # Static files location
    location /static {
        alias $USER_HOME/app/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Proxy to application
    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
else
    # Configuration for root domain (with www redirect)
    cat > "$NGINX_CONFIG" << EOF
# Nginx configuration for $DOMAIN_NAME
# Generated by setup-application.sh
# Note: This is HTTP-only. Run setup-ssl.sh to enable HTTPS.

# Redirect www to non-www
server {
    listen 80;
    server_name www.$DOMAIN_NAME;
    
    return 301 http://$DOMAIN_NAME\$request_uri;
}

# Main HTTP server block
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    # Static files location
    location /static {
        alias $USER_HOME/app/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Proxy to application
    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF
fi

log_info "Nginx configuration file created: $NGINX_CONFIG"

# Enable the site by creating symlink
if [ ! -e "$NGINX_ENABLED" ]; then
    ln -s "$NGINX_CONFIG" "$NGINX_ENABLED"
    log_info "Enabled nginx site: $USERNAME"
else
    log_warn "Nginx site already enabled: $USERNAME"
fi

# Test nginx configuration (only if nginx is installed)
if command -v nginx &> /dev/null; then
    log_info "Testing nginx configuration..."
    if nginx -t; then
        log_info "Nginx configuration is valid"
        
        # Reload nginx to apply changes
        log_info "Reloading nginx..."
        systemctl reload nginx
        log_info "Nginx reloaded successfully"
    else
        log_error "Nginx configuration test failed"
        exit 1
    fi
else
    log_warn "Nginx is not installed yet. Configuration will be validated when nginx is installed."
    log_warn "After nginx is installed, run: nginx -t && systemctl reload nginx"
fi

log_info "Nginx configuration completed successfully"

# ============================================================================
# SYSTEMD SERVICE CONFIGURATION
# ============================================================================

log_info "Creating systemd service for application"

SERVICE_NAME="app-$USERNAME"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# Generate systemd unit file
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Application for $DOMAIN_NAME
After=network.target

[Service]
Type=simple
User=$USERNAME
WorkingDirectory=$USER_HOME/app
Environment="APP_PORT=$APP_PORT"
ExecStart=$USER_HOME/app/start.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Resource limits for high concurrency
LimitNOFILE=65535
LimitNPROC=4096

# Security settings
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

log_info "Systemd service file created: $SERVICE_FILE"

# Reload systemd to recognize new service
log_info "Reloading systemd daemon..."
systemctl daemon-reload

# Enable service to start on boot
log_info "Enabling service: $SERVICE_NAME"
systemctl enable "$SERVICE_NAME"

log_info "Systemd service configured successfully"
log_info "Service name: $SERVICE_NAME"
log_info "To start the service after deploying your application, run:"
log_info "  systemctl start $SERVICE_NAME"

# ============================================================================
# PROMETHEUS CONFIGURATION
# ============================================================================

log_info "Updating Prometheus configuration"

PROMETHEUS_CONFIG="/etc/prometheus/prometheus.yml"
PROMETHEUS_BACKUP="/etc/prometheus/prometheus.yml.backup.$(date +%Y%m%d_%H%M%S)"

# Check if Prometheus config exists
if [ ! -f "$PROMETHEUS_CONFIG" ]; then
    log_warn "Prometheus configuration not found at $PROMETHEUS_CONFIG"
    log_warn "Creating basic Prometheus configuration..."
    
    mkdir -p /etc/prometheus
    cat > "$PROMETHEUS_CONFIG" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF
fi

# Backup existing configuration
cp "$PROMETHEUS_CONFIG" "$PROMETHEUS_BACKUP"
log_info "Backed up Prometheus config to: $PROMETHEUS_BACKUP"

# Check if this application is already configured
if grep -q "job_name: '$USERNAME'" "$PROMETHEUS_CONFIG"; then
    log_warn "Prometheus scrape target for $USERNAME already exists"
else
    # Add new scrape target for this application
    log_info "Adding scrape target for $USERNAME on port $APP_PORT with metrics path $METRICS_PATH"
    
    # Append new scrape config
    cat >> "$PROMETHEUS_CONFIG" << EOF

  - job_name: '$USERNAME'
    metrics_path: '$METRICS_PATH'
    static_configs:
      - targets: ['localhost:$APP_PORT']
        labels:
          domain: '$DOMAIN_NAME'
          app: '$USERNAME'
EOF
    
    log_info "Added Prometheus scrape target for $USERNAME"
fi

# Validate Prometheus configuration
if command -v promtool &> /dev/null; then
    log_info "Validating Prometheus configuration..."
    if promtool check config "$PROMETHEUS_CONFIG"; then
        log_info "Prometheus configuration is valid"
    else
        log_error "Prometheus configuration validation failed"
        log_error "Restoring backup..."
        mv "$PROMETHEUS_BACKUP" "$PROMETHEUS_CONFIG"
        exit 1
    fi
else
    log_warn "promtool not found, skipping configuration validation"
fi

# Reload Prometheus
if systemctl is-active --quiet prometheus; then
    log_info "Reloading Prometheus..."
    systemctl reload prometheus || systemctl restart prometheus
    log_info "Prometheus reloaded successfully"
else
    log_warn "Prometheus service is not running"
    log_info "Starting Prometheus service..."
    systemctl start prometheus || log_warn "Failed to start Prometheus"
fi

log_info "Prometheus configuration completed successfully"

# ============================================================================
# SETUP COMPLETE
# ============================================================================

log_info ""
log_info "=========================================="
log_info "Application setup completed successfully!"
log_info "=========================================="
log_info ""
log_info "Summary:"
log_info "  Domain:        $DOMAIN_NAME"
log_info "  Username:      $USERNAME"
log_info "  App Port:      $APP_PORT"
log_info "  Metrics Path:  $METRICS_PATH"
log_info "  Service Name:  $SERVICE_NAME"
log_info "  Home Dir:      $USER_HOME"
log_info "  App Dir:       $USER_HOME/app"
log_info "  Releases Dir:  $USER_HOME/releases"
log_info ""
log_info "Next steps:"
log_info "  1. Deploy your application to $USER_HOME/releases/<version>/app/"
log_info "  2. Update the symlink: ln -sfn $USER_HOME/releases/<version>/app $USER_HOME/app"
log_info "  3. Start the service: systemctl start $SERVICE_NAME"
log_info "  4. Check status: systemctl status $SERVICE_NAME"
log_info "  5. View logs: journalctl -u $SERVICE_NAME -f"
log_info ""
log_info "Your application is currently accessible via HTTP at: http://$DOMAIN_NAME"
log_info ""
log_info "=========================================="
log_info "SSL SETUP (IMPORTANT)"
log_info "=========================================="
log_info ""
log_info "To enable HTTPS, run the SSL setup script after:"
log_info "  1. DNS records are configured and propagated"
log_info "  2. Domain resolves to this server's IP address"
log_info ""
log_info "Run: ./infra/scripts/setup-ssl.sh $DOMAIN_NAME <droplet_ip>"
log_info ""
log_info "Example: ./infra/scripts/setup-ssl.sh $DOMAIN_NAME 192.0.2.1"
log_info ""

exit 0

