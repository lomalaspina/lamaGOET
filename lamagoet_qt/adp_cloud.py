"""Actual Gaussian-broadened displacement PDFs, not deformed ellipsoids.

Only numpy is required. All lengths are Angstrom. Artifacts are data, never
executable input. A failed normalization/grid check is an error, not a fallback
to an ellipsoid labelled as the non-Gaussian distribution.
"""
from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import numpy as np


def model_paths(path):
    """Resolve a bounded native joint manifest, or retain a single artifact.

    Manifest entries must be sibling files, never arbitrary executable input
    or paths outside the result directory. Loading a cloud still validates its
    normalization, total moment and site symmetry through CloudModel.
    """
    path = Path(path).resolve()
    if path.stat().st_size > 40 * 1024 * 1024:
        raise ValueError("Model artifact exceeds the viewer size limit")
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != "tonto.multi-angular-adp":
        return [(str(data.get("target_label", "Target")), path)]
    if data.get("version") != 1 or not isinstance(data.get("targets"), list) or not 1 <= len(data["targets"]) <= 64:
        raise ValueError("Invalid joint angular model manifest")
    result, labels = [], set()
    for row in data["targets"]:
        label, name = row.get("target_label"), row.get("model_file")
        if not isinstance(label, str) or not label or label in labels:
            raise ValueError("Missing or repeated joint angular target label")
        if not isinstance(name, str) or not name or Path(name).name != name or "\\" in name:
            raise ValueError("Joint model entries must be sibling artifact filenames")
        target = (path.parent/name).resolve()
        if target.parent != path.parent or target == path or not target.is_file():
            raise ValueError("Joint model artifact is missing or outside its result directory")
        labels.add(label); result.append((label, target))
    return result


@dataclass
class ProbabilityMesh:
    vertices: np.ndarray
    faces: np.ndarray
    probability: float
    level: float
    integrated_mass: float
    enclosed_mass: float
    grid_size: int
    level_relative_change: float


class CloudModel:
    def __init__(self, data: dict):
        if data.get("schema") not in {"tonto.curved-adp", "tonto.lissajous-adp"} or data.get("version") != 1:
            raise ValueError("Unsupported displacement-model schema/version")
        if data.get("length_unit") != "angstrom":
            raise ValueError("Displacement model must explicitly use Angstrom")
        self.data = data
        self.nodes = self._array("displacement_nodes")
        self.local_u = self._array("local_covariance", (3, 3))
        self.total_u = self._array("total_covariance", (3, 3))
        self.mean = self._array("mean_cartesian", (3,))
        self.direct = self._array("cell_direct", (3, 3))
        self.rotations = self._array("site_rotations")
        if self.nodes.ndim != 2 or self.nodes.shape[1] != 3 or not 1 <= len(self.nodes) <= 131072:
            raise ValueError("Invalid displacement quadrature dimensions")
        if self.rotations.ndim != 3 or self.rotations.shape[1:] != (3, 3) or not 1 <= len(self.rotations) <= 96:
            raise ValueError("Invalid site-group dimensions")
        if data.get('schema') == 'tonto.lissajous-adp':
            self._validate_lissajous_metadata()
        if abs(float(data.get("node_weight", 0)) * len(self.nodes) - 1) > 1e-12:
            raise ValueError("Displacement quadrature is not normalized")
        if np.max(abs(self.local_u - self.local_u.T)) > 1e-12 or np.linalg.eigvalsh(self.local_u).min() <= 0:
            raise ValueError("Local covariance is not symmetric positive definite")
        if np.max(abs(self.nodes.mean(axis=0))) > 1e-9:
            raise ValueError("Displacement cloud is not mean-centered")
        moment = self.local_u + self.nodes.T @ self.nodes / len(self.nodes)
        if not np.allclose(moment, self.total_u, atol=2e-10, rtol=2e-9):
            raise ValueError("Total covariance disagrees with the actual cloud")
        if abs(np.linalg.det(self.direct)) < 1e-9:
            raise ValueError("Singular model cell")
        q = np.array([[.91, 1.37, 2.03], [2.61, -.73, 1.17], [-3.4, 2.8, .47]])
        base = np.exp(1j * (q @ self.nodes.T)).mean(axis=1)
        for r in self.rotations:
            if not np.allclose(r @ r.T, np.eye(3), atol=1e-9, rtol=0):
                raise ValueError("Nonorthogonal Cartesian site operation")
            if not np.allclose(r @ self.local_u @ r.T, self.local_u, atol=1e-11, rtol=1e-9):
                raise ValueError("Local covariance violates site symmetry")
            other = np.exp(1j * (q @ r @ self.nodes.T)).mean(axis=1)
            if np.max(abs(base - other)) > 1e-9:
                raise ValueError("Displacement quadrature violates site symmetry")
        atoms = data.get("atoms", [])
        labels = [a["label"] for a in atoms]
        if not atoms or len(labels) != len(set(labels)) or labels.count(data["target_label"]) != 1:
            raise ValueError("Missing or ambiguous atom identity")
        for a in atoms:
            cart = np.asarray(a["mean_cartesian"], dtype=float)
            frac = np.asarray(a["fractional"], dtype=float)
            cov = np.asarray(a["total_covariance"], dtype=float)
            if cart.shape != (3,) or frac.shape != (3,) or cov.shape != (3, 3):
                raise ValueError("Invalid atom geometry dimensions")
            if not np.isfinite(cart).all() or not np.isfinite(cov).all() or not np.allclose(self.direct @ frac, cart, atol=1e-8):
                raise ValueError("Atom coordinates disagree with model cell")
        self.inverse = np.linalg.inv(self.local_u)
        self.norm = 1 / np.sqrt((2 * np.pi) ** 3 * np.linalg.det(self.local_u))

    def _validate_lissajous_metadata(self):
        """Check the declared trajectory against native quadrature, not its label."""
        import math
        d = self.data
        dim = d.get('dimensions')
        if type(dim) is not int or dim not in (2, 3) or d.get('model') != 'lissajous':
            raise ValueError('Invalid Lissajous dimension/model metadata')
        ratio = d.get('winding_ratio', [])
        if (not isinstance(ratio, list) or len(ratio) != dim or
                any(type(x) is not int or not 1 <= x <= 16 for x in ratio) or math.gcd(*ratio) != 1):
            raise ValueError('Lissajous winding ratio must be reduced positive integers')
        if d.get('averaging') != 'one_shared_uniform_phase' or d.get('absolute_frequencies_refined') is not False or d.get('fixed_last_phase_rad') != 0:
            raise ValueError('Unsupported Lissajous averaging/frequency convention')
        if any(key in d for key in ('pivot_label','pivot_cartesian','parameters_rad')):
            raise ValueError('Lissajous model must not contain a bond pivot or radian-only parameters')
        p = self._array('shape_parameters', (2*dim+2,))
        amps = self._array('amplitudes_A', (dim,))
        phases = self._array('phases_rad', (dim-1,))
        w = self._array('orientation_rad', (3,))
        if d.get('shape_parameter_units') != ['angstrom']*dim+['radian']*(dim+2):
            raise ValueError('Wrong Lissajous parameter units')
        if not np.array_equal(p, np.r_[amps,phases,w]) or np.any(amps < 0):
            raise ValueError('Inconsistent Lissajous parameters')
        angle = np.linalg.norm(w)
        if angle >= np.pi or np.any(abs(phases) > np.pi):
            raise ValueError('Lissajous orientation/phase outside supported chart')
        s = np.array([[0,-w[2],w[1]],[w[2],0,-w[0]],[-w[1],w[0],0]])
        if angle < 1e-4:
            a = 1-angle**2/6+angle**4/120
            b = .5-angle**2/24+angle**4/720
        else:
            a = np.sin(angle)/angle
            b = (1-np.cos(angle))/angle**2
        rotation = np.eye(3)+a*s+b*s@s
        if len(self.nodes) % len(self.rotations):
            raise ValueError('Incomplete Lissajous site orbit')
        n = len(self.nodes)//len(self.rotations)
        if not 16*max(ratio) <= n <= 8192:
            raise ValueError('Unsupported Lissajous phase quadrature')
        theta = 2*np.pi*np.arange(n)/n
        base = np.zeros((3,n))
        base[:dim] = amps[:,None]*np.sin(np.asarray(ratio)[:,None]*theta+np.r_[phases,0][:,None])
        base = rotation@base
        for i,site in enumerate(self.rotations):
            if not np.allclose(self.nodes[i*n:(i+1)*n], (site@base).T, atol=2e-11, rtol=1e-10):
                raise ValueError('Lissajous quadrature disagrees with amplitudes, phases, orientation or site orbit')

    def _array(self, key, shape=None):
        value = np.asarray(self.data[key], dtype=float)
        if not np.isfinite(value).all() or (shape is not None and value.shape != shape):
            raise ValueError(f"Invalid {key}")
        return value

    @classmethod
    def read(cls, path):
        path = Path(path)
        if path.stat().st_size > 40 * 1024 * 1024:
            raise ValueError("Model artifact exceeds the viewer size limit")
        return cls(json.loads(path.read_text(encoding="utf-8")))

    def density(self, points):
        """Positive normalized mixture; centered displacement coordinates."""
        points = np.asarray(points, dtype=float)
        result = np.zeros(len(points))
        # Limit temporary arrays; avoid a points x nodes x 3 allocation.
        for start in range(0, len(self.nodes), 64):
            nodes = self.nodes[start:start + 64]
            ni = nodes @ self.inverse
            nn = np.sum(ni * nodes, axis=1)
            for pos in range(0, len(points), 4096):
                x = points[pos:pos + 4096]
                xx = np.sum((x @ self.inverse) * x, axis=1)
                squared = xx[:, None] + nn[None, :] - 2 * np.einsum('ij,kj->ik', x, ni, optimize=False)
                result[pos:pos + len(x)] += np.exp(-.5 * squared).sum(axis=1)
        return result * (self.norm / len(self.nodes))

    def surface(self, probability=.5, grids=(33, 49, 65, 81, 97)):
        if not .01 <= probability <= .99:
            raise ValueError("Enclosed probability must be between 1% and 99%")
        padding = 6.5 * np.sqrt(np.diag(self.local_u))
        low, high = self.nodes.min(axis=0) - padding, self.nodes.max(axis=0) + padding
        previous = None
        for n in grids:
            axes = [np.linspace(low[i], high[i], n) for i in range(3)]
            spacing = (high - low) / (n - 1)
            positions = np.stack(np.meshgrid(*axes, indexing="ij"), axis=-1)
            field = self.density(positions.reshape(-1, 3)).reshape(n, n, n)
            dv = np.prod(spacing)
            mass = field.sum() * dv
            ordered = np.sort(field.ravel())[::-1]
            cumulative = np.cumsum(ordered) * dv
            index = int(np.searchsorted(cumulative, probability))
            if index >= len(ordered):
                raise ValueError("Probability cloud does not enclose requested mass")
            level = float(ordered[index])
            enclosed = float(field[field >= level].sum() * dv)
            change = np.inf if previous is None else abs(level - previous) / level
            if abs(mass - 1) < 2e-4 and change < .015 and abs(enclosed - probability) < .003:
                vertices, faces = _isosurface(field, level, low, spacing)
                return ProbabilityMesh(vertices, faces, probability, level, float(mass), enclosed, n, float(change))
            previous = level
        raise ValueError("Probability grid did not converge; no approximate shape displayed")


def _isosurface(field, level, origin, spacing):
    """Marching tetrahedra on a Cartesian grid, including disconnected lobes."""
    offsets = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0], [1, 1, 0],
                        [0, 0, 1], [1, 0, 1], [0, 1, 1], [1, 1, 1]])
    n = np.array(field.shape) - 1
    values = np.stack([field[o[0]:o[0] + n[0], o[1]:o[1] + n[1], o[2]:o[2] + n[2]] for o in offsets], axis=-1)
    active = (values.min(axis=-1) < level) & (values.max(axis=-1) >= level)
    cells = np.argwhere(active)
    values = values[active]
    xyz = origin + (cells[:, None, :] + offsets[None, :, :]) * spacing
    triangles = []
    for tetra in ((0, 1, 3, 7), (0, 3, 2, 7), (0, 2, 6, 7), (0, 6, 4, 7), (0, 4, 5, 7), (0, 5, 1, 7)):
        v, p = values[:, tetra], xyz[:, tetra, :]
        codes = ((v >= level) * (1 << np.arange(4))).sum(axis=1)
        for code in range(1, 15):
            selected = codes == code
            if not np.any(selected):
                continue
            vv, pp = v[selected], p[selected]
            inside = [i for i in range(4) if code & (1 << i)]
            outside = [i for i in range(4) if not code & (1 << i)]
            if len(inside) == 2:
                a, b = inside; c, d = outside
                edges = [(a, c), (a, d), (b, c), (b, d)]
                polygons = ((0, 1, 2), (1, 3, 2))
            else:
                single, others = (inside[0], outside) if len(inside) == 1 else (outside[0], inside)
                edges = [(single, i) for i in others]
                polygons = ((0, 1, 2),)
            points = []
            for a, b in edges:
                t = (level - vv[:, a]) / (vv[:, b] - vv[:, a])
                points.append(pp[:, a] + t[:, None] * (pp[:, b] - pp[:, a]))
            points = np.stack(points, axis=1)
            outward = pp[:, outside].mean(axis=1) - pp[:, inside].mean(axis=1)
            for poly in polygons:
                tri = points[:, poly, :].copy()
                normal = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
                flip = (normal * outward).sum(axis=1) < 0
                tri[flip] = tri[flip][:, [0, 2, 1], :]
                triangles.append(tri)
    if not triangles:
        raise ValueError("No probability surface could be extracted")
    vertices = np.concatenate(triangles).reshape(-1, 3)
    return vertices, np.arange(len(vertices)).reshape(-1, 3)
