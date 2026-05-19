# PSI threshold fix — install and re-benchmark

## What changed

- **Old:** `LOAD_INT(psi_full) >= 25` compared the fixed-point **integer** part to 25, i.e. **25.00%** stall as shown in `/proc/pressure/memory` — not 0.25%. Benchmarks peaked near `full avg10=0.18` (0.18%), so the gate never fired.
- **New:** `psi_mem_avg10_exceeds_bps()` compares the same fixed-point avg10 as `/proc` using `PSI_MEM_THRESHOLD_BPS=1` (0.01%).
- **Signal:** gate uses memory PSI **`some`** avg10 only (rises before `full` under swap thrash).
- **Zones fix:** only skip pause when **no** zone in the zonelist is below min watermarks (old logic skipped if *any* zone was ok).
- **Debug:** `/sys/kernel/debug/pressure_pause_activations` (mount debugfs first):

| Field | Meaning |
|-------|---------|
| `activations` | coordination ran (wake kswapd + bounded wait) |
| `entered` | `do_try_to_free_pages` called the hook |
| `skip_psi_low` | PSI `some` avg10 below threshold |
| `skip_zones_ok` | no zone below min watermarks |
| `skip_no_reclaimable` | no reclaimable pages |
| `skip_cgroup` | cgroup reclaim path |
| `peak_psi_some_avg10` | max `some` avg10 seen at hook (since boot) |
| `peak_psi_full_avg10` | max `full` avg10 seen at hook (since boot) |

## Install rebuilt kernel

```bash
cd ~/EDU-OS4-KILL-LOOP
cd kernel/linux && make -j$(nproc)
./scripts/install-pressurepause-kernel.sh
# reboot -> 6.8.12-pressurepause+
sudo mount -t debugfs none /sys/kernel/debug   # if needed
./scripts/verify-activation.sh
```

## Re-benchmark (same params both kernels)

```bash
./bench-run.sh   # on pressurepause+ (after); captures pressure-pause-debugfs-*.txt
# reboot baseline
./bench-run.sh   # on 6.8.12-baseline (before)
```

Non-interactive matched run on patched kernel only:

```bash
BENCH_AUTO=1 BENCH_VM_WORKERS=8 BENCH_VM_BYTES_PCT=93 ./bench-run.sh
BENCH_AUTO=1 BENCH_VM_WORKERS=4 BENCH_VM_BYTES_PCT=85 ./bench-run.sh
```

Compare `results/bench-*`: `pressure-pause-debugfs-*.txt` (`activations` delta), `pgmajfault` delta, `vmstat` si/so, `pressure-samples.txt`.
