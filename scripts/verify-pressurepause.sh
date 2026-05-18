#!/bin/bash
# Run after booting 6.8.12-pressurepause (or 6.8.12-pressurepause+).
# Save to results/: VERIFY_SAVE=1 ./scripts/verify-pressurepause.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
kr="$(uname -r)"

if [[ "$kr" != *pressurepause* ]]; then
	echo "error: not running pressurepause kernel (got $kr)" >&2
	exit 1
fi

run_verify() {
	echo "kernel: $kr"
	echo "--- /proc/pressure/memory ---"
	cat /proc/pressure/memory
	echo "--- stress-ng smoke (30s) ---"
	stress-ng --vm 2 --vm-bytes 70% --timeout 30s
	echo "smoke test finished OK"
}

if [[ "${VERIFY_SAVE:-}" == 1 ]]; then
	out="$ROOT/results/patched-verify-$(date +%Y%m%d)"
	mkdir -p "$out"
	{
		echo "# Phase 3 verification — AFTER (patched kernel)"
		echo "run_type=after"
		echo "kernel_role=patched"
		echo "date=$(date -Iseconds)"
		echo "host=$(hostname)"
		echo "uname=$(uname -a)"
		echo "command=$0"
	} >"$out/metadata.txt"
	run_verify | tee "$out/verify-pressurepause.log"
	echo "Saved: $out/"
else
	run_verify
fi
