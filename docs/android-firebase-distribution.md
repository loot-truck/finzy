# Testing the Flutter app on Android via Firebase App Distribution

Unlike iOS, this needs no paid developer account and no physically-connected
device or self-hosted runner — `.github/workflows/android.yml` runs on a
plain GitHub-hosted Ubuntu runner, builds a signed release APK, and uploads
it to Firebase App Distribution. Testers install/update it from the
Firebase App Distribution app on their own schedule.

## One-time setup

### 1. Generate a release keystore

```bash
keytool -genkey -v -keystore release.keystore -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```
You'll be prompted for a store password, a key password, and identity
details (name/org — doesn't need to be accurate). Keep the resulting
`release.keystore` file **outside the repo** (it's already covered by
`.gitignore`'s `*.keystore` and `*.jks` rules if placed under
`android/app/`, but simplest is to keep it entirely outside the project
directory). This is your own self-issued signing key — nothing to register
with Apple/Google, no cost, no approval process.

### 2. Create a Firebase project

- [console.firebase.google.com](https://console.firebase.google.com) → Add
  project (free "Spark" plan is enough).
- Add an Android app to it, using the app's application ID —
  `mobile/flutter_app/android/app/build.gradle.kts` currently sets
  `applicationId = "com.financetracker.flutter_app"`.
- Note the **App ID** Firebase assigns (format `1:1234567890:android:abcd...`,
  found in Project Settings → General → Your apps).

### 3. Create a service account for CI

- Firebase console → Project Settings → Service Accounts → "Generate new
  private key" — downloads a `.json` file. This lets CI authenticate to
  Firebase without your personal login.

### 4. Add a tester group

- Firebase console → App Distribution → Testers & Groups → New group →
  name it `testers` (matches the `groups: testers` value in the workflow) →
  add your email (and anyone else's) as a tester.
- Each tester needs the **Firebase App Distribution** app installed from
  the Play Store (or the App Store, if you ever add iOS distribution this
  way too) and accepts an email invite once.

### 5. Add GitHub Actions secrets

Settings → Secrets and variables → Actions → New repository secret, for
each of:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -i release.keystore \| pbcopy` (paste the result) |
| `ANDROID_KEYSTORE_PASSWORD` | the store password from step 1 |
| `ANDROID_KEY_ALIAS` | `upload` (or whatever alias you used) |
| `ANDROID_KEY_PASSWORD` | the key password from step 1 |
| `FIREBASE_ANDROID_APP_ID` | the App ID from step 2 |
| `FIREBASE_SERVICE_ACCOUNT` | the full contents of the `.json` file from step 3 |

## Running a build

- Actions tab → "Android Firebase Distribution" → Run workflow, or push to
  `develop`.
- The workflow decodes the keystore, builds `flutter build apk --release`
  signed with it, and uploads to Firebase App Distribution.
- Testers get a notification in the Firebase App Distribution app (or by
  email) and can install/update directly — no cable, no unlocked-phone
  requirement, no dependency on your machine being on.

## Local release builds

To build a signed release APK locally (matching what CI produces), create
`mobile/flutter_app/android/key.properties` (gitignored) pointing at your
keystore:
```
storeFile=/absolute/path/to/release.keystore
storePassword=...
keyAlias=upload
keyPassword=...
```
Without this file, `flutter run --release`/`flutter build apk --release`
falls back to the Android debug key (Flutter's default scaffold behavior),
which is fine for local testing but shouldn't be distributed to others
since the debug key isn't private to you.
