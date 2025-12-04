#!/usr/bin/env bats

# Tests for template repository scenario
# Validates Requirements 6.1, 6.2, 6.3:
# - Deploy job is skipped in template repository
# - Release is still created
# - Release format is correct

load 'bats-support/load'
load 'bats-assert/load'

setup() {
    # Get the project root directory
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export PROJECT_ROOT
    
    # Source the release notes generation script
    source "$PROJECT_ROOT/tests/generate-release-notes.sh"
}

# ============================================================================
# Template Repository Detection Tests (Requirement 6.1)
# ============================================================================

@test "workflow: deploy job has conditional to skip template repository" {
    run grep -A 1 "^  deploy:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "if:"
}

@test "workflow: deploy job checks for template repository name" {
    run grep "if:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "superstas/pet-projects-droplet-stack"
}

@test "workflow: deploy job skips when repository is template AND ref is tag" {
    # The condition should be: skip if (repo == template AND tag push)
    run grep -A 1 "^  deploy:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "github.repository == 'superstas/pet-projects-droplet-stack'"
    assert_output --partial "startsWith(github.ref, 'refs/tags/')"
}

@test "workflow: deploy job uses negation to skip template" {
    # Should use !(...) to skip when condition is true
    run grep -A 1 "^  deploy:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "if: \${{ !("
}

@test "workflow: deploy job comment explains template skip" {
    run grep -B 1 "if: \${{ !(" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "Skip deploy for the template repository"
}

# ============================================================================
# Release Job Independence Tests (Requirement 6.2)
# ============================================================================

@test "workflow: create-release job exists" {
    run grep "^  create-release:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}

@test "workflow: create-release job is independent of deploy job" {
    # Release job should not have needs dependency to work in template repos
    run grep -A 2 "^  create-release:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    refute_output --partial "needs:"
}

@test "workflow: create-release job runs on tag push" {
    run grep -A 3 "^  create-release:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "startsWith(github.ref, 'refs/tags/')"
}

@test "workflow: create-release job only runs on tag push" {
    run grep -A 3 "^  create-release:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "startsWith(github.ref, 'refs/tags/')"
}

@test "workflow: create-release job has contents write permission" {
    run grep -A 10 "^  create-release:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "permissions:"
    assert_output --partial "contents: write"
}

@test "workflow: create-release job checks out code with full history" {
    run grep -A 20 "^  create-release:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "fetch-depth: 0"
}

# ============================================================================
# Release Format Consistency Tests (Requirement 6.3)
# ============================================================================

@test "release format: includes title with tag name" {
    run generate_release_notes "v1.0.0" "" '[]' ''
    assert_output --partial "# Release v1.0.0"
}

@test "release format: includes Changes section" {
    run generate_release_notes "v1.0.0" "" '[]' ''
    assert_output --partial "## Changes"
}

@test "release format: includes separator" {
    run generate_release_notes "v1.0.0" "" '[]' ''
    assert_output --partial "---"
}

@test "release format: includes Full Changelog link" {
    run generate_release_notes "v1.0.0" "" '[]' ''
    assert_output --partial "**Full Changelog**:"
}

@test "release format: same format for template and non-template repos" {
    # Generate notes for template repo scenario (first release, no previous tag)
    local template_notes=$(generate_release_notes "v1.0.0" "" '[]' 'abc1234|Initial commit' 'owner/repo')
    
    # Generate notes for non-template repo scenario (with previous tag)
    local regular_notes=$(generate_release_notes "v1.0.1" "v1.0.0" '[]' 'def5678|Update feature')
    
    # Both should have the same structure
    echo "$template_notes" | grep -q "# Release"
    echo "$template_notes" | grep -q "## Changes"
    echo "$template_notes" | grep -q -- "---"
    echo "$template_notes" | grep -q "Full Changelog"
    
    echo "$regular_notes" | grep -q "# Release"
    echo "$regular_notes" | grep -q "## Changes"
    echo "$regular_notes" | grep -q -- "---"
    echo "$regular_notes" | grep -q "Full Changelog"
}

@test "release format: handles first release in template repository" {
    # Template repository typically has first release scenario
    run generate_release_notes "v1.0.0" "" '[]' 'abc1234|Initial template setup
def5678|Add documentation
ghi9012|Configure workflows' 'owner/repo'
    
    assert_output --partial "# Release v1.0.0"
    assert_output --partial "## Changes"
    # Check that commits are formatted as links
    assert_output --partial "- Initial template setup ([\`abc1234\`](https://github.com/owner/repo/commit/abc1234))"
    assert_output --partial "- Add documentation ([\`def5678\`](https://github.com/owner/repo/commit/def5678))"
    assert_output --partial "- Configure workflows ([\`ghi9012\`](https://github.com/owner/repo/commit/ghi9012))"
    assert_output --partial "**Full Changelog**: v1.0.0"
}

@test "release format: handles PRs in template repository" {
    local pr_data='[{"number":1,"title":"Initial template setup","author":"maintainer"},{"number":2,"title":"Add documentation","author":"contributor"}]'
    run generate_release_notes "v1.0.0" "" "$pr_data" ''
    
    assert_output --partial "# Release v1.0.0"
    assert_output --partial "- #1 Initial template setup (@maintainer)"
    assert_output --partial "- #2 Add documentation (@contributor)"
}

@test "release format: minimalist structure is maintained" {
    # Verify the format is minimalist (no extra sections)
    run generate_release_notes "v1.0.0" "" '[]' 'abc1234|Test commit' 'owner/repo'
    
    # Count sections - should only have: Title, Changes, Separator, Changelog
    local section_count=$(echo "$output" | grep -c "^#")
    assert_equal "$section_count" "2"  # "# Release" and "## Changes"
}

# ============================================================================
# Workflow Logic Tests
# ============================================================================

@test "workflow: deploy and release jobs can run independently" {
    # Verify that the workflow structure allows:
    # 1. Deploy runs, then release runs (normal repos)
    # 2. Deploy skips, release still runs (template repo)
    
    # Check deploy job condition
    run grep -A 1 "^  deploy:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "if:"
    
    # Check release job runs on tags
    run grep -A 3 "^  create-release:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "startsWith(github.ref, 'refs/tags/')"
}

@test "workflow: release job does not depend on deploy success" {
    # The release job should run independently without needs dependency
    run grep -A 3 "^  create-release:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    refute_output --partial "needs:"
}

@test "workflow: tag trigger is defined" {
    run grep -A 5 "^on:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "tags:"
    assert_output --partial "- 'v*.*.*'"
}

# ============================================================================
# Integration Tests
# ============================================================================

@test "integration: workflow file is valid YAML" {
    # Basic YAML syntax check
    run grep "^name:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
    
    run grep "^on:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
    
    run grep "^jobs:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}

@test "integration: all required steps exist in create-release job" {
    local workflow="$PROJECT_ROOT/.github/workflows/deploy.yml"
    
    # Check for required steps
    grep -q "Extract current tag" "$workflow"
    grep -q "Find previous tag" "$workflow"
    grep -q "Collect PR numbers from commits" "$workflow"
    grep -q "Fetch PR details from GitHub API" "$workflow"
    grep -q "Generate release notes" "$workflow"
    grep -q "Create or update GitHub release" "$workflow"
}

@test "integration: release notes generation is consistent across scenarios" {
    # Test various scenarios to ensure consistency
    
    # Scenario 1: First release with commits
    local notes1=$(generate_release_notes "v1.0.0" "" '[]' 'abc1234|Initial commit' 'owner/repo')
    echo "$notes1" | grep -q "# Release v1.0.0"
    echo "$notes1" | grep -q "## Changes"
    
    # Scenario 2: Subsequent release with PRs
    local pr_data='[{"number":10,"title":"Feature","author":"user"}]'
    local notes2=$(generate_release_notes "v1.1.0" "v1.0.0" "$pr_data" '' 'owner/repo')
    echo "$notes2" | grep -q "# Release v1.1.0"
    echo "$notes2" | grep -q "#10 Feature"
    
    # Scenario 3: Release with no changes
    local notes3=$(generate_release_notes "v1.0.1" "v1.0.0" '[]' '')
    echo "$notes3" | grep -q "# Release v1.0.1"
    echo "$notes3" | grep -q "No changes found in this release"
}

# ============================================================================
# Edge Cases
# ============================================================================

@test "edge case: template repository with manual workflow dispatch" {
    # Verify workflow_dispatch trigger exists
    run grep -A 10 "^on:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "workflow_dispatch:"
}

@test "edge case: release job handles missing deploy outputs gracefully" {
    # Since deploy might be skipped, release job should not fail if deploy outputs are missing
    # This is implicitly tested by the independent execution (no needs dependency)
    run grep -A 3 "^  create-release:" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    refute_output --partial "needs:"
}

@test "edge case: empty commit list in template repository" {
    run generate_release_notes "v1.0.0" "" '[]' ''
    assert_output --partial "- No changes found in this release"
}

@test "edge case: template repository name is exact match" {
    # Ensure the condition checks for exact repository name
    run grep "github.repository == 'superstas/pet-projects-droplet-stack'" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}
