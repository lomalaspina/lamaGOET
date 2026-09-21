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
| `WAVE` | `0.71073` | X-ray wavelength in Å |
| `FCUT` | `3` | F/σ cutoff, applied to observations before merging |
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
| `USEBECKE` | `false` | emit non-default Tonto Becke-grid controls |
| `ACCURACY` | `extreme` | Becke grid: `very_low`, `sg-1`, `low`, `medium`, `high`, `very_high`, `extreme`, `best` |
| `BECKEPRUNINGSCHEME` | `none` | Becke pruning: `none`, `sg1`, or `robust` |
| `LINEDEP` | *(empty)* | explicit Tonto linear-dependence threshold |

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
| `REFHPOS` | `true` | refine hydrogen coordinates |
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
| `DISP` | `no` | Tonto experimental dispersion correction |
| `MINCORCOEF` | *(empty)* | optional minimum correlation coefficient |
| `POWDER_HAR` | `false` | legacy powder-HAR/Jana route |
| `USENOSPHERA2` | `false` | legacy NoSpherA2/Jana form-factor route |
| `NSA2ACC` | `2` | NoSpherA2 accuracy integer |
| `RESDENS` | `false` | retained residual-density workflow flag |

## Extinction

| Variable | Default | Meaning |
|---|---|---|
| `EXTI` | `no` | refine extinction (`yes`/`no`) |
| `EXTINCTION_MODEL` | `zachariasen` | `zachariasen` or `becker-coppens` |
| `EXTINCTION_TYPE` | `type-1` | Becker-Coppens `type-1`, `type-2`, or `mixed` |
| `EXTINCTION_DISTRIBUTION` | `gaussian` | Gaussian or Lorentzian mosaic distribution |
| `EXTINCTION_ANISOTROPIC` | `false` | isotropic when false; anisotropic when true |
| `EXTINCTION_MEAN_PATH_MM` | `0.3` | absorption-weighted mean path length in mm |

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

## Completeness guarantee

The automated `test_documented_options.py` compares every key in the canonical
schema with this page. Adding a runner/GUI variable without documenting it
fails the normal test suite. Descriptions still require scientific review; the
test guarantees presence, not correctness.
