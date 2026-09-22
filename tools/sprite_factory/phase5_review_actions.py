"""Conservative source-review mappings, not runtime animation certification."""
import re


PATTERNS = {
    'idle': r'_(?:battlewait01_loop|ba10_waitA01)\.',
    'physical_attack': r'_(?:attack01|ba20_buturi01)\.',
    'special_attack': r'_(?:rangeattack01|ba21_tokusyu01)\.',
    'damage': r'_(?:damage01|ba30_damageS01)\.',
    'sleep': r'_(?:sleep01_loop|kw20_drowseB01)\.',
    'faint_start': r'_(?:down01_start|ba41_down01)\.',
    'faint_loop': r'_down01_loop\.',
}


def candidates(names, bank=None):
    # Token boundaries prevent attack01 matching rangeattack01 and down matching
    # jumpdown. Deliberately prefer the primary clip/loop, never choose by order.
    if bank is not None:
        if type(bank) is not int or not 0 <= bank <= 9:
            raise ValueError('Animation bank must be an integer from 0 to 9')
        # Five-digit clips contain a bank digit followed by the four-digit
        # action code. Select one coherent bank; never fill gaps from another.
        # Legacy ba/fi/kw names have no numeric bank and remain untouched.
        names = [name for name in names if not (match := re.search(
            r'^pm\d{4}_\d{2}_\d{2}_(\d)\d{4}_', name, re.I))
            or int(match[1]) == bank]
    result = {category: [name for name in names if re.search(pattern, name, re.I)]
              for category, pattern in PATTERNS.items()}
    # Reviewed older naming family: A enters rest, B is the breathing loop,
    # C exits. Don't infer a loop from a lone arbitrary 'drowse' clip.
    lower = {n.lower() for n in names}
    result['sleep'] = [n for n in result['sleep'] if 'kw20_drowseb01.' not in n.lower() or
        all(re.sub(r'\.\d{3}$', '', n.lower()).replace('drowseb01.', 'drowse'+phase+'01.') in lower for phase in ('a','c'))]
    return result
