# Experimental fixed-geometry periodic XCW

lamaGOET distinguishes three calculations:

- **HAR** refines coordinates and displacement parameters using a theoretical
  wavefunction.
- **XCW** optimizes a Tonto wavefunction against diffraction data at a fixed
  geometry.
- **XWR** runs HAR first and then XCW at the final HAR geometry.

The periodic XCW option is a Tonto calculation. lamaGOET runs Crystal23
`NEWK` plus `CRYAPI_OUT` at the selected fixed geometry. The formatted GRED
file supplies the geometry and direct-lattice overlap/density/Fock blocks,
while formatted KRED supplies the native complex eigenvectors, energies and
occupations at every full-zone k point. Tonto validates the exact matching
Tonto basis against GRED's central overlap before checking mesh completeness,
occupations, overlap orthonormality, electron count, projector idempotency,
stationarity, time reversal and full crystallographic covariance before XCW
can start.

## Why periodic XCW uses both GRED and KRED

KRED and GRED carry complementary information. KRED is the authoritative
source of the complex Bloch orbitals used as periodic-XCW variational
parameters, but it is not a self-describing real-space density file. It omits
the direct-lattice `S(R)`, `P(R)` and `F(R)` blocks required by Tonto's
atom-centred density evaluation and partitioning. GRED is CRYSTAL23's compact,
official formatted direct-lattice interface and supplies those blocks together
with the primitive cell, atoms and basis-shell metadata.

More importantly, a finite k mesh determines only Born-von Karman alias sums.
A direct inverse transform of KRED's `P(k)` cannot distinguish `P(R)` from
`P(R+nN)`. On the Natrolite 2x2x2 reference this apparently harmless
replacement changed the direct density-matrix blocks by 1.424 in relative
Frobenius norm. Tonto therefore retains the exact GRED `P0(R)` at lambda zero
and applies only the inverse-transformed change `Delta P(k)` produced by XCW.
This is a physical boundary condition, not merely a file-format limitation.

The complex static structure factors reconstructed from the direct CRYAPI
matrices were checked
against Crystal23 XFAC values using the same geometry and basis. After the
single crystallographic origin/Fourier-convention alignment, the results were:

| System | Reflections | Amplitude R1 | Relative complex RMS |
|---|---:|---:|---:|
| NH3 (non-centrosymmetric) | 81 | 0.0000690 | 0.0001535 |
| Diamond | 57 | 0.0003888 | 0.0003534 |
| Quartz (chiral) | 512 | 0.0001182 | 0.0001812 |
| Natrolite (non-centrosymmetric) | 9,928 | 0.0001976 | 0.0002923 |

These residual differences are at the precision of the printed XFAC/FCF
values and do not show reflection-dependent phase corruption. For Natrolite,
increasing the Crystal23 mesh from 2x2x2 to 4x4x4 changed amplitudes by only
`2.02e-6` in R1 and complex factors by `3.13e-5` relative RMS over all 9,928
reflections.

The native GRED reader was then checked against the established XML reader.
For Diamond, NH3 and chiral quartz it reproduced the complete Tonto FCF
prediction exactly; the 46-AO Diamond periodic-XCW lambda-zero control also
reproduced every reported R factor, goodness of fit, scale and extinction
value exactly. Therefore lamaGOET now uses GRED for Crystal23 periodic HAR and
GRED+KRED for periodic XCW. KRED alone remains scientifically insufficient.
The legacy XML reader remains available in Tonto. lamaGOET also falls back to
that path for unrestricted Crystal23 HAR jobs, which are outside the current
native GRED reader contract; `LAMAGOET_CRYSTAL_DENSITY_INTERFACE=xml` provides
an explicit compatibility override. CP2K HAR has a separate
[native MO_KP/CSR interface](CP2K_NATIVE_INTERFACE.md), with its original XML
bridge retained as an explicit legacy option.

This remains necessary when the preceding HAR used CP2K: neither a CP2K
native HAR import nor its legacy bridge is yet a validated CP2K-only reference
for the periodic-XCW solver. The native HAR interface also imports CP2K's
overlap and Kohn-Sham/Fock matrices, but lamaGOET still builds a fresh native
Crystal23 reference at the final CP2K-HAR geometry for this XCW workflow.

## Supported experimental scope

- neutral, restricted closed-shell cells (charge 0, multiplicity 1);
- pure semilocal BLYP or PBE references;
- one all-electron basis represented identically in Crystal23 GRED and Tonto;
- fixed coordinates and ADPs throughout XCW;
- deterministic held-out reflections for independent validation.

HF, hybrid functionals, open-shell references and CP2K-only XCW references are
rejected rather than approximated silently.

## GUI workflow

Open the **XCW** tab and select **Experimental periodic XCW (fixed geometry,
native Crystal23 orbitals)**. Then choose either:

- **Perform XCW only** to use the supplied CIF geometry, or
- **Perform XWR** after a Crystal23 or CP2K HAR.

Set the native reference functional, the common Crystal23/Tonto all-electron
basis, real-space grid, density lattice radius, convergence tolerance,
damping, iterations and held-out percentage. The lambda fields are shared
with molecular XCW. For a publishable calculation, demonstrate convergence
with respect to both the periodic grid and Tonto's Becke-grid accuracy.

lamaGOET uses `extreme` as the minimum Becke-grid accuracy for periodic XCW
and preserves an explicit `best` request. This protects imported periodic
form factors from the earlier low-grid reconstruction error.

### Exact custom basis pairs

The ordinary basis selector is appropriate when Crystal23 and Tonto have the
same named basis. For a custom or decontracted basis, enable **Use an exact
paired custom Crystal23/Tonto basis** and supply both:

1. the CRYSTAL23 shell block, containing exactly one final `99 0`; and
2. the matching Tonto basis-library sidecar and its basis name.

The GUI stages both inputs with the job. The runners combine the sidecar with
Tonto's ordinary basis library so neutral free-atom references remain
available. Tonto then rejects an AO-count or central-overlap mismatch before
using GRED/KRED data.

The retained carbon-only 46-AO Diamond pair is in
`examples/periodic_xcw/diamond_core_decontracted_46/`. It is a reproducible
research option, not the default. Intercell density is carried by all
`P_mu,nu(R)` blocks; AO count alone is not a completeness criterion.

For the official Crystal23 launcher scripts, lamaGOET resolves `runprop23`
beside the configured `runcry23` executable and loads that installation's
`cry23.bashrc` when a non-interactive local or cluster shell has not already
defined `CRY23_EXEDIR` and `CRY23_SCRDIR`. The configured scratch directory
must exist or be creatable and writable; failures are reported before XCW
starts.

## Restart and outputs

When checkpoint writing is enabled, Tonto stores the k-resolved projector,
orbitals, lambda, dimensions, electron count and reference signature after
each update. Restart accepts the state only after checking reference
provenance, Hermiticity, electron count, projector idempotency, orbital/
projector consistency, direct-density reconstruction and space-group
symmetry. A stored convergence marker is not trusted by itself: Tonto rebuilds
the present diffraction, Hartree and XC gradient and reuses the terminal
projector without an update only when it still satisfies the requested
tolerance. Otherwise, it is retained only as a valid starting guess.

When the input reflection file is unmerged, every XCW orbital iteration and
lambda point restarts from that immutable full unmerged set, repeats the
selected preprocessing and MERG operation, and then performs model-zero
pruning with the current aspherical prediction. Final CIF/FCF/residual output
is rebuilt the same way from the converged projector, so a reflection excluded
for one density is not permanently lost if it becomes nonzero later.

The completed calculation writes the fixed-geometry CIFs, XCW FCF/FCO files,
residual-density cube, work/free statistics, compressed GRED and KRED reference
files, and the checkpoint files into `periodic_XCW.<job-name>/`. These files
are test artifacts, not evidence that grid or lambda convergence has been
established automatically.

By default lamaGOET deletes the much larger Crystal23 XML after confirming
that GRED was written. It automatically retains XML when the legacy reader is
needed. Set `LAMAGOET_KEEP_CRYSTAL_XML=true` for an additional legacy external
workflow or when the optional TREXIO exporter still requires XML.

## Matched Diamond lambda-zero checkpoint

Using the same 57 reflections, PBE reference, 6x6x6 k mesh, fixed geometry,
periodic stockholder and extreme atom-centred integration:

| Model/reference | AOs per primitive cell | R(F) | goodness of fit squared |
|---|---:|---:|---:|
| Tonto IAM | n/a | 0.009500 | 11.909232 |
| POB-TZVP-rev2 | 36 | 0.005680 | 3.035515 |
| Core-decontracted custom pair | 46 | 0.006054 | 3.287344 |

Both imported periodic references improve on IAM. The 36-AO reference is
slightly better in this matched test, so lamaGOET does not silently replace it
with the 46-AO experiment. The 46-AO path remains available when explicitly
selected as an exact pair.

A fresh `TOLDEE 8` standard-basis control also reproduced CRYSTAL23's direct
`XFAC` amplitudes over all 57 reflections with mean absolute difference
`0.001877`, RMS difference `0.002549`, and maximum difference `0.006789` after
the same thermal convolution.  This validates the actual prediction boundary
and the retained off-cell `P(R)` blocks, rather than using AO count as a proxy
for density completeness.
