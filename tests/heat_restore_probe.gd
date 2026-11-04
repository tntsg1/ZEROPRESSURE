extends SceneTree
# 124 号 probe: does the furnace snapshot in a copied career restore? (the user's furnace showed
# empty while its heat was still "processing"). Reads a COPY only; writes nothing.
#   godot --headless --path . -s tests/heat_restore_probe.gd -- file=<copy>
const Furnace = preload("res://scripts/smelter.gd")


func _initialize() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("file="):
			path = a.substr(5)
	var s := FileAccess.get_file_as_string(path)
	var d: Dictionary = JSON.parse_string(s.substr(s.find("\n") + 1))
	var h: Dictionary = d.get("industrial_heat", {})
	var snap: Dictionary = h.get("furnace", {})
	var f = Furnace.new(false)
	f.begin_manual()
	var ok: bool = f.restore_manual(snap)
	print("restore_manual: %s · m_s %.3f m_l %.3f T %.1f input %.2f" % [ok, f.m_s, f.m_l, f.T, f.input_t])
	if not ok and f.has_method("restore_reason"):
		print("why: %s" % f.restore_reason())
	quit(0)
