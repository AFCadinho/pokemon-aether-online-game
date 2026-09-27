"""Pinned importer colour sockets; omissions remain explicit review limitations."""
COLOR_SOCKETS = {**{'BaseColorLayer' + str(i): 'BaseColorLayer' + str(i) for i in range(1, 5)},
                 **{'EmissionColorLayer' + str(i): 'EmissionColorLayer' + str(i) for i in range(1, 5)},
                 'BaseColorLayer5': 'Mask_color'}
# PokemonSwitch.py reads or omits these fields without feeding shader inputs.
UNREPRESENTED_COLORS = {'EmissionColorLayer5', 'BaseColorLayer6', 'SubsurfaceColor'}
