"""Read-only shared-U mixture artifact contract, in Angstrom.

This does not enable a refinement or infer a displacement model from a CIF.
Each node is an EXACT Gaussian-component mean, not a quadrature approximation.
The full site orbit is retained, including duplicate means at special points.
"""
from __future__ import annotations

import numpy as np


def mixture_weights(data, nodes, rotations):
    """Validate canonical seed metadata and its full weighted site orbit."""
    if data.get('model') != 'shared_u_two_gaussian_mixture':
        raise ValueError('Invalid shared-U mixture model')
    if data.get('averaging') != 'full_site_probability_average':
        raise ValueError('Mixture requires the full site-probability average')
    if data.get('shape_parameter_units') != ['angstrom'] * 3 + ['dimensionless']:
        raise ValueError('Invalid mixture parameter units')
    if any(k in data for k in ('node_weight', 'pivot_label', 'winding_ratio', 'phases_rad')):
        raise ValueError('Mixture must use component weights, without a pivot or phase convention')
    d = np.asarray(data.get('separation_A'), dtype=float)
    p = np.asarray(data.get('shape_parameters'), dtype=float)
    w = data.get('mixture_weight')
    if (d.shape != (3,) or p.shape != (4,) or not np.isfinite(d).all()
            or not np.isfinite(p).all() or not np.array_equal(d, p[:3])):
        raise ValueError('Inconsistent mixture separation/shape parameters')
    if isinstance(w, bool) or not isinstance(w, (float, int)) or not 0 < w <= .5:
        raise ValueError('Mixture artifact requires canonical 0 < w <= 1/2')
    if p[3] > 0 or not np.isclose(p[3], np.log(w/(1-w)), atol=2e-13, rtol=2e-13):
        raise ValueError('Mixture logit and canonical weight disagree')
    targets = [a for a in data.get('atoms', []) if a.get('label') == data.get('target_label')]
    if len(targets) != 1:
        raise ValueError('Missing or ambiguous mixture target identity')
    for key, shape in [('mean_cartesian', (3,)), ('total_covariance', (3, 3))]:
        value = np.asarray(targets[0].get(key), dtype=float)
        model_value = np.asarray(data.get(key), dtype=float)
        if (value.shape != shape or model_value.shape != shape
                or not np.allclose(value, model_value, atol=2e-12, rtol=1e-12)):
            raise ValueError('Mixture target atom and model geometry/covariance disagree')
    # Orthogonality is also checked by the generic cloud reader. Here verify
    # that this is a complete group, not a hand-picked subset of orientations.
    if not any(np.allclose(r, np.eye(3), atol=1e-10, rtol=0) for r in rotations):
        raise ValueError('Site group has no identity')
    for i, r in enumerate(rotations):
        if any(np.allclose(r, s, atol=1e-10, rtol=0) for s in rotations[:i]):
            raise ValueError('Duplicate site operation')
        for s in rotations:
            if not any(np.allclose(r @ s, t, atol=1e-9, rtol=0) for t in rotations):
                raise ValueError('Incomplete site group')
    weights = np.asarray(data.get('component_weights'), dtype=float)
    expected_nodes = np.concatenate([np.array([(1-w)*d, -w*d]) @ r.T for r in rotations])
    expected_weights = np.tile([w, 1-w], len(rotations)) / len(rotations)
    if (nodes.shape != expected_nodes.shape or weights.shape != expected_weights.shape
            or not np.isfinite(weights).all() or np.any(weights <= 0)
            or not np.allclose(nodes, expected_nodes, atol=2e-12, rtol=1e-12)
            or not np.allclose(weights, expected_weights, atol=2e-15, rtol=1e-14)
            or abs(weights.sum() - 1) > 1e-14):
        raise ValueError('Mixture nodes/weights disagree with canonical full site orbit')
    return weights
