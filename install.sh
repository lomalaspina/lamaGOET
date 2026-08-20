#!/usr/bin/env bash
#
# Install lamaGOET's dependencies and put its commands on the PATH.
#
# Debian, Ubuntu and WSL only. On macOS see docs/INSTALL.md; the Qt interface
# builds its private Python environment automatically, while the shell runners
# need the GNU tools from Homebrew.
#
# Safe to run more than once.

set -Eeuo pipefail

localdir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! command -v apt-get >/dev/null 2>&1; then
    echo "install.sh handles Debian, Ubuntu and WSL." >&2
    echo "On macOS: brew install gnu-sed gawk coreutils, then run" >&2
    echo "    python3 $localdir/GUI_lamaGOET_qt.py --check-install" >&2
    echo "See docs/INSTALL.md." >&2
    exit 2
fi

if (( EUID == 0 )); then
    admin=()
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        user_command=(sudo -H -u "${SUDO_USER}")
    else
        user_command=()
    fi
elif command -v sudo >/dev/null 2>&1; then
    admin=(sudo)
    user_command=()
else
    echo "lamaGOET installation needs root access to install system packages." >&2
    echo "Install sudo, run this script as root, or follow docs/INSTALL.md." >&2
    exit 2
fi

run_admin() {
    "${admin[@]}" "$@"
}

run_user() {
    "${user_command[@]}" "$@"
}

echo "lamaGOET: refreshing Debian/Ubuntu package information..."
run_admin apt-get update

echo "lamaGOET: installing shell, Python, Qt, OpenGL and desktop dependencies..."
run_admin env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    bash \
    bc \
    ca-certificates \
    coreutils \
    desktop-file-utils \
    findutils \
    gawk \
    grep \
    gzip \
    locales \
    openssh-client \
    python3 \
    python3-pip \
    python3-venv \
    sed \
    zenity \
    libdbus-1-3 \
    libegl1 \
    libfontconfig1 \
    libgl1 \
    libgl1-mesa-dri \
    libglib2.0-0 \
    libglvnd0 \
    libglx0 \
    libice6 \
    libopengl0 \
    libsm6 \
    libwayland-client0 \
    libwayland-cursor0 \
    libwayland-egl1 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcb-cursor0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render0 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-sync1 \
    libxcb-util1 \
    libxcb-xfixes0 \
    libxcb-xinerama0 \
    libxcb-xkb1 \
    libxext6 \
    libxi6 \
    libxkbcommon0 \
    libxkbcommon-x11-0 \
    libxrandr2 \
    libxrender1 \
    libxtst6

if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'; then
    echo "lamaGOET Qt requires Python 3.10 or newer." >&2
    echo "The python3 supplied by this operating system is too old." >&2
    echo "Install a newer Python, then run install.sh again." >&2
    exit 2
fi

# Install a real Linux application identity. WSLg and Wayland use the desktop
# file name as the window application ID; without this association a
# Python-launched lamaGOET window is displayed with the generic penguin icon.
run_admin install -Dm644 "$localdir/llama.png" \
    /usr/local/share/pixmaps/lamagoet.png
run_admin install -Dm644 "$localdir/llama.png" \
    /usr/local/share/icons/hicolor/128x128/apps/lamagoet.png
run_admin install -Dm644 "$localdir/lamagoet.desktop" \
    /usr/local/share/applications/lamagoet.desktop
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    run_admin gtk-update-icon-cache -f -t /usr/local/share/icons/hicolor
fi
run_admin update-desktop-database /usr/local/share/applications

# Commands on the PATH. Re-running the installer replaces the links safely.
run_admin ln -sf "$localdir/lamaGOET.sh"             /usr/local/bin/lamaGOET
run_admin ln -sf "$localdir/RUN_lamaGOET_release.sh" /usr/local/bin/RUN_lamaGOET
run_admin ln -sf "$localdir/lamaGOET_qt.sh"          /usr/local/bin/lamaGOET_qt
run_admin ln -sf "$localdir/GUI_lamaGOET_qt.sh"      /usr/local/bin/GUI_lamaGOET

# The runners refuse to start without their GNU-tool environment shim. The
# symlinks above mean dirname of the invoked command is /usr/local/bin.
run_admin ln -sf "$localdir/lamagoet_shell_env.sh" \
    /usr/local/bin/lamagoet_shell_env.sh

# Build the private environment and initialize the actual Qt display backend.
# This catches incomplete pip installs and native XCB/Wayland/OpenGL failures
# now, instead of reporting success and failing on the user's first launch.
run_user python3 "$localdir/GUI_lamaGOET_qt.py" --check-install

cat <<'DONE'

lamaGOET installed and its Qt interface passed the startup check.

    lamaGOET_qt        set up and run a calculation on this computer
    GUI_lamaGOET       set up a calculation and submit it to a PBS cluster
    lamaGOET           run the job_options.txt in the current directory
    RUN_lamaGOET       the command a cluster node runs

Close any already-running lamaGOET window before launching it again so WSLg
uses the new lamaGOET taskbar identity and icon.
DONE
