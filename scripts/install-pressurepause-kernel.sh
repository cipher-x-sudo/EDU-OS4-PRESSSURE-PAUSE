#!/bin/bash
# Install 6.8.12-pressurepause after a successful build (requires sudo).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/kernel/linux"

if [[ ! -f arch/x86/boot/bzImage ]]; then
	echo "error: build bzImage first (make -j2 LOCALVERSION=-pressurepause)" >&2
	exit 1
fi

ver="$(make -s kernelrelease)"
echo "Installing kernel $ver ..."
sudo make modules_install install
sudo update-grub
echo "Done. Reboot and select Advanced options -> Linux $ver"
ls -la /boot/vmlinuz*"${ver}"* 2>/dev/null || ls -la /boot/vmlinuz*pressurepause* 2>/dev/null
echo "After reboot: ./scripts/verify-activation.sh  (debugfs counter must increase under stress)"
