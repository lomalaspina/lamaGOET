"""Explicit 2D/3D Lissajous configuration, separate from angular ADPs.

This opt-in interface must never fall back to an ordinary harmonic run.
Executable capability is checked separately before a result directory is made.
"""
import math
import re

DEFAULTS = {
    'LISSAJOUS_TARGET': '',
    'LISSAJOUS_DIMENSIONS': '2',
    'LISSAJOUS_RATIO_2D': '1 2',
    'LISSAJOUS_RATIO_3D': '1 2 3',
    'LISSAJOUS_AMPLITUDES_2D': '0.03 0.02',
    'LISSAJOUS_AMPLITUDES_3D': '0.03 0.02 0.015',
    'LISSAJOUS_PHASES_2D': '0.31',
    'LISSAJOUS_PHASES_3D': '0.31 -0.23',
    'LISSAJOUS_ORIENTATION': '0 0 0',
}


def configuration(options):
    """Preserve ordered winding integers and physical units; never round them."""
    o = DEFAULTS | options
    if str(o['LISSAJOUS_DIMENSIONS']) not in {'2', '3'}:
        raise ValueError('Choose 2D or 3D Lissajous motion')
    dim = int(o['LISSAJOUS_DIMENSIONS'])
    tag = f'{dim}D'
    tokens = str(o['LISSAJOUS_RATIO_'+tag]).replace(':', ' ').split()
    if len(tokens) != dim or any(not re.fullmatch(r'[1-9][0-9]*', s) for s in tokens):
        raise ValueError(f'Use {dim} positive integer winding numbers, not fitted frequencies')
    ratio = [int(s) for s in tokens]
    if max(ratio) > 16 or math.gcd(*ratio) != 1:
        raise ValueError('Use a reduced integer ratio with entries from 1 to 16')
    if len(set(ratio)) != dim:
        raise ValueError('Repeated frequencies have redundant free phase/orientation parameters')

    def numbers(key, count):
        try:
            values = [float(s) for s in str(o[key]).replace(',', ' ').split()]
        except ValueError as exc:
            raise ValueError(f'{key} requires finite numeric values') from exc
        if len(values) != count or not all(math.isfinite(x) for x in values):
            raise ValueError(f'{key} requires {count} finite values')
        return values

    amps = numbers('LISSAJOUS_AMPLITUDES_'+tag, dim)
    phases = numbers('LISSAJOUS_PHASES_'+tag, dim-1)
    orientation = numbers('LISSAJOUS_ORIENTATION', 3)
    if min(amps) <= 0:
        raise ValueError('Free Lissajous refinement needs positive nonzero starting amplitudes')
    if any(abs(x) > math.pi for x in phases):
        raise ValueError('Starting phase differences must be within [-pi,pi]')
    if math.hypot(*orientation) >= math.pi:
        raise ValueError('The starting rotation vector must have magnitude below pi')
    target=str(o['LISSAJOUS_TARGET']).strip()
    if target and not re.fullmatch(r'[A-Za-z0-9_+.*-]+', target):
        raise ValueError('Use a single atom label for the Lissajous target')
    return dict(model='lissajous', target_label=target, dimensions=dim, winding_ratio=ratio,
                amplitudes_A=amps, phases_rad=phases, orientation_rad=orientation,
                averaging='one_shared_uniform_phase', fixed_last_phase_rad=0,
                local_gaussian_U_required=True, shape_parameter_count=2*dim+2,
                absolute_frequencies_refined=False)


def require_production_route(options):
    import json
    config = configuration(options)
    if not config['target_label']:
        raise ValueError('Select a Lissajous target atom label')
    if json.loads(options.get('CURVED_ADDITIONAL_TARGETS', '[]')) != []:
        raise ValueError('Lissajous currently supports one target; clear additional angular targets explicitly')
    return config


def make_namelist(options):
    c = require_production_route(options)
    lines = ['&lissajous_adp', f" dimensions={c['dimensions']},",
             f" target_label='{c['target_label']}',",
             f" electronic_source='{options['CURVED_ELECTRONIC_SOURCE']}',",
             ' initial_covariance_is_local=.true.,']
    for name, values in [('winding_ratio', c['winding_ratio']),
                         ('amplitudes_angstrom', c['amplitudes_A']),
                         ('phases_rad', c['phases_rad']), ('orientation_rad', c['orientation_rad'])]:
        lines.append(f' {name}=' + ','.join(f'{v:.17g}' for v in values) + ',')
    lines += [f" max_cycles={int(options['CURVED_MAX_CYCLES'])}, time_limit_seconds={int(options['CURVED_TIME_LIMIT'])}", '/']
    return '\n'.join(lines) + '\n'
