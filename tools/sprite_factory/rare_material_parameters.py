"""Pinned importer colour sockets; omissions remain explicit review limitations."""
COLOR_SOCKETS = {**{'BaseColorLayer' + str(i): 'BaseColorLayer' + str(i) for i in range(1, 5)},
                 **{'EmissionColorLayer' + str(i): 'EmissionColorLayer' + str(i) for i in range(1, 5)},
                 'BaseColorLayer5': 'Mask_color', 'BaseColorLayer8': 'LowEye_color'}
# PokemonSwitch.py reads or omits these fields without feeding shader inputs.
UNREPRESENTED_COLORS = {'EmissionColorLayer5', 'BaseColorLayer6', 'BaseColorLayer7', 'BaseColorLayer9',
                        'SubsurfaceColor', 'BaseColorClearCoat', 'IridescenceColor1',
                        'IridescenceColor2', 'IridescenceColor3', 'EmissionColor'}

# Layered roughness/metallicity are not connected by the pinned importer.
# Keep their differences visible in the review receipt; never call this parity.
UNREPRESENTED_FLOATS = {'EmissionIntensityLayer5', 'NormalHeight1',
                        'RoughnessHighlight', 'MetallicHighlight', 'RoughnessClearCoat',
                        *('RoughnessLayer' + str(i) for i in range(1, 6)),
                        *('MetallicLayer' + str(i) for i in range(1, 6))}
FLOAT_SOCKETS = {'EmissionIntensity': 'EmissionStrength', 'Roughness': 'Roughness',
                 **{'LayerMaskScale' + str(i): 'LayerMaskScale' + str(i) for i in range(1, 5)},
                 **{'EmissionIntensityLayer' + str(i): 'EmissionIntensityLayer' + str(i)
                    for i in range(1, 5)}}


def color_socket(key, material):
    """Match the pinned importer's eye-only Layer8 assignment."""
    if key == 'BaseColorLayer8' and 'eye' not in material:
        return None
    return COLOR_SOCKETS.get(key)


def unrepresented_eye_normal(material, channel):
    """The pinned PokemonSwitch importer never binds Eye NormalMap1."""
    shaders = material.get('shaders', [])
    return (channel == 'NormalMap1' and bool(shaders)
            and any(s['name'] == 'EyeClearCoat' for s in shaders)
            and all(s['name'] in ('Eye', 'EyeClearCoat') for s in shaders))
