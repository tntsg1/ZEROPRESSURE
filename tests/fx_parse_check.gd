extends SceneTree
# Every mechanism drawing script (*_fx.gd) and the mechanism scripts that make them load and
# compile (a parse error in one of them stops the whole game loading).
# godot --headless --path . -s tests/fx_parse_check.gd
func _initialize() -> void:
	var bad := 0
	var n := 0
	var d := DirAccess.open("res://scripts")
	var names: Array = []
	for f in d.get_files():
		if f.ends_with("_fx.gd") or f == "mech_fx_kit.gd":
			names.append(f)
	for f in ["ice", "flywheel", "thermal", "softshell", "cryo", "furnace", "munitions", "media", "immersion", "sandwich", "drillstring", "coldchain", "tanknet", "dilution", "tether", "composite", "bio", "atmos", "spine", "liquids", "liquid_surface", "liquid_colors", "waterball", "liquid_rounds", "boiloff", "art_equip", "gas_plant", "gas_works", "world", "game"]:
		names.append(f + ".gd")
	for f in names:
		var s = load("res://scripts/" + f)
		n += 1
		if s == null or not s.can_instantiate():
			bad += 1
			print("  [FAIL] %s does not load" % f)
	print("FX PARSE %s (%d of %d load)" % ["PASS" if bad == 0 else "FAIL", n - bad, n])
	quit(1 if bad > 0 else 0)
