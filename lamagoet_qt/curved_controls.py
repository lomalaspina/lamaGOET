"""Opt-in Multi-harmonic angular ADP controls (legacy input keys retained)."""
from PySide6.QtWidgets import QCheckBox, QComboBox, QFormLayout, QGroupBox, QLabel, QLineEdit, QSpinBox, QWidget


class CurvedControls(QGroupBox):
    def __init__(self, parent=None):
        super().__init__("Multi-harmonic angular ADP refinement - opt-in", parent)
        form = QFormLayout(self)
        self.model = QComboBox()
        for label, value in (("Off — ordinary ADPs / existing Gram–Charlier controls", "off"),
                             ("One transverse direction (planar)", "planar"),
                             ("Two transverse directions (surface)", "surface")):
            self.model.addItem(label, value)
        form.addRow("Displacement model", self.model)
        self.details = QWidget()
        inner = QFormLayout(self.details)
        self.source = QComboBox()
        self.source.addItem("IAM (spherical atoms; no SCF)", "iam")
        self.source.addItem("Single-density HAR (native restricted molecular SCF)", "molecular_hirshfeld")
        inner.addRow("Electronic scattering model", self.source)
        self.fields = {}
        for key, label in (("CURVED_TARGET", "Target atom label"), ("CURVED_PIVOT", "Bond pivot atom label"),
                           ("CURVED_TRANSVERSE_1", "First direction T1,T2,T3 (radians)"),
                           ("CURVED_TRANSVERSE_2", "Second direction T1,T2,T3 (radians)"),
                           ("CURVED_PLANE_ANGLE", "Transverse frame angle (radians)"),
                           ("CURVED_REFERENCE", "Cartesian reference direction (x y z)"),
                           ("CURVED_PIVOT_SHIFT", "Pivot image translation (Cartesian Å)"),
                           ("CURVED_OUTPUT", "New result subdirectory")):
            self.fields[key] = QLineEdit()
            inner.addRow(label, self.fields[key])
        self.local = QCheckBox("Starting target U is LOCAL Gaussian U, not a previous angular model's total U")
        self.molecule = QCheckBox("For HAR: CIF contains the complete molecule; no crystal fragment is missing")
        inner.addRow(self.local)
        inner.addRow(self.molecule)
        self.bounds = {}
        for key, label, upper in (("CURVED_MAX_CYCLES", "Maximum refinement cycles", 10000),
                                  ("CURVED_TIME_LIMIT", "Refinement time limit (s)", 86400),
                                  ("CURVED_JOB_TIMEOUT", "Whole job / SCF time limit (s)", 604800)):
            spin = QSpinBox(); spin.setRange(1, upper)
            self.bounds[key] = spin
            inner.addRow(label, spin)
        note = QLabel(
            "Activates Tonto --curved-adp instead of the ordinary HAR loop. Uses the selected CIF, "
            "HKL, F² weights, merging, dispersion and H settings. One target only; site symmetry is "
            "enforced by Tonto. IAM ignores QM controls. HAR requires Tonto RHF/PBE/BLYP/B3LYP, "
            "singlet, complete molecule, no embedding/relativity. No periodic HAR, extinction, "
            "riding H, XCW or simultaneous Gram–Charlier. The native angular ADP solver controls "
            "convergence, not the ordinary solver widgets. Runs one CPU thread, with a 10 GiB "
            "address-space limit. Results are never overwritten. Small steps are not proof of convergence."
        )
        note.setWordWrap(True)
        inner.addRow(note)
        form.addRow(self.details)
        self.model.currentIndexChanged.connect(self._changed)
        self.source.currentIndexChanged.connect(self._changed)
        self._changed()

    def _changed(self):
        self.details.setVisible(self.model.currentData() != "off")
        self.fields["CURVED_TRANSVERSE_2"].setEnabled(self.model.currentData() == "surface")
        self.molecule.setEnabled(self.source.currentData() == "molecular_hirshfeld")

    def load(self, options):
        from .options_schema import OPTION_DEFAULTS
        o = dict(OPTION_DEFAULTS, **options)
        for widget, key in ((self.model, "CURVED_MODEL"), (self.source, "CURVED_ELECTRONIC_SOURCE")):
            widget.setCurrentIndex(max(0, widget.findData(o[key])))
        for key, widget in self.fields.items():
            widget.setText(str(o[key]))
        for key, widget in self.bounds.items():
            widget.setValue(int(o[key]))
        from .curved_job import enabled
        self.local.setChecked(enabled(o["CURVED_LOCAL_U_CONFIRMED"]))
        self.molecule.setChecked(enabled(o["CURVED_MOLECULE_CONFIRMED"]))
        self._changed()

    def values(self):
        result = {key: widget.text().strip() for key, widget in self.fields.items()}
        result.update({key: str(widget.value()) for key, widget in self.bounds.items()})
        result.update(CURVED_MODEL=self.model.currentData(), CURVED_ELECTRONIC_SOURCE=self.source.currentData(),
                      CURVED_LOCAL_U_CONFIRMED=str(self.local.isChecked()).lower(),
                      CURVED_MOLECULE_CONFIRMED=str(self.molecule.isChecked()).lower())
        return result
