"""Wavelength-dependent anomalous-dispersion coefficients for lamaGOET.

Two calculation paths are exposed because WinGX/XDISP offers both of them:

``fprime``
    The Cromer--Liberman FPRIME implementation (Kissel--Pratt correction,
    without the Jensen term), ported from GSAS-II's :func:`FPcalc` routine.
    It reads the traditional ``Xsect.dat``/``xsect_n.dat`` orbital table.

``brennan``
    The Brennan--Cowan Cromer--Liberman implementation provided by Gemmi.

The resolved numbers, rather than merely the selected source, are written to
``job_options.txt`` by the GUI.  Cluster calculations therefore reproduce the
GUI-side coefficients without needing Gemmi, the orbital table, or network
access on the compute node.
"""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import math
import os
from pathlib import Path
import tempfile
import urllib.request


FPRIME_DATA_URL = (
    "https://raw.githubusercontent.com/AdvancedPhotonSource/GSAS-II/"
    "f75620dc7e6dfe40b2b193052dc6c524f7e3f72b/GSASII/inputs/Xsect.dat"
)
FPRIME_DATA_SHA256 = (
    "90be10ad9899b18f36933ffc1d31e7f2dce28c2373b6bfdd8539f7f6a1a9117f"
)


class DispersionError(RuntimeError):
    """Raised when anomalous-scattering coefficients cannot be resolved."""


@dataclass(frozen=True)
class DispersionCoefficient:
    element: str
    fp: float
    fpp: float
    source: str
    manual: bool = False


def _normal_element(element: str) -> str:
    value = element.strip()
    if not value:
        raise DispersionError("An empty element symbol was supplied.")
    return value[0].upper() + value[1:].lower()


def _candidate_fprime_paths() -> list[Path]:
    candidates: list[Path] = []
    configured = os.environ.get("LAMAGOET_XSECT_DATA", "").strip()
    if configured:
        candidates.append(Path(configured).expanduser())
    candidates.extend(
        (
            Path(__file__).resolve().parent / "data" / "Xsect.dat",
            Path.home() / ".cache" / "lamagoet" / "Xsect.dat",
            Path("/mnt/c/wingx/files/xsect_n.dat"),
            Path("/mnt/c/WinGX/files/xsect_n.dat"),
            Path(r"C:\wingx\files\xsect_n.dat"),
            Path(r"C:\WinGX\files\xsect_n.dat"),
        )
    )
    result: list[Path] = []
    for candidate in candidates:
        if candidate not in result:
            result.append(candidate)
    return result


def find_fprime_data() -> Path | None:
    """Return an installed FPRIME orbital table, if one is available."""

    return next((path for path in _candidate_fprime_paths() if path.is_file()), None)


def install_fprime_data(destination: str | Path | None = None) -> Path:
    """Download the pinned GSAS-II FPRIME table and verify its checksum."""

    target = (
        Path(destination).expanduser()
        if destination is not None
        else Path.home() / ".cache" / "lamagoet" / "Xsect.dat"
    )
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(FPRIME_DATA_URL, timeout=45) as response:
            payload = response.read()
    except OSError as exc:
        raise DispersionError(
            "Could not download the FPRIME Xsect.dat table. Re-run install.sh "
            "with network access, install WinGX, or set LAMAGOET_XSECT_DATA "
            "to a compatible Xsect.dat/xsect_n.dat file."
        ) from exc
    digest = hashlib.sha256(payload).hexdigest()
    if digest.lower() != FPRIME_DATA_SHA256:
        raise DispersionError(
            "The downloaded FPRIME Xsect.dat table failed its SHA-256 check; "
            "it was not installed."
        )
    handle, temporary_name = tempfile.mkstemp(
        prefix=".Xsect.", suffix=".tmp", dir=target.parent
    )
    try:
        with os.fdopen(handle, "wb") as stream:
            stream.write(payload)
        os.replace(temporary_name, target)
    finally:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
    return target


def ensure_fprime_data(*, download: bool = True) -> Path:
    path = find_fprime_data()
    if path is not None:
        return path
    if download:
        return install_fprime_data()
    raise DispersionError(
        "No FPRIME Xsect.dat table is installed. Re-run install.sh, install "
        "WinGX, or set LAMAGOET_XSECT_DATA."
    )


def _fortran_float(value: str) -> float:
    return float(value.replace("D", "E").replace("d", "e"))


def _xsection_orbitals(element: str, path: Path) -> list[dict[str, object]]:
    """Read one element from a traditional FPRIME orbital table."""

    symbol = _normal_element(element).upper().ljust(2)
    try:
        lines = path.read_text(encoding="ascii", errors="replace").splitlines()
    except OSError as exc:
        raise DispersionError(f"Could not read the FPRIME table {path}: {exc}") from exc

    au = 2.80022e7
    c1 = 0.02721
    result: list[dict[str, object]] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if line[:2] != symbol:
            index += 1
            continue
        if index + 2 >= len(lines):
            raise DispersionError(f"Truncated FPRIME record for {element} in {path}.")
        record = line + lines[index + 1] + lines[index + 2]
        orbital_name = record[9:14].strip()
        record = record[14:]
        try:
            if_be = int(record[0])
            values = record[1:].split()
            binding_energy = _fortran_float(values[0])
            energies = [_fortran_float(values[2 * i + 1]) for i in range(11)]
            cross_sections = [
                _fortran_float(values[2 * i + 2]) for i in range(11)
            ]
        except (IndexError, ValueError) as exc:
            raise DispersionError(
                f"Could not parse the {element} {orbital_name or 'orbital'} "
                f"record in {path}."
            ) from exc
        orbital: dict[str, object] = {
            "name": orbital_name,
            "if_be": if_be,
            "binding_energy": binding_energy,
            "bb": binding_energy / c1,
            "xsection_ip": [value / au for value in cross_sections[5:10]],
        }
        if if_be == 0:
            orbital["s_edge"] = cross_sections[10] / au
            n_values = 11
        else:
            orbital["energy_term"] = cross_sections[10]
            energies = energies[:10]
            cross_sections = cross_sections[:10]
            n_values = 10
            orbital["s_edge"] = 0.0
        ordered = sorted(zip(energies, cross_sections))
        orbital["n_values"] = n_values
        orbital["log_energy"] = [math.log(item[0]) for item in ordered]
        orbital["log_xsection"] = [
            math.log(item[1]) if item[1] > 0.0 else 0.0 for item in ordered
        ]
        result.append(orbital)
        index += 3
    if not result:
        if symbol.strip() in {"H", "HE"}:
            return []
        raise DispersionError(
            f"Element {_normal_element(element)} is not present in the "
            f"FPRIME table {path}."
        )
    return result


def _fprime_fpcalc(orbitals: list[dict[str, object]], energy_kev: float) -> tuple[float, float]:
    """Port of GSAS-II FPcalc (Cromer--Liberman FPRIME)."""

    def aitken(orbital: dict[str, object], log_energy_kev: float) -> float:
        n_values = int(orbital["n_values"])
        j = n_values - 1
        log_energies = orbital["log_energy"]
        assert isinstance(log_energies, list)
        for i in range(n_values):
            if log_energies[i] <= log_energy_kev:
                j = i
        if j > n_values - 3:
            j = n_values - 3
        table = [0.0] * 6
        log_xsection = orbital["log_xsection"]
        assert isinstance(log_xsection, list)
        for i in range(3):
            table[i] = log_xsection[i + j]
            table[i + 3] = log_energies[i + j] - log_energy_kev
        table[1] = (
            table[0] * table[4] - table[1] * table[3]
        ) / (log_energies[j + 1] - log_energies[j])
        table[2] = (
            table[0] * table[5] - table[2] * table[3]
        ) / (log_energies[j + 2] - log_energies[j])
        return (
            table[1] * table[5] - table[2] * table[4]
        ) / (log_energies[j + 2] - log_energies[j + 1])

    def dgauss(
        orbital: dict[str, object], cx: float, rx: float, isig: int
    ) -> float:
        weights = (
            0.11846344252810,
            0.23931433524968,
            0.284444444444,
            0.23931433524968,
            0.11846344252810,
        )
        abscissae = (
            0.04691007703067,
            0.23076534494716,
            0.5,
            0.76923465505284,
            0.95308992296933,
        )
        bb = float(orbital["bb"])
        b2 = bb * bb
        r2 = rx * rx
        xsections = orbital["xsection_ip"]
        assert isinstance(xsections, list)
        value = 0.0
        for weight, x, xsection in zip(weights, abscissae, xsections):
            x2 = x * x
            if isig == 0:
                term = bb * (xsection * (b2 / x2) - cx * r2) / (r2 * x2 - b2)
            elif isig == 1:
                term = 0.5 * bb * b2 * xsection / (
                    math.sqrt(x) * (r2 * x2 - x * b2)
                )
            elif isig == 2:
                denominator = x * x2 * r2 - b2 / x
                term = 2.0 * bb * (
                    xsection * b2 / (denominator * x2 * x2)
                    - cx * r2 / denominator
                )
            else:
                term = bb * b2 * (
                    xsection - float(orbital["s_edge"]) * x2
                ) / (r2 * x2 * x2 - x2 * b2)
            value += weight * term
        return value

    if not orbitals:
        return 0.0, 0.0
    au = 2.80022e7
    c1 = 0.02721
    c = 137.0367
    fp = 0.0
    fpp = 0.0
    log_energy = math.log(energy_kev)
    rx = energy_kev / c1
    energy_term = 0.0
    for orbital in orbitals:
        cx = 0.0
        bb = float(orbital["bb"])
        binding_energy = float(orbital["binding_energy"])
        if int(orbital["if_be"]) != 0:
            energy_term = float(orbital["energy_term"])
        if binding_energy <= energy_kev:
            cx = math.exp(aitken(orbital, log_energy)) / au
        correction = 0.0
        if int(orbital["if_be"]) == 0 and binding_energy >= energy_kev:
            cx = 0.0
            fpi = dgauss(orbital, cx, rx, 3)
            correction = (
                0.5
                * float(orbital["s_edge"])
                * bb**2
                * math.log((rx - bb) / (-rx - bb))
                / rx
            )
        else:
            fpi = dgauss(orbital, cx, rx, int(orbital["if_be"]))
            if cx != 0.0:
                correction = -0.5 * cx * rx * math.log((rx + bb) / (rx - bb))
        fp += (fpi + correction) * c / (2.0 * math.pi**2)
        fpp += c * cx * rx / (4.0 * math.pi)
    return fp - energy_term, fpp


def calculate_dispersion(
    element: str,
    wavelength_angstrom: float,
    source: str,
    *,
    fprime_data: str | Path | None = None,
) -> DispersionCoefficient:
    """Calculate f-prime/f-double-prime for one neutral free atom."""

    symbol = _normal_element(element)
    if not math.isfinite(wavelength_angstrom) or wavelength_angstrom <= 0.0:
        raise DispersionError("The wavelength must be a positive finite number.")
    selected = source.strip().lower()
    if symbol in {"H", "He"}:
        # Both traditional implementations begin at Li; XDISP writes zeros
        # for H and He because their anomalous terms are negligible here.
        return DispersionCoefficient(symbol, 0.0, 0.0, selected)
    if selected == "fprime":
        path = Path(fprime_data) if fprime_data is not None else ensure_fprime_data()
        orbitals = _xsection_orbitals(symbol, path)
        # Traditional FPRIME uses this rounded hc value in keV Angstrom.
        fp, fpp = _fprime_fpcalc(orbitals, 12.397639 / wavelength_angstrom)
    elif selected == "brennan":
        try:
            import gemmi
        except ImportError as exc:
            raise DispersionError(
                "The Brennan--Cowan option requires Gemmi. Re-run install.sh "
                "or install requirements-qt.txt in the lamaGOET environment."
            ) from exc
        z = gemmi.Element(symbol).atomic_number
        if z < 3 or z > 92:
            raise DispersionError(
                f"The Brennan--Cowan/Gemmi implementation supports Li through U; "
                f"{symbol} is outside that range. Use FPRIME or a manual override."
            )
        fp, fpp = gemmi.cromer_liberman(
            z=z, energy=gemmi.hc / wavelength_angstrom
        )
    else:
        raise DispersionError(
            f"Unknown dispersion source {source!r}; choose 'fprime' or 'brennan'."
        )
    if not all(math.isfinite(value) for value in (fp, fpp)):
        raise DispersionError(
            f"{source} returned a non-finite dispersion coefficient for {symbol}."
        )
    return DispersionCoefficient(symbol, float(fp), float(fpp), selected)


def resolve_dispersion(
    elements: list[str] | tuple[str, ...],
    wavelength_angstrom: float,
    source: str,
    overrides: dict[str, tuple[float, float]] | None = None,
    *,
    fprime_data: str | Path | None = None,
) -> list[DispersionCoefficient]:
    """Resolve a deterministic per-element table, applying manual overrides."""

    manual = {
        _normal_element(element): (float(values[0]), float(values[1]))
        for element, values in (overrides or {}).items()
    }
    result: list[DispersionCoefficient] = []
    for element in sorted({_normal_element(value) for value in elements}, key=str.casefold):
        if element in manual:
            fp, fpp = manual[element]
            if not all(math.isfinite(value) for value in (fp, fpp)):
                raise DispersionError(
                    f"The manual dispersion coefficients for {element} must be finite."
                )
            result.append(
                DispersionCoefficient(element, fp, fpp, source, manual=True)
            )
        else:
            result.append(
                calculate_dispersion(
                    element,
                    wavelength_angstrom,
                    source,
                    fprime_data=fprime_data,
                )
            )
    return result


def serialize_coefficients(values: list[DispersionCoefficient]) -> str:
    """Return Tonto's flat ``element f' f''`` list on one shell-safe line."""

    return " ".join(
        f"{value.element} {value.fp:.10g} {value.fpp:.10g}" for value in values
    )


def serialize_overrides(overrides: dict[str, tuple[float, float]]) -> str:
    canonical = {
        _normal_element(element): [float(values[0]), float(values[1])]
        for element, values in sorted(overrides.items(), key=lambda item: item[0].casefold())
    }
    return json.dumps(canonical, sort_keys=True, separators=(",", ":"))


def parse_overrides(value: str) -> dict[str, tuple[float, float]]:
    if not value.strip():
        return {}
    try:
        raw = json.loads(value)
        result = {
            _normal_element(element): (float(values[0]), float(values[1]))
            for element, values in raw.items()
        }
    except (AttributeError, IndexError, TypeError, ValueError, json.JSONDecodeError) as exc:
        raise DispersionError(
            "DISPERSION_MANUAL_OVERRIDES is not a valid element-to-[f',f''] mapping."
        ) from exc
    return result
