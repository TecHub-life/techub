#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOCKERFILE="$REPO_ROOT_DIR/Dockerfile"

# Inputs/overrides
IM_VERSION="${IM_VERSION:-}"
IM_SHA256="${IM_SHA256:-}"
DRY_RUN="${DRY_RUN:-}"

if [[ -z "$IM_VERSION" ]]; then
  # Use GitHub API to fetch latest IM7 tag
  # Note: Requires no auth for public repos; rate-limited anonymously
  AUTH_HEADER=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    AUTH_HEADER=( -H "Authorization: Bearer ${GITHUB_TOKEN}" )
  fi
  TAGS_JSON=$(curl -fsSL "https://api.github.com/repos/ImageMagick/ImageMagick/tags?per_page=50" "${AUTH_HEADER[@]}")
  IM_VERSION=$(echo "$TAGS_JSON" | grep -Eo '"name"\s*:\s*"7\.[^"]+"' | head -n1 | sed -E 's/.*"(7\.[^"]+)".*/\1/')
  if [[ -z "$IM_VERSION" ]]; then
    echo "Could not determine latest ImageMagick 7 tag from GitHub" >&2
    exit 1
  fi
fi

# Build tarball URL from GitHub refs/tags, always available as source tarball
TARBALL_URL="https://github.com/ImageMagick/ImageMagick/archive/refs/tags/${IM_VERSION}.tar.gz"

if [[ -z "${IM_SHA256}" ]]; then
  if [[ "${DRY_RUN}" == "1" ]]; then
    IM_SHA256="DRYRUN"
  else
    TMP_TARBALL="$(mktemp)"
    AUTH_HEADER=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      AUTH_HEADER=( -H "Authorization: Bearer ${GITHUB_TOKEN}" )
    fi
    curl -fsSL "$TARBALL_URL" -o "$TMP_TARBALL" "${AUTH_HEADER[@]}"
    IM_SHA256=$(sha256sum "$TMP_TARBALL" | awk '{print $1}')
  fi
fi

if [[ "${DRY_RUN}" == "1" ]]; then
  echo "[DRY_RUN] Would set IM version=${IM_VERSION}, sha256=${IM_SHA256}"
else
  # Update Dockerfile ARGs
  sed -i -E "s/^ARG IMAGEMAGICK_VERSION=.*/ARG IMAGEMAGICK_VERSION=${IM_VERSION}/" "$DOCKERFILE"
  if grep -qE '^ARG IMAGEMAGICK_SHA256' "$DOCKERFILE"; then
    sed -i -E "s/^ARG IMAGEMAGICK_SHA256.*/ARG IMAGEMAGICK_SHA256=${IM_SHA256}/" "$DOCKERFILE"
  else
    # Insert after version ARG if missing
    sed -i -E "s/^(ARG IMAGEMAGICK_VERSION=.*)$/\1\nARG IMAGEMAGICK_SHA256=${IM_SHA256}/" "$DOCKERFILE"
  fi
fi

# Export for PR step
{
  echo "NEW_IM_VERSION=${IM_VERSION}"
  echo "NEW_IM_SHA256=${IM_SHA256}"
} >> "${GITHUB_ENV:-/dev/null}"

echo "Prepared bump to IM ${IM_VERSION} (${IM_SHA256})"
