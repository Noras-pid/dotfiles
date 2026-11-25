# dotfiles

CachyOS + Hyprland + Orrery/Quickshell rice. Everything to rebuild the machine after a reinstall.

## Restore, one command

Install CachyOS (btrfs, same username), log in, open a terminal:

    bash <(curl -fsSL https://raw.githubusercontent.com/Noras-pid/dotfiles/main/bootstrap.sh)

It installs yay, every package (`packages/`), flatpaks, copies `home/` into `$HOME`
(old files go to `~/.dotfiles-backup/`), installs the systemd units and sudoers rule from `system/`,
sets zsh and applies the theme. Reboot at the end.

## Update the repo after changing your setup

    cd ~/dotfiles && ./sync.sh && git add -A && git commit -m "update" && git push

`sync.sh` copies the live config, refreshes package lists and aborts if it finds a token or private key.

## Layout

- `home/` mirror of `$HOME` (`.config`, `.local/bin`, fonts, wallpapers, shell rc)
- `system/` `/etc` units, greetd config, turbo and gpu shutdown scripts. Hardware-specific units (nvidia, ath10k, disk D) install only when the hardware is present
- `packages/` pacman, AUR, flatpak, system services

Not stored: browser profiles, Discord/Steam data, keyrings, games, ssh keys, `~/.gitconfig`. Back these up separately.

## Apps and mail accounts

`install.sh` also installs Steam, Discord and Thunderbird (pacman), the Claude Code CLI
(official installer) and Cursor (official AppImage, unpacked to `~/.local/opt/cursor`).

`secrets/thunderbird.tar.gz` holds the Thunderbird profile without the downloaded mail:
account settings, saved logins and the key that unlocks them, address book and filters.
`install.sh` unpacks it into `~/.config/thunderbird` when no profile exists there, so every
account is back on first start. `./sync.sh` refreshes it; close Thunderbird first.

`secrets/anixapp.tar.gz` (AnixApp login and settings) and `secrets/opencode.tar.gz`
(opencode config with provider keys, key files and the credentials from its database)
work the same way: `./sync.sh` refreshes them, `install.sh` unpacks them when nothing is
there yet.

`secrets/claude-code.tar.gz` (instructions, settings, skills, every project's memory, the
login and the plugin list), `secrets/cursor.tar.gz` (editor settings, snippets, MCP servers,
CLI config, skills and the extension ids) and `secrets/github.tar.gz` (`.gitconfig`, the
`gh` config and its token) restore the development tools. Claude Code re-downloads its
plugins from the marketplaces, and Cursor's own account is signed in again by hand.

## Encrypted bundles

Every file under `secrets/` is a gpg symmetric (AES256) archive. `./sync.sh` encrypts them
with the passphrase in `~/.config/dotfiles/passphrase`, which is never in the repository;
`install.sh` asks for that passphrase once, the first time it opens a bundle, and uses it
for the rest. `DOTFILES_PASSPHRASE=... ./install.sh` skips the prompt. A wrong passphrase
restores nothing and the tools are simply set up from scratch.
