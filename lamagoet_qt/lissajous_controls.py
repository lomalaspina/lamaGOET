"""Dimension-specific settings; no bond input or silent phase/randomness change."""
from PySide6.QtWidgets import QWidget, QFormLayout, QComboBox, QLineEdit, QLabel
from .lissajous_options import DEFAULTS, configuration


class LissajousControls(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.form = QFormLayout(self)
        self.dimensions = QComboBox()
        self.dimensions.addItem('2D trajectory + 3D Gaussian broadening', '2')
        self.dimensions.addItem('3D trajectory + 3D Gaussian broadening', '3')
        self.form.addRow('Lissajous dimensions', self.dimensions)
        self.fields = {}
        self.fields['LISSAJOUS_TARGET'] = QLineEdit()
        self.form.addRow('Target atom label (no bond or pivot)', self.fields['LISSAJOUS_TARGET'])
        for dim in (2, 3):
            for suffix, label in (
                    ('RATIO', 'Discrete winding ratio (not frequencies)'),
                    ('AMPLITUDES', 'Starting amplitudes (Å)'),
                    ('PHASES', 'Starting phase differences (rad)')):
                key = f'LISSAJOUS_{suffix}_{dim}D'
                field = QLineEdit(DEFAULTS[key]); self.fields[key] = field
                self.form.addRow(f'{dim}D — {label}', field)
        self.fields['LISSAJOUS_ORIENTATION'] = QLineEdit(DEFAULTS['LISSAJOUS_ORIENTATION'])
        self.form.addRow('Starting 3D orientation vector (rad)', self.fields['LISSAJOUS_ORIENTATION'])
        self.note = QLabel('')
        self.note.setWordWrap(True); self.form.addRow(self.note)
        self.dimensions.currentIndexChanged.connect(self._changed)
        self._changed()

    def _changed(self):
        dim = self.dimensions.currentData()
        for key, field in self.fields.items():
            visible = key.endswith(dim+'D') or key.endswith('ORIENTATION') or key.endswith('TARGET')
            field.setVisible(visible); self.form.labelForField(field).setVisible(visible)
        count = 2*int(dim)+2
        self.note.setText(f'{count} shape parameters plus the local Gaussian U tensor before site/data rank reductions. '
                          'The last phase fixes the time origin. All coordinates share one phase; '
                          'no phonon calculation or absolute-frequency estimate is made. '
                          'Both choices give a volumetric distribution after Gaussian broadening. '
                          'Experimental opt-in: one target, with site symmetry enforced. '
                          'Choose a discrete ratio; it is not a refined physical frequency. '
                          'A failed or rank-deficient fit is not a usable refined model.')

    def load(self, options):
        o = DEFAULTS | options
        dim = str(o['LISSAJOUS_DIMENSIONS'])
        if dim not in {'2', '3'}:
            raise ValueError('Invalid saved Lissajous dimension; expected 2 or 3')
        self.dimensions.setCurrentIndex(self.dimensions.findData(dim))
        for key, field in self.fields.items():
            field.setText(str(o[key]))
        self._changed()

    def values(self):
        return {'LISSAJOUS_DIMENSIONS': self.dimensions.currentData(),
                **{key: field.text().strip() for key, field in self.fields.items()}}

    def configuration(self):
        return configuration(self.values())
