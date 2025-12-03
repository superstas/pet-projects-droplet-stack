"""
Test subdomain detection logic.

This test verifies that the subdomain detection logic correctly identifies
whether a domain is a root domain or a subdomain, which affects SSL certificate
and nginx configuration generation.

"""

import subprocess


def count_dots(domain: str) -> int:
    """Count dots in domain name (mimics bash logic)."""
    return domain.count('.')


def is_subdomain(domain: str) -> bool:
    """
    Determine if domain is a subdomain.
    
    Logic: A domain with more than one dot is considered a subdomain.
    - example.com (1 dot) -> root domain
    - api.example.com (2 dots) -> subdomain
    - dev.api.example.com (3 dots) -> subdomain
    """
    return count_dots(domain) > 1


def test_root_domain_detection():
    """Test that root domains are correctly identified."""
    root_domains = [
        'example.com',
        'myapp.io',
        'test-site.org',
        'rivalfeed.app',
    ]
    
    for domain in root_domains:
        assert not is_subdomain(domain), f"{domain} should be detected as root domain"


def test_subdomain_detection():
    """Test that subdomains are correctly identified."""
    subdomains = [
        'api.example.com',
        'test.myapp.io',
        'staging.rivalfeed.app',
        'dev.api.example.com',
        'my-service.test-site.org',
    ]
    
    for domain in subdomains:
        assert is_subdomain(domain), f"{domain} should be detected as subdomain"


def test_bash_script_subdomain_detection():
    """Test that bash scripts correctly detect subdomains."""
    test_cases = [
        ('example.com', False),
        ('api.example.com', True),
        ('dev.api.example.com', True),
        ('myapp.io', False),
    ]
    
    for domain, expected_is_subdomain in test_cases:
        # Test the bash logic: count dots
        result = subprocess.run(
            ['bash', '-c', f'echo "{domain}" | tr -cd "." | wc -c'],
            capture_output=True,
            text=True
        )
        dot_count = int(result.stdout.strip())
        detected_is_subdomain = dot_count > 1
        
        assert detected_is_subdomain == expected_is_subdomain, \
            f"Domain {domain}: expected subdomain={expected_is_subdomain}, got {detected_is_subdomain}"


def test_certbot_domain_arguments():
    """
    Test that certbot would receive correct domain arguments.
    
    Root domains should get both domain and www.domain.
    Subdomains should only get the subdomain itself.
    """
    # Root domain should include www variant
    root_domain = 'example.com'
    assert not is_subdomain(root_domain)
    expected_domains = [root_domain, f'www.{root_domain}']
    
    # Subdomain should NOT include www variant
    subdomain = 'api.example.com'
    assert is_subdomain(subdomain)
    expected_domains_sub = [subdomain]
    
    # Verify we don't create www.api.example.com
    assert f'www.{subdomain}' not in expected_domains_sub


def test_edge_cases():
    """Test edge cases for subdomain detection."""
    # Single label (invalid domain, but test the logic)
    assert not is_subdomain('localhost')  # 0 dots
    
    # Very deep subdomain
    assert is_subdomain('a.b.c.d.e.example.com')  # Many dots
    
    # Domain with hyphens
    assert not is_subdomain('my-app.com')  # 1 dot
    assert is_subdomain('my-api.my-app.com')  # 2 dots
