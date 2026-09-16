# Graphical interface reference

The Qt interface is an input editor and monitor. It does not calculate a
wavefunction or fit a structure itself. Every save writes a complete
`job_options.txt`, including explicit defaults for controls hidden by the
selected program. Hidden does not mean omitted.

## HAR tab: job and input

| Interface entry | `job_options.txt` key | Meaning / visibility |
|---|---|---|
| Job name | `JOBNAME` | one-word base name for inputs, outputs, cycle directories, and `.lst` |
| SCF program | `SCFCALCPROG` | selects Tonto, Gaussian, ORCA, OCC, ELMOdb, CP2K, Crystal23, or SCCC optimization route |
| CIF or PDB | `CIF` | starting structure; CIF is required for crystallographic symmetry/cell workflows |
| Complete molecule(s) in CIF with Tonto | `COMPLETESTRUCT` | use Tonto `defragment` during the run; distinct from manual viewer growth |
| Load precise ADPs and coordinates from a CIF | `INITADP`, `INITADPFILE` | ELMOdb-only initial-parameter source |
| Reflection file | `HKL` | hidden for Gaussian/ORCA SCCC optimizations |
| Write header | `WRITEHEADER` | write Tonto reflection metadata |
| on F / on F² | `ONF`, `ONF2` | declared observation type when header writing is enabled |
| MERG code | `MERGCODE` | SHELXL-compatible merging rule 0–4; live explanation appears below the selector |
| Method | `METHOD` | editable program-specific electronic method; hidden for CP2K, which has a dedicated functional |
| Basis set | `BASISSETG` or `BASISSETT` | editable program-specific basis; Crystal23 retains this field; CP2K uses its own basis selector |
| Extra Gaussian keywords | `EXTRAKEY` | literal route additions for Gaussian and Gaussian SCCC only |

The method/basis menus close after selection and change when the program
changes. The text remains editable for expert keywords, but unsupported text
is not automatically validated by Tonto.

## External/custom basis definition

| Entry | Key/file | Meaning |
|---|---|---|
| Input external basis set manually | `GAUSGEN` | stage a program-specific custom basis |
| Basis path | `basis_gen.txt` | source or generated definition copied into the calculation directory |
| Load file | file action | select an existing definition |
| Edit definition | file action | open/edit the staged text definition |
| Basis Set Exchange | file action | choose an all-electron basis per element and render the selected program syntax |
| Tonto reference basis for Crystal23 HAR | `CRYSTAL_TONTO_BASIS_NAME` | legacy XML only; exact matching Tonto basis, never the literal Crystal `GEN` keyword |

For periodic programs the orange warning is intentional: a basis can be
all-electron yet unusable because diffuse periodic replicas become linearly
dependent. Basis Set Exchange conversion guarantees syntax and element
coverage, not periodic conditioning.

## Gaussian options

| Entry | Key | Meaning |
|---|---|---|
| Use Grimme dispersion (GD3BJ) | `GAUSSEMPDISP` | add the supported Gaussian empirical-dispersion route |
| Use relativistic method | `GAUSSREL` | activate the runner's supported scalar-relativistic Gaussian input |

These controls are visible only for Gaussian; they are not Tonto experimental
dispersion or generic controls for another program.

## Charge, spin, resources, and convergence

| Entry | Key | Meaning |
|---|---|---|
| Charge | `CHARGE` | finite-fragment charge; also copied to CP2K cell charge |
| Multiplicity | `MULTIPLICITY` | spin multiplicity; also copied to CP2K cell multiplicity |
| Wavelength | `WAVE` | diffraction wavelength in Å |
| F/sigma cutoff | `FCUT` | weak-observation criterion applied before merging |
| SCF processors | `NUMPROC` | external electronic-structure process/thread count; selects parallel Crystal driver when >1 |
| Tonto processors | `NUMPROCTONTO` | Tonto parallel process count |
| Maximum shift/s.u. | `CONVTOL` | main structural HAR convergence criterion |
| Maximum HAR cycles | `MAXCYCLE` | outer-cycle safety cap |
| SCF memory | `MEM` | external-program memory string |
| PBS memory per processor | `MEMPBS` | cluster resource request |
| Notification email | `EMAIL` | cluster GUI only |

## Crystal23 structure options

These entries appear only for Crystal23. Interface, LDREMO, and the other
expert Crystal controls are grouped on **Advanced HAR**.

| Entry | Key | Meaning |
|---|---|---|
| Use Hermann-Mauguin symbol | `USEHMSYM` | use the supported symbol-based structure route |
| Network compound outputs | `DEFRAGNETW` | activate outputs/geometry handling for extended networks |
| Reuse previous-cycle guess | `USEGUESS` | pass the preceding periodic SCF state as the next guess |
| Rhombohedral setting | `CRYSTAL_SETTING` | automatic, hexagonal axes, or rhombohedral axes |
| Integral screening (TOLINTEG) | `CRYSTAL_TOLINTEG` | `auto`, default, or explicit five integers |
| Crystal23 density interface | `LAMAGOET_CRYSTAL_DENSITY_INTERFACE` | native GRED (recommended) or legacy XML |
| Overlap-eigenvector removal | `CRYSTAL_LDREMO` | expert LDREMO integer; blank disables it |

## Density partition

| Entry | Key | Meaning / scope |
|---|---|---|
| Density model | `PARTITION_MODEL` | Tonto SCF (`oc-hirshfeld`) or experimental observed density (`oc-observed`); selector is applicable only to Tonto SCF jobs |
| Stockholder model | `STOCKHOLDER_MODEL` | finite cluster or periodic procrystal denominator; available for Tonto observed-density, Crystal23, and CP2K paths where supported |
| Reconstruction | `OBSERVED_DENSITY_RECONSTRUCTION` | constrained positive model (recommended) or legacy deconvolution; observed density only |
| Motion treatment | `OBSERVED_DENSITY_MOTION_MODEL` | static density + ADPs, or experimental dynamic atom shapes; observed density only |
| Held-out reflections | `OBSERVED_DENSITY_R_FREE_PERCENTAGE` | deterministic validation fraction excluded from reconstruction and structural LS |
| IAM-prior strength | `OBSERVED_DENSITY_PRIOR_STRENGTH` | explicit Tikhonov pull toward IAM; zero is the documented default |
| Smoothness β | `OBSERVED_DENSITY_SMOOTHNESS` | reciprocal damping 1 / [1 + β \|k\|²] in bohr² |
| Reconstruction step | `OBSERVED_DENSITY_STEP_SIZE` | initial projected-density step; line search may backtrack/grow it |
| Reconstruction iterations | `OBSERVED_DENSITY_MAX_ITERATIONS` | inner projected iterations per outer phase cycle |
| Residual-density shrinkage | `OBSERVED_DENSITY_SHRINKAGE` | reliability-weighted residual fraction; must be <1 |
| Minimum thermal factor | `OBSERVED_DENSITY_MIN_TF` | lower bound used by the legacy/static conversion where applicable |
| Zero-model phase | `OBSERVED_ZERO_PHASE_SIGN` | omit, positive, or negative sign for a symmetry-allowed exactly-zero model coefficient |
| Output Hirshfeld atoms after partition | `OUTPUT_HIRSHFELD_ATOM_CUBES` | write live per-independent-atom density cubes after partition |
| Atom label | `HIRSHFELD_ATOM_CUBE_LABEL` | exact CIF label; blank writes all independent atoms |

Dynamic observed density replaces the ordinary refinement-mode row with
**dynamic shapes only** and disables coordinate/ADP controls. This prevents a
non-identifiable second motion model.

## Molecular cluster environment

| Entry | Key | Meaning |
|---|---|---|
| Use SC cluster charges | `SCCHARGES` | update a point-charge environment self-consistently |
| radius | `SCCRADIUS` | charge-environment radius in Å |
| Complete molecules | `DEFRAG` | complete charge-environment molecules |
| Use dipoles | `SCDIPOLES` | include supported environmental dipoles |
| Nuclear interaction (ORCA) | `ADDNUCINTER` | ORCA-only interaction option |
| Use explicit cluster of molecules | `EXPLICITMOL` | include neighboring molecules quantum mechanically |
| within radius | `EXPLRADIUS` | explicit-cluster radius in Å |
| Complete molecules | `DEFRAGEXPL` | complete explicit neighboring molecules |

The group is hidden for ELMOdb, Crystal23, and CP2K. Crystal23 and CP2K have a
periodic environment; ELMOdb has its own transfer/tail controls.

## Tonto refinement options

| Entry | Key | Meaning |
|---|---|---|
| positions and ADPs | `POSADP` | refine both general coordinates and displacement parameters |
| positions only | `POSONLY` | refine coordinates while fixing ADPs |
| ADPs only | `ADPSONLY` | refine ADPs while fixing coordinates |
| Start with Tonto IAM | `IAMTONTO` | run/report an IAM starting refinement |
| Only perform Tonto IAM | `ONLYIAMTONTO` | stop after IAM; control calculation |
| Refine nothing for atom labels | `REFNOTHING`, `ATOMLIST` | fix exact listed atom labels |
| Refine these atoms isotropically | `REFUISO`, `ATOMUISOLIST` | use isotropic displacement for listed labels |
| Refine H positions | `REFHPOS` | allow hydrogen coordinate parameters |
| Refine H ADPs | `REFHADP` | allow hydrogen displacement parameters |
| H atoms isotropic | `HADP` | use isotropic H displacement treatment |
| Refine anharmonic ADPs | `REFANHARM`, `ANHARMATOMS` | enable selected anharmonic atoms |
| 3rd / 4th order | `THIRDORD`, `FOURTHORD` | select Gram-Charlier orders |
| Elongate X-H bond lengths | `XHALONG` | modify starting X-H geometry |
| B-H, C-H, N-H, O-H | `BHBOND`, `CHBOND`, `NHBOND`, `OHBOND` | starting bond lengths in Å |
| Apply experimental dispersion correction | `DISP` | Tonto experimental dispersion correction |
| Refine extinction correction | `EXTI` | expose and activate the selected extinction model |

### Extinction panel

| Entry | Key | Meaning |
|---|---|---|
| Correction | `EXTINCTION_MODEL` | Zachariasen or Becker-Coppens |
| Becker-Coppens type | `EXTINCTION_TYPE` | type 1, type 2, or mixed |
| Mosaic distribution | `EXTINCTION_DISTRIBUTION` | Gaussian or Lorentzian |
| Nature | `EXTINCTION_ANISOTROPIC` | isotropic or anisotropic |
| Absorption-weighted mean path | `EXTINCTION_MEAN_PATH_MM` | specimen-specific value in mm |

The explanation box changes with the selected model and is part of the
scientific warning, not merely interface decoration.

## CP2K periodic all-electron settings

Visible only for CP2K:

| Entry | Key | Meaning |
|---|---|---|
| Basis name | `CP2K_BASIS_SET` | parsed from the selected CP2K basis file; editable |
| XC functional | `CP2K_XC_FUNCTIONAL` | supported BLYP or PBE |
| Density interface | `CP2K_DENSITY_INTERFACE` | native density/overlap/Fock or legacy XML bridge |
| k-point grid | `CP2K_KPOINT_GRID` | three periodic mesh dimensions |
| Cutoff | `CP2K_CUTOFF` | GAPW plane-wave cutoff |
| Relative cutoff | `CP2K_REL_CUTOFF` | GAPW relative grid cutoff |
| Maximum SCF cycles | `CP2K_MAX_SCF` | electronic iteration cap |
| SCF tolerance | `CP2K_EPS_SCF` | CP2K SCF convergence target |
| Added MOs | `CP2K_ADDED_MOS` | virtual space; -1 requests all available |

Executable and basis-file paths are on **Settings**.

## Periodic wavefunction export

| Entry | Key | Meaning |
|---|---|---|
| Write final periodic wavefunction as TREXIO | `PERIODIC_WAVEFUNCTION_EXPORT` | exact periodic representation for supported Crystal23/CP2K result |
| Run finite all-electron crystal-cluster calculation | `FINITE_WAVEFUNCTION_EXPORT` | separate finite approximation producing `.47`/WFN/WFX |
| Finite basis directory/name | `FINITE_WAVEFUNCTION_BASIS_DIR`, `FINITE_WAVEFUNCTION_BASIS_NAME` | Tonto all-electron basis for new finite SCF |
| Active-region centre atom | `FINITE_WAVEFUNCTION_CENTER_ATOM` | one-based unit-cell atom index |
| Active-region radius | `FINITE_WAVEFUNCTION_ACTIVE_RADIUS` | quantum active sphere in Å |
| Quantum-buffer radii | `FINITE_WAVEFUNCTION_BUFFER_RADII` | comma-separated radii for boundary sensitivity testing |
| Cap severed bonds | `FINITE_WAVEFUNCTION_CAP_BOUNDARIES` | optional H capping for extended covalent networks |
| Prepare only | `FINITE_WAVEFUNCTION_PREPARE_ONLY` | validate clusters/inputs without running Tonto |

## Advanced HAR tab

| Entry | Key | Meaning |
|---|---|---|
| Energy convergence | `CONVTOLE` | energy/density-cycle threshold where used |
| Tonto linear-dependence tolerance | `LINEDEP` | explicit Tonto AO linear-dependence control |
| Maximum Crystal cycles | `MAXXTALCYCLE` | Crystal23 SCF cap; blank automatic |
| Crystal BIPOSIZE | `BIPOSIZE` | optional Crystal Coulomb buffer size |
| Crystal ILASIZE | `ILASIZE` | optional Crystal ILA array dimension |
| Use Crystal SUPERCON | `SUPERCON` | enable the supported Crystal keyword |
| SHRINK A/B | `SHRINKA`, `SHRINKB` | Crystal23 k-point shrinking factors |
| Maximum least-squares cycles | `MAXLSCYCLE` | Tonto inner LS cap; dynamic observed mode uses it as the phase-updated outer cap |
| Maximum pHAR cycles | `MAXPHARCYCLE` | powder-HAR outer cap |
| NoSpherA2 accuracy | `NSA2ACC` | accuracy integer passed to legacy NoSpherA2 route |
| Minimum correlation coefficient | `MINCORCOEF` | supported correlation pruning threshold |
| Powder HAR | `POWDER_HAR` | activate legacy powder-HAR/Jana workflow |
| Use NoSpherA2 | `USENOSPHERA2` | activate legacy NoSpherA2/Jana transfer workflow |
| Use a non-default Becke grid | `USEBECKE` | emit explicit Tonto Becke integration controls |
| Becke accuracy | `ACCURACY` | `very_low`, `sg-1`, `low`, `medium`, `high`, `very_high`, `extreme`, or `best` |
| Becke pruning scheme | `BECKEPRUNINGSCHEME` | `none`, `sg1`, or `robust` |
| Stationary-wavefunction energy tolerance | `HAR_ENERGY_REPEAT_TOL` | repeated-cycle energy threshold |
| Stationary-wavefunction RMSD tolerance | `HAR_SCF_RMSD_TOL` | repeated-cycle SCF-density threshold |

## ELMO advanced tab

| Entry | Key | Meaning |
|---|---|---|
| Use GAMESS-US through ELMOdb | `USEGAMESS` | request legacy overlap/integral support |
| Number of disulfide bonds | `NSSBOND` | number of explicit disulfide definitions |
| Disulfide-bond atoms | `SSBONDATOMS` | atom-number pairs, one per line |
| Number of tailored residues | `NTAIL` | count of manual tailored residues |
| Tail atom limit | `ATAIL` | ELMO tail atom limit |
| Tail fragment limit | `FRTAIL` | ELMO tail fragment limit |
| Tailor-made residue definition | `MANUALRESIDUE` | literal ELMO residue block |

## XCW tab

The molecular and periodic controls are described in {doc}`xcw` and
{doc}`periodic-xcw`. Their exact variable mapping is listed in
{doc}`options-reference`.

## Plots tab

See {doc}`plots`. The panel is currently a retained, unvalidated legacy path.

## Settings tab

The settings panel records executable and data paths:

| Entry | Key |
|---|---|
| Tonto executable | `TONTO` |
| Gaussian executable | `GAUSSIAN_BIN` |
| ORCA executable | `ORCA_BIN` |
| OCC executable | `OCC_BIN` |
| Crystal23 serial driver | `CRYSTAL_BIN` |
| Crystal23 parallel driver | `CRYSTAL_PARALLEL_BIN` |
| ELMOdb executable | `ELMODB_BIN` |
| GAMESS-US interface | `GAMESS` |
| Jana executable | `JANAEXE` |
| CP2K executable | `CP2K_BIN` |
| Tonto basis-set directory | `BASISSETDIR` |
| XCW basis-set directory | `BASISSETDIRXCW` |
| ELMO libraries directory | `ELMOLIB` |
| CP2K/Tonto Slater basis directory | `TONTO_BASIS_DIR` |
| CP2K all-electron basis file | `CP2K_BASIS_SET_FILE` |

Discovery fills empty fields from common installations. A path entered by the
user is not overwritten silently.

## Structure viewer

The viewer loads only the CIF chosen by the user and its subsequent live Tonto
CIFs. It does not scan the working directory for an arbitrary structure.

- left drag rotates; wheel zooms; right/middle drag pans;
- click two atoms for their distance;
- click three ordered atoms for angle A-B-C with B as the vertex;
- a fourth click begins a new selection; Esc clears it;
- **ADP ellipsoids** use the CIF Uij tensor and selected probability, not an
  element-radius sphere;
- **Follow latest Tonto CIF** monitors only files belonging to the current job;
- after an external final residual calculation without ADPs, the viewer retains
  the ADPs from the last refinement cycle at the final coordinates.

The grow controls can complete connected fragments or add short-contact/van
der Waals neighbors. Press **Apply** before **Export grown CIF**. The source
space group and cell are retained.

## Save, run, submit, and cancel

**Save without running/submitting** writes only `job_options.txt` and any
prepared sidecars. **OK - run locally** writes options and starts
`lamaGOET.sh`. **OK - submit to cluster** writes options and PBS script and
calls `qsub`. **Kill job** is available only for a process started by the local
GUI; it is not a cluster cancellation command. **Cancel** closes the form
without authorizing a calculation.
