.PHONY: all test test-python test-bats help

# Default target
all: test

# Run all tests (Python property tests and BATS unit tests)
test: test-python test-bats

# Run Python property-based tests using pytest
test-python:
	@echo "Running Python property-based tests..."
	@cd tests && pytest -v

# Run BATS unit tests
test-bats:
	@echo "Running BATS unit tests..."
	@./tests/bats/bats-core/bin/bats tests/bats/*.bats

# Display help information
help:
	@echo "Infrastructure Testing Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  all          - Run all tests (default)"
	@echo "  test         - Run all tests (Python + BATS)"
	@echo "  test-python  - Run Python property-based tests only"
	@echo "  test-bats    - Run BATS unit tests only"
	@echo "  help         - Display this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make              # Run all tests"
	@echo "  make test         # Run all tests"
	@echo "  make test-python  # Run only Python tests"
	@echo "  make test-bats    # Run only BATS tests"
	@echo "  make help         # Show this help"
	@echo ""
	@echo "Requirements:"
	@echo "  - Python 3.7+ with pytest and hypothesis installed"
	@echo "  - BATS testing framework (run ./tests/setup-bats.sh to install)"
	@echo "  - Install Python dependencies: pip install -r tests/requirements.txt"
