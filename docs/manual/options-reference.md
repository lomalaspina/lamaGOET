# `job_options.txt` reference

`job_options.txt` is the formal contract between the Qt interface and the two
shell runners. It is a quoted shell-assignment file, not a Tonto input file.
The GUI writes every canonical variable on every save because an unset shell
variable is not equivalent to the literal `false` expected by many legacy
branches.

The defaults below are the safe compatibility defaults in
`lamagoet_qt/options_schema.py`. A default is not a scientific recommendation
for every system. Values saved by the GUI override them.

## Job, data, and dispatch

| Variable | Default | Meaning |
|---|---|---|
| `SCFCALCPROG` | `Gaussian` | workflow/program dispatch identifier |
| `SCFCALC_BIN` | `g09` | derived executable for the active external program; compatibility key |
| `JOBNAME` | `my_job` | base name for generated files and directories |
| `CIF` | *(empty)* | input CIF or PDB path |
| `HKL` | *(empty)* | reflection-data path |
| `EXIT` | `OK` | GUI action/status compatibility flag |
| `EMAIL` | *(empty)* | PBS notification address; cluster mode only |
| `CHARGE` | `0` | molecular/cell charge as routed by the selected program |
| `MULTIPLICITY` | `1` | spin multiplicity |
| `WAVE` | `0.71073` | X-ray wavelength in Å; opening a CIF in the GUI adopts its `_diffrn_radiation_wavelength`, while reopening saved options preserves their explicit value |
| `FCUT` | `3` | significance cutoff applied before merging: $F/u(F)$ for an $F$ target, or $I/u(I)$ for an $F^2$ target with inverse-sigma weighting; ignored for SHELXL WGHT fits, whose `gt` subset is reported at $I>2u(I)$ |
| `MERGCODE` | `2` | reflection merge rule 0–4 |
| `WRITEHEADER` | `false` | write Tonto reflection-file header |
| `ONF` | `false` | declare observations on F when header is written |
| `ONF2` | `false` | declare observations on F² when header is written |
| `USEEQUIV` | `false` | retained legacy compatibility flag; current runners use `MERGCODE` |
| `COMPLETESTRUCT` | `false` | use Tonto defragment/molecule completion |
| `INITADP` | `false` | load ELMO initial precise coordinates/ADPs |
| `INITADPFILE` | *(empty)* | CIF supplying ELMO initial coordinates/ADPs |

## Resources and convergence

| Variable | Default | Meaning |
|---|---|---|
| `NUMPROC` | `1` | external-program processors; Crystal parallel dispatch uses >1 |
| `NUMPROCTONTO` | `1` | Tonto processors |
| `MEM` | `1gb` | external SCF memory request |
| `MEMPBS` | `1gb` | PBS memory request per processor |
| `CONVTOL` | `0.01` | maximum structural shift/s.u. convergence threshold |
| `CONVTOLE` | `0.00001` | energy/outer-cycle convergence threshold where used |
| `MAXCYCLE` | `50` | maximum HAR/SCCC outer cycles |
| `MAXLSCYCLE` | `30` | Tonto least-squares cycles; observed dynamic path reuses as outer phase cap |
| `MAXPHARCYCLE` | `10` | maximum powder-HAR cycles |
| `MAXXTALCYCLE` | *(empty)* | optional maximum Crystal23 SCF cycles |
| `HAR_ENERGY_REPEAT_TOL` | `1.0E-10` | energy tolerance for stationary/repeating wavefunction detection |
| `HAR_SCF_RMSD_TOL` | `1.0E-8` | SCF-density RMS tolerance for stationary/repeating detection |

## Methods, basis sets, and integration

| Variable | Default | Meaning |
|---|---|---|
| `METHOD` | `rhf` | selected HAR/external electronic method |
| `BASISSETG` | `STO-3G` | Gaussian/ORCA/OCC/Crystal/ELMO basis selection |
| `BASISSETT` | `STO-3G` | Tonto HAR basis selection |
| `BASISSETDIR` | `/usr/local/bin/basis_sets` | Tonto/ELMO basis directory |
| `GAUSGEN` | `false` | enable external/custom `basis_gen.txt` |
| `EXTRAKEY` | *(empty)* | literal extra Gaussian route keywords |
| `GAUSSEMPDISP` | `false` | Gaussian GD3BJ empirical dispersion request |
| `GAUSSREL` | `false` | supported Gaussian relativistic route |
| `DKH_BASIS_CONFIRMED` | `false` | explicit confirmation that a manually supplied Gaussian basis is all-electron and DKH-optimized; automatically set for compatible Basis Set Exchange choices |
| `USEBECKE` | `false` | emit non-default Tonto Becke-grid controls |
| `ACCURACY` | `extreme` | Becke grid: `very_low`, `sg-1`, `low`, `medium`, `high`, `very_high`, `extreme`, `best` |
| `BECKEPRUNINGSCHEME` | `none` | Becke pruning: `none`, `sg1`, or `robust` |
| `LINEDEP` | *(empty)* | explicit Tonto linear-dependence threshold |

Basis names and element metadata are obtained from the [Basis Set
Exchange](https://www.basissetexchange.org/) ([Pritchard *et al.*,
2019](https://doi.org/10.1021/acs.jcim.9b00725)); conversion to each consumer's
syntax is a lamaGOET operation. The grid controls refer to Becke's multicentre
integration scheme ([Becke, 1988](https://doi.org/10.1063/1.454033)). The
Douglas--Kroll--Hess safeguard reflects the original scalar-relativistic
formulation ([Douglas and Kroll,
1974](https://doi.org/10.1016/0003-4916(74)90333-9); [Hess,
1986](https://doi.org/10.1103/PhysRevA.33.3742)).

## Executables and installation paths

| Variable | Default | Meaning |
|---|---|---|
| `TONTO` | `tonto` | Tonto executable |
| `GAUSSIAN_BIN` | `g09` | Gaussian executable |
| `ORCA_BIN` | `orca` | ORCA executable |
| `OCC_BIN` | `occ` | OCC executable |
| `CRYSTAL_BIN` | `runcry23` | Crystal23 serial driver |
| `CRYSTAL_PARALLEL_BIN` | *(empty)* | optional site-specific Crystal23 parallel driver |
| `CP2K_BIN` | `cp2k.ssmp` | CP2K executable |
| `ELMODB_BIN` | `elmodb` | ELMOdb executable |
| `ELMOLIB` | `/usr/local/bin/LIBRARIES` | ELMO library directory |
| `GAMESS` | `gamess_int` | GAMESS-US interface executable |
| `JANAEXE` | `jana2006` | Jana executable for legacy powder/NoSpherA2 path |
| `TONTO_BASIS_DIR` | *(empty)* | CP2K/Tonto Slater-basis support directory |

## General Tonto refinement

| Variable | Default | Meaning |
|---|---|---|
| `POSADP` | `true` | refine positions and ADPs |
| `POSONLY` | `false` | refine positions only |
| `ADPSONLY` | `false` | refine ADPs only |
| `IAMTONTO` | `false` | perform an initial Tonto IAM fit |
| `ONLYIAMTONTO` | `false` | stop after Tonto IAM |
| `REFNOTHING` | `false` | fix listed atom labels |
| `ATOMLIST` | *(empty)* | labels fixed by `REFNOTHING` |
| `REFUISO` | `false` | refine listed atoms isotropically |
| `ATOMUISOLIST` | *(empty)* | labels receiving isotropic treatment |
| `H_POSITION_MODEL` | `refine` | hydrogen-coordinate treatment: `refine`, `fixed`, or `riding` |
| `REFHPOS` | `true` | legacy mirror (`true` only for `H_POSITION_MODEL=refine`) |
| `REFHADP` | `true` | refine hydrogen displacement parameters |
| `HADP` | `no` | isotropic hydrogen ADP request (`yes`/`no`) |
| `REFANHARM` | `false` | enable anharmonic displacement refinement |
| `ANHARMATOMS` | *(empty)* | atom labels for anharmonic refinement |
| `THIRDORD` | `false` | include third-order anharmonic terms |
| `FOURTHORD` | `false` | include fourth-order anharmonic terms |
| `XHALONG` | `false` | alter starting X-H distances |
| `BHBOND` | `1.190` | starting B-H distance in Å |
| `CHBOND` | `1.083` | starting C-H distance in Å |
| `NHBOND` | `1.009` | starting N-H distance in Å |
| `OHBOND` | `0.983` | starting O-H distance in Å |
| `DISP` | `no` | enable wavelength-dependent anomalous-scattering coefficients |
| `DISPERSION_SOURCE` | `fprime` | GUI calculation source: `fprime` or `brennan` |
| `DISPERSION_MANUAL_OVERRIDES` | `{}` | JSON mapping of checked element overrides to $[f',f'']$ |
| `DISPERSION_COEFFICIENTS` | *(empty)* | resolved flat `element f' f''` list consumed by Tonto |
| `MINCORCOEF` | *(empty)* | optional minimum correlation coefficient |
| `POWDER_HAR` | `false` | legacy powder-HAR/Jana route |
| `USENOSPHERA2` | `false` | legacy NoSpherA2/Jana form-factor route |
| `NSA2ACC` | `2` | NoSpherA2 accuracy integer |
| `RESDENS` | `false` | retained residual-density workflow flag |

`H_POSITION_MODEL=riding` makes each H coordinate follow the coordinate shift
of its single bonded non-hydrogen parent. It does not constrain the X-H
distance separately and it does not change the independently selected H-ADP
treatment. A missing or ambiguous non-hydrogen parent is reported by Tonto
rather than guessed. Older files containing only `REFHPOS=false` are migrated
to `fixed`; an explicit `H_POSITION_MODEL` always takes precedence. Dynamic
observed-density refinement fixes coordinates and therefore forces `fixed`.

The riding option is a deliberately limited parent-shift model, not the full
SHELXL `AFIX`/`HFIX` system in the [official instruction
reference](https://shelx.uni-goettingen.de/shelxl_html.php). Gram--Charlier
orders follow crystallographic ADP conventions ([Johnson,
1969](https://doi.org/10.1107/S0567739469000325); [Trueblood *et al.*,
1996](https://doi.org/10.1107/S0108767396005697)), while `DISP` uses the CIF
$f'$/$f''$ anomalous-scattering quantities defined by the [IUCr CIF Core
dictionary](https://www.iucr.org/resources/cif/dictionaries/cif_core).
NoSpherA2 should be cited to [Kleemiss *et al.*
(2021)](https://doi.org/10.1039/D0SC05526C), and the legacy powder path also
requires the external [JANA system](https://jana.fzu.cz/).

## Extinction

| Variable | Default | Meaning |
|---|---|---|
| `EXTI` | `no` | refine extinction (`yes`/`no`) |
| `EXTINCTION_MODEL` | `zachariasen` | `zachariasen` or `becker-coppens` |
| `EXTINCTION_TYPE` | `type-1` | Becker-Coppens `type-1`, `type-2`, or `mixed` |
| `EXTINCTION_DISTRIBUTION` | `gaussian` | Gaussian or Lorentzian mosaic distribution |
| `EXTINCTION_ANISOTROPIC` | `false` | isotropic when false; anisotropic when true |
| `EXTINCTION_MEAN_PATH_MM` | `0.3` | absorption-weighted mean path length in mm |

The model names and required CIF description follow the [IUCr CIF Core
extinction definition](https://www.iucr.org/__data/iucr/cifdic_html/3/CORE_DIC/Irefine_ls.extinction_method.html).
Primary Zachariasen--Larson and Becker--Coppens references are listed in
{doc}`references`.

## Post-refinement absolute structure

| Variable | Default | Meaning |
|---|---|---|
| `CALCULATE_FLACK_PARAMETER` | `false` | calculate the post-refinement Parsons intensity-quotient estimate of Flack $x$ from paired Friedel observations |

The runners omit the Tonto keyword when this option is false, preserving the
established calculation.  When true, they write
`calculate_flack_parameter= true` in each supported Tonto `xray_data` block.
The GUI requires `MERGCODE=2` and `DISP=yes`; the structure must also be
acentric and noncentrosymmetric, and the input must retain unmerged Friedel
opposites.  This option does not select a refinement target or weighting
scheme, and it does not add an inversion-twin fraction to the least-squares
matrix.  The estimator and data-selection rules follow [Parsons, Flack and
Wagner (2013)](https://doi.org/10.1107/S2052519213010014); see
{doc}`principles` for the equations and {doc}`limitations` for interpretation.

## Least-squares weighting

| Variable | Default | Meaning |
|---|---|---|
| `TONTO_REFINEMENT_TARGET` | `f` | least-squares observations: `f` for amplitudes (established Tonto default) or `f2` for intensities |
| `TONTO_WEIGHTING_SCHEME` | `sigma` | weighting law, independent of the target: `sigma` preserves Tonto's established inverse-sigma weighting and supports either target; `shelxl` selects the independent WGHT implementation and requires `f2` |
| `SHELXL_WEIGHT_A` | `0.1` | SHELXL `WGHT` coefficient A; ignored unless the selected scheme is `shelxl` |
| `SHELXL_WEIGHT_B` | `0.0` | SHELXL `WGHT` coefficient B; ignored unless the selected scheme is `shelxl` |
| `SHELXL_WEIGHT_C` | `0.0` | SHELXL `WGHT` coefficient C; ignored unless the selected scheme is `shelxl` |
| `SHELXL_WEIGHT_D` | `0.0` | SHELXL `WGHT` coefficient D; ignored unless the selected scheme is `shelxl` |
| `SHELXL_WEIGHT_E` | `0.0` | SHELXL `WGHT` coefficient E; ignored unless the selected scheme is `shelxl` |
| `SHELXL_WEIGHT_F` | `0.3333333333333333` | SHELXL `WGHT` observed-intensity fraction F; ignored unless the selected scheme is `shelxl` |

The GUI stores all six coefficients so a published or archived SHELXL
refinement can be reproduced without silently discarding the less commonly
used C--F terms. Selecting SHELXL automatically selects and locks the
$F^2$ target. With `sigma`, either target remains available. The default
combination (`f` plus `sigma`) emits no new Tonto keywords and therefore does
not change existing lamaGOET calculations.

`MERG` and `WGHT` syntax and the SHELXL intensity-weighting convention are
defined in the [official SHELXL instruction
reference](https://shelx.uni-goettingen.de/shelxl_html.php). lamaGOET exposes
them as optional compatibility choices; the established Tonto objective
remains the default.

After an $F^2$/SHELXL fit, Tonto prints a **SHELXL-style WGHT recommendation**
for the next fit.  It orders reflections by $F_c^2$ and searches the A--B
plane for flatter goodness-of-fit values across ten intensity bins, while
holding C--F fixed.  The recommendation is informational: Tonto does not
replace the active weights after convergence, because doing so would make the
reported statistics and parameter uncertainties refer to a different
objective from the one actually minimized.  Apply the suggested A and B in a
subsequent calculation only after inspecting the model and data quality.

## Nonlinear least-squares solver

| Variable | Default | Meaning |
|---|---|---|
| `TONTO_LEAST_SQUARES_SOLVER` | `gauss-newton` | `gauss-newton`, `shelxl-damped`, or `levenberg-marquardt`; all minimize the same selected weighted objective |
| `SHELXL_DAMP` | `0.7` | nonnegative SHELXL-style diagonal damping coefficient $d$; the multiplier is $1+d/1000$ |
| `SHELXL_LIMSE` | `15` | nonnegative ceiling on the largest structural shift/esd for a fixed-damping step; zero computes uncertainties without applying a shift |
| `LM_INITIAL_LAMBDA` | `1.0E-3` | positive initial Levenberg--Marquardt trust/damping parameter |
| `LM_LAMBDA_UP` | `10` | factor greater than one applied after a rejected LM trial |
| `LM_LAMBDA_DOWN` | `0.1` | factor strictly between zero and one applied after an accepted LM trial |
| `LM_MAX_TRIALS` | `8` | maximum trial steps attempted from one accepted model before stopping safely; effective minimum 20 for lamaGOET anharmonic jobs |

The Gauss--Newton default is intentionally omitted from generated Tonto input
for harmonic jobs, so an unchanged lamaGOET job remains usable with a Tonto
executable that predates selectable solvers.  For a third- or fourth-order
anharmonic job, lamaGOET promotes this default to adaptive LM and raises
`LM_MAX_TRIALS` and `MAXLSCYCLE` to at least 20 and 200, respectively.  An
explicit fixed-damping choice is preserved. Fixed-damping and LM controls are
written only for their respective modes. Solver selection is independent of
`TONTO_REFINEMENT_TARGET` and `TONTO_WEIGHTING_SCHEME`.

The fixed diagonal multiplier follows SHELXL `DAMP` as documented in the
[official instruction
reference](https://shelx.uni-goettingen.de/shelxl_html.php). The adaptive mode
implements the algorithms introduced by [Levenberg
(1944)](https://doi.org/10.1090/qam/10666) and [Marquardt
(1963)](https://doi.org/10.1137/0111030).

## Molecular environment

| Variable | Default | Meaning |
|---|---|---|
| `SCCHARGES` | `false` | use self-consistent cluster charges |
| `SCCRADIUS` | `8` | cluster-charge radius in Å |
| `DEFRAG` | `false` | complete cluster-charge molecules |
| `SCDIPOLES` | `false` | include supported cluster dipoles |
| `ADDNUCINTER` | `false` | ORCA nuclear interaction with environment |
| `EXPLICITMOL` | `false` | use explicit quantum cluster molecules |
| `EXPLRADIUS` | `3` | explicit-cluster radius in Å |
| `DEFRAGEXPL` | `false` | complete explicit-cluster molecules |

## Crystal23

| Variable | Default | Meaning |
|---|---|---|
| `CRYSTAL_SETTING` | `auto` | automatic, hexagonal (`h`), or rhombohedral (`r`) axes |
| `USEHMSYM` | `false` | use Hermann-Mauguin symbol route |
| `DEFRAGNETW` | `false` | network-compound outputs/geometry path |
| `USEGUESS` | `false` | reuse previous-cycle Crystal guess |
| `SHRINKA` | `2` | Crystal reciprocal shrinking factor A |
| `SHRINKB` | `2` | Crystal reciprocal shrinking factor B |
| `CRYSTAL_TOLINTEG` | `auto` | `auto`, `default`, or five Crystal TOLINTEG integers |
| `CRYSTAL_LDREMO` | *(empty)* | expert overlap-eigenvector removal integer |
| `BIPOSIZE` | *(empty)* | optional Crystal Coulomb bipolar-buffer size |
| `ILASIZE` | *(empty)* | optional Crystal ILA dimension |
| `SUPERCON` | `false` | enable supported Crystal SUPERCON path |
| `LAMAGOET_CRYSTAL_DENSITY_INTERFACE` | `gred` | native `gred` or legacy `xml` density interface |
| `CRYSTAL_TONTO_BASIS_NAME` | *(empty)* | exact matching Tonto basis for legacy XML + Crystal `GEN` |

## CP2K periodic HAR

| Variable | Default | Meaning |
|---|---|---|
| `CP2K_DENSITY_INTERFACE` | `native` | native MOKP+CSR or legacy XML route |
| `CP2K_BASIS_SET_FILE` | *(empty)* | CP2K all-electron basis-file path |
| `CP2K_BASIS_SET` | `aug-SZV-MOLOPT-ae-SR` | selected CP2K basis name |
| `CP2K_BASIS_MAP` | *(empty)* | optional per-element CP2K basis mapping |
| `CP2K_TONTO_SLATER_BASIS_FILE` | *(empty)* | explicit matching Tonto Slater-basis support file |
| `CP2K_XC_FUNCTIONAL` | `BLYP` | supported CP2K XC functional |
| `CP2K_KPOINT_GRID` | `2 2 2` | three k-mesh dimensions |
| `CP2K_CELL_CHARGE` | `0` | CP2K periodic-cell charge |
| `CP2K_CELL_MULTIPLICITY` | `1` | CP2K periodic-cell multiplicity |
| `CP2K_CUTOFF` | `1200` | primary GAPW grid cutoff |
| `CP2K_REL_CUTOFF` | `80` | GAPW relative cutoff |
| `CP2K_EPS_SCF` | `1.0E-8` | SCF convergence threshold |
| `CP2K_EPS_DEFAULT` | `1.0E-12` | CP2K numerical default threshold used by generated input |
| `CP2K_MAX_SCF` | `100` | maximum CP2K SCF cycles |
| `CP2K_ADDED_MOS` | `20` | number of added virtual MOs; `-1` requests all available |
| `CP2K_MPI_RANKS` | *(empty)* | optional explicit MPI rank count |
| `CP2K_NUM_THREADS` | *(empty)* | optional explicit thread count per rank |
| `CP2K_RUN_COMMAND` | *(empty)* | expert site-specific CP2K command template |
| `CP2K_TERMINAL_VERBOSE` | `true` | compatibility control for CP2K terminal detail |

## Partition and observed density

| Variable | Default | Meaning |
|---|---|---|
| `PARTITION_MODEL` | `oc-hirshfeld` | standard Tonto density or experimental `oc-observed` |
| `STOCKHOLDER_MODEL` | `cluster` | finite `cluster`, neutral-proatom `periodic`, or experimental charge-iterated `periodic-hi`; the last is restricted to imported Crystal23/CP2K periodic densities |
| `HIRSHFELD_I_MAX_ITERATIONS` | `50` | maximum inner charge/population iterations for `periodic-hi` |
| `HIRSHFELD_I_CHARGE_TOLERANCE` | `5.0E-4` | largest allowed independent-atom fixed-point charge residual in e; this follows the convergence criterion used by Vanpoucke *et al.* |
| `HIRSHFELD_I_MIXING` | `0.5` | linear charge-update mixing; range (0,1] |
| `OBSERVED_DENSITY_RECONSTRUCTION` | `constrained` | constrained positive prior or `legacy` deconvolution |
| `OBSERVED_DENSITY_MOTION_MODEL` | `static` | `static` intrinsic density + ADPs or `dynamic` averaged shapes |
| `OBSERVED_DENSITY_R_FREE_PERCENTAGE` | `10` | deterministic held-out percentage |
| `OBSERVED_DENSITY_PRIOR_STRENGTH` | `0.0` | explicit IAM-prior penalty |
| `OBSERVED_DENSITY_SMOOTHNESS` | `0.01` | reciprocal-space damping β in bohr² |
| `OBSERVED_DENSITY_STEP_SIZE` | `0.25` | initial projected reconstruction step |
| `OBSERVED_DENSITY_MAX_ITERATIONS` | `12` | reconstruction iterations per outer cycle |
| `OBSERVED_DENSITY_SHRINKAGE` | `0.5` | accepted residual-density fraction |
| `OBSERVED_DENSITY_MIN_TF` | `0.1` | minimum thermal factor for applicable conversion |
| `OBSERVED_ZERO_PHASE_SIGN` | `0` | sign hypothesis for exactly zero model coefficient: -1, 0, or +1 |
| `OUTPUT_HIRSHFELD_ATOM_CUBES` | `false` | write atomic-density cubes after partition |
| `HIRSHFELD_ATOM_CUBE_LABEL` | *(empty)* | exact atom label; blank means all independent atoms |
| `OUTPUT_ANHARMONIC_PDF_CUBES` | `false` | write signed per-atom Gram--Charlier probability-density cubes at the final model |
| `ANHARMONIC_PDF_CUBE_ATOMS` | *(empty)* | exact checkbox-selected asymmetric-unit atom labels separated by spaces; blank means automatic selection of all atoms carrying a requested-order coefficient |
| `ANHARMONIC_PDF_CUBE_SECOND_ORDER` | `true` | include the normalized harmonic second-order term $P_0$ |
| `ANHARMONIC_PDF_CUBE_THIRD_ORDER` | `true` | include the signed third-order Gram--Charlier correction |
| `ANHARMONIC_PDF_CUBE_FOURTH_ORDER` | `true` | include the signed fourth-order Gram--Charlier correction |
| `ANHARMONIC_PDF_CUBE_CONTOUR_PROBABILITY` | `50` | harmonic-reference enclosed probability (1--99%) used to report equal-magnitude positive and negative contour levels; cube values are unchanged |
| `ANHARMONIC_PDF_CUBE_AUTOSIZE` | `true` | enlarge each box until its boundary satisfies the cutoff |
| `ANHARMONIC_PDF_CUBE_BOUNDARY_CUTOFF` | `0.001` | maximum absolute boundary probability density in Å$^{-3}$ |
| `ANHARMONIC_PDF_CUBE_SEPARATION` | `0.1` | requested Cartesian point spacing in Å |
| `ANHARMONIC_PDF_CUBE_WIDTH_X` | `4.0` | initial/manual x width in Å |
| `ANHARMONIC_PDF_CUBE_WIDTH_Y` | `4.0` | initial/manual y width in Å |
| `ANHARMONIC_PDF_CUBE_WIDTH_Z` | `4.0` | initial/manual z width in Å |
| `ANHARMONIC_PDF_CUBE_INCLUDE_NEIGHBOURS` | `true` | include unit-cell and adjacent-image atoms in the cube header |

## Molecular XCW and XWR

| Variable | Default | Meaning |
|---|---|---|
| `XCWONLY` | `false` | run XCW at the input geometry without HAR |
| `XWR` | `false` | run HAR followed by XCW |
| `XCW_MODE` | `molecular` | `molecular` or experimental `periodic` XCW |
| `METHODXCW` | `rhf` | Tonto method for molecular XCW |
| `BASISSETTXCW` | `STO-3G` | Tonto basis for molecular XCW |
| `BASISSETDIRXCW` | `/usr/local/bin/basis_sets` | molecular-XCW basis directory |
| `SCCHARGESXCW` | `false` | use molecular-XCW cluster charges |
| `SCCRADIUSXCW` | `8` | molecular-XCW cluster-charge radius in Å |
| `DEFRAGXCW` | `false` | complete molecular-XCW environment molecules |
| `LAMBDAINITIAL` | `0` | first X-ray restraint multiplier |
| `LAMBDASTEP` | `0.1` | lambda increment |
| `LAMBDAMAX` | `1` | requested final lambda |

## Periodic XCW

| Variable | Default | Meaning |
|---|---|---|
| `PERIODIC_XCW_REFERENCE_DFT` | `BLYP` | restricted native Crystal23 reference functional |
| `PERIODIC_XCW_REFERENCE_BASIS` | `POB-TZVP-REV2` | common Crystal23/Tonto reference basis |
| `PERIODIC_XCW_CRYSTAL_BASIS_FILE` | *(empty)* | optional custom Crystal23 basis block |
| `PERIODIC_XCW_TONTO_BASIS_FILE` | *(empty)* | exact matching Tonto basis sidecar |
| `PERIODIC_XCW_TONTO_BASIS_NAME` | *(empty)* | file-safe name assigned to the staged sidecar |
| `PERIODIC_XCW_GRID` | `24 24 24` | periodic KS real-space grid dimensions |
| `PERIODIC_XCW_DENSITY_RADIUS` | `1` | direct-density lattice radius |
| `PERIODIC_XCW_CONVERGENCE` | `1.0E-6` | objective/projector convergence tolerance |
| `PERIODIC_XCW_DAMPING` | `0.5` | old-iterate fraction |
| `PERIODIC_XCW_MAX_ITERATIONS` | `20` | iteration cap at each lambda |
| `PERIODIC_XCW_R_FREE_PERCENTAGE` | `10` | deterministic held-out fraction |
| `PERIODIC_XCW_RESTART` | `false` | restart from this job's compatible checkpoint |
| `PERIODIC_XCW_WRITE_CHECKPOINT` | `true` | write accepted checkpoint each iteration |

## Periodic and finite wavefunction export

| Variable | Default | Meaning |
|---|---|---|
| `PERIODIC_WAVEFUNCTION_EXPORT` | `false` | export supported Crystal23/CP2K periodic state to TREXIO |
| `FINITE_WAVEFUNCTION_EXPORT` | `false` | perform separate buffered finite Tonto calculation |
| `FINITE_WAVEFUNCTION_BASIS_DIR` | `/usr/local/bin/basis_sets` | finite-cluster Tonto basis directory |
| `FINITE_WAVEFUNCTION_BASIS_NAME` | `pob-TZVP-rev2` | finite-cluster all-electron basis |
| `FINITE_WAVEFUNCTION_CENTER_ATOM` | `1` | one-based active-region centre atom |
| `FINITE_WAVEFUNCTION_ACTIVE_RADIUS` | `2.0` | active-region radius in Å |
| `FINITE_WAVEFUNCTION_BUFFER_RADII` | `4.0,6.0` | comma-separated buffer sensitivity radii in Å |
| `FINITE_WAVEFUNCTION_CAP_BOUNDARIES` | `true` | H-cap severed network bonds where supported |
| `FINITE_WAVEFUNCTION_PREPARE_ONLY` | `false` | prepare/validate inputs without running finite SCF |

The periodic export follows the [TREXIO
specification](https://trex-coe.github.io/trexio/) and format paper
([Posenitskiy *et al.*, 2023](https://doi.org/10.1063/5.0148161)); the finite
exports are separate approximations.

## ELMOdb

| Variable | Default | Meaning |
|---|---|---|
| `USEGAMESS` | `false` | use GAMESS-US overlap/integral route through ELMOdb |
| `NSSBOND` | `0` | number of disulfide bonds |
| `SSBONDATOMS` | *(empty)* | explicit disulfide atom-number pairs |
| `NTAIL` | `0` | number of tailor-made residues |
| `ATAIL` | `100` | maximum tail atoms |
| `FRTAIL` | `200` | maximum tail fragments |
| `MANUALRESIDUE` | *(empty)* | literal tailor-made residue definition |

## Plot controls

| Variable | Default | Meaning |
|---|---|---|
| `PLOT_TONTO` | `false` | activate legacy Tonto plot path |
| `SHELXL_RESIDUAL_MAP` | `false` | also write an independent comparison using the nominal published SHELXL FMAP 2 coefficient |
| `DEFDEN` | `false` | deformation-density map |
| `DFTXCPOT` | `false` | DFT XC-potential map |
| `DENS` | `false` | electron-density map |
| `LAPL` | `false` | Laplacian map |
| `NEGLAPL` | `false` | negative-Laplacian map |
| `PROMOL` | `false` | promolecule-density map |
| `PLOT_ANGS` | `false` | interpret plot dimensions in Å |
| `USESEPARATION` | `false` | use explicit grid spacing |
| `SEPARATION` | *(empty)* | requested grid separation |
| `USEALLPOINTS` | `false` | retain all generated grid points |
| `PTSX` | `10` | X grid-point count |
| `PTSY` | `10` | Y grid-point count |
| `PTSZ` | `10` | Z grid-point count |
| `USECENTER` | `false` | centre plot on an atom |
| `CENTERATOM` | `1` | one-based plot-centre atom |
| `XAXIS` | `1 2` | ordered atom pair defining X direction |
| `YAXIS` | `1 3` | ordered atom pair defining Y direction |
| `WIDTHX` | `10` | X extent |
| `WIDTHY` | `10` | Y extent |
| `WIDTHZ` | `10` | Z extent |

`SHELXL_RESIDUAL_MAP` implements only the nominal `FMAP 2` coefficient stated
in the [official SHELXL instruction
reference](https://shelx.uni-goettingen.de/shelxl_html.php); see {doc}`plots`
for the equation and explicit limitations.

## Completeness guarantee

The automated `test_documented_options.py` compares every key in the canonical
schema with this page. Adding a runner/GUI variable without documenting it
fails the normal test suite. Descriptions still require scientific review; the
test guarantees presence, not correctness.
