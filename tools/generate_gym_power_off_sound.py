"""Generate the original electric-barrier shutdown effect (requires ffmpeg)."""

import math
from pathlib import Path
import random
import struct
import subprocess
import tempfile
import wave


def main() -> None:
    sample_rate = 22050
    duration = 0.65
    rng = random.Random(178)
    frames = bytearray()
    for index in range(round(sample_rate * duration)):
        time = index / sample_rate
        # A falling electrical buzz, fading arcing noise and a relay click.
        phase = math.tau * (1450 * (1 - math.exp(-6.8 * time)) / 6.8 + 70 * time)
        buzz = (math.sin(phase) + 0.35 * math.sin(3 * phase) + 0.12 * math.sin(5 * phase)) / 1.47
        noise = rng.uniform(-1, 1)
        envelope = min(time / 0.008, 1) * (1 - time / duration) ** 2
        crackle = noise * (0.12 + 0.12 * max(0, math.sin(math.tau * 43 * time)))
        relay = noise * 0.35 * math.exp(-time * 260)
        sample = 0.55 * (envelope * (0.75 * buzz + crackle) + relay)
        frames.extend(struct.pack("<h", round(sample * 32767)))

    output = Path(__file__).resolve().parents[1] / "assets/audio/sfx/overworld/gym_electric_power_off.ogg"
    with tempfile.TemporaryDirectory(prefix="gym-power-off-") as directory:
        source = Path(directory) / "power_off.wav"
        with wave.open(str(source), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(sample_rate)
            audio.writeframes(frames)
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
             "-c:a", "libvorbis", "-q:a", "5", str(output)],
            check=True,
        )
    print(f"Generated {output.name}: {duration:.2f}s, {output.stat().st_size} bytes")


if __name__ == "__main__":
    main()
