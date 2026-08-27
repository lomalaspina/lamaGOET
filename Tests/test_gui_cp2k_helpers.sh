#!/bin/bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_dir/lamaGOET.sh"
basis_fixture="$repo_dir/Tests/cp2k_basis_sample"
cif_fixture="$repo_dir/Tests/inputs/calc.cif"
grown_fixture="$repo_dir/Tests/.tmp-grown-$$.cif"
tmp_dir="$repo_dir/Tests/.tmp-gui-helpers-$$"
mkdir -p "$tmp_dir"
trap 'rm -f -- "$grown_fixture"; rm -rf -- "$tmp_dir"' EXIT

actual=$("$script" --list-cp2k-basis-sets "$basis_fixture" "aug-SZV-MOLOPT-ae-SR")
expected=$'aug-SZV-MOLOPT-ae-SR\naug-SZV-MOLOPT-ae-SR-q1\nDZVP-MOLOPT-GTH\nDZVP-MOLOPT-GTH-q4'
if [[ "$actual" != "$expected" ]]; then
    printf 'Unexpected CP2K basis list:\n%s\n' "$actual" >&2
    exit 1
fi

actual=$("$script" --list-cp2k-functionals "PBE")
expected=$'PBE\nBLYP'
if [[ "$actual" != "$expected" ]]; then
    printf 'Unexpected CP2K functional list:\n%s\n' "$actual" >&2
    exit 1
fi

actual=$("$script" --list-scf-methods Gaussian "BLYP")
if [[ "$(printf '%s\n' "$actual" | head -n 1)" != "BLYP" ]] \
    || ! printf '%s\n' "$actual" | grep -qx "b3lyp"; then
    echo "Saved Gaussian method was not preserved in the editable method list" >&2
    exit 1
fi
for method in PBEPBE uPBEPBE; do
    if ! printf '%s\n' "$actual" | grep -qx "$method"; then
        echo "Canonical Gaussian method $method is missing" >&2
        exit 1
    fi
done
for unsupported in PBE1PBE uPBE1PBE m06 wb97xd; do
    if printf '%s\n' "$actual" | grep -qx "$unsupported"; then
        echo "Method unsupported by Tonto leaked into the Gaussian suggestions: $unsupported" >&2
        exit 1
    fi
done
for obsolete in pbe upbe pbe0 upbe0; do
    if printf '%s\n' "$actual" | grep -qx "$obsolete"; then
        echo "Legacy Gaussian method $obsolete leaked into the method list" >&2
        exit 1
    fi
done

actual=$("$script" --list-scf-methods Gaussian "pbe0")
if [[ "$(printf '%s\n' "$actual" | head -n 1)" != "PBE1PBE" ]]; then
    echo "Legacy Gaussian PBE0 method was not canonicalized" >&2
    exit 1
fi

printf '%s\n' Orca > "$tmp_dir/scf-program"
actual=$("$script" --list-scf-basis-sets "$tmp_dir/scf-program" "MyCustomBasis")
if [[ "$(printf '%s\n' "$actual" | head -n 1)" != "MyCustomBasis" ]] \
    || ! printf '%s\n' "$actual" | grep -qx "def2-TZVP"; then
    echo "ORCA basis suggestions or the saved custom value are missing" >&2
    exit 1
fi
if printf '%s\n' "$actual" | grep -qx "GenECP"; then
    echo "Gaussian-only basis suggestion leaked into the ORCA list" >&2
    exit 1
fi

for program in OCC Tonto elmodb; do
    actual=$("$script" --list-scf-basis-sets "$program" "")
    if [[ "$program" == "OCC" ]] && ! printf '%s\n' "$actual" | grep -qx "cc-pVDZ"; then
        echo "OCC basis suggestions are missing" >&2
        exit 1
    fi
done

actual=$("$script" --list-scf-methods Crystal14 "PBE0")
if [[ "$(printf '%s\n' "$actual" | head -n 1)" != "PBE0" ]] \
    || ! printf '%s\n' "$actual" | grep -qx "PBE" \
    || printf '%s\n' "$actual" | grep -qx "HSE06"; then
    echo "CRYSTAL23 method suggestions or the saved value are missing" >&2
    exit 1
fi

actual=$("$script" --list-scf-basis-sets Crystal14 "MyCrystalBasis")
if [[ "$(printf '%s\n' "$actual" | head -n 1)" != "MyCrystalBasis" ]] \
    || ! printf '%s\n' "$actual" | grep -qx "POB-TZVP-REV2"; then
    echo "CRYSTAL23 basis suggestions or the saved editable value are missing" >&2
    exit 1
fi

LAMAGOET_STRUCTURE_VIEWER=true "$script" --view-cif "$cif_fixture"
mkdir -p "$tmp_dir/no-dialog"
printf '%s\n' '#!/bin/bash' 'exit 1' > "$tmp_dir/no-dialog/zenity"
chmod +x "$tmp_dir/no-dialog/zenity"
if PATH="$tmp_dir/no-dialog:$PATH" \
    LAMAGOET_STRUCTURE_VIEWER=true \
    "$script" --view-cif "$repo_dir/Tests/inputs/missing.cif"; then
    echo "Missing structure unexpectedly passed viewer validation" >&2
    exit 1
fi

grown_result=$(
    LAMAGOET_STRUCTURE_VIEWER=true \
    LAMAGOET_GROWN_CIF="$grown_fixture" \
    "$script" --grow-cif "$cif_fixture"
)
if [[ "$grown_result" != "$grown_fixture" ]] || ! cmp -s "$cif_fixture" "$grown_fixture"; then
    echo "Manual-grow helper did not create and select the new CIF" >&2
    exit 1
fi

printf '%s\n' \
    '#!/bin/bash' \
    'case " $* " in' \
    '  *" --list "*) printf "%s\n" Olex2 ;;' \
    '  *" --file-selection "*) printf "%s\n" "$MOCK_VIEWER" ;;' \
    'esac' > "$tmp_dir/zenity"
printf '%s\n' \
    '#!/bin/bash' \
    'printf "%s\n" "$1" > "$MOCK_VIEWER_LOG"' > "$tmp_dir/chosen-viewer"
chmod +x "$tmp_dir/zenity" "$tmp_dir/chosen-viewer"
MOCK_VIEWER="$tmp_dir/chosen-viewer" \
MOCK_VIEWER_LOG="$tmp_dir/viewer-argument" \
PATH="$tmp_dir:$PATH" \
LAMAGOET_VIEWER_WAIT=true \
    "$script" --view-cif "$cif_fixture"
if [[ "$(cat "$tmp_dir/viewer-argument")" != "$cif_fixture" ]]; then
    echo "The viewer selector did not pass the CIF to the user-selected executable" >&2
    exit 1
fi

echo "CP2K GUI helper tests passed"
