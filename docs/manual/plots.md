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

The final residual-density cube and optional Hirshfeld-atom cubes are separate
from this legacy plot panel and have stronger regression coverage. Use a cube
viewer such as VESTA and verify units:

- constrained Hirshfeld-atom cubes are written in electrons/bohr³;
- retained residual-density cubes are normally interpreted in
  electrons/Å³.

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
