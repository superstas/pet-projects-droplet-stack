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
    - Add hash suffix to ensure uniqueness
    - Truncate to 32 characters max
    """
    import hashlib
    
    # Convert to lowercase
    sanitized = domain.lower()
    
    # Remove all non-alphanumeric characters
    sanitized = re.sub(r'[^a-z0-9]', '', sanitized)
    
    # Generate a 6-character hash suffix from the original domain for uniqueness
    hash_suffix = hashlib.md5(domain.encode()).hexdigest()[:6]
    
    # Calculate max length for base part (32 total - 6 for hash)
    max_base_len = 26
    
    # Truncate base part and add hash suffix
    if len(sanitized) > max_base_len:
        sanitized = sanitized[:max_base_len]
    
    # Add hash suffix for uniqueness
    sanitized = sanitized + hash_suffix
    
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
    should preserve all alphanumeric characters in the base part.
    """
    result = sanitize_domain(domain)
    
    # Extract only alphanumeric characters from original
    expected_base = re.sub(r'[^a-z0-9]', '', domain.lower())
    
    # The result should start with the expected base (up to 26 chars) + 6-char hash
    max_base_len = min(26, len(expected_base))
    expected_prefix = expected_base[:max_base_len]
    
    assert result.startswith(expected_prefix), \
        f"Result '{result}' should start with '{expected_prefix}'"
    
    # Result should be exactly 32 chars or less
    assert len(result) <= 32, f"Result '{result}' exceeds 32 characters"
    
    # Result should contain only alphanumeric characters
    assert re.match(r'^[a-z0-9]+$', result), \
        f"Result '{result}' contains invalid characters"


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
    
    # Result should start with the lowercase version of the input (up to 26 chars)
    expected_base = uppercase_domain.lower()
    max_base_len = min(26, len(expected_base))
    expected_prefix = expected_base[:max_base_len]
    
    assert result.startswith(expected_prefix), \
        f"Result '{result}' should start with '{expected_prefix}'"
    
    # Result should be exactly the expected length (base + 6-char hash)
    expected_len = min(26, len(expected_base)) + 6
    assert len(result) == expected_len, \
        f"Expected length {expected_len} but got {len(result)}"


if __name__ == '__main__':
    import pytest
    import sys
    
    # Run the tests
    sys.exit(pytest.main([__file__, '-v']))
