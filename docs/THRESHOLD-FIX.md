# PSI threshold fix — install and re-benchmark

## What changed

- **Old:** `LOAD_INT(psi_full) >= 25` required **25%** full stall (never fired at `full avg10=0.14`).
- **New:** `PSI_MEM_THRESHOLD_BPS=1` (0.01%) fixed-point compare; triggers on **some** or **full** avg10.
- **Zones fix:** only skip pause when **no** zone in the zonelist is below min watermarks (old logic skipped if *any* zone was ok).
- **Debug:** `/sys/kernel/debug/pressure_pause_activations` increments when coordination runs.

## Install rebuilt kernel

```bash
cd ~/EDU-OS4-KILL-LOOP
./scripts/install-pressurepause-kernel.sh
# reboot -> 6.8.12-pressurepause+
./scripts/verify-activation.sh
# (reads /sys/kernel/debug/pressure_pause_activations via sudo if needed)
```

## Re-benchmark (same params both kernels)

```bash
./bench-run.sh   # on pressurepause+ (after)
# reboot baseline
./bench-run.sh   # on 6.8.12-baseline (before)
```

Compare `results/bench-*` folders: pgmajfault delta, `vmstat.log` si/so, `pressure-samples.txt`.
