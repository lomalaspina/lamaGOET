#!/usr/bin/env python3
"""Construct every main widget and exercise growth without showing a window."""

from pathlib import Path
import math
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
from lamagoet_qt.crystal import Cell, DisplayAtom
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
        measurement_atoms = [
            DisplayAtom("A", "C", (0.0, 0.0, 0.0), (0.0, 0.0, 0.0), 0, 0),
            DisplayAtom("B", "C", (0.1, 0.0, 0.0), (1.0, 0.0, 0.0), 1, 0),
            DisplayAtom("C", "C", (0.1, 0.1, 0.0), (1.0, 1.0, 0.0), 2, 0),
            DisplayAtom("D", "C", (0.0, 0.1, 0.0), (0.0, 1.0, 0.0), 3, 0),
        ]
        window.viewer.set_structure(
            Cell.from_parameters(10.0, 10.0, 10.0, 90.0, 90.0, 90.0),
            measurement_atoms,
        )
        window.viewer.select_index(0)
        window.viewer.select_index(1)
        assert window.viewer.selected_indices == (0, 1)
        assert [atom.label for atom in window.viewer.selected_atoms()] == ["A", "B"]
        assert "Distance A–B" in window.atom_status.text()
        assert "1.0000 Å" in window.atom_status.text()
        window.viewer.select_index(2)
        assert window.viewer.selected_indices == (0, 1, 2)
        assert [atom.label for atom in window.viewer.selected_atoms()] == [
            "A",
            "B",
            "C",
        ]
        assert "Angle A–B–C" in window.atom_status.text()
        assert "vertex B" in window.atom_status.text()
        assert "90.000°" in window.atom_status.text()
        window.viewer.select_index(3)
        assert window.viewer.selected_indices == (3,)
        assert "Selected 1: D" in window.atom_status.text()
        window.viewer.select_index(3)
        assert window.viewer.selected_indices == ()
        assert window.atom_status.text() == "No atom selected"

        for index in (0, 2, 1):
            window.viewer.select_index(index)
        assert window.viewer.selected_indices == (0, 2, 1)
        assert [atom.label for atom in window.viewer.selected_atoms()] == [
            "A",
            "C",
            "B",
        ]
        assert "Angle A–C–B" in window.atom_status.text()
        assert "vertex C" in window.atom_status.text()
        assert "45.000°" in window.atom_status.text()
        window.viewer.keyPressEvent(
            QKeyEvent(QEvent.Type.KeyPress, Qt.Key.Key_Escape, Qt.KeyboardModifier.NoModifier)
        )
        assert window.viewer.selected_index is None
        assert window.viewer.selected_indices == ()
        assert window.viewer.selected_atoms() == []
        assert window.atom_status.text() == "No atom selected"

        # Restore the crystallographic model after the synthetic measurement
        # geometry so radius growth still exercises the loaded CIF.
        window._load_cif_from_field()
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
        refined_uij = {
            atom.label: atom.u_aniso
            for atom in window.structure.asymmetric_atoms
            if atom.u_aniso is not None
        }
        refined_fractional = window.structure.asymmetric_atoms[0].fractional
        final_residual = Path(directory) / "2.my_job.cartesian.cif2"
        final_text = (ROOT / "Tests" / "inputs" / "calc.cif").read_text(
            encoding="utf-8"
        )
        final_text = final_text.split("loop_\n_atom_site_aniso_label", 1)[0]
        final_text = final_text.replace("0.5992(7)", "0.5993(7)", 1)
        final_residual.write_text(final_text, encoding="utf-8")
        os.utime(final_residual, ns=(latest.stat().st_mtime_ns + 1,) * 2)
        window._refresh_latest_cif()
        assert window._displayed_cif == final_residual.resolve()
        assert window.structure.asymmetric_atoms[0].fractional != refined_fractional
        assert {
            atom.label: atom.u_aniso
            for atom in window.structure.asymmetric_atoms
            if atom.u_aniso is not None
        } == refined_uij
        assert "retained last refinement ADPs" in window.statusBar().currentMessage()
        screenshot = os.environ.get("LAMAGOET_QT_SCREENSHOT")
        if screenshot:
            window.show()
            app.processEvents()
            if not window.grab().save(screenshot):
                raise RuntimeError(f"could not save Qt screenshot to {screenshot}")
        # Opening another CIF manually starts a new viewing session.  A later
        # ADP-free automatic update must not inherit tensors from the old job.
        window._load_structure(final_residual)
        assert window._last_structure_with_adps is None
        next_job_output = Path(directory) / "3.my_job.cartesian.cif2"
        next_text = final_text.replace("0.5993(7)", "0.5994(7)", 1)
        next_job_output.write_text(next_text, encoding="utf-8")
        os.utime(
            next_job_output,
            ns=(final_residual.stat().st_mtime_ns + 1,) * 2,
        )
        window._refresh_latest_cif()
        assert window._displayed_cif == next_job_output.resolve()
        assert not window.structure.has_displacement_parameters()

        # If two numbered cycle outputs arrive between timer ticks, show both
        # in order. The ADP-bearing refinement is then also the tensor source
        # for the following ADP-free theoretical geometry.
        batch_refined = Path(directory) / "4.my_job.fractional.cif1"
        batch_refined.write_bytes(
            (ROOT / "Tests" / "inputs" / "calc.cif").read_bytes()
        )
        batch_final = Path(directory) / "5.my_job.cartesian.cif2"
        batch_final.write_text(
            final_text.replace("0.5993(7)", "0.5995(7)", 1),
            encoding="utf-8",
        )
        batch_time = next_job_output.stat().st_mtime_ns + 10
        os.utime(batch_refined, ns=(batch_time,) * 2)
        os.utime(batch_final, ns=(batch_time + 1,) * 2)
        window._refresh_latest_cif()
        assert window._displayed_cif == batch_refined.resolve()
        assert window.structure.has_displacement_parameters()
        assert "Tonto cycle 4" in window.structure_status.text()
        window._refresh_latest_cif()
        assert window._displayed_cif == batch_final.resolve()
        assert window.structure.has_displacement_parameters()
        assert "Tonto cycle 5" in window.structure_status.text()
        assert "retained last refinement ADPs" in window.statusBar().currentMessage()
        window._refresh_latest_cif()
        assert window._displayed_cif == batch_final.resolve()
        window.close()

        # A remotely running calculation overwrites one stable live-CIF path
        # on every cycle.  Exercise three such updates, including same-size
        # contents with an intentionally unchanged modification timestamp.
        refresh_directory = Path(directory) / "same-path-live-refresh"
        refresh_directory.mkdir()
        refresh_window = MainWindow(refresh_directory / "job_options.txt")
        refresh_window.job_name.setText("my_job")
        refresh_window.cif_path.setText(str(ROOT / "Tests" / "inputs" / "calc.cif"))
        refresh_window._load_cif_from_field()
        refresh_window.viewer.select_index(0)
        refresh_window.viewer.select_index(1)
        assert "Distance" in refresh_window.atom_status.text()

        live_cif = refresh_directory / "my_job.latest_tonto.cif"
        source_text = (ROOT / "Tests" / "inputs" / "calc.cif").read_text(
            encoding="utf-8"
        )
        cycle_texts = [
            source_text.replace("0.5992(7)", f"0.599{cycle}(7)", 1)
            for cycle in (3, 4, 5)
        ]
        assert len({len(text.encode("utf-8")) for text in cycle_texts}) == 1
        forced_mtime = (ROOT / "Tests" / "inputs" / "calc.cif").stat().st_mtime_ns
        for cycle, (expected_x, cycle_text) in enumerate(
            zip((0.5993, 0.5994, 0.5995), cycle_texts),
            start=1,
        ):
            live_cif.write_text(cycle_text, encoding="utf-8")
            os.utime(live_cif, ns=(forced_mtime, forced_mtime))
            refresh_window._refresh_latest_cif()

            assert refresh_window._displayed_cif == live_cif.resolve()
            assert math.isclose(
                refresh_window.structure.asymmetric_atoms[0].fractional[0],
                expected_x,
            )
            assert math.isclose(refresh_window.visible_atoms[0].fractional[0], expected_x)
            assert math.isclose(
                refresh_window.viewer.atoms[0].fractional[0], expected_x
            )
            assert refresh_window.viewer.selected_indices == ()
            assert refresh_window.viewer.selected_atoms() == []
            assert refresh_window.atom_status.text() == "No atom selected"
            assert (
                f"Live structure update {cycle}"
                in refresh_window.structure_status.text()
            )
            assert live_cif.name in refresh_window.structure_status.text()
        refresh_window.close()

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
        assert cp2k_window.cp2k_density_interface.currentData() == "native"
        assert cp2k_window._current_values()["CP2K_DENSITY_INTERFACE"] == "native"
        cp2k_window.cp2k_density_interface.setCurrentIndex(
            cp2k_window.cp2k_density_interface.findData("xml")
        )
        assert cp2k_window._current_values()["CP2K_DENSITY_INTERFACE"] == "xml"
        cp2k_window.save_options()
        cp2k_reloaded = MainWindow(cp2k_options)
        assert cp2k_reloaded.cp2k_density_interface.currentData() == "xml"
        cp2k_reloaded.close()
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
            'CRYSTAL_TONTO_BASIS_NAME="def2-TZVP"\n'
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
        crystal_layout = crystal_window.crystal_group.layout()
        assert crystal_layout.indexOf(crystal_window.crystal_flags_row) == 0
        assert crystal_layout.indexOf(crystal_window.crystal_parameters_row) == 1
        assert (
            crystal_window.crystal_setting.parent()
            is crystal_window.crystal_parameters_row
        )
        assert (
            crystal_window.crystal_tolinteg.parent()
            is crystal_window.crystal_parameters_row
        )
        assert (
            crystal_window.use_hm_symbol.parent()
            is crystal_window.crystal_flags_row
        )
        assert (
            crystal_window.network_compound.parent()
            is crystal_window.crystal_flags_row
        )
        assert (
            crystal_window.use_previous_crystal_guess.parent()
            is crystal_window.crystal_flags_row
        )
        assert not crystal_window.stockholder_group.isHidden()
        assert crystal_window.partition_model.isHidden()
        assert not crystal_window.stockholder_model.isHidden()
        assert crystal_window.observed_shrinkage.isHidden()
        assert crystal_window.stockholder_model.currentData() == "periodic"
        assert crystal_window._current_values()["PARTITION_MODEL"] == "oc-crystal23"
        assert crystal_window.cluster_group.isHidden()
        assert crystal_window.method.currentText() == "HSE06"
        assert crystal_window.basis.currentText() == "POB-TZVP-REV2"
        assert crystal_window.crystal_tonto_basis.isHidden()
        crystal_window.external_basis.setChecked(True)
        assert not crystal_window.crystal_tonto_basis.isHidden()
        assert crystal_window.crystal_tonto_basis.currentText() == "def2-TZVP"
        assert (
            crystal_window._current_values()["CRYSTAL_TONTO_BASIS_NAME"]
            == "def2-TZVP"
        )
        crystal_window.crystal_tonto_basis.setEditText("")
        try:
            crystal_window._current_values()
        except ValueError as exc:
            assert "exact matching Tonto library basis name" in str(exc)
        else:
            raise AssertionError(
                "external Crystal23 basis accepted without a Tonto basis name"
            )
        crystal_window.close()
    app.processEvents()
    print("Qt GUI off-screen smoke test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
