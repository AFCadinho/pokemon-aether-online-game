"""Render a Game Boy-style entrance sound from noise-channel parameters.

Reference: pret/pokered audio/sfx/go_inside_1.asm (SFX_Go_Inside_1_Ch8).
https://github.com/pret/pokered/blob/master/audio/sfx/go_inside_1.asm
Two noise notes: (9, 15, 1, 0x44), (8, 13, 1, 0x43).
This is a synthesized reconstruction, not a recording from the game.
"""
import math
from pathlib import Path
import struct
import subprocess
import tempfile
import wave


def main():
    rate = 22050
    frame_rate = 59.7275
    data = bytearray()
    for length, volume, register in [(9, 15, 0x44), (8, 13, 0x43)]:
        duration = (length + 1) / frame_rate
        frequency = 262144 / ((register & 7) * 2 ** (register >> 4))
        lfsr, phase = 0x7FFF, 0.0
        for i in range(round(rate * duration)):
            t = i / rate
            phase += frequency / rate
            while phase >= 1:
                feedback = (lfsr ^ (lfsr >> 1)) & 1
                lfsr = (lfsr >> 1) | (feedback << 14)
                phase -= 1
            envelope = max(0, volume - int(t * 64)) / 15
            # Tiny edge ramps avoid a digital click without smoothing away
            # the characteristic stepped noise or adding a servo whistle.
            ramp = min(1, t / 0.002, (duration - t) / 0.003)
            sample = (1 if lfsr & 1 == 0 else -1) * envelope * ramp * 0.20
            data.extend(struct.pack('<h', round(sample * 32767)))
    duration = len(data) / 2 / rate
    output = Path(__file__).resolve().parents[1] / 'assets/audio/sfx/overworld/sliding_door.ogg'
    with tempfile.TemporaryDirectory(prefix='sliding-door-') as tmp:
        source = Path(tmp) / 'door.wav'
        with wave.open(str(source), 'wb') as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(rate)
            audio.writeframes(data)
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(source),
                        '-c:a', 'libvorbis', '-q:a', '5', str(output)], check=True)
    print(f'{output.name}: {duration}s, {output.stat().st_size} bytes')


if __name__ == '__main__':
    main()
