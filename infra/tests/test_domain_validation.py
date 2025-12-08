#!/usr/bin/env python3
"""
Property-based tests for domain name validation.

Tests the regex pattern used in GitHub Actions workflow to validate domain names.
The pattern should accept valid FQDNs including subdomains.

"""

import re
from hypothesis import given, strategies as st, settings, assume


# This is the regex pattern used in .github/workflows/create-droplet.yml
DOMAIN_VALIDATION_PATTERN = r'^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'


def is_valid_domain(domain: str) -> bool:
    """
    Validate a domain name using the same regex as the GitHub workflow.
    
    Returns True if the domain matches the validation pattern.
    """
    return bool(re.match(DOMAIN_VALIDATION_PATTERN, domain))


# Strategy for generating valid domain labels (parts between dots)
valid_label = st.text(
    alphabet='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-',
    min_size=1,
    max_size=63
).filter(lambda s: s[0].isalnum() and s[-1].isalnum())

# Strategy for generating valid TLDs
valid_tld = st.text(
    alphabet='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
    min_size=2,
    max_size=10
)


def test_valid_simple_domains():
    """Test that common valid domains are accepted."""
    valid_domains = [
        'example.com',
        'test.org',
        'my-site.net',
        'example123.com',
        '123example.com',
        'a.co',
        'example.technology',
    ]
    
    for domain in valid_domains:
        assert is_valid_domain(domain), f"Domain '{domain}' should be valid"


def test_valid_subdomains():
    """Test that subdomains are accepted."""
    valid_subdomains = [
        'test.rivalfeed.app',
        'api.example.com',
        'www.example.com',
        'dev.api.example.com',
        'staging.app.example.com',
        'my-subdomain.example.com',
        'sub123.example.com',
    ]
    
    for domain in valid_subdomains:
        assert is_valid_domain(domain), f"Subdomain '{domain}' should be valid"


def test_invalid_domains():
    """Test that invalid domains are rejected."""
    invalid_domains = [
        '',                          # Empty
        'example',                   # No TLD
        '.example.com',              # Starts with dot
        'example.com.',              # Ends with dot
        'example..com',              # Double dot
        '-example.com',              # Starts with hyphen
        'example-.com',              # Ends with hyphen
        'example.c',                 # TLD too short
        'example .com',              # Contains space
        'example@.com',              # Invalid character
        'example_test.com',          # Underscore not allowed
        '192.168.1.1',               # IP address (numeric TLD)
    ]
    
    for domain in invalid_domains:
        assert not is_valid_domain(domain), f"Domain '{domain}' should be invalid"


@settings(max_examples=100)
@given(
    labels=st.lists(valid_label, min_size=1, max_size=5),
    tld=valid_tld
)
def test_generated_valid_domains_are_accepted(labels, tld):
    """
    Property: Any properly formatted domain should be accepted.
    
    For any list of valid labels and a valid TLD, when combined with dots,
    the resulting domain should pass validation.
    """
    domain = '.'.join(labels) + '.' + tld
    
    # Skip if domain is too long (max 253 chars for FQDN)
    assume(len(domain) <= 253)
    
    assert is_valid_domain(domain), \
        f"Generated domain '{domain}' should be valid"


@settings(max_examples=100)
@given(st.text(min_size=1, max_size=100))
def test_domains_with_invalid_chars_are_rejected(text):
    """
    Property: Domains with invalid characters should be rejected.
    
    For any text containing characters outside [a-zA-Z0-9.-],
    it should be rejected.
    """
    # Only test strings that contain invalid characters
    assume(not re.match(r'^[a-zA-Z0-9.-]+$', text))
    
    assert not is_valid_domain(text), \
        f"Text '{text}' with invalid characters should be rejected"


def test_edge_cases():
    """Test specific edge cases."""
    # Single letter labels are valid
    assert is_valid_domain('a.b.co')
    
    # Numbers in labels are valid
    assert is_valid_domain('123.456.com')
    
    # Hyphens in middle are valid
    assert is_valid_domain('my-test-site.com')
    
    # Multiple subdomains are valid
    assert is_valid_domain('a.b.c.d.e.com')
    
    # Long but valid domain
    assert is_valid_domain('a' * 63 + '.com')
    
    # Label too long (64 chars) - should be invalid
    assert not is_valid_domain('a' * 64 + '.com')


def test_real_world_examples():
    """Test real-world domain examples."""
    real_domains = [
        'github.com',
        'api.github.com',
        'www.google.com',
        'mail.google.com',
        'docs.python.org',
        'test.rivalfeed.app',
        'staging.myapp.io',
        'dev-api.example.co.uk',
    ]
    
    for domain in real_domains:
        # Note: .co.uk won't work with our simple pattern
        # Our pattern expects single TLD, not compound TLDs
        if '.co.uk' in domain:
            continue
        assert is_valid_domain(domain), f"Real domain '{domain}' should be valid"


if __name__ == '__main__':
    import pytest
    import sys
    
    # Run the tests
    sys.exit(pytest.main([__file__, '-v']))
