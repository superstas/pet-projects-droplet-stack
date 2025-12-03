# Bats Testing Framework

This directory contains the Bats (Bash Automated Testing System) framework for testing bash scripts.

## Installation

Bats is installed as a git submodule. To set it up:

```bash
# Clone bats-core into tests/bats/bats-core
git submodule add https://github.com/bats-core/bats-core.git tests/bats/bats-core
git submodule add https://github.com/bats-core/bats-support.git tests/bats/bats-support
git submodule add https://github.com/bats-core/bats-assert.git tests/bats/bats-assert

# Initialize submodules (if cloning this repo)
git submodule update --init --recursive
```

## Running Tests

```bash
# Run all bats tests
./tests/bats/bats-core/bin/bats tests/bats/*.bats

# Run specific test file
./tests/bats/bats-core/bin/bats tests/bats/test_domain_sanitization.bats
```

## Test Structure

Bats tests are located in `tests/bats/*.bats` files. Each test file contains test cases using the `@test` syntax.

Example:
```bash
@test "domain sanitization removes special characters" {
  result=$(sanitize_domain "my-app.example.com")
  [[ "$result" =~ ^[a-z0-9]+$ ]]
}
```
