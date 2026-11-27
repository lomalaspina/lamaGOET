"""Positive independent-axis overtone PDF; separate from shared-phase Lissajous.

The JSON contains a mathematical distribution, not a list of frequencies.
Product quadrature is generated deterministically and must pass a separate
N/2N density check before a probability surface can be displayed.
"""
from __future__ import annotations

import numpy as np


def overtone_nodes(data, rotations, *, doubled=False):
    dim=data.get('dimensions');mask=data.get('overtone_enabled');n=data.get('phase_order')
    if data.get('model')!='independent_axis_overtone' or type(dim) is not int or dim not in (2,3):
        raise ValueError('Invalid independent-overtone model/dimensions')
    if (not isinstance(mask,list) or len(mask)!=dim or any(type(v) is not bool for v in mask)):
        raise ValueError('Invalid per-axis overtone mask')
    if type(n) is not int or n not in (16,32,64):
        raise ValueError('Overtone display phase order must be 16, 32 or 64')
    if data.get('averaging')!='independent_uniform_axis_phases' or data.get('absolute_frequencies_refined') is not False:
        raise ValueError('Overtone axes require independent phases and no refined frequency')
    if any(k in data for k in ('winding_ratio','phases_rad','pivot_label','node_weight','component_weights')):
        raise ValueError('Independent-overtone artifact contains incompatible model fields')
    a=np.asarray(data.get('amplitudes_A'),dtype=float)
    d=np.asarray(data.get('overtones_A'),dtype=float)
    w=np.asarray(data.get('orientation_rad'),dtype=float)
    p=np.asarray(data.get('shape_parameters'),dtype=float)
    if (a.shape!=(dim,) or d.shape!=(dim,) or w.shape!=(3,)
            or not all(np.isfinite(v).all() for v in (a,d,w,p)) or np.any(a<0)
            or np.linalg.norm(w)>=np.pi or np.any(d[~np.asarray(mask)]!=0)):
        raise ValueError('Invalid overtone amplitudes, disabled terms or orientation')
    expected=np.r_[a,d[np.asarray(mask)],w]
    if p.shape!=expected.shape or not np.array_equal(p,expected):
        raise ValueError('Inconsistent overtone shape vector')
    if data.get('shape_parameter_units')!=['angstrom']*(dim+sum(mask))+['radian']*3:
        raise ValueError('Invalid overtone parameter units')
    if not any(np.allclose(r,np.eye(3),atol=1e-10,rtol=0) for r in rotations):
        raise ValueError('Site group has no identity')
    for i,r in enumerate(rotations):
        if any(np.allclose(r,s,atol=1e-10,rtol=0) for s in rotations[:i]):
            raise ValueError('Duplicate site operation')
        if not np.allclose(r@r.T,np.eye(3),atol=1e-10,rtol=0):
            raise ValueError('Nonorthogonal site operation')
        for s in rotations:
            if not any(np.allclose(r@s,t,atol=1e-9,rtol=0) for t in rotations):
                raise ValueError('Incomplete site group')
    if doubled:n*=2
    if n**dim*len(rotations) > (1048576 if doubled else 131072):
        raise ValueError('Overtone display quadrature exceeds the memory limit')
    angle=np.linalg.norm(w)
    skew=np.array([[0,-w[2],w[1]],[w[2],0,-w[0]],[-w[1],w[0],0]])
    if angle<1e-4:
        c1=1-angle**2/6+angle**4/120
        c2=.5-angle**2/24+angle**4/720
    else:c1=np.sin(angle)/angle;c2=(1-np.cos(angle))/angle**2
    rotation=np.eye(3)+c1*skew+c2*skew@skew
    tau=2*np.pi*np.arange(n)/n
    axes=[a[j]*np.cos(tau)+d[j]*np.cos(2*tau) for j in range(dim)]
    seed=np.zeros((n**dim,3))
    seed[:,:dim]=np.stack(np.meshgrid(*axes,indexing='ij'),axis=-1).reshape(-1,dim)
    seed=seed@rotation.T
    nodes=np.concatenate([seed@r.T for r in rotations])
    if not doubled and 'displacement_nodes' in data:
        supplied=np.asarray(data['displacement_nodes'],dtype=float)
        if supplied.shape!=nodes.shape or not np.allclose(supplied,nodes,atol=2e-12,rtol=1e-12):
            raise ValueError('Supplied overtone nodes disagree with its independent product measure')
    target=[a for a in data.get('atoms',[]) if a.get('label')==data.get('target_label')]
    if len(target)!=1:raise ValueError('Missing or ambiguous overtone target identity')
    for key,shape in [('mean_cartesian',(3,)),('total_covariance',(3,3))]:
        value=np.asarray(target[0].get(key),dtype=float);model=np.asarray(data.get(key),dtype=float)
        if value.shape!=shape or model.shape!=shape or not np.allclose(value,model,atol=2e-12,rtol=1e-12):
            raise ValueError('Overtone target/model geometry or covariance disagree')
    return nodes


def check_overtone_density(model, points, level):
    """N/2N PDF check at deterministic contour probes, not renormalization."""
    nodes=overtone_nodes(model.data,model.rotations,doubled=True)
    points=np.asarray(points,dtype=float)
    reference=np.zeros(len(points))
    xx=np.sum((points@model.inverse)*points,axis=1)
    for start in range(0,len(nodes),256):
        block=nodes[start:start+256];ni=block@model.inverse;nn=np.sum(ni*block,axis=1)
        squared=xx[:,None]+nn[None,:]-2*np.einsum('ij,kj->ik',points,ni,optimize=False)
        reference+=np.exp(-.5*squared).sum(axis=1)
    reference*=model.norm/len(nodes)
    error=float(np.max(abs(reference-model.density(points)))/level)
    if not np.isfinite(error) or error>=1e-4:
        raise ValueError('Overtone phase quadrature did not converge; increase display phase order')
    return error
