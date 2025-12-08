#!/usr/bin/env python3
"""
Property-based tests for unique port assignment.

"""

import json
from hypothesis import given, strategies as st, settings


def check_port_conflict(new_port: int, existing_ports: list[int]) -> bool:
    """
    Check if a new port conflicts with existing ports.
    
    Args:
        new_port: The port to check
        existing_ports: List of ports already in use
    
    Returns:
        True if port is available (no conflict), False if port conflicts
    """
    return new_port not in existing_ports


def suggest_alternative_port(existing_ports: list[int], preferred_range: tuple[int, int] = (9000, 9999)) -> int:
    """
    Suggest an alternative port that doesn't conflict with existing ports.
    
    Args:
        existing_ports: List of ports already in use
        preferred_range: Tuple of (min_port, max_port) for the preferred range
    
    Returns:
        An available port number
    
    Raises:
        ValueError: If no ports are available in the range
    """
    min_port, max_port = preferred_range
    
    for port in range(min_port, max_port + 1):
        if port not in existing_ports:
            return port
    
    raise ValueError(f"No available ports in range {min_port}-{max_port}")


@settings(max_examples=100)
@given(
    st.lists(st.integers(min_value=9000, max_value=9999), min_size=1, max_size=20, unique=True)
)
def test_port_conflict_detection(existing_ports):
    """
    Property 9: Unique port assignment
    
    For any set of existing ports, the port conflict check should correctly
    identify when a new port conflicts with an existing port.
    
    """
    # Test that existing ports are detected as conflicts
    conflicting_port = existing_ports[0]
    assert not check_port_conflict(conflicting_port, existing_ports), \
        f"Port {conflicting_port} should be detected as conflicting"
    
    # Test that a port not in the list is available
    # Find a port that's definitely not in the list
    available_port = max(existing_ports) + 1
    if available_port <= 9999:
        assert check_port_conflict(available_port, existing_ports), \
            f"Port {available_port} should be available"


@settings(max_examples=100)
@given(
    st.lists(st.integers(min_value=9000, max_value=9999), min_size=0, max_size=50, unique=True)
)
def test_suggested_port_is_unique(existing_ports):
    """
    Property: Suggested alternative ports should not conflict with existing ports.
    
    For any set of existing ports (where the range isn't exhausted),
    the suggested port should be unique and in the valid range.
    """
    # Only test if there are available ports
    if len(existing_ports) >= 1000:  # Range 9000-9999 has 1000 ports
        return
    
    suggested_port = suggest_alternative_port(existing_ports)
    
    # Suggested port should not be in existing ports
    assert suggested_port not in existing_ports, \
        f"Suggested port {suggested_port} conflicts with existing ports"
    
    # Suggested port should be in valid range
    assert 9000 <= suggested_port <= 9999, \
        f"Suggested port {suggested_port} is outside valid range 9000-9999"


@settings(max_examples=100)
@given(
    st.lists(st.integers(min_value=1024, max_value=65535), min_size=1, max_size=100, unique=True)
)
def test_port_conflict_check_with_any_valid_ports(existing_ports):
    """
    Property: Port conflict detection should work for any valid port range.
    
    For any set of valid ports (1024-65535), the conflict detection
    should correctly identify conflicts.
    """
    # Pick a random port from existing ports
    conflicting_port = existing_ports[len(existing_ports) // 2]
    
    # Should detect conflict
    assert not check_port_conflict(conflicting_port, existing_ports), \
        f"Port {conflicting_port} should be detected as conflicting"
    
    # Find a port definitely not in the list
    test_port = 1024
    while test_port in existing_ports and test_port < 65535:
        test_port += 1
    
    if test_port <= 65535:
        assert check_port_conflict(test_port, existing_ports), \
            f"Port {test_port} should be available"


@settings(max_examples=100)
@given(
    st.integers(min_value=9000, max_value=9999),
    st.lists(st.integers(min_value=9000, max_value=9999), min_size=0, max_size=50, unique=True)
)
def test_port_availability_is_consistent(new_port, existing_ports):
    """
    Property: Port availability check should be consistent.
    
    For any port and set of existing ports, checking availability twice
    should give the same result.
    """
    result1 = check_port_conflict(new_port, existing_ports)
    result2 = check_port_conflict(new_port, existing_ports)
    
    assert result1 == result2, \
        "Port availability check should be consistent"
    
    # Verify the logic
    expected = new_port not in existing_ports
    assert result1 == expected, \
        f"Port {new_port} availability should be {expected}"


if __name__ == '__main__':
    import pytest
    import sys
    
    # Run the tests
    sys.exit(pytest.main([__file__, '-v']))
