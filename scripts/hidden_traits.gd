class_name HiddenTraits
extends Node2D
# 认真拆有奖励, 方向四 (design/认真拆有奖励_设计稿_20261111.md §6): a machine measured with the meter may
# show something its outside did not. Rolled once when the ship comes in, from the contract's seed and
# the machine's own name, so neither a reload nor a second measurement rolls it again; seen only once
# it has been measured (an orange ✦ on it then — no words on the work).
#   rare    a rare model: worth 1.6 times as much (taken whole into the equipment mouth)
#   spare   a spares box inside: the wrench opens its cover (nothing left in it) and the box comes out
#   board   a valuable board inside (electrical machines only): the same, and the machine must be dead —
#           opened live, an arc fries the board
#   plate   a maker's plate: into the book (no money)
# Not measured, nothing is lost: the machine sells as it always did. A mishap on it or a cut into it
# ruins what was inside. The training course, the exam and the belt have none.

static var ON := true

const MIN_VALUE := 1500.0
const P_RARE := 0.04
const P_SPARE := 0.06
const P_BOARD := 0.05
const P_PLATE := 0.03
const RARE_K := 1.6
const SPARE_SHARE := [0.08, 0.15]
const BOARD_SHARE := [0.12, 0.25]
const ITEM_MIN := 300.0
const ITEM_MAX := 6000.0
const OPEN_T := 1.2            # s the wrench takes over the cover
# placeholders: the owner writes the makers and the plates' words
const MAKERS := ["MAKER-A", "MAKER-B", "MAKER-C", "MAKER-D"]

var game
var prof_us := 0             # µs this node spent this run in _draw / _process / _physics_process (tests/clean_run_perf.gd)
var traits := {}               # piece id (str) -> {type, revealed, opened, ruined, worth, maker}
var found: Array = []          # [type, tag] found this job (the settlement's band)


static func w(zh: String, en: String) -> String:
	return zh if Txt.zh else en


func setup(g) -> void:
	game = g
	z_index = 55
	roll()


func active() -> bool:
	return ON and game != null and game.clean != null and game.clean.active()


func roll() -> void:
	traits = {}
	if not active():
		return
	var seed0 := int(game.job.get("variant", 0)) if not game.job.is_empty() else 0
	for id in game.world.order:
		var p = game.world.pieces[id]
		if p.cls != "equip" or not p.intact or not p.scope or p.gone or float(p.value) < MIN_VALUE:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|%d|%s" % [game.ship_id, seed0, p.key if p.key != "" else p.tag])
		var x := rng.randf()
		var t := ""
		if x < P_RARE:
			t = "rare"
		elif x < P_RARE + P_SPARE:
			t = "spare"
		elif x < P_RARE + P_SPARE + P_BOARD:
			t = "board" if game.sys.electric_piece(p) else ""
		elif x < P_RARE + P_SPARE + P_BOARD + P_PLATE:
			t = "plate"
		if t == "":
			continue
		var worth := 0.0
		match t:
			"spare": worth = clampf(float(p.value) * rng.randf_range(SPARE_SHARE[0], SPARE_SHARE[1]), ITEM_MIN, ITEM_MAX)
			"board": worth = clampf(float(p.value) * rng.randf_range(BOARD_SHARE[0], BOARD_SHARE[1]), ITEM_MIN, ITEM_MAX)
			"rare": worth = float(p.value) * (RARE_K - 1.0)
		traits[str(p.id)] = {"type": t, "revealed": false, "opened": false, "ruined": false, "worth": snappedf(worth, 10.0),
			"maker": MAKERS[rng.randi() % MAKERS.size()]}


func of(p):
	return traits.get(str(p.id)) if p != null else null


# ---------------------------------------------------------------- the meter (game.do_measure on a piece)

func on_measure(p) -> void:
	var tr = of(p)
	if tr == null or tr.revealed or tr.ruined:
		return
	tr.revealed = true
	var at: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
	match str(tr.type):
		"rare":
			# what it is worth now that it is known for what it is
			p.value = float(p.value) * RARE_K
			game.clean.base_value += float(tr.worth)
			_book("rare", p)
		"plate":
			_book("plate", p, str(tr.maker))
	found.append([str(tr.type), str(p.tag)])
	game.say("ht_" + str(tr.type), at + Vector2(0, -40))
	game.sfx.play("reveal", at)
	game.fx.ring(at, 6.0, 60.0, 0.5, Charcoal.accent(0.9), 1.6)
	queue_redraw()


# a line for the meter's inspect readout ("" when nothing has been found)
func inspect_line(p) -> String:
	var tr = of(p)
	if tr == null or not tr.revealed:
		return ""
	if tr.ruined:
		return w("内藏物已经毁了", "WHAT WAS INSIDE IS RUINED")
	match str(tr.type):
		"rare": return w("铭牌：稀有型号 · 价值 ×1.6", "PLATE: A RARE MODEL · WORTH ×1.6")
		"spare": return w("里面有备件匣 · 用扳手开盖", "A SPARES BOX INSIDE · OPEN IT WITH THE WRENCH") if not tr.opened else w("备件匣已取出", "SPARES BOX TAKEN OUT")
		"board": return w("里面有值钱的电路板 · 断电后用扳手开盖", "A VALUABLE BOARD INSIDE · DEAD FIRST, THEN THE WRENCH") if not tr.opened else w("电路板已取出", "BOARD TAKEN OUT")
		"plate": return w("制造商铭牌：%s", "MAKER'S PLATE: %s") % str(tr.maker)
	return ""


# ---------------------------------------------------------------- the wrench: opening the cover

# a measured machine with something to take out of it (the wrench's target, scripts/tools.gd)
func can_open(p) -> bool:
	var tr = of(p)
	return tr != null and tr.revealed and not tr.opened and not tr.ruined and str(tr.type) in ["spare", "board"]


# why the cover will not come off now ("" when it will)
func open_block(p) -> String:
	if p.body == null:
		return "ht_free_first"
	var k: String = game.clean.residual(p)
	match k:
		"batt", "cap": return "ht_discharge_first"
		"gas": return "ht_vent_first"
		"liq": return "ht_drain_first"
		"hard": return "ht_hazard"
	return ""


func open(p) -> bool:
	var tr = of(p)
	if not can_open(p):
		return false
	var at: Vector2 = game.world.frame(p) * Geom.centroid(p.poly)
	var why := open_block(p)
	if why != "":
		game.say(why, at + Vector2(0, -40))
		game.sfx.play("deny")
		return false
	tr.opened = true
	queue_redraw()
	# a board opened live: an arc, and the board is scrap
	if str(tr.type) == "board" and game.sys.piece_volts(p) > 30.0:
		tr.ruined = true
		for i in 4:
			game.fx.arc(at, at + Vector2.from_angle(randf() * TAU) * randf_range(30, 70), randf_range(0.15, 0.3), 0.7)
		game.sfx.play("zap_small", at)
		game.say("ht_board_fried", at + Vector2(0, -40))
		return true
	game.sfx.play("hatch", at)
	_spawn(p, tr, at)
	_book(str(tr.type), p)
	return true


# the box (or the board) out of it: a small loose machine of its own, safe to carry
func _spawn(p, tr: Dictionary, at: Vector2) -> void:
	var spare: bool = str(tr.type) == "spare"
	var sz := Vector2(0.55, 0.4) * Geom.M if spare else Vector2(0.5, 0.32) * Geom.M
	var out: Vector2 = (at - game.drone.global_position).normalized()
	if not out.is_finite() or out == Vector2.ZERO:
		out = Vector2.UP
	var c := at + out * 0.9 * Geom.M
	var poly := PackedVector2Array([c + Vector2(-sz.x, -sz.y) * 0.5, c + Vector2(sz.x, -sz.y) * 0.5, c + Vector2(sz.x, sz.y) * 0.5, c + Vector2(-sz.x, sz.y) * 0.5])
	var tag := "%s-%s" % [str(p.tag) if p.tag != "" else "X", "SP" if spare else "PCB"]
	var q = game.world.add_piece("equip", poly, {"key": tag, "tag": tag, "cls": "equip", "mass": 0.05 if spare else 0.02,
		"value": float(tr.worth), "cond": 1.0, "name_key": "p_ark_spares_box" if spare else "p_dc_tray", "fragile": 0.2, "scope": true})
	game.world.make_body([q], null)
	if q.body != null:
		q.body.linear_velocity = out * 70.0 + p.body.linear_velocity * 0.5
		q.body.angular_velocity = randf_range(-1.5, 1.5)
	game.clean.cond0[str(q.id)] = 1.0
	game.clean.base_value += float(q.value)
	game.clean.whole_n += 1
	game.fx.ring(c, 4.0, 40.0, 0.4, Charcoal.accent(0.9), 1.4)
	game.sfx.play("reveal", c)
	game.say("ht_out_" + str(tr.type), c + Vector2(0, -36))


# ---------------------------------------------------------------- ruined, and the book

func on_ruined(p) -> void:
	var tr = of(p)
	if tr != null and str(tr.type) in ["spare", "board"] and not tr.opened:
		tr.ruined = true
		queue_redraw()


# the career's record (scripts/codex.gd shows it under each machine's entry)
func _book(type: String, p, maker := "") -> void:
	if not Career.usable() or Career.data.is_empty():
		return
	var hb: Dictionary = Career.data.get("hidden_book", {})
	var art: String = Codex.art_of(p)
	var arts: Dictionary = hb.get("arts", {})
	var e: Dictionary = arts.get(art, {})
	e[type] = int(e.get(type, 0)) + 1
	arts[art] = e
	hb["arts"] = arts
	if maker != "":
		var plates: Dictionary = hb.get("plates", {})
		plates[maker] = int(plates.get(maker, 0)) + 1
		hb["plates"] = plates
	Career.data.hidden_book = hb


static func book_line(art: String) -> String:
	if art == "" or Career.data.is_empty():
		return ""
	var e: Dictionary = Career.data.get("hidden_book", {}).get("arts", {}).get(art, {})
	if e.is_empty():
		return ""
	var parts: Array = []
	for t in ["rare", "spare", "board", "plate"]:
		if int(e.get(t, 0)) > 0:
			parts.append("%s ×%d" % [type_name(t), int(e[t])])
	return w("已发现：", "FOUND: ") + "、".join(parts) if Txt.zh else w("已发现：", "FOUND: ") + ", ".join(parts)


static func type_name(t: String) -> String:
	return {"rare": w("稀有型号", "RARE MODEL"), "spare": w("内藏备件", "SPARES INSIDE"), "board": w("电路板", "BOARD"), "plate": w("铭牌", "MAKER'S PLATE")}.get(t, t)


# ---------------------------------------------------------------- saving

func to_save() -> Dictionary:
	return {"traits": traits, "found": found}


func from_save(d: Dictionary) -> void:
	if d.is_empty():
		return
	traits = d.get("traits", traits)
	found = d.get("found", [])
	queue_redraw()


# ---------------------------------------------------------------- the ✦ on what has been found

var _t := 0.0
func _process(dt: float) -> void:
	var _pt := Time.get_ticks_usec()
	_process_inner(dt)
	prof_us += Time.get_ticks_usec() - _pt


func _process_inner(dt: float) -> void:
	_t += dt
	for k in traits:
		var tr: Dictionary = traits[k]
		if tr.revealed and not tr.ruined and not (tr.opened and str(tr.type) in ["spare", "board"]):
			queue_redraw()
			return


func _draw() -> void:
	var _pt := Time.get_ticks_usec()
	_draw_inner()
	prof_us += Time.get_ticks_usec() - _pt


func _draw_inner() -> void:
	if game == null or game.cam == null:
		return
	var z: float = maxf(0.05, game.cam_zoom())
	for k in traits:
		var tr: Dictionary = traits[k]
		if not tr.revealed or tr.ruined or str(tr.type) == "plate" or (tr.opened and str(tr.type) != "rare"):
			continue
		var p = game.world.pieces.get(int(k))
		if p == null or p.gone:
			continue
		# its own cached bounds' corner, carried by its frame (the whole outline each frame cost too much)
		var bb: Rect2 = p.bb if p.bb.has_area() else Geom.bbox(p.poly)
		var at: Vector2 = game.world.frame(p) * Vector2(bb.end.x, bb.position.y) + Vector2(-4.0, 4.0) / z
		var pulse := 0.75 + 0.25 * sin(_t * 3.0 + float(k.hash() % 7))
		var r := 6.0 / z * (1.0 + 0.12 * pulse)
		var col := Charcoal.accent(0.95 * pulse)
		var cols := PackedColorArray([col, col, col, col])
		# four spikes, each a quad from the centre (a concave star made the renderer triangulate it)
		for i in 4:
			var a := -PI * 0.5 + i * PI * 0.5
			var q := PackedVector2Array([at, at + Vector2.from_angle(a - PI * 0.25) * r * 0.38, at + Vector2.from_angle(a) * r, at + Vector2.from_angle(a + PI * 0.25) * r * 0.38])
			draw_primitive(q, cols, PackedVector2Array())
