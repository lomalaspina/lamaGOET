"""Separate positive-model configuration; never reinterpret shared-phase Lissajous."""
import json
import math
import re

MODELS = {'shared_u_mixture', 'independent_overtone'}
DEFAULTS = {
    'POSITIVE_TARGET': '', 'MIXTURE_POPULATION': '0.3',
    'MIXTURE_AUTO_DIRECTION': 'true', 'MIXTURE_INITIAL_SEPARATION': '0.1',
    'MIXTURE_SEPARATION': '0.1 0 0', 'OVERTONE_DIMENSIONS': '3',
    'OVERTONE_AMPLITUDES_2D': '0.03 0.02', 'OVERTONE_AMPLITUDES_3D': '0.03 0.02 0.015',
    'OVERTONE_COEFFICIENTS_2D': '0.01 0', 'OVERTONE_COEFFICIENTS_3D': '0.01 0 0',
    'OVERTONE_ENABLED_2D': 'true false', 'OVERTONE_ENABLED_3D': 'true false false',
    'OVERTONE_ORIENTATION': '0 0 0',
}

def configuration(options):
    o=DEFAULTS | options
    model=o.get('CURVED_MODEL')
    if model not in MODELS:raise ValueError('Choose shared-U mixture or independent-phase overtone')
    target=str(o['POSITIVE_TARGET']).strip()
    if target and not re.fullmatch(r'[A-Za-z0-9_+.*-]+',target):
        raise ValueError('Use a single positive-model target atom label')
    def numbers(key,n):
        try:vals=[float(x) for x in str(o[key]).replace(',',' ').split()]
        except ValueError as e:raise ValueError(key+' requires finite numeric values') from e
        if len(vals)!=n or not all(math.isfinite(v) for v in vals):
            raise ValueError(f'{key} requires {n} finite values')
        return vals
    c=dict(model=model,target_label=target,local_gaussian_U_required=True,absolute_frequencies_refined=False)
    if model=='shared_u_mixture':
        w=numbers('MIXTURE_POPULATION',1)[0]
        if not 0<w<1:raise ValueError('Starting population must be strictly between zero and one')
        auto=str(o['MIXTURE_AUTO_DIRECTION']).lower()
        if auto not in {'true','false'}:raise ValueError('Automatic starting direction must be true or false')
        length=numbers('MIXTURE_INITIAL_SEPARATION',1)[0]
        if length<=0:raise ValueError('Starting separation length must be positive')
        c.update(population=w,automatic_start_direction=auto=='true',initial_separation_A=length,
                 separation_A=numbers('MIXTURE_SEPARATION',3),shape_parameter_count=4)
    else:
        if str(o['OVERTONE_DIMENSIONS']) not in {'2','3'}:raise ValueError('Choose two or three independent axes')
        dim=int(o['OVERTONE_DIMENSIONS']);tag=f'{dim}D'
        mask=str(o['OVERTONE_ENABLED_'+tag]).lower().split()
        if len(mask)!=dim or any(x not in {'true','false'} for x in mask):raise ValueError('Choose one enable flag per overtone axis')
        mask=[x=='true' for x in mask]
        amps=numbers('OVERTONE_AMPLITUDES_'+tag,dim);overtones=numbers('OVERTONE_COEFFICIENTS_'+tag,dim)
        if any(x<0 for x in amps):raise ValueError('Fundamental amplitudes must be nonnegative')
        if any(d!=0 and not enabled for d,enabled in zip(overtones,mask)):
            raise ValueError('Disabled overtones must be explicitly zero; no coefficients are silently discarded')
        orientation=numbers('OVERTONE_ORIENTATION',3)
        if math.hypot(*orientation)>=math.pi:raise ValueError('Starting rotation vector must have magnitude below pi')
        c.update(dimensions=dim,amplitudes_A=amps,overtones_A=overtones,overtone_enabled=mask,
                 orientation_rad=orientation,averaging='independent_uniform_phases',
                 shape_parameter_count=dim+sum(mask)+3)
    return c

def require_production_route(options):
    c=configuration(options)
    if not c['target_label']:raise ValueError('Select a positive-model target atom label')
    if json.loads(options.get('CURVED_ADDITIONAL_TARGETS','[]'))!=[]:
        raise ValueError('Positive models currently support one target; clear additional angular targets explicitly')
    return c

def make_namelist(options):
    c=require_production_route(options)
    lines=['&positive_adp',f" model_kind='{'mixture' if c['model']=='shared_u_mixture' else 'independent_overtone'}',",
           f" target_label='{c['target_label']}',",f" electronic_source='{options['CURVED_ELECTRONIC_SOURCE']}',",
           ' initial_covariance_is_local=.true.,']
    if c['model']=='shared_u_mixture':
        lines += [f" mixture_population={c['population']:.17g},",
                  f" automatic_start_direction={'.true.' if c['automatic_start_direction'] else '.false.'},",
                  f" initial_separation_angstrom={c['initial_separation_A']:.17g},"]
        rows=[('separation_angstrom',c['separation_A'])]
    else:
        lines += [f" dimensions={c['dimensions']},",
                  ' overtone_enabled='+','.join('.true.' if x else '.false.' for x in c['overtone_enabled'])+',']
        rows=[('amplitudes_angstrom',c['amplitudes_A']),('overtones_angstrom',c['overtones_A']),('orientation_rad',c['orientation_rad'])]
    for name,values in rows:lines.append(f' {name}='+','.join(f'{x:.17g}' for x in values)+',')
    lines += [f" max_cycles={int(options['CURVED_MAX_CYCLES'])}, time_limit_seconds={int(options['CURVED_TIME_LIMIT'])}",'/']
    return '\n'.join(lines)+'\n'
