extends "res://tests/guide_check.gd"
# 2026-11-11 (user: "我死了一次之后，右上角的文字怎么都变成方块了"): the keys plate redraws only when its
# state changes; the Chinese glyphs come from the SystemFont fallback, whose glyph atlas grows when a
# lot of new characters are drawn (the death card, the reload) and gets a new texture — a plate drawn
# before still points at the old one and its Chinese turns to white blocks. The drone dies, the game
# restarts, the plate is looked at; then a flood of new glyphs right under a still plate.
# Own test saves; nothing moves the mouse.
#   tools/run_test.sh tests/hud_keys_font_check.gd
const HudKeys = preload("res://scripts/hud_keys.gd")


func _initialize() -> void:
	Career.path = "user://zp_test_keysfont_career.json"
	SaveGame.path = "user://zp_test_keysfont_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _start() -> void:
	g = root.get_tree().current_scene if g == null else g
	g.tutorial = null
	Txt.zh = true
	g.drone.alive = true
	g.drone.spawn_t = 3.0
	HudKeys.ON = true


# near-white pixels in the plate: the keys' text is grey ink, a tofu block is solid white
func _white(tag: String) -> float:
	var kb = g.hud.keys_band
	var img: Image = Cap.to_srgb8(root.get_texture().get_image())
	var k := img.get_width() / root.get_visible_rect().size.x
	var r: Rect2 = kb.band_rect()
	r = Rect2(r.position * k, r.size * k)
	Cap.save(root, "res://tests/out/keysfont_%s.png" % tag)
	var n := 0
	var tot := 0
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			tot += 1
			var c := img.get_pixel(x, y)
			if c.r > 0.9 and c.g > 0.9 and c.b > 0.9:
				n += 1
	var f := float(n) / maxf(1.0, float(tot))
	print("WHITE %s %.4f (%d px of %d) plate %s" % [tag, f, n, tot, r])
	return f


# pixels lit like the grey text in a screen rect (viewport coords): letters cover a part, blocks all
func _white_at(r: Rect2) -> float:
	var img: Image = Cap.to_srgb8(root.get_texture().get_image())
	var k := img.get_width() / root.get_visible_rect().size.x
	r = Rect2(r.position * k, r.size * k)
	var n := 0
	var tot := 0
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			tot += 1
			var c := img.get_pixel(x, y)
			if c.v > 0.35:
				n += 1
	return float(n) / maxf(1.0, float(tot))


func _run() -> void:
	Game.contract = {}
	Game.start_ship = "fr26"
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": {"hauler": 1, "hauler2": 1}}
	root.add_child(g)
	root.get_tree().current_scene = g
	await _frames(40)
	_start()
	await _frames(60)
	var w0 := _white("a_before")
	check(g.hud.keys_band.shown(), "the plate is up")
	# the font itself: every Chinese character on the plate is known to the chain
	var f: Font = Fonts.get_font("Medium")
	var miss := ""
	for fn in g.hud.keys_band._fns:
		for ch in str(fn.s):
			if not f.has_char(ch.unicode_at(0)):
				miss += ch
	check(miss == "", "the font chain knows every character on the plate (%s)" % miss)
	# drawn every frame like the rest of the HUD, never left pointing at old glyph textures
	var d0: int = g.hud.keys_band.draws
	await _frames(60)
	var dn: int = g.hud.keys_band.draws - d0
	check(dn >= 55, "the plate is drawn again every frame (%d draws in 60 frames)" % dn)
	# a flood of new glyphs under a still plate: the atlas grows, the plate must follow
	var flood := Node2D.new()
	flood.z_index = -100
	var chars := ""
	for i in 1600:
		chars += char(0x4E00 + 7 * i)
	flood.draw.connect(func():
		for px in [11, 12, 13, 14, 15, 16]:
			for row in 20:
				flood.draw_string(Fonts.get_font("Medium"), Vector2(-4000, 40 + row * 20), chars.substr(row * 80, 80), HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
				flood.draw_string(Fonts.get_font("SemiBold"), Vector2(-4000, 40 + row * 20), chars.substr(row * 80, 80), HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE))
	g.hud.add_child(flood)
	await _frames(30)
	flood.queue_free()
	await _frames(30)
	var w2 := _white("b_flood")
	check(w2 <= w0 * 1.5 + 0.002, "after a flood of new glyphs the plate's text is not blocks (white %.4f)" % w2)
	# the general guard (scripts/font_watch.gd): a still panel drawn once in grey Chinese; the subset's
	# glyph cache is thrown away under it (as the reimport did). With the watcher off the panel turns
	# to white blocks — the bug, seen; with it on, the whole tree is drawn afresh and the text is back.
	var fw = Fonts.watch
	check(fw != null and fw.is_inside_tree(), "the font watcher runs under the root")
	var layer := CanvasLayer.new()
	layer.layer = 90
	var still := Node2D.new()
	var at := Rect2(200, 500, 520, 60)
	still.draw.connect(func():
		still.draw_rect(at, Color(0.05, 0.05, 0.06))
		still.draw_string(Fonts.get_font("Medium"), at.position + Vector2(10, 42), "拆解船厂设备回收危险品", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.55, 0.55, 0.55)))
	layer.add_child(still)
	g.add_child(layer)
	await _frames(10)
	var s0 := _white_at(at)
	fw.on = false
	var zs: Array = []
	for fb in Fonts.get_font("Medium").fallbacks:
		if fb is FontFile:
			zs.append(fb)
	for z in zs:
		(z as FontFile).clear_cache()
	await _frames(70)
	var s1 := _white_at(at)
	Cap.save(root, "res://tests/out/keysfont_e_cache_off.png")
	print("STILL white before %.4f · cache thrown, watcher off %.4f" % [s0, s1])
	check(s1 > s0 * 1.6, "with the watcher off the still panel shows the bug: solid blocks (%.4f → %.4f)" % [s0, s1])
	var r0: int = fw.refreshed
	fw.on = true
	await _frames(80)
	var s2 := _white_at(at)
	Cap.save(root, "res://tests/out/keysfont_f_cache_watch.png")
	print("STILL with the watcher %.4f (refreshed %d)" % [s2, fw.refreshed - r0])
	check(fw.refreshed > r0 and s2 <= s0 * 1.15, "with the watcher on the tree is drawn afresh and the blocks are gone (%.4f)" % s2)
	layer.queue_free()
	# the drone dies, the death card is up, the game restarts
	g.drone.hurt(99999.0, g.drone.global_position + Vector2(10, 0))
	await _frames(120)
	_white("c_dead")
	await _frames(600)
	var w3 := _white("c_dead_later")
	check(w3 <= w0 * 1.5 + 0.002, "after the death and the new drone the plate's text is not blocks (white %.4f)" % w3)
	g.restart()
	g = null
	await _frames(30)
	_start()
	for i in 900:
		await process_frame
		if g.hud.keys_band.shown():
			break
		if i % 60 == 0:
			g.drone.alive = true
	await _frames(60)
	if g.hud.keys_band.shown():
		var w1 := _white("d_restarted")
		check(w1 <= w0 * 1.5 + 0.002, "after the restart the plate's text is not blocks (white %.4f, before %.4f)" % [w1, w0])
	print("KEYSFONT %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL", checks, fails])
	quit(fails)
