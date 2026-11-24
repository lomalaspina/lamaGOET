"""Opt-in Multi-harmonic angular ADP controls (legacy input keys retained)."""
import json
from PySide6.QtWidgets import (QCheckBox, QComboBox, QFormLayout, QGroupBox, QLabel, QLineEdit, QSpinBox,
                              QWidget, QTableWidget, QTableWidgetItem, QPushButton, QHBoxLayout)


class CurvedControls(QGroupBox):
    def __init__(self, parent=None):
        super().__init__("Multi-harmonic angular ADP refinement - opt-in", parent)
        form = QFormLayout(self)
        self.model = QComboBox()
        for label, value in (("Off — ordinary ADPs / existing Gram–Charlier controls", "off"),
                             ("Two harmonic angular directions (9 displacement parameters)", "harmonic_surface"),
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
        self.auto_geometry = QCheckBox("Automatic bond geometry and starting values (recommended)")
        self.auto_geometry.setChecked(True)
        inner.addRow(self.auto_geometry)
        self.advanced = QCheckBox("Show advanced angular settings")
        inner.addRow(self.advanced)
        self.inner_form = inner
        self.fields = {}
        for key, label in (("CURVED_TARGET", "Target atom label"), ("CURVED_PIVOT", "Pivot label (optional if unique bonded neighbour)"),
                           ("CURVED_TRANSVERSE_1", "First direction T1,T2,T3 (radians)"),
                           ("CURVED_TRANSVERSE_2", "Second direction T1,T2,T3 (radians)"),
                           ("CURVED_PLANE_ANGLE", "Transverse frame angle (radians)"),
                           ("CURVED_REFERENCE", "Cartesian reference direction (x y z)"),
                           ("CURVED_PIVOT_SHIFT", "Pivot image translation (Cartesian Å)"),
                           ("CURVED_OUTPUT", "New result subdirectory")):
            self.fields[key] = QLineEdit()
            inner.addRow(label, self.fields[key])
        self.target_columns = ("target", "pivot", "model", "transverse_1", "transverse_2", "plane_angle", "reference", "pivot_shift")
        self.additional = QTableWidget(0, len(self.target_columns))
        self.additional.setHorizontalHeaderLabels(["Target", "Pivot", "Model", "T1 T2 T3 (rad)", "Second T1 T2 T3 (rad)",
                                                  "Frame angle (rad)", "Reference x y z", "Pivot shift (Å)"])
        self.additional.setMinimumHeight(145)
        inner.addRow("Additional independent targets", self.additional)
        buttons = QHBoxLayout()
        add = QPushButton("Add target")
        remove = QPushButton("Remove selected targets")
        buttons.addWidget(add); buttons.addWidget(remove)
        inner.addRow(buttons)
        add.clicked.connect(self._add_target_clicked)
        remove.clicked.connect(self.remove_targets)
        self.local = QCheckBox("Every starting target U is LOCAL Gaussian U, not a previous angular model's total U")
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
        simple_note = QLabel("For a terminal atom, normally select only its label. Automatic setup uses its unique bonded neighbour, "
                            "the correct lattice image and a numerical starting frame; the angular coefficients and orientation refine. "
                            "The compact harmonic option has 6 local U terms, 2 angular amplitudes and 1 orientation in a general position. "
                            "For water hydrogens choose each H as a target and the water O as pivot. "
                            "A central atom such as water O has no unique pivot: the model cannot infer a whole-water motion from that selection.")
        simple_note.setWordWrap(True);inner.addRow(simple_note)
        self.scope_note = QLabel(
            "Activates Tonto --curved-adp instead of the ordinary HAR loop. Uses the selected CIF, "
            "HKL, F² weights, merging, dispersion and H settings. All selected targets refine jointly, "
            "with shared structural parameters, one scale and cross-target parameter covariance. "
            "Add only independent atoms, not symmetry equivalents; site symmetry is enforced by Tonto. "
            "Shared pivots are allowed; this does not impose correlated physical motion. "
            "IAM ignores QM controls. HAR requires Tonto RHF/PBE/BLYP/B3LYP, "
            "singlet, complete molecule, no embedding/relativity. No periodic HAR, extinction, "
            "riding H, XCW or simultaneous Gram–Charlier. The native angular ADP solver controls "
            "convergence, not the ordinary solver widgets. Runs one CPU thread, with a 10 GiB "
            "address-space limit. Results are never overwritten. Small steps are not proof of convergence."
        )
        self.scope_note.setWordWrap(True)
        inner.addRow(self.scope_note)
        form.addRow(self.details)
        self.model.currentIndexChanged.connect(self._changed)
        self.source.currentIndexChanged.connect(self._changed)
        self.auto_geometry.toggled.connect(self._changed)
        self.advanced.toggled.connect(self._changed)
        self._changed()

    def _add_target_clicked(self):
        self.add_target()

    def add_target(self, row=None):
        if self.additional.rowCount() >= 63:
            return
        if row is None:
            row = dict(target="", pivot=self.fields["CURVED_PIVOT"].text(), model=self.model.currentData(),
                       transverse_1=self.fields["CURVED_TRANSVERSE_1"].text(), transverse_2=self.fields["CURVED_TRANSVERSE_2"].text(),
                       plane_angle=self.fields["CURVED_PLANE_ANGLE"].text(), reference=self.fields["CURVED_REFERENCE"].text(),
                       pivot_shift=self.fields["CURVED_PIVOT_SHIFT"].text())
        i = self.additional.rowCount(); self.additional.insertRow(i)
        for j, key in enumerate(self.target_columns):
            if key == "model":
                combo = QComboBox(); combo.addItems(["harmonic_surface", "planar", "surface"])
                combo.setCurrentText(row[key]); self.additional.setCellWidget(i, j, combo)
            else:
                self.additional.setItem(i, j, QTableWidgetItem(str(row[key])))

    def remove_targets(self):
        for row in sorted({index.row() for index in self.additional.selectedIndexes()}, reverse=True):
            self.additional.removeRow(row)

    def _changed(self):
        self.details.setVisible(self.model.currentData() != "off")
        automatic=self.auto_geometry.isChecked()
        show_advanced=self.advanced.isChecked() or not automatic
        for key in ("CURVED_TRANSVERSE_1", "CURVED_TRANSVERSE_2", "CURVED_PLANE_ANGLE", "CURVED_REFERENCE", "CURVED_PIVOT_SHIFT"):
            widget=self.fields[key]
            widget.setVisible(show_advanced);self.inner_form.labelForField(widget).setVisible(show_advanced)
            widget.setEnabled(not automatic and (key!="CURVED_TRANSVERSE_2" or self.model.currentData() in {"surface","harmonic_surface"}))
        for column in range(3,len(self.target_columns)):
            self.additional.setColumnHidden(column,not show_advanced)
        self.scope_note.setVisible(show_advanced)
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
        self.auto_geometry.setChecked(enabled(o["CURVED_AUTO_GEOMETRY"]))
        self.additional.setRowCount(0)
        for row in json.loads(o.get("CURVED_ADDITIONAL_TARGETS", "[]")):
            self.add_target(row)
        self._changed()

    def values(self):
        result = {key: widget.text().strip() for key, widget in self.fields.items()}
        result.update({key: str(widget.value()) for key, widget in self.bounds.items()})
        result.update(CURVED_MODEL=self.model.currentData(), CURVED_ELECTRONIC_SOURCE=self.source.currentData(),
                      CURVED_AUTO_GEOMETRY=str(self.auto_geometry.isChecked()).lower(),
                      CURVED_LOCAL_U_CONFIRMED=str(self.local.isChecked()).lower(),
                      CURVED_MOLECULE_CONFIRMED=str(self.molecule.isChecked()).lower())
        rows = []
        for i in range(self.additional.rowCount()):
            rows.append({key: (self.additional.cellWidget(i, j).currentText() if key == "model"
                              else self.additional.item(i, j).text().strip()) for j, key in enumerate(self.target_columns)})
        result["CURVED_ADDITIONAL_TARGETS"] = json.dumps(rows, separators=(",", ":"))
        return result
