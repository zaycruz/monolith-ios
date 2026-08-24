# Deploying Monolith

## TestFlight

The TestFlight lane archives the Release configuration with automatic signing and uploads it through the Apple account signed into Xcode.

### Prerequisites

- Xcode is signed into the App Store Connect team `RA5ZRTAX47`.
- App Store Connect contains the app for bundle identifier `openaccesslabs.byollm-assistantOS`.
- `CURRENT_PROJECT_VERSION` is higher than every build already uploaded for the current marketing version.
- The worktree is committed and the iOS, gateway, and contract test suites pass.

### Upload

Run from the repository root:

```sh
./scripts/deploy-testflight.sh
```

The script reads the version and build number from Xcode, writes the archive under `build/TestFlight/`, and uploads it using `scripts/testflight/ExportOptions.plist`. It refuses a dirty worktree so the uploaded binary maps to a commit. For a deliberate diagnostic build only, set `ALLOW_DIRTY_TESTFLIGHT_DEPLOY=1`.

After upload, wait for App Store Connect processing, confirm the build reports `VALID`, add it to the intended internal testing group, and install it from TestFlight.

TestFlight binaries cannot be rolled back in place. If a build is bad, remove it from testing and upload a corrected build with a higher `CURRENT_PROJECT_VERSION`.

## Gateway

The gateway under `server/pi-gateway/` is not packaged in the iOS archive. Deploy it independently, keep `PI_GATEWAY_TOKEN` and GitHub credentials out of source control, and place remote traffic behind TLS or an encrypted tunnel.

Tool-capable harnesses must run under a separate OS identity or container from the credential-holding gateway. Environment scrubbing is defense in depth and does not provide same-user process isolation on macOS.

Before enabling GitHub connection, configure the gateway values documented in `server/pi-gateway/README.md`, then verify `/health`, `/v1/runtimes`, `/v1/connections`, and a streamed completion through the same URL the iOS app uses.
