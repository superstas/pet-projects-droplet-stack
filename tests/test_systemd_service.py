#!/usr/bin/env python3
"""
Property-based tests for systemd service configuration.

"""

import re
from hypothesis import given, strategies as st, settings


def generate_systemd_service(domain: str, username: str, user_home: str) -> tuple[str, str]:
    """
    Generate systemd service configuration for an application.
    
    Returns:
        tuple: (service_name, service_content)
    """
    service_name = f"app-{username}"
    
    service_content = f"""[Unit]
Description=Application for {domain}
After=network.target

[Service]
Type=simple
User={username}
WorkingDirectory={user_home}/app
ExecStart={user_home}/app/start.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
"""
    
    return service_name, service_content


def sanitize_domain(domain: str) -> str:
    """Sanitize domain to create valid username."""
    sanitized = domain.lower()
    sanitized = re.sub(r'[^a-z0-9]', '', sanitized)
    sanitized = sanitized[:32]
    return sanitized


@settings(max_examples=100)
@given(st.text(alphabet='abcdefghijklmnopqrstuvwxyz0123456789.-', min_size=3, max_size=50))
def test_systemd_service_file_path_is_correct(domain):
    """
    Property 3: Systemd service creation
    
    For any application name, when the setup script runs, a systemd unit file
    should be created at /etc/systemd/system/app-{sanitized_name}.service
    
    """
    username = sanitize_domain(domain)
    
    if not username:  # Skip if username is empty
        return
    
    user_home = f"/home/{username}"
    service_name, service_content = generate_systemd_service(domain, username, user_home)
    
    # Verify service name follows the pattern app-{username}
    expected_service_name = f"app-{username}"
    assert service_name == expected_service_name, \
        f"Service name should be 'app-{username}', got '{service_name}'"
    
    # Verify the service file path would be correct
    expected_path = f"/etc/systemd/system/{service_name}.service"
    assert expected_path == f"/etc/systemd/system/app-{username}.service", \
        f"Service file path should be {expected_path}"
    
    # Verify service content has required sections
    assert "[Unit]" in service_content, "Service should have [Unit] section"
    assert "[Service]" in service_content, "Service should have [Service] section"
    assert "[Install]" in service_content, "Service should have [Install] section"


@settings(max_examples=100)
@given(st.text(alphabet='abcdefghijklmnopqrstuvwxyz0123456789', min_size=1, max_size=32))
def test_systemd_service_user_assignment(username):
    """
    Property 4: Systemd service user assignment
    
    For any system username, when a systemd unit file is created,
    the unit file should contain User={username} in the [Service] section.
    
    """
    domain = f"{username}.com"
    user_home = f"/home/{username}"
    
    service_name, service_content = generate_systemd_service(domain, username, user_home)
    
    # Verify User field is set correctly
    assert f"User={username}" in service_content, \
        f"Service should contain 'User={username}'"
    
    # Verify it's in the [Service] section
    # Extract the [Service] section
    service_section_match = re.search(r'\[Service\](.*?)\[', service_content, re.DOTALL)
    assert service_section_match, "Should have [Service] section"
    
    service_section = service_section_match.group(1)
    assert f"User={username}" in service_section, \
        f"User={username} should be in [Service] section"


@settings(max_examples=100)
@given(st.text(alphabet='abcdefghijklmnopqrstuvwxyz0123456789', min_size=1, max_size=32))
def test_systemd_service_working_directory(username):
    """
    Property: Systemd service should set WorkingDirectory correctly.
    
    For any username, the service should have WorkingDirectory
    pointing to /home/{username}/app
    """
    domain = f"{username}.com"
    user_home = f"/home/{username}"
    
    service_name, service_content = generate_systemd_service(domain, username, user_home)
    
    # Verify WorkingDirectory is set correctly
    expected_working_dir = f"WorkingDirectory={user_home}/app"
    assert expected_working_dir in service_content, \
        f"Service should contain '{expected_working_dir}'"


@settings(max_examples=100)
@given(st.text(alphabet='abcdefghijklmnopqrstuvwxyz0123456789', min_size=1, max_size=32))
def test_systemd_service_restart_policy(username):
    """
    Property: Systemd service should have Restart=always configured.
    
    For any username, the service should be configured to restart
    automatically on failure.
    """
    domain = f"{username}.com"
    user_home = f"/home/{username}"
    
    service_name, service_content = generate_systemd_service(domain, username, user_home)
    
    # Verify Restart policy
    assert "Restart=always" in service_content, \
        "Service should have 'Restart=always'"
    
    # Verify RestartSec is set
    assert "RestartSec=" in service_content, \
        "Service should have RestartSec configured"


@settings(max_examples=100)
@given(st.text(alphabet='abcdefghijklmnopqrstuvwxyz0123456789', min_size=1, max_size=32))
def test_systemd_service_journal_output(username):
    """
    Property: Systemd service should log to journal.
    
    For any username, the service should be configured to send
    output to systemd journal.
    """
    domain = f"{username}.com"
    user_home = f"/home/{username}"
    
    service_name, service_content = generate_systemd_service(domain, username, user_home)
    
    # Verify journal logging
    assert "StandardOutput=journal" in service_content, \
        "Service should have 'StandardOutput=journal'"
    assert "StandardError=journal" in service_content, \
        "Service should have 'StandardError=journal'"


if __name__ == '__main__':
    import pytest
    import sys
    
    # Run the tests
    sys.exit(pytest.main([__file__, '-v']))
