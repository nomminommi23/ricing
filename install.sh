#!/usr/bin/env bash
# Clones this rice onto a fresh machine and drops its files into ~/.config.
#
#   ./install.sh              clone/update and install
#   ./install.sh --dry-run    show what would happen, change nothing
#   ./install.sh --deps       also install dependencies (Arch/pacman only)
#
# ~/.config almost always already has *other* apps' configs in it, so this
# never does a plain `git clone` into it (git refuses a non-empty target
# anyway). Instead it clones into a temp dir, then moves only the paths this
# repo actually tracks into ~/.config one by one - anything already there
# under the same name gets backed up first, never overwritten silently. If
# ~/.config is already a clone of this repo (re-running this script, or a
# machine that already has the rice), it just pulls instead.
set -euo pipefail

REPO_URL="${RICING_REPO_URL:-https://github.com/nomminommi23/ricing.git}"
TARGET="$HOME/.config"
BACKUP="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
INSTALL_DEPS=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --deps) INSTALL_DEPS=1 ;;
        --repo=*) REPO_URL="${arg#--repo=}" ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "install.sh: unknown option '$arg'" >&2; exit 1 ;;
    esac
done

run() {
    if [ "$DRY_RUN" = 1 ]; then
        echo "+ $*"
    else
        "$@"
    fi
}

command -v git >/dev/null || { echo "install.sh: git is required" >&2; exit 1; }

# Already a checkout of this repo (fresh install run twice, or a machine that
# already has the rice) - just update it in place.
if [ -d "$TARGET/.git" ] && git -C "$TARGET" remote get-url origin 2>/dev/null | grep -qF "$(basename "$REPO_URL" .git)"; then
    echo "~/.config is already a checkout of this repo - pulling instead of cloning."
    run git -C "$TARGET" pull --ff-only
    echo "Done. See the README's Requirements section for dependencies (or re-run with --deps on Arch)."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Cloning $REPO_URL ..."
run git clone "$REPO_URL" "$TMP/repo"
[ "$DRY_RUN" = 1 ] && { echo "(dry run: nothing was actually cloned, stopping here)"; exit 0; }

mkdir -p "$TARGET"
moved_any=0
for entry in "$TMP/repo"/.[!.]* "$TMP/repo"/*; do
    name="$(basename "$entry")"
    [ "$name" = ".git" ] && continue
    [ -e "$entry" ] || continue  # unmatched glob

    dest="$TARGET/$name"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mkdir -p "$BACKUP"
        echo "  $name already exists in ~/.config - backing it up to $BACKUP/$name"
        mv "$dest" "$BACKUP/$name"
    fi
    mv "$entry" "$dest"
    moved_any=1
done

mv "$TMP/repo/.git" "$TARGET/.git"
echo "Installed $([ "$moved_any" = 1 ] && echo "the rice" || echo "nothing (repo was empty?)") into $TARGET."
[ -d "$BACKUP" ] && echo "Anything that was already there got backed up to $BACKUP - safe to delete once you've checked it."

if [ "$INSTALL_DEPS" = 1 ]; then
    if command -v pacman >/dev/null; then
        echo "Installing dependencies via pacman (see README.md for apt/dnf equivalents)..."
        sudo pacman -S --needed hyprland sddm xdg-desktop-portal-hyprland quickshell kitty rofi \
            mako thunar thunar-volman thunar-archive-plugin tumbler gvfs gvfs-mtp gvfs-smb \
            xarchiver swaybg hyprcursor librsvg grim slurp wl-clipboard cliphist zenity \
            networkmanager network-manager-applet wireplumber pavucontrol blueman brightnessctl \
            playerctl lm_sensors nvidia-utils curl python qt5ct qt6ct nwg-look materia-gtk-theme \
            papirus-icon-theme ttf-jetbrains-mono-nerd
    else
        echo "--deps only knows pacman (Arch). See the Requirements section in README.md for apt/dnf." >&2
    fi
fi

echo "Done. Log out and back into a Hyprland/SDDM session (or reboot) to pick everything up."
