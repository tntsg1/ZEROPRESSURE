"""98 号 the trade port's own sounds (real recordings only, the local Sonniss library): the receipt
printer at a counter, a capsule shot up the pneumatic tube, the weighbridge's beep. The rest are
recordings the game has (stamp, hiss, door, crane_loop). Writes assets/audio/<name>.ogg.
Usage: G:/audio_library/venv/Scripts/python.exe tools/trade_audio.py
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

# name: (recording, start s, length s, peak)
SOUNDS = {
    'receipt': ('Sonniss.com - GDC 2017 - Game Audio Bundle Part 8of9/The Soundcatcher - Electric Cash Register/Cash Register_SANYO ECR 335_Bon_Print_2_2.wav', 0.0, 1.3, 0.8),
    'tube': ('Sonniss.com - GDC 2018 - Game Audio Bundle Part 1of8/Airborne Sound - Variety 1 Sound Effects/Steam Blast,Tube or Pipe,Distant.wav', 0.0, 0.8, 0.75),
    'scale_beep': ('InMotionAudio - Medical Thermometer/BEEPMed_Thermometer_Beep11_InMotionAudio_MedicalThermometer.wav', 0.0, 0.5, 0.6),
}


def load(rel, start, dur):
    path = POOL / rel
    info = sf.info(str(path))
    a = int(start * info.samplerate)
    b = int((start + dur) * info.samplerate)
    data, sr = sf.read(str(path), start=a, stop=min(b, info.frames), always_2d=True, dtype='float32')
    x = data.astype(np.float64)
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    x = x[:, :2]
    ratio = Fraction(SR, int(sr)).limit_denominator(400)
    if ratio != 1:
        x = np.stack([resample_poly(x[:, c], ratio.numerator, ratio.denominator) for c in range(2)], axis=1)
    return x


def fade(x, a=0.004, r=0.08):
    n = len(x)
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(min(r, len(x) / SR / 3) * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return x * e[:, None]


for name, (rel, start, dur, peak) in SOUNDS.items():
    x = load(rel, start, dur)
    x = fade(x - x.mean(axis=0))
    m = np.max(np.abs(x))
    if m > 0:
        x = x * (peak / m)
    f = WORK / (name + '.wav')
    sf.write(str(f), (np.clip(x, -1, 1) * 32767).astype('<i2'), SR, subtype='PCM_16')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(f), '-c:a', 'libvorbis', '-q:a', '6', str(OUT / (name + '.ogg'))], check=True)
    print('wrote', name, '%.2fs' % (len(x) / SR))
