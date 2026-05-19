#!/bin/bash
# Verify PressurePause activates after PSI threshold fix (run on pressurepause kernel).
set -euo pipefail

KR="$(uname -r)"
DBG="/sys/kernel/debug/pressure_pause_activations"

if [[ ! -d /sys/kernel/debug ]] && [[ $(id -u) -ne 0 ]]; then
	if command -v sudo >/dev/null; then
		sudo mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
	fi
fi

if [[ "$KR" != *pressurepause* ]]; then
	echo "error: boot 6.8.12-pressurepause+ first (got $KR)" >&2
	exit 1
fi

read_count() {
	if [[ -r "$DBG" ]]; then
		cat "$DBG"
	elif command -v sudo >/dev/null && sudo test -f "$DBG" 2>/dev/null; then
		sudo cat "$DBG"
	else
		return 1
	fi
}

if ! read_count >/dev/null 2>&1; then
	echo "error: $DBG not found — install rebuilt kernel (#8+) and reboot:" >&2
	echo "  ./scripts/install-pressurepause-kernel.sh" >&2
	echo "If you already rebooted, debugfs may need root: sudo cat $DBG" >&2
	exit 1
fi

show_stats() {
	echo "--- pressure_pause debugfs stats ---"
	read_count | sed 's/^/  /'
}

show_stats
before=$(read_count | awk '/^activations/{print $2}')
entered_before=$(read_count | awk '/^entered/{print $2}')
echo "activations before stress: ${before:-0} (entered=${entered_before:-0})"
echo "running stress-ng 60s ..."
stress-ng --vm 4 --vm-bytes 85% --timeout 60s
show_stats
after=$(read_count | awk '/^activations/{print $2}')
entered_after=$(read_count | awk '/^entered/{print $2}')
echo "activations after stress:  ${after:-0} (entered=${entered_after:-0})"
delta=$((after - before))
entered_delta=$((entered_after - entered_before))
echo "activation delta: $delta | do_try_to_free_pages entries: $entered_delta"
if [[ "$delta" -gt 0 ]]; then
	echo "OK: PressurePause ran during stress"
	exit 0
fi
if [[ "$entered_delta" -gt 0 ]]; then
	echo "note: direct reclaim ran but guards blocked pause — see skip_* lines above" >&2
else
	echo "note: little or no direct reclaim during stress (try --vm-bytes 90% or more workers)" >&2
fi
exit 1
