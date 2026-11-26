#!/bin/sh
# Launch Discord Quest App from the Proton prefix built by setup-prefix.sh.
#
# The app is a WebView2 host whose Chromium only survives inside Proton's
# pressure-vessel container with the sandbox and GPU process disabled. Plain
# wine, and Proton's wine binary run outside the container, both render a black
# window.
#
# gamescope is optional. Without it the app is an ordinary window that the
# window manager sizes normally, which keeps text sharp. With it, the app is
# presented as a fullscreen "game", and because gamescope upscales the app's
# own 800x600 window the result is soft: set GS_ARGS to opt in, e.g.
#   GS_ARGS="-W 1920 -H 1080 -f"
set -eu

GAMEID=${GAMEID:-discord-quest-app}
data=${XDG_DATA_HOME:-$HOME/.local/share}/discord-quest-app
PREFIX=${DQA_PREFIX:-$data/prefix}
WEBVIEW2_ARGS=${WEBVIEW2_ARGS:---no-sandbox --disable-gpu --in-process-gpu}

export WINEPREFIX=$PREFIX
export GAMEID

if [ -z "${UMU_RUN:-}" ]; then
    for c in "$(command -v umu-run 2>/dev/null || true)" \
             "$HOME/.config/heroic/tools/runtimes/umu/umu-run"; do
        [ -n "$c" ] && [ -x "$c" ] && UMU_RUN=$c && break
    done
fi
[ -n "${UMU_RUN:-}" ] || { echo "umu-run not found; set UMU_RUN" >&2; exit 1; }

if [ -z "${PROTONPATH:-}" ]; then
    PROTONPATH=$(ls -d "$HOME/.local/share/Steam/compatibilitytools.d"/GE-Proton* \
                        "$HOME/.steam/root/compatibilitytools.d"/GE-Proton* \
                        "$HOME/.local/share/Steam/steamapps/common"/Proton* \
                        "$HOME/games/SteamLibrary/steamapps/common"/Proton* 2>/dev/null \
                 | sort -V | tail -1)
fi
[ -n "${PROTONPATH:-}" ] || { echo "no Proton build found; set PROTONPATH" >&2; exit 1; }
export PROTONPATH

appdir="$PREFIX/drive_c/users/${WINEUSER:-steamuser}/AppData/Local/Discord Quest App"
if [ ! -x "$appdir/discord-quest-completer.exe" ]; then
    echo "no app in $appdir - run setup-prefix.sh first" >&2
    exit 1
fi

# Proton derives the game drive from the working directory. A desktop launch
# starts in $HOME, which makes it fail with "unable to use parent for game
# drive, path /home", so start from the app's own directory.
cd "$appdir"

if [ -n "${GS_ARGS:-}" ]; then
    # shellcheck disable=SC2086
    exec env WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="$WEBVIEW2_ARGS" \
        gamescope $GS_ARGS -- "$UMU_RUN" "$appdir/discord-quest-completer.exe" "$@"
fi

exec env WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS="$WEBVIEW2_ARGS" \
    "$UMU_RUN" "$appdir/discord-quest-completer.exe" "$@"
