# Maps and plots

:::{admonition} Current status
:class: warning
The plot panel is preserved in the interface, but the end-to-end plot workflow
is not covered by the current automated or retained scientific regression
suite and has reported failures on the present development line. Treat it as
an unvalidated legacy interface. Inspect the generated Tonto `stdin` and
`stdout`; do not assume that selecting a box produced the requested map.
:::

## Available quantities

**Run Tonto plot calculation** activates the plot path. The selectable fields
are:

- deformation density;
- DFT exchange-correlation potential;
- electron density;
- Laplacian;
- negative Laplacian; and
- promolecule density.

The quantity must exist for the current wavefunction/density model. For
example, a DFT XC potential is not defined by an HF wavefunction in the same
sense as by the selected DFT implementation.

## Grid definition

The plot plane/volume is defined by a centre, axes, widths, and sampling:

| Control | Meaning |
|---|---|
| Plot dimensions are in Å | interpret widths/separation in Å rather than the Tonto default unit |
| Use explicit grid separation | specify point spacing directly |
| Grid separation | distance between adjacent samples when explicit separation is enabled |
| Use all grid points | request the full generated grid rather than the legacy reduction |
| Grid points X/Y/Z | explicit counts along each dimension |
| Use an atom as plot centre | centre the grid at a one-based atom index |
| Centre atom | one-based atom index in Tonto's generated structure |
| X-axis atom pair | ordered atom indices defining the first direction |
| Y-axis atom pair | ordered atom indices defining the second direction |
| Plot widths X/Y/Z | physical extents of the requested region |

The X and Y directions must be non-collinear. Atom indices refer to the Tonto
structure after completion/growth, not necessarily the row order in the
original CIF. Confirm them in `stdout` or the generated XYZ/CIF.

## Sampling and interpretation

A visually smooth map can be numerically unconverged. Test separation/point
count until extrema, integrated density, critical features, and contour shape
are stable. Report the units and sign convention. In particular:

- density and deformation density require a stated electron-density unit;
- the Laplacian sign convention must accompany plots of charge concentration;
- promolecule subtraction must use the same geometry, basis conventions, and
  grid as the total density; and
- exchange-correlation potential values depend directly on the implemented
  functional and numerical grid.

## Residual-density and Hirshfeld-atom cubes

The standard final residual cube, optional nominal FMAP 2 coefficient
comparison, and optional Hirshfeld-atom cubes are separate from the legacy
plot types and have stronger regression coverage. Use a cube viewer and verify
units:

- constrained Hirshfeld-atom cubes are written in electrons/bohr³;
- retained residual-density cubes are normally interpreted in
  electrons/Å³.

The standard file is `JOBNAME.residual_density,cell.cube`. Enabling
**Also calculate the nominal SHELXL FMAP 2 coefficient comparison**
additionally writes `JOBNAME.shelxl_residual_density,cell.cube`; it never
replaces or reroutes the standard path. The independent path evaluates the
nominal displayed FMAP 2 difference-density equation

$$
\Delta\rho(\mathbf r)=\frac{1}{V}\sum_{\mathbf h}
  (F_o-F_c)\exp(i\phi_c)
  \exp(-2\pi i\,\mathbf h\!\cdot\!\mathbf r).
$$

Here the observed amplitude is placed on the absolute scale, $F_c$ and
$\phi_c$ are the magnitude and phase of the calculated structure factor, and
$V$ is the unit-cell volume. The implementation does not use least-squares
`WGHT` values as Fourier coefficients. SHELXL documentation states that poorly
measured observations are downweighted, but does not publish that exact
algorithm; lamaGOET/Tonto deliberately does not infer an undocumented
sigma-dependent factor. Consequently, this is a transparent comparison of the
nominal published coefficient, not a complete SHELXL residual-map
implementation, not a claim of byte-for-byte identity with the SHELXL
executable, and not an Olex2/CCTBX map.

Both Tonto cubes use the identical current merged reflections and sampling
grid. Residual extrema can change substantially with grid spacing, so compare
maps only on matched grids and report the actual separations printed in
`stdout`. A smaller separation samples sharper peaks and holes more fully but
costs more memory and time.

The per-atom cube represents the density assigned by the live stockholder
partition after that partition step. Select an exact CIF atom label to limit
output, or leave it blank for all independent atoms. The cube is a diagnostic,
not proof that the partition is unique or that a subsequent refinement is
physically valid.

## Recovery procedure

Until the plot path is revalidated:

1. save `job_options.txt`;
2. inspect the generated plot block in Tonto `stdin`;
3. run the smallest grid and confirm the expected output file exists;
4. inspect `stdout` for the plot keyword and a completed grid calculation;
5. increase the grid systematically; and
6. retain a known numerical checksum or extrema/integral baseline before using
   the plot in a publication.
