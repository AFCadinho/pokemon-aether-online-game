"""Prepare reviewed source-family aliases and one complete Terastal attack proposal."""
import copy


def prepare(identity, decoded):
    result = copy.deepcopy(decoded)
    aliases = []
    for clip in result['clips']:
        name = clip['name'].split('|')[-1].removesuffix('.gfbanm')
        if not name.startswith(identity + '_'):
            if identity not in ('pm1120_12_00', 'pm1120_13_00', 'pm1120_14_00') or name != 'pm1120_11_00_00400_attack01':
                raise ValueError('Unexpected source action identity: ' + name)
            replacement = identity + '_00400_attack01'
            aliases.append({'source': clip['name'], 'proposal': replacement,
                            'policy': 'shared Ogerpon physical attack; transform data unchanged'})
            clip['name'] = replacement
    composite = None
    if identity == 'pm1130_12_00':
        suffixes = ('20460_rangeattack02_start', '20461_rangeattack02_loop', '20462_rangeattack02_end')
        parts = []
        for suffix in suffixes:
            matches = [c for c in result['clips'] if c['name'].split('|')[-1] == identity + '_' + suffix]
            if len(matches) != 1: raise ValueError('Missing/ambiguous native special-attack component')
            parts.append(matches[0])
        if len({c['fps'] for c in parts}) != 1: raise ValueError('Composite sample rates differ')
        frames, offset = [], 0.0
        for part in parts:
            if not part['frames'] or abs(part['frames'][0]['time']) > 1e-6 or abs(part['frames'][-1]['time']-part['duration']) > 1e-6:
                raise ValueError('Native component clock is incomplete')
            for frame in part['frames']:
                new = dict(frame, time=frame['time']+offset)
                # The incoming component owns a shared boundary; never duplicate key times.
                if frames and abs(new['time']-frames[-1]['time']) < 1e-6: frames[-1] = new
                else: frames.append(new)
            offset += part['duration']
        if any(a['time'] >= b['time'] for a,b in zip(frames,frames[1:])):
            raise ValueError('Composite clock is unordered')
        combined = dict(parts[0], name=identity+'_20450_rangeattack01', duration=offset, frames=frames)
        result['clips'].append(combined)
        composite = {'proposal': combined['name'], 'native_components': [p['name'] for p in parts],
                     'duration': offset, 'policy': 'native start + one loop + native end; authored sequencing'}
    return result, {'aliases': aliases, 'composite_special_attack': composite,
                    'runtime_approved': False}
