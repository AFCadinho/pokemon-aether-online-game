#!/usr/bin/env python3
"""Fit weighted bone offsets to manually marked pixels across native poses.

Observations are dictionaries with capture (JSON path), action, column, pixel
([x,y] relative to the capture cell). Every capture must match the proposal.
The existing offsets provide a weak prior for underdetermined bone rotations.
Output remains an unapproved proposal and must be rendered and reviewed.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

from calibrate_attack_attachment import dot, ray


def solve(matrix, vector):
    """Solve a small positive definite regularized system with pivoting."""
    rows = [list(row) + [value] for row, value in zip(matrix, vector)]
    size = len(rows)
    for column in range(size):
        pivot = max(range(column, size), key=lambda index: abs(rows[index][column]))
        rows[column], rows[pivot] = rows[pivot], rows[column]
        scale = rows[column][column]
        if abs(scale) < 1e-15:
            raise ValueError('Singular fitting system')
        rows[column] = [value / scale for value in rows[column]]
        for index in range(size):
            if index == column:
                continue
            factor = rows[index][column]
            rows[index] = [a-factor*b for a, b in zip(rows[index], rows[column])]
    return [row[-1] for row in rows]


def fit(group, observations, regularization=1e-5):
    if not group or not observations or regularization <= 0:
        raise ValueError('Need bones, observations, and positive regularization')
    total = sum(float(definition.get('weight', 1)) for definition in group)
    if total <= 0:
        raise ValueError('Invalid bone weights')
    prior = [value for definition in group for value in definition['offset']]
    coefficients, targets = [], []
    for capture, pixel, width, height in observations:
        origin, direction = ray(capture, pixel, width, height)
        norm = math.sqrt(dot(direction, direction))
        unit = [value/norm for value in direction]
        projection = [[float(i == j)-unit[i]*unit[j] for j in range(3)] for i in range(3)]
        basis = [[] for _ in range(3)]
        translation = [0.0]*3
        for definition in group:
            transform = capture['bones'][definition['bone']]
            weight = float(definition.get('weight', 1))/total
            for axis in range(3):
                translation[axis] += weight*transform[9+axis]
                basis[axis].extend(weight*transform[column*3+axis] for column in range(3))
        for row in projection:
            coefficients.append([sum(row[axis]*basis[axis][column] for axis in range(3))
                                 for column in range(len(prior))])
            targets.append(sum(row[axis]*(origin[axis]-translation[axis]) for axis in range(3)))
    normal = [[sum(row[i]*row[j] for row in coefficients) for j in range(len(prior))]
              for i in range(len(prior))]
    rhs = [sum(row[i]*target for row, target in zip(coefficients, targets)) for i in range(len(prior))]
    ridge = max(sum(normal[i][i] for i in range(len(prior)))/len(prior), 1e-10)*regularization
    for i in range(len(prior)):
        normal[i][i] += ridge
        rhs[i] += ridge*prior[i]
    solution = solve(normal, rhs)
    residuals = []
    for start in range(0, len(targets), 3):
        residuals.append(math.sqrt(sum((dot(row, solution)-target)**2
                         for row, target in zip(coefficients[start:start+3], targets[start:start+3]))))
    if not all(math.isfinite(value) for value in solution+residuals):
        raise ValueError('Non-finite fit')
    return solution, residuals


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['input', 'observations', 'output']:
        parser.add_argument('--'+name, required=True, type=Path)
    parser.add_argument('--part', default='mouth')
    parser.add_argument('--emitter', type=int, default=0)
    parser.add_argument('--max-residual', type=float, default=0.03)
    args = parser.parse_args()
    proposal = json.loads(args.input.read_text())
    raw = json.loads(args.observations.read_text())
    observations, provenance = [], []
    for record in raw:
        path = Path(record['capture'])
        sheet = json.loads(path.read_text())
        if (sheet['identity'], sheet['runtime_sha256']) != (proposal['identity'], proposal['runtime_sha256']):
            raise ValueError('Observation model revision differs')
        capture = next(c for c in sheet['captures'] if c['action'] == record['action'] and c['column'] == record['column'])
        pixel = record['pixel']
        if len(pixel) != 2 or not all(math.isfinite(value) for value in pixel):
            raise ValueError('Invalid pixel coordinates')
        observations.append((capture, pixel, sheet['width'], sheet['height']))
        provenance.append({**record, 'capture_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                           'fraction': capture['fraction']})
    group = proposal['candidate_parts'][args.part][args.emitter]
    solution, residuals = fit(group, observations)
    if max(residuals) > args.max_residual:
        raise ValueError(f'Inconsistent observations: residuals {residuals}')
    for index, definition in enumerate(group):
        definition['offset'] = solution[index*3:index*3+3]
    proposal['review_status'] = 'unreviewed'
    proposal.setdefault('manual_pose_fits', []).append({'part': args.part, 'emitter': args.emitter,
        'observations': provenance, 'ray_residuals': residuals, 'regularization': 1e-5})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(proposal, indent=2, sort_keys=True)+'\n')
    print(json.dumps({'ray_residuals': residuals, 'offsets': [d['offset'] for d in group]}))


if __name__ == '__main__':
    main()
