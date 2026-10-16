# Restora frontend

Android-first, online-only engineering foundation for one elbow flexion/extension demonstration. Developer A primarily owns this repository; both developers review and contribute. The independent FastAPI repository owns the API and database. See [CONTRIBUTING.md](CONTRIBUTING.md) for the paired GitHub Flow and [docs/SPRINT.md](docs/SPRINT.md) for the seven-day plan.

The current exercise input is **SIMULATED**, clearly labelled throughout the application. There is no live camera preview, camera permission request, ML Kit processing, or verified physical-phone tracking. Thresholds (flexed ≤70°, extended ≥150°), target (10), dwell (200 ms), confidence cutoff (0.7), and instructions are demonstration defaults requiring professional review before patient use. This is not patient-ready software.

## Run the foundation

Install Flutter **3.47.7** (Dart 3.13.5; `.fvmrc` records the selection), Android Studio with Android SDK 36, JDK 17, and an Android emulator or USB-debuggable phone. The generated Android project targets SDK 36 and requires Android API 24+. Gradle also installs SDK platform 35 for a transitive JNI plugin; accept the Android SDK licenses before building. Flutter/package versions and official references are recorded in [docs/dependencies.md](docs/dependencies.md).

```powershell
cd restora-frontend
flutter doctor -v
flutter doctor --android-licenses
flutter pub get --enforce-lockfile
flutter devices
# Android emulator talks to the host backend at 10.0.2.2.
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Developer B first follows the backend README to migrate PostgreSQL, seed `demo@example.test` with a developer-chosen synthetic password, and run Uvicorn. Enter that password on the login screen. No seed password or backend secret is bundled here.

For a USB phone using the local backend:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

For a deployed backend, use its explicitly supplied Railway HTTPS URL:

```powershell
flutter run -d <android-device-id> --dart-define=API_BASE_URL=https://<backend-domain>
```

Only debug Android configuration permits loopback/emulator HTTP. Nonlocal cleartext URLs are rejected by the API client. Release runs require an HTTPS API URL; no release signing/distribution has been configured. The access token is stored with Android-backed `flutter_secure_storage`, not shared preferences; Android backup is disabled. Passwords are never persisted by application code.

## Exercise and save behavior

Sign in online → load the assigned exercise → open the simulated integration demo → Start → hold the slider at ≥150°, ≤70°, and ≥150° for roughly 0.3 seconds at each end → Stop and save → Done → History. History is fetched from the backend.

The independent state machine requires extension → flexion → return extension before counting. Dwell and 5° hysteresis reject brief threshold noise. Missing/low-confidence landmarks, invalid angles, out-of-order samples, a gap over 500 ms, or lifecycle interruption discard partial movement without deleting completed repetitions. The source contract requires capture timestamps from a session-local monotonic clock. A watchdog resets partial movement after silence and stops a silent source after 5 seconds.

Stopping freezes the summary and its single client-generated UUID before any asynchronous shutdown/request. Failed saves keep that exact summary in memory on the exercise screen. Retry save sends identical values and UUID; the backend returns the existing record after a lost successful response. Authentication expiry offers in-place sign-in above the existing screen, followed by retry. Use the same account. Explicit discard or process termination loses an unsaved summary. There is no durable offline database, queue, or background synchronization.

## Structure and boundaries

```text
lib/
  core/api/                    HTTP, bearer headers, error envelope and response checks
  core/platform/               replaceable secure token store
  features/authentication/     data repositories, ChangeNotifier state, screens
  features/exercise/           assignment, isolated counter/controller, screens
    platform/pose_source.dart  replaceable on-device tracking boundary
    platform/simulated_pose_source.dart  labelled integration-only input
  features/sessions/           immutable summary, API history/save, state, screens
contract/                      backend-approved OpenAPI snapshot and example summary
test/                          counter, retry/lifecycle, HTTP/error behavior
```

Screens render state; ChangeNotifier controllers coordinate feature actions; repositories map backend JSON; platform services own token storage and pose input. `ExerciseController` receives `PoseSource` and `SessionRepository` dependencies. Replace `SimulatedPoseSource` with an Android camera/ML Kit adapter without changing rep counting or session serialization. Camera frames and landmarks stay on the phone; the network layer only sends the stopped summary.

In-place reauthentication compares the backend JWT subject with the existing subject before replacing secure storage. This only preserves the identity associated with in-memory assignment/history/pending-session state; decoded claims never authorize a request. The backend verifies signatures, expiration, and ownership. Switching accounts requires signing out first, which replaces feature screens and clears their in-memory state.

Backend endpoints: `POST /v1/auth/login`, `GET /v1/assignment`, `POST /v1/sessions`, `GET /v1/sessions`, and `GET /health`. The backend owns field validation, identity/ownership, and idempotency. Snapshot and example in `contract/` must come from the matching backend export; update paired PRs under the same task ID and deploy compatible backend changes before clients.

## Checks

```powershell
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build apk --debug
```

CI runs these commands with pinned Flutter and JDK. The tests exercise full cycles, dwell/jitter, missing/invalid/stale samples, capture gaps, frozen retries, duplicate retry prevention, authentication failures, lifecycle startup races, request bodies, server envelopes, malformed responses, timeouts, and network failures. An APK build does not validate camera behavior, secure-storage operation on a phone, or the end-to-end phone/backend workflow.

Verified in this workspace on 2026-10-16: `flutter pub get --enforce-lockfile` passed; formatting passed; `flutter analyze` reported no issues; all **27 Flutter tests passed**; `flutter build apk --debug` succeeded. The local artifact is `build/app/outputs/flutter-apk/app-debug.apk` (159,292,575 bytes), excluded from Git. The first native build installed the additional SDK platform and CMake dependencies described above.

The repository HTTP smoke also passed against the running FastAPI/PostgreSQL backend: login → assignment → one simulated summary → identical retry → conflicting retry rejected → backend history. Two identical POSTs and one conflicting POST left exactly one stored simulated session. These results verify the foundation and its simulated integration path. No physical phone was connected: camera tracking, secure token storage on the actual phone, phone lifecycle/permission behavior, and the complete phone/backend workflow remain unverified. Frontend source is published to [adnro2/restora](https://github.com/adnro2/restora/tree/feat/RST-001-mvp-foundation) on `feat/RST-001-mvp-foundation`; `main` retains the initial scaffold pending PR review. Remote CI, Railway deployment, and release distribution remain pending; this repository does not claim Docker execution or hosted deployment validation.

With the local backend running and seeded, the repository smoke script uses the same HTTP repositories as the app to verify login, assignment retrieval, save, identical retry, conflict rejection, and history. It creates one synthetic simulated session per invocation:

```powershell
$env:API_BASE_URL = 'http://127.0.0.1:8000'
# Set DEMO_PASSWORD to the password chosen during backend seed; avoid logging it.
dart run tool/smoke_api.dart
```

## Camera milestone, Day 1–2

Developer A must implement and test an Android camera/ML Kit `PoseSource` on the **actual demo phone**, with Developer B pairing on integration. Planned candidates and native requirements are in [docs/dependencies.md](docs/dependencies.md); these packages are not installed or represented as implemented.

Required work: runtime camera permission and denial recovery; preview; Android image format/plane conversion; sensor/display rotation and mirrored preview handling; single in-flight inference with stale result dropping; shoulder/elbow/wrist confidence and angle extraction; monotonic capture timestamps; lifecycle shutdown/release/restart; interruption handling and visible status. Test lighting, framing, distance, occlusion, thermal load, latency, and full rep cycles. Confirm frames never leave the phone.

**Day 2 decision:** demonstrate reproducible counting and safe interruption behavior on the actual phone, or record the camera blocker and keep the demonstration explicitly simulated. Simulation success is not evidence of live-camera completion. No additional exercises or deferred product features should enter this one-week sprint.

