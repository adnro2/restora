# RST-005 frontend UX review

The frontend now presents the existing online demonstration as a consistent four-screen flow: sign in, review the assigned exercise, run a simulated session, then view server-backed history. This work improves the foundation; it does not complete live camera tracking or verify the MVP on an Android phone.

- **Sign in:** clear account fields, inline email/password validation, focus on the field that needs attention, a password visibility control, and a disabled submit action while signing in. Authentication failures appear with an accessible next action. No demo password is bundled in the app.
- **Assignment:** readable exercise instructions and demo target, a clearly labelled simulated-session action, loading feedback, refresh, and distinct recovery actions for an expired sign-in versus a network/server failure.
- **Exercise:** a large complete-repetition counter, target progress, tracking-status feedback, an elbow illustration, and persistent start/stop/save actions. Simulation controls remain explicitly labelled. Missing landmarks and interrupted input reset partial cycles through the existing independently tested counting logic.
- **History:** server-backed results, readable local dates and stop reasons, a tracking-mode label on each result, refresh, and separate loading, empty, authentication, and network/server states.

The shared theme uses readable type, consistent spacing, restrained green surfaces, and distinct warning/error notices. Content scrolls within a safe area and a bounded reading width. Layout tests cover a 360px viewport with 1.5× text. Error/recovery panels, changing session status and the repetition counter expose live semantics. The counter announces complete repetitions, and target progress has a numeric accessibility value with a descriptive label. Sign-out disables navigation until secure storage responds; a storage failure keeps the account open and provides feedback and retry.

The assignment and exercise screens retain professional-review warnings for movement thresholds, targets, and instructions. The exercise screen says **SIMULATED INPUT · NO CAMERA TRACKING**. History identifies simulated results as test input. Simulation is an integration tool and provides no evidence that camera tracking works.

Stopping freezes the summary, including its client-generated session UUID, timestamps, completed count, mode, and stop reason. If saving fails, the stopped summary remains in memory while the exercise screen stays open. Retry sends the same payload and UUID. Back navigation cannot silently lose those results; the user must save successfully or explicitly confirm discard. There is no durable offline storage or background retry queue.

This work can proceed independently of backend implementation. Widget tests inject synthetic assignments, a test-only pose source, and API/repository responses. Production authentication, assignments, submissions, and history still use the existing backend repositories. The approved OpenAPI snapshot, example session payload, endpoint paths, and request/response models remain unchanged. Backend integration and ownership enforcement must still be verified against the real API.

Run checks from the frontend repository before opening the PR:

```powershell
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build apk --debug
```

The new flow tests exercise loading and network recovery, expired-token reauthentication, stopped-session protection, identical retry submission, and enlarged-text layouts. Existing tests continue to cover API/error handling, authentication, counting cycles, jitter, tracking loss, and immutable retry summaries. Record the final checks, results, and build commit in the PR; an available test or build command is not evidence that it ran.

Generate optional review images with:

```powershell
flutter test test/ui_preview_test.dart --dart-define=WRITE_UI_PREVIEWS=true
```

The command writes `login.png`, `assignment.png`, `exercise_simulated.png`, and `history.png` under the ignored `build/ux_previews/` directory. These are actual Flutter widget-test renders at 390 × 1000 logical pixels using synthetic fixtures and SDK fonts. They are not Android screenshots, physical-phone testing, backend integration evidence, or camera evidence. Normal test runs skip image generation.

Copies from the verified RST-005 render are included for review:

| Screen | Synthetic widget preview |
| --- | --- |
| Sign in | [login.png](ux-previews/login.png) |
| Assigned exercise | [assignment.png](ux-previews/assignment.png) |
| Simulated exercise | [exercise_simulated.png](ux-previews/exercise_simulated.png) |
| Server history layout | [history.png](ux-previews/history.png) |

Executed on 2026-10-16: enforced dependency lockfile resolution, formatting, static analysis with no issues, **40 passing tests** using `flutter test --dart-define=WRITE_UI_PREVIEWS=true`, and a successful Android debug APK build. These results include the sign-out race regression, login/history recovery, frozen failed-save retry and enlarged-text layouts. The normal test command skips the one opt-in render test. Hosted CI and device tests are pending. API, lockfile and counting rules are unchanged by this task; the earlier local HTTP/PostgreSQL smoke was not repeated for the visual changes.

The task branch is `feat/RST-005-frontend-ux`, stacked on `feat/RST-001-mvp-foundation`. Review the foundation before merging it into frontend `main`; review the UX branch against the foundation in the meantime. After a foundation squash merge, start from updated `main` and cherry-pick only the RST-005 commit(s) so the new PR contains only UX work. Use another developer's review, passing CI, squash merge, and branch deletion as documented in the repository workflow. Frontend and backend repositories have independent PRs and merges; frontend work does not need to wait for every backend deliverable. Link related work by task ID, preserve the agreed contract, and deploy compatible backend changes before releasing a client that needs them.

Remaining integration work includes the camera/ML Kit adapter, permission and lifecycle handling, actual-phone tracking validation and the Day 2 decision gate, on-device secure token storage checks, sign-in/save/history and failed-save recovery against the real backend on the phone, and supplied-target deployment with CI. Preserve the sprint's protected integration/testing time. Professional review remains required before any patient use.
