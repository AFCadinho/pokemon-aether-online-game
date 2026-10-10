#!/usr/bin/env python3
"""Triangulate a manually selected anatomical point from two recorded views.

Pixels are relative to one 420x360 capture, not the full contact sheet. Both
views must describe the same animation time. Writes an unapproved proposal.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path


def add(a, b):
    return [x+y for x, y in zip(a, b)]


def sub(a, b):
    return [x-y for x, y in zip(a, b)]


def mul(a, s):
    return [x*s for x in a]


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def cross(a, b):
    return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]


def ray(capture, pixel, width, height):
    transform = capture['camera']
    tangent = math.tan(math.radians(capture['fov'])/2)
    local = [(2*pixel[0]/width-1)*width/height*tangent,
             (1-2*pixel[1]/height)*tangent, -1]
    direction = [sum(transform[column*3+row]*local[column] for column in range(3)) for row in range(3)]
    return transform[9:12], direction


def triangulate(first, second):
    p, u = first
    q, v = second
    w = sub(p, q)
    a, b, c, d, e = dot(u,u), dot(u,v), dot(v,v), dot(u,w), dot(v,w)
    denominator = a*c-b*b
    if abs(denominator) < 1e-8:
        raise ValueError('Views are parallel')
    s, t = (b*e-c*d)/denominator, (a*e-b*d)/denominator
    if min(s,t) <= 0:
        raise ValueError('Selected point is behind a camera')
    left, right = add(p,mul(u,s)), add(q,mul(v,t))
    return mul(add(left,right),0.5), math.sqrt(dot(sub(left,right),sub(left,right)))


def bone_local(transform, point):
    x, y, z = transform[:3], transform[3:6], transform[6:9]
    determinant = dot(x,cross(y,z))
    if abs(determinant) < 1e-10:
        raise ValueError('Bone transform is singular')
    delta = sub(point,transform[9:12])
    return [dot(delta,cross(y,z))/determinant,
            dot(delta,cross(z,x))/determinant,
            dot(delta,cross(x,y))/determinant]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['capture','input','output']:
        parser.add_argument('--'+name, required=True, type=Path)
    parser.add_argument('--pixels', required=True, type=float, nargs=4)
    parser.add_argument('--action', default='idle')
    parser.add_argument('--fraction', default=0.45, type=float)
    parser.add_argument('--bone', required=True)
    parser.add_argument('--part', default='mouth')
    parser.add_argument('--max-residual', default=0.03, type=float)
    args = parser.parse_args()
    capture = json.loads(args.capture.read_text())
    report = json.loads(args.input.read_text())
    if (capture['identity'],capture['runtime_sha256']) != (report['identity'],report['runtime_sha256']):
        raise ValueError('Capture does not match the proposal model revision')
    views = [next(c for c in capture['captures'] if c['action']==args.action
                  and abs(c['fraction']-args.fraction)<1e-6 and c['column']==column) for column in [1,3]]
    point, residual = triangulate(*[ray(c,args.pixels[i*2:i*2+2],capture['width'],capture['height']) for i,c in enumerate(views)])
    if residual > args.max_residual:
        raise ValueError(f'Pixel rays disagree by {residual:.6f}; inspect the two views')
    definition = next(d for group in report['candidate_parts'][args.part] for d in group if d['bone']==args.bone)
    definition['offset'] = bone_local(views[0]['bones'][args.bone],point)
    report['review_status'] = 'unreviewed'
    report.setdefault('manual_measurements',[]).append({
        'bone':args.bone,'part':args.part,'action':args.action,'fraction':args.fraction,
        'pixels':args.pixels,'ray_residual':residual,
        'capture_sha256':hashlib.sha256(args.capture.read_bytes()).hexdigest(),
    })
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
    print(json.dumps({'bone':args.bone,'offset':definition['offset'],'ray_residual':residual}))


if __name__ == '__main__':
    main()
