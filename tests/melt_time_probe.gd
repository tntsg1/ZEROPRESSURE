extends SceneTree
# How long a heat takes now (user 2026-11-05: melting under 30 s, cooling under 10 s), the furnace
# model alone at full power: charge → all liquid at tapping heat, and the billets' cooling to 200 °C.
#   godot --headless --path . -s tests/melt_time_probe.gd
const Furnace = preload("res://scripts/smelter.gd")


func _initialize() -> void:
	for tonnes in [3.0, 6.0, 12.0]:
		var f = Furnace.new()
		f.begin_manual()
		f.manual_charge(tonnes)
		f.manual_command("feed", 1.0)
		f.manual_command("power", 1.0)
		var s := 0.0
		while s < 900.0 and not (f.bunker <= 0.001 and f.m_s <= 0.001 and f.T >= Furnace.T_TAP - 25.0):
			f.step(1.0 / 60.0)
			s += 1.0 / 60.0
		var melt := s
		var hot := 1600.0
		var c := 0.0
		while hot > 200.0:
			hot = 25.0 + (hot - 25.0) * exp(-(1.0 / 60.0) / Furnace.COOL_TAU)
			c += 1.0 / 60.0
		print("  %.0f t: melt to tapping heat %.1f s; cooling 1600 -> 200 °C %.1f s" % [tonnes, melt, c])
		f.free() if f is Object and not f is RefCounted else null
	quit()
