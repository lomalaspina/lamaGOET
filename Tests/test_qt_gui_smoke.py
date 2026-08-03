#!/usr/bin/env python3
"""Construct every main widget and exercise growth without showing a window."""

from pathlib import Path
import os
import sys
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

try:
    from PySide6.QtCore import QEvent, Qt
    from PySide6.QtGui import QKeyEvent
    from PySide6.QtWidgets import QApplication
except ImportError:
    print("Qt GUI smoke test skipped: PySide6 is not installed")
    raise SystemExit(0)

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from lamagoet_qt.main_window import MainWindow
from lamagoet_qt.job_options import load_job_options


def main() -> int:
    app = QApplication.instance() or QApplication([])
    with tempfile.TemporaryDirectory() as directory:
        options = Path(directory) / "job_options.txt"
        window = MainWindow(options)
        assert window.program.currentData() == "Gaussian"
        assert not window.gaussian_features.isHidden()
        assert not window.cluster_group.isHidden()
        assert not window.header_group.isHidden()
        assert not window.external_basis_group.isHidden()
        assert window.email.isHidden()
        assert window.initial_adp_group.isHidden()
        window.show()
        app.processEvents()
        total_width = sum(window.main_splitter.sizes())
        window.main_splitter.moveSplitter(360, 1)
        app.processEvents()
        assert window.main_splitter.sizes()[0] <= 390
        window.main_splitter.moveSplitter(total_width - 380, 1)
        app.processEvents()
        assert window.main_splitter.sizes()[1] <= 420
        window.main_splitter.setSizes([570, 850])
        window.program.showPopup()
        window.program.setCurrentIndex(window.program.findData("Orca"))
        app.processEvents()
        assert not window.program.view().isVisible()
        window.hide()
        window.cif_path.setText(str(ROOT / "Tests" / "inputs" / "calc.cif"))
        window._load_cif_from_field()
        assert window.structure is not None
        assert any(atom.u_aniso for atom in window.visible_atoms)
        assert any(atom.u_cartesian for atom in window.visible_atoms)
        window.show_ellipsoids.setChecked(True)
        window.ellipsoid_probability.setValue(90)
        assert window.viewer.show_ellipsoids
        assert window.viewer.ellipsoid_probability == 90
        window.projection_mode.setCurrentIndex(
            window.projection_mode.findData("orthographic")
        )
        window.depth_cueing.setChecked(False)
        assert window.viewer.projection_mode == "orthographic"
        assert not window.viewer.depth_cueing
        for mode in (
            "asu",
            "cell",
            "molecules",
            "short_contacts",
            "vdw",
            "supercell",
        ):
            window.grow_mode.setCurrentIndex(window.grow_mode.findData(mode))
            window.apply_grow()
            assert window.visible_atoms
        # Start the cumulative-operation check from a small, ordinary view;
        # growing VdW contacts from the full 3x3x3 pack is valid but needlessly
        # expensive for a smoke test.
        window.grow_mode.setCurrentIndex(window.grow_mode.findData("asu"))
        window.apply_grow()
        window.grow_mode.setCurrentIndex(window.grow_mode.findData("vdw"))
        window.apply_grow()
        vdw_coordinates = {
            tuple(round(value, 7) for value in atom.cartesian)
            for atom in window.visible_atoms
        }
        window.grow_mode.setCurrentIndex(window.grow_mode.findData("molecules"))
        window.apply_grow()
        completed_coordinates = {
            tuple(round(value, 7) for value in atom.cartesian)
            for atom in window.visible_atoms
        }
        assert vdw_coordinates.issubset(completed_coordinates)
        window.viewer.select_index(0)
        assert window.viewer.selected_index == 0
        window.viewer.select_index(0)
        assert window.viewer.selected_index is None
        assert window.atom_status.text() == "No atom selected"
        window.viewer.select_index(0)
        window.viewer.keyPressEvent(
            QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_Escape, Qt.KeyboardModifier.NoModifier)
        )
        assert window.viewer.selected_index is None
        window.viewer.selected_index = 0
        window.grow_mode.setCurrentIndex(window.grow_mode.findData("radius"))
        window.apply_grow()
        assert window.visible_atoms
        window.grow_mode.setCurrentIndex(window.grow_mode.findData("cell"))
        window.apply_grow()
        for program, minimum_methods, minimum_basis in (
            ("Tonto", 3, 20),
            ("elmodb", 3, 20),
            ("optgaussian", 10, 40),
            ("optorca", 10, 40),
        ):
            window.program.setCurrentIndex(window.program.findData(program))
            assert window.method.count() >= minimum_methods
            assert window.basis.count() >= minimum_basis
        window.program.setCurrentIndex(window.program.findData("elmodb"))
        assert not window.initial_adp_group.isHidden()
        window.initial_adp.setChecked(True)
        window.initial_adp_path.setText(
            str(ROOT / "Tests" / "inputs" / "calc.cif")
        )
        elmo_values = window._current_values()
        assert elmo_values["INITADP"] == "true"
        assert elmo_values["INITADPFILE"].endswith("calc.cif")
        window.program.setCurrentIndex(window.program.findData("optgaussian"))
        assert window.hkl_row.isHidden()
        assert window.header_group.isHidden()
        window.program.setCurrentIndex(window.program.findData("Orca"))
        assert not window.nuclear_interaction.isHidden()
        window.program.setCurrentIndex(window.program.findData("Gaussian"))
        assert window.nuclear_interaction.isHidden()
        window.program.setCurrentIndex(window.program.findData("Gaussian"))
        window.external_basis.setChecked(True)
        window.basis_definition_path.setText(
            str(ROOT / "Tests" / "cp2k_basis_sample")
        )
        window.grimme.setChecked(True)
        window.relativistic.setChecked(True)
        window.h_adp.setChecked(True)
        window.dispersion_correction.setChecked(True)
        os.environ["LAMAGOET_QT_DRY_RUN"] = "true"
        window.submit_job()
        os.environ.pop("LAMAGOET_QT_DRY_RUN", None)
        assert options.is_file()
        assert not (Path(directory) / "lamaGOET.pbs").exists()
        assert not (Path(directory) / "calc.cif").exists()
        assert (Path(directory) / "basis_gen.txt").is_file()
        saved = load_job_options(options)
        for name in (
            "COMPLETESTRUCT",
            "WRITEHEADER",
            "GAUSGEN",
            "GAUSSEMPDISP",
            "GAUSSREL",
            "POSADP",
            "REFHPOS",
            "DISP",
            "TONTO",
            "PLOT_TONTO",
            "BASISSETDIR",
            "GAUSSIAN_BIN",
            "ORCA_BIN",
        ):
            assert name in saved
        assert saved["GAUSGEN"] == "true"
        assert saved["HADP"] == "yes"
        assert saved["DISP"] == "yes"
        # All fields are emitted, including hidden/default fields needed by
        # shell conditionals. Local mode simply leaves EMAIL empty.
        assert saved["EMAIL"] == ""

        unrelated = Path(directory) / "unrelated.cif"
        unrelated.write_bytes((ROOT / "Tests" / "inputs" / "calc.cif").read_bytes())
        window._refresh_latest_cif()
        assert window._displayed_cif != unrelated.resolve()
        latest = Path(directory) / "1.my_job.cartesian.cif2"
        latest.write_bytes((ROOT / "Tests" / "inputs" / "calc.cif").read_bytes())
        window._refresh_latest_cif()
        assert window._displayed_cif == latest.resolve()
        screenshot = os.environ.get("LAMAGOET_QT_SCREENSHOT")
        if screenshot:
            window.show()
            app.processEvents()
            if not window.grab().save(screenshot):
                raise RuntimeError(f"could not save Qt screenshot to {screenshot}")
        window.close()

        cluster_directory = Path(directory) / "cluster"
        cluster_directory.mkdir()
        cluster_options = cluster_directory / "job_options.txt"
        cluster_window = MainWindow(cluster_options, submission_mode="cluster")
        assert not cluster_window.email.isHidden()
        cluster_window.cif_path.setText(
            str(ROOT / "Tests" / "inputs" / "calc.cif")
        )
        cluster_window.email.setText("user@example.org")
        os.environ["LAMAGOET_QT_DRY_RUN"] = "true"
        cluster_window.submit_job()
        os.environ.pop("LAMAGOET_QT_DRY_RUN", None)
        assert (cluster_directory / "job_options.txt").is_file()
        assert (cluster_directory / "lamaGOET.pbs").is_file()
        assert (cluster_directory / "calc.cif").is_file()
        cluster_saved = load_job_options(cluster_options)
        assert cluster_saved["EMAIL"] == "user@example.org"
        cluster_window.close()

        cp2k_options = Path(directory) / "cp2k_options.txt"
        cp2k_options.write_text(
            'SCFCALCPROG="CP2K"\n'
            f'CP2K_BASIS_SET_FILE="{ROOT / "Tests" / "cp2k_basis_sample"}"\n'
            'CP2K_BASIS_SET="DZVP-MOLOPT-GTH-q4"\n'
            'CP2K_XC_FUNCTIONAL="PBE"\n',
            encoding="utf-8",
        )
        cp2k_window = MainWindow(cp2k_options)
        assert cp2k_window.program.currentData() == "CP2K"
        assert not cp2k_window.cp2k_group.isHidden()
        assert cp2k_window.cluster_group.isHidden()
        assert cp2k_window.cp2k_basis.currentText() == "DZVP-MOLOPT-GTH-q4"
        assert cp2k_window.cp2k_basis.count() == 4
        assert cp2k_window.cp2k_functional.currentText() == "PBE"
        assert not cp2k_window.stockholder_group.isHidden()
        assert cp2k_window.partition_model.currentData() == "oc-crystal23"
        assert cp2k_window.stockholder_model.currentData() == "cluster"
        cp2k_window.stockholder_model.setCurrentIndex(
            cp2k_window.stockholder_model.findData("periodic")
        )
        assert cp2k_window._current_values()["STOCKHOLDER_MODEL"] == "periodic"
        cp2k_window.partition_model.setCurrentIndex(
            cp2k_window.partition_model.findData("oc-observed")
        )
        assert cp2k_window.stockholder_model.isHidden()
        assert not cp2k_window.observed_shrinkage.isHidden()
        cp2k_window.observed_shrinkage.setValue(0.35)
        cp2k_window.observed_min_tf.setValue(0.025)
        cp2k_window.observed_zero_phase_sign.setCurrentIndex(
            cp2k_window.observed_zero_phase_sign.findData(-1)
        )
        cp2k_values = cp2k_window._current_values()
        assert cp2k_values["PARTITION_MODEL"] == "oc-observed"
        assert cp2k_values["OBSERVED_DENSITY_SHRINKAGE"] == 0.35
        assert cp2k_values["OBSERVED_DENSITY_MIN_TF"] == 0.025
        assert cp2k_values["OBSERVED_ZERO_PHASE_SIGN"] == -1
        cp2k_window.close()

        crystal_options = Path(directory) / "crystal_options.txt"
        crystal_options.write_text(
            'SCFCALCPROG="Crystal14"\n'
            'METHOD="HSE06"\n'
            'BASISSETG="POB-TZVP-REV2"\n'
            'PARTITION_MODEL="oc-observed"\n'
            'OBSERVED_DENSITY_SHRINKAGE="0.4"\n'
            'OBSERVED_DENSITY_MIN_TF="0.05"\n'
            'OBSERVED_ZERO_PHASE_SIGN="1"\n'
            'STOCKHOLDER_MODEL="periodic"\n',
            encoding="utf-8",
        )
        crystal_window = MainWindow(crystal_options)
        assert crystal_window.program.currentData() == "Crystal14"
        assert not crystal_window.method.isHidden()
        assert not crystal_window.basis.isHidden()
        assert crystal_window.cp2k_group.isHidden()
        assert not crystal_window.crystal_group.isHidden()
        assert not crystal_window.stockholder_group.isHidden()
        assert crystal_window.partition_model.currentData() == "oc-observed"
        assert crystal_window.stockholder_model.isHidden()
        assert not crystal_window.observed_shrinkage.isHidden()
        assert crystal_window.observed_shrinkage.value() == 0.4
        assert crystal_window.observed_min_tf.value() == 0.05
        assert crystal_window.observed_zero_phase_sign.currentData() == 1
        assert crystal_window.stockholder_model.currentData() == "periodic"
        assert crystal_window.cluster_group.isHidden()
        assert crystal_window.method.currentText() == "HSE06"
        assert crystal_window.basis.currentText() == "POB-TZVP-REV2"
        crystal_window.close()
    app.processEvents()
    print("Qt GUI off-screen smoke test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
