#!/usr/bin/env bash
# Qt must receive a UTF-8 locale even when WSL was started with LANG=C or the
# legacy LANG=en_US.  Exercise the real launcher without starting the GUI.

set -uo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/lamagoet-locale.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

cat > "$tmp_dir/capture-locale" <<'EOF'
#!/usr/bin/env bash
locale charmap
printf 'LANG=%s\n' "${LANG:-}"
printf 'LC_CTYPE=%s\n' "${LC_CTYPE:-}"
EOF
chmod +x "$tmp_dir/capture-locale"

output=$(env -i \
    HOME="${HOME:-$tmp_dir}" \
    PATH="$PATH" \
    LANG=C \
    LAMAGOET_QT_PYTHON="$tmp_dir/capture-locale" \
    bash "$repo_dir/lamaGOET_qt.sh" 2>"$tmp_dir/stderr")

charmap=$(printf '%s\n' "$output" | sed -n '1p')
case "$charmap" in
    UTF-8|UTF8|utf8) ;;
    *)
        echo "lamaGOET_qt.sh selected non-UTF-8 charmap '$charmap'" >&2
        exit 1
        ;;
esac

if [ -s "$tmp_dir/stderr" ]; then
    echo "lamaGOET_qt.sh emitted an unexpected locale diagnostic:" >&2
    sed 's/^/  /' "$tmp_dir/stderr" >&2
    exit 1
fi

echo "Qt launcher UTF-8 locale check passed ($charmap)"
