#!/bin/sh
# Build the Proton prefix for the Windows build of Discord Quest App.
#
#   ./setup-prefix.sh [/path/to/discord-quest-completer-windows-x86_64-setup.exe]
#
# Uses umu-launcher (bundled with Heroic, or `umu-run` on PATH) with a
# GE-Proton/Proton build. The app is a WebView2 host: plain wine renders a black
# window, Proton's container is what makes its Chromium run.
#
# Paths follow the XDG base directory spec:
#   prefix  ${XDG_DATA_HOME:-~/.local/share}/discord-quest-app/prefix
#   cache   ${XDG_CACHE_HOME:-~/.cache}/discord-quest-app
set -eu

GAMEID=${GAMEID:-discord-quest-app}
data=${XDG_DATA_HOME:-$HOME/.local/share}/discord-quest-app
PREFIX=${DQA_PREFIX:-$data/prefix}
CACHE=${DQA_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/discord-quest-app}
REPO=${DQA_RELEASE_REPO:-m-yr-ondo/discord-quest-app}
WEBVIEW2_URL="https://go.microsoft.com/fwlink/p/?LinkId=2124701"
SETUP=${1:-}

here=$(cd "$(dirname "$0")" && pwd)
export WINEPREFIX=$PREFIX
export GAMEID

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

if [ -z "${UMU_RUN:-}" ]; then
    for c in "$(command -v umu-run 2>/dev/null || true)" \
             "$HOME/.config/heroic/tools/runtimes/umu/umu-run"; do
        [ -n "$c" ] && [ -x "$c" ] && UMU_RUN=$c && break
    done
fi
[ -n "${UMU_RUN:-}" ] || die "umu-run not found: install umu-launcher or Heroic, or set UMU_RUN"
export UMU_RUN

if [ -z "${PROTONPATH:-}" ]; then
    PROTONPATH=$(ls -d "$HOME/.local/share/Steam/compatibilitytools.d"/GE-Proton* \
                        "$HOME/.steam/root/compatibilitytools.d"/GE-Proton* \
                        "$HOME/.local/share/Steam/steamapps/common"/Proton* \
                        "$HOME/games/SteamLibrary/steamapps/common"/Proton* 2>/dev/null \
                 | sort -V | tail -1)
fi
[ -n "${PROTONPATH:-}" ] || die "no Proton build found: set PROTONPATH to a Proton or GE-Proton directory"
export PROTONPATH

if pgrep -f "AppData/Local/Discord Quest App/discord-quest-completer.exe" >/dev/null 2>&1; then
    die "Discord Quest App is running; close it before running setup again"
fi

command -v gamescope >/dev/null || die "gamescope is required (pacman -S gamescope)"
command -v curl >/dev/null || die "curl is required"
command -v x86_64-w64-mingw32-gcc >/dev/null ||
    die "mingw-w64 is required for the tray-free runner (pacman -S mingw-w64-gcc)"
mkdir -p "$CACHE"

unix_to_z() { printf 'Z:%s' "$(printf '%s' "$1" | sed 's|/|\\\\|g')"; }

say "umu-run: $UMU_RUN"
say "proton:  $PROTONPATH"
say "prefix:  $PREFIX"

wv2_exe=$(ls "$PREFIX/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application"/*/msedgewebview2.exe 2>/dev/null | head -1 || true)
if [ -n "$wv2_exe" ]; then
    say "WebView2 runtime already present"
else
    wv2="$CACHE/MicrosoftEdgeWebView2RuntimeInstallerX64.exe"
    if [ ! -f "$wv2" ]; then
        say "downloading the WebView2 Evergreen standalone installer (about 215 MB)"
        curl -L --fail --output "$wv2" "$WEBVIEW2_URL"
    fi
    say "installing WebView2 into the prefix (takes a couple of minutes)"
    "$UMU_RUN" "$(unix_to_z "$wv2")" /silent /install >/dev/null 2>&1 || true
    wv2_exe=$(ls "$PREFIX/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application"/*/msedgewebview2.exe 2>/dev/null | head -1 || true)
    [ -n "$wv2_exe" ] || die "WebView2 did not install into $PREFIX"
    say "WebView2 runtime: $(basename "$(dirname "$(dirname "$wv2_exe")")")"
fi

if [ -z "$SETUP" ]; then
    SETUP="$CACHE/discord-quest-completer-windows-x86_64-setup.exe"
    if [ "${DQA_REFRESH:-0}" = "1" ]; then
        rm -f "$SETUP"
    fi
    if [ ! -f "$SETUP" ]; then
        say "downloading the latest installer from $REPO"
        curl -L --fail --output "$SETUP" \
            "https://github.com/$REPO/releases/latest/download/discord-quest-completer-windows-x86_64-setup.exe"
    fi
fi

say "installing the app"
"$UMU_RUN" "$(unix_to_z "$SETUP")" /S >/dev/null 2>&1

appdir="$PREFIX/drive_c/users/${WINEUSER:-steamuser}/AppData/Local/Discord Quest App"
[ -f "$appdir/discord-quest-completer.exe" ] || die "install failed: $appdir is empty"

say "building the tray-free runner"
x86_64-w64-mingw32-gcc -O2 -s -mwindows -o "$CACHE/src-win.exe" "$here/runner-stub.c" -lshell32
cp "$CACHE/src-win.exe" "$appdir/data/src-win.exe"

say ""
say "prefix ready: $PREFIX"
say "run it with: $here/run.sh  (or the launcher installed by install.sh)"
