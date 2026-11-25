#!/usr/bin/env bash
# Restore this whole setup on a fresh CachyOS / Arch install.
#   ./install.sh              everything
#   ./install.sh --no-system  skip /etc, services and drivers tweaks
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")"
REPO="$PWD"
SYSTEM=1; [ "${1:-}" = "--no-system" ] && SYSTEM=0

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
[ "$(id -u)" -ne 0 ] || { echo "run as your normal user, not root"; exit 1; }
command -v pacman >/dev/null || { echo "needs Arch or CachyOS"; exit 1; }
sudo -v || exit 1

# Everything under secrets/ is one gpg symmetric archive per tool. The passphrase is
# asked for once, when the first bundle is opened; DOTFILES_PASSPHRASE skips the prompt.
DOTFILES_PASS="${DOTFILES_PASSPHRASE:-}"
has_bundle() { [ -f "secrets/$1.tar.gz.gpg" ]; }
open_bundle() {   # open_bundle <name>  ->  prints the path of the decrypted archive
  local name="$1" src="secrets/$1.tar.gz.gpg" out try
  [ -f "$src" ] || return 1
  out="$(mktemp)"
  for try in 1 2 3 4; do
    if [ -n "$DOTFILES_PASS" ] &&
       gpg --batch --quiet --pinentry-mode loopback --passphrase "$DOTFILES_PASS" -o "$out" --yes -d "$src" 2>/dev/null; then
      printf '%s\n' "$out"; return 0
    fi
    [ -n "$DOTFILES_PASS" ] && echo "wrong passphrase" >&2
    [ -t 0 ] || [ -r /dev/tty ] || break
    read -rsp "passphrase for the encrypted settings: " DOTFILES_PASS < /dev/tty; echo >&2
    [ -n "$DOTFILES_PASS" ] || break
  done
  rm -f "$out"; DOTFILES_PASS=""; return 1
}

say "base tools"
sudo pacman -Syu --needed --noconfirm git base-devel rsync flatpak curl jq sqlite

say "yay"
if ! command -v yay >/dev/null; then
  tmp=$(mktemp -d)
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" &&
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

say "pacman packages"
if ! sudo pacman -S --needed --noconfirm - < packages/pacman.txt; then
  echo "batch failed, retrying one by one"
  while read -r p; do
    [ -n "$p" ] && { sudo pacman -S --needed --noconfirm "$p" || echo "$p" >> /tmp/dotfiles-failed.txt; }
  done < packages/pacman.txt
fi

say "AUR packages"
while read -r p; do
  [ -n "$p" ] && { yay -S --needed --noconfirm "$p" || echo "$p" >> /tmp/dotfiles-failed.txt; }
done < packages/aur.txt

say "flatpak apps"
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
while read -r a; do
  [ -n "$a" ] && { sudo flatpak install -y --noninteractive flathub "$a" || echo "$a" >> /tmp/dotfiles-failed.txt; }
done < packages/flatpak.txt

say "apps: Steam, Discord, Thunderbird, Claude Code, Cursor"
# steam needs the multilib repo (on by default on CachyOS)
for p in steam discord thunderbird; do
  sudo pacman -S --needed --noconfirm "$p" || echo "$p" >> /tmp/dotfiles-failed.txt
done
if ! command -v claude >/dev/null && [ ! -x "$HOME/.local/bin/claude" ]; then
  curl -fsSL https://claude.ai/install.sh | bash || echo "claude-code (claude.ai/install.sh)" >> /tmp/dotfiles-failed.txt
fi
install_cursor() {  # the official AppImage, unpacked the way home/.local/share/applications/cursor.desktop expects
  local opt="$HOME/.local/opt" url ver tmp
  [ -x "$opt/cursor/usr/share/cursor/cursor" ] && return 0
  url="$(curl -fsSL 'https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable' | jq -r '.downloadUrl // empty')"
  [ -n "$url" ] || return 1
  ver="$(basename "$url" | sed -E 's/^Cursor-([0-9.]+)-.*/\1/')"
  tmp="$(mktemp -d)"
  curl -fL -# --retry 3 -o "$tmp/cursor.AppImage" "$url" && chmod +x "$tmp/cursor.AppImage" &&
    (cd "$tmp" && ./cursor.AppImage --appimage-extract >/dev/null) &&
    [ -x "$tmp/squashfs-root/usr/share/cursor/cursor" ] || { rm -rf "$tmp"; return 1; }
  mkdir -p "$opt/cursor-$ver" "$HOME/.local/bin"
  rm -rf "$opt/cursor-$ver/squashfs-root"
  mv "$tmp/squashfs-root" "$opt/cursor-$ver/squashfs-root"
  ln -sfn "$opt/cursor-$ver/squashfs-root" "$opt/cursor"
  ln -sfn "$opt/cursor/usr/share/cursor/bin/cursor" "$HOME/.local/bin/cursor"
  rm -rf "$tmp"
}
install_cursor || echo "cursor (cursor.com AppImage)" >> /tmp/dotfiles-failed.txt

say "AnixApp"
install_anixapp() {  # the AppImage from the project's GitHub releases, where anixapp.desktop expects it
  local dst="$HOME/.local/bin/AnixApp.AppImage" url
  [ -x "$dst" ] && return 0
  url="$(curl -fsSL https://api.github.com/repos/Anixapp-Community/anixapp/releases/latest |
         jq -r '[.assets[] | select(.name | endswith(".AppImage"))][0].browser_download_url // empty')"
  [ -n "$url" ] || return 1
  mkdir -p "$HOME/.local/bin"
  curl -fL -# --retry 3 -o "$dst.part" "$url" && chmod +x "$dst.part" && mv "$dst.part" "$dst" || { rm -f "$dst.part"; return 1; }
}
install_anixapp || echo "anixapp (github.com/Anixapp-Community/anixapp AppImage)" >> /tmp/dotfiles-failed.txt

say "SLSsteam"
# Not in the AUR: the Arch package comes from the project's GitHub releases. Its settings
# (home/.config/SLSsteam) and the Steam launcher that loads it (home/.local/share/applications/
# steam.desktop, LD_AUDIT=/usr/lib/libSLSsteam.so) arrive with the config files below.
install_slssteam() {
  [ -f /usr/lib/libSLSsteam.so ] && return 0
  local tmp; tmp="$(mktemp -d)"
  curl -fL -# --retry 3 -o "$tmp/slssteam.pkg.tar.zst" \
    https://github.com/AceSLS/SLSsteam/releases/latest/download/SLSsteam-Arch-release-x86_64.pkg.tar.zst &&
    sudo pacman -U --needed --noconfirm "$tmp/slssteam.pkg.tar.zst"
  local rc=$?; rm -rf "$tmp"; return $rc
}
install_slssteam || echo "slssteam (github.com/AceSLS/SLSsteam release package)" >> /tmp/dotfiles-failed.txt

say "config files into $HOME"
backup="$HOME/.dotfiles-backup/$(date +%F-%H%M%S)"
mkdir -p "$backup"
rsync -a --backup --backup-dir="$backup" home/ "$HOME/"
# Thunderbird accounts from secrets/thunderbird.tar.gz.gpg (settings and saved logins).
# Mail itself is fetched again from the servers on first start.
TB="$HOME/.config/thunderbird"
if has_bundle thunderbird; then
  if [ -f "$TB/profiles.ini" ]; then
    echo "thunderbird: a profile already exists, left alone"
  else
    say "Thunderbird accounts"
    if tgz="$(open_bundle thunderbird)" && mkdir -p "$TB" && tar -C "$TB" -xzf "$tgz" && chmod -R go-rwx "$TB"; then
      rm -f "$tgz"
      echo "thunderbird: accounts restored"
    else
      echo "thunderbird accounts (secrets/thunderbird.tar.gz.gpg)" >> /tmp/dotfiles-failed.txt
    fi
  fi
fi

AX="$HOME/.config/anixapp"
if has_bundle anixapp; then
  if [ -e "$AX" ]; then
    echo "anixapp: settings already exist, left alone"
  else
    say "AnixApp settings"
    if tgz="$(open_bundle anixapp)" && mkdir -p "$AX" && tar -C "$AX" -xzf "$tgz" && chmod -R go-rwx "$AX"; then
      rm -f "$tgz"
      echo "anixapp: login and settings restored"
    else
      echo "anixapp settings (secrets/anixapp.tar.gz.gpg)" >> /tmp/dotfiles-failed.txt
    fi
  fi
fi

# opencode (the package comes from packages/aur.txt): config, keys and stored credentials.
if has_bundle opencode; then
  if [ -e "$HOME/.config/opencode" ]; then
    echo "opencode: config already exists, left alone"
  else
    say "opencode settings and keys"
    stage="$(mktemp -d)"; oc_ok=1
    tgz="$(open_bundle opencode)" && tar -C "$stage" -xzf "$tgz" || oc_ok=0
    rm -f "$tgz"
    if [ "$oc_ok" -eq 1 ]; then
      mkdir -p "$HOME/.config/opencode" "$HOME/.local/state/opencode"
      cp -a "$stage/config/." "$HOME/.config/opencode/" && chmod -R go-rwx "$HOME/.config/opencode"
      [ -f "$stage/state/model.json" ] && cp "$stage/state/model.json" "$HOME/.local/state/opencode/"
      if [ -s "$stage/credentials.sql" ]; then
        db="$HOME/.local/share/opencode/opencode.db"
        # the database and its tables are created by opencode itself on first use
        [ -f "$db" ] || opencode auth list >/dev/null 2>&1 || true
        if [ -f "$db" ] && sqlite3 "$db" < "$stage/credentials.sql"; then
          echo "opencode: $(grep -c '^INSERT' "$stage/credentials.sql") stored credentials restored"
        else
          # keep the keys so they can be imported once opencode has created its database
          mkdir -p "$HOME/.local/share/opencode"
          install -m 600 "$stage/credentials.sql" "$HOME/.local/share/opencode/credentials.sql"
          echo "opencode: run 'opencode auth list' once, then: sqlite3 ~/.local/share/opencode/opencode.db < ~/.local/share/opencode/credentials.sql"
          oc_ok=0
        fi
      fi
    fi
    rm -rf "$stage"
    [ "$oc_ok" -eq 1 ] && echo "opencode: settings restored" || echo "opencode credentials (secrets/opencode.tar.gz.gpg)" >> /tmp/dotfiles-failed.txt
  fi
fi

# git and the GitHub CLI: config, hosts and the token (gh stores it in the keyring again).
if has_bundle github; then
  say "git and GitHub CLI"
  stage="$(mktemp -d)"
  if tgz="$(open_bundle github)" && tar -C "$stage" -xzf "$tgz"; then
    rm -f "$tgz"
    [ -f "$stage/gitconfig" ] && [ ! -f "$HOME/.gitconfig" ] && cp -a "$stage/gitconfig" "$HOME/.gitconfig"
    if [ -d "$stage/gh" ]; then
      mkdir -p "$HOME/.config/gh"
      for f in "$stage"/gh/*; do [ -e "$HOME/.config/gh/$(basename "$f")" ] || cp -a "$f" "$HOME/.config/gh/"; done
      chmod -R go-rwx "$HOME/.config/gh"
    fi
    if [ -s "$stage/gh-token" ] && command -v gh >/dev/null; then
      if gh auth status >/dev/null 2>&1; then
        echo "gh: already signed in, token left alone"
      elif gh auth login --with-token < "$stage/gh-token" 2>/dev/null; then
        echo "gh: signed in as $(gh api user --jq .login 2>/dev/null)"
      else
        echo "gh token (secrets/github.tar.gz.gpg)" >> /tmp/dotfiles-failed.txt
      fi
    fi
  else
    echo "github settings (secrets/github.tar.gz.gpg)" >> /tmp/dotfiles-failed.txt
  fi
  rm -rf "$stage"
fi

# Claude Code: instructions, settings, skills, project memory, login and the plugin list.
# Claude Code re-downloads the plugins themselves from the marketplaces on first start.
if has_bundle claude-code; then
  if [ -e "$HOME/.claude/CLAUDE.md" ]; then
    echo "claude code: config already exists, left alone"
  else
    say "Claude Code settings"
    stage="$(mktemp -d)"
    if tgz="$(open_bundle claude-code)" && tar -C "$stage" -xzf "$tgz"; then
      rm -f "$tgz"
      mkdir -p "$HOME/.claude"
      cp -a "$stage/claude/." "$HOME/.claude/"
      [ -f "$stage/claude.json" ] && [ ! -f "$HOME/.claude.json" ] && cp -a "$stage/claude.json" "$HOME/.claude.json"
      chmod 600 "$HOME/.claude/.credentials.json" "$HOME/.claude.json" 2>/dev/null
      echo "claude code: $(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l) skills, $(find "$HOME/.claude/projects" -maxdepth 2 -name memory -type d 2>/dev/null | wc -l) project memories"
    else
      echo "claude code settings (secrets/claude-code.tar.gz.gpg)" >> /tmp/dotfiles-failed.txt
    fi
    rm -rf "$stage"
  fi
fi

# Cursor: editor settings, snippets, MCP servers, CLI config, skills and the extensions.
# The Cursor account itself is signed in again by hand.
if has_bundle cursor; then
  if [ -e "$HOME/.config/Cursor/User/settings.json" ]; then
    echo "cursor: settings already exist, left alone"
  else
    say "Cursor settings"
    stage="$(mktemp -d)"
    if tgz="$(open_bundle cursor)" && tar -C "$stage" -xzf "$tgz"; then
      rm -f "$tgz"
      mkdir -p "$HOME/.config/Cursor/User" "$HOME/.cursor"
      [ -d "$stage/user" ] && cp -a "$stage/user/." "$HOME/.config/Cursor/User/"
      [ -d "$stage/cursor" ] && cp -a "$stage/cursor/." "$HOME/.cursor/"
      if [ -s "$stage/extensions.txt" ] && [ -x "$HOME/.local/bin/cursor" ]; then
        while read -r ext; do
          [ -n "$ext" ] && { "$HOME/.local/bin/cursor" --install-extension "$ext" >/dev/null 2>&1 ||
            echo "cursor extension $ext" >> /tmp/dotfiles-failed.txt; }
        done < "$stage/extensions.txt"
      fi
      echo "cursor: settings restored"
    else
      echo "cursor settings (secrets/cursor.tar.gz.gpg)" >> /tmp/dotfiles-failed.txt
    fi
    rm -rf "$stage"
  fi
fi

if [ "$USER" != "noras" ]; then
  grep -rIl '/home/noras' "$HOME/.config" "$HOME/.local/bin" "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile" \
    "$HOME/.gitconfig" "$HOME/.claude/CLAUDE.md" 2>/dev/null |
    xargs -r sed -i "s|/home/noras|$HOME|g"
fi
rmdir "$backup" 2>/dev/null || true
chmod 700 "$HOME/.config/orrery/shell.json" 2>/dev/null || true
[ -d "$HOME/.local/share/icons" ] && gtk-update-icon-cache -q "$HOME/.local/share/icons/hicolor" 2>/dev/null
fc-cache -f >/dev/null 2>&1

say "user services"
systemctl --user daemon-reload
systemctl --user enable nightlight-auto.timer orrery-dark-default.service 2>&1 | tail -2

if [ "$SYSTEM" -eq 1 ]; then
  say "system files and services"
  bash system/install.sh
fi

say "default shell"
[ "$(basename "$SHELL")" = zsh ] || chsh -s /usr/bin/zsh

if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v orrery-theme >/dev/null; then
  say "theme"
  orrery-theme set rei || true
fi

say "done"
[ -f /tmp/dotfiles-failed.txt ] && { echo "failed packages:"; cat /tmp/dotfiles-failed.txt; }
echo "reboot, log in, and the theme renders on first start. old files are in $HOME/.dotfiles-backup"
