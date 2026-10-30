extends SceneTree
# 78 号 P0-1: which recovery mouth a load goes to — by its real outline turned its
# narrowest way, the outside rack when only it fits, "" (cut it / scrap it) when no
# mouth does — and that a cut shares out a piece's mass instead of re-making it.
# godot --headless --path . --fixed-fps 60 -s tests/mouth_route_check.gd
var g: Node
var fails := 0
var checks := 0
const LM = preload("res://scripts/load_motion.gd")
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
# a loose box of equipment, w x h metres, turned by rot, mass t
func load_at(at: Vector2, size_m: Vector2, key: String, rot: float = 0.0, mass: float = 0.2):
	var h := size_m*Geom.M*0.5
	var poly := PackedVector2Array()
	for c in [Vector2(-h.x,-h.y),Vector2(h.x,-h.y),Vector2(h.x,h.y),Vector2(-h.x,h.y)]:
		poly.append(at+(c as Vector2).rotated(rot))
	var p = g.world.add_piece("cargo",poly,{"key":key,"tag":key,"cls":"equip","mass":mass,"value":1000.0})
	g.world.make_body([p],null)
	p.body.freeze = true
	return p
func _run() -> void:
	SaveGame.allow_test = false
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "ro128"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	var small: float = Dock.ZONES.equip.w
	var rack: float = Dock.ZONES.equip_bulk.w
	print("mouths: equip %.1f m, outside rack %.1f m (%s)" % [small, rack, "side" if Dock.ZONES.equip_bulk.face == Vector2.LEFT else "top"])
	var far := Vector2(Dock.zpos("equip").x, Dock.FLOOR_Y*Geom.M-400.0)
	# long and thin, lying across the mouth: turned end-on it goes in a small bay
	var thin = load_at(far,Vector2(9.0,0.6),"THIN")
	var n: Vector2 = LM.narrowest(thin.body,Vector2.DOWN)
	check(absf(n.x/Geom.M-0.6) < 0.1,"long thin load: narrowest width 0.6 m found by turning (%.2f m)" % (n.x/Geom.M))
	check(Dock.kind(Dock.for_load("equip",thin.body)) == "equip" and Dock.for_load("equip",thin.body) != "equip_bulk","long thin load is routed to a small equipment bay, not the rack (%s)" % Dock.for_load("equip",thin.body))
	g.world.remove_piece(thin)
	# user 2026-10-26: TUG-001's thruster pod (6.8 x 1.2 m) lying flat in the player's grapple was
	# pointed at the 4.2 m bay; only the rack takes it — the grapple can't stand it on end
	var pod = load_at(far,Vector2(6.8,1.2),"POD")
	check(Dock.for_load("equip",pod.body,false) == "equip_bulk","thruster pod lying flat in the grapple goes to the rack, not the 4.2 m bay (%s)" % Dock.for_load("equip",pod.body,false))
	check(Dock.for_load("equip",pod.body) in ["equip","equip2"],"a machine that can stand it on end may use the small bay")
	g.world.remove_piece(pod)
		# turned 45°: neither 0° nor 90° lines it up; the 24-step turn does
	var tilted = load_at(far,Vector2(5.5,1.0),"TILT",deg_to_rad(45.0))
	var old_best := INF
	for turn in [0.0, PI*0.5]:
		var sp := Vector2(INF,-INF)
		for q in g.world.world_poly(tilted):
			var d: float = (q-far).rotated(turn).x
			sp = Vector2(minf(sp.x,d),maxf(sp.y,d))
		old_best = minf(old_best,sp.y-sp.x)
	n = LM.narrowest(tilted.body,Vector2.DOWN)
	check(old_best/Geom.M > small and n.x/Geom.M <= 1.05,"rotated load: 0°/90° gave %.1f m (> %.1f m bay), turning gives %.2f m" % [old_best/Geom.M, small, n.x/Geom.M])
	check(Dock.for_load("equip",tilted.body) in ["equip","equip2"],"rotated load is routed to a small bay")
	# turn it the found way: its span across the mouth really is that narrow
	tilted.body.rotation += n.y
	var sp2: Vector2 = LM.span(tilted.body,Vector2.DOWN)
	check(absf((sp2.y-sp2.x)-n.x) < 2.0,"turning the body by the found angle gives that width (%.2f m)" % ((sp2.y-sp2.x)/Geom.M))
	g.world.remove_piece(tilted)
	# heavy: weight decides who can carry it, not which mouth takes it
	var heavy = load_at(far,Vector2(2.0,2.0),"HEAVY",0.0,3.0)
	check(Dock.for_load("equip",heavy.body) in ["equip","equip2"],"heavy 3 t load still routes to the small bay its size fits")
	var h := Hauler.new()
	h.game = g
	check(h.toggle(heavy.body) == "hauler_heavy","hauler refuses the 3 t load as too heavy (not as no-mouth)")
	g.world.remove_piece(heavy)
	# small -> large: square too big for any bay however turned, small enough for the rack
	var side := minf(small + 1.5, rack - 1.0)
	var big = load_at(far,Vector2(side,side),"BIG")
	check(side > small and Dock.for_load("equip",big.body) == "equip_bulk","%.1f m square load goes to the outside rack, not a %.1f m bay (%s)" % [side, small, Dock.for_load("equip",big.body)])
	check(h.toggle(big.body) == "hauler_marked","hauler takes it on for the rack")
	h.queue.clear()
	g.world.remove_piece(big)
	# no mouth at all: a load wider than the rack every way
	var huge = load_at(far,Vector2(rack+3.0,rack+3.0),"HUGE",0.0,1.0)
	check(Dock.for_load("equip",huge.body) == "","a load wider than every mouth however turned gets no mouth (\"\")")
	var why := Dock.no_mouth_text(huge.body)
	check(why != "" and why.find("%.1f" % rack) >= 0,"the no-mouth line names its width and the widest mouth: %s" % why)
	check(h.toggle(huge.body) == "hauler_no_mouth" and not h.queue.has(huge.body),"hauler marks it as needing a cut instead of queueing an endless squeeze")
	var c := Crane.new()
	c.game = g
	check(c.toggle(huge.body) == "hauler_no_mouth","crane refuses it the same way")
	check(g.txt("hauler_no_mouth") != "hauler_no_mouth" and g.txt("no_mouth") != "no_mouth","both prompt lines exist")
	g.world.remove_piece(huge)
	h.free()
	c.free()
	# a cut shares out the mass the piece had: 0.03 t of film over ~280 m² stays 0.03 t
	var poly := PackedVector2Array([far,far+Vector2(20,0)*Geom.M,far+Vector2(20,14)*Geom.M,far+Vector2(0,14)*Geom.M])
	var film = g.world.add_piece("film",poly,{"key":"FILM","tag":"FILM","cls":"metal","mass":0.03,"density":0.05})
	var before: float = film.mass
	g.cut_kerf(film,PackedVector2Array([far+Vector2(10,-2)*Geom.M,far+Vector2(10,16)*Geom.M]))
	var after := 0.0
	var parts := 0
	for id in g.world.order:
		var q = g.world.pieces[id]
		if q == film or q.get_meta("origin","") == "FILM":
			after += q.mass
			parts += 1
	check(parts >= 2 and after <= before + 0.0001 and after > before * 0.8,"cut film keeps its mass: %.3f t -> %.3f t in %d parts (was area x density ≈ %.1f t)" % [before, after, parts, Geom.area(poly)/(Geom.M*Geom.M)*0.05])
	# a real carry: 5 x 1 m at 45° spans 4.24 m, over the 4.2 m bay — the hauler swings it on the way
	# the berth cleared of RO-128 (sealed in its hull nothing is reachable)
	for id in g.world.order.duplicate():
		var sp = g.world.pieces[id]
		if not sp.gone:
			g.world.remove_piece(sp)
	g.nav_grid().dirty = true
	await frames(4)
	var hl := Hauler.new()
	hl.game = g
	hl.process_mode = Node.PROCESS_MODE_PAUSABLE
	g.add_child(hl)
	g.hauler = hl
	var bay := Dock.zpos("equip")
	var skew = load_at(bay+Vector2(-6.0*Geom.M,16.0*Geom.M),Vector2(5.0,1.0),"SKEW",deg_to_rad(45.0),0.4)
	check(not LM.fits(skew.body,small*Geom.M,Vector2.DOWN) and Dock.for_load("equip",skew.body) in ["equip","equip2"],"skewed 5 m load doesn't fit the bay as it lies, but turned it does: routed to a small bay")
	skew.body.freeze = false
	check(hl.toggle(skew.body) == "hauler_marked","hauler takes the skewed load")
	var took := ""
	var turned := false
	for i in 1800:
		await process_frame
		if not is_instance_valid(skew.body) or skew.gone:
			break
		if LM.fits(skew.body,small*Geom.M,Vector2.DOWN): turned = true
		if skew.body.capture != null:
			took = str(skew.body.capture)
			break
	check(turned and took in ["equip","equip2"],"hauler turns it to pass and the small bay takes it whole (%s)" % took)
	print("mouth_route_check: %d/%d" % [checks-fails, checks])
	quit(1 if fails > 0 else 0)
