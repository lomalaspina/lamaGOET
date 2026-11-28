"""A constrained endpoint is successful, but never relabelled a regular fit."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from lamagoet_qt.curved_job import run


class BoundaryStatus(unittest.TestCase):
    def case(self, prefix, status, code, expected):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            uncertainty = "not_exported_nonregular_active_amplitude_boundary"
            (out / (prefix + ".summary")).write_text(
                f"status {status}\nuncertainty_status {uncertainty}\n"
            )
            record = dict(result_prefix=prefix, command=["not-executed"], job_timeout_seconds=10)
            with patch("lamagoet_qt.curved_job.subprocess.run",
                       return_value=subprocess.CompletedProcess([], code)):
                result = run(out, record)
            saved = json.loads((out / "run.json").read_text())
            self.assertEqual(saved["status"], expected)
            self.assertEqual(result, 0 if expected in ("converged", "constrained_converged") else 2)
            if prefix == "positive":
                self.assertEqual(saved["uncertainty_status"], uncertainty)

    def test_boundary_success_retains_nonregular_status(self):
        self.case("positive", "constrained_converged", 0, "constrained_converged")

    def test_nonzero_exit_cannot_claim_success(self):
        self.case("positive", "constrained_converged", 2, "failed_or_not_converged")

    def test_ordinary_convergence_unchanged(self):
        self.case("positive", "converged", 0, "converged")

    def test_failed_native_status_remains_failed(self):
        self.case("positive", "not_converged", 0, "failed_or_not_converged")

    def test_other_models_do_not_gain_boundary_support(self):
        self.case("curved", "constrained_converged", 0, "failed_or_not_converged")


if __name__ == "__main__":
    unittest.main()
