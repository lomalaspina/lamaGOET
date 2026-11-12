"""Read-only displacement-model viewer; no refinement settings are changed."""
from pathlib import Path
import math
import numpy as np
from PySide6.QtCore import QObject, QRunnable, QThreadPool, Signal, Qt
from PySide6.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QLabel, QSpinBox, QComboBox, QCheckBox
from .adp_cloud import CloudModel
from .crystal import Cell, DisplayAtom
from .viewer import StructureView


class _Signals(QObject):
    finished = Signal(object)
    failed = Signal(str)


class _BuildMesh(QRunnable):
    def __init__(self, model, probability):
        super().__init__()
        self.model, self.probability = model, probability
        self.signals = _Signals()

    def run(self):
        try:
            self.signals.finished.emit(self.model.surface(self.probability))
        except Exception as exc:
            self.signals.failed.emit(str(exc))


class AdpCloudDialog(QDialog):
    def __init__(self, path, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Displacement probability cloud — native Tonto model")
        self.resize(900, 760)
        self.model = CloudModel.read(path)
        self.mesh = None
        layout = QVBoxLayout(self)
        self.source = QLabel(f"{Path(path).resolve()}\nModel: {self.model.data['model']} — status: {self.model.data.get('fit_status', 'unknown')}")
        self.source.setWordWrap(True)
        self.source.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        layout.addWidget(self.source)
        row = QHBoxLayout()
        self.mode = QComboBox()
        self.mode.addItems(["Actual displacement probability cloud", "Equivalent second-moment ellipsoid"])
        self.mode.currentIndexChanged.connect(self._mode_changed)
        row.addWidget(self.mode)
        row.addWidget(QLabel("Enclosed probability"))
        self.probability = QSpinBox();self.probability.setRange(1, 99);self.probability.setValue(50);self.probability.setSuffix("%")
        self.probability.valueChanged.connect(self.rebuild)
        row.addWidget(self.probability);layout.addLayout(row)
        self.local_view = QCheckBox("Local environment within 4 Å of the modelled atom")
        self.local_view.setChecked(True);self.local_view.toggled.connect(self._set_structure)
        layout.addWidget(self.local_view)
        self.status = QLabel();self.status.setWordWrap(True);layout.addWidget(self.status)
        self.viewer = StructureView();self.viewer.show_labels = True;self.viewer.show_ellipsoids = True;self.viewer.show_cell = False
        layout.addWidget(self.viewer, 1)
        self._set_structure()
        self.rebuild()

    def _set_structure(self):
        vectors = self.model.direct.T
        lengths = np.linalg.norm(vectors, axis=1)
        angles = [math.degrees(math.acos(np.clip(np.dot(vectors[i], vectors[j]) / (lengths[i] * lengths[j]), -1, 1)))
                  for i, j in ((1, 2), (0, 2), (0, 1))]
        cell = Cell(*lengths, *angles, tuple(map(tuple, vectors)))
        atoms = []
        for i, a in enumerate(self.model.data["atoms"]):
            if self.local_view.isChecked() and np.linalg.norm(np.asarray(a["mean_cartesian"]) - self.model.mean) > 4:
                continue
            u = np.asarray(a["total_covariance"])
            six = tuple(u[r, c] for r, c in ((0, 0), (1, 1), (2, 2), (0, 1), (0, 2), (1, 2)))
            atoms.append(DisplayAtom(a["label"], a["element"], tuple(a["fractional"]), tuple(a["mean_cartesian"]),
                                     i, 0, occupancy=a["occupancy"], u_iso=float(np.trace(u) / 3), u_cartesian=six))
        self.viewer.set_structure(cell, atoms)
        self.viewer.show_probability_clouds = True
        if self.mesh is not None:
            self.viewer.set_probability_mesh(self.model.data["target_label"], self.mesh.vertices, self.mesh.faces)
            self._mode_changed()

    def _mode_changed(self):
        self.viewer.show_probability_clouds = self.mode.currentIndex() == 0 and self.mesh is not None
        self.viewer.ellipsoid_probability = float(self.probability.value())
        self.viewer.update()

    def rebuild(self):
        self.probability.setEnabled(False);self.mode.setEnabled(False)
        # Do not display the preceding percentage's cloud under a new label.
        self.mesh = None;self.viewer.probability_meshes.clear()
        self.viewer.setEnabled(False)
        self.viewer.setVisible(False)
        self.status.setText("Computing the normalized distribution and checking grid convergence…")
        self.worker = _BuildMesh(self.model, self.probability.value() / 100)
        self.worker.signals.finished.connect(self._completed)
        self.worker.signals.failed.connect(self._failed)
        QThreadPool.globalInstance().start(self.worker)

    def _completed(self, mesh):
        self.mesh = mesh
        self.viewer.set_probability_mesh(self.model.data["target_label"], mesh.vertices, mesh.faces)
        self.status.setText(f"Actual cloud: {100 * mesh.enclosed_mass:.2f}% enclosed; grid integral {mesh.integrated_mass:.6f}; "
                            f"{mesh.grid_size}³ grid. Surface level {mesh.level:.5g} Å⁻³. "
                            "The equivalent ellipsoid shows only the second moment, not this complete distribution.")
        self.probability.setEnabled(True);self.mode.setEnabled(True);self.viewer.setEnabled(True)
        self.viewer.setVisible(True)
        self._mode_changed()

    def _failed(self, message):
        self.status.setText("Cloud NOT displayed: " + message)
        self.probability.setEnabled(True)
        self.mesh = None;self.viewer.probability_meshes.clear();self.viewer.setEnabled(False)
        self.viewer.setVisible(False)
        # Keep the view disabled: no misleading ellipsoid fallback.
