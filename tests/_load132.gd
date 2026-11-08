extends SceneTree
func _initialize() -> void:
	for p in ["res://scripts/console_kit.gd", "res://scripts/guide_cards.gd", "res://scripts/guide_card.gd", "res://scripts/guide_lead.gd", "res://scripts/codex_page.gd", "res://scripts/hud.gd", "res://scripts/district_panel.gd", "res://scripts/hall_panel.gd", "res://scripts/process_queue_panel.gd", "res://scripts/heat_panel.gd", "res://scripts/mill_panel.gd", "res://scripts/grid.gd", "res://scripts/industrial_heat.gd", "res://scripts/need_voice.gd", "res://scripts/power_panel.gd", "res://scripts/settings_panel.gd", "res://scripts/power_supply.gd", "res://scripts/ops.gd", "res://scripts/power_works.gd", "res://scripts/process_works.gd"]:
		var s = load(p)
		print(p, " ", s != null and s.can_instantiate())
	quit()
