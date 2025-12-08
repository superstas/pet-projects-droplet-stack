# Infrastructure Components

This directory contains all infrastructure-related components for the Pet Projects Droplet Stack, including provisioning scripts, configuration templates, and comprehensive tests.

## Overview

The `infra/` directory organizes all infrastructure code separately from application code, making it easy to understand, maintain, and test the infrastructure provisioning and deployment system.

## Directory Structure

```
infra/
├── scripts/          # Server provisioning and configuration scripts
├── templates/        # Cloud-init and configuration templates
├── tests/            # Infrastructure tests (property-based and unit tests)
├── Makefile          # Test execution and automation
└── README.md         # This file
```

## Components

### scripts/

Contains shell scripts for server provisioning, configuration, and deployment automation.

**Files:**
- `setup-application.sh` - Configures Nginx, systemd services, and Prometheus monitoring for applications
- `setup-ssl.sh` - Provisions and configures Let's Encrypt SSL certificates with auto-renewal

**Usage:**
These scripts are automatically executed by GitHub Actions workflows during droplet creation and SSL setup. They can also be run manually on the server for troubleshooting or updates.

**Key Features:**
- Idempotent operations (safe to run multiple times)
- Comprehensive error handling and logging
- Support for multi-application deployments
- Automatic service configuration and restart

### templates/

Contains configuration templates used during server provisioning.

**Files:**
- `cloud-init.yml` - Cloud-init configuration for initial droplet setup

**Purpose:**
The cloud-init template configures the base system during droplet creation, including:
- System packages and dependencies
- Security settings and firewall rules
- User accounts and SSH access
- Base Nginx and Prometheus installation
- Automatic security updates

### tests/

Contains comprehensive infrastructure tests to ensure correctness and reliability.

**Test Types:**

1. **Property-Based Tests (Python/Hypothesis)** - Verify universal properties that should hold across all inputs
   - Domain sanitization and validation
   - Nginx configuration generation
   - Systemd service creation
   - Prometheus monitoring setup
   - SSL certificate management
   - Port assignment and isolation

2. **Unit Tests (BATS)** - Test specific script functions and configuration validation
   - Configuration file syntax validation
   - Bash script function testing
   - Release notes generation
   - Template repository workflows

See [tests/README.md](./tests/README.md) for detailed test documentation.

## Running Tests

The infrastructure includes a Makefile for convenient test execution.

### Quick Start

```bash
# Run all tests (recommended)
make test

# Run only Python property-based tests
make test-python

# Run only BATS unit tests
make test-bats

# Show available commands
make help
```

### Prerequisites

**For Python Tests:**
```bash
# Install Python dependencies
pip install -r infra/tests/requirements.txt
```

**For BATS Tests:**
```bash
# Install BATS testing framework
./tests/setup-bats.sh
```

### Test Execution Details

**Python Property Tests:**
- Run with pytest and hypothesis
- Minimum 100 iterations per property
- Validate universal correctness properties
- Located in `infra/tests/test_*.py`

**BATS Unit Tests:**
- Test bash script functions
- Validate configuration syntax
- Test specific examples and edge cases
- Located in `infra/tests/bats/*.bats`

## Integration with GitHub Actions

The infrastructure scripts and templates are used by GitHub Actions workflows:

- **Create Droplet** (`.github/workflows/create-droplet.yml`)
  - Uses `scripts/setup-application.sh`
  - Uses `templates/cloud-init.yml`
  
- **Setup SSL** (`.github/workflows/setup-ssl.yml`)
  - Uses `scripts/setup-ssl.sh`

- **Deploy** (`.github/workflows/deploy.yml`)
  - Deploys applications to configured infrastructure

## Development Workflow

When modifying infrastructure components:

1. **Make Changes** - Update scripts, templates, or tests
2. **Run Tests** - Execute `make test` to verify correctness
3. **Test in Branch** - Create a test droplet from a branch to verify end-to-end
4. **Review** - Ensure all tests pass and documentation is updated
5. **Merge** - Merge changes after verification

## Testing Philosophy

The infrastructure uses a dual testing approach:

- **Property-Based Tests** verify that universal properties hold across all possible inputs, catching edge cases and ensuring general correctness
- **Unit Tests** verify specific examples, important edge cases, and concrete functionality

Together, these provide comprehensive coverage: unit tests catch specific bugs, while property tests verify general correctness.

## Documentation

For complete project documentation, see:
- [Main README](../README.md) - Project overview, quick start, and usage
- [Tests README](tests/README.md) - Detailed test documentation and examples

## Contributing

When contributing to infrastructure:

1. Ensure all tests pass (`make test`)
2. Add tests for new functionality
3. Update documentation as needed
4. Follow existing code style and patterns
5. Test changes on a real droplet before merging

## Requirements

- **Python:** 3.7+ with pytest and hypothesis
- **Bash:** 4.0+
- **BATS:** Installed via `./tests/setup-bats.sh`
- **System:** Linux/macOS for running tests

## Support

For issues, questions, or contributions, please refer to the main repository documentation and issue tracker.
