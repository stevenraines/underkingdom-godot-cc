extends TileMapLayer

## EntityLayer - Custom TileMapLayer with runtime color modulation
##
## Allows runtime color changes via TileData.modulate

# Reference to parent ASCIIRenderer to access modulated_cells dictionary
var renderer: ASCIIRenderer

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	if not renderer:
		return false
	return renderer.entity_modulated_cells.has(coords)

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	if not renderer:
		return
	tile_data.modulate = renderer.entity_modulated_cells.get(coords, Color.WHITE)
