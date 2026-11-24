"""Opt-in Multi-harmonic angular ADP controls (legacy input keys retained)."""
import json
from PySide6.QtWidgets import (QCheckBox, QComboBox, QFormLayout, QGroupBox, QLabel, QLineEdit, QSpinBox,
                              QWidget, QTableWidget, QTableWidgetItem, QPushButton, QHBoxLayout,
                              QDialog, QDialogButtonBox, QMessageBox, QHeaderView, QLayout)
from PySide6.QtCore import Qt, QTimer


class _TargetTable(QTableWidget):
    def minimumSizeHint(self):
        # QTableView's hint can be smaller than an explicit minimumHeight.
        # QFormLayout then budgets too little space when advanced rows expand.
        return super().minimumSizeHint().expandedTo(self.minimumSize())


class CurvedControls(QGroupBox):
    def __init__(self, parent=None):
        super().__init__("Multi-harmonic angular ADP refinement - opt-in", parent)
        self.structure_loader = None
        form = QFormLayout(self)
        form.setSizeConstraint(QLayout.SizeConstraint.SetMinimumSize)
        self.model = QComboBox()
        for label, value in (("Off — ordinary ADPs / existing Gram–Charlier controls", "off"),
                             ("Target only — free orientation and curvature (up to 16 displacement parameters)", "free_surface"),
                             ("Two harmonic angular directions (9 displacement parameters)", "harmonic_surface"),
                             ("One transverse direction (planar)", "planar"),
                             ("Two transverse directions (surface)", "surface")):
            self.model.addItem(label, value)
        form.addRow("Displacement model", self.model)
        self.details = QWidget()
        inner = QFormLayout(self.details)
        inner.setSizeConstraint(QLayout.SizeConstraint.SetNoConstraint)
        self.source = QComboBox()
        self.source.addItem("IAM (spherical atoms; no SCF)", "iam")
        self.source.addItem("Single-density HAR (native restricted molecular SCF)", "molecular_hirshfeld")
        inner.addRow("Electronic scattering model", self.source)
        self.auto_geometry = QCheckBox("Determine bond and directions automatically (recommended)")
        self.auto_geometry.setChecked(True)
        inner.addRow(self.auto_geometry)
        self.default_starts = QCheckBox("Use suggested starting coefficients (not restraints)")
        self.default_starts.setChecked(True)
        inner.addRow(self.default_starts)
        self.advanced = QCheckBox("Show advanced angular settings")
        inner.addRow(self.advanced)
        self.inner_form = inner
        self.fields = {}
        for key, label in (("CURVED_TARGET", "Target atom label"), ("CURVED_PIVOT", "Pivot label (optional if unique bonded neighbour)"),
                           ("CURVED_TRANSVERSE_1", "Direction 1 starting coefficients T1,T2,T3 (rad)"),
                           ("CURVED_TRANSVERSE_2", "Direction 2 starting coefficients T1,T2,T3 (rad)"),
                           ("CURVED_PLANE_ANGLE", "Starting transverse orientation (rad)"),
                           ("CURVED_ORIENTATION", "Starting 3D rotation vector (rad)"),
                           ("CURVED_MEAN_LENGTH", "Starting mean radial length (Å; refined, not a bond length)"),
                           ("CURVED_REFERENCE", "Cartesian reference direction (x y z)"),
                           ("CURVED_PIVOT_SHIFT", "Pivot image translation (Cartesian Å)"),
                           ("CURVED_OUTPUT", "New result subdirectory")):
            self.fields[key] = QLineEdit()
            inner.addRow(label, self.fields[key])
        choose=QPushButton("Choose target atom and bonded neighbour…")
        self.choose_button=choose
        choose.clicked.connect(lambda: self.choose_bond())
        inner.addRow(choose)
        self.target_columns = ("target", "pivot", "model", "transverse_1", "transverse_2", "plane_angle", "reference", "pivot_shift", "orientation", "mean_length")
        self.additional = _TargetTable(0, len(self.target_columns))
        self.additional.setHorizontalHeaderLabels(["Target", "Pivot", "Model", "T1 T2 T3 (rad)", "Second T1 T2 T3 (rad)",
                                                  "Frame angle (rad)", "Reference x y z", "Pivot shift (Å)", "3D rotation (rad)", "Mean radial length (Å)"])
        self.additional.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        self.additional.setMinimumHeight(145)
        inner.addRow("Additional independent targets", self.additional)
        buttons = QHBoxLayout()
        add = QPushButton("Add target")
        remove = QPushButton("Remove selected targets")
        buttons.addWidget(add); buttons.addWidget(remove)
        choose_extra=QPushButton("Choose atom/bond for selected row…")
        self.choose_extra_button=choose_extra
        buttons.addWidget(choose_extra)
        inner.addRow(buttons)
        add.clicked.connect(self._add_target_clicked)
        remove.clicked.connect(self.remove_targets)
        choose_extra.clicked.connect(self._choose_extra)
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
                            "Multiply bonded atoms are supported: use the atom/bond selector to choose a reference neighbour. "
                            "A chosen bond is a model assumption, not a whole-water or collective motion constraint.")
        simple_note.setWordWrap(True);inner.addRow(simple_note)
        self.simple_note=simple_note;self.bond_note_text=simple_note.text()
        self.starts_note = QLabel("Starting coefficients are free to change during refinement; no restraint penalty is added. "
                                 "To edit them, clear 'Use suggested starting coefficients'. Automatic bond geometry can remain enabled. "
                                 "No starting set is known to be optimal for every structure; check convergence and sensitivity to other starts.")
        self.starts_note.setWordWrap(True);inner.addRow(self.starts_note)
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
        self.default_starts.toggled.connect(self._changed)
        self.advanced.toggled.connect(self._changed)
        self._changed()

    def _sync_height(self):
        # A QFormLayout's minimumSize omits the full wrapped-label height.
        # Preserve its height-for-width so a containing scroll area scrolls,
        # rather than laying later controls over the minimum-height table.
        height=self.inner_form.totalHeightForWidth(self.details.width())
        if height>0 and self.details.minimumHeight()!=height:
            self.details.setMinimumHeight(height)

    def resizeEvent(self,event):
        super().resizeEvent(event)
        QTimer.singleShot(0,self._sync_height)

    def _add_target_clicked(self):
        self.add_target()

    def add_target(self, row=None):
        if self.additional.rowCount() >= 63:
            return
        if row is not None and row.get('model')=='free_surface':
            from .curved_job import suggested_angular_starts
            row=dict(pivot='',reference='0 0 1',pivot_shift='0 0 0',**suggested_angular_starts('free_surface'))|row
        if row is None:
            row = dict(target="", pivot="" if self.auto_geometry.isChecked() else self.fields["CURVED_PIVOT"].text(), model=self.model.currentData(),
                       transverse_1=self.fields["CURVED_TRANSVERSE_1"].text(), transverse_2=self.fields["CURVED_TRANSVERSE_2"].text(),
                       plane_angle=self.fields["CURVED_PLANE_ANGLE"].text(), reference=self.fields["CURVED_REFERENCE"].text(),
                       pivot_shift=self.fields["CURVED_PIVOT_SHIFT"].text(),orientation=self.fields['CURVED_ORIENTATION'].text(),
                       mean_length=self.fields['CURVED_MEAN_LENGTH'].text())
        i = self.additional.rowCount(); self.additional.insertRow(i)
        for j, key in enumerate(self.target_columns):
            if key == "model":
                combo = QComboBox(); combo.addItems(["harmonic_surface", "planar", "surface", "free_surface"])
                combo.setCurrentText(row[key]); self.additional.setCellWidget(i, j, combo)
                combo.currentTextChanged.connect(self._changed)
            else:
                self.additional.setItem(i, j, QTableWidgetItem(str(row.get(key,{'orientation':'0 0 0','mean_length':'1'}.get(key,'')))))
        self._changed()

    def remove_targets(self):
        for row in sorted({index.row() for index in self.additional.selectedIndexes()}, reverse=True):
            self.additional.removeRow(row)

    def _choose_extra(self):
        row=self.additional.currentRow()
        if row<0:
            QMessageBox.information(self,"Angular target","Select an additional-target row first.")
            return
        self.choose_bond(row)

    def choose_bond(self, row=None):
        """Select a neighbour from all bonds; do not rank bonds as preferred axes."""
        try:
            if self.structure_loader is None:
                raise ValueError("Select an input CIF first.")
            structure=self.structure_loader()
        except Exception as exc:
            QMessageBox.warning(self,"Angular connectivity",str(exc));return
        model=self.model.currentData() if row is None else self.additional.cellWidget(row,2).currentText()
        if model=='free_surface':
            dialog=QDialog(self);dialog.setWindowTitle("Target-only ADP — choose atom")
            layout=QFormLayout(dialog);targets=QComboBox()
            targets.addItems([a.label for a in structure.asymmetric_atoms])
            current=self.fields['CURVED_TARGET'].text() if row is None else self.additional.item(row,0).text()
            if targets.findText(current)>=0:targets.setCurrentText(current)
            layout.addRow('Target atom (any connectivity)',targets)
            note=QLabel('No bond or pivot is assigned. Orientation and curvature refine; the whole distribution obeys site symmetry.')
            note.setWordWrap(True);layout.addRow(note)
            buttons=QDialogButtonBox(QDialogButtonBox.StandardButton.Ok|QDialogButtonBox.StandardButton.Cancel)
            layout.addRow(buttons);buttons.accepted.connect(dialog.accept);buttons.rejected.connect(dialog.reject)
            if dialog.exec()==QDialog.DialogCode.Accepted:
                if row is None:self.fields['CURVED_TARGET'].setText(targets.currentText())
                else:self.additional.item(row,0).setText(targets.currentText())
            return
        from .curved_job import angular_bond_candidates
        dialog=QDialog(self);dialog.setWindowTitle("Angular ADP — atom and reference bond")
        layout=QFormLayout(dialog)
        targets=QComboBox();targets.addItems([a.label for a in structure.asymmetric_atoms])
        current=self.fields['CURVED_TARGET'].text() if row is None else self.additional.item(row,0).text()
        index=targets.findText(current)
        if index>=0:targets.setCurrentIndex(index)
        pivots=QComboBox();note=QLabel();note.setWordWrap(True)
        layout.addRow("Target atom (any element)",targets);layout.addRow("Reference bonded neighbour",pivots)
        layout.addRow(note)
        buttons=QDialogButtonBox(QDialogButtonBox.StandardButton.Ok|QDialogButtonBox.StandardButton.Cancel)
        layout.addRow(buttons);buttons.rejected.connect(dialog.reject);buttons.accepted.connect(dialog.accept)
        def refresh():
            pivots.clear()
            try: candidates=angular_bond_candidates(structure,targets.currentText())
            except ValueError as exc:
                note.setText(str(exc));buttons.button(QDialogButtonBox.StandardButton.Ok).setEnabled(False);return
            counts={p['pivot']:sum(q['pivot']==p['pivot'] for q in candidates) for p in candidates}
            if len(candidates)>1:pivots.addItem("Choose a reference bond — none selected automatically",None)
            for candidate in candidates:
                supported=candidate['supported'] and counts[candidate['pivot']]==1
                label=f"{candidate['pivot']}   {candidate['distance']:.4f} Å"
                if not supported:label += "  (image not supported by automatic setup)"
                pivots.addItem(label,candidate['pivot'] if supported else None)
            note.setText("Connectivity uses Tonto-compatible covalent radii and periodic images. "
                         "All bonded neighbours are listed, including for non-terminal atoms. "
                         "The selected bond defines this angular model's geometry; it is not a restraint. "
                         "For several chemically plausible bonds, compare alternatives. "
                         + ("No bonded neighbour found: this bond-anchored model cannot invent a pivot." if not candidates else ""))
            selection_changed()
        def selection_changed():
            buttons.button(QDialogButtonBox.StandardButton.Ok).setEnabled(pivots.currentData() is not None)
        targets.currentTextChanged.connect(refresh);pivots.currentIndexChanged.connect(selection_changed)
        refresh()
        if dialog.exec()!=QDialog.DialogCode.Accepted:return
        if pivots.currentData() is None:return
        if row is None:
            self.fields['CURVED_TARGET'].setText(targets.currentText())
            self.fields['CURVED_PIVOT'].setText(pivots.currentData())
        else:
            self.additional.item(row,0).setText(targets.currentText())
            self.additional.item(row,1).setText(pivots.currentData())
        self.auto_geometry.setChecked(True)

    def _changed(self):
        self.details.setVisible(self.model.currentData() != "off")
        automatic=self.auto_geometry.isChecked()
        defaults=self.default_starts.isChecked()
        free=self.model.currentData()=='free_surface'
        any_bond=not free or any(self.additional.cellWidget(r,2) is not None and self.additional.cellWidget(r,2).currentText()!='free_surface'
                                for r in range(self.additional.rowCount()))
        any_free=free or any(self.additional.cellWidget(r,2) is not None and self.additional.cellWidget(r,2).currentText()=='free_surface'
                            for r in range(self.additional.rowCount()))
        self.auto_geometry.setVisible(any_bond)
        self.choose_button.setText('Choose target atom…' if free else 'Choose target atom and bonded neighbour…')
        self.choose_extra_button.setText('Choose atom/bond for selected row…' if any_bond else 'Choose atom for selected row…')
        self.simple_note.setText('Target-only model: select the atom, without a bond or pivot. Six angular coefficients, '
            'three orientation coordinates and one positive mean radial length refine together with local Gaussian U '
            '(at most 16 displacement parameters). The full distribution obeys site symmetry. Symmetry and the data '
            'can reduce independent information; rank-deficient fits must fail rather than invent uncertainties. '
            'The radial length is not a bond length. Numerical starts are editable under Advanced settings.' if free else self.bond_note_text)
        show_advanced=self.advanced.isChecked() or (any_bond and not automatic) or not defaults
        if defaults and self.model.currentData() != "off":
            from .curved_job import suggested_angular_starts
            seeds=suggested_angular_starts(self.model.currentData())
            for key, field in (("transverse_1","CURVED_TRANSVERSE_1"), ("transverse_2","CURVED_TRANSVERSE_2"),
                               ("plane_angle","CURVED_PLANE_ANGLE")):
                self.fields[field].setText(seeds[key])
            if free:
                self.fields['CURVED_ORIENTATION'].setText(seeds['orientation'])
                self.fields['CURVED_MEAN_LENGTH'].setText(seeds['mean_length'])
            for row in range(self.additional.rowCount()):
                if self.additional.cellWidget(row,2) is None or self.additional.item(row,7) is None:
                    continue
                seeds=suggested_angular_starts(self.additional.cellWidget(row,2).currentText())
                for col, key in ((3,"transverse_1"),(4,"transverse_2"),(5,"plane_angle")):
                    self.additional.item(row,col).setText(seeds[key])
                if 'orientation' in seeds and self.additional.item(row,9) is not None:
                    self.additional.item(row,8).setText(seeds['orientation'])
                    self.additional.item(row,9).setText(seeds['mean_length'])
        for key in ("CURVED_PIVOT","CURVED_TRANSVERSE_1", "CURVED_TRANSVERSE_2", "CURVED_PLANE_ANGLE", "CURVED_REFERENCE", "CURVED_PIVOT_SHIFT",
                    "CURVED_ORIENTATION","CURVED_MEAN_LENGTH"):
            widget=self.fields[key]
            visible=show_advanced
            if key=='CURVED_PIVOT':visible=not free
            elif key in {'CURVED_REFERENCE','CURVED_PIVOT_SHIFT','CURVED_PLANE_ANGLE'}:visible=visible and not free
            elif key in {'CURVED_ORIENTATION','CURVED_MEAN_LENGTH'}:visible=visible and free
            widget.setVisible(visible);self.inner_form.labelForField(widget).setVisible(visible)
            editable=not automatic if key in {"CURVED_REFERENCE","CURVED_PIVOT_SHIFT"} else not defaults
            if key=='CURVED_PIVOT':editable=True
            widget.setEnabled(editable and (key!="CURVED_TRANSVERSE_2" or self.model.currentData() in {"surface","harmonic_surface","free_surface"}))
        self.additional.setColumnHidden(1,free and not any_bond)
        for column in range(3,len(self.target_columns)):
            visible=show_advanced and (any_bond if column in {5,6,7} else any_free if column in {8,9} else True)
            self.additional.setColumnHidden(column,not visible)
            for row in range(self.additional.rowCount()):
                item=self.additional.item(row,column)
                if item is None:continue
                editable=not automatic if column in {6,7} else not defaults
                row_free=self.additional.cellWidget(row,2).currentText()=='free_surface'
                if column in {5,6,7} and row_free:editable=False
                if column in {8,9} and not row_free:editable=False
                item.setFlags((item.flags() | Qt.ItemFlag.ItemIsEditable) if editable
                              else (item.flags() & ~Qt.ItemFlag.ItemIsEditable))
        self.starts_note.setVisible(show_advanced)
        self.scope_note.setVisible(show_advanced)
        self.molecule.setEnabled(self.source.currentData() == "molecular_hirshfeld")
        QTimer.singleShot(0,self._sync_height)

    def load(self, options):
        from .options_schema import complete_job_options
        o = complete_job_options(options)
        # Signals can update default displays. Set modes before loading saved
        # manual coefficients, which must never be replaced during a reload.
        from .curved_job import enabled, default_starts_enabled
        self.default_starts.setChecked(default_starts_enabled(o))
        self.auto_geometry.setChecked(enabled(o["CURVED_AUTO_GEOMETRY"]))
        for widget, key in ((self.model, "CURVED_MODEL"), (self.source, "CURVED_ELECTRONIC_SOURCE")):
            widget.setCurrentIndex(max(0, widget.findData(o[key])))
        for key, widget in self.fields.items():
            widget.setText(str(o[key]))
        for key, widget in self.bounds.items():
            widget.setValue(int(o[key]))
        self.local.setChecked(enabled(o["CURVED_LOCAL_U_CONFIRMED"]))
        self.molecule.setChecked(enabled(o["CURVED_MOLECULE_CONFIRMED"]))
        self.additional.setRowCount(0)
        for row in json.loads(o.get("CURVED_ADDITIONAL_TARGETS", "[]")):
            self.add_target(row)
        self._changed()

    def values(self):
        result = {key: widget.text().strip() for key, widget in self.fields.items()}
        result.update({key: str(widget.value()) for key, widget in self.bounds.items()})
        result.update(CURVED_MODEL=self.model.currentData(), CURVED_ELECTRONIC_SOURCE=self.source.currentData(),
                      CURVED_AUTO_GEOMETRY=str(self.auto_geometry.isChecked()).lower(),
                      CURVED_DEFAULT_STARTS=str(self.default_starts.isChecked()).lower(),
                      CURVED_LOCAL_U_CONFIRMED=str(self.local.isChecked()).lower(),
                      CURVED_MOLECULE_CONFIRMED=str(self.molecule.isChecked()).lower())
        rows = []
        for i in range(self.additional.rowCount()):
            row={key: (self.additional.cellWidget(i, j).currentText() if key == "model"
                       else self.additional.item(i, j).text().strip()) for j, key in enumerate(self.target_columns)}
            if row['model']!='free_surface':
                row.pop('orientation');row.pop('mean_length')
            rows.append(row)
        result["CURVED_ADDITIONAL_TARGETS"] = json.dumps(rows, separators=(",", ":"))
        return result
