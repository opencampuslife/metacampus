@tool
extends Node

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_generate_tileset()
	print("[BuildTileset] Done")
	get_tree().quit()

func _generate_tileset() -> void:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(32, 32)

	var tile_files := {
		"grass": "res://assets/tiles/grass.png",
		"path": "res://assets/tiles/path.png",
		"wall": "res://assets/tiles/wall.png",
		"water": "res://assets/tiles/water.png",
		"flower": "res://assets/tiles/flower.png",
		"fence": "res://assets/tiles/fence.png",
	}

	var source_id := 0
	for name in tile_files:
		var path = tile_files[name]
		if not ResourceLoader.exists(path):
			print("  Missing: %s (%s)" % [name, path])
			continue
		var tex = load(path) as Texture2D
		if not tex:
			continue
		var atlas = TileSetAtlasSource.new()
		atlas.texture = tex
		atlas.texture_region_size = Vector2i(32, 32)
		atlas.margins = Vector2i(0, 0)
		atlas.separation = Vector2i(0, 0)
		atlas.tiles/Vector2i(0, 0) = TileSetAtlasSource.TileData.new()
		tileset.add_source(atlas, source_id)
		source_id += 1
		print("  Added: %s" % name)

	var save_path = "res://assets/tiles/campus_tileset.tres"
	ResourceSaver.save(tileset, save_path)
	print("Saved: %s" % save_path)
