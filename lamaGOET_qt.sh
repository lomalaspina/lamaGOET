#!/usr/bin/env bash
set -euo pipefail

script_source=${BASH_SOURCE[0]}
while [[ -L "$script_source" ]]; do
    source_dir=$(cd -P "$(dirname "$script_source")" && pwd)
    script_source=$(readlink "$script_source")
    [[ "$script_source" = /* ]] || script_source="$source_dir/$script_source"
done
script_dir=$(cd -P "$(dirname "$script_source")" && pwd)

# Qt 6 requires a UTF-8 character locale.  WSL can keep LANG=en_US after
# en_US.UTF-8 has been generated, which selects the legacy ISO-8859-1 locale
# and makes Qt print a warning at every launch.  Correct only this process:
# preserve the user's language where a UTF-8 variant exists, then fall back to
# the portable C UTF-8 locale.  Do not change /etc/default/locale or the
# calling shell's environment.
ensure_utf8_locale() {
    local charmap locale_hint locale_name locale_modifier candidate

    charmap=$(locale charmap 2>/dev/null || true)
    case "$charmap" in
        UTF-8|UTF8|utf8) return 0 ;;
    esac

    locale_hint=${LC_ALL:-${LC_CTYPE:-${LANG:-C}}}
    locale_name=${locale_hint%%.*}
    locale_name=${locale_name%%@*}
    locale_modifier=
    case "$locale_hint" in
        *@*) locale_modifier=@${locale_hint#*@} ;;
    esac

    for candidate in \
        "${locale_name}.UTF-8${locale_modifier}" \
        "${locale_name}.utf8${locale_modifier}" \
        C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8
    do
        charmap=$(LC_ALL="$candidate" locale charmap 2>/dev/null || true)
        case "$charmap" in
            UTF-8|UTF8|utf8)
                # LC_ALL overrides every locale category.  Replace it only
                # when the caller explicitly set it; otherwise LANG and
                # LC_CTYPE are sufficient and preserve category overrides.
                if [[ -n "${LC_ALL:-}" ]]; then
                    export LC_ALL=$candidate
                else
                    export LANG=$candidate
                    export LC_CTYPE=$candidate
                fi
                return 0
                ;;
        esac
    done

    return 0
}

ensure_utf8_locale

if [[ -n "${LAMAGOET_QT_PYTHON:-}" ]]; then
    python_command=$LAMAGOET_QT_PYTHON
elif [[ -x "$script_dir/.venv-qt/bin/python" ]]; then
    python_command="$script_dir/.venv-qt/bin/python"
elif command -v python3 >/dev/null 2>&1; then
    python_command=python3
elif command -v python >/dev/null 2>&1; then
    python_command=python
else
    echo "lamaGOET Qt requires Python 3.10 or newer." >&2
    exit 2
fi

exec "$python_command" "$script_dir/GUI_lamaGOET_qt.py" --mode local "$@"
