#!/bin/bash

set -e

# === CONFIGURATION ===
REPO="TOMP-WG/TOMP-API"
REF_SPEC_PATH_IN_REPO="TOMP-API.yaml"
REF_FILE="TOMP-API-reference.yaml"

# You can override these via env vars or CLI args
CANDIDATE_FILE="${CANDIDATE_SPEC:-candidate.yaml}"
VERSION="${VERSION_TAG:-$1}"

FAIL_ON_BREAKING_CHANGES="${FAIL_ON_BREAKING_CHANGES:-true}"
FAIL_ON_NON_BREAKING_CHANGES="${FAIL_ON_NON_BREAKING_CHANGES:-false}"
SHOW_UNCLASSIFIED="${SHOW_UNCLASSIFIED:-true}"

# === FUNCTION TO GET LATEST RELEASE ===
get_latest_release() {
  # Try using jq if available, otherwise fall back to grep/sed
  if command -v jq &> /dev/null; then
    curl --silent "https://api.github.com/repos/${REPO}/releases/latest" | jq -r '.tag_name'
  else
    # Fallback to grep/sed with better error handling
    local response=$(curl --silent "https://api.github.com/repos/${REPO}/releases/latest")
    if [[ -z "$response" ]]; then
      echo "❌ Failed to fetch latest release from GitHub API" >&2
      return 1
    fi
    echo "$response" | grep -o '"tag_name":[[:space:]]*"[^"]*"' | cut -d'"' -f4
  fi
}

# === DOWNLOAD REFERENCE SPEC ===
if [[ -z "$VERSION" ]]; then
  echo "🔍 No version specified. Fetching latest release..."
  VERSION=$(get_latest_release)
fi

echo "📥 Downloading reference spec from TOMP-API $VERSION"

REFERENCE_URL="https://raw.githubusercontent.com/${REPO}/${VERSION}/${REF_SPEC_PATH_IN_REPO}"

curl -sSL "$REFERENCE_URL" -o "$REF_FILE" || {
  echo "❌ Failed to download reference spec from $REFERENCE_URL"
  exit 1
}

echo "✅ Downloaded reference spec to $REF_FILE"
echo "📄 Using candidate spec: $CANDIDATE_FILE"

if [[ ! -f "$CANDIDATE_FILE" ]]; then
  echo "❌ Candidate spec file '$CANDIDATE_FILE' not found!"
  exit 1
fi

# === VALIDATE FILES ===
# Check file existence and readability
if [ ! -f "$REF_FILE" ]; then
  echo "❌ Reference file missing: $REF_FILE"
  exit 1
fi

if [ ! -f "$CANDIDATE_FILE" ]; then
  echo "❌ Candidate file missing: $CANDIDATE_FILE"
  exit 1
fi

if [ ! -r "$REF_FILE" ]; then
  echo "❌ Reference file not readable: $REF_FILE"
  exit 1
fi

if [ ! -r "$CANDIDATE_FILE" ]; then
  echo "❌ Candidate file not readable: $CANDIDATE_FILE"
  exit 1
fi

# Basic YAML validation (check for common YAML syntax markers)
if ! head -n 10 "$REF_FILE" | grep -qE "(^openapi:|^swagger:|^---$|^[a-zA-Z]+:)"; then
  echo "⚠️  Warning: Reference file may not be valid YAML/OpenAPI format"
fi

if ! head -n 10 "$CANDIDATE_FILE" | grep -qE "(^openapi:|^swagger:|^---$|^[a-zA-Z]+:)"; then
  echo "⚠️  Warning: Candidate file may not be valid YAML/OpenAPI format"
fi

chmod a+r "$REF_FILE"
chmod a+r "$CANDIDATE_FILE"

# Compute safe relative paths for Docker mount
# Convert to absolute paths first, then make relative to PWD
REF_ABS=$(realpath "$REF_FILE" 2>/dev/null || echo "$REF_FILE")
CANDIDATE_ABS=$(realpath "$CANDIDATE_FILE" 2>/dev/null || echo "$CANDIDATE_FILE")

# Check if files are within current directory tree
if [[ "$REF_ABS" != "$PWD"* ]]; then
  echo "⚠️  Reference file is outside current directory, copying to temp location"
  cp "$REF_FILE" "./temp_ref.yaml"
  REF_FILE="./temp_ref.yaml"
fi

if [[ "$CANDIDATE_ABS" != "$PWD"* ]]; then
  echo "⚠️  Candidate file is outside current directory, copying to temp location"
  cp "$CANDIDATE_FILE" "./temp_candidate.yaml"
  CANDIDATE_FILE="./temp_candidate.yaml"
fi

# Now compute container paths
REF_IN_CONTAINER="/specs/$(basename "$REF_FILE")"
CANDIDATE_IN_CONTAINER="/specs/$(basename "$CANDIDATE_FILE")"

echo "📦 Running openapi-diff inside Docker..."
echo "🔗 Host:       $PWD"
echo "📄 Reference:  $REF_IN_CONTAINER"
echo "📄 Candidate:  $CANDIDATE_IN_CONTAINER"

# Run docker command and capture exit code
if ! docker run --rm -v "$PWD:/specs:ro" openapitools/openapi-diff:latest \
  "$REF_IN_CONTAINER" "$CANDIDATE_IN_CONTAINER" --debug --error --trace \
  > diff_result.txt 2>&1; then
  echo "❌ Docker command failed with exit code $?"
  echo "🔍 Docker output:"
  cat diff_result.txt
  exit 1
fi

cat diff_result.txt

# === PARSE RESULTS ===
# Use word boundaries to distinguish between BREAKING and NON_BREAKING
HAS_BREAKING=$(grep -E "(^|[^_])BREAKING([^_]|$)" diff_result.txt | grep -v "NON_BREAKING" || true)
HAS_NON_BREAKING=$(grep -i "NON_BREAKING" diff_result.txt || true)
HAS_UNCLASSIFIED=$(grep -i "UNCLASSIFIED" diff_result.txt || true)

FAIL=false

if [[ "$FAIL_ON_BREAKING_CHANGES" == true && -n "$HAS_BREAKING" ]]; then
  echo "🚨 Breaking changes detected!"
  FAIL=true
fi

if [[ "$FAIL_ON_NON_BREAKING_CHANGES" == true && -n "$HAS_NON_BREAKING" ]]; then
  echo "⚠️ Non-breaking changes present!"
  FAIL=true
fi

if [[ "$SHOW_UNCLASSIFIED" == true && -n "$HAS_UNCLASSIFIED" ]]; then
  echo "❓ Unclassified changes detected."
fi

# === CLEANUP ===
# Remove temporary files if created
[ -f "./temp_ref.yaml" ] && rm -f "./temp_ref.yaml"
[ -f "./temp_candidate.yaml" ] && rm -f "./temp_candidate.yaml"

if [[ "$FAIL" == true ]]; then
  echo "❌ Spec comparison failed."
  exit 1
else
  echo "✅ API spec is compatible."
  exit 0
fi

