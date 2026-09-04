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
        gaussian_methods = {
            window.method.itemText(index) for index in range(window.method.count())
        }
        assert {"PBEPBE", "uPBEPBE", "blyp", "b3lyp"}.issubset(gaussian_methods)
        assert not {"PBE1PBE", "uPBE1PBE", "m06", "wb97xd"}.intersection(
            gaussian_methods
        )
        assert not {"pbe", "upbe", "pbe0", "upbe0"}.intersection(
            gaussian_methods
        )
        window.method.setEditText("pbe0")
        assert window._current_values()["METHOD"] == "PBE1PBE"
        window.method.setCurrentText("rhf")
        assert not window.gaussian_features.isHidden()
        assert not window.cluster_group.isHidden()
        assert not window.header_group.isHidden()
        assert window.merg_code.currentData() == 2
        assert "space-group equivalents" in window.merg_description.toPlainText()
        assert [
            window.becke_accuracy.itemText(index)
            for index in range(window.becke_accuracy.count())
        ] == [
            "very_low", "sg-1", "low", "medium", "high", "very_high",
            "extreme", "best",
        ]
        assert window.becke_accuracy.currentText() == "extreme"
        assert window.xcw_mode.currentData() == "molecular"
        assert not window.molecular_xcw_options.isHidden()
        assert window.periodic_xcw_options.isHidden()
        window.xcw_mode.setCurrentIndex(window.xcw_mode.findData("periodic"))
        window.xcw_only.setChecked(True)
        assert window.molecular_xcw_options.isHidden()
        assert not window.periodic_xcw_options.isHidden()
        assert not window.periodic_xcw_custom_basis.isChecked()
        assert window.periodic_xcw_reference_basis.isEnabled()
        window.periodic_xcw_reference_dft.setCurrentText("PBE")
        window.periodic_xcw_reference_basis.setEditText("pob-TZVP-rev2")
        crystal_basis = Path(directory) / "custom-crystal-basis.txt"
        crystal_basis.write_text(
            "6 1\n0 0 1 2.0 1.0\n1.0 1.0\n99 0\n",
            encoding="utf-8",
        )
        tonto_basis = Path(directory) / "core-decontracted-carbon"
        tonto_basis.write_text("exact sidecar\n", encoding="utf-8")
        window.periodic_xcw_custom_basis.setChecked(True)
        window.periodic_xcw_crystal_basis_file.setText(str(crystal_basis))
        window.periodic_xcw_tonto_basis_file.setText(str(tonto_basis))
        window.periodic_xcw_tonto_basis_name.setText("core-decontracted-carbon")
        assert not window.periodic_xcw_reference_basis.isEnabled()
        window.periodic_xcw_grid.setText("20 22 24")
        window.periodic_xcw_density_radius.setValue(2)
        window.periodic_xcw_convergence.setText("2.5E-7")
        window.periodic_xcw_damping.setValue(0.35)
        window.periodic_xcw_max_iterations.setValue(44)
        window.periodic_xcw_r_free.setValue(15)
        window.periodic_xcw_restart.setChecked(True)
        periodic_values = window._current_values()
        assert periodic_values["XCW_MODE"] == "periodic"
        assert periodic_values["PERIODIC_XCW_REFERENCE_DFT"] == "PBE"
        assert periodic_values["PERIODIC_XCW_REFERENCE_BASIS"] == "pob-TZVP-rev2"
        assert periodic_values["PERIODIC_XCW_CRYSTAL_BASIS_FILE"] == str(
            crystal_basis
        )
        assert periodic_values["PERIODIC_XCW_TONTO_BASIS_FILE"] == str(
            tonto_basis
        )
        assert (
            periodic_values["PERIODIC_XCW_TONTO_BASIS_NAME"]
            == "core-decontracted-carbon"
        )
        window._prepare_periodic_xcw_basis_pair()
        assert window.periodic_xcw_crystal_basis_file.text() == (
            "./periodic_xcw_crystal_basis.txt"
        )
        assert window.periodic_xcw_tonto_basis_file.text() == (
            "./periodic_xcw_tonto_basis.sidecar"
        )
        assert (Path(directory) / "periodic_xcw_crystal_basis.txt").is_file()
        assert (Path(directory) / "periodic_xcw_tonto_basis.sidecar").is_file()
        assert periodic_values["PERIODIC_XCW_GRID"] == "20 22 24"
        assert periodic_values["PERIODIC_XCW_DENSITY_RADIUS"] == 2
        assert periodic_values["PERIODIC_XCW_CONVERGENCE"] == "2.5E-7"
        assert periodic_values["PERIODIC_XCW_DAMPING"] == 0.35
        assert periodic_values["PERIODIC_XCW_MAX_ITERATIONS"] == 44
        assert periodic_values["PERIODIC_XCW_R_FREE_PERCENTAGE"] == 15
        assert periodic_values["PERIODIC_XCW_RESTART"] == "true"
        window.xcw_only.setChecked(False)
        window.xcw_mode.setCurrentIndex(window.xcw_mode.findData("molecular"))
        window.merg_code.setCurrentIndex(window.merg_code.findData(4))
        assert "anomalous-scattering" in window.merg_description.toPlainText()
        window.merg_code.setCurrentIndex(window.merg_code.findData(2))
        assert not window.external_basis_group.isHidden()
        assert window.email.isHidden()
        assert window.initial_adp_group.isHidden()
        assert not window.extinction_correction.isChecked()
        window.extinction_correction.setChecked(True)
        assert window._current_values()["EXTI"] == "yes"
        assert not window.extinction_options.isHidden()
        assert window.extinction_model.currentData() == "zachariasen"
        assert "SHELXL" in window.extinction_explanation.text()
        window.extinction_model.setCurrentIndex(
            window.extinction_model.findData("becker-coppens")
        )
        window.extinction_type.setCurrentIndex(
            window.extinction_type.findData("type-2")
        )
        window.extinction_distribution.setCurrentIndex(
            window.extinction_distribution.findData("lorentzian")
        )
        window.extinction_nature.setCurrentIndex(
            window.extinction_nature.findData("anisotropic")
        )
        window.extinction_mean_path.setValue(0.425)
        extinction_values = window._current_values()
        assert extinction_values["EXTINCTION_MODEL"] == "becker-coppens"
        assert extinction_values["EXTINCTION_TYPE"] == "type-2"
        assert extinction_values["EXTINCTION_DISTRIBUTION"] == "lorentzian"
        assert extinction_values["EXTINCTION_ANISOTROPIC"] == "true"
        assert extinction_values["EXTINCTION_MEAN_PATH_MM"] == 0.425
        assert not window.extinction_mean_path.isHidden()
        assert window.save_options() == options
        saved_extinction = load_job_options(options)
        assert saved_extinction["EXTINCTION_MODEL"] == "becker-coppens"
        assert saved_extinction["EXTINCTION_TYPE"] == "type-2"
        assert saved_extinction["EXTINCTION_DISTRIBUTION"] == "lorentzian"
        assert saved_extinction["EXTINCTION_ANISOTROPIC"] == "true"
        assert saved_extinction["EXTINCTION_MEAN_PATH_MM"] == "0.425"
        reloaded = MainWindow(options)
        assert reloaded.extinction_correction.isChecked()
        assert reloaded.extinction_model.currentData() == "becker-coppens"
        assert reloaded.extinction_type.currentData() == "type-2"
        assert reloaded.extinction_distribution.currentData() == "lorentzian"
        assert reloaded.extinction_nature.currentData() == "anisotropic"
        assert reloaded.extinction_mean_path.value() == 0.425
        reloaded.close()
        window.extinction_correction.setChecked(False)
        assert window.extinction_options.isHidden()
        assert window.logo_label.pixmap() is not None
        assert not window.logo_label.pixmap().isNull()
        assert window.logo_label.alignment() & Qt.AlignmentFlag.AlignHCenter
        central_layout = window.centralWidget().layout()
        assert central_layout.indexOf(window.logo_label) == 0
        assert central_layout.indexOf(window.main_splitter) == 1
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
            ("optgaussian", 8, 40),
            ("optorca", 5, 40),
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
            "MERGCODE",
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
            'CP2K_XC_FUNCTIONAL="PBE"\n'
            'OUTPUT_HIRSHFELD_ATOM_CUBES="true"\n'
            'HIRSHFELD_ATOM_CUBE_LABEL="N1"\n',
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
        assert cp2k_window.partition_model.isHidden()
        assert cp2k_window.observed_shrinkage.isHidden()
        assert not cp2k_window.stockholder_model.isHidden()
        assert cp2k_window.stockholder_model.currentData() == "cluster"
        assert cp2k_window.output_hirshfeld_atom_cubes.isChecked()
        assert cp2k_window.hirshfeld_atom_cube_label.isEnabled()
        assert cp2k_window.hirshfeld_atom_cube_label.text() == "N1"
        cp2k_window.stockholder_model.setCurrentIndex(
            cp2k_window.stockholder_model.findData("periodic")
        )
        assert cp2k_window._current_values()["STOCKHOLDER_MODEL"] == "periodic"
        cp2k_values = cp2k_window._current_values()
        assert cp2k_values["PARTITION_MODEL"] == "oc-crystal23"
        assert cp2k_values["OUTPUT_HIRSHFELD_ATOM_CUBES"] == "true"
        assert cp2k_values["HIRSHFELD_ATOM_CUBE_LABEL"] == "N1"
        cp2k_window.close()

        tonto_options = Path(directory) / "tonto_observed_options.txt"
        tonto_options.write_text(
            'SCFCALCPROG="Tonto"\n'
            'PARTITION_MODEL="oc-observed"\n'
            'OBSERVED_DENSITY_RECONSTRUCTION="legacy"\n'
            'OBSERVED_DENSITY_SHRINKAGE="0.35"\n'
            'OBSERVED_DENSITY_MIN_TF="0.025"\n'
            'OBSERVED_ZERO_PHASE_SIGN="-1"\n',
            encoding="utf-8",
        )
        tonto_window = MainWindow(tonto_options)
        assert tonto_window.program.currentData() == "Tonto"
        assert not tonto_window.stockholder_group.isHidden()
        assert not tonto_window.partition_model.isHidden()
        assert tonto_window.partition_model.currentData() == "oc-observed"
        assert not tonto_window.stockholder_model.isHidden()
        assert tonto_window.stockholder_model.currentData() == "cluster"
        tonto_window.stockholder_model.setCurrentIndex(
            tonto_window.stockholder_model.findData("periodic")
        )
        assert not tonto_window.observed_shrinkage.isHidden()
        assert tonto_window.observed_shrinkage.value() == 0.35
        assert tonto_window.observed_min_tf.value() == 0.025
        assert tonto_window.observed_zero_phase_sign.currentData() == -1
        tonto_values = tonto_window._current_values()
        assert tonto_values["PARTITION_MODEL"] == "oc-observed"
        assert tonto_values["STOCKHOLDER_MODEL"] == "periodic"
        tonto_window.close()

        constrained_options = Path(directory) / "tonto_constrained_options.txt"
        constrained_options.write_text(
            'SCFCALCPROG="Tonto"\n'
            'PARTITION_MODEL="oc-observed"\n'
            'OBSERVED_DENSITY_RECONSTRUCTION="constrained"\n'
            'OBSERVED_DENSITY_R_FREE_PERCENTAGE="20"\n'
            'OBSERVED_DENSITY_PRIOR_STRENGTH="0.2"\n'
            'OBSERVED_DENSITY_SMOOTHNESS="0.3"\n'
            'OBSERVED_DENSITY_STEP_SIZE="0.4"\n'
            'OBSERVED_DENSITY_MAX_ITERATIONS="24"\n',
            encoding="utf-8",
        )
        constrained_window = MainWindow(constrained_options)
        assert constrained_window.partition_model.currentData() == "oc-observed"
        assert constrained_window.observed_reconstruction.currentData() == "constrained"
        assert not constrained_window.observed_motion_model.isHidden()
        assert constrained_window.observed_motion_model.currentData() == "static"
        assert constrained_window.observed_dynamic_warning.isHidden()
        assert constrained_window.observed_shrinkage.isHidden()
        assert constrained_window.observed_min_tf.isHidden()
        assert not constrained_window.observed_r_free.isHidden()
        assert constrained_window.observed_r_free.value() == 20
        assert constrained_window.observed_prior.value() == 0.2
        assert constrained_window.observed_smoothness.value() == 0.3
        assert constrained_window.observed_step.value() == 0.4
        assert constrained_window.observed_max_iterations.value() == 24
        constrained_values = constrained_window._current_values()
        assert constrained_values["OBSERVED_DENSITY_RECONSTRUCTION"] == "constrained"
        assert constrained_values["OBSERVED_DENSITY_MOTION_MODEL"] == "static"
        assert constrained_values["OBSERVED_DENSITY_R_FREE_PERCENTAGE"] == 20
        constrained_window.close()

        dynamic_options = Path(directory) / "tonto_dynamic_options.txt"
        dynamic_options.write_text(
            'SCFCALCPROG="Tonto"\n'
            'PARTITION_MODEL="oc-observed"\n'
            'OBSERVED_DENSITY_RECONSTRUCTION="constrained"\n'
            'OBSERVED_DENSITY_MOTION_MODEL="dynamic"\n'
            'POSADP="true"\n'
            'POSONLY="false"\n'
            'ADPSONLY="true"\n'
            'REFHPOS="true"\n'
            'REFUISO="true"\n'
            'REFHADP="true"\n'
            'HADP="yes"\n'
            'REFANHARM="true"\n'
            'THIRDORD="true"\n'
            'FOURTHORD="true"\n',
            encoding="utf-8",
        )
        dynamic_window = MainWindow(dynamic_options)
        assert dynamic_window.observed_motion_model.currentData() == "dynamic"
        assert not dynamic_window.observed_dynamic_warning.isHidden()
        assert dynamic_window.refine_dynamic_shapes.isChecked()
        assert not dynamic_window.refine_dynamic_shapes.isHidden()
        assert "ΔFcalc" in dynamic_window.convergence_label.text()
        assert "dynamic-density" in dynamic_window.max_ls_cycles_label.text()
        assert not dynamic_window.refine_pos_only.isEnabled()
        assert not dynamic_window.refine_pos_adp.isEnabled()
        assert not dynamic_window.refine_adps_only.isEnabled()
        assert not dynamic_window.refine_uiso.isChecked()
        assert not dynamic_window.refine_uiso.isEnabled()
        assert not dynamic_window.refine_h_positions.isChecked()
        assert not dynamic_window.refine_h_positions.isEnabled()
        assert not dynamic_window.refine_h_adps.isChecked()
        assert not dynamic_window.refine_h_adps.isEnabled()
        assert not dynamic_window.h_adp.isChecked()
        assert not dynamic_window.h_adp.isEnabled()
        assert not dynamic_window.refine_anharmonic.isChecked()
        assert not dynamic_window.refine_anharmonic.isEnabled()
        dynamic_values = dynamic_window._current_values()
        assert dynamic_values["OBSERVED_DENSITY_MOTION_MODEL"] == "dynamic"
        assert dynamic_values["POSADP"] == "false"
        assert dynamic_values["POSONLY"] == "true"
        assert dynamic_values["ADPSONLY"] == "false"
        assert dynamic_values["REFHPOS"] == "false"
        assert dynamic_values["REFUISO"] == "false"
        assert dynamic_values["REFHADP"] == "false"
        assert dynamic_values["HADP"] == "no"
        assert dynamic_values["REFANHARM"] == "false"
        assert dynamic_values["THIRDORD"] == "false"
        assert dynamic_values["FOURTHORD"] == "false"
        dynamic_window.close()

        constrained_default_options = (
            Path(directory) / "tonto_constrained_default_options.txt"
        )
        constrained_default_options.write_text(
            'SCFCALCPROG="Tonto"\n'
            'PARTITION_MODEL="oc-observed"\n'
            'OBSERVED_DENSITY_RECONSTRUCTION="constrained"\n',
            encoding="utf-8",
        )
        constrained_default_window = MainWindow(constrained_default_options)
        assert constrained_default_window.observed_prior.value() == 0.0
        assert constrained_default_window.observed_smoothness.value() == 0.01
        constrained_default_window.close()

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
        assert crystal_window.partition_model.isHidden()
        assert not crystal_window.stockholder_model.isHidden()
        assert crystal_window.observed_shrinkage.isHidden()
        assert crystal_window.stockholder_model.currentData() == "periodic"
        assert crystal_window._current_values()["PARTITION_MODEL"] == "oc-crystal23"
        assert crystal_window.cluster_group.isHidden()
        assert crystal_window.method.currentText() == "HSE06"
        assert crystal_window.basis.currentText() == "POB-TZVP-REV2"
        crystal_window.close()
    app.processEvents()
    print("Qt GUI off-screen smoke test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
