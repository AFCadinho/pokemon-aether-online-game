"""Conservative source-review mappings, not runtime animation certification."""
import re


PATTERNS = {
    'idle': r'_(?:battlewait01_loop|ba10_waitA01)\.',
    'physical_attack': r'_(?:attack01|ba20_buturi01)\.',
    'special_attack': r'_(?:rangeattack01|ba21_tokusyu01)\.',
    'damage': r'_(?:damage01|ba30_damageS01)\.',
    'sleep': r'_sleep01_loop\.',
    'faint_start': r'_(?:down01_start|ba41_down01)\.',
    'faint_loop': r'_down01_loop\.',
}


def candidates(names):
    # Token boundaries prevent attack01 matching rangeattack01 and down matching
    # jumpdown. Deliberately prefer the primary clip/loop, never choose by order.
    return {category: [name for name in names if re.search(pattern, name, re.I)]
            for category, pattern in PATTERNS.items()}
