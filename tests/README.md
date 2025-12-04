# Testing Infrastructure

This directory contains all tests for the DigitalOcean Pet Project Template.

## Test Types

### 1. Property-Based Tests (Hypothesis)

**Location:** `tests/test_*.py`

**Installation:**
```bash
pip install -r tests/requirements.txt
```

**Running Property Tests:**
```bash
# Run all property tests
pytest tests/

# Run specific test file
pytest tests/test_domain_sanitization.py

# Run with verbose output
pytest tests/ -v

# Run with hypothesis statistics
pytest tests/ -v --hypothesis-show-statistics
```

**Property Test Files:**
- `test_domain_sanitization.py` - Property 1: Domain name sanitization
- `test_nginx_config.py` - Property 2: Nginx proxy configuration
- `test_systemd_service.py` - Properties 3 & 4: Systemd service creation and user assignment
- `test_prometheus_config.py` - Properties 5 & 6: Prometheus scrape configuration
- `test_ssl_certificate.py` - Property 7: Multiple applications domain isolation
- `test_nginx_server_blocks.py` - Property 8: Nginx server block per application
- `test_port_assignment.py` - Property 9: Unique port assignment
- `test_prometheus_multi_app.py` - Property 10: Prometheus multi-application monitoring

### 2. Unit Tests (Bats)

Unit tests use the Bats (Bash Automated Testing System) framework to test bash script functions and configuration validation.

**Location:** `tests/bats/*.bats`

**Installation:**
```bash
./tests/setup-bats.sh
```

**Running Unit Tests:**
```bash
# Run all bats tests
./tests/bats/bats-core/bin/bats tests/bats/*.bats

# Run specific test file
./tests/bats/bats-core/bin/bats tests/bats/test_config_validation.bats
```

**Unit Test Files:**
- `test_config_validation.bats` - Configuration file syntax validation
- `test_script_functions.bats` - Bash script function testing
- `test_pr_extraction.bats` - PR number extraction from commit messages
- `test_release_notes_generation.bats` - Release notes formatting and generation
- `test_template_repository.bats` - Template repository workflow behavior

**Test Helper Scripts:**
- `generate-release-notes.sh` - Helper script for testing release notes generation logic (extracted from workflow)

## Requirements

### Python Requirements
- Python 3.7+
- hypothesis >= 6.0.0
- pytest >= 7.0.0
- pyyaml (for YAML validation)

### Bash Requirements
- Bash 4.0+
- Bats testing framework (installed via setup-bats.sh)

## Test Configuration

Property-based tests are configured to run a minimum of 100 iterations per test to ensure comprehensive coverage.

Each property test includes a comment referencing the design document property it validates:
```python
# **Feature: digitalocean-pet-project-template, Property 1: Domain name sanitization**
```

## Continuous Integration

Tests can be integrated into GitHub Actions workflows:

```yaml
- name: Run property tests
  run: |
    pip install -r tests/requirements.txt
    pytest tests/ -v

- name: Run unit tests
  run: |
    ./tests/setup-bats.sh
    ./tests/bats/bats-core/bin/bats tests/bats/*.bats
```
