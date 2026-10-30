extends SceneTree
# Compatibility survey plus actual receiving geometry, using isolated loads.
var g: Node
var fails := 0
var checks := 0
func _initialize() -> void: _run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL",label])
func load_at(at: Vector2, size: Vector2, key: String):
	var a := at-size*0.5
	var b := at+size*0.5
	var p = g.world.add_piece("cargo",PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]),{"key":key,"cls":"equip","mass":0.2,"value":100.0})
	g.world.make_body([p],null)
	p.body.freeze = true
	return p
func _run() -> void:
	SaveGame.allow_test = false
	Game.contract = {}
	g = load("res://scenes/main.tscn").instantiate()
	g.ship_id = "pod"
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
	await frames(8)
	g.tutorial = null
	var zp := Dock.zpos("equip")
	var wide = load_at(zp+Vector2(0,30),Vector2(5.55,0.4)*Geom.M,"WIDE")
	await frames(20)
	check(wide.body != null and wide.body.capture == null and not wide.gone,"standard mouth cannot swallow equipment wider than its actual opening")
	g.world.remove_piece(wide)
	var offset = load_at(zp+Vector2(90,20),Vector2(1.2,0.4)*Geom.M,"OFFSET")
	await frames(20)
	check(offset.body != null and offset.body.capture == null and not offset.gone,"centre distance alone cannot capture a load whose edge misses the receiving opening")
	g.world.remove_piece(offset)
	var tall = load_at(zp+Vector2(0,3.1*Geom.M),Vector2(1.0,5.0)*Geom.M,"TALL")
	await frames(20)
	check(tall.body != null and tall.body.capture == "equip","tall equipment is engaged at its leading surface before its centre hits the boom")
	for i in 300:
		await process_frame
		if tall.gone: break
	check(tall.gone and g.income_equip > 0,"leading-surface intake follows the real recovery and payment path")
	var ships := 0
	var equipment := 0
	var problems: Array = []
	for file in DirAccess.get_files_at("res://ships"):
		if not file.ends_with(".json"): continue
		var ship := Ship.load_data(file.get_basename())
		if not ship.has("pieces"): continue
		var ext := Ship.extent(ship)
		Dock.configure(Dock.length_for(float(ship.get("length",0)),{}),ext.x,ext.y)
		g.dock.set_ship(ship)
		ships += 1
		var rack: Dictionary = Dock.ZONES.equip_bulk
		if (rack.face == Vector2.DOWN and (rack.pos.x-rack.w*0.5 <= Dock.ARM_X1+4.0 or rack.pos.x+rack.w*0.5 >= Dock.BOUNDS.end.x)) or (rack.face == Vector2.LEFT and (rack.pos.x <= Dock.ARM_X1+4.0 or rack.pos.x >= Dock.BOUNDS.end.x or rack.pos.y-rack.w*0.5 <= Dock.RAIL_Y or rack.pos.y+rack.w*0.5 >= Dock.FLOOR_Y)):
			problems.append(file+": rack outside usable berth or overlaps boom")
		for p in ship.pieces:
			if p.get("cls","") != "equip": continue
			equipment += 1
			var poly := PackedVector2Array()
			for q in p.poly: poly.append(Vector2(q[0],q[1]))
			var box := Geom.bbox(poly)
			if (box.size.x if rack.face == Vector2.DOWN else box.size.y) >= float(rack.w): problems.append(file+": "+str(p.key))
	print("Receiver survey: %d ships, %d equipment pieces; problems=%s" % [ships,equipment,str(problems)])
	check(ships > 30 and equipment > 100 and problems.is_empty(),"all authored ship equipment fits an outside rack within its configured berth; no large legacy target is stranded")
	var vt := Ship.load_data("vt80")
	var ext := Ship.extent(vt)
	Dock.configure(Dock.length_for(float(vt.length),{}),ext.x,ext.y)
	g.dock.set_ship(vt)
	var rack: Dictionary = Dock.ZONES.equip_bulk
	check(rack.face == Vector2.LEFT and Dock.FLOOR_X1 == 120.0,"59 m header uses side entry without changing its existing 120 m berth")
	var header = load_at(Dock.zpos("equip_bulk")-Vector2(29.5*Geom.M+85,0),Vector2(59.0,0.4)*Geom.M,"HEADER")
	await frames(4)
	var header_body = header.body
	var mask: int = header_body.collision_mask
	for i in 80:
		if header.gone or header_body.capture != null: break
		preload("res://scripts/load_motion.gd").move(header_body,Vector2(2,0))
		await process_frame
	check(not header.gone and header_body.capture == "equip_bulk" and mask == FreeBody.MASK,"full-size 59 m header reaches the side rack through collision-checked movement")
	for i in 300:
		await process_frame
		if header.gone: break
	check(header.gone,"side entry completes the same real equipment recovery path")
	g.queue_free()
	await frames(5)
	var drain := Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<drain: await process_frame
	print("G4 RECEIVER %s (%d checks, %d failed)" % ["PASS" if fails == 0 else "FAIL",checks,fails])
	quit(0 if fails == 0 else 1)
