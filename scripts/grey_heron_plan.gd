extends RefCounted
# Authored GR-7 preparation. No cutting, instant emptying or forced reveals:
# every operation uses the same fittings, measurements and simulation as play.
static func steps() -> Array:
	var out: Array = []
	for id in ["V-C01"]: out.append(_setting(id,true))
	for id in ["GAS-AB","P-C01","GAS-D"]: out.append(_hose(id,true))
	for id in ["K-G","K-B"]: out.append(_setting(id,false))
	out.append(_setting("E-D02",true))
	out.append(_check("E-D01","volts",0.9))
	out.append(_setting("PWR-EXT",true))
	out.append(_setting("HATCH-JAM",true))
	out.append(_setting("HATCH-SW",true,[_read("P-C01","pressure",1.0)]))
	out.append(_setting("DR-BC",true,[_read("GAS-AB","pressure",1.0),_read("P-C01","pressure",1.0)]))
	out.append(_setting("DR-CD",true,[_read("P-C01","pressure",1.0),_read("GAS-D","pressure",1.0)]))
	out.append(_setting("DR-CE",true,[_read("P-C01","pressure",1.0),{"room":"E","kind":"pressure","max":1.0}]))
	out.append(_setting("G-LOCAL",false))
	for id in ["TK-B1","TK-B2","EM-A"]: out.append(_hose(id,true))
	out.append({"ctrl":"GUARD-F","op":"guard","pre":[]})
	out.append(_setting("V-F01",true))
	out.append(_hose("FUEL-F",true))
	for id in ["V-E1","V-E2"]: out.append(_setting(id,true))
	out.append(_hose("COOL-E",true))
	var final: Array = [_read("E-D01","volts",0.9),_read("COOL-E","fluid",0.01),_read("COOL-E","temp",55.0),_read("FUEL-F","fluid",0.01)]
	for id in ["GAS-AB","P-C01","GAS-D","TK-B1","TK-B2","EM-A"]: final.append(_read(id,"pressure",1.0))
	out.append({"ctrl":"COOL-E","op":"check","pre":final})
	for id in ["V-F01","V-E1","V-E2"]: out.append(_setting(id,false))
	for id in ["GAS-AB","P-C01","GAS-D","TK-B1","TK-B2","EM-A","FUEL-F","COOL-E"]: out.append(_hose(id,false))
	out.append(_setting("PWR-EXT",false))
	return out

static func _read(id: String, kind: String, limit: float) -> Dictionary:
	return {"key":id,"kind":kind,"max":limit}
static func _setting(id: String, value: bool, pre: Array = []) -> Dictionary:
	return {"ctrl":id,"op":"set","value":value,"pre":pre}
static func _hose(id: String, value: bool) -> Dictionary:
	return {"ctrl":id,"op":"hose","value":value,"pre":[]}
static func _check(id: String, kind: String, limit: float) -> Dictionary:
	return {"ctrl":id,"op":"check","pre":[_read(id,kind,limit)]}

static func _available(plan, id: String):
	var g = plan.game
	var c = g.world.ctrls.get(id)
	if c == null or not g.world.ctrl_alive(c):
		plan._pause("plan_changed",id)
		plan.running = false
		return null
	var blocked: String = g.tools._ctrl_blocked(c)
	if blocked != "":
		plan._pause("plan_hidden" if blocked == "hidden" else "plan_preset_blocked",id)
		return null
	return c

static func tick(plan, dt: float) -> void:
	plan.step_t += dt
	if plan.step_t < plan.STEP_TIME: return
	plan.step_t = 0.0
	var g = plan.game
	var st: Dictionary = plan.steps[plan.i]
	for pr in st.pre:
		var reading: Dictionary
		var label: String = str(pr.get("key",pr.get("room","")))
		if pr.has("room"):
			# Door-side pressure probe: measure the actual adjacent compartment.
			reading = g.sys.measure("WP:" + pr.room,"pressure",pr.room,"inst_pressure",{"vol":pr.room})
		else:
			var probe = _available(plan,pr.key)
			if probe == null: return
			if probe.medium == "gas" and g.sys.dead_leg_closed(probe):
				plan._pause("plan_preset_blocked",str(g.sys.vessel_cfg.get(probe.target,{}).get("dead_leg",probe.id)))
				return
			g.do_measure({"kind":"ctrl","ctrl":probe,"pos":g.world.ctrl_world(probe)})
			var key: String = pr.key + ("/T" if pr.kind == "temp" else "")
			reading = g.sys.readings.get(key,{})
		if reading.is_empty() or g.sys.stale(reading) or float(reading.val) > float(pr.max):
			plan._pause("plan_preset_wait",label)
			return
	plan.wait = ""
	if st.op == "guard":
		var p = g.world.tag(st.ctrl)
		if p != null and not p.gone and p.body == null:
			var joints: Array = g.world.joints_of(p)
			if joints.is_empty():
				plan._pause("plan_preset_blocked",st.ctrl)
				return
			var j = joints[0]
			if not j.type in ["bolt","clamp"]:
				plan._pause("plan_preset_blocked",st.ctrl)
				return
			g.do_wrench({"kind":"joint","joint":j,"pos":g.world.joint_world(j)},true)
			return # allow connectivity/physics to release the cover before retry
	else:
		var c = _available(plan,st.ctrl)
		if c == null: return
		var success := true
		var incidents: int = g.incidents.size()
		if st.op == "set":
			var current: bool = c.state
			if c.kind == "stop": current = not g.sys.running("G-01")
			if c.kind == "hatch":
				current = true
				for tag in Ship.ctrl_cfg(g.ship,c.id).get("doors",[]):
					var p = g.world.tag(tag)
					if p == null or p.gone:
						plan._pause("plan_changed",tag)
						plan.running = false
						return
					current = current and p.door_open
			var want: bool = true if c.kind == "stop" else st.value
			if current != want:
				g.changed["c:" + c.id] = true
				success = g._operate(c,g.world.ctrl_world(c))
				g.log_op("plan")
		elif st.op == "hose":
			var connected: bool = g.sys.hoses.has(c.id)
			if connected and st.value and g.sys.hoses[c.id].get("mode","") != "recover":
				success = g.do_hose({"ctrl":c,"pos":g.world.ctrl_world(c)},true)
				connected = false
			if success and connected != bool(st.value):
				var old_mode: String = g.tools.hose_mode
				g.tools.hose_mode = "recover"
				success = g.do_hose({"ctrl":c,"pos":g.world.ctrl_world(c)},true)
				g.tools.hose_mode = old_mode
		if g.incidents.size() > incidents:
			plan._pause("plan_preset_blocked",c.id)
			plan.running = false
			return
		if not success:
			plan._pause("plan_preset_blocked",c.id)
			return
	plan.i += 1
