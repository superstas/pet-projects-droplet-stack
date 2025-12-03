#!/usr/bin/env python3
"""
Property-based tests for domain name sanitization.

"""

import re
import subprocess
from hypothesis import given, strategies as st, settings


def sanitize_domain(domain: str) -> str:
    """
    Sanitize a domain name to create a valid Linux username.
    
    Rules:
    - Convert to lowercase
    - Remove all non-alphanumeric characters
    - Truncate to 32 characters max
    """
    # Convert to lowercase
    sanitized = domain.lower()
    
    # Remove all non-alphanumeric characters
    sanitized = re.sub(r'[^a-z0-9]', '', sanitized)
    
    # Truncate to 32 characters
    sanitized = sanitized[:32]
    
    return sanitized


@settings(max_examples=100)
@given(st.text(min_size=1, max_size=253))
def test_domain_sanitization_produces_valid_username(domain):
    """
    Property 1: Domain name sanitization
    
    For any domain name input, when the system generates a username,
    the resulting username should contain only characters matching
    the pattern [a-z0-9]
    
    """
    result = sanitize_domain(domain)
    
    # The result should only contain lowercase letters and digits
    assert re.match(r'^[a-z0-9]*$', result), \
        f"Username '{result}' contains invalid characters (must be [a-z0-9])"
    
    # The result should not exceed 32 characters
    assert len(result) <= 32, \
        f"Username '{result}' exceeds 32 character limit (length: {len(result)})"
    
    # Note: Empty result is acceptable if input has no valid characters
    # This is an edge case that should be handled by the calling code


@settings(max_examples=100)
@given(st.text(alphabet='abcdefghijklmnopqrstuvwxyz0123456789.-', min_size=1, max_size=100))
def test_domain_sanitization_preserves_valid_characters(domain):
    """
    Property: Valid characters should be preserved (except dots and hyphens).
    
    For any domain containing valid characters, the sanitized version
    should preserve all alphanumeric characters.
    """
    result = sanitize_domain(domain)
    
    # Extract only alphanumeric characters from original
    expected_chars = re.sub(r'[^a-z0-9]', '', domain.lower())[:32]
    
    assert result == expected_chars, \
        f"Expected '{expected_chars}' but got '{result}'"


@settings(max_examples=100)
@given(st.text(alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZ', min_size=1, max_size=50))
def test_domain_sanitization_converts_to_lowercase(uppercase_domain):
    """
    Property: All uppercase letters should be converted to lowercase.
    """
    result = sanitize_domain(uppercase_domain)
    
    # Result should be all lowercase
    assert result == result.lower(), \
        f"Result '{result}' is not all lowercase"
    
    # Result should match the lowercase version (truncated to 32 chars)
    expected = uppercase_domain.lower()[:32]
    assert result == expected, \
        f"Expected '{expected}' but got '{result}'"


if __name__ == '__main__':
    import pytest
    import sys
    
    # Run the tests
    sys.exit(pytest.main([__file__, '-v']))
