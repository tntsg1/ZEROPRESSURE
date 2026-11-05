extends "res://tests/record108.gd"
# 128 号第 6 段 (user 2026-11-05): the company's own tug at work, and the moments most likely to clip
# shown slowed down, clear: the hulk winched into the station's mouth as its tug stops at the gate and
# goes in; two tugs cast off a long hulk and go in through the gate one after the other (the second
# holding above it, the gate open before they get there); a contract's opening: the hull shoved out of
# the mouth in strokes while its tug comes down from the gate behind the stern, round the port clear
# of every solid, up the berth's open side past the floor's end and pushed in, the tug home after.
# Test saves only.
#   tools/run_test.sh tests/record_tug_rig.gd --write-movie recordings/record_tug_rig.avi --fixed-fps 30


# the camera held on a point after the game has placed it (the opening places it every frame)
class Pin extends Node:
	var g
	var at = null
	var zoom := 0.5
	func _process(_dt: float) -> void:
		if at != null and g != null and is_instance_valid(g) and g.cam != null:
			g.cam.position = at
			g.cam.zoom = Vector2(zoom, zoom)
			g.cam.reset_smoothing()


var pin: Pin


func _initialize() -> void:
	Txt.test_zh = true
	Txt.zh = true
	Scan.ON = false
	Career.path = "user://zp_test_record_tug_rig_career.json"
	SaveGame.path = "user://zp_test_record_tug_rig_save.json"
	SaveGame.allow_test = true
	for f in [Career.path, SaveGame.path]:
		for ext in ["", ".bak", ".tmp", ".old", ".done", ".bak.done"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f + ext))
	root.add_child(preload("res://tests/test_window.gd").new())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out/tug_rig/"))
	pin = Pin.new()
	pin.process_priority = 1000
	pin.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(pin)
	_run.call_deferred()


func _bring(ship: String) -> String:
	var i := -1
	for k in Career.data.offers.size():
		if Career.data.offers[k].get("find", false):
			i = k
			break
	if i < 0:
		Career.data.offers = Market.make(900 + ShipMarket.data().assets.size(), Career.data)
		i = 0
		Career.data.offers[0].find = true
	var id := str(Career.data.offers[i].id)
	if ship != "":
		Career.data.offers[i].ship = ship
	ShipMarket.tow_find(i)
	var a := ShipMarket.asset(id)
	if a.is_empty():
		return ""
	if ship != "":
		a.listing.offer.ship = ship
		a.ship = ship
	Shipping.data().day = maxf(float(Shipping.data().day), float(a.run.depart) + float(a.run.tof) + 0.01)
	ShipMarket.tick()
	Career.save()
	return id


func _berth() -> void:
	if g != null:
		g.queue_free()
		await process_frame
	Game.start_ship = "berth"
	Game.contract = {}
	SaveGame.load_requested = false
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	current_scene = g
	pin.g = g
	await _secs(0.3)
	g.tutorial = null


func _wait_towin() -> void:
	var t := 0
	while g.state != "towin" and t < FPS * 6:
		await _secs(1.0 / FPS)
		t += 1


# the bringing-in run on our own clock from `from` s, at speed k until `slow_at`, then at k_slow
func _towin_clock(from: float, slow_at: float, k_slow: float) -> void:
	var tt = g.tow_traffic
	var t := from
	tt.arrival.t = t
	while g.state == "towin" and not tt.arrival.is_empty():
		var k := 1.0 if t < slow_at else k_slow
		Engine.time_scale = k
		t += k / FPS
		await _secs(1.0 / FPS)
		if not tt.arrival.is_empty():
			tt.arrival.t = t


func _drone_inside(box: Rect2) -> void:
	if g.drone != null:
		g.drone.global_position = box.position + Vector2(54.0, 18.0) * Geom.M
		g.drone.linear_velocity = Vector2.ZERO


func _run() -> void:
	cap_total = 5
	_caption_layer()
	Career.data = Career.fresh()
	Career.data.market = true
	Career.data.story_job = {}
	Career.data.active = {}
	Career.data.money = 900000.0
	Career.data.port = {"salvage": 1, "trade": 1, "tug": 2}
	Career.data.drill = {"granted": true, "done": true}
	Career.data.prologue_done = true
	Career.data.seen = {"belt_prelude": true, "first_ship": true, "intro": true, "first_tow": true, "starmap_tour": true, "port_walk": true}
	Career.data.upgrades = {"berth88": true}
	Career.data.offers = Market.make(515, Career.data)
	Career.save()
	await _berth()
	await _secs(0.4)
	var M := Geom.M
	var box := PortStructure.box("tug")

	# ---- 1: towed in to the station's mouth; slowed: stopped off the wall, cast off at the gate, winched in
	_bring("gr7")
	await _wait_towin()
	_beat(1, "拖船拖船进港：拖缆 → 锁臂 → 反推刹停", "慢镜头：贴墙前停稳，拖船在闸门外脱开，船坞口绞车把船拉进去")
	await _towin_clock(2.2, 5.2, 0.4)
	Engine.time_scale = 1.0

	# ---- 2: the gate open before it, in to its berth
	_beat(2, "闸门先开好，拖船进站停回泊位", "站内甲板：从闸门开进来，停在自己的泊位上")
	for i in FPS * 6:
		_drone_inside(box)
		g.cam_override = box.position + Vector2(16.0, 12.0) * M
		g.zoom_override = 0.45
		await _secs(1.0 / FPS)
		if i == FPS * 5:
			Cap.save(root, "res://tests/out/tug_rig/3_home_on_deck.png")
	g.cam_override = null
	g.zoom_override = -1.0

	# ---- 3: two tugs on a long hulk; slowed: cast off, in through the gate one after the other
	Career.data.tug_charge = {"TG-1": 1.0, "TG-2": 1.0}
	await _secs(0.2)
	_bring("fx70")
	await _wait_towin()
	_beat(3, "大船两艘一起拖，进闸一前一后", "慢镜头：两艘保持间距；后一艘在闸门上方等前一艘进站")
	await _towin_clock(3.0, 6.6, 0.5)
	# the flights home, slowed, the camera on the gate
	Engine.time_scale = 0.5
	var f := 0
	while (not g.tow_traffic.flights.is_empty() or g.tow_traffic.W.gate > 0.02) and f < FPS * 14:
		_drone_inside(box)
		g.cam_override = box.position + Vector2(-6.0, 4.0) * M
		g.zoom_override = 0.42
		await _secs(1.0 / FPS)
		f += 1
	Engine.time_scale = 1.0
	g.cam_override = null
	g.zoom_override = -1.0

	# ---- 4: a contract's opening on the hulk in the mouth: shoved out in strokes, the tug comes down
	var a1 := {}
	for a in ShipMarket.data().assets:
		if int(a.get("yard", -1)) == 0:
			a1 = a
	var idx := -1
	Career.data.offers.append(a1.listing.offer.duplicate(true))
	Career.data.offers[-1].id = a1.id
	idx = Career.data.offers.size() - 1
	Career.accept(idx)
	Game.contract = Career.sign_active()
	Game.contract.erase("traps")
	Game.start_ship = str(Game.contract.get("ship", ""))
	SaveGame.load_requested = false
	g.queue_free()
	await process_frame
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": false, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	current_scene = g
	pin.g = g
	await process_frame
	await process_frame
	var wait := 0
	while g.dock._plan_task >= 0 and wait < FPS * 3:
		await process_frame
		wait += 1
	var jt: float = g.dock._join_t
	_beat(4, "合同开场：船从船坞口分段推出，拖船从闸门下来接船尾", "慢镜头：拖船在闸门高度等船尾让开，再从后方追上贴住")
	pin.at = box.position + Vector2(-26.0, 16.0) * M
	pin.zoom = 0.36
	var t := 0.0
	while t < jt + 0.6 and g.state == "intro":
		t += 0.45 / FPS
		g.state_t = t
		await _secs(1.0 / FPS)
	# ---- 5: round the port clear of everything, up past the floor's end, pushed in; the tug goes home
	pin.at = null
	_beat(5, "绕开港区、从泊位地板尽头外侧上来，顶推进船坞", "护舷压扁；推到位后拖船后退，自己飞回拖船站闸门")
	f = 0
	while g.state == "intro" and f < FPS * 16:
		await _secs(1.0 / FPS)
		f += 1
	await _secs(1.5)
	print("RECORD TUG RIG DONE")
	quit()
