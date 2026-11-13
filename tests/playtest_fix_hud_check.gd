extends SceneTree
# 2026-11-12 公测反馈: "右上角的当前提示会和什么快捷键展示重叠，导致看不全。"
# The right column's cards (the first ship's coach card, the first-meeting codex card, the
# first-use key card) must stand clear of the function keys top right (scripts/hud_keys.gd), at
# 1280×720, 1600×900 and 1920×1080; the centre card (scripts/hud_center.gd) too.
#   godot --path . --resolution 1600x900 --position -2600,40 -s tests/playtest_fix_hud_check.gd --fixed-fps 60 -- shots 1600_after
#   ... -- shots 1600_before old      (HudKeys.stack off: the old places, expected to fail)
# Test saves only; the pointer is the bot's aim, the clicks the bot's buttons.
const Cap = preload("res://tests/cap.gd")

var g
var fails := 0


func _initialize() -> void:
	Career.path = "user://zp_test_pfhud_career.json"
	SaveGame.path = "user://zp_test_pfhud_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func ok(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _band() -> Rect2:
	return g.hud.keys_band.band_rect() if g.hud.keys_band != null else Rect2()


func _clear(r: Rect2, what: String) -> void:
	var b := _band()
	ok(r.has_area() and b.has_area() and not r.intersects(b), "%s %s clear of the keys %s" % [what, r, b])
	var s: Vector2 = g.hud.size()
	ok(r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= s.x + 0.5 and r.end.y <= s.y + 0.5, "%s whole on the screen (%s)" % [what, s])


func _run() -> void:
	Txt.zh = true
	var args := OS.get_cmdline_user_args()
	var shots := args.has("shots")
	var tag := args[args.find("shots") + 1] if shots and args.size() > args.find("shots") + 1 else "x"
	if args.has("old"):
		preload("res://scripts/hud_keys.gd").stack = false
	print("window ", DisplayServer.window_get_size(), " canvas ", root.get_visible_rect().size)
	Game.coach_in_tests = true
	Career.data = Career.fresh()
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true}
	Career.data.active = Career.opening(0)
	Career.save()
	var job: Dictionary = Career.active()
	Game.contract = job
	Game.start_ship = str(job.ship)
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "mmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	await _frames(12)
	g.tutorial = null
	# past the berth tour: the coach's step card stands on the right
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	if g.coach != null:
		g.coach._unhandled_input(key)
	await _frames(150)
	ok(g.coach_on() and g.coach.card.visible, "the first ship's coach card is up")
	ok(g.hud.keys_band.shown(), "the function keys are up")
	_clear(g.coach.card.get_global_rect(), "the coach card")
	# the band unfolded (ALL): the card still clear
	g.hud.keys_band.open = true
	await _frames(40)
	_clear(g.coach.card.get_global_rect(), "the coach card, keys unfolded")
	if shots:
		Cap.save(root, "res://proofs/playtest_fix_hud_%s_coach_open.png" % tag)
	g.hud.keys_band.open = false
	await _frames(40)
	if shots:
		Cap.save(root, "res://proofs/playtest_fix_hud_%s_coach.png" % tag)
	# the coach put away: a first-meeting card and a first-use key card on the right
	g.coach.stop()
	await _frames(20)
	for id in CodexData.E.keys().slice(0, 12):
		Codex.mark(id)
	g.codex.gap_t = 99.0
	g.bot["codex"] = true
	var entry := ""
	for id in CodexData.E.keys().slice(12):
		if not Codex.carded(str(id)):
			entry = str(id)
			break
	g.codex.meet(entry, "test")
	g.hud.op_act = "hold"
	g.hud.op_t = 0.0
	await _frames(50)
	g.hud.op_t = 0.6
	await _frames(2)
	_clear(g.codex_hud.rect, "the codex card")
	_clear(g.hud.op_rect(g.hud.size()), "the key card")
	ok(not g.codex_hud.rect.intersects(g.hud.op_rect(g.hud.size())), "the codex and key cards clear of each other")
	# the centre card: a danger part selected, clear of the keys and the cards on the right
	var hc = g.hud_center
	var pick = null
	for id in g.world.order:
		var p = g.world.pieces[id]
		if p.gone or p.body != null or not hc.danger(p):
			continue
		var at: Vector2 = g.world.frame(p) * Geom.centroid(p.poly)
		var l: Array = g.world.pieces_at(at)
		if not l.is_empty() and l[0] == p and not g.world.hidden(at):
			pick = p
			break
	if pick != null:
		var at: Vector2 = g.world.frame(pick) * Geom.centroid(pick.poly)
		g.drone.global_position = at + Vector2(-3.0 * Geom.M, -2.0 * Geom.M)
		g.drone.linear_velocity = Vector2.ZERO
		g.drone.reset_physics_interpolation()
		g.bot.aim = at
		await _frames(12)
		g.bot.mmb = true
		await _frames(2)
		g.bot.mmb = false
		await _frames(20)
		g.hud.op_t = 0.6
		await _frames(2)
		if hc.sel == pick:
			_clear(hc.card_rect, "the centre card")
			ok(not hc.card_rect.intersects(g.codex_hud.rect), "the centre card clear of the codex card")
			ok(not hc.card_rect.intersects(g.hud.op_rect(g.hud.size())), "the centre card clear of the key card")
			for z in g.hud.keep_out():
				ok(not hc.card_rect.intersects(z), "the centre card clear of the HUD's %s (%s)" % [z, hc.card_side])
		else:
			print("NOTE the danger part did not take the card here (%s)" % pick)
	else:
		print("NOTE no visible danger part on this ship")
	if shots:
		Cap.save(root, "res://proofs/playtest_fix_hud_%s_cards.png" % tag)
	print("playtest_fix_hud_check: %d fails" % fails)
	quit(fails)
