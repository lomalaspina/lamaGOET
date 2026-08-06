#!/bin/bash
#
# Install lamaGOET's dependencies and put its commands on the PATH.
#
# Debian, Ubuntu and WSL only. On macOS see docs/INSTALL.md; the Qt interface
# needs no installation beyond Python 3.10, and the shell runners need the GNU
# tools from Homebrew.
#
# Safe to run more than once.

set -u

LOCALDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! command -v apt-get >/dev/null 2>&1; then
    echo "install.sh only handles Debian, Ubuntu and WSL." >&2
    echo "On macOS: brew install gnu-sed gawk coreutils, then run" >&2
    echo "    python3 $LOCALDIR/GUI_lamaGOET_qt.py --setup-only" >&2
    echo "See docs/INSTALL.md." >&2
    exit 2
fi

# GNU sed, awk and coreutils. The runners depend on GNU behaviour; see
# lamagoet_shell_env.sh.
sudo apt-get install -y gawk coreutils sed

# Python, for the Qt interface. The launchers build their own environment.
sudo apt-get install -y python3 python3-venv python3-pip

# Qt runtime libraries, needed to open a window.
sudo apt-get install -y libxcb-cursor0 libxkbcommon-x11-0 libegl1
sudo apt-get install -y language-pack-en-base

# Still used for a few input prompts: the space group, an external basis set,
# and dispersion coefficients. lamaGOET says what to do if it is absent.
sudo apt-get install -y zenity

sudo cp "$LOCALDIR/llama.png" /usr/local/include/

# Commands on the PATH. -f so re-running replaces the links instead of failing.
sudo ln -sf "$LOCALDIR/lamaGOET.sh"                /usr/local/bin/lamaGOET
sudo ln -sf "$LOCALDIR/RUN_lamaGOET_release.sh"    /usr/local/bin/RUN_lamaGOET
sudo ln -sf "$LOCALDIR/lamaGOET_qt.sh"             /usr/local/bin/lamaGOET_qt
sudo ln -sf "$LOCALDIR/GUI_lamaGOET_qt.sh"         /usr/local/bin/GUI_lamaGOET

# The runners refuse to start without their environment shim, and the symlinks
# above mean $(dirname "$0") resolves to /usr/local/bin.
sudo ln -sf "$LOCALDIR/lamagoet_shell_env.sh"      /usr/local/bin/lamagoet_shell_env.sh

# Build the private Qt environment now, so the first launch is not a long wait.
python3 "$LOCALDIR/GUI_lamaGOET_qt.py" --setup-only

cat <<'DONE'

lamaGOET installed.

    lamaGOET_qt        set up and run a calculation on this computer
    GUI_lamaGOET       set up a calculation and submit it to a PBS cluster
    lamaGOET           run the job_options.txt in the current directory
    RUN_lamaGOET       the command a cluster node runs

DONE
