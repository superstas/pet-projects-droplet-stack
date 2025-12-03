# Pet Projects Droplet Stack

Production-ready infrastructure template for pet projects running on a single low-cost DigitalOcean droplet.  
Perfect for side projects, MVPs, and personal applications that need quick&cheap infrastructure setup without the complexity.

## Features

- **One-click provisioning & deployment** via GitHub Actions
- **Automatic SSL certificates** (Let’s Encrypt) with auto-renewal
- **Debian + Nginx** reverse proxy with optimized configuration
- **UFW firewall** with a minimal exposed surface
- **Performance-optimized stack** to handle maximum load on tiny hardware
- **Automatic security updates**
- **Built-in Prometheus** monitoring
- **SQLite** pre-installed and ready to use
- **Multi-application support** on a single droplet
- **Zero-downtime deployments** with rollback capability
- **The cheapest way** to host your zero-MRR projects

## Prerequisites

Before getting started, you'll need:

1. DigitalOcean account with an active API token
2. Domain name with access to DNS settings
3. GitHub account to use GitHub Actions

## Quick Start

### 1. Create Repository from Template

Click "Use this template" button on GitHub and create your repository.

### 2. Generate SSH Keys

Create SSH keys for server access:

```bash
ssh-keygen -t ed25519 -C "your-project-name" -f ~/.ssh/do_project_key -N ""
```

This creates two files:
- `~/.ssh/do_project_key` (private key)
- `~/.ssh/do_project_key.pub` (public key)

### 3. Configure GitHub Secrets

Go to Settings → Secrets and variables → Actions → Repository secrets and add:

| Secret Name | Description | How to Get |
|------------|-------------|------------|
| `DO_API_TOKEN` | DigitalOcean API token with Write scope | [Generate New Token](https://cloud.digitalocean.com/account/api/tokens) |
| `SSH_PUBLIC_KEY` | Public SSH key | `cat ~/.ssh/do_project_key.pub` |
| `SSH_PRIVATE_KEY` | Private SSH key | `cat ~/.ssh/do_project_key` |

Important: Use Repository secrets (not Environment secrets) and ensure DO_API_TOKEN has Write scope.

### 4. Create Your First Droplet

1. Go to Actions → Create Droplet
2. Click "Run workflow"
3. Fill in parameters:
   - domain_name: your domain (e.g., `example.com`)
   - region: DigitalOcean region (e.g., `nyc1`, `sfo3`, `ams3`)
   - app_port: application port (default: `9000`)
   - metrics_path: metrics endpoint (default: `/metrics`)
4. Wait for completion (~5-10 minutes)
5. Note the droplet IP from workflow output

### 5. Configure DNS

Add these A records to your DNS provider:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `@` | `<droplet-ip>` | 3600 |
| A | `www` | `<droplet-ip>` | 3600 |

Verify DNS propagation:
```bash
dig +short example.com
dig +short www.example.com
```

Both should return your droplet IP. Wait 5-60 minutes for propagation.

### 6. Setup SSL Certificate

Once DNS propagates:

1. Go to Actions → Setup SSL
2. Click "Run workflow"
3. Enter domain_name: `example.com`
4. Wait for completion (~2-3 minutes)

Your application is now accessible at `https://example.com`

### 7. Deploy Your Application

Prepare your application:

```
app/
├── start.sh         # Startup script (required)
├── your-binary      # Your application
└── static/          # Static files (optional)
```

Deploy by creating a release tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow automatically deploys to your server.

## License

MIT License - see LICENSE file for details
