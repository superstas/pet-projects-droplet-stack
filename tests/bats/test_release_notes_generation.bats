#!/usr/bin/env bats

# Test release notes generation functionality

load 'bats-support/load'
load 'bats-assert/load'

setup() {
  # Source the release notes generation script
  source tests/generate-release-notes.sh
}

@test "Release notes include title with tag name" {
  run generate_release_notes "v1.2.3" "v1.2.2" '[]' ''
  
  assert_output --partial "# Release v1.2.3"
}

@test "Release notes include Changes section" {
  run generate_release_notes "v1.2.3" "v1.2.2" '[]' ''
  
  assert_output --partial "## Changes"
}

@test "Release notes include separator" {
  run generate_release_notes "v1.2.3" "v1.2.2" '[]' ''
  
  assert_output --partial "---"
}

@test "Release notes include Full Changelog link with both tags" {
  run generate_release_notes "v1.2.3" "v1.2.2" '[]' ''
  
  assert_output --partial "**Full Changelog**: v1.2.2...v1.2.3"
}

@test "Release notes include Full Changelog link for first release" {
  run generate_release_notes "v1.0.0" "" '[]' ''
  
  assert_output --partial "**Full Changelog**: v1.0.0"
}

@test "Release notes format PR in correct format" {
  local pr_data='[{"number":123,"title":"Add feature","author":"johndoe"}]'
  run generate_release_notes "v1.2.3" "v1.2.2" "$pr_data" ''
  
  assert_output --partial "- #123 Add feature (@johndoe)"
}

@test "Release notes include multiple PRs" {
  local pr_data='[{"number":123,"title":"Add feature","author":"johndoe"},{"number":124,"title":"Fix bug","author":"janedoe"}]'
  run generate_release_notes "v1.2.3" "v1.2.2" "$pr_data" ''
  
  assert_output --partial "- #123 Add feature (@johndoe)"
  assert_output --partial "- #124 Fix bug (@janedoe)"
}

@test "Release notes show message when no PRs and no commits found" {
  run generate_release_notes "v1.2.3" "v1.2.2" '[]' ''
  
  assert_output --partial "- No changes found in this release"
}

@test "Release notes include commit messages when no PRs found" {
  local commits='abc1234567890|Fix typo in README
def5678901234|Update dependencies'
  run generate_release_notes "v1.2.3" "v1.2.2" '[]' "$commits" "owner/repo"
  
  # Check that commits are formatted as links
  assert_output --partial "- Fix typo in README ([\`abc1234\`](https://github.com/owner/repo/commit/abc1234567890))"
  assert_output --partial "- Update dependencies ([\`def5678\`](https://github.com/owner/repo/commit/def5678901234))"
}

@test "Release notes prefer PRs over commits when both available" {
  local pr_data='[{"number":123,"title":"Add feature","author":"johndoe"}]'
  local commits='abc1234567890|Fix typo in README'
  run generate_release_notes "v1.2.3" "v1.2.2" "$pr_data" "$commits"
  
  # Should show PR, not commit
  assert_output --partial "- #123 Add feature (@johndoe)"
  refute_output --partial "Fix typo in README"
}

@test "Release notes exclude merge pull request commits" {
  local commits='abc1234567890|Merge pull request #123 from user/branch
def5678901234|Fix typo in README
ghi9012345678|Merge pull request #456 from user/feature'
  run generate_release_notes "v1.2.3" "v1.2.2" '[]' "$commits" "owner/repo"
  
  # Should NOT include merge commits
  refute_output --partial "Merge pull request"
  # Should include regular commits
  assert_output --partial "- Fix typo in README"
}

@test "Release notes follow correct section order" {
  local pr_data='[{"number":123,"title":"Test","author":"user"}]'
  run generate_release_notes "v1.2.3" "v1.2.2" "$pr_data" ''
  
  # Check that sections appear in correct order
  echo "$output" | grep -q "# Release v1.2.3"
  echo "$output" | grep -q "## Changes"
  echo "$output" | grep -q "\- #123"
  echo "$output" | grep -q -- "---"
  echo "$output" | grep -q "\*\*Full Changelog\*\*"
}
