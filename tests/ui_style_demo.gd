extends SceneTree
# UI style proposals for the berth terminal home page: one 1080p shot per style
# (tests/out/ui_style_A..D.png), a 2×2 overview with notes, and a 3-frame strip
# of the selection sliding from 1 to 2 in one style.
# A's dark variants: `dark` shoots ui_style_A_dark1/2.png, each also with 2 selected
# (…_sel2.png), and ui_style_A_compare.png beside the light original.
# tools/run_test.sh tests/ui_style_demo.gd -- [A B C D] [strip=X] [dark]
const Cap = preload("res://tests/cap.gd")
const NOTES = preload("res://scripts/ui_demo/notes.gd")

const STYLES := {
	"A": "res://scripts/ui_demo/style_a.gd",
	"B": "res://scripts/ui_demo/style_b.gd",
	"C": "res://scripts/ui_demo/style_c.gd",
	"D": "res://scripts/ui_demo/style_d.gd",
}


func _initialize() -> void:
	Career.path = "user://zp_test_uidemo_career.json"
	SaveGame.path = "user://zp_test_uidemo_save.json"
	SaveGame.allow_test = true
	root.add_child(preload("res://tests/test_window.gd").new())
	_run.call_deferred()


func _shot(node: Control, path: String) -> void:
	node.queue_redraw()
	for i in 4:
		await process_frame
	Cap.save(root, path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var which: Array = []
	var strip := ""
	var dark := false
	for a in args:
		if a == "dark":
			dark = true
		elif a.begins_with("strip="):
			strip = a.substr(6)
		elif STYLES.has(a):
			which.append(a)
	if which.is_empty() and strip == "" and not dark:
		which = STYLES.keys()
	for k in which:
		var n: Control = load(STYLES[k]).new()
		root.add_child(n)
		await _shot(n, "res://tests/out/ui_style_%s.png" % k)
		n.queue_free()
		await process_frame
	if which.size() == 4:
		await _overview()
	if strip != "":
		await _strip(strip)
	if dark:
		await _dark()
	quit()


func _dark() -> void:
	for v in ["dark1", "dark2"]:
		var n: Control = load(STYLES.A).new()
		n.set_variant(v)
		root.add_child(n)
		await _shot(n, "res://tests/out/ui_style_A_%s.png" % v)
		n.sel = 1.0
		await _shot(n, "res://tests/out/ui_style_A_%s_sel2.png" % v)
		n.queue_free()
		await process_frame
	var o: Control = NOTES.Board.new()
	o.mode = "compare"
	root.add_child(o)
	await _shot(o, "res://tests/out/ui_style_A_compare.png")
	o.queue_free()


func _overview() -> void:
	var o: Control = NOTES.Board.new()
	o.mode = "grid"
	root.add_child(o)
	await _shot(o, "res://tests/out/ui_style_overview.png")
	o.queue_free()
	await process_frame


func _strip(k: String) -> void:
	var n: Control = load(STYLES[k]).new()
	root.add_child(n)
	var steps := [0.0, 0.5, 1.0]
	for i in 3:
		n.sel = steps[i]
		n.t = i * 0.6
		await _shot(n, "res://tests/out/ui_style_%s_sel%d.png" % [k, i])
	n.queue_free()
	await process_frame
	var o: Control = NOTES.Board.new()
	o.mode = "strip"
	o.strip_key = k
	root.add_child(o)
	await _shot(o, "res://tests/out/ui_style_%s_select_strip.png" % k)
	o.queue_free()
