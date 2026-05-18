#!/bin/bash
# Run after booting 6.8.12-pressurepause (or 6.8.12-pressurepause+).
set -euo pipefail

kr="$(uname -r)"
echo "kernel: $kr"
if [[ "$kr" != *pressurepause* ]]; then
	echo "error: not running pressurepause kernel (got $kr)" >&2
	exit 1
fi

echo "--- /proc/pressure/memory ---"
cat /proc/pressure/memory

echo "--- stress-ng smoke (30s) ---"
stress-ng --vm 2 --vm-bytes 70% --timeout 30s
echo "smoke test finished OK"
