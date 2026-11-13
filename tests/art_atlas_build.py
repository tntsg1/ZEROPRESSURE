# 零件图鉴 builder: manifest.json + raw/*.png (from tests/art_atlas.gd) -> numbered cells,
# sheets, index.html, 清单.csv.  python -I tests/art_atlas_build.py
import csv, html, json, os, re, shutil, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = "E:/godot/zeropower"
OUT = ROOT + "/proofs/零件图鉴_20261111"
SC = ROOT + "/scripts/"

man = json.load(open(OUT + "/manifest.json", encoding="utf8"))

# ---------------------------------------------------------------- which function draws what
def arms(path, start_pat, end_pat=None, call=True):
    src = open(path, encoding="utf8").read().replace("\r\n", "\n")
    i = src.index(start_pat)
    seg = src[i:]
    out = {}
    for m in re.finditer(r'^\t\t((?:"[\w]+"(?:, )?)+):(?: (\w+)\()?', seg, re.M):
        keys = re.findall(r'"([\w]+)"', m.group(1))
        for k in keys:
            out[k] = m.group(2) or ""
    return out

EQ_FN = arms(SC + "art_equip.gd", "static func _draw_art")
SH_FN = arms(SC + "art_ships.gd", "static func _draw_art")
DT_FN = arms(SC + "art_detail.gd", "static func draw(")
OLD_FN = arms(SC + "art.gd", "static func _draw_old")

def fn_of(e):
    a, f = e["art"], e["file"]
    if f == "art_equip.gd":
        return EQ_FN.get(a, "") or "?"
    if f == "art_ships.gd":
        return SH_FN.get(a, "") or "?"
    if f == "art_detail.gd":
        return DT_FN.get(a, "") or "?"
    if f == "art.gd":
        if a in OLD_FN:
            return "Art._draw_old · case \"%s\"" % a
        return ""
    return ""

# ---------------------------------------------------------------- categories
CATS = ["电力与配电", "推进与燃料", "气液与管阀", "生命维持与居住", "反应堆与核心资产", "货舱与搬运", "仪器与控制台", "机械与作业设备", "其他", "结构件"]
def L(s): return set(s.split())
ART_CAT = {}
for cat, s in {
    "电力与配电": "battery swb gen transformer inverter fuelcell charger junction cabinet panel aux module apu electrolyser switch_chassis steam_turbine slip_ring",
    "推进与燃料": "eng_core eng_front engine_s nozzle rcs_quad fueltank cryotank sphere_tank turbopump turbo_pump turbo reaction_wheel flywheel_rotor despin_brake brake tether_damper spray_bar",
    "气液与管阀": "pump pipe filter gastank manifold relief water hx cdu chiller condenser evaporator radiator duct_fan dry_cooler scrubber hydrocyclone shaker degasser gas_buster decanter agitator mud_pump choke_manifold koomey bop standpipe psa separator_3ph ortho_para precooler cold_box_h2 coldbox screw_comp axial_comp scroll_pump turboexpander pulse_tube hpu actuator extinguisher pipe_bundle pipe_rack trap tray rotary_seal level_radar coriolis",
    "生命维持与居住": "env bunk seat seat_d bed_d bed suit_d suit locker galley fridge freezer medcab medcart plants plant_tray table desk shelf bench suite optable_d op_table biobox co2_scrubber humidifier composter uv_steriliser food_module escape_pod wine_rack beehive piano lamp growlamp overhead harness ladder stairs glove",
    "反应堆与核心资产": "ntr_core pwr_core crdm control_drum tf_coil cs_stack divertor vv_wall port_plug gyrotron ech nbi pellet dump_res rcp pressurizer fw_d fw_u fw_l fw_r shadow_shield reactor grav_support vault vault_d safe_deposit qpu storage_array blackbox drive_carrier dr_stage",
    "货舱与搬运": "cargo crate container barrel drum bar ingot_rack mail_sorter strap_d hook reel lift lift_d spoke_lift hold_crane tow_winch case_d",
    "仪器与控制台": "console nav nav_rack screen monitor sensor insp radar spectrograph microscope magnetometer imu star_tracker ir_camera coronagraph mass_spec gc particle_det xray_scanner gauge_box beacon biometric fsm fgs ghs wfs aft_optics hexapod iso_table instrument_rack mirror ref_plant",
    "机械与作业设备": "arm lathe mill crusher forklift deck_tractor work_vehicle car roughneck top_drive crown_block travel_block drawworks rotary_table bha drillpipe arc_furnace eddy_sorter mag_separator recoater robot dock turret ciws launcher gun_mount gun_rack missile missile_d decoy launch_cradle hyd_clamp uav",
}.items():
    for a in L(s): ART_CAT[a] = cat

ART_CAT.update({a: "结构件" for a in L("armor cover glass grating insul shell shroud guard ice strut window")})
ART_CAT.update({"cap": "气液与管阀", "o2cab": "生命维持与居住", "stator": "电力与配电", "toolwall": "机械与作业设备", "immersion_rack": "仪器与控制台"})
ART_CAT.update({"power_amp": "电力与配电", "aux_thruster": "推进与燃料",
                "gamma_monitor": "仪器与控制台", "ax_gamma": "仪器与控制台", "radio_console": "仪器与控制台",
                "fish_feeder": "生命维持与居住", "steam_humidifier": "生命维持与居住", "mist_pump": "生命维持与居住"})
# E002–E016 redrawn in art_ships.gd (2026-11-11): kept on the page they were on as "aux"
ART_CAT.update({"rf_amp": "电力与配电", "aux_rocket": "推进与燃料", "gamma_probe": "仪器与控制台", "comms_desk": "仪器与控制台",
                "pellet_feeder": "生命维持与居住", "steam_cyl": "生命维持与居住", "fog_pump": "生命维持与居住",
                "fw_appliance": "电力与配电", "rig_welder": "电力与配电", "e07_unit": "电力与配电", "shunt_reg": "电力与配电",
                "gas_puff": "电力与配电", "ion_grid": "电力与配电", "rb_clock": "电力与配电", "daq_rail": "电力与配电"})
# E018–E028 batteries redrawn in art_ships.gd (2026-11-11): still on the power pages
ART_CAT.update({a: "电力与配电" for a in L("ark_aux_pack battery_cart emerg_light ring_battery shuttle_pack vrla_rack main_battery drone_pack courier_stack lock_ups pod_ups race_pack standby_bank ups_unit")})

ART_CAT.update({a: '电力与配电' for a in L('bench_drill bms_cab brake_ctrl cal_bench crd_cab crypto_rack dispatch_log dosing_skid food_bench gas_detector hv_switchgear material_rack pack_rack survey_log tool_cart turbine_ctrl tx_cabinet')})
ART_CAT.update({a: '电力与配电' for a in L('hv_switchgear')})
ART_CAT.update({a: '电力与配电' for a in L('chem_store core_store cryo_cdb cryo_spares dcdc drill_tools ev_calib garden_locker herbarium ob_cal plate_archive sample_cyl server_spares shot_archive spare_cells spare_leads well_logs')})
ART_CAT.update({a: '电力与配电' for a in L('batch_log cargo_log cockpit_case custody_reg dining_table evidence_lockers flow_ctrl mail_locker manifest_term pharmacy sample_trays seed_vault shadow_board smelt_log supply_stack svc_bench tow_log')})
ART_CAT.update({a: '电力与配电' for a in L('bl_electrolyser co2_burner diesel_genset drups fuel_cell_pm main_alternator rtg_module stirling_gen ts_power turbine_genset')})
ART_CAT.update({a: '电力与配电' for a in L('apu_mono baffle_heater bay_charger brake_handle_panel busbar_box charge_post control_strip cradle_ctrl cradle_lock cryo_ctrl_panel cryo_manifold dcdc engine_panel esd_station flywheel_brake_panel freezer_ctrl fridge_ctl frost_vent hemt_bias hull_support irrigation_ctrl leak_panel level_gauge lift_call lift_saddle lock_backup_box monitor_wall process_panel purge_panel push_fender pusher_plate quiet_pcu race_ecu rail_lock_board rail_lock_square rcs_ctrl recovery_valves release_board release_cabinet rod_lock_panel room_panel s_bat shield_probe slips_panel small_manifold solar_pcu standby_dist tank_bracket tank_temp tension_link tether_brake_frame tether_root tool_cart uv_tube wall_socket')})
ART_CAT.update({a: '电力与配电' for a in L('esd_station')})
ART_CAT.update({a: '电力与配电' for a in L('room_panel')})
ART_CAT.update({a: '电力与配电' for a in L('material_rack room_panel')})
def cat_of(e):
    if e.get("cat_keep"):   # a redrawn kind stays on the page it was on (swap_cells, 2026-11-11)
        return e["cat_keep"]
    if e["struct"]:
        return "结构件"
    return ART_CAT.get(e["art"], "其他")

for e in man:
    e["cat"] = cat_of(e)
# ---- stable identity + frozen numbers.  The key never depends on how a part is drawn (the
# resolved art changes when someone redraws it): name_key + the art its ship files give it.
# manifest_ids.json = {"max": N, "ids": {key: "E001"}, "info": {key: text}}: kept ids are reused,
# new keys go after the max, vanished keys keep their number (never reused).
IDS = OUT + "/manifest_ids.json"
def key_of(e):
    ra = max(e["raw_arts"].items(), key=lambda kv: (kv[1], kv[0]))[0]
    return "%s|%s" % (e["name_key"], ra)
keys = {}
for e in man:
    k = key_of(e)
    if k in keys:
        k += "|" + e["art"]
    assert k not in keys, k
    keys[k] = e
    e["key"] = k
for e in man:
    e["cat"] = cat_of(e)
if os.path.exists(IDS):
    fz = json.load(open(IDS, encoding="utf8"))
else:
    # baseline: the numbering the user first saw (sorted by category, art, name_key). Seven keys were
    # drawn as plain "aux" then and have a dedicated art now; sort them as they were (E002-E016 = the 15 aux).
    OLD_AUX = {"p_ark_amp", "p_aux", "p_ax_gamma_monitor", "p_bl_feeder", "p_bl_humidifier", "p_bl_mister", "p_comms"}
    def base_key(e):
        if e["name_key"] in OLD_AUX:
            return (0, "aux", e["name_key"])
        return (CATS.index(e["cat"]), e["art"], e["name_key"])
    fz = {"max": 0, "ids": {}, "info": {}}
    for e in sorted(man, key=base_key):
        fz["max"] += 1
        fz["ids"][e["key"]] = "E%03d" % fz["max"]
for e in sorted(man, key=lambda e: (CATS.index(e["cat"]), e["art"], e["name_key"])):
    if e["key"] not in fz["ids"]:
        fz["max"] += 1
        fz["ids"][e["key"]] = "E%03d" % fz["max"]
        print("NEW id", fz["ids"][e["key"]], e["key"])
    e["id"] = fz["ids"][e["key"]]
    fz["info"][e["key"]] = "%s | %s" % (e["name_zh"], e["art"])
live = {e["key"] for e in man}
for k, i in fz["ids"].items():
    if k not in live:
        print("RETIRED (number kept, not reused)", i, k)
json.dump(fz, open(IDS, "w", encoding="utf8"), ensure_ascii=False, indent=1)
order = sorted(man, key=lambda e: (CATS.index(e["cat"]), int(e["id"][1:])))

def ship_label(s): return s.upper().replace("_", "-")
def legacy(e): return e["file"] in ("art.gd", "不画") or (e["file"] == "art.gd" and not fn_of(e))
for e in man:
    e["legacy"] = e["file"] == "art.gd"
    e["nodraw"] = e["file"] not in ("art_equip.gd", "art_ships.gd", "art_detail.gd", "art.gd")
    e["fn"] = fn_of(e)
    if e["legacy"] and not e["fn"]:
        e["fn"] = "(无对应画法)"
    e["ships_s"] = " ".join("%s×%d" % (ship_label(s), n) for s, n in sorted(e["ships"], key=lambda x: -x[1]))
    e["nm"] = e["name_zh"] if e["name_zh"] and e["name_zh"] != e["name_key"] else ("(无名称)" if not e["name_key"] else e["name_key"])

# ---------------------------------------------------------------- cells
os.makedirs(OUT + "/cells", exist_ok=True)
for _f in os.listdir(OUT + "/cells"):
    if _f[:-4] not in {e["id"] for e in man}:
        os.remove(OUT + "/cells/" + _f)
for e in order:
    shutil.copyfile("%s/raw/%04d.png" % (OUT, e["idx"]), "%s/cells/%s.png" % (OUT, e["id"]))

# ---------------------------------------------------------------- sheets
F = lambda sz, bd=False: ImageFont.truetype("C:/Windows/Fonts/msyh%s.ttc" % ("bd" if bd else ""), sz)
f_id, f_nm, f_sm = F(19, True), F(18, True), F(13)
BG, INK, DIM, ORG = (13, 14, 16), (232, 234, 236), (150, 156, 162), (255, 122, 40)
COLS, ROWS = 6, 6
CWD, THH, CAPH = 320, 240, 84
PW = COLS * CWD
PH = 60 + ROWS * (THH + CAPH)

def fit(d, text, font, maxw):
    if d.textlength(text, font=font) <= maxw:
        return text
    while text and d.textlength(text + "…", font=font) > maxw:
        text = text[:-1]
    return text + "…"

pages = []  # (cat, pageno, filename, ids)
by_cat = {c: [e for e in order if e["cat"] == c] for c in CATS}
for c in CATS:
    items = by_cat[c]
    n_pages = (len(items) + COLS * ROWS - 1) // (COLS * ROWS)
    for pg in range(n_pages):
        chunk = items[pg * COLS * ROWS:(pg + 1) * COLS * ROWS]
        rows = (len(chunk) + COLS - 1) // COLS
        im = Image.new("RGB", (PW, 60 + rows * (THH + CAPH)), BG)
        d = ImageDraw.Draw(im)
        d.text((16, 12), "%s  %d/%d" % (c, pg + 1, n_pages), font=F(26, True), fill=INK)
        d.text((PW - 16, 20), "本页 %d 格  · 橙色角标 = 仍走 art.gd 旧画法" % len(chunk), font=f_sm, fill=DIM, anchor="ra")
        for i, e in enumerate(chunk):
            x, y = (i % COLS) * CWD, 60 + (i // COLS) * (THH + CAPH)
            t = Image.open("%s/cells/%s.png" % (OUT, e["id"])).convert("RGB").resize((CWD - 4, THH - 2), Image.LANCZOS)
            im.paste(t, (x + 2, y))
            d.rectangle([x + 1, y, x + CWD - 2, y + THH - 2], outline=(40, 42, 46))
            d.text((x + 8, y + THH + 2), e["id"], font=f_id, fill=ORG if e["legacy"] else INK)
            d.text((x + 66, y + THH + 3), fit(d, e["nm"], f_nm, CWD - 74), font=f_nm, fill=INK)
            d.text((x + 8, y + THH + 29), fit(d, "%s · %s m · %s" % (e["name_key"] or e["art"], e["size"], e["art"]), f_sm, CWD - 16), font=f_sm, fill=DIM)
            d.text((x + 8, y + THH + 48), fit(d, "%d 件 · %s" % (e["n"], e["ships_s"]), f_sm, CWD - 16), font=f_sm, fill=DIM)
            if e["legacy"]:
                d.rectangle([x + 2, y, x + 58, y + 20], fill=ORG)
                d.text((x + 6, y + 2), "旧画法", font=F(13, True), fill=(10, 10, 10))
        fn = "页%02d_%s_%d.png" % (len(pages) + 1, c, pg + 1)
        im.save(OUT + "/" + fn)
        pages.append((c, pg + 1, n_pages, fn, [e["id"] for e in chunk]))

# ---------------------------------------------------------------- csv
with open(OUT + "/清单.csv", "w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["编号", "类别", "中文名", "name_key", "画法key", "画法函数名", "所在文件", "尺寸(米)", "出现船只", "次数", "是否旧画法(art.gd)", "选画法途径", "图鉴页"])
    pg_of = {i: p[3] for p in pages for i in p[4]}
    for e in order:
        w.writerow([e["id"], e["cat"], e["nm"], e["name_key"], e["art"], e["fn"],
                    e["file"] + ("（旧画法）" if e["legacy"] else ""), e["size"], e["ships_s"], e["n"],
                    "是" if e["legacy"] else "", {"own": "零件自带art", "ships": "art_ships.BY_NAME", "equip": "art_equip.BY_NAME", "detail": "art_detail.BY_NAME"}[e["via"]], pg_of[e["id"]]])

# ---------------------------------------------------------------- html
H = html.escape
cards = {}
for c in CATS:
    cs = []
    for e in by_cat[c]:
        cs.append(
            '<figure class="c%s" data-s="%s" data-k="%s"><img loading="lazy" src="cells/%s.png" alt="%s">'
            '<figcaption><b>%s</b> %s%s<br><span>%s · %s m · %s</span><br><span>%s · %d 件 · %s</span></figcaption></figure>' % (
                " old" if e["legacy"] else "", H((e["id"] + e["nm"] + e["name_key"] + e["art"] + e["ships_s"]).lower()), H(e["key"]), e["id"], H(e["id"]),
                e["id"], H(e["nm"]), '<i>旧画法</i>' if e["legacy"] else "", H(e["name_key"] or "—"), e["size"], H(e["art"]),
                H(e["file"]), e["n"], H(e["ships_s"])))
    cards[c] = "".join(cs)
nav = "".join('<a href="#c%d">%s <em>%d</em></a>' % (i, c, len(by_cat[c])) for i, c in enumerate(CATS))
body = "".join('<section id="c%d"><h2>%s <em>%d</em></h2><div class="g">%s</div></section>' % (i, c, len(by_cat[c]), cards[c]) for i, c in enumerate(CATS))
n_old = sum(1 for e in order if e["legacy"])
page = """<!doctype html><html lang="zh"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>零压 零件图鉴</title><style>
:root{--bg:#0d0e10;--ink:#e8eaec;--dim:#969ca2;--org:#ff7a28;--ln:#26282c}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 "Microsoft YaHei",sans-serif}
header{position:sticky;top:0;z-index:5;background:#0d0e10f2;border-bottom:1px solid var(--ln);padding:10px 16px;display:flex;flex-wrap:wrap;gap:10px 18px;align-items:center}
h1{font-size:18px;margin:0}nav{display:flex;flex-wrap:wrap;gap:6px 14px}nav a{color:var(--dim);text-decoration:none}nav a:hover{color:var(--ink)}em{color:var(--dim);font-style:normal;font-size:12px}
input[type=search]{background:#16181b;border:1px solid var(--ln);color:var(--ink);padding:5px 9px;border-radius:4px;width:220px}label{color:var(--dim);cursor:pointer}
section{padding:8px 16px 20px}h2{font-size:20px;border-bottom:1px solid var(--ln);padding-bottom:6px}
.g{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:10px}
figure{margin:0;background:#101215;border:1px solid var(--ln);cursor:zoom-in}figure.old{border-color:#7a3a14}
figure img{display:block;width:100%%;height:auto}figcaption{padding:6px 9px 8px;font-size:13px}figcaption b{color:var(--ink);font-size:15px}figcaption span{color:var(--dim);font-size:12px}
figcaption i{background:var(--org);color:#111;font-style:normal;font-size:11px;padding:0 5px;margin-left:6px;border-radius:2px}
.hide{display:none}#lb{position:fixed;inset:0;background:#000d;display:none;align-items:center;justify-content:center;flex-direction:column;z-index:9;cursor:zoom-out;padding:16px}
#lb img{max-width:96vw;max-height:80vh;image-rendering:auto;background:#0d0e10;border:1px solid var(--ln)}#lb p{margin:10px 0 0;text-align:center;max-width:90vw}
</style></head><body>
<header><h1>零压 · 零件图鉴 <em>共 %d 种，仍走旧画法 %d 种</em></h1><input id="q" type="search" placeholder="搜编号 / 中文名 / name_key / 船">
<label><input id="o" type="checkbox"> 只看旧画法</label><nav>%s</nav></header>%s
<div id="lb"><img id="li"><p id="lc"></p></div>
<script>
const q=document.getElementById('q'),o=document.getElementById('o');
function f(){const v=q.value.trim().toLowerCase();document.querySelectorAll('figure').forEach(e=>{e.classList.toggle('hide',(v&&!e.dataset.s.includes(v))||(o.checked&&!e.classList.contains('old')))})}
q.oninput=f;o.onchange=f;
const lb=document.getElementById('lb');document.querySelectorAll('figure').forEach(e=>e.onclick=()=>{document.getElementById('li').src=e.querySelector('img').src;document.getElementById('lc').innerHTML=e.querySelector('figcaption').innerHTML;lb.style.display='flex'});
lb.onclick=()=>lb.style.display='none';
</script></body></html>""" % (len(order), n_old, nav, body)
open(OUT + "/index.html", "w", encoding="utf8").write(page)
# tick boxes (勾选.json is the user's; this build never writes or deletes it)
sys.path.insert(0, ROOT + "/tests")
import art_atlas_checks
art_atlas_checks.inject()
print("total", len(order), "pages", len(pages), "legacy", n_old)
for c in CATS: print(c, len(by_cat[c]))
print("nodraw:", [(e["id"], e["art"]) for e in order if e["nodraw"]])
print("legacy no fn:", [(e["id"], e["art"]) for e in order if e["legacy"] and e["fn"] == "(无对应画法)"])
