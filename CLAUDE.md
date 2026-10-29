# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

EchipaMea — Flutter app for small contractor teams, with two roles in one binary: **Foreman** (manage clients, projects, phases, team, planning) and **Worker** (see assigned jobs, follow phase instructions, submit end-of-day reports). UI is localized in Romanian (default), Hungarian and English.

## Commands

```bash
flutter pub get                  # dependencies
flutter analyze                  # lint/static analysis (CI gate)
flutter test                     # all tests
flutter test test/features/projects_controller_test.dart          # single file
flutter test --plain-name 'addProject adds project'               # single test by name
dart format .                    # formatter
flutter build apk --release      # Android build (CI gate)
flutter run -d windows|chrome|<device-id>
scripts/e2e_app.sh [windows|linux|chrome]   # end-to-end: real app + real server (see README)
```

`.env` must exist before any run/build/test — `pubspec.yaml` declares it as a bundled asset and `main.dart` loads it at startup. Copy `.env.example` to `.env` (this is what CI does).

Backend (`server/`, NestJS + Prisma + Postgres), run from `server/`:

```bash
npm run start:dev                # API on :3000 (needs server/.env and a migrated DB)
npm run typecheck && npm run lint && npm run format:check
npm test                         # unit tests (src/**/*.spec.ts)
npm run test:e2e                 # real app + Postgres; TEST_DATABASE_URL must name a *_test DB
npx jest --config ./test/jest-e2e.json --runInBand test/auth.e2e-spec.ts   # one e2e suite
npm run spec:generate            # regenerate docs/backend-openapi.yaml after route/DTO changes
npm run spec:check               # CI gate: specs must match the code
npm run prisma:deploy && npm run seed
```

e2e suites each truncate every table and re-seed (`test/support/db.ts`); new suites should use `createTestApp()` / `loginForeman()` / `workerSession()` from `test/support/`. `POST /foreman/login` is throttled to 5/min per app instance, so log in once per role in `beforeAll`.

## Repo conventions (from `.cursor/rules/`, all still in force)

- **Build after significant changes**: run a real build (`flutter build apk` or `flutter run`) before reporting completion on multi-file, routing, state, dependency, or platform-integration changes — not just `flutter analyze`.
- **Format before commit**: `dart format` the changed files before creating a commit.
- **Localize all new UI text**: never hardcode user-facing strings. Add the key to *all three* language maps in [app_localizations.dart](lib/src/core/i18n/app_localizations.dart), add the matching getter, and use `context.l10n.<key>` in widgets.
- **Update README for user-visible functionality**: new flows, routes, env vars, or permissions go into `README.md` in the same task; if no change is needed, say why.

## Architecture

**Layering** — `lib/src/core/` holds cross-cutting concerns (routing, i18n, theme, auth/session, env, adaptive breakpoints); `lib/src/features/<feature>/` follows `domain/entities` → `application` (coordinators, API clients) → `presentation/{pages,providers,widgets}`.

**State: Riverpod; a repository per domain picks mock or API.** Clients, team, projects with their phases, daily worker sequences, notifications, and the foreman's profile and company each go through a repository: `lib/src/features/foreman/data/` (`ClientsRepository`, `EmployeesRepository`, `ProjectsRepository`, `SequencesRepository`, `NotificationsRepository`, with hand-written JSON mappers that keep server shapes such as `YYYY-MM-DD` phase dates out of the entities) and [profile_repository.dart](lib/src/core/profile/profile_repository.dart). Each has an in-memory (or SharedPreferences) version holding the demo seed and an `ApiClient` version, chosen by `AppEnv.hasBackend` in its `…RepositoryProvider`. Their notifiers are `AsyncNotifier`s: a save awaits the server, then replaces the local copy with the reply (no optimistic writes); a refusal throws and leaves the state alone, and the page shows it with `apiErrorMessage`. The in-memory repositories mirror the server, e.g. an unknown id throws `NOT_FOUND` and submitting a done phase `PHASE_INVALID_TRANSITION`. Sequences are per day: `daySequencesProvider(dayKey)` is an auto-disposed family that reloads whenever the projects change, because suggestions are worked out from the phases (only manual orders are stored). The worker side has its own [worker_repository.dart](lib/src/features/worker/data/worker_repository.dart): with a backend it uses the worker endpoints (`/worker/me`, `/worker/projects`, `/workers/:id/sequence`, `/worker/arrivals`, phase submit) with the worker's token, so a worker phone never loads the company's roster or project list; in mock mode it is built on the foreman's in-memory repositories. Worker providers start `build()` with `await watchWorkerSession(ref)` (the worker counterpart of `watchForemanScope`). In mock mode they also follow the foreman's `projectsProvider`/`teamProvider`, whose demo data they are built on. Use `selectAsync` for such a dependency, never `select` on `.value`: a value that changes during the first load restarts it, and a provider nobody listens to (a bare `container.read(...future)` in a test) is paused and never finishes. Only a few things persist on the device: both sessions, in `flutter_secure_storage` via `TokenStore` ([token_store.dart](lib/src/core/auth/token_store.dart)), and, in SharedPreferences, the selected locale, theme mode, setup-flow completion, the foreman getting-started checklist, and the mock-mode profile.

**Work-instruction media is not uploaded yet.** In mock mode photos and voice memos are **local file paths** on the instruction (`photoPaths`/`audioPaths`). With a backend the editor hides the attach controls behind a hint, and an instruction carries the server's attachments as `photoMediaIds`/`audioMediaIds` without showing them. They must survive every save, because a phase PATCH replaces the whole instruction list. Uploading and displaying them is a planned follow-up.

**Reading async foreman data.**
- **Providers:** foreman data providers watch their repository, then start `build()` with `await watchForemanScope(ref)` ([auth_session_controller.dart](lib/src/core/auth/auth_session_controller.dart)). With a backend it waits for the session to be restored and rebuilds the provider when a different foreman signs in; it returns false, meaning load nothing, while signed out.
- **Screens:** read these providers with `.current` ([async_status_view.dart](lib/src/core/ui/async_status_view.dart)), not `.value`. During a reload for a changed dependency, Riverpod keeps the previous value, which here is another company's data; `.current` drops it, and also drops data after a failed load. When `.current` is null, show `AsyncStatusView` (a spinner, or the error with Retry).
- **Edit forms are resolved at the route:** the public page widget waits for the entity, then builds the private stateful form with it, because the form copies it into controllers once in `initState` (client, employee, project and phase forms). Since the page watches the list, the form also receives the latest entity on every change; `widget.existing` is current, only the controllers are not.
- **Retry:** the root `ProviderScope` uses `apiRetry`, so Riverpod retries a failed load only for network errors and 5xx, never for a 4xx.

**Two parallel session models.** `authSessionProvider` is the *foreman* session; `sessionProvider` is the *worker* session created by scanning a QR ticket. Both are `AsyncNotifier`s restored from `TokenStore` at startup, so a worker stays signed in across restarts until the 7-day refresh token runs out or the foreman deactivates them. Both can exist on the same device at once, and [app_router.dart](lib/src/core/routing/app_router.dart) `redirect` arbitrates between them — it waits while either is still loading, it is the single source of truth for who may reach `/foreman/*` vs `/worker/*`, and it also gates the first-run `/setup` flow. Route changes almost always mean touching that redirect.

**HTTP goes through `ApiClient`** ([api_client.dart](lib/src/core/network/api_client.dart)), one instance per session: `foremanApiProvider`, `workerApiProvider`, plus `publicApiProvider` for login, refresh and ticket redeem. Each session notifier implements `SessionTokens`; on a 401 the client refreshes once (concurrent 401s share the refresh — refresh tokens rotate, so a parallel second refresh would replay a spent token and get the session revoked) and retries once. A refused refresh, or `ACCOUNT_DISABLED`, expires the session and the router sends the user to sign in; being offline never does. Errors are `ApiException` (`status`, `code`, `field`, `traceId`; `isNetwork` when no response arrived) — show them with `apiErrorMessage(l10n, error)`, never `error.toString()`. Don't build URLs from `AppEnv.authApiBaseUrl` by hand; `AppEnv.hasBackend` is the only mock-mode check.

**Login modes.** `AUTH_API_BASE_URL` decides everything: empty means mock mode (no network, seeded demo data, what CI runs); set means the app talks to `server/`.

Foreman login is mocked in `AuthSessionNotifier._mockTokenForEmail` when the base URL is empty (any `@`-containing email + 3+ char password), and posts to `/foreman/login` otherwise.

Worker login is a real QR redeem. The foreman asks the server for a ticket (`POST /employees/{id}/login-ticket`) and shows `qrPayload`; the worker scans it and `SessionNotifier.connectFromQrPayload` POSTs to `/worker/login-tickets/redeem`, receiving a real worker JWT. The local expiry check survives as a fast fail, but the server decides. Payload parsing lives in [qr_ticket_payload.dart](lib/src/core/auth/qr_ticket_payload.dart) and still accepts raw JSON, `?payload=<json>` and base64. Mock mode falls back to a locally minted ticket and a `mock-worker-session-…` token — `WorkerSession.isAuthenticated` is how you tell the two apart.

**There is no anonymous access.** Every request and every socket must present a token naming a company; the server has no `AnonymousPrincipal` and no flag that can reintroduce one. Sockets authenticate with a single-use ticket from `POST /realtime/tickets` passed as `?ticket=` — Dart cannot set headers on a WebSocket from Flutter web, and a raw access token in a query string would land in every access log.

**Project/phase status is derived, not set.** `ProjectStatus` (`planned`/`inProgress`/`done`) is computed from the phases by `projectStatusFromPhases` in [project.dart:192](lib/src/features/foreman/domain/entities/project.dart#L192): all phases `done` → project done; any phase started → in progress. `PhaseStatus` (`notStarted`/`inProgress`/`pendingReview`/`done`) is what actually moves, via `submitPhaseForReview` / `reviewPhase` on `ProjectsNotifier`. Never assign `ProjectStatus` directly when mutating phases — recompute it. The one override is closing a project (`markDone`, undone by `reopen`), which is all the project form's status dropdown offers. With a backend the server derives both, so every repository change returns the whole project and the notifier swaps it in. `submitPhaseForReview` means "a worker's report arrived": with a backend the upload already moved the phase, so it only refetches the project. Likewise the project-level worker list is derived from phase assignments, not entered separately.

**Worker→project assignment.** With a backend, `GET /worker/projects` decides: the project's or a live phase's assignment, done projects left out. Mock mode (`InMemoryWorkerRepository.projects`) tries, in order: `project.assignedEmployeeIds`, any phase's `assignedEmployeeIds`, then a case-insensitive match of the worker's display name against `project.workers`. That name fallback exists only because older demo projects have no employee IDs; the server does not reproduce it.

**Realtime side-effects live in `application/` coordinators**, both mounted by watching them in [app.dart](lib/src/app.dart) so they run for the whole app lifetime:

- `workerTelemetryCoordinator` — opens `WORKER_TELEMETRY_WS_URL` only while local device time is inside the employee's configured working days/hours, sends a `worker_location` frame roughly every 30 minutes, and closes the socket outside those hours. It has no reconnect loop on purpose: each sample opens the socket if it is down.
- `foremanNotificationsProvider` — an `AsyncNotifier` holding the server's notification list and unread count, plus the `FOREMAN_NOTIFICATIONS_WS_URL` socket. The socket only announces: a `worker_report_submitted` frame refetches the list and invalidates `projectsProvider`, because the server has already stored the notification and moved the phase. While a foreman is signed in, a dropped socket reconnects with `Backoff` (2s doubling to 60s, a fresh ticket per attempt) and refetches once it is back. Titles are worded when shown, so a language switch rewords the list.
- Report submit posts multipart/form-data to `/worker/reports` through `workerApiProvider` (`WORKER_REPORTS_API_URL`, if set, overrides the URL). The server moves the phase to pendingReview and fans out to foremen itself; the app no longer publishes a socket frame. In mock mode the upload is a no-op success.

**Backend contracts:** [docs/backend-openapi.yaml](docs/backend-openapi.yaml) (REST) is **generated** from the server code — after changing a route or DTO, run `npm run spec:generate` in `server/` and commit the result; never hand-edit it. [docs/websockets-asyncapi-draft.yaml](docs/websockets-asyncapi-draft.yaml) (realtime) is hand-written; when changing a frame, update it and the Dart client together. `npm run spec:check` (CI) fails if either spec disagrees with the code. REST endpoints assume `Authorization: Bearer <token>` (except the public `POST /foreman/login`) and the `error.code`/`error.message`/`error.field`/`traceId` envelope.

## Testing

Tests use plain `ProviderContainer()` from `flutter_riverpod` and read notifiers directly; widget tests exist for the heavier forms. Always call `SharedPreferences.setMockInitialValues({})` in `setUp` — several controllers read prefs during `build()` and will hang or throw otherwise. Tests depend on the seeded demo IDs (`p1`, `p2`, `c1`, `e1`, …), so changing the seed data in the in-memory repositories breaks tests elsewhere. Async notifiers report loading for at least a microtask even in mock mode, so a test awaits `container.read(xProvider.future)` before reading or mutating, and widget code must not assume the list is there on the first frame.

[test/flutter_test_config.dart](test/flutter_test_config.dart) gives every test an empty in-memory `flutter_secure_storage`. Tests that talk to the API use [test/support/fake_api.dart](test/support/fake_api.dart): `useFakeBackend()` leaves mock mode for one test, `FakeServer` scripts responses by `METHOD /path` and records requests, and `makeApiContainer(server:, store:)` overrides `httpClientProvider` and `tokenStoreProvider` and turns off Riverpod's retry. Pass `store: foremanStore()` for a signed-in foreman, or `workerStore()` for a connected worker. No real network, no new dependencies — it is `package:http/testing.dart`.

[integration_test/app_e2e_test.dart](integration_test/app_e2e_test.dart) is the opposite: one ordered journey through the real UI against the real server, run by `scripts/e2e_app.sh`.
- **Server:** `npm run e2e:app-server` resets and seeds the `_test` database and serves with `E2E_TEST_HOOKS=true`.
- **When to touch it:** a change to sign-in, routing, the QR code dialog or the connect page, notifications or sessions should keep it passing. Each step logs `e2e step N`, so a hang shows where it stopped.
- **Waiting:** wait with `pumpUntil`/`pumpUntilFound` in real time, never `pumpAndSettle`, because spinners and sockets never settle. `pumpUntilFound` also waits out the page transition and clears snack bars, which otherwise cover the bottom of the next page.
- **Desktop sign-in:** `mobile_scanner` has no camera on Windows or Linux, so the connect page offers a typed login code (`worker-login-code-field`), and the foreman's QR dialog can show and copy it (`employee-login-code`).

## Platform notes

Adding a feature that touches camera, microphone, photos, location, or external map apps requires matching native config: Android `RECORD_AUDIO` and `map_launcher` package-visibility queries in the manifest; iOS `Info.plist` usage strings plus `LSApplicationQueriesSchemes` entries for map apps. Voice playback is intentionally skipped on web (with an on-screen hint) — guard platform-specific media code rather than assuming mobile.

`flutter_secure_storage` needs: Android `allowBackup="false"` (already set — a restored backup of its encrypted prefs cannot be decrypted) and minSdk 24, which is Flutter's default; on macOS it uses the legacy keychain (`usesDataProtectionKeychain: false` in `SecureTokenStore`) so no Keychain Sharing entitlement or provisioning profile is needed; on web it only works over HTTPS or localhost.
