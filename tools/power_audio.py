"""100 号 the power district's own sounds (real recordings only, the local Sonniss library): a
feeder breaker closing in its cubicle, and the turbine hall's running sound — a machine-room hum
under an electric motor's whine taken down an octave, crossfaded into a seamless loop. The rest
are recordings the game has (clank, clamp, clamp_off, winch_brake, scale_beep, pump_loop,
crane_loop). Writes assets/audio/breaker.ogg and turbine_loop.ogg.
Usage: G:/audio_library/venv/Scripts/python.exe tools/power_audio.py
"""
import subprocess
from fractions import Fraction
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'audio'
WORK = Path('G:/audio_library/work/zeropower')
POOL = Path('G:/audio_library/sonniss/files')
SR = 44100
WORK.mkdir(parents=True, exist_ok=True)
BREAKER = 'Sonniss.com - GDC 2018 - Game Audio Bundle Part 6of8/UberDuo - The Cabin Audio Playset/Switch,ElectricalPanelBreaker,On.wav'
HUM = 'Sonniss.com - GDC 2017 - Game Audio Bundle Part 7of9/RedSonic - Hums Light Machines/electric_hum_buzz_01.wav'
MOTOR = 'Sonniss.com - GDC 2019 - Game Audio Bundle Part 1of8/3maze - Electric Motors/motor_long_006.wav'


def load(rel, start, dur, rate=1.0):
    path = POOL / rel
    info = sf.info(str(path))
    data, sr = sf.read(str(path), start=int(start * info.samplerate), stop=min(info.frames, int((start + dur) * info.samplerate)), always_2d=True, dtype='float32')
    x = data.astype(np.float64)
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    x = x[:, :2]
    # rate < 1: played slower, lower (a bigger machine)
    ratio = Fraction(SR, int(sr * rate)).limit_denominator(400)
    if ratio != 1:
        x = np.stack([resample_poly(x[:, c], ratio.numerator, ratio.denominator) for c in range(2)], axis=1)
    return x - x.mean(axis=0)


def write(name, x, peak):
    x = x * (peak / np.max(np.abs(x)))
    f = WORK / (name + '.wav')
    sf.write(str(f), (np.clip(x, -1, 1) * 32767).astype('<i2'), SR, subtype='PCM_16')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(f), '-c:a', 'libvorbis', '-q:a', '6', str(OUT / (name + '.ogg'))], check=True)
    print('wrote', name, '%.2fs' % (len(x) / SR))


# the breaker: from just before its clack, 0.6 s, a quick tail
b = load(BREAKER, 0.0, 2.0)
env = np.abs(b).max(axis=1)
on = max(0, int(np.argmax(env > env.max() * 0.25)) - int(0.01 * SR))
b = b[on:on + int(0.6 * SR)]
tail = int(0.15 * SR)
b[-tail:] *= np.linspace(1, 0, tail)[:, None]
b[:40] *= np.linspace(0, 1, 40)[:, None]
write('breaker', b, 0.85)

# the turbine hall: the hum, and the motor an octave down under it
hum = load(HUM, 1.0, 7.0)
mot = load(MOTOR, 1.0, 3.4, 0.5)
n = min(len(hum), len(mot))
x = hum[:n] * 0.55 + mot[:n] * (0.45 * np.max(np.abs(hum[:n])) / np.max(np.abs(mot[:n])))
k = int(SR * 0.6)
r = np.linspace(0, 1, k)[:, None]
x = np.concatenate([x[k:-k], x[-k:] * (1 - r) + x[:k] * r])
write('turbine_loop', x, 0.6)
