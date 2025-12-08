#!/bin/bash
# Test helper script to generate release notes for GitHub releases
# This is extracted from the workflow for unit testing purposes
# Location: infra/tests/generate-release-notes.sh

generate_release_notes() {
  local current_tag="$1"
  local previous_tag="$2"
  local pr_data="$3"
  local commits="$4"
  local github_repo="${5:-owner/repo}"  # Default for testing
  
  # Start building release notes
  local release_notes="# Release ${current_tag}"
  release_notes="${release_notes}\n"
  release_notes="${release_notes}\n## Changes"
  
  # Add PR list if we have any
  local pr_count=$(echo "$pr_data" | jq '. | length' 2>/dev/null || echo "0")
  
  if [ "$pr_count" -gt 0 ]; then
    # Iterate through PRs and format them
    for i in $(seq 0 $((pr_count - 1))); do
      local pr_number=$(echo "$pr_data" | jq -r ".[$i].number" 2>/dev/null)
      local pr_title=$(echo "$pr_data" | jq -r ".[$i].title" 2>/dev/null)
      local pr_author=$(echo "$pr_data" | jq -r ".[$i].author" 2>/dev/null)
      
      # Format: - #123 Title (@author)
      release_notes="${release_notes}\n- #${pr_number} ${pr_title} (@${pr_author})"
    done
  else
    # Use commit messages when no PRs are found (Requirement 2.5)
    if [ -n "$commits" ]; then
      while IFS='|' read -r commit_hash commit_message; do
        # Skip empty lines
        [ -z "$commit_hash" ] && continue
        
        # Skip "Merge pull request" commits (they duplicate PR information)
        if echo "$commit_message" | grep -qiE "^Merge pull request #[0-9]+"; then
          continue
        fi
        
        # Get short hash (first 7 characters)
        local short_hash=$(echo "$commit_hash" | cut -c1-7)
        
        # Create commit URL
        local commit_url="https://github.com/${github_repo}/commit/${commit_hash}"
        
        # Format: - commit_message ([short_hash](url))
        release_notes="${release_notes}\n- ${commit_message} ([\`${short_hash}\`](${commit_url}))"
      done <<< "$commits"
    else
      release_notes="${release_notes}\n- No changes found in this release"
    fi
  fi
  
  # Add separator
  release_notes="${release_notes}\n"
  release_notes="${release_notes}\n---"
  
  # Add Full Changelog link
  if [ -n "$previous_tag" ]; then
    release_notes="${release_notes}\n**Full Changelog**: ${previous_tag}...${current_tag}"
  else
    # First release - just show current tag
    release_notes="${release_notes}\n**Full Changelog**: ${current_tag}"
  fi
  
  # Output the release notes
  echo -e "$release_notes"
}

# If script is run directly (not sourced), execute with provided arguments
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  if [ $# -lt 2 ]; then
    echo "Usage: $0 <current_tag> <previous_tag> [pr_data_json] [commits_data] [github_repo]"
    echo "Example with PRs: $0 v1.2.3 v1.2.2 '[{\"number\":123,\"title\":\"Fix bug\",\"author\":\"user\"}]' '' 'owner/repo'"
    echo "Example with commits: $0 v1.2.3 v1.2.2 '[]' 'abc1234|Fix typo in README"$'\n'"def5678|Update dependencies' 'owner/repo'"
    exit 1
  fi
  
  generate_release_notes "$1" "$2" "${3:-[]}" "${4:-}" "${5:-owner/repo}"
fi
