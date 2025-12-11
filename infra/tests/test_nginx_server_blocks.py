#!/usr/bin/env python3
"""
Property-based tests for nginx server block creation per application.

"""

import re
from hypothesis import given, strategies as st, settings, assume


def get_nginx_config_path(username: str) -> str:
    """
    Get the nginx configuration file path for a user/application.
    
    Args:
        username: The sanitized username
    
    Returns:
        Path to the nginx configuration file
    """
    return f"/etc/nginx/sites-available/{username}"


def get_nginx_enabled_path(username: str) -> str:
    """
    Get the nginx enabled symlink path for a user/application.
    
    Args:
        username: The sanitized username
    
    Returns:
        Path to the nginx enabled symlink
    """
    return f"/etc/nginx/sites-enabled/{username}"


def sanitize_domain_to_username(domain: str) -> str:
    """
    Sanitize domain to create username (matches setup-application.sh logic).
    
    Args:
        domain: Domain name
    
    Returns:
        Sanitized username
    """
    import hashlib
    
    # Convert to lowercase
    sanitized = domain.lower()
    
    # Remove all non-alphanumeric characters
    sanitized = re.sub(r'[^a-z0-9]', '', sanitized)
    
    # If the sanitized result would be too long or empty, use hash-based approach
    if len(sanitized) > 26 or len(sanitized) == 0:
        # Use first 26 chars + 6-char hash for uniqueness
        hash_suffix = hashlib.md5(domain.encode()).hexdigest()[:6]
        sanitized = sanitized[:26] + hash_suffix
    elif len(sanitized) < 32:
        # For shorter names, add hash suffix to ensure uniqueness
        # This prevents collisions like '0aaaaa' from both '0.aaaaa' and '0a.aaaa'
        hash_suffix = hashlib.md5(domain.encode()).hexdigest()[:6]
        max_base_len = 32 - 6  # Reserve 6 chars for hash
        sanitized = sanitized[:max_base_len] + hash_suffix
    
    # Ensure we don't exceed 32 characters
    sanitized = sanitized[:32]
    
    return sanitized


def check_server_blocks_unique(applications: list[dict]) -> bool:
    """
    Check that each application has a unique nginx server block file.
    
    Args:
        applications: List of application configs with 'domain' key
    
    Returns:
        True if all applications have unique server block paths
    """
    config_paths = []
    
    for app in applications:
        username = sanitize_domain_to_username(app['domain'])
        config_path = get_nginx_config_path(username)
        config_paths.append(config_path)
    
    # All paths should be unique
    return len(config_paths) == len(set(config_paths))


# Strategy for generating valid domain names
domain_strategy = st.from_regex(
    r'^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]?\.[a-z]{2,}$',
    fullmatch=True
)


@settings(max_examples=100)
@given(st.lists(domain_strategy, min_size=1, max_size=10, unique=True))
def test_each_application_has_unique_nginx_config_file(domains):
    """
    Property 8: Nginx server block per application
    
    For any set of applications, each application should have its own
    unique nginx configuration file in /etc/nginx/sites-available/
    
    """
    # Convert domains to usernames
    usernames = [sanitize_domain_to_username(domain) for domain in domains]
    
    # Get config paths
    config_paths = [get_nginx_config_path(username) for username in usernames]
    
    # All config paths should be unique
    assert len(config_paths) == len(set(config_paths)), \
        f"Nginx config paths are not unique: {config_paths}"
    
    # Each path should follow the expected format
    for username, config_path in zip(usernames, config_paths):
        assert config_path == f"/etc/nginx/sites-available/{username}", \
            f"Config path '{config_path}' does not match expected format"


@settings(max_examples=100)
@given(st.lists(domain_strategy, min_size=1, max_size=10, unique=True))
def test_each_application_has_unique_nginx_enabled_symlink(domains):
    """
    Property: Each application should have a unique enabled symlink.
    
    For any set of applications, each should have its own symlink
    in /etc/nginx/sites-enabled/
    """
    # Convert domains to usernames
    usernames = [sanitize_domain_to_username(domain) for domain in domains]
    
    # Get enabled paths
    enabled_paths = [get_nginx_enabled_path(username) for username in usernames]
    
    # All enabled paths should be unique
    assert len(enabled_paths) == len(set(enabled_paths)), \
        f"Nginx enabled paths are not unique: {enabled_paths}"
    
    # Each path should follow the expected format
    for username, enabled_path in zip(usernames, enabled_paths):
        assert enabled_path == f"/etc/nginx/sites-enabled/{username}", \
            f"Enabled path '{enabled_path}' does not match expected format"


@settings(max_examples=100)
@given(st.lists(domain_strategy, min_size=2, max_size=10, unique=True))
def test_server_block_uniqueness_property(domains):
    """
    Property: Server block uniqueness should hold for multiple applications.
    
    For any set of unique domains, each should get a unique server block file.
    """
    applications = [{'domain': domain} for domain in domains]
    
    assert check_server_blocks_unique(applications), \
        f"Server blocks are not unique for domains: {domains}"


@settings(max_examples=100)
@given(
    st.lists(domain_strategy, min_size=1, max_size=5, unique=True),
    domain_strategy
)
def test_adding_application_creates_new_server_block(existing_domains, new_domain):
    """
    Property: Adding a new application should create a new server block.
    
    For any set of existing applications and a new application,
    the new application should get its own unique server block file
    that doesn't conflict with existing ones.
    """
    # Ensure new domain is not in existing domains
    assume(new_domain not in existing_domains)
    
    # Get config paths for existing applications
    existing_usernames = [sanitize_domain_to_username(d) for d in existing_domains]
    existing_paths = [get_nginx_config_path(u) for u in existing_usernames]
    
    # Add new application
    new_username = sanitize_domain_to_username(new_domain)
    new_path = get_nginx_config_path(new_username)
    
    # New path should not conflict with existing paths
    assert new_path not in existing_paths, \
        f"New server block path '{new_path}' conflicts with existing paths"
    
    # All paths together should be unique
    all_paths = existing_paths + [new_path]
    assert len(all_paths) == len(set(all_paths)), \
        "Server block paths are not unique after adding new application"


@settings(max_examples=100)
@given(domain_strategy)
def test_server_block_path_format(domain):
    """
    Property: Server block paths should follow nginx conventions.
    
    For any domain, the server block configuration file should be
    in /etc/nginx/sites-available/ and the enabled symlink should be
    in /etc/nginx/sites-enabled/
    """
    username = sanitize_domain_to_username(domain)
    
    config_path = get_nginx_config_path(username)
    enabled_path = get_nginx_enabled_path(username)
    
    # Config path should be in sites-available
    assert config_path.startswith("/etc/nginx/sites-available/"), \
        f"Config path '{config_path}' is not in sites-available directory"
    
    # Enabled path should be in sites-enabled
    assert enabled_path.startswith("/etc/nginx/sites-enabled/"), \
        f"Enabled path '{enabled_path}' is not in sites-enabled directory"
    
    # Both should end with the username
    assert config_path.endswith(username), \
        f"Config path '{config_path}' does not end with username '{username}'"
    assert enabled_path.endswith(username), \
        f"Enabled path '{enabled_path}' does not end with username '{username}'"


@settings(max_examples=100)
@given(st.lists(domain_strategy, min_size=2, max_size=10, unique=True))
def test_different_domains_get_different_server_blocks(domains):
    """
    Property: Different domains should always get different server blocks.
    
    For any set of unique domains, no two domains should share the same
    server block configuration file.
    """
    usernames = [sanitize_domain_to_username(domain) for domain in domains]
    config_paths = [get_nginx_config_path(username) for username in usernames]
    
    # Create a mapping of domains to config paths
    domain_to_path = dict(zip(domains, config_paths))
    
    # Check that no two different domains map to the same path
    for i, domain1 in enumerate(domains):
        for domain2 in domains[i+1:]:
            path1 = domain_to_path[domain1]
            path2 = domain_to_path[domain2]
            
            assert path1 != path2, \
                f"Domains '{domain1}' and '{domain2}' map to the same server block: {path1}"


if __name__ == '__main__':
    import pytest
    import sys
    
    # Run the tests
    sys.exit(pytest.main([__file__, '-v']))
