"""Target-only positive ADP starts; no bond, ratio or shared-phase input."""
from PySide6.QtWidgets import QWidget, QFormLayout, QLineEdit, QComboBox, QCheckBox, QLabel
from .positive_options import DEFAULTS, configuration

class PositiveControls(QWidget):
    def __init__(self,parent=None):
        super().__init__(parent)
        self.model='shared_u_mixture';self.form=QFormLayout(self);self.fields={}
        self.target=QLineEdit();self.fields['POSITIVE_TARGET']=self.target
        self.form.addRow('Target atom label (no bond or pivot)',self.target)
        self.advanced=QCheckBox('Edit starting values (free parameters, not restraints)')
        self.form.addRow(self.advanced)
        self.auto=QCheckBox('Start along largest principal axis of local U')
        self.auto.setChecked(True);self.form.addRow(self.auto)
        self.dimensions=QComboBox()
        self.dimensions.addItem('Two independent axes + 3D Gaussian broadening','2')
        self.dimensions.addItem('Three independent axes + 3D Gaussian broadening','3')
        self.dimensions.setCurrentIndex(1);self.form.addRow('Independent-phase dimensions',self.dimensions)
        labels={'MIXTURE_POPULATION':'Starting population w',
                'MIXTURE_INITIAL_SEPARATION':'Automatic starting separation length (Å)',
                'MIXTURE_SEPARATION':'Explicit starting separation vector (Å)',
                'OVERTONE_ORIENTATION':'Starting 3D orientation vector (rad)'}
        for dim in (2,3):
            labels.update({f'OVERTONE_AMPLITUDES_{dim}D':f'{dim}D starting fundamental amplitudes (Å)',
                           f'OVERTONE_COEFFICIENTS_{dim}D':f'{dim}D starting signed overtones (Å)',
                           f'OVERTONE_ENABLED_{dim}D':f'{dim}D refine overtones (true/false per axis)'})
        for key,label in labels.items():
            self.fields[key]=QLineEdit(DEFAULTS[key]);self.form.addRow(label,self.fields[key])
        self.note=QLabel();self.note.setWordWrap(True);self.form.addRow(self.note)
        self.advanced.toggled.connect(self._changed);self.auto.toggled.connect(self._changed)
        self.dimensions.currentIndexChanged.connect(self._changed);self._changed()
    def set_model(self,model):
        self.model=model;self._changed()
    def _changed(self):
        mixture=self.model=='shared_u_mixture';advanced=self.advanced.isChecked()
        self.form.setRowVisible(self.auto,mixture and advanced)
        self.form.setRowVisible(self.dimensions,not mixture)
        for key,field in self.fields.items():
            visible=key=='POSITIVE_TARGET'
            if advanced and key.startswith('MIXTURE_') and mixture:
                visible=key!='MIXTURE_SEPARATION' or not self.auto.isChecked()
                if key=='MIXTURE_INITIAL_SEPARATION':visible=self.auto.isChecked()
            if advanced and key.startswith('OVERTONE_') and not mixture:
                visible=key.endswith(self.dimensions.currentData()+'D') or key=='OVERTONE_ORIENTATION'
            self.form.setRowVisible(field,visible)
        self.note.setText(
            'Two Gaussians share one local U and a refined mean; four shape parameters plus six local U terms at a general site. '
            'The automatic direction is only a numerical start; separation and population refine freely. '
            'Population can be weak or branch-dependent, not a measured microscopic occupancy.'
            if mixture else
            'Independent phases on different axes; a fundamental and enabled second harmonic on each axis. '
            'The default one-overtone 3D choice has seven shape parameters plus six local U terms. '
            'No frequency ratio or inter-axis phase is fitted. Unrestricted measured CuCl trials did not converge; this remains experimental.'
        )
    def load(self,options):
        o=DEFAULTS|options
        self.auto.setChecked(str(o['MIXTURE_AUTO_DIRECTION']).lower()=='true')
        dim=str(o['OVERTONE_DIMENSIONS'])
        if dim not in {'2','3'}:raise ValueError('Invalid saved independent-phase dimension')
        self.dimensions.setCurrentIndex(self.dimensions.findData(dim))
        for key,field in self.fields.items():field.setText(str(o[key]))
        self._changed()
    def values(self):
        return {**{key:field.text().strip() for key,field in self.fields.items()},
                'MIXTURE_AUTO_DIRECTION':str(self.auto.isChecked()).lower(),
                'OVERTONE_DIMENSIONS':self.dimensions.currentData()}
    def configuration(self):
        return configuration(self.values()|{'CURVED_MODEL':self.model})
