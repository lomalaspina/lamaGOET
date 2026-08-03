#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from lamagoet_qt import bootstrap


class QtBootstrapTest(unittest.TestCase):
    def test_explicit_environment_override_is_respected(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory) / "project"
            project.mkdir()
            selected = Path(directory) / "custom environment"
            with mock.patch.dict(
                "os.environ", {"LAMAGOET_QT_VENV": str(selected)}, clear=False
            ):
                self.assertEqual(bootstrap.select_environment(project), selected)

    def test_shared_checkout_keeps_incompatible_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            legacy = project / ".venv-qt"
            legacy.mkdir()
            # A Windows interpreter is incompatible with a Linux/WSL launch.
            (legacy / "Scripts").mkdir()
            (legacy / "Scripts" / "python.exe").touch()
            with mock.patch("platform.system", return_value="Linux"), mock.patch(
                "platform.machine", return_value="x86_64"
            ):
                selected = bootstrap.select_environment(project)
        self.assertEqual(selected.name, f".venv-qt-linux-x86_64-py{sys.version_info.major}{sys.version_info.minor}")

    def test_environment_is_created_installed_marked_and_reused(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            requirements = project / "requirements-qt.txt"
            requirements.write_text("PySide6>=6.7,<7\n", encoding="utf-8")
            script = project / "GUI_lamaGOET_qt.py"
            script.write_text("", encoding="utf-8")
            commands: list[list[str]] = []

            def fake_run(command, **_kwargs):
                command = [str(item) for item in command]
                commands.append(command)
                if command[1:3] == ["-m", "venv"]:
                    python = bootstrap.environment_python(Path(command[3]))
                    python.parent.mkdir(parents=True, exist_ok=True)
                    python.touch()
                return subprocess.CompletedProcess(command, 0)

            system_name = "Windows" if sys.platform == "win32" else "Linux"
            with mock.patch("platform.system", return_value=system_name), mock.patch(
                "platform.machine", return_value="test-machine"
            ), mock.patch("subprocess.run", side_effect=fake_run), mock.patch(
                "os.execve"
            ) as execute:
                python = bootstrap.ensure_qt_environment(
                    project, script, ["--mode", "local"]
                )

                self.assertTrue(python.is_file())
                self.assertTrue(any(command[1:3] == ["-m", "venv"] for command in commands))
                installs = [command for command in commands if "pip" in command]
                self.assertEqual(len(installs), 1)
                marker = python.parent.parent / bootstrap.MARKER_NAME
                self.assertEqual(
                    json.loads(marker.read_text(encoding="utf-8"))["schema"], 1
                )
                execute.assert_called_once()
                launched_environment = execute.call_args.args[2]
                self.assertEqual(launched_environment["VIRTUAL_ENV"], str(project / ".venv-qt"))
                self.assertEqual(
                    launched_environment["PATH"].split(bootstrap.os.pathsep)[0],
                    str(python.parent),
                )

                commands.clear()
                execute.reset_mock()
                bootstrap.ensure_qt_environment(project, script, [])
                self.assertFalse(any("pip" in command for command in commands))
                execute.assert_called_once()


if __name__ == "__main__":
    unittest.main()
