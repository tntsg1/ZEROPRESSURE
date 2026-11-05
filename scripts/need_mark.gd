extends Node2D
# 128 号 第 3 段 §十二: the one target mark on the screen — where the main line's step leads (a
# district's business console to press "修" at, a berth facility to mend). The brackets round the
# target (scripts/guide_mark.gd) and the way there as every "fly there" guide shows it: lit chevrons
# along the floor, the edge arrow with the metres left (scripts/guide_way.gd). Made by the HUD,
# under the game. Quiet whenever another guide speaks, a page is open, or the HUD's voice is off.

const GuideMark = preload("res://scripts/guide_mark.gd")
const GuideWay = preload("res://scripts/guide_way.gd")
const PortStructure = preload("res://scripts/port_structure.gd")

var game
var target := Vector2.INF
var label := ""
var way = GuideWay.new()
var t := 0.0
var avoid := Rect2()


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	way.attach(self)


# where a step's go leads: {at, name} (empty when it is not a place)
static func spot_of(go: String) -> Dictionary:
	if go.begins_with("guide:build:"):
		var z := go.get_slice(":", 2)
		if z in Port.ZONES and z != "salvage":
			return {"at": PortStructure.console_spot(z), "name": Txt.t("pt_console_business") + " · " + Port.name_of(z)}
	if go.begins_with("guide:repair:"):
		var id := go.get_slice(":", 2)
		if Repair.found(id):
			return {}
		return {"at": RepairShow.spot(id), "name": Repair.name_of(id)}
	return {}


func set_go(go: String, on: bool) -> void:
	var s := spot_of(go) if on else {}
	target = s.get("at", Vector2.INF)
	label = str(s.get("name", ""))


func _process(dt: float) -> void:
	t += dt
	var flying: bool = target != Vector2.INF and game != null and game.drone != null and game.console_ui == null
	way.update(game, game.drone.global_position if flying else Vector2.INF, target if flying else Vector2.INF, dt)
	queue_redraw()


func _draw() -> void:
	if target == Vector2.INF or game == null or game.console_ui != null:
		return
	var z: float = maxf(game.cam_zoom(), 0.02)
	GuideMark.target(self, target, z, UiSkin.ACCENT, t, label, 34.0)
	way.draw_edge(self, label, UiSkin.ACCENT, avoid)
