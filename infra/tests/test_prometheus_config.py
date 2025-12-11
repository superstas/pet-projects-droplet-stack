#!/usr/bin/env python3
"""
Property-based tests for Prometheus configuration.

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
@given(
    st.text(alphabet='abcdefghijklmnopqrstuvwxyz0123456789.-', min_size=3, max_size=50),
    st.integers(min_value=1024, max_value=65535)
)
def test_prometheus_scrape_target_configuration(domain, port):
    """
    Property 5: Prometheus scrape target configuration
    
    For any application with domain and port, when Prometheus configuration
    is updated, the prometheus.yml should contain a scrape target for that
    application's metrics endpoint.
    
    """
    username = sanitize_domain(domain)
    assume(len(username) > 0)  # Skip empty usernames
    
    metrics_path = "/metrics"
    
    # Start with basic Prometheus config
    initial_config = """
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
"""
    
    # Add new scrape target
    updated_config = add_prometheus_scrape_target(
        initial_config, username, domain, port, metrics_path
    )
    
    # Parse the updated config
    config_dict = yaml.safe_load(updated_config)
    
    # Verify scrape_configs exists
    assert 'scrape_configs' in config_dict, \
        "Updated config should have scrape_configs"
    
    # Find the job for this application
    app_job = None
    for job in config_dict['scrape_configs']:
        if job['job_name'] == username:
            app_job = job
            break
    
    assert app_job is not None, \
        f"Config should contain job for {username}"
    
    # Verify the target includes the correct port
    assert 'static_configs' in app_job, \
        "Job should have static_configs"
    
    targets = app_job['static_configs'][0]['targets']
    expected_target = f'localhost:{port}'
    assert expected_target in targets, \
        f"Targets should include {expected_target}"


@settings(max_examples=100)
@given(
    st.text(alphabet='abcdefghijklmnopqrstuvwxyz0123456789.-', min_size=3, max_size=50),
    st.integers(min_value=1024, max_value=65535),
    st.text(alphabet='abcdefghijklmnopqrstuvwxyz0123456789/-', min_size=2, max_size=50)
)
def test_custom_metrics_endpoint_configuration(domain, port, custom_path):
    """
    Property 6: Custom metrics endpoint configuration
    
    For any custom metrics path specified in workflow inputs, when Prometheus
    configuration is generated, the scrape configuration should use that
    custom path instead of the default /metrics.
    
    """
    username = sanitize_domain(domain)
    assume(len(username) > 0)  # Skip empty usernames
    
    # Ensure path starts with /
    if not custom_path.startswith('/'):
        custom_path = '/' + custom_path
    
    # Start with basic Prometheus config
    initial_config = """
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
"""
    
    # Add new scrape target with custom metrics path
    updated_config = add_prometheus_scrape_target(
        initial_config, username, domain, port, custom_path
    )
    
    # Parse the updated config
    config_dict = yaml.safe_load(updated_config)
    
    # Find the job for this application
    app_job = None
    for job in config_dict['scrape_configs']:
        if job['job_name'] == username:
            app_job = job
            break
    
    assert app_job is not None, \
        f"Config should contain job for {username}"
    
    # Verify the custom metrics path is used
    assert 'metrics_path' in app_job, \
        "Job should have metrics_path configured"
    
    assert app_job['metrics_path'] == custom_path, \
        f"Metrics path should be {custom_path}, got {app_job.get('metrics_path')}"


@settings(max_examples=100)
@given(
    st.lists(
        st.tuples(
            st.text(alphabet='abcdefghijklmnopqrstuvwxyz0123456789', min_size=3, max_size=20),
            st.integers(min_value=9000, max_value=9999)
        ),
        min_size=1,
        max_size=5,
        unique=True
    )
)
def test_prometheus_preserves_existing_targets(apps):
    """
    Property: When adding new application, existing scrape targets should be preserved.
    
    For any set of existing applications, when a new application is added,
    all existing scrape targets should remain in the configuration.
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
    for username, port in apps:
        domain = f"{username}.com"
        config = add_prometheus_scrape_target(
            config, username, domain, port, "/metrics"
        )
    
    # Parse final config
    config_dict = yaml.safe_load(config)
    
    # Verify all applications are present
    job_names = [job['job_name'] for job in config_dict['scrape_configs']]
    
    for username, _ in apps:
        assert username in job_names, \
            f"Config should contain job for {username}"
    
    # Verify prometheus job is still there
    assert 'prometheus' in job_names, \
        "Original prometheus job should be preserved"


@settings(max_examples=100)
@given(
    st.text(alphabet='abcdefghijklmnopqrstuvwxyz0123456789', min_size=3, max_size=20),
    st.integers(min_value=1024, max_value=65535)
)
def test_prometheus_config_has_required_labels(username, port):
    """
    Property: Prometheus scrape targets should include domain and app labels.
    
    For any application, the scrape target should include labels
    for domain and app identification.
    """
    domain = f"{username}.com"
    
    initial_config = """
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
"""
    
    updated_config = add_prometheus_scrape_target(
        initial_config, username, domain, port, "/metrics"
    )
    
    config_dict = yaml.safe_load(updated_config)
    
    # Find the job
    app_job = None
    for job in config_dict['scrape_configs']:
        if job['job_name'] == username:
            app_job = job
            break
    
    assert app_job is not None
    
    # Check labels
    labels = app_job['static_configs'][0].get('labels', {})
    assert 'domain' in labels, "Should have domain label"
    assert 'app' in labels, "Should have app label"
    assert labels['domain'] == domain, f"Domain label should be {domain}"
    assert labels['app'] == username, f"App label should be {username}"


if __name__ == '__main__':
    import pytest
    import sys
    
    # Run the tests
    sys.exit(pytest.main([__file__, '-v']))
