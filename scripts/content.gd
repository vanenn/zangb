extends RefCounted

var classes = {}
var survivors = {}
var weapons = {}
var enemies = {}
var maps = {}
var waves = []
var mods = {}
var equipment = {}
var character_textures = []
var prop_textures = []
var floor_textures = []
var vfx_frames = {}
const VFX_SHEETS = {
	"physical":["shotgun_hit","nail_hit","bolt_hit","pistol_hit"],
	"melee":["wrench","baton","cleaver","chainsaw"],
	"elements":["lightning","acid_spray","fire_burst","water_jet"],
	"tactical":["paper_hit","brick_hit","sonic","explosion"],
	"ground":["fire_loop","acid_loop","water_loop","dust"],
	"projectiles":["book_flight","brick_flight","chalk_flight","nail_flight"],
	"equipment":["bolt_flight","speaker","muzzle","armor_hit"]
}
var font: Font = preload("res://assets/NotoSerifCJKsc-Regular.otf")
var cover: Texture2D = preload("res://assets/cover.png")

func _init():
	for sheet in VFX_SHEETS:
		var atlas = load("res://assets/vfx/%s.png" % sheet)
		var cell = atlas.get_size()/Vector2(6,4)
		for row in range(4):
			var frames = []
			for column in range(6):
				var frame = AtlasTexture.new()
				frame.atlas = atlas
				frame.region = Rect2(Vector2(column,row)*cell,cell)
				frame.filter_clip = true
				frames.append(frame)
			vfx_frames[VFX_SHEETS[sheet][row]] = frames
	for name in ["classes", "survivors", "weapons", "enemies", "maps", "mods", "equipment"]:
		var entries = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))
		var table = {}
		for entry in entries:
			table[entry.id] = entry
		set(name, table)
	waves = JSON.parse_string(FileAccess.get_file_as_string("res://data/waves.json"))
	character_textures = _atlas(preload("res://assets/characters.png"))
	var added = preload("res://assets/characters-v2.png")
	for index in range(6):
		var tile = AtlasTexture.new()
		tile.atlas = added
		tile.region = Rect2(Vector2(index%3,index/3)*added.get_size()/Vector2(3,2),added.get_size()/Vector2(3,2))
		tile.filter_clip = true
		character_textures.append(tile)
	prop_textures = _atlas(preload("res://assets/props.png"))
	var floors = load("res://assets/floors.png")
	for index in range(4):
		var texture = AtlasTexture.new()
		texture.atlas = floors
		texture.region = Rect2(Vector2(index%2,index/2)*floors.get_size()/2.0,floors.get_size()/2.0)
		texture.filter_clip = true
		floor_textures.append(texture)

func _atlas(texture: Texture2D) -> Array:
	var result = []
	var cell = texture.get_size() / 4.0
	for index in range(16):
		var tile = AtlasTexture.new()
		tile.atlas = texture
		tile.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
		tile.filter_clip = true
		result.append(tile)
	return result

func wave(number: int) -> Dictionary:
	return waves[clampi(number - 1, 0, 9)]

func effect_frame(id: String, phase: float) -> AtlasTexture:
	return vfx_frames[id][clampi(int(phase*6),0,5)]

func survivor_pool(unlocked: Array) -> Array:
	var result = []
	for id in survivors:
		if id in unlocked:
			result.append(id)
	return result
