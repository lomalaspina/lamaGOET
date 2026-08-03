"""Main Qt window for lamaGOET."""

from __future__ import annotations

from collections import OrderedDict
import os
from pathlib import Path
import re
import signal
import shutil
import subprocess

from PySide6.QtCore import QTimer, Qt
from PySide6.QtGui import QAction
from PySide6.QtWidgets import (
    QApplication,
    QButtonGroup,
    QCheckBox,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QDoubleSpinBox,
    QFileDialog,
    QFormLayout,
    QFrame,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPlainTextEdit,
    QPushButton,
    QRadioButton,
    QScrollArea,
    QSpinBox,
    QSplitter,
    QStatusBar,
    QTabWidget,
    QToolBar,
    QVBoxLayout,
    QWidget,
)

from .basis_exchange import (
    BasisExchangeError,
    all_electron_basis_names,
    common_preferred_basis,
    render_mixed_basis,
)
from .cluster import SubmissionError, write_pbs_script
from .crystal import (
    CifError,
    CrystalStructure,
    DisplayAtom,
    crystal23_spacegroup_record,
    write_grown_cif,
)
from .job_options import cp2k_basis_names, load_job_options, save_job_options
from .viewer import StructureView


PROGRAMS = (
    ("Gaussian", "Gaussian"),
    ("Orca", "Orca"),
    ("OCC", "OCC"),
    ("Tonto", "Tonto"),
    ("ELMO database", "elmodb"),
    ("CP2K periodic (all-electron GAPW)", "CP2K"),
    ("Crystal23", "Crystal14"),
    ("SC cluster optimization: Gaussian + Tonto", "optgaussian"),
    ("SC cluster optimization: Orca + Tonto", "optorca"),
)

METHODS = {
    "Gaussian": (
        "rhf", "uhf", "rohf", "rks", "uks", "blyp", "ublyp", "b3lyp",
        "ub3lyp", "b3pw91", "pbe", "pbe0", "bp86", "tpss", "tpssh",
        "m06", "m06-2x", "wb97xd",
    ),
    "Orca": (
        "RHF", "UHF", "ROHF", "RKS", "UKS", "BLYP", "B3LYP", "BP86",
        "PBE", "PBE0", "TPSS", "TPSSh", "M06", "M06-2X", "wB97X-D3",
        "wB97X-V",
    ),
    "OCC": ("rhf", "uhf", "rks", "uks", "blyp", "b3lyp", "pbe", "pbe0"),
    "Tonto": ("rhf", "uhf", "rks", "uks", "blyp", "b3lyp"),
    "Crystal14": (
        "rhf", "uhf", "PBE", "BLYP", "B3LYP", "B3PW", "PBE0", "HSE06",
        "PBESOL", "PBESOL0", "SCAN", "R2SCAN", "M06L", "M06", "M062X",
    ),
}
METHODS["optgaussian"] = METHODS["Gaussian"]
METHODS["optorca"] = METHODS["Orca"]
METHODS["elmodb"] = METHODS["Tonto"]

GAUSSIAN_BASIS = (
    "STO-3G", "STO-6G", "3-21G", "3-21G(d)", "3-21++G(d)", "4-31G",
    "6-21G", "6-31G", "6-31G(d)", "6-31G(d,p)", "6-31G(2d)",
    "6-31G(2d,p)", "6-31G(2df,p)", "6-31G(2df,2p)", "6-31+G",
    "6-31+G(d)", "6-31+G(d,p)", "6-31++G", "6-31++G(d)",
    "6-31++G(d,p)", "6-311G", "6-311G(d)", "6-311G(d,p)",
    "6-311G(2d,p)", "6-311G(2d,2p)", "6-311G(2df,2p)",
    "6-311G(2df,2pd)", "6-311+G(d)", "6-311+G(d,p)",
    "6-311++G(d,p)", "6-311++G(2d,2p)", "D95", "D95V", "D95V+",
    "D95++", "SHC", "CEP-4G", "CEP-31G", "CEP-121G", "LANL2MB",
    "LANL2DZ", "SDD", "DGDZVP", "DGDZVP2", "DGTZVP", "MIDI", "UGBS",
    "EPR-II", "EPR-III", "cc-pVDZ", "cc-pVTZ", "cc-pVQZ", "cc-pV5Z",
    "cc-pV6Z", "aug-cc-pVDZ", "aug-cc-pVTZ", "aug-cc-pVQZ",
    "aug-cc-pV5Z", "aug-cc-pV6Z", "cc-pCVDZ", "cc-pCVTZ", "cc-pCVQZ",
    "aug-cc-pCVDZ", "aug-cc-pCVTZ", "aug-cc-pCVQZ", "Def2SVP",
    "Def2TZVP", "Def2TZVPP", "Def2QZVP", "Def2QZVPP", "Gen", "GenECP",
)

ORCA_BASIS = (
    "STO-3G", "MINI", "MINIS", "MINIX", "MIDI", "3-21G", "3-21GSP",
    "4-22GSP", "6-31G", "6-31G(d)", "6-31G(d,p)", "6-31G(2d)",
    "6-31G(2d,p)", "6-31G(2d,2p)", "6-31G(2df)", "6-31G(2df,2p)",
    "6-31+G(d)", "6-31++G(d,p)", "6-311G", "6-311G(d)",
    "6-311G(d,p)", "6-311++G(d,p)", "SV", "SV(P)", "SVP", "TZV",
    "TZV(P)", "TZVP", "TZVPP", "QZVP", "def2-SV(P)", "def2-SVP",
    "def2-SVPD", "def2-TZVP", "def2-TZVPP", "def2-TZVPD",
    "def2-TZVPPD", "def2-QZVP", "def2-QZVPP", "def2-QZVPD",
    "def2-QZVPPD", "ma-def2-SVP", "ma-def2-TZVP", "ma-def2-TZVPP",
    "cc-pVDZ", "cc-pVTZ", "cc-pVQZ", "cc-pV5Z", "cc-pV6Z",
    "aug-cc-pVDZ", "aug-cc-pVTZ", "aug-cc-pVQZ", "aug-cc-pV5Z",
    "cc-pCVDZ", "cc-pCVTZ", "cc-pCVQZ", "cc-pwCVDZ", "cc-pwCVTZ",
    "cc-pwCVQZ", "pc-0", "pc-1", "pc-2", "pc-3", "pc-4", "aug-pc-0",
    "aug-pc-1", "aug-pc-2", "aug-pc-3", "Sapporo-DZP-2012",
    "Sapporo-TZP-2012", "Sapporo-QZP-2012", "Partridge-1", "Partridge-2",
    "Partridge-3", "Partridge-4", "x2c-SVPall", "x2c-TZVPall",
    "x2c-TZVPPall", "x2c-QZVPall", "ZORA-def2-SVP", "ZORA-def2-TZVP",
    "ZORA-def2-TZVPP", "DKH-def2-SVP", "DKH-def2-TZVP",
    "DKH-def2-TZVPP",
)

TONTO_BASIS = (
    "STO-3G", "3-21G", "6-31G(d)", "6-31G(d,p)", "6-311++G(2d,2p)",
    "6-311G(d,p)", "ahlrichs-polarization", "aug-cc-pVDZ",
    "aug-cc-pVQZ", "aug-cc-pVTZ", "cc-pVDZ", "cc-pVQZ", "cc-pVTZ",
    "Clementi-Roetti", "Coppens", "def2-SVP", "def2-SV(P)", "def2-TZVP",
    "def2-TZVPP", "DZP", "DZP-DKH", "pVDZ-Ahlrichs", "pob-TZVP-rev2",
    "Sadlej+", "Sadlej-PVTZ", "Spackman-DZP+", "Thakkar", "TZP-DKH",
    "vanLenthe-Baerends", "VTZ-Ahlrichs",
)

BASIS = {
    "Gaussian": GAUSSIAN_BASIS,
    "Orca": ORCA_BASIS,
    "OCC": ("STO-3G", "3-21G", "6-31G", "6-31G(d)", "cc-pVDZ", "cc-pVTZ"),
    "Tonto": TONTO_BASIS,
    "elmodb": TONTO_BASIS,
    "Crystal14": (
        "STO-3G", "STO-6G", "POB-DZVP", "POB-DZVPP", "POB-TZVP",
        "POB-DZVP-REV2", "POB-TZVP-REV2",
    ),
}

CP2K_FUNCTIONALS = (
    "BLYP", "BP", "PADE", "LDA", "PBE", "TPSS", "HCTH120", "OLYP", "BEEFVDW"
)


def _editable_combo() -> QComboBox:
    widget = QComboBox()
    widget.setEditable(True)
    widget.setInsertPolicy(QComboBox.InsertPolicy.NoInsert)
    return widget


def re_is_cif_path(path: Path) -> bool:
    return path.name.lower().endswith((".cif", ".cif1", ".cif2"))


def _bool_text(value: bool) -> str:
    return "true" if value else "false"


class MainWindow(QMainWindow):
    def __init__(
        self,
        option_path: str | Path = "job_options.txt",
        *,
        submission_mode: str = "local",
    ):
        super().__init__()
        if submission_mode not in {"local", "cluster"}:
            raise ValueError(f"unknown submission mode: {submission_mode}")
        self.submission_mode = submission_mode
        self.setWindowTitle("lamaGOET Qt — HAR setup and structure grow")
        self.resize(1420, 860)
        self.option_path = Path(option_path).resolve()
        self.saved_options: "OrderedDict[str, str]" = OrderedDict()
        self.structure: CrystalStructure | None = None
        self.visible_atoms: list[DisplayAtom] = []
        self.current_grow_description = "asymmetric unit"
        self._displayed_cif: Path | None = None
        self._latest_cif_stamp: tuple[Path, int] | None = None
        self._initial_cif: Path | None = None
        self._cif_watch_baseline: dict[Path, int] = {}
        self.local_process: subprocess.Popen | None = None
        self.cluster_job_id: str | None = None
        self._build_ui()
        self.load_options(self.option_path)
        self.cif_timer = QTimer(self)
        self.cif_timer.setInterval(2500)
        self.cif_timer.timeout.connect(self._refresh_latest_cif)
        self.cif_timer.start()

    def _build_ui(self) -> None:
        toolbar = QToolBar("Job")
        toolbar.setMovable(False)
        self.addToolBar(toolbar)
        open_options = QAction("Open options", self)
        open_options.triggered.connect(self.choose_options)
        toolbar.addAction(open_options)
        save_options_action = QAction("Save options", self)
        save_options_action.triggered.connect(self.save_options)
        toolbar.addAction(save_options_action)
        save_as = QAction("Save options as…", self)
        save_as.triggered.connect(self.save_options_as)
        toolbar.addAction(save_as)
        toolbar.addSeparator()
        open_cif_action = QAction("Open CIF", self)
        open_cif_action.triggered.connect(self.choose_cif)
        toolbar.addAction(open_cif_action)
        export_action = QAction("Export grown CIF", self)
        export_action.triggered.connect(self.export_grown_cif)
        toolbar.addAction(export_action)

        self.main_splitter = QSplitter(Qt.Orientation.Horizontal)
        self.main_splitter.addWidget(self._job_panel())
        self.main_splitter.addWidget(self._structure_panel())
        self.main_splitter.setSizes([570, 850])
        self.main_splitter.setChildrenCollapsible(False)
        self.main_splitter.setOpaqueResize(True)
        self.main_splitter.setHandleWidth(14)
        self.main_splitter.setStretchFactor(0, 2)
        self.main_splitter.setStretchFactor(1, 3)
        self.main_splitter.setStyleSheet(
            "QSplitter::handle:horizontal {"
            " background: #8c98a3; border-left: 4px solid #d9dfe4;"
            " border-right: 4px solid #d9dfe4; }"
            "QSplitter::handle:horizontal:hover,"
            " QSplitter::handle:horizontal:pressed { background: #287fb8; }"
        )
        handle = self.main_splitter.handle(1)
        handle.setCursor(Qt.CursorShape.SplitHCursor)
        handle.setToolTip("Drag to resize the setup and structure panels")
        self.setCentralWidget(self.main_splitter)
        self.setStatusBar(QStatusBar())

    def _job_panel(self) -> QWidget:
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        content = QWidget()
        layout = QVBoxLayout(content)

        job_group = QGroupBox("Job and input")
        job_form = QFormLayout(job_group)
        self.job_name = QLineEdit("my_job")
        self.job_name.editingFinished.connect(self._reset_cif_watch_baseline)
        job_form.addRow("Job name", self.job_name)
        self.program = QComboBox()
        for label, value in PROGRAMS:
            self.program.addItem(label, value)
        self.program.currentIndexChanged.connect(self._program_changed)
        self.program.activated.connect(self._program_activated)
        job_form.addRow("SCF program", self.program)

        cif_row = QWidget()
        cif_layout = QHBoxLayout(cif_row)
        cif_layout.setContentsMargins(0, 0, 0, 0)
        self.cif_path = QLineEdit()
        self.cif_path.editingFinished.connect(self._load_cif_from_field)
        cif_layout.addWidget(self.cif_path)
        cif_button = QPushButton("Browse…")
        cif_button.clicked.connect(self.choose_cif)
        cif_layout.addWidget(cif_button)
        job_form.addRow("CIF or PDB", cif_row)
        self.complete_structure = QCheckBox("Complete molecule(s) in CIF with Tonto")
        self.complete_structure.setToolTip(
            "Uses the established COMPLETESTRUCT/defragment path in the runners."
        )
        job_form.addRow("", self.complete_structure)

        self.initial_adp_group = QGroupBox(
            "ELMO initial coordinates and displacement parameters"
        )
        initial_adp_layout = QGridLayout(self.initial_adp_group)
        self.initial_adp = QCheckBox(
            "Load precise ADPs and coordinates from a CIF"
        )
        self.initial_adp.toggled.connect(self._initial_adp_changed)
        initial_adp_layout.addWidget(self.initial_adp, 0, 0, 1, 3)
        self.initial_adp_path = QLineEdit()
        initial_adp_layout.addWidget(self.initial_adp_path, 1, 0, 1, 2)
        self.initial_adp_button = QPushButton("Browse…")
        self.initial_adp_button.clicked.connect(self.choose_initial_adp)
        initial_adp_layout.addWidget(self.initial_adp_button, 1, 2)
        job_form.addRow(self.initial_adp_group)

        self.hkl_row = QWidget()
        hkl_layout = QHBoxLayout(self.hkl_row)
        hkl_layout.setContentsMargins(0, 0, 0, 0)
        self.hkl_path = QLineEdit()
        hkl_layout.addWidget(self.hkl_path)
        hkl_button = QPushButton("Browse…")
        hkl_button.clicked.connect(self.choose_hkl)
        hkl_layout.addWidget(hkl_button)
        self.hkl_label = QLabel("Reflection file")
        job_form.addRow(self.hkl_label, self.hkl_row)

        self.header_group = QGroupBox("Tonto reflection-file header")
        header_layout = QHBoxLayout(self.header_group)
        self.write_header = QCheckBox("Write header")
        self.write_header.toggled.connect(self._header_changed)
        header_layout.addWidget(self.write_header)
        self.header_on_f = QRadioButton("on F")
        self.header_on_f2 = QRadioButton("on F²")
        self.header_on_f.setChecked(True)
        header_layout.addWidget(self.header_on_f)
        header_layout.addWidget(self.header_on_f2)
        self.use_equivalents = QCheckBox("Use equivalents")
        self.use_equivalents.setToolTip(
            "General Tonto xray_data.use_equivalents option; it is not "
            "specific to Crystal23."
        )
        header_layout.addWidget(self.use_equivalents)
        job_form.addRow(self.header_group)

        self.method_label = QLabel("Method")
        self.method = _editable_combo()
        job_form.addRow(self.method_label, self.method)
        self.basis_label = QLabel("Basis set")
        self.basis = _editable_combo()
        job_form.addRow(self.basis_label, self.basis)
        self.extra_keywords_label = QLabel("Extra Gaussian keywords")
        self.extra_keywords = QLineEdit()
        job_form.addRow(self.extra_keywords_label, self.extra_keywords)
        layout.addWidget(job_group)

        self.external_basis_group = QGroupBox("External/custom basis definition")
        external_layout = QGridLayout(self.external_basis_group)
        self.external_basis = QCheckBox("Input external basis set manually")
        self.external_basis.toggled.connect(self._external_basis_changed)
        external_layout.addWidget(self.external_basis, 0, 0, 1, 3)
        self.basis_definition_path = QLineEdit()
        self.basis_definition_path.setPlaceholderText(
            "basis_gen.txt in the calculation directory"
        )
        external_layout.addWidget(self.basis_definition_path, 1, 0, 1, 3)
        basis_browse = QPushButton("Load file…")
        basis_browse.clicked.connect(self.choose_external_basis)
        external_layout.addWidget(basis_browse, 2, 0)
        self.edit_basis_button = QPushButton("Edit definition…")
        self.edit_basis_button.clicked.connect(self.edit_external_basis)
        external_layout.addWidget(self.edit_basis_button, 2, 1)
        self.bse_button = QPushButton("Basis Set Exchange...")
        self.bse_button.setToolTip(
            "Select a separate all-electron basis for each element in the loaded CIF."
        )
        self.bse_button.clicked.connect(self.choose_basis_exchange)
        external_layout.addWidget(self.bse_button, 2, 2)
        layout.addWidget(self.external_basis_group)

        self.gaussian_features = QGroupBox("Gaussian options")
        gaussian_layout = QHBoxLayout(self.gaussian_features)
        self.grimme = QCheckBox("Use Grimme dispersion (GD3BJ)")
        self.relativistic = QCheckBox("Use relativistic method")
        gaussian_layout.addWidget(self.grimme)
        gaussian_layout.addWidget(self.relativistic)
        layout.addWidget(self.gaussian_features)

        physical = QGroupBox("Charge, spin and refinement")
        form = QFormLayout(physical)
        self.charge = QSpinBox()
        self.charge.setRange(-30, 30)
        form.addRow("Charge", self.charge)
        self.multiplicity = QSpinBox()
        self.multiplicity.setRange(1, 50)
        self.multiplicity.setValue(1)
        form.addRow("Multiplicity", self.multiplicity)
        wave_row = QWidget()
        wave_layout = QHBoxLayout(wave_row)
        wave_layout.setContentsMargins(0, 0, 0, 0)
        wave_layout.addWidget(QLabel("Wavelength (Å)"))
        self.wave = QLineEdit("0.71073")
        wave_layout.addWidget(self.wave)
        wave_layout.addWidget(QLabel("F/sigma cutoff"))
        self.fcut = QLineEdit("3")
        wave_layout.addWidget(self.fcut)
        form.addRow(wave_row)
        processor_row = QWidget()
        processor_layout = QHBoxLayout(processor_row)
        processor_layout.setContentsMargins(0, 0, 0, 0)
        processor_layout.addWidget(QLabel("SCF processors"))
        self.processors = QSpinBox()
        self.processors.setRange(1, 4096)
        self.processors.setValue(1)
        processor_layout.addWidget(self.processors)
        processor_layout.addWidget(QLabel("Tonto processors"))
        self.tonto_processors = QSpinBox()
        self.tonto_processors.setRange(1, 4096)
        self.tonto_processors.setValue(1)
        processor_layout.addWidget(self.tonto_processors)
        form.addRow(processor_row)
        self.convergence = QLineEdit("0.01")
        form.addRow("Maximum shift/s.u.", self.convergence)
        self.max_cycles = QSpinBox()
        self.max_cycles.setRange(1, 999)
        self.max_cycles.setValue(50)
        form.addRow("Maximum HAR cycles", self.max_cycles)
        memory_row = QWidget()
        memory_layout = QHBoxLayout(memory_row)
        memory_layout.setContentsMargins(0, 0, 0, 0)
        memory_layout.addWidget(QLabel("SCF memory"))
        self.memory = QLineEdit("1gb")
        memory_layout.addWidget(self.memory)
        memory_layout.addWidget(QLabel("PBS memory per processor"))
        self.pbs_memory = QLineEdit("1gb")
        memory_layout.addWidget(self.pbs_memory)
        form.addRow(memory_row)
        self.email = QLineEdit()
        self.email_label = QLabel("Notification email")
        form.addRow(self.email_label, self.email)
        cluster_mode = self.submission_mode == "cluster"
        self.email_label.setVisible(cluster_mode)
        self.email.setVisible(cluster_mode)
        layout.addWidget(physical)

        self.crystal_group = QGroupBox("Crystal23 structure options")
        crystal_layout = QHBoxLayout(self.crystal_group)
        self.use_hm_symbol = QCheckBox("Use Hermann–Mauguin symbol")
        self.network_compound = QCheckBox("Network compound outputs")
        self.use_previous_crystal_guess = QCheckBox("Reuse previous-cycle guess")
        crystal_layout.addWidget(self.use_hm_symbol)
        crystal_layout.addWidget(self.network_compound)
        crystal_layout.addWidget(self.use_previous_crystal_guess)
        crystal_layout.addWidget(QLabel("Rhombohedral setting"))
        self.crystal_setting = QComboBox()
        self.crystal_setting.addItem("Automatic from CIF cell", "auto")
        self.crystal_setting.addItem("Hexagonal axes", "h")
        self.crystal_setting.addItem("Rhombohedral axes", "r")
        crystal_layout.addWidget(self.crystal_setting)
        layout.addWidget(self.crystal_group)

        self.stockholder_group = QGroupBox("Density partition")
        stockholder_form = QFormLayout(self.stockholder_group)
        self.partition_model = QComboBox()
        self.partition_model.addItem(
            "Tonto SCF density (standard)", "oc-hirshfeld"
        )
        self.partition_model.addItem(
            "Regularized observed density (experimental)", "oc-observed"
        )
        self.partition_model.setToolTip(
            "Available for Tonto SCF jobs only. oc-hirshfeld uses the Tonto SCF "
            "density; oc-observed constructs atomic form factors from an IAM "
            "prior plus regularized, phased experimental residual density."
        )
        self.partition_model.currentIndexChanged.connect(
            self._partition_model_changed
        )
        self.partition_model_label = QLabel("Density model")
        stockholder_form.addRow(self.partition_model_label, self.partition_model)

        self.stockholder_model = QComboBox()
        self.stockholder_model.addItem(
            "Finite HS atom cluster (existing model)", "cluster"
        )
        self.stockholder_model.addItem(
            "Periodic unit-cell procrystal", "periodic"
        )
        self.stockholder_model.setToolTip(
            "Selects only the Hirshfeld stockholder denominator. The density "
            "remains the imported Crystal23 or CP2K density."
        )
        self.stockholder_model_label = QLabel("Stockholder model")
        stockholder_form.addRow(
            self.stockholder_model_label, self.stockholder_model
        )

        self.observed_shrinkage = QDoubleSpinBox()
        self.observed_shrinkage.setRange(0.0, 0.999999)
        self.observed_shrinkage.setDecimals(6)
        self.observed_shrinkage.setSingleStep(0.05)
        self.observed_shrinkage.setValue(0.5)
        self.observed_shrinkage.setToolTip(
            "Fraction of the reliability-weighted observed residual density "
            "added to the IAM prior. It must be smaller than one."
        )
        self.observed_shrinkage_label = QLabel("Residual-density shrinkage")
        stockholder_form.addRow(
            self.observed_shrinkage_label, self.observed_shrinkage
        )

        self.observed_min_tf = QDoubleSpinBox()
        self.observed_min_tf.setRange(0.000000000001, 1.0)
        self.observed_min_tf.setDecimals(12)
        self.observed_min_tf.setSingleStep(0.01)
        self.observed_min_tf.setValue(0.1)
        self.observed_min_tf.setToolTip(
            "Smallest harmonic temperature factor used while converting the "
            "dynamic residual density to static atomic form factors."
        )
        self.observed_min_tf_label = QLabel("Minimum thermal factor")
        stockholder_form.addRow(
            self.observed_min_tf_label, self.observed_min_tf
        )

        self.observed_zero_phase_sign = QComboBox()
        self.observed_zero_phase_sign.addItem(
            "Omit zero-model coefficient (recommended)", 0
        )
        self.observed_zero_phase_sign.addItem("Use positive phase sign", 1)
        self.observed_zero_phase_sign.addItem("Use negative phase sign", -1)
        self.observed_zero_phase_sign.setToolTip(
            "Sign hypothesis used only for a symmetry-allowed phase when the "
            "model structure factor is exactly zero."
        )
        self.observed_zero_phase_sign_label = QLabel("Zero-model phase")
        stockholder_form.addRow(
            self.observed_zero_phase_sign_label,
            self.observed_zero_phase_sign,
        )
        layout.addWidget(self.stockholder_group)

        self.cluster_group = QGroupBox("Molecular cluster environment")
        cluster_form = QFormLayout(self.cluster_group)
        sc_charge_row = QWidget()
        sc_charge_layout = QHBoxLayout(sc_charge_row)
        sc_charge_layout.setContentsMargins(0, 0, 0, 0)
        self.sc_charges = QCheckBox("Use SC cluster charges")
        self.sc_charges.toggled.connect(self._cluster_controls_changed)
        sc_charge_layout.addWidget(self.sc_charges)
        self.sc_radius = QLineEdit("8")
        self.sc_radius.setMaximumWidth(90)
        sc_charge_layout.addWidget(QLabel("radius (Å)"))
        sc_charge_layout.addWidget(self.sc_radius)
        self.complete_charge_molecules = QCheckBox("Complete molecules")
        sc_charge_layout.addWidget(self.complete_charge_molecules)
        self.use_dipoles = QCheckBox("Use dipoles")
        sc_charge_layout.addWidget(self.use_dipoles)
        self.nuclear_interaction = QCheckBox("Nuclear interaction (Orca)")
        sc_charge_layout.addWidget(self.nuclear_interaction)
        cluster_form.addRow(sc_charge_row)

        explicit_row = QWidget()
        explicit_layout = QHBoxLayout(explicit_row)
        explicit_layout.setContentsMargins(0, 0, 0, 0)
        self.explicit_molecules = QCheckBox("Use explicit cluster of molecules")
        self.explicit_molecules.toggled.connect(self._cluster_controls_changed)
        explicit_layout.addWidget(self.explicit_molecules)
        self.explicit_radius = QLineEdit("3")
        self.explicit_radius.setMaximumWidth(90)
        explicit_layout.addWidget(QLabel("within radius (Å)"))
        explicit_layout.addWidget(self.explicit_radius)
        self.complete_explicit_molecules = QCheckBox("Complete molecules")
        explicit_layout.addWidget(self.complete_explicit_molecules)
        cluster_form.addRow(explicit_row)
        layout.addWidget(self.cluster_group)

        refinement = QGroupBox("Tonto refinement options")
        refinement_form = QFormLayout(refinement)
        mode_row = QWidget()
        mode_layout = QHBoxLayout(mode_row)
        mode_layout.setContentsMargins(0, 0, 0, 0)
        self.refine_mode = QButtonGroup(self)
        self.refine_pos_adp = QRadioButton("positions and ADPs")
        self.refine_pos_only = QRadioButton("positions only")
        self.refine_adps_only = QRadioButton("ADPs only")
        self.refine_pos_adp.setChecked(True)
        for identifier, button in enumerate(
            (self.refine_pos_adp, self.refine_pos_only, self.refine_adps_only)
        ):
            self.refine_mode.addButton(button, identifier)
            mode_layout.addWidget(button)
        refinement_form.addRow("All atom types", mode_row)

        iam_row = QWidget()
        iam_layout = QHBoxLayout(iam_row)
        iam_layout.setContentsMargins(0, 0, 0, 0)
        self.iam_tonto = QCheckBox("Start with Tonto IAM")
        self.iam_tonto.toggled.connect(self._refinement_controls_changed)
        self.only_iam_tonto = QCheckBox("Only perform Tonto IAM")
        iam_layout.addWidget(self.iam_tonto)
        iam_layout.addWidget(self.only_iam_tonto)
        refinement_form.addRow(iam_row)

        self.refine_nothing = QCheckBox("Refine nothing for atom labels")
        self.refine_nothing.toggled.connect(self._refinement_controls_changed)
        self.atom_list = QLineEdit()
        refinement_form.addRow(self.refine_nothing, self.atom_list)
        self.refine_uiso = QCheckBox("Refine these atoms isotropically")
        self.refine_uiso.toggled.connect(self._refinement_controls_changed)
        self.atom_uiso_list = QLineEdit()
        refinement_form.addRow(self.refine_uiso, self.atom_uiso_list)

        hydrogen_row = QWidget()
        hydrogen_layout = QHBoxLayout(hydrogen_row)
        hydrogen_layout.setContentsMargins(0, 0, 0, 0)
        self.refine_h_positions = QCheckBox("Refine H positions")
        self.refine_h_adps = QCheckBox("Refine H ADPs")
        self.refine_h_positions.setChecked(True)
        self.refine_h_adps.setChecked(True)
        self.h_adp = QCheckBox("H atoms isotropic")
        hydrogen_layout.addWidget(self.refine_h_positions)
        hydrogen_layout.addWidget(self.refine_h_adps)
        hydrogen_layout.addWidget(self.h_adp)
        refinement_form.addRow(hydrogen_row)

        anharmonic_row = QWidget()
        anharmonic_layout = QHBoxLayout(anharmonic_row)
        anharmonic_layout.setContentsMargins(0, 0, 0, 0)
        self.refine_anharmonic = QCheckBox("Refine anharmonic ADPs")
        self.refine_anharmonic.toggled.connect(self._refinement_controls_changed)
        self.anharmonic_atoms = QLineEdit()
        self.third_order = QCheckBox("3rd order")
        self.fourth_order = QCheckBox("4th order")
        anharmonic_layout.addWidget(self.refine_anharmonic)
        anharmonic_layout.addWidget(QLabel("atoms"))
        anharmonic_layout.addWidget(self.anharmonic_atoms)
        anharmonic_layout.addWidget(self.third_order)
        anharmonic_layout.addWidget(self.fourth_order)
        refinement_form.addRow(anharmonic_row)

        xh_row = QWidget()
        xh_layout = QGridLayout(xh_row)
        xh_layout.setContentsMargins(0, 0, 0, 0)
        self.elongate_xh = QCheckBox("Elongate X–H bond lengths")
        self.elongate_xh.toggled.connect(self._refinement_controls_changed)
        xh_layout.addWidget(self.elongate_xh, 0, 0, 1, 2)
        self.bh_bond = QLineEdit("1.190")
        self.ch_bond = QLineEdit("1.083")
        self.nh_bond = QLineEdit("1.009")
        self.oh_bond = QLineEdit("0.983")
        for column, (label, widget) in enumerate(
            (
                ("B–H", self.bh_bond),
                ("C–H", self.ch_bond),
                ("N–H", self.nh_bond),
                ("O–H", self.oh_bond),
            )
        ):
            xh_layout.addWidget(QLabel(label), 1, column * 2)
            xh_layout.addWidget(widget, 1, column * 2 + 1)
        refinement_form.addRow(xh_row)

        self.dispersion_correction = QCheckBox(
            "Apply experimental dispersion correction"
        )
        refinement_form.addRow(self.dispersion_correction)
        layout.addWidget(refinement)

        self.cp2k_group = QGroupBox("CP2K periodic all-electron settings")
        cp2k_form = QFormLayout(self.cp2k_group)
        self.cp2k_bin = QLineEdit()
        cp2k_basis_row = QWidget()
        cp2k_basis_layout = QHBoxLayout(cp2k_basis_row)
        cp2k_basis_layout.setContentsMargins(0, 0, 0, 0)
        self.cp2k_basis_file = QLineEdit()
        self.cp2k_basis_file.editingFinished.connect(self._reload_cp2k_bases)
        cp2k_basis_layout.addWidget(self.cp2k_basis_file)
        cp2k_file_button = QPushButton("Browse…")
        cp2k_file_button.clicked.connect(self.choose_cp2k_basis)
        cp2k_basis_layout.addWidget(cp2k_file_button)
        self.cp2k_basis_file_row = cp2k_basis_row
        # Executable and basis-file paths are placed together with every other
        # installation path on the Settings tab.  Keep this row object alive
        # for the basis parser, but do not duplicate it in two Qt parents.
        self.cp2k_basis = _editable_combo()
        cp2k_form.addRow("Basis name", self.cp2k_basis)
        self.cp2k_functional = QComboBox()
        self.cp2k_functional.addItems(CP2K_FUNCTIONALS)
        cp2k_form.addRow("XC functional", self.cp2k_functional)
        self.kpoints = QLineEdit("2 2 2")
        cp2k_form.addRow("k-point grid", self.kpoints)
        self.cp2k_cutoff = QLineEdit("1200")
        cp2k_form.addRow("Cutoff", self.cp2k_cutoff)
        self.cp2k_rel_cutoff = QLineEdit("80")
        cp2k_form.addRow("Relative cutoff", self.cp2k_rel_cutoff)
        self.cp2k_max_scf = QSpinBox()
        self.cp2k_max_scf.setRange(1, 10000)
        self.cp2k_max_scf.setValue(100)
        cp2k_form.addRow("Maximum SCF cycles", self.cp2k_max_scf)
        self.cp2k_eps_scf = QLineEdit("1.0E-8")
        cp2k_form.addRow("SCF tolerance", self.cp2k_eps_scf)
        self.cp2k_added_mos = QSpinBox()
        self.cp2k_added_mos.setRange(0, 10000)
        self.cp2k_added_mos.setValue(20)
        cp2k_form.addRow("Added MOs", self.cp2k_added_mos)
        layout.addWidget(self.cp2k_group)

        if self.submission_mode == "cluster":
            note_text = (
                "Cluster mode: OK saves job_options.txt, writes lamaGOET.pbs, "
                "and submits it with qsub. It never starts a local HAR."
            )
            ok_text = "OK — submit to cluster"
            save_text = "Save without submitting"
        else:
            note_text = (
                "Local mode: OK saves job_options.txt and starts lamaGOET.sh on "
                "this computer. It never writes a PBS file or calls qsub."
            )
            ok_text = "OK — run locally"
            save_text = "Save without running"
        note = QLabel(
            note_text
            + " Saved XCW/plot settings which are not shown here are preserved "
            "unchanged."
        )
        note.setWordWrap(True)
        note.setFrameShape(QFrame.Shape.StyledPanel)
        layout.addWidget(note)
        action_row = QHBoxLayout()
        save_button = QPushButton(save_text)
        save_button.clicked.connect(self.save_options)
        action_row.addWidget(save_button)
        action_row.addStretch(1)
        cancel_button = QPushButton("Cancel")
        cancel_button.clicked.connect(self.close)
        action_row.addWidget(cancel_button)
        self.kill_button = QPushButton("Kill job")
        self.kill_button.setEnabled(False)
        self.kill_button.clicked.connect(self.kill_job)
        action_row.addWidget(self.kill_button)
        ok_button = QPushButton(ok_text)
        ok_button.setDefault(True)
        ok_button.clicked.connect(self.submit_job)
        action_row.addWidget(ok_button)
        layout.addLayout(action_row)
        layout.addStretch(1)
        scroll.setWidget(content)
        # The form itself scrolls, so a large fixed minimum only served to lock
        # the main splitter close to its startup position.
        scroll.setMinimumWidth(300)
        tabs = QTabWidget()
        tabs.setDocumentMode(True)
        tabs.addTab(scroll, "HAR")
        tabs.addTab(self._advanced_har_panel(), "Advanced HAR")
        self.elmo_advanced_tab = self._elmo_advanced_panel()
        tabs.addTab(self.elmo_advanced_tab, "ELMO advanced")
        tabs.addTab(self._xcw_panel(), "XCW")
        tabs.addTab(self._plots_panel(), "Plots")
        tabs.addTab(self._settings_panel(), "Settings")
        return tabs

    @staticmethod
    def _form_scroll(form: QFormLayout) -> QScrollArea:
        page = QWidget()
        page.setLayout(form)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(page)
        return scroll

    def _advanced_har_panel(self) -> QScrollArea:
        form = QFormLayout()
        self.energy_convergence = QLineEdit("0.00001")
        form.addRow("Energy convergence", self.energy_convergence)
        self.linear_dependence = QLineEdit()
        form.addRow("Tonto linear-dependence tolerance", self.linear_dependence)
        self.max_ls_cycles = QSpinBox()
        self.max_ls_cycles.setRange(1, 10000)
        self.max_ls_cycles.setValue(30)
        form.addRow("Maximum least-squares cycles", self.max_ls_cycles)
        self.max_xtal_cycles = QLineEdit()
        form.addRow("Maximum Crystal cycles (blank = automatic)", self.max_xtal_cycles)
        self.supercon = QCheckBox("Use Crystal SUPERCON")
        form.addRow(self.supercon)
        shrink_row = QWidget()
        shrink_layout = QHBoxLayout(shrink_row)
        shrink_layout.setContentsMargins(0, 0, 0, 0)
        self.shrink_a = QSpinBox()
        self.shrink_a.setRange(1, 999)
        self.shrink_a.setValue(2)
        self.shrink_b = QSpinBox()
        self.shrink_b.setRange(1, 999)
        self.shrink_b.setValue(2)
        shrink_layout.addWidget(QLabel("SHRINK A"))
        shrink_layout.addWidget(self.shrink_a)
        shrink_layout.addWidget(QLabel("SHRINK B"))
        shrink_layout.addWidget(self.shrink_b)
        form.addRow("Crystal k-point shrinking", shrink_row)
        self.max_phar_cycles = QSpinBox()
        self.max_phar_cycles.setRange(1, 10000)
        self.max_phar_cycles.setValue(10)
        form.addRow("Maximum pHAR cycles", self.max_phar_cycles)
        self.nsa2_accuracy = QSpinBox()
        self.nsa2_accuracy.setRange(0, 99)
        self.nsa2_accuracy.setValue(2)
        form.addRow("NoSpherA2 accuracy", self.nsa2_accuracy)
        self.minimum_correlation = QLineEdit()
        form.addRow("Minimum correlation coefficient", self.minimum_correlation)
        self.powder_har = QCheckBox("Powder HAR")
        form.addRow(self.powder_har)
        self.use_nosphera2 = QCheckBox("Use NoSpherA2")
        form.addRow(self.use_nosphera2)
        self.use_becke = QCheckBox("Use a non-default Becke grid")
        form.addRow(self.use_becke)
        self.becke_accuracy = QComboBox()
        self.becke_accuracy.setEditable(True)
        self.becke_accuracy.addItems(
            ["very_low", "low", "medium", "high", "very_high"]
        )
        form.addRow("Becke accuracy", self.becke_accuracy)
        self.becke_pruning = QComboBox()
        self.becke_pruning.setEditable(True)
        self.becke_pruning.addItems(["none", "sg1", "robust"])
        form.addRow("Becke pruning scheme", self.becke_pruning)
        self.har_energy_repeat_tol = QLineEdit("1.0E-10")
        form.addRow("Stationary-wavefunction energy tolerance", self.har_energy_repeat_tol)
        self.har_scf_rmsd_tol = QLineEdit("1.0E-8")
        form.addRow("Stationary-wavefunction RMSD tolerance", self.har_scf_rmsd_tol)
        return self._form_scroll(form)

    def _elmo_advanced_panel(self) -> QScrollArea:
        form = QFormLayout()
        self.use_gamess = QCheckBox("Use GAMESS-US through ELMOdb")
        form.addRow(self.use_gamess)
        self.n_disulfide = QSpinBox()
        self.n_disulfide.setRange(0, 100000)
        form.addRow("Number of disulfide bonds", self.n_disulfide)
        self.disulfide_atoms = QPlainTextEdit()
        self.disulfide_atoms.setPlaceholderText("Atom-number pairs, one pair per line")
        self.disulfide_atoms.setMaximumHeight(100)
        form.addRow("Disulfide-bond atoms", self.disulfide_atoms)
        self.n_tail = QSpinBox()
        self.n_tail.setRange(0, 100000)
        form.addRow("Number of tailored residues", self.n_tail)
        self.atom_tail = QSpinBox()
        self.atom_tail.setRange(0, 1000000)
        self.atom_tail.setValue(100)
        form.addRow("Tail atom limit", self.atom_tail)
        self.fragment_tail = QSpinBox()
        self.fragment_tail.setRange(0, 1000000)
        self.fragment_tail.setValue(200)
        form.addRow("Tail fragment limit", self.fragment_tail)
        self.manual_residue = QPlainTextEdit()
        self.manual_residue.setMaximumHeight(180)
        form.addRow("Tailor-made residue definition", self.manual_residue)
        return self._form_scroll(form)

    def _xcw_panel(self) -> QScrollArea:
        form = QFormLayout()
        self.xcw_only = QCheckBox("Perform XCW only (based on input geometry, no HAR)")
        form.addRow(self.xcw_only)
        self.xray_restrained = QCheckBox("Perform XWR (HAR+XCW) job")
        form.addRow(self.xray_restrained)
        self.method_xcw = _editable_combo()
        self.method_xcw.addItems(METHODS["Tonto"])
        form.addRow("XCW method", self.method_xcw)
        self.basis_xcw = _editable_combo()
        self.basis_xcw.addItems(TONTO_BASIS)
        form.addRow("XCW basis", self.basis_xcw)
        self.xcw_sc_charges = QCheckBox("Use SC cluster charges in XCW")
        form.addRow(self.xcw_sc_charges)
        self.xcw_sc_radius = QLineEdit("8")
        form.addRow("XCW cluster radius (Å)", self.xcw_sc_radius)
        self.xcw_defragment = QCheckBox("Complete XCW cluster molecules")
        form.addRow(self.xcw_defragment)
        self.lambda_initial = QLineEdit("0")
        self.lambda_step = QLineEdit("0.1")
        self.lambda_max = QLineEdit("1")
        form.addRow("Initial lambda", self.lambda_initial)
        form.addRow("Lambda step", self.lambda_step)
        form.addRow("Maximum lambda", self.lambda_max)
        return self._form_scroll(form)

    def _plots_panel(self) -> QScrollArea:
        form = QFormLayout()
        self.plot_tonto = QCheckBox("Run Tonto plot calculation")
        form.addRow(self.plot_tonto)
        self.plot_deformation = QCheckBox("Deformation density")
        self.plot_dft_xc = QCheckBox("DFT XC potential")
        self.plot_density = QCheckBox("Electron density")
        self.plot_laplacian = QCheckBox("Laplacian")
        self.plot_negative_laplacian = QCheckBox("Negative Laplacian")
        self.plot_promolecule = QCheckBox("Promolecule density")
        for widget in (
            self.plot_deformation,
            self.plot_dft_xc,
            self.plot_density,
            self.plot_laplacian,
            self.plot_negative_laplacian,
            self.plot_promolecule,
        ):
            form.addRow(widget)
        self.plot_angstrom = QCheckBox("Plot dimensions are in Å")
        form.addRow(self.plot_angstrom)
        self.use_separation = QCheckBox("Use explicit grid separation")
        form.addRow(self.use_separation)
        self.separation = QLineEdit()
        form.addRow("Grid separation", self.separation)
        self.use_all_points = QCheckBox("Use all grid points")
        form.addRow(self.use_all_points)
        points_row = QWidget()
        points_layout = QHBoxLayout(points_row)
        points_layout.setContentsMargins(0, 0, 0, 0)
        self.points_x = QSpinBox(); self.points_x.setRange(1, 100000); self.points_x.setValue(10)
        self.points_y = QSpinBox(); self.points_y.setRange(1, 100000); self.points_y.setValue(10)
        self.points_z = QSpinBox(); self.points_z.setRange(1, 100000); self.points_z.setValue(10)
        for label, widget in (("X", self.points_x), ("Y", self.points_y), ("Z", self.points_z)):
            points_layout.addWidget(QLabel(label)); points_layout.addWidget(widget)
        form.addRow("Grid points", points_row)
        self.use_center = QCheckBox("Use an atom as plot centre")
        form.addRow(self.use_center)
        self.center_atom = QSpinBox(); self.center_atom.setRange(1, 100000)
        form.addRow("Centre atom", self.center_atom)
        self.x_axis = QLineEdit("1 2")
        self.y_axis = QLineEdit("1 3")
        form.addRow("X-axis atom pair", self.x_axis)
        form.addRow("Y-axis atom pair", self.y_axis)
        widths = QWidget(); widths_layout = QHBoxLayout(widths); widths_layout.setContentsMargins(0, 0, 0, 0)
        self.width_x = QLineEdit("10"); self.width_y = QLineEdit("10"); self.width_z = QLineEdit("10")
        for label, widget in (("X", self.width_x), ("Y", self.width_y), ("Z", self.width_z)):
            widths_layout.addWidget(QLabel(label)); widths_layout.addWidget(widget)
        form.addRow("Plot widths", widths)
        return self._form_scroll(form)

    def _path_control(self, line_edit: QLineEdit, *, directory: bool = False) -> QWidget:
        row = QWidget()
        layout = QHBoxLayout(row)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(line_edit)
        button = QPushButton("Browse…")
        if directory:
            button.clicked.connect(lambda: self._choose_directory(line_edit))
        else:
            button.clicked.connect(lambda: self._choose_executable(line_edit))
        layout.addWidget(button)
        return row

    def _settings_panel(self) -> QScrollArea:
        form = QFormLayout()
        self.tonto_bin = QLineEdit("tonto")
        self.gaussian_bin = QLineEdit("g09")
        self.orca_bin = QLineEdit("orca")
        self.occ_bin = QLineEdit("occ")
        self.crystal_bin = QLineEdit("runcry23")
        self.elmodb_bin = QLineEdit("elmodb")
        self.gamess_bin = QLineEdit("gamess_int")
        self.jana_bin = QLineEdit("jana2006")
        for label, widget in (
            ("Tonto executable", self.tonto_bin),
            ("Gaussian executable", self.gaussian_bin),
            ("ORCA executable", self.orca_bin),
            ("OCC executable", self.occ_bin),
            ("Crystal23 executable", self.crystal_bin),
            ("ELMOdb executable", self.elmodb_bin),
            ("GAMESS-US interface", self.gamess_bin),
            ("Jana executable", self.jana_bin),
            ("CP2K executable", self.cp2k_bin),
        ):
            form.addRow(label, self._path_control(widget))
        self.basis_directory = QLineEdit("/usr/local/bin/basis_sets")
        self.xcw_basis_directory = QLineEdit("/usr/local/bin/basis_sets")
        self.elmo_library = QLineEdit("/usr/local/bin/LIBRARIES")
        self.tonto_basis_directory = QLineEdit()
        for label, widget in (
            ("Tonto basis-set directory", self.basis_directory),
            ("XCW basis-set directory", self.xcw_basis_directory),
            ("ELMO libraries directory", self.elmo_library),
            ("CP2K/Tonto Slater basis directory", self.tonto_basis_directory),
        ):
            form.addRow(label, self._path_control(widget, directory=True))
        form.addRow("CP2K all-electron basis file", self.cp2k_basis_file_row)
        return self._form_scroll(form)

    def _structure_panel(self) -> QWidget:
        panel = QWidget()
        layout = QVBoxLayout(panel)
        controls = QGridLayout()
        self.grow_mode = QComboBox()
        self.grow_mode.addItem("Asymmetric unit", "asu")
        self.grow_mode.addItem("Complete unit cell", "cell")
        self.grow_mode.addItem("Complete fragment(s)/molecule(s)", "molecules")
        self.grow_mode.addItem("Short contacts", "short_contacts")
        self.grow_mode.addItem("van der Waals radii", "vdw")
        self.grow_mode.addItem("Within radius of selected atom", "radius")
        self.grow_mode.addItem("Neighbouring cells (3×3×3)", "supercell")
        self.grow_mode.setSizeAdjustPolicy(
            QComboBox.SizeAdjustPolicy.AdjustToMinimumContentsLengthWithIcon
        )
        self.grow_mode.setMinimumContentsLength(24)
        self.grow_mode.currentIndexChanged.connect(self._grow_mode_changed)
        controls.addWidget(QLabel("Manual grow mode"), 0, 0)
        controls.addWidget(self.grow_mode, 0, 1, 1, 4)
        controls.setColumnStretch(1, 1)
        self.radius_label = QLabel("Distance")
        self.radius = QDoubleSpinBox()
        self.radius.setRange(1.0, 25.0)
        self.radius.setValue(4.0)
        self.radius.setSuffix(" Å")
        controls.addWidget(self.radius_label, 1, 0)
        controls.addWidget(self.radius, 1, 1)
        self.vdw_tolerance_label = QLabel("Tolerance")
        self.vdw_tolerance = QDoubleSpinBox()
        self.vdw_tolerance.setRange(-0.5, 3.0)
        self.vdw_tolerance.setSingleStep(0.1)
        self.vdw_tolerance.setValue(0.2)
        self.vdw_tolerance.setSuffix(" Å")
        controls.addWidget(self.vdw_tolerance_label, 1, 2)
        controls.addWidget(self.vdw_tolerance, 1, 3)
        apply_button = QPushButton("Apply")
        apply_button.clicked.connect(self.apply_grow)
        controls.addWidget(apply_button, 0, 5)
        reset_button = QPushButton("Reset view")
        reset_button.clicked.connect(lambda: self.viewer.reset_view())
        controls.addWidget(reset_button, 0, 6)
        layout.addWidget(self._control_strip(controls))

        display_controls = QGridLayout()
        self.show_cell = QCheckBox("Unit-cell box")
        self.show_cell.setChecked(True)
        self.show_cell.toggled.connect(self._display_changed)
        display_controls.addWidget(self.show_cell, 0, 0)
        self.show_labels = QCheckBox("Atom labels")
        self.show_labels.toggled.connect(self._display_changed)
        display_controls.addWidget(self.show_labels, 0, 1)
        display_controls.addWidget(QLabel("Projection"), 0, 2)
        self.projection_mode = QComboBox()
        self.projection_mode.addItem("Perspective", "perspective")
        self.projection_mode.addItem("Orthographic", "orthographic")
        self.projection_mode.currentIndexChanged.connect(self._display_changed)
        display_controls.addWidget(self.projection_mode, 0, 3)
        self.depth_cueing = QCheckBox("Depth cueing")
        self.depth_cueing.setChecked(True)
        self.depth_cueing.toggled.connect(self._display_changed)
        display_controls.addWidget(self.depth_cueing, 0, 4)
        self.show_ellipsoids = QCheckBox("ADP ellipsoids")
        self.show_ellipsoids.setChecked(True)
        self.show_ellipsoids.setToolTip(
            "Transforms CIF Uij values to Cartesian displacement tensors and "
            "draws their probability ellipsoids."
        )
        self.show_ellipsoids.toggled.connect(self._display_changed)
        display_controls.addWidget(self.show_ellipsoids, 1, 0)
        self.ellipsoid_probability_label = QLabel("Probability")
        display_controls.addWidget(self.ellipsoid_probability_label, 1, 1)
        self.ellipsoid_probability = QSpinBox()
        self.ellipsoid_probability.setRange(1, 99)
        self.ellipsoid_probability.setValue(50)
        self.ellipsoid_probability.setSuffix("%")
        self.ellipsoid_probability.valueChanged.connect(self._display_changed)
        display_controls.addWidget(self.ellipsoid_probability, 1, 2)
        self.follow_latest_cif = QCheckBox("Follow latest Tonto CIF")
        self.follow_latest_cif.setChecked(True)
        self.follow_latest_cif.setToolTip(
            "Reloads the newest local *.cif or *.cif2 written in the calculation tree."
        )
        display_controls.addWidget(self.follow_latest_cif, 1, 3, 1, 2)
        self.atom_status = QLabel("No atom selected")
        display_controls.addWidget(self.atom_status, 2, 0, 1, 5)
        display_controls.setColumnStretch(3, 1)
        layout.addWidget(self._control_strip(display_controls))

        self.viewer = StructureView()
        self.viewer.atom_selected.connect(self._atom_selected)
        layout.addWidget(self.viewer, 1)
        self._display_changed()

        bottom = QHBoxLayout()
        help_text = QLabel(
            "Left-drag rotates • wheel zooms • right/middle-drag pans • click an "
            "atom to use radius growth. Export keeps the source unit cell and space "
            "group while adding the displayed atoms to the QM starting fragment."
        )
        help_text.setWordWrap(True)
        bottom.addWidget(help_text, 1)
        export = QPushButton("Export grown CIF…")
        export.clicked.connect(self.export_grown_cif)
        bottom.addWidget(export)
        layout.addLayout(bottom)
        self._grow_mode_changed()
        return panel

    @staticmethod
    def _control_strip(control_layout) -> QScrollArea:
        """Keep viewer controls usable without imposing their width on the splitter."""

        control_layout.setContentsMargins(0, 0, 0, 0)
        control_layout.setHorizontalSpacing(2)
        control_layout.setVerticalSpacing(3)
        content = QWidget()
        content.setLayout(control_layout)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(content)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setMinimumWidth(0)
        height = (
            content.sizeHint().height()
            + scroll.horizontalScrollBar().sizeHint().height()
            + 4
        )
        scroll.setFixedHeight(height)
        return scroll

    def _option(self, name: str, default: str = "") -> str:
        return self.saved_options.get(name, default)

    def load_options(self, path: str | Path) -> None:
        self.option_path = Path(path).resolve()
        self.saved_options = load_job_options(self.option_path)
        program = self._option("SCFCALCPROG", "Gaussian")
        index = self.program.findData(program)
        self.program.setCurrentIndex(max(0, index))
        self.job_name.setText(self._option("JOBNAME", "my_job"))
        self.cif_path.setText(self._option("CIF"))
        self.hkl_path.setText(self._option("HKL"))
        self.complete_structure.setChecked(self._bool_option("COMPLETESTRUCT"))
        self.initial_adp.setChecked(self._bool_option("INITADP"))
        self.initial_adp_path.setText(self._option("INITADPFILE"))
        self.write_header.setChecked(self._bool_option("WRITEHEADER"))
        self.header_on_f.setChecked(self._bool_option("ONF", True))
        self.header_on_f2.setChecked(self._bool_option("ONF2"))
        self.use_equivalents.setChecked(self._bool_option("USEEQUIV"))
        self.extra_keywords.setText(self._option("EXTRAKEY"))
        self.external_basis.setChecked(self._bool_option("GAUSGEN"))
        basis_definition = self.option_path.parent / "basis_gen.txt"
        self.basis_definition_path.setText(
            str(basis_definition) if basis_definition.exists() else ""
        )
        self.grimme.setChecked(self._bool_option("GAUSSEMPDISP"))
        self.relativistic.setChecked(self._bool_option("GAUSSREL"))
        self.charge.setValue(self._int_option("CHARGE", 0))
        self.multiplicity.setValue(self._int_option("MULTIPLICITY", 1))
        self.wave.setText(self._option("WAVE", "0.71073"))
        self.fcut.setText(self._option("FCUT", "3"))
        self.processors.setValue(self._int_option("NUMPROC", 1))
        self.tonto_processors.setValue(self._int_option("NUMPROCTONTO", 1))
        self.convergence.setText(self._option("CONVTOL", "0.01"))
        self.max_cycles.setValue(self._int_option("MAXCYCLE", 50))
        self.memory.setText(self._option("MEM", "1gb"))
        self.pbs_memory.setText(self._option("MEMPBS", "1gb"))
        self.email.setText(self._option("EMAIL"))
        self.use_hm_symbol.setChecked(self._bool_option("USEHMSYM"))
        self.network_compound.setChecked(self._bool_option("DEFRAGNETW"))
        self.use_previous_crystal_guess.setChecked(self._bool_option("USEGUESS"))
        setting_index = self.crystal_setting.findData(
            self._option("CRYSTAL_SETTING", "auto")
        )
        self.crystal_setting.setCurrentIndex(max(0, setting_index))
        stockholder_index = self.stockholder_model.findData(
            self._option("STOCKHOLDER_MODEL", "cluster")
        )
        self.stockholder_model.setCurrentIndex(max(0, stockholder_index))
        partition_model = self._option("PARTITION_MODEL", "oc-hirshfeld")
        if partition_model in {
            "auto",
            "tonto",
            "oc-hirshfeld",
            "crystal23",
            "oc-crystal23",
        }:
            partition_model = "oc-hirshfeld"
        elif partition_model == "observed":
            partition_model = "oc-observed"
        partition_index = self.partition_model.findData(partition_model)
        self.partition_model.setCurrentIndex(max(0, partition_index))
        self.observed_shrinkage.setValue(
            self._float_option("OBSERVED_DENSITY_SHRINKAGE", 0.5)
        )
        self.observed_min_tf.setValue(
            self._float_option("OBSERVED_DENSITY_MIN_TF", 0.1)
        )
        zero_phase_index = self.observed_zero_phase_sign.findData(
            self._int_option("OBSERVED_ZERO_PHASE_SIGN", 0)
        )
        self.observed_zero_phase_sign.setCurrentIndex(max(0, zero_phase_index))
        self._partition_model_changed()
        self.sc_charges.setChecked(self._bool_option("SCCHARGES"))
        self.sc_radius.setText(self._option("SCCRADIUS", "8"))
        self.complete_charge_molecules.setChecked(self._bool_option("DEFRAG"))
        self.use_dipoles.setChecked(self._bool_option("SCDIPOLES"))
        self.nuclear_interaction.setChecked(self._bool_option("ADDNUCINTER"))
        self.explicit_molecules.setChecked(self._bool_option("EXPLICITMOL"))
        self.explicit_radius.setText(self._option("EXPLRADIUS", "3"))
        self.complete_explicit_molecules.setChecked(
            self._bool_option("DEFRAGEXPL")
        )
        if self._bool_option("POSONLY"):
            self.refine_pos_only.setChecked(True)
        elif self._bool_option("ADPSONLY"):
            self.refine_adps_only.setChecked(True)
        else:
            self.refine_pos_adp.setChecked(True)
        self.iam_tonto.setChecked(self._bool_option("IAMTONTO"))
        self.only_iam_tonto.setChecked(self._bool_option("ONLYIAMTONTO"))
        self.refine_nothing.setChecked(self._bool_option("REFNOTHING"))
        self.atom_list.setText(self._option("ATOMLIST"))
        self.refine_uiso.setChecked(self._bool_option("REFUISO"))
        self.atom_uiso_list.setText(self._option("ATOMUISOLIST"))
        self.refine_h_positions.setChecked(self._bool_option("REFHPOS", True))
        self.refine_h_adps.setChecked(self._bool_option("REFHADP", True))
        self.h_adp.setChecked(self._bool_option("HADP"))
        self.refine_anharmonic.setChecked(self._bool_option("REFANHARM"))
        self.anharmonic_atoms.setText(self._option("ANHARMATOMS"))
        self.third_order.setChecked(self._bool_option("THIRDORD"))
        self.fourth_order.setChecked(self._bool_option("FOURTHORD"))
        self.elongate_xh.setChecked(self._bool_option("XHALONG"))
        self.bh_bond.setText(self._option("BHBOND", "1.190"))
        self.ch_bond.setText(self._option("CHBOND", "1.083"))
        self.nh_bond.setText(self._option("NHBOND", "1.009"))
        self.oh_bond.setText(self._option("OHBOND", "0.983"))
        self.dispersion_correction.setChecked(self._bool_option("DISP"))
        self.energy_convergence.setText(self._option("CONVTOLE", "0.00001"))
        self.linear_dependence.setText(self._option("LINEDEP"))
        self.max_ls_cycles.setValue(self._int_option("MAXLSCYCLE", 30))
        self.max_xtal_cycles.setText(self._option("MAXXTALCYCLE"))
        self.supercon.setChecked(self._bool_option("SUPERCON"))
        self.shrink_a.setValue(self._int_option("SHRINKA", 2))
        self.shrink_b.setValue(self._int_option("SHRINKB", 2))
        self.max_phar_cycles.setValue(self._int_option("MAXPHARCYCLE", 10))
        self.nsa2_accuracy.setValue(self._int_option("NSA2ACC", 2))
        self.minimum_correlation.setText(self._option("MINCORCOEF"))
        self.powder_har.setChecked(self._bool_option("POWDER_HAR"))
        self.use_nosphera2.setChecked(self._bool_option("USENOSPHERA2"))
        self.use_becke.setChecked(self._bool_option("USEBECKE"))
        self._set_combo_text(
            self.becke_accuracy, self._option("ACCURACY", "very_low")
        )
        self._set_combo_text(
            self.becke_pruning,
            self._option("BECKEPRUNINGSCHEME", "none"),
        )
        self.har_energy_repeat_tol.setText(
            self._option("HAR_ENERGY_REPEAT_TOL", "1.0E-10")
        )
        self.har_scf_rmsd_tol.setText(
            self._option("HAR_SCF_RMSD_TOL", "1.0E-8")
        )
        self.use_gamess.setChecked(self._bool_option("USEGAMESS"))
        self.n_disulfide.setValue(self._int_option("NSSBOND", 0))
        self.disulfide_atoms.setPlainText(self._option("SSBONDATOMS"))
        self.n_tail.setValue(self._int_option("NTAIL", 0))
        self.atom_tail.setValue(self._int_option("ATAIL", 100))
        self.fragment_tail.setValue(self._int_option("FRTAIL", 200))
        self.manual_residue.setPlainText(self._option("MANUALRESIDUE"))
        self.xcw_only.setChecked(self._bool_option("XCWONLY"))
        self.xray_restrained.setChecked(self._bool_option("XWR"))
        self._set_combo_text(self.method_xcw, self._option("METHODXCW", "rhf"))
        self._set_combo_text(
            self.basis_xcw, self._option("BASISSETTXCW", "STO-3G")
        )
        self.xcw_sc_charges.setChecked(self._bool_option("SCCHARGESXCW"))
        self.xcw_sc_radius.setText(self._option("SCCRADIUSXCW", "8"))
        self.xcw_defragment.setChecked(self._bool_option("DEFRAGXCW"))
        self.lambda_initial.setText(self._option("LAMBDAINITIAL", "0"))
        self.lambda_step.setText(self._option("LAMBDASTEP", "0.1"))
        self.lambda_max.setText(self._option("LAMBDAMAX", "1"))
        self.plot_tonto.setChecked(self._bool_option("PLOT_TONTO"))
        self.plot_deformation.setChecked(self._bool_option("DEFDEN"))
        self.plot_dft_xc.setChecked(self._bool_option("DFTXCPOT"))
        self.plot_density.setChecked(self._bool_option("DENS"))
        self.plot_laplacian.setChecked(self._bool_option("LAPL"))
        self.plot_negative_laplacian.setChecked(self._bool_option("NEGLAPL"))
        self.plot_promolecule.setChecked(self._bool_option("PROMOL"))
        self.plot_angstrom.setChecked(self._bool_option("PLOT_ANGS"))
        self.use_separation.setChecked(self._bool_option("USESEPARATION"))
        self.separation.setText(self._option("SEPARATION"))
        self.use_all_points.setChecked(self._bool_option("USEALLPOINTS"))
        self.points_x.setValue(self._int_option("PTSX", 10))
        self.points_y.setValue(self._int_option("PTSY", 10))
        self.points_z.setValue(self._int_option("PTSZ", 10))
        self.use_center.setChecked(self._bool_option("USECENTER"))
        self.center_atom.setValue(self._int_option("CENTERATOM", 1))
        self.x_axis.setText(self._option("XAXIS", "1 2"))
        self.y_axis.setText(self._option("YAXIS", "1 3"))
        self.width_x.setText(self._option("WIDTHX", "10"))
        self.width_y.setText(self._option("WIDTHY", "10"))
        self.width_z.setText(self._option("WIDTHZ", "10"))
        self.tonto_bin.setText(self._option("TONTO", "tonto"))
        self.gaussian_bin.setText(self._option("GAUSSIAN_BIN", "g09"))
        self.orca_bin.setText(self._option("ORCA_BIN", "orca"))
        self.occ_bin.setText(self._option("OCC_BIN", "occ"))
        self.crystal_bin.setText(self._option("CRYSTAL_BIN", "runcry23"))
        self.elmodb_bin.setText(self._option("ELMODB_BIN", "elmodb"))
        self.gamess_bin.setText(self._option("GAMESS", "gamess_int"))
        self.jana_bin.setText(self._option("JANAEXE", "jana2006"))
        self.basis_directory.setText(
            self._option("BASISSETDIR", "/usr/local/bin/basis_sets")
        )
        self.xcw_basis_directory.setText(
            self._option("BASISSETDIRXCW", "/usr/local/bin/basis_sets")
        )
        self.elmo_library.setText(
            self._option("ELMOLIB", "/usr/local/bin/LIBRARIES")
        )
        self.tonto_basis_directory.setText(self._option("TONTO_BASIS_DIR"))
        self.cp2k_bin.setText(self._option("CP2K_BIN"))
        self.cp2k_basis_file.setText(
            self._option("CP2K_BASIS_SET_FILE") or self._guess_cp2k_basis_file()
        )
        self.kpoints.setText(self._option("CP2K_KPOINT_GRID", "2 2 2"))
        self.cp2k_cutoff.setText(self._option("CP2K_CUTOFF", "1200"))
        self.cp2k_rel_cutoff.setText(self._option("CP2K_REL_CUTOFF", "80"))
        self.cp2k_max_scf.setValue(self._int_option("CP2K_MAX_SCF", 100))
        self.cp2k_eps_scf.setText(self._option("CP2K_EPS_SCF", "1.0E-8"))
        self.cp2k_added_mos.setValue(self._int_option("CP2K_ADDED_MOS", 20))
        self._program_changed()
        self._set_combo_text(self.method, self._option("METHOD", "rhf"))
        basis_name = (
            self._option("BASISSETT", "STO-3G")
            if program == "Tonto"
            else self._option("BASISSETG", "STO-3G")
        )
        self._set_combo_text(self.basis, basis_name)
        self._reload_cp2k_bases()
        self._set_combo_text(
            self.cp2k_basis,
            self._option(
                "CP2K_BASIS_SET",
                self._option("CP2K_BASIS", "aug-SZV-MOLOPT-ae-SR"),
            ),
        )
        self._set_combo_text(
            self.cp2k_functional, self._option("CP2K_XC_FUNCTIONAL", "BLYP")
        )
        if self.cif_path.text():
            self._load_cif_from_field()
        self._header_changed()
        self._initial_adp_changed()
        self._external_basis_changed()
        self._cluster_controls_changed()
        self._refinement_controls_changed()
        self.statusBar().showMessage(f"Loaded {self.option_path}", 5000)

    def _int_option(self, name: str, default: int) -> int:
        try:
            return int(float(self._option(name, str(default))))
        except ValueError:
            return default

    def _float_option(self, name: str, default: float) -> float:
        try:
            return float(self._option(name, str(default)))
        except ValueError:
            return default

    def _bool_option(self, name: str, default: bool = False) -> bool:
        value = self._option(name)
        if not value:
            return default
        return value.strip().lower() in {"true", "yes", "1", "on"}

    def _guess_cp2k_basis_file(self) -> str:
        candidates: list[Path] = []
        data_dir = os.environ.get("CP2K_DATA_DIR")
        if data_dir:
            candidates.append(Path(data_dir) / "BASIS_AUG_MOLOPT")
        if self.cp2k_bin.text().strip():
            executable = Path(self.cp2k_bin.text()).expanduser()
            candidates.extend(
                (
                    executable.parent.parent / "share" / "cp2k" / "data" / "BASIS_AUG_MOLOPT",
                    executable.parent.parent.parent
                    / "share"
                    / "cp2k"
                    / "data"
                    / "BASIS_AUG_MOLOPT",
                )
            )
        candidates.extend(
            (
                Path.home()
                / "cp2k-master"
                / "install"
                / "share"
                / "cp2k"
                / "data"
                / "BASIS_AUG_MOLOPT",
                Path("/usr/local/share/cp2k/data/BASIS_AUG_MOLOPT"),
                Path("/usr/share/cp2k/data/BASIS_AUG_MOLOPT"),
            )
        )
        return next((str(path) for path in candidates if path.is_file()), "")

    def _header_changed(self) -> None:
        enabled = self.write_header.isChecked()
        self.header_on_f.setEnabled(enabled)
        self.header_on_f2.setEnabled(enabled)

    def _initial_adp_changed(self) -> None:
        enabled = self.initial_adp.isChecked()
        self.initial_adp_path.setEnabled(enabled)
        self.initial_adp_button.setEnabled(enabled)

    def _external_basis_changed(self) -> None:
        enabled = self.external_basis.isChecked()
        self.basis_definition_path.setEnabled(enabled)
        self.edit_basis_button.setEnabled(enabled)

    def _cluster_controls_changed(self) -> None:
        charge_enabled = self.sc_charges.isChecked()
        self.sc_radius.setEnabled(charge_enabled)
        self.complete_charge_molecules.setEnabled(charge_enabled)
        self.use_dipoles.setEnabled(charge_enabled)
        self.nuclear_interaction.setEnabled(
            charge_enabled
            and self.program.currentData() in {"Orca", "optorca"}
        )
        explicit_enabled = self.explicit_molecules.isChecked()
        self.explicit_radius.setEnabled(explicit_enabled)
        self.complete_explicit_molecules.setEnabled(explicit_enabled)

    def _refinement_controls_changed(self) -> None:
        self.only_iam_tonto.setEnabled(self.iam_tonto.isChecked())
        self.atom_list.setEnabled(self.refine_nothing.isChecked())
        self.atom_uiso_list.setEnabled(self.refine_uiso.isChecked())
        anharmonic = self.refine_anharmonic.isChecked()
        self.anharmonic_atoms.setEnabled(anharmonic)
        self.third_order.setEnabled(anharmonic)
        self.fourth_order.setEnabled(anharmonic)
        elongate = self.elongate_xh.isChecked()
        for widget in (self.bh_bond, self.ch_bond, self.nh_bond, self.oh_bond):
            widget.setEnabled(elongate)

    def _grow_mode_changed(self) -> None:
        mode = self.grow_mode.currentData()
        uses_distance = mode in {"radius", "short_contacts"}
        self.radius_label.setVisible(uses_distance)
        self.radius.setVisible(uses_distance)
        uses_vdw = mode == "vdw"
        self.vdw_tolerance_label.setVisible(uses_vdw)
        self.vdw_tolerance.setVisible(uses_vdw)

    @staticmethod
    def _set_combo_text(combo: QComboBox, text: str) -> None:
        index = combo.findText(text, Qt.MatchFlag.MatchFixedString)
        if index >= 0:
            combo.setCurrentIndex(index)
        else:
            combo.setEditText(text)

    def _program_changed(self, *_args) -> None:
        program = self.program.currentData() or "Gaussian"
        old_method = self.method.currentText()
        old_basis = self.basis.currentText()
        self.method.clear()
        self.method.addItems(METHODS.get(program, ()))
        self.basis.clear()
        if program in {"Gaussian", "optgaussian"}:
            self.basis.addItems(GAUSSIAN_BASIS)
        elif program in {"Orca", "optorca"}:
            self.basis.addItems(ORCA_BASIS)
        else:
            self.basis.addItems(BASIS.get(program, ()))
        if old_method:
            self._set_combo_text(self.method, old_method)
        if old_basis:
            self._set_combo_text(self.basis, old_basis)
        legacy_method = program != "CP2K"
        self.method.setVisible(legacy_method)
        self.method_label.setVisible(legacy_method)
        self.basis.setVisible(program != "CP2K")
        self.basis_label.setVisible(program != "CP2K")
        gaussian = program in {"Gaussian", "optgaussian"}
        self.extra_keywords.setVisible(gaussian)
        self.extra_keywords_label.setVisible(gaussian)
        self.gaussian_features.setVisible(gaussian)
        self.cluster_group.setVisible(
            program not in {"elmodb", "Crystal14", "CP2K"}
        )
        self.crystal_group.setVisible(program == "Crystal14")
        self.stockholder_group.setVisible(
            program in {"Tonto", "Crystal14", "CP2K"}
        )
        has_reflections = program not in {"optgaussian", "optorca"}
        self.hkl_label.setVisible(has_reflections)
        self.hkl_row.setVisible(has_reflections)
        self.header_group.setVisible(has_reflections)
        self.initial_adp_group.setVisible(program == "elmodb")
        self.nuclear_interaction.setVisible(program in {"Orca", "optorca"})
        self.cp2k_group.setVisible(program == "CP2K")
        self._partition_model_changed()
        self._cluster_controls_changed()
        # Some Linux Qt themes leave this popup visible while the dependent
        # controls are being rebuilt. Explicitly close it after selection.
        QTimer.singleShot(0, self.program.hidePopup)

    def _partition_model_changed(self, *_args) -> None:
        program = self.program.currentData() or "Gaussian"
        tonto = program == "Tonto"
        periodic = program in {"Crystal14", "CP2K"}
        observed = tonto and self.partition_model.currentData() == "oc-observed"
        self.stockholder_group.setTitle(
            "Tonto density partition" if tonto else "Periodic stockholder model"
        )
        self.partition_model_label.setVisible(tonto)
        self.partition_model.setVisible(tonto)
        self.stockholder_model_label.setVisible(periodic)
        self.stockholder_model.setVisible(periodic)
        for widget in (
            self.observed_shrinkage_label,
            self.observed_shrinkage,
            self.observed_min_tf_label,
            self.observed_min_tf,
            self.observed_zero_phase_sign_label,
            self.observed_zero_phase_sign,
        ):
            widget.setVisible(observed)

    def _program_activated(self, *_args) -> None:
        self.program.hidePopup()

    def _reload_cp2k_bases(self) -> None:
        current = self.cp2k_basis.currentText() or "aug-SZV-MOLOPT-ae-SR"
        choices = cp2k_basis_names(self.cp2k_basis_file.text())
        if current and current not in choices:
            choices.insert(0, current)
        if not choices:
            choices = ["aug-SZV-MOLOPT-ae-SR"]
        self.cp2k_basis.clear()
        self.cp2k_basis.addItems(choices)
        self._set_combo_text(self.cp2k_basis, current)

    def _load_cif_from_field(self) -> None:
        value = self.cif_path.text().strip()
        if not value or not re_is_cif_path(Path(value)):
            return
        path = Path(value).expanduser()
        if not path.is_absolute():
            path = self.option_path.parent / path
        try:
            self._load_structure(path)
        except (CifError, OSError, ValueError) as exc:
            self.structure = None
            QMessageBox.critical(self, "Could not load CIF", str(exc))

    def _load_structure(self, path: Path, *, automatic: bool = False) -> None:
        structure = CrystalStructure.from_cif(path)
        atoms = structure.asymmetric_unit()
        self.structure = structure
        self.visible_atoms = atoms
        self.current_grow_description = "asymmetric unit"
        self._displayed_cif = path.resolve()
        if automatic:
            self._cif_watch_baseline[path.resolve()] = path.stat().st_mtime_ns
        else:
            self._initial_cif = path.resolve()
            self._reset_cif_watch_baseline()
        self.viewer.set_structure(structure.cell, atoms)
        prefix = "Automatically refreshed" if automatic else "Loaded"
        self.statusBar().showMessage(
            f"{prefix} {path.name}: {len(atoms)} asymmetric-unit atoms; "
            f"{len(structure.symmetry_operations)} symmetry operations",
            10000,
        )

    def _tonto_output_candidates(self) -> list[Path]:
        job_name = self.job_name.text().strip()
        if not job_name:
            return []
        escaped_job = re.escape(job_name)
        output_pattern = re.compile(
            rf"(?:[0-9]+\.)?{escaped_job}\."
            r"(?:cartesian\.cif2|fractional\.cif1|archive\.cif)$",
            re.IGNORECASE,
        )
        live_name = f"{job_name}.latest_tonto.cif".lower()
        result: list[Path] = []
        for path in self.option_path.parent.rglob("*"):
            if not path.is_file():
                continue
            name = path.name
            if name.lower() == live_name or output_pattern.fullmatch(name):
                result.append(path)
        return result

    def _reset_cif_watch_baseline(self) -> None:
        self._latest_cif_stamp = None
        baseline: dict[Path, int] = {}
        try:
            for path in self._tonto_output_candidates():
                baseline[path.resolve()] = path.stat().st_mtime_ns
        except OSError:
            pass
        self._cif_watch_baseline = baseline

    def _refresh_latest_cif(self) -> None:
        if not self.follow_latest_cif.isChecked() or self._initial_cif is None:
            return
        try:
            changed: list[tuple[Path, int]] = []
            for path in self._tonto_output_candidates():
                resolved = path.resolve()
                modified = path.stat().st_mtime_ns
                if self._cif_watch_baseline.get(resolved) != modified:
                    changed.append((path, modified))
            if not changed:
                return
            newest, modified = max(changed, key=lambda item: item[1])
            stamp = (newest.resolve(), modified)
            if stamp == self._latest_cif_stamp:
                return
            self._load_structure(newest, automatic=True)
            self._latest_cif_stamp = stamp
        except (CifError, OSError, ValueError):
            # A Tonto CIF can briefly be incomplete while it is being written.
            # The next timer event retries after the file settles.
            return

    def apply_grow(self) -> None:
        if not self.structure:
            QMessageBox.information(self, "No structure", "Open a CIF first.")
            return
        mode = self.grow_mode.currentData()
        try:
            if mode == "asu":
                atoms = self.structure.asymmetric_unit()
                description = "asymmetric unit"
            elif mode == "cell":
                atoms = self.structure.unit_cell()
                description = "complete unit cell"
            elif mode == "molecules":
                atoms = self.structure.complete_molecules(self.visible_atoms)
                description = (
                    f"{self.current_grow_description} + completed fragment(s)/molecule(s)"
                )
            elif mode == "short_contacts":
                atoms = self.structure.short_contacts(
                    self.radius.value(), self.visible_atoms
                )
                description = (
                    f"{self.current_grow_description} + short contacts within "
                    f"{self.radius.value():g} Angstrom"
                )
            elif mode == "vdw":
                atoms = self.structure.vdw_contacts(
                    self.vdw_tolerance.value(), self.visible_atoms
                )
                description = (
                    f"{self.current_grow_description} + contacts within van der Waals radii "
                    f"+ {self.vdw_tolerance.value():g} Angstrom"
                )
            elif mode == "supercell":
                atoms = self.structure.supercell(1)
                description = "3x3x3 neighbouring-cell pack"
            else:
                center = self.viewer.selected_atom()
                if center is None:
                    QMessageBox.information(
                        self,
                        "Select an atom",
                        "Click the atom that should be the centre of radius growth.",
                    )
                    return
                atoms = self.structure.within_radius(
                    center, self.radius.value(), self.visible_atoms
                )
                description = (
                    f"{self.current_grow_description} + atoms within "
                    f"{self.radius.value():g} Angstrom of {center.label}"
                )
            self.visible_atoms = atoms
            self.current_grow_description = description
            self.viewer.set_structure(self.structure.cell, atoms)
            self.statusBar().showMessage(
                f"{description}: {len(atoms)} atoms are now in the export geometry",
                10000,
            )
        except (CifError, ValueError) as exc:
            QMessageBox.critical(self, "Could not grow structure", str(exc))

    def export_grown_cif(self) -> None:
        if not self.structure or not self.visible_atoms:
            QMessageBox.information(self, "No structure", "Open and grow a CIF first.")
            return
        source = Path(self.cif_path.text()).expanduser()
        if not source.is_absolute():
            source = self.option_path.parent / source
        suggested = source.with_name(source.stem + "_lamagoet_grown.cif")
        filename, _ = QFileDialog.getSaveFileName(
            self, "Export grown structure", str(suggested), "CIF files (*.cif)"
        )
        if not filename:
            return
        try:
            output = write_grown_cif(
                filename,
                self.structure,
                self.visible_atoms,
                source_description=self.current_grow_description,
            )
        except (CifError, OSError) as exc:
            QMessageBox.critical(self, "Could not export CIF", str(exc))
            return
        answer = QMessageBox.question(
            self,
            "Use grown geometry?",
            f"Created {output}\n\nThe original cell and symmetry were retained. "
            "Use this grown QM fragment as the CIF for the job?",
        )
        if answer == QMessageBox.StandardButton.Yes:
            self.cif_path.setText(str(output))
        self.statusBar().showMessage(f"Exported {len(self.visible_atoms)} atoms to {output}")

    def _current_values(self) -> dict[str, object]:
        program = self.program.currentData() or "Gaussian"
        if program == "Tonto":
            partition_model = self.partition_model.currentData()
        elif program in {"Crystal14", "CP2K"}:
            partition_model = "oc-crystal23"
        else:
            partition_model = "oc-hirshfeld"
        result: dict[str, object] = {
            "SCFCALCPROG": program,
            "JOBNAME": self.job_name.text().strip() or "my_job",
            "CIF": self.cif_path.text().strip(),
            "HKL": self.hkl_path.text().strip(),
            "CHARGE": self.charge.value(),
            "MULTIPLICITY": self.multiplicity.value(),
            "WAVE": self.wave.text().strip(),
            "FCUT": self.fcut.text().strip(),
            "NUMPROC": self.processors.value(),
            "NUMPROCTONTO": self.tonto_processors.value(),
            "CONVTOL": self.convergence.text().strip(),
            "MAXCYCLE": self.max_cycles.value(),
            "MEM": self.memory.text().strip(),
            "MEMPBS": self.pbs_memory.text().strip(),
            "COMPLETESTRUCT": _bool_text(self.complete_structure.isChecked()),
            "INITADP": _bool_text(self.initial_adp.isChecked()),
            "INITADPFILE": self.initial_adp_path.text().strip(),
            "WRITEHEADER": _bool_text(self.write_header.isChecked()),
            "ONF": _bool_text(
                self.write_header.isChecked() and self.header_on_f.isChecked()
            ),
            "ONF2": _bool_text(
                self.write_header.isChecked() and self.header_on_f2.isChecked()
            ),
            "USEEQUIV": _bool_text(self.use_equivalents.isChecked()),
            "GAUSGEN": _bool_text(self.external_basis.isChecked()),
            "GAUSSEMPDISP": _bool_text(self.grimme.isChecked()),
            "GAUSSREL": _bool_text(self.relativistic.isChecked()),
            "USEHMSYM": _bool_text(self.use_hm_symbol.isChecked()),
            "DEFRAGNETW": _bool_text(self.network_compound.isChecked()),
            "USEGUESS": _bool_text(self.use_previous_crystal_guess.isChecked()),
            "CRYSTAL_SETTING": self.crystal_setting.currentData(),
            "PARTITION_MODEL": partition_model,
            "STOCKHOLDER_MODEL": self.stockholder_model.currentData(),
            "OBSERVED_DENSITY_SHRINKAGE": self.observed_shrinkage.value(),
            "OBSERVED_DENSITY_MIN_TF": self.observed_min_tf.value(),
            "OBSERVED_ZERO_PHASE_SIGN": self.observed_zero_phase_sign.currentData(),
            "SCCHARGES": _bool_text(self.sc_charges.isChecked()),
            "SCCRADIUS": self.sc_radius.text().strip(),
            "DEFRAG": _bool_text(self.complete_charge_molecules.isChecked()),
            "SCDIPOLES": _bool_text(self.use_dipoles.isChecked()),
            "ADDNUCINTER": _bool_text(
                program in {"Orca", "optorca"}
                and self.nuclear_interaction.isChecked()
            ),
            "EXPLICITMOL": _bool_text(self.explicit_molecules.isChecked()),
            "EXPLRADIUS": self.explicit_radius.text().strip(),
            "DEFRAGEXPL": _bool_text(
                self.complete_explicit_molecules.isChecked()
            ),
            "POSADP": _bool_text(self.refine_pos_adp.isChecked()),
            "POSONLY": _bool_text(self.refine_pos_only.isChecked()),
            "ADPSONLY": _bool_text(self.refine_adps_only.isChecked()),
            "IAMTONTO": _bool_text(self.iam_tonto.isChecked()),
            "ONLYIAMTONTO": _bool_text(self.only_iam_tonto.isChecked()),
            "REFNOTHING": _bool_text(self.refine_nothing.isChecked()),
            "ATOMLIST": self.atom_list.text().strip(),
            "REFUISO": _bool_text(self.refine_uiso.isChecked()),
            "ATOMUISOLIST": self.atom_uiso_list.text().strip(),
            "REFHPOS": _bool_text(self.refine_h_positions.isChecked()),
            "REFHADP": _bool_text(self.refine_h_adps.isChecked()),
            "HADP": "yes" if self.h_adp.isChecked() else "no",
            "REFANHARM": _bool_text(self.refine_anharmonic.isChecked()),
            "ANHARMATOMS": self.anharmonic_atoms.text().strip(),
            "THIRDORD": _bool_text(self.third_order.isChecked()),
            "FOURTHORD": _bool_text(self.fourth_order.isChecked()),
            "XHALONG": _bool_text(self.elongate_xh.isChecked()),
            "BHBOND": self.bh_bond.text().strip(),
            "CHBOND": self.ch_bond.text().strip(),
            "NHBOND": self.nh_bond.text().strip(),
            "OHBOND": self.oh_bond.text().strip(),
            "DISP": "yes" if self.dispersion_correction.isChecked() else "no",
            "CONVTOLE": self.energy_convergence.text().strip(),
            "LINEDEP": self.linear_dependence.text().strip(),
            "MAXLSCYCLE": self.max_ls_cycles.value(),
            "MAXXTALCYCLE": self.max_xtal_cycles.text().strip(),
            "SUPERCON": _bool_text(self.supercon.isChecked()),
            "SHRINKA": self.shrink_a.value(),
            "SHRINKB": self.shrink_b.value(),
            "MAXPHARCYCLE": self.max_phar_cycles.value(),
            "NSA2ACC": self.nsa2_accuracy.value(),
            "MINCORCOEF": self.minimum_correlation.text().strip(),
            "POWDER_HAR": _bool_text(self.powder_har.isChecked()),
            "USENOSPHERA2": _bool_text(self.use_nosphera2.isChecked()),
            "USEBECKE": _bool_text(self.use_becke.isChecked()),
            "ACCURACY": self.becke_accuracy.currentText().strip(),
            "BECKEPRUNINGSCHEME": self.becke_pruning.currentText().strip(),
            "HAR_ENERGY_REPEAT_TOL": self.har_energy_repeat_tol.text().strip(),
            "HAR_SCF_RMSD_TOL": self.har_scf_rmsd_tol.text().strip(),
            "USEGAMESS": _bool_text(self.use_gamess.isChecked()),
            "NSSBOND": self.n_disulfide.value(),
            "SSBONDATOMS": self.disulfide_atoms.toPlainText(),
            "NTAIL": self.n_tail.value(),
            "ATAIL": self.atom_tail.value(),
            "FRTAIL": self.fragment_tail.value(),
            "MANUALRESIDUE": self.manual_residue.toPlainText(),
            "XCWONLY": _bool_text(self.xcw_only.isChecked()),
            "XWR": _bool_text(self.xray_restrained.isChecked()),
            "METHODXCW": self.method_xcw.currentText().strip(),
            "BASISSETTXCW": self.basis_xcw.currentText().strip(),
            "SCCHARGESXCW": _bool_text(self.xcw_sc_charges.isChecked()),
            "SCCRADIUSXCW": self.xcw_sc_radius.text().strip(),
            "DEFRAGXCW": _bool_text(self.xcw_defragment.isChecked()),
            "LAMBDAINITIAL": self.lambda_initial.text().strip(),
            "LAMBDASTEP": self.lambda_step.text().strip(),
            "LAMBDAMAX": self.lambda_max.text().strip(),
            "PLOT_TONTO": _bool_text(self.plot_tonto.isChecked()),
            "DEFDEN": _bool_text(self.plot_deformation.isChecked()),
            "DFTXCPOT": _bool_text(self.plot_dft_xc.isChecked()),
            "DENS": _bool_text(self.plot_density.isChecked()),
            "LAPL": _bool_text(self.plot_laplacian.isChecked()),
            "NEGLAPL": _bool_text(self.plot_negative_laplacian.isChecked()),
            "PROMOL": _bool_text(self.plot_promolecule.isChecked()),
            "PLOT_ANGS": _bool_text(self.plot_angstrom.isChecked()),
            "USESEPARATION": _bool_text(self.use_separation.isChecked()),
            "SEPARATION": self.separation.text().strip(),
            "USEALLPOINTS": _bool_text(self.use_all_points.isChecked()),
            "PTSX": self.points_x.value(),
            "PTSY": self.points_y.value(),
            "PTSZ": self.points_z.value(),
            "USECENTER": _bool_text(self.use_center.isChecked()),
            "CENTERATOM": self.center_atom.value(),
            "XAXIS": self.x_axis.text().strip(),
            "YAXIS": self.y_axis.text().strip(),
            "WIDTHX": self.width_x.text().strip(),
            "WIDTHY": self.width_y.text().strip(),
            "WIDTHZ": self.width_z.text().strip(),
            "TONTO": self.tonto_bin.text().strip(),
            "GAUSSIAN_BIN": self.gaussian_bin.text().strip(),
            "ORCA_BIN": self.orca_bin.text().strip(),
            "OCC_BIN": self.occ_bin.text().strip(),
            "CRYSTAL_BIN": self.crystal_bin.text().strip(),
            "ELMODB_BIN": self.elmodb_bin.text().strip(),
            "GAMESS": self.gamess_bin.text().strip(),
            "JANAEXE": self.jana_bin.text().strip(),
            "BASISSETDIR": self.basis_directory.text().strip(),
            "BASISSETDIRXCW": self.xcw_basis_directory.text().strip(),
            "ELMOLIB": self.elmo_library.text().strip(),
            "TONTO_BASIS_DIR": self.tonto_basis_directory.text().strip(),
            "EXIT": "OK",
        }
        if self.submission_mode == "cluster":
            result["EMAIL"] = self.email.text().strip()
        if program != "CP2K":
            result["METHOD"] = self.method.currentText().strip()
            result["BASISSETT" if program == "Tonto" else "BASISSETG"] = (
                self.basis.currentText().strip()
            )
        if program in {"Gaussian", "optgaussian"}:
            result["EXTRAKEY"] = self.extra_keywords.text()
        if program == "CP2K":
            result.update(
                {
                    "CP2K_BIN": self.cp2k_bin.text().strip(),
                    "CP2K_BASIS_SET_FILE": self.cp2k_basis_file.text().strip(),
                    "CP2K_BASIS_SET": self.cp2k_basis.currentText().strip(),
                    "CP2K_XC_FUNCTIONAL": self.cp2k_functional.currentText(),
                    "CP2K_KPOINT_GRID": self.kpoints.text().strip(),
                    "CP2K_CELL_CHARGE": self.charge.value(),
                    "CP2K_CELL_MULTIPLICITY": self.multiplicity.value(),
                    "CP2K_CUTOFF": self.cp2k_cutoff.text().strip(),
                    "CP2K_REL_CUTOFF": self.cp2k_rel_cutoff.text().strip(),
                    "CP2K_MAX_SCF": self.cp2k_max_scf.value(),
                    "CP2K_EPS_SCF": self.cp2k_eps_scf.text().strip(),
                    "CP2K_ADDED_MOS": self.cp2k_added_mos.value(),
                }
            )
        return result

    def _prepare_basis_definition(self) -> None:
        if not self.external_basis.isChecked():
            return
        target = self.option_path.parent / "basis_gen.txt"
        source_text = self.basis_definition_path.text().strip()
        source = Path(source_text).expanduser() if source_text else target
        if not source.is_absolute():
            source = self.option_path.parent / source
        if not source.is_file():
            raise OSError(
                "External basis input is enabled, but no basis definition exists. "
                "Use “Load file…” or “Edit definition…”."
            )
        if source.resolve() != target.resolve():
            shutil.copy2(source, target)
        self.basis_definition_path.setText(str(target))

    def _prepare_crystal_spacegroup(self) -> None:
        """Stage the Crystal23 setting chosen in Qt for local/PBS runners."""

        if self.program.currentData() != "Crystal14":
            return
        structure = self.structure
        if structure is None:
            value = self.cif_path.text().strip()
            if value:
                path = Path(value).expanduser()
                if not path.is_absolute():
                    path = self.option_path.parent / path
                structure = CrystalStructure.from_cif(path)
        if structure is None:
            raise OSError("Open the Crystal23 CIF before saving the job.")
        setting = self.crystal_setting.currentData()
        if setting == "auto":
            cell = structure.cell
            rhombohedral_name = structure.space_group_name.strip().upper().startswith("R")
            rhombohedral_cell = (
                abs(cell.a - cell.b) < 1.0e-5
                and abs(cell.b - cell.c) < 1.0e-5
                and abs(cell.alpha - cell.beta) < 1.0e-4
                and abs(cell.beta - cell.gamma) < 1.0e-4
                and abs(cell.gamma - 120.0) > 1.0e-3
            )
            setting = "r" if rhombohedral_name and rhombohedral_cell else "h"
        # Keep the exact three-column contract produced by SPACEGROUPMENU:
        # number/setting = International Tables symbol/setting = Hall symbol.
        # The shell runner reads column 2 and derives XTALSETTING from its
        # optional :r suffix.
        (self.option_path.parent / "spacegroup.txt").write_text(
            crystal23_spacegroup_record(structure, setting),
            encoding="utf-8",
            newline="\n",
        )

    def save_options(self) -> Path | None:
        try:
            self._prepare_basis_definition()
            self._prepare_crystal_spacegroup()
            output = save_job_options(
                self.option_path,
                self._current_values(),
                preserved=self.saved_options,
            )
            self.saved_options = load_job_options(output)
        except (CifError, OSError, ValueError) as exc:
            QMessageBox.critical(self, "Could not save options", str(exc))
            return None
        self.statusBar().showMessage(f"Saved {output}", 8000)
        return output

    def _stage_cluster_input(self, widget: QLineEdit, *, required: bool) -> None:
        value = widget.text().strip()
        if not value:
            if required:
                raise SubmissionError("Select the required input file before submitting.")
            return
        source = Path(value).expanduser()
        if not source.is_absolute():
            source = self.option_path.parent / source
        if not source.is_file():
            raise SubmissionError(f"Input file was not found: {source}")
        target = self.option_path.parent / source.name
        if source.resolve() != target.resolve():
            if target.exists() and target.read_bytes() != source.read_bytes():
                raise SubmissionError(
                    f"{target.name} already exists in the calculation directory "
                    "with different contents."
                )
            if not target.exists():
                shutil.copy2(source, target)
        widget.setText(f"./{target.name}")

    def submit_job(self) -> None:
        if self.submission_mode == "local":
            self._start_local_job()
            return
        try:
            self._stage_cluster_input(self.cif_path, required=True)
            if self.program.currentData() not in {"optgaussian", "optorca"}:
                self._stage_cluster_input(self.hkl_path, required=False)
            if self.program.currentData() == "elmodb" and self.initial_adp.isChecked():
                self._stage_cluster_input(self.initial_adp_path, required=True)
            output = self.save_options()
            if output is None:
                return
            values = self._current_values()
            pbs = write_pbs_script(self.option_path.parent / "lamaGOET.pbs", values)
            if os.environ.get("LAMAGOET_QT_DRY_RUN", "").lower() in {
                "1",
                "true",
                "yes",
            }:
                self.statusBar().showMessage(
                    f"Dry run: wrote {output.name} and {pbs.name}", 10000
                )
                return
            qsub = shutil.which("qsub")
            if not qsub:
                raise SubmissionError(
                    f"Wrote {pbs}, but qsub was not found on this submitting computer."
                )
            completed = subprocess.run(
                [qsub, pbs.name],
                cwd=self.option_path.parent,
                text=True,
                capture_output=True,
                check=False,
            )
            if completed.returncode:
                raise SubmissionError(
                    completed.stderr.strip()
                    or completed.stdout.strip()
                    or f"qsub exited with status {completed.returncode}"
                )
        except (OSError, SubmissionError) as exc:
            QMessageBox.critical(self, "Cluster submission failed", str(exc))
            return
        job_id = completed.stdout.strip() or "submitted"
        self.cluster_job_id = job_id.split()[0]
        self.kill_button.setEnabled(job_id != "submitted")
        QMessageBox.information(
            self,
            "Job submitted",
            f"PBS accepted the job: {job_id}\n\n"
            "The window will remain open and follow new local Tonto CIF files.",
        )
        self.statusBar().showMessage(f"Submitted PBS job {job_id}", 15000)

    def _start_local_job(self) -> None:
        try:
            cif_value = self.cif_path.text().strip()
            if not cif_value:
                raise SubmissionError("Select a CIF/PDB input before running.")
            cif_path = Path(cif_value).expanduser()
            if not cif_path.is_absolute():
                cif_path = self.option_path.parent / cif_path
            if not cif_path.is_file():
                raise SubmissionError(f"Input file was not found: {cif_path}")
            if self.program.currentData() == "elmodb" and self.initial_adp.isChecked():
                adp_value = self.initial_adp_path.text().strip()
                adp_path = Path(adp_value).expanduser() if adp_value else Path()
                if not adp_value or (
                    not adp_path.is_absolute()
                    and not (self.option_path.parent / adp_path).is_file()
                ) or (adp_path.is_absolute() and not adp_path.is_file()):
                    raise SubmissionError(
                        "Select the precise-coordinate/ADP CIF before running ELMO."
                    )
            output = self.save_options()
            if output is None:
                return
            if os.environ.get("LAMAGOET_QT_DRY_RUN", "").lower() in {
                "1",
                "true",
                "yes",
            }:
                self.statusBar().showMessage(
                    f"Local dry run: wrote {output.name}; no PBS file was created",
                    10000,
                )
                return
            if self.local_process and self.local_process.poll() is None:
                raise SubmissionError("A local lamaGOET calculation is already running.")
            bash = shutil.which("bash")
            if not bash:
                raise SubmissionError(
                    "bash was not found; lamaGOET.sh cannot be started locally."
                )
            runner = Path(__file__).resolve().parents[1] / "lamaGOET.sh"
            if not runner.is_file():
                raise SubmissionError(f"Local runner was not found: {runner}")
            self.local_process = subprocess.Popen(
                [bash, str(runner), "--run-job-options", str(output)],
                cwd=self.option_path.parent,
                start_new_session=os.name != "nt",
                creationflags=(
                    subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
                ),
            )
        except (OSError, SubmissionError) as exc:
            QMessageBox.critical(self, "Local calculation could not start", str(exc))
            return
        self.statusBar().showMessage(
            f"Started local lamaGOET process {self.local_process.pid}", 15000
        )
        self.kill_button.setEnabled(True)
        QMessageBox.information(
            self,
            "Local calculation started",
            "lamaGOET.sh is running on this computer. Output remains visible in "
            "the launching terminal, and this window will follow new Tonto CIFs.",
        )

    def save_options_as(self) -> None:
        filename, _ = QFileDialog.getSaveFileName(
            self,
            "Save lamaGOET options",
            str(self.option_path),
            "lamaGOET options (*.txt);;All files (*)",
        )
        if filename:
            self.option_path = Path(filename).resolve()
            self.save_options()

    def choose_external_basis(self) -> None:
        filename, _ = QFileDialog.getOpenFileName(
            self,
            "Load external basis definition",
            str(self.option_path.parent),
            "Basis definition files (*.txt *.gbs);;All files (*)",
        )
        if filename:
            self.basis_definition_path.setText(filename)
            self.external_basis.setChecked(True)

    def edit_external_basis(self) -> None:
        dialog = QDialog(self)
        dialog.setWindowTitle("External basis definition")
        dialog.resize(760, 560)
        layout = QVBoxLayout(dialog)
        explanation = QLabel(
            "Enter the complete basis definition in the format required by the "
            "selected SCF program. It will be saved as basis_gen.txt."
        )
        explanation.setWordWrap(True)
        layout.addWidget(explanation)
        editor = QPlainTextEdit()
        source_text = self.basis_definition_path.text().strip()
        source = (
            Path(source_text).expanduser()
            if source_text
            else self.option_path.parent / "basis_gen.txt"
        )
        if not source.is_absolute():
            source = self.option_path.parent / source
        if source.is_file():
            editor.setPlainText(
                source.read_text(encoding="utf-8", errors="replace")
            )
        layout.addWidget(editor)
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Save
            | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(dialog.accept)
        buttons.rejected.connect(dialog.reject)
        layout.addWidget(buttons)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            target = self.option_path.parent / "basis_gen.txt"
            target.write_text(editor.toPlainText(), encoding="utf-8", newline="\n")
            self.basis_definition_path.setText(str(target))
            self.external_basis.setChecked(True)

    def choose_basis_exchange(self) -> None:
        if not self.structure:
            QMessageBox.information(
                self,
                "Open a CIF first",
                "The CIF is needed to determine which element selectors to show.",
            )
            return
        program = self.program.currentData() or "Gaussian"
        elements = sorted(
            {atom.element for atom in self.structure.asymmetric_unit()},
            key=str.casefold,
        )
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)
        try:
            available = {
                element: all_electron_basis_names(element) for element in elements
            }
        except BasisExchangeError as exc:
            QMessageBox.critical(self, "Basis Set Exchange", str(exc))
            return
        finally:
            QApplication.restoreOverrideCursor()
        missing = [element for element, names in available.items() if not names]
        if missing:
            QMessageBox.critical(
                self,
                "Basis Set Exchange",
                "No all-electron orbital GTO basis was found for: "
                + ", ".join(missing),
            )
            return

        dialog = QDialog(self)
        dialog.setWindowTitle("Basis Set Exchange - all-electron choices")
        dialog.resize(620, max(260, min(760, 150 + 55 * len(elements))))
        layout = QVBoxLayout(dialog)
        explanation = QLabel(
            "Only orbital GTO bases containing no ECP for the selected element "
            "are listed. Choose independently for each element."
        )
        explanation.setWordWrap(True)
        layout.addWidget(explanation)
        form = QFormLayout()
        selectors: dict[str, QComboBox] = {}
        preferred = (
            self.cp2k_basis.currentText()
            if program == "CP2K"
            else self.basis.currentText()
        )
        for element in elements:
            selector = QComboBox()
            selector.setMaxVisibleItems(24)
            selector.addItems(available[element])
            initial = common_preferred_basis(
                available[element],
                (preferred, "def2-TZVP", "cc-pVTZ", "6-31G(d,p)", "STO-3G"),
            )
            selector.setCurrentText(initial)
            form.addRow(element, selector)
            selectors[element] = selector
        form_page = QWidget()
        form_page.setLayout(form)
        form_scroll = QScrollArea()
        form_scroll.setWidgetResizable(True)
        form_scroll.setWidget(form_page)
        layout.addWidget(form_scroll, 1)
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok
            | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(dialog.accept)
        buttons.rejected.connect(dialog.reject)
        layout.addWidget(buttons)
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return

        selections = {
            element: selector.currentText() for element, selector in selectors.items()
        }
        try:
            text, cp2k_map = render_mixed_basis(program, selections)
            target = self.option_path.parent / "basis_gen.txt"
            target.write_text(text, encoding="utf-8", newline="\n")
        except (BasisExchangeError, OSError) as exc:
            QMessageBox.critical(self, "Basis Set Exchange", str(exc))
            return
        self.basis_definition_path.setText(str(target))
        self.external_basis.setChecked(True)
        if program in {"Gaussian", "optgaussian", "Crystal14"}:
            self._set_combo_text(self.basis, "gen")
        elif program in {"Orca", "optorca"}:
            self._set_combo_text(self.basis, "External")
        elif program == "CP2K":
            self.cp2k_basis_file.setText(str(target))
            self._set_combo_text(self.cp2k_basis, next(iter(selections.values())))
            self.saved_options["CP2K_BASIS_MAP"] = cp2k_map
        self.statusBar().showMessage(
            "Created all-electron mixed basis: "
            + ", ".join(
                f"{element}={name}" for element, name in selections.items()
            ),
            15000,
        )

    def choose_options(self) -> None:
        filename, _ = QFileDialog.getOpenFileName(
            self, "Open lamaGOET options", str(self.option_path.parent), "Text files (*.txt)"
        )
        if filename:
            self.load_options(filename)

    def choose_cif(self) -> None:
        filename, _ = QFileDialog.getOpenFileName(
            self,
            "Open structure",
            str(Path(self.cif_path.text()).parent if self.cif_path.text() else Path.cwd()),
            "Crystallographic files (*.cif *.pdb);;CIF files (*.cif);;All files (*)",
        )
        if filename:
            self.cif_path.setText(filename)
            self._load_cif_from_field()

    def choose_hkl(self) -> None:
        filename, _ = QFileDialog.getOpenFileName(
            self, "Open reflection file", str(Path.cwd()), "Reflection files (*.hkl);;All files (*)"
        )
        if filename:
            self.hkl_path.setText(filename)

    def choose_initial_adp(self) -> None:
        filename, _ = QFileDialog.getOpenFileName(
            self,
            "Open precise-coordinate/ADP CIF",
            str(Path.cwd()),
            "CIF files (*.cif);;All files (*)",
        )
        if filename:
            self.initial_adp_path.setText(filename)
            self.initial_adp.setChecked(True)

    def choose_cp2k_basis(self) -> None:
        filename, _ = QFileDialog.getOpenFileName(
            self, "Open CP2K basis file", str(Path.cwd()), "CP2K basis files (*)"
        )
        if filename:
            self.cp2k_basis_file.setText(filename)
            self._reload_cp2k_bases()

    def _choose_executable(self, widget: QLineEdit) -> None:
        filename, _ = QFileDialog.getOpenFileName(
            self,
            "Select executable",
            str(Path(widget.text()).expanduser().parent if widget.text() else Path.cwd()),
            "All files (*)",
        )
        if filename:
            widget.setText(filename)

    def _choose_directory(self, widget: QLineEdit) -> None:
        directory = QFileDialog.getExistingDirectory(
            self,
            "Select directory",
            str(Path(widget.text()).expanduser() if widget.text() else Path.cwd()),
        )
        if directory:
            widget.setText(directory)

    def kill_job(self) -> None:
        """Terminate the complete local process group or cancel the PBS job."""

        errors: list[str] = []
        if self.local_process and self.local_process.poll() is None:
            try:
                if os.name == "nt":
                    completed = subprocess.run(
                        ["taskkill", "/PID", str(self.local_process.pid), "/T", "/F"],
                        text=True,
                        capture_output=True,
                        check=False,
                    )
                    if completed.returncode:
                        raise OSError(completed.stderr.strip() or completed.stdout.strip())
                else:
                    os.killpg(os.getpgid(self.local_process.pid), signal.SIGTERM)
            except OSError as exc:
                errors.append(f"local job: {exc}")
        if self.cluster_job_id:
            qdel = shutil.which("qdel")
            if not qdel:
                errors.append("PBS job: qdel was not found")
            else:
                completed = subprocess.run(
                    [qdel, self.cluster_job_id],
                    text=True,
                    capture_output=True,
                    check=False,
                )
                if completed.returncode:
                    errors.append(
                        "PBS job: "
                        + (completed.stderr.strip() or completed.stdout.strip())
                    )
                else:
                    self.cluster_job_id = None
        if errors:
            QMessageBox.critical(self, "Could not kill job", "\n".join(errors))
            return
        self.kill_button.setEnabled(False)
        self.statusBar().showMessage("Job termination requested", 10000)

    def _atom_selected(self, atom: DisplayAtom | None) -> None:
        if atom is None:
            self.atom_status.setText("No atom selected")
            return
        x, y, z = atom.fractional
        self.atom_status.setText(
            f"Selected {atom.label} ({atom.element})  [{x:.4f}, {y:.4f}, {z:.4f}]"
        )

    def _display_changed(self) -> None:
        self.viewer.show_cell = self.show_cell.isChecked()
        self.viewer.show_labels = self.show_labels.isChecked()
        self.viewer.projection_mode = self.projection_mode.currentData()
        self.viewer.depth_cueing = self.depth_cueing.isChecked()
        self.viewer.show_ellipsoids = self.show_ellipsoids.isChecked()
        self.viewer.ellipsoid_probability = float(
            self.ellipsoid_probability.value()
        )
        enabled = self.show_ellipsoids.isChecked()
        self.ellipsoid_probability_label.setEnabled(enabled)
        self.ellipsoid_probability.setEnabled(enabled)
        self.viewer.update()


def run(
    option_path: str | Path = "job_options.txt",
    *,
    submission_mode: str = "local",
) -> int:
    app = QApplication.instance() or QApplication([])
    app.setApplicationName("lamaGOET")
    window = MainWindow(option_path, submission_mode=submission_mode)
    window.show()
    return app.exec()
