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

**State: Riverpod, in-memory demo data.** `server/` implements the full API, but the app only calls it for auth, QR tickets, socket tickets and report upload; domain data has no client-side API wiring or persistence yet. `projectsProvider`, `teamProvider`, `clientsProvider` are `NotifierProvider`s that seed hardcoded demo objects in `build()`. Only a few things persist: both sessions, in `flutter_secure_storage` via `TokenStore` ([token_store.dart](lib/src/core/auth/token_store.dart)), and, in SharedPreferences, the selected locale, theme mode, setup-flow completion and the foreman getting-started checklist. Photos and voice memos are held as **local file paths**, not uploaded, until a backend stores binaries.

**Two parallel session models.** `authSessionProvider` is the *foreman* session; `sessionProvider` is the *worker* session created by scanning a QR ticket. Both are `AsyncNotifier`s restored from `TokenStore` at startup, so a worker stays signed in across restarts until the 7-day refresh token runs out or the foreman deactivates them. Both can exist on the same device at once, and [app_router.dart](lib/src/core/routing/app_router.dart) `redirect` arbitrates between them — it waits while either is still loading, it is the single source of truth for who may reach `/foreman/*` vs `/worker/*`, and it also gates the first-run `/setup` flow. Route changes almost always mean touching that redirect.

**HTTP goes through `ApiClient`** ([api_client.dart](lib/src/core/network/api_client.dart)), one instance per session: `foremanApiProvider`, `workerApiProvider`, plus `publicApiProvider` for login, refresh and ticket redeem. Each session notifier implements `SessionTokens`; on a 401 the client refreshes once (concurrent 401s share the refresh — refresh tokens rotate, so a parallel second refresh would replay a spent token and get the session revoked) and retries once. A refused refresh, or `ACCOUNT_DISABLED`, expires the session and the router sends the user to sign in; being offline never does. Errors are `ApiException` (`status`, `code`, `field`, `traceId`; `isNetwork` when no response arrived) — show them with `apiErrorMessage(l10n, error)`, never `error.toString()`. Don't build URLs from `AppEnv.authApiBaseUrl` by hand; `AppEnv.hasBackend` is the only mock-mode check.

**Login modes.** `AUTH_API_BASE_URL` decides everything: empty means mock mode (no network, seeded demo data, what CI runs); set means the app talks to `server/`.

Foreman login is mocked in `AuthSessionNotifier._mockTokenForEmail` when the base URL is empty (any `@`-containing email + 3+ char password), and posts to `/foreman/login` otherwise.

Worker login is a real QR redeem. The foreman asks the server for a ticket (`POST /employees/{id}/login-ticket`) and shows `qrPayload`; the worker scans it and `SessionNotifier.connectFromQrPayload` POSTs to `/worker/login-tickets/redeem`, receiving a real worker JWT. The local expiry check survives as a fast fail, but the server decides. Payload parsing lives in [qr_ticket_payload.dart](lib/src/core/auth/qr_ticket_payload.dart) and still accepts raw JSON, `?payload=<json>` and base64. Mock mode falls back to a locally minted ticket and a `mock-worker-session-…` token — `WorkerSession.isAuthenticated` is how you tell the two apart.

**There is no anonymous access.** Every request and every socket must present a token naming a company; the server has no `AnonymousPrincipal` and no flag that can reintroduce one. Sockets authenticate with a single-use ticket from `POST /realtime/tickets` passed as `?ticket=` — Dart cannot set headers on a WebSocket from Flutter web, and a raw access token in a query string would land in every access log.

**Project/phase status is derived, not set.** `ProjectStatus` (`planned`/`inProgress`/`done`) is computed from the phases by `projectStatusFromPhases` in [project.dart:177](lib/src/features/foreman/domain/entities/project.dart#L177): all phases `done` → project done; any phase started → in progress. `PhaseStatus` (`notStarted`/`inProgress`/`pendingReview`/`done`) is what actually moves, via `submitPhaseForReview` / approval on `ProjectsNotifier`. Never assign `ProjectStatus` directly when mutating phases — recompute it. Likewise the project-level worker list is derived from phase assignments, not entered separately.

**Worker→foreman assignment matching** ([worker_assigned_projects_provider.dart](lib/src/features/worker/presentation/providers/worker_assigned_projects_provider.dart)) tries, in order: `project.assignedEmployeeIds`, any phase's `assignedEmployeeIds`, then a case-insensitive match of the worker's display name against `project.workers`. The name fallback exists because older demo projects have no employee IDs.

**Realtime side-effects live in `application/` coordinators**, both mounted by watching them in [app.dart](lib/src/app.dart) so they run for the whole app lifetime:

- `workerTelemetryCoordinator` — opens `WORKER_TELEMETRY_WS_URL` only while local device time is inside the employee's configured working days/hours, sends a `worker_location` frame roughly every 30 minutes, and closes the socket outside those hours.
- `foremanNotificationsProvider` — connects to `FOREMAN_NOTIFICATIONS_WS_URL` while a foreman session exists, and turns `worker_report_submitted` events into the app-bar notification badge and phase status changes.
- Report submit posts multipart/form-data to `/worker/reports` through `workerApiProvider` (`WORKER_REPORTS_API_URL`, if set, overrides the URL). The server moves the phase to pendingReview and fans out to foremen itself; the app no longer publishes a socket frame. In mock mode the upload is a no-op success.

**Backend contracts:** [docs/backend-openapi.yaml](docs/backend-openapi.yaml) (REST) is **generated** from the server code — after changing a route or DTO, run `npm run spec:generate` in `server/` and commit the result; never hand-edit it. [docs/websockets-asyncapi-draft.yaml](docs/websockets-asyncapi-draft.yaml) (realtime) is hand-written; when changing a frame, update it and the Dart client together. `npm run spec:check` (CI) fails if either spec disagrees with the code. REST endpoints assume `Authorization: Bearer <token>` (except the public `POST /foreman/login`) and the `error.code`/`error.message`/`error.field`/`traceId` envelope.

## Testing

Tests use plain `ProviderContainer()` from `flutter_riverpod` and read notifiers directly; widget tests exist for the heavier forms. Always call `SharedPreferences.setMockInitialValues({})` in `setUp` — several controllers read prefs during `build()` and will hang or throw otherwise. Tests depend on the seeded demo IDs (`p1`, `p2`, `c1`, `e1`, …), so changing the seed data in a `build()` breaks tests elsewhere.

[test/flutter_test_config.dart](test/flutter_test_config.dart) gives every test an empty in-memory `flutter_secure_storage`. Tests that talk to the API use [test/support/fake_api.dart](test/support/fake_api.dart): `useFakeBackend()` leaves mock mode for one test, `FakeServer` scripts responses by `METHOD /path` and records requests, and `makeApiContainer(server:, store:)` overrides `httpClientProvider` and `tokenStoreProvider`. No real network, no new dependencies — it is `package:http/testing.dart`.

## Platform notes

Adding a feature that touches camera, microphone, photos, location, or external map apps requires matching native config: Android `RECORD_AUDIO` and `map_launcher` package-visibility queries in the manifest; iOS `Info.plist` usage strings plus `LSApplicationQueriesSchemes` entries for map apps. Voice playback is intentionally skipped on web (with an on-screen hint) — guard platform-specific media code rather than assuming mobile.

`flutter_secure_storage` needs: Android `allowBackup="false"` (already set — a restored backup of its encrypted prefs cannot be decrypted) and minSdk 24, which is Flutter's default; on macOS it uses the legacy keychain (`usesDataProtectionKeychain: false` in `SecureTokenStore`) so no Keychain Sharing entitlement or provisioning profile is needed; on web it only works over HTTPS or localhost.
