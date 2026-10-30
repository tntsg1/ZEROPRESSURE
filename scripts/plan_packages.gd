extends RefCounted
# Plain package records plus isolated executors. Workers stay outside the tree;
# the owner authorizes and serially ticks them, owns shutdown and delivery events.
var owner_plan
var catalogue: Array = []
var jobs: Array = []
var cursor := 0
var protected: Array = []
var selected: Array = []

func _init(plan) -> void:
	owner_plan = plan

func dispose() -> void:
	for j in jobs:
		if is_instance_valid(j.worker): j.worker.free()
	jobs.clear()
	owner_plan = null

func refresh() -> void:
	var g = owner_plan.game
	catalogue = []
	if not owner_plan.steps.is_empty():
		catalogue.append({"id":"preset:gr7:preparation" if owner_plan.preset else "legacy:" + g.ship_id,"version":1,"ship":g.ship_id,"kind":"preset" if owner_plan.preset else "legacy",
			"label":Txt.t("pkg_preparation" if owner_plan.preset else "pkg_legacy"),"steps":owner_plan.steps.duplicate(true),
			"deps":[],"targets":[],"protected":[],"preset":owner_plan.preset})
	if g.ship_id == "gr7":
		if not catalogue.any(func(d):return d.id == "preset:gr7:preparation"):
			catalogue.append({"id":"preset:gr7:preparation","version":1,"ship":"gr7","kind":"preset","label":Txt.t("pkg_preparation"),
				"deps":[],"targets":[],"protected":[],"preset":true,"steps":load("res://scripts/grey_heron_plan.gd").steps()})
		var path := "res://data/workplans/gr7_roof.json"
		if FileAccess.file_exists(path):
			var authored = JSON.parse_string(FileAccess.get_file_as_string(path))
			if authored is Dictionary and valid(authored):
				authored.label = str(authored.get("label_zh" if Txt.zh else "label_en",authored.id))
				catalogue.append(authored)
	for d in Career.data.get("plan_books", {}).get(g.ship_id, []):
		if d is Dictionary and valid(d):
			catalogue.append(d.duplicate(true))
	# The field save owns the exact revision already authorized. Keep it visible
	# even if the career's shelf changed after the job began.
	for j in jobs:
		if not catalogue.any(func(d):return d.id == j.definition.id): catalogue.append(j.definition.duplicate(true))
	for d in catalogue: d.label = display_name(d)

func display_name(d: Dictionary) -> String:
	if d.has("label_key"):
		var name := Txt.t(str(d.label_key))
		return name % str(d.get("label_arg","")) if "%s" in name else name
	return str(d.get("label_zh" if Txt.zh else "label_en",d.get("label",d.get("id",""))))

func valid(d: Dictionary) -> bool:
	if str(d.get("id", "")) == "" or int(d.get("version", 0)) != 1: return false
	if not d.get("steps", null) is Array or d.steps.is_empty(): return false
	if not d.get("deps", []) is Array or not d.get("protected", []) is Array or not d.get("targets", []) is Array: return false
	for st in d.steps:
		if not st is Dictionary: return false
		if d.get("preset", false):
			if str(st.get("op", "")) not in ["set","hose","check","guard"]: return false
			continue
		match str(st.get("do", "")):
			"cut":
				if not st.get("pl", null) is Array or st.pl.size() < 2 or str(st.get("key", "")) == "": return false
				for q in st.pl:
					if not q is Array or q.size() != 2: return false
					for v in q:
						if typeof(v) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(v)): return false
			"haul":
				if not st.get("keys", null) is Array or st.keys.is_empty() or str(st.get("zone", "")) not in ["equip","metal","hazard"]: return false
			"w", "h":
				if str(st.get("ctrl", "")) == "": return false
			_:
				return false
	return true

func cut_conflicts(st: Dictionary, keep: Array = []) -> Array:
	var out: Array = []
	var g = owner_plan.game
	var key := str(st.get("key", ""))
	var piece = g.world.key_piece(key)
	var path := PackedVector2Array()
	if piece != null:
		for q in st.get("pl",[]): path.append(g.world.frame(piece) * Vector2(float(q[0]),float(q[1])))
	for k in (protected if keep.is_empty() else keep):
		if key == str(k) or key.begins_with(str(k)+"~"):
			out.append(k)
			continue
		var p = g.world.key_piece(str(k))
		if p == null or path.is_empty(): continue
		var poly: PackedVector2Array = g.world.world_poly(p)
		var radius := float(st.get("kerf",World.KERF))
		if not Geom.bbox(path).grow(radius).intersects(Geom.bbox(poly)): continue
		var edge := poly.duplicate()
		edge.append(poly[0])
		if Geometry2D.is_point_in_polygon(path[0],poly) or Geometry2D.is_point_in_polygon(path[-1],poly) or Geom.polyline_hits_polyline(path,edge) != null:
			out.append(k)
			continue
		for cutter in Geom.stroke(path,radius):
			if not Geometry2D.intersect_polygons(cutter,poly).is_empty():
				out.append(k)
				break
	return out

func conflicts(d: Dictionary, extra: Array = []) -> Array:
	var out: Array = []
	var keep := protected.duplicate()
	for key in d.get("protected", []) + extra:
		if not keep.has(key): keep.append(key)
	for st in d.steps:
		if st.get("do", "") == "cut":
			for k in cut_conflicts(st,keep):
				if not out.has(k): out.append(k)
	return out

func authorize(ids: Array) -> bool:
	if owner_plan.running: return false
	var definitions := {}
	for d in catalogue: definitions[str(d.id)] = d
	var keep := protected.duplicate()
	for id in ids:
		if definitions.has(str(id)):
			for key in definitions[str(id)].get("protected",[]):
				if not keep.has(key): keep.append(key)
	# Validate the entire request before changing any executor or progress.
	for id in ids:
		if not definitions.has(str(id)): return false
		var d: Dictionary = definitions[str(id)]
		if not valid(d): return false
		if str(d.get("ship", owner_plan.game.ship_id)) != owner_plan.game.ship_id or not conflicts(d,keep).is_empty(): return false
		for dep in d.get("deps", []):
			if not ids.has(dep): return false
	if _cyclic(definitions, ids): return false
	for j in jobs: j.enabled = ids.has(j.definition.id)
	for id in ids:
		if _job(str(id)) != null: continue
		var d: Dictionary = definitions[str(id)].duplicate(true)
		var w = owner_plan.get_script().new()
		w.game = owner_plan.game
		w.steps = d.steps.duplicate(true)
		w.preset = bool(d.get("preset", false))
		w.package_worker = true
		if str(d.id) == "legacy:" + owner_plan.game.ship_id or (owner_plan.preset and str(d.id) == "preset:gr7:preparation"):
			w.i = owner_plan.i
			w.haul_watch = owner_plan.haul_watch.duplicate(true)
		if w.preset: w._preset_driver = load("res://scripts/grey_heron_plan.gd")
		jobs.append({"definition":d,"worker":w,"enabled":true,"state":"ready"})
	selected = ids.duplicate()
	protected = keep
	return not ids.is_empty()

func archive_recording(recording: Array) -> void:
	if recording.is_empty(): return
	var g = owner_plan.game
	var books: Dictionary = Career.data.get("plan_books", {})
	var shelf: Array = books.get(g.ship_id, [])
	var revision := JSON.stringify(recording).sha256_text().substr(0,12)
	var previous := ""
	var at := 0
	var sequence := 0
	while at < recording.size():
		var start := at
		var st: Dictionary = recording[at]
		var kind := str(st.get("do", ""))
		var target := str(st.get("key", "")) if kind == "cut" else ("haul" if kind == "haul" else "controls")
		at += 1
		while at < recording.size():
			var next_st: Dictionary = recording[at]
			var next_kind := str(next_st.get("do", ""))
			var next_target := str(next_st.get("key", "")) if next_kind == "cut" else ("haul" if next_kind == "haul" else "controls")
			if next_target != target: break
			at += 1
		var id := "learned:%s:%s:%d" % [g.ship_id,revision,sequence]
		sequence += 1
		var title := Txt.t("pkg_recorded_controls")
		var label_key := "pkg_recorded_controls"
		if kind == "cut": title = Txt.t("pkg_recorded_cut") % target
		elif kind == "haul": title = Txt.t("pkg_recorded_haul")
		if kind == "cut": label_key = "pkg_recorded_cut"
		elif kind == "haul": label_key = "pkg_recorded_haul"
		var dependencies: Array = []
		if previous != "" and kind != "haul": dependencies.append(previous)
		var segment: Array = recording.slice(start,at).duplicate(true)
		var verified_cut: bool = kind == "cut" and segment.all(func(s):return s.has("before") and s.has("after") and s.has("links"))
		var definition := {"id":id,"version":1,"ship":g.ship_id,"label":title,"label_key":label_key,"label_arg":target,"kind":"verified" if verified_cut else "legacy",
			"targets":[target] if kind == "cut" else [],"protected":[],"deps":dependencies,"steps":segment}
		if not shelf.any(func(d):return d.get("id","") == id): shelf.append(definition)
		if kind != "haul": previous = id
	books[g.ship_id] = shelf
	Career.data.plan_books = books

func _job(id: String):
	for j in jobs:
		if str(j.definition.id) == id: return j
	return null

func _cyclic(definitions: Dictionary, ids: Array) -> bool:
	var done: Array = []
	for n in ids.size():
		for id in ids:
			if done.has(id): continue
			var ready := true
			for dep in definitions[str(id)].get("deps", []):
				if not done.has(dep): ready = false
			if ready: done.append(id)
	return done.size() != ids.size()

func complete(j: Dictionary) -> bool:
	return j.worker.i >= j.worker.steps.size() and j.worker.haul_watch.is_empty()

func dependencies_met(j: Dictionary) -> bool:
	for id in j.definition.get("deps", []):
		var other = _job(str(id))
		if other == null or not other.enabled or not complete(other): return false
	return true

func tick(dt: float) -> void:
	var plan = owner_plan
	var g = plan.game
	if not plan.running or g.state != "play" or g.paused_sim or g.auto_paused: return
	var enabled := 0
	var done := 0
	for j in jobs:
		if not j.enabled: continue
		enabled += 1
		if complete(j):
			j.state = "done"
			done += 1
	if enabled == 0 or enabled == done:
		plan.running = false
		plan.wait = ""
		return
	# One cutting/control executor consumes this frame's machine time. A blocked
	# package yields immediately, so an unrelated authorized job can progress.
	for offset in jobs.size():
		var index := (cursor + offset) % jobs.size()
		var j: Dictionary = jobs[index]
		if not j.enabled or complete(j): continue
		if not dependencies_met(j):
			j.state = "dependency"
			continue
		var w = j.worker
		w.running = true
		var previous_i: int = w.i
		var previous_t: float = w.step_t
		var incident_count: int = g.incidents.size()
		w._physics_process(dt)
		j.state = "blocked" if w.wait != "" else "running"
		if g.incidents.size() > incident_count:
			plan.cancel()
			return
		if w.i != previous_i or w.step_t > previous_t:
			cursor = (index + 1) % jobs.size()
			return

func delivered(b, zone: String) -> void:
	for j in jobs: j.worker.on_haul(b, zone, false)

func summary() -> Array:
	var done := 0
	var enabled := 0
	var line := Txt.t("plan_ready")
	for j in jobs:
		if not j.enabled: continue
		enabled += 1
		if complete(j): done += 1
		elif j.state == "dependency": line = display_name(j.definition) + " · " + Txt.t("pkg_dependency")
		else:
			var state: Array = j.worker.status()
			if not state.is_empty(): line = display_name(j.definition) + " · " + str(state[1])
	if enabled > 0 and done == enabled: line = Txt.t("plan_done")
	return [Txt.t("pkg_progress") % [done, enabled], line]

func save_state() -> Dictionary:
	var records: Array = []
	for j in jobs:
		records.append({"definition":j.definition.duplicate(true),"enabled":j.enabled,"state":j.state,"execution":j.worker.save_state()})
	return {"version":1,"jobs":records,"protected":protected.duplicate(),"selected":selected.duplicate(),"cursor":cursor}

func load_state(d: Dictionary) -> void:
	for j in jobs:
		if is_instance_valid(j.worker): j.worker.free()
	jobs.clear()
	protected = d.get("protected", []).duplicate()
	selected = d.get("selected", []).duplicate()
	cursor = int(d.get("cursor", 0))
	for record in d.get("jobs", []):
		if not record is Dictionary or not record.get("definition", null) is Dictionary or not valid(record.definition): continue
		var w = owner_plan.get_script().new()
		w.game = owner_plan.game
		w.package_worker = true
		w.load_state(record.execution)
		if w.preset: w._preset_driver = load("res://scripts/grey_heron_plan.gd")
		jobs.append({"definition":record.definition.duplicate(true),"worker":w,"enabled":bool(record.enabled),"state":"ready"})
	refresh()
