#!/usr/bin/env python3
"""
Property-based tests for SSL certificate domain isolation.

"""

import os
from hypothesis import given, strategies as st, settings, assume


def get_certificate_path(domain: str) -> str:
    """
    Get the expected certificate path for a domain.
    
    Args:
        domain: The domain name
    
    Returns:
        Path to the certificate directory
    """
    return f"/etc/letsencrypt/live/{domain}"


def check_certificate_isolation(domains: list[str]) -> bool:
    """
    Check that each domain has its own certificate path.
    
    Args:
        domains: List of domain names
    
    Returns:
        True if all domains have unique certificate paths
    """
    cert_paths = [get_certificate_path(domain) for domain in domains]
    
    # All paths should be unique
    return len(cert_paths) == len(set(cert_paths))


def extract_domain_from_cert_path(cert_path: str) -> str:
    """
    Extract domain name from certificate path.
    
    Args:
        cert_path: Path to certificate directory
    
    Returns:
        Domain name
    """
    # Path format: /etc/letsencrypt/live/{domain}
    return os.path.basename(cert_path)


# Strategy for generating valid domain names
domain_strategy = st.from_regex(
    r'^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]?\.[a-z]{2,}$',
    fullmatch=True
)


@settings(max_examples=100)
@given(st.lists(domain_strategy, min_size=1, max_size=10, unique=True))
def test_each_domain_has_unique_certificate_path(domains):
    """
    Property 7: Multiple applications domain isolation
    
    For any set of domains, each domain should have its own unique
    certificate path, ensuring SSL certificate isolation.
    
    """
    # Get certificate paths for all domains
    cert_paths = [get_certificate_path(domain) for domain in domains]
    
    # All certificate paths should be unique
    assert len(cert_paths) == len(set(cert_paths)), \
        f"Certificate paths are not unique: {cert_paths}"
    
    # Each path should contain the domain name
    for domain, cert_path in zip(domains, cert_paths):
        assert domain in cert_path, \
            f"Certificate path '{cert_path}' does not contain domain '{domain}'"


@settings(max_examples=100)
@given(st.lists(domain_strategy, min_size=2, max_size=10, unique=True))
def test_certificate_isolation_property(domains):
    """
    Property: Certificate isolation should hold for any set of unique domains.
    
    For any set of unique domains, the certificate isolation check
    should return True.
    """
    assert check_certificate_isolation(domains), \
        f"Certificate isolation failed for domains: {domains}"


@settings(max_examples=100)
@given(domain_strategy)
def test_certificate_path_format(domain):
    """
    Property: Certificate path should follow Let's Encrypt convention.
    
    For any valid domain, the certificate path should be in the format
    /etc/letsencrypt/live/{domain}
    """
    cert_path = get_certificate_path(domain)
    
    # Path should start with /etc/letsencrypt/live/
    assert cert_path.startswith("/etc/letsencrypt/live/"), \
        f"Certificate path '{cert_path}' does not follow Let's Encrypt convention"
    
    # Path should end with the domain name
    assert cert_path.endswith(domain), \
        f"Certificate path '{cert_path}' does not end with domain '{domain}'"
    
    # Extract domain from path should match original
    extracted_domain = extract_domain_from_cert_path(cert_path)
    assert extracted_domain == domain, \
        f"Extracted domain '{extracted_domain}' does not match original '{domain}'"


@settings(max_examples=100)
@given(
    st.lists(domain_strategy, min_size=1, max_size=5, unique=True),
    domain_strategy
)
def test_adding_new_domain_maintains_isolation(existing_domains, new_domain):
    """
    Property: Adding a new domain should maintain certificate isolation.
    
    For any set of existing domains and a new domain, adding the new domain
    should not affect the certificate paths of existing domains.
    """
    # Ensure new domain is not in existing domains
    assume(new_domain not in existing_domains)
    
    # Get certificate paths for existing domains
    existing_paths = [get_certificate_path(domain) for domain in existing_domains]
    
    # Add new domain
    all_domains = existing_domains + [new_domain]
    
    # Get certificate paths for all domains
    all_paths = [get_certificate_path(domain) for domain in all_domains]
    
    # Existing paths should be unchanged
    for i, existing_path in enumerate(existing_paths):
        assert existing_path == all_paths[i], \
            f"Existing certificate path changed: {existing_path} -> {all_paths[i]}"
    
    # New domain should have its own unique path
    new_path = all_paths[-1]
    assert new_path not in existing_paths, \
        f"New domain's certificate path conflicts with existing paths"
    
    # All paths should still be unique
    assert len(all_paths) == len(set(all_paths)), \
        "Certificate paths are not unique after adding new domain"


if __name__ == '__main__':
    import pytest
    import sys
    
    # Run the tests
    sys.exit(pytest.main([__file__, '-v']))
