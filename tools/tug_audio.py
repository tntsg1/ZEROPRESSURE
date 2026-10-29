"""96 号 the tug station's own sound (user 2026-10-28: real recordings only, no synthesis — the local
Sonniss library): the gantry's travel and hoist motor, one recording crossfaded into a seamless loop.
The rest of the station's sounds are recordings the game already has (clamp, hatch, hose_on,
winch_brake, roll_lock, pump_loop). Writes assets/audio/crane_loop.ogg.
Usage: G:/audio_library/venv/Scripts/python.exe tools/tug_audio.py
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
REC = 'Sonniss.com - GDC 2019 - Game Audio Bundle Part 1of8/3maze - Electric Motors/motor_med_011.wav'

info = sf.info(str(POOL / REC))
data, sr = sf.read(str(POOL / REC), start=int(0.5 * info.samplerate), stop=int(3.7 * info.samplerate), always_2d=True, dtype='float32')
x = data.astype(np.float64)
if x.shape[1] == 1:
    x = np.repeat(x, 2, axis=1)
x = x[:, :2]
ratio = Fraction(SR, int(sr)).limit_denominator(400)
if ratio != 1:
    x = np.stack([resample_poly(x[:, c], ratio.numerator, ratio.denominator) for c in range(2)], axis=1)
x = x - x.mean(axis=0)
n = int(SR * 0.5)
k = np.linspace(0, 1, n)[:, None]
x = np.concatenate([x[n:-n], x[-n:] * (1 - k) + x[:n] * k])
x = x * (0.65 / np.max(np.abs(x)))
f = WORK / 'crane_loop.wav'
sf.write(str(f), (np.clip(x, -1, 1) * 32767).astype('<i2'), SR, subtype='PCM_16')
subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(f), '-c:a', 'libvorbis', '-q:a', '6', str(OUT / 'crane_loop.ogg')], check=True)
print('wrote crane_loop %.2fs from motor_med_011.wav' % (len(x) / SR))
