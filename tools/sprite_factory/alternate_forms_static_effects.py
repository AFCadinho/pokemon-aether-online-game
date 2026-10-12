"""Source layer colour in linear light for native static effect surfaces."""
from io import BytesIO
from pathlib import Path
from PIL import Image
from catalog_remaining_eye_bake import linear_to_srgb


def linear(value):
    v = value / 255
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4


def colour(material, directory):
    base = Image.open(directory/Path(material['textures']['BaseColorMap']).with_suffix('.png')).convert('RGBA')
    mask = Image.open(directory/Path(material['textures']['LayerMaskMap']).with_suffix('.png')).convert('RGBA')
    if base.size != mask.size:
        # Expand uniform inputs exactly. Keep nonuniform source texels intact;
        # differing detailed domains need their own shader, never a downsample.
        if all(lo == hi for lo,hi in base.getextrema()):
            base = Image.new('RGBA',mask.size,base.getpixel((0,0)))
        elif all(lo == hi for lo,hi in mask.getextrema()):
            mask = Image.new('RGBA',base.size,mask.getpixel((0,0)))
        else:
            raise ValueError('Nonuniform static effect domains require native shader sampling')
    output = []
    for rgba, channels in zip(base.getdata(), mask.getdata()):
        original = [linear(v) for v in rgba[:3]]
        result = original.copy()
        for index, channel in enumerate(channels, 1):
            tint = material['colors'][f'BaseColorLayer{index}']
            strength = min(1.0, channel/255*2*material['floats'][f'LayerMaskScale{index}'])
            result = [a*(1-strength)+b*t*strength for a,b,t in zip(result,original,tint)]
        output.append(tuple(linear_to_srgb(v) for v in result)+(rgba[3],))
    image = Image.new('RGBA', base.size); image.putdata(output)
    encoded = BytesIO(); image.save(encoded, format='PNG')
    return encoded.getvalue()
