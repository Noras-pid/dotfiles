#!/usr/bin/env bash
# One command on a fresh CachyOS / Arch install:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Noras-pid/dotfiles/main/bootstrap.sh)
#
# Installs git and the GitHub CLI, signs in to GitHub (the dotfiles repository is
# private, so the clone needs it), clones the repository and runs install.sh.
set -euo pipefail
REPO="${DOTFILES_REPO:-Noras-pid/dotfiles}"
DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

command -v pacman >/dev/null || { echo "needs Arch or CachyOS" >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo "run as your normal user, not root" >&2; exit 1; }

need=()
command -v git >/dev/null || need+=(git)
command -v gh >/dev/null || need+=(github-cli)
if [ "${#need[@]}" -gt 0 ]; then
  echo "==> installing ${need[*]}"
  sudo pacman -Sy --needed --noconfirm "${need[@]}"
fi

if ! gh auth status >/dev/null 2>&1; then
  if [ -n "${GH_TOKEN:-}" ]; then
    printf '%s\n' "$GH_TOKEN" | gh auth login --hostname github.com --with-token
  else
    echo "==> sign in to the GitHub account that owns $REPO"
    echo "    a one-time code is shown; open github.com/login/device on any device and enter it"
    gh auth login --hostname github.com --git-protocol https --web --scopes repo
  fi
fi
gh auth setup-git

if [ -d "$DIR/.git" ]; then
  echo "==> updating $DIR"
  git -C "$DIR" pull --ff-only
else
  echo "==> cloning $REPO into $DIR"
  git clone "https://github.com/$REPO.git" "$DIR"
fi

exec "$DIR/install.sh" "$@"
