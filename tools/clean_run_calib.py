"""认真拆有奖励 calibration (design/认真拆有奖励_设计稿_20261111.md §5, stage 6).

Income by play style, worked out from the ship files with the rules and constants in
scripts/clean_run.gd, scripts/mishap.gd and scripts/hidden_traits.gd (equipment only: the structure's
scrap is the same whichever way the machines are handled, so it is left out of both sides):
  old_lazy    before this change: harmless leftovers refused at the equipment mouth, 40 % at the hazard mouth
  lazy_hand   by hand, nothing done first: each harmless leftover a mishap (3-6 % off, breaks the streak)
  lazy_J      the machines do it all: harmless leftovers emptied on the drain rack (no streak either way)
  careful     everything clean: streak on every machine, leftovers recovered (gas, liquid, battery), S/A/B,
              the meter's finds (expected value)
The streak depends on the order the machines go in: the mean over random orders (400 shuffles).
  python tools/clean_run_calib.py [ship ...]
"""
import json
import random
import sys

STEP, CAP_N = 0.005, 10
LOSS = {"batt": 0.04, "cap": 0.05, "gas": 0.06, "liq": 0.03}
BENIGN_LIQ = ["water", "coolant", "hydraulic", "glycol", "nutrient", "refrigerant"]
HARD_LOOKS = ["lh2", "lhe", "lng", "ln2", "fuel", "mmh", "n2o4"]
HAZARD_ONLY = ["explosive", "bio", "chem", "rad"]
BAT_MWH_T, BAT_EFF, BAT_PRICE = 0.4, 0.9, 600.0
S_AT, A_AT, S_BONUS, A_BONUS = 0.90, 0.70, 0.03, 0.015
LAZY_CAP = 1.05            # scripts/clean_run.gd LAZY_CAP: a lazy machine's base pay at most this over the old route
LAZY_FLOOR = 0.4           # never less than the old hazard mouth paid
P_RARE, P_SPARE, P_BOARD = 0.04, 0.06, 0.05


def residual(p, d):
    tag = p.get("tag") or ""
    if p.get("hazard") in HAZARD_ONLY:
        return "hard"
    for k, v in d.get("fluids", {}).get("volumes", {}).items():
        if v.get("piece") == tag and tag and float(v.get("amount", 0)) > float(v.get("hazard", 0.02)):
            look = str(v.get("look", v.get("fluid", "")))
            return "liq" if v.get("fluid") in BENIGN_LIQ and look not in HARD_LOOKS else "hard"
    for k, v in d.get("gas", {}).get("vessels", {}).items():
        if v.get("piece") == tag and tag and not v.get("sealed", False):
            if float(v.get("kpa", 0)) > 20.0:
                name = (k + " " + str(v.get("gas", ""))).lower()
                if "h2" in name or "fuel" in name or "prop" in name:
                    return "hard" if float(v.get("kpa", 0)) > float(v.get("burst", 200)) else ""
                return "gas"
    for s in d.get("power", {}).get("sources", []) + d.get("power", {}).get("isolated", []):
        if s.get("piece") == tag and tag:
            kd = s.get("kind", "battery")
            if kd == "cap" and float(s.get("charge", 1.0)) > 0.05:
                return "cap"
            if kd == "battery" and float(s.get("charge", 1.0)) > 0.01:
                return "batt"
    return ""


def old_hazard(p, d, k):
    # the old dest_of: what the equipment mouth refused (a battery never was)
    return k in ("gas", "liq", "cap") and not (k == "gas" and not _bursts(p, d))


def _bursts(p, d):
    tag = p.get("tag") or ""
    for k, v in d.get("gas", {}).get("vessels", {}).items():
        if v.get("piece") == tag:
            return float(v.get("kpa", 0)) > float(v.get("burst", 200))
    return False


def streak_bonus(order, clean):
    combo, b = 0, 0.0
    for v, ok in zip(order, clean):
        if ok is None:
            continue
        if ok:
            combo += 1
            b += v * STEP * min(combo, CAP_N)
        else:
            combo = 0
    return b


def mean_streak(vals, flags, n=400):
    idx = list(range(len(vals)))
    tot = 0.0
    rng = random.Random(7)
    for _ in range(n):
        rng.shuffle(idx)
        tot += streak_bonus([vals[i] for i in idx], [flags[i] for i in idx])
    return tot / n


def grade_share(G, major=False):
    return S_BONUS if G >= S_AT and not major else (A_BONUS if G >= A_AT else 0.0)


def electric_tags(d):
    out = set()
    for l in d.get("lines", []):
        if l.get("kind") == "cable":
            out.add(l.get("a"))
            out.add(l.get("b"))
    return out


def ship(sid):
    d = json.load(open("ships/%s.json" % sid, encoding="utf-8"))
    eq = [p for p in d["pieces"] if p.get("cls") == "equip" and p.get("scope", True)]
    elec = electric_tags(d)
    vals, ks = [], []
    for p in eq:
        vals.append(float(p.get("value", 0)) * float(p.get("cond", 1.0)))
        ks.append(residual(p, d))
    # the lazy pay share f (scripts/clean_run.gd _lazy_share): what a machine whose leftovers were
    # thrown out or drained keeps of its price, so the lazy route's base pay is at most LAZY_CAP × the old
    O = sum(v for v, k in zip(vals, ks) if k == "")
    R_old = sum(v * (0.4 if old_hazard(p, d, k) else 1.0) for p, v, k in zip(eq, vals, ks) if k in LOSS)
    R_new = sum(v for v, k in zip(vals, ks) if k in LOSS)
    f = 1.0 if R_new <= 0 else max(LAZY_FLOOR, min(1.0, (LAZY_CAP * (O + R_old) - O) / R_new))
    full = sum(v * (f if k in LOSS else 1.0) for v, k in zip(vals, ks) if k != "hard")
    hard = sum(v for v, k in zip(vals, ks) if k == "hard") * 0.4
    # ---- old lazy: harmless leftovers at 40 %
    old = hard + sum(v * (0.4 if old_hazard(p, d, k) else 1.0) for p, v, k in zip(eq, vals, ks) if k != "hard")
    # ---- lazy by hand: mishaps
    lh_base = hard + sum(v * (1.0 - LOSS[k]) * f if k in LOSS else v for v, k in zip(vals, ks) if k != "hard")
    flags = [None if k == "hard" else (k == "") for k in ks]
    lh_streak = mean_streak(vals, flags)
    base_all = sum(float(p.get("value", 0)) for p in eq)
    C_lh = sum(float(p.get("value", 0)) for p, k in zip(eq, ks) if k == "") / base_all if base_all else 0
    has_res = any(k in LOSS for k in ks) or float(d.get("gas", {}).get("value", 0) or 0) > 0
    G_lh = 0.75 * C_lh if has_res else C_lh
    lh = lh_base + lh_streak + grade_share(G_lh) * lh_base
    # ---- lazy with J: drained, neither clean nor a break
    flagsJ = [None if k != "" else True for k in ks]
    lj_streak = mean_streak(vals, flagsJ)
    G_lj = 0.75 * C_lh if has_res else C_lh
    lj = full + hard + lj_streak + grade_share(G_lj) * (full + hard)
    # ---- careful
    flagsC = [True for k in ks]
    c_streak = mean_streak(vals, flagsC)
    gas_v = float(d.get("gas", {}).get("value", 0) or 0)
    fl_v = sum(float(x) for x in (d.get("fluids", {}).get("value", {}) or {}).values())
    batt = 0.0
    for p, k in zip(eq, ks):
        if k == "batt":
            for s in d["power"].get("sources", []) + d["power"].get("isolated", []):
                if s.get("piece") == p.get("tag"):
                    batt += float(p.get("mass", 0)) * BAT_MWH_T * float(s.get("charge", 1.0)) * BAT_EFF * BAT_PRICE
    hid = 0.0
    for p in eq:
        v = float(p.get("value", 0))
        if v < 1500:
            continue
        hid += P_RARE * 0.6 * v
        hid += P_SPARE * min(max(v * 0.115, 300), 6000)
        if p.get("tag") in elec:
            hid += P_BOARD * min(max(v * 0.185, 300), 6000)
    c_base = sum(v for v, k in zip(vals, ks) if k != "hard") + hard
    careful = c_base + c_streak + S_BONUS * c_base + batt + hid
    return {"ship": sid, "machines": len(eq), "equip": base_all, "leftover_n": sum(1 for k in ks if k in LOSS),
            "old_lazy": old, "lazy_hand": lh, "lazy_J": lj, "careful": careful,
            "streak": c_streak, "grade": S_BONUS * c_base, "batt": batt, "finds": hid, "gas_fluid": gas_v + fl_v, "f": f}


def main():
    ships = sys.argv[1:] or ["tug", "s09", "gr7", "fr26", "vt80", "med47"]
    print("| 船 | 整件设备 | 带良性残留 | 偷懒保留比例 f | 改前偷懒 | 手动偷懒 | 开 J 偷懒 | 认真 | 认真比改前偷懒 | 认真比开 J | 其中：连击 / 评级 / 余电 / 隐藏期望 | 气液（已有，另计） |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for s in ships:
        r = ship(s)
        o = r["old_lazy"]
        print("| %s | %d 件 $%s | %d 件 | %.2f | $%s | $%s (%+.1f%%) | $%s (%+.1f%%) | $%s | %+.1f%% | %+.1f%% | $%s / $%s / $%s / $%s | $%s |" % (
            s, r["machines"], f'{r["equip"]:,.0f}', r["leftover_n"], r["f"], f'{o:,.0f}',
            f'{r["lazy_hand"]:,.0f}', (r["lazy_hand"] / o - 1) * 100, f'{r["lazy_J"]:,.0f}', (r["lazy_J"] / o - 1) * 100,
            f'{r["careful"]:,.0f}', (r["careful"] / o - 1) * 100, (r["careful"] / r["lazy_J"] - 1) * 100,
            f'{r["streak"]:,.0f}', f'{r["grade"]:,.0f}', f'{r["batt"]:,.0f}', f'{r["finds"]:,.0f}', f'{r["gas_fluid"]:,.0f}'))


if __name__ == "__main__":
    main()
