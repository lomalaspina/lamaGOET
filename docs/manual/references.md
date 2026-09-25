# References

This manual distinguishes primary methodological literature from software
manuals and living online documentation. URLs were selected to resolve to the
publisher or software project wherever possible.

## lamaGOET and Tonto

1. L. A. Malaspina, A. Genoni and S. Grabowsky, “lamaGOET: an interface for
   quantum crystallography,” *J. Appl. Cryst.* **54** (2021), 987–995.
   [doi:10.1107/S1600576721002545](https://doi.org/10.1107/S1600576721002545).

2. [lamaGOET source repository](https://github.com/lomalaspina/lamaGOET),
   `cleanup` branch for the interface documented here.

3. [Tonto source repository](https://github.com/dylan-jayatilaka/tonto).
   Periodic and observed-density options in this manual require the compatible
   development branch identified in the calculation provenance.

## Hirshfeld atoms and HAR

4. F. L. Hirshfeld, “Bonded-atom fragments for describing molecular charge
   densities,” *Theor. Chim. Acta* **44** (1977), 129–138.
   [doi:10.1007/BF00549096](https://doi.org/10.1007/BF00549096).

5. D. Jayatilaka and B. Dittrich, “X-ray structure refinement using
   aspherical atomic density functions obtained from quantum-mechanical
   calculations,” *Acta Cryst.* A**64** (2008), 383–393.
   [doi:10.1107/S0108767308005709](https://doi.org/10.1107/S0108767308005709).

6. S. C. Capelli, H.-B. Bürgi, B. Dittrich, S. Grabowsky and D. Jayatilaka,
   “Hirshfeld atom refinement,” *IUCrJ* **1** (2014), 361–379.
   [doi:10.1107/S2052252514014845](https://doi.org/10.1107/S2052252514014845).

7. P. N. Ruth, R. Herbst-Irmer and D. Stalke, “Hirshfeld atom refinement
   based on projector augmented wave densities with periodic boundary
   conditions,” *IUCrJ* **9** (2022), 286–297.
   [doi:10.1107/S2052252522001385](https://doi.org/10.1107/S2052252522001385).

8. D. E. P. Vanpoucke, P. Bultinck and I. Van Driessche, “Extending
   Hirshfeld-I to bulk and periodic materials,” *J. Comput. Chem.* **34**
   (2013), 405–417.
   [doi:10.1002/jcc.23088](https://doi.org/10.1002/jcc.23088).

9. M. L. Chodkiewicz, M. Woińska and K. Woźniak, “Hirshfeld atom like
   refinement with alternative electron density partitions,” *IUCrJ* **7**
   (2020), 1199–1215.
   [doi:10.1107/S2052252520013603](https://doi.org/10.1107/S2052252520013603).

10. [Current developments and trends in quantum crystallography](https://journals.iucr.org/b/issues/2024/04/00/je5055/index.html),
   *Acta Cryst.* B (2024). This review provides broader context for HAR,
   X-ray restrained wavefunctions, and current terminology.

## XCW/XRW and XWR

11. D. Jayatilaka and D. J. Grimwood, “Wavefunctions derived from experiment.
   I. Motivation and theory,” *Acta Cryst.* A**57** (2001), 76–86.
   [doi:10.1107/S0108767300013155](https://doi.org/10.1107/S0108767300013155).

12. D. J. Grimwood and D. Jayatilaka, “Wavefunctions derived from experiment.
    II. Further developments,” *Acta Cryst.* A**57** (2001), 87–100.
    [doi:10.1107/S0108767300013167](https://doi.org/10.1107/S0108767300013167).

13. M. L. Davidson, S. Grabowsky and D. Jayatilaka, “X-ray constrained
    wavefunctions based on Hirshfeld atoms. I. Method and review,” *Acta
    Cryst.* B**78** (2022), 312–332.
    [doi:10.1107/S2052520622004097](https://doi.org/10.1107/S2052520622004097).

14. [X-ray constrained wavefunctions based on Hirshfeld atoms. II.
    Reproducibility of electron densities in crystals of α-oxalic acid
    dihydrate](https://journals.iucr.org/b/issues/2022/03/01/so5075/),
    *Acta Cryst.* B**78** (2022). This paper is especially relevant to the
    halting/overfitting and reproducibility problem.

## Crystallographic definitions

15. S. R. Hall, F. H. Allen and I. D. Brown, “The crystallographic
    information file (CIF): a new standard archive file for crystallography,”
    *Acta Cryst.* A**47** (1991), 655–685.
    [IUCr CIF Core dictionary](https://www.iucr.org/resources/cif/dictionaries/cif_core).

16. [CIF Core definition of `_refine_ls.extinction_method`](https://www.iucr.org/__data/iucr/cifdic_html/3/CORE_DIC/Irefine_ls.extinction_method.html)
    and [definition of `_refine_ls.extinction_coef`](https://www.iucr.org/__data/iucr/cifdic_html/3_orig/CORE_DIC/Irefine_ls.extinction_coef.html).

17. W. H. Zachariasen, *Acta Cryst.* **23** (1967), 558–564; A. C. Larson,
    *Acta Cryst.* **23** (1967), 664–665. These are the primary references for
    the commonly named Zachariasen/Larson extinction treatment.

18. P. J. Becker and P. Coppens, *Acta Cryst.* A**30** (1974), 129–147 and
    148–153. These papers define the Becker–Coppens extinction classifications
    and distributions.

19. G. M. Sheldrick, “Crystal structure refinement with SHELXL,” *Acta
    Cryst.* C**71** (2015), 3–8.
    [doi:10.1107/S2053229614024218](https://doi.org/10.1107/S2053229614024218).

    The [official SHELXL command
    list](https://shelx.uni-goettingen.de/shelxl_comlist.pdf) documents `FMAP 2`
    as an $F_o-F_c$ synthesis using calculated phases.

## Periodic electronic-structure programs

20. R. Dovesi *et al.*, *CRYSTAL23 User's Manual*, University of Torino
    (2023). [Official PDF](https://www.crystal.unito.it/include/manuals/crystal23.pdf)
    and [CRYSTAL documentation page](https://www.crystal.unito.it/documentation.html).

21. T. D. Kühne *et al.*, “CP2K: An electronic structure and molecular
    dynamics software package — Quickstep: Efficient and accurate electronic
    structure calculations,” *J. Chem. Phys.* **152** (2020), 194103.
    [doi:10.1063/5.0007045](https://doi.org/10.1063/5.0007045).

22. CP2K manual entries for
    [GAPW](https://manual.cp2k.org/trunk/methods/dft/gapw.html),
    [k points](https://manual.cp2k.org/trunk/methods/dft/k-points.html),
    [molecular-orbital/k-point output](https://manual.cp2k.org/trunk/methods/electronic_structure/molecular_orbitals.html),
    and [the `MO_KP` print section](https://manual.cp2k.org/trunk/CP2K_INPUT/FORCE_EVAL/DFT/PRINT/MO_KP.html).

## Basis and interchange formats

23. B. P. Pritchard, D. Altarawy, B. Didier, T. D. Gibson and T. L.
    Windus, “A New Basis Set Exchange: An Open, Up-to-Date Resource for the
    Molecular Sciences Community,” *J. Chem. Inf. Model.* **59** (2019),
    4814–4820.
    [doi:10.1021/acs.jcim.9b00725](https://doi.org/10.1021/acs.jcim.9b00725).

24. [Basis Set Exchange](https://www.basissetexchange.org/), used as a source
    of basis definitions subject to the program-specific conversion and
    all-electron/periodic restrictions described in this manual.

25. [TREXIO documentation](https://trex-coe.github.io/trexio/), for the
    interoperable periodic wavefunction container used by optional exports.

## Manual design references

26. [XD2015 manual](https://www.chem.gla.ac.uk/~louis/xd-home/docs/xd2015manual.pdf)
    and [XD2006 workshop manual](https://www.chem.gla.ac.uk/~louis/xdworkshop/workshop/documentation/xd2006manual.pdf),
    consulted for scientific-manual organization and crystallographic style.

27. [Gaussian keyword index](https://gaussian.com/keywords/) and
    [optimization keyword page](https://gaussian.com/opt/), consulted for the
    pattern of concise keyword definitions followed by examples. Gaussian
    input syntax in lamaGOET must still be checked against the manual for the
    installed licensed version.

## Citation practice

For a publication, cite lamaGOET, Tonto, the electronic-structure program,
the method/basis, and the methodological paper appropriate to the workflow.
Also report the actual repository revisions and executable versions. Citing a
software package does not replace disclosure of the options that define the
scientific calculation.
