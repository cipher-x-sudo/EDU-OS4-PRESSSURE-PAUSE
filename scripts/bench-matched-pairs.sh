#!/bin/bash
# Non-interactive matched PressurePause benchmarks (patched kernel only).
# Baseline runs: reboot to 6.8.12-baseline and run ./bench-run.sh with same params.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export BENCH_AUTO=1
export BENCH_SKIP_CONFIRM=1
export BENCH_STRESS_TIMEOUT="${BENCH_STRESS_TIMEOUT:-120}"
export BENCH_COLLECT_PSI=yes
export BENCH_PSI_INTERVAL=5

if [[ "$(uname -r)" != *pressurepause* ]]; then
	echo "error: boot 6.8.12-pressurepause+ first (got $(uname -r))" >&2
	exit 1
fi

if [[ ! -r /sys/kernel/debug/pressure_pause_activations ]] &&
	command -v sudo >/dev/null; then
	sudo mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
fi

echo "=== 4 workers / 85% ==="
BENCH_VM_WORKERS=4 BENCH_VM_BYTES_PCT=85 "$ROOT/bench-run.sh"

echo ""
echo "=== 8 workers / 93% ==="
BENCH_VM_WORKERS=8 BENCH_VM_BYTES_PCT=93 "$ROOT/bench-run.sh"

echo ""
echo "Done. Compare results/bench-*-baseline-* on baseline kernel with these directories."
