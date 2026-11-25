#!/usr/bin/env bash
# One command on a fresh CachyOS / Arch install:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Noras-pid/dotfiles/main/bootstrap.sh)
#
# Clones this repository and runs install.sh, which asks once for the passphrase
# that unlocks the encrypted settings under secrets/.
set -euo pipefail
REPO="${DOTFILES_REPO:-Noras-pid/dotfiles}"
DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

command -v pacman >/dev/null || { echo "needs Arch or CachyOS" >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo "run as your normal user, not root" >&2; exit 1; }

if ! command -v git >/dev/null; then
  echo "==> installing git"
  sudo pacman -Sy --needed --noconfirm git
fi

if [ -d "$DIR/.git" ]; then
  echo "==> updating $DIR"
  git -C "$DIR" pull --ff-only
else
  echo "==> cloning $REPO into $DIR"
  git clone --depth 1 "https://github.com/$REPO.git" "$DIR"
fi

exec "$DIR/install.sh" "$@"
