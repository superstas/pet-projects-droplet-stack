#!/usr/bin/env python3
"""
Property-based tests for Prometheus multi-application monitoring.

"""

import re
import yaml
from hypothesis import given, strategies as st, settings, assume


def add_prometheus_scrape_target(existing_config: str, username: str, domain: str, 
                                  port: int, metrics_path: str) -> str:
    """
    Add a new scrape target to Prometheus configuration.
    
    This simulates the Prometheus config update from setup-application.sh
    """
    # Parse existing config
    config_dict = yaml.safe_load(existing_config)
    
    # Check if scrape_configs exists
    if 'scrape_configs' not in config_dict:
        config_dict['scrape_configs'] = []
    
    # Check if this job already exists
    existing_jobs = [job['job_name'] for job in config_dict['scrape_configs']]
    if username in existing_jobs:
        return existing_config  # Already exists
    
    # Add new scrape target
    new_target = {
        'job_name': username,
        'metrics_path': metrics_path,
        'static_configs': [
            {
                'targets': [f'localhost:{port}'],
                'labels': {
                    'domain': domain,
                    'app': username
                }
            }
        ]
    }
    
    config_dict['scrape_configs'].append(new_target)
    
    # Convert back to YAML
    return yaml.dump(config_dict, default_flow_style=False, sort_keys=False)


def sanitize_domain(domain: str) -> str:
    """Sanitize domain to create valid username."""
    sanitized = domain.lower()
    sanitized = re.sub(r'[^a-z0-9]', '', sanitized)
    sanitized = sanitized[:32]
    return sanitized


def get_scrape_targets(config: str) -> list[dict]:
    """
    Extract all scrape targets from Prometheus config.
    
    Args:
        config: YAML configuration string
    
    Returns:
        List of scrape target dictionaries
    """
    config_dict = yaml.safe_load(config)
    return config_dict.get('scrape_configs', [])


# Strategy for generating valid domain names
domain_strategy = st.from_regex(
    r'^[a-z0-9][a-z0-9-]{0,30}[a-z0-9]?\.[a-z]{2,}$',
    fullmatch=True
)


@settings(max_examples=100)
@given(
    st.lists(domain_strategy, min_size=1, max_size=5, unique=True),
    domain_strategy,
    st.integers(min_value=9000, max_value=9999)
)
def test_adding_application_preserves_existing_scrape_targets(existing_domains, new_domain, new_port):
    """
    Property 10: Prometheus multi-application monitoring
    
    For any new application added to a droplet, when Prometheus configuration
    is updated, the existing scrape targets should remain unchanged and a new
    target should be appended.
    
    """
    # Ensure new domain is not in existing domains
    assume(new_domain not in existing_domains)
    
    # Ensure sanitized usernames are unique (no collisions)
    existing_usernames = [sanitize_domain(d) for d in existing_domains]
    new_username = sanitize_domain(new_domain)
    assume(new_username not in existing_usernames)
    
    # Start with basic Prometheus config
    config = """
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
"""
    
    # Add existing applications
    existing_apps = []
    for i, domain in enumerate(existing_domains):
        username = sanitize_domain(domain)
        assume(len(username) > 0)  # Skip empty usernames
        port = 9000 + i
        config = add_prometheus_scrape_target(config, username, domain, port, "/metrics")
        existing_apps.append({
            'username': username,
            'domain': domain,
            'port': port
        })
    
    # Get scrape targets before adding new application
    targets_before = get_scrape_targets(config)
    targets_before_count = len(targets_before)
    
    # Extract job names and configurations before
    jobs_before = {job['job_name']: job for job in targets_before}
    
    # Add new application (new_username already computed above)
    assume(len(new_username) > 0)
    config = add_prometheus_scrape_target(config, new_username, new_domain, new_port, "/metrics")
    
    # Get scrape targets after adding new application
    targets_after = get_scrape_targets(config)
    targets_after_count = len(targets_after)
    
    # Verify that the number of targets increased by 1
    assert targets_after_count == targets_before_count + 1, \
        f"Expected {targets_before_count + 1} targets, got {targets_after_count}"
    
    # Verify all existing targets are still present and unchanged
    jobs_after = {job['job_name']: job for job in targets_after}
    
    for job_name, job_config in jobs_before.items():
        assert job_name in jobs_after, \
            f"Existing job '{job_name}' was removed"
        
        # Verify the configuration is unchanged
        assert jobs_after[job_name] == job_config, \
            f"Configuration for job '{job_name}' was modified"
    
    # Verify new target was added
    assert new_username in jobs_after, \
        f"New job '{new_username}' was not added"
    
    # Verify new target has correct configuration
    new_job = jobs_after[new_username]
    assert new_job['metrics_path'] == "/metrics"
    assert f'localhost:{new_port}' in new_job['static_configs'][0]['targets']


@settings(max_examples=100)
@given(
    st.lists(
        st.tuples(domain_strategy, st.integers(min_value=9000, max_value=9999)),
        min_size=2,
        max_size=10,
        unique=True
    )
)
def test_multiple_applications_all_monitored(apps):
    """
    Property: All applications on a droplet should be monitored by Prometheus.
    
    For any set of applications, each should have its own scrape target
    in the Prometheus configuration.
    """
    # Start with basic config
    config = """
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
"""
    
    # Add all applications
    app_usernames = []
    for domain, port in apps:
        username = sanitize_domain(domain)
        assume(len(username) > 0)
        
        # Skip if username already exists (collision)
        if username in app_usernames:
            continue
            
        config = add_prometheus_scrape_target(config, username, domain, port, "/metrics")
        app_usernames.append(username)
    
    # Get all scrape targets
    targets = get_scrape_targets(config)
    job_names = [job['job_name'] for job in targets]
    
    # Verify all applications are present
    for username in app_usernames:
        assert username in job_names, \
            f"Application '{username}' is not being monitored"


@settings(max_examples=100)
@given(
    st.lists(domain_strategy, min_size=1, max_size=5, unique=True),
    domain_strategy
)
def test_adding_application_does_not_modify_existing_targets(existing_domains, new_domain):
    """
    Property: Adding a new application should not modify existing scrape targets.
    
    For any set of existing applications, when a new application is added,
    the configuration of existing scrape targets should remain exactly the same.
    """
    # Ensure new domain is not in existing domains
    assume(new_domain not in existing_domains)
    
    # Start with basic config
    config = """
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
"""
    
    # Add existing applications and store their configurations
    existing_configs = {}
    for i, domain in enumerate(existing_domains):
        username = sanitize_domain(domain)
        assume(len(username) > 0)
        port = 9000 + i
        config = add_prometheus_scrape_target(config, username, domain, port, "/metrics")
        
        # Store the configuration
        targets = get_scrape_targets(config)
        for job in targets:
            if job['job_name'] == username:
                existing_configs[username] = job.copy()
    
    # Add new application
    new_username = sanitize_domain(new_domain)
    assume(len(new_username) > 0)
    assume(new_username not in existing_configs)  # No collision
    
    config = add_prometheus_scrape_target(config, new_username, new_domain, 9100, "/metrics")
    
    # Get updated targets
    updated_targets = get_scrape_targets(config)
    updated_configs = {job['job_name']: job for job in updated_targets}
    
    # Verify existing configurations are unchanged
    for username, original_config in existing_configs.items():
        assert username in updated_configs, \
            f"Existing application '{username}' was removed"
        
        assert updated_configs[username] == original_config, \
            f"Configuration for '{username}' was modified when adding new application"


@settings(max_examples=100)
@given(
    st.lists(domain_strategy, min_size=1, max_size=8, unique=True)
)
def test_prometheus_monitors_all_applications_independently(domains):
    """
    Property: Each application should have independent monitoring configuration.
    
    For any set of applications, each should have its own job_name and
    scrape configuration that doesn't interfere with others.
    """
    # Start with basic config
    config = """
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
"""
    
    # Add all applications
    app_data = []
    for i, domain in enumerate(domains):
        username = sanitize_domain(domain)
        assume(len(username) > 0)
        
        # Skip duplicates
        if any(app['username'] == username for app in app_data):
            continue
        
        port = 9000 + i
        config = add_prometheus_scrape_target(config, username, domain, port, "/metrics")
        app_data.append({'username': username, 'domain': domain, 'port': port})
    
    # Get all targets
    targets = get_scrape_targets(config)
    
    # Verify each application has unique job_name
    job_names = [job['job_name'] for job in targets]
    assert len(job_names) == len(set(job_names)), \
        "Job names should be unique"
    
    # Verify each application has correct configuration
    for app in app_data:
        matching_jobs = [job for job in targets if job['job_name'] == app['username']]
        assert len(matching_jobs) == 1, \
            f"Should have exactly one job for {app['username']}"
        
        job = matching_jobs[0]
        target = job['static_configs'][0]['targets'][0]
        assert f"localhost:{app['port']}" == target, \
            f"Target should be localhost:{app['port']}, got {target}"


if __name__ == '__main__':
    import pytest
    import sys
    
    # Run the tests
    sys.exit(pytest.main([__file__, '-v']))
