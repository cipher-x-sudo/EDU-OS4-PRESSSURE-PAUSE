#!/bin/bash
# Verify PressurePause activates after PSI threshold fix (run on pressurepause kernel).
set -euo pipefail

KR="$(uname -r)"
DBG="/sys/kernel/debug/pressure_pause_activations"

if [[ "$KR" != *pressurepause* ]]; then
	echo "error: boot 6.8.12-pressurepause+ first (got $KR)" >&2
	exit 1
fi

if [[ ! -r "$DBG" ]]; then
	echo "error: $DBG missing — install rebuilt kernel and reboot:" >&2
	echo "  cd kernel/linux && sudo make modules_install install && sudo update-grub" >&2
	exit 1
fi

before=$(cat "$DBG")
echo "activations before stress: $before"
echo "running stress-ng 60s ..."
stress-ng --vm 4 --vm-bytes 85% --timeout 60s
after=$(cat "$DBG")
echo "activations after stress:  $after"
delta=$((after - before))
echo "delta: $delta"
if [[ "$delta" -gt 0 ]]; then
	echo "OK: PressurePause ran during stress"
	exit 0
fi
echo "warning: counter did not increase (PSI may still be below 10 bps or no direct reclaim)" >&2
exit 1
