#!/bin/bash
Encoding=UTF-8
export LC_NUMERIC="en_US.UTF-8"

# Make GNU sed/awk/coreutils available under their plain names, and provide
# the _upper/_lower helpers, so this script behaves the same on Linux and
# macOS.  See lamagoet_shell_env.sh for why this is necessary.
_lamagoet_env_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ -r "$_lamagoet_env_dir/lamagoet_shell_env.sh" ]; then
    source "$_lamagoet_env_dir/lamagoet_shell_env.sh"
else
    echo "lamaGOET: cannot find lamagoet_shell_env.sh next to $0" >&2
    echo "If lamaGOET was installed with install.sh, make sure that file was" >&2
    echo "symlinked into the same directory as this script." >&2
    exit 2
fi

# BEGIN LAMAGOET CP2K SINGLE-FILE BACKEND
# Periodic all-electron CP2K backend embedded directly in this monolithic
# lamaGOET.sh. Only the CIF and binary-density parsers remain external Python
# programs.
LAMAGOET_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export LAMAGOET_SCRIPT_DIR

_lamagoet_publish_latest_cif() {
    local server=${LAMAGOET_LIVE_CIF_SERVER:-}
    local directory=${LAMAGOET_LIVE_CIF_DIRECTORY:-}
    local port=${LAMAGOET_LIVE_CIF_PORT:-2244}
    local candidate

    [[ -n "$server" && -n "$directory" ]] || return 0
    command -v scp >/dev/null 2>&1 || return 0
    for candidate in \
        "${JOBNAME}.cartesian.cif2" \
        "${JOBNAME}.fractional.cif1" \
        "${JOBNAME}.archive.cif"
    do
        [[ -s "$candidate" ]] || continue
        scp -q -o BatchMode=yes -o ConnectTimeout=10 -P "$port" "$candidate" \
            "${server}:${directory}/${JOBNAME}.latest_tonto.cif" || {
            printf 'lamaGOET: warning: could not publish the latest Tonto CIF to the submitting computer\n' >&2
        }
        return 0
    done
}

_cp2k_list_basis_sets() {
    local basis_file=${1:-}
    local current=${2:-}

    if [ ! -r "$basis_file" ]; then
        if [ -n "$current" ]; then
            printf '%s\n' "$current"
        fi
        return 0
    fi

    # CP2K basis-block headers start with an element symbol followed by one o
    # more basis aliases. Primitive and shell-description lines start with
    # numbers, so they are excluded here.
    {
        if [ -n "$current" ]; then
            printf '%s\n' "$current"
        fi
        awk '
            /^[[:space:]]*[#!]/ || /^[[:space:]]*$/ { next }
            $1 ~ /^[A-Z][a-z]?$/ && NF >= 2 {
                for (field = 2; field <= NF; field++) {
                    if ($field !~ /^[0-9.+-]/) print $field
                }
            }
        ' "$basis_file"
    } | awk 'NF && !seen[$0]++'
}

_cp2k_list_functionals() {
    local current=${1:-BLYP}
    case "$(_upper "$current")" in
        BLYP|BP|PADE|LDA|PBE|TPSS|HCTH120|OLYP|BEEFVDW)
            current=$(_upper "$current")
            ;;
        *)
            current=BLYP
            ;;
    esac
    printf '%s\n' \
        "$current" \
        BLYP BP PADE LDA PBE TPSS HCTH120 OLYP BEEFVDW |
        awk 'NF && !seen[$0]++'
}

_lamagoet_selected_scf_program() {
    local selection=${1:-Gaussian}
    if [ -r "$selection" ]; then
        selection=$(head -n 1 "$selection")
    fi
    printf '%s\n' "${selection:-Gaussian}"
}

_lamagoet_list_scf_methods() {
    local program
    local current=${2:-}
    program=$(_lamagoet_selected_scf_program "${1:-Gaussian}")

    {
        [ -n "$current" ] && printf '%s\n' "$current"
        case "$program" in
            Gaussian|optgaussian)
                printf '%s\n' \
                    rhf uhf rohf rks uks blyp ublyp b3lyp ub3lyp \
                    b3pw91 ub3pw91 pbe upbe pbe0 upbe0 bp86 ubp86 \
                    tpss utpss tpssh utpssh m06 um06 m06-2x um06-2x \
                    wb97xd uwb97xd
                ;;
            Orca|optorca)
                printf '%s\n' \
                    RHF UHF ROHF RKS UKS BLYP B3LYP BP86 PBE PBE0 \
                    TPSS TPSSh M06 M06-2X wB97X-D3 wB97X-V
                ;;
            Tonto)
                printf '%s\n' rhf uhf rks uks blyp b3lyp
                ;;
            Crystal14)
                # CRYSTAL23 accepts RHF/UHF directly.  All other choices
                # below are written inside its DFT block by TONTO_TO_CRYSTAL.
                printf '%s\n' \
                    rhf uhf PBE BLYP B3LYP B3PW PBE0 HSE06 PBESOL \
                    PBESOL0 SCAN R2SCAN M06L M06 M062X
                ;;
            OCC)
                printf '%s\n' rhf uhf rks uks blyp b3lyp pbe pbe0
                ;;
            elmodb)
                # ELMODB accepts user-supplied method text.  Preserve the
                # saved value without claiming a fixed built-in list.
                :
                ;;
            *)
                [ -n "$current" ] || printf '%s\n' rhf
                ;;
        esac
    } | awk 'NF && !seen[tolower($0)]++'
}

_lamagoet_list_scf_basis_sets() {
    local program
    local current=${2:-}
    program=$(_lamagoet_selected_scf_program "${1:-Gaussian}")

    {
        [ -n "$current" ] && printf '%s\n' "$current"
        case "$program" in
            Gaussian|optgaussian)
                printf '%s\n' \
                    STO-3G STO-6G 3-21G 3-21G\(d\) 3-21++G\(d\) \
                    4-31G 6-21G 6-31G 6-31G\(d\) 6-31G\(d,p\) \
                    6-31G\(2d\) 6-31G\(2d,p\) 6-31G\(2df,p\) \
                    6-31G\(2df,2p\) 6-31+G 6-31+G\(d\) \
                    6-31+G\(d,p\) 6-31++G 6-31++G\(d\) \
                    6-31++G\(d,p\) 6-311G 6-311G\(d\) \
                    6-311G\(d,p\) 6-311G\(2d,p\) 6-311G\(2d,2p\) \
                    6-311G\(2df,2p\) 6-311G\(2df,2pd\) \
                    6-311+G\(d\) 6-311+G\(d,p\) 6-311++G\(d,p\) \
                    6-311++G\(2d,2p\) D95 D95V D95V+ D95++ \
                    SHC CEP-4G CEP-31G CEP-121G LANL2MB LANL2DZ \
                    SDD DGDZVP DGDZVP2 DGTZVP MIDI UGBS EPR-II EPR-III \
                    cc-pVDZ cc-pVTZ cc-pVQZ cc-pV5Z cc-pV6Z \
                    aug-cc-pVDZ aug-cc-pVTZ aug-cc-pVQZ aug-cc-pV5Z \
                    aug-cc-pV6Z cc-pCVDZ cc-pCVTZ cc-pCVQZ \
                    aug-cc-pCVDZ aug-cc-pCVTZ aug-cc-pCVQZ \
                    Def2SVP Def2TZVP Def2TZVPP Def2QZVP Def2QZVPP \
                    Gen GenECP
                ;;
            Orca|optorca)
                printf '%s\n' \
                    STO-3G MINI MINIS MINIX MIDI 3-21G 3-21GSP \
                    4-22GSP 6-31G 6-31G\(d\) 6-31G\(d,p\) \
                    6-31G\(2d\) 6-31G\(2d,p\) 6-31G\(2d,2p\) \
                    6-31G\(2df\) 6-31G\(2df,2p\) 6-31+G\(d\) \
                    6-31++G\(d,p\) 6-311G 6-311G\(d\) \
                    6-311G\(d,p\) 6-311++G\(d,p\) \
                    SV SV\(P\) SVP TZV TZV\(P\) TZVP TZVPP QZVP \
                    def2-SV\(P\) def2-SVP def2-SVPD def2-TZVP \
                    def2-TZVPP def2-TZVPD def2-TZVPPD def2-QZVP \
                    def2-QZVPP def2-QZVPD def2-QZVPPD \
                    ma-def2-SVP ma-def2-TZVP ma-def2-TZVPP \
                    cc-pVDZ cc-pVTZ cc-pVQZ cc-pV5Z cc-pV6Z \
                    aug-cc-pVDZ aug-cc-pVTZ aug-cc-pVQZ aug-cc-pV5Z \
                    cc-pCVDZ cc-pCVTZ cc-pCVQZ cc-pwCVDZ cc-pwCVTZ \
                    cc-pwCVQZ pc-0 pc-1 pc-2 pc-3 pc-4 \
                    aug-pc-0 aug-pc-1 aug-pc-2 aug-pc-3 \
                    Sapporo-DZP-2012 Sapporo-TZP-2012 Sapporo-QZP-2012 \
                    Partridge-1 Partridge-2 Partridge-3 Partridge-4 \
                    x2c-SVPall x2c-TZVPall x2c-TZVPPall x2c-QZVPall \
                    ZORA-def2-SVP ZORA-def2-TZVP ZORA-def2-TZVPP \
                    DKH-def2-SVP DKH-def2-TZVP DKH-def2-TZVPP
                ;;
            Crystal14)
                # Internal CRYSTAL23 basis libraries.  The editable entry
                # still permits a locally installed/custom keyword.
                printf '%s\n' \
                    STO-3G STO-6G POB-DZVP POB-DZVPP POB-TZVP \
                    POB-DZVP-REV2 POB-TZVP-REV2
                ;;
            OCC)
                printf '%s\n' STO-3G 3-21G 6-31G 6-31G\(d\) cc-pVDZ cc-pVTZ
                ;;
            Tonto)
                :
                ;;
            elmodb)
                # No authoritative fixed ELMODB list; keep the editable
                # saved value and do not invent suggestions.
                :
                ;;
            *)
                [[ -n "$current" || "$program" == "elmodb" ]] || printf '%s\n' STO-3G
                ;;
        esac
    } | awk 'NF && !seen[tolower($0)]++'
}

_lamagoet_select_viewer() {
    local choice
    local viewer
    local candidate

    if ! command -v zenity >/dev/null 2>&1; then
        return 1
    fi

    choice=$(zenity --list --radiolist \
        --title="Choose the structure-growing program" \
        --text="Choose a program. If it is not on PATH, lamaGOET will ask you to locate its executable." \
        --column="Use" --column="Program" \
        TRUE "Olex2" \
        FALSE "Mercury" \
        FALSE "VESTA" \
        FALSE "Avogadro" \
        FALSE "Jmol" \
        FALSE "Choose another executable") || return 1

    case "$choice" in
        Olex2) candidates=(olex2 Olex2 olex2.exe) ;;
        Mercury) candidates=(mercury mercury.exe) ;;
        VESTA) candidates=(vesta VESTA VESTA.exe) ;;
        Avogadro) candidates=(avogadro2 avogadro avogadro2.exe avogadro.exe) ;;
        Jmol) candidates=(jmol jmol.sh Jmol.jar) ;;
        "Choose another executable") candidates=() ;;
        *) return 1 ;;
    esac

    for candidate in "${candidates[@]}"; do
        if command -v "$candidate" >/dev/null 2>&1; then
            viewer=$(command -v "$candidate")
            break
        fi
    done

    if [ -z "$viewer" ]; then
        viewer=$(zenity --file-selection \
            --title="Locate the $choice executable") || return 1
    fi
    printf '%s\n' "$viewer"
}

_lamagoet_view_cif() {
    local structure=${1:-}
    local viewer=${LAMAGOET_STRUCTURE_VIEWER:-}
    local viewer_input
    local message

    if [ -z "$structure" ] || [ ! -f "$structure" ]; then
        message="Select an existing CIF or PDB file before opening the structure viewer."
        if command -v zenity >/dev/null 2>&1; then
            zenity --error --title="lamaGOET structure viewer" --text="$message"
        else
            printf 'lamaGOET: %s\n' "$message" >&2
        fi
        return 1
    fi

    if [ -n "$viewer" ] && [ ! -x "$viewer" ] \
        && ! command -v "$viewer" >/dev/null 2>&1; then
        message="LAMAGOET_STRUCTURE_VIEWER is set to '$viewer', but that executable was not found."
        if command -v zenity >/dev/null 2>&1; then
            zenity --error --title="lamaGOET structure viewer" --text="$message"
        else
            printf 'lamaGOET: %s\n' "$message" >&2
        fi
        return 1
    fi

    if [ -z "$viewer" ]; then
        viewer=$(_lamagoet_select_viewer) || return 1
    fi

    if [ -z "$viewer" ]; then
        message="No structure viewer was selected. Set LAMAGOET_STRUCTURE_VIEWER to an executable path to bypass the selector."
        if command -v zenity >/dev/null 2>&1; then
            zenity --error --title="lamaGOET structure viewer" --text="$message"
        else
            printf 'lamaGOET: %s\n' "$message" >&2
        fi
        return 1
    fi

    viewer_input=$structure
    if [[ "$viewer" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
        viewer_input=$(wslpath -w "$structure")
    fi
    if [[ "$viewer" == *.jar ]]; then
        viewer=(java -jar "$viewer")
    else
        viewer=("$viewer")
    fi
    if [[ "${LAMAGOET_VIEWER_WAIT:-false}" == "true" ]]; then
        "${viewer[@]}" "$viewer_input" >/dev/null 2>&1
    else
        "${viewer[@]}" "$viewer_input" >/dev/null 2>&1 &
    fi
}

_lamagoet_grow_cif() {
    local source_cif=${1:-}
    local target_cif=${LAMAGOET_GROWN_CIF:-}
    local suggested
    local source_name
    local message

    if [ -z "$source_cif" ] || [ ! -f "$source_cif" ]; then
        _lamagoet_view_cif "$source_cif"
        return 1
    fi
    if [[ "$(_lower "$source_cif")" != *.cif ]]; then
        message="Manual crystallographic growing requires a CIF input file."
        if command -v zenity >/dev/null 2>&1; then
            zenity --error --title="lamaGOET manual grow" --text="$message"
        else
            printf 'lamaGOET: %s\n' "$message" >&2
        fi
        return 1
    fi

    if [[ "$source_cif" != /* ]]; then
        source_cif="$PWD/$source_cif"
    fi
    source_name=${source_cif##*/}
    suggested="$PWD/${source_name%.*}_grown.cif"
    if [ -z "$target_cif" ]; then
        if command -v zenity >/dev/null 2>&1; then
            target_cif=$(zenity --file-selection --save --confirm-overwrite \
                --title="Save manually grown structure as" \
                --filename="$suggested") || return 1
        else
            message="A save dialog is unavailable. Set LAMAGOET_GROWN_CIF to the new CIF path and try again."
            printf 'lamaGOET: %s\n' "$message" >&2
            return 1
        fi
    fi

    if [[ "$target_cif" != /* ]]; then
        target_cif="$PWD/$target_cif"
    fi
    if [[ "$target_cif" == "$source_cif" ]]; then
        message="Choose a new filename for the grown CIF; the original CIF will not be overwritten."
        if command -v zenity >/dev/null 2>&1; then
            zenity --error --title="lamaGOET manual grow" --text="$message"
        else
            printf 'lamaGOET: %s\n' "$message" >&2
        fi
        return 1
    fi
    if [ -e "$target_cif" ] && [ -n "${LAMAGOET_GROWN_CIF:-}" ] \
        && [[ "${LAMAGOET_OVERWRITE_GROWN_CIF:-false}" != "true" ]]; then
        printf 'lamaGOET: refusing to overwrite existing grown CIF: %s\n' "$target_cif" >&2
        return 1
    fi

    cp -- "$source_cif" "$target_cif" || return 1
    LAMAGOET_VIEWER_WAIT=true _lamagoet_view_cif "$target_cif" || return 1
    if [ ! -s "$target_cif" ]; then
        printf 'lamaGOET: grown CIF is missing or empty: %s\n' "$target_cif" >&2
        return 1
    fi
    printf '%s\n' "$target_cif"
}

case "${1:-}" in
    --list-cp2k-basis-sets)
        _cp2k_list_basis_sets "${2:-}" "${3:-}"
        exit $?
        ;;
    --list-cp2k-functionals)
        _cp2k_list_functionals "${2:-}"
        exit $?
        ;;
    --list-scf-methods)
        _lamagoet_list_scf_methods "${2:-Gaussian}" "${3:-}"
        exit $?
        ;;
    --list-scf-basis-sets)
        _lamagoet_list_scf_basis_sets "${2:-Gaussian}" "${3:-}"
        exit $?
        ;;
    --view-cif)
        _lamagoet_view_cif "${2:-}"
        exit $?
        ;;
    --grow-cif)
        _lamagoet_grow_cif "${2:-}"
        exit $?
        ;;
    --run-job-options)
        LAMAGOET_BATCH_OPTIONS=${2:-job_options.txt}
        ;;
esac

_cp2k_log() {
    local message="$*"
    printf '%s\n' "$message"
    if [ -n "${JOBNAME:-}" ]; then
        printf '%s\n' "$message" >> "${JOBNAME}.lst"
    fi
}

_cp2k_log_detail() {
    local message="$*"
    if [ -n "${JOBNAME:-}" ]; then
        printf '%s\n' "$message" >> "${JOBNAME}.lst"
    fi
}

_cp2k_error() {
    local message="lamaGOET/CP2K: ERROR: $*"
    printf '%s\n' "$message" >&2
    if [ -n "${JOBNAME:-}" ]; then
        printf '%s\n' "$message" >> "${JOBNAME}.lst"
    fi
    return 1
}

_cp2k_require_file() {
    [ -f "$1" ] || _cp2k_error "required file not found: $1"
}

_cp2k_require_command() {
    command -v "$1" >/dev/null 2>&1 || _cp2k_error "required command not found: $1"
}

_cp2k_abspath() {
    realpath -m -- "$1"
}

_cp2k_resolve_executable() {
    local executable=${1:-}
    [ -n "$executable" ] || {
        _cp2k_error "set CP2K_BIN in the GUI"
        return 1
    }
    if [[ "$executable" == */* ]]; then
        [ -x "$executable" ] || {
            _cp2k_error "CP2K executable is missing or not executable: $executable"
            return 1
        }
        _cp2k_abspath "$executable"
    else
        _cp2k_require_command "$executable" || return 1
        command -v "$executable"
    fi
}

# CP2K shared builds write required runtime library paths to bin/cp2k.conf.
_cp2k_prepare_runtime() {
    local cp2k_bin=$1 config line combined=""
    config="$(dirname "$cp2k_bin")/cp2k.conf"
    if [ -f "$config" ]; then
        while IFS= read -r line; do
            [[ "$line" == /* ]] || continue
            if [ -z "$combined" ]; then
                combined=$line
            else
                combined="$combined:$line"
            fi
        done < "$config"
        if [ -n "$combined" ]; then
            export LD_LIBRARY_PATH="$combined${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        fi
    fi
}

_cp2k_functional() {
    local requested=${CP2K_XC_FUNCTIONAL:-}
    if [ -n "$requested" ]; then
        case "$(_upper "$requested")" in
            B3LYP|PBE0|HSE*|*HYB*)
                _cp2k_error "hybrid functional '$requested' requires an explicit periodic CP2K &HF section"
                return 1
                ;;
        esac
        printf '%s\n' "$requested"
        return 0
    fi
    case "$(_lower "$METHOD")" in
        rks|uks|blyp|ublyp) printf '%s\n' BLYP ;;
        pbe|upbe)           printf '%s\n' PBE ;;
        "")                  printf '%s\n' BLYP ;;
        rhf|uhf|hf|b3lyp|ub3lyp|pbe0|upbe0)
            _cp2k_error "METHOD='${METHOD:-}' requires a custom periodic CP2K &HF setup"
            return 1
            ;;
        *)
            _cp2k_error "cannot map METHOD='${METHOD:-}' to CP2K; set CP2K_XC_FUNCTIONAL"
            return 1
            ;;
    esac
}

_cp2k_geometry_cif() {
    local candidate
    # Later CP2K cycles must use Tonto's refined archive CIF, never a grown
    # Cartesian cluster CIF.
    for candidate in \
        "${JOBNAME:-job}.archive.cif" \
        "${J:-0}.tonto_cycle.${JOBNAME:-job}/${J:-0}.${JOBNAME:-job}.archive.cif" \
        "${CIF:-}"; do
        if [ -n "$candidate" ] && [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    _cp2k_error "no CIF containing the current periodic geometry was found"
}

_cp2k_float_gt() {
    awk -v a="${1:-0}" -v b="${2:-0}" 'BEGIN { exit !(a+0 > b+0) }'
}

CP2K_VALIDATE_LAMAGOET_MODE() {
    local name value
    for name in POWDER_HAR SCCHARGES COMPLETESTRUCT EXPLICITMOL DEFRAGNETW XCWONLY PLOT_TONTO XWR; do
        eval "value=\${$name:-false}"
        if [[ "$(_lower "$value")" == "true" ]]; then
            _cp2k_error "$name=true is not supported by the periodic CP2K backend"
            return 1
        fi
    done
    return 0
}

_cp2k_write_input_maybe_faster() {
    local output=$1 project=$2 basis_file=$3 charge=$4 multiplicity=$5
    local functional=$6 subsys=$7 scf_guess=$8 restart_file=${9:-}

    local uks_line=""
    local restart_line=""

    # Use unrestricted Kohn-Sham for open-shell calculations or
    # whenever METHOD begins with "u".
    if [ "$multiplicity" -gt 1 ] 2>/dev/null || [[ "$(_lower "$METHOD")" == u* ]]; then
        uks_line="    UKS T"
    fi

    # Optional wavefunction restart.
    if [ -n "$restart_file" ]; then
        restart_line="    WFN_RESTART_FILE_NAME $restart_file"
    fi

    cat > "$output" <<EOF_CP2K
! Generated directly by instalation_July19/lamaGOET.sh
! Periodic all-electron GAPW single-point energy calculation.

&GLOBAL
  PROJECT $project
  RUN_TYPE ENERGY
  PRINT_LEVEL LOW
&END GLOBAL

&FORCE_EVAL
  METHOD QUICKSTEP

  &DFT
    BASIS_SET_FILE_NAME $basis_file
    CHARGE $charge
    MULTIPLICITY $multiplicity
$uks_line
$restart_line

    ! All-electron calculation using GAPW.
    ! The included SUBSYS file must contain:
    !   BASIS_SET <...-ae>
    !   POTENTIAL ALL

    &QS
      METHOD GAPW
      EPS_DEFAULT ${CP2K_EPS_DEFAULT:-1.0E-10}
      GAPW_ACCURATE_XCINT T
    &END QS

    ! Real-space integration grid.
    ! These values should be convergence-tested for the
    ! chosen all-electron basis.
    &MGRID
      CUTOFF ${CP2K_CUTOFF:-800}
      REL_CUTOFF ${CP2K_REL_CUTOFF:-60}
      NGRIDS ${CP2K_NGRIDS:-4}
    &END MGRID

    ! Three-dimensional periodic crystal.
    &POISSON
      PERIODIC XYZ
    &END POISSON

    ! Periodic Brillouin-zone sampling.
    ! Default: 2 x 2 x 2 Monkhorst-Pack grid.
    &KPOINTS
      SCHEME MONKHORST-PACK ${CP2K_KPOINT_GRID:-2 2 2}
      GAMMA_CENTERED T
      SYMMETRY T
    &END KPOINTS

    ! Ground-state SCF calculation.
    &SCF
      MAX_SCF ${CP2K_MAX_SCF:-100}
      EPS_SCF ${CP2K_EPS_SCF:-1.0E-8}
      SCF_GUESS $scf_guess

      ! Standard diagonalization is appropriate for the
      ! insulating molecular crystal considered here.
      &DIAGONALIZATION
        ALGORITHM STANDARD
      &END DIAGONALIZATION

      ! Robust density mixing.
      &MIXING
        METHOD BROYDEN_MIXING
        ALPHA ${CP2K_MIXING_ALPHA:-0.20}
        NBROYDEN ${CP2K_MIXING_NBROYDEN:-8}
      &END MIXING

      ! Keep restart capability for subsequent calculations.
      &PRINT
        &RESTART ON
          BACKUP_COPIES 1
        &END RESTART
      &END PRINT

    &END SCF

    &XC
      &XC_FUNCTIONAL $functional
      &END XC_FUNCTIONAL
    &END XC

  &END DFT

  @INCLUDE '$subsys'

&END FORCE_EVAL
EOF_CP2K
}


_cp2k_write_input() {
    local output=$1 project=$2 basis_file=$3 charge=$4 multiplicity=$5
    local functional=$6 subsys=$7 scf_guess=$8 restart_file=${9:-}
    local uks_line="" restart_line=""

    if [ "$multiplicity" -gt 1 ] 2>/dev/null || [[ "$(_lower "$METHOD")" == u* ]]; then
        uks_line="    UKS T"
    fi
    if [ -n "$restart_file" ]; then
        restart_line="    WFN_RESTART_FILE_NAME $restart_file"
    fi

    cat > "$output" <<EOF_CP2K
! Generated directly by instalation_July19/lamaGOET.sh
! Periodic all-electron GAPW density for Tonto/lamaGOET HAR.
&GLOBAL
  PROJECT $project
  RUN_TYPE ENERGY
  PRINT_LEVEL MEDIUM
&END GLOBAL

&FORCE_EVAL
  METHOD QUICKSTEP
  &DFT
    BASIS_SET_FILE_NAME $basis_file
    CHARGE $charge
    MULTIPLICITY $multiplicity
$uks_line
$restart_line
    &QS
      METHOD GAPW
      EPS_DEFAULT ${CP2K_EPS_DEFAULT:-1.0E-12}
      GAPW_ACCURATE_XCINT T
    &END QS
    &MGRID
      CUTOFF ${CP2K_CUTOFF:-1200}
      REL_CUTOFF ${CP2K_REL_CUTOFF:-80}
      NGRIDS 5
    &END MGRID
    &POISSON
      PERIODIC XYZ
    &END POISSON
    &KPOINTS
      SCHEME MONKHORST-PACK ${CP2K_KPOINT_GRID:-2 2 2}
      GAMMA_CENTERED T
      SYMMETRY FALSE
      FULL_GRID TRUE
    &END KPOINTS
    &SCF
      MAX_SCF ${CP2K_MAX_SCF:-100}
      EPS_SCF ${CP2K_EPS_SCF:-1.0E-8}
      SCF_GUESS $scf_guess
      ADDED_MOS ${CP2K_ADDED_MOS:-20}
      &DIAGONALIZATION
        ALGORITHM STANDARD
      &END DIAGONALIZATION
      &MIXING
        METHOD BROYDEN_MIXING
        ALPHA 0.20
        NBROYDEN 8
      &END MIXING
      &PRINT
        &RESTART ON
          BACKUP_COPIES 1
        &END RESTART
      &END PRINT
    &END SCF
    &XC
      &XC_FUNCTIONAL $functional
      &END XC_FUNCTIONAL
    &END XC
    &PRINT
      &MO_KP ON
        AO_EXPORT_TYPE GTO_BASIS
        NDIGITS 15
        UNIT BOHR
        FILENAME =$project.mokp
        ADD_LAST NO
      &END MO_KP
    &END PRINT
  &END DFT
  @INCLUDE '$subsys'
&END FORCE_EVAL
EOF_CP2K
}

_cp2k_run() {
    local cp2k_bin=$1 input=$2 output=$3 main_log=${4:-}
    local executable_name ranks threads rc output_name verbose

    executable_name=$(basename "$cp2k_bin")
    output_name=$(basename "$output")
    ranks=${CP2K_MPI_RANKS:-${NUMPROC:-1}}
    threads=${CP2K_NUM_THREADS:-${NUMPROC:-1}}
    verbose=${CP2K_TERMINAL_VERBOSE:-true}

    _cp2k_prepare_runtime "$cp2k_bin" || return 1

    if [ -n "${CP2K_RUN_COMMAND:-}" ]; then
        CP2K_INPUT=$(basename "$input") \
        CP2K_OUTPUT="$output_name" \
        CP2K_EXECUTABLE="$cp2k_bin" \
        bash -lc "$CP2K_RUN_COMMAND" > "$output_name" 2>&1
        rc=$?

    elif [[ "$executable_name" == *.psmp || "$executable_name" == cp2k.psmp ]]; then
        _cp2k_require_command mpirun || return 1

        OMP_NUM_THREADS=${CP2K_NUM_THREADS:-1} \
        OMP_PROC_BIND=${OMP_PROC_BIND:-spread} \
        OMP_PLACES=${OMP_PLACES:-cores} \
        mpirun -n "$ranks" "$cp2k_bin" -i "$(basename "$input")" \
            > "$output_name" 2>&1
        rc=$?

    else
        OMP_NUM_THREADS="$threads" \
        OMP_PROC_BIND=${OMP_PROC_BIND:-spread} \
        OMP_PLACES=${OMP_PLACES:-cores} \
        "$cp2k_bin" -i "$(basename "$input")" \
            > "$output_name" 2>&1
        rc=$?
    fi

    return "$rc"

}

# Complete CP2K output is retained in each per-cycle *.cp2k.out file and is
# streamed live by default so cluster/submission logs remain inspectable.
# Set CP2K_TERMINAL_VERBOSE=false only when a compact terminal log is required.
_cp2k_run_original_unwanted_terminal_output() {
    local cp2k_bin=$1 input=$2 output=$3 main_log=${4:-}
    local executable_name ranks threads rc output_name verbose
    executable_name=$(basename "$cp2k_bin")
    output_name=$(basename "$output")
    ranks=${CP2K_MPI_RANKS:-${NUMPROC:-1}}
    threads=${CP2K_NUM_THREADS:-${NUMPROC:-1}}
    verbose=${CP2K_TERMINAL_VERBOSE:-true}

    _cp2k_prepare_runtime "$cp2k_bin" || return 1

    if [ -n "${CP2K_RUN_COMMAND:-}" ]; then
        if [[ "$(_lower "$verbose")" == "true" ]]; then
            set -o pipefail
            CP2K_INPUT=$(basename "$input") \
            CP2K_OUTPUT="$output_name" \
            CP2K_EXECUTABLE="$cp2k_bin" \
            bash -lc "$CP2K_RUN_COMMAND" 2>&1 | tee "$output_name"
            rc=${PIPESTATUS[0]}
            set +o pipefail
        else
            CP2K_INPUT=$(basename "$input") \
            CP2K_OUTPUT="$output_name" \
            CP2K_EXECUTABLE="$cp2k_bin" \
            bash -lc "$CP2K_RUN_COMMAND" > "$output_name" 2>&1
            rc=$?
        fi
    elif [[ "$executable_name" == *.psmp || "$executable_name" == cp2k.psmp ]]; then
        _cp2k_require_command mpirun || return 1
        if [[ "$(_lower "$verbose")" == "true" ]]; then
            set -o pipefail
            OMP_NUM_THREADS=${CP2K_NUM_THREADS:-1} \
            OMP_PROC_BIND=${OMP_PROC_BIND:-spread} \
            OMP_PLACES=${OMP_PLACES:-cores} \
            mpirun -n "$ranks" "$cp2k_bin" -i "$(basename "$input")" 2>&1 \
                | tee "$output_name"
            rc=${PIPESTATUS[0]}
            set +o pipefail
        else
            OMP_NUM_THREADS=${CP2K_NUM_THREADS:-1} \
            OMP_PROC_BIND=${OMP_PROC_BIND:-spread} \
            OMP_PLACES=${OMP_PLACES:-cores} \
            mpirun -n "$ranks" "$cp2k_bin" -i "$(basename "$input")" \
                > "$output_name" 2>&1
            rc=$?
        fi
    else
        if [[ "$(_lower "$verbose")" == "true" ]]; then
            set -o pipefail
            OMP_NUM_THREADS="$threads" \
            OMP_PROC_BIND=${OMP_PROC_BIND:-spread} \
            OMP_PLACES=${OMP_PLACES:-cores} \
            "$cp2k_bin" -i "$(basename "$input")" 2>&1 \
                | tee "$output_name"
            rc=${PIPESTATUS[0]}
            set +o pipefail
        else
            OMP_NUM_THREADS="$threads" \
            OMP_PROC_BIND=${OMP_PROC_BIND:-spread} \
            OMP_PLACES=${OMP_PLACES:-cores} \
            "$cp2k_bin" -i "$(basename "$input")" \
                > "$output_name" 2>&1
            rc=$?
        fi
    fi

    return "$rc"
}

# Generate one periodic CP2K density and convert *.kp + *.mokp to Tonto XML.
TONTO_TO_CP2K() {
    local cp2k_bin bridge cif_converter basis_file basis_label functional geometry
    local cycle_dir previous_dir subsys input output scf_guess restart_file=""
    local kp_file mokp_file basis_mapping main_log converter_log bridge_log next_cycle
    local basis_args=()

    _cp2k_require_command python3 || return 1
    _cp2k_require_command realpath || return 1
    CP2K_VALIDATE_LAMAGOET_MODE || return 1

    cp2k_bin=$(_cp2k_resolve_executable "${CP2K_BIN:-${SCFCALC_BIN:-}}") || return 1
    bridge=${CP2K_TONTO_BRIDGE:-$LAMAGOET_SCRIPT_DIR/cp2k_tonto_bridge.py}
    cif_converter=${CP2K_CIF_TO_SUBSYS:-$LAMAGOET_SCRIPT_DIR/cif_to_cp2k.py}
    basis_file=${CP2K_BASIS_SET_FILE:-}
    basis_label=${CP2K_BASIS_SET:-${BASISSETG:-}}

    _cp2k_require_file "$bridge" || return 1
    _cp2k_require_file "$cif_converter" || return 1
    [ -n "$basis_file" ] || {
        _cp2k_error "CP2K_BASIS_SET_FILE must name an all-electron CP2K basis file"
        return 1
    }
    _cp2k_require_file "$basis_file" || return 1
    [ -n "$basis_label" ] || {
        _cp2k_error "CP2K_BASIS_SET must name an all-electron CP2K basis"
        return 1
    }

    bridge=$(_cp2k_abspath "$bridge") || return 1
    cif_converter=$(_cp2k_abspath "$cif_converter") || return 1
    basis_file=$(_cp2k_abspath "$basis_file") || return 1
    geometry=$(_cp2k_geometry_cif) || return 1
    geometry=$(_cp2k_abspath "$geometry") || return 1
    functional=$(_cp2k_functional) || return 1
    main_log=$(_cp2k_abspath "${JOBNAME}.lst") || return 1

    next_cycle=$((${I:-0} + 1))
    if [ "$next_cycle" -gt 1 ]; then
        _cp2k_log "Preparing periodic geometry for CP2K cycle number $next_cycle"
    fi
    I=$next_cycle
    cycle_dir="${I}.CP2K.cycle.${JOBNAME}"
    mkdir -p "$cycle_dir" || return 1
    cycle_dir=$(_cp2k_abspath "$cycle_dir") || return 1
    subsys="$cycle_dir/${I}.${JOBNAME}.subsys.inc"
    input="$cycle_dir/${I}.${JOBNAME}.cp2k.inp"
    output="$cycle_dir/${I}.${JOBNAME}.cp2k.out"

    for basis_mapping in ${CP2K_BASIS_MAP:-}; do
        basis_args+=(--basis-map "$basis_mapping")
    done
    converter_log="$cycle_dir/${I}.${JOBNAME}.cif-to-cp2k.log"
    if ! python3 "$cif_converter" \
        --cif "$geometry" \
        --output "$subsys" \
        --basis "$basis_label" \
        --potential ALL \
        "${basis_args[@]}" > "$converter_log" 2>&1; then
        tail -n 20 "$converter_log" >&2
        _cp2k_error "periodic-geometry preparation failed; inspect $converter_log"
        return 1
    fi

    scf_guess=ATOMIC
    if [ "$I" -gt 1 ]; then
        previous_dir="$((I - 1)).CP2K.cycle.${JOBNAME}"
        kp_file=$(find "$previous_dir" -maxdepth 1 -type f -name '*RESTART*.kp' -print 2>/dev/null | sort | tail -1)
        if [ -n "$kp_file" ]; then
            restart_file="$cycle_dir/$(basename "$kp_file")"
            cp "$kp_file" "$restart_file" || return 1
            restart_file=$(_cp2k_abspath "$restart_file") || return 1
            scf_guess=RESTART
        fi
    fi

    _cp2k_write_input "$input" "$JOBNAME" "$basis_file" \
        "${CP2K_CELL_CHARGE:-0}" "${CP2K_CELL_MULTIPLICITY:-1}" \
        "$functional" "$subsys" "$scf_guess" "$restart_file" || return 1

    CP2K_LAST_CYCLE_DIR=$cycle_di
    CP2K_LAST_INPUT=$input
    export CP2K_LAST_CYCLE_DIR CP2K_LAST_INPUT I

    if [[ "${CP2K_PREPARE_ONLY:-false}" == "true" ]]; then
        _cp2k_log "CP2K input prepared: $input"
        _cp2k_log "Expanded periodic cell: $subsys"
        return 0
    fi

    _cp2k_log "Running CP2K, cycle number $I"
    _cp2k_log_detail "Periodic geometry: $geometry"
    _cp2k_log_detail "CP2K input: $input"
    if ! (
        cd "$cycle_dir" || exit 1
        _cp2k_run "$cp2k_bin" "$input" "$output" "$main_log"
    ); then
        _cp2k_error "CP2K cycle number $I finished with error; inspect $output"
        return 1
    fi

    if ! grep -q 'PROGRAM ENDED AT' "$output"; then
        _cp2k_error "CP2K cycle number $I did not terminate normally; inspect $output"
        return 1
    fi
    _cp2k_log "CP2K cycle number $I ended"

    kp_file=$(find "$cycle_dir" -maxdepth 1 -type f -name '*RESTART*.kp' -print | sort | tail -1)
    mokp_file=$(find "$cycle_dir" -maxdepth 1 -type f -name '*.mokp' -print | sort | tail -1)
    [ -n "$kp_file" ] || {
        _cp2k_error "CP2K did not produce a *RESTART*.kp density restart"
        return 1
    }
    [ -n "$mokp_file" ] || {
        _cp2k_error "CP2K did not produce MO_KP .mokp metadata; use CP2K 2026.2+ and a non-Gamma k-point calculation"
        return 1
    }

    CP2K_PERIODIC_XML="$cycle_dir/${I}.${JOBNAME}.cp2k.xml"
    CP2K_TONTO_BASIS_DIR="$cycle_dir"
    CP2K_TONTO_BASIS_NAME=${CP2K_TONTO_BASIS_NAME:-cp2k-generated}
    CP2K_TONTO_BASIS_FILE="$cycle_dir/$CP2K_TONTO_BASIS_NAME"
    CP2K_PERIODIC_MANIFEST="$cycle_dir/${I}.${JOBNAME}.cp2k-tonto.json"
    CP2K_LAST_OUTPUT=$output

    bridge_log="$cycle_dir/${I}.${JOBNAME}.cp2k-tonto-bridge.log"
    if ! python3 "$bridge" \
        --kp "$kp_file" \
        --mokp "$mokp_file" \
        --xml "$CP2K_PERIODIC_XML" \
        --basis "$CP2K_TONTO_BASIS_FILE" \
        --basis-name "$CP2K_TONTO_BASIS_NAME" \
        --reference-cif "$geometry" \
        --manifest "$CP2K_PERIODIC_MANIFEST" > "$bridge_log" 2>&1; then
        tail -n 20 "$bridge_log" >&2
        _cp2k_error "CP2K-to-Tonto conversion failed; inspect $bridge_log"
        return 1
    fi

    CP2K_LAST_ENERGY=$(awk '/ENERGY\| Total FORCE_EVAL/{value=$NF} END{print value}' "$output")
    CP2K_LAST_RMSD=$(awk '/RMS.*density|RMS.*Density/{value=$NF} END{print value}' "$output")
    [ -n "$CP2K_LAST_ENERGY" ] || {
        _cp2k_error "could not extract the final CP2K FORCE_EVAL energy from $output"
        return 1
    }

    export CP2K_PERIODIC_XML CP2K_TONTO_BASIS_DIR CP2K_TONTO_BASIS_NAME
    export CP2K_TONTO_BASIS_FILE CP2K_PERIODIC_MANIFEST CP2K_LAST_OUTPUT
    export CP2K_LAST_ENERGY CP2K_LAST_RMSD
}

CP2K_TONTO_PERIODIC_SETUP() {
    local slater_name slater_source
    local tonto_exec tonto_root candidate

    [ -n "${CP2K_PERIODIC_XML:-}" ] || {
        _cp2k_error "CP2K_PERIODIC_XML is unset; run TONTO_TO_CP2K first"
        return 1
    }

    _cp2k_require_file "$CP2K_PERIODIC_XML" || return 1
    _cp2k_require_file "$CP2K_TONTO_BASIS_FILE" || return 1

    # The CP2K bridge creates a Gaussian AO basis.  Tonto additionally
    # requires a Slater pro-atom library for Hirshfeld references.
    slater_name=${CP2K_TONTO_SLATER_BASIS_NAME:-Thakkar}
    slater_source=${CP2K_TONTO_SLATER_BASIS_FILE:-}
    tonto_exec=${TONTO:-${TONTO_BIN:-}}

    # Optional explicit Tonto basis-library directory.
    if [ -z "$slater_source" ] && [ -n "${TONTO_BASIS_DIR:-}" ]; then
        candidate="$TONTO_BASIS_DIR/$slater_name"
        if [ -f "$candidate" ]; then
            slater_source=$candidate
        fi
    fi

    # Derive the source checkout from .../build/tonto.
    if [ -z "$slater_source" ] && [ -n "$tonto_exec" ]; then
        case "$tonto_exec" in
            */*) ;;
            *) tonto_exec=$(command -v "$tonto_exec" 2>/dev/null || true) ;;
        esac

        if [ -n "$tonto_exec" ]; then
            tonto_root=$(
                cd "$(dirname "$tonto_exec")/.." 2>/dev/null &&
                pwd -P
            ) || tonto_root=

            if [ -n "$tonto_root" ]; then
                candidate="$tonto_root/basis_sets/$slater_name"
                if [ -f "$candidate" ]; then
                    slater_source=$candidate
                fi
            fi
        fi
    fi

    # Known source-checkout fallbacks.
    if [ -z "$slater_source" ]; then
        for candidate in \
            "$HOME/tonto_CP2K/basis_sets/$slater_name" \
            "$HOME/tonto/basis_sets/$slater_name"
        do
            if [ -f "$candidate" ]; then
                slater_source=$candidate
                break
            fi
        done
    fi

    if [ -z "$slater_source" ] || [ ! -f "$slater_source" ]; then
        _cp2k_error "Tonto Slater basis library '$slater_name' was not found"
        _cp2k_error "expected, for example: $HOME/tonto_CP2K/basis_sets/$slater_name"
        _cp2k_error "or set CP2K_TONTO_SLATER_BASIS_FILE explicitly"
        return 1
    fi

    # basis_directory applies to both Gaussian and Slater libraries.
    # Stage both files in the CP2K cycle directory.
    cp -f -- \
        "$slater_source" \
        "$CP2K_TONTO_BASIS_DIR/$slater_name" || {
        _cp2k_error "could not stage Slater basis $slater_source"
        return 1
    }

    CP2K_TONTO_SLATER_BASIS_NAME=$slater_name
    CP2K_TONTO_SLATER_BASIS_FILE="$CP2K_TONTO_BASIS_DIR/$slater_name"
    export CP2K_TONTO_SLATER_BASIS_NAME
    export CP2K_TONTO_SLATER_BASIS_FILE

    _cp2k_require_file "$CP2K_TONTO_SLATER_BASIS_FILE" || return 1

    {
        echo "   ! Periodic all-electron density generated by CP2K"
        echo "   basis_directory= $CP2K_TONTO_BASIS_DIR"
        echo "   basis_name= $CP2K_TONTO_BASIS_NAME"
        echo "   slaterbasis_name= $CP2K_TONTO_SLATER_BASIS_NAME"
        echo "   c23_xml_file_name= $CP2K_PERIODIC_XML"
        echo "   process_cif_and_c23_xml"
        echo ""
    } >> stdin

    _cp2k_log_detail "Tonto Gaussian basis: $CP2K_TONTO_BASIS_FILE"
    _cp2k_log_detail "Tonto Slater basis: $CP2K_TONTO_SLATER_BASIS_FILE"
}

CP2K_TONTO_SCFDATA() {
    local periodic_functional
    periodic_functional=$(_cp2k_functional) || return 1
    periodic_functional=$(_upper "$periodic_functional")

    {
        echo "   ! The periodic molecular density uses CP2K $periodic_functional."
        echo "   ! Periodic oc-crystal23 Hirshfeld weights use Tonto's Thakkar"
        echo "   ! spherical pro-atoms, not a matching Tonto DFT free-atom SCF."
        echo "   ! This legacy BLYP SCF metadata only satisfies make_HA_inputs;"
        echo "   ! it does not replace or mix the imported CP2K density."
        echo "   scfdata= {"
        echo "      initial_density= promolecule"
        echo "      kind= rks"
        echo "      dft_exchange_functional= becke88"
        echo "      dft_correlation_functional= lyp"
        echo "      output= false"
        echo "      use_SC_cluster_charges= false"
        echo "   }"
        echo ""
    } >> stdin
}

CP2K_CHECK_ENERGY() {
    local previous previous_cycle
    [ -n "${CP2K_LAST_ENERGY:-}" ] || {
        _cp2k_error "CP2K_LAST_ENERGY is unset"
        return 1
    }

    if [ -z "${ENERGIA:-}" ]; then
        ENERGIA=$CP2K_LAST_ENERGY
        RMSD=${CP2K_LAST_RMSD:-0.0}
        ENERGIA2=$ENERGIA
        RMSD2=$RMSD
        DE=0.0
    else
        previous=${ENERGIA2:-$ENERGIA}
        ENERGIA2=$CP2K_LAST_ENERGY
        RMSD2=${CP2K_LAST_RMSD:-0.0}
        DE=$(awk -v a="$ENERGIA2" -v b="$previous" 'BEGIN { printf "%.12f", a-b }')
    fi

    export ENERGIA ENERGIA2 RMSD RMSD2 DE
    _cp2k_log "CP2K cycle number $I, final energy is: $ENERGIA2, RMSD is: $RMSD2"
    if [ "$I" -gt 1 ]; then
        previous_cycle=$((I - 1))
        _cp2k_log "Delta E (cycle  $I - $previous_cycle): $DE"
    fi
}

# LAMAGOET CP2K LST FIT SUMMARY v1.1
# Write one compact .lst row for a Tonto fit and bind it explicitly to the
# CP2K wavefunction cycle that was passed into that fit.  Do not infer this
# association from I == J: other lamaGOET workflows can contain preparation,
# cluster-charge, structure-completion or final-residual program calls that do
# not advance the two counters in lockstep.
CP2K_WRITE_FIT_ROW() {
    local wavefunction_cycle=${1:-${I:-0}}
    local fit_data fit_iter initial_chi final_chi r_factor rw_facto
    local max_shift max_atom max_param n_params n_eigs
    local energy rmsd delta table_cycle

    [ -f stdout ] || {
        _cp2k_error "Tonto stdout is missing while preparing the CP2K fit summary"
        return 1
    }
    [[ "$wavefunction_cycle" =~ ^[0-9]+$ ]] && [ "$wavefunction_cycle" -ge 1 ] || {
        _cp2k_error "invalid CP2K wavefunction cycle '$wavefunction_cycle' for the fit summary"
        return 1
    }

    fit_data=$(awk '
        /^Begin rigid-atom fit/ { in_fit=1; next }
        in_fit && /^Rigid-atom fit results/ { in_fit=0 }
        in_fit && $1 ~ /^[0-9]+$/ && NF >= 10 {
            count++
            if (count == 1) initial_chi=$2
            fit_iter=$1
            final_chi=$2
            r_factor=$3
            rw_factor=$4
            n_params=$9
            n_eigs=$10
            shift=$5 + 0.0
            abs_shift=(shift < 0.0 ? -shift : shift)
            if (!have_max || abs_shift > max_shift) {
                have_max=1; max_shift=abs_shift; max_atom=$7; max_param=$8
            }
        }
        END {
            if (count == 0) exit 2
            printf "%s\t%s\t%s\t%s\t%s\t%.6f\t%s\t%s\t%s\t%s\n", \
                   fit_iter, initial_chi, final_chi, r_factor, rw_factor, \
                   max_shift, max_atom, max_param, n_params, n_eigs
        }
    ' stdout) || {
        _cp2k_error "could not parse the rigid-atom fit table from Tonto stdout"
        return 1
    }

    IFS=$'\t' read -r \
        fit_iter initial_chi final_chi r_factor rw_factor \
        max_shift max_atom max_param n_params n_eigs <<< "$fit_data"

    table_cycle=${J:-0}
    energy=${CP2K_LAST_ENERGY:-${ENERGIA2:-n/a}}
    rmsd=${CP2K_LAST_RMSD:-${RMSD2:-n/a}}
    delta=${DE:-0.000000000000}
    [[ -n "$rmsd" ]] || rmsd=n/a

    if [ "$table_cycle" -eq 1 ] && [ "${CP2K_LST_MAPPING_NOTE_WRITTEN:-false}" != true ]; then
        printf "# CP2K rows: Cycle = Tonto ha_fit cycle; Energy/RMSD = CP2K wavefunction used by that fit.\n" \
            >> "${JOBNAME}.lst"
        CP2K_LST_MAPPING_NOTE_WRITTEN=true
    fi

    printf " %2d    %3s    %14s %14s %15s %15s %14s  %-6s %-6s %8s %9s %15s %12s %18s\n" \
        "$table_cycle" "$fit_iter" "$initial_chi" "$final_chi" \
        "$r_factor" "$rw_factor" "$max_shift" "$max_atom" "$max_param" \
        "$n_params" "$n_eigs" "$energy" "$rmsd" "$delta" \
        >> "${JOBNAME}.lst"

    _cp2k_log "Recorded Tonto fit cycle $table_cycle with CP2K wavefunction cycle $wavefunction_cycle"
}

CP2K_ASSERT_TONTO_FIT() {
    if ! grep -q '^Begin rigid-atom fit' stdout || ! grep -q '^Rigid-atom fit results' stdout; then
        _cp2k_error "Tonto did not perform a Hirshfeld atom fit; inspect stdin and stdout"
        return 1
    fi
    [ -n "${MAXSHIFT:-}" ] || {
        _cp2k_error "Tonto fit completed but MAXSHIFT could not be read from stdout"
        return 1
    }
    _cp2k_log "Tonto HAR cycle $J complete: maximum shift/esd = $MAXSHIFT"
}

CP2K_FINAL_RESIDUALS() {
    _cp2k_log "Calculating residual density at final geometry"
    TONTO_HEADER
    PROCESS_CIF
    DEFINE_JOB_NAME
    CP2K_TONTO_PERIODIC_SETUP || return 1
    CRYSTAL_BLOCK
    PUT_GEOM
    {
        echo "   make_structure_factors"
        echo ""
        echo "   put_minmax_residual_density"
        echo ""
        echo "   put_fitting_plots"
        echo ""
        echo "}"
    } >> stdin

    rm -f stdout stde
    local tonto_status=0
    if [[ "${NUMPROCTONTO:-1}" != "1" ]]; then
        mpirun -n "$NUMPROCTONTO" "$TONTO" || tonto_status=$?
    else
        "$TONTO" || tonto_status=$?
    fi
    # CLEANUP FIX V1: validate CP2K residual section, not merely normal shutdown.
    if [[ "$tonto_status" -ne 0 ]] || ! grep -q '^Unit cell residual density:' stdout 2>/dev/null; then
        _cp2k_error "final Tonto residual calculation failed; inspect stdin and stdout"
        return 1
    fi
    mkdir -p "final.CP2K.residuals.${JOBNAME}"
    cp stdin "final.CP2K.residuals.${JOBNAME}/stdin"
    cp stdout "final.CP2K.residuals.${JOBNAME}/stdout"
    # CLEANUP FIX V1: archive final CP2K residual products.
    for artifact in "${JOBNAME}.fractional.cif1" "${JOBNAME}.cartesian.cif2" "${JOBNAME}.residual_density,cell.cube"; do
        if [[ -f "$artifact" ]]; then
            cp "$artifact" "final.CP2K.residuals.${JOBNAME}/$artifact"
        fi
    done
    awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for(d=b-2;d<c-1;++d)print a[d]}' stdout \
        | tee -a "${JOBNAME}.lst"
}

CP2K_RUN_HAR() {
    local duration fit_wfn_cycle
    local final_density_current=false
    CP2K_VALIDATE_LAMAGOET_MODE || return 1
    _cp2k_log "Starting periodic CP2K Hirshfeld atom refinement"

    # Initial periodic wavefunction/density at the CIF geometry.
    TONTO_TO_CP2K || return 1
    CP2K_CHECK_ENERGY || return 1
    CHECK_WAVEFUNCTION_STALL "$ENERGIA2" "$RMSD2"

    # First Tonto Hirshfeld atom fit. Bind the row to the CP2K density
    # that is about to be passed to Tonto; do not infer the mapping from I/J.
    fit_wfn_cycle=$I
    SCF_TO_TONTO || return 1
    CP2K_ASSERT_TONTO_FIT || return 1
    CP2K_WRITE_FIT_ROW "$fit_wfn_cycle" || return 1

    while _cp2k_float_gt "$MAXSHIFT" "${CONVTOL:-0.01}" && [ "$J" -lt "${MAXCYCLE:-20}" ]; do
        TONTO_TO_CP2K || return 1
        CP2K_CHECK_ENERGY || return 1
        CHECK_WAVEFUNCTION_STALL "$ENERGIA2" "$RMSD2"
        if [[ "${HAR_WAVEFUNCTION_STALLED:-false}" == "true" ]]; then
            final_density_current=true
            _cp2k_log "Refinement ended because the periodic SCF energy is stationary."
            break
        fi
        fit_wfn_cycle=$I
        SCF_TO_TONTO || return 1
        CP2K_ASSERT_TONTO_FIT || return 1
        CP2K_WRITE_FIT_ROW "$fit_wfn_cycle" || return 1
    done

    if [[ "${HAR_WAVEFUNCTION_STALLED:-false}" == "true" ]]; then
        _cp2k_log "The last CP2K density already corresponds to the final refined geometry."
    elif _cp2k_float_gt "$MAXSHIFT" "${CONVTOL:-0.01}"; then
        _cp2k_log "Refinement ended after the maximum number of cycles without convergence."
    else
        _cp2k_log "Refinement ended. The geometry has converged."
    fi

    # Recalculate the periodic density at the final refined geometry, then compute
    # residuals. Therefore the residual-density message can only appear after HAR.
    if [[ "$final_density_current" != "true" ]]; then
        TONTO_TO_CP2K || return 1
        CP2K_CHECK_ENERGY || return 1
    else
        _cp2k_log "Reusing the current converged CP2K density for final residuals."
    fi
    CP2K_FINAL_RESIDUALS || return 1

    _cp2k_log "Periodic CP2K HAR finished"
    _cp2k_log "Final CP2K energy: ${ENERGIA2:-unknown} Ha"
    _cp2k_log "Final maximum shift/esd: ${MAXSHIFT:-unknown}"
    duration=$SECONDS
    _cp2k_log "$((duration / 86400)) days, $(((duration / 3600) % 24)) hours, $(((duration / 60) % 60)) minutes and $((duration % 60)) seconds elapsed."
}

# CLI modes are limited to preparing/running one CP2K density; they do not set
# TESTS and they do not replace the normal GUI HAR workflow.
_cp2k_cli() {
    local mode=$1 cif=${2:-} job=${3:-cp2k_example}
    [ -n "$cif" ] || {
        echo "Usage: $(basename "$0") $mode CIF [JOBNAME]" >&2
        return 2
    }
    CIF=$cif
    JOBNAME=$job
    I=0
    J=0
    METHOD=${METHOD:-pbe}
    SCFCALCPROG=CP2K
    POWDER_HAR=false
    SCCHARGES=false
    COMPLETESTRUCT=false
    EXPLICITMOL=false
    DEFRAGNETW=false
    XCWONLY=false
    PLOT_TONTO=false
    XWR=false
    case "$mode" in
        --cp2k-preflight) CP2K_PREPARE_ONLY=true ;;
        --cp2k-smoke-test) CP2K_PREPARE_ONLY=false ;;
        *) return 2 ;;
    esac
    TONTO_TO_CP2K
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    case "${1:-}" in
        --cp2k-preflight|--cp2k-smoke-test)
            _cp2k_mode=$1
            shift
            _cp2k_cli "$_cp2k_mode" "$@"
            exit $?
            ;;
    esac
fi
# END LAMAGOET CP2K SINGLE-FILE BACKEND

REQUIRE_ZENITY(){
	# Some inputs are still collected with a zenity pop-up. zenity is part of
	# the old GTK stack and is not present on macOS, so say plainly what is
	# missing and how to supply it by hand rather than dying with
	# "zenity: command not found" halfway through a run.
	local what=$1 file=$2
	command -v zenity >/dev/null 2>&1 && return 0
	{
		echo
		echo "lamaGOET needs $what, and asks for it with a zenity window."
		echo "zenity is not installed, so it cannot ask."
		echo
		echo "Either install it:"
		case "$(uname -s)" in
			Darwin) echo "    brew install zenity" ;;
			*)      echo "    sudo apt-get install zenity" ;;
		esac
		echo
		echo "or create $file in this directory yourself and run lamaGOET again."
		echo
	} >&2
	return 1
}

SPACEGROUPMENU(){
	SPACEGROUPARRAY=(
        "1        = p 1          =  p 1            "
	"2        = p -1         =  -p 1           "
	"3:b      = p 1 2 1      =  p 2y           "
	"3:b      = p 2          =  p 2y           "
	"3:c      = p 1 1 2      =  p 2            "
	"3:a      = p 2 1 1      =  p 2x           "
	"4:b      = p 1 21 1     =  p 2yb          "
	"4:b      = p 1 21 1     =  p 2y1          "
	"4:b      = p 21         =  p 2yb          "
	"4:c      = p 1 1 21     =  p 2c           "
	"4:c      = p 1 1 21     =  p 21           "
	"4:a      = p 21 1 1     =  p 2xa          "
	"4:a      = p 21 1 1     =  p 2x1          "
	"5:b1     = c 1 2 1      =  c 2y           "
	"5:b1     = c 2          =  c 2y           "
	"5:b2     = a 1 2 1      =  a 2y           "
	"5:b3     = i 1 2 1      =  i 2y           "
	"5:c1     = a 1 1 2      =  a 2            "
	"5:c2     = b 1 1 2      =  b 2            "
	"5:c3     = i 1 1 2      =  i 2            "
	"5:a1     = b 2 1 1      =  b 2x           "
	"5:a2     = c 2 1 1      =  c 2x           "
	"5:a3     = i 2 1 1      =  i 2x           "
	"6:b      = p 1 m 1      =  p -2y          "
	"6:b      = p m          =  p -2y          "
	"6:c      = p 1 1 m      =  p -2           "
	"6:a      = p m 1 1      =  p -2x          "
	"7:b1     = p 1 c 1      =  p -2yc         "
	"7:b1     = p c          =  p -2yc         "
	"7:b2     = p 1 n 1      =  p -2yac        "
	"7:b2     = p n          =  p -2yac        "
	"7:b3     = p 1 a 1      =  p -2ya         "
	"7:b3     = p a          =  p -2ya         "
	"7:c1     = p 1 1 a      =  p -2a          "
	"7:c2     = p 1 1 n      =  p -2ab         "
	"7:c3     = p 1 1 b      =  p -2b          "
	"7:a1     = p b 1 1      =  p -2xb         "
	"7:a2     = p n 1 1      =  p -2xbc        "
	"7:a3     = p c 1 1      =  p -2xc         "
	"8:b1     = c 1 m 1      =  c -2y          "
	"8:b1     = c m          =  c -2y          "
	"8:b2     = a 1 m 1      =  a -2y          "
	"8:b3     = i 1 m 1      =  i -2y          "
	"8:b3     = i m          =  i -2y          "
	"8:c1     = a 1 1 m      =  a -2           "
	"8:c2     = b 1 1 m      =  b -2           "
	"8:c3     = i 1 1 m      =  i -2           "
	"8:a1     = b m 1 1      =  b -2x          "
	"8:a2     = c m 1 1      =  c -2x          "
	"8:a3     = i m 1 1      =  i -2x          "
	"9:b1     = c 1 c 1      =  c -2yc         "
	"9:b1     = c c          =  c -2yc         "
	"9:b2     = a 1 n 1      =  a -2yab        "
	"9:b3     = i 1 a 1      =  i -2ya         "
	"9:-b1    = a 1 a 1      =  a -2ya         "
	"9:-b2    = c 1 n 1      =  c -2yac        "
	"9:-b3    = i 1 c 1      =  i -2yc         "
	"9:c1     = a 1 1 a      =  a -2a          "
	"9:c2     = b 1 1 n      =  b -2ab         "
	"9:c3     = i 1 1 b      =  i -2b          "
	"9:-c1    = b 1 1 b      =  b -2b          "
	"9:-c2    = a 1 1 n      =  a -2ab         "
	"9:-c3    = i 1 1 a      =  i -2a          "
	"9:a1     = b b 1 1      =  b -2xb         "
	"9:a2     = c n 1 1      =  c -2xac        "
	"9:a3     = i c 1 1      =  i -2xc         "
	"9:-a1    = c c 1 1      =  c -2xc         "
	"9:-a2    = b n 1 1      =  b -2xab        "
	"9:-a3    = i b 1 1      =  i -2xb         "
	"10:b     = p 1 2/m 1    =  -p 2y          "
	"10:b     = p 2/m        =  -p 2y          "
	"10:c     = p 1 1 2/m    =  -p 2           "
	"10:a     = p 2/m 1 1    =  -p 2x          "
	"11:b     = p 1 21/m 1   =  -p 2yb         "
	"11:b     = p 1 21/m 1   =  -p 2y1         "
	"11:b     = p 21/m       =  -p 2yb         "
	"11:c     = p 1 1 21/m   =  -p 2c          "
	"11:c     = p 1 1 21/m   =  -p 21          "
	"11:a     = p 21/m 1 1   =  -p 2xa         "
	"11:a     = p 21/m 1 1   =  -p 2x1         "
	"12:b1    = c 1 2/m 1    =  -c 2y          "
	"12:b1    = c 2/m        =  -c 2y          "
	"12:b2    = a 1 2/m 1    =  -a 2y          "
	"12:b3    = i 1 2/m 1    =  -i 2y          "
	"12:b3    = i 2/m        =  -i 2y          "
	"12:c1    = a 1 1 2/m    =  -a 2           "
	"12:c2    = b 1 1 2/m    =  -b 2           "
	"12:c3    = i 1 1 2/m    =  -i 2           "
	"12:a1    = b 2/m 1 1    =  -b 2x          "
	"12:a2    = c 2/m 1 1    =  -c 2x          "
	"12:a3    = i 2/m 1 1    =  -i 2x          "
	"13:b1    = p 1 2/c 1    =  -p 2yc         "
	"13:b1    = p 2/c        =  -p 2yc         "
	"13:b2    = p 1 2/n 1    =  -p 2yac        "
	"13:b2    = p 2/n        =  -p 2yac        "
	"13:b3    = p 1 2/a 1    =  -p 2ya         "
	"13:b3    = p 2/a        =  -p 2ya         "
	"13:c1    = p 1 1 2/a    =  -p 2a          "
	"13:c2    = p 1 1 2/n    =  -p 2ab         "
	"13:c3    = p 1 1 2/b    =  -p 2b          "
	"13:a1    = p 2/b 1 1    =  -p 2xb         "
	"13:a2    = p 2/n 1 1    =  -p 2xbc        "
	"13:a3    = p 2/c 1 1    =  -p 2xc         "
	"14:b1    = p 1 21/c 1   =  -p 2ybc        "
	"14:b1    = p 21/c       =  -p 2ybc        "
	"14:b2    = p 1 21/n 1   =  -p 2yn         "
	"14:b2    = p 21/n       =  -p 2yn         "
	"14:b3    = p 1 21/a 1   =  -p 2yab        "
	"14:b3    = p 21/a       =  -p 2yab        "
	"14:c1    = p 1 1 21/a   =  -p 2ac         "
	"14:c2    = p 1 1 21/n   =  -p 2n          "
	"14:c3    = p 1 1 21/b   =  -p 2bc         "
	"14:a1    = p 21/b 1 1   =  -p 2xab        "
	"14:a2    = p 21/n 1 1   =  -p 2xn         "
	"14:a3    = p 21/c 1 1   =  -p 2xac        "
	"15:b1    = c 1 2/c 1    =  -c 2yc         "
	"15:b1    = c 2/c        =  -c 2yc         "
	"15:b2    = a 1 2/n 1    =  -a 2yab        "
	"15:b3    = i 1 2/a 1    =  -i 2ya         "
	"15:b3    = i 2/a        =  -i 2ya         "
	"15:-b1   = a 1 2/a 1    =  -a 2ya         "
	"15:-b2   = c 1 2/n 1    =  -c 2yac        "
	"15:-b2   = c 2/n        =  -c 2yac        "
	"15:-b3   = i 1 2/c 1    =  -i 2yc         "
	"15:-b3   = i 2/c        =  -i 2yc         "
	"15:c1    = a 1 1 2/a    =  -a 2a          "
	"15:c2    = b 1 1 2/n    =  -b 2ab         "
	"15:c3    = i 1 1 2/b    =  -i 2b          "
	"15:-c1   = b 1 1 2/b    =  -b 2b          "
	"15:-c2   = a 1 1 2/n    =  -a 2ab         "
	"15:-c3   = i 1 1 2/a    =  -i 2a          "
	"15:a1    = b 2/b 1 1    =  -b 2xb         "
	"15:a2    = c 2/n 1 1    =  -c 2xac        "
	"15:a3    = i 2/c 1 1    =  -i 2xc         "
	"15:-a1   = c 2/c 1 1    =  -c 2xc         "
	"15:-a2   = b 2/n 1 1    =  -b 2xab        "
	"15:-a3   = i 2/b 1 1    =  -i 2xb         "
	"16       = p 2 2 2      =  p 2 2          "
	"17:      = p 2 2 21     =  p 2c 2         "
	"17:      = p 2 2 21     =  p 21 2         "
	"17:cab   = p 21 2 2     =  p 2a 2a        "
	"17:bca   = p 2 21 2     =  p 2 2b         "
	"18:      = p 21 21 2    =  p 2 2ab        "
	"18:cab   = p 2 21 21    =  p 2bc 2        "
	"18:bca   = p 21 2 21    =  p 2ac 2ac      "
	"19       = p 21 21 21   =  p 2ac 2ab      "
	"20:      = c 2 2 21     =  c 2c 2         "
	"20:      = c 2 2 21     =  c 21 2         "
	"20:cab   = a 21 2 2     =  a 2a 2a        "
	"20:cab   = a 21 2 2     =  a 2a 21        "
	"20:bca   = b 2 21 2     =  b 2 2b         "
	"21:      = c 2 2 2      =  c 2 2          "
	"21:cab   = a 2 2 2      =  a 2 2          "
	"21:bca   = b 2 2 2      =  b 2 2          "
	"22       = f 2 2 2      =  f 2 2          "
	"23       = i 2 2 2      =  i 2 2          "
	"24       = i 21 21 21   =  i 2b 2c        "
	"25:      = p m m 2      =  p 2 -2         "
	"25:cab   = p 2 m m      =  p -2 2         "
	"25:bca   = p m 2 m      =  p -2 -2        "
	"26:      = p m c 21     =  p 2c -2        "
	"26:      = p m c 21     =  p 21 -2        "
	"26:ba-c  = p c m 21     =  p 2c -2c       "
	"26:ba-c  = p c m 21     =  p 21 -2c       "
	"26:cab   = p 21 m a     =  p -2a 2a       "
	"26:-cba  = p 21 a m     =  p -2 2a        "
	"26:bca   = p b 21 m     =  p -2 -2b       "
	"26:a-cb  = p m 21 b     =  p -2b -2       "
	"27:      = p c c 2      =  p 2 -2c        "
	"27:cab   = p 2 a a      =  p -2a 2        "
	"27:bca   = p b 2 b      =  p -2b -2b      "
	"28:      = p m a 2      =  p 2 -2a        "
	"28:      = p m a 2      =  p 2 -21        "
	"28:ba-c  = p b m 2      =  p 2 -2b        "
	"28:cab   = p 2 m b      =  p -2b 2        "
	"28:-cba  = p 2 c m      =  p -2c 2        "
	"28:-cba  = p 2 c m      =  p -21 2        "
	"28:bca   = p c 2 m      =  p -2c -2c      "
	"28:a-cb  = p m 2 a      =  p -2a -2a      "
	"29:      = p c a 21     =  p 2c -2ac      "
	"29:ba-c  = p b c 21     =  p 2c -2b       "
	"29:cab   = p 21 a b     =  p -2b 2a       "
	"29:-cba  = p 21 c a     =  p -2ac 2a      "
	"29:bca   = p c 21 b     =  p -2bc -2c     "
	"29:a-cb  = p b 21 a     =  p -2a -2ab     "
	"30:      = p n c 2      =  p 2 -2bc       "
	"30:ba-c  = p c n 2      =  p 2 -2ac       "
	"30:cab   = p 2 n a      =  p -2ac 2       "
	"30:-cba  = p 2 a n      =  p -2ab 2       "
	"30:bca   = p b 2 n      =  p -2ab -2ab    "
	"30:a-cb  = p n 2 b      =  p -2bc -2bc    "
	"31:      = p m n 21     =  p 2ac -2       "
	"31:ba-c  = p n m 21     =  p 2bc -2bc     "
	"31:cab   = p 21 m n     =  p -2ab 2ab     "
	"31:-cba  = p 21 n m     =  p -2 2ac       "
	"31:bca   = p n 21 m     =  p -2 -2bc      "
	"31:a-cb  = p m 21 n     =  p -2ab -2      "
	"32:      = p b a 2      =  p 2 -2ab       "
	"32:cab   = p 2 c b      =  p -2bc 2       "
	"32:bca   = p c 2 a      =  p -2ac -2ac    "
	"33:      = p n a 21     =  p 2c -2n       "
	"33:      = p n a 21     =  p 21 -2n       "
	"33:ba-c  = p b n 21     =  p 2c -2ab      "
	"33:ba-c  = p b n 21     =  p 21 -2ab      "
	"33:cab   = p 21 n b     =  p -2bc 2a      "
	"33:cab   = p 21 n b     =  p -2bc 21      "
	"33:-cba  = p 21 c n     =  p -2n 2a       "
	"33:-cba  = p 21 c n     =  p -2n 21       "
	"33:bca   = p c 21 n     =  p -2n -2ac     "
	"33:a-cb  = p n 21 a     =  p -2ac -2n     "
	"34:      = p n n 2      =  p 2 -2n        "
	"34:cab   = p 2 n n      =  p -2n 2        "
	"34:bca   = p n 2 n      =  p -2n -2n      "
	"35:      = c m m 2      =  c 2 -2         "
	"35:cab   = a 2 m m      =  a -2 2         "
	"35:bca   = b m 2 m      =  b -2 -2        "
	"36:      = c m c 21     =  c 2c -2        "
	"36:      = c m c 21     =  c 21 -2        "
	"36:ba-c  = c c m 21     =  c 2c -2c       "
	"36:ba-c  = c c m 21     =  c 21 -2c       "
	"36:cab   = a 21 m a     =  a -2a 2a       "
	"36:cab   = a 21 m a     =  a -2a 21       "
	"36:-cba  = a 21 a m     =  a -2 2a        "
	"36:-cba  = a 21 a m     =  a -2 21        "
	"36:bca   = b b 21 m     =  b -2 -2b       "
	"36:a-cb  = b m 21 b     =  b -2b -2       "
	"37:      = c c c 2      =  c 2 -2c        "
	"37:cab   = a 2 a a      =  a -2a 2        "
	"37:bca   = b b 2 b      =  b -2b -2b      "
	"38:      = a m m 2      =  a 2 -2         "
	"38:ba-c  = b m m 2      =  b 2 -2         "
	"38:cab   = b 2 m m      =  b -2 2         "
	"38:-cba  = c 2 m m      =  c -2 2         "
	"38:bca   = c m 2 m      =  c -2 -2        "
	"38:a-cb  = a m 2 m      =  a -2 -2        "
	"39:      = a b m 2      =  a 2 -2c        "
	"39:ba-c  = b m a 2      =  b 2 -2a        "
	"39:cab   = b 2 c m      =  b -2a 2        "
	"39:-cba  = c 2 m b      =  c -2a 2        "
	"39:bca   = c m 2 a      =  c -2a -2a      "
	"39:a-cb  = a c 2 m      =  a -2c -2c      "
	"40:      = a m a 2      =  a 2 -2a        "
	"40:ba-c  = b b m 2      =  b 2 -2b        "
	"40:cab   = b 2 m b      =  b -2b 2        "
	"40:-cba  = c 2 c m      =  c -2c 2        "
	"40:bca   = c c 2 m      =  c -2c -2c      "
	"40:a-cb  = a m 2 a      =  a -2a -2a      "
	"41:      = a b a 2      =  a 2 -2ab       "
	"41:ba-c  = b b a 2      =  b 2 -2ab       "
	"41:cab   = b 2 c b      =  b -2ab 2       "
	"41:-cba  = c 2 c b      =  c -2ac 2       "
	"41:bca   = c c 2 a      =  c -2ac -2ac    "
	"41:a-cb  = a c 2 a      =  a -2ab -2ab    "
	"42:      = f m m 2      =  f 2 -2         "
	"42:cab   = f 2 m m      =  f -2 2         "
	"42:bca   = f m 2 m      =  f -2 -2        "
	"43:      = f d d 2      =  f 2 -2d        "
	"43:cab   = f 2 d d      =  f -2d 2        "
	"43:bca   = f d 2 d      =  f -2d -2d      "
	"44:      = i m m 2      =  i 2 -2         "
	"44:cab   = i 2 m m      =  i -2 2         "
	"44:bca   = i m 2 m      =  i -2 -2        "
	"45:      = i b a 2      =  i 2 -2c        "
	"45:cab   = i 2 c b      =  i -2a 2        "
	"45:bca   = i c 2 a      =  i -2b -2b      "
	"46:      = i m a 2      =  i 2 -2a        "
	"46:ba-c  = i b m 2      =  i 2 -2b        "
	"46:cab   = i 2 m b      =  i -2b 2        "
	"46:-cba  = i 2 c m      =  i -2c 2        "
	"46:bca   = i c 2 m      =  i -2c -2c      "
	"46:a-cb  = i m 2 a      =  i -2a -2a      "
	"47       = p m m m      =  -p 2 2         "
	"48:1     = p n n n:1    =  p 2 2 -1n      "
	"48:2     = p n n n:2    =  -p 2ab 2bc     "
	"49:      = p c c m      =  -p 2 2c        "
	"49:cab   = p m a a      =  -p 2a 2        "
	"49:bca   = p b m b      =  -p 2b 2b       "
	"50:1     = p b a n:1    =  p 2 2 -1ab     "
	"50:2     = p b a n:2    =  -p 2ab 2b      "
	"50:1cab  = p n c b:1    =  p 2 2 -1bc     "
	"50:2cab  = p n c b:2    =  -p 2b 2bc      "
	"50:1bca  = p c n a:1    =  p 2 2 -1ac     "
	"50:2bca  = p c n a:2    =  -p 2a 2c       "
	"51:      = p m m a      =  -p 2a 2a       "
	"51:ba-c  = p m m b      =  -p 2b 2        "
	"51:cab   = p b m m      =  -p 2 2b        "
	"51:-cba  = p c m m      =  -p 2c 2c       "
	"51:bca   = p m c m      =  -p 2c 2        "
	"51:a-cb  = p m a m      =  -p 2 2a        "
	"52:      = p n n a      =  -p 2a 2bc      "
	"52:ba-c  = p n n b      =  -p 2b 2n       "
	"52:cab   = p b n n      =  -p 2n 2b       "
	"52:-cba  = p c n n      =  -p 2ab 2c      "
	"52:bca   = p n c n      =  -p 2ab 2n      "
	"52:a-cb  = p n a n      =  -p 2n 2bc      "
	"53:      = p m n a      =  -p 2ac 2       "
	"53:ba-c  = p n m b      =  -p 2bc 2bc     "
	"53:cab   = p b m n      =  -p 2ab 2ab     "
	"53:-cba  = p c n m      =  -p 2 2ac       "
	"53:bca   = p n c m      =  -p 2 2bc       "
	"53:a-cb  = p m a n      =  -p 2ab 2       "
	"54:      = p c c a      =  -p 2a 2ac      "
	"54:ba-c  = p c c b      =  -p 2b 2c       "
	"54:cab   = p b a a      =  -p 2a 2b       "
	"54:-cba  = p c a a      =  -p 2ac 2c      "
	"54:bca   = p b c b      =  -p 2bc 2b      "
	"54:a-cb  = p b a b      =  -p 2b 2ab      "
	"55:      = p b a m      =  -p 2 2ab       "
	"55:cab   = p m c b      =  -p 2bc 2       "
	"55:bca   = p c m a      =  -p 2ac 2ac     "
	"56:      = p c c n      =  -p 2ab 2ac     "
	"56:cab   = p n a a      =  -p 2ac 2bc     "
	"56:bca   = p b n b      =  -p 2bc 2ab     "
	"57:      = p b c m      =  -p 2c 2b       "
	"57:ba-c  = p c a m      =  -p 2c 2ac      "
	"57:cab   = p m c a      =  -p 2ac 2a      "
	"57:-cba  = p m a b      =  -p 2b 2a       "
	"57:bca   = p b m a      =  -p 2a 2ab      "
	"57:a-cb  = p c m b      =  -p 2bc 2c      "
	"58:      = p n n m      =  -p 2 2n        "
	"58:cab   = p m n n      =  -p 2n 2        "
	"58:bca   = p n m n      =  -p 2n 2n       "
	"59:1     = p m m n:1    =  p 2 2ab -1ab   "
	"59:2     = p m m n:2    =  -p 2ab 2a      "
	"59:1cab  = p n m m:1    =  p 2bc 2 -1bc   "
	"59:2cab  = p n m m:2    =  -p 2c 2bc      "
	"59:1bca  = p m n m:1    =  p 2ac 2ac -1ac "
	"59:2bca  = p m n m:2    =  -p 2c 2a       "
	"60:      = p b c n      =  -p 2n 2ab      "
	"60:ba-c  = p c a n      =  -p 2n 2c       "
	"60:cab   = p n c a      =  -p 2a 2n       "
	"60:-cba  = p n a b      =  -p 2bc 2n      "
	"60:bca   = p b n a      =  -p 2ac 2b      "
	"60:a-cb  = p c n b      =  -p 2b 2ac      "
	"61:      = p b c a      =  -p 2ac 2ab     "
	"61:ba-c  = p c a b      =  -p 2bc 2ac     "
	"62:      = p n m a      =  -p 2ac 2n      "
	"62:ba-c  = p m n b      =  -p 2bc 2a      "
	"62:cab   = p b n m      =  -p 2c 2ab      "
	"62:-cba  = p c m n      =  -p 2n 2ac      "
	"62:bca   = p m c n      =  -p 2n 2a       "
	"62:a-cb  = p n a m      =  -p 2c 2n       "
	"63:      = c m c m      =  -c 2c 2        "
	"63:ba-c  = c c m m      =  -c 2c 2c       "
	"63:cab   = a m m a      =  -a 2a 2a       "
	"63:-cba  = a m a m      =  -a 2 2a        "
	"63:bca   = b b m m      =  -b 2 2b        "
	"63:a-cb  = b m m b      =  -b 2b 2        "
	"64:      = c m c a      =  -c 2ac 2       "
	"64:ba-c  = c c m b      =  -c 2ac 2ac     "
	"64:cab   = a b m a      =  -a 2ab 2ab     "
	"64:-cba  = a c a m      =  -a 2 2ab       "
	"64:bca   = b b c m      =  -b 2 2ab       "
	"64:a-cb  = b m a b      =  -b 2ab 2       "
	"65:      = c m m m      =  -c 2 2         "
	"65:cab   = a m m m      =  -a 2 2         "
	"65:bca   = b m m m      =  -b 2 2         "
	"66:      = c c c m      =  -c 2 2c        "
	"66:cab   = a m a a      =  -a 2a 2        "
	"66:bca   = b b m b      =  -b 2b 2b       "
	"67:      = c m m a      =  -c 2a 2        "
	"67:ba-c  = c m m b      =  -c 2a 2a       "
	"67:cab   = a b m m      =  -a 2b 2b       "
	"67:-cba  = a c m m      =  -a 2 2c        "
	"67:bca   = b m c m      =  -b 2 2a        "
	"67:a-cb  = b m a m      =  -b 2a 2        "
	"68:1     = c c c a:1    =  c 2 2 -1ac     "
	"68:2     = c c c a:2    =  -c 2a 2ac      "
	"68:1ba-c = c c c b:1    =  c 2 2 -1ac     "
	"68:2ba-c = c c c b:2    =  -c 2a 2c       "
	"68:1cab  = a b a a:1    =  a 2 2 -1ab     "
	"68:2cab  = a b a a:2    =  -a 2a 2c       "
	"68:1-cba = a c a a:1    =  a 2 2 -1ab     "
	"68:2-cba = a c a a:2    =  -a 2ab 2b      "
	"68:1bca  = b b c b:1    =  b 2 2 -1ab     "
	"68:2bca  = b b c b:2    =  -b 2ab 2b      "
	"68:1a-cb = b b a b:1    =  b 2 2 -1ab     "
	"68:2a-cb = b b a b:2    =  -b 2b 2ab      "
	"69       = f m m m      =  -f 2 2         "
	"70:1     = f d d d:1    =  f 2 2 -1d      "
	"70:2     = f d d d:2    =  -f 2uv 2vw     "
	"71       = i m m m      =  -i 2 2         "
	"72:      = i b a m      =  -i 2 2c        "
	"72:cab   = i m c b      =  -i 2a 2        "
	"72:bca   = i c m a      =  -i 2b 2b       "
	"73:      = i b c a      =  -i 2b 2c       "
	"73:ba-c  = i c a b      =  -i 2a 2b       "
	"74:      = i m m a      =  -i 2b 2        "
	"74:ba-c  = i m m b      =  -i 2a 2a       "
	"74:cab   = i b m m      =  -i 2c 2c       "
	"74:-cba  = i c m m      =  -i 2 2b        "
	"74:bca   = i m c m      =  -i 2 2a        "
	"74:a-cb  = i m a m      =  -i 2c 2        "
	"75       = p 4          =  p 4            "
	"76:      = p 41         =  p 4w           "
	"76:      = p 41         =  p 41           "
	"77:      = p 42         =  p 4c           "
	"77:      = p 42         =  p 42           "
	"78:      = p 43         =  p 4cw          "
	"78:      = p 43         =  p 43           "
	"79       = i 4          =  i 4            "
	"80       = i 41         =  i 4bw          "
	"81       = p -4         =  p -4           "
	"82       = i -4         =  i -4           "
	"83       = p 4/m        =  -p 4           "
	"84:      = p 42/m       =  -p 4c          "
	"84:      = p 42/m       =  -p 42          "
	"85:1     = p 4/n:1      =  p 4ab -1ab     "
	"85:2     = p 4/n:2      =  -p 4a          "
	"86:1     = p 42/n:1     =  p 4n -1n       "
	"86:2     = p 42/n:2     =  -p 4bc         "
	"87       = i 4/m        =  -i 4           "
	"88:1     = i 41/a:1     =  i 4bw -1bw     "
	"88:2     = i 41/a:2     =  -i 4ad         "
	"89       = p 4 2 2      =  p 4 2          "
	"90       = p 4 21 2     =  p 4ab 2ab      "
	"91:      = p 41 2 2     =  p 4w 2c        "
	"91:      = p 41 2 2     =  p 41 2c        "
	"92       = p 41 21 2    =  p 4abw 2nw     "
	"93:      = p 42 2 2     =  p 4c 2         "
	"93:      = p 42 2 2     =  p 42 2         "
	"94       = p 42 21 2    =  p 4n 2n        "
	"95:      = p 43 2 2     =  p 4cw 2c       "
	"95:      = p 43 2 2     =  p 43 2c        "
	"96       = p 43 21 2    =  p 4nw 2abw     "
	"97       = i 4 2 2      =  i 4 2          "
	"98       = i 41 2 2     =  i 4bw 2bw      "
	"99       = p 4 m m      =  p 4 -2         "
	"100      = p 4 b m      =  p 4 -2ab       "
	"101:     = p 42 c m     =  p 4c -2c       "
	"101:     = p 42 c m     =  p 42 -2c       "
	"102      = p 42 n m     =  p 4n -2n       "
	"103      = p 4 c c      =  p 4 -2c        "
	"104      = p 4 n c      =  p 4 -2n        "
	"105:     = p 42 m c     =  p 4c -2        "
	"105:     = p 42 m c     =  p 42 -2        "
	"106:     = p 42 b c     =  p 4c -2ab      "
	"106:     = p 42 b c     =  p 42 -2ab      "
	"107      = i 4 m m      =  i 4 -2         "
	"108      = i 4 c m      =  i 4 -2c        "
	"109      = i 41 m d     =  i 4bw -2       "
	"110      = i 41 c d     =  i 4bw -2c      "
	"111      = p -4 2 m     =  p -4 2         "
	"112      = p -4 2 c     =  p -4 2c        "
	"113      = p -4 21 m    =  p -4 2ab       "
	"114      = p -4 21 c    =  p -4 2n        "
	"115      = p -4 m 2     =  p -4 -2        "
	"116      = p -4 c 2     =  p -4 -2c       "
	"117      = p -4 b 2     =  p -4 -2ab      "
	"118      = p -4 n 2     =  p -4 -2n       "
	"119      = i -4 m 2     =  i -4 -2        "
	"120      = i -4 c 2     =  i -4 -2c       "
	"121      = i -4 2 m     =  i -4 2         "
	"122      = i -4 2 d     =  i -4 2bw       "
	"123      = p 4/m m m    =  -p 4 2         "
	"124      = p 4/m c c    =  -p 4 2c        "
	"125:1    = p 4/n b m:1  =  p 4 2 -1ab     "
	"125:2    = p 4/n b m:2  =  -p 4a 2b       "
	"126:1    = p 4/n n c:1  =  p 4 2 -1n      "
	"126:2    = p 4/n n c:2  =  -p 4a 2bc      "
	"127      = p 4/m b m    =  -p 4 2ab       "
	"128      = p 4/m n c    =  -p 4 2n        "
	"129:1    = p 4/n m m:1  =  p 4ab 2ab -1ab "
	"129:2    = p 4/n m m:2  =  -p 4a 2a       "
	"130:1    = p 4/n c c:1  =  p 4ab 2n -1ab  "
	"130:2    = p 4/n c c:2  =  -p 4a 2ac      "
	"131      = p 42/m m c   =  -p 4c 2        "
	"132      = p 42/m c m   =  -p 4c 2c       "
	"133:1    = p 42/n b c:1 =  p 4n 2c -1n    "
	"133:2    = p 42/n b c:2 =  -p 4ac 2b      "
	"134:1    = p 42/n n m:1 =  p 4n 2 -1n     "
	"134:2    = p 42/n n m:2 =  -p 4ac 2bc     "
	"135:     = p 42/m b c   =  -p 4c 2ab      "
	"135:     = p 42/m b c   =  -p 42 2ab      "
	"136      = p 42/m n m   =  -p 4n 2n       "
	"137:1    = p 42/n m c:1 =  p 4n 2n -1n    "
	"137:2    = p 42/n m c:2 =  -p 4ac 2a      "
	"138:1    = p 42/n c m:1 =  p 4n 2ab -1n   "
	"138:2    = p 42/n c m:2 =  -p 4ac 2ac     "
	"139      = i 4/m m m    =  -i 4 2         "
	"140      = i 4/m c m    =  -i 4 2c        "
	"141:1    = i 41/a m d:1 =  i 4bw 2bw -1bw "
	"141:2    = i 41/a m d:2 =  -i 4bd 2       "
	"142:1    = i 41/a c d:1 =  i 4bw 2aw -1bw "
	"142:2    = i 41/a c d:2 =  -i 4bd 2c      "
	"143      = p 3          =  p 3            "
	"144      = p 31         =  p 31           "
	"145      = p 32         =  p 32           "
	"146:h    = r 3:h        =  r 3            "
	"146:r    = r 3:r        =  p 3*           "
	"147      = p -3         =  -p 3           "
	"148:h    = r -3:h       =  -r 3           "
	"148:r    = r -3:r       =  -p 3*          "
	"149      = p 3 1 2      =  p 3 2          "
	"150      = p 3 2 1      =  p 3 2""        "
	"151      = p 31 1 2     =  p 31 2 (0 0 4) "
	"152      = p 31 2 1     =  p 31 2""       "
	"153      = p 32 1 2     =  p 32 2 (0 0 2) "
	"154      = p 32 2 1     =  p 32 2""       "
	"155:h    = r 3 2:h      =  r 3 2""        "
	"155:r    = r 3 2:r      =  p 3* 2         "
	"156      = p 3 m 1      =  p 3 -2""       "
	"157      = p 3 1 m      =  p 3 -2         "
	"158      = p 3 c 1      =  p 3 -2""c      "
	"159      = p 3 1 c      =  p 3 -2c        "
	"160:h    = r 3 m:h      =  r 3 -2""       "
	"160:r    = r 3 m:r      =  p 3* -2        "
	"161:h    = r 3 c:h      =  r 3 -2""c      "
	"161:r    = r 3 c:r      =  p 3* -2n       "
	"162      = p -3 1 m     =  -p 3 2         "
	"163      = p -3 1 c     =  -p 3 2c        "
	"164      = p -3 m 1     =  -p 3 2""       "
	"165      = p -3 c 1     =  -p 3 2""c      "
	"166:h    = r -3 m:h     =  -r 3 2""       "
	"166:r    = r -3 m:r     =  -p 3* 2        "
	"167:h    = r -3 c:h     =  -r 3 2""c      "
	"167:r    = r -3 c:r     =  -p 3* 2n       "
	"168      = p 6          =  p 6            "
	"169      = p 61         =  p 61           "
	"170      = p 65         =  p 65           "
	"171      = p 62         =  p 62           "
	"172      = p 64         =  p 64           "
	"173:     = p 63         =  p 6c           "
	"173:     = p 63         =  p 63           "
	"174      = p -6         =  p -6           "
	"175      = p 6/m        =  -p 6           "
	"176:     = p 63/m       =  -p 6c          "
	"176:     = p 63/m       =  -p 63          "
	"177      = p 6 2 2      =  p 6 2          "
	"178      = p 61 2 2     =  p 61 2 (0 0 5) "
	"179      = p 65 2 2     =  p 65 2 (0 0 1) "
	"180      = p 62 2 2     =  p 62 2 (0 0 4) "
	"181      = p 64 2 2     =  p 64 2 (0 0 2) "
	"182:     = p 63 2 2     =  p 6c 2c        "
	"182:     = p 63 2 2     =  p 63 2c        "
	"183      = p 6 m m      =  p 6 -2         "
	"184      = p 6 c c      =  p 6 -2c        "
	"185:     = p 63 c m     =  p 6c -2        "
	"185:     = p 63 c m     =  p 63 -2        "
	"186:     = p 63 m c     =  p 6c -2c       "
	"186:     = p 63 m c     =  p 63 -2c       "
	"187      = p -6 m 2     =  p -6 2         "
	"188      = p -6 c 2     =  p -6c 2        "
	"189      = p -6 2 m     =  p -6 -2        "
	"190      = p -6 2 c     =  p -6c -2c      "
	"191      = p 6/m m m    =  -p 6 2         "
	"192      = p 6/m c c    =  -p 6 2c        "
	"193:     = p 63/m c m   =  -p 6c 2        "
	"193:     = p 63/m c m   =  -p 63 2        "
	"194:     = p 63/m m c   =  -p 6c 2c       "
	"194:     = p 63/m m c   =  -p 63 2c       "
	"195      = p 2 3        =  p 2 2 3        "
	"196      = f 2 3        =  f 2 2 3        "
	"197      = i 2 3        =  i 2 2 3        "
	"198      = p 21 3       =  p 2ac 2ab 3    "
	"199      = i 21 3       =  i 2b 2c 3      "
	"200      = p m -3       =  -p 2 2 3       "
	"201:1    = p n -3:1     =  p 2 2 3 -1n    "
	"201:2    = p n -3:2     =  -p 2ab 2bc 3   "
	"202      = f m -3       =  -f 2 2 3       "
	"203:1    = f d -3:1     =  f 2 2 3 -1d    "
	"203:2    = f d -3:2     =  -f 2uv 2vw 3   "
	"204      = i m -3       =  -i 2 2 3       "
	"205      = p a -3       =  -p 2ac 2ab 3   "
	"206      = i a -3       =  -i 2b 2c 3     "
	"207      = p 4 3 2      =  p 4 2 3        "
	"208      = p 42 3 2     =  p 4n 2 3       "
	"209      = f 4 3 2      =  f 4 2 3        "
	"210      = f 41 3 2     =  f 4d 2 3       "
	"211      = i 4 3 2      =  i 4 2 3        "
	"212      = p 43 3 2     =  p 4acd 2ab 3   "
	"213      = p 41 3 2     =  p 4bd 2ab 3    "
	"214      = i 41 3 2     =  i 4bd 2c 3     "
	"215      = p -4 3 m     =  p -4 2 3       "
	"216      = f -4 3 m     =  f -4 2 3       "
	"217      = i -4 3 m     =  i -4 2 3       "
	"218      = p -4 3 n     =  p -4n 2 3      "
	"219      = f -4 3 c     =  f -4a 2 3      "
	"220      = i -4 3 d     =  i -4bd 2c 3    "
	"221      = p m -3 m     =  -p 4 2 3       "
	"222:1    = p n -3 n:1   =  p 4 2 3 -1n    "
	"222:2    = p n -3 n:2   =  -p 4a 2bc 3    "
	"223      = p m -3 n     =  -p 4n 2 3      "
	"224:1    = p n -3 m:1   =  p 4n 2 3 -1n   "
	"224:2    = p n -3 m:2   =  -p 4bc 2bc 3   "
	"225      = f m -3 m     =  -f 4 2 3       "
	"226      = f m -3 c     =  -f 4a 2 3      "
	"227:1    = f d -3 m:1   =  f 4d 2 3 -1d   "
	"227:2    = f d -3 m:2   =  -f 4vw 2vw 3   "
	"228:1    = f d -3 c:1   =  f 4d 2 3 -1ad  "
	"228:2    = f d -3 c:2   =  -f 4ud 2vw 3   "
	"229      = i m -3 m     =  -i 4 2 3       "
	"230      = i a -3 d     =  -i 4bd 2c 3    ")
	
        if [[ "$SCFCALCPROG" == "elmodb" ]]; then
		REQUIRE_ZENITY "the unit cell parameters" "crystal_data.txt" || exit 2
        	zenity --forms --title="Crystal data" --text="Enter the unit cell parameters and space group:" \
	           --add-entry="a= " \
        	   --add-entry="b= " \
        	   --add-entry="c= " \
        	   --add-entry="alpha= " \
        	   --add-entry="beta = " \
        	   --add-entry="gamma= " > crystal_data.txt
        fi
	
	REQUIRE_ZENITY "the space group" "spacegroup.txt" || exit 2
	zenity --list --title="Select the space group" --width=980 --height=720 \
		--column="Number = IT symbol = Hall symbol" \
		"${SPACEGROUPARRAY[@]}" > spacegroup.txt
	
}


RUN_NOSPHERA2(){

mkdir $NSA2_COUNTER.NoSphera2_cycle

if [[ "$COMPLETESTRUCT" == "true"  ]]; then
        #Replace label on xyz block for assym unit cif
        #echo "xyz assym"
        EXISTS=$(awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}')
        if [[ ! -z $EXISTS ]]; then
                awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
                awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
                sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.archive.cif 
        fi
        #echo "xyz assym done"

        #Replace label on xyz block for frag unit cif
        #echo "xyz frag"
        awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
        awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
        sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1 
        #echo "xyz frag done"
        
        #Replace label on ADP block for assym unit cif
        #echo "adp assym"
        EXISTS=$(awk '{a[NR]=$0}/^# ADPs/{b=NR+11}{c=FNR}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk '{if(NF>6 && $2~/^[0-9]/) print $0}' | awk 'substr($1,2,2)!~/^[0-9]/{print $0}')
        if [[ ! -z $EXISTS ]]; then
                awk '{a[NR]=$0}/^# ADPs/{b=NR+11}{c=FNR}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk '{if(NF>6 && $2~/^[0-9]/) print $0}' | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
                awk '{a[NR]=$0}/^# ADPs/{b=NR+11}{c=FNR}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk '{if(NF>6 && $2~/^[0-9]/) print $0}' | awk 'substr($1,2,2)!~/^[0-9]/{print $0}'  > ATOMS
                sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.archive.cif 
        fi        
        #echo "adp assym done"
        
        #Replace label on ADP block for frag unit cif
        #echo "adp frag"
        awk '{a[NR]=$0}/^# ADPs/{b=NR+11}{c=FNR}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk '{if(NF>6 && $2~/^[0-9]/) print $0}' | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
        awk '{a[NR]=$0}/^# ADPs/{b=NR+11}{c=FNR}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk '{if(NF>6 && $2~/^[0-9]/) print $0}' | awk 'substr($1,2,2)!~/^[0-9]/{print $0}'  > ATOMS
        sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1 
        #echo "adp frag done"
        rm ATOMS ATOMS_NEW
fi

#Add symmetry loop that NoSpherA2 reads
echo "" > SYMMETRY
echo "loop_" >> SYMMETRY
echo "   _space_group_symop_id " >> SYMMETRY
echo "   _space_group_symop_operation_xyz " >> SYMMETRY
#awk '{a[NR]=$0}/^    _symmetry_equiv_pos_as_xyz/{b=NR+1}/^# Unit cell/{c=NR-3}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk -n '{ print NR, $0}' | awk '{gsub(/\ /,"",$2)}'  >> SYMMETRY
awk '{a[NR]=$0}/^    _symmetry_equiv_pos_as_xyz/{b=NR+1}/^# Unit cell/{c=NR-3}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | tr -d \ |  awk -n '{ print NR, $0}' | tr -d \' >> SYMMETRY
#awk '{a[NR]=$0}/^    _symmetry_equiv_pos_as_xyz/{b=NR+1}/^# Unit cell/{c=NR-3}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1  > SYMMETRY_OLD
#sed -i -ne '/'"$(sed -n '1p' SYMMETRY_OLD )"'/ {p; r SYMMETRY' -e 'p; :a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1
echo "$(cat SYMMETRY)" >> $JOBNAME.fractional.cif1
echo "$(cat SYMMETRY)" >> $JOBNAME.archive.cif
rm SYMMETRY

NoSphera2.exe -cif $JOBNAME.archive.cif -asym_cif $JOBNAME.fractional.cif1 -wfn $JOBNAME.wfn -hkl $JOBNAME.hkl -acc $NSA2ACC -cpus $NUMPROC > /dev/null
if ! grep -q 'Time Breakdown:' "NoSpherA2.log"; then
	echo "ERROR: NoSpherA2 finished with error, please check the $I.th NoSpherA2.log file for more details" | tee -a $JOBNAME.lst
       	exit 1
else
        mv experimental.tsc $JOBNAME.tsc
       	echo "NoSpherA2 job finish correctly."
       	cp $JOBNAME.wfn  $NSA2_COUNTER.NoSphera2_cycle/$NSA2_COUNTER.$JOBNAME.wfn
       	cp $JOBNAME.tsc  $NSA2_COUNTER.NoSphera2_cycle/$NSA2_COUNTER.$JOBNAME.tsc
       	cp NoSpherA2.log $NSA2_COUNTER.NoSphera2_cycle//$NSA2_COUNTER.NoSpherA2.log
        #sleep 2s
fi

NSA2_COUNTER=$[$NSA2_COUNTER+1]
}

LABELS_IN_XYZ(){
if [[ "$COMPLETESTRUCT" == "true"  ]]; then
        #Replace label on xyz block for xyz 
        awk '{if(NR>2 && $2~/^[0-9]/) print $0}' $JOBNAME.xyz | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
        awk '{if(NR>2 && $2~/^[0-9]/) print $0}' $JOBNAME.xyz | awk 'substr($1,2,2)!~/^[0-9]/{print $0}'  > ATOMS
        sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.xyz

        rm ATOMS ATOMS_NEW 
fi
}

GAUSSIAN_NO_CHARGES(){
echo "%rwf=./$JOBNAME.rwf" > $JOBNAME.com 
echo "%int=./$JOBNAME.int" >> $JOBNAME.com 
echo "%NoSave" >> $JOBNAME.com 
echo "%chk=./$JOBNAME.chk" >> $JOBNAME.com 
echo "%mem=$MEM" >> $JOBNAME.com 
echo "%nprocshared=$NUMPROC" >> $JOBNAME.com
if [ "$SCFCALCPROG" = "optgaussian" ]; then
		OPT=" opt=calcfc"
	OPT=" opt"
fi
if [ "$METHOD" = "rks" ]; then
	echo "# blyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com    
else
	if [ "$METHOD" = "uks" ]; then
		echo "# ublyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	else
		echo "# $METHOD/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
        fi
fi			
echo ""  >> $JOBNAME.com
echo "$JOBNAME" >> $JOBNAME.com
echo "" >>  $JOBNAME.com
echo "$CHARGE $MULTIPLICITY" >>  $JOBNAME.com
awk 'NR>2' $JOBNAME.xyz >>  $JOBNAME.com
echo "" >> $JOBNAME.com 
if [ "$GAUSGEN" = "true" ]; then
	cat basis_gen.txt >> $JOBNAME.com 
	echo "" >> $JOBNAME.com 
fi
echo "./$JOBNAME.wfn" >> $JOBNAME.com 
echo "" >> $JOBNAME.com 
#I=$"1"
echo "Updating wave at gas phase" 
$SCFCALC_BIN $JOBNAME.com
cp Test.FChk $JOBNAME.fchk
sed -i '/^#/d' $JOBNAME.fchk
echo "Updating wave at gas phase done" 
#echo "Gaussian cycle number $I ended"
if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
	echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
	exit 1
fi
}

ORCA_NO_CHARGES(){
if [ "$METHOD" = "rks" ]; then
	echo "! blyp $BASISSETG" > $JOBNAME.inp
elif [ "$METHOD" = "uks" ]; then
	echo "! ublyp $BASISSETG" > $JOBNAME.inp
else
	echo "! $METHOD $BASISSETG" > $JOBNAME.inp
fi
echo "" >> $JOBNAME.inp 
echo "%pal nprocs $NUMPROC end" >> $JOBNAME.inp
echo "" >> $JOBNAME.inp
echo "%output" >> $JOBNAME.inp 
echo "   PrintLevel=Normal" >> $JOBNAME.inp 
echo "   Print[ P_Basis       ] 2" >> $JOBNAME.inp 
echo "   Print[ P_GuessOrb    ] 1" >> $JOBNAME.inp 
echo "   Print[ P_MOs         ] 1" >> $JOBNAME.inp 
echo "   Print[ P_Density     ] 1" >> $JOBNAME.inp 
echo "   Print[ P_SpinDensity ] 1" >> $JOBNAME.inp 
echo "end" >> $JOBNAME.inp 
echo "" >> $JOBNAME.inp 
echo "* xyz $CHARGE $MULTIPLICITY" >> $JOBNAME.inp 
awk 'NR>2' $JOBNAME.xyz >> $JOBNAME.inp 
echo "*" >> $JOBNAME.inp 
if [[ "$GAUSGEN" == "true" ]]; then
	cat basis_gen.txt >> $JOBNAME.inp
	echo "" >> $JOBNAME.inp
fi
#I=$"1"
#echo "Running Orca, cycle number $I" 
if [ -f $JOBNAME.gbw ]; then
        rm $JOBNAME.gbw
fi      
echo "Updating wave at gas phase" 
$SCFCALC_BIN $JOBNAME.inp > $JOBNAME.out
echo "Updating wave at gas phase done" 
if [[ "$(which orca_2mkl.exe)" == "" ]]; then
	orca_2mkl $JOBNAME -molden  > /dev/null
else 
	orca_2mkl.exe $JOBNAME -molden  > /dev/null
fi
if [[ "$(which orca_2aim.exe)" == "" ]]; then
	orca_2aim $JOBNAME  > /dev/null
else
	orca_2aim.exe $JOBNAME  > /dev/null
fi
NAPONE=$[ $NUMBEROFATOMS + 1 ]
STARTLINE=$(grep -n "  $NAPONE 0" $JOBNAME.molden.input | awk -F: '{print $1}')
ENDLINE=$(grep -n "\[5D\]" $JOBNAME.molden.input | awk -F: '{print $1}')
if [[ "$STARTLINE" != "" && "$ENDLINE" != "" ]]; then
	sed -i "$STARTLINE","$[ $ENDLINE - 1]"'{/.*/d;}' $JOBNAME.molden.input
	sed -i '/Q\ /d' $JOBNAME.molden.input
fi
#echo "Orca cycle number $I ended"
if ! grep -q '****ORCA TERMINATED NORMALLY****' "$JOBNAME.out"; then
	echo "ERROR: Orca job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
	exit 1
fi
}

WRITEXYZ(){
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" > stdin
echo "!!!                                                                                         !!!" >> stdin
echo "!!!                        This stdin was written with lamaGOET                             !!!" >> stdin
echo "!!!                                                                                         !!!" >> stdin
echo "!!!                    script written by Lorraine Andrade Malaspina                         !!!" >> stdin
echo "!!!                        contact: lorraine.malaspina@gmail.com                            !!!" >> stdin
echo "!!!                                                                                         !!!" >> stdin
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >> stdin
echo "{ " >> stdin
echo "" >> stdin
echo "   keyword_echo_on" >> stdin
echo "" >> stdin
echo "   ! Process the CIF" >> stdin
echo "   CIF= {" >> stdin
echo "       file_name= $CIF" >> stdin
if [ "$XHALONG" = "true" ]; then
          	if [ ! -z "$BHBOND" ]; then
	   	echo "       BH_bond_length= $BHBOND angstrom" >> stdin
   	fi
          	if [ ! -z "$CHBOND" ]; then
	   	echo "       CH_bond_length= $CHBOND angstrom" >> stdin
   	fi
          	if [ ! -z "$NHBOND" ]; then
	   	echo "       NH_bond_length= $NHBOND angstrom" >> stdin
   	fi
          	if [ ! -z "$OHBOND" ]; then
	   	echo "       OH_bond_length= $OHBOND angstrom" >> stdin
   	fi
fi
echo "    }" >> stdin
echo "" >> stdin
echo "   process_CIF" >> stdin
echo "" >> stdin
echo "   name= $JOBNAME" >> stdin
echo "" >> stdin
COMPLETECIFBLOCK
echo "   put" >> stdin 
echo "" >> stdin
if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
        if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
                if [[ "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "Gaussian" ]]; then
                       	echo "   write_xyz_file" >> stdin
		else
	                echo "   write_fragment_xyz_file " >> stdin
		fi
        else 
                echo "   write_xyz_file" >> stdin
        fi
else 
        echo "   write_xtal23_xyz_file" >> stdin
fi
echo "   put_cif" >> stdin
if [[ "$COMPLETESTRUCT" == "true" || "$SCFCALCPROG" == "optgaussian" ]]; then
	echo "" >> stdin
	echo "   put_grown_cif" >> stdin
fi
echo "" >> stdin
echo "}" >> stdin 
echo "Updating geometry"
if [[ "$NUMPROCTONTO" != "1" ]]; then
	mpirun -n $NUMPROCTONTO $TONTO	
else
	$TONTO
fi
echo "Updating geometry done"
if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then
	if [ -f "$JOBNAME.xyz" ]; then
		sed -i 's/(//g' $JOBNAME.xyz
		sed -i 's/)//g' $JOBNAME.xyz
	fi
fi
#if [[ -f $JOBNAME.cartesian.cif2 ]]; then
if [[ -f $JOBNAME.fractional.cif1 ]]; then
        cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian_cov.cif2
        cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional_cov.cif1
	sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
	sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.fractional.cif1
        cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
        cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
fi
if [[ "$SCFCALCPROG" == "Gaussian" ]]; then  
        GAUSSIAN_NO_CHARGES
else 
	ORCA_NO_CHARGES
fi
}

#CHECK_ATOM_LABELS(){
#awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
#awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
#sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.archive.cif
#awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
#awk '{a[NR]=$0}/^# Fractional coordinates/{b=NR+13}/^# ==================================/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
#sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1
#awk '{a[NR]=$0}/^# ADPs/{b=NR+13}/,0/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk  '$1=$1"1"' > ATOMS_NEW
#awk '{a[NR]=$0}/^# ADPs/{b=NR+13}/,0/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.fractional.cif1 | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
#sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1
#awk '{a[NR]=$0}/^# ADPs/{b=NR+13}/,0/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' | gawk '$1=$1"1"' > ATOMS_NEW
#awk '{a[NR]=$0}/^# ADPs/{b=NR+13}/,0/{c=NR-4}END{for(d=b;d<=c;++d)print a[d]}' $JOBNAME.archive.cif | awk 'substr($1,2,2)!~/^[0-9]/{print $0}' > ATOMS
#sed -i -ne '/'"$(sed -n '1p' ATOMS)"'/ {r ATOMS_NEW' -e ':a; n; /'"$(awk 'END{print}' ATOMS)"'/ {b}; ba}; p' $JOBNAME.fractional.cif1
#rm ATOMS ATOMS_NEW
#}

RUN_JANA(){
mkdir $JANA_COUNTER.Jana_cycle

todos *.m*
todos *.m??

 cp $JOBNAME.cif $JANA_COUNTER.Jana_cycle/$JOBNAME.start.cif

echo "Starting Jana cycle number $JANA_COUNTER"
#RUN Jana
$JANAEXE $JOBNAME @Batch.txt

python3 /usr/local/bin/powderHARcifrewrite.py
echo "Jana cycle number $JANA_COUNTER ended"

 cp $JOBNAME.m40 $JANA_COUNTER.Jana_cycle/$JOBNAME.m40
 cp $JOBNAME.m41 $JANA_COUNTER.Jana_cycle/$JOBNAME.m41
 cp $JOBNAME.m70 $JANA_COUNTER.Jana_cycle/$JOBNAME.m70
 cp $JOBNAME.m50 $JANA_COUNTER.Jana_cycle/$JOBNAME.m50
 cp $JOBNAME.m90 $JANA_COUNTER.Jana_cycle/$JOBNAME.m90
 cp $JOBNAME.m80 $JANA_COUNTER.Jana_cycle/$JOBNAME.m80
 cp $JOBNAME.m83 $JANA_COUNTER.Jana_cycle/$JOBNAME.m83
 cp $JOBNAME.m85 $JANA_COUNTER.Jana_cycle/$JOBNAME.m85
 cp $JOBNAME.m95 $JANA_COUNTER.Jana_cycle/$JOBNAME.m95
 cp $JOBNAME.cif $JANA_COUNTER.Jana_cycle/$JOBNAME.cif
 cp Jana2006-Batch.log $JANA_COUNTER.Jana_cycle/"$JOBNAME"_Jana_batch.log

 JANA_COUNTER=$[$JANA_COUNTER+1]
#if [[ "$SCCHARGES" == "true" && "$SCFCALCPROG" != "Tonto" ]]; then 
#       WRITEXYZ
#fi
}

GAMESS_ELMODB_OLD_PDB(){
	I=$[ $I + 1 ]
	PDB=$( echo $CIF | awk -F "/" '{print $NF}' )
	echo "title" > $JOBNAME.gamess.inp
	echo "prova $JOBNAME - $BASISSETG - closed shell SCF" >> $JOBNAME.gamess.inp
	echo "charge $CHARGE " >> $JOBNAME.gamess.inp
	if [ "$MULTIPLICITY" != "1" ]; then
		echo "multiplicity $MULTIPLICITY" >> $JOBNAME.gamess.inp
	fi
	echo "adapt off" >> $JOBNAME.gamess.inp
	echo "nosym" >> $JOBNAME.gamess.inp
	echo "geometry angstrom" >> $JOBNAME.gamess.inp
	if [ "$I" = "1" ]; then
		awk '$1 ~ /ATOM/ {printf "%f\t %f\t %f\t %s\t %s\n", $6, $7, $8, "carga", $3}' $CIF > atoms
	else
		awk 'NR > 2 {printf "%f\t %f\t %f\t %s\t %s\n", $2, $3, $4, "carga", $1}' $JOBNAME.xyz > atoms		
	fi
	awk '{print $5}' atoms | gawk 'BEGIN { FS = "" } {print $1}' | awk '{ if ($1 == "N") print "7.0"; else if ($1 == "H") print "1.0"; else if ($1 == "O") print "8.0"; else if ($1 == "C") print "6.0"; else if ($1 == "S") print "16.0"; }' > atoms_Z
	awk '{print $5}' atoms | gawk 'BEGIN { FS = "" } {print $1}' > atoms_names
	awk 'FNR==NR{a[NR]=$1;next}{$4=a[FNR]}1' atoms_Z atoms > full
	cp full atoms
	awk 'FNR==NR{a[NR]=$1;next}{$5=a[FNR]}1' atoms_names atoms > full
	awk '{printf "%f\t %f\t %f\t %s\t %s\n", $1, $2, $3, $4, $5}' full >> $JOBNAME.gamess.inp
	rm atoms 
	rm atoms_Z 
	rm full
	rm atoms_names
	echo "end" >> $JOBNAME.gamess.inp
	case "6-31g(d,p)" in
	 $BASISSETG ) echo "basis 6-31G**" >> $JOBNAME.gamess.inp;;
	 *) 	case "6-311g(d,p)" in
		 $BASISSETG ) echo "basis 6-311G**" >> $JOBNAME.gamess.inp;;
		 *)	echo "basis $BASISSETG" >> $JOBNAME.gamess.inp;;
		esac;;
	esac
	echo "runtype scf" >> $JOBNAME.gamess.inp
	echo "scftype rhf" >> $JOBNAME.gamess.inp
	echo "enter " >> $JOBNAME.gamess.inp
	echo "Calculating overlap integrals with gamessus, cycle number $I" 
	$GAMESS < $JOBNAME.gamess.inp > $JOBNAME.gamess.out
	echo "Gamess cycle number $I ended"
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.gamess.inp  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.gamess.inp
	cp $JOBNAME.gamess.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.gamess.out
	cp sao  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.sao
	rm ed* 
	rm gamess_input*
	if ! grep -q 'OVERLAP INTEGRALS WRITTEN ON FILE sao' "$JOBNAME.gamess.out"; then
		echo "ERROR: Calculation of overlap integrals with gamessus finished with error, please check the $I.th gamess.out file for more details" | tee -a $JOBNAME.lst
		exit 1
	else 
		echo "Calculation of overlap integrals with gamess done, writing elmodb input files"
		if [[ ! -f "$( echo $SCFCALC_BIN | awk -F "/" '{print $NF}' )" ]]; then
			cp $SCFCALC_BIN .
		fi
	
		if [ "$I" = "1" ]; then
			BASISSETDIR=$( echo "$(dirname $BASISSETDIR)/" )
			ELMOLIB=$( echo "$(dirname $ELMOLIB)/" )
#this is correct but until the elmo problem is solved I will keep it commented
#			if [[ "$INITADP" == "true" ]];then
#				echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' cif=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp		
#			else
				echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp		
#			fi
#			if [[ "$INITADP" == "true" ]];then
#				echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' cif_file='$INITADPFILE' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
#			else
				echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
#			fi
			if [[ "$NTAIL" != "0" ]]; then
				echo "$MANUALRESIDUE" >> $JOBNAME.elmodb.inp
			fi
			if [[ "$NSSBOND" != "0" ]]; then
				echo "$SSBONDATOMS" >> $JOBNAME.elmodb.inp
			fi			
		else 
#there is a problem with the conversion from fractional to cartesian inside the elmodb program, saving example files in the aga folder 4cut and changing back to always use the xyz. The elmo cannot read the cartesian cif
#			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' cif=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. comp_sao=.false. "'$END'" " > $JOBNAME.elmodb.inp
			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' xyz=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. comp_sao=.false. "'$END'" " > $JOBNAME.elmodb.inp
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' xyz_file='$JOBNAME.xyz' ntail=$NTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
			if [[ "$NTAIL" != "0" ]]; then
				echo "$MANUALRESIDUE" >> $JOBNAME.elmodb.inp
			fi
			if [[ "$NSSBOND" != "0" ]]; then
				echo "$SSBONDATOMS" >> $JOBNAME.elmodb.inp
			fi
		fi
		echo "Running elmodb"
		./$( echo $SCFCALC_BIN | awk -F "/" '{print $NF}' ) < $JOBNAME.elmodb.inp > $JOBNAME.elmodb.out
		if ! grep -q 'CONGRATULATIONS: THE ELMO-TRANSFERs ENDED GRACEFULLY!!!' "$JOBNAME.elmodb.out"; then
			echo "ERROR: elmodb finished with error, please check the $I.th elmodb.out file for more details" | tee -a $JOBNAME.lst
			exit 1
		else
			echo "elmodb job finish correctly."
			cp $JOBNAME.elmodb.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.out
			cp $JOBNAME.elmodb.inp  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.inp
			cp $JOBNAME.fchk  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.fchk
			if [ "$I" != "1" ]; then
				cp $JOBNAME.xyz  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.xyz
			fi
		fi
		if [[ "$USENOSPHERA2" == "true" ]]; then
#			awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
			echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
	                echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
       		        RUN_NOSPHERA2
        	        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
		fi
	fi
}

ELMODB(){
	I=$[ $I + 1 ]
	if [[ ! -f "$( echo $SCFCALC_BIN | awk -F "/" '{print $NF}' )" ]]; then
		cp $SCFCALC_BIN .
	fi
	if [ "$I" = "1" ]; then
		BASISSETDIR=$( echo "$(dirname $BASISSETDIR)/" )
		ELMOLIB=$( echo "$(dirname $ELMOLIB)/" )
#this is correct but until the elmo problem is solved I will keep it commented
#		if [[ "$INITADP" == "true" ]];then
#			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' cif=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp		
#		else
			echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp		
#		fi
#		if [[ "$INITADP" == "true" ]];then
#			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' cif_file='$INITADPFILE' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
#		else
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
#		fi
		if [[ "$NTAIL" != "0" ]]; then
			echo "$MANUALRESIDUE" >> $JOBNAME.elmodb.inp
		fi
		if [[ "$NSSBOND" != "0" ]]; then
			echo "$SSBONDATOMS" >> $JOBNAME.elmodb.inp
		fi
	else 
#there is a problem with the conversion from fractional to cartesian inside the elmodb program, saving example files in the aga folder 4cut and changing back to always use the xyz. The elmo cannot read the cartesian cif
#		echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' cif=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp
		echo " "'$INPUT_METHOD'"      job_title='$JOBNAME' basis_set='$BASISSETG' xyz=.true. iprint_level=1 ncpus=$NUMPROC alloc_mem=$MEM bset_path='$BASISSETDIR' lib_path='$ELMOLIB' nci=.true. "'$END'" " > $JOBNAME.elmodb.inp
		if [[ "$NTAIL" != "0" ]]; then
#			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' cif_file='$JOBNAME.fractional.cif1' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' xyz_file='$JOBNAME.xyz' ntail=$NTAIL max_atail=$ATAIL max_frtail=$FRTAIL nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
			echo "$MANUALRESIDUE" >> $JOBNAME.elmodb.inp
		else
#			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' cif_file='$JOBNAME.fractional.cif1' nssbond=$NSSBOND "'$END'"  " >>
			echo " "'$INPUT_STRUCTURE'"   pdb_file='$PDB' xyz_file='$JOBNAME.xyz' nssbond=$NSSBOND "'$END'"  " >> $JOBNAME.elmodb.inp
		fi
		if [[ "$NSSBOND" != "0" ]]; then
			echo "$SSBONDATOMS" >> $JOBNAME.elmodb.inp
		fi
	fi
	echo "Running elmodb"
	./$( echo $SCFCALC_BIN | awk -F "/" '{print $NF}' ) < $JOBNAME.elmodb.inp > $JOBNAME.elmodb.out
	if ! grep -q 'CONGRATULATIONS: THE ELMO-TRANSFERs ENDED GRACEFULLY!!!' "$JOBNAME.elmodb.out"; then
		echo "ERROR: elmodb finished with error, please check the $I.th elmodb.out file for more details" | tee -a $JOBNAME.lst
		exit 1
	else
		echo "elmodb job finish correctly."
                if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
		        mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
                fi
		cp $JOBNAME.elmodb.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.out
		cp $JOBNAME.elmodb.inp  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.inp
		cp $JOBNAME.fchk  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.elmodb.fchk
		if [ "$I" != "1" ]; then
			cp $JOBNAME.xyz  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.xyz
		fi
	fi
	if [[ "$USENOSPHERA2" == "true" ]]; then
#		awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
                echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
	        RUN_NOSPHERA2
                echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
	fi
}

TONTO_TO_ORCA(){
	I=$[ $I + 1 ]
	echo "Extracting XYZ for Orca cycle number $I"
	if [ "$SCFCALCPROG" = "optorca" ]; then
		ORCAOPT=" Opt"
	fi
	if [ "$METHOD" = "rks" ]; then
		echo "! blyp $BASISSETG $ORCAOPT" > $JOBNAME.inp
	else
		if [ "$METHOD" = "uks" ]; then
			echo "! ublyp $BASISSETG $ORCAOPT" > $JOBNAME.inp
		else
			echo "! $METHOD $BASISSETG $ORCAOPT" > $JOBNAME.inp
		fi
	fi
	echo "" >> $JOBNAME.inp
	echo "%pal nprocs $NUMPROC end" >> $JOBNAME.inp
	echo "" >> $JOBNAME.inp
	echo "%output"  >> $JOBNAME.inp
	echo "   PrintLevel=Normal"  >> $JOBNAME.inp
	echo "   Print[ P_Basis       ] 2"  >> $JOBNAME.inp
	echo "   Print[ P_GuessOrb    ] 1"  >> $JOBNAME.inp
	echo "   Print[ P_MOs         ] 1"  >> $JOBNAME.inp
	echo "   Print[ P_Density     ] 1"  >> $JOBNAME.inp
	echo "   Print[ P_SpinDensity ] 1"  >> $JOBNAME.inp
	echo "end"  >> $JOBNAME.inp
	echo ""  >> $JOBNAME.inp
	if [ "$SCCHARGES" = "true" ]; then 
		echo '% pointcharges "'$JOBNAME'.qxyz"'  >> $JOBNAME.inp
		sed -i '1,12{/.*/d}' cluster_charges 
		sed -i '$ d' cluster_charges
		sed -i -n '1~3p' cluster_charges 
		sed -i '{/^$/d}' cluster_charges 
		LINEONE=$(wc -l cluster_charges | awk '{print $1}')
		echo $LINEONE > $JOBNAME.qxyz
		awk '{printf " %12s  %12s %12s  %12s\n",$4,$1,$2,$3}' cluster_charges >> $JOBNAME.qxyz
                echo "" >> $JOBNAME.qxyz
		echo ""  >> $JOBNAME.inp
		if [[ "$ADDNUCINTER" == "true" ]]; then
			echo "%method" >> $JOBNAME.inp
			echo "   DoEQ true" >> $JOBNAME.inp
			echo "end"  >> $JOBNAME.inp
			echo ""  >> $JOBNAME.inp
		fi
	fi
	echo "* xyz $CHARGE $MULTIPLICITY"  >> $JOBNAME.inp
	awk 'NR>2' $JOBNAME.xyz  >> $JOBNAME.inp
	echo "*"  >> $JOBNAME.inp
	if [[ "$GAUSGEN" == "true" ]]; then
		cat basis_gen.txt >> $JOBNAME.inp
		echo "" >> $JOBNAME.inp
	fi
	echo "Running Orca, cycle number $I" 
        if [ -f $JOBNAME.gbw ]; then
                rm $JOBNAME.gbw
        fi
	$SCFCALC_BIN $JOBNAME.inp > $JOBNAME.out
	echo "Orca cycle number $I ended"
	if ! grep -q '****ORCA TERMINATED NORMALLY****' "$JOBNAME.out"; then
		echo "ERROR: Orca job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
	echo "Generation of molden file for Orca cycle number $I"
	if [[ "$(which orca_2mkl.exe)" == "" ]]; then
		orca_2mkl $JOBNAME -molden  > /dev/null
	else 	
		orca_2mkl.exe $JOBNAME -molden  > /dev/null
	fi
	echo "Generation of wfn file for Orca cycle number $I"
	if [[ "$(which orca_2aim.exe)" == "" ]]; then
		orca_2aim $JOBNAME  > /dev/null
	else
		orca_2aim.exe $JOBNAME  > /dev/null
	fi
 	NAPONE=$[ $NUMBEROFATOMS + 1 ]
	STARTLINE=$(grep -n "  $NAPONE 0" $JOBNAME.molden.input | awk -F: '{print $1}')
	ENDLINE=$(grep -n "\[5D\]" $JOBNAME.molden.input | awk -F: '{print $1}')
	if [[ "$STARTLINE" != "" && "$ENDLINE" != "" ]]; then
		sed -i "$STARTLINE","$[ $ENDLINE - 1 ]"'{/.*/d;}' $JOBNAME.molden.input
		sed -i '/Q\ /d' $JOBNAME.molden.input
	fi
#	echo "Orca cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
        NUMATOMWFN=$(grep -m1 " Q " $JOBNAME.wfn | awk '{ print $2 }' )
        NUMATOMWFN=$[$NUMATOMWFN -1]
        awk -v  NUMATOMWFN=$NUMATOMWFN 'NR==2 {gsub($7, NUMATOMWFN, $0); print}1' $JOBNAME.wfn > temp.wfn
        sed -i '2d' temp.wfn
        sed -i '/ Q /d' temp.wfn
        mv temp.wfn $JOBNAME.wfn
	if [[ "$USENOSPHERA2" == "true" ]]; then
		#awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I in progress"
		RUN_NOSPHERA2
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I ended"
	fi
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.inp          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.inp
	cp $JOBNAME.qxyz         $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.qxyz
	cp $JOBNAME.molden.input $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input
	cp $JOBNAME.out          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
	if [[ "$USENOSPHERA2" == "true" ]]; then
		cp $JOBNAME.wfn $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
	fi
}

TONTO_TO_OCC(){
	I=$[ $I + 1 ]
	echo "Extracting XYZ for OCC cycle number $I"
	if [ "$SCFCALCPROG" = "optorca" ]; then
		OPT=" Opt"
	fi
	echo "Running OCC, cycle number $I" 
        if [ -f $JOBNAME.gbw ]; then
                rm $JOBNAME.gbw
        fi
	if [ "$SCCHARGES" = "true" ]; then 
                if [ "$SCDIPOLES" = "true" ]; then       
                	awk '{a[NR]=$0}{b=13}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' cluster_charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $4, $1, $2, $3 }' >> $JOBNAME.qxyz
                else
                	awk '{a[NR]=$0}{b=13}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;d+=3)print a[d]}' cluster_charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $4, $1, $2, $3 }' >> $JOBNAME.qxyz
                fi
	fi
	if [ "$SCCHARGES" = "true" ]; then 
		$SCFCALC_BIN scf $JOBNAME.xyz --method $METHOD --basis $BASISSETG -o fchk --point-charges $JOBNAME.qxyz > $JOBNAME.out
	else 
		$SCFCALC_BIN scf $JOBNAME.xyz --method $METHOD --basis $BASISSETG -o fchk > $JOBNAME.out
	fi
	echo "OCC cycle number $I ended"
	if ! grep -q 'A job well done' "$JOBNAME.out"; then
		echo "ERROR: OCC job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.xyz          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.xyz
#	cp $JOBNAME.owf$JOBNAME.fchk $JOBNAME.fchk
#	cp $JOBNAME.owf.$JOBNAME.fchk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
	cp $JOBNAME.owf.fchk     $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
	cp $JOBNAME.out          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
        if [ -f "cluster_charges" ]; then
		cp cluster_charges          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.cluster_charges
        fi
}

TONTO_HEADER(){
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" > stdin
	echo "!!!                                                                                         !!!" >> stdin
	echo "!!!                        This stdin was written with lamaGOET                             !!!" >> stdin
	echo "!!!                                                                                         !!!" >> stdin
	echo "!!!                    script written by Lorraine Andrade Malaspina                         !!!" >> stdin
	echo "!!!                        contact: lorraine.malaspina@gmail.com                            !!!" >> stdin
	echo "!!!                                                                                         !!!" >> stdin
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >> stdin
	echo "{ " >> stdin
	echo "" >> stdin
	echo "   keyword_echo_on" >> stdin
	echo "" >> stdin
}

READ_ELMO_FCHK(){
        echo "   name= $JOBNAME" >> stdin 
        echo "" >> stdin
	echo "   read_g09_fchk_file $JOBNAME.fchk" >> stdin
        echo "" >> stdin
}

READ_GAUSSIAN_FCHK(){
        echo "   name= $JOBNAME" >> stdin 
        echo "" >> stdin
        if [[ "$POWDER_HAR" == "false" || ( "$POWDER_HAR" == "true" && "$SCFCALCPROG" == "Tonto") ]]; then
	        echo "   read_g09_fchk_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk" >> stdin
        else
	        echo "   read_g09_fchk_file $JOBNAME.fchk" >> stdin
        fi
        echo "" >> stdin
}

READ_ORCA_FCHK(){
        echo "   name= $JOBNAME" >> stdin 
        echo "" >> stdin
        if [[ "$POWDER_HAR" == "false" || ( "$POWDER_HAR" == "true" && "$SCFCALCPROG" == "Tonto") ]]; then
               	echo "   read_molden_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input" >> stdin
        else       
        	echo "   read_molden_file $JOBNAME.molden.input" >> stdin
        fi
        echo "" >> stdin
}

READ_CRYSTAL_WFN(){
        echo "" >> stdin
#        echo "   read_molden_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input" >> stdin
##        echo "   read_CRYSTAL_XML_file $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.XML" >> stdin #this one was the one working before
##        echo "   c23_XML_file_name= $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.XML" >> stdin # this is the one working before, exchanging to use the one in the work folder to compat the files.
        echo "   c23_XML_file_name= GenerateXML.XML" >> stdin 
        echo "   process_cif_and_c23_xml" >> stdin 
#       echo "This routine is still being writen, come back later. " | tee -a $JOBNAME.lst
#       unset MAIN_DIALOG
#       exit 0
        echo "" >> stdin
        echo "   name= $JOBNAME" >> stdin 
        echo "" >> stdin
}

DEFINE_JOB_NAME(){
	echo "   name= $JOBNAME" >> stdin
        echo "" >> stdin
}

CHANGE_JOB_NAME(){
	echo "   name= $JOBNAME.XCW" >> stdin
        echo "" >> stdin
}

PROCESS_CIF(){
	echo "   ! Process the CIF" >> stdin
	echo "   CIF= {" >> stdin
	if [[ $POWDER_HAR == "false" ]]; then 
		if [[ $J == 0 ]]; then 
			if [[ ( "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ) && "$SCFCALCPROG" != "Tonto" ]]; then
#      				echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
       				echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1" >> stdin
			else
				echo "       file_name= $CIF" >> stdin
			fi
			if [ "$XHALONG" = "true" ]; then
		           	if [[ ! -z "$BHBOND" ]]; then
				   	echo "       BH_bond_length= $BHBOND angstrom" >> stdin
			   	fi
		           	if [[ ! -z "$CHBOND" ]]; then
				   	echo "       CH_bond_length= $CHBOND angstrom" >> stdin
			   	fi
		           	if [[ ! -z "$NHBOND" ]]; then
				   	echo "       NH_bond_length= $NHBOND angstrom" >> stdin
			   	fi
                	   	if [[ ! -z "$OHBOND" ]]; then
				   	echo "       OH_bond_length= $OHBOND angstrom" >> stdin
			   	fi
			fi
		elif [ $J = 1 ]; then 
			if [[ "$SCCHARGES" == "true" && ("$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca") ]]; then
#	#			if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca" ]]; then
					if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
#						echo "       file_name= 0.tonto_cycle.$JOBNAME/0.$JOBNAME.cartesian.cif2" >> stdin
       				                echo "       file_name= 0.tonto_cycle.$JOBNAME/0.$JOBNAME.fractional.cif1" >> stdin
					else
						echo "       file_name= $CIF" >> stdin
					fi
			else
#                               if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
#       				echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif" >> stdin
#                               else
#        				echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
       				        echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1" >> stdin
#                               fi
        		fi
        	else
#                       if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
#       			echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif" >> stdin
#                       else
#        			echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2" >> stdin
       				echo "       file_name= $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1" >> stdin
#                       fi
		fi
                if [ "$XHALONG" = "true" ]; then
                        	if [ ! -z "$BHBOND" ]; then
                	   	echo "       BH_bond_length= $BHBOND angstrom" >> stdin
                   	fi
                          	if [ ! -z "$CHBOND" ]; then
                	   	echo "       CH_bond_length= $CHBOND angstrom" >> stdin
                   	fi
                          	if [ ! -z "$NHBOND" ]; then
	                	echo "       NH_bond_length= $NHBOND angstrom" >> stdin
                   	fi
                          	if [ ! -z "$OHBOND" ]; then
                	   	echo "       OH_bond_length= $OHBOND angstrom" >> stdin
                   	fi
                fi
		echo "    }" >> stdin
		echo "" >> stdin
                if [[ "$SCFCALCPROG" != "Crystal14" && "$SCFCALCPROG" != "CP2K" ]]; then
        		echo "   process_CIF" >> stdin
		        echo "" >> stdin
                fi
	else 
		echo "       file_name= $CIF" >> stdin
		echo "    }" >> stdin
		echo "" >> stdin
                if [[ "$SCFCALCPROG" != "Crystal14" && "$SCFCALCPROG" != "CP2K" ]]; then
        		echo "   process_CIF" >> stdin
	        	echo "" >> stdin
                fi
		COMPLETECIFBLOCK

        fi
#	if [ $J = 1 ]; then 
#		if [[ "$SCCHARGES" == "true" && ("$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca") ]]; then
#			if [[ "$COMPLETECIF" == "true" ]]; then
#				COMPLETECIFBLOCK	
#			fi
#		fi
#	fi
}

TONTO_BASIS_SET(){
	echo "   basis_directory= $BASISSETDIR" >> stdin
	echo "   basis_name= $BASISSETT" >> stdin
	echo "" >> stdin
}

NOT_TONTO_BASIS_SET(){
	echo "   basis_directory= $BASISSETDIR" >> stdin
	echo "   basis_name= $BASISSETG" >> stdin
	echo "" >> stdin
}

DISPERSION_COEF(){
	echo "   	 dispersion_coefficients= {" >> stdin
	echo "   	 $(cat DISP_inst.txt)" >> stdin
	echo "   	 }" >> stdin
	echo "" >> stdin
}

EXTI_REF(){
	echo "   	 refine_extinction= $EXTI" >> stdin
	echo "" >> stdin
}

CHARGE_MULT(){
	echo "   charge= $CHARGE" >> stdin       
	echo "   multiplicity= $MULTIPLICITY" >> stdin
        echo "" >> stdin
}

TONTO_IAM_BLOCK(){
	echo ""
	echo "   crystal= {    " >> stdin
	if [[ "$SCFCALCPROG" = "elmodb" && "$INITADP" == "false" ]]; then
		echo "      REDIRECT tonto.cell" >> stdin
	fi
	echo "      xray_data= {   " >> stdin
	echo "         optimise_extinction= false" >> stdin
	echo "         correct_dispersion= $DISP" >> stdin
	echo "         wavelength= $WAVE Angstrom" >> stdin
	if [ "$REFANHARM" == "true" ]; then
		if [[ "$THIRDORD" == "false" && "$FOURTHORD" == "true" ]]; then
			echo "         refine_4th_order_only= true " >> stdin
			echo "         refine_4th_order_for_atoms= { $ANHARMATOMS } " >> stdin
		elif [[ "$THIRDORD" == "true" && "$FOURTHORD" == "true" ]]; then
			echo "         refine_4th_order_for_atoms= { $ANHARMATOMS } " >> stdin
		elif [[ "$THIRDORD" == "true" && "$FOURTHORD" == "false" ]]; then
			echo "         refine_3rd_order_for_atoms= { $ANHARMATOMS } " >> stdin
		else 
			echo "ERROR: Please select at least one of the anharmonic terms to refine" | tee -a $JOBNAME.lst
			exit 1
		fi
	fi
	if [[ "$ISFCF" != "true" ]]; then
		echo "         REDIRECT $HKL" >> stdin
	else
		echo "         read_fcf_file $HKL" >> stdin
	fi
	if [[ "$USEEQUIV" = "true" ]]; then
		echo "         use_equivalents= $USEEQUIV" >> stdin
        fi
	if [[ "$FCUT" != "0" ]]; then
		echo "         f_sigma_cutoff= $FCUT" >> stdin
	fi
	if [[ "$MINCORCOEF" != "" ]]; then
		echo "         min_correlation= $MINCORCOEF"  >> stdin
	fi
        if [[ "$USENOSPHERA2" != "true" ]]; then
	        echo "         tol_for_shift_on_esd= $CONVTOL" >> stdin
	        echo "         refine_H_U_iso= yes" >> stdin
        fi
	echo "" >> stdin
	echo "         show_fit_output= true" >> stdin
	echo "         show_fit_results= true" >> stdin
	echo "" >> stdin
	echo "      }  " >> stdin
	echo "   }  " >> stdin
	echo "" >> stdin
        if [[ "$SCFCALCPROG" != "Crystal14" && "$DEFRAGNETW" != "true" ]]; then
        	echo "   ! Geometry    " >> stdin
	        echo "   put" >> stdin
        	echo "" >> stdin
        fi
	echo "   IAM_refinement" >> stdin
	echo "" >> stdin
        if [[ "$ONLYIAMTONTO" == "true" ]]; then 
	        echo "}" >> stdin
	        echo "" >> stdin
	        echo "Running Tonto IAM refinement." 
                $TONTO
		echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
		echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
		exit 0
        fi
}

WRITE_DENSITY_PARTITION_MODEL(){
	if [[ "$SCFCALCPROG" != "Tonto" ]]; then
		echo "         partition_model= oc-crystal23" >> stdin
		echo "         stockholder_model= ${STOCKHOLDER_MODEL:-cluster}" >> stdin
		return 0
	fi
	case "${PARTITION_MODEL:-oc-hirshfeld}" in
		auto|tonto|oc-hirshfeld|crystal23|oc-crystal23|"")
			echo "         partition_model= oc-hirshfeld" >> stdin
			;;
		observed|oc-observed)
			echo "         partition_model= oc-observed" >> stdin
			echo "         observed_density_shrinkage= ${OBSERVED_DENSITY_SHRINKAGE:-0.5}" >> stdin
			echo "         observed_density_min_TF= ${OBSERVED_DENSITY_MIN_TF:-0.1}" >> stdin
			echo "         observed_zero_phase_sign= ${OBSERVED_ZERO_PHASE_SIGN:-0}" >> stdin
			;;
		*)
			echo "ERROR: Unsupported Tonto PARTITION_MODEL '${PARTITION_MODEL}'. Use oc-hirshfeld or oc-observed." | tee -a "$JOBNAME.lst" >&2
			return 1
			;;
	esac
}

CRYSTAL_BLOCK(){
	echo "" >> stdin
	echo "   crystal= {    " >> stdin
	if [[ "$SCFCALCPROG" == "elmodb" && $J == 0 && "$INITADP" == "false" ]]; then
		echo "      REDIRECT tonto.cell" >> stdin
	fi
#	if [[ "$POWDER_HAR" == "true" && $PROFILE_COUNTER -gt 1  ]]; then
#		echo "      REDIRECT tonto.cell" >> stdin
#	fi
	if [[ "$SCFCALCPROG" == "optgaussian" || "$SCFCALCPROG" == "optorca" ]]; then 
		echo "      REDIRECT tonto.cell" >> stdin
	fi
        if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
                echo "      spacegroup= { hermann_mauguin_symbol= "'"'$SPACEGROUPHM'"'" }" >> stdin
        fi
	if [[ "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" ]]; then 
		echo "      xray_data= {   " >> stdin
	        if [[ "$POWDER_HAR" != "true" ]]; then 
                        # Tonto's thermal_smearing_model= keyword is gone. Its job -- choosing
                        # how the density is partitioned before thermal smearing -- now belongs
                        # to partition_model=, written immediately below. The old value
                        # "atom-based" meant one-centre partitioning, which is what the "oc-"
                        # prefix of every current value denotes, so oc-hirshfeld and friends
                        # already carry it. Emitting both would set an invalid value and then
                        # repeat the key.
                        if [[ "$SCFCALCPROG" == "Crystal14" || "$SCFCALCPROG" == "CP2K" || "$SCFCALCPROG" == "Tonto" ]]; then
				WRITE_DENSITY_PARTITION_MODEL || return 1
                        else
                                echo "         partition_model= oc-hirshfeld" >> stdin
                        fi
                        if [[ "$PLOT_TONTO" == "false" ]]; then
        			echo "         optimise_extinction= false" >> stdin
        			echo "         correct_dispersion= $DISP" >> stdin
        			echo "         optimise_scale_factor= true" >> stdin
        			echo "         refine_extinction= $EXTI" >> stdin
        		fi
                fi
		echo "         wavelength= $WAVE Angstrom" >> stdin
		if [[ "$REFANHARM" == "true" && "$PLOT_TONTO" == "false" ]]; then
			if [[ "$THIRDORD" == "false" && "$FOURTHORD" == "true" ]]; then
				echo "         refine_4th_order_only= true " >> stdin
				echo "         refine_4th_order_for_atoms= { $ANHARMATOMS } " >> stdin
			elif [[ "$THIRDORD" == "true" && "$FOURTHORD" == "true" ]]; then
				echo "         refine_4th_order_for_atoms= { $ANHARMATOMS } " >> stdin
			elif [[ "$THIRDORD" == "true" && "$FOURTHORD" == "false" ]]; then
				echo "         refine_3rd_order_for_atoms= { $ANHARMATOMS } " >> stdin
			else 
				echo "ERROR: Please select at least one of the anharmonic terms to refine" | tee -a $JOBNAME.lst
				exit 1
			fi
		fi
	        if [[ "$POWDER_HAR" != "true" ]]; then 
			if [[ "$ISFCF" != "true" ]]; then
				echo "         REDIRECT $HKL" >> stdin
			else
				echo "         read_fcf_file $HKL" >> stdin
			fi
	                if [[ "$USEEQUIV" = "true" ]]; then
                		echo "         use_equivalents= $USEEQUIV" >> stdin
                        fi
	                if [[ "$FCUT" != "0" ]]; then
        		        echo "         f_sigma_cutoff= $FCUT" >> stdin
                        fi
        		if [[ "$PLOT_TONTO" == "false" ]]; then
        			if [[ "$MINCORCOEF" != "" ]]; then
        				echo "         min_correlation= $MINCORCOEF"  >> stdin
        			fi
        			echo "         tol_for_shift_on_esd= $CONVTOL" >> stdin
        			echo "         refine_H_U_iso= $HADP" >> stdin
        			if [[ "$SCFCALCPROG" == "Tonto" && "$IAMTONTO" == "true" ]]; then 
        				echo "" >> stdin
        				echo "         show_fit_output= false" >> stdin
        				echo "         show_fit_results= false" >> stdin
        			fi
        			echo "" >> stdin
        			if [[ "$SCFCALCPROG" != "Tonto" ]]; then 
        				echo "	 show_fit_output= TRUE" >> stdin
        				echo "	 show_fit_results= TRUE" >> stdin
        				echo "" >> stdin
        			fi
        			if [ "$POSONLY" = "true" ]; then 
        				echo "	 refine_positions_only= $POSONLY" >> stdin
        			fi
        			if [ "$ADPSONLY" = "true" ]; then 
        				echo "	 refine_ADPs_only= $ADPSONLY" >> stdin
        			fi
        			if [ "$REFHADP" = "false" ]; then
        				if [ "$ADPSONLY" != "true" ]; then 
        					echo "	 refine_H_ADPs= $REFHADP" >> stdin 
        				fi
        			fi
        			if [ "$REFHPOS" = "false" ]; then
        				if [[ "$ADPSONLY" != "true" ]]; then
        					echo "	 refine_H_positions= $REFHPOS" >> stdin 
        				fi
        			fi
        			if [ "$REFNOTHING" = "true" ]; then
        				echo "	 refine_nothing_for_atoms= { $ATOMLIST }" >> stdin 
        			fi
        			if [ "$REFUISO" = "true" ]; then
        				echo "	 refine_u_iso_for_atoms= { $ATOMUISOLIST }" >> stdin 
        			fi
        			if [[ "$MAXLSCYCLE" != "" ]]; then
        				echo "	 max_iterations= $MAXLSCYCLE" >> stdin 
        			fi
        		fi
                fi
                if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
		        echo "         do_residual_cube= YES " >> stdin
                fi
		echo "      }  " >> stdin
	fi
	echo "   }  " >> stdin
	echo "" >> stdin
}

SET_H_ISO(){ 
	echo "	 set_isotropic_h_adps"  >> stdin
	echo "" >> stdin
}

PUT_GEOM(){
        if [[ "$SCFCALCPROG" != "Crystal14" && "$SCFCALCPROG" != "CP2K" && "$DEFRAGNETW" != "true" ]]; then
	        echo "   ! Geometry    " >> stdin
        	echo "   put" >> stdin
        	echo "" >> stdin
        fi
}

BECKE_GRID(){
		echo "   !Tight grid" >> stdin
		echo "   becke_grid = {" >> stdin
		echo "      set_defaults" >> stdin
		echo "      accuracy= $ACCURACY" >> stdin
		echo "      pruning_scheme= $BECKEPRUNINGSCHEME" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
}

SCF_BLOCK_NOT_TONTO(){
	if [[ "$SCCHARGES" == "true" && "$SCFCALCPROG" != "elmodb" ]]; then 
		echo "     ! SC cluster charge SCF" >> stdin
		echo "      scfdata= {" >> stdin
		if [[ "$METHOD" != "rks" && "$METHOD" != "rhf" && "$METHOD" != "uhf" && "$METHOD" != "uks" ]]; then
                        if [[ "$METHOD" == "ub3lyp" || "$METHOD" == "UB3LYP" ]]; then
		                echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= uks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
                		echo "      dft_correlation_functional= b3lypgc" >> stdin
                        elif [[ "$METHOD" == "b3lyp" || "$METHOD" == "B3LYP" ]]; then
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
                		echo "      dft_correlation_functional= b3lypgc" >> stdin
                        else
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
                		echo "      dft_correlation_functional= b3lypgc" >> stdin
                        fi
			echo "      output= true " >> stdin
		else
                        if [[ "$METHOD" == "uhf" || "$METHOD" == "UHF" || "$METHOD" == "UKS" || "$METHOD" == "uks" ]]; then
		        	echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
                        elif [[ "$METHOD" == "rhf" || "$METHOD" == "RHF" || "$METHOD" == "RKS" || "$METHOD" == "rks" ]]; then
		        	echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
                        fi
			echo "      kind= $METHOD" >> stdin
			echo "      output= true " >> stdin
		fi
		echo "      use_SC_cluster_charges= TRUE" >> stdin
		echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
		echo "      defragment= $DEFRAG" >> stdin
		echo "      save_cluster_charges= true" >> stdin
		echo "      convergence= 0.001" >> stdin
		echo "      diis= { convergence_tolerance= 0.0002 }" >> stdin
		echo "      output= YES" >> stdin
		echo "      output_results= YES" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
		echo "   make_scf_density_matrix" >> stdin
		echo "   assign_NOs_to_MOs " >> stdin
		echo "   make_hirshfeld_inputs" >> stdin
		echo "   make_fock_matrix" >> stdin
		echo "" >> stdin
		echo "   ! SC cluster charge SCF" >> stdin
		echo "   scfdata= {" >> stdin
		echo "      initial_density= promolecule" >> stdin
		if [[ "$METHOD" != "rks" && "$METHOD" != "rhf" && "$METHOD" != "uhf" && "$METHOD" != "uks" ]]; then
                        if [[ "$METHOD" == "ub3lyp" || "$METHOD" == "UB3LYP" ]]; then
		                echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= uks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
        			echo "      dft_correlation_functional= b3lypgc" >> stdin
                        elif [[ "$METHOD" == "b3lyp" || "$METHOD" == "B3LYP" ]]; then
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
        			echo "      dft_correlation_functional= b3lypgc" >> stdin
                        else
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
        			echo "      dft_correlation_functional= b3lypgc" >> stdin
                        fi
			echo "      output= true " >> stdin
		else
                        if [[ "$METHOD" == "uhf" || "$METHOD" == "UHF" || "$METHOD" == "UKS" || "$METHOD" == "uks" ]]; then
	                	echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
                        elif [[ "$METHOD" == "rhf" || "$METHOD" == "RHF" || "$METHOD" == "RKS" || "$METHOD" == "rks" ]]; then
	                	echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
                        fi
			echo "      kind= $METHOD" >> stdin
			echo "      output= true " >> stdin
		fi
		echo "      use_SC_cluster_charges= TRUE" >> stdin
		echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
		echo "      defragment= $DEFRAG" >> stdin
		echo "      put_cluster" >> stdin
		echo "      put_cluster_charges" >> stdin
		echo "" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
		if [[ "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" && "$J" != "0" ]]; then 
	                if [[ "$POWDER_HAR" != "true" ]]; then
			        echo "   ! Make Hirshfeld structure factors" >> stdin
#			        echo "   fit_hirshfeld_atoms" >> stdin
                                if [[ "$SCFCALCPROG" == "Crystal14" || "$SCFCALCPROG" == "CP2K" || "$SCFCALCPROG" == "Tonto" ]]; then
                                        echo "   phar_defragment" >> stdin
                                fi
			        echo "   ha_fit" >> stdin
        			echo "" >> stdin
	        	fi
                fi
                if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
                        if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
                		if [[ "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "Gaussian" ]]; then
		                       	echo "   write_xyz_file" >> stdin
				else
	                                echo "   write_fragment_xyz_file " >> stdin
				fi
                        else 
                                echo "   write_xyz_file" >> stdin
                        fi
                else 
                        echo "   write_xtal23_xyz_file" >> stdin
                fi
	else
		if [[ "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" ]]; then 
	                if [[ "$POWDER_HAR" != "true" ]]; then
			        echo "   ! Make Hirshfeld structure factors" >> stdin
				if [[ "$SCFCALCPROG" == "Orca" ]]; then
			                echo "   make_scf_density_matrix" >> stdin
			                echo "   assign_NOs_to_MOs " >> stdin
			                echo "   make_hirshfeld_inputs" >> stdin
			                echo "   make_fock_matrix" >> stdin
				fi
#       			echo "   fit_hirshfeld_atoms" >> stdin
                                if [[ "$SCFCALCPROG" == "Crystal14" || "$SCFCALCPROG" == "CP2K" || "$SCFCALCPROG" == "Tonto" ]]; then
                                        echo "   phar_defragment" >> stdin
                                fi
			        echo "   ha_fit" >> stdin
        			echo "" >> stdin
                        else
                                echo "   put_cif" >> stdin
        		fi
                fi
                if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
                        if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
                		if [[ "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "Gaussian" ]]; then
		                       	echo "   write_xyz_file" >> stdin
				else
	                                echo "   write_fragment_xyz_file " >> stdin
				fi
                        else 
                                echo "   write_xyz_file" >> stdin
                        fi
                else 
                        echo "   write_xtal23_xyz_file" >> stdin
                fi
	fi
}

SCF_BLOCK_PROM_TONTO(){
	echo "   ! Normal SCF" >> stdin
	echo "   scfdata= {" >> stdin
	echo "      initial_density= promolecule " >> stdin
	echo "      kind= rhf" >> stdin   # this is the promolecule guess, should be always rhf
	echo "      output= true " >> stdin
	echo "      use_SC_cluster_charges= FALSE" >> stdin
        if [[ "$LINEDEP" != "" ]]; then
	        echo "      linear_dependence_tol= $LINEDEP" >> stdin
        fi
	echo "      convergence= 0.001" >> stdin
	echo "      diis= { convergence_tolerance= 0.0002 }" >> stdin
	echo "   }" >> stdin
	echo "" >> stdin
	echo "   scf" >> stdin
	echo "" >> stdin
}

SCF_BLOCK_REST_TONTO(){
	echo "   ! SC cluster charge SCF" >> stdin
	echo "   scfdata= {" >> stdin
	echo "      initial_MOs= restricted" >> stdin
	if [[ "$METHOD" == "b3lyp" || "$METHOD" == "B3LYP" || "$METHOD" == "rks" || "$METHOD" == "RKS" ]]; then
		echo "      kind= rks" >> stdin
	        echo "      output= true " >> stdin
		echo "      dft_exchange_functional= b3lypgx" >> stdin
		echo "      dft_correlation_functional= b3lypgc" >> stdin
	elif [[ "$METHOD" == "blyp" || "$METHOD" == "BLYP" ]]; then
		echo "      kind= rks" >> stdin
	        echo "      output= true " >> stdin
		echo "      dft_exchange_functional= becke88" >> stdin
		echo "      dft_correlation_functional= lyp" >> stdin
	else 
		echo "      kind= $METHOD" >> stdin
	        echo "      output= true " >> stdin
	fi
        if [[ "$LINEDEP" != "" ]]; then
	        echo "      linear_dependence_tol= $LINEDEP" >> stdin
        fi
	if [[ "$SCCHARGES" == "true" ]]; then 
		echo "      use_SC_cluster_charges= TRUE" >> stdin
		echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
		echo "      defragment= $DEFRAG" >> stdin
	else
		echo "      use_SC_cluster_charges= FALSE" >> stdin
	fi
	if [[ "$PLOT_TONTO" == "false" ]]; then
		echo "      convergence= 0.001" >> stdin
		echo "      diis= { convergence_tolerance= 0.0002 }" >> stdin
	fi
	echo "   }" >> stdin
	echo "" >> stdin
	if [[ "$PLOT_TONTO" == "false" ]]; then
	        echo "   scf" >> stdin
	        echo "" >> stdin
        fi
	if [[ "$XCWONLY" != "true" && "$PLOT_TONTO" == "false" && "$POWDER_HAR" != "true" ]]; then
		echo "   ! Make Hirshfeld structure factors" >> stdin
		echo "   refine_hirshfeld_atoms" >> stdin
		echo "" >> stdin
	fi
	if [[ "$USENOSPHERA2" == "true" ]]; then
		echo "   write_aim2000_wfn_file" >> stdin
		echo "" >> stdin
		echo "   put_cif" >> stdin
		echo "" >> stdin
	fi
}

SCF_TO_TONTO(){
	TONTO_HEADER
	if [ "$SCFCALCPROG" = "elmodb" ]; then
		READ_ELMO_FCHK
	fi
	if [[ "$SCFCALCPROG" != "elmodb" && "$SCFCALCPROG" != "optgaussian" && "$POWDER_HAR" == "true" ]]; then
		PROCESS_CIF
		DEFINE_JOB_NAME
	fi
	if [[ "$SCFCALCPROG" == "Gaussian" ||  "$SCFCALCPROG" == "optgaussian" || "$SCFCALCPROG" == "OCC" ]]; then
		READ_GAUSSIAN_FCHK
	elif [[ "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "optorca" ]]; then
		READ_ORCA_FCHK
#       elif [ "$SCFCALCPROG" = "Crystal14" ]; then
#	        READ_CRYSTAL_WFN
	else
		DEFINE_JOB_NAME
	fi
	echo "" >> stdin
	if [[ "$SCFCALCPROG" != "elmodb" && "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" && "$POWDER_HAR" != "true" ]]; then
		PROCESS_CIF
		DEFINE_JOB_NAME
               if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
                        #TONTO_BASIS_SET
                        NOT_TONTO_BASIS_SET
        	        CHARGE_MULT
        	        READ_CRYSTAL_WFN
               fi
	fi

	# BEGIN LAMAGOET CP2K INTEGRATION: periodic density import
	if [ "$SCFCALCPROG" = "CP2K" ]; then
		CP2K_TONTO_PERIODIC_SETUP || return 1
	fi
	# END LAMAGOET CP2K INTEGRATION: periodic density import
	if [[ $J -gt 0 && "$SCFCALCPROG" == "elmodb" ]]; then
		PROCESS_CIF
		DEFINE_JOB_NAME
	fi
	if [[ $J -eq 0 && "$SCFCALCPROG" == "elmodb" && "$INITADP" == "true" ]]; then
		echo "   ! Process the CIF" >> stdin
		echo "   CIF= {" >> stdin
		echo "       file_name= $INITADPFILE" >> stdin
		echo "    }" >> stdin
		echo "" >> stdin
		echo "   process_CIF" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin
		echo "" >> stdin
	fi
	if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
		TONTO_BASIS_SET
		if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
			COMPLETECIFBLOCK
		fi
	fi
#       if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
#       	echo "   use_spherical_basis= TRUE" >> stdin
#               TONTO_BASIS_SET
#       fi
	if [[ "$DISP" == "yes" ]]; then 
		DISPERSION_COEF
	fi
        if [[ "$SCFCALCPROG" != "Crystal14" && "$SCFCALCPROG" != "CP2K" ]]; then
         	CHARGE_MULT
        fi
	if [[ $J == 0 && "$IAMTONTO" == "true" ]]; then 
		TONTO_IAM_BLOCK
	fi
	CRYSTAL_BLOCK
       	PUT_GEOM
	if [[ "$POWDER_HAR" != "true" ]]; then
        	if [[ "$USEBECKE" == "true" ]]; then 
        		BECKE_GRID
        	fi
        	if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "CP2K" ]]; then
        	    SCF_BLOCK_NOT_TONTO
        	elif [ "$SCFCALCPROG" = "CP2K" ]; then
        	    # BEGIN LAMAGOET CP2K INTEGRATION: periodic Hirshfeld fit
	            CP2K_TONTO_SCFDATA || return 1
                    echo "   ! Make Hirshfeld structure factors from the periodic CP2K density" >> stdin
                    # Rebuild the pHAR atom mapping for this newly imported density
                    # and refined geometry. This runs on every cycle; atomic form
                    # factors are never reused across HAR cycles.
                    echo "   phar_defragment" >> stdin
                    echo "   ha_fit" >> stdin
        	    echo "   write_xtal23_xyz_file" >> stdin
        	    echo "" >> stdin
        	    # END LAMAGOET CP2K INTEGRATION: periodic Hirshfeld fit
        	fi
        fi
       	if [[ "$SCFCALCPROG" == "Tonto" ]]; then
       		SCF_BLOCK_PROM_TONTO
       		SCF_BLOCK_REST_TONTO
       	fi
	echo "" >> stdin
	echo "}" >> stdin 
	J=$[ $J + 1 ]
	echo "Running Tonto, cycle number $J" 
        if [[ "$NUMPROCTONTO" != "1" ]]; then
		mpirun -n $NUMPROCTONTO $TONTO	
	else
		$TONTO
	fi
	if [[ "$USENOSPHERA2" == "true" ]]; then
                LABELS_IN_XYZ
        fi
	if [[ "$SCFCALCPROG" == "Tonto" ]]; then
                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
	        	mkdir $J.tonto_cycle.$JOBNAME
                fi
		cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian_cov.cif2
		cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional_cov.cif1
		cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive_cov.cif
		sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
		sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.fractional.cif1
		cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
		cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
		cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
		cp $JOBNAME'.archive.fco' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
		cp $JOBNAME'.archive.fcf' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
		cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
		cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
		cp $JOBNAME.residual_density,cell.cube $J.tonto_cycle.$JOBNAME/$J.residual_density,cell.cube
                if [[ "$POWDER_HAR" == "true" ]]; then
		        cp $JOBNAME.hkl $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.hkl
                fi
	fi
	INITIALCHI=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print $2}')
	MAXSHIFT=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$7; param=$8; max=$5}}END{print shift}')
	MAXSHIFTATOM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$7; param=$8; max=$5}}END{print atom}')
	MAXSHIFTPARAM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR+10}/^Rigid-atom fit results/{c=NR-4}END {for(d=b;d<=c;++d)print a[d]}' stdout | awk -v max=0 '{if($5>max){shift=$5; atom=$7; param=$8; max=$5}}END{print param}')
# this is getting the last value of the table, BUT! Its not correct to
# use the last value of the table because for every fit the last value
# will be smaller than the convergency criteria and then lamaGOET will
# stop. the fisrt value of the table must be read so we know that the
# wavefuntion is still the same and therefore no changes will happen
# in the geometry, this is an implicit way of checking that the
# convergency is also in the energy level. 
# correct
	# One pass over the last fit table, normalised for either layout.
#	_fit_summary=$(FIT_TABLE_SUMMARY)
#	if [[ $J == 1 ]]; then 
#		MAXSHIFT=0
#	else
#		MAXSHIFT=$(printf '%s' "$_fit_summary" | cut -f6)
#	fi
#	MAXSHIFT=$(printf '%s' "$_fit_summary" | cut -f6)
#	MAXSHIFTATOM=$(printf '%s' "$_fit_summary" | cut -f7)
#	MAXSHIFTPARAM=$(printf '%s' "$_fit_summary" | cut -f8)
	if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then
		sed -i 's/(//g' $JOBNAME.xyz
		sed -i 's/)//g' $JOBNAME.xyz
	fi
	echo "Tonto cycle number $J ended"
	if ! grep -q 'Wall-clock time taken' "stdout"; then
		echo "ERROR: problems in fit cycle, please check the $J.th stdout file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
	if [ $J = 1 ] && [[ "$SCFCALCPROG" == "Tonto" ]]; then
		# Tonto runs the whole refinement loop itself, so there are no
		# lamaGOET cycles to tabulate and the per-cycle table below would be
		# headers with nothing under them. Say where the numbers are instead.
		{
			echo "===================="
			echo "Refinement progress"
			echo "===================="
			echo ""
			echo "Tonto performs the refinement cycles internally, so there is no"
			echo "per-cycle table here. Its own least-squares iterations, and the"
			echo "results of each refinement, are in the sections below and in"
			echo "full in stdout."
			echo ""
		} >> $JOBNAME.lst
	elif [ $J = 1 ]; then
		echo "====================" >> $JOBNAME.lst
		echo "Begin rigid-atom fit" >> $JOBNAME.lst
		echo "====================" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo "Cycle   Fit      initial        final            R              R_w              Max.           Max.      No. of     No. of     Energy         RMSD         Delta " >> $JOBNAME.lst
		echo "       Iter       chi2          chi2                                             Shift          Shift     params     eig's    at final      at final       Energy " >> $JOBNAME.lst
		echo "                                                                                 /esd           param                near 0     Geom.          Geom.                " >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
	fi
#	if [[ "$SCFCALCPROG" != "Gaussian" && "$SCFCALCPROG" != "Orca" && "$SCFCALCPROG" != "Crystal14" || "$SCFCALCPROG" != "OCC" ]]; then 
#		echo -e " $J\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $1}' )\t$INITIALCHI\t$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  $2"\t"$3"\t"$4"\t"}') $MAXSHIFT\t$MAXSHIFTATOM $MAXSHIFTPARAM $(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print  "\t""    "$9" \t"$10 }' ) "  >> $JOBNAME.lst  
#	fi
	FIT_ITER=$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $1}')
#  	INITIAL_CHI=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print  $2}')
	FINALCHI=$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $2}')
	FINAL_R=$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $3}')
	FINAL_RW=$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $4}')
#	MAXSHIFT=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print  $5}')
#	MAXSHIFTATOM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print  $7}')
#	MAXSHIFTPARAM=$(awk '{a[NR]=$0}/^Begin rigid-atom fit/{b=NR}END {print a[b+10]}' stdout | awk '{print  $8}')
	NUMBER_PARAM=$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $9}')
	NUMBER_EIGEN=$(awk '{a[NR]=$0}/^Rigid-atom fit results/{b=NR}END {print a[b-4]}' stdout | awk '{print $10}')
#	echo -e " $J\t$FIT_ITER\t$INITIALCHI\t$FINALCHI\t$FINAL_R\t$FINAL_RW\t$MAXSHIFT\t$MAXSHIFTATOM $MAXSHIFTPARAM\t$NUMBER_PARAM\t$NUMBER_EIGEN\t "  >> $JOBNAME.lst  
	if [[ "$SCFCALCPROG" != "Tonto" ]]; then 
                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
	        	mkdir $J.tonto_cycle.$JOBNAME
                fi
		cp $JOBNAME.xyz $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.xyz
		cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
		cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
		if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
			cp $JOBNAME.residual_density,cell.cube $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.residual_density,cell.cube
		fi
		if [[ "$SCFCALCPROG" != "optgaussian" ]]; then
	                if [ -f $JOBNAME.fractional.cif1 ]; then
#                       if [ -f $JOBNAME.cartesian.cif2 ]; then
				cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian_cov.cif2
				cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional_cov.cif1
				cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive_cov.cif
				sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
				sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.fractional.cif1
				cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
				cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
				cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
				cp $JOBNAME'.archive.fco' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
				cp $JOBNAME'.archive.fcf' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
			fi
		fi
		if [[ "$SCFCALCPROG" != "elmodb" &&  "$SCCHARGES" == "true" ]]; then
			cp cluster_charges $J.tonto_cycle.$JOBNAME/$J.cluster_charges
#			cp gaussian-point-charges $J.tonto_cycle.$JOBNAME/$J.gaussian-point-charges
		fi
	fi
	_lamagoet_publish_latest_cif
}

TONTO_TO_GAUSSIAN(){
	I=$[ $I + 1 ]
	echo "Extracting XYZ for Gaussian cycle number $I"
	echo "%rwf=./$JOBNAME.rwf" >  $JOBNAME.com
	echo "%int=./$JOBNAME.int" >> $JOBNAME.com
	echo "%NoSave" >> $JOBNAME.com
	echo "%chk=./$JOBNAME.chk" > $JOBNAME.com
	echo "%mem=$MEM" >> $JOBNAME.com
	echo "%nprocshared=$NUMPROC" >> $JOBNAME.com
	if [ "$METHOD" = "rks" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "#$OPT blyp/$BASISSETG Charge nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "#$OPT blyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	elif [ "$METHOD" = "uks" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "#$OPT ublyp/$BASISSETG Charge nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "#$OPT ublyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	elif [ "$METHOD" = "rhf" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "#$OPT rhf/$BASISSETG Charge nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "#$OPT rhf/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	else
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "#$OPT $METHOD/$BASISSETG Charge nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "#$OPT $METHOD/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	fi
	echo "" >> $JOBNAME.com
	echo "$JOBNAME" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "$CHARGE $MULTIPLICITY" >> $JOBNAME.com
	awk 'NR>2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.xyz >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	if [ "$SCCHARGES" = "true" ]; then 
#                if [ ! -f gaussian-point-charges ]; then
#                	echo "" > gaussian-point-charges
#                	awk '/Cluster monopole charges and positions/{print p; f=1} {p=$0} /------------------------------------------------------------------------/{c=1} f; c--==0{f=0}' stdout >> gaussian-point-charges
#                	awk '{a[NR]=$0}{b=11}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' gaussian-point-charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
#                        echo "" >> $JOBNAME.com
#                else
                if [ "$SCDIPOLES" = "true" ]; then       
                	awk '{a[NR]=$0}{b=13}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' cluster_charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
                else
                	awk '{a[NR]=$0}{b=13}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;d+=3)print a[d]}' cluster_charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
                fi
                        echo "" >> $JOBNAME.com
#                fi
#                rm gaussian-point-charges
	fi
	if [ "$GAUSGEN" = "true" ]; then
	        cat basis_gen.txt >> $JOBNAME.com
		echo "" >> $JOBNAME.com
	fi
	echo "./$JOBNAME.wfn" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "Running Gaussian, cycle number $I"
	$SCFCALC_BIN $JOBNAME.com
        cp Test.FChk $JOBNAME.fchk 
        sed -i '/^#/d' $JOBNAME.fchk
	echo "Gaussian cycle number $I ended"
	if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
		echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
	if [[ "$USENOSPHERA2" == "true" && "$I" != "1" ]]; then
	        echo "Generation fcheck file for Gaussian cycle number $I"
#		awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I in progress"
		RUN_NOSPHERA2
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I ended"
	fi
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
	cp Test.FChk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
        sed -i '/^#/d' $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk 
	cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
	if [[ "$USENOSPHERA2" == "true" ]]; then
		cp $JOBNAME.wfn $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
	fi
}

TONTO_TO_CRYSTAL(){
	I=$[ $I + 1 ]
        if [[ "$SPACEGROUPHM" == "" ]]; then
                SPACEGROUPHM=$( awk '/_symmetry_space_group_name_H-M/ {print $0}' 0.tonto_cycle.$JOBNAME/0.$JOBNAME.cartesian.cif2 | sed "s/'/\:/g" | awk -F ":" '{print $2}' )
        fi
	CELLA=$(grep "a cell parameter ............" stdout | head -1 | awk '{print $NF}' | cut -f1 -d"(" )
	CELLB=$(grep "b cell parameter ............" stdout | head -1 | awk '{print $NF}' | cut -f1 -d"(" )
	CELLC=$(grep "c cell parameter ............" stdout | head -1 | awk '{print $NF}' | cut -f1 -d"(" )
	CELLALPHA=$(grep "alpha angle ................." stdout | head -1 | awk '{print $NF}' | cut -f1 -d"(" )
	CELLBETA=$(grep "beta  angle ................." stdout | head -1 | awk '{print $NF}'  | cut -f1 -d"(" )
	CELLGAMMA=$(grep "gamma angle ................." stdout | head -1 | awk '{print $NF}' | cut -f1 -d"(" )
	echo "$JOBNAME"  > $JOBNAME.d12 
	echo "CRYSTAL"   >> $JOBNAME.d12
        SPACEGROUPITNUMBER=$(grep "_symmetry_Int_Tables_number" $CIF | tr -d \' | awk '{print $2}' | tr -d '\r')
	if [[ "$SPACEGROUPITNUMBER" == "" ]]; then
                SPACEGROUPITNUMBER=$(grep "_space_group_IT_number" $CIF | tr -d \' | awk '{print $2}' | tr -d '\r')
	        if [[ "$SPACEGROUPITNUMBER" == "" ]]; then
		        echo "ERROR: Space group number not found. Please enter the space group number in your cif with the keyword _symmetry_Int_Tables_number or _space_group_IT_number and restart your job" | tee -a $JOBNAME.lst
		        exit 1
                fi 
	fi
        if [[ "$USEHMSYM" == "true" ]];then 
	        echo "1 $XTALSETTING 0"     >> $JOBNAME.d12
                echo $SPACEGROUPHM >> $JOBNAME.d12
        else
	        echo "0 $XTALSETTING 0"     >> $JOBNAME.d12
                echo $SPACEGROUPITNUMBER  >> $JOBNAME.d12
        fi
        if (( $( bc <<< "$CELLALPHA == 90") )); then
                CELLALPHA2=""
        else
                CELLALPHA2=$CELLALPHA
        fi
        if (( $( bc <<< "$CELLBETA == 90") )); then
                CELLBETA2=""
        else
                CELLBETA2=$CELLBETA
        fi
        if (( $( bc <<< "$CELLGAMMA == 90") )); then
                CELLGAMMA2=""
        else
                CELLGAMMA2=$CELLGAMMA
        fi
        if (( $( bc <<< "$CELLA == $CELLB") )); then
                if (( $( bc <<< "$CELLB == $CELLC") )); then
                        CELLC=""
                fi
                if (( $( bc <<< "$CELLGAMMA == 120") )); then
                        CELLGAMMA2=""
                fi
                CELLB=""
        fi
        echo "$CELLA $CELLB $CELLC $CELLALPHA2 $CELLBETA2 $CELLGAMMA2"  >> $JOBNAME.d12
        sed '2d' $JOBNAME.xyz >> $JOBNAME.d12
#       cat $JOBNAME.xyz  >> $JOBNAME.d12
#       echo "MOLECULE"  >> $JOBNAME.d12
        echo "KEEPSYMM"  >> $JOBNAME.d12
        echo "NOSHIFT"  >> $JOBNAME.d12
        if [[ "$SUPERCON" == "true" ]]; then
                echo "SUPERCON"  >> $JOBNAME.d12
                echo "1. 0. 0."  >> $JOBNAME.d12
                echo "0. 1. 0."  >> $JOBNAME.d12
                echo "0. 0. 1."  >> $JOBNAME.d12
        fi
#       echo "1"  >> $JOBNAME.d12
#       echo "1 0 0 0"  >> $JOBNAME.d12
        if [[ "$GAUSGEN" == "true" || "$BASISSETG" == "gen" ]]; then
                echo "END"  >> $JOBNAME.d12
                cat basis_gen.txt >>  $JOBNAME.d12
                echo "99 0"  >> $JOBNAME.d12
                echo "ENDBS"  >> $JOBNAME.d12
        else
                echo "BASISSET"  >> $JOBNAME.d12
                echo "$BASISSETG"  >> $JOBNAME.d12
        fi
        if [[ "$METHOD" != "rhf" ]]; then
                if [[ "$METHOD" == "uhf" ]]; then
                        echo "$METHOD"  >> $JOBNAME.d12
                else
                        echo "DFT"  >> $JOBNAME.d12
                        echo "$METHOD"  >> $JOBNAME.d12
                        echo "END"  >> $JOBNAME.d12
                fi
        fi
##      echo "END"  >> $JOBNAME.d12 is this extra??
#       echo "XLGRID"  >> $JOBNAME.d12
#       echo "SCFDIR"  >> $JOBNAME.d12
#       echo "BIPOSIZE"  >> $JOBNAME.d12
#       echo "60000000"  >> $JOBNAME.d12
#       echo "EXCHSIZE"  >> $JOBNAME.d12
#       echo "40000000"  >> $JOBNAME.d12
        echo "SHRINK"  >> $JOBNAME.d12
        echo "$SHRINKA $SHRINKB"  >> $JOBNAME.d12
#       echo "LEVSHIFT"  >> $JOBNAME.d12
#       echo "6 1"  >> $JOBNAME.d12
#       echo "TOLINTEG"  >> $JOBNAME.d12
#       echo "7 7 7 7 25"  >> $JOBNAME.d12
        echo "TOLDEE"  >> $JOBNAME.d12
        echo "7"  >> $JOBNAME.d12
        if [[ "$MAXXTALCYCLE" != "" ]]; then
                echo "MAXCYCLE"  >> $JOBNAME.d12
                echo "$MAXXTALCYCLE"  >> $JOBNAME.d12
        fi
        if [[ $I -ge 2 && "$USEGUESS" == "true" ]]; then
		echo "GUESSP" >> $JOBNAME.d12
	fi
       	echo "END"  >> $JOBNAME.d12
#       I=$"1"
	echo "Running Crystal, cycle number $I" 
        if [[ "$NUMPROC" != "1" ]]; then
                cp $JOBNAME.d12 INPUT
        	mpirun -n $NUMPROC $SCFCALC_BIN >& $JOBNAME.out 	
        else
        	if [[ $I -ge 2 && "$USEGUESS" == "true" ]]; then
	        	$SCFCALC_BIN $JOBNAME $JOBNAME
		else
		        $SCFCALC_BIN $JOBNAME
		fi
        fi
	echo "Crystal cycle number $I ended"
        if [[ ! -f GenerateXML.d3  ]]; then
                echo "CRYAPI_OUT"  > GenerateXML.d3
	fi
        echo "Running Crystal properties, cycle number $I" 
        if [[ "$NUMPROC" != "1" ]]; then
                cp fort.9 $JOBNAME.f9
                cp fort.98 $JOBNAME.f98
                runPprop23 $NUMPROC GenerateXML $JOBNAME
        else
                runprop23 GenerateXML $JOBNAME
        fi
	echo "Crystal properties, cycle number $I ended" 
	if ! grep -q 'SCF ENDED - CONVERGENCE ON ENERGY' "$JOBNAME.out"; then
		echo "ERROR: Crystal job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
        if [[ "$I" == "1" ]]; then
                ENERGIA=$(grep "TOTAL ENERGY" $JOBNAME.out | tail -n1 | awk '{print $4}')
                RMSD=$(grep "TOTAL ENERGY" $JOBNAME.out | tail -n1 | awk '{print $5}' | sed 's/DE//g' )
        	echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
#       else
#       	echo "Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
        fi
	echo "" >> $JOBNAME.lst
#       echo "###############################################################################################" >> $JOBNAME.lst
	echo "Crystal cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
	        mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.d12 $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.d12
	cp $JOBNAME.f98 $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.f98
	cp $JOBNAME.f9 $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.f9
#       cp $JOBNAME.d3 $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.d3
        gzip -k GenerateXML.XML
	mv GenerateXML.XML.gz $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.XML.gz
	cp $JOBNAME.out  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
}

GET_FREQ(){
	I=$[ $I + 1 ]
	echo "Extrating XYZ for Gaussian cycle number $I"
	echo "%rwf=./$JOBNAME.rwf" >  $JOBNAME.com
	echo "%int=./$JOBNAME.int" >> $JOBNAME.com
	echo "%NoSave" >> $JOBNAME.com
	echo "%chk=./$JOBNAME.chk" > $JOBNAME.com
	echo "%mem=$MEM" >> $JOBNAME.com
	echo "%nprocshared=$NUMPROC" >> $JOBNAME.com
	#echo "# rb3lyp/$BASISSETG output=wfn" >> $JOBNAME.com
	if [ "$METHOD" = "rks" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# $ONLY_ONE blyp/$BASISSETG freq=noraman Charge nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "# $ONLY_ONE blyp/$BASISSETG freq=noraman nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	elif [ "$METHOD" = "uks" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# $ONLY_ONE ublyp/$BASISSETG freq=noraman Charge nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "# $ONLY_ONE ublyp/$BASISSETG freq=noraman nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	elif [ "$METHOD" = "rhf" ]; then
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# $ONLY_ONE rhf/$BASISSETG freq=noraman Charge nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "# $ONLY_ONE rhf/$BASISSETG freq=noraman nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	else
		if [ "$SCCHARGES" = "true" ]; then 
	   		echo "# $ONLY_ONE $METHOD/$BASISSETG freq=noraman Charge nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
		else
			echo "# $ONLY_ONE $METHOD/$BASISSETG freq=noraman nosymm output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" >> $JOBNAME.com
	        fi
	fi
	echo "" >> $JOBNAME.com
	echo "$JOBNAME" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "$CHARGE $MULTIPLICITY" >> $JOBNAME.com
#        echo $J
	awk 'NR>2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.xyz >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	if [ "$SCCHARGES" = "true" ]; then 
#                if [ ! -f gaussian-point-charges ]; then
#                	echo "" > gaussian-point-charges
#                	awk '/Cluster monopole charges and positions/{print p; f=1} {p=$0} /------------------------------------------------------------------------/{c=1} f; c--==0{f=0}' stdout >> gaussian-point-charges
#                	awk '{a[NR]=$0}{b=11}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' gaussian-point-charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
#                        echo "" >> $JOBNAME.com
#                else
			awk '{a[NR]=$0}{b=13}/^------------------------------------------------------------------------/{c=NR}END{for(d=b;d<=c-1;++d)print a[d]}' cluster_charges | awk '{printf "%s\t %s\t %s\t %s\t \n", $1, $2, $3, $4 }' >> $JOBNAME.com
                        echo "" >> $JOBNAME.com
#                fi
#                rm gaussian-point-charges
	fi
	if [ "$GAUSGEN" = "true" ]; then
	        cat basis_gen.txt >> $JOBNAME.com
		echo "" >> $JOBNAME.com
	fi
	echo "./$JOBNAME.wfn" >> $JOBNAME.com
	echo "" >> $JOBNAME.com
	echo "Running Gaussian, cycle number $I"
	$SCFCALC_BIN $JOBNAME.com
        cp Test.FChk $JOBNAME.fchk 
        sed -i '/^#/d' $JOBNAME.fchk
	echo "Gaussian cycle number $I ended"
	if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
		echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
	echo "Generation fcheck file for Gaussian cycle number $I"
	if [[ "$USENOSPHERA2" == "true" ]]; then
#		awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I in progress"
		RUN_NOSPHERA2
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I ended"
	fi
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
	        mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
	cp Test.FChk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
        sed -i '/^#/d' $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk 
	cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
	if [[ "$USENOSPHERA2" == "true" ]]; then
		cp $JOBNAME.wfn  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
	fi
}

GET_FREQ_ORCA(){
	I=$[ $I + 1 ]
	echo "Extrating XYZ for Orca cycle number $I"
	if [ "$SCFCALCPROG" = "optorca" ]; then
		ORCAOPT=" Opt"
	fi
	if [[ "$SCFCALCPROG" == "optorca" && "$SCCHARGES" == "false" ]]; then
		ONLY_ONE=" Opt"
	fi
	if [ "$METHOD" = "rks" ]; then
		echo "! blyp $BASISSETG $ONLY_ONE FREQ" > $JOBNAME.inp
	else
		if [ "$METHOD" = "uks" ]; then
			echo "! ublyp $BASISSETG $ONLY_ONE FREQ" > $JOBNAME.inp
		else
			echo "! $METHOD $BASISSETG $ONLY_ONE FREQ" > $JOBNAME.inp
		fi
	fi
	echo "" >> $JOBNAME.inp
	echo "%pal nprocs $NUMPROC end" >> $JOBNAME.inp
	echo "" >> $JOBNAME.inp
	echo "%output"  >> $JOBNAME.inp
	echo "   PrintLevel=Normal"  >> $JOBNAME.inp
	echo "   Print[ P_Basis       ] 2"  >> $JOBNAME.inp
	echo "   Print[ P_GuessOrb    ] 1"  >> $JOBNAME.inp
	echo "   Print[ P_MOs         ] 1"  >> $JOBNAME.inp
	echo "   Print[ P_Density     ] 1"  >> $JOBNAME.inp
	echo "   Print[ P_SpinDensity ] 1"  >> $JOBNAME.inp
	echo "end"  >> $JOBNAME.inp
	echo ""  >> $JOBNAME.inp
	if [ "$SCCHARGES" = "true" ]; then 
		echo '% pointcharges "'$JOBNAME'.qxyz"'  >> $JOBNAME.inp
		sed -i '1,12{/.*/d}' cluster_charges 
		sed -i '$ d' cluster_charges
		sed -i -n '1~3p' cluster_charges 
		sed -i '{/^$/d}' cluster_charges 
		LINEONE=$(wc -l cluster_charges | awk '{print $1}')
		echo $LINEONE > $JOBNAME.qxyz
		awk '{printf " %12s  %12s %12s  %12s\n",$4,$1,$2,$3}' cluster_charges >> $JOBNAME.qxyz
                echo "" >> $JOBNAME.qxyz
		echo ""  >> $JOBNAME.inp
		if [[ "$ADDNUCINTER" == "true" ]]; then
			echo "%method" >> $JOBNAME.inp
			echo "   DoEQ true" >> $JOBNAME.inp
			echo "end"  >> $JOBNAME.inp
		fi
	fi
	echo "* xyz $CHARGE $MULTIPLICITY"  >> $JOBNAME.inp
	awk 'NR>2' $JOBNAME.xyz  >> $JOBNAME.inp
	if [ "$SCCHARGES" = "true" ]; then 
		echo ""  >> $JOBNAME.inp
	fi
	echo "*"  >> $JOBNAME.inp
	if [[ "$GAUSGEN" == "true" ]]; then
		cat basis_gen.txt >> $JOBNAME.inp
		echo "" >> $JOBNAME.inp
	fi
	echo "Running Orca, cycle number $I" 
        if [ -f $JOBNAME.gbw ]; then
                rm $JOBNAME.gbw
        fi
	$SCFCALC_BIN $JOBNAME.inp > $JOBNAME.out
	echo "Orca cycle number $I ended"
	if ! grep -q '****ORCA TERMINATED NORMALLY****' "$JOBNAME.out"; then
		echo "ERROR: Orca job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
	echo "Generation of molden file for Orca cycle number $I"
	if [[ "$(which orca_2mkl.exe)" == "" ]]; then
		orca_2mkl $JOBNAME -molden  > /dev/null
	else 	
		orca_2mkl.exe $JOBNAME -molden  > /dev/null
	fi
	echo "Generation of wfn file for Orca cycle number $I"
	if [[ "$(which orca_2aim.exe)" == "" ]]; then
		orca_2aim $JOBNAME  > /dev/null
	else
		orca_2aim.exe $JOBNAME  > /dev/null
	fi
        NUMATOMWFN=$(grep -m1 " Q " $JOBNAME.wfn | awk '{ print $2 }' )
        NUMATOMWFN=$[$NUMATOMWFN -1]
        awk -v  NUMATOMWFN=$NUMATOMWFN 'NR==2 {gsub($7, NUMATOMWFN, $0); print}1' $JOBNAME.wfn > temp.wfn
        sed -i '2d' temp.wfn
        sed -i '/ Q /d' temp.wfn
        mv temp.wfn $JOBNAME.wfn
	if [[ "$USENOSPHERA2" == "true" ]]; then
		#awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I in progress"
		RUN_NOSPHERA2
		echo "Generation of .tsc file with NoSpherA2 for cycle number $I ended"
	fi
        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
        fi
	cp $JOBNAME.inp          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.inp
	cp $JOBNAME.qxyz         $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.qxyz
	cp $JOBNAME.molden.input $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input
	cp $JOBNAME.out          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
	if [[ "$USENOSPHERA2" == "true" ]]; then
		cp $JOBNAME.wfn $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
	fi
}

_har_abs_diff_le() {
	local first=$1
	local second=$2
	local tolerance=$3
	awk -v a="$first" -v b="$second" -v tol="$tolerance" '
		BEGIN {
			d = a - b
			if (d < 0) d = -d
			exit !(d <= tol)
		}
	'
}

_har_abs_value_le() {
	local value=$1
	local tolerance=$2
	awk -v value="$value" -v tol="$tolerance" '
		BEGIN {
			if (value < 0) value = -value
			exit !(value <= tol)
		}
	'
}

CHECK_WAVEFUNCTION_STALL(){
	local current_energy=$1
	local current_rmsd=$2
	local energy_tolerance=${HAR_ENERGY_REPEAT_TOL:-${CONVTOLE:-0.000001}}
	local rmsd_tolerance=${HAR_SCF_RMSD_TOL:-1.0e-7}
	local reason=""

	HAR_WAVEFUNCTION_STALLED=false
	if [[ -z "$current_energy" ]]; then
		return 0
	fi
	if [[ -n "${HAR_ENERGY_LAST:-}" ]] \
		&& _har_abs_diff_le "$current_energy" "$HAR_ENERGY_LAST" "$energy_tolerance"; then
		HAR_DIRECT_REPEAT_COUNT=$(( ${HAR_DIRECT_REPEAT_COUNT:-0} + 1 ))
		HAR_PERIOD2_REPEAT_COUNT=0
		if (( HAR_DIRECT_REPEAT_COUNT >= 2 )); then
			reason="the SCF energy repeated in consecutive cycles"
		fi
	elif [[ -n "${HAR_ENERGY_PREV2:-}" ]] \
		&& _har_abs_diff_le "$current_energy" "$HAR_ENERGY_PREV2" "$energy_tolerance"; then
		HAR_PERIOD2_REPEAT_COUNT=$(( ${HAR_PERIOD2_REPEAT_COUNT:-0} + 1 ))
		HAR_DIRECT_REPEAT_COUNT=0
		if (( HAR_PERIOD2_REPEAT_COUNT >= 2 )); then
			reason="the SCF energy entered a stable two-cycle oscillation"
		fi
	else
		HAR_DIRECT_REPEAT_COUNT=0
		HAR_PERIOD2_REPEAT_COUNT=0
	fi

	HAR_ENERGY_PREV2=${HAR_ENERGY_LAST:-}
	HAR_ENERGY_LAST=$current_energy
	if [[ -n "$reason" ]]; then
		HAR_WAVEFUNCTION_STALLED=true
		if [[ -n "$current_rmsd" ]] && ! _har_abs_value_le "$current_rmsd" "$rmsd_tolerance"; then
			echo "SCF RMSD $current_rmsd is above the diagnostic tolerance $rmsd_tolerance, but the SCF program terminated normally."
		fi
		echo "Refinement wavefunction is stationary: $reason (energy tolerance $energy_tolerance, RMSD ${current_rmsd:-unavailable})."
		echo "The HAR loop will stop and the final residual density will be calculated."
	fi
}

CHECK_ENERGY(){
	if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "optgaussian" ]]; then 
		ENERGIA3=$ENERGIA
                ENERGIA2=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log |  sed 's/^ //' | sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*HF=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
                RMSD2=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log | sed 's/^ //' |  sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*RMSD=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
#		ENERGIA2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed -n '/HF=/{N;p;}' | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
#		RMSD2=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//'| sed -n '/RMSD=/{N;p;}' | sed 's/^.*RMSD=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}'| tr -d '\r')
		echo "Gaussian cycle number $I, final energy is: $ENERGIA2, RMSD is: $RMSD2 "
	elif [[ "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "optorca" ]]; then
		ENERGIA2=$(sed -n '/FINAL SINGLE POINT ENERGY/p' $JOBNAME.out | tail -1 | awk '{print $5}' | tr -d '\r')
		RMSD2=$(sed -n '/Last RMS-Density change/p' $JOBNAME.out | tail -1 | awk '{print $5}' | tr -d '\r')
		echo "Orca cycle number $I, final energy is: $ENERGIA2, RMSD is: $RMSD2 "
	elif [[ "$SCFCALCPROG" == "Crystal14" ]]; then
                ENERGIA2=$(grep "TOTAL ENERGY" $JOBNAME.out | tail -n1 | awk '{print $4}')
                RMSD2=$(grep "TOTAL ENERGY" $JOBNAME.out | tail -n1 | awk '{print $5}' | sed 's/DE//g' )
	elif [[ "$SCFCALCPROG" == "OCC" ]]; then
		ENERGIA2=$(sed -n '/^total/p' $JOBNAME.out | awk '{print $2}' | tr -d '\r')
		RMSD2=$( awk '{a[NR]=$0}/restricted spinorbital SCF energy converged after/ {print a[NR-1]}' $JOBNAME.out | awk '{print $3}'| tr -d '\r')
	fi
	DE=$(awk "BEGIN {print $ENERGIA2 - $ENERGIA}")
	ABSDE=$(awk "function abs(x){return (( x < 0.0) ? -x : x)} BEGIN {print abs($ENERGIA2) - abs($ENERGIA)}")
	ABSDE2=$(awk "function abs(x){return (( x < 0.0) ? -x : x)} BEGIN {print abs($ENERGIA2) - abs($ENERGIA3)}")
	DE=$(printf '%.12f' $DE)
	# Cycle, fit iterations, chi2 before and after, R, R_w, largest
	# shift and where it was, parameter and eigenvalue counts.
	echo -e " $J\t$FIT_ITER\t$INITIALCHI\t$FINALCHI\t$FINAL_R\t$FINAL_RW\t$MAXSHIFT\t$MAXSHIFTATOM $MAXSHIFTPARAM\t$NUMBER_PARAM\t$NUMBER_EIGEN\t$ENERGIA2\t$RMSD2\t$DE"  >> $JOBNAME.lst  
#	printf ' %s\t%s\t%s\t%s\t%s\t%s\t%s\t%s %s\t%s\t%s\t%s\t%s\t%s\n' \
#		"$J" \
#		"$(printf '%s' "$_fit_summary" | cut -f1)" \
#		"$(printf '%s' "$_fit_summary" | cut -f2)" \
#		"$(printf '%s' "$_fit_summary" | cut -f3)" \
#		"$(printf '%s' "$_fit_summary" | cut -f4)" \
#		"$(printf '%s' "$_fit_summary" | cut -f5)" \
#		"$MAXSHIFT" "$MAXSHIFTATOM" "$MAXSHIFTPARAM" \
#		"$(printf '%s' "$_fit_summary" | cut -f9)" \
#		"$(printf '%s' "$_fit_summary" | cut -f10)" \
#		"$ENERGIA2" "$RMSD2" "$DE" >> $JOBNAME.lst
	if [[ -z "${HAR_ENERGY_LAST:-}" && -n "${ENERGIA:-}" ]]; then
		HAR_ENERGY_LAST=$ENERGIA
	fi
	CHECK_WAVEFUNCTION_STALL "$ENERGIA2" "$RMSD2"
	ENERGIA=$ENERGIA2
	RMSD=$RMSD2
	echo "Delta E (cycle  $I - $[ I - 1 ]): $DE "
}


APPEND_IAM_RESULTS(){
	# Copy the starting IAM refinement into $JOBNAME.lst.
	#
	# Tonto heads the independent-atom-model refinement "IAM refinement" and
	# the Hirshfeld atom refinement "Structure refinement results". Only the
	# latter was ever copied into the summary, so a job started from a Tonto
	# IAM lost precisely the numbers it was started for: without the IAM there
	# is nothing to compare the HAR against, which is the entire reason for
	# running one. The results were in stdout all along, just not in the file
	# users are told holds the results.
	#
	# lamaGOET also looked for a "Rigid-atom fit results" heading. Current
	# Tonto does not emit that string at all, so those extractions were dead.
	[ -f stdout ] || return 0
	grep -q '^IAM refinement' stdout || return 0
	{
		echo ""
		echo "###############################################################################################"
		echo "                        Independent Atom Model (IAM) refinement                                 "
		echo "###############################################################################################"
		echo ""
		awk '/^IAM refinement/{copy=1}
		     copy && /^Final asymmetric unit parameter values:/{exit}
		     copy' stdout
	} >> $JOBNAME.lst
}

FIT_TABLE_SUMMARY(){
	# Emit one normalised, tab-separated record describing the last
	# least-squares fit in stdout:
	#
	#   iter  chi2_initial  chi2_final  R  R_w  max_shift  atom  param  N_p  N_eig
	#
	# Tonto prints one row per least-squares iteration and then a heading:
	# "IAM refinement" for the starting model, "Structure refinement results"
	# for a Hirshfeld atom refinement. It used to print "Rigid-atom fit
	# results", which lamaGOET looked for; that string no longer appears, so
	# every field below came out empty and the per-cycle table in the summary
	# had headers and no rows.
	#
	# The two tables also differ in shape. The IAM has ten columns and one
	# chi2; the HAR has twelve, leading with a cycle number and carrying both
	# an initial and a final chi2. Normalise here so the caller does not care.
	awk '
		/^IAM refinement$/ || /^Structure refinement results$/ { heading = NR }
#this is looking for the wrong header!
		{ line[NR] = $0 }
		END {
			if (!heading) exit
			for (i = heading - 1; i > 0; i--)
				if (line[i] ~ /^[ \t]*[0-9]+[ \t]/) { last = i; break }
			if (!last) exit
			for (i = last; i > 0; i--)
				if (line[i] !~ /^[ \t]*[0-9]+[ \t]/) { first = i + 1; break }

			maxshift = 0
			for (i = first; i <= last; i++) {
				n = split(line[i], f)
				if (n >= 12) { s = f[7]; a = f[9];  p = f[10] }
				else         { s = f[5]; a = f[7];  p = f[8]  }
				if (s < 0) s = -s
				if (s > maxshift) { maxshift = s; maxatom = a; maxparam = p }
			}

			n = split(line[last], f)
			if (n >= 12) { iter = f[2]; ci = f[3]; cf = f[4]; r = f[5]; rw = f[6] }
			else         { iter = f[1]; ci = f[2]; cf = f[2]; r = f[3]; rw = f[4] }

			printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
			       iter, ci, cf, r, rw, maxshift, maxatom, maxparam,
			       f[n-1], f[n]
		}
	' stdout
}

GET_RESIDUALS(){
	TONTO_HEADER
	DEFINE_JOB_NAME
	if [ "$SCFCALCPROG" = "elmodb" ]; then
		READ_ELMO_FCHK
	fi
	if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "OCC" ]]; then
		READ_GAUSSIAN_FCHK
	elif [ "$SCFCALCPROG" = "Orca" ]; then
		READ_ORCA_FCHK
#	elif [ "$SCFCALCPROG" = "Crystal14" ]; then
#		READ_CRYSTAL_WFN
	else
		DEFINE_JOB_NAME
	fi
	echo "" >> stdin
		PROCESS_CIF
		DEFINE_JOB_NAME
	if [ "$SCFCALCPROG" = "Tonto" ]; then 
		TONTO_BASIS_SET
	fi
	if [ "$DISP" = "yes" ]; then 
		DISPERSION_COEF
	fi
	if [ "$SCFCALCPROG" = "Crystal14" ]; then
		NOT_TONTO_BASIS_SET
	fi
		CHARGE_MULT
	if [ "$SCFCALCPROG" = "Crystal14" ]; then
		READ_CRYSTAL_WFN
		CRYSTAL_BLOCK
		DEFINE_JOB_NAME
	fi
	# CLEANUP FIX V1: rebuild reflection/xray data for final residuals.
	# The refined CIF carries cell/geometry metadata but not the reflection list.
	# Crystal14 already did this immediately above.
	if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
		CRYSTAL_BLOCK
	fi
	if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
		echo "   scfdata= {" >> stdin
		if [[ "$METHOD" != "rks" && "$METHOD" != "rhf" && "$METHOD" != "uhf" && "$METHOD" != "uks" && "$METHOD" != "HF" ]]; then
	                if [[ "$METHOD" == "ub3lyp" || "$METHOD" == "UB3LYP" ]]; then
		                echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= uks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
	        		echo "      dft_correlation_functional= b3lypgc" >> stdin
	                elif [[ "$METHOD" == "b3lyp" || "$METHOD" == "B3LYP" ]]; then
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
	        		echo "      dft_correlation_functional= b3lypgc" >> stdin
	                else
		                echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
			        echo "      kind= rks " >> stdin
			        echo "      dft_exchange_functional= b3lypgx" >> stdin
	        		echo "      dft_correlation_functional= b3lypgc" >> stdin
	                fi
			echo "      output= true " >> stdin
		else
	                if [[ "$METHOD" == "uhf" || "$METHOD" == "UHF" || "$METHOD" == "UKS" || "$METHOD" == "uks" ]]; then
		        	echo "      initial_MOs= unrestricted   " >> stdin # Only for new tonto may 2020
	                elif [[ "$METHOD" == "rhf" || "$METHOD" == "RHF" || "$METHOD" == "RKS" || "$METHOD" == "rks" ]]; then
		        	echo "      initial_MOs= restricted   " >> stdin # Only for new tonto may 2020
	                fi
			echo "      kind= $METHOD" >> stdin
			echo "      output= true " >> stdin
		fi
		echo "      use_SC_cluster_charges= $SCCHARGES" >> stdin
		if [ "$SCCHARGES" == "true" ]; then 
			echo "      cluster_radius= $SCCRADIUS angstrom" >> stdin
			echo "      defragment= $DEFRAG" >> stdin
			echo "      save_cluster_charges= true" >> stdin
		fi
		echo "      convergence= 0.001" >> stdin
		echo "      diis= { convergence_tolerance= 0.0002 }" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
		echo "   make_scf_density_matrix" >> stdin
		echo "   assign_NOs_to_MOs " >> stdin
	fi
	echo "   make_structure_factors" >> stdin
	echo "" >> stdin
	echo "   put_minmax_residual_density" >> stdin
	echo "" >> stdin
        echo "   put_fitting_plots" >> stdin
#       echo "   plot_grid= {                           " >> stdin
#       echo "" >> stdin
#       echo "      kind= residual_density_map" >> stdin
#       echo "      use_unit_cell_as_bbox" >> stdin
#       echo "      desired_separation= 0.1 angstrom" >> stdin
#       echo "      plot_format= cell.cube" >> stdin
#       echo "      plot_units= angstrom^-3" >> stdin
#       echo "" >> stdin
#       echo "    }" >> stdin
#       echo "" >> stdin
#       echo "   plot" >> stdin
	echo "" >> stdin
	echo "}" >> stdin 
	echo "Calculating residual density at final geometry" 
	J=$[ $J + 1 ]
        rm -f stdout stde
        local tonto_status=0
        if [[ "$NUMPROCTONTO" != "1" ]]; then
		mpirun -n "$NUMPROCTONTO" "$TONTO" || tonto_status=$?
	else
		"$TONTO" || tonto_status=$?
	fi
        # CLEANUP FIX V1: validate final residual calculation.
        if [[ "$tonto_status" -ne 0 ]] || ! grep -q '^Unit cell residual density:' stdout 2>/dev/null; then
                echo "ERROR: final Tonto residual-density calculation failed; inspect stdin and stdout" | tee -a "$JOBNAME.lst" >&2
                return 1
        fi
	if [[ "$USENOSPHERA2" == "true" ]]; then
                LABELS_IN_XYZ
        fi
        if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
        	mkdir $J.tonto_cycle.$JOBNAME
        fi
	cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
	cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
	cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
	cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
	cp $JOBNAME'.archive.cif' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
	cp $JOBNAME'.archive.fcf' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
	cp $JOBNAME'.archive.fco' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
	cp $JOBNAME'.residual_density,cell.cube' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.residual_density,cell.cube
}

XCW_SCF_BLOCK(){
	echo "   ! More accuracy" >> stdin
	echo "   output_style_options= {" >> stdin
	echo "      real_precision= 8" >> stdin
	echo "      real_width= 20" >> stdin
	echo "   }" >> stdin
	echo "   " >> stdin
	SCF_BLOCK_PROM_TONTO
#	if [[ "$XCWONLY" == "false" ]]; then 
#		echo "   read_archive molecular_orbitals restricted" >> stdin
#		echo "   read_archive orbital_energies restricted" >> stdin
#		echo "   read_archive density_matrix restricted" >> stdin
#		echo "   " >> stdin
#	fi
	echo "   scfdata= {" >> stdin
	echo "   " >> stdin
	echo "     initial_density=   restricted" >> stdin
	echo "     kind=            xray_$METHODXCW" >> stdin
        echo "     output= true " >> stdin
	echo "     direct=          yes" >> stdin
	echo "     convergence= 0.001" >> stdin
	echo "     use_SC_cluster_charges= $SCCHARGESXCW" >> stdin
	if [[ "$SCCHARGESXCW" == "true" ]]; then
		echo "     cluster_radius= $SCCRADIUSXCW angstrom" >> stdin
	fi
	echo "   " >> stdin
	echo "     diis= {                     ! This is the extrapolation procedure" >> stdin
	echo "       save_iteration=  2" >> stdin
	echo "       start_iteration= 4" >> stdin
	echo "       keep=            8" >> stdin
	echo "        convergence_tolerance= 0.0002" >> stdin
	echo "     }" >> stdin
	echo "   " >> stdin
	echo "     max_iterations=  200         ! The maximum number of SCF interation" >> stdin
	echo "   " >> stdin
	echo "     use_damping=     YES         ! These are used to damp the SCF interation process " >> stdin
	echo "     damp_factor=     0.50        ! by including 20% of the previous result  " >> stdin
	echo "     damp_finish=     3 " >> stdin
	echo "      " >> stdin
	echo "     use_level_shift= YES " >> stdin
	echo "     !level_shift=    1.0         ! This is another form of damping " >> stdin
	echo "     !level_shift_finish= 3 " >> stdin
	echo "     initial_lambda=  $LAMBDAINITIAL       ! These specify the "lambda value" " >> stdin
	echo "     lambda_step=     $LAMBDASTEP          ! used to mix the energy with the chi^2 " >> stdin
	echo "     lambda_max=      $LAMBDAMAX " >> stdin
	echo "   } " >> stdin
	echo "" >> stdin
	echo "   scf " >> stdin
	echo "    " >> stdin
	echo "} " >> stdin
}

XCW(){
	TONTO_HEADER
	if [[ "$XWR" == "true" ]]; then 
		CHANGE_JOB_NAME
	else
		DEFINE_JOB_NAME
	fi
	CHARGE_MULT
	PROCESS_CIF
	if [[ "$XWR" == "true" ]]; then 
		CHANGE_JOB_NAME
	else
		DEFINE_JOB_NAME
	fi
	echo "   basis_directory= $BASISSETDIRXCW" >> stdin
	echo "   basis_name= $BASISSETTXCW" >> stdin
	echo "" >> stdin
	if [[ "$COMPLETESTRUCT" == "true"  ]]; then
		COMPLETECIFBLOCK
	fi
	CRYSTAL_BLOCK
	if [[ "$USEBECKE" == "true" ]]; then 
		BECKE_GRID
	fi
	XCW_SCF_BLOCK
	J=$[ $J + 1 ]
	echo "Runing Tonto, cycle number $J" 
        if [[ "$NUMPROCTONTO" != "1" ]]; then
		mpirun -n $NUMPROCTONTO $TONTO	
	else
		$TONTO
	fi
	echo "Tonto cycle number $J ended"
        if [ ! -d "$J.XCW_cycle.$JOBNAME" ]; then
	        mkdir $J.XCW_cycle.$JOBNAME
        fi
	cp stdin $J.XCW_cycle.$JOBNAME/$J.stdin
	cp stdout $J.XCW_cycle.$JOBNAME/$J.stdout
	cp $JOBNAME'.cartesian.cif2' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.cartesian_cov.cif2
	cp $JOBNAME'.fractional.cif1' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.fractional_cov.cif1
	cp $JOBNAME'.archive.cif' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.archive_cov.cif
	sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.cartesian.cif2
	sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $JOBNAME.fractional.cif1
	cp $JOBNAME'.cartesian.cif2' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
	cp $JOBNAME'.fractional.cif1' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
	cp $JOBNAME'.archive.cif' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.archive.cif
	cp $JOBNAME'.archive.fcf' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.archive.fcf
	cp $JOBNAME'.archive.fco' $J.XCW_cycle.$JOBNAME/$J.$JOBNAME.archive.fco
	cp $JOBNAME.residual_density,cell.cube $J.XCW_cycle.$JOBNAME/$J.residual_density,cell.cube
	if ! grep -q 'Wall-clock time taken' "stdout"; then
		echo "ERROR: problems in fit cycle, please check the $J.th stdout file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
#for f in *,restricted; do cp $f "$J.fit_cycle.$JOBNAME/$J.${f%}"; done
}

BOTTOM_PLOT(){
	if [ "$USECENTER" = "true" ]; then
		echo "      centre_atom= $CENTERATOM" >> stdin
		echo "      x_axis_atoms= $XAXIS" >> stdin
		echo "      y_axis_atoms= $YAXIS" >> stdin
		echo "      x_width= $WIDTHX Angstrom" >> stdin
		echo "      y_width= $WIDTHY Angstrom" >> stdin
		echo "      z_width= $WIDTHZ Angstrom" >> stdin
	else 
		echo "      use_unit_cell_as_bbox" >> stdin
	fi
	if [ "$USESEPARATION" = "true" ]; then
		echo "      desired_separation= $SEPARATION angstrom" >> stdin
	elif [ "$USEALLPOINTS" = "true" ]; then
		echo "      n_all_points= $PTSX $PTSY $PTSZ" >> stdin
	else
		echo "ERROR: Please enter cube size information" | tee -a $JOBNAME.lst
		exit 1
	fi
	echo "      plot_format= cell.cube" >> stdin
	if [ "$PLOT_ANGS" = "true" ]; then
		echo "      plot_units= angstrom^-3" >> stdin
	fi
	echo "" >> stdin
	echo "    }" >> stdin
	echo "" >> stdin
	echo "   plot" >> stdin
	echo "" >> stdin
}

PLOTS(){
	TONTO_HEADER
	PROCESS_CIF
	COMPLETECIFBLOCK
	DEFINE_JOB_NAME
	TONTO_BASIS_SET
	CHARGE_MULT
	CRYSTAL_BLOCK
	PUT_GEOM
	if [[ "$USEBECKE" == "true" ]]; then 
		BECKE_GRID
	fi
#echo "   read_archive molecular_orbitals restricted" >> stdin
	echo "   read_archive MOs r" >> stdin
#echo "   read_archive orbital_energies restricted" >> stdin
	echo "   read_archive MO_energies r" >> stdin
	echo "" >> stdin
	SCF_BLOCK_REST_TONTO
#	echo "   make_scf_density_matrix" >> stdin
#echo "   read_archive density_matrix restricted" >> stdin
	echo "   read_archive density_mx r" >> stdin
	echo "   assign_NOs_to_MOs " >> stdin
	echo "   make_structure_factors" >> stdin
	echo "" >> stdin
	if [ "$DEFDEN" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= deformation_density" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$DFTXCPOT" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= dft_xc_potential" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$DENS" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= electron_density" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$LAPL" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= laplacian" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$NEGLAPL" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= negative_laplacian" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$PROMOL" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= promolecule_density" >> stdin
		BOTTOM_PLOT
	fi
	if [ "$RESDENS" = "true" ]; then
		echo "   plot_grid= {" >> stdin
		echo "      kind= residual_density_map" >> stdin
		BOTTOM_PLOT
	fi
	echo "}" >> stdin 
        if [[ "$NUMPROCTONTO" != "1" ]]; then
		mpirun -n $NUMPROCTONTO $TONTO	
	else
		$TONTO
	fi
	if ! grep -q 'Wall-clock time taken' "stdout"; then
		echo "ERROR: problems in fit cycle, please check the $J.th stdout file for more details" | tee -a $JOBNAME.lst
		exit 1
	fi
}

RUN_XWR(){
	XCW	
	echo "" >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "                                     RESIDUALS AFTER XCW                                       " >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "" >> $JOBNAME.lst
	echo " $(awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)" >> $JOBNAME.lst
}

COMPLETECIFBLOCK(){
	if [[ "$COMPLETESTRUCT" == "true" && "$EXPLICITMOL" == "true" ]]; then
		echo "   cluster= {" >> stdin
                if [[ "$EXPLICITMOL" == "true" && "$COMPLETESTRUCT" == "false" ]]; then
		        echo "      generation_method= within_radius" >> stdin
		        echo "      radius= $EXPLRADIUS Angstrom" >> stdin
        		echo "      defragment= $DEFRAGEXPL" >> stdin
                elif [[ "$DOUBLEGROW" == "true" ]]; then
        		echo "      defragment= $COMPLETESTRUCT" >> stdin
                fi
		echo "      make_info" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
		echo "   create_cluster" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin		
		echo "" >> stdin
                if [[ "$EXPLICITMOL" == "true" && "$DOUBLEGROW" == "true" ]]; then
		        echo "   put" >> stdin
        		echo "   put_cif" >> stdin
        		echo "   put_grown_cif" >> stdin
        		echo "" >> stdin
        		echo "}" >> stdin
        		echo "" >> stdin
                        $TONTO
	                if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
                                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
                	        	mkdir $J.tonto_cycle.$JOBNAME
                                fi
                                cp $JOBNAME.cartesian.cif2 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
                                cp $JOBNAME.fractional.cif1 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
                                cp stdin $J.tonto_cycle.$JOBNAME/0.stdin
                                cp stdout $J.tonto_cycle.$JOBNAME/0.stdout
	                        if [[ "$J" == "0" ]]; then 
        #                               cp $JOBNAME.cartesian.cif2 defrag.cif
                                        cp $JOBNAME.fractional.cif1 defrag.cif
                                        CIF=defrag.cif
                                fi
                        else
                                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
                	        	mkdir $J.tonto_cycle.$JOBNAME
                                fi
                                cp $JOBNAME.cartesian.cif2 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
                                cp $JOBNAME.fractional.cif1 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
                                cp stdin $J.tonto_cycle.$JOBNAME/0.stdin
                                cp stdout $J.tonto_cycle.$JOBNAME/0.stdout
                        fi
	                        if [[ "$J" != "0" ]]; then 
                                        DOUBLEGROW=false
                                fi
                        TONTO_HEADER
                        PROCESS_CIF
                        DEFINE_JOB_NAME
	                if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
                		TONTO_BASIS_SET
                        fi
        	        echo "   cluster= {" >> stdin
                	echo "      generation_method= within_radius" >> stdin
        	        echo "      radius= $EXPLRADIUS Angstrom" >> stdin
               		echo "      defragment= $DEFRAGEXPL" >> stdin
                	echo "      make_info" >> stdin
        	        echo "   }" >> stdin
        		echo "" >> stdin
                	echo "   create_cluster" >> stdin
        	        echo "" >> stdin
        		echo "   name= $JOBNAME" >> stdin		
                	echo "" >> stdin
               fi
	fi

	if [[ "$COMPLETESTRUCT" == "true" && "$EXPLICITMOL" == "false" ]]; then
		echo "   cluster= {" >> stdin
        	echo "      defragment= $COMPLETESTRUCT" >> stdin
		echo "      make_info" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
		echo "   create_cluster" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin		
		echo "" >> stdin
	fi

	if [[ "$COMPLETESTRUCT" == "false" && "$EXPLICITMOL" == "true" ]]; then
		echo "   cluster= {" >> stdin
                if [[ "$EXPLICITMOL" == "true" && "$COMPLETESTRUCT" == "false" ]]; then
		        echo "      generation_method= within_radius" >> stdin
		        echo "      radius= $EXPLRADIUS Angstrom" >> stdin
        		echo "      defragment= $DEFRAGEXPL" >> stdin
                elif [[ "$DOUBLEGROW" == "true" ]]; then
        		echo "      defragment= $COMPLETESTRUCT" >> stdin
                fi
		echo "      make_info" >> stdin
		echo "   }" >> stdin
		echo "" >> stdin
		echo "   create_cluster" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin		
		echo "" >> stdin
                if [[ "$EXPLICITMOL" == "true" && "$DOUBLEGROW" == "true" ]]; then
		        echo "   put" >> stdin
        		echo "   put_cif" >> stdin
        		echo "   put_grown_cif" >> stdin
        		echo "" >> stdin
        		echo "}" >> stdin
        		echo "" >> stdin
                        $TONTO
	                if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
                                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
                	        	mkdir $J.tonto_cycle.$JOBNAME
                                fi
                                cp $JOBNAME.cartesian.cif2 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
                                cp $JOBNAME.fractional.cif1 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
                                cp stdin $J.tonto_cycle.$JOBNAME/0.stdin
                                cp stdout $J.tonto_cycle.$JOBNAME/0.stdout
	                        if [[ "$J" == "0" ]]; then 
        #                               cp $JOBNAME.cartesian.cif2 defrag.cif
                                        cp $JOBNAME.fractional.cif1 defrag.cif
                                        CIF=defrag.cif
                                fi
                        else
                                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
                	        	mkdir $J.tonto_cycle.$JOBNAME
                                fi
                                cp $JOBNAME.cartesian.cif2 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
                                cp $JOBNAME.fractional.cif1 $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
                                cp stdin $J.tonto_cycle.$JOBNAME/0.stdin
                                cp stdout $J.tonto_cycle.$JOBNAME/0.stdout
                        fi
                        if [[ "$J" != "0" ]]; then 
                                DOUBLEGROW=false
                        fi
                        TONTO_HEADER
                        PROCESS_CIF
                        DEFINE_JOB_NAME
	                if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
                		TONTO_BASIS_SET
                        fi
        	        echo "   cluster= {" >> stdin
                	echo "      generation_method= within_radius" >> stdin
        	        echo "      radius= $EXPLRADIUS Angstrom" >> stdin
               		echo "      defragment= $DEFRAGEXPL" >> stdin
                	echo "      make_info" >> stdin
        	        echo "   }" >> stdin
        		echo "" >> stdin
                	echo "   create_cluster" >> stdin
        	        echo "" >> stdin
        		echo "   name= $JOBNAME" >> stdin		
                	echo "" >> stdin
               fi
	fi
}

COMPLETECELLBLOCK(){
        echo "   cluster= {" >> stdin
        echo "      generation_method= unit_cell" >> stdin
	echo "      make_info" >> stdin
	echo "   }" >> stdin
	echo "" >> stdin
	echo "   create_cluster" >> stdin
	echo "" >> stdin
	echo "   name= $JOBNAME" >> stdin		
	echo "" >> stdin
}

REDUCECELLCLUSTER(){
        echo "   cluster= {" >> stdin
        echo "      generation_method= assymetric_unit" >> stdin
        echo "      make_info" >> stdin
        echo "   }" >> stdin
        echo "" >> stdin
        echo "   create_cluster" >> stdin
        echo "" >> stdin
        echo "   name= $JOBNAME" >> stdin
        echo "" >> stdin
}

run_script(){
	SECONDS=0
	#MAXSHIFT=0
	# BEGIN LAMAGOET CP2K INTEGRATION: mode validation
	if [ "$SCFCALCPROG" = "CP2K" ]; then
		CP2K_VALIDATE_LAMAGOET_MODE || exit 1
	fi
	# END LAMAGOET CP2K INTEGRATION: mode validation

	if [ "$POWDER_HAR" = "true" ]; then
                NSA2_COUNTER=$"1"
                JANA_COUNTER=$"0" ###counter for powder HAR
                if [ ! -d "$JANA_COUNTER.Jana_cycle" ]; then
                        mkdir $JANA_COUNTER.Jana_cycle
                fi
                cp $JOBNAME.m40 $JANA_COUNTER.Jana_cycle/$JOBNAME.m40
                cp $JOBNAME.m41 $JANA_COUNTER.Jana_cycle/$JOBNAME.m41
                cp $JOBNAME.m70 $JANA_COUNTER.Jana_cycle/$JOBNAME.m70
                cp $JOBNAME.m50 $JANA_COUNTER.Jana_cycle/$JOBNAME.m50
                cp $JOBNAME.m90 $JANA_COUNTER.Jana_cycle/$JOBNAME.m90
                cp $JOBNAME.m80 $JANA_COUNTER.Jana_cycle/$JOBNAME.m80
                cp $JOBNAME.m83 $JANA_COUNTER.Jana_cycle/$JOBNAME.m83
                cp $JOBNAME.m85 $JANA_COUNTER.Jana_cycle/$JOBNAME.m85
                cp $JOBNAME.m95 $JANA_COUNTER.Jana_cycle/$JOBNAME.m95
                cp $JOBNAME.cif $JANA_COUNTER.Jana_cycle/$JOBNAME.cif
                python3 /usr/local/bin/powderHARstart.py
                python3 /usr/local/bin/powderHARcifrewrite.py
                JANA_COUNTER=$[$JANA_COUNTER+1]
        fi
	I=$"0"   ###counter for gaussian jobs
	J=$"0"   ###counter for tonto fits
	shopt -s nocasematch	

	if [[ "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" && "$POWDER_HAR" != "true" ]]; then 
		HKLEXT=$(echo $HKL | awk -F. '{print $NF}')
		if [[ "$HKLEXT" != "fcf" ]]; then
			#removing  0 0 0 line 
			if [[ ! -z $(awk '{if (($1) == "0" && ($2) == "0" && ($3) == "0" ) print}' $HKL) ]]; then
				awk '{if (($1) != "0" && ($2) != "0" && ($3) != "0" ) print}' $HKL > $JOBNAME.tonto_edited.hkl
			fi
			#backing up hkl input file and copying the one without the 0 line to the $HKL variable
			if [ -f "$JOBNAME.tonto_edited.hkl" ]; then
				cp $HKL $JOBNAME.your_input.hkl
				cp $JOBNAME.tonto_edited.hkl $HKL
				rm $JOBNAME.tonto_edited.hkl
				echo "WARNING: HKL has been formated, your original input is saved with the name $JOBNAME.your_input.hkl!"
			fi
			
			#checking if numbers are grown together and separating them. note that this will ignore the header lines if is exists.
			if [[ ! -z "$(awk ' NF<5 && NF>2 {print $0}' $HKL)" ]]; then
				gawk 'BEGIN { FS = "" } { for (i = 1; i <= NF; i = i + 1) h=$1$2$3$4; k=$5$6$7$8; l=$9$10$11$12; i_f=$13$14$15$16$17$18$19$20; sig=$21$22$23$24$25$26$27$28; print h, k, l, i_f, sig }' $HKL > $JOBNAME.tonto_edited.hkl
				cp $HKL $JOBNAME.your_input.hkl
				cp $JOBNAME.tonto_edited.hkl $HKL
				rm $JOBNAME.tonto_edited.hkl
			fi
		
			# writing header on hkl
			if [ "$WRITEHEADER" = "true" ]; then
			  	#checking if the header was not there already
				if [[ ! -z "$(grep "reflection_data= {" $HKL)" ]]; then
					echo "header was already in the hkl file, nothing to do."
				else
					#putting the header in
					sed -i '1 i\   data= {' $HKL 
					if [ "$ONF" = "true" ]; then
						sed -i '1 i\  keys= { h= k= l= f_exp= f_sigma= }' $HKL 
				     	elif [ "$ONF2" = "true" ]; then
						sed -i '1 i\  keys= { h= k= l= i_exp= i_sigma= }' $HKL 
					else
						echo "ERROR: Please select the format of the hkl file for header (F or F^2)" | tee -a $JOBNAME.lst
						exit 1
					fi
					sed -i '1 i\ reflection_data= {' $HKL 
					sed -i '$ a\   }' $HKL
					sed -i '$ a\  }' $HKL 
					sed -i '$ a\ REVERT' $HKL 
				fi
			fi
		
			if [[ -z "$(grep "reflection_data= {" $HKL)" ]]; then
				echo "You are missing the tonto header in the hkl file."
			fi
		else
			ISFCF=true
		fi
	fi
	if [[ "$PLOT_TONTO" == "true" ]]; then
		PLOTS
		exit 0
		exit
	fi	
	if [[ "$XCWONLY" == "true" ]]; then
		XCW
		exit 0
		exit
	fi
	if [[ ("$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "OCC") && "$SCCHARGES" == "true" ]]; then
		DOUBLE_SCF="true"
	fi 
	if [[ ("$SCFCALCPROG" == "Tonto" && "$POWDER_HAR" == "true") && "$SCCHARGES" == "true" ]]; then
		DOUBLE_SCF="true"
	fi 
	if [[ "$COMPLETESTRUCT" == "true" && "$EXPLICITMOL" == "true" ]]; then
		DOUBLEGROW="true"
	fi 
	echo "###############################################################################################" > $JOBNAME.lst
	echo "                                           lamaGOET                                            " >> $JOBNAME.lst
	echo "###############################################################################################" >> $JOBNAME.lst
	echo "Job started on:" >> $JOBNAME.lst
	date >> $JOBNAME.lst
	echo "User Inputs: " >> $JOBNAME.lst
	echo "Tonto executable	: $TONTO"  >> $JOBNAME.lst 
	echo "$($TONTO -v)" >> $JOBNAME.lst 
	echo "SCF program		: $SCFCALCPROG" >> $JOBNAME.lst
	if [ "$SCFCALCPROG" != "Tonto" ]; then 
		echo "SCF executable		: $SCFCALC_BIN" >> $JOBNAME.lst
	fi
	echo "Job name		: $JOBNAME" >> $JOBNAME.lst
	echo "Input cif		: $CIF" >> $JOBNAME.lst
	if [[ "$SCFCALCPROG" != "optgaussian" || "$SCFCALCPROG" != "optorca" ]]; then 
		echo "Input hkl		: $HKL" >> $JOBNAME.lst
		echo "Wavelenght		: $WAVE" Angstrom >> $JOBNAME.lst
		echo "F_sigma_cutoff		: $FCUT" >> $JOBNAME.lst
	fi
	echo "Tol. for shift on esd	: $CONVTOL" >> $JOBNAME.lst
	echo "Charge			: $CHARGE" >> $JOBNAME.lst
	echo "Multiplicity		: $MULTIPLICITY" >> $JOBNAME.lst
	if [ "$SCFCALCPROG" = "Tonto" ]; then 
		echo "Level of theory 	: $METHOD/$BASISSETT" >> $JOBNAME.lst
		echo "Basis set directory	: $BASISSETDIR" >> $JOBNAME.lst
	else
		echo "Level of theory 	: $METHOD/$BASISSETG" >> $JOBNAME.lst
	fi
	if [[ "$SCFCALCPROG" == "Tonto" ]]; then 
		echo "Becke grid (not default): $USEBECKE" >> $JOBNAME.lst
		if [[ "$USEBECKE" == "true" ]]; then
			echo "Becke grid accuracy	: $ACCURACY" >> $JOBNAME.lst
			echo "Becke grid pruning scheme	: $BECKEPRUNINGSCHEME" >> $JOBNAME.lst
		fi
	fi
	if [[ "$SCFCALCPROG" != "elmodb" ]]; then 
		echo "Use SC cluster charges 	: $SCCHARGES" >> $JOBNAME.lst
		if [ "$SCCHARGES" = "true" ]; then
			echo "SC cluster charge radius: $SCCRADIUS Angstrom" >> $JOBNAME.lst
			echo "Complete molecules	: $DEFRAG" >> $JOBNAME.lst
		fi
	fi
	echo "Refine position and ADPs: $POSADP" >> $JOBNAME.lst
	echo "Refine positions only	: $POSONLY" >> $JOBNAME.lst
	echo "Refine ADPs only	: $ADPSONLY" >> $JOBNAME.lst
	if [[ "$POSONLY" != "true" ]]; then
		echo "Refine H ADPs 		: $REFHADP" >> $JOBNAME.lst
		if [[ "$REFHADP" == "true" ]]; then
			echo "Refine Hydrogens isot.	: $HADP" >> $JOBNAME.lst
		fi
	fi
	echo "Dispersion correction	: $DISP" >> $JOBNAME.lst
	if [ $DISP = "yes" ]; then
		echo "			  $(cat DISP_inst.txt)" >> $JOBNAME.lst
	fi
	
	if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" && "$SCFCALCPROG" != "CP2K" ]]; then 
		echo "Only for Gaussian/Orca/OCC job	" >> $JOBNAME.lst
		echo "Number of processor 	: $NUMPROC" >> $JOBNAME.lst
		echo "Memory		 	: $MEM" >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "                                     Starting Geometry                                         " >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" > stdin
		echo "!!!                                                                                         !!!" >> stdin
		echo "!!!                        This stdin was written with lamaGOET                             !!!" >> stdin
		echo "!!!                                                                                         !!!" >> stdin
		echo "!!!                    script written by Lorraine Andrade Malaspina                         !!!" >> stdin
		echo "!!!                        contact: lorraine.malaspina@gmail.com                            !!!" >> stdin
		echo "!!!                                                                                         !!!" >> stdin
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >> stdin
		echo "{ " >> stdin
		echo "" >> stdin
		echo "   keyword_echo_on" >> stdin
		echo "" >> stdin
		echo "   ! Process the CIF" >> stdin
		echo "   CIF= {" >> stdin
		echo "       file_name= $CIF" >> stdin
		if [ "$XHALONG" = "true" ]; then
	           	if [ ! -z "$BHBOND" ]; then
			   	echo "       BH_bond_length= $BHBOND angstrom" >> stdin
		   	fi
	           	if [ ! -z "$CHBOND" ]; then
			   	echo "       CH_bond_length= $CHBOND angstrom" >> stdin
		   	fi
	           	if [ ! -z "$NHBOND" ]; then
			   	echo "       NH_bond_length= $NHBOND angstrom" >> stdin
		   	fi
	           	if [ ! -z "$OHBOND" ]; then
			   	echo "       OH_bond_length= $OHBOND angstrom" >> stdin
		   	fi
		fi
		echo "    }" >> stdin
		echo "" >> stdin
		echo "   process_CIF" >> stdin
		echo "" >> stdin
		echo "   name= $JOBNAME" >> stdin
		echo "" >> stdin
#               if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
#               fi
		COMPLETECIFBLOCK
		echo "   put" >> stdin 
		echo "" >> stdin
                if [[ "$SCFCALCPROG" != "Crystal14" ]]; then
                        if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" ]]; then
                		if [[ "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "Gaussian" ]]; then
                                	echo "   write_xyz_file" >> stdin
				else
	                                echo "   write_fragment_xyz_file " >> stdin
				fi
                        else 
                                echo "   write_xyz_file" >> stdin
                        fi
                else
                        echo "   write_xtal23_xyz_file" >> stdin
                fi
		echo "   put_cif" >> stdin
		if [[ "$COMPLETESTRUCT" == "true" || "$EXPLICITMOL" == "true" || "$SCFCALCPROG" == "OCC" ]]; then
			echo "" >> stdin
			echo "   put_grown_cif" >> stdin
		fi
		if [[ "$SCFCALCPROG" == "optgaussian" || "$SCFCALCPROG" == "optorca" ]];then
			echo "" >> stdin
			echo "   put_grown_cif" >> stdin
		fi
		echo "" >> stdin
		echo "}" >> stdin 
		echo "Reading cif with Tonto"
		if [[ "$NUMPROCTONTO" != "1" ]]; then
			mpirun -n $NUMPROCTONTO $TONTO	
		else
			$TONTO
		fi
		NUMBEROFATOMS=$(awk '/No. of atoms ............../ {print $5}' stdout )
	        if [[ "$USENOSPHERA2" == "true" ]]; then
                        LABELS_IN_XYZ
                fi
                #there is no refinement here yet!!!!!!
		if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "elmodb" ]]; then
			sed -i 's/(//g' $JOBNAME.xyz
			sed -i 's/)//g' $JOBNAME.xyz
		fi
		if ! grep -q 'Wall-clock time taken' "stdout"; then
			echo "ERROR: something wrong with your input cif file, please check the stdout file for more details" | tee -a $JOBNAME.lst
			exit 1
		fi
                if [ ! -d "$J.tonto_cycle.$JOBNAME" ]; then
	        	mkdir $J.tonto_cycle.$JOBNAME
                fi
		if [[ ( "$SCFCALCPROG" == "optgaussian"  &&  "$SCCHARGES" == "false" ) || "$SCFCALCPROG" == "optorca"  &&  "$SCCHARGES" == "false" ]]; then 
			cp $JOBNAME.xyz $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.xyz
                else
			cp $JOBNAME.xyz $J.tonto_cycle.$JOBNAME/$JOBNAME.starting_geom.xyz
		fi
		cp stdin $J.tonto_cycle.$JOBNAME/$J.stdin
		cp stdout $J.tonto_cycle.$JOBNAME/$J.stdout
#               if [ -f $JOBNAME.cartesian.cif2 ]; then
                if [ -f $JOBNAME.fractional.cif1 ]; then
			cp $JOBNAME'.cartesian.cif2' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
			cp $JOBNAME'.fractional.cif1' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
			sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.cartesian.cif2
			sed -i '/# NOTE: Cartesian 9Nx9N covariance matrix in BOHR units/,/# ===========/d' $J.tonto_cycle.$JOBNAME/$J.$JOBNAME.fractional.cif1
		fi
		awk '{a[NR]=$0}/^Atom coordinates/{b=NR}/^Unit cell information/{c=NR}END{for(d=b-1;d<=c-2;++d)print a[d]}' stdout >> $JOBNAME.lst
		echo "Done reading cif with Tonto"
#is this ok now?if [[ "$SCFCALCPROG" == "elmodb" && ! -z tonto.cell || "$SCFCALCPROG" == "optgaussian" && ! -z tonto.cell  ]]; then
		if [[ ( "$SCFCALCPROG" == "elmodb" && ! -f tonto.cell ) || ( "$SCFCALCPROG" == "optgaussian" && ! -f tonto.cell ) || ( "$SCFCALCPROG" == "optorca" && ! -f tonto.cell ) ]]; then
			CELLA=$(grep "a cell parameter ............" stdout | head -1 | awk '{print $NF}')
			CELLB=$(grep "b cell parameter ............" stdout | head -1 | awk '{print $NF}')
			CELLC=$(grep "c cell parameter ............" stdout | head -1 | awk '{print $NF}')
			CELLALPHA=$(grep "alpha angle ................." stdout | head -1 | awk '{print $NF}')
			CELLBETA=$(grep "beta  angle ................." stdout | head -1 | awk '{print $NF}')
			CELLGAMMA=$(grep "gamma angle ................." stdout | head -1 | awk '{print $NF}')
			SPACEGROUP=$(grep "Hall symbol" stdout | gawk 'BEGIN { FS = " ................ " } {print $NF}')
	  		echo "      spacegroup= { hall_symbol= '$SPACEGROUP' }" > tonto.cell
			echo "" >> tonto.cell
			echo "      unit_cell= {" >> tonto.cell
			echo "" >> tonto.cell
			echo "         angles=       $CELLALPHA   $CELLBETA   $CELLGAMMA   Degree" >> tonto.cell
			echo "         dimensions=   $CELLA   $CELLB   $CELLC   Angstrom" >> tonto.cell
			echo "" >> tonto.cell
			echo "      }" >> tonto.cell
			echo "" >> tonto.cell
			echo "      REVERT" >> tonto.cell
		fi
#is this ok now?if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "optgaussian" ]]; then 
                if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
 	        	TONTO_TO_CRYSTAL
        		SCF_TO_TONTO
 	        	TONTO_TO_CRYSTAL
 	        	CHECK_ENERGY
                fi
		if [[ "$SCFCALCPROG" == "Gaussian" ]] || [[ "$SCFCALCPROG" == "optgaussian"  &&  "$SCCHARGES" == "true" ]]; then 
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Starting Gaussian                                         " >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "%rwf=./$JOBNAME.rwf" > $JOBNAME.com 
			echo "%int=./$JOBNAME.int" | tee -a $JOBNAME.com  $JOBNAME.lst
			echo "%NoSave" | tee -a $JOBNAME.com  $JOBNAME.lst
			echo "%chk=./$JOBNAME.chk" | tee -a $JOBNAME.com  $JOBNAME.lst
			echo "%mem=$MEM" | tee -a $JOBNAME.com  $JOBNAME.lst
			echo "%nprocshared=$NUMPROC" | tee -a $JOBNAME.com $JOBNAME.lst
			if [ "$SCFCALCPROG" = "optgaussian" ]; then
#				OPT=" opt=calcfc"
				OPT=" opt"
			fi
			if [ "$METHOD" = "rks" ]; then
				echo "# blyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" | tee -a $JOBNAME.com $JOBNAME.lst    
			else
				if [ "$METHOD" = "uks" ]; then
					echo "# ublyp/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" | tee -a $JOBNAME.com $JOBNAME.lst
				else
					echo "# $METHOD/$BASISSETG nosymm $EXTRAKEY output=wfn 6D 10F Fchk $INT $GAUSSEMPDISPKEY" | tee -a $JOBNAME.com $JOBNAME.lst
			        fi
			fi			
			echo ""  | tee -a $JOBNAME.com $JOBNAME.lst
			echo "$JOBNAME" | tee -a $JOBNAME.com $JOBNAME.lst
			echo "" | tee -a  $JOBNAME.com $JOBNAME.lst
			echo "$CHARGE $MULTIPLICITY" | tee -a  $JOBNAME.com $JOBNAME.lst
			awk 'NR>2' $JOBNAME.xyz | tee -a  $JOBNAME.com $JOBNAME.lst
			echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
			if [ "$GAUSGEN" = "true" ]; then
		        	cat basis_gen.txt | tee -a $JOBNAME.com  $JOBNAME.lst
				echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
			fi
			echo "./$JOBNAME.wfn" | tee -a $JOBNAME.com  $JOBNAME.lst
			echo "" | tee -a $JOBNAME.com  $JOBNAME.lst
			I=$"1"
			echo "Running Gaussian, cycle number $I" 
			$SCFCALC_BIN $JOBNAME.com
	                cp Test.FChk $JOBNAME.fchk
                        sed -i '/^#/d' $JOBNAME.fchk
			echo "Gaussian cycle number $I ended"
			if ! grep -q 'Normal termination of Gaussian' "$JOBNAME.log"; then
				echo "ERROR: Gaussian job finished with error, please check the $I.th log file for more details" | tee -a $JOBNAME.lst
				exit 1
			fi
                        ENERGIA=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log |  sed 's/^ //' |  sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*HF=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
                        RMSD=$(sed -n '/Population analysis/,/Writing a WFN file/p' $JOBNAME.log |  sed 's/^ //' |  sed ':begin;$!N;s/\n//;tbegin' | awk '!f && sub(/.*RMSD=/,""){f=1} f' | awk -F '\' '{ print $1}' | tr -d '\r')
#			ENERGIA=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//' |  grep "HF=" | sed 's/^.*HF=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}' | tr -d '\r')
#			RMSD=$(sed 's/^ //' $JOBNAME.log | sed 'N;s/\n//' | sed 'N;s/\n//' | sed 'N;s/\n//'| sed -n '/RMSD=/{N;p;}' | sed 's/^.*RMSD=//' | sed 'N;s/\n//' | sed '2d' | sed 's/RMSD=//g' | awk -F '\' '{ print $1}'| tr -d '\r')
			echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
#			echo "Generation fcheck file for Gaussian cycle number $I"
			echo "Gaussian cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
                        # waiting for Bjarke to write any hkl dummy
                        # file with the correct indices
			if [[ "$USENOSPHERA2" == "true" ]]; then
#				awk '$1 ~ /^[0-9]/ {printf "%4i%4i%4i%8.2f%8.2f\n", $1, $2, $3, $4, $5}' $HKL > shelx.hkl
		                echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
                                if [[ "$SCCHARGES" != "true" ]]; then 
				        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
				        RUN_NOSPHERA2
				        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
                                fi
			fi
                        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
	        	        mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
                        fi
			cp $JOBNAME.com  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.com
			cp Test.FChk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
                        sed -i '/^#/d' $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk 
			cp $JOBNAME.log  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.log
			if [[ "$USENOSPHERA2" == "true" ]]; then
				cp $JOBNAME.wfn  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
                                if [[ "$SCCHARGES" != "true" ]]; then 
                                        RUN_JANA
                                fi
			fi
			SCF_TO_TONTO
			TONTO_TO_GAUSSIAN
			CHECK_ENERGY
#		elif [[ "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "optorca" ]]; then  
		elif [[ "$SCFCALCPROG" == "Orca" ]] || [[ "$SCFCALCPROG" == "optorca"  &&  "$SCCHARGES" == "true" ]]; then 
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Starting Orca                                             " >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			if [[ "$SCFCALCPROG" == "optorca" ]]; then
				OPT="Opt"
			fi
			if [ "$METHOD" = "rks" ]; then
				echo "! blyp $BASISSETG " > $JOBNAME.inp
				echo "! blyp $BASISSETG " >> $JOBNAME.lst
			elif [ "$METHOD" = "uks" ]; then
				echo "! ublyp $BASISSETG " > $JOBNAME.inp
				echo "! ublyp $BASISSETG " >> $JOBNAME.lst
			else
				echo "! $METHOD $BASISSETG " > $JOBNAME.inp
				echo "! $METHOD $BASISSETG " >> $JOBNAME.lst
			fi
			echo "" | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "%pal nprocs $NUMPROC end" | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "" | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "%output" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   PrintLevel=Normal" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   Print[ P_Basis       ] 2" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   Print[ P_GuessOrb    ] 1" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   Print[ P_MOs         ] 1" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   Print[ P_Density     ] 1" | tee -a $JOBNAME.inp $JOBNAME.lst
	 		echo "   Print[ P_SpinDensity ] 1" | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "end" | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "" | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "* xyz $CHARGE $MULTIPLICITY" | tee -a $JOBNAME.inp $JOBNAME.lst
			awk 'NR>2' $JOBNAME.xyz | tee -a $JOBNAME.inp $JOBNAME.lst
			echo "*" | tee -a $JOBNAME.inp $JOBNAME.lst
			if [[ "$GAUSGEN" == "true" ]]; then
				cat basis_gen.txt | tee -a $JOBNAME.inp $JOBNAME.lst
				echo "" | tee -a $JOBNAME.inp $JOBNAME.lst
			fi
			I=$"1"
			echo "Running Orca, cycle number $I" 
                        if [ -f $JOBNAME.gbw ]; then
                                rm $JOBNAME.gbw
                        fi      
	 		$SCFCALC_BIN $JOBNAME.inp > $JOBNAME.out
			echo "Orca cycle number $I ended"
			if ! grep -q '****ORCA TERMINATED NORMALLY****' "$JOBNAME.out"; then
				echo "ERROR: Orca job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
				exit 1
			fi
			ENERGIA=$(sed -n '/FINAL SINGLE POINT ENERGY/p' $JOBNAME.out | tail -1 | awk '{print $5}' | tr -d '\r')
			RMSD=$(sed -n '/Last RMS-Density change/p' $JOBNAME.out | tail -1 | awk '{print $5}' | tr -d '\r')
			echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "Generation molden file for Orca cycle number $I"
			if [[ "$(which orca_2mkl.exe)" == "" ]]; then
				orca_2mkl $JOBNAME -molden  > /dev/null
			else 
				orca_2mkl.exe $JOBNAME -molden  > /dev/null
			fi
			if [[ "$(which orca_2aim.exe)" == "" ]]; then
				orca_2aim $JOBNAME  > /dev/null
			else
				orca_2aim.exe $JOBNAME  > /dev/null
			fi
#			echo "Orca cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
# 			This is the first cycle, no charges here yet!!!
#                       NUMATOMWFN=$(grep -m1 " Q " $JOBNAME.wfn | awk '{ print $2 }' )
#                       NUMATOMWFN=$[$NUMATOMWFN -1]
#                       awk -v  NUMATOMWFN=$NUMATOMWFN 'NR==2 {gsub($7, NUMATOMWFN, $0); print}1' $JOBNAME.wfn > temp.wfn
#                       sed -i '2d' temp.wfn
#                       sed -i '/ Q /d' temp.wfn
#                       mv temp.wfn $JOBNAME.wfn
# 			This is the first cycle, no charges here yet!!!
#			NAPONE=$[ $NUMBEROFATOMS + 1 ]
#			STARTLINE=$(grep -n "  $NAPONE 0" $JOBNAME.molden.input | awk -F: '{print $1}')
#			ENDLINE=$(grep -n "\[5D\]" $JOBNAME.molden.input | awk -F: '{print $1}')
#			sed -i "$STARTLINE","$[ $ENDLINE - 1]"'{/.*/d;}' $JOBNAME.molden.input
#			sed -i '/Q\ /d' $JOBNAME.molden.input
			if [[ "$USENOSPHERA2" == "true" && "$SCCHARGES" != "true" ]]; then
		                echo "   0   0   0    0.00    0.00"  >> $JOBNAME.hkl
                                if [[ "$SCCHARGES" != "true" ]]; then 
				        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
				        RUN_NOSPHERA2
				        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
                                fi
			fi
                        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
		                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
                        fi
			cp $JOBNAME.inp          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.inp
			cp $JOBNAME.molden.input $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.molden.input
			cp $JOBNAME.out          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
			if [[ "$USENOSPHERA2" == "true" && "$SCCHARGES" != "true" ]]; then
				cp $JOBNAME.wfn $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
                                if [[ "$SCCHARGES" != "true" ]]; then 
                                        RUN_JANA
                                fi
			fi
			SCF_TO_TONTO
			TONTO_TO_ORCA
			CHECK_ENERGY
		fi
		if [[ "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "optocc" ]]; then  
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Starting OCC                                             " >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			if [[ "$SCFCALCPROG" == "optocc" ]]; then
				OPT="Opt"
			fi
			I=$"1"
			echo "Running OCC, cycle number $I" 
			$SCFCALC_BIN scf $JOBNAME.xyz --method $METHOD --basis $BASISSETG -o fchk > $JOBNAME.out
			echo "OCC cycle number $I ended"
			if ! grep -q 'A job well done' "$JOBNAME.out"; then
				echo "ERROR: OCC job finished with error, please check the $I.th out file for more details" | tee -a $JOBNAME.lst
				exit 1
			fi
			ENERGIA=$(sed -n '/^total/p' $JOBNAME.out | awk '{print $2}' | tr -d '\r')
			RMSD=$( awk '{a[NR]=$0}/restricted spinorbital SCF energy converged after/ {print a[NR-1]}' $JOBNAME.out | awk '{print $3}'| tr -d '\r')
			echo "Starting geometry: Energy= $ENERGIA, RMSD= $RMSD" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "OCC cycle number $I, final energy is: $ENERGIA, RMSD is: $RMSD "
                        if [ ! -d "$I.$SCFCALCPROG.cycle.$JOBNAME" ]; then
		                mkdir $I.$SCFCALCPROG.cycle.$JOBNAME
                        fi
			cp $JOBNAME.xyz          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.xyz
#			cp $JOBNAME.owf.$JOBNAME.fchk $JOBNAME.fchk
#			cp $JOBNAME.owf.$JOBNAME.fchk $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
			cp $JOBNAME.owf.fchk     $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.fchk
			cp $JOBNAME.out          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.out
        		if [ -f "cluster_charges" ]; then
				cp cluster_charges          $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.cluster_charges
		        fi
			SCF_TO_TONTO
			TONTO_TO_OCC
			CHECK_ENERGY
		fi
		if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "OCC" || "$SCFCALCPROG" == "Crystal14" || "$SCFCALCPROG" == "CP2K" ]]; then
			if [[ "$DOUBLE_SCF" == "true" ]]; then #I think this whole block is not necessary! need to test
				if [[ "$POWDER_HAR" == "true" ]]; then
                                        RUN_JANA
                                        WRITEXYZ
				        SCF_TO_TONTO
				        if [ "$SCFCALCPROG" = "Gaussian" ]; then  
					        TONTO_TO_GAUSSIAN
        				else 
	        				TONTO_TO_ORCA
		        		fi
                                        RUN_JANA
                                        WRITEXYZ
                                fi
               			SCF_TO_TONTO
				if [ "$SCFCALCPROG" = "Gaussian" ]; then  
					TONTO_TO_GAUSSIAN
				elif [ "$SCFCALCPROG" = "Orca" ]; then 
					TONTO_TO_ORCA
				elif [ "$SCFCALCPROG" = "OCC" ]; then
					TONTO_TO_OCC
				fi
				CHECK_ENERGY
			fi		
		        if [[ "$POWDER_HAR" == "true" ]]; then
				while (( $(echo "$(echo ${DE#-}) > $CONVTOLE" | bc -l) && $( echo  "$JANA_COUNTER <= $MAXPHARCYCLE" | bc -l ) )); do
#	                while (( $( echo "$JANA_COUNTER < $MAXPHARCYCLE" | bc -l )  )); do
                                        RUN_JANA
                                        if [[ "$SCCHARGES" == "true" ]]; then 
                                                WRITEXYZ
                                        fi
				        SCF_TO_TONTO
        				if [ "$SCFCALCPROG" = "Gaussian" ]; then  
	        			        TONTO_TO_GAUSSIAN
        	        		elif [ "$SCFCALCPROG" = "Orca" ]; then 
	                			TONTO_TO_ORCA
					elif [ "$SCFCALCPROG" = "OCC" ]; then
						TONTO_TO_OCC
	                		fi
				        CHECK_ENERGY
                                done
                        else
                                if [[ "$SCFCALCPROG" != "Crystal14" && "$SCFCALCPROG" != "CP2K" ]]; then  
 		        	        while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) && $( echo "$J <= $MAXCYCLE" | bc -l )  )); do
# 		        	        while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $(echo "$(echo ${DE#-}) > $CONVTOLE" | bc -l) || $( echo "$J <= $MAXCYCLE" | bc -l ) )); do
                                                if [[ "${HAR_WAVEFUNCTION_STALLED:-false}" == "true" ]]; then
                                                        echo "Refinement ended because the wavefunction stopped changing."
                                                        break
                                                fi
				                if [[ $J -ge $MAXCYCLE ]]; then
				                	CHECK_ENERGY
        				        	echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
        				        	break
        				        fi
        				        SCF_TO_TONTO
        				        if [ "$SCFCALCPROG" = "Gaussian" ]; then  
        			        		TONTO_TO_GAUSSIAN
        				        elif [ "$SCFCALCPROG" = "Orca" ]; then  
        			        		TONTO_TO_ORCA
        				        elif [ "$SCFCALCPROG" = "OCC" ]; then  
        			        		TONTO_TO_OCC
        			        	fi
        			        	CHECK_ENERGY
        		        	done
                                 else 
#					echo "I AM IN THE FIRST LOOP XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
#					echo maxshif $MAXSHIFT
#					echo convtol $CONVTOL
#					echo DE $DE
#					echo convtoleee $CONVTOLE
					#echo "MAXSHIFT=[$MAXSHIFT]"
					#echo "CONVTOL=[$CONVTOL]"
					#echo "DE=[$DE]"
					#echo "CONVTOLE=[$CONVTOLE]"
					#echo "$MAXSHIFT > $CONVTOL" | bc -l
					#echo "${DE#-} > $CONVTOLE" | bc -l
					#MAXSHIFT=$(echo "$MAXSHIFT > $CONVTOL" | bc -l)
					#DE=$(echo "${DE#-} > $CONVTOLE" | bc -l)
					#while (( MAXSHIFT || DE )); do
 		        	        while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $(echo "$(echo ${DE#-}) > $CONVTOLE" | bc -l) )); do

                                                if [[ "${HAR_WAVEFUNCTION_STALLED:-false}" == "true" ]]; then
                                                        echo "Refinement ended because the wavefunction stopped changing."
                                                        break
                                                fi
				                if [[ $J -ge $MAXCYCLE ]]; then
				                	CHECK_ENERGY
        				        	echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
        				        	break
        				        fi
        				        SCF_TO_TONTO
        			        	TONTO_TO_CRYSTAL
        			        	CHECK_ENERGY
#						echo "I AM HERE!!!"
        		        	done
					GET_RESIDUALS
                                 fi
                        fi
		fi
		if [[ "$SCFCALCPROG" == "optgaussian" || "$SCFCALCPROG" == "optorca" ]]; then
			if [[ "$SCCHARGES" == "true" ]];then
#			while (( ($(awk "BEGIN {print $DE > $CONVTOL}") | bc -l ) || $( echo "$J <= 1" | bc -l )  )); do
				while (( $(echo "$(echo ${DE#-}) > $CONVTOL" | bc -l) || $( echo "$J <= 1" | bc -l )  )); do
					if [[ $J -ge $MAXCYCLE ]];then
						CHECK_ENERGY
						echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
						break
					fi
					SCF_TO_TONTO
					if [[ "$SCFCALCPROG" == "Gaussian" || "$SCFCALCPROG" == "optgaussian" ]]; then  
						TONTO_TO_GAUSSIAN
					else 
						TONTO_TO_ORCA
					fi
					CHECK_ENERGY
				done
				if [[ "$SCFCALCPROG" == "optgaussian" ]]; then
					GET_FREQ
				elif [[ "$SCFCALCPROG" == "optorca" ]]; then
					GET_FREQ_ORCA
				fi
			else
#     				ONLY_ONE="opt=calcfc"
     				ONLY_ONE="opt"
				if [[ "$SCFCALCPROG" == "optgaussian" ]]; then
					GET_FREQ
				elif [[ "$SCFCALCPROG" == "optorca" ]]; then
					GET_FREQ_ORCA
				fi
			fi
		fi
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		APPEND_IAM_RESULTS
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "                                     Final Geometry                                            " >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		echo "Energy= $ENERGIA2, RMSD= $RMSD2" >> $JOBNAME.lst
		echo " $(awk '{a[NR]=$0}/^Structure refinement results/ && !b {b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		if [[ "$SCFCALCPROG" != "Tonto" && "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" ]]; then 
			echo " $(awk '{a[NR]=$0}/^Rigid-atom fit results/ && !b {b=NR}/^Fit statistics vs. angle/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' $[$J-1].tonto_cycle.$JOBNAME/$[$J-1].stdout)"  >> $JOBNAME.lst
			echo " $(awk '{a[NR]=$0}/^Reflections pruned/ && !b {b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		fi
		if [[ "$SCFCALCPROG" != "optgaussian" && "$SCFCALCPROG" != "optorca" ]]; then  
		        if [[ "$POWDER_HAR" != "true" && "$SCFCALCPROG" != "Crystal14" ]]; then  
			        GET_RESIDUALS
			        echo " $(awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)" >> $JOBNAME.lst
                        fi
		        if [[ "$XWR" == "true" ]]; then
		        	RUN_XWR
        		fi
		elif [[ "$SCFCALCPROG" == "optgaussian" && "$SCCHARGES" == "true" ]]; then  
			SCF_TO_TONTO
			GET_FREQ
		elif [[ "$SCFCALCPROG" == "optorca" && "$SCCHARGES" == "true" ]]; then  
			SCF_TO_TONTO
			GET_FREQ_ORCA
		fi
		echo " $(awk '{a[NR]=$0}/^Reflections pruned/{b=NR}/^Atom coordinates/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		DURATION=$SECONDS
		echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
		echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
		exit

	# BEGIN LAMAGOET CP2K SINGLE-FILE: dispatch
	elif [[ "$SCFCALCPROG" == "CP2K" ]]; then
		CP2K_RUN_HAR || exit 1
		exit 0
	# END LAMAGOET CP2K SINGLE-FILE: dispatch
	elif [[ "$SCFCALCPROG" == "Tonto" ]]; then

                if [[  "$SCFCALCPROG" == "Tonto" && "$POWDER_HAR" == "true" ]]; then
		        SCF_TO_TONTO
		        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
		        RUN_NOSPHERA2
		        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
                        RUN_JANA
        		while (( $( echo "$JANA_COUNTER < $MAXPHARCYCLE" | bc -l )  )); do
                #               echo "I am here again"
		                SCF_TO_TONTO
		                if [ "$POWDER_HAR" = "true" ]; then
		                        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER in progress"
                		        RUN_NOSPHERA2
	                	        echo "Generation of .tsc file with NoSpherA2 for cycle number $NSA2_COUNTER ended"
                                        RUN_JANA
                                fi
                        done
                else
                        SCF_TO_TONTO
                fi
		echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		APPEND_IAM_RESULTS
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "                                     Final Geometry                                            " >> $JOBNAME.lst
		echo "###############################################################################################" >> $JOBNAME.lst
		echo "" >> $JOBNAME.lst
		# Tonto emits one "Structure refinement results" block per refinement,
		# so a job that starts from a Tonto IAM produces two: the IAM first,
		# then the Hirshfeld atom refinement. Record the FIRST match, not the
		# last, or the IAM block is dropped and the summary shows only the HAR
		# under lamaGOET's own "Begin rigid-atom fit" heading. Comparing the
		# two is the whole point of starting from an IAM.
		echo " $(awk '{a[NR]=$0}/^Structure refinement results/ && !b {b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		if [[ "$XWR" == "true" ]]; then
			RUN_XWR
		fi
		DURATION=$SECONDS
		echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
		echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
		exit
	else
		if [ "$USEGAMESS" = "false" ]; then    
			ELMODB
			SCF_TO_TONTO
			ELMODB
			while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $( echo "$J <= 1" | bc -l )  )); do
			if [[ $J -ge $MAXCYCLE ]];then
				echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
				break
			fi
				SCF_TO_TONTO
				ELMODB
			done
			echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			APPEND_IAM_RESULTS
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Final Geometry                                            " >> $JOBNAME.lst
				echo "###############################################################################################" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo " $(awk '{a[NR]=$0}/^Structure refinement results/ && !b {b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		        if [[ "$POWDER_HAR" != "true" ]]; then  
			        GET_RESIDUALS
			        echo " $(awk '{a[NR]=$0}/^Reflections pruned/{b=NR}/^Atom coordinates/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
			        echo " $(awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)" >> $JOBNAME.lst
                        fi
			if [[ "$XWR" == "true" ]]; then
				RUN_XWR
			fi
			DURATION=$SECONDS
			echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
			echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
			exit
		else 
			GAMESS_ELMODB_OLD_PDB
			SCF_TO_TONTO
			GAMESS_ELMODB_OLD_PDB
			while (( $(echo "$MAXSHIFT > $CONVTOL" | bc -l) || $( echo "$J <= 1" | bc -l )  )); do
	        		if [[ $J -ge $MAXCYCLE ]];then
		        		echo "ERROR: Refinement ended. Too many fit cycles. Check if result is reasonable and/or change your convergency criteira."
		        		break
		        	fi
		        	if [[ "$USENOSPHERA2" == "true" ]]; then
		        		cp $JOBNAME.wfn  $I.$SCFCALCPROG.cycle.$JOBNAME/$I.$JOBNAME.wfn
                                        RUN_JANA
		        	fi
		        	SCF_TO_TONTO
	        		GAMESS_ELMODB_OLD_PDB
			done
			echo "__________________________________________________________________________________________________________________________________________________________________" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			APPEND_IAM_RESULTS
			echo "###############################################################################################" >> $JOBNAME.lst
			echo "                                     Final Geometry                                            " >> $JOBNAME.lst
				echo "###############################################################################################" >> $JOBNAME.lst
			echo "" >> $JOBNAME.lst
			echo " $(awk '{a[NR]=$0}/^Structure refinement results/ && !b {b=NR}/^Wall-clock time taken for job /{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
		        if [[ "$POWDER_HAR" != "true" ]]; then  
			        GET_RESIDUALS
			        echo " $(awk '{a[NR]=$0}/^Reflections pruned/{b=NR}/^Atom coordinates/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)"  >> $JOBNAME.lst
			        echo " $(awk '{a[NR]=$0}/^Residual density data/{b=NR}/^Wall-clock time taken for job/{c=NR}END{for (d=b-2;d<c-1;++d) print a[d]}' stdout)" >> $JOBNAME.lst
                        fi
			if [[ "$XWR" == "true" ]]; then
				RUN_XWR
			fi
			DURATION=$SECONDS
			echo "Job ended, elapsed time:" | tee -a $JOBNAME.lst
			echo "$(($DURATION / 86400 )) days,  $((($DURATION / 3600) % 24 )) hours, $((($DURATION / 60) % 60 ))minutes and $(($DURATION % 60 )) seconds elapsed." | tee -a $JOBNAME.lst
			exit
		fi
	fi
}

# Load saved job options. The Qt interface writes the complete schema, but a
# hand-written or older file may be missing keys, so supply the defaults the
# rest of the script assumes.
LAMAGOET_INITIAL_OPTIONS=${LAMAGOET_BATCH_OPTIONS:-job_options.txt}
if [[ -f "$LAMAGOET_INITIAL_OPTIONS" ]]; then
    source "$LAMAGOET_INITIAL_OPTIONS"
fi
# COMPLETECIF was renamed COMPLETESTRUCT; option files written by the old GUI
# still use the former name.
if [[ -z "${COMPLETESTRUCT:-}" && -n "${COMPLETECIF:-}" ]]; then
    COMPLETESTRUCT=$COMPLETECIF
fi
if [[ -z "${SCFCALCPROG:-}" ]]; then
    SCFCALCPROG="Gaussian"
fi
export SCFCALCPROG
if [[ "$SCFCALCPROG" == "CP2K" && -z "${CP2K_BASIS_SET:-}" ]]; then
    CP2K_BASIS_SET=${CP2K_BASIS:-${BASISSETG:-}}
fi
: "${CP2K_BASIS_SET_FILE:=$HOME/cp2k-master/install/share/cp2k/data/BASIS_AUG_MOLOPT}"
: "${CP2K_BASIS_SET:=aug-SZV-MOLOPT-ae-SR}"
: "${CP2K_XC_FUNCTIONAL:=BLYP}"
: "${METHOD:=rhf}"
: "${BASISSETG:=STO-3G}"
export CP2K_BASIS_SET_FILE CP2K_BASIS_SET CP2K_XC_FUNCTIONAL
# Checking if job_options exists. The Qt interface and the cluster runners
# both use --run-job-options to hand one over directly.
if [[ -n "${LAMAGOET_BATCH_OPTIONS:-}" ]]; then
	if [[ ! -f "$LAMAGOET_BATCH_OPTIONS" ]]; then
		echo "lamaGOET: job options file not found: $LAMAGOET_BATCH_OPTIONS" >&2
		exit 1
	fi
	source "$LAMAGOET_BATCH_OPTIONS"

# Processor counts are used unquoted as `mpirun -n $NUMPROCTONTO`, so an option
# file that predates them expands to `mpirun -n <binary>`: the -n flag consumes
# the executable path and MPI reports "No executable was specified", which says
# nothing about the real cause. Supply the defaults the schema promises.
NUMPROC=${NUMPROC:-1}
NUMPROCTONTO=${NUMPROCTONTO:-1}
	if [[ -z "${EXIT:-}" ]]; then
		EXIT="OK"
	fi
else
if [[ -f job_options.txt  ]]; then
	sed -i '/EXIT/d' job_options.txt
	source ./job_options.txt 
	sed -n -i '/=/p' job_options.txt
	if [[ ! -z "$MANUALRESIDUE" ]]; then 
		if [[ ! -f TAILORED ]]; then
			echo "$MANUALRESIDUE" > TAILORED
		fi
	else 
		echo " 
ALE   0   17  .t.        !Input for the first tailor-made residue 
	
CA        1    1   .f.     N   CA  C     
N         1    1   .f.     CA  N   H1     
C         1    1   .f.     CA  C   O     
O         3    1   .f.     C   O   OXT     
OXT       3    1   .f.     C   OXT O
CB        1    1   .f.     CA  CB  HB1   
CA_HA     1    2   .f.     CA  HA  C    
CA_N      1    2   .f.     CA  N   HA     
N_H1      1    2   .f.     N   H1  CA
N_H2      1    2   .f.     N   H2  CA
N_H3      1    2   .f.     N   H3  CA  
CA_C      1    2   .f.     CA  C   O     
C_O_OXT   4    3   .f.     C   O   OXT      
CA_CB     1    2   .f.     CA  CB  C    
CB_HB1    1    2   .f.     CB  HB1 CA   
CB_HB2    1    2   .f.     CB  HB2 CA   
CB_HB3    1    2   .f.     CB  HB3 CA 
 " > TAILORED
	fi

	if [[ ! -z "$SSBONDATOMS" ]]; then 
		if [[ ! -f DISSBONDS ]]; then
			echo "$SSBONDATOMS" > DISSBONDS
		fi
	else 
		echo " 
   3  40
   4  32
  16  26
 " > DISSBONDS
	fi
	if [[ ! -z $(cat job_options.txt) ]]; then
		export $(cut -d= -f1 job_options.txt | awk 'NF==1' | sed '/"/d')
	fi
	if [[ "$TESTS" != "true" ]]; then
		# There is no built-in terminal GUI any more. A job_options.txt is
		# already present, so run it as-is; edit it with the Qt interface or
		# by hand.
		echo "lamaGOET: using the job_options.txt in $(pwd)"
	else
		if [[ "$SCFCALCPROG" == "elmodb" && "$EXIT" == "OK" ]]; then
			PDB=$( echo $CIF | awk -F "/" '{print $NF}' ) 
		fi
	fi
else
	if [[ ! -f TAILORED ]]; then
		echo " 
ALE   0   17  .t.        !Input for the first tailor-made residue 
	
CA        1    1   .f.     N   CA  C     
N         1    1   .f.     CA  N   H1     
C         1    1   .f.     CA  C   O     
O         3    1   .f.     C   O   OXT     
OXT       3    1   .f.     C   OXT O
CB        1    1   .f.     CA  CB  HB1   
CA_HA     1    2   .f.     CA  HA  C    
CA_N      1    2   .f.     CA  N   HA     
N_H1      1    2   .f.     N   H1  CA
N_H2      1    2   .f.     N   H2  CA
N_H3      1    2   .f.     N   H3  CA  
CA_C      1    2   .f.     CA  C   O     
C_O_OXT   4    3   .f.     C   O   OXT      
CA_CB     1    2   .f.     CA  CB  C    
CB_HB1    1    2   .f.     CB  HB1 CA   
CB_HB2    1    2   .f.     CB  HB2 CA   
CB_HB3    1    2   .f.     CB  HB3 CA 
 " > TAILORED
	fi
	if [[ ! -f DISSBONDS ]]; then
		echo " 
   3  40
   4  32
  16  26
 " > DISSBONDS
	fi
	cat >&2 <<'NO_OPTIONS'

lamaGOET: no job_options.txt in this directory, and nothing to run.

lamaGOET no longer has a built-in terminal interface. Set a job up with the
Qt interface, which writes job_options.txt for you:

    lamaGOET_qt.sh        to run the calculation on this computer
    GUI_lamaGOET_qt.sh    to submit it to a PBS cluster

Then run it from the directory holding job_options.txt:

    lamaGOET

or point at a file directly:

    lamaGOET --run-job-options /path/to/job_options.txt

NO_OPTIONS
	exit 2
fi
fi

source "${LAMAGOET_BATCH_OPTIONS:-./job_options.txt}"
#rm job_options.txt
echo "" > $JOBNAME.lst
if [[ -z "$SCFCALCPROG" ]]; then
	SCFCALCPROG="Gaussian"
	echo "SCFCALCPROG=\"$SCFCALCPROG\"" >> job_options.txt
fi

if [[ "$GAUSGEN" = "true" && ! -f basis_gen.txt ]]; then
    BASISSETG="gen"
    REQUIRE_ZENITY "an external basis set" "basis_gen.txt" || exit 2
    zenity --entry --title="New basis set" --text="Enter or paste the basis set in the gaussian format as: \n !!NO EMPTY LINE!! \n C 0 \n S 5 \n exponent1 coefficient1 \n exponent2 coefficient2 \n exponent3 coefficient3 \n exponent4 coefficient4 \n exponent5 coefficient5 \n **** \n !!NO EMPTY LINE!! \n (Repeat this for all shells and all elements) " > basis_gen.txt
    sed -i '/BASISSETG=/c\BASISSETG=\"'$BASISSETG'"' job_options.txt
fi

# ORCA reads an external BSE/manual definition from the $DATA block appended
# to its input. Do not also place a named built-in basis on the route line.
if [[ "$GAUSGEN" == "true" && ( "$SCFCALCPROG" == "Orca" || "$SCFCALCPROG" == "optorca" ) ]]; then
    BASISSETG=""
fi

if [ "$GAUSSEMPDISP" = "true" ]; then
	GAUSSEMPDISPKEY="EmpiricalDispersion=gd3bj"
fi

if [ "$GAUSSREL" = "true" ]; then
    INT="int=dkh"
    echo "INT=\"$INT\"" >> job_options.txt
fi

if [[ "$DISP" = "yes" && "$EXIT" = "OK" ]]; then
	REQUIRE_ZENITY "the dispersion coefficients" "DISP_inst.txt" || exit 2
	zenity --entry --title="Dispersion coefficients" --text="Enter the dispersion coefficients for each element type followed by f' and f'' values i.e.: \n \n C 0.0031 0.0016 H 0.0 0.0" > DISP_inst.txt
	while [ $? -eq 1 ]; do 
		zenity --entry --title="Dispersion coefficients" --text="Enter the dispersion coefficients for each element type followed by f' and f'' values i.e.: \n \n C 0.0031 0.0016 H 0.0 0.0" > DISP_inst.txt
	done
fi

if [[ "$SCFCALCPROG" == "elmodb" && "$EXIT" == "OK" ]]; then
	if [[ ! -f "$( echo $CIF | awk -F "/" '{print $NF}' )" ]]; then
		cp $CIF .
	fi
	PDB=$( echo $CIF | awk -F "/" '{print $NF}' ) 
	echo "PDB=\"$PDB\"" >> job_options.txt
	if [[ "$INITADP" == "true" ]];then
		INITADPFILE=$( echo $INITADPFILE | awk -F "/" '{print $NF}' ) 
		echo "INITADPFILE=\"$INITADPFILE\"" >> job_options.txt
	fi
	if [[ ! -f "tonto.cell" ]]; then
		#extracting information from pdb file into new jobname.pdb file (only for elmodb)
		# is tehre a cell in the pdb?
		if [[ ! -z $(awk '$1 ~ /CRYST1/ {print $0}'  $PDB) ]]; then
			CELLA=$(awk '$1 ~ /CRYST1/ {print $2}'  $PDB)
			CELLB=$(awk '$1 ~ /CRYST1/ {print $3}'  $PDB)
			CELLC=$(awk '$1 ~ /CRYST1/ {print $4}'  $PDB)
			CELLALPHA=$(awk '$1 ~ /CRYST1/ {print $5}'  $PDB)
			CELLBETA=$(awk '$1 ~ /CRYST1/ {print $6}'  $PDB)
			CELLGAMMA=$(awk '$1 ~ /CRYST1/ {print $7}'  $PDB)
			SPACEGROUP=$(awk '$1 ~ /CRYST1/ {print $0}' $PDB | awk ' {print substr($0,index($0,$8),--NF)}')
	  		echo "      spacegroup= { hermann_mauguin_symbol= '$SPACEGROUP' }" > tonto.cell
			echo "" >> tonto.cell
			echo "      unit_cell= {" >> tonto.cell
			echo "" >> tonto.cell
			echo "         angles=       $CELLALPHA   $CELLBETA   $CELLGAMMA   Degree" >> tonto.cell
			echo "         dimensions=   $CELLA   $CELLB   $CELLC   Angstrom" >> tonto.cell
			echo "" >> tonto.cell
			echo "      }" >> tonto.cell
			echo "" >> tonto.cell
			echo "      REVERT" >> tonto.cell
		else
			SPACEGROUPMENU
			CELLA=$(awk -F'|' '{print $1}'  crystal_data.txt )
			CELLB=$(awk -F'|' '{print $2}'  crystal_data.txt )
			CELLC=$(awk -F'|' '{print $3}'  crystal_data.txt )
			CELLALPHA=$(awk -F'|' '{print $4}'  crystal_data.txt )
			CELLBETA=$(awk -F'|' '{print $5}'  crystal_data.txt )
			CELLGAMMA=$(awk -F'|' '{print $6}'  crystal_data.txt )
			SPACEGROUP=$(cat spacegroup.txt | awk -F'=' '{print $3}' )
			rm spacegroup.txt
			echo "      spacegroup= { hall_symbol= '$SPACEGROUP' }" > tonto.cell
			echo "" >> tonto.cell
			echo "      unit_cell= {" >> tonto.cell
			echo "" >> tonto.cell
			echo "         angles=       $CELLALPHA   $CELLBETA   $CELLGAMMA   Degree" >> tonto.cell
			echo "         dimensions=   $CELLA   $CELLB   $CELLC   Angstrom" >> tonto.cell
			echo "" >> tonto.cell
			echo "      }" >> tonto.cell
			echo "" >> tonto.cell
			echo "      REVERT" >> tonto.cell
		fi
	fi
	# are there more lines in the pdb then the ATOM lines?
	if [[ ! -z $(awk '$1 !~ /ATOM/ && ! /HETATM/ && ! /END/ {print $0}'  $PDB) ]]  ; then
		awk '$1 ~ /ATOM/ {print $0}'  $PDB > $JOBNAME.cut.pdb
		awk '$1 ~ /HETATM/ {print $0}'  $PDB > $JOBNAME.cut.pdb
		sed -i 's/HETATM/ATOM/g' $JOBNAME.cut.pdb
		echo "END" >> $JOBNAME.cut.pdb
		if [[ ! -z $(diff -ZB $PDB $JOBNAME.cut.pdb) ]]; then
			PDB=$JOBNAME.cut.pdb	
		fi
	fi
fi

if [ "$EXIT" = "OK" ]; then
        if [[ "$SCFCALCPROG" == "Crystal14" ]]; then
                if [[ ! -f "spacegroup.txt"  ]]; then
                        SPACEGROUPMENU
                fi
                SPACEGROUP=$(cat spacegroup.txt | awk -F'=' '{print $2}' )
                SETTING=$(echo "$SPACEGROUP" | awk -F':' '{print $2}' | tr -d ' ')
                if [[ "$SETTING" == "r" ]]; then
                        XTALSETTING=1
                else
                        XTALSETTING=0
                fi
        fi
        # The old GUI opened a zenity window that tailed the results file.
        # The file is still written; follow it with `tail -f` if you want to
        # watch the refinement as it goes.
        echo "lamaGOET: results are being written to $(pwd)/$JOBNAME.lst"
	run_script
else
#	clea
	exit 0
fi


#  <hbox>
#   <checkbox active="false" sensitive="true" space-fill="True"  space-expand="True" sensitive="false" >
#	     <label>residual_density_map</label>
#    <variable>RESDENS</variable>		
#    <default>false</default>
#   </checkbox>
#  </hbox>   
