# lamaGOET periodic CP2K backend example.
# Source or copy these values into the job configuration used by the periodic branch.

SCFCALCPROG="CP2K"
SCFCALC_BIN="/path/to/cp2k.psmp"

# The bridge, CIF converter and template are found automatically beside
# RUN_lamaGOET_release.sh. Override these only when testing other copies.
# CP2K_TONTO_BRIDGE="/other/path/cp2k_tonto_bridge.py"
# CP2K_CIF_TO_SUBSYS="/other/path/cif_to_cp2k.py"
# CP2K_TEMPLATE="/other/path/cp2k_periodic_har.inp.template"

# Use a real all-electron CP2K orbital-basis file and matching labels.
CP2K_BASIS_SET_FILE="/path/to/ALL_ELECTRON_BASIS_SETS"
CP2K_BASIS_SET="YOUR-ALL-ELECTRON-BASIS"
# CP2K_BASIS_MAP="H=H-ALL-ELECTRON C=C-ALL-ELECTRON N=N-ALL-ELECTRON O=O-ALL-ELECTRON"

# These are properties of the complete periodic cell, not lamaGOET's molecular cluster.
CP2K_CELL_CHARGE="0"
CP2K_CELL_MULTIPLICITY="1"

# Stock template: semilocal DFT only.
CP2K_XC_FUNCTIONAL="BLYP"
CP2K_KPOINT_GRID="2 2 2"
CP2K_CUTOFF="1200"
CP2K_REL_CUTOFF="80"
CP2K_EPS_DEFAULT="1.0E-12"
CP2K_EPS_SCF="1.0E-8"
CP2K_MAX_SCF="100"
CP2K_ADDED_MOS="20"

# Optional scheduler/launcher override. CP2K_INPUT, CP2K_OUTPUT and
# CP2K_EXECUTABLE are exported inside the cycle directory.
# CP2K_RUN_COMMAND='srun -n "$NUMPROC" "$CP2K_EXECUTABLE" -i "$CP2K_INPUT" -o "$CP2K_OUTPUT"'

# Required lamaGOET mode restrictions for this prototype:
POWDER_HAR="false"
SCCHARGES="false"
COMPLETESTRUCT="false"
EXPLICITMOL="false"
DEFRAGNETW="false"
XCWONLY="false"
PLOT_TONTO="false"
XWR="false"
