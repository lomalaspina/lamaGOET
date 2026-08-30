# Hirshfeld-atom density cubes

Enable **Output Hirshfeld atoms after partition** in the density-partition
panel to write Gaussian cube files from the stockholder partition that Tonto
actually uses in the refinement. The cube bounding box is the crystallographic
unit cell and its header contains all atoms in that unit cell, but the scalar
field contains the electron density assigned to one independent atom only.

Leave **Atom label (optional)** blank to write every independent atom. Enter an
exact CIF atom label, such as `N1`, to write only that atom and avoid the cost
and disk use of producing every cube. Label matching is case-insensitive.

Files are named like:

```text
my_job.Hirshfeld_atom_density_cycle_0_N1,cell.cube
```

For the legacy observed-density reconstruction, enabling the same checkbox
also writes three separate real-space diagnostics per selected atom:

```text
my_job.Hirshfeld_atom_IAM_prior_cycle_0_H1,cell.cube
my_job.Hirshfeld_atom_observed_residual_cycle_0_H1,cell.cube
my_job.Hirshfeld_atom_density_cycle_0_H1,cell.cube
```

They contain, respectively, the neutral spherical IAM prior, the signed
stockholder-weighted regularized observed residual, and their sum before ADP
deconvolution. A companion table records the exact reciprocal-space correction
added to the static atomic form factor before and after division by the floored
harmonic temperature factor:

```text
my_job.Hirshfeld_atom_observed_FF_correction_cycle_0_H1.dat
```

The local and cluster runners copy these into the corresponding
`<N>.tonto_cycle.<job>/` directory, with the lamaGOET cycle number prepended,
before the next wavefunction/partition cycle can replace a same-named file.

The option supports molecular Hirshfeld partitions, imported Crystal23/CP2K
densities with either cluster or periodic stockholders, and the legacy
observed-density partition. The individual legacy observed-density components
and their sum state their contents and deconvolution status in their cube
titles.

The constrained observed-density reconstruction is currently represented only
on irregular atom-centred quadrature channels. Tonto therefore reports a clear
warning and does not create a regular cube for that model: interpolating those
channels would not reproduce the density used by the refinement.
