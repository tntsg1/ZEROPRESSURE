class_name CodexFx
# 图鉴的“全息档案”画法（2026-11-05，用户：首次遇见的知识卡不够酷；问答选 C：卡片和示意图都做）。
# 示意图在一块仪器屏上：暗网格、边缘刻度、四角括号；每种符号都有自己的循环动画（热管线发红并冒
# 热浪——热浪扭曲是一块读屏幕的着色器；气体一圈圈扩散；电缆有电流流过；液滴晃动；锁和夹具做
# 轻微的工作动作……）；真实线稿有呼吸微动和一道扫描高光。卡片（scripts/codex_hud.gd）和图鉴书
# （scripts/codex_page.gd）都经 CodexHud.draw_art 用这里的画法。“减少动效”时一切静止。
# 符号都是几条线、几段弧，图框约 110×90，CPU 每帧画也只有几十个绘制命令；热浪只在热管线上用着色器。
# Motion Prompt #005 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#005

# 危险等级 1–3 格：按每条“危险”句子里的词分（会炸、会烧、有毒、辐射、高压、电弧、喷出为 3；伤、烫、
# 砸、漏、裂、卡、断为 2；其余为 1），37 条手工覆盖。生成脚本和逐条表格在汇报里。
const LEVEL := {
	"bolt": 1, "weld": 1, "lock": 2, "clamp": 1, "hull": 3, "bulkhead": 3, "frame": 2, "door": 3,
	"rail": 2, "film": 2, "cable": 2, "pipe_line": 2, "cut_line": 1, "glass": 2, "armor": 2, "insul": 1,
	"cover": 2, "port": 1, "valve": 2, "switch": 2, "test": 1, "probe": 1, "socket": 2, "discharge": 3,
	"seal": 1, "swb": 2, "battery": 2, "cap": 3, "gen": 2, "panel": 2, "junction": 3, "transformer": 3,
	"inverter": 2, "fuelcell": 2, "charger": 2, "dump_res": 2, "slip_ring": 2, "tray": 1, "module": 2, "pump": 2,
	"hx": 1, "radiator": 2, "chiller": 2, "freezer": 2, "env": 1, "duct_fan": 1, "filter": 3, "trap": 1,
	"manifold": 2, "aux": 2, "relief": 3, "pipe": 3, "hpu": 3, "actuator": 2, "gastank": 3, "fueltank": 3,
	"sphere_tank": 3, "cryotank": 3, "water": 1, "extinguisher": 3, "o2cab": 3, "co2_scrubber": 1, "psa": 2, "electrolyser": 3,
	"humidifier": 1, "uv_steriliser": 1, "separator_3ph": 2, "coriolis": 2, "level_radar": 1, "gauge_box": 2, "insp": 1, "screw_comp": 2,
	"axial_comp": 2, "turboexpander": 2, "turbo_pump": 2, "scroll_pump": 1, "dry_cooler": 1, "cdu": 1, "eng_core": 3, "engine_s": 3,
	"nozzle": 2, "rcs_quad": 3, "turbopump": 2, "apu": 2, "ntr_core": 3, "nav_rack": 2, "nav": 2, "console": 1,
	"blackbox": 1, "imu": 2, "star_tracker": 2, "radar": 2, "xray_scanner": 3, "biometric": 1, "hook": 2, "reel": 2,
	"arm": 2, "dock": 2, "brake": 2, "lift": 2, "hold_crane": 2, "machine_tool": 1, "vehicle": 2, "cargo": 1,
	"uav": 2, "stator": 2, "launch_cradle": 2, "flywheel_rotor": 2, "reaction_wheel": 2, "despin_brake": 2, "rotary_seal": 1, "spoke_lift": 2,
	"tether_damper": 2, "hyd_clamp": 2, "iso_table": 2, "escape_pod": 3, "safe_deposit": 1, "pwr_core": 3, "crdm": 2, "rcp": 2,
	"pressurizer": 3, "steam_turbine": 2, "condenser": 1, "control_drum": 3, "shadow_shield": 3, "tf_coil": 3, "cs_stack": 3, "grav_support": 3,
	"vv_wall": 3, "blanket": 2, "divertor": 2, "gyrotron": 3, "ech": 2, "nbi": 3, "pellet": 2, "port_plug": 2,
	"coldbox": 2, "cold_box_h2": 3, "dr_stage": 2, "qpu": 2, "pulse_tube": 1, "ghs": 2, "instrument_rack": 2, "mirror": 2,
	"hexapod": 1, "aft_optics": 2, "fsm": 2, "fgs": 2, "wfs": 2, "recoater": 1, "ir_camera": 1, "spectrograph": 1,
	"coronagraph": 2, "particle_det": 2, "magnetometer": 1, "lab": 2, "immersion_rack": 1, "storage_array": 1, "drive_carrier": 1, "top_drive": 1,
	"drawworks": 1, "blocks": 1, "rotary_table": 1, "drillpipe": 1, "bha": 1, "mud_pump": 3, "shaker": 1, "mud_clean": 1,
	"roughneck": 1, "bop": 1, "well_manifold": 3, "ortho_para": 1, "precooler": 1, "arc_furnace": 2, "sorter": 1, "scrubber": 2,
	"crusher": 1, "turret": 2, "launcher": 3, "ciws": 2, "m_munitions": 3, "m_quench": 1, "m_flywheel": 3, "m_pyro": 2,
	"m_magnet": 2, "m_preload": 2, "m_drones": 2, "m_cryo_tank": 3, "m_boiloff": 3, "m_frozen_valve": 3, "m_dilution": 2, "m_coldchain": 2,
	"m_ice": 2, "m_drill_torque": 3, "m_drill_slips": 2, "m_tanknet": 2, "m_immersion": 1, "m_custody": 1, "m_waterball": 2, "m_media": 1,
	"m_o2_flash": 3, "m_composite": 3, "m_radiation": 3, "m_decay_heat": 2, "m_thermal": 2, "m_bio": 1, "m_balance": 2, "m_sandwich": 2,
	"m_boxbeam": 1, "m_sail": 2, "m_softshell": 2, "m_tether": 2, "m_train": 2, "m_ore": 2, "m_rails": 2, "m_rings": 3,
	"m_spine": 2, "m_workday": 1, "m_mirror_dust": 2, "m_mirror_lock": 2, "m_glass": 2, "m_vault": 2, "m_hypergolic": 3, "m_nested": 2,
	"s_gas": 3, "s_stale": 2, "s_power": 1, "s_heat": 2, "s_cloud": 3, "s_fire": 3, "s_liquid": 3, "s_hose": 2,
	"s_free": 2, "s_grapple": 2, "s_furnace": 3, "s_equip_mouth": 2, "s_hazard_mouth": 3, "s_field": 2, "s_berth_ext": 1, "s_blueprint": 1,
	"s_scope": 2, "s_hauler": 1, "s_impact": 2, "s_ullage": 3, "s_contents": 1, "s_o2_rich": 3,
}


static func now() -> float:
	return BenchFx.now() if BenchFx.on() else 0.0


static func level(id: String) -> int:
	return int(LEVEL.get(id, 1))


# the entry's archive number, in the book's order (CX-001 …)
static func code(id: String) -> String:
	var i := CodexData.E.keys().find(id)
	return "CX-%03d" % (i + 1) if i >= 0 else "CX-—"


static var _rows: Texture2D


# faint scan rows (one row lit in three), tiled in one draw
static func rows_tex() -> Texture2D:
	if _rows == null:
		var img := Image.create(4, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		for x in 4:
			img.set_pixel(x, 2, Color(1, 1, 1, 1))
		_rows = ImageTexture.create_from_image(img)
	return _rows


static func fract(x: float) -> float:
	return x - floor(x)


# ---------------------------------------------------------------- the instrument screen behind a drawing

static var _grid: Texture2D
static var _ticks_x: Texture2D
static var _ticks_y: Texture2D


# the screen's grid (8 px, every fourth line brighter) and its edge ticks, baked once into small
# tiles: each drawn in one call however large the box (was some forty lines a frame)
static func _bake() -> void:
	var g := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	g.fill(Color(1, 1, 1, 0))
	for i in 4:
		var al := 0.055 if i == 3 else 0.025
		for k in 32:
			g.set_pixel(i * 8 + 7, k, Color(1, 1, 1, al))
			g.set_pixel(k, i * 8 + 7, Color(1, 1, 1, maxf(al, g.get_pixel(k, i * 8 + 7).a)))
	_grid = ImageTexture.create_from_image(g)
	var tx := Image.create(32, 4, false, Image.FORMAT_RGBA8)
	tx.fill(Color(1, 1, 1, 0))
	for i in 4:
		for yy in (4 if i == 0 else 2):
			tx.set_pixel(i * 8, 3 - yy, Color(1, 1, 1, 1))
	_ticks_x = ImageTexture.create_from_image(tx)
	var ty := Image.create(4, 32, false, Image.FORMAT_RGBA8)
	ty.fill(Color(1, 1, 1, 0))
	for i in 4:
		for xx in (4 if i == 0 else 2):
			ty.set_pixel(xx, i * 8, Color(1, 1, 1, 1))
	_ticks_y = ImageTexture.create_from_image(ty)


static func screen(ci: CanvasItem, r: Rect2, a: float, grid := true) -> void:
	if _grid == null:
		_bake()
	ci.draw_rect(r, Color(0.03, 0.031, 0.034, a))
	if grid:
		ci.draw_texture_rect(_grid, r, true, Color(1, 1, 1, a))
	ci.draw_texture_rect(_ticks_x, Rect2(r.position.x, r.end.y - 4.0, r.size.x, 4.0), true, Color(0.82, 0.83, 0.8, 0.3 * a))
	ci.draw_texture_rect(_ticks_y, Rect2(r.position.x, r.position.y, 4.0, r.size.y), true, Color(0.82, 0.83, 0.8, 0.3 * a))
	brackets(ci, r, Color(0.86, 0.87, 0.84, 0.6 * a), 7.0)   # 2026-11-11 炭黑: greyscale (was cyan)



# four corner brackets
static func brackets(ci: CanvasItem, r: Rect2, col: Color, l: float, w := 1.0) -> void:
	for c in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
		var p: Vector2 = c[0]
		var d: Vector2 = c[1]
		ci.draw_line(p, p + Vector2(l * d.x, 0), col, w)
		ci.draw_line(p, p + Vector2(0, l * d.y), col, w)


# the scan over a real drawing: a thin ice-blue line running down with a short fading trail
static func scan(ci: CanvasItem, r: Rect2, a: float, t: float) -> void:
	if t <= 0.0:
		return
	var q := fract(t / 2.8)
	var y := r.position.y - 12.0 + q * (r.size.y + 24.0)
	for i in 6:
		var yy := y - i * 2.0
		if yy < r.position.y or yy > r.end.y:
			continue
		ci.draw_line(Vector2(r.position.x + 1, yy), Vector2(r.end.x - 1, yy), Color(0.92, 0.93, 0.9, (0.4 if i == 0 else 0.08 * (6 - i) / 6.0) * a), 1.0)


# ---------------------------------------------------------------- heat shimmer (a screen-reading shader)

const SHIMMER := """
shader_type canvas_item;
// the instrument grid seen through rising heat: the grid itself is drawn here, bent by the heat
// (strongest just over the hot line, fading as it rises), with a faint orange haze. It reads nothing
// from the screen (no copy of the frame): cheap. The box under it is drawn without its own grid.
uniform vec2 size = vec2(108.0, 86.0);
float grid(vec2 p) {
	// distance from the cell's middle: a line where either reaches the edge (about 1 px wide)
	vec2 d = abs(fract((p + 0.5) / 8.0) - 0.5) * 8.0;
	float l = max(smoothstep(3.35, 3.95, d.x), smoothstep(3.35, 3.95, d.y));
	vec2 c = floor(p / 8.0);
	float bright = (mod(c.x, 4.0) > 2.5 || mod(c.y, 4.0) > 2.5) ? 0.055 : 0.025;
	return l * bright;
}
void fragment() {
	vec2 px = UV * size;
	float m = smoothstep(0.95, 0.35, UV.y) * smoothstep(0.0, 0.2, UV.y);
	vec2 w = px + vec2(sin(px.y * 0.32 - TIME * 6.0 + px.x * 0.06), cos(px.x * 0.22 + TIME * 4.5) * 0.5) * 2.4 * m;
	float g = grid(w);
	vec3 hot = vec3(1.0, 0.36, 0.12);
	COLOR = vec4(mix(vec3(1.0), hot, m * 0.7), g + 0.045 * m * (0.6 + 0.4 * sin(TIME * 2.2)));
}
"""
static var _shimmer_sh: Shader


class Shimmer extends ColorRect:
	var seen := -9

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		if CodexFx._shimmer_sh == null:
			CodexFx._shimmer_sh = Shader.new()
			CodexFx._shimmer_sh.code = CodexFx.SHIMMER
		m.shader = CodexFx._shimmer_sh
		material = m
		visible = false

	func _process(_dt: float) -> void:
		# shown only while its drawing is being drawn
		if Engine.get_process_frames() - seen > 1:
			visible = false


# is host's heat shader still free this frame (one box per host gets it; others keep the plain grid)
static func shimmer_free(host: CanvasItem) -> bool:
	if not (host is Control) or not BenchFx.on() or prof_off == "shimmer":
		return false
	var s: Shimmer = host.get_meta("cx_shimmer") if host.has_meta("cx_shimmer") else null
	return s == null or not is_instance_valid(s) or s.seen != Engine.get_process_frames()


# heat over a box drawn on host (a Control): its shimmer child is placed there for this frame
static var prof_off := ""     # tests only: "shimmer" / "glyph" / "card" left out, to see what each costs


static func shimmer(host: CanvasItem, r: Rect2) -> void:
	if not (host is Control) or not BenchFx.on() or prof_off == "shimmer":
		return
	var s: Shimmer = host.get_meta("cx_shimmer") if host.has_meta("cx_shimmer") else null
	if s == null or not is_instance_valid(s):
		s = Shimmer.new()
		host.set_meta("cx_shimmer", s)
		host.add_child.call_deferred(s)
		return
	s.position = r.position
	s.size = r.size
	(s.material as ShaderMaterial).set_shader_parameter("size", r.size)
	s.seen = Engine.get_process_frames()
	s.visible = true


# ---------------------------------------------------------------- the signs, alive

static func _path(pts: PackedVector2Array, q: float) -> Vector2:
	# a point q (0..1) of the way along a polyline
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var want := q * total
	for i in pts.size() - 1:
		var l := pts[i].distance_to(pts[i + 1])
		if want <= l:
			return pts[i].lerp(pts[i + 1], want / maxf(l, 0.001))
		want -= l
	return pts[pts.size() - 1]


static func _curve(a: Vector2, b: Vector2, c: Vector2, d: Vector2, n := 18) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		var v := 1.0 - u
		out.append(a * v * v * v + b * 3.0 * v * v * u + c * 3.0 * v * u * u + d * u * u * u)
	return out


static func _glow(ci: CanvasItem, at: Vector2, rad: float, col: Color) -> void:
	ci.draw_texture_rect(UiSkin.glow_tex(), Rect2(at - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false, col)


# the sign for g in r at time t (t = 0: still)
static func glyph(ci: CanvasItem, g: String, r: Rect2, a: float, t: float) -> void:
	var cen := r.get_center()
	var s: float = minf(r.size.x, r.size.y)
	var col := Pal.ink(0.8 * a)
	var dim := Pal.ink(0.35 * a)
	match g:
		"heat":
			# a lagged hot line low in the box: red through the gaps in its cladding, pulsing; heat rising
			var y0 := r.end.y - s * 0.22
			var pr := Rect2(Vector2(r.position.x + s * 0.12, y0 - s * 0.06), Vector2(r.size.x - s * 0.24, s * 0.12))
			var pulse := 0.75 + 0.25 * sin(t * 2.2)
			_glow(ci, pr.get_center(), minf(pr.size.x * 0.4, (r.end.y - pr.get_center().y) * 0.95), Color(1.0, 0.3, 0.1, 0.2 * pulse * a))
			ci.draw_rect(pr, Color(0.55, 0.12, 0.04, a))
			ci.draw_rect(Rect2(pr.position, Vector2(pr.size.x, 2.0)), Color(1.0, 0.55, 0.25, 0.8 * pulse * a))
			for i in 5:
				var bx := pr.position.x + pr.size.x * (i + 0.5) / 5.0
				var bw := maxf(5.0, s * 0.06)
				ci.draw_rect(Rect2(bx - bw * 0.5, pr.position.y - 1.0, bw, pr.size.y + 2.0), Color(0.16, 0.17, 0.19, a))
				ci.draw_rect(Rect2(bx - bw * 0.5, pr.position.y - 1.0, bw, pr.size.y + 2.0), dim, false, 1.0)
			ci.draw_rect(pr, Pal.heat(0.9 * a, 1.2), false, 1.0)
			# heat rising: three soft wavy strands drifting up and fading (the shimmer does the rest)
			for i in 3:
				var x0 := pr.position.x + pr.size.x * (i + 0.5) / 3.0
				var q := fract(t * 0.35 + i * 0.33)
				var pts := PackedVector2Array()
				var top := y0 - s * 0.1 - q * s * 0.3
				var nk := maxi(9, int(s / 5.0))
				for k in nk:
					var yy := top - k * s * 0.36 / nk
					pts.append(Vector2(x0 + sin(yy / s * 16.0 + t * 3.0 + i * 2.0) * s * 0.03, yy))
				var fade := sin(PI * q) if t > 0.0 else 0.6
				ci.draw_polyline(pts, Pal.heat(0.55 * fade * a, 1.2), 1.4, true)
			# the shimmer over it is drawn by the caller's shader (CodexFx.shimmer)
		"fire":
			# open fire: three tongues of flame flickering over a glowing bed, embers rising
			var base := r.end.y - s * 0.16
			var fl := 0.8 + 0.2 * sin(t * 9.0) * sin(t * 3.7)
			_glow(ci, Vector2(cen.x, base), minf(s * 0.5, (r.end.y - base) * 2.5), Color(1.0, 0.35, 0.1, 0.22 * fl * a))
			ci.draw_rect(Rect2(cen.x - s * 0.36, base, s * 0.72, 2.0), Pal.heat(0.9 * a, 1.3))
			for i in 3:
				var cx := cen.x + (i - 1) * s * 0.2
				var hgt := s * (0.42 if i == 1 else 0.3) * (0.85 + 0.15 * sin(t * (7.0 + i) + i * 2.1))
				var sway := sin(t * (3.0 + i * 0.7) + i) * s * 0.04
				for layer in 2:
					var k := 1.0 if layer == 0 else 0.55
					var wdt := s * 0.1 * k * (1.3 if i == 1 else 1.0)
					var tip := Vector2(cx + sway, base - hgt * k)
					var pts := PackedVector2Array([Vector2(cx - wdt, base), Vector2(cx - wdt * 0.8, base - hgt * k * 0.35), tip, Vector2(cx + wdt * 0.8, base - hgt * k * 0.4), Vector2(cx + wdt, base)])
					ci.draw_colored_polygon(pts, Color(1.0, 0.42, 0.12, 0.85 * a) if layer == 0 else Color(1.0, 0.85, 0.55, 0.9 * a))
			for i in 6:
				var q := fract(t * 0.6 + i * 0.173)
				var ex := cen.x + sin(i * 4.3 + t * 2.0) * s * 0.3
				ci.draw_circle(Vector2(ex, base - q * s * 0.6), 1.1, Pal.heat((1.0 - q) * a, 1.4))
		"gas":
			# a nozzle at the centre; rings spreading out and fading, specks carried with them

			for i in 4:
				var q := fract(t / 2.4 + i / 4.0) if t > 0.0 else 0.25 * i
				var rad := s * (0.08 + 0.4 * q)
				ci.draw_arc(cen, rad, 0, TAU, 40, Pal.tint(Pal.AIR, (1.0 - q) * 0.85 * a, 1.0), 1.2, true)
			for i in 10:
				var ang := i * TAU / 10.0 + 0.3 * sin(i * 7.1)
				var q2 := fract(t / 3.1 + i * 0.137) if t > 0.0 else 0.4
				ci.draw_circle(cen + Vector2.from_angle(ang) * s * (0.1 + 0.36 * q2), 1.2, Pal.tint(Pal.AIR, (1.0 - q2) * 0.9 * a, 1.0))
			ci.draw_circle(cen, s * 0.07, Color(0.06, 0.07, 0.08, a))
			ci.draw_arc(cen, s * 0.07, 0, TAU, 20, col, 1.4, true)
			_glow(ci, cen, s * 0.16, Pal.tint(Pal.AIR, 0.25 * a, 1.0))
		"cable":
			# a cable slung between two terminals; current runs along it as bright pulses
			var a0 := cen + Vector2(-s * 0.42, s * 0.12)
			var d0 := cen + Vector2(s * 0.42, -s * 0.06)
			var pts := _curve(a0, cen + Vector2(-s * 0.15, -s * 0.38), cen + Vector2(s * 0.1, s * 0.4), d0)
			ci.draw_polyline(pts, Color(0, 0, 0, 0.6 * a), 4.0, true)
			ci.draw_polyline(pts, Pal.tint(Pal.VOLT, 0.55 * a, 0.9), 2.0, true)
			ci.draw_polyline(pts, Pal.tint(Pal.VOLT, 0.25 * a, 1.3), 0.8, true)
			for term in [a0, d0]:
				ci.draw_rect(Rect2(term - Vector2(4, 4), Vector2(8, 8)), Color(0.08, 0.09, 0.1, a))
				ci.draw_rect(Rect2(term - Vector2(4, 4), Vector2(8, 8)), col, false, 1.0)
			for i in 3:
				var q := fract(t * 0.55 + i / 3.0) if t > 0.0 else 0.33 * i + 0.15
				var p := _path(pts, q)
				_glow(ci, p, s * 0.09, Pal.tint(Pal.VOLT, 0.55 * a, 1.4))
				ci.draw_circle(p, 1.8, Color(1, 1, 1, 0.95 * a))
			# now and then a spark at the far terminal
			var sp := fract(t / 2.6)
			if t > 0.0 and sp < 0.12:
				for k in 4:
					var ang := -PI * 0.5 + (k - 1.5) * 0.5 + sin(t * 40.0 + k) * 0.2
					ci.draw_line(d0, d0 + Vector2.from_angle(ang) * s * 0.1 * (1.0 - sp / 0.12), Pal.tint(Pal.VOLT, a, 1.6), 1.0, true)
		"bolt_volt":
			# a bolt of current that jitters and flickers
			var step: float = floor(t / 0.09)
			var pts := PackedVector2Array()
			for k in 6:
				var u := k / 5.0
				var jit: float = sin(step * 12.9898 + k * 78.233) * 43758.5453
				jit = (jit - floor(jit) - 0.5) * s * 0.14 if t > 0.0 else 0.0
				pts.append(cen + Vector2(lerpf(s * 0.06, -s * 0.06, u) + jit * (0.0 if k == 0 or k == 5 else 1.0), lerpf(-s * 0.36, s * 0.36, u)))
			var fl := 0.65 + 0.35 * sin(t * 23.0) * sin(t * 7.0)
			_glow(ci, cen, s * 0.3, Pal.tint(Pal.VOLT, 0.18 * fl * a, 1.2))
			ci.draw_polyline(pts, Pal.tint(Pal.VOLT, 0.35 * a, 1.2), 4.0, true)
			ci.draw_polyline(pts, Pal.tint(Pal.VOLT, fl * a, 1.6), 1.6, true)
		"drop":
			# a drop that wobbles; now and then a small one breaks off and falls
			var wob := sin(t * 3.1) * 0.08
			var rx := s * 0.18 * (1.0 + wob)
			var ry := s * 0.18 * (1.0 - wob)
			var pts := PackedVector2Array()
			for k in 33:
				var ang := k * TAU / 32.0
				pts.append(cen + Vector2(cos(ang) * rx, sin(ang) * ry))
			ci.draw_colored_polygon(pts, Pal.tint(Pal.FLUID, 0.22 * a, 1.0))
			ci.draw_polyline(pts, Pal.tint(Pal.FLUID, 0.9 * a, 1.0), 1.4, true)
			ci.draw_arc(cen + Vector2(-rx * 0.35, -ry * 0.35), s * 0.06, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.5 * a), 1.2, true)
			var fq := fract(t / 2.2)
			ci.draw_circle(cen + Vector2(s * 0.3, -s * 0.2 + fq * s * 0.45), s * 0.05, Pal.tint(Pal.FLUID, (1.0 - fq) * 0.8 * a, 1.0))
		"lock":
			# the shackle lifts a hair and clicks home; the keyhole blinks
			var lift := maxf(0.0, sin(t * 2.0)) * s * 0.03
			var body := Rect2(cen - Vector2(s * 0.18, s * 0.05), Vector2(s * 0.36, s * 0.28))
			ci.draw_rect(body, Color(0.08, 0.09, 0.1, a))
			ci.draw_rect(body, col, false, 1.5)
			ci.draw_arc(cen - Vector2(0, s * 0.05 + lift), s * 0.12, PI, TAU, 14, col, 1.5, true)
			ci.draw_line(cen + Vector2(-s * 0.12, -s * 0.05 - lift), cen + Vector2(-s * 0.12, -s * 0.02), col, 1.5)
			ci.draw_circle(body.get_center(), 2.2, Pal.heat((0.5 + 0.5 * absf(sin(t * 2.0))) * a, 1.2))
		"clamp":
			# the jaws close a little and open again
			var j := (0.5 + 0.5 * sin(t * 1.8)) * s * 0.04
			ci.draw_line(cen + Vector2(-s * 0.3, s * 0.2), cen + Vector2(s * 0.3, s * 0.2), col, 2.0, true)
			ci.draw_line(cen + Vector2(-s * 0.2, s * 0.2), cen + Vector2(-s * 0.1 + j, -s * 0.15), col, 1.5, true)
			ci.draw_line(cen + Vector2(s * 0.2, s * 0.2), cen + Vector2(s * 0.1 - j, -s * 0.15), col, 1.5, true)
			ci.draw_rect(Rect2(cen + Vector2(-s * 0.06, -s * 0.22), Vector2(s * 0.12, s * 0.1)), Pal.tint(Pal.AIR, 0.5 * a, 1.0), false, 1.0)
		"bolt":
			# a hex head turning slowly in its washer
			ci.draw_arc(cen, s * 0.26, 0, TAU, 32, dim, 1.0, true)
			var hx := PackedVector2Array()
			for k in 7:
				hx.append(cen + Vector2.from_angle(k * TAU / 6.0 + t * 0.6) * s * 0.2)
			ci.draw_colored_polygon(hx, Color(0.1, 0.11, 0.12, a))
			ci.draw_polyline(hx, col, 1.5, true)
			ci.draw_arc(cen, s * 0.09, 0, TAU, 16, col, 1.2, true)
		"weld":
			# the bead, and a spark running along it
			var pts := PackedVector2Array()
			for i in 5:
				ci.draw_arc(cen + Vector2((i - 2) * s * 0.1, 0), s * 0.06, 0, PI, 8, col, 1.2, true)
				pts.append(cen + Vector2((i - 2) * s * 0.1, s * 0.03))
			var p := _path(pts, fract(t * 0.4))
			_glow(ci, p, s * 0.12, Pal.heat(0.6 * a, 1.3))
			ci.draw_circle(p, 1.6, Color(1, 0.9, 0.7, a))
		"pipe":
			# a line with what is in it flowing along
			var y1 := cen.y - s * 0.07
			var y2 := cen.y + s * 0.07
			ci.draw_line(Vector2(r.position.x + s * 0.1, y1), Vector2(r.end.x - s * 0.1, y1), Pal.tint(Pal.FLUID, 0.85 * a, 1.0), 1.5, true)
			ci.draw_line(Vector2(r.position.x + s * 0.1, y2), Vector2(r.end.x - s * 0.1, y2), Pal.tint(Pal.FLUID, 0.85 * a, 1.0), 1.5, true)
			var len := r.size.x - s * 0.2
			for i in 6:
				var q := fract(t * 0.5 + i / 6.0)
				var x := r.position.x + s * 0.1 + q * len
				ci.draw_line(Vector2(x, cen.y), Vector2(minf(x + s * 0.06, r.end.x - s * 0.1), cen.y), Pal.tint(Pal.FLUID, 0.6 * a, 1.2), 2.0)
		"cut":
			# the cut line, a cutting spark travelling down it
			ci.draw_line(cen + Vector2(0, -s * 0.38), cen + Vector2(0, s * 0.38), Pal.heat(0.5 * a, 1.0), 1.0, true)
			for i in 6:
				var yy := cen.y - s * 0.35 + i * s * 0.14
				ci.draw_line(Vector2(cen.x - s * 0.06, yy), Vector2(cen.x + s * 0.06, yy), Pal.heat(0.8 * a, 1.0), 1.2, true)
			var sy := cen.y - s * 0.38 + fract(t * 0.35) * s * 0.76
			_glow(ci, Vector2(cen.x, sy), s * 0.1, Pal.heat(0.7 * a, 1.4))
		"hull":
			# a plate; its rivets catch the light one after another
			var pr := Rect2(cen - Vector2(s * 0.4, s * 0.12), Vector2(s * 0.8, s * 0.24))
			ci.draw_rect(pr, Color(0.09, 0.1, 0.11, a))
			ci.draw_rect(pr, col, false, 1.4)
			var lit := int(fract(t * 0.5) * 6.0) if t > 0.0 else -1
			for i in 6:
				var x := pr.position.x + pr.size.x * (i + 0.5) / 6.0
				var c2 := Pal.tint(Pal.AIR, a, 1.4) if i == lit else col
				ci.draw_circle(Vector2(x, pr.position.y + 4), 1.3, c2)
				ci.draw_circle(Vector2(x, pr.end.y - 4), 1.3, c2)
		"frame":
			# a truss; a load pulse running along its diagonals
			var y0 := cen.y - s * 0.15
			var y1 := cen.y + s * 0.15
			ci.draw_line(Vector2(cen.x - s * 0.4, y0), Vector2(cen.x + s * 0.4, y0), col, 1.6, true)
			ci.draw_line(Vector2(cen.x - s * 0.4, y1), Vector2(cen.x + s * 0.4, y1), col, 1.6, true)
			var pts := PackedVector2Array()
			for i in 4:
				var x0 := cen.x - s * 0.4 + i * s * 0.2
				ci.draw_line(Vector2(x0, y1), Vector2(x0 + s * 0.2, y0), col, 1.1, true)
				pts.append(Vector2(x0, y1))
				pts.append(Vector2(x0 + s * 0.2, y0))
			_glow(ci, _path(pts, fract(t * 0.3)), s * 0.08, Pal.tint(Pal.AIR, 0.5 * a, 1.3))
		"film":
			for i in 3:
				var yy := cen.y - s * 0.2 + i * s * 0.2
				var pts := PackedVector2Array()
				for k in 9:
					var u := k / 8.0
					pts.append(Vector2(cen.x - s * 0.4 + u * s * 0.8, yy + sin(u * 6.0 + t * 1.6 + i) * s * 0.04))
				ci.draw_polyline(pts, Pal.ink((0.65 - i * 0.12) * a), 1.0, true)
		"door":
			var slide := (0.5 + 0.5 * sin(t * 0.9)) * s * 0.03
			ci.draw_rect(Rect2(cen - Vector2(s * 0.18, s * 0.32), Vector2(s * 0.36, s * 0.64)), dim, false, 1.0)
			ci.draw_rect(Rect2(cen - Vector2(s * 0.18 - slide, s * 0.32), Vector2(s * 0.36, s * 0.64)), col, false, 1.5)
			ci.draw_line(cen + Vector2(s * 0.1 + slide, -s * 0.04), cen + Vector2(s * 0.1 + slide, s * 0.06), col, 2.0, true)
			ci.draw_line(cen + Vector2(0, -s * 0.42), cen + Vector2(0, -s * 0.36), Pal.heat((0.4 + 0.6 * float(fract(t) < 0.5)) * a, 1.2), 2.0, true)
		"valve":
			ci.draw_line(cen + Vector2(-s * 0.42, 0), cen + Vector2(-s * 0.16, 0), col, 1.4, true)
			ci.draw_line(cen + Vector2(s * 0.16, 0), cen + Vector2(s * 0.42, 0), col, 1.4, true)
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(-s * 0.16, -s * 0.1), cen, cen + Vector2(-s * 0.16, s * 0.1)]), col)
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(s * 0.16, -s * 0.1), cen, cen + Vector2(s * 0.16, s * 0.1)]), col)
			ci.draw_line(cen, cen + Vector2(0, -s * 0.22), col, 1.2, true)
			var wc := cen + Vector2(0, -s * 0.26)
			ci.draw_arc(wc, s * 0.08, 0, TAU, 16, col, 1.2, true)
			for k in 3:
				var ang := t * 0.8 + k * TAU / 3.0
				ci.draw_line(wc, wc + Vector2.from_angle(ang) * s * 0.08, col, 1.0, true)
		"switch":
			var on := fract(t / 3.0) < 0.5
			ci.draw_rect(Rect2(cen - Vector2(s * 0.14, s * 0.22), Vector2(s * 0.28, s * 0.44)), col, false, 1.4)
			ci.draw_line(cen, cen + Vector2(s * (0.08 if on else -0.08), -s * 0.18), Pal.heat(0.85 * a, 1.0), 2.4, true)
			ci.draw_circle(cen, 2.0, col)
			ci.draw_circle(cen + Vector2(0, s * 0.15), 2.0, Hmi.ok_col(a) if on else dim)
		"probe":
			ci.draw_arc(cen + Vector2(0, s * 0.08), s * 0.26, PI * 1.15, TAU - PI * 0.15, 24, col, 1.4, true)
			var ang := -PI * 0.5 + 0.55 + 0.25 * sin(t * 1.7) + 0.05 * sin(t * 9.0)
			ci.draw_line(cen + Vector2(0, s * 0.08), cen + Vector2(0, s * 0.08) + Vector2.from_angle(ang) * s * 0.22, Pal.heat(0.85 * a, 1.0), 1.6, true)
			ci.draw_circle(cen + Vector2(0, s * 0.08), 2.0, col)
		"socket":
			ci.draw_arc(cen, s * 0.22, 0, TAU, 28, col, 1.4, true)
			var gp := 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 2.4))
			for sx in [-1, 1]:
				_glow(ci, cen + Vector2(sx * s * 0.07, 0), s * 0.06, Pal.tint(Pal.VOLT, 0.4 * gp * a, 1.3))
				ci.draw_line(cen + Vector2(sx * s * 0.07, -s * 0.06), cen + Vector2(sx * s * 0.07, s * 0.06), col, 2.0, true)
		"ice":
			var pts := PackedVector2Array([cen + Vector2(-s * 0.3, s * 0.2), cen + Vector2(-s * 0.2, -s * 0.25), cen + Vector2(s * 0.15, -s * 0.3), cen + Vector2(s * 0.35, s * 0.05), cen + Vector2(s * 0.1, s * 0.3)])
			ci.draw_colored_polygon(pts, Pal.tint(Pal.AIR, 0.18 * a, 1.0))
			pts.append(pts[0])
			ci.draw_polyline(pts, Pal.tint(Pal.AIR, 0.85 * a, 1.0), 1.3, true)
			for k in 5:
				var tw := maxf(0.0, sin(t * 2.0 + k * 1.7))
				var p := cen + Vector2(sin(k * 3.1) * s * 0.18, cos(k * 2.3) * s * 0.16)
				ci.draw_line(p - Vector2(2, 0) * tw, p + Vector2(2, 0) * tw, Color(1, 1, 1, tw * a), 1.0)
				ci.draw_line(p - Vector2(0, 2) * tw, p + Vector2(0, 2) * tw, Color(1, 1, 1, tw * a), 1.0)
		"clock":
			ci.draw_arc(cen, s * 0.28, 0, TAU, 32, col, 1.4, true)
			for k in 12:
				var ang := k * TAU / 12.0
				ci.draw_line(cen + Vector2.from_angle(ang) * s * 0.24, cen + Vector2.from_angle(ang) * s * 0.27, dim, 1.0)
			ci.draw_line(cen, cen + Vector2.from_angle(-PI * 0.5 + t * 0.35) * s * 0.2, col, 1.6, true)
			ci.draw_line(cen, cen + Vector2.from_angle(-PI * 0.5 + t * 3.0) * s * 0.24, Pal.heat(0.8 * a, 1.0), 1.0, true)
		"free":
			var dx := sin(t * 0.8) * s * 0.03
			ci.draw_rect(Rect2(cen - Vector2(s * 0.08 - dx, s * 0.12), Vector2(s * 0.3, s * 0.22)), col, false, 1.4)
			for i in 3:
				var q := fract(t * 0.7 + i / 3.0)
				var yy := cen.y - s * 0.07 + i * s * 0.07
				ci.draw_line(Vector2(cen.x - s * 0.4 + q * s * 0.1, yy), Vector2(cen.x - s * 0.15 + q * s * 0.05, yy), Pal.ink((0.6 - i * 0.15) * (1.0 - q * 0.5) * a), 1.0, true)
		"furnace":
			var fl := 0.7 + 0.3 * sin(t * 6.0) * sin(t * 2.3)
			ci.draw_rect(Rect2(cen - Vector2(s * 0.22, s * 0.18), Vector2(s * 0.44, s * 0.36)), col, false, 1.4)
			_glow(ci, cen + Vector2(0, s * 0.07), s * 0.2, Pal.heat(0.3 * fl * a, 1.3))
			ci.draw_rect(Rect2(cen + Vector2(-s * 0.14, s * 0.02), Vector2(s * 0.28, s * 0.1)), Pal.heat(fl * a, 1.3))
			ci.draw_line(cen + Vector2(-s * 0.3, -s * 0.3), cen + Vector2(s * 0.3, -s * 0.3), col, 1.0, true)
		"mouth":
			ci.draw_polyline(PackedVector2Array([cen + Vector2(-s * 0.36, -s * 0.2), cen + Vector2(-s * 0.16, s * 0.18), cen + Vector2(s * 0.16, s * 0.18), cen + Vector2(s * 0.36, -s * 0.2)]), col, 1.6, true)
			var q := fract(t * 0.6)
			var ay := -s * 0.34 + q * s * 0.3
			ci.draw_line(cen + Vector2(0, ay), cen + Vector2(0, ay + s * 0.2), Pal.tint(Pal.FLUID, (1.0 - q * 0.6) * 0.85 * a, 1.0), 1.6, true)
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(-s * 0.06, ay + s * 0.16), cen + Vector2(s * 0.06, ay + s * 0.16), cen + Vector2(0, ay + s * 0.24)]), Pal.tint(Pal.FLUID, 0.85 * a, 1.0))
		"field":
			for i in 3:
				var q := fract(t * 0.5 + i / 3.0) if t > 0.0 else i / 3.0
				ci.draw_arc(cen + Vector2(s * 0.4, 0), s * (0.15 + q * 0.35), PI * 0.7, PI * 1.3, 14, Pal.tint(Pal.AIR, (1.0 - q) * 0.85 * a, 1.0), 1.2, true)
			ci.draw_line(cen + Vector2(-s * 0.35, 0), cen + Vector2(s * 0.05, 0), col, 1.4, true)
			ci.draw_colored_polygon(PackedVector2Array([cen + Vector2(-s * 0.4, 0), cen + Vector2(-s * 0.3, -s * 0.06), cen + Vector2(-s * 0.3, s * 0.06)]), col)
		"plan":
			var pr := Rect2(cen - Vector2(s * 0.34, s * 0.22), Vector2(s * 0.68, s * 0.44))
			ci.draw_rect(pr, Pal.tint(Pal.AIR, 0.7 * a, 1.0), false, 1.2)
			ci.draw_line(cen + Vector2(-s * 0.2, -s * 0.22), cen + Vector2(-s * 0.2, s * 0.22), Pal.tint(Pal.AIR, 0.4 * a, 1.0), 1.0, true)
			ci.draw_line(cen + Vector2(-s * 0.34, 0), cen + Vector2(s * 0.34, 0), Pal.tint(Pal.AIR, 0.4 * a, 1.0), 1.0, true)
			ci.draw_line(cen + Vector2(s * 0.08, -s * 0.22), cen + Vector2(s * 0.08, s * 0.22), Pal.tint(Pal.AIR, 0.4 * a, 1.0), 1.0, true)
			scan(ci, pr, a, t)
		_:
			var b := 1.0 + 0.04 * sin(t * 1.5)
			ci.draw_rect(Rect2(cen - r.size * 0.25 * b, r.size * 0.5 * b), col, false, 1.2)
