#!/usr/bin/env bash
# Copy the live config from $HOME into ./home and refresh the package lists.
# Run it before every commit: ./sync.sh && git add -A && git commit
set -euo pipefail
cd "$(dirname "$0")"
H="$HOME"

CONFIG_DIRS=(alacritty ambxst btop caelestia cava easyeffects fastfetch fish fuzzel gtk-3.0 gtk-4.0 htop hypr
  kitty MangoHud menus micro nvtop nwg-displays orrery pulse qt5ct qt6ct qtengine session spicetify systemd
  Thunar uwsm xfce4 xsettingsd zed faugus-launcher quickshell wlogout noctalia hyprquickframe qView swash SLSsteam)
CONFIG_FILES=(starship.toml mimeapps.list gamemode.ini kdeglobals user-dirs.dirs user-dirs.locale pavucontrol.ini QtProject.conf)
HOME_FILES=(.zshrc .bashrc .profile)
SHARE_DIRS=(fonts applications icons/Bibata-Modern-Ice)
BIN_SKIP=(AnixApp.AppImage codex cursor)

EXCL=(--exclude='*.bak' --exclude='*.bak-*' --exclude='*.before-orrery-shortcuts' --exclude='*.fancy-*'
  --exclude='*.minimal-*' --exclude='__pycache__' --exclude='*.log' --exclude='mimeinfo.cache'
  --exclude='*.before-install' --exclude='wine-extension-*.desktop' --exclude='.uuid')

put() { # put <relative path under $HOME>
  local rel="$1" src="$H/$1"
  [ -e "$src" ] || { echo "skip (missing): $rel"; return; }
  mkdir -p "home/$(dirname "$rel")"
  if [ -d "$src" ]; then
    local mode=-aL; [[ "$rel" == */icons/* ]] && mode=-a
    rsync "$mode" --delete --delete-excluded "${EXCL[@]}" "$src/" "home/$rel/"
  else
    rsync -aL "$src" "home/$rel"
  fi
}

for d in "${CONFIG_DIRS[@]}"; do put ".config/$d"; done
for f in "${CONFIG_FILES[@]}"; do put ".config/$f"; done
for f in "${HOME_FILES[@]}"; do put "$f"; done
for d in "${SHARE_DIRS[@]}"; do put ".local/share/$d"; done
put Pictures/Wallpapers

rm -rf home/.config/orrery/current home/.config/hypr/scheme/current.*
# ~/.local/bin: only the scripts kept here. Installed tools (links into uv, AppImages,
# CLIs, compiled binaries) are restored by their own installers, not from this repo.
rm -rf home/.local/bin; mkdir -p home/.local/bin
for f in "$H"/.local/bin/*; do
  n="$(basename "$f")"
  [ -f "$f" ] || continue
  case "$n" in *.bak|*.bak-*|*.pre-*|*.rose[0-9]*|*.log|*.fancy-*|*.minimal-*|*.before-orrery-shortcuts) continue ;; esac
  for s in "${BIN_SKIP[@]}"; do [ "$n" = "$s" ] && continue 2; done
  if [ -L "$f" ]; then case "$(realpath "$f")" in "$H"/.local/src/Orrery-dotfiles/*) ;; *) continue ;; esac; fi
  [ "$(stat -Lc %s "$f")" -le 1048576 ] || continue
  grep -Iq . "$f" || continue
  install -m "$(stat -Lc %a "$f")" "$f" "home/.local/bin/$n"
done

# packages/exclude.txt: names kept out of the lists even while installed here
drop() { grep -vxFf packages/exclude.txt || true; }
pacman -Qqen | drop | sort > packages/pacman.txt
pacman -Qqem | grep -v '^yay-bin$' | drop | sort > packages/aur.txt
flatpak list --app --columns=application,origin 2>/dev/null | awk '$2=="flathub"{print $1}' | drop > packages/flatpak.txt || true

# Thunderbird accounts: settings, saved logins and the key that unlocks them, address book,
# filters. Not the downloaded mail. Stored as is: this repo is private and must stay private.
TB="$H/.config/thunderbird"
if [ -f "$TB/profiles.ini" ]; then
  pgrep -x thunderbird >/dev/null && echo "note: Thunderbird is running, its files may be mid-write"
  mkdir -p secrets
  list="$(mktemp)"
  (cd "$TB" && find . -type f \
      \( -path './*/ImapMail/*' -o -path './*/Mail/*' \) ! -name 'msgFilterRules.dat' -prune -o -type f \
      ! -name 'global-messages-db.sqlite*' ! -name '*.msf' ! -name 'lock' ! -name '.parentlock' \
      ! -path './*/cache2/*' ! -path './*/startupCache/*' ! -path './*/storage/*' ! -path './*/crashes/*' \
      ! -path './*/datareporting/*' ! -path './*/minidumps/*' ! -path './*/saved-telemetry-pings/*' \
      ! -path './*/security_state/*' ! -path './*/shader-cache/*' ! -path './Crash Reports/*' \
      ! -name '*.sqlite-wal' ! -name '*.sqlite-shm' ! -name 'favicons.sqlite' -print | LC_ALL=C sort > "$list")
  tar -C "$TB" --no-recursion -T "$list" --owner=0 --group=0 --numeric-owner -cf - | gzip -n > secrets/thunderbird.tar.gz
  echo "thunderbird: $(wc -l < "$list") files, $(du -h secrets/thunderbird.tar.gz | cut -f1)"
  rm -f "$list"
fi

# AnixApp: login, cookies, settings, filters and the download queue; no caches.
# Stored as is, like the Thunderbird profile.
AX="$H/.config/anixapp"
if [ -d "$AX" ]; then
  pgrep -xi anixapp >/dev/null && echo "note: AnixApp is running, its files may be mid-write"
  mkdir -p secrets
  list="$(mktemp)"
  (cd "$AX" && find . -type f \
      ! -path './Cache/*' ! -path './Code Cache/*' ! -path './GPUCache/*' ! -path './GPUPersistentCache/*' \
      ! -path './DawnWebGPUCache/*' ! -path './DawnGraphiteCache/*' ! -path './diagnostics/*' \
      ! -path './Crashpad/*' ! -path './blob_storage/*' ! -path './Partitions/*/Cache/*' \
      ! -path './Partitions/*/Code Cache/*' ! -path './Partitions/*/GPUCache/*' \
      ! -path './Shared Dictionary/*' ! -path './VideoDecodeStats/*' ! -name '*-journal' ! -name 'LOCK' ! -name '*.log' \
      -print | LC_ALL=C sort > "$list")
  tar -C "$AX" --no-recursion -T "$list" --owner=0 --group=0 --numeric-owner -cf - | gzip -n > secrets/anixapp.tar.gz
  echo "anixapp: $(wc -l < "$list") files, $(du -h secrets/anixapp.tar.gz | cut -f1)"
  rm -f "$list"
fi

# opencode: config with provider keys, key files, the service password, the chosen model,
# and the credentials stored in its database (as SQL, without the 50 MB of sessions).
OC="$H/.config/opencode"
if [ -d "$OC" ]; then
  mkdir -p secrets
  stage="$(mktemp -d)"
  mkdir -p "$stage/config" "$stage/state"
  rsync -a --exclude='*.bak-*' --exclude='*.bak' --exclude='node_modules' "$OC/" "$stage/config/"
  [ -f "$H/.local/state/opencode/model.json" ] && cp "$H/.local/state/opencode/model.json" "$stage/state/"
  db="$H/.local/share/opencode/opencode.db"
  if [ -f "$db" ] && command -v sqlite3 >/dev/null; then
    sqlite3 -readonly "$db" ".mode insert credential" "select * from credential order by id" |
      sed 's/^INSERT INTO /INSERT OR REPLACE INTO /' > "$stage/credentials.sql"
  fi
  (cd "$stage" && find . -type f | LC_ALL=C sort |
     tar --no-recursion -T - --owner=0 --group=0 --numeric-owner --mtime='2000-01-01' -cf - | gzip -n) > secrets/opencode.tar.gz
  echo "opencode: $(grep -c '^INSERT' "$stage/credentials.sql" 2>/dev/null || echo 0) stored credentials, $(du -h secrets/opencode.tar.gz | cut -f1)"
  rm -rf "$stage"
fi

# Claude Code: instructions, settings, skills, the memory of every project, the login,
# and the list of installed plugins (the plugins themselves are re-downloaded).
if [ -d "$H/.claude" ]; then
  mkdir -p secrets
  stage="$(mktemp -d)"; mkdir -p "$stage/claude"
  for f in CLAUDE.md settings.json .credentials.json; do
    [ -f "$H/.claude/$f" ] && cp -a "$H/.claude/$f" "$stage/claude/"
  done
  for d in skills agents commands; do
    [ -d "$H/.claude/$d" ] && rsync -aL --exclude='__pycache__' --exclude='*.pyc' "$H/.claude/$d/" "$stage/claude/$d/"
  done
  for f in installed_plugins.json known_marketplaces.json; do
    [ -f "$H/.claude/plugins/$f" ] && { mkdir -p "$stage/claude/plugins"; cp -a "$H/.claude/plugins/$f" "$stage/claude/plugins/"; }
  done
  # every project's memory/, under the same project key
  if [ -d "$H/.claude/projects" ]; then
    for p in "$H/.claude/projects"/*/memory; do
      [ -d "$p" ] || continue
      key="$(basename "$(dirname "$p")")"
      mkdir -p "$stage/claude/projects/$key"
      rsync -a "$p/" "$stage/claude/projects/$key/memory/"
    done
  fi
  # ~/.claude.json without the caches and the recorded prompt history
  [ -f "$H/.claude.json" ] && jq 'with_entries(select(.key | startswith("cached") or startswith("additionalModel") or endswith("Cache") | not))
      | if .projects then .projects |= with_entries(.value |= del(.history)) else . end' \
      "$H/.claude.json" > "$stage/claude.json" 2>/dev/null
  (cd "$stage" && find . -type f | LC_ALL=C sort |
     tar --no-recursion -T - --owner=0 --group=0 --numeric-owner --mtime='2000-01-01' -cf - | gzip -n) > secrets/claude-code.tar.gz
  echo "claude code: $(find "$stage" -type f | wc -l) files, $(du -h secrets/claude-code.tar.gz | cut -f1)"
  rm -rf "$stage"
fi

# Cursor: editor settings, snippets, MCP servers, CLI config, skills and the extension list.
# Not the 4.2 GB of workspace state, so the Cursor account is signed in again.
if [ -d "$H/.config/Cursor" ] || [ -d "$H/.cursor" ]; then
  mkdir -p secrets
  stage="$(mktemp -d)"; mkdir -p "$stage/user" "$stage/cursor"
  for f in settings.json keybindings.json; do
    [ -f "$H/.config/Cursor/User/$f" ] && cp -a "$H/.config/Cursor/User/$f" "$stage/user/"
  done
  [ -d "$H/.config/Cursor/User/snippets" ] && rsync -a "$H/.config/Cursor/User/snippets/" "$stage/user/snippets/"
  for f in mcp.json cli-config.json argv.json; do
    [ -f "$H/.cursor/$f" ] && cp -a "$H/.cursor/$f" "$stage/cursor/"
  done
  for d in skills skills-cursor; do
    [ -d "$H/.cursor/$d" ] && rsync -aL --exclude='__pycache__' --exclude='*.pyc' "$H/.cursor/$d/" "$stage/cursor/$d/"
  done
  # ids only: install.sh reinstalls them with `cursor --install-extension`
  if [ -f "$H/.cursor/extensions/extensions.json" ]; then
    jq -r '.[] | "\(.identifier.id)"' "$H/.cursor/extensions/extensions.json" 2>/dev/null | LC_ALL=C sort -u > "$stage/extensions.txt" || true
  fi
  (cd "$stage" && find . -type f | LC_ALL=C sort |
     tar --no-recursion -T - --owner=0 --group=0 --numeric-owner --mtime='2000-01-01' -cf - | gzip -n) > secrets/cursor.tar.gz
  echo "cursor: $(find "$stage" -type f | wc -l) files, $(wc -l < "$stage/extensions.txt" 2>/dev/null || echo 0) extensions"
  rm -rf "$stage"
fi

# git and the GitHub CLI, including the token the CLI keeps in the system keyring.
if [ -f "$H/.gitconfig" ] || [ -d "$H/.config/gh" ]; then
  mkdir -p secrets
  stage="$(mktemp -d)"
  [ -f "$H/.gitconfig" ] && cp -a "$H/.gitconfig" "$stage/gitconfig"
  if [ -d "$H/.config/gh" ]; then
    mkdir -p "$stage/gh"
    for f in config.yml hosts.yml; do [ -f "$H/.config/gh/$f" ] && cp -a "$H/.config/gh/$f" "$stage/gh/"; done
  fi
  command -v gh >/dev/null && gh auth token > "$stage/gh-token" 2>/dev/null
  [ -s "$stage/gh-token" ] || rm -f "$stage/gh-token"
  (cd "$stage" && find . -type f | LC_ALL=C sort |
     tar --no-recursion -T - --owner=0 --group=0 --numeric-owner --mtime='2000-01-01' -cf - | gzip -n) > secrets/github.tar.gz
  echo "github: $(find "$stage" -type f | wc -l) files$([ -f "$stage/gh-token" ] && echo ', token included')"
  rm -rf "$stage"
fi

install -m 755 /usr/local/bin/turbo-unlock system/usr/local/bin/turbo-unlock 2>/dev/null || true

# Everything under secrets/ is encrypted with the passphrase in
# ~/.config/dotfiles/passphrase (never in the repository). install.sh asks for it.
PASSFILE="${DOTFILES_PASSPHRASE_FILE:-$H/.config/dotfiles/passphrase}"
if [ -d secrets ] && ls secrets/*.tar.gz >/dev/null 2>&1; then
  if [ ! -s "$PASSFILE" ]; then
    echo "no passphrase in $PASSFILE: the bundles under secrets/ cannot be encrypted" >&2
    exit 1
  fi
  for plain in secrets/*.tar.gz; do
    gpg --batch --yes --quiet --symmetric --cipher-algo AES256 --pinentry-mode loopback \
        --passphrase-file "$PASSFILE" -o "$plain.gpg" "$plain" && rm -f "$plain"
  done
  echo "secrets: $(ls secrets/*.gpg 2>/dev/null | wc -l) encrypted bundles"
fi

if grep -rIEn --exclude-dir=.git --exclude=sync.sh \
  'ghp_[A-Za-z0-9]{30,}|github_pat_|sk-[A-Za-z0-9_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|[MN][A-Za-z0-9_-]{23}\.[A-Za-z0-9_-]{6}\.[A-Za-z0-9_-]{27,}|"?(access|refresh)_?token"?\s*[:=]\s*"[A-Za-z0-9._-]{20,}' . ; then
  echo "SECRET FOUND, remove it before committing" >&2; exit 1
fi
echo "synced: $(du -sh home | cut -f1) in home/, no secrets matched"
