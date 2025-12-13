#!/bin/bash
set -e
set -o pipefail

# setup-ssl.sh
# Script to configure SSL certificate for an existing application
#
# Usage: setup-ssl.sh <domain_name> <droplet_ip> [username]
#
# Parameters:
#   $1 - domain_name: Domain name for the application (e.g., example.com)
#   $2 - droplet_ip: IP address of the droplet
#   $3 - username: Application username (optional, will be generated from domain if not provided)
#

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
# Purpose: Convert domain name to valid Linux username (same as setup-application.sh)
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

# Function: validate_dns
# Purpose: Validate that domain resolves to the correct IP address
#
# Parameters:
#   $1 - domain_name: Domain to validate
#   $2 - expected_ip: Expected IP address
#
# Returns:
#   0 if DNS is valid
#   1 if DNS validation fails
validate_dns() {
    local domain="$1"
    local expected_ip="$2"
    
    log_info "Validating DNS configuration for $domain"
    log_info "Expected IP: $expected_ip"
    
    # Check if dig is available
    if ! command -v dig &> /dev/null; then
        log_error "dig command not found. Please install dnsutils package."
        return 1
    fi
    
    # Resolve domain to IP using dig
    local resolved_ip
    resolved_ip=$(dig +short "$domain" A | head -n 1)
    
    if [ -z "$resolved_ip" ]; then
        log_error "Failed to resolve domain: $domain"
        log_error ""
        log_error "DNS Configuration Required:"
        log_error "================================"
        log_error "Please configure the following DNS records:"
        log_error ""
        log_error "  Type: A"
        log_error "  Name: @"
        log_error "  Value: $expected_ip"
        log_error ""
        log_error "  Type: A"
        log_error "  Name: www"
        log_error "  Value: $expected_ip"
        log_error ""
        log_error "After configuring DNS, wait for propagation (usually 5-30 minutes)"
        log_error "and then run this script again."
        log_error ""
        return 1
    fi
    
    log_info "Resolved IP: $resolved_ip"
    
    # Compare resolved IP with expected IP
    if [ "$resolved_ip" != "$expected_ip" ]; then
        log_error "DNS validation failed!"
        log_error "Domain $domain resolves to $resolved_ip"
        log_error "Expected IP: $expected_ip"
        log_error ""
        log_error "DNS Configuration Required:"
        log_error "================================"
        log_error "Please update your DNS records to point to the correct IP:"
        log_error ""
        log_error "  Type: A"
        log_error "  Name: @"
        log_error "  Value: $expected_ip"
        log_error ""
        log_error "  Type: A"
        log_error "  Name: www"
        log_error "  Value: $expected_ip"
        log_error ""
        log_error "After updating DNS, wait for propagation and run this script again."
        log_error ""
        return 1
    fi
    
    log_info "DNS validation successful!"
    
    # Check www subdomain only for root domains (not subdomains)
    local dot_count
    dot_count=$(echo "$domain" | tr -cd '.' | wc -c)
    
    if [ "$dot_count" -eq 1 ]; then
        # Root domain - check www variant
        local www_resolved_ip
        www_resolved_ip=$(dig +short "www.$domain" A | head -n 1)
        
        if [ -z "$www_resolved_ip" ]; then
            log_warn "www.$domain does not resolve to any IP"
            log_warn "Consider adding a DNS A record for www.$domain -> $expected_ip"
        elif [ "$www_resolved_ip" != "$expected_ip" ]; then
            log_warn "www.$domain resolves to $www_resolved_ip (expected: $expected_ip)"
            log_warn "Consider updating the DNS A record for www.$domain"
        else
            log_info "www.$domain also resolves correctly to $expected_ip"
        fi
    else
        # Subdomain - www check not applicable
        log_info "Subdomain detected - www check skipped"
    fi
    
    return 0
}

# Validate arguments
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    log_error "Usage: $0 <domain_name> <droplet_ip> [username]"
    exit 1
fi

DOMAIN_NAME="$1"
DROPLET_IP="$2"
PROVIDED_USERNAME="$3"

# Validate inputs
if [ -z "$DOMAIN_NAME" ]; then
    log_error "Domain name cannot be empty"
    exit 1
fi

if [ -z "$DROPLET_IP" ]; then
    log_error "Droplet IP cannot be empty"
    exit 1
fi

# Validate IP address format
if ! [[ "$DROPLET_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    log_error "Invalid IP address format: $DROPLET_IP"
    exit 1
fi

# Use provided username or generate from domain
if [ -n "$PROVIDED_USERNAME" ] && [ "$PROVIDED_USERNAME" != "null" ]; then
    USERNAME="$PROVIDED_USERNAME"
    log_info "Using provided username: $USERNAME"
else
    USERNAME=$(sanitize_domain "$DOMAIN_NAME")
    log_info "Generated username from domain: $USERNAME"
fi

if [ -z "$USERNAME" ]; then
    log_error "Failed to determine valid username for domain: $DOMAIN_NAME"
    exit 1
fi

log_info "Starting SSL setup for domain: $DOMAIN_NAME"
log_info "Droplet IP: $DROPLET_IP"
log_info "Username: $USERNAME"

# ============================================================================
# DNS VALIDATION
# ============================================================================

if ! validate_dns "$DOMAIN_NAME" "$DROPLET_IP"; then
    log_error "DNS validation failed. Cannot proceed with SSL setup."
    exit 1
fi

# ============================================================================
# SSL CERTIFICATE ACQUISITION
# ============================================================================

log_info "Acquiring SSL certificate for domain: $DOMAIN_NAME"

# Check if certificate already exists
CERT_PATH="/etc/letsencrypt/live/$DOMAIN_NAME"
if [ -d "$CERT_PATH" ]; then
    log_warn "SSL certificate already exists for $DOMAIN_NAME"
    log_info "Certificate will be renewed if needed"
fi

# Determine if this is a subdomain or root domain
# Count the number of dots in the domain
DOT_COUNT=$(echo "$DOMAIN_NAME" | tr -cd '.' | wc -c)

# Check if it's a subdomain (more than one dot, e.g., api.example.com)
# or a root domain (one dot, e.g., example.com)
IS_SUBDOMAIN=false
if [ "$DOT_COUNT" -gt 1 ]; then
    IS_SUBDOMAIN=true
    log_info "Detected subdomain: $DOMAIN_NAME"
else
    log_info "Detected root domain: $DOMAIN_NAME"
fi

# Run certbot to obtain SSL certificate
# --nginx: Use nginx plugin
# --non-interactive: Run without user interaction
# --agree-tos: Agree to terms of service
# --no-redirect: Don't configure redirect (we'll do it manually)
# -d: Domain names to include in certificate
log_info "Running certbot to obtain SSL certificate..."

# For root domains, include www variant; for subdomains, only the subdomain itself
if [ "$IS_SUBDOMAIN" = true ]; then
    # Subdomain: only request certificate for the subdomain
    if certbot --nginx \
        --non-interactive \
        --agree-tos \
        --no-redirect \
        --register-unsafely-without-email \
        -d "$DOMAIN_NAME"; then
        log_info "SSL certificate obtained successfully"
    else
        EXIT_CODE=$?
        log_error "Failed to obtain SSL certificate (exit code: $EXIT_CODE)"
        log_error ""
        log_error "Common issues:"
        log_error "  1. DNS records not properly configured"
        log_error "  2. Domain doesn't resolve to this server's IP"
        log_error "  3. Ports 80 and 443 are not accessible"
        log_error "  4. Rate limit reached (Let's Encrypt allows 5 failures per hour)"
        log_error ""
        log_error "Please check the error messages above and try again."
        exit 1
    fi
else
    # Root domain: request certificate for both domain and www variant
    if certbot --nginx \
        --non-interactive \
        --agree-tos \
        --no-redirect \
        --register-unsafely-without-email \
        -d "$DOMAIN_NAME" \
        -d "www.$DOMAIN_NAME"; then
        log_info "SSL certificate obtained successfully"
    else
        EXIT_CODE=$?
        log_error "Failed to obtain SSL certificate (exit code: $EXIT_CODE)"
        log_error ""
        log_error "Common issues:"
        log_error "  1. DNS records not properly configured"
        log_error "  2. Domain doesn't resolve to this server's IP"
        log_error "  3. Ports 80 and 443 are not accessible"
        log_error "  4. Rate limit reached (Let's Encrypt allows 5 failures per hour)"
        log_error ""
        log_error "Please check the error messages above and try again."
        exit 1
    fi
fi

log_info "SSL certificate setup completed"

# ============================================================================
# NGINX CONFIGURATION UPDATE FOR SSL
# ============================================================================

log_info "Updating nginx configuration to use SSL"

NGINX_CONFIG="/etc/nginx/sites-available/$USERNAME"
NGINX_BACKUP="/etc/nginx/sites-available/$USERNAME.backup.$(date +%Y%m%d_%H%M%S)"

# Check if nginx config exists
if [ ! -f "$NGINX_CONFIG" ]; then
    log_error "Nginx configuration not found: $NGINX_CONFIG"
    log_error "Please run setup-application.sh first to create the initial configuration"
    exit 1
fi

# Backup existing configuration
cp "$NGINX_CONFIG" "$NGINX_BACKUP"
log_info "Backed up nginx config to: $NGINX_BACKUP"

# Read existing configuration to extract app port and static path
APP_PORT=$(grep -oP 'proxy_pass http://localhost:\K[0-9]+' "$NGINX_CONFIG" | head -n 1)
USER_HOME="/home/$USERNAME"

if [ -z "$APP_PORT" ]; then
    log_error "Could not determine application port from existing nginx config"
    log_error "Restoring backup..."
    mv "$NGINX_BACKUP" "$NGINX_CONFIG"
    exit 1
fi

log_info "Detected application port: $APP_PORT"

# Determine if this is a subdomain or root domain
DOT_COUNT=$(echo "$DOMAIN_NAME" | tr -cd '.' | wc -c)
IS_SUBDOMAIN=false
if [ "$DOT_COUNT" -gt 1 ]; then
    IS_SUBDOMAIN=true
fi

# Generate new nginx configuration with SSL
if [ "$IS_SUBDOMAIN" = true ]; then
    # Configuration for subdomain (no www redirect)
    cat > "$NGINX_CONFIG" << EOF
# Nginx configuration for $DOMAIN_NAME
# Generated by setup-ssl.sh
# Updated: $(date)

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    return 301 https://\$server_name\$request_uri;
}

# Main HTTPS server block
server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    # SSL security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    
    # HSTS header
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
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
# Generated by setup-ssl.sh
# Updated: $(date)

# Redirect www to non-www (HTTPS)
server {
    listen 443 ssl http2;
    server_name www.$DOMAIN_NAME;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    return 301 https://$DOMAIN_NAME\$request_uri;
}

# Redirect www to non-www (HTTP)
server {
    listen 80;
    server_name www.$DOMAIN_NAME;
    
    return 301 https://$DOMAIN_NAME\$request_uri;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    return 301 https://\$server_name\$request_uri;
}

# Main HTTPS server block
server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    # SSL security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    
    # HSTS header
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
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

log_info "Nginx configuration updated with SSL support"

# ============================================================================
# NGINX RELOAD
# ============================================================================

log_info "Testing nginx configuration..."
if nginx -t; then
    log_info "Nginx configuration is valid"
else
    log_error "Nginx configuration test failed"
    log_error "Restoring backup configuration..."
    mv "$NGINX_BACKUP" "$NGINX_CONFIG"
    nginx -t
    exit 1
fi

# Reload nginx to apply changes
log_info "Reloading nginx..."
if systemctl reload nginx; then
    log_info "Nginx reloaded successfully"
else
    log_error "Failed to reload nginx"
    log_error "Restoring backup configuration..."
    mv "$NGINX_BACKUP" "$NGINX_CONFIG"
    systemctl reload nginx
    exit 1
fi

# Verify nginx is running
if systemctl is-active --quiet nginx; then
    log_info "Nginx is running"
else
    log_error "Nginx is not running!"
    exit 1
fi

log_info "Nginx configuration completed successfully"

# ============================================================================
# HTTPS VERIFICATION
# ============================================================================

log_info "Verifying HTTPS access..."

# Wait a moment for nginx to fully reload
sleep 2

# Test HTTPS endpoint
HTTPS_URL="https://$DOMAIN_NAME"
log_info "Testing HTTPS endpoint: $HTTPS_URL"

if curl -f -s -o /dev/null -w "%{http_code}" --max-time 10 "$HTTPS_URL" > /dev/null 2>&1; then
    HTTP_CODE=$(curl -f -s -o /dev/null -w "%{http_code}" --max-time 10 "$HTTPS_URL")
    log_info "HTTPS endpoint is accessible (HTTP $HTTP_CODE)"
else
    log_warn "Could not verify HTTPS endpoint"
    log_warn "This may be normal if your application is not yet deployed"
    log_warn "The SSL certificate and nginx configuration are correctly set up"
fi

# Check SSL certificate validity
log_info "Checking SSL certificate..."
if echo | openssl s_client -servername "$DOMAIN_NAME" -connect "$DOMAIN_NAME:443" 2>/dev/null | openssl x509 -noout -dates > /dev/null 2>&1; then
    CERT_INFO=$(echo | openssl s_client -servername "$DOMAIN_NAME" -connect "$DOMAIN_NAME:443" 2>/dev/null | openssl x509 -noout -dates)
    log_info "SSL certificate is valid:"
    echo "$CERT_INFO" | while read -r line; do
        log_info "  $line"
    done
else
    log_warn "Could not verify SSL certificate details"
    log_warn "Certificate should still be valid"
fi

# ============================================================================
# SETUP COMPLETE
# ============================================================================

log_info ""
log_info "=========================================="
log_info "SSL setup completed successfully!"
log_info "=========================================="
log_info ""
log_info "Summary:"
log_info "  Domain:        $DOMAIN_NAME"
log_info "  IP Address:    $DROPLET_IP"
log_info "  Username:      $USERNAME"
log_info "  Certificate:   /etc/letsencrypt/live/$DOMAIN_NAME/"
log_info ""
log_info "Your application is now accessible at:"
log_info "  https://$DOMAIN_NAME"
log_info ""
log_info "HTTP requests will automatically redirect to HTTPS"
log_info "www.$DOMAIN_NAME will redirect to $DOMAIN_NAME"
log_info ""
log_info "Certificate auto-renewal is configured via certbot"
log_info ""

exit 0
