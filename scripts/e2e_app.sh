#!/usr/bin/env bash
# Runs the app's end-to-end suite (integration_test/) against a real server on
# a freshly reset and seeded e2e test database, then stops the server.
#
#   scripts/e2e_app.sh            # windows on Windows (Git Bash), linux elsewhere
#   scripts/e2e_app.sh macos      # any device `flutter devices` lists
#   CHROMEDRIVER=/path/to/chromedriver scripts/e2e_app.sh chrome
#
# A browser goes through `flutter drive` and needs a ChromeDriver matching
# the installed Chrome; the script starts it on port 4444.
#
# Needs TEST_DATABASE_URL (in server/.env or the environment) naming a
# database whose name ends in _test, and server/node_modules installed.
# E2E_APP_PORT picks the port (default 3100). On Linux CI, wrap it in
# xvfb-run.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
device="${1:-}"
if [ -z "$device" ]; then
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) device=windows ;;
    Darwin) device=macos ;;
    *) device=linux ;;
  esac
fi
port="${E2E_APP_PORT:-3100}"
work="$(mktemp -d)"
log="$work/server.log"
pidfile="$work/server.pid"

stop_server() {
  if [ -s "$pidfile" ]; then
    pid="$(cat "$pidfile")"
    if command -v taskkill > /dev/null 2>&1; then
      taskkill //F //T //PID "$pid" > /dev/null 2>&1 || true
    else
      kill "$pid" 2> /dev/null || true
    fi
  fi
  kill "${launcher:-}" 2> /dev/null || true
  kill "${chromedriver_pid:-}" 2> /dev/null || true
}
trap stop_server EXIT

echo "Starting the e2e server on port $port (log: $log)"
(cd "$root/server" && E2E_APP_PORT="$port" E2E_APP_PIDFILE="$pidfile" npm run e2e:app-server) > "$log" 2>&1 &
launcher=$!

for _ in $(seq 1 180); do
  grep -q "server ready" "$log" && break
  if ! kill -0 "$launcher" 2> /dev/null; then
    cat "$log"
    echo "The e2e server exited before it was ready." >&2
    exit 1
  fi
  sleep 1
done
if ! grep -q "server ready" "$log"; then
  cat "$log"
  echo "The e2e server did not become ready in time." >&2
  exit 1
fi

cd "$root"
define="--dart-define=E2E_API_BASE_URL=http://127.0.0.1:$port"
set +e
case "$device" in
  chrome | edge | web-server)
    if [ -z "${CHROMEDRIVER:-}" ]; then
      echo "Set CHROMEDRIVER to a chromedriver matching your browser." >&2
      exit 1
    fi
    "$CHROMEDRIVER" --port=4444 > "$work/chromedriver.log" 2>&1 &
    chromedriver_pid=$!
    sleep 2
    # On web `flutter drive` can hang after the run has finished, so trust
    # the verdict the test prints rather than its exit.
    drive_log="$work/drive.log"
    flutter drive --driver=test_driver/integration_test.dart \
      --target=integration_test/app_e2e_test.dart -d "$device" "$define" \
      > "$drive_log" 2>&1 &
    drive_pid=$!
    tail -f "$drive_log" &
    tail_pid=$!
    while kill -0 "$drive_pid" 2> /dev/null &&
      ! grep -qE "All tests passed!|Some tests failed" "$drive_log"; do
      sleep 2
    done
    sleep 2
    kill "$tail_pid" "$chromedriver_pid" 2> /dev/null || true
    wait "$drive_pid" 2> /dev/null || true
    grep -q "All tests passed!" "$drive_log"
    ;;
  *)
    flutter test integration_test -d "$device" "$define"
    ;;
esac
status=$?
set -e
if [ $status -ne 0 ]; then
  echo "--- last lines of the server log ($log)"
  tail -n 80 "$log"
fi
exit $status
