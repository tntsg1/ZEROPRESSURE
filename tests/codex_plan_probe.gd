extends SceneTree
# probe: what a WorkPlan records while tests/salvage_bot.gd strips a ship, and how far it replays
const Bot = preload("res://tests/salvage_bot.gd")
var g
var bot
var phase := "strip"
var frame := 0
var rec: Array = []
var ship := "pod"
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"): ship = a
	root.add_child(preload("res://tests/test_window.gd").new())
	Career.path = "user://zp_test_codex_probe_career.json"
	SaveGame.path = "user://zp_test_codex_probe_save.json"
	SaveGame.allow_test = false
	Career.data = Career.fresh()
	Career.data.methods = {"cutter": 1}
	_spawn()
	bot = Bot.new(g, {})
func _spawn() -> void:
	Career.data.active = {}
	Game.start_ship = ship
	Game.contract = {"id":"CODEX-PROBE-%d" % Time.get_ticks_msec(),"ship":ship,"fee":0,"time":3600,"kit":{}}
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro":true,"skip_contract":true,"aim":Vector2.ZERO,"lmb":false,"move":Vector2.ZERO}
	root.add_child(g)
func _count(steps: Array) -> Dictionary:
	var out := {}
	for s in steps: out[str(s.get("do",""))] = int(out.get(str(s.get("do","")),0)) + 1
	return out
func _left() -> int:
	var n := 0
	for id in g.world.order:
		if not g.world.pieces[id].gone: n += 1
	return n
func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10: return false
	if phase == "strip":
		if frame == 10: g.tutorial = null
		if bot.step() or frame > 60000:
			rec = g.plan.rec.duplicate(true)
			print("BOT DONE frames=%d state=%s left=%d blocked=%s rec=%d %s notes=%s" % [frame, g.state, _left(), g.plan.record_blocked, rec.size(), str(_count(rec)), str(bot.notes.slice(0, 6))])
			g.queue_free()
			Engine.time_scale = 1.0
			phase = "spawn"
			frame = 0
		return false
	if phase == "spawn":
		_spawn()
		phase = "wait"
		frame = 0
		return false
	if phase == "wait":
		if frame == 10:
			g.tutorial = null
			g.plan.steps = rec.duplicate(true)
			g.plan.i = 0
			g.plan.preset = false
			print("REPLAY start pieces=%d" % _left())
			g.plan_key()
			phase = "replay"
		return false
	if phase == "replay":
		if frame % 1200 == 0:
			print("  t=%d i=%d/%d wait=%s %s watch=%d left=%d" % [frame, g.plan.i, rec.size(), g.plan.wait, g.plan.wait_arg, g.plan.haul_watch.size(), _left()])
		if not g.plan.running or frame > 36000:
			print("REPLAY END frames=%d i=%d/%d running=%s wait=%s %s watch=%d left=%d incidents=%d" % [frame, g.plan.i, rec.size(), g.plan.running, g.plan.wait, g.plan.wait_arg, g.plan.haul_watch.size(), _left(), g.incidents.size()])
			quit(0)
	return false
