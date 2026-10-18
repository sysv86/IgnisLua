#!/usr/bin/env bash
# Run the Exo shell with a supervisor and a liveness watchdog.
#
#   ./scripts/run_exo.sh [config.lua]
#
# * restarts the shell if the process exits (IgnisLua still has a rare crash
#   inside LuaGObject's marshalling -- see exo/README.md, "Stability notes");
# * restarts it if the IPC stops answering, which is what a blocked main loop
#   (deadlock) looks like from the outside: the bar stays drawn but nothing
#   updates and nothing reacts.

set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname -- "$script_dir")"
config="${1:-$repo_root/exo/config.lua}"
launcher="$repo_root/bin/ignis-bin"
cli="$repo_root/bin/ignis-bin"

if [[ ! -x "$launcher" ]]; then
    echo "error: $launcher not found (run 'make' first)" >&2
    exit 1
fi

log_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$log_dir"
log="$log_dir/exo.log"

echo "[supervisor] starting Exo ($config), log: $log"

app_pid=""
start_app() {
    "$launcher" init -c "$config" >>"$log" 2>&1 &
    app_pid=$!
    echo "[supervisor] started pid $app_pid at $(date '+%H:%M:%S')" >>"$log"
}

stop_app() {
    if [[ -n "$app_pid" ]] && kill -0 "$app_pid" 2>/dev/null; then
        kill "$app_pid" 2>/dev/null
        for _ in 1 2 3 4 5 6; do
            kill -0 "$app_pid" 2>/dev/null || break
            sleep 0.5
        done
        kill -9 "$app_pid" 2>/dev/null
    fi
}

failures=0
start_app
# The first seconds are the configuration load; give it time to come up.
sleep 25

while true; do
    if ! kill -0 "$app_pid" 2>/dev/null; then
        wait "$app_pid" 2>/dev/null
        status=$?
        echo "[supervisor] Exo exited with status $status at $(date '+%H:%M:%S')" >>"$log"
        sleep 2
        failures=0
        start_app
        sleep 25
        continue
    fi

    # Generous timeout: a busy (but healthy) shell can take a few seconds to
    # answer, and the CLI itself needs a moment to build its proxy.
    if timeout 20 "$cli" list-windows >/dev/null 2>&1; then
        failures=0
    else
        failures=$((failures + 1))
        echo "[supervisor] IPC did not answer (attempt $failures) at $(date '+%H:%M:%S')" >>"$log"
        if [[ "$failures" -ge 5 ]]; then
            echo "[supervisor] main loop looks deadlocked, restarting at $(date '+%H:%M:%S')" >>"$log"
            stop_app
            sleep 2
            failures=0
            start_app
            sleep 25
            continue
        fi
    fi

    sleep 20
done
