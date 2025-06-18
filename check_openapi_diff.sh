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
  curl --silent "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name":' \
    | sed -E 's/.*"([^"]+)".*/\1/'
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

# === RUN OPENAPI-DIFF ===
REF_IN_CONTAINER="/spec/$(realpath --relative-to="$PWD" "$REF_FILE")"
CANDIDATE_IN_CONTAINER="/spec/$(realpath --relative-to="$PWD" "$CANDIDATE_FILE")"

echo "📄 Container REF: $REF_IN_CONTAINER"
echo "📄 Container CANDIDATE: $CANDIDATE_IN_CONTAINER"

docker run --rm -v "${PWD}:/spec" openapitools/openapi-diff:latest \
  "$REF_IN_CONTAINER" "$CANDIDATE_IN_CONTAINER" \
  > diff_result.txt

cat diff_result.txt

# === PARSE RESULTS ===
HAS_BREAKING=$(grep -i "BREAKING" diff_result.txt)
HAS_NON_BREAKING=$(grep -i "NON_BREAKING" diff_result.txt)
HAS_UNCLASSIFIED=$(grep -i "UNCLASSIFIED" diff_result.txt)

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

if [[ "$FAIL" == true ]]; then
  echo "❌ Spec comparison failed."
  exit 1
else
  echo "✅ API spec is compatible."
  exit 0
fi

