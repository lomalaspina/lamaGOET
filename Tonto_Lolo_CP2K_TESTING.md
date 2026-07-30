# Tonto `Lolo_CP2K` Fourier-kernel change

This source change is maintained on the companion Tonto `Lolo_CP2K` branch.

It does **not** reuse atomic form factors. `get_C23_Hirshfeld_atom_FFs`
continues to construct a fresh density and fresh form factors from the current
geometry at every `HA_fit` refinement step.

The only source change is in the innermost Fourier loop:

```text
exp(i k.r) = cos(k.r) + i sin(k.r)
```

The two real components are accumulated separately to avoid the general
complex-exponential and complex-multiply path.

Rebuild Tonto using the same compiler flags and MPI configuration as your
current executable. Do not replace the production executable until a real
CP2K/Tonto job has been compared.

## Validation performed

The included `benchmark_c23_fourier_kernel.f90` compares the original complex
sum with the replacement real/imaginary sum. With GNU Fortran 11.4, `-O3
-march=native`, 4,000 grid points, 512 reflections, and three repetitions:

```text
maximum absolute difference: 0.0000E+00
complex-exp kernel:           0.2735 s
real sin/cos kernel:          0.2588 s
speed ratio (old/new):        1.057x
```

This is a modest kernel-level improvement, not evidence that the full
`Making F_pred` stage will be 5.7% faster. A production dataset is required to
measure the end-to-end effect.

The changed `molecule.scf.foo` successfully generated `molecule.scf.F90` in a
native-Linux LF-only checkout. The complete serial branch build later stopped
at 33% in the untouched `shell1.foo`/`shell.foo` inheritance preprocessing,
before the generated modules reached the Fortran compilation phase. Therefore
the change has a successful Foo-generation check and isolated numerical
benchmark, but not a complete Tonto executable build. Do not treat it as
production-ready unless your full Tonto build and a representative refinement
both pass.
