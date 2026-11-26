#!/bin/sh
# Install Discord Quest App for the current user, following XDG conventions:
#
#   ${XDG_DATA_HOME:-~/.local/share}/discord-quest-app/prefix   Proton prefix
#   ~/.local/bin/discord-quest-app                              launcher
#   ${XDG_DATA_HOME:-~/.local/share}/applications/*.desktop     menu entry
#   ${XDG_CACHE_HOME:-~/.cache}/discord-quest-app               downloads
#
# Pass an NSIS installer path as the first argument to install a specific
# release instead of the latest published one.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}
apps=$data/applications
bindir=$HOME/.local/bin

"$here/setup-prefix.sh" "$@"

mkdir -p "$bindir" "$apps"
install -m 755 "$here/run.sh" "$bindir/discord-quest-app"

cat > "$apps/discord-quest-app.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Discord Quest App
Comment=Complete Discord quests (Windows build under Proton)
Exec=$bindir/discord-quest-app
Icon=applications-games
Terminal=false
Categories=Game;Utility;
StartupWMClass=discord-quest-completer.exe
EOF

if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$apps" >/dev/null 2>&1 || true
fi

printf '\ninstalled:\n  %s\n  %s\n' "$bindir/discord-quest-app" "$apps/discord-quest-app.desktop"
printf '\nupdates: re-run this installer with DQA_REFRESH=1.\n'
printf 'The in-app update prompt runs an NSIS installer under Wine and is not supported here.\n'
