# Experimental fixed-geometry periodic XCW

lamaGOET distinguishes three calculations:

- **HAR** refines coordinates and displacement parameters using a theoretical
  wavefunction.
- **XCW** optimizes a Tonto wavefunction against diffraction data at a fixed
  geometry.
- **XWR** runs HAR first and then XCW at the final HAR geometry.

The periodic XCW option is a Tonto calculation. lamaGOET runs Crystal23
`NEWK` plus `CRYAPI_OUT` at the selected fixed geometry. The resulting XML
supplies the compatible basis and direct-lattice overlap/density/Fock blocks,
while formatted KRED supplies the native complex eigenvectors, energies and
occupations at every full-zone k point. Tonto validates mesh completeness,
occupations, overlap orthonormality, electron count, projector idempotency,
stationarity, time reversal and full crystallographic covariance before XCW
can start.

This remains necessary when the preceding HAR used CP2K: the CP2K bridge XML
does not contain a Crystal-compatible orbital/overlap/Fock state, so lamaGOET
builds a fresh native Crystal23 reference at the final CP2K-HAR geometry.

## Supported experimental scope

- neutral, restricted closed-shell cells (charge 0, multiplicity 1);
- pure semilocal BLYP or PBE references;
- one all-electron basis represented identically in Crystal23 XML and Tonto;
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
using XML/KRED data.

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
residual-density cube, work/free statistics, compressed XML and KRED reference
files, and the checkpoint files into `periodic_XCW.<job-name>/`. These files
are test artifacts, not evidence that grid or lambda convergence has been
established automatically.

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
