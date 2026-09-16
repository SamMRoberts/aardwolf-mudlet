"""Reproduce the three original, short PCM chat tones using the standard library."""
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'src' / 'resources'
NOTES = {
    'bell': [(880, .16), (1320, .12)],
    'chime': [(660, .12), (880, .12), (1100, .18)],
    'pop': [(420, .08)],
}


def main():
    for name, notes in NOTES.items():
        samples = []
        for hz, seconds in notes:
            count = int(seconds * 22050)
            for i in range(count):
                envelope = min(1, i / 180) * math.exp(-5 * i / count) * (1 - i / count)
                samples.append(int(6500 * envelope * math.sin(2 * math.pi * hz * i / 22050)))
            samples.extend([0] * 660)
        with wave.open(str(ROOT / f'chat-{name}.wav'), 'wb') as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(22050)
            output.writeframes(struct.pack('<' + 'h' * len(samples), *samples))


if __name__ == '__main__':
    main()
