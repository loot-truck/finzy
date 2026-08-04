# Deploying to your iPhone via a self-hosted GitHub Actions runner

This is the free alternative to `docs/ios-testflight.md` — no Apple Developer
Program, no macOS Actions billing. The trade-off: your Mac and iPhone both
have to be on, unlocked, and connected whenever the workflow runs, since it
drives your local Xcode installation directly.

## Prerequisites

- Xcode installed on this Mac, with Command Line Tools selected:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```
- A free Apple ID added in Xcode → Settings → Accounts (Personal Team), or a
  paid account if you have one.
- The iPhone connected once via USB, "Trust This Computer" accepted, and
  registered under the `Runner` target's Signing & Capabilities in Xcode
  (`mobile/flutter_app/ios/Runner.xcworkspace`) — this creates the local
  provisioning profile the workflow will reuse.
- Flutter on `PATH` for whichever user account runs the runner service.

## 1. Register the runner

GitHub repo → Settings → Actions → Runners → "New self-hosted runner" →
macOS / ARM64. It gives you a one-time token and commands like:

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -o actions-runner-osx-arm64.tar.gz -L <url from the GitHub page>
tar xzf actions-runner-osx-arm64.tar.gz
./config.sh --url https://github.com/loot-truck/finzy --token <TOKEN>
```
Give it the label `macos-local` (matches `.github/workflows/ios-local.yml`'s
`runs-on: [self-hosted, macOS]` — the default `macOS` label is applied
automatically; no extra label config is required unless you rename it).

## 2. Run the runner

For a first test, run it in the foreground in a terminal you keep open:

```bash
./run.sh
```

To keep it running persistently:

```bash
./svc.sh install
./svc.sh start
```

**Known issue**: a LaunchDaemon-run service may not have access to your
login Keychain, which code signing needs. If builds fail with a signing/
Keychain error under `svc.sh`, either keep using `./run.sh` in a logged-in
terminal session, or unlock the keychain explicitly before jobs run:

```bash
security unlock-keychain ~/Library/Keychains/login.keychain-db
```

## 3. Run the workflow

- Plug the iPhone in, unlock it.
- GitHub repo → Actions → "iOS Local Device Install" → Run workflow.
- It finds the connected device automatically (via `flutter devices
  --machine`), builds in release mode, and installs directly — no upload,
  no TestFlight step.

## Constraints

- This is not a background/offline deploy: the Mac and iPhone must both be
  present and connected for the run to succeed. "Self-hosted" removes the
  need for a paid cloud Mac runner — it doesn't remove the need for your
  own hardware to be there.
- With a free Personal Team, the install still expires after **7 days** —
  re-run the workflow at least weekly (with the phone connected) to refresh
  it, even with no code changes.
- Only one physical device is targeted per run (the first `platformType:
  ios, type: device` match). For multiple iPhones, connect one at a time
  and re-run, or extend the workflow to loop over all matches.
