"""Round-trip the shell assignment file shared by all lamaGOET front ends."""

from __future__ import annotations

from collections import OrderedDict
from pathlib import Path
import re
import shlex
from typing import Mapping

from .options_schema import complete_job_options


_ASSIGNMENT = re.compile(r"^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$")


def cp2k_basis_names(path: str | Path) -> list[str]:
    """Return every alias declared by a CP2K basis-block header."""

    result: list[str] = []
    basis_path = Path(path).expanduser()
    if not basis_path.is_file():
        return result
    for raw_line in basis_path.read_text(
        encoding="utf-8", errors="replace"
    ).splitlines():
        fields = raw_line.split()
        if (
            len(fields) >= 2
            and re.fullmatch(r"[A-Z][a-z]?", fields[0])
            and not fields[1][0].isdigit()
        ):
            for field in fields[1:]:
                if not re.match(r"^[0-9.+-]", field) and field not in result:
                    result.append(field)
    return result


def _decode_shell_value(value: str) -> str:
    value = value.strip()
    if not value:
        return ""
    if len(value) >= 2 and value[0] == value[-1] == '"':
        body = value[1:-1]
        result: list[str] = []
        index = 0
        while index < len(body):
            if body[index] == "\\" and index + 1 < len(body):
                following = body[index + 1]
                if following in {'\\', '"', "$", "`"}:
                    result.append(following)
                    index += 2
                    continue
                if following == "n":
                    result.append("\n")
                    index += 2
                    continue
            result.append(body[index])
            index += 1
        return "".join(result)
    if len(value) >= 2 and value[0] == value[-1] == "'":
        return value[1:-1]
    try:
        parts = shlex.split(value, posix=True)
    except ValueError:
        return value.strip("'\"")
    return parts[0] if len(parts) == 1 else " ".join(parts)


def load_job_options(path: str | Path) -> "OrderedDict[str, str]":
    result: "OrderedDict[str, str]" = OrderedDict()
    option_path = Path(path)
    if option_path.exists():
        for raw_line in option_path.read_text(
            encoding="utf-8", errors="replace"
        ).splitlines():
            match = _ASSIGNMENT.match(raw_line.strip())
            if match:
                result[match.group(1)] = _decode_shell_value(match.group(2))
    if not result.get("COMPLETESTRUCT") and result.get("COMPLETECIF"):
        result["COMPLETESTRUCT"] = result["COMPLETECIF"]
    return OrderedDict(
        (name, str(value)) for name, value in complete_job_options(result).items()
    )


def _quote_shell(value: object) -> str:
    text = str(value)
    return '"' + (
        text.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("$", "\\$")
        .replace("`", "\\`")
        .replace("\n", "\\n")
    ) + '"'


def save_job_options(
    path: str | Path,
    values: Mapping[str, object],
    *,
    preserved: Mapping[str, object] | None = None,
) -> Path:
    merged: "OrderedDict[str, object]" = OrderedDict()
    if preserved:
        merged.update(preserved)
    merged.update(values)
    merged = complete_job_options(merged)
    option_path = Path(path)
    option_path.parent.mkdir(parents=True, exist_ok=True)
    option_path.write_text(
        "".join(f"{name}={_quote_shell(value)}\n" for name, value in merged.items()),
        encoding="utf-8",
        newline="\n",
    )
    return option_path.resolve()
