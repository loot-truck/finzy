# Testing the Flutter app on your iPhone (no local Xcode)

Since Xcode can't be installed on this Mac, iOS builds are signed and
uploaded to TestFlight entirely by a GitHub Actions macOS runner (Xcode
comes preinstalled there — nothing installs locally). You just trigger the
workflow and install the build via the TestFlight app.

## One-time setup (in your browser, no Xcode needed)

1. **Enroll in the Apple Developer Program** at
   [developer.apple.com/programs](https://developer.apple.com/programs)
   ($99/year). This is a web form + payment, not a local tool. Required
   because installs signed without a paid account expire after 7 days and
   that free-tier signing path itself needs local Xcode — the paid account
   is what lets everything happen on CI instead.

2. **Register an App ID** in the
   [Apple Developer portal](https://developer.apple.com/account/resources/identifiers/list) →
   Identifiers → "+". Use a bundle ID matching the app —
   `mobile/flutter_app/ios/Runner.xcodeproj/project.pbxproj` currently uses
   `com.vamshinaik2020.financetracker` (check/update
   `PRODUCT_BUNDLE_IDENTIFIER` there if you want a different one before
   registering).

3. **Create an app record** in
   [App Store Connect](https://appstoreconnect.apple.com) → Apps → "+" →
   New App, using that same bundle ID. This is what TestFlight builds
   attach to.

4. **Create an App Store Connect API key**: App Store Connect → Users and
   Access → Integrations → App Store Connect API → "+". Download the
   `.p8` file (only downloadable once) and note the **Key ID** and
   **Issuer ID**. This key lets CI authenticate and upload builds without
   an interactive Apple ID login.

5. **Add these as GitHub Actions secrets** on the repo (Settings → Secrets
   and variables → Actions):
   - `ASC_KEY_ID`
   - `ASC_ISSUER_ID`
   - `ASC_KEY_CONTENT` — the full contents of the `.p8` file
   - `MATCH_PASSWORD` — a passphrase you choose, used to encrypt signing
     certs/profiles that `fastlane match` generates and stores (see below)
   - `MATCH_GIT_URL` — a **private** git repo you control, where `match`
     stores the encrypted certificate/profile (create an empty private repo
     for this; it holds no app code, just encrypted signing material)

   `fastlane match` (configured in `mobile/flutter_app/ios/fastlane/`)
   generates the distribution certificate and provisioning profile
   automatically on its first CI run and stores them (encrypted) in that
   repo — nothing to generate by hand.

6. **Add yourself as a TestFlight tester**: App Store Connect → your app →
   TestFlight tab → Internal Testing → add your Apple ID email. Install the
   **TestFlight** app from the App Store on your iPhone; once a build is
   processed you'll get a notification there.

## Running a build

- Go to the repo's Actions tab → "iOS TestFlight" workflow → "Run workflow",
  or push to the `develop` branch.
- The workflow builds the Flutter app, archives and signs it, and uploads to
  TestFlight. Apple typically takes a few minutes to finish processing
  before it's installable.
- Open TestFlight on your iPhone, install/update, and test.

## Turnaround expectations

Each cycle (push → CI build → Apple processing → install) takes several
minutes — good for "test this feature on my phone" checkpoints, not
hot-reload. That's the trade-off of not having local Xcode; there's no way
around it for a physical iPhone without either local Xcode or a paid
developer account + CI signing (which is what this sets up).
