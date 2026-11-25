#!/usr/bin/env bash
# Root-level part of the restore. Called by ../install.sh, uses sudo.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")"

has_nvidia() { lspci 2>/dev/null | grep -qi 'nvidia'; }
has_ath10k() { lspci -k 2>/dev/null | grep -q 'ath10k_pci'; }
has_disk_d() { [ -e /dev/disk/by-uuid/44EE544CEE5437FE ]; }
unit() { sudo install -Dm644 "etc/systemd/system/$1" "/etc/systemd/system/$1"; }
dropin() { sudo install -Dm644 "etc/systemd/system/$1/$2" "/etc/systemd/system/$1/$2"; }

sudo install -Dm755 usr/local/bin/turbo-unlock /usr/local/bin/turbo-unlock
sudo install -Dm755 usr/local/sbin/gpu-clients-stop /usr/local/sbin/gpu-clients-stop
unit turbo-unlock.service
dropin var-cache.mount.d lazy-unmount.conf

echo "$USER ALL=(root) NOPASSWD: /usr/local/bin/turbo-unlock" | sudo tee /etc/sudoers.d/turbo-unlock >/dev/null
sudo chmod 440 /etc/sudoers.d/turbo-unlock
sudo visudo -cf /etc/sudoers.d/turbo-unlock >/dev/null || sudo rm -f /etc/sudoers.d/turbo-unlock

[ -d /etc/greetd ] && sudo install -Dm644 etc/greetd/config.toml /etc/greetd/config.toml

enable=(turbo-unlock.service)
if has_nvidia; then
  unit nvidia-unload-on-shutdown.service
  dropin nvidia-unload-on-shutdown.service.d 10-keep-dgpu-awake.conf
  unit gpu-clients-stop.service
  enable+=(nvidia-unload-on-shutdown.service gpu-clients-stop.service)
fi
if has_ath10k; then
  unit unload-wifi-on-shutdown.service
  enable+=(unload-wifi-on-shutdown.service)
fi
if has_disk_d; then
  unit ntfs-dirty-fix-d.service
  dropin run-media-noras-44EE544CEE5437FE.mount.d 90-shutdown-order.conf
  enable+=(ntfs-dirty-fix-d.service)
fi
sudo systemctl daemon-reload
sudo systemctl enable "${enable[@]}"

while read -r u; do
  [ -n "$u" ] && sudo systemctl enable "$u" 2>&1 | tail -1
done < ../packages/services-system.txt
