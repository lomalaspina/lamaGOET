# Curved ADP GUI activation, 19 November 2026

Scope: opt-in planar/surface selector, safe option round-trip, fresh-directory
input generation, IAM and one native restricted molecular SCF/capture, and
shared local/cluster runner dispatch. Ordinary jobs remain on their old path.
The supported scientific scope and quantitative resolution definitions are in
`docs/manual/curved-adp.md`; defaults are in `options-reference.md`.

Validation performed locally:

- `Tests/test_curved_job.py`: invalid settings rejected; signed HKL records
  and native-header records preserved; multiple batches refused; output
  directories cannot be reused; both real shell launchers dispatch to the new
  runner (mock native executable); exit zero alone cannot bless nonconvergence.
- `Tests/test_qt_gui_smoke.py`: full main window constructs and its existing
  option/refinement controls remain functional; selector round-trip is covered
  by the new test. The rendered selector was visually inspected.
- Native deployed Tonto command integration: generated IAM and tiny complete
  NH3 restricted-SCF/Hirshfeld inputs produce fixed-evaluation artifacts.
  SCF actually converges; wrapper correctly does not call evaluation a fit.
- Native synthetic P21/c Cu/Cl/C runner integration, 216 observations and
  complex dispersion: stationary and perturbed-start surface fits converge;
  a deliberately one-iteration-limited fit returns nonzero/nonconverged.
  These are software controls, not claims about experimental structure quality.
- Existing large-data HAR comparisons and their Cl residual slices were
  collected, not recalculated for this UI change. The comparison uses the same
  external converged electronic density in all four models. It does not
  establish that the separate large native SCF convergence issue is solved.
- HTML/PDF documentation builds with Sphinx warnings treated as errors.
  Added equations, selector instructions, comparison table and matched slices
  were rendered and visually checked. No user manual text was replaced wholesale.

The native curved solver and its convergence/uncertainty acceptance criteria
were not modified. The GUI does not certify a universal resolution cutoff,
physical interpretation, or identifiability from a clean residual map.
