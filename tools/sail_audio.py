"""Sample ships' sounds (design/…/93_样板船_SA-200, 94_样板船_OB-90, 95_样板船_GR-7; user 2026-10-28: real recordings only, no
synthesis — the local Sonniss library). Each sound is one recording, cut, levelled, faded; the
motor is crossfaded into a seamless loop. Writes assets/audio/<name>.ogg.
Usage: G:/audio_library/venv/Scripts/python.exe tools/sail_audio.py
"""
import os
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

# name: (recording, start s, length s, loop, peak)
SOUNDS = {
    'furl_loop': ('Sonniss.com - GDC 2019 - Game Audio Bundle Part 1of8/3maze - Electric Motors/motor_long_006.wav', 0.6, 3.2, True, 0.7),
    'sail_flap': ('Gladestock Studios - Naval Warfare/GS sail impact 004.wav', 0.0, 0.9, False, 0.85),
    'film_tear': ('Sonniss.com - GDC 2017 - Game Audio Bundle Part 3of9/Double Trouble Audio - Punchy Cardboard/Cardboard Tearing 01 Continious.wav', 0.2, 1.4, False, 0.9),
    'static_arc': ('BluezoneCorp - High Voltage/Bluezone_BC0299_electricity_surge_discharge_electrical_arc_crackling_002_01.wav', 0.0, 0.8, False, 0.8),
    'roll_lock': ('Bottle Rocket Fx - Cyborg Collection/Spacecraft_Bay Door_Lock Down_Large_01.wav', 0.0, 1.8, False, 0.9),
    'winch_brake': ('Pole Position - Polaris Ranger Electric UTV 2017/Polaris, Ranger, t9, Var SFX, Parking Brake, Onboard, Left, CMC6.wav', 0.0, 1.2, False, 0.85),
    # 94 号 OB-90: a segment cracking, a ring's actuators latching
    'mirror_crack': ('BluezoneCorp - Broken Glass/Bluezone_BC0274_glass_impact_break_small_014.wav', 0.0, 0.59, False, 0.85),
    'mirror_lock': ('Epic Stock Media - HD Lock And Mechanism Sound Design Kit/MECHLtch_Click Deep Mechanism Latch Button Nearfield Thunk 02_ESM_HDLM.wav', 0.0, 0.2, False, 0.9),
    # 95 号 GR-7: a big section of hull coming away (the demolition's weight)
    # 98 号 LC-140: the winch taking up and the small ship rolling out along its cradle
    'tow_start': ('Bombay Sonic - Heidelberg Printing Press/Printing Press,Slow, Machine, Start.wav', 0.0, 3.0, False, 0.85),
    'tow_roll': ('Matt Script - Electric Lawn Mower/Electric_Mower_moving_over_concrete_dragging_scrape_scraping_rolling_metal_plastic_02.wav', 0.8, 4.0, True, 0.7),
    'hull_break': ('Sonniss.com - GDC 2019 - Game Audio Bundle Part 1of8/BlueZone - Heavy Metal Impact Sound Effects/Bluezone_BC0251_heavy_metal_impact_large_tank_01_03.wav', 0.0, 2.2, False, 0.95),
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
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return x * e[:, None]


def loopify(x, xf=0.5):
    n = int(SR * xf)
    k = np.linspace(0, 1, n)[:, None]
    seam = x[-n:] * (1 - k) + x[:n] * k
    return np.concatenate([x[n:-n], seam])


for name, (rel, start, dur, loop, peak) in SOUNDS.items():
    x = load(rel, start, dur)
    x = x - x.mean(axis=0)
    x = loopify(x) if loop else fade(x)
    m = np.max(np.abs(x))
    if m > 0:
        x = x * (peak / m)
    f = WORK / (name + '.wav')
    sf.write(str(f), (np.clip(x, -1, 1) * 32767).astype('<i2'), SR, subtype='PCM_16')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(f), '-c:a', 'libvorbis', '-q:a', '6', str(OUT / (name + '.ogg'))], check=True)
    print('wrote', name, '%.2fs' % (len(x) / SR), 'from', os.path.basename(rel))
