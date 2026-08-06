"""Checks for the Windows paths, none of which can be run from macOS or Linux.

lamaGOET supports Windows two ways:

  WSL             everything behaves as it does on Linux; this is the
                  recommended route and needs no special code
  native Windows  the Qt interface runs and can submit to a cluster, but
                  cannot run a calculation here, because lamaGOET.sh needs a
                  Unix shell

These tests cover what can be verified without a Windows machine: file
encodings, the interpreter-path logic, and the guard on local runs.  Whether
PySide6 actually paints a window on Windows is untested.
"""

import os
import sys
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))


class WindowsLauncherTest(unittest.TestCase):
    """The .cmd launchers must have CRLF line endings.

    cmd.exe parses batch files by byte offset and mishandles LF-only files,
    particularly around goto labels - which these launchers use heavily.  The
    symptom appears only on Windows, so nothing else would catch it.
    """

    def test_cmd_files_use_crlf(self):
        cmd_files = sorted(REPO.glob("*.cmd"))
        self.assertTrue(cmd_files, "no .cmd launchers found")
        for path in cmd_files:
            data = path.read_bytes()
            with self.subTest(launcher=path.name):
                self.assertNotIn(
                    b"\r\r\n", data, f"{path.name} has doubled carriage returns"
                )
                lone_lf = data.replace(b"\r\n", b"").count(b"\n")
                self.assertEqual(
                    lone_lf,
                    0,
                    f"{path.name} has {lone_lf} LF-only line endings; cmd.exe "
                    f"mis-parses goto labels in such files",
                )

    def test_gitattributes_keeps_them_crlf(self):
        attributes = (REPO / ".gitattributes").read_text(encoding="utf-8")
        self.assertIn("*.cmd", attributes)
        self.assertIn("eol=crlf", attributes)

    def test_command_files_are_not_crlf(self):
        """macOS .command files are bash; a CR would break the shebang."""
        for path in sorted(REPO.glob("*.command")):
            with self.subTest(launcher=path.name):
                self.assertNotIn(b"\r", path.read_bytes())


class WindowsEnvironmentTest(unittest.TestCase):
    def test_venv_interpreter_path_is_windows_shaped(self):
        from lamagoet_qt import bootstrap

        environment = Path("C:/somewhere/.venv-qt")
        self.assertEqual(
            bootstrap.environment_python(environment, system_name="Windows"),
            environment / "Scripts" / "python.exe",
        )
        self.assertEqual(
            bootstrap.environment_python(environment, system_name="Linux"),
            environment / "bin" / "python",
        )

    def test_user_environment_root_uses_localappdata(self):
        from lamagoet_qt import bootstrap

        with mock.patch.object(
            bootstrap.platform, "system", return_value="Windows"
        ), mock.patch.dict(
            os.environ, {"LOCALAPPDATA": r"C:\Users\someone\AppData\Local"}, clear=False
        ):
            root = bootstrap._user_environment_root()
        self.assertEqual(root.name, "lamaGOET")
        self.assertIn("AppData", str(root))


class WindowsJobOptionsTest(unittest.TestCase):
    def test_job_options_are_written_with_unix_newlines(self):
        """WSL bash reads a file native Windows Python may have written."""
        import tempfile

        from lamagoet_qt.job_options import save_job_options

        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "job_options.txt"
            save_job_options(target, {"JOBNAME": "my_job"})
            self.assertNotIn(
                b"\r\n",
                target.read_bytes(),
                "job_options.txt must use LF; bash does not strip the CR and "
                "every value would end with one",
            )


class WindowsLocalRunTest(unittest.TestCase):
    def test_local_run_on_native_windows_explains_itself(self):
        """`bash` on native Windows is WSL's launcher and cannot take C:\\ paths."""
        source = (REPO / "lamagoet_qt" / "main_window.py").read_text(encoding="utf-8")
        marker = 'if os.name == "nt":'
        self.assertIn(marker, source)
        guard = source[source.index(marker):source.index(marker) + 1200]
        self.assertIn("WSL", guard)
        self.assertIn("GUI_lamaGOET_qt.cmd", guard)
        self.assertLess(
            source.index(marker),
            source.index('bash = shutil.which("bash")'),
            "the Windows guard must come before bash is looked up",
        )


if __name__ == "__main__":
    unittest.main()
