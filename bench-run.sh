#!/bin/bash
# Interactive PressurePause benchmark — baseline vs patched kernel.
# Run from repo root: ./bench-run.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
KR="$(uname -r)"

# --- kernel detection (same patterns as scripts/verify-pressurepause.sh) ---
run_type="unknown"
kernel_role="unknown"
if [[ "$KR" == *pressurepause* ]]; then
	run_type="after"
	kernel_role="patched"
elif [[ "$KR" == *baseline* ]]; then
	run_type="before"
	kernel_role="baseline"
else
	echo "warning: unrecognized kernel '$KR' (expected *baseline* or *pressurepause*)" >&2
	echo "         continuing with run_type=unknown, kernel_role=unknown" >&2
fi

need_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "error: required command not found: $1" >&2
		exit 1
	fi
}

need_cmd stress-ng
need_cmd vmstat

prompt() {
	local prompt_text="$1"
	local default="$2"
	local varname="$3"
	local input=""
	read -r -p "${prompt_text} [${default}]: " input || true
	if [[ -z "${input// }" ]]; then
		printf -v "$varname" '%s' "$default"
	else
		printf -v "$varname" '%s' "$input"
	fi
}

prompt_yn() {
	local prompt_text="$1"
	local default_yes="$2"
	local varname="$3"
	local hint="Y/n"
	[[ "$default_yes" == "no" ]] && hint="y/N"
	local input=""
	read -r -p "${prompt_text} [${hint}]: " input || true
	input="${input:-}"
	if [[ -z "$input" ]]; then
		if [[ "$default_yes" == "yes" ]]; then
			printf -v "$varname" '%s' "yes"
		else
			printf -v "$varname" '%s' "no"
		fi
		return
	fi
	case "${input,,}" in
	y | yes) printf -v "$varname" '%s' "yes" ;;
	n | no) printf -v "$varname" '%s' "no" ;;
	*)
		echo "  (unrecognized; using default)" >&2
		prompt_yn "$prompt_text" "$default_yes" "$varname"
		;;
	esac
}

snapshot_pgmajfault() {
	local dest="$1"
	if [[ -r /proc/vmstat ]]; then
		grep '^pgmajfault ' /proc/vmstat >"$dest"
	else
		echo "pgmajfault unavailable" >"$dest"
	fi
}

snapshot_pressure() {
	local dest="$1"
	if [[ -r /proc/pressure/memory ]]; then
		cat /proc/pressure/memory >"$dest"
	else
		echo "no PSI" >"$dest"
	fi
}

snapshot_free() {
	local dest="$1"
	free -h >"$dest"
}

pgmajfault_value() {
	awk '{print $2}' "$1" 2>/dev/null || echo "0"
}

echo "=== PressurePause benchmark ==="
echo "repo:   $ROOT"
echo "kernel: $KR"
echo "run_type=$run_type  kernel_role=$kernel_role"
echo ""

# --- interactive parameters ---
STRESS_TIMEOUT=""
VM_WORKERS=""
VM_BYTES_PCT=""
VMSTAT_INTERVAL=""
VMSTAT_DURATION=""
COLLECT_PSI=""
PSI_INTERVAL=""

prompt "stress-ng timeout (seconds)" "120" STRESS_TIMEOUT
prompt "stress-ng VM workers (--vm)" "4" VM_WORKERS
prompt "stress-ng vm-bytes percent" "85" VM_BYTES_PCT
prompt "vmstat sample interval (seconds)" "1" VMSTAT_INTERVAL
default_vmstat_duration=$((STRESS_TIMEOUT + 10))
prompt "vmstat total duration (seconds)" "$default_vmstat_duration" VMSTAT_DURATION
prompt_yn "Collect PSI samples during stress?" "yes" COLLECT_PSI
if [[ "$COLLECT_PSI" == "yes" ]]; then
	prompt "PSI sample interval (seconds)" "5" PSI_INTERVAL
fi

if ! [[ "$STRESS_TIMEOUT" =~ ^[0-9]+$ ]] ||
	! [[ "$VM_WORKERS" =~ ^[0-9]+$ ]] ||
	! [[ "$VM_BYTES_PCT" =~ ^[0-9]+$ ]] ||
	! [[ "$VMSTAT_INTERVAL" =~ ^[0-9]+$ ]] ||
	! [[ "$VMSTAT_DURATION" =~ ^[0-9]+$ ]]; then
	echo "error: numeric fields must be positive integers" >&2
	exit 1
fi
if [[ "$COLLECT_PSI" == "yes" ]] && ! [[ "$PSI_INTERVAL" =~ ^[0-9]+$ ]]; then
	echo "error: PSI interval must be a positive integer" >&2
	exit 1
fi

VMSTAT_COUNT=$((VMSTAT_DURATION / VMSTAT_INTERVAL))
if [[ "$VMSTAT_COUNT" -lt 1 ]]; then
	echo "error: vmstat duration must be >= sample interval" >&2
	exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/results/bench-${KR}-${STAMP}"
mkdir -p "$OUT"

echo ""
echo "--- planned run ---"
echo "  output:     $OUT"
echo "  stress-ng:  --vm ${VM_WORKERS} --vm-bytes ${VM_BYTES_PCT}% --timeout ${STRESS_TIMEOUT}s"
echo "  vmstat:     ${VMSTAT_INTERVAL} ${VMSTAT_COUNT}  (~${VMSTAT_DURATION}s) -> vmstat.txt"
if [[ "$COLLECT_PSI" == "yes" ]]; then
	echo "  PSI samples: every ${PSI_INTERVAL}s -> pressure-samples.txt"
fi
echo ""
read -r -p "Start benchmark? [Y/n]: " confirm || true
confirm="${confirm:-Y}"
if [[ "${confirm,,}" == "n" || "${confirm,,}" == "no" ]]; then
	echo "Aborted."
	exit 0
fi

{
	echo "run_type=${run_type}"
	echo "kernel_role=${kernel_role}"
	echo "kernel=${KR}"
	echo "date=$(date -Iseconds)"
	echo "host=$(hostname)"
	echo "uname=$(uname -a)"
	echo "stress_timeout_s=${STRESS_TIMEOUT}"
	echo "vm_workers=${VM_WORKERS}"
	echo "vm_bytes_pct=${VM_BYTES_PCT}"
	echo "vmstat_interval_s=${VMSTAT_INTERVAL}"
	echo "vmstat_duration_s=${VMSTAT_DURATION}"
	echo "vmstat_count=${VMSTAT_COUNT}"
	echo "collect_psi=${COLLECT_PSI}"
	[[ "$COLLECT_PSI" == "yes" ]] && echo "psi_interval_s=${PSI_INTERVAL}"
	echo "command=$0"
} >"$OUT/metadata.txt"

echo ""
echo "[1/4] Before snapshots..."
snapshot_pgmajfault "$OUT/vmstat-before.txt"
snapshot_pressure "$OUT/pressure-before.txt"
snapshot_free "$OUT/free-before.txt"

STRESS_MARKER="$OUT/.stress-running"
: >"$STRESS_MARKER"

pressure_sampler() {
	local marker="$1"
	while [[ -f "$marker" ]]; do
		{
			echo "=== $(date -Iseconds) ==="
			if [[ -r /proc/pressure/memory ]]; then
				cat /proc/pressure/memory
			else
				echo "no PSI"
			fi
		} >>"$OUT/pressure-samples.txt"
		sleep "$PSI_INTERVAL"
	done
}

VMSTAT_PID=""
PSI_PID=""

cleanup_background() {
	rm -f "$STRESS_MARKER"
	if [[ -n "${VMSTAT_PID:-}" ]] && kill -0 "$VMSTAT_PID" 2>/dev/null; then
		wait "$VMSTAT_PID" 2>/dev/null || true
	fi
	if [[ -n "${PSI_PID:-}" ]] && kill -0 "$PSI_PID" 2>/dev/null; then
		kill "$PSI_PID" 2>/dev/null || true
		wait "$PSI_PID" 2>/dev/null || true
	fi
}
trap cleanup_background EXIT

echo "[2/4] Starting vmstat (background)..."
vmstat "$VMSTAT_INTERVAL" "$VMSTAT_COUNT" >"$OUT/vmstat.txt" &
VMSTAT_PID=$!

if [[ "$COLLECT_PSI" == "yes" ]]; then
	echo "[2/4] Starting PSI sampler (background)..."
	: >"$OUT/pressure-samples.txt"
	pressure_sampler "$STRESS_MARKER" &
	PSI_PID=$!
fi

echo "[3/4] Running stress-ng (${STRESS_TIMEOUT}s)..."
set +e
stress-ng --vm "$VM_WORKERS" --vm-bytes "${VM_BYTES_PCT}%" --timeout "${STRESS_TIMEOUT}s" \
	2>&1 | tee "$OUT/stress-ng.txt"
stress_rc=${PIPESTATUS[0]}
set -e
rm -f "$STRESS_MARKER"

if [[ -n "${PSI_PID:-}" ]] && kill -0 "$PSI_PID" 2>/dev/null; then
	wait "$PSI_PID" 2>/dev/null || true
	PSI_PID=""
fi

echo "[4/4] After snapshots..."
snapshot_pgmajfault "$OUT/vmstat-after.txt"
snapshot_pressure "$OUT/pressure-after.txt"
snapshot_free "$OUT/free-after.txt"

if [[ -n "${VMSTAT_PID:-}" ]] && kill -0 "$VMSTAT_PID" 2>/dev/null; then
	echo "Waiting for vmstat to finish..."
	wait "$VMSTAT_PID" 2>/dev/null || true
fi
VMSTAT_PID=""
trap - EXIT

before_pf="$(pgmajfault_value "$OUT/vmstat-before.txt")"
after_pf="$(pgmajfault_value "$OUT/vmstat-after.txt")"
delta_pf=$((after_pf - before_pf))

echo ""
echo "=== benchmark complete ==="
echo "Results:  $OUT"
echo "pgmajfault: before=$before_pf  after=$after_pf  delta=+$delta_pf"
if [[ "$stress_rc" -ne 0 ]]; then
	echo "stress-ng exited with status $stress_rc (see stress-ng.txt)" >&2
fi
echo ""
case "$kernel_role" in
baseline)
	echo "Reminder: this run is BEFORE (baseline kernel)."
	echo "  Reboot to 6.8.12-pressurepause (or +) and run ./bench-run.sh again for AFTER."
	;;
patched)
	echo "Reminder: this run is AFTER (patched / pressurepause kernel)."
	echo "  Compare with a results/bench-*-baseline-* directory from the baseline boot."
	;;
*)
	echo "Reminder: run once on 6.8.12-baseline and once on 6.8.12-pressurepause for before/after."
	;;
esac

exit "$stress_rc"
