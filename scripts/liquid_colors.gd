extends RefCounted
# What colour a liquid is (user 2026-11-10: "不同液体用它现实里的颜色" — the water had been green).
# One table for everything that draws a real liquid: liquids.gd's globules and jets, the liquid
# surface (liquid_surface.gd), and the mechanisms' own drawing (*_fx.gd). The fluid-system marker
# colour in the UI and schematics (Pal.FLUID) is not this: it tells liquid lines from gas ones.
# Kept restrained for the black-and-white picture: pale, see-through, only the liquids that are
# strongly coloured in life (tetroxide, hydraulic oil, coolant) are.
#   col: the liquid's colour; op: how opaque its body is (0 clear, 1 you can't see through it)
#   mist: true for the cryogens (a white cold mist hangs round them)
# Coolant (glycol): pink, not the common fluorescent green — green was the old colour of every
# liquid in the game and would read as "nothing changed".

const COL := {
	"water":       {"col": Color(0.80, 0.90, 1.00), "op": 0.0},
	"fuel":        {"col": Color(0.96, 0.86, 0.46), "op": 0.15},   # kerosene / RP-1
	"mmh":         {"col": Color(0.96, 0.95, 0.80), "op": 0.05},   # colourless, a touch of yellow
	"nto":         {"col": Color(0.60, 0.21, 0.08), "op": 0.55},   # red-brown, fumes brown
	"glycol":      {"col": Color(1.00, 0.46, 0.70), "op": 0.25},   # coolant: pink
	"oil":         {"col": Color(0.95, 0.62, 0.16), "op": 0.45},   # lube oil: amber
	"hydraulic":   {"col": Color(0.86, 0.20, 0.16), "op": 0.4},    # hydraulic fluid: red
	"foam":        {"col": Color(0.95, 0.95, 0.94), "op": 0.9},    # fire foam: white
	"mud":         {"col": Color(0.48, 0.40, 0.32), "op": 0.95},   # drilling mud: grey-brown
	"lhe":         {"col": Color(0.90, 0.94, 1.00), "op": 0.0, "mist": true},
	"lh2":         {"col": Color(0.90, 0.94, 1.00), "op": 0.0, "mist": true},
	"lng":         {"col": Color(0.92, 0.94, 0.97), "op": 0.0, "mist": true},
	"ln2":         {"col": Color(0.90, 0.94, 1.00), "op": 0.0, "mist": true},
	"lox":         {"col": Color(0.55, 0.75, 1.00), "op": 0.15, "mist": true},   # liquid oxygen: pale blue
	"refrigerant": {"col": Color(0.90, 0.93, 0.97), "op": 0.0},
	"solvent":     {"col": Color(0.92, 0.94, 0.96), "op": 0.0},
	"acid":        {"col": Color(0.95, 0.94, 0.78), "op": 0.05},
	"nutrient":    {"col": Color(0.92, 0.82, 0.48), "op": 0.2},
}
# the fluid kinds the ships name that have no globule look of their own: their colour key
const FLUID_KEY := {"coolant": "glycol", "n2": "ln2", "o2": "lox", "lox": "lox", "hydraulic": "hydraulic",
	"refrigerant": "refrigerant", "solvent": "solvent", "acid": "acid", "nutrient": "nutrient", "glycol": "glycol",
	"oil": "oil", "water": "water", "fuel": "fuel", "lng": "lng", "mud": "mud", "foam": "foam"}
# their order in the liquid surface's palette (liquid_surface.gd)
const ORDER := ["water", "fuel", "mmh", "nto", "glycol", "oil", "hydraulic", "foam", "mud",
	"lhe", "lh2", "lng", "ln2", "lox", "refrigerant", "solvent", "acid", "nutrient"]
const PAL_W := 5
const PAL_H := 4


static func entry(key: String) -> Dictionary:
	return COL.get(key, COL.get(FLUID_KEY.get(key, "water"), COL.water))


static func of(key: String, a: float = 1.0) -> Color:
	var c: Color = entry(key).col
	return Color(c.r, c.g, c.b, a)


static func opacity(key: String) -> float:
	return float(entry(key).get("op", 0.0))


static func misty(key: String) -> bool:
	return bool(entry(key).get("mist", false))


# a volume's colour key (its look, else its fluid kind)
static func of_volume(v: Dictionary) -> String:
	if v.has("look"):
		return str(v.look)
	return str(FLUID_KEY.get(str(v.get("fluid", "")), "water"))


# where a liquid sits in the palette: the surface's tint channels carry this (u, v)
static func uv(key: String) -> Vector2:
	var k := key if COL.has(key) else str(FLUID_KEY.get(key, "water"))
	var i: int = ORDER.find(k)
	if i < 0:
		i = 0
	return Vector2((i % PAL_W + 0.5) / PAL_W, (i / PAL_W + 0.5) / PAL_H)


# the palette the surface looks its colour up in: rgb the colour, a its opacity
static func palette() -> ImageTexture:
	var img := Image.create(PAL_W, PAL_H, false, Image.FORMAT_RGBAF)
	img.fill(Color(COL.water.col.r, COL.water.col.g, COL.water.col.b, 0.0))
	for i in ORDER.size():
		var e: Dictionary = COL[ORDER[i]]
		var c: Color = e.col
		img.set_pixel(i % PAL_W, i / PAL_W, Color(c.r, c.g, c.b, float(e.get("op", 0.0))))
	return ImageTexture.create_from_image(img)
