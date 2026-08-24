#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="$repo_root/byollm-assistantOS.xcodeproj"
scheme="byollm-assistantOS"
configuration="Release"
export_options="$repo_root/scripts/testflight/ExportOptions.plist"

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

echo "Archiving Monolith $marketing_version ($build_number)..."
xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -configuration "$configuration" \
  -destination "generic/platform=iOS" \
  -archivePath "$archive_path" \
  -allowProvisioningUpdates \
  archive

echo "Uploading Monolith $marketing_version ($build_number) to App Store Connect..."
xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_path" \
  -exportOptionsPlist "$export_options" \
  -allowProvisioningUpdates

echo "Upload submitted: Monolith $marketing_version ($build_number)"
echo "Archive: $archive_path"
