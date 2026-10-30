extends SceneTree
# Developer "auto sort": free every piece (F3), switch auto sort on, and the
# loose pieces fly to their own mouths — whole equipment to the equipment bay,
# keels, decks and scrap to the furnace. Test files only.
# godot --headless --path . --fixed-fps 60 -s tests/dev_sort_check.gd

var frame := 0
var g
var dev
var fails := 0
var loose0 := 0
var dev_was := false
var end_frame := 3640            # `-- secs=180` for a big ship's longer queue


# Exercise the actual workbench button, not a positional run(n) shortcut.
func toggle_sort() -> void:
	dev.set_open(true)
	dev.bench.buttons.dev_sort.grab_focus()
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	dev.set_open(false)


func _initialize() -> void:
	Txt.zh = true
	dev_was = Txt.dev
	Career.path = "user://zp_test_devsort_career.json"
	SaveGame.path = "user://zp_test_devsort_save.json"
	for f in [Career.path, SaveGame.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Career.data = {}
	Career.start_new()
	Career.save()
	Game.contract = Career.sign_active()
	Game.start_ship = Game.contract.ship
	# user 2026-10-28 (H-67, its big pieces flew off to the top left): any ship, `-- ship=h67`
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("ship="):
			Game.contract = {}
			Game.start_ship = arg.substr(5)
		if arg.begins_with("secs="):
			end_frame = 40 + int(arg.substr(5)) * 60
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2(-30, -30) * 48.0, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	print("  [%s] %s" % ["PASS" if ok else "FAIL", what])


func _loose() -> Array:
	return g.world.bodies.filter(func(b): return is_instance_valid(b) and b.capture == null and not b.pieces.is_empty())


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 30:
		Txt.dev = true
		for n in g.get_children():
			if n is DevPanel:
				dev = n
		DevPanel.god = true
		dev.run(2)
		dev.run(3)
	elif frame == 40:
		loose0 = _loose().size()
		toggle_sort()
		check(DevPanel.sort_on, "native workbench button enables auto sort")
		check(not paused and not g.paused_sim, "closing workbench restores simulation")
	elif frame == 180:
		check(_loose().any(func(b): return b.has_meta("sort_layer")), "real loose bodies are in automatic transit")
		toggle_sort()
		check(not DevPanel.sort_on and _loose().all(func(b): return not b.has_meta("sort_layer") and b.collision_layer != 0), "native off button restores in-flight body collisions")
		toggle_sort()
		check(DevPanel.sort_on, "native button can restart sorting")
	elif frame > 40 and (frame % 600 == 0 or frame == end_frame):
		var l := _loose()
		var ghosts := l.filter(func(b): return b.has_meta("sort_layer")).size()
		var skip := l.filter(func(b): return b.get_meta("sort_skip", false)).size()
		print("t=%ds loose %d (on the way %d, turned away %d) rate %.1f%%" % [(frame - 40) / 60, l.size(), ghosts, skip, g.recovery_rate() * 100.0])
		if frame == end_frame:
			check(loose0 > 10, "F3 freed the ship (%d loose bodies)" % loose0)
			check(l.size() <= loose0 * 0.1, "nearly everything went in by itself (%d of %d left)" % [l.size(), loose0])
			check(g.recovery_rate() > 0.5, "actual receiver settlements produce nonzero recovery above 50 percent")
			# what is left is only what no mouth takes whole (it must be cut), never one sent to a mouth
			# too small for it and left lying where it was turned away
			var stray := l.filter(func(b): return Dock.for_load(dev._sort_zone(b), b) != "")
			for b in stray:
				print("    left: %s at %s m (%s)" % [str(b.pieces.map(func(p): return p.tag if p.tag != "" else p.kind)), str(((b.global_transform * b.center_of_mass) / Geom.M).round()), Dock.for_load(dev._sort_zone(b), b)])
			check(stray.size() <= 1, "nothing a mouth takes is left lying about (%d)" % stray.size())
			toggle_sort()
			check(not DevPanel.sort_on and _loose().all(func(b): return not b.has_meta("sort_layer")), "off again: nothing left ghosted")
			Txt.dev = dev_was
			DevPanel.god = false
			print("DEVSORT %s" % ("PASS" if fails == 0 else "FAIL"))
			quit(0 if fails == 0 else 1)
			return true
	return false
