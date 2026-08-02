#!/usr/bin/env python3
from pathlib import Path
import tempfile
import unittest

from lamagoet_qt.cluster import (
    SubmissionError,
    build_pbs_script,
    write_pbs_script,
)


class ClusterSubmissionTest(unittest.TestCase):
    def setUp(self):
        self.values = {
            "SCFCALCPROG": "Gaussian",
            "JOBNAME": "nh3_har",
            "CIF": "./nh3.cif",
            "NUMPROC": 8,
            "NUMPROCTONTO": 4,
            "MEMPBS": "2gb",
            "EMAIL": "user@example.org",
        }

    def test_gaussian_pbs_uses_scf_processors_and_cluster_runner(self):
        text = build_pbs_script(self.values)
        self.assertIn("#PBS -l nodes=1:g09:RUN_lamaGOET:ppn=8", text)
        self.assertIn("#PBS -N nh3_har", text)
        self.assertIn("\nRUN_lamaGOET\n", text)
        self.assertIn('export LAMAGOET_LIVE_CIF_SERVER="$SERVER"', text)
        self.assertIn(
            'export LAMAGOET_LIVE_CIF_DIRECTORY="$PBS_O_WORKDIR"', text
        )
        self.assertNotIn("lamaGOET.sh", text)

    def test_tonto_pbs_uses_tonto_processors(self):
        self.values["SCFCALCPROG"] = "Tonto"
        text = build_pbs_script(self.values)
        self.assertIn("#PBS -l nodes=1:RUN_lamaGOET:ppn=4", text)

    def test_unsafe_job_name_is_rejected(self):
        self.values["JOBNAME"] = "bad; qsub other"
        with self.assertRaises(SubmissionError):
            build_pbs_script(self.values)

    def test_script_is_written_with_lf_line_endings(self):
        with tempfile.TemporaryDirectory() as directory:
            output = write_pbs_script(Path(directory) / "lamaGOET.pbs", self.values)
            data = output.read_bytes()
        self.assertNotIn(b"\r\n", data)
        self.assertTrue(data.startswith(b"#!/bin/sh\n"))

    def test_both_runners_publish_after_tonto_when_qt_pbs_exports_destination(self):
        root = Path(__file__).resolve().parents[1]
        for filename in ("RUN_lamaGOET_release.sh", "lamaGOET.sh"):
            text = (root / filename).read_text(encoding="utf-8")
            self.assertIn("_lamagoet_publish_latest_cif()", text)
            self.assertEqual(text.count("_lamagoet_publish_latest_cif"), 2)
            self.assertIn("${JOBNAME}.latest_tonto.cif", text)
            self.assertIn("BatchMode=yes", text)

    def test_qt_launchers_select_distinct_local_and_cluster_modes(self):
        root = Path(__file__).resolve().parents[1]
        local_launcher = (root / "lamaGOET_qt.sh").read_text(encoding="utf-8")
        cluster_launcher = (root / "GUI_lamaGOET_qt.sh").read_text(
            encoding="utf-8"
        )
        self.assertIn("--mode local", local_launcher)
        self.assertNotIn("--mode cluster", local_launcher)
        self.assertIn("--mode cluster", cluster_launcher)


if __name__ == "__main__":
    unittest.main()
