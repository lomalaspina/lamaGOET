---
orphan: false
---

<div class="hero">

# lamaGOET scientific manual

**Reproducible setup and execution of molecular and periodic Hirshfeld atom
refinement, X-ray constrained wavefunction calculations, and related Tonto
workflows.**

This manual describes what lamaGOET calculates, how the graphical controls map
to the generated inputs, what evidence supports each implementation, and where
the present scientific and software boundaries lie.

</div>

:::{admonition} Scope and version
:class: important
This manual documents the `cleanup` branch at revision **{sub-ref}`release`**.
It describes interfaces implemented jointly by lamaGOET and the compatible
Tonto development branch. A control visible in the GUI is not evidence that a
particular external program, basis, material, or experimental data set has
been scientifically validated.
:::

<a class="reference download" href="downloads/lamaGOET-Scientific-Manual.pdf">Download the PDF edition</a>

:::{rubric} Choose a workflow
:::

:::::{only} html
::::{grid} 2
:gutter: 3

:::{grid-item-card} Molecular HAR
:link: har
:link-type: doc
Iterate a molecular wavefunction and a Tonto aspherical-atom refinement using
Tonto, Gaussian, ORCA, OCC, or ELMOdb.
:::

:::{grid-item-card} Periodic HAR
:link: periodic-har
:link-type: doc
Use Crystal23 or all-electron CP2K for a genuinely periodic density, imported
through native density interfaces or retained legacy XML paths.
:::

:::{grid-item-card} Molecular XCW and XWR
:link: xcw
:link-type: doc
Optimize a Tonto wavefunction against diffraction data at fixed geometry, or
run HAR followed by XCW.
:::

:::{grid-item-card} Periodic XCW
:link: periodic-xcw
:link-type: doc
Optimize k-resolved Tonto orbitals at fixed geometry using a matched Crystal23
GRED+KRED reference. This path is experimental.
:::

:::{grid-item-card} Tonto SCCC optimizations
:link: sccc
:link-type: doc
Run self-consistent cluster-charge theoretical optimizations with Gaussian or
ORCA coordinated by Tonto.
:::

:::{grid-item-card} Maps and plots
:link: plots
:link-type: doc
Configure Tonto density, deformation-density, Laplacian, promolecule, and
exchange-correlation-potential grids. Current limitations are explicit.
:::

::::
:::::

::::{only} latex
```{list-table}
:widths: 31 69
:header-rows: 0

* - **{doc}`Molecular HAR <har>`**
  - Iterate a molecular wavefunction and a Tonto aspherical-atom refinement
    using Tonto, Gaussian, ORCA, OCC, or ELMOdb.
* - **{doc}`Periodic HAR <periodic-har>`**
  - Use Crystal23 or all-electron CP2K for a genuinely periodic density,
    imported through native density interfaces or retained legacy XML paths.
* - **{doc}`Molecular XCW and XWR <xcw>`**
  - Optimize a Tonto wavefunction against diffraction data at fixed geometry,
    or run HAR followed by XCW.
* - **{doc}`Periodic XCW <periodic-xcw>`**
  - Optimize k-resolved Tonto orbitals at fixed geometry using a matched
    Crystal23 GRED+KRED reference. This path is experimental.
* - **{doc}`Tonto SCCC optimizations <sccc>`**
  - Run self-consistent cluster-charge theoretical optimizations with Gaussian
    or ORCA coordinated by Tonto.
* - **{doc}`Maps and plots <plots>`**
  - Configure Tonto density, deformation-density, Laplacian, promolecule, and
    exchange-correlation-potential grids. Current limitations are explicit.
```
::::

:::{rubric} Terminology used here
:::

- **HAR** refines structural parameters using theoretically calculated
  wavefunctions and Hirshfeld atomic scattering factors.
- **XCW** is performed by Tonto at a fixed geometry and optimizes a
  wavefunction under an X-ray restraint.
- **XWR** is the sequence HAR followed by XCW.
- **Periodic HAR** and **periodic XCW** preserve translational periodicity in
  their respective density or orbital representations.
- **IAM** denotes an independent-atom model with spherical tabulated atoms.

The terminology is deliberately strict: a CP2K or Crystal23 HAR is still HAR,
not XCW; a fixed-geometry periodic orbital optimization is periodic XCW; and
the sequence of the two is XWR.

```{toctree}
:maxdepth: 2
:caption: Foundations

getting-started
principles
```

```{toctree}
:maxdepth: 2
:caption: Calculation workflows

har
periodic-har
xcw
periodic-xcw
sccc
plots
```

```{toctree}
:maxdepth: 2
:caption: Operation and reference

gui-reference
options-reference
outputs
examples
troubleshooting
limitations
```

```{toctree}
:maxdepth: 2
:caption: Validation and provenance

validation
references
glossary
```
