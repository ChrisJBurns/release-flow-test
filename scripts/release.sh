#!/bin/bash
set -e

# Configuration
VERSION_FILE="${VERSION_FILE:-VERSION}"
CHART_PATH="${CHART_PATH:-deploy/charts/release-flow-test}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helpers
info()  { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
warn()  { echo -e "${YELLOW}$1${NC}"; }
error() { echo -e "${RED}$1${NC}" >&2; exit 1; }

confirm() {
  echo -n "$1 [y/N]: "
  read -r response
  [[ "$response" =~ ^[Yy]$ ]]
}

# Preflight checks
check_requirements() {
  command -v gh &>/dev/null || error "gh CLI is not installed. Install from: https://cli.github.com/"
  gh auth status &>/dev/null || error "Not authenticated with gh. Run: gh auth login"
  [ -z "$(git status --porcelain)" ] || error "Working directory not clean. Commit or stash changes first."
  [ -f "$VERSION_FILE" ] || error "VERSION file not found: $VERSION_FILE"
}

check_branch() {
  local branch=$(git branch --show-current)
  if [ "$branch" != "main" ]; then
    warn "Warning: Not on main branch (on: $branch)"
    confirm "Continue anyway?" || exit 0
  fi
}

# Version parsing
parse_version() {
  local version=$(tr -d '[:space:]' < "$VERSION_FILE")
  echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || error "Invalid version: $version"
  echo "$version"
}

get_version_parts() {
  local version=$1
  echo "$version" | cut -d. -f"$2"
}

# Calculate new version
calc_new_version() {
  local current=$1 bump=$2
  local major minor patch

  major=$(get_version_parts "$current" 1)
  minor=$(get_version_parts "$current" 2)
  patch=$(get_version_parts "$current" 3)

  case $bump in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "${major}.$((minor + 1)).0" ;;
    patch) echo "${major}.${minor}.$((patch + 1))" ;;
  esac
}

# Prompt for bump type
prompt_bump_type() {
  local current=$1
  local major minor patch

  major=$(get_version_parts "$current" 1)
  minor=$(get_version_parts "$current" 2)
  patch=$(get_version_parts "$current" 3)

  echo ""
  echo "What type of release is this?"
  echo ""
  echo "  1) major  - Breaking changes      ($current -> $((major + 1)).0.0)"
  echo "  2) minor  - New features          ($current -> ${major}.$((minor + 1)).0)"
  echo "  3) patch  - Bug fixes             ($current -> ${major}.${minor}.$((patch + 1)))"
  echo ""
  read -p "Enter choice [1/2/3]: " choice

  case $choice in
    1|major) echo "major" ;;
    2|minor) echo "minor" ;;
    3|patch) echo "patch" ;;
    *) error "Invalid choice: $choice" ;;
  esac
}

# Update version files
update_files() {
  local version=$1

  echo "$version" > "$VERSION_FILE"

  if [ -f "$CHART_PATH/Chart.yaml" ]; then
    sed -i '' "s/^version:.*/version: $version/" "$CHART_PATH/Chart.yaml"
    sed -i '' "s/^appVersion:.*/appVersion: \"$version\"/" "$CHART_PATH/Chart.yaml"
  fi

  if [ -f "$CHART_PATH/values.yaml" ]; then
    sed -i '' "s/^  tag:.*/  tag: \"$version\"/" "$CHART_PATH/values.yaml"
  fi
}

# Create PR
create_pr() {
  local version=$1 bump=$2 branch=$3

  gh pr create \
    --title "Release v${version}" \
    --body "## Release v${version}

### Changes
- Updated VERSION to \`${version}\`
- Updated Chart.yaml version/appVersion to \`${version}\`
- Updated values.yaml image.tag to \`${version}\`

### Release Type
**${bump}**

### After Merge
1. Tag \`v${version}\` will be created automatically
2. Container image will be built and signed
3. Helm chart will be published and signed" \
    --label "release" \
    --head "$branch" \
    --base "main"
}

# Main
main() {
  info "=== Release PR Creator ==="
  echo ""

  check_requirements
  check_branch

  git pull --quiet

  local current_version=$(parse_version)
  echo "Current version: $(success "$current_version")"

  local bump_type=$(prompt_bump_type "$current_version")
  local new_version=$(calc_new_version "$current_version" "$bump_type")
  local branch="release/v${new_version}"

  echo ""
  echo "Bump type: $(warn "$bump_type")"
  echo "New version: $(success "$new_version")"

  # Validate
  git rev-parse --verify "$branch" &>/dev/null && error "Branch $branch already exists"
  git rev-parse "v${new_version}" &>/dev/null && error "Tag v${new_version} already exists"

  echo ""
  confirm "Create release PR for v${new_version}?" || { warn "Cancelled"; exit 0; }

  # Create branch and update files
  echo ""
  echo "Creating branch..."
  git checkout -b "$branch"

  echo "Updating files..."
  update_files "$new_version"

  echo "Committing..."
  git add -A
  git commit -m "Release v${new_version}"

  echo "Pushing..."
  git push -u origin "$branch"

  echo "Creating PR..."
  local pr_url=$(create_pr "$new_version" "$bump_type" "$branch")

  git checkout main

  echo ""
  success "=== Success ==="
  echo "PR: $(info "$pr_url")"
}

main
