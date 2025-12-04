#!/usr/bin/env bats

# Unit tests for PR number extraction from commit messages
# Tests the regex patterns used in GitHub Actions workflow for release automation

load 'bats-support/load'
load 'bats-assert/load'

setup() {
    # Get the project root directory
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export PROJECT_ROOT
    
    # Define the PR extraction function that matches the workflow logic
    extract_pr_numbers() {
        local commits="$1"
        echo "$commits" | grep -oE '#[0-9]+|[Pp][Rr] #[0-9]+|[Mm]erge pull request #[0-9]+|pull request #[0-9]+|\(#[0-9]+\)' | \
            grep -oE '[0-9]+' | \
            sort -u | \
            tr '\n' ' ' | \
            sed 's/ $//'
    }
    export -f extract_pr_numbers
}

# ============================================================================
# PR Number Extraction Tests
# ============================================================================

@test "PR extraction: extracts simple #123 format" {
    commits="Fix bug in authentication #123"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "123"
}

@test "PR extraction: extracts GitHub merge format" {
    commits="Merge pull request #456 from user/feature"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "456"
}

@test "PR extraction: extracts PR in parentheses" {
    commits="Add new feature (PR #789)"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "789"
}

@test "PR extraction: extracts PR with hash in parentheses" {
    commits="Update documentation (#101)"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "101"
}

@test "PR extraction: extracts explicit PR reference" {
    commits="Refactor code PR #202"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "202"
}

@test "PR extraction: extracts full pull request text" {
    commits="Fix issue pull request #303"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "303"
}

@test "PR extraction: extracts multiple PRs from one commit" {
    commits="Multiple PRs: #111 and #222"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "111 222"
}

@test "PR extraction: handles commit without PR" {
    commits="No PR in this commit"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" ""
}

@test "PR extraction: extracts all PRs from multiple commits" {
    commits="Fix bug in authentication #123
Merge pull request #456 from user/feature
Add new feature (PR #789)
Update documentation (#101)
Refactor code PR #202
Fix issue pull request #303
Multiple PRs: #111 and #222
No PR in this commit
Another fix #333"
    
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "101 111 123 202 222 303 333 456 789"
}

@test "PR extraction: deduplicates PR numbers" {
    commits="Fix #123
Update #123
Another change #123"
    
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "123"
}

@test "PR extraction: sorts PR numbers numerically" {
    commits="Fix #999
Update #111
Change #555"
    
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "111 555 999"
}

@test "PR extraction: handles lowercase pr" {
    commits="Fix issue pr #404"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "404"
}

@test "PR extraction: handles mixed case PR" {
    commits="Fix issue Pr #505"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "505"
}

@test "PR extraction: handles lowercase merge" {
    commits="merge pull request #606 from branch"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "606"
}

@test "PR extraction: handles mixed case Merge" {
    commits="Merge Pull Request #707 from branch"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "707"
}

@test "PR extraction: ignores PR-like text without numbers" {
    commits="This is a PR without number
Another commit with # but no number
Fix issue #"
    
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" ""
}

@test "PR extraction: handles large PR numbers" {
    commits="Fix #12345"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "12345"
}

@test "PR extraction: handles PR at start of message" {
    commits="#808 Fix critical bug"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "808"
}

@test "PR extraction: handles PR at end of message" {
    commits="Fix critical bug #909"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "909"
}

@test "PR extraction: handles multiple formats in same commit" {
    commits="Merge pull request #100 (#200)"
    result=$(extract_pr_numbers "$commits")
    assert_equal "$result" "100 200"
}

# ============================================================================
# Workflow Integration Tests
# ============================================================================

@test "workflow: deploy.yml contains PR collection step" {
    run grep -q "Collect PR numbers from commits" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}

@test "workflow: uses correct git log format" {
    run grep -q 'git log --pretty=format:"%H|%s"' "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}

@test "workflow: uses correct regex pattern" {
    run grep -q "grep -oE '#\[0-9\]+|\[Pp\]\[Rr\] #\[0-9\]+|\[Mm\]erge pull request #\[0-9\]+|pull request #\[0-9\]+|\\\\(#\[0-9\]+\\\\)'" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}

@test "workflow: sorts and deduplicates PR numbers" {
    run grep -q "sort -u" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}

@test "workflow: stores PR numbers in output" {
    run grep -q "numbers=\$PR_NUMBERS" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}

@test "workflow: stores PR count in output" {
    run grep -q "count=\$PR_COUNT" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}

@test "workflow: handles case with no previous tag" {
    run grep -A 5 'if \[ -z "\$PREVIOUS_TAG" \]' "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial 'git log --pretty=format:"%H|%s" "$CURRENT_TAG"'
}

@test "workflow: handles case with previous tag" {
    run grep -q 'git log --pretty=format:"%H|%s" "\${PREVIOUS_TAG}..\${CURRENT_TAG}"' "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}

# ============================================================================
# GitHub API Fetching Tests
# ============================================================================

@test "workflow: contains PR details fetching step" {
    run grep -q "Fetch PR details from GitHub API" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}

@test "workflow: uses GITHUB_TOKEN for API calls" {
    run grep -A 5 "Fetch PR details from GitHub API" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "GITHUB_TOKEN"
}

@test "workflow: defines API retry function" {
    run grep -q "call_github_api_with_retry()" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_success
}

@test "workflow: handles rate limiting with retry" {
    run grep -A 50 "call_github_api_with_retry()" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "403"
    assert_output --partial "Rate limited"
}

@test "workflow: handles 404 errors gracefully" {
    run grep -A 50 "call_github_api_with_retry()" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "404"
    assert_output --partial "not found"
}

@test "workflow: implements exponential backoff" {
    run grep -A 50 "call_github_api_with_retry()" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "wait_time=2"
    assert_output --partial "wait_time=\$((wait_time * 2))"
}

@test "workflow: retries up to 3 times" {
    run grep -A 50 "call_github_api_with_retry()" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "max_attempts=3"
}

@test "workflow: extracts PR title from API response" {
    run grep -A 120 "Fetch PR details from GitHub API" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "jq -r '.title"
}

@test "workflow: extracts PR author from API response" {
    run grep -A 120 "Fetch PR details from GitHub API" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "jq -r '.user.login"
}

@test "workflow: extracts PR URL from API response" {
    run grep -A 120 "Fetch PR details from GitHub API" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "jq -r '.html_url"
}

@test "workflow: stores PR data in JSON format" {
    run grep -A 120 "Fetch PR details from GitHub API" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "PR_DATA="
    assert_output --partial 'number'
    assert_output --partial 'title'
    assert_output --partial 'author'
}

@test "workflow: escapes special characters in PR titles" {
    run grep -A 150 "Fetch PR details from GitHub API" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "pr_title_escaped"
    assert_output --partial "sed 's/\\\\/\\\\\\\\/g'"
}

@test "workflow: handles empty PR list" {
    run grep -A 10 "Fetch PR details from GitHub API" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial 'if [ -z "$PR_NUMBERS" ]'
    assert_output --partial "pr_data=[]"
}

@test "workflow: continues on API failure" {
    run grep -A 150 "Fetch PR details from GitHub API" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "Failed to fetch PR"
    assert_output --partial "skipping"
}

@test "workflow: stores PR data in multiline output" {
    run grep -A 160 "Fetch PR details from GitHub API" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "pr_data<<EOF"
    assert_output --partial "EOF"
}

@test "workflow: uses GitHub API v3" {
    run grep -A 50 "call_github_api_with_retry()" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "application/vnd.github.v3+json"
}

@test "workflow: calls correct API endpoint" {
    run grep -A 50 "call_github_api_with_retry()" "$PROJECT_ROOT/.github/workflows/deploy.yml"
    assert_output --partial "api.github.com/repos"
    assert_output --partial "/pulls/"
}
