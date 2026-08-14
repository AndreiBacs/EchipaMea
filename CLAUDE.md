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

## Repo conventions (from `.cursor/rules/`, all still in force)

- **Build after significant changes**: run a real build (`flutter build apk` or `flutter run`) before reporting completion on multi-file, routing, state, dependency, or platform-integration changes — not just `flutter analyze`.
- **Format before commit**: `dart format` the changed files before creating a commit.
- **Localize all new UI text**: never hardcode user-facing strings. Add the key to *all three* language maps in [app_localizations.dart](lib/src/core/i18n/app_localizations.dart), add the matching getter, and use `context.l10n.<key>` in widgets.
- **Update README for user-visible functionality**: new flows, routes, env vars, or permissions go into `README.md` in the same task; if no change is needed, say why.

## Architecture

**Layering** — `lib/src/core/` holds cross-cutting concerns (routing, i18n, theme, auth/session, env, adaptive breakpoints); `lib/src/features/<feature>/` follows `domain/entities` → `application` (coordinators, API clients) → `presentation/{pages,providers,widgets}`.

**State: Riverpod, in-memory demo data.** There is no backend yet and no persistence layer for domain data. `projectsProvider`, `teamProvider`, `clientsProvider` are `NotifierProvider`s that seed hardcoded demo objects in `build()`. Only a few things persist, via SharedPreferences: foreman auth token, selected locale, theme mode, setup-flow completion, foreman getting-started checklist progress. Photos and voice memos are held as **local file paths**, not uploaded, until a backend stores binaries.

**Two parallel session models.** `authSessionProvider` (`AsyncNotifier`, SharedPreferences-backed) is the *foreman* session; `sessionProvider` (`Notifier`, memory only) is the *worker* session created by scanning a QR ticket. Both can exist on the same device at once, and [app_router.dart](lib/src/core/routing/app_router.dart) `redirect` arbitrates between them — that redirect is the single source of truth for who may reach `/foreman/*` vs `/worker/*`, and it also gates the first-run `/setup` flow. Route changes almost always mean touching that redirect.

**Login modes.** With `AUTH_API_BASE_URL` empty, foreman login is mocked in `AuthSessionNotifier._mockTokenForEmail` (any `@`-containing email + 3+ char password). Worker login is *always* local right now: the foreman generates a QR ticket (`type: foreman_worker_login_ticket`, `ticketId`, employee identity, `expiresAt`), and `SessionNotifier.connectFromQrPayload` validates expiry locally and mints a mock token. It accepts raw JSON, `?payload=<json>`, and base64 payloads — mirroring the planned backend consume-ticket endpoint.

**Project/phase status is derived, not set.** `ProjectStatus` (`planned`/`inProgress`/`done`) is computed from the phases by `projectStatusFromPhases` in [project.dart:177](lib/src/features/foreman/domain/entities/project.dart#L177): all phases `done` → project done; any phase started → in progress. `PhaseStatus` (`notStarted`/`inProgress`/`pendingReview`/`done`) is what actually moves, via `submitPhaseForReview` / approval on `ProjectsNotifier`. Never assign `ProjectStatus` directly when mutating phases — recompute it. Likewise the project-level worker list is derived from phase assignments, not entered separately.

**Worker→foreman assignment matching** ([worker_assigned_projects_provider.dart](lib/src/features/worker/presentation/providers/worker_assigned_projects_provider.dart)) tries, in order: `project.assignedEmployeeIds`, any phase's `assignedEmployeeIds`, then a case-insensitive match of the worker's display name against `project.workers`. The name fallback exists because older demo projects have no employee IDs.

**Realtime side-effects live in `application/` coordinators**, both mounted by watching them in [app.dart](lib/src/app.dart) so they run for the whole app lifetime:

- `workerTelemetryCoordinator` — opens `WORKER_TELEMETRY_WS_URL` only while local device time is inside the employee's configured working days/hours, sends a `worker_location` frame roughly every 30 minutes, and closes the socket outside those hours.
- `foremanNotificationsProvider` — connects to `FOREMAN_NOTIFICATIONS_WS_URL` while a foreman session exists, and turns `worker_report_submitted` events into the app-bar notification badge and phase status changes.
- Report submit posts multipart/form-data to `WORKER_REPORTS_API_URL`, then opens a short-lived socket, waits for ready, sends one `worker_report_submitted` frame and awaits the sink close so the frame flushes. All of this is best-effort — an unset or unreachable endpoint must not break the flow.

**Backend contracts** are drafted in [docs/backend-openapi-draft.yaml](docs/backend-openapi-draft.yaml) (REST) and [docs/websockets-asyncapi-draft.yaml](docs/websockets-asyncapi-draft.yaml) (realtime). When changing a payload shape, keep the runtime frame, the OpenAPI draft, and the AsyncAPI draft in sync. REST endpoints assume `Authorization: Bearer <token>` (except the public `POST /foreman/login`) and the `error.code`/`error.message`/`error.field`/`traceId` envelope.

## Testing

Tests use plain `ProviderContainer()` from `flutter_riverpod` and read notifiers directly; widget tests exist for the heavier forms. Always call `SharedPreferences.setMockInitialValues({})` in `setUp` — several controllers read prefs during `build()` and will hang or throw otherwise. Tests depend on the seeded demo IDs (`p1`, `p2`, `c1`, `e1`, …), so changing the seed data in a `build()` breaks tests elsewhere.

## Platform notes

Adding a feature that touches camera, microphone, photos, location, or external map apps requires matching native config: Android `RECORD_AUDIO` and `map_launcher` package-visibility queries in the manifest; iOS `Info.plist` usage strings plus `LSApplicationQueriesSchemes` entries for map apps. Voice playback is intentionally skipped on web (with an on-screen hint) — guard platform-specific media code rather than assuming mobile.
