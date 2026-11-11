extends "res://tests/hold_nocollide_check.gd"
# 2026-11-11 量子隧穿·机体 (user: "无人机本身也可以进行量子隧穿，无视其他的东西"): the drone's own tunnelling
# (scripts/body_tunnel.gd), by real keys (U, N, the movement keys through the bot) and a real click on
# the key strip's "机体" button (nothing moved by hand but where a case starts):
#   - both tunnellings are on once bought (user 2026-11-11: "升级默认开启"; an old save's too);
#   - not fitted (an old save: the grapple's tunnelling only): U does nothing, N switches as before;
#   - fitted: on by itself; U and the "机体" button switch it; N alone leaves it be;
#   - on: through a closed box of hull walls and a loose piece (the piece feels nothing), with the
#     effect (halo in and out, the jets' echoes); inertia as ever (it coasts on, brakes as ever);
#   - switched off inside a wall: not shot out — eased to open space, then it touches again;
#   - a room still under pressure stays solid from outside (and says so); vented, in it goes;
#   - the berth's edge holds it in;
#   - three key frames (tests/out/body_tunnel_*.png) with -- shots.
# Own test saves only.
#   tools/run_test.sh tests/body_tunnel_check.gd --fixed-fps 60 [-- shots]

func _initialize() -> void:
	Career.path = "user://zp_test_bodytun_career.json"
	SaveGame.path = "user://zp_test_bodytun_save.json"
	SaveGame.allow_test = true
	if DisplayServer.get_name() != "headless":
		root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


# the drone's own tunnelling key (U)
func _shift_n() -> void:
	await _tap(KEY_U)


func _click(at: Vector2, press: int) -> void:
	var b := InputEventMouseButton.new()
	b.position = at
	b.global_position = at
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = press > 0
	b.button_mask = MOUSE_BUTTON_MASK_LEFT if press > 0 else 0
	root.push_input(b, true)


func _fly(dir: Vector2, frames: int, watch: Callable = Callable()) -> void:
	for f in frames:
		g.bot.move = dir
		await physics_frame
		if watch.is_valid():
			watch.call(f)
	g.bot.move = Vector2.ZERO


func _run() -> void:
	Txt.zh = true
	Game.contract = {}
	var M := Geom.M
	var shots := "shots" in OS.get_cmdline_user_args()
	# ---------------- not fitted: an old save with the grapple's tunnelling only
	await _game({"skill_grapple_multi": 1, "tunnel": 1})
	var bt = g.tools.body_tunnel
	check(bt != null and not bt.fitted(), "OLD SAVE: the grapple's tunnelling fitted, the drone's not")
	check(g.tools.tunnel_on(), "OLD SAVE: the grapple's tunnelling, bought before, is on (default on)")
	await _shift_n()
	check(bt.state == "off" and g.tools.tunnel_on(), "OLD SAVE: U does nothing (and leaves the grapple's be)")
	await _tap(KEY_N)
	check(not g.tools.tunnel_on() and bt.state == "off", "OLD SAVE: N switches the grapple's tunnelling (off)")
	await _tap(KEY_N)
	check(g.tools.tunnel_on(), "OLD SAVE: and on again")
	check(Keys.codes("tunnel_body") == [KEY_U] and not (KEY_U in Keys.codes("dash")), "KEYS: the drone's own on U, clear of the dash (Shift)")
	check(Terminal.REQUIRES.get("tunnel_body", "") == "tunnel" and Terminal.LATE.get("tunnel_body", []) == [20, 30], "SHOP: needs the grapple's tunnelling, the same stage (20 jobs, reputation 30)")
	var price := 0.0
	for it in Terminal.SHOP:
		if it[0] == "tunnel_body": price = float(it[2])
	check(price == 1200000.0, "SHOP: 1 200 000 (%s)" % Pal.money(price))
	g.queue_free()
	await _frames(4)

	# ---------------- fitted
	await _game({"skill_grapple_multi": 1, "tunnel": 1, "tunnel_body": 1})
	bt = g.tools.body_tunnel
	var d = g.drone
	var mask0: int = bt.mask0
	check(bt.fitted() and bt.active() and g.tools.tunnel_on() and d.collision_mask == ((mask0 & 16) | 128) and d.collision_layer == 0, "FITTED: bought, both on by themselves (drone mask %d → %d, layer 0)" % [mask0, d.collision_mask])
	await _shift_n()
	check(bt.state == "off" and d.collision_mask == mask0 and g.tools.tunnel_on(), "FITTED: U switches the drone's own off (mask %d), the grapple's stays on" % d.collision_mask)
	await _tap(KEY_N)
	check(bt.state == "off" and not g.tools.tunnel_on(), "FITTED: N alone switches the grapple's, the drone's stays as it was")
	# the key strip's "机体" button: a real click switches it on
	var kb = g.hud.keys_band
	await _frames(10)
	var br := Rect2()
	for k in kb._keys:
		if str(k.fn.a) == "tunnel_body":
			br = k.r
	check(br.has_area(), "STRIP: the 机体 button is on the key strip")
	var bp: Vector2 = br.get_center() + Vector2(kb._off, 0)
	_click(bp, 1)
	await _frames(2)
	_click(bp, -1)
	await _frames(6)
	check(bt.active(), "STRIP: a real click on 机体 switches the drone's own tunnelling on")
	await _frames(20)
	Cap.save(root, "res://tests/out/body_tunnel_keystrip.png")
	# ---------------- through a closed box of hull walls, a loose piece in the way
	var c := Vector2(24.0, -6.0)
	_box(c, Vector2(2.4, 1.4), "BTBOX")
	var lp = _rect((c + Vector2(4.2, 0.0)) * M, Vector2(0.6, 0.6) * M, "BT-LOOSE", 0.3)
	var lb = lp.body
	_place_drone((c - Vector2(5.0, 0.0)) * M)
	if shots:
		g.cam_override = c * M
		g.zoom_override = 2.0
		g.zoom_now = 2.0
		g.zoom_target = 2.0
	await _frames(6)
	var fx = g.tools.tunnel_fx
	var e0: int = fx.stats.drone_entries
	var x0: float = d.global_position.x
	var lv := 0.0
	var flames := 0
	var shot_n := 0
	var inn := 0
	for f in 150:
		g.bot.move = Vector2(1.0, 0.0)
		await physics_frame
		if is_instance_valid(lb): lv = maxf(lv, lb.linear_velocity.length())
		flames = maxi(flames, int(fx.stats.flames))
		# key frames: going into the first wall, inside the second box's wall, just out of the last
		var want_shot := false
		if fx.stats.drone_in > inn:
			inn = fx.stats.drone_in
			want_shot = inn == 2 or inn == 7
		if fx.stats.drone_exits >= 2 and shot_n == 2:
			want_shot = true
		if shots and shot_n < 3 and want_shot:
			await process_frame
			Cap.save(root, "res://tests/out/body_tunnel_%d.png" % shot_n)
			shot_n += 1
	g.bot.move = Vector2.ZERO
	var x1: float = d.global_position.x
	var v1: float = d.linear_velocity.x
	print("  WALL: drone %.1f → %.1f m  (box %.1f..%.1f)  v %.0f px/s  entries %d exits %d halos %d flames %d  loose piece |v| max %.2f  shots %d" % [x0 / M, x1 / M, c.x - 2.4, c.x + 2.4, v1, fx.stats.drone_entries - e0, fx.stats.drone_exits, fx.stats.halos, flames, lv, shot_n])
	check(x1 / M > c.x + 2.4 + 1.0, "WALL: it flies in and out through the box's hull walls (%.1f m)" % (x1 / M))
	check(lv < STILL, "WALL: the loose piece in its way feels nothing (%.2f px/s)" % lv)
	check(fx.stats.drone_entries > e0 and fx.stats.drone_exits >= 1 and flames > 0, "WALL: the effect played: a halo in, one out, the jets' echoes")
	# inertia: flight assist off, keys let go, it coasts on
	d.assist = false
	await _frames(20)
	check(d.linear_velocity.x > v1 * 0.8, "INERTIA: keys let go, it drifts on (%.0f → %.0f px/s)" % [v1, d.linear_velocity.x])
	d.assist = true
	if shots:
		g.cam_override = null
		g.zoom_override = -1.0
	# ---------------- switched off inside the wall: eased out, never shot out
	_place_drone(Vector2(c.x - 2.4 + 0.15, c.y) * M)
	await _frames(4)
	await _shift_n()
	check(bt.state == "clearing" and d.collision_mask == ((mask0 & 16) | 128), "OFF IN A WALL: it stays untouchable while in it (state %s)" % bt.state)
	print("  OFF IN A WALL: free here %s, nearest free %s (drone at %s)" % [bt._free_at(d, d.global_position), str(bt._nearest_free(d) / M), str(d.global_position / M)])
	var vmax := 0.0
	var out_t := -1.0
	for f in 240:
		await physics_frame
		vmax = maxf(vmax, d.linear_velocity.length())
		if bt.state == "off":
			out_t = (f + 1) / 60.0
			break
	print("  OFF IN A WALL: out after %.2f s, max %.1f px/s, mask %d, state %s" % [out_t, vmax, d.collision_mask, bt.state])
	check(out_t > 0.0 and d.collision_mask == mask0, "OFF IN A WALL: eased out to open space, then it touches again (%.2f s)" % out_t)
	check(vmax <= bt.EASE_V + 12.0, "OFF IN A WALL: never shot out (max %.1f px/s)" % vmax)
	d.linear_velocity = Vector2.ZERO
	# ---------------- a room still under pressure
	await _shift_n()
	check(bt.active(), "PRESSURE: on again")
	var room = g.world.rooms.get("F")
	var pf: float = g.sys.P("F")
	check(room != null and pf > Systems.SAFE_KPA, "PRESSURE: the pod's room F is under pressure (%.0f kPa)" % pf)
	var rb: Rect2 = room.bbox
	_place_drone(Vector2(rb.position.x - 3.0 * M, rb.get_center().y))
	await _frames(4)
	var seen := {"in": false, "minx": INF}
	await _fly(Vector2(1.0, 0.0), 180, func(f):
		if Geometry2D.is_point_in_polygon(d.global_position, room.poly): seen["in"] = true)
	print("  PRESSURE: at x %.1f m (room from %.1f m)  held %d  in %s" % [d.global_position.x / M, rb.position.x / M, bt.stats.held_room, seen["in"]])
	check(not seen["in"] and bt.stats.held_room > 0 and bt.blocked == "F", "PRESSURE: it cannot tunnel into the room under pressure")
	# vented: in it goes
	g.sys.vols["F"].n = 0.0
	await _frames(2)
	await _fly(Vector2(1.0, 0.0), 120, func(f):
		if Geometry2D.is_point_in_polygon(d.global_position, room.poly): seen["in"] = true)
	print("  VENTED: %.1f kPa, at x %.1f m" % [g.sys.P("F"), d.global_position.x / M])
	check(seen["in"], "PRESSURE: vented, it tunnels in")
	# ---------------- the berth's edge: the tower wall on the left, the floor under it
	var wall_x: float = (Dock.TOWER_X + 0.6) * M
	var floor_y: float = Dock.FLOOR_Y * M
	_place_drone(Vector2(wall_x + 2.5 * M, (Dock.RAIL_Y + Dock.FLOOR_Y) * 0.5 * M))
	await _frames(4)
	await _fly(Vector2(-1.0, 0.0), 120, func(f): seen["minx"] = minf(float(seen["minx"]), d.global_position.x))
	var minx: float = seen["minx"]
	seen["maxy"] = -INF
	await _fly(Vector2(0.0, 1.0), 150, func(f): seen["maxy"] = maxf(float(seen["maxy"]), d.global_position.y))
	var maxy: float = seen["maxy"]
	print("  EDGE: tower wall at %.2f m, the drone got to %.2f m; floor at %.2f m, got to %.2f m" % [wall_x / M, minx / M, floor_y / M, maxy / M])
	check(minx >= wall_x + Drone.R - 6.0 and maxy <= floor_y - Drone.R + 6.0 and bt.active(), "EDGE: the berth's edge (tower wall, floor) holds it in while it tunnels")
	print("body_tunnel_check: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
