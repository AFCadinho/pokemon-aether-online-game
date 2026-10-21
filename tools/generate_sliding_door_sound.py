"""Original short glass-door servo/air sound; no sampled third-party audio."""
import math
from pathlib import Path
import random
import struct
import subprocess
import tempfile
import wave


def main():
    rate, duration = 22050, 0.20
    rng = random.Random(2106)
    data = bytearray()
    low = 0.0
    for i in range(round(rate * duration)):
        t = i / rate
        low += 0.22 * (rng.uniform(-1, 1) - low)
        envelope = math.sin(math.pi * t / duration) ** 1.2
        # Soft filtered friction, a quiet falling servo and a padded latch.
        phase = math.tau * (510 * t - 360 * t * t)
        servo = math.sin(phase) + 0.18 * math.sin(2 * phase)
        latch = math.sin(math.tau * 185 * t) * math.exp(-t * 160)
        fade_in = min(1, t / 0.004)
        sample = fade_in * (envelope * (0.38 * low + 0.045 * servo) + 0.055 * latch)
        data.extend(struct.pack('<h', round(sample * 32767)))
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
