class_name RenderInterface
extends Node2D

## RenderInterface - Abstract rendering layer
##
## Base class for all renderers. Game logic never touches visuals directly,
## allowing easy swapping between ASCII, sprites, or other rendering methods.

## Render a tile at the given position
func render_tile(position: Vector2i, tile_type: String, variant: int = 0) -> void:
	push_error("render_tile must be overridden in subclass")

## Render an entity at the given position
func render_entity(position: Vector2i, entity_type: String, color: Color = Color.WHITE) -> void:
	push_error("render_entity must be overridden in subclass")

## Clear entity at position
func clear_entity(position: Vector2i) -> void:
	push_error("clear_entity must be overridden in subclass")

## Update field of view (dim/hide tiles outside visible range)
## visible_tiles: tiles visible for entities (requires LOS)
## terrain_visible_tiles: tiles visible for terrain only (optional, daytime outdoors)
func update_fov(visible_tiles: Array[Vector2i], terrain_visible_tiles: Array[Vector2i] = []) -> void:
	push_error("update_fov must be overridden in subclass")

## Center camera on position
func center_camera(position: Vector2i) -> void:
	push_error("center_camera must be overridden in subclass")

## Clear all rendering
func clear_all() -> void:
	push_error("clear_all must be overridden in subclass")
