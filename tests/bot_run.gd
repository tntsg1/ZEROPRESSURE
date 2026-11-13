extends SceneTree
# The salvage bot on one contract: GR-001 as built, or a random contract from a
# seed (seed=N, stars=N), careless or not. Prints the books.
# godot --headless --path . --fixed-fps 60 -s tests/bot_run.gd -- [seed=N] [ship=ID] [careless] [paced] [ledger] [kit=a,b]

const Bot = preload("res://tests/salvage_bot.gd")
var game
var bot
var job := {}
var show_ledger := false
var kit := {}
var paced := false
var every := 600   # every=N: a progress line every N frames


func _initialize() -> void:
	var careless := false
	var stars := 1
	var seed := -1
	var ship := ""
	var grid_stage := -1
	for a in OS.get_cmdline_user_args():
		if a == "careless":
			careless = true
		elif a.begins_with("seed="):
			seed = int(a.substr(5))
		elif a.begins_with("ship="):
			ship = a.substr(5)
		elif a.begins_with("stars="):
			stars = int(a.substr(6))
		elif a == "paced":
			paced = true
		elif a.begins_with("grid="):
			grid_stage = int(a.substr(5))
		elif a.begins_with("every="):
			every = maxi(1, int(a.substr(6)))
		elif a == "ledger":
			show_ledger = true
		elif a.begins_with("kit="):
			for id in a.substr(4).split(","):
				kit[id] = 1
	if seed >= 0:
		job = Market.offer_for(seed, {"rep": 20, "done": 1}, stars)
		print("contract ", job)
	# 71 号: grid=N works the ship as a career's contract on the port's grid at power stage N
	if grid_stage >= 0:
		Career.path = "user://zp_test_botgrid_career.json"
		SaveGame.path = "user://zp_test_botgrid_save.json"
		SaveGame.allow_test = true
		Career.data = Career.fresh()
		Career.data.port = {"salvage": 1, "power": grid_stage}
		Career.data.prologue_done = true
		Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true}
		Grid.BOTS = true
		if job.is_empty():
			# (not TUG-001: the first ship rides the port authority's line)
			job = Career.opening(1) if ship in ["", "s09"] else {"id": "GRID-" + ship.to_upper(), "ship": ship, "owner": "salvage", "fee": 0.0, "time": 1800.0}
		Career.data.active = job
		Career.save()
		print("GRID power stage %d: %.0f MW" % [grid_stage, Grid.capacity()])
	Game.contract = job
	if ship != "":
		Game.start_ship = ship
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO, "kit": kit}
	root.add_child(scene)
	game = scene
	bot = Bot.new(game, {"careless": careless, "paced": paced})


var _frame := 0


func _process(_dt: float) -> bool:
	_frame += 1
	if _frame % every == 0:
		var hb = game.hauler.body if game.hauler != null else null
		print("PROGRESS frame %d wall %.0f s sim %.0f s x%.0f phase %s earned %.0f bodies %d hauling %s" % [_frame, Time.get_ticks_msec() / 1000.0, game.sys.time, Engine.time_scale, bot.phase, game.earned(), game.world.bodies.size(),
			"-" if hb == null or not is_instance_valid(hb) else str(hb.pieces.map(func(q): return q.tag))])
		if bot.phase == "strip" and OS.get_cmdline_user_args().has("diag") and _frame % 3000 == 0:
			for b in game.world.bodies:
				if is_instance_valid(b):
					print("  body ", b.pieces.map(func(q): return q.tag), " at ", (b.global_position / Geom.M).snapped(Vector2(0.1, 0.1)), " v ", b.linear_velocity.length(), " m ", b.mass, " sent ", bot.sent.get(b, "-"), " cap ", b.capture != null, " haz ", b.pieces.map(func(q): return q.hazard), " size ", _size(b))
		if bot.phase == "strip" and OS.get_cmdline_user_args().has("diag") and _frame == 3000:
			var mouth: Vector2 = Dock.zpos("equip")
			var q := PhysicsShapeQueryParameters2D.new()
			var sh := RectangleShape2D.new()
			sh.size = Vector2(4.0, 12.0) * Geom.M
			q.shape = sh
			q.transform = Transform2D(0, mouth)
			for hit in game.get_world_2d().direct_space_state.intersect_shape(q, 32):
				var c = hit.collider
				print("  AT EQUIP MOUTH ", c.name, " ", c.get_class(), " path ", c.get_path(), " layer ", c.collision_layer)
		if bot.phase == "prep" and OS.get_cmdline_user_args().has("diag"):
			print("  unsafe ", bot._unsafe().slice(0, 10))
			print("  notes ", bot.notes.slice(maxi(0, bot.notes.size() - 4)))
	if bot.step():
		for n in bot.notes:
			print(n)
		print("BOT ", bot.summary(), "  incidents ", game.incidents)
		# 108 号 第 5 件: the furnace's ingots (value at the scrap price, tonnes) and the parts shelved
		print("INGOT value %.0f ore %.0f t %.2f parts %.0f" % [game.income_metal, game.income_ore, maxf(0.0, game.income_metal - game.income_ore) / maxf(1.0, game.world.metal_price), game.parts_value])
		if game.gear != null:
			print("FEATS furnace %d equip %.0f %s" % [game.gear.furnace_n, game.gear.equip_v, str(game.gear.feats_now)])
		# a sample ship's core asset (95 号): what of it reached the equipment mouth, for the card
		var ca = load("res://scripts/core_asset.gd")
		if ca.has(game):
			var rv: Dictionary = ca.review(game)
			print("ASSET got %.0f of %.0f, minutes %.1f" % [float(rv.got), float(rv.full), game.playtime / 60.0])
		if show_ledger:
			for l in game.ledger:
				print("LEDGER ", l)
		return true
	return false


# a body's extent in metres, in its own frame (diagnostics)
func _size(b) -> Vector2:
	var r := Rect2()
	var first := true
	for p in b.pieces:
		for q in game.world.world_poly(p):
			var l: Vector2 = b.global_transform.affine_inverse() * q
			if first:
				r = Rect2(l, Vector2.ZERO)
				first = false
			else:
				r = r.expand(l)
	return (r.size / Geom.M).snapped(Vector2(0.1, 0.1))
