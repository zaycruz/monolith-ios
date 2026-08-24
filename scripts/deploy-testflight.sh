#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="$repo_root/byollm-assistantOS.xcodeproj"
scheme="byollm-assistantOS"
configuration="Release"
export_options="$repo_root/scripts/testflight/ExportOptions.plist"

authentication_args=()
if [[ -n "${APP_STORE_CONNECT_KEY_PATH:-}" || -n "${APP_STORE_CONNECT_KEY_ID:-}" || -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  if [[ -z "${APP_STORE_CONNECT_KEY_PATH:-}" || -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
    echo "APP_STORE_CONNECT_KEY_PATH, APP_STORE_CONNECT_KEY_ID, and APP_STORE_CONNECT_ISSUER_ID must be set together." >&2
    exit 1
  fi

  if [[ ! -f "$APP_STORE_CONNECT_KEY_PATH" ]]; then
    echo "App Store Connect API key not found: $APP_STORE_CONNECT_KEY_PATH" >&2
    exit 1
  fi

  authentication_args=(
    -authenticationKeyPath "$APP_STORE_CONNECT_KEY_PATH"
    -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID"
    -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"
  )
fi

if [[ "${ALLOW_DIRTY_TESTFLIGHT_DEPLOY:-0}" != "1" ]] && [[ -n "$(git -C "$repo_root" status --porcelain --untracked-files=normal)" ]]; then
  echo "Refusing to deploy from a dirty worktree." >&2
  echo "Commit the release, or set ALLOW_DIRTY_TESTFLIGHT_DEPLOY=1 for an intentional local build." >&2
  exit 1
fi

build_settings="$(xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -configuration "$configuration" \
  -showBuildSettings)"

marketing_version="$(awk -F ' = ' '/^[[:space:]]*MARKETING_VERSION = / { print $2; exit }' <<<"$build_settings")"
build_number="$(awk -F ' = ' '/^[[:space:]]*CURRENT_PROJECT_VERSION = / { print $2; exit }' <<<"$build_settings")"

if [[ -z "$marketing_version" || -z "$build_number" ]]; then
  echo "Could not resolve MARKETING_VERSION or CURRENT_PROJECT_VERSION." >&2
  exit 1
fi

artifact_root="${TESTFLIGHT_BUILD_DIR:-$repo_root/build/TestFlight}"
release_dir="$artifact_root/Monolith-$marketing_version-$build_number"
archive_path="$release_dir/Monolith.xcarchive"
export_path="$release_dir/upload"

mkdir -p "$release_dir"

if [[ "${SKIP_TESTFLIGHT_ARCHIVE:-0}" != "1" ]]; then
  echo "Archiving Monolith $marketing_version ($build_number)..."
  xcodebuild \
    -project "$project" \
    -scheme "$scheme" \
    -configuration "$configuration" \
    -destination "generic/platform=iOS" \
    -archivePath "$archive_path" \
    -allowProvisioningUpdates \
    "${authentication_args[@]}" \
    archive
elif [[ ! -d "$archive_path" ]]; then
  echo "Cannot skip archive; archive does not exist: $archive_path" >&2
  exit 1
fi

echo "Uploading Monolith $marketing_version ($build_number) to App Store Connect..."
xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_path" \
  -exportOptionsPlist "$export_options" \
  -allowProvisioningUpdates \
  "${authentication_args[@]}"

echo "Upload submitted: Monolith $marketing_version ($build_number)"
echo "Archive: $archive_path"
