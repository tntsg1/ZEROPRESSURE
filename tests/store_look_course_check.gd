extends SceneTree
# Warehouse thumbnail lookup must skip training course files in ships/.

func _initialize() -> void:
	var missing := StoreBook.look_any("", "", "codex_missing_equipment_kind")
	var battery := StoreBook.look_any("", "", "p_battery")
	var course := StoreBook.look("sp_atmos_course", "BAT-T")
	if not missing.is_empty() or battery.is_empty() or not course.is_empty():
		push_error("Warehouse thumbnail lookup failed: missing=%s battery=%s course=%s" % [missing, battery, course])
		quit(1)
		return
	print("PASS: missing thumbnail, real equipment fallback, and course file")
	quit()
