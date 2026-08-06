#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_dir/Tests/lib/shell_test_helpers.sh"
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT

mkdir -p "$tmp_root/bin"
printf '%s\n' \
    '#!/usr/bin/env bash' \
    'printf "%s\n" "$@" > "$FAKE_SCP_LOG"' \
    > "$tmp_root/bin/scp"
chmod +x "$tmp_root/bin/scp"

for runner in RUN_lamaGOET_release.sh lamaGOET.sh; do
    case_dir="$tmp_root/${runner%.sh}"
    mkdir -p "$case_dir"
    (
        cd "$case_dir"
        export PATH="$tmp_root/bin:$PATH"
        export FAKE_SCP_LOG="$case_dir/scp.log"
        export LAMAGOET_LIVE_CIF_SERVER="submit-host"
        export LAMAGOET_LIVE_CIF_DIRECTORY="/data/calculation"
        export LAMAGOET_LIVE_CIF_PORT=2244
        JOBNAME=nh3
        printf 'data_test\n' > nh3.cartesian.cif2
        extract_function "$repo_dir/$runner" '
                /^_lamagoet_publish_latest_cif\(\)/ { copying=1 }
                copying { print }
                copying && /^}/ { exit }
        ' "publish helper"
        _lamagoet_publish_latest_cif
        grep -q 'nh3.cartesian.cif2' "$FAKE_SCP_LOG"
        grep -q 'submit-host:/data/calculation/nh3.latest_tonto.cif' \
            "$FAKE_SCP_LOG"
        grep -q 'BatchMode=yes' "$FAKE_SCP_LOG"
    )
done

echo "Live Tonto CIF publishing tests passed"
