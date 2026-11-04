extends Node
const FastDraw = preload("res://scripts/fast_draw.gd")
# A shut-down reactor still hot with radiation (exotic batch, NR-95 "Hearth": "the
# work is not taking the reactor apart but lifting the 5.6 t shield in front of the
# core first, and working in its shadow"). A ship file's "reactor":
#   {"core": piece, "rate": mSv/h at 1 m, "shields": [pieces that stop it],
#    "limit": the drone's dose (mSv) that faults its electronics,
#    "drums": {control drum: its mechanical lock}, "petals": [radiator petals],
#    "safe": °C the core must be under before the petals fold}
#   The core's dose rate falls with the square of the distance, and anything on a
#   shield's far side is in its shadow (a hundredth of it) — wherever the shield is,
#   on its mounts or hanging from the crane. The drone soaks it up: past the limit
#   its electronics fault (it is hurt) and the count starts again. A dose probe
#   reads the rate where it sits.
#   The core lifted with a control drum still unlocked: the drum slips, a burst of
#   dose over everything near. A radiator petal taken off while the core
#   (scripts/furnace.gd, its decay heat) is still over "safe" deforms.
#   A fission core touched by the beam detonates (user 2026-10-27, "如果堆芯被激光弄坏的话，
#   会直接发生核爆"; then, the 3-2-1 count in the core's heart and the criticality before it not
#   felt in play: "你干脆直接改成直接核爆吧"): the first cut into it, anywhere, and scripts/nuke.gd
#   takes over. Any ship: the core of a "reactor" section, and every piece that is a fission
#   reactor by its name (PT-34's, ARK-01's main and secondary). The beam close to one warns.
# Saved: the drone's dose, which drums slipped.

const SHADOW := 0.01
const TIME_K := 1.0 / 30.0     # a game second soaks up two minutes' dose
const SLIP_DOSE := 120.0
const NEAR := 1.5              # m: the beam this close to a core warns
# what a fission reactor is called in the ship files (MF-126's furnace core is not one)
const NUCLEAR := ["p_ntr_core", "p_reactor_core", "p_ark_secondary_reactor", "p_reactor"]

var game
var world
var cfg := {}
var dose := 0.0
var slipped := false
var _warned := false
var _petals_hot := {}
var nuked := false
var cores: Array = []          # every fission core aboard
var _near_t := -99.0
var _told := false          # 117 号 (Q3 A): the beam's warning said once; after that the mark flashes
var _warn_k := 0.0
var mark: Node2D
var glow: Node2D              # the breathing glow under the mark: the only part redrawn every frame
var _mt := 0.0
var _mark_key := []           # zoom and where the cores are, as the mark was last drawn


func setup(g, ship: Dictionary) -> void:
	game = g
	world = g.world
	cfg = ship.get("reactor", {})
	for id in world.order:
		var p = world.pieces[id]
		if _nuclear(p):
			cores.append(p)
	# user 2026-10-27: "I can't see where its reactor is" — far out the equipment art fades and
	# the core was a plain box: every core carries its radiation mark and its name at every zoom
	if not cores.is_empty():
		glow = Node2D.new()
		glow.z_index = 9
		glow.z_as_relative = false
		glow.draw.connect(_draw_glow)
		world.add_child(glow)
		mark = Node2D.new()
		mark.z_index = 9
		mark.z_as_relative = false
		mark.draw.connect(_draw_mark)
		world.add_child(mark)


func _nuclear(q) -> bool:
	return (cfg.has("core") and (q.tag == str(cfg.core) or str(q.get_meta("origin", "")) == str(cfg.core))) or str(q.name_key) in NUCLEAR


func _process(dt: float) -> void:
	if mark != null:
		_mt += dt
		glow.queue_redraw()
		# 60 FPS (2026-10-27): the trefoil and its two lines of text again only when the zoom or a
		# core moved (all of it every frame was 0.3 ms)
		_warn_k = maxf(0.0, _warn_k - dt / 1.6)
		var key: Array = [snappedf(game.cam_zoom(), 0.0001), nuked, snappedf(_warn_k, 0.05)]
		for c in cores:
			key.append(Vector2.INF if c.gone else world.frame(c) * Geom.centroid(c.poly))
		if key != _mark_key:
			_mark_key = key
			mark.queue_redraw()
	if not cores.is_empty() and game != null and game.state == "play" and not game.paused_sim and not game.menu_open:
		_watch_beam()


# the trefoil and the name over each core, a fixed size on the screen; a glow breathing with
# the dose rate; under it, what the beam would do
func _draw_glow() -> void:
	var tex: Texture2D = game.fx.glow_tex if game != null and game.fx != null else null
	if tex == null or nuked:
		return
	var r := 18.0 / maxf(0.02, game.cam_zoom())
	var k := 0.5 + 0.5 * sin(_mt * 2.4)
	var hot := Pal.heat(0.9, 1.6)
	for c in cores:
		if c.gone:
			continue
		var at: Vector2 = world.frame(c) * Geom.centroid(c.poly)
		var gr := r * (2.6 + 0.6 * k)
		glow.draw_texture_rect(tex, Rect2(at - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(hot.r, hot.g, hot.b, 0.12 + 0.08 * k))


func _draw_mark() -> void:
	if game == null or nuked:
		return
	var z: float = maxf(0.02, game.cam_zoom())
	var s := 1.0 / z
	var r := 18.0 * s
	var hot := Pal.heat(0.9, 1.6)
	var font: Font = game.hud.font if game.hud != null else ThemeDB.fallback_font
	for c in cores:
		if c.gone:
			continue
		var at: Vector2 = world.frame(c) * Geom.centroid(c.poly)
		# the trefoil: three blades round a hub
		FastDraw.circle(mark, at, r * 1.15, Color(0.03, 0.032, 0.036, 0.75))
		for i in 3:
			var a0 := -PI / 2.0 + i * TAU / 3.0 - PI / 6.0
			var pts := PackedVector2Array([at + Vector2.from_angle(a0) * r * 0.32])
			for kk in 9:
				pts.append(at + Vector2.from_angle(a0 + PI / 3.0 * kk / 8.0) * r)
			pts.append(at + Vector2.from_angle(a0 + PI / 3.0) * r * 0.32)
			FastDraw.poly(mark, pts, hot)
		FastDraw.circle(mark, at, r * 0.2, hot)
		FastDraw.arc(mark, at, r * 1.15, 0.0, TAU, 32, Pal.ink(0.8), 1.4 * s, true)
		var txt := ("反应堆 CORE · %.0f mSv/h（1 m 处）" if Txt.zh else "REACTOR CORE · %.0f mSv/h AT 1 m") % float(cfg.get("rate", 3200.0)) if c == _core() else ("反应堆 REACTOR" if Txt.zh else "REACTOR")
		var warn := "激光切到即核爆" if Txt.zh else "THE BEAM DETONATES IT"
		mark.draw_set_transform(at + Vector2(r * 1.4, -r * 0.4), 0.0, Vector2(s, s))
		var w := maxf(font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, font.get_string_size(warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
		mark.draw_rect(Rect2(Vector2(-6, -16), Vector2(w + 12, 42)), Color(0.03, 0.032, 0.036, 0.85))
		mark.draw_string(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Pal.ink(0.92))
		# the beam close: the warning line flares instead of a second sentence over the picture
		if _warn_k > 0.0:
			var ww := font.get_string_size(warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			mark.draw_rect(Rect2(Vector2(-3, 6), Vector2(ww + 6, 19)), Color(1.6, 0.3, 0.22, 0.35 * _warn_k))
		mark.draw_string(font, Vector2(0, 20), warn, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.6, 0.3, 0.22, 0.95).lerp(Color(2.4, 2.2, 2.0, 1.0), 0.6 * _warn_k))
		mark.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# the beam close to a core: the warning, once every few seconds
func _watch_beam() -> void:
	var tl = game.tools
	if nuked or tl == null or not tl.cutting:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _near_t < 2.5:
		return
	var f: Vector2 = tl.front
	for q in cores:
		if q.gone:
			continue
		var lp: Vector2 = world.frame(q).affine_inverse() * f
		if Geometry2D.is_point_in_polygon(lp, q.poly) or Geom.dist_to_boundary(lp, q.poly) < NEAR * Geom.M:
			_near_t = now
			_warn_k = 1.0
			if not _told:
				_told = true
				game.say("core_near", f)
			game.sfx.play("warn")
			return


# the beam into a fission core: scripts/nuke.gd takes it from here
func detonate(p) -> void:
	if nuked:
		return
	nuked = true
	game.incident("core_detonation", str(p.tag))
	game.start_nuke(world.frame(p) * Geom.centroid(p.poly))


func on_cut(p) -> void:
	if not nuked and _nuclear(p):
		detonate(p)


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"dose": dose, "slipped": slipped}


func load_state(d: Dictionary) -> void:
	dose = float(d.get("dose", 0.0))
	slipped = bool(d.get("slipped", false))


func _core():
	var p = world.tag(cfg.get("core", ""))
	return p if p != null and not p.gone else null


# the dose rate (mSv/h) at a point (px)
func rate_at(pos: Vector2) -> float:
	var c = _core()
	if c == null:
		return 0.0
	var src: Vector2 = world.frame(c) * Geom.centroid(c.poly)
	var r := maxf(1.0, src.distance_to(pos) / Geom.M)
	var k: float = float(cfg.get("rate", 3200.0)) / (r * r)
	if _shadowed(src, pos):
		k *= SHADOW
	return k


func _shadowed(a: Vector2, b: Vector2) -> bool:
	var polys: Array = []
	for t in cfg.get("shields", []):
		var p = world.tag(str(t))
		if p != null and not p.gone:
			polys.append(world.frame(p) * p.poly)
	if polys.is_empty():
		return false
	var n := int(a.distance_to(b) / (0.4 * Geom.M)) + 1
	for i in range(1, n):
		var q := a.lerp(b, float(i) / n)
		for pl in polys:
			if Geometry2D.is_point_in_polygon(q, pl):
				return true
	return false


# what a dose probe reads (mSv/h)
func probe(c) -> float:
	return rate_at(world.ctrl_world(c))


func _physics_process(dt: float) -> void:
	if not active() or game == null or game.paused_sim or game.state != "play":
		return
	if game.drone == null or not game.drone.alive:
		return
	dose += rate_at(game.drone.global_position) * dt * TIME_K
	var lim: float = float(cfg.get("limit", 250.0))
	if dose > lim * 0.5 and not _warned:
		_warned = true
		game.say("dose_warn", game.drone.global_position, "%d" % int(dose))
	if dose > lim:
		dose = 0.0
		_warned = false
		game.hurt_drone(20.0, game.drone.global_position, "dose", "dose", 1.0)
		game.incident("dose_fault", "%d" % int(lim))
		game.say("dose_fault", game.drone.global_position, "")
	# the decay heat, as the petals feel it
	var hot: bool = game.furnace != null and game.furnace.active() and game.furnace.T > float(cfg.get("safe", 60.0))
	for t in cfg.get("petals", []):
		_petals_hot[t] = hot


func on_freed(b) -> void:
	if not active():
		return
	for q in b.pieces:
		if q.tag == cfg.get("core", "") and not slipped:
			var loose: Array = []
			for d in cfg.get("drums", {}):
				if not game.sys.on(str(cfg.drums[d])):
					loose.append(d)
			if not loose.is_empty():
				slipped = true
				var at: Vector2 = world.frame(q) * Geom.centroid(q.poly)
				for d in loose:
					var dp = world.tag(str(d))
					if dp != null and not dp.gone and dp.intact:
						game._dent(dp, minf(dp.cond, 0.5), "dv_drum_slip")
				if game.drone.global_position.distance_to(at) < 25.0 * Geom.M:
					dose += SLIP_DOSE
				game.incident("drum_slip", ",".join(loose))
				game.say("drum_slip", at, q.tag)
		if (cfg.get("petals", []) as Array).has(q.tag) and _petals_hot.get(q.tag, false) and q.intact:
			var before: float = q.cond
			game._dent(q, minf(q.cond, 0.5), "dv_petal_hot")
			game.incident("petal_hot", q.tag)
			game.say("petal_hot", world.frame(q) * Geom.centroid(q.poly), q.tag)
			game.note_loss("loss_petal_hot", q.tag, (before - q.cond) * q.value)
