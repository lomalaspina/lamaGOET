# Limitations and scientific boundaries

lamaGOET is an orchestration and analysis interface. It cannot make an
inappropriate electronic-structure model, basis, data reduction, or
crystallographic parameterization scientifically valid. The boundaries below
are part of the method definition, not merely software caveats.

## Maturity labels used in this manual

**Validated control**
: A retained calculation exercises the stated path and is compared against an
  independent or legacy reference with numerical acceptance evidence.

**Engineering-tested**
: Parsing, execution, invariants, or restart behavior have been tested, but
  publication-grade convergence and generality have not been established.

**Experimental**
: The interface is available for research evaluation. Method selection,
  convergence, and uncertainty treatment still require explicit validation.

**Legacy compatibility**
: Retained to reproduce earlier work or support an external dependency. It is
  not the preferred path for a new calculation.

## Workflow support matrix

| Workflow | Program/interface | Present boundary |
|---|---|---|
| Molecular HAR | Tonto, Gaussian, ORCA, OCC, ELMOdb | Established orchestration; external-program/version coverage is not exhaustive |
| Periodic HAR | Crystal23 restricted all-electron native GRED | Validated against legacy XML for retained NH3, Diamond, Quartz, and Natrolite controls |
| Periodic HAR | Crystal23 legacy XML | Compatibility path; still required for unsupported states/features |
| Periodic HAR | CP2K restricted all-electron native matrices/MOKP | One-cycle native-versus-XML controls for NH3 and Diamond; no universal basis/material validation |
| Periodic HAR | CP2K legacy XML bridge | Compatibility path; Python bridge remains available explicitly |
| Molecular XCW/XWR | Tonto | Available; λ and environment selection remain scientific choices |
| Periodic XCW | Crystal23 GRED+KRED / Tonto | Experimental; λ-zero and small nonzero engineering controls exist for Diamond |
| Observed-density reconstruction | Tonto | Experimental research model; not equivalent to ordinary HAR or a periodic inverse-Kohn--Sham solution |
| Dynamic observed density | Tonto | Experimental fixed-structure density-shape analysis; conventional ADPs are not independently identifiable from the same smeared density |
| Plots/cubes | Tonto | Input generation exists; the full plotting workflow is currently not release-validated |
| SCCC optimization | Gaussian/ORCA with Tonto | Available molecular cluster workflow; not a periodic geometry optimizer |

The table describes the repository snapshot, not a guarantee for all versions
of the external programs.

## Crystallographic data

- The user is responsible for absorption correction, detector corrections,
  scaling consistency, wavelength, uncertainty quality, and provenance of the
  measured intensities.
- A MERG code defines symmetry treatment; it does not rescue twinning,
  modulation, diffuse scattering, multiple lattices, or a wrong space group.
- Weak-observation rejection before merging follows the implemented SHELX-like
  lifecycle. The chosen threshold still affects bias and completeness and must
  be reported.
- Model-dependent zero-Fcalc pruning can change after each aspherical
  partition. The original unmerged observations must remain available so a
  reflection can re-enter.
- Completeness and Friedel coverage written to the CIF depend on the available
  wavelength, cell, symmetry, angular limit, and observation population. A
  missing prerequisite must be represented as unavailable, not invented.

## Geometry and disorder

The routine workflow assumes a crystallographically interpretable ordered
model. Severe disorder, anharmonic motion, occupational modulation, twinning,
incommensurability, and multiphase data require model-specific treatment not
provided by a generic checkbox. Constraints and restraints must be justified
and inspected in the generated Tonto input.

Completing a molecule for the quantum calculation does not change the
crystallographic asymmetric unit. Manual growth creates a new starting CIF;
it does not convert the refinement to P1 and must not duplicate symmetry
equivalents already handled by Tonto.

## Basis sets

Tonto requires all-electron information for the density and atom partition.
An ECP/pseudopotential basis is not interchangeable with an all-electron
basis. A basis retrieved from Basis Set Exchange may be mathematically valid
in a molecular code yet unsuitable or linearly dependent in a periodic solid.

For Crystal23 and CP2K:

- prefer a basis designed/tested for periodic all-electron work;
- preserve exact shell/contraction/AO ordering from the producing program;
- preserve formal shell charges required by Crystal23;
- use a matched Tonto sidecar where a downstream Tonto operation requires the
  basis explicitly;
- converge integral thresholds, direct-lattice support, and k mesh.

AO count is not a completeness metric by itself. In Diamond, both the 36-AO
standard and 46-AO core-decontracted references retained extensive off-cell
density; the smaller basis gave slightly better matched λ-zero statistics in
the retained test. The full density depends on contractions *and* all retained
translation blocks.

## Periodic density interfaces

GRED and native CP2K matrices retain direct-lattice information. KRED retains
k-resolved complex orbitals. A finite k-point inverse transform aliases
translation blocks, so KRED alone does not uniquely reconstruct the exact
GRED density anchor. Periodic XCW therefore uses the exact direct-density
anchor plus the inverse-transformed *change* in the orbital projector.

Cell setting, atom mapping, AO ordering, contraction normalization, complex
phase convention, translation convention, and electron trace are all part of
the data contract. A file that parses but violates one of these invariants is
not a valid wavefunction import.

The initial native paths cover restricted all-electron cases used in the
retained controls. Spin-polarized, relativistic, pseudopotential, hybrid,
metallic/fractional-occupation, and unusual symmetry cases require separate
validation and may use a legacy route or be unsupported.

The currently validated scalar-relativistic route exposed by lamaGOET is
Gaussian `int=dkh` with an explicitly DKH-compatible all-electron basis. The
private Tonto branch intentionally rejects DKH/IOTC requests: its historical
core-Hamiltonian implementation has not yet been ported together with the
required picture-change density and structure-factor operators. This explicit
failure prevents a relativistic request from silently running as a
nonrelativistic calculation. Tonto's retained Pauli/ZORA source is not exposed
as a validated lamaGOET HAR route.

## Stockholder atoms

Cluster and periodic stockholders answer different boundary-condition
questions. A periodic stockholder includes translated crystalline density;
the cluster variant partitions the finite environment supplied. Neither is
universally superior. Converge the environment/radius and examine per-atom
cubes, electron populations, site-symmetry leakage, and final reflection
statistics.

Hirshfeld-atom cubes are diagnostic sampled densities. Their visual shape
depends on the grid and isovalue and does not directly provide an uncertainty
or prove that a partition is chemically unique.

## Observed-density models

Experimental diffraction provides finite, noisy structure factors and not a
unique positive three-dimensional electron density. Phase information,
resolution truncation, thermal averaging, scale, extinction, and missing
reflections make direct inversion ill-posed. The observed-density paths
therefore require a prior, symmetry, electron-count/positivity constraints,
regularization, and held-out validation.

Static observed-density reconstruction incorporates ADPs in the forward model
to avoid dividing noisy Fourier density by small thermal factors. Dynamic
observed density instead treats a thermally averaged atomic shape as the
object. In the dynamic model, positions/ADPs cannot all be independently
refined from the same shape without an additional identifiable parameterization
or prior. It is not a drop-in route to neutron-like hydrogen positions.

The current observed-density implementation is not a complete periodic
inverse-Kohn--Sham reconstruction. Claims about orbitals, potentials, bond
topology, or unique atomic densities require independent validation beyond an
improved training-set R factor.

## XCW and λ selection

XCW trades an electronic-energy objective against diffraction agreement. A
larger λ can fit noise and model deficiencies. Select λ with an explicit path,
convergence checks, and preferably deterministic held-out reflections. At
periodic λ = 0 the imported reference must be reproduced before a nonzero
response is scientifically interpretable.

The periodic-XCW implementation is fixed-geometry. HAR followed by XCW is
XWR; it does not imply simultaneous periodic refinement of nuclear and orbital
parameters. The retained nonzero-λ Diamond run demonstrates an engineering
response and checkpoint integrity, not a publication-ready λ.

## Extinction

Zachariasen--Larson and Becker--Coppens parameterizations have different
assumptions. Becker--Coppens type 1, type 2, mixed, Gaussian/Lorentzian, and
isotropic/anisotropic choices require data capable of supporting those
parameters. A refined coefficient with a small numerical e.s.d. is not proof
that the model is physically identifiable. Compare residual trends versus
intensity and angle and report the complete model in the CIF.

## Wavefunction exports

`.47`, WFN, and WFX are finite-molecule representations. They cannot encode
an infinite k-periodic state exactly. Periodic TREXIO is the authoritative
periodic export. A finite crystal-cluster calculation can produce conventional
molecular files for local analysis, but boundary termination, charge,
multiplicity, embedding, and cluster convergence must be reported and it must
not be relabelled as the periodic wavefunction.

## Platform and external-program limits

- The GUI is intended for Linux, macOS, WSL, and native Windows setup; local
  refinement execution requires a Unix shell, so native Windows runs through
  WSL or submits to a compatible cluster.
- Cluster support targets PBS-style submission. Site modules, schedulers, MPI
  wrappers, scratch policies, and licences remain site-specific.
- `install.sh` installs lamaGOET's Python/system dependencies where supported;
  it does not install or license Tonto, Crystal23, Gaussian, ORCA, CP2K, OCC,
  ELMOdb, or GAMESS-US.
- Qt offscreen smoke tests prove widget construction, not correct rendering on
  every window manager, display scale, or WSLg version.

## What a passing test means

The normal test suite checks shell portability, runner parity, option
serialization, GUI construction, helpers, and retained archive integrity. It
does not run licensed electronic-structure packages and therefore cannot prove
that every scientific workflow remains numerically identical. Live scientific
regressions are opt-in and must record program versions and fresh results.

No software test can replace convergence studies, chemically appropriate
model selection, uncertainty analysis, and expert inspection of the final
crystallographic artifacts.
