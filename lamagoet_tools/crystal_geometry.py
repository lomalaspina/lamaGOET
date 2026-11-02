"""Geometry-only CRYSTAL cycle zero and labelled asymmetric-atom ordering.

This deliberately does not rewrite CIF representatives/ADPs, transform a density
matrix, or certify GUESSP compatibility. The existing restart guard still applies.
"""
from __future__ import annotations

import argparse
from decimal import Decimal
import hashlib
import json
import math
from pathlib import Path
import re
import sys

from cif_to_cp2k import parse_cif, strip_esd


VERSION = 1
ELEMENTS = ("X H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn "
            "Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La "
            "Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi "
            "Po At Rn Fr Ra Ac Th Pa U Np Pu Am Cm Bk Cf Es Fm Md No Lr Rf Db Sg Bh Hs Mt "
            "Ds Rg Cn Nh Fl Mc Lv Ts Og").split()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def number(value):
    result = strip_esd(value.replace("D", "E").replace("d", "e"))
    require(math.isfinite(result), "Non-finite geometry value")
    return result


def rounding(value):
    """Half the printed last place, not the experimental standard uncertainty."""
    plain = re.sub(r"\([^)]*\)$", "", value)
    return float(Decimal(10) ** Decimal(Decimal(plain).as_tuple().exponent)) / 2


def input_geometry(path):
    rows = Path(path).read_text().splitlines(keepends=True)
    require(len(rows) > 7 and rows[1].strip() == "CRYSTAL",
            "Cycle zero expects lamaGOET's CRYSTAL geometry input")
    count = int(rows[5].strip())
    require(count > 0 and len(rows) > 6 + count, "Invalid asymmetric atom count")
    atoms = []
    for row in rows[6:6 + count]:
        fields = row.split()
        require(len(fields) == 4, "Expected atomic number and three fractional coordinates")
        z = int(fields[0])
        require(1 <= z < len(ELEMENTS), "Cycle zero requires ordinary all-electron atomic numbers")
        atoms.append((z, [number(v) for v in fields[1:]], fields[1:]))
    end = 6 + count
    # Only geometry options currently emitted by both lamaGOET runners.
    while end < len(rows):
        keyword = rows[end].strip().upper()
        if keyword in ("BASISSET", "END"):
            break
        if keyword in ("KEEPSYMM", "NOSHIFT"):
            end += 1
        elif keyword == "SUPERCON":
            require(end + 3 < len(rows), "Incomplete SUPERCON")
            matrix = [[number(x) for x in row.split()] for row in rows[end+1:end+4]]
            require(matrix == [[1., 0., 0.], [0., 1., 0.], [0., 0., 1.]],
                    "Cycle zero does not yet map non-identity SUPERCON")
            end += 4
        else:
            raise ValueError(f"Unsupported cycle-zero geometry directive: {keyword}")
    require(end < len(rows), "Missing geometry terminator")
    return rows, atoms, end


def labelled_atoms(cif):
    _, loops = parse_cif(Path(cif).read_text())
    preferred = [loop for loop in loops if "_atom_site_cryst_label" in loop[0]]
    if preferred:
        label, coords = "_atom_site_cryst_label", ["_atom_site_cryst_" + x for x in "xyz"]
    else:
        preferred = [loop for loop in loops if "_atom_site_label" in loop[0]]
        label, coords = "_atom_site_label", ["_atom_site_fract_" + x for x in "xyz"]
    require(len(preferred) == 1, "Expected exactly one fractional atom table in Tonto's CIF")
    tags, rows = preferred[0]
    require(all(tag in tags for tag in coords), "Missing fractional coordinates")
    result = {}
    for row in rows:
        name = row[tags.index(label)]
        require(name not in result, f"Duplicate CIF label {name}")
        values = [row[tags.index(tag)] for tag in coords]
        result[name] = ([number(x) for x in values], values)
    return result


def identify(path, cif):
    rows, atoms, end = input_geometry(path)
    labelled = labelled_atoms(cif)
    # put_cif can contain a grown molecular fragment while write_xtal23_xyz_file
    # contains only the asymmetric unit. Identify that subset, do not expand it.
    require(len(atoms) <= len(labelled), "CIF has fewer atoms than the CRYSTAL asymmetric unit")
    ordered = []
    for z, xyz, tokens in atoms:
        matches = []
        for label, (position, values) in labelled.items():
            # Compare this cycle's generated files, never nearest neighbours across
            # refinement cycles. Permit whole-cell images and printed rounding only.
            if all(abs((x-y) - round(x-y)) <= min(1e-4, rounding(a)+rounding(b)) + 2e-11
                   for x, y, a, b in zip(xyz, position, tokens, values)):
                matches.append(label)
        require(len(matches) == 1, "Ambiguous or missing CIF label for CRYSTAL atom")
        ordered.append({"label": matches[0], "atomic_number": z})
    require(len({x["label"] for x in ordered}) == len(atoms), "Non-bijective atom mapping")
    return rows, ordered, end


def prepare(input_path, cif, folder):
    folder = Path(folder)
    require(folder.is_dir(), "Cycle-zero evidence directory must already exist")
    rows, ordered, end = identify(input_path, cif)
    (folder / "source.d12").write_bytes(Path(input_path).read_bytes())
    (folder / "source.cif").write_bytes(Path(cif).read_bytes())
    (folder / "geometry.d12").write_text("".join(rows[:end]) + "EXTPRT\nTESTGEOM\nEND\n")
    record = {"version": VERSION, "atoms": ordered, "source_input_sha256": digest(input_path),
              "source_cif_sha256": digest(cif), "geometry_input_sha256": digest(folder / "geometry.d12"),
              "evidence_directory": str(folder.resolve()), "restart_certified": False}
    (folder / "pending.json").write_text(json.dumps(record, indent=2) + "\n")


def determinant(a):
    return (a[0][0]*(a[1][1]*a[2][2]-a[1][2]*a[2][1])
            - a[0][1]*(a[1][0]*a[2][2]-a[1][2]*a[2][0])
            + a[0][2]*(a[1][0]*a[2][1]-a[1][1]*a[2][0]))


def inspect_gui(path):
    rows = Path(path).read_text().splitlines()
    require(len(rows) >= 11, "Truncated EXTPRT geometry")
    header = [int(x) for x in rows[0].split()]
    require(len(header) == 3 and header[0] == 3, "Expected three-dimensional CRYSTAL geometry")
    lattice = [[number(x) for x in row.split()] for row in rows[1:4]]
    require(all(len(row) == 3 for row in lattice), "Invalid primitive lattice")
    volume = abs(determinant(lattice))
    require(volume > 1e-8, "Singular primitive lattice")
    nops = int(rows[4])
    require(1 <= nops <= 192 and len(rows) > 5 + 4*nops, "Invalid symmetry operator count")
    for i in range(nops):
        op = [[number(x) for x in row.split()] for row in rows[5+4*i:9+4*i]]
        require(all(len(row) == 3 for row in op), "Invalid geometry symmetry operator")
        require(abs(abs(determinant(op[:3])) - 1) < 1e-8, "Singular symmetry operator")
    start = 6 + 4*nops
    count = int(rows[start-1])
    require(count > 0 and len(rows) >= start+count, "Invalid primitive atom count")
    atoms = []
    for row in rows[start:start+count]:
        fields = row.split()
        require(len(fields) == 4, "Invalid primitive atom row")
        z = int(fields[0])
        require(1 <= z < len(ELEMENTS), "Unsupported exported atomic number")
        atoms.append({"atomic_number": z, "cartesian_angstrom": [number(x) for x in fields[1:]]})
    return {"primitive_lattice_angstrom": lattice, "primitive_volume_angstrom3": volume,
            "symmetry_operations": nops, "primitive_atoms": atoms, "gui_sha256": digest(path)}


def accept(folder, record_path):
    folder = Path(folder)
    record = json.loads((folder / "pending.json").read_text())
    require(digest(folder / "geometry.d12") == record["geometry_input_sha256"], "Geometry input changed")
    output = (folder / "geometry.out").read_text(errors="replace")
    require("ERROR" not in output.upper() and not re.search(r"\bNAN\b|\bCYC\s+\d+\s+ETOT", output),
            "Geometry-only CRYSTAL failed or unexpectedly entered SCF")
    geometry = inspect_gui(folder / "geometry.gui")
    require({x["atomic_number"] for x in record["atoms"]} ==
            {x["atomic_number"] for x in geometry["primitive_atoms"]}, "Export changed the element set")
    record.update(geometry=geometry, geometry_output_sha256=digest(folder / "geometry.out"))
    record["status"] = "geometry_exported_and_input_order_recorded"
    content = json.dumps(record, indent=2) + "\n"
    (folder / "validated.json").write_text(content)
    Path(record_path).write_text(content)


def order(input_path, cif, record_path):
    rows, current, _ = identify(input_path, cif)
    record = json.loads(Path(record_path).read_text())
    require(record["version"] == VERSION and record["status"] == "geometry_exported_and_input_order_recorded",
            "Unvalidated cycle-zero ordering record")
    wanted = record["atoms"]
    require(len(current) == len(wanted), "Asymmetric atom count changed since cycle zero")
    by_label = {atom["label"]: row for atom, row in zip(current, rows[6:6+len(current)])}
    aliases = {}
    for atom in wanted:
        matches = [x for x in current if x == atom]
        if not matches:
            z = atom["atomic_number"]
            old = [x for x in wanted if x["atomic_number"] == z]
            new = [x for x in current if x["atomic_number"] == z]
            # Older Tonto imports renamed a sole N1 to N (NH3). Support only
            # this exact, unambiguous singleton convention, not proximity-based
            # relabelling or an arbitrary permutation of same-element sites.
            if len(old) == len(new) == 1 and {old[0]["label"], new[0]["label"]} == {ELEMENTS[z], ELEMENTS[z]+"1"}:
                matches = new
        require(len(matches) == 1,
                "Asymmetric atom labels/elements changed since cycle zero; cannot preserve AO order")
        aliases[atom["label"]] = matches[0]["label"]
    require(len(set(aliases.values())) == len(wanted), "Non-bijective current atom mapping")
    rows[6:6+len(current)] = [by_label[aliases[atom["label"]]] for atom in wanted]
    # Reorder complete lines only: no coordinate rounding, wrapping, or CIF/ADP edits.
    Path(input_path).write_text("".join(rows))
    Path(str(input_path) + ".atom-order.json").write_text(json.dumps({
        "cycle_zero_record": str(Path(record_path).resolve()), "current_label_for_initial_label": aliases,
        "input_order": current, "output_order": wanted, "ordered_input_sha256": digest(input_path),
        "source_cif_sha256": digest(cif), "restart_certified": False}, indent=2) + "\n")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    for action in ("prepare", "order"):
        command = sub.add_parser(action)
        command.add_argument("input")
        command.add_argument("cif")
        command.add_argument("destination")
    command = sub.add_parser("accept")
    command.add_argument("folder")
    command.add_argument("record")
    args = parser.parse_args(argv)
    try:
        if args.action == "prepare":
            prepare(args.input, args.cif, args.destination)
        elif args.action == "order":
            order(args.input, args.cif, args.destination)
        else:
            accept(args.folder, args.record)
    except (OSError, ValueError, RuntimeError, KeyError, IndexError) as exc:
        if args.action == "order":
            try:
                Path(args.input + ".atom-order.json").write_text(json.dumps({
                    "status": "ordering_not_certified_fresh_scf_required", "error": str(exc),
                    "input_sha256": digest(args.input), "cif": args.cif,
                    "cycle_zero_record": args.destination, "restart_certified": False}, indent=2) + "\n")
            except OSError:
                pass  # Shell still invalidates restart provenance or stops.
        print(f"lamaGOET CRYSTAL cycle zero: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
