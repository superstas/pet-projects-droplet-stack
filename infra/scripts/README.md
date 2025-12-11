# Infrastructure Scripts

This directory contains bash scripts for managing the deployment infrastructure.

## metadata-helpers.sh

Helper functions for interacting with GitHub Actions Variables to store and retrieve deployment metadata.

### Functions

#### `get_metadata()`

Reads deployment metadata from the `DEPLOYMENT_METADATA` GitHub Actions variable.

**Returns:**
- JSON string with metadata
- Empty object `{}` if variable doesn't exist

**Environment variables required:**
- `GITHUB_TOKEN` - GitHub token for API authentication
- `GITHUB_REPOSITORY` - Repository in format `owner/repo`

**Example:**
```bash
source infra/scripts/metadata-helpers.sh
METADATA=$(get_metadata)
echo "$METADATA" | jq .
```

#### `update_metadata(json_data)`

Updates or creates the `DEPLOYMENT_METADATA` GitHub Actions variable.

**Parameters:**
- `json_data` - JSON string with new metadata

**Returns:**
- `0` on success
- `1` on error

**Environment variables required:**
- `GITHUB_TOKEN` - GitHub token for API authentication
- `GITHUB_REPOSITORY` - Repository in format `owner/repo`

**Example:**
```bash
source infra/scripts/metadata-helpers.sh

METADATA='{"droplet":{"ip":"1.2.3.4","ssh_port":53222},"applications":[]}'
update_metadata "$METADATA"
```

#### `get_droplet_ip()`

Extracts the droplet IP address from metadata.

**Returns:**
- IP address string
- Empty string if not found

**Environment variables required:**
- `GITHUB_TOKEN` - GitHub token for API authentication
- `GITHUB_REPOSITORY` - Repository in format `owner/repo`

**Example:**
```bash
source infra/scripts/metadata-helpers.sh
DROPLET_IP=$(get_droplet_ip)
echo "Droplet IP: $DROPLET_IP"
```

#### `get_ssh_port()`

Extracts the SSH port from metadata.

**Returns:**
- SSH port number
- `53222` (default) if not found

**Environment variables required:**
- `GITHUB_TOKEN` - GitHub token for API authentication
- `GITHUB_REPOSITORY` - Repository in format `owner/repo`

**Example:**
```bash
source infra/scripts/metadata-helpers.sh
SSH_PORT=$(get_ssh_port)
echo "SSH Port: $SSH_PORT"
```

#### `get_ssh_user()`

Extracts the SSH username from metadata.

**Returns:**
- SSH username
- `"admin"` (default) if not found

**Environment variables required:**
- `GITHUB_TOKEN` - GitHub token for API authentication
- `GITHUB_REPOSITORY` - Repository in format `owner/repo`

**Example:**
```bash
source infra/scripts/metadata-helpers.sh
SSH_USER=$(get_ssh_user)
echo "SSH User: $SSH_USER"
```

### Metadata Structure

The metadata is stored as a JSON object with the following structure:

```json
{
  "droplet": {
    "id": "string",
    "name": "string",
    "ip": "string (IPv4 address)",
    "region": "string",
    "size": "string",
    "created_at": "string (ISO 8601 timestamp)",
    "ssh_port": "number (1024-65535)",
    "ssh_user": "string"
  },
  "applications": [
    {
      "domain": "string (FQDN)",
      "username": "string",
      "port": "number (1024-65535)",
      "metrics_path": "string",
      "service_name": "string"
    }
  ]
}
```

### Error Handling

All functions validate required environment variables and return appropriate error codes:
- Missing `GITHUB_TOKEN` or `GITHUB_REPOSITORY` returns `1` with error message
- Invalid JSON input to `update_metadata()` returns `1` with error message
- GitHub API errors return `1` with descriptive error message

### Testing

Unit tests are available in `infra/tests/bats/test_metadata_helpers.bats`.

Run tests with:
```bash
cd infra/tests
./bats/bats-core/bin/bats bats/test_metadata_helpers.bats
```

## Other Scripts

### setup-application.sh

Sets up a new application on the droplet with nginx configuration, systemd service, and Prometheus monitoring.

### setup-ssl.sh

Configures SSL certificates using Let's Encrypt for deployed applications.
