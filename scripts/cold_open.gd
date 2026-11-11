extends Node2D
# 开局重做 样片 (design/开局重做_方案_20261110.md, user 2026-11-10: "目前开局不够吸引人" — A the first
# minute or two; B+C a short film, then the controls at once, the first plate cut within 10 s).
# Off by default (ColdOpen.ON). With it on, a new career's belt prologue begins with the film
# (scripts/cold_open_film.gd) instead of the four opening cards and the 13 s belt cut-scene; the
# drone is already at the hulk, the laser in hand, one dashed line across the machinery room's roof
# plate (TOP-2; its aft seam cracked long ago). One stroke and room M's 98 kPa takes the plate off
# for real (the game's own blowout: Systems → Game.on_blowout), the drone knocked back with it —
# so "brake" is the next thing it asks for. Then the prologue goes on as before from its brake
# step (no long flight first). The opening cards stay in the pause menu.
# Narration only as the owner's placeholders (data/台词.txt L_cold_*).

static var ON := true              # the switch (owner 2026-11-10: "ok", the sample signed off)
static var in_tests := false       # a test may play it
static var SHOW_SLOTS := false     # an empty line shows its slot (〔旁白占位 L_cold_n〕), for review shots

const Film = preload("res://scripts/cold_open_film.gd")
const GuideMark = preload("res://scripts/guide_mark.gd")
const CUT_A := Vector2(7.78, -2.95)    # m, hulk-local: the dashed line across TOP-2's fore end
const CUT_B := Vector2(7.78, -1.9)
const CRACK := [Vector2(9.66, -2.4), Vector2(9.48, -2.1)]
const DRONE_AT := Vector2(6.6, -4.5)
const ZOOM := 1.45

var game
var prologue
var phase := "film"          # film → cut → blown → done
var t := 0.0
var phase_t := 0.0
var film = null
var film_t := 0.0            # how long the film ran (the test's timeline)
var cut_at := -1.0           # s from the hand-over to the plate going
var hand_t := -1.0           # game time the controls came
var _blow_seen := 0
var _top = null
var _hidden: Array = []      # the game's own items, not drawn under the film
var _kicked := false
var _fragile := {}           # piece id -> its fragility, held at 0 for the first cut (owner: "免掉")
const VENT := Vector2(8.6, -2.25)     # m, hulk-local: the middle of the plate's gap
const PLATE_V := 9.0                  # m/s the room's air leaves the plate with (98 kPa on ~2 m² of steel)
const KNOCK_V := 6.0                  # m/s the blast pushes the drone away


static func line(id: String) -> String:
	var p: Array = Lines.get_pair(id)
	if p.is_empty():
		return ""
	return str(p[0]) if Txt.zh else str(p[1] if str(p[1]) != "" else p[0])


# a new career out in the belt, the prologue not yet begun, the switch on
static func wants(g) -> bool:
	if not ON or g == null or not g.belt or g.bot != null:
		return false
	if g.testing and not in_tests:
		return false
	if not Career.usable() or Career.data.is_empty():
		return false
	var seen: Dictionary = Career.data.get("seen", {})
	return not seen.has("cold_open") and int(Career.guide_at("prologue")) <= 0


func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func begin(g, pr) -> void:
	game = g
	prologue = pr
	z_index = 40
	z_as_relative = false
	# what it replaces: the four cards (still in the pause menu) and the belt's 13 s cut-scene
	var seen: Dictionary = Career.data.get("seen", {})
	seen["intro"] = true
	seen["belt_prelude"] = true
	Career.data.seen = seen
	if not Career.data.has("permit_day"):
		Career.data.permit_day = int(Shipping.day()) + 1
	Career.save()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup.call_deferred()


func active() -> bool:
	return phase in ["film", "cut"]


func _setup() -> void:
	if game == null or game.world == null:
		return
	_top = prologue._piece("TOP-2")
	# the old crack: the aft seam of the plate let go years ago, only its fore end still holds
	# and the room's lamp hangs on its own cables now (its bolts to the plate rusted through):
	# the plate carries no cable that would hold it in place once it is cut
	var aft = prologue._piece("TOP-3")
	var lamp = prologue._piece("LAMP-M")
	if _top != null and aft != null:
		for j in game.world.joints_of(_top).duplicate():
			if j.a == aft.id or j.b == aft.id or (lamp != null and (j.a == lamp.id or j.b == lamp.id)):
				game.world.kill_joint(j)
		game.world.relink()
	# a dead hulk: its main breaker long open, so the cable run under the roof is cold (the first
	# cut is about the air, not an arc)
	if game.sys != null and game.sys.switch.has("K-T"):
		game.sys.set_switch("K-T", false)
	# owner 2026-11-10 ("免掉"): this first blast costs nothing — the machinery in the room takes no
	# blowout damage and no −$ floats up (Game.on_blowout dents by fragility; it is 0 till it is over)
	for p in game.world.pieces.values():
		if not p.gone and str(p.room) == "M" and p.cls == "equip":
			_fragile[p.id] = p.fragile
			p.fragile = 0.0
	_place()
	# the prologue's card waits till the first cut is done (it showed through the film's last fade)
	if prologue.card != null:
		prologue.card.visible = false
	# 60 FPS: the film covers the screen, so the game under it is not drawn until it shows through
	for c in game.get_children():
		if (c is CanvasItem or c is CanvasLayer) and c.visible:
			c.visible = false
			_hidden.append(c)
	film = Film.new()
	film.show_slots = SHOW_SLOTS
	film.sfx = game.sfx
	film.on_done = _hand_over
	film.on_reveal = _unhide
	game.get_tree().paused = true
	game.prelude_on = true
	game.add_child(film)


func _unspare() -> void:
	for id in _fragile:
		var p = game.world.pieces.get(id)
		if p != null and not p.gone:
			p.fragile = _fragile[id]
	_fragile = {}


func _exit_tree() -> void:
	if game != null and is_instance_valid(game) and game.world != null:
		_unspare()


func _unhide() -> void:
	for c in _hidden:
		if is_instance_valid(c):
			c.visible = true
	_hidden = []


func _xf() -> Transform2D:
	var k = prologue._keel()
	return game.world.frame(k) if k != null else Transform2D.IDENTITY


func _place() -> void:
	prologue._placed = true
	if game.drone != null:
		game.drone.global_position = _xf() * (DRONE_AT * Geom.M)
		game.drone.linear_velocity = Vector2.ZERO
	game.cam_pos = _xf() * (Vector2(7.8, -3.2) * Geom.M)
	game.zoom_now = ZOOM
	game.zoom_override = ZOOM
	if game.tools != null:
		game.tools.set_tool(2, true)


func _hand_over() -> void:
	film_t = film.t if film != null else 0.0
	film = null
	game.prelude_on = false
	game.get_tree().paused = false
	_place()
	phase = "cut"
	phase_t = 0.0
	hand_t = t
	if prologue.card != null:
		prologue.card.visible = false


func tool_allowed(n: int) -> bool:
	return n == 2


# the laser stays in hand through the blast (a button still down must not read as a locked tool)
func holds_tools() -> bool:
	return phase in ["film", "cut", "blown"]


func _quiet() -> void:
	game.messages = game.messages.filter(func(m): return not str(m[0]) in ["tool_locked_use", "tool_locked"])


func _process(dt: float) -> void:
	t += dt
	phase_t += dt
	match phase:
		"cut":
			if prologue.card != null:
				prologue.card.visible = false
			if game.incidents.size() > _blow_seen:
				for i in range(_blow_seen, game.incidents.size()):
					if str(game.incidents[i][1]) == "blowout":
						_blown()
						break
				_blow_seen = game.incidents.size()
			elif _top != null and _top.body != null and phase_t > 0.2 and game.sys.P("M") < 30.0:
				_blown()
		"blown":
			_kick()
			# the moment, slowed: then the view lets go and the prologue asks for the brake
			if phase_t > 1.6:
				game.zoom_override = -1.0
				phase = "done"
				prologue.step = prologue.STEPS.find("brake")
				prologue.step_t = 0.0
				prologue.card.visible = true
				prologue._show()
				_quiet()
				_unspare()
				Career.guide_keep("prologue", prologue.step)
				var seen: Dictionary = Career.data.get("seen", {})
				seen["cold_open"] = true
				Career.data.seen = seen
				Career.save()
	queue_redraw()


func _blown() -> void:
	if phase != "cut":
		return
	phase = "blown"
	cut_at = phase_t
	phase_t = 0.0
	if Txt.slowmo_on and not Txt.no_flash():
		game.slowmo = maxf(game.slowmo, 0.9)
	game.shake(0.6, Vector2(0, -1))
	# the blast reaches the drone: a push, and from then on only its own thrusters stop it
	if game.drone != null:
		var away: Vector2 = game.drone.global_position - _xf() * (VENT * Geom.M)
		game.drone.linear_velocity += away.normalized() * KNOCK_V * Geom.M
	_kick()


# Game.on_blowout gives every loose body in the room one push sized for a hatch's worth of air;
# a whole roof plate over a 98 kPa room leaves faster than that. Once the plate is loose (the
# stroke committed), the rest of what the air does to it: outward and turning.
func _kick() -> void:
	if _kicked or _top == null or _top.body == null:
		return
	_kicked = true
	var b = _top.body
	var out: Vector2 = (_xf().basis_xform(Vector2(0.25, -1.0))).normalized()
	var dv: Vector2 = out * PLATE_V * Geom.M - b.linear_velocity
	if dv.dot(out) > 0.0:
		b.apply_central_impulse(out * dv.dot(out) * b.mass)
	b.angular_velocity += 1.6


func _draw() -> void:
	if game == null or phase == "film" or phase == "done":
		return
	var xf := _xf()
	var z: float = maxf(game.cam_zoom(), 0.02)
	var M := Geom.M
	var a := xf * (CUT_A * M)
	var b := xf * (CUT_B * M)
	if phase == "cut":
		var k := 0.55 + 0.45 * sin(t * 6.0)
		# the line to cut, dashed, the colour of the beam
		var n := 9
		for i in n:
			if i % 2 == 0:
				draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), Pal.heat(0.9 * k, 1.8), 4.0 / z)
		GuideMark.target(self, a.lerp(b, 0.5), z, Pal.heat(0.8, 1.4), t, "", 18.0, 1.0)
		# the old crack, glowing faintly: this plate only holds at one end
		draw_line(xf * (CRACK[0] * M), xf * (CRACK[1] * M), Pal.heat(0.35 + 0.2 * k, 1.2), 2.0 / z)
		# what is behind it: the room's pressure, read off the hulk's own gas
		var p: float = game.sys.P("M")
		var at := xf * (Vector2(9.0, -3.3) * M)
		var fs := 20.0 / z
		draw_line(xf * (Vector2(8.6, -2.25) * M), at + Vector2(-4, 4) / z, Pal.tint(Pal.AIR, 0.7, 1.2), 1.2 / z)
		draw_string(Fonts.get_font("Medium"), at, w("机舱 %d kPa", "ENGINE ROOM %d kPa") % int(round(p)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), Pal.tint(Pal.AIR, 0.95, 1.3))
		# the one thing to do, by the line (the key picture, not a card)
		var tip := w("按住左键，沿虚线切开", "HOLD LEFT MOUSE · CUT ALONG THE LINE")
		if phase_t > 8.0:
			tip += w("  ·  鼠标对准橙色虚线", "  ·  AIM AT THE ORANGE LINE")
		var tp := a + Vector2(-26.0, -16.0) / z
		var font := Fonts.get_font("Medium")
		var tw := font.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
		draw_rect(Rect2(tp + Vector2(-tw - 14.0 / z, -fs - 6.0 / z), Vector2(tw + 24.0 / z, fs + 16.0 / z)), Color(0.02, 0.024, 0.03, 0.8))
		draw_rect(Rect2(tp + Vector2(6.0 / z, -fs - 6.0 / z), Vector2(4.0 / z, fs + 16.0 / z)), UiSkin.ACCENT)
		draw_string(font, tp + Vector2(-tw - 4.0 / z, 0), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), Pal.ink(0.95))
		_slot("L_cold_5", tp + Vector2(-tw * 0.5, -fs - 30.0 / z), z)
	elif phase == "blown":
		_slot("L_cold_6", game.drone.global_position + Vector2(0, -90.0) / z, z)


# the owner's line where it would play; its slot while it is not written (SHOW_SLOTS)
func _slot(id: String, at: Vector2, z: float) -> void:
	var tx := line(id)
	if tx == "":
		if not SHOW_SLOTS:
			return
		tx = "〔台词占位 %s〕" % id
	var fs := int(18.0 / z)
	var font := Fonts.get_font("Medium")
	var tw := font.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at - Vector2(tw * 0.5, 0), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.tint(UiSkin.ACCENT, 0.85) if line(id) == "" else Pal.ink(0.92))
