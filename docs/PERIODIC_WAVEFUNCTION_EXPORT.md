# Periodic wavefunction export

lamaGOET can optionally write the final CP2K or Crystal23 wavefunction as
`JOBNAME.periodic.trexio`. Enable **Write the final CP2K/Crystal23
wavefunction as TREXIO** in the Qt interface, or set:

```bash
PERIODIC_WAVEFUNCTION_EXPORT="true"
```

in `job_options.txt`.

## Why TREXIO

Molecular WFN, WFX and NBO `.47` files do not define a periodic cell,
k-points, k-point weights, complex Bloch coefficients, or the translation
phase of a basis function. Writing a periodic result into one of those formats
would therefore discard essential information. TREXIO stores those periodic
quantities explicitly.

The export contains the all-electron Gaussian basis, cell, nuclei, sampled
k-points and weights, orbital energies, occupations, spin indices, and real
and imaginary MO coefficients. A JSON sidecar records dimensions, validation
results, and whether the available virtual space is complete.

## CP2K

The exporter reads the existing `MO_KP` `.mokp` file used by the CP2K–Tonto
density bridge. It preserves CP2K's full sampled k grid and applies the same AO
ordering and atom-gauge transformation as CP2K's native TREXIO writer.

`CP2K_ADDED_MOS=20`, the normal lamaGOET default, produces all occupied bands
plus 20 virtual bands. Select **All available (-1)** for **Added MOs** if a
complete virtual space is required. CP2K then diagonalizes every available
orbital at every k point during every HAR wavefunction calculation, which can
be much more expensive. The JSON sidecar states whether `NMO == NAO`.

Only all-electron calculations are accepted. The export fails rather than
silently representing an effective-core/pseudopotential calculation as a
full-electron wavefunction.

## Crystal23

Crystal23 XML contains the direct-lattice overlap and Fock/Kohn–Sham matrices,
but not canonical MO coefficients or Gaussian exponents. The exporter:

1. Fourier transforms the paired direct-lattice matrices to each irreducible
   k point.
2. Solves `F(k) C(k) = S(k) C(k) epsilon(k)` by a Hermitian Cholesky
   transformation.
3. Verifies the reconstructed coefficients are overlap-orthonormal.
4. Combines them with the exact Tonto/Crystal basis-library file selected in
   the job.

The export is rejected if the basis expands to a different number of AOs than
the XML. The current implementation supports the restricted, one-spin
Crystal23 XML written by the lamaGOET workflow. An unrestricted Crystal23 XML
is rejected explicitly until both spin matrix blocks have a validated test
case.

## Files

- `JOBNAME.periodic.trexio`: HDF5 TREXIO wavefunction.
- `JOBNAME.periodic.trexio.json`: human-readable provenance and validation.
- `JOBNAME.periodic-wavefunction-export.log`: exporter stdout/stderr.

The files are also copied into the final Tonto residual-cycle directory. CP2K
jobs additionally copy them into `final.CP2K.residuals.JOBNAME`.

You can validate a file independently with the lamaGOET environment:

```bash
source .venv-qt/bin/activate
python periodic_wavefunction_export.py validate my_job.periodic.trexio
```

## Finite supercell WFX/NBO files

A finite Born–von Karman supercell can formally be constructed from a complete
uniform k mesh, but it is not an exact representation of the infinite
wavefunction in a molecular format. It also scales as `NAO * Nk` basis
functions: the 6×6×6 diamond example would have 31,104 basis functions before
writing dense MO coefficients. Arbitrary eigenvector phases and degenerate
band rotations must additionally be gauge-fixed before producing real
localized orbitals.

lamaGOET therefore does not silently generate a finite WFX or `.47` surrogate.
TREXIO is the publishable periodic result. A future supercell conversion should
be a separate, explicitly labelled post-processing operation with band-gauge
control and a file-size limit.
