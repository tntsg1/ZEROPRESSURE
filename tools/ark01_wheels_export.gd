extends SceneTree
# ARK-01 改造方案 2: writes the side-hung wheels into ships/ark01.json (tools/authoring/ark01_wheels.gd
# applied to the file as it stands: the file carries hand edits the authoring script doesn't make,
# so it is transformed in place rather than exported anew). Does nothing to a file already turned.
#   godot --headless --path . -s tools/ark01_wheels_export.gd
const Wheels = preload("res://tools/authoring/ark01_wheels.gd")
const Export = preload("res://tools/ship_export.gd")


func _initialize() -> void:
	var path := "res://ships/ark01.json"
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		push_error("ships/ark01.json is not valid JSON")
		quit(1)
		return
	if bool(d.get("rings", {}).get("wheels", false)):
		print("ships/ark01.json already has the wheels")
		quit()
		return
	d = Wheels.apply(d)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(Export.pretty(d, "") + "\n")
	f.close()
	print("wrote ships/ark01.json with the wheels: %d pieces, %d joints, %d lines, %d controls, %d rooms" % [d.pieces.size(), d.joints.size(), d.lines.size(), d.ctrls.size(), d.rooms.size()])
	quit()
